import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'services/daemon_service.dart';
import 'providers/scan_provider.dart';
import 'providers/config_provider.dart';
import 'pages/home_page.dart';
import 'pages/results_page.dart';
import 'pages/settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1100, 720),
    minimumSize: Size(700, 500),
    center: true,
    title: 'DevCleaner',
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  final daemon = DaemonService();
  // Start the daemon; if the exe is not found the error surfaces in ConfigProvider/ScanProvider UI.
  try {
    await daemon.start();
  } catch (_) {}

  runApp(DevCleanerApp(daemon: daemon));
}

class DevCleanerApp extends StatelessWidget {
  final DaemonService daemon;
  const DevCleanerApp({super.key, required this.daemon});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DaemonService>.value(value: daemon),
        ChangeNotifierProvider<ConfigProvider>(
          create: (_) => ConfigProvider(daemon),
        ),
        ChangeNotifierProvider<ScanProvider>(
          create: (_) => ScanProvider(daemon),
        ),
      ],
      child: MaterialApp(
        title: 'DevCleaner',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1565C0),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1565C0),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        home: const AppShell(),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends HomePageNavigatorState<AppShell> {
  int _index = 0;

  @override
  void switchToResults() {
    setState(() => _index = 1);
  }

  @override
  Widget build(BuildContext context) {
    const destinations = [
      NavigationRailDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: Text('Home'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.list_alt_outlined),
        selectedIcon: Icon(Icons.list_alt),
        label: Text('Results'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: Text('Settings'),
      ),
    ];

    final pages = [
      const HomePage(),
      const ResultsPage(),
      const SettingsPage(),
    ];

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            destinations: destinations,
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: pages[_index]),
        ],
      ),
    );
  }
}
