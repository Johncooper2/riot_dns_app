import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'screens/dns_screen.dart';
import 'screens/game_screen.dart';
import 'screens/settings_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF111827),
  ));
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const RiotDnsApp());
}

class RiotDnsApp extends StatelessWidget {
  const RiotDnsApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Riot DNS',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark,
    home: const MainShell(),
  );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _idx = 0;

  final _pages = const [
    HomeScreen(),
    DnsScreen(),
    GameScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: _idx, children: _pages),
    bottomNavigationBar: BottomNavigationBar(
      currentIndex: _idx,
      onTap: (i) => setState(() => _idx = i),
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.shield),          label: 'خانه'),
        BottomNavigationBarItem(icon: Icon(Icons.dns),             label: 'DNS'),
        BottomNavigationBarItem(icon: Icon(Icons.sports_esports),  label: 'بازی'),
        BottomNavigationBarItem(icon: Icon(Icons.settings),        label: 'تنظیمات'),
      ],
    ),
  );
}
