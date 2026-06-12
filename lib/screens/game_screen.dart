// lib/screens/game_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/game_server.dart';
import '../services/dns_scanner.dart';
import '../theme.dart';
import '../widgets/common.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<GameServer> _servers = [];
  bool _scanning = false;
  int  _scanned  = 0;

  @override
  void initState() {
    super.initState();
    _tab     = TabController(length: 2, vsync: this);
    _servers = List.from(kGameServers);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _scanAll() async {
    setState(() { _scanning = true; _scanned = 0; });
    final futures = _servers.map((s) =>
      DnsScanner.scanGameServer(s, count: 4, onUpdate: () {
        if (mounted) setState(() => _scanned++);
      })
    ).toList();
    await Future.wait(futures);
    if (mounted) setState(() => _scanning = false);
  }

  List<GameServer> _byGame(String game) {
    final list = _servers.where((s) => s.game == game).toList();
    list.sort((a, b) {
      if (a.latencyMs == null) return 1;
      if (b.latencyMs == null) return -1;
      return a.gamingScore.compareTo(b.gamingScore);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('سرورهای بازی'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textSec,
          tabs: const [
            Tab(text: '🟡  League of Legends'),
            Tab(text: '🔵  Wild Rift'),
          ],
        ),
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
              icon: const Icon(Icons.speed, color: AppTheme.gold),
              tooltip: 'تست همه سرورها',
              onPressed: _scanAll,
            ),
        ],
      ),
      body: Column(children: [
        if (_scanning)
          LinearProgressIndicator(
            value: _scanned / _servers.length,
            backgroundColor: AppTheme.border,
            color: AppTheme.gold,
            minHeight: 3,
          ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildServerList(_byGame('lol'),      AppTheme.gold),
              _buildServerList(_byGame('wildrift'), AppTheme.purple),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildServerList(List<GameServer> servers, Color color) {
    if (servers.isEmpty) return const Center(child: CircularProgressIndicator());

    final scanned = servers.where((s) => s.latencyMs != null).toList();
    return ListView(children: [
      // ── Mini latency chart ──────────────────────────────────
      if (scanned.length >= 3)
        _buildChart(scanned, color),

      // ── Best server highlight ───────────────────────────────
      if (scanned.isNotEmpty)
        _buildBestCard(scanned.first, color),

      // ── All servers ─────────────────────────────────────────
      ...servers.asMap().entries.map((e) => _buildServerTile(e.value, e.key + 1, color)),
      const SizedBox(height: 20),
    ]);
  }

  Widget _buildChart(List<GameServer> servers, Color color) {
    final top = servers.take(8).toList();
    return Container(
      height: 130,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: BarChart(BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (top.map((s) => s.latencyMs ?? 0).reduce((a, b) => a > b ? a : b) * 1.3),
        barGroups: top.asMap().entries.map((e) => BarChartGroupData(
          x: e.key,
          barRods: [BarChartRodData(
            toY: e.value.latencyMs ?? 0,
            color: AppTheme.latencyColor(e.value.latencyMs),
            width: 16,
            borderRadius: BorderRadius.circular(4),
          )],
        )).toList(),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, _) => Text(
              top[v.toInt()].region,
              style: const TextStyle(color: AppTheme.textSec, fontSize: 9),
            ),
          )),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
      )),
    );
  }

  Widget _buildBestCard(GameServer best, Color color) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withOpacity(0.15), AppTheme.card], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(children: [
        const Text('🥇', style: TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('بهترین سرور', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          Text(best.name, style: const TextStyle(color: AppTheme.textPrim, fontSize: 15, fontWeight: FontWeight.w700)),
          Text(best.ip, style: const TextStyle(color: AppTheme.textSec, fontSize: 12, fontFamily: 'monospace')),
        ])),
        LatencyBadge(ms: best.latencyMs, fontSize: 15),
      ]),
    );
  }

  Widget _buildServerTile(GameServer s, int rank, Color color) {
    final rankEmoji = rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '  $rank';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        Text(rankEmoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.name, style: const TextStyle(color: AppTheme.textPrim, fontSize: 13, fontWeight: FontWeight.w600)),
          Row(children: [
            Text(s.ip, style: const TextStyle(color: AppTheme.textSec, fontSize: 11, fontFamily: 'monospace')),
            if (s.jitterMs != null) ...[
              const SizedBox(width: 8),
              Text('jitter: ${s.jitterMs!.toStringAsFixed(0)}ms',
                style: const TextStyle(color: AppTheme.textSec, fontSize: 10)),
            ],
            if (s.lossPct != null && s.lossPct! > 0) ...[
              const SizedBox(width: 8),
              Text('loss: ${s.lossPct!.toStringAsFixed(0)}%',
                style: const TextStyle(color: AppTheme.red, fontSize: 10)),
            ],
          ]),
        ])),
        s.isScanning
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent))
            : LatencyBadge(ms: s.latencyMs),
      ]),
    );
  }
}
