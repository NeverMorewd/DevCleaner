import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/rpc_types.dart';
import '../providers/config_provider.dart';
import '../providers/scan_provider.dart';

typedef _Def = ({
  String key,
  String name,
  String sub,
  IconData icon,
  Color color
});

// Simple scanners in compact 2-col grid (no expandable children).
// nuget, build_artifacts, env_vars, windows_temp are handled as expandable rows.
const List<_Def> _kSimpleScanners = [
  (key: 'cargo',         name: 'Cargo',         sub: 'Rust',           icon: Icons.memory,                   color: Color(0xFFCE422B)),
  (key: 'rustup',        name: 'Rustup',        sub: 'Old toolchains', icon: Icons.system_update_alt,        color: Color(0xFFBF360C)),
  (key: 'golang',        name: 'Go Modules',    sub: 'Go',             icon: Icons.cloud_queue,              color: Color(0xFF00ADD8)),
  (key: 'node',          name: 'Node.js',       sub: 'npm / yarn',     icon: Icons.hub,                      color: Color(0xFF339933)),
  (key: 'pip',           name: 'pip / uv',      sub: 'Python',         icon: Icons.code,                     color: Color(0xFF3776AB)),
  (key: 'maven',         name: 'Maven',         sub: 'Java',           icon: Icons.inventory_2_outlined,     color: Color(0xFFC71A36)),
  (key: 'gradle',        name: 'Gradle',        sub: 'Java / Android', icon: Icons.construction,             color: Color(0xFF1BA9AC)),
  (key: 'cpp_vcpkg',     name: 'vcpkg',         sub: 'C++',            icon: Icons.build_circle_outlined,    color: Color(0xFF6E4C13)),
  (key: 'cpp_conan',     name: 'Conan',         sub: 'C++',            icon: Icons.settings_input_component, color: Color(0xFF1F9FD5)),
  (key: 'android_sdk',   name: 'Android SDK',   sub: 'Old SDKs',       icon: Icons.android,                  color: Color(0xFF3DDC84)),
  (key: 'ide_cache',     name: 'IDE Caches',    sub: 'JetBrains / VS', icon: Icons.developer_mode,           color: Color(0xFFE91E8C)),
  (key: 'browser_cache', name: 'Browser Cache', sub: 'Chrome / Edge',  icon: Icons.public,                   color: Color(0xFF1A73E8)),
  (key: 'dump_files',    name: 'Dump Files',    sub: 'Crash logs',     icon: Icons.warning_amber_rounded,    color: Color(0xFF6D4C41)),
  (key: 'flutter_pub',   name: 'Flutter / Dart',sub: 'Pub cache',      icon: Icons.flutter_dash,             color: Color(0xFF02569B)),
];

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool _scannersExpanded = true;
  bool _resultsExpanded  = true;
  final _searchCtrl = TextEditingController();
  Timer? _configSaveTimer;
  final Set<String> _expanded = {};

  void _toggleExpand(String key) => setState(() =>
      _expanded.contains(key) ? _expanded.remove(key) : _expanded.add(key));

  void _scheduleConfigSave(ConfigProvider config) {
    _configSaveTimer?.cancel();
    _configSaveTimer = Timer(const Duration(milliseconds: 400), () {
      config.saveToFile().catchError((_) {});
    });
  }

  @override
  void dispose() {
    _configSaveTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ScanProvider, ConfigProvider>(
      builder: (context, scan, config, _) {
        final hasContent = scan.state == ScanState.done || scan.state == ScanState.error;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildScannerHeader(context, scan, config),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInOut,
              child: _scannersExpanded
                  ? _buildScannerPanel(context, config)
                  : const SizedBox.shrink(),
            ),
            if (hasContent) ...[
              _buildResultsHeader(context, scan),
              if (_resultsExpanded) Expanded(child: _buildResultsContent(context, scan)),
            ] else
              Expanded(child: _buildIdleState(context)),
          ],
        );
      },
    );
  }

  // ── Scanner header ────────────────────────────────────────────────────────

  Widget _buildScannerHeader(BuildContext context, ScanProvider scan, ConfigProvider config) {
    final theme      = Theme.of(context);
    final isDark     = theme.brightness == Brightness.dark;
    final isScanning = scan.state == ScanState.scanning;
    final enabledCount = config.scanners.values.where((v) => v).length;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F1923)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        border: Border(bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4))),
      ),
      child: Row(
        children: [
          _CollapseBtn(
            expanded: _scannersExpanded,
            onTap: () => setState(() => _scannersExpanded = !_scannersExpanded),
          ),
          const SizedBox(width: 4),
          Text('Scanners',
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.3)),
          const SizedBox(width: 6),
          _Badge(label: '$enabledCount / ${config.scanners.length}', color: theme.colorScheme.primary),
          const Spacer(),
          if (isScanning) ...[
            SizedBox(
              width: 12, height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                scan.progress.isNotEmpty ? scan.progress : 'Scanning\u2026',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (scan.scannersTotal > 0) ...[
              const SizedBox(width: 6),
              Text('${scan.scannersDone}/${scan.scannersTotal}',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
            const SizedBox(width: 10),
          ],
          if (scan.state == ScanState.done) ...[
            Text('${scan.totalCount} items \u00b7 ${_hs(scan.totalSize)} found',
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)),
            const SizedBox(width: 12),
          ],
          if (!isScanning)
            _ActionBtn(
              label: 'Start Scan',
              icon: Icons.search,
              onTap: () {
                scan.startScan();
                setState(() { _scannersExpanded = false; _resultsExpanded = true; });
              },
            ),
        ],
      ),
    );
  }

  // ── Scanner panel ─────────────────────────────────────────────────────────

  Widget _buildScannerPanel(BuildContext context, ConfigProvider config) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF111920) : theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCsharpGroup(context, config),
          _buildSimpleGrid(context, config),
          _buildExpandableScanner(
            context: context, config: config,
            scannerKey: 'build_artifacts',
            name: 'Build Artifacts', sub: 'obj/ bin/ target/ etc.',
            icon: Icons.folder_delete_outlined, color: const Color(0xFF607D8B),
            expandKey: '_build_artifacts',
            children: _buildArtifactChildren(context, config),
          ),
          _buildExpandableScanner(
            context: context, config: config,
            scannerKey: 'env_vars',
            name: 'Env Vars', sub: 'PATH & variable issues',
            icon: Icons.settings_suggest, color: const Color(0xFFEF6C00),
            expandKey: '_env_vars',
            children: _buildEnvVarsChildren(context, config),
          ),
          _buildExpandableScanner(
            context: context, config: config,
            scannerKey: 'windows_temp',
            name: 'Windows Temp', sub: 'TEMP / Prefetch / WER',
            icon: Icons.auto_delete, color: const Color(0xFF0078D4),
            expandKey: '_windows_temp',
            children: _buildWindowsTempChildren(context, config),
          ),
          _buildWhitelistRow(context, config),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  // ── C# / .NET group ───────────────────────────────────────────────────────

  Widget _buildCsharpGroup(BuildContext context, ConfigProvider config) {
    final theme      = Theme.of(context);
    final isDark     = theme.brightness == Brightness.dark;
    const color      = Color(0xFF512BD4);
    const expKey     = '_csharp';
    final nugetOn    = config.scanners['nuget'] ?? false;
    final artifactOn = config.artifacts['scan_csharp_obj_bin'] ?? false;
    final anyOn      = nugetOn || artifactOn;
    final isExpanded = _expanded.contains(expKey);

    return Column(children: [
      InkWell(
        onTap: () => _toggleExpand(expKey),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          height: 44,
          color: anyOn
              ? (isDark ? color.withValues(alpha: 0.10) : color.withValues(alpha: 0.06))
              : Colors.transparent,
          child: Row(children: [
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: anyOn ? color : color.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Icon(Icons.widgets_outlined, size: 14,
                  color: anyOn ? Colors.white : Colors.white.withValues(alpha: 0.55)),
            ),
            const SizedBox(width: 8),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('C# / .NET', style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600, fontSize: 12,
                  color: anyOn
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withValues(alpha: 0.40),
                )),
                Text('NuGet + Build Artifacts', style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant
                      .withValues(alpha: anyOn ? 0.7 : 0.35),
                )),
              ],
            )),
            Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
          ]),
        ),
      ),
      if (isExpanded) ...[
        _SubToggle(
          label: 'NuGet', description: '.NET package cache',
          value: nugetOn, indent: 44,
          onChanged: (v) { config.updateScanner('nuget', v); _scheduleConfigSave(config); },
        ),
        _SubToggle(
          label: 'Build Artifacts  (obj/ bin/)',
          description: 'Requires Build Artifacts scanner to be enabled',
          value: artifactOn, indent: 44,
          onChanged: (v) {
            config.updateArtifact('scan_csharp_obj_bin', v);
            if (v && !(config.scanners['build_artifacts'] ?? false)) {
              config.updateScanner('build_artifacts', true);
            }
            _scheduleConfigSave(config);
          },
        ),
      ],
      Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.25)),
    ]);
  }

  // ── Simple 2-col grid ─────────────────────────────────────────────────────

  Widget _buildSimpleGrid(BuildContext context, ConfigProvider config) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final cols = constraints.maxWidth > 960 ? 4 : constraints.maxWidth > 640 ? 3 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols, mainAxisExtent: 44, mainAxisSpacing: 1, crossAxisSpacing: 1,
        ),
        itemCount: _kSimpleScanners.length,
        itemBuilder: (_, i) {
          final s       = _kSimpleScanners[i];
          final enabled = config.scanners[s.key] ?? false;
          return _ScannerRow(
            def: s, enabled: enabled,
            onToggle: (v) { config.updateScanner(s.key, v); _scheduleConfigSave(config); },
          );
        },
      );
    });
  }

  // ── Generic expandable scanner row ────────────────────────────────────────

  Widget _buildExpandableScanner({
    required BuildContext context,
    required ConfigProvider config,
    required String scannerKey,
    required String name,
    required String sub,
    required IconData icon,
    required Color color,
    required String expandKey,
    required List<Widget> children,
  }) {
    final theme      = Theme.of(context);
    final isDark     = theme.brightness == Brightness.dark;
    final enabled    = config.scanners[scannerKey] ?? false;
    final isExpanded = _expanded.contains(expandKey);

    return Column(children: [
      Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.25)),
      InkWell(
        onTap: () => _toggleExpand(expandKey),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          height: 44,
          color: enabled
              ? (isDark ? color.withValues(alpha: 0.10) : color.withValues(alpha: 0.06))
              : Colors.transparent,
          child: Row(children: [
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: enabled ? color : color.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Icon(icon, size: 14,
                  color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.55)),
            ),
            const SizedBox(width: 8),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(name, style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600, fontSize: 12,
                  color: enabled
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withValues(alpha: 0.40),
                )),
                Text(sub, style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant
                      .withValues(alpha: enabled ? 0.7 : 0.35),
                )),
              ],
            )),
            GestureDetector(
              onTap: () { config.updateScanner(scannerKey, !enabled); _scheduleConfigSave(config); },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Switch(
                  value: enabled,
                  onChanged: (v) { config.updateScanner(scannerKey, v); _scheduleConfigSave(config); },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
          ]),
        ),
      ),
      if (isExpanded) ...children,
    ]);
  }

  // ── Artifact sub-items ────────────────────────────────────────────────────

  List<Widget> _buildArtifactChildren(BuildContext context, ConfigProvider config) {
    const items = [
      ('scan_csharp_obj_bin', 'C# / .NET',  'obj/ bin/'),
      ('scan_rust_target',    'Rust',        'target/'),
      ('scan_node_modules',   'Node.js',     'node_modules/'),
      ('scan_frontend_dist',  'JS / TS',     '.next/ .nuxt/ dist/'),
      ('scan_java_build',     'Java',        'Maven target/ Gradle build/'),
      ('scan_python_cache',   'Python',      '__pycache__/ .pytest_cache/'),
      ('scan_cmake_build',    'C / C++',     'CMakeFiles/ cmake-build-*/'),
      ('scan_flutter_build',  'Flutter',     'build/ .dart_tool/'),
      ('scan_go_vendor',      'Go',          'vendor/'),
    ];
    return [
      _SubGrid(children: items.map((item) {
        final (key, label, desc) = item;
        final value = config.artifacts[key] ?? false;
        return _SubCheckbox(
          label: label, description: desc, value: value,
          onChanged: (v) { config.updateArtifact(key, v); _scheduleConfigSave(config); },
        );
      }).toList()),
    ];
  }

  // ── Env Vars sub-items ────────────────────────────────────────────────────

  List<Widget> _buildEnvVarsChildren(BuildContext context, ConfigProvider config) {
    final opts = config.envVarsOptions;
    return [
      _SubToggle(
        label: 'Invalid variable values',
        description: 'JAVA_HOME, GOROOT, etc. pointing to non-existent paths',
        value: opts['check_invalid_values'] ?? true, indent: 44,
        onChanged: (v) { config.updateEnvVarsOption('check_invalid_values', v); _scheduleConfigSave(config); },
      ),
      _SubToggle(
        label: 'Invalid PATH entries',
        description: "PATH entries that don't exist on disk",
        value: opts['check_path_entries'] ?? true, indent: 44,
        onChanged: (v) { config.updateEnvVarsOption('check_path_entries', v); _scheduleConfigSave(config); },
      ),
    ];
  }

  // ── Windows Temp sub-items ────────────────────────────────────────────────

  List<Widget> _buildWindowsTempChildren(BuildContext context, ConfigProvider config) {
    final opts = config.windowsTempOptions;
    const items = [
      ('user_temp',   'User TEMP',             r'%LOCALAPPDATA%\Temp'),
      ('system_temp', 'System TEMP',           r'C:\Windows\Temp'),
      ('prefetch',    'Prefetch',              r'C:\Windows\Prefetch'),
      ('wu_download', 'Windows Update cache',  r'SoftwareDistribution\Download'),
      ('inet_cache',  'IE/Edge cache',         r'INetCache (legacy)'),
      ('wer',         'Windows Error Reports', r'WER\ReportArchive + Queue'),
    ];
    return [
      _SubGrid(children: items.map((item) {
        final (key, label, desc) = item;
        final value = opts[key] ?? true;
        return _SubCheckbox(
          label: label, description: desc, value: value,
          onChanged: (v) { config.updateWindowsTempOption(key, v); _scheduleConfigSave(config); },
        );
      }).toList()),
    ];
  }

  // ── Whitelist row ─────────────────────────────────────────────────────────

  Widget _buildWhitelistRow(BuildContext context, ConfigProvider config) {
    final theme  = Theme.of(context);
    final count  = config.whitelistPatterns.length;
    final active = count > 0;

    return Column(children: [
      Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.25)),
      InkWell(
        onTap: () => _showWhitelistDialog(context, config),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          height: 44,
          child: Row(children: [
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: active ? 1.0 : 0.25),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Icon(Icons.shield_outlined, size: 14,
                  color: Colors.white.withValues(alpha: active ? 1.0 : 0.55)),
            ),
            const SizedBox(width: 8),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Whitelist', style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600, fontSize: 12,
                )),
                Text(
                  active
                      ? '$count ignore pattern${count == 1 ? '' : 's'} active'
                      : 'No ignore patterns \u2014 tap to configure',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            )),
            Icon(Icons.chevron_right, size: 16,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
          ]),
        ),
      ),
    ]);
  }

  void _showWhitelistDialog(BuildContext context, ConfigProvider config) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _WhitelistDialog(config: config),
    );
  }

  // ── Results header ─────────────────────────────────────────────────────────

  Widget _buildResultsHeader(BuildContext context, ScanProvider scan) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDone = scan.state == ScanState.done;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F1923)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(children: [
        _CollapseBtn(
          expanded: _resultsExpanded,
          onTap: () => setState(() => _resultsExpanded = !_resultsExpanded),
        ),
        const SizedBox(width: 4),
        Text('Results',
            style: theme.textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.3)),
        const SizedBox(width: 6),
        if (isDone)
          _Badge(
            label: '${scan.filteredItems.length} / ${scan.totalCount}  \u00b7  ${_hs(scan.totalSize)}',
            color: theme.colorScheme.tertiary,
          )
        else
          _Badge(label: 'Error', color: theme.colorScheme.error),
        const Spacer(),
        if (_resultsExpanded && isDone) ...[
          SizedBox(
            width: 220, height: 26,
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search\u2026',
                hintStyle: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                prefixIcon: const Icon(Icons.search, size: 13),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 11),
                        padding: EdgeInsets.zero,
                        onPressed: () { _searchCtrl.clear(); scan.setSearch(''); },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: theme.dividerColor, width: 0.8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: theme.dividerColor, width: 0.8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                isDense: true,
              ),
              style: theme.textTheme.bodySmall,
              onChanged: scan.setSearch,
            ),
          ),
          const SizedBox(width: 8),
          Text('Sort:', style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
          const SizedBox(width: 4),
          DropdownButton<String>(
            value: scan.sortBy, isDense: true,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurface, fontSize: 12),
            borderRadius: BorderRadius.circular(6),
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 'size',    child: Text('Size')),
              DropdownMenuItem(value: 'name',    child: Text('Name')),
              DropdownMenuItem(value: 'scanner', child: Text('Scanner')),
              DropdownMenuItem(value: 'type',    child: Text('Type')),
            ],
            onChanged: (v) { if (v != null) scan.setSort(v, scan.sortAscending); },
          ),
          IconButton(
            icon: Icon(scan.sortAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 13),
            onPressed: () => scan.setSort(scan.sortBy, !scan.sortAscending),
            padding: const EdgeInsets.all(2),
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 6),
          _SmallTextBtn(label: 'All',  onTap: () => scan.selectAll(true)),
          _SmallTextBtn(label: 'None', onTap: () => scan.selectAll(false)),
        ],
      ]),
    );
  }

  // ── Results content ───────────────────────────────────────────────────────

  Widget _buildResultsContent(BuildContext context, ScanProvider scan) {
    if (scan.state == ScanState.error) {
      return _emptyState(context,
          icon: Icons.error_outline,
          title: 'Scan failed',
          subtitle: scan.error ?? 'Unknown error');
    }
    final items = scan.filteredItems;
    if (items.isEmpty) {
      return _emptyState(context,
          icon: Icons.cleaning_services_rounded,
          title: scan.searchQuery.isNotEmpty
              ? 'No items match your search'
              : 'Nothing to clean \u2014 dev environment is tidy',
          subtitle: '');
    }
    return Stack(children: [
      Column(children: [
        Expanded(child: _buildList(context, scan, items)),
        if (scan.selectedCount > 0) _buildBottomBar(context, scan),
      ]),
      if (scan.isDeleting) _buildDeleteOverlay(context, scan),
    ]);
  }

  Widget _buildList(BuildContext context, ScanProvider scan, List<CleanItem> items) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(
        height: 1, indent: 42,
        color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
      ),
      itemBuilder: (ctx, i) => _buildRow(ctx, scan, items[i]),
    );
  }

  Widget _buildRow(BuildContext context, ScanProvider scan, CleanItem item) {
    final theme = Theme.of(context);

    Color typeColor(String t) => switch (t) {
          'cache'              => const Color(0xFF1E88E5),
          'build_artifact'     => const Color(0xFFF57C00),
          'old_version'        => const Color(0xFF8E24AA),
          'node_modules'       => const Color(0xFF43A047),
          'invalid_env_var'    => const Color(0xFFE53935),
          'invalid_path_entry' => const Color(0xFFE53935),
          'dump_file'          => const Color(0xFF6D4C41),
          'temp_directory'     => const Color(0xFF00897B),
          _                    => Colors.grey,
        };

    return GestureDetector(
      onSecondaryTapUp: (d) => _showCtxMenu(context, scan, item, d.globalPosition),
      child: InkWell(
        onTap: () => scan.toggleItem(item),
        child: SizedBox(
          height: 36,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(children: [
              SizedBox(
                width: 18, height: 18,
                child: Checkbox(
                  value: item.selected,
                  onChanged: (_) => scan.toggleItem(item),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 3, height: 20,
                decoration: BoxDecoration(
                  color: typeColor(item.itemType),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Text(
                  item.packageName != null
                      ? '${item.packageName}${item.version != null ? "  ${item.version}" : ""}'
                      : item.description,
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  item.path,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFamily: 'Consolas, monospace', fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: 72,
                child: Text(
                  item.scanner,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.outline, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 8),
              _MiniTag(label: item.itemType.replaceAll('_', ' '), color: typeColor(item.itemType)),
              const SizedBox(width: 6),
              SizedBox(
                width: 62,
                child: Text(
                  item.humanSize,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold, color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Context menu ─────────────────────────────────────────────────────────

  Future<void> _showCtxMenu(BuildContext context, ScanProvider scan,
      CleanItem item, Offset pos) async {
    final config  = context.read<ConfigProvider>();
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final isNonFs = item.itemType == 'invalid_env_var' || item.itemType == 'invalid_path_entry';

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(pos.dx, pos.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      elevation: 8,
      items: isNonFs
          ? [
              PopupMenuItem(value: 'copy', height: 36,
                  child: Row(children: [
                    Icon(Icons.copy_outlined, size: 15,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 10),
                    const Text('Copy to Clipboard', style: TextStyle(fontSize: 13)),
                  ])),
            ]
          : [
              PopupMenuItem(value: 'explorer', height: 36,
                  child: Row(children: [
                    Icon(Icons.folder_open_outlined, size: 15,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 10),
                    const Text('Open in Explorer', style: TextStyle(fontSize: 13)),
                  ])),
              const PopupMenuDivider(height: 1),
              PopupMenuItem(value: 'whitelist', height: 36,
                  child: Row(children: [
                    Icon(Icons.playlist_add_check, size: 15,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    const Text('Add to whitelist', style: TextStyle(fontSize: 13)),
                  ])),
            ],
    );

    if (!context.mounted) return;
    switch (result) {
      case 'copy':
        final text = item.itemType == 'invalid_env_var'
            ? '${item.packageName ?? item.description} = ${item.path}'
            : item.path;
        await Clipboard.setData(ClipboardData(text: text));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Copied to clipboard'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ));
        }
      case 'explorer':
        final type = FileSystemEntity.typeSync(item.path);
        if (type == FileSystemEntityType.directory) {
          Process.run('explorer.exe', [item.path]);
        } else {
          Process.run('explorer.exe', ['/select,', item.path]);
        }
      case 'whitelist':
        final escaped = item.path.replaceAllMapped(
          RegExp(r'[.*+?^${}()|[\]\\]'),
          (m) => '\\${m[0]}',
        );
        config.addWhitelistPattern(escaped);
        try { await config.saveToFile(); } catch (_) {}
        scan.removeItem(item);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Added to whitelist'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ));
        }
    }
  }

  // ── Bottom delete bar ─────────────────────────────────────────────────────

  Widget _buildBottomBar(BuildContext context, ScanProvider scan) {
    final theme = Theme.of(context);
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5))),
      ),
      child: Row(children: [
        Icon(Icons.check_box_outlined, size: 13, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          '${scan.selectedCount} selected  \u00b7  ${_hs(scan.selectedSize)} will be freed',
          style: theme.textTheme.bodySmall,
        ),
        const Spacer(),
        SizedBox(
          height: 28,
          child: FilledButton.icon(
            onPressed: () => _confirmDelete(context, scan),
            icon: const Icon(Icons.delete_sweep, size: 14),
            label: Text('Delete ${scan.selectedCount} items'),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              textStyle: theme.textTheme.labelMedium,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> _confirmDelete(BuildContext context, ScanProvider scan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Confirm Deletion'),
        content: Text(
            'Delete ${scan.selectedCount} items and free ${_hs(scan.selectedSize)}?\n\nThis cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await scan.deleteSelected();
      if (context.mounted && scan.lastDeleteErrors.isNotEmpty) {
        await _showDeleteErrorsDialog(context, scan.lastDeleteErrors);
      }
    }
  }

  Future<void> _showDeleteErrorsDialog(
      BuildContext context, List<DeleteError> errors) async {
    final theme = Theme.of(context);
    final lockedErrors = errors.where((e) => e.lockingProcesses.isNotEmpty).toList();
    final permErrors   = errors.where((e) => e.lockingProcesses.isEmpty && e.accessDenied).toList();
    final otherErrors  = errors.where((e) => !e.accessDenied).toList();

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 100, vertical: 60),
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              border: Border(bottom: BorderSide(
                  color: theme.colorScheme.error.withValues(alpha: 0.3))),
            ),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded, size: 16,
                  color: theme.colorScheme.onErrorContainer),
              const SizedBox(width: 8),
              Text(
                '${errors.length} item${errors.length == 1 ? '' : 's'} could not be deleted',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close, size: 16, color: theme.colorScheme.onErrorContainer),
                onPressed: () => Navigator.pop(ctx),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (lockedErrors.isNotEmpty) ...[
                  _errSectionTitle(theme, Icons.lock_outline, 'File in use', theme.colorScheme.error),
                  const SizedBox(height: 6),
                  ...lockedErrors.map((e) => _errLockedRow(theme, e)),
                  const SizedBox(height: 14),
                ],
                if (permErrors.isNotEmpty) ...[
                  _errSectionTitle(theme, Icons.no_encryption_outlined, 'Access denied', theme.colorScheme.error),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(children: [
                      Icon(Icons.admin_panel_settings_outlined, size: 14,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        'These files are protected. Try running DevCleaner as Administrator.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 6),
                  ...permErrors.map((e) => _errPathRow(theme, e)),
                  const SizedBox(height: 14),
                ],
                if (otherErrors.isNotEmpty) ...[
                  _errSectionTitle(theme, Icons.error_outline, 'Other errors',
                      theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 6),
                  ...otherErrors.map((e) => _errPathRow(theme, e, showMessage: true)),
                ],
              ]),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _errSectionTitle(ThemeData theme, IconData icon, String title, Color color) {
    return Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Text(title, style: theme.textTheme.labelMedium
          ?.copyWith(fontWeight: FontWeight.w700, color: color)),
    ]);
  }

  Widget _errLockedRow(ThemeData theme, DeleteError e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.insert_drive_file_outlined, size: 12,
              color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(child: Text(e.path,
              style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'Consolas, monospace', fontSize: 11),
              overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 4),
        Container(
          margin: const EdgeInsets.only(left: 18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(children: e.lockingProcesses.map((proc) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(children: [
              Icon(Icons.memory_outlined, size: 12, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(child: Text(proc.name,
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis)),
              Text('PID ${proc.pid}', style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline, fontFamily: 'Consolas, monospace')),
            ]),
          )).toList()),
        ),
      ]),
    );
  }

  Widget _errPathRow(ThemeData theme, DeleteError e, {bool showMessage = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.insert_drive_file_outlined, size: 12,
              color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(child: Text(e.path,
              style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'Consolas, monospace', fontSize: 11),
              overflow: TextOverflow.ellipsis)),
        ]),
        if (showMessage)
          Padding(
            padding: const EdgeInsets.only(left: 18, top: 2),
            child: Text(e.message,
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error),
                overflow: TextOverflow.ellipsis),
          ),
      ]),
    );
  }

  Widget _buildDeleteOverlay(BuildContext context, ScanProvider scan) {
    final theme    = Theme.of(context);
    final progress = scan.deleteTotal > 0 ? scan.deleteProgress / scan.deleteTotal : null;
    return Container(
      color: Colors.black.withValues(alpha: 0.50),
      child: Center(
        child: Card(
          elevation: 16,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Deleting\u2026', style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(
                width: 260,
                child: LinearProgressIndicator(value: progress, minHeight: 5),
              ),
              const SizedBox(height: 6),
              Text('${scan.deleteProgress} / ${scan.deleteTotal}  \u00b7  ${_hs(scan.freedBytes)} freed',
                  style: theme.textTheme.bodySmall),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildIdleState(BuildContext context) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF0D1520) : const Color(0xFFF6F9FB),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.manage_search_rounded, size: 52, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 12),
          Text('Ready to scan', style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600,
          )),
          const SizedBox(height: 4),
          Text('Configure scanners above and click Start Scan',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
        ]),
      ),
    );
  }

  Widget _emptyState(BuildContext context,
      {required IconData icon, required String title, required String subtitle}) {
    final theme = Theme.of(context);
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 48, color: theme.colorScheme.outlineVariant),
        const SizedBox(height: 12),
        Text(title, style: theme.textTheme.titleSmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline)),
        ],
      ]),
    );
  }

  String _hs(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

// ── Whitelist dialog ──────────────────────────────────────────────────────────

class _WhitelistDialog extends StatefulWidget {
  final ConfigProvider config;
  const _WhitelistDialog({required this.config});

  @override
  State<_WhitelistDialog> createState() => _WhitelistDialogState();
}

class _WhitelistDialogState extends State<_WhitelistDialog> {
  final _ctrl = TextEditingController();
  String? _patternError;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _add() async {
    final p = _ctrl.text.trim();
    if (p.isEmpty) return;
    try { RegExp(p); } catch (_) {
      setState(() => _patternError = 'Invalid regex pattern');
      return;
    }
    setState(() => _patternError = null);
    widget.config.addWhitelistPattern(p);
    _ctrl.clear();
    try { await widget.config.saveToFile(); } catch (_) {}
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme    = Theme.of(context);
    final config   = widget.config;
    final patterns = config.whitelistPatterns;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 160, vertical: 80),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            border: Border(bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5))),
          ),
          child: Row(children: [
            Icon(Icons.shield_outlined, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text('Whitelist  (Ignore Patterns)',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: () => Navigator.pop(context),
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
            ),
          ]),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'Regex patterns matched against full paths. Matching items are excluded from results.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              if (patterns.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('No patterns \u2014 all scanned items are shown.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline, fontStyle: FontStyle.italic,
                      )),
                )
              else
                ...patterns.map((p) => _PatternRow(
                  pattern: p,
                  onDelete: () async {
                    config.removeWhitelistPattern(p);
                    try { await config.saveToFile(); } catch (_) {}
                    setState(() {});
                  },
                )),
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    onSubmitted: (_) => _add(),
                    onChanged: (_) {
                      if (_patternError != null) setState(() => _patternError = null);
                    },
                    decoration: InputDecoration(
                      hintText: r'C:\\Users\\you\\keep\\this',
                      hintStyle: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                      errorText: _patternError,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: _add,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Add', style: TextStyle(fontSize: 13)),
                ),
              ]),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _PatternRow extends StatelessWidget {
  final String pattern;
  final VoidCallback onDelete;
  const _PatternRow({required this.pattern, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 30,
      child: Row(children: [
        Icon(Icons.subdirectory_arrow_right, size: 13,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
        const SizedBox(width: 4),
        Expanded(child: Text(pattern,
            style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'Consolas, monospace'),
            overflow: TextOverflow.ellipsis)),
        InkWell(
          onTap: onDelete,
          borderRadius: BorderRadius.circular(4),
          child: Padding(padding: const EdgeInsets.all(4),
              child: Icon(Icons.close, size: 14, color: theme.colorScheme.error)),
        ),
      ]),
    );
  }
}

// ── Small reusable widgets ────────────────────────────────────────────────────

class _CollapseBtn extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;
  const _CollapseBtn({required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(expanded ? Icons.expand_less : Icons.expand_more,
            size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 28,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 13),
        label: Text(label),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          textStyle: theme.textTheme.labelMedium,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
      ),
    );
  }
}

class _SmallTextBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SmallTextBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 11),
      ),
      child: Text(label),
    );
  }
}

class _ScannerRow extends StatelessWidget {
  final _Def def;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  const _ScannerRow({required this.def, required this.enabled, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () => onToggle(!enabled),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        color: enabled
            ? (isDark ? def.color.withValues(alpha: 0.08) : def.color.withValues(alpha: 0.05))
            : Colors.transparent,
        child: Row(children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              color: enabled ? def.color : def.color.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Icon(def.icon, size: 14,
                color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.55)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(def.name, style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600, fontSize: 12,
                color: enabled
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withValues(alpha: 0.40),
              ), overflow: TextOverflow.ellipsis),
              Text(def.sub, style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: theme.colorScheme.onSurfaceVariant
                    .withValues(alpha: enabled ? 0.7 : 0.35),
              ), overflow: TextOverflow.ellipsis),
            ],
          )),
          Switch(
            value: enabled, onChanged: onToggle,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ]),
      ),
    );
  }
}

class _SubToggle extends StatelessWidget {
  final String label;
  final String description;
  final bool value;
  final double indent;
  final ValueChanged<bool> onChanged;

  const _SubToggle({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
    this.indent = 44,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: EdgeInsets.only(left: indent, right: 12, top: 6, bottom: 6),
        child: Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: value
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withValues(alpha: 0.45),
              )),
              Text(description, style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ), overflow: TextOverflow.ellipsis),
            ],
          )),
          Switch(
            value: value, onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ]),
      ),
    );
  }
}

class _SubGrid extends StatelessWidget {
  final List<Widget> children;
  const _SubGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(44, 4, 8, 8),
      child: LayoutBuilder(builder: (ctx, c) {
        final cols = c.maxWidth > 480 ? 2 : 1;
        if (cols == 1) return Column(children: children);
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += 2) {
          rows.add(Row(children: [
            Expanded(child: children[i]),
            const SizedBox(width: 4),
            Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox.shrink()),
          ]));
        }
        return Column(children: rows);
      }),
    );
  }
}

class _SubCheckbox extends StatelessWidget {
  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SubCheckbox({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Row(children: [
          SizedBox(
            width: 28, height: 28,
            child: Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: value
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withValues(alpha: 0.45),
              )),
              Text(description, style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ), overflow: TextOverflow.ellipsis),
            ],
          )),
        ]),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
