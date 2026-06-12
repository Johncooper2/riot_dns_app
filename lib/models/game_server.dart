// lib/models/game_server.dart

class GameServer {
  final String name;
  final String ip;
  final String game;    // 'lol' | 'wildrift'
  final String region;

  double? latencyMs;
  double? jitterMs;
  double? lossPct;
  double? score;
  bool    isScanning = false;
  List<int> openPorts = [];

  GameServer({
    required this.name,
    required this.ip,
    required this.game,
    required this.region,
  });

  String get gameLabel => game == 'lol' ? 'League of Legends' : 'Wild Rift';

  double get gamingScore {
    if (score != null) return score!;
    final lat = latencyMs ?? 9999;
    final j   = jitterMs  ?? 0;
    final l   = lossPct   ?? 0;
    return lat * 0.5 + j * 0.3 + (l / 100) * 200;
  }

  String get latencyLabel {
    if (latencyMs == null) return '—';
    return '${latencyMs!.toStringAsFixed(0)} ms';
  }

  String get statusEmoji {
    if (latencyMs == null) return '❌';
    if (latencyMs! < 50)  return '🟢';
    if (latencyMs! < 100) return '🟡';
    return '🔴';
  }
}

final List<GameServer> kGameServers = [
  // League of Legends
  GameServer(name: 'LoL NA  (Oregon/Virginia)',  ip: '104.160.131.3',  game: 'lol',      region: 'NA'),
  GameServer(name: 'LoL EUW (Amsterdam)',         ip: '104.160.141.3',  game: 'lol',      region: 'EUW'),
  GameServer(name: 'LoL EUNE (Frankfurt)',        ip: '104.160.142.3',  game: 'lol',      region: 'EUNE'),
  GameServer(name: 'LoL KR  (Seoul)',             ip: '104.160.166.3',  game: 'lol',      region: 'KR'),
  GameServer(name: 'LoL TR  (Istanbul)',          ip: '104.160.154.3',  game: 'lol',      region: 'TR'),
  GameServer(name: 'LoL ME  (Bahrain/Dubai)',     ip: '104.160.170.3',  game: 'lol',      region: 'ME'),
  GameServer(name: 'LoL SEA (Singapore)',         ip: '104.160.162.3',  game: 'lol',      region: 'SEA'),
  GameServer(name: 'LoL JP  (Tokyo)',             ip: '104.160.157.3',  game: 'lol',      region: 'JP'),
  GameServer(name: 'LoL OCE (Sydney)',            ip: '104.160.156.1',  game: 'lol',      region: 'OCE'),
  // Wild Rift
  GameServer(name: 'WR MENA (Bahrain)',           ip: '15.185.0.1',     game: 'wildrift', region: 'MENA'),
  GameServer(name: 'WR EU  (Frankfurt)',          ip: '13.53.131.0',    game: 'wildrift', region: 'EU'),
  GameServer(name: 'WR SEA (Singapore)',          ip: '54.169.0.1',     game: 'wildrift', region: 'SEA'),
  GameServer(name: 'WR NA  (N.Virginia)',         ip: '52.15.154.0',    game: 'wildrift', region: 'NA'),
  GameServer(name: 'WR JP  (Tokyo)',              ip: '13.230.0.1',     game: 'wildrift', region: 'JP'),
  GameServer(name: 'WR KR  (Seoul)',              ip: '13.124.0.1',     game: 'wildrift', region: 'KR'),
  GameServer(name: 'WR OCE (Sydney)',             ip: '13.54.0.1',      game: 'wildrift', region: 'OCE'),
  GameServer(name: 'WR BR  (São Paulo)',          ip: '18.231.0.1',     game: 'wildrift', region: 'BR'),
];
