// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/vpn_service.dart';
import '../models/dns_server.dart';
import '../models/game_server.dart';
import '../theme.dart';
import '../widgets/common.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  bool   _vpnRunning    = false;
  bool   _loading       = false;
  String _activeDnsName = '—';
  String _activeDnsIp   = '—';
  String _activeProto   = '—';
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    Future.microtask(() => _loadState());
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    try {
      final running = await VpnDnsService.checkRunning()
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
      final name = await VpnDnsService.getSavedDnsName();
      final ip   = await VpnDnsService.getSavedDnsIp();
      if (mounted) setState(() {
        _vpnRunning    = running;
        _activeDnsName = name ?? '—';
        _activeDnsIp   = ip   ?? '—';
      });
    } catch (_) {
      if (mounted) setState(() {
        _vpnRunning    = false;
        _activeDnsName = '—';
        _activeDnsIp   = '—';
      });
    }
  }

  Future<void> _toggle() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      if (_vpnRunning) {
        await VpnDnsService.stop();
        if (mounted) setState(() {
          _vpnRunning    = false;
          _activeDnsName = '—';
          _activeDnsIp   = '—';
          _activeProto   = '—';
        });
      } else {
        final ip = await VpnDnsService.getSavedDnsIp();
        if (ip == null) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('ابتدا از تب DNS یه سرور انتخاب کن'),
            backgroundColor: AppTheme.yellow,
          ));
        } else {
          final server = kDnsServers.firstWhere(
            (s) => s.ip == ip,
            orElse: () => DnsServer(name: 'Custom', ip: ip, category: 'custom'),
          );
          final ok = await VpnDnsService.start(server)
              .timeout(const Duration(seconds: 10), onTimeout: () => false);
          if (mounted) {
            if (ok) {
              setState(() {
                _vpnRunning    = true;
                _activeDnsName = server.name;
                _activeDnsIp   = server.ip;
                _activeProto   = server.bestProtocolForAndroid;
              });
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('خطا در اتصال VPN'),
                backgroundColor: AppTheme.red,
              ));
            }
          }
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('خطا: $e'),
        backgroundColor: AppTheme.red,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Riot DNS Changer'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: AppTheme.textSec),
            onPressed: _showInfo,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(children: [
          const SizedBox(height: 32),
          _buildPowerButton(),
          const SizedBox(height: 32),
          _buildStatusCard(),
          const SizedBox(height: 24),
          if (_vpnRunning) _buildProtocolCard(),
          const SizedBox(height: 24),
          _buildQuickStats(),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Widget _buildPowerButton() {
    final color = _vpnRunning ? AppTheme.green : AppTheme.textSec;
    return Center(
      child: GestureDetector(
        onTap: _toggle,
        child: Stack(alignment: Alignment.center, children: [
          if (_vpnRunning)
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => Container(
                width:  160 + _pulseCtrl.value * 20,
                height: 160 + _pulseCtrl.value * 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.green.withOpacity(0.3 - _pulseCtrl.value * 0.28),
                    width: 2,
                  ),
                ),
              ),
            ),
          Container(
            width: 140, height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.card,
              border: Border.all(color: color, width: 3),
              boxShadow: [BoxShadow(
                color: color.withOpacity(_vpnRunning ? 0.4 : 0.1),
                blurRadius: 30, spreadRadius: 5,
              )],
            ),
            child: _loading
                ? const CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 3)
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.power_settings_new, size: 52, color: color),
                    const SizedBox(height: 6),
                    Text(
                      _vpnRunning ? 'فعال' : 'غیرفعال',
                      style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ]),
          ),
        ]),
      ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _vpnRunning ? AppTheme.green.withOpacity(0.4) : AppTheme.border,
        ),
      ),
      child: Column(children: [
        _statusRow('وضعیت', _vpnRunning ? '🟢 متصل' : '🔴 قطع',
            _vpnRunning ? AppTheme.green : AppTheme.red),
        const Divider(color: AppTheme.border, height: 20),
        _statusRow('DNS سرور', _activeDnsName, AppTheme.textPrim),
        const SizedBox(height: 8),
        _statusRow('آدرس IP', _activeDnsIp, AppTheme.accent),
        if (_activeProto != '—') ...[
          const SizedBox(height: 8),
          _statusRow('پروتکل', _activeProto, AppTheme.yellow),
        ],
      ]),
    );
  }

  Widget _statusRow(String label, String value, Color valueColor) => Row(
    children: [
      Text(label, style: const TextStyle(color: AppTheme.textSec, fontSize: 13)),
      const Spacer(),
      Text(value, style: TextStyle(
        color: valueColor, fontSize: 13, fontWeight: FontWeight.w600,
      )),
    ],
  );

  Widget _buildProtocolCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.green.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.security, color: AppTheme.green, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('VPN فعال است',
              style: TextStyle(color: AppTheme.green, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            'DNS از طریق $_activeDnsIp هدایت می‌شه',
            style: const TextStyle(color: AppTheme.textSec, fontSize: 11),
          ),
        ])),
      ]),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildQuickStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        _statBox('🎮', 'سرور بازی', '${kGameServers.length}', AppTheme.gold),
        const SizedBox(width: 12),
        _statBox('🌐', 'DNS سرور', '${kDnsServers.length}', AppTheme.accent),
        const SizedBox(width: 12),
        _statBox('🔒', 'DoT دارن',
            '${kDnsServers.where((s) => s.dotHostname != null).length}', AppTheme.green),
      ]),
    );
  }

  Widget _statBox(String icon, String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(
          color: color, fontSize: 18, fontWeight: FontWeight.w800,
        )),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: AppTheme.textSec, fontSize: 10),
            textAlign: TextAlign.center),
      ]),
    ),
  );

  void _showInfo() => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Riot DNS Changer v3.1',
          style: TextStyle(color: AppTheme.textPrim)),
      content: const Text(
        'DNS Changer بدون نیاز به root\n\n'
        '• VPN-based — اندروید ≥ 5\n'
        '• پشتیبانی از DoT / DoH / DoU\n'
        '• تست latency سرورهای Riot\n'
        '• راهنمای Private DNS اندروید',
        style: TextStyle(color: AppTheme.textSec, height: 1.6),
      ),
      actions: [TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('بستن'),
      )],
    ),
  );
}
