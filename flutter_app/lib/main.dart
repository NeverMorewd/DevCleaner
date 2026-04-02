import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'services/daemon_service.dart';
import 'providers/scan_provider.dart';
import 'providers/config_provider.dart';
import 'pages/home_page.dart';
import 'pages/results_page.dart';
import 'pages/settings_page.dart';
import 'widgets/app_title_bar.dart';
import 'widgets/scan_overlay.dart';

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
    titleBarStyle: TitleBarStyle.hidden,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  final daemon = DaemonService();
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
            seedColor: const Color(0xFF009688),
            brightness: Brightness.light,
          ).copyWith(
            surface: const Color(0xFFF4F7F9),
            surfaceContainer: const Color(0xFFECF0F4),
            surfaceContainerHighest: const Color(0xFFDDE4EC),
          ),
          useMaterial3: true,
          cardTheme: CardTheme(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFDDE4EC)),
            ),
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF009688),
            brightness: Brightness.dark,
          ).copyWith(
            surface: const Color(0xFF111920),
            surfaceContainer: const Color(0xFF192030),
            surfaceContainerHighest: const Color(0xFF223040),
          ),
          useMaterial3: true,
          cardTheme: CardTheme(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF2A3A50)),
            ),
          ),
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
  void switchToResults() => setState(() => _index = 1);

  @override
  Widget build(BuildContext context) {
    final scan = context.watch<ScanProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
      body: Column(
        children: [
          const AppTitleBar(),
          Expanded(
            child: Stack(
              children: [
                Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _index,
                      onDestinationSelected: (i) =>
                          setState(() => _index = i),
                      labelType: NavigationRailLabelType.all,
                      destinations: destinations,
                      backgroundColor: isDark
                          ? const Color(0xFF0F1923)
                          : theme.colorScheme.surfaceContainer,
                      indicatorColor:
                          theme.colorScheme.primary.withValues(alpha: 0.15),
                      selectedIconTheme: IconThemeData(
                        color: theme.colorScheme.primary,
                      ),
                      unselectedIconTheme: IconThemeData(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: theme.dividerColor.withValues(alpha: 0.5),
                    ),
                    Expanded(child: pages[_index]),
                  ],
                ),
                if (scan.state == ScanState.scanning)
                  ScanOverlay(scan: scan),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
