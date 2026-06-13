// lib/services/vpn_service.dart
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dns_server.dart';

class VpnDnsService {
  static const _channel = MethodChannel('com.riotdns/vpn');

  static bool _isRunning = false;
  static DnsServer? _activeDns;

  static bool    get isRunning  => _isRunning;
  static DnsServer? get activeDns => _activeDns;

  /// شروع VPN DNS changer
  static Future<bool> start(DnsServer primary, {DnsServer? secondary}) async {
    try {
      final result = await _channel.invokeMethod<bool>('startVpn', {
        'dns1':         primary.ip,
        'dns2':         secondary?.ip ?? '',
        'protocol':     primary.bestProtocolForAndroid,
        'dot_hostname': primary.dotHostname ?? '',
      });
      if (result == true) {
        _isRunning = true;
        _activeDns = primary;
        await _savePrefs(primary, secondary);
      }
      return result ?? false;
    } on PlatformException catch (e) {
      print('VPN start error: ${e.message}');
      return false;
    }
  }

  /// توقف VPN
  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopVpn');
      _isRunning = false;
      _activeDns = null;
    } on PlatformException catch (e) {
      print('VPN stop error: ${e.message}');
    }
  }

  /// وضعیت VPN
  static Future<bool> checkRunning() async {
    try {
      final r = await _channel.invokeMethod<bool>('isVpnRunning');
      _isRunning = r ?? false;
      return _isRunning;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _savePrefs(DnsServer primary, DnsServer? secondary) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dns1',      primary.ip);
    await prefs.setString('dns2',      secondary?.ip ?? '');
    await prefs.setString('protocol',  primary.bestProtocolForAndroid);
    await prefs.setString('dot_host',  primary.dotHostname ?? '');
    await prefs.setString('dns_name',  primary.name);
  }

  static Future<String?> getSavedDnsIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('dns1');
  }

  static Future<String?> getSavedDnsName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('dns_name');
  }

  static Future<String?> getSavedProtocol() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('protocol');
  }

  static Future<bool> getAutoStart() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('auto_start') ?? false;
  }

  static Future<void> setAutoStart(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_start', v);
  }
}
