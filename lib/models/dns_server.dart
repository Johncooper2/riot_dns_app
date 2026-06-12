// lib/models/dns_server.dart

class DnsProtocol {
  static const String dou = 'DoU';
  static const String dot = 'DoT';
  static const String doh = 'DoH';
}

class DnsServer {
  final String name;
  final String ip;
  final String category;
  final String? dotHostname;
  final String? dohPath;

  // نتایج اسکن
  double? latencyMs;
  double? jitterMs;
  double? lossPct;
  double? score;
  bool?   dotSupported;
  bool?   dohSupported;
  bool?   douSupported;
  double? dotLatency;
  double? dohLatency;
  String? dotTlsVersion;
  String? bestProtocol;
  bool    isScanning = false;

  DnsServer({
    required this.name,
    required this.ip,
    required this.category,
    this.dotHostname,
    this.dohPath,
  });

  String get bestProtocolForAndroid {
    if (dotSupported == true) return DnsProtocol.dot;
    if (dohSupported == true) return DnsProtocol.doh;
    if (douSupported == true) return DnsProtocol.dou;
    return 'N/A';
  }

  String get androidSettingValue {
    switch (bestProtocolForAndroid) {
      case DnsProtocol.dot:
        return dotHostname ?? ip;
      case DnsProtocol.doh:
        return 'https://${dotHostname ?? ip}${dohPath ?? '/dns-query'}';
      case DnsProtocol.dou:
        return ip;
      default:
        return ip;
    }
  }

  String get androidInstruction {
    switch (bestProtocolForAndroid) {
      case DnsProtocol.dot:
        return 'Settings → Connections → More → Private DNS\n→ "Private DNS provider hostname"\n→ بزن: ${dotHostname ?? ip}';
      case DnsProtocol.doh:
        return 'نیاز به اپ: AdGuard یا Intra\n→ DoH URL: https://${dotHostname ?? ip}${dohPath ?? '/dns-query'}';
      case DnsProtocol.dou:
        return 'Settings → Wi-Fi → اتصال فعلی\n→ IP Settings: Static\n→ DNS 1: $ip';
      default:
        return 'قابل استفاده نیست';
    }
  }

  double get gamingScore {
    if (score != null) return score!;
    final lat = latencyMs ?? 9999;
    final j   = jitterMs  ?? 0;
    final l   = lossPct   ?? 0;
    return lat * 0.5 + j * 0.3 + (l / 100) * 200;
  }

  Map<String, dynamic> toJson() => {
    'name': name, 'ip': ip, 'category': category,
    'latency': latencyMs, 'jitter': jitterMs, 'loss': lossPct,
    'dot': dotSupported, 'doh': dohSupported, 'dou': douSupported,
    'best_protocol': bestProtocolForAndroid,
  };
}

// ──────────────────────────────────────────────────────────────
//  لیست DNS سرورها
// ──────────────────────────────────────────────────────────────
final List<DnsServer> kDnsServers = [
  // International
  DnsServer(name: 'Cloudflare 1.1.1.1',       ip: '1.1.1.1',         category: 'international', dotHostname: 'one.one.one.one',              dohPath: '/dns-query'),
  DnsServer(name: 'Cloudflare 1.0.0.1',       ip: '1.0.0.1',         category: 'international', dotHostname: 'one.one.one.one',              dohPath: '/dns-query'),
  DnsServer(name: 'Google 8.8.8.8',           ip: '8.8.8.8',         category: 'international', dotHostname: 'dns.google',                   dohPath: '/dns-query'),
  DnsServer(name: 'Google 8.8.4.4',           ip: '8.8.4.4',         category: 'international', dotHostname: 'dns.google',                   dohPath: '/dns-query'),
  DnsServer(name: 'Quad9',                    ip: '9.9.9.9',          category: 'international', dotHostname: 'dns.quad9.net',                dohPath: '/dns-query'),
  DnsServer(name: 'Quad9 Secondary',          ip: '149.112.112.112',  category: 'international', dotHostname: 'dns.quad9.net',                dohPath: '/dns-query'),
  DnsServer(name: 'OpenDNS Primary',          ip: '208.67.222.222',   category: 'international', dotHostname: 'dns.opendns.com'),
  DnsServer(name: 'OpenDNS Secondary',        ip: '208.67.220.220',   category: 'international', dotHostname: 'dns.opendns.com'),
  // Gaming
  DnsServer(name: 'NextDNS #1',               ip: '45.90.28.0',       category: 'gaming',        dotHostname: 'dns.nextdns.io',               dohPath: '/dns-query'),
  DnsServer(name: 'NextDNS #2',               ip: '45.90.30.0',       category: 'gaming',        dotHostname: 'dns.nextdns.io',               dohPath: '/dns-query'),
  DnsServer(name: 'ControlD #1',              ip: '76.76.2.0',        category: 'gaming',        dotHostname: 'freedns.controld.com',         dohPath: '/dns-query'),
  DnsServer(name: 'ControlD #2',              ip: '76.76.10.0',       category: 'gaming',        dotHostname: 'freedns.controld.com',         dohPath: '/dns-query'),
  DnsServer(name: 'AdGuard Primary',          ip: '94.140.14.14',     category: 'gaming',        dotHostname: 'dns.adguard-dns.com',          dohPath: '/dns-query'),
  DnsServer(name: 'AdGuard Secondary',        ip: '94.140.15.15',     category: 'gaming',        dotHostname: 'dns.adguard-dns.com',          dohPath: '/dns-query'),
  DnsServer(name: 'DNS.SB',                   ip: '185.222.222.222',  category: 'gaming',        dotHostname: 'dot.sb',                       dohPath: '/dns-query'),
  DnsServer(name: 'CF Gaming 1.1.1.3',        ip: '1.1.1.3',          category: 'gaming',        dotHostname: 'one.one.one.one',              dohPath: '/dns-query'),
  // Iran
  DnsServer(name: 'Shecan #1',                ip: '178.22.122.100',   category: 'iran'),
  DnsServer(name: 'Shecan #2',                ip: '185.51.200.2',     category: 'iran'),
  DnsServer(name: 'Electro #1',               ip: '78.157.42.100',    category: 'iran'),
  DnsServer(name: 'Electro #2',               ip: '78.157.42.101',    category: 'iran'),
  DnsServer(name: 'Pishgaman #1',             ip: '5.202.100.100',    category: 'iran'),
  DnsServer(name: 'Pishgaman #2',             ip: '5.202.100.101',    category: 'iran'),
  DnsServer(name: 'Asiatech',                 ip: '194.225.0.252',    category: 'iran'),
  DnsServer(name: 'Irancell',                 ip: '5.200.200.200',    category: 'iran'),
  DnsServer(name: 'MCI #1',                   ip: '217.218.127.127',  category: 'iran'),
  DnsServer(name: 'MCI #2',                   ip: '217.218.155.155',  category: 'iran'),
  DnsServer(name: 'Shatel',                   ip: '85.15.1.14',       category: 'iran'),
  DnsServer(name: 'Respina',                  ip: '185.120.30.30',    category: 'iran'),
  // Security
  DnsServer(name: 'Yandex Basic',             ip: '77.88.8.8',        category: 'security',      dotHostname: 'common.dot.dns.yandex.net'),
  DnsServer(name: 'CleanBrowsing #1',         ip: '185.228.168.168',  category: 'security',      dotHostname: 'security-filter-dns.cleanbrowsing.org', dohPath: '/doh/security-filter/'),
  DnsServer(name: 'CleanBrowsing #2',         ip: '185.228.169.168',  category: 'security',      dotHostname: 'security-filter-dns.cleanbrowsing.org', dohPath: '/doh/security-filter/'),
  DnsServer(name: 'Cisco Umbrella',           ip: '208.67.222.123',   category: 'security',      dohPath: '/dns-query'),
  // Asia/ME
  DnsServer(name: 'Alibaba #1',               ip: '223.5.5.5',        category: 'asia',          dotHostname: 'dns.alidns.com',               dohPath: '/dns-query'),
  DnsServer(name: 'Alibaba #2',               ip: '223.6.6.6',        category: 'asia',          dotHostname: 'dns.alidns.com',               dohPath: '/dns-query'),
  DnsServer(name: '114DNS',                   ip: '114.114.114.114',  category: 'asia'),
  DnsServer(name: 'Etisalat (UAE)',           ip: '213.42.20.20',     category: 'asia'),
  DnsServer(name: 'STC (Saudi)',              ip: '212.48.68.150',    category: 'asia'),
  DnsServer(name: 'Nawras (Oman)',            ip: '195.229.241.222',  category: 'asia'),
];
