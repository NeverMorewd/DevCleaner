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
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DevCleaner',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Reclaim your disk space from dev caches and build artifacts',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
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
          if (scan.state == ScanState.scanning) ...[
            const SizedBox(height: 16),
            _buildScanProgress(context, scan),
          ],
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

    final scanners = [
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
        Text(
          'Enabled Scanners',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
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
                childAspectRatio: 2.4,
              ),
              itemCount: scanners.length,
              itemBuilder: (context, idx) {
                final (key, name, icon, subtitle) = scanners[idx];
                final enabled = scannerMap[key] ?? false;
                return Card(
                  elevation: enabled ? 2 : 0,
                  color: enabled
                      ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                      : theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.3),
                  child: InkWell(
                    onTap: () {
                      config.updateScanner(key, !enabled);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            icon,
                            size: 20,
                            color: enabled
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
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
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: enabled,
                            onChanged: (v) => config.updateScanner(key, v),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ),
                  ),
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

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: isScanning ? null : () => scan.startScan(),
            icon: isScanning
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.search),
            label: Text(isScanning ? 'Scanning...' : 'Start Scan'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: theme.textTheme.titleMedium,
            ),
          ),
        ),
        if (isScanning) ...[
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () => scan.abortScan(),
            icon: const Icon(Icons.stop),
            label: const Text('Abort'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildScanProgress(BuildContext context, ScanProvider scan) {
    final theme = Theme.of(context);
    final progress = scan.scannersTotal > 0
        ? scan.scannersDone / scan.scannersTotal
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Scanning...',
                  style: theme.textTheme.titleSmall,
                ),
                if (scan.scannersTotal > 0)
                  Text(
                    '${scan.scannersDone} / ${scan.scannersTotal}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress),
            if (scan.progress.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                scan.progress,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScanComplete(BuildContext context, ScanProvider scan) {
    final theme = Theme.of(context);

    String humanSize(int bytes) {
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      if (bytes < 1024 * 1024 * 1024) {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }

    return Card(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline,
                color: theme.colorScheme.primary, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scan complete!',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Found ${scan.totalCount} items '
                    '(${humanSize(scan.totalSize)}) that can be cleaned.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: () {
                // Navigate to results - done via NavigationRail in MainShell
                // We use a callback via navigating parent - use a notification
                _navigateToResults(context);
              },
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
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 32),
            const SizedBox(width: 16),
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
}

/// Abstract State base class that allows [AppShell] (or any ancestor)
/// to handle navigation from [HomePage] to the Results tab.
abstract class HomePageNavigatorState<T extends StatefulWidget>
    extends State<T> {
  void switchToResults();
}
