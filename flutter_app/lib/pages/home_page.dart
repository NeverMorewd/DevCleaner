import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/scan_provider.dart';
import '../providers/config_provider.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ScanProvider, ConfigProvider>(
      builder: (context, scan, config, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            Expanded(
              child: config.loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildBody(context, scan, config),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF14202E)
            : theme.colorScheme.surfaceContainer,
        border: Border(
          bottom: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DevCleaner',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Reclaim disk space from dev caches and build artifacts',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, ScanProvider scan, ConfigProvider config) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildScannerGrid(context, config),
          const SizedBox(height: 24),
          _buildScanButton(context, scan),
          if (scan.state == ScanState.done) ...[
            const SizedBox(height: 16),
            _buildScanComplete(context, scan),
          ],
          if (scan.state == ScanState.error && scan.error != null) ...[
            const SizedBox(height: 16),
            _buildScanError(context, scan.error!),
          ],
        ],
      ),
    );
  }

  Widget _buildScannerGrid(BuildContext context, ConfigProvider config) {
    final theme = Theme.of(context);
    final scannerMap = config.scanners;

    const scanners = [
      ('nuget', 'NuGet', Icons.code, '.NET packages'),
      ('cargo', 'Cargo', Icons.memory, 'Rust packages'),
      ('golang', 'Go Modules', Icons.storage, 'Go packages'),
      ('node', 'Node.js', Icons.javascript, 'npm/yarn/pnpm'),
      ('pip', 'pip / uv', Icons.terminal, 'Python packages'),
      ('maven', 'Maven', Icons.coffee, 'Java packages'),
      ('gradle', 'Gradle', Icons.build, 'Java builds'),
      ('build_artifacts', 'Build Artifacts', Icons.folder_delete, 'obj/bin/target'),
      ('env_vars', 'Env Vars', Icons.settings_system_daydream, 'Invalid entries'),
      ('dump_files', 'Dump Files', Icons.bug_report, 'Crash reports'),
      ('android_sdk', 'Android SDK', Icons.android, 'Old SDK versions'),
      ('ide_cache', 'IDE Caches', Icons.computer, 'VS Code/JetBrains'),
      ('windows_temp', 'Windows Temp', Icons.cleaning_services, 'Temp files'),
      ('rustup', 'Rustup', Icons.memory_outlined, 'Old toolchains'),
      ('browser_cache', 'Browser Cache', Icons.language, 'Chrome/Edge/Firefox'),
      ('flutter_pub', 'Flutter/Dart Pub', Icons.flutter_dash, 'Pub cache'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Scanners',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${scannerMap.values.where((v) => v).length}/${scanners.length}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 900
                ? 4
                : constraints.maxWidth > 600
                    ? 3
                    : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.6,
              ),
              itemCount: scanners.length,
              itemBuilder: (context, idx) {
                final (key, name, icon, subtitle) = scanners[idx];
                final enabled = scannerMap[key] ?? false;
                return _ScannerCard(
                  key: ValueKey(key),
                  name: name,
                  icon: icon,
                  subtitle: subtitle,
                  enabled: enabled,
                  onToggle: (v) => config.updateScanner(key, v),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildScanButton(BuildContext context, ScanProvider scan) {
    final theme = Theme.of(context);
    final isScanning = scan.state == ScanState.scanning;

    return FilledButton.icon(
      onPressed: isScanning ? null : () => scan.startScan(),
      icon: const Icon(Icons.search, size: 20),
      label: Text(isScanning ? 'Scanning…' : 'Start Scan'),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        textStyle: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildScanComplete(BuildContext context, ScanProvider scan) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline,
                color: theme.colorScheme.primary, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scan complete',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${scan.totalCount} items found  •  ${_humanSize(scan.totalSize)} can be freed',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: () => _navigateToResults(context),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('View Results'),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToResults(BuildContext context) {
    final state = context.findAncestorStateOfType<HomePageNavigatorState>();
    state?.switchToResults();
  }

  Widget _buildScanError(BuildContext context, String error) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scan failed',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(error, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _humanSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

// ── Scanner card widget ────────────────────────────────────────────────────────

class _ScannerCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final String subtitle;
  final bool enabled;
  final ValueChanged<bool> onToggle;

  const _ScannerCard({
    super.key,
    required this.name,
    required this.icon,
    required this.subtitle,
    required this.enabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final activeBg = isDark
        ? theme.colorScheme.primary.withValues(alpha: 0.18)
        : theme.colorScheme.primaryContainer.withValues(alpha: 0.45);
    final inactiveBg = isDark
        ? theme.colorScheme.surface
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: enabled ? activeBg : inactiveBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: enabled
              ? theme.colorScheme.primary.withValues(alpha: 0.35)
              : theme.dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: () => onToggle(!enabled),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: enabled
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: enabled
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.7),
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: enabled,
                  onChanged: onToggle,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Abstract State base class that allows [AppShell] to navigate to Results.
abstract class HomePageNavigatorState<T extends StatefulWidget>
    extends State<T> {
  void switchToResults();
}
