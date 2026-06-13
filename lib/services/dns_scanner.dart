// lib/services/dns_scanner.dart
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import '../models/dns_server.dart';
import '../models/game_server.dart';

class ScanResult {
  final double? latencyMs;
  final double  jitterMs;
  final double  lossPct;
  ScanResult({this.latencyMs, this.jitterMs = 0, this.lossPct = 0});
}

class ProtocolResult {
  final bool    supported;
  final double? latencyMs;
  final String? error;
  final String? tlsVersion;
  ProtocolResult({required this.supported, this.latencyMs, this.error, this.tlsVersion});
}

class DnsScanner {

  // ── DNS Query ─────────────────────────────────────────────────
  static Uint8List buildDnsQuery(String domain, {int qtype = 1}) {
    final rng = Random();
    final tid = rng.nextInt(65535);
    final buf = BytesBuilder();
    // header
    buf.addByte((tid >> 8) & 0xFF);
    buf.addByte(tid & 0xFF);
    buf.addByte(0x01); buf.addByte(0x00); // flags: RD
    buf.addByte(0x00); buf.addByte(0x01); // QDCOUNT
    buf.addByte(0x00); buf.addByte(0x00); // ANCOUNT
    buf.addByte(0x00); buf.addByte(0x00); // NSCOUNT
    buf.addByte(0x00); buf.addByte(0x00); // ARCOUNT
    // qname
    for (final part in domain.split('.')) {
      buf.addByte(part.length);
      buf.add(part.codeUnits);
    }
    buf.addByte(0x00);
    // qtype + qclass
    buf.addByte((qtype >> 8) & 0xFF); buf.addByte(qtype & 0xFF);
    buf.addByte(0x00); buf.addByte(0x01);
    return buf.toBytes();
  }

  // ── UDP DNS Test ──────────────────────────────────────────────
  static Future<ScanResult> testDnsUdp(
    String ip, {
    int count = 5,
    Duration timeout = const Duration(seconds: 3),
    String domain = 'google.com',
  }) async {
    final payload = buildDnsQuery(domain);
    final latencies = <double>[];

    for (int i = 0; i < count; i++) {
      try {
        final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
        final t0 = DateTime.now();
        socket.send(payload, InternetAddress(ip), 53);
        await socket.timeout(timeout).first;
        final elapsed = DateTime.now().difference(t0).inMicroseconds / 1000.0;
        latencies.add(elapsed);
        socket.close();
      } catch (_) {
        // timeout یا error
      }
    }

    if (latencies.isEmpty) return ScanResult(lossPct: 100);

    final avg    = latencies.reduce((a, b) => a + b) / latencies.length;
    final loss   = (count - latencies.length) / count * 100;
    double jitter = 0;
    if (latencies.length > 1) {
      final mean = avg;
      jitter = sqrt(latencies.map((l) => pow(l - mean, 2)).reduce((a, b) => a + b) / latencies.length);
    }
    return ScanResult(latencyMs: avg, jitterMs: jitter, lossPct: loss);
  }

  // ── TCP Latency Test ─────────────────────────────────────────
  static Future<double?> tcpProbe(
    String ip, int port, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    try {
      final t0 = DateTime.now();
      final socket = await Socket.connect(ip, port, timeout: timeout);
      final elapsed = DateTime.now().difference(t0).inMicroseconds / 1000.0;
      socket.destroy();
      return elapsed;
    } catch (_) {
      return null;
    }
  }

  // ── DoT Test (DNS over TLS — پورت 853) ──────────────────────
  static Future<ProtocolResult> testDoT(
    String ip, {
    String? hostname,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      final t0  = DateTime.now();
      final raw = await Socket.connect(ip, 853)
          .timeout(timeout);
      final tls = await SecureSocket.secure(
        raw,
        host: hostname,
        onBadCertificate: (_) => true,
      ).timeout(timeout);

      final query = buildDnsQuery('google.com');
      final lenPrefix = Uint8List(2);
      lenPrefix[0] = (query.length >> 8) & 0xFF;
      lenPrefix[1] = query.length & 0xFF;
      tls.add(lenPrefix);
      tls.add(query);
      await tls.flush();

      await tls.timeout(const Duration(seconds: 2)).first;
      final elapsed = DateTime.now().difference(t0).inMicroseconds / 1000.0;
      final tlsVersion = tls.selectedProtocol ?? 'unknown';
      await tls.close();

      return ProtocolResult(
        supported: true,
        latencyMs: elapsed,
        tlsVersion: tlsVersion,
      );
    } on TlsException catch (e) {
      return ProtocolResult(supported: false, error: 'cert:${e.message}');
    } on SocketException {
      return ProtocolResult(supported: false, error: 'port_closed');
    } on TimeoutException {
      return ProtocolResult(supported: false, error: 'timeout');
    } catch (e) {
      return ProtocolResult(supported: false, error: e.toString());
    }
  }

  // ── DoH Test (DNS over HTTPS — پورت 443) ────────────────────
  static Future<ProtocolResult> testDoH(
    String ip, {
    String? hostname,
    String path = '/dns-query',
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (hostname == null) {
      return ProtocolResult(supported: false, error: 'no_hostname');
    }
    try {
      final client = HttpClient()..badCertificateCallback = (_, __, ___) => false;
      client.connectionTimeout = timeout;

      final query  = buildDnsQuery('google.com');
      final uri    = Uri.parse('https://$hostname$path');

      final t0     = DateTime.now();
      final req    = await client.postUrl(uri);
      req.headers.set('Host', hostname);
      req.headers.set('Accept', 'application/dns-message');
      req.headers.set('Content-Type', 'application/dns-message');
      req.add(query);
      final resp   = await req.close().timeout(timeout);
      final elapsed = DateTime.now().difference(t0).inMicroseconds / 1000.0;
      await resp.drain();
      client.close();

      final ok = resp.statusCode == 200 || resp.statusCode == 400;
      return ProtocolResult(
        supported: ok,
        latencyMs: elapsed,
        error: ok ? null : 'http_${resp.statusCode}',
      );
    } on TimeoutException {
      return ProtocolResult(supported: false, error: 'timeout');
    } catch (e) {
      return ProtocolResult(supported: false, error: e.toString().substring(0, min(40, e.toString().length)));
    }
  }

  static String _base64UrlEncode(Uint8List data) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
    final result = StringBuffer();
    for (int i = 0; i < data.length; i += 3) {
      final b0 = data[i];
      final b1 = i + 1 < data.length ? data[i + 1] : 0;
      final b2 = i + 2 < data.length ? data[i + 2] : 0;
      result.write(chars[(b0 >> 2) & 0x3F]);
      result.write(chars[((b0 << 4) | (b1 >> 4)) & 0x3F]);
      if (i + 1 < data.length) result.write(chars[((b1 << 2) | (b2 >> 6)) & 0x3F]);
      if (i + 2 < data.length) result.write(chars[b2 & 0x3F]);
    }
    return result.toString();
  }

  // ── Game Server Test ─────────────────────────────────────────
  static const List<int> riotPorts = [443, 80, 5223, 5222, 2099];

  static Future<ScanResult> testGameServer(
    String ip, {
    int count = 4,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final latencies = <double>[];

    for (int i = 0; i < count; i++) {
      double? lat;
      for (final port in riotPorts) {
        lat = await tcpProbe(ip, port, timeout: timeout);
        if (lat != null) break;
      }
      if (lat != null) latencies.add(lat);
    }

    if (latencies.isEmpty) return ScanResult(lossPct: 100);

    final avg  = latencies.reduce((a, b) => a + b) / latencies.length;
    final loss = (count - latencies.length) / count * 100;
    double jitter = 0;
    if (latencies.length > 1) {
      jitter = sqrt(latencies.map((l) => pow(l - avg, 2)).reduce((a, b) => a + b) / latencies.length);
    }
    return ScanResult(latencyMs: avg, jitterMs: jitter, lossPct: loss);
  }

  // ── Full DNS Server Scan ─────────────────────────────────────
  static Future<void> scanDnsServer(
    DnsServer server, {
    void Function()? onUpdate,
    int count = 5,
  }) async {
    server.isScanning = true;
    onUpdate?.call();

    // DoU
    final dou = await testDnsUdp(server.ip, count: count);
    server.latencyMs  = dou.latencyMs;
    server.jitterMs   = dou.jitterMs;
    server.lossPct    = dou.lossPct;
    server.douSupported = dou.latencyMs != null;

    // DoT
    if (server.dotHostname != null) {
      final dot = await testDoT(server.ip, hostname: server.dotHostname);
      server.dotSupported  = dot.supported;
      server.dotLatency    = dot.latencyMs;
      server.dotTlsVersion = dot.tlsVersion;
    } else {
      server.dotSupported = false;
    }

    // DoH
    if (server.dotHostname != null && server.dohPath != null) {
      final doh = await testDoH(server.ip, hostname: server.dotHostname, path: server.dohPath!);
      server.dohSupported = doh.supported;
      server.dohLatency   = doh.latencyMs;
    } else {
      server.dohSupported = false;
    }

    // score
    final lat = server.latencyMs ?? 9999;
    final j   = server.jitterMs  ?? 0;
    final l   = server.lossPct   ?? 0;
    server.score = lat * 0.5 + j * 0.3 + (l / 100) * 200;
    server.isScanning = false;
    onUpdate?.call();
  }

  // ── Full Game Server Scan ────────────────────────────────────
  static Future<void> scanGameServer(
    GameServer server, {
    void Function()? onUpdate,
    int count = 4,
  }) async {
    server.isScanning = true;
    onUpdate?.call();

    final result = await testGameServer(server.ip, count: count);
    server.latencyMs = result.latencyMs;
    server.jitterMs  = result.jitterMs;
    server.lossPct   = result.lossPct;
    server.score     = server.gamingScore;
    server.isScanning = false;
    onUpdate?.call();
  }
}
