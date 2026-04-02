import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'services/daemon_service.dart';
import 'providers/scan_provider.dart';
import 'providers/config_provider.dart';
import 'pages/scan_page.dart';
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
            surfaceContainer: const Color(0xFFECF1F5),
            surfaceContainerHighest: const Color(0xFFDFE8EF),
          ),
          useMaterial3: true,
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
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
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
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

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final scan = context.watch<ScanProvider>();

    return Scaffold(
      body: Column(
        children: [
          const AppTitleBar(),
          Expanded(
            child: Stack(
              children: [
                const ScanPage(),
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
