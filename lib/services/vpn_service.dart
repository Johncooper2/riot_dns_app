// lib/services/vpn_service.dart
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dns_server.dart';

class VpnDnsService {
  static const _channel = MethodChannel('com.riotdns/vpn');

  static bool       _isRunning = false;
  static DnsServer? _activeDns;

  static bool       get isRunning  => _isRunning;
  static DnsServer? get activeDns  => _activeDns;

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
    } catch (e) {
      return false;
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopVpn');
    } catch (_) {}
    _isRunning = false;
    _activeDns = null;
  }

  static Future<bool> checkRunning() async {
    try {
      final r = await _channel.invokeMethod<bool>('isVpnRunning')
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
      _isRunning = r ?? false;
      return _isRunning;
    } catch (_) {
      _isRunning = false;
      return false;
    }
  }

  static Future<void> _savePrefs(DnsServer primary, DnsServer? secondary) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dns1',     primary.ip);
      await prefs.setString('dns2',     secondary?.ip ?? '');
      await prefs.setString('protocol', primary.bestProtocolForAndroid);
      await prefs.setString('dot_host', primary.dotHostname ?? '');
      await prefs.setString('dns_name', primary.name);
    } catch (_) {}
  }

  static Future<String?> getSavedDnsIp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('dns1');
    } catch (_) { return null; }
  }

  static Future<String?> getSavedDnsName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('dns_name');
    } catch (_) { return null; }
  }

  static Future<bool> getAutoStart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('auto_start') ?? false;
    } catch (_) { return false; }
  }

  static Future<void> setAutoStart(bool v) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_start', v);
    } catch (_) {}
  }
}
