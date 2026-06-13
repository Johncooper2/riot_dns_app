// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/vpn_service.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool   _autoStart = false;
  String _customDns = '';
  final  _ctrl      = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auto = await VpnDnsService.getAutoStart();
    final ip   = await VpnDnsService.getSavedDnsIp();
    if (mounted) setState(() {
      _autoStart = auto;
      _customDns = ip ?? '';
      _ctrl.text = ip ?? '';
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('تنظیمات')),
      body: ListView(children: [

        // ── VPN ──────────────────────────────────────────────
        _sectionHeader('VPN'),
        _switchTile(
          icon: Icons.replay,
          title: 'شروع خودکار بعد از ری‌استارت',
          subtitle: 'VPN بعد از روشن شدن گوشی خودکار اجرا بشه',
          value: _autoStart,
          onChanged: (v) async {
            await VpnDnsService.setAutoStart(v);
            setState(() => _autoStart = v);
          },
        ),

        // ── DNS دستی ─────────────────────────────────────────
        _sectionHeader('DNS دستی'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              style: const TextStyle(color: AppTheme.textPrim, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: '1.1.1.1',
                hintStyle: const TextStyle(color: AppTheme.textSec),
                filled: true,
                fillColor: AppTheme.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                prefixIcon: const Icon(Icons.dns, color: AppTheme.textSec),
              ),
            )),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () async {
                final ip = _ctrl.text.trim();
                if (ip.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('آدرس IP رو وارد کن'),
                    backgroundColor: AppTheme.yellow,
                  ));
                  return;
                }
                final regex = RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$');
                if (!regex.hasMatch(ip)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('فرمت IP صحیح نیست'),
                    backgroundColor: AppTheme.red,
                  ));
                  return;
                }
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('dns1', ip);
                await prefs.setString('dns_name', 'Custom ($ip)');
                if (mounted) {
                  setState(() => _customDns = ip);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('DNS ذخیره شد'),
                    backgroundColor: AppTheme.green,
                  ));
                }
              },
              child: const Text('ذخیره'),
            ),
          ]),
        ),

        // ── راهنمای پروتکل‌ها ─────────────────────────────────
        _sectionHeader('پروتکل‌های DNS'),
        _protoInfoTile('🔒 DoT — DNS over TLS', 'پورت 853 — رمزنگاری TLS\nPrivate DNS اندروید ≥ 9\nبهترین انتخاب برای حریم خصوصی', AppTheme.green),
        _protoInfoTile('🌐 DoH — DNS over HTTPS', 'پورت 443 — رمزنگاری HTTPS\nنیاز به اپ مثل AdGuard یا Intra\nمخفی از ISP', AppTheme.accent),
        _protoInfoTile('📶 DoU — DNS over UDP', 'پورت 53 — بدون رمزنگاری\nسریع‌ترین ولی قابل شنود ISP\nتنظیم IP استاتیک Wi-Fi', AppTheme.yellow),

        // ── درباره ───────────────────────────────────────────
        _sectionHeader('درباره'),
        _infoTile('نسخه', '3.1.0'),
        _infoTile('اندروید مینیمم', '5.0 (API 21)'),
        _infoTile('روش DNS', 'VPN-based (بدون root)'),
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Text(title, style: const TextStyle(
      color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2,
    )),
  );

  Widget _switchTile({required IconData icon, required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) =>
    Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: SwitchListTile(
        secondary: Icon(icon, color: AppTheme.textSec),
        title: Text(title, style: const TextStyle(color: AppTheme.textPrim, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.textSec, fontSize: 11)),
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.accent,
      ),
    );

  Widget _protoInfoTile(String title, String desc, Color color) =>
    Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        Text(desc, style: const TextStyle(color: AppTheme.textSec, fontSize: 12, height: 1.5)),
      ]),
    );

  Widget _infoTile(String label, String value) =>
    Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Row(children: [
        Text(label, style: const TextStyle(color: AppTheme.textSec, fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(color: AppTheme.textPrim, fontSize: 13, fontFamily: 'monospace')),
      ]),
    );
}
