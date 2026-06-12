// lib/screens/dns_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/dns_server.dart';
import '../services/dns_scanner.dart';
import '../services/vpn_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

class DnsScreen extends StatefulWidget {
  const DnsScreen({super.key});
  @override
  State<DnsScreen> createState() => _DnsScreenState();
}

class _DnsScreenState extends State<DnsScreen> {
  List<DnsServer> _servers    = [];
  String  _filterCat          = 'all';
  String  _filterProto        = 'all';
  String  _search             = '';
  bool    _scanning           = false;
  int     _scanned            = 0;
  String? _activeDnsIp;
  DnsServer? _selectedPrimary;
  DnsServer? _selectedSecondary;

  final List<String> _cats   = ['all', 'iran', 'international', 'gaming', 'security', 'asia'];
  final List<String> _protos = ['all', 'DoT', 'DoH', 'DoU'];

  @override
  void initState() {
    super.initState();
    _servers = List.from(kDnsServers);
    _loadActive();
  }

  Future<void> _loadActive() async {
    final ip = await VpnDnsService.getSavedDnsIp();
    if (mounted) setState(() => _activeDnsIp = ip);
  }

  List<DnsServer> get _filtered {
    var list = _servers.where((s) {
      if (_filterCat != 'all' && s.category != _filterCat) return false;
      if (_filterProto != 'all') {
        if (_filterProto == 'DoT' && s.dotSupported != true) return false;
        if (_filterProto == 'DoH' && s.dohSupported != true) return false;
        if (_filterProto == 'DoU' && s.douSupported != true) return false;
      }
      if (_search.isNotEmpty &&
          !s.name.toLowerCase().contains(_search.toLowerCase()) &&
          !s.ip.contains(_search)) return false;
      return true;
    }).toList();

    // مرتب‌سازی بر اساس score
    list.sort((a, b) {
      if (a.latencyMs == null && b.latencyMs == null) return 0;
      if (a.latencyMs == null) return 1;
      if (b.latencyMs == null) return -1;
      return a.gamingScore.compareTo(b.gamingScore);
    });
    return list;
  }

  Future<void> _scanAll() async {
    setState(() { _scanning = true; _scanned = 0; });
    final futures = <Future>[];
    for (final s in _servers) {
      futures.add(DnsScanner.scanDnsServer(s, count: 4, onUpdate: () {
        if (mounted) setState(() => _scanned++);
      }));
    }
    await Future.wait(futures);
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _scanOne(DnsServer server) async {
    await DnsScanner.scanDnsServer(server, count: 5, onUpdate: () {
      if (mounted) setState(() {});
    });
  }

  Future<void> _activateDns(DnsServer primary) async {
    final ok = await VpnDnsService.start(primary, secondary: _selectedSecondary);
    if (!mounted) return;
    if (ok) {
      setState(() => _activeDnsIp = primary.ip);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ ${primary.name} فعال شد'),
        backgroundColor: AppTheme.green,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('❌ خطا در اتصال VPN'),
        backgroundColor: AppTheme.red,
      ));
    }
  }

  void _showAndroidConfig(DnsServer server) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AndroidConfigSheet(server: server),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('DNS سرورها'),
        actions: [
          if (_scanning)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(child: Text(
                '$_scanned/${_servers.length}',
                style: const TextStyle(color: AppTheme.accent, fontSize: 13),
              )),
            )
          else
            IconButton(
              icon: const Icon(Icons.play_arrow, color: AppTheme.accent),
              tooltip: 'اسکن همه',
              onPressed: _scanAll,
            ),
        ],
      ),
      body: Column(children: [
        // ── Progress Bar ─────────────────────────────────────
        if (_scanning)
          LinearProgressIndicator(
            value: _scanned / _servers.length,
            backgroundColor: AppTheme.border,
            color: AppTheme.accent,
            minHeight: 3,
          ),

        // ── Search ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            style: const TextStyle(color: AppTheme.textPrim),
            decoration: InputDecoration(
              hintText: 'جستجو نام یا IP...',
              hintStyle: const TextStyle(color: AppTheme.textSec),
              prefixIcon: const Icon(Icons.search, color: AppTheme.textSec),
              filled: true,
              fillColor: AppTheme.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),

        // ── Category Filter ──────────────────────────────────
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            itemCount: _cats.length,
            itemBuilder: (_, i) {
              final c = _cats[i];
              final selected = _filterCat == c;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(_catLabel(c)),
                  selected: selected,
                  onSelected: (_) => setState(() => _filterCat = c),
                ),
              );
            },
          ),
        ),

        // ── Protocol Filter ──────────────────────────────────
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            itemCount: _protos.length,
            itemBuilder: (_, i) {
              final p = _protos[i];
              final selected = _filterProto == p;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(p, style: const TextStyle(fontSize: 11)),
                  selected: selected,
                  onSelected: (_) => setState(() => _filterProto = p),
                  selectedColor: _protoColor(p).withOpacity(0.2),
                ),
              );
            },
          ),
        ),

        // ── Result Count ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(children: [
            Text('${filtered.length} سرور', style: const TextStyle(color: AppTheme.textSec, fontSize: 12)),
            const Spacer(),
            if (_selectedSecondary != null)
              Text('Secondary: ${_selectedSecondary!.ip}',
                style: const TextStyle(color: AppTheme.textSec, fontSize: 11)),
          ]),
        ),

        // ── List ─────────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('نتیجه‌ای یافت نشد', style: TextStyle(color: AppTheme.textSec)))
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final s = filtered[i];
                    final isActive = s.ip == _activeDnsIp;
                    return Dismissible(
                      key: Key(s.ip),
                      direction: DismissDirection.startToEnd,
                      background: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 20),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.phone_android, color: AppTheme.accent),
                      ),
                      confirmDismiss: (_) async {
                        _showAndroidConfig(s);
                        return false;
                      },
                      child: DnsCard(
                        server: s,
                        isActive: isActive,
                        onTap: () => _scanOne(s),
                        onActivate: () => _activateDns(s),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  String _catLabel(String c) => const {
    'all': 'همه', 'iran': '🇮🇷 ایران',
    'international': '🌍 بین‌المللی', 'gaming': '🎮 گیمینگ',
    'security': '🔒 امنیتی', 'asia': '🌏 آسیا',
  }[c] ?? c;

  Color _protoColor(String p) => const {
    'DoT': AppTheme.green, 'DoH': AppTheme.accent, 'DoU': AppTheme.yellow,
  }[p] ?? AppTheme.textSec;
}
