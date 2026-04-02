import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rpc_types.dart';
import '../providers/config_provider.dart';
import '../providers/scan_provider.dart';

// ── Scanner metadata ──────────────────────────────────────────────────────────

typedef _Def = ({
  String key,
  String name,
  String sub,
  IconData icon,
  Color color
});

const List<_Def> _kScanners = [
  (key: 'nuget',           name: 'NuGet',         sub: '.NET',          icon: Icons.widgets_outlined,     color: Color(0xFF512BD4)),
  (key: 'cargo',           name: 'Cargo',          sub: 'Rust',          icon: Icons.memory,               color: Color(0xFFCE422B)),
  (key: 'golang',          name: 'Go Modules',     sub: 'Go',            icon: Icons.cloud_queue,          color: Color(0xFF00ADD8)),
  (key: 'node',            name: 'Node.js',        sub: 'npm / yarn',    icon: Icons.hub,                  color: Color(0xFF339933)),
  (key: 'pip',             name: 'pip / uv',       sub: 'Python',        icon: Icons.code,                 color: Color(0xFF3776AB)),
  (key: 'maven',           name: 'Maven',          sub: 'Java',          icon: Icons.inventory_2_outlined, color: Color(0xFFC71A36)),
  (key: 'gradle',          name: 'Gradle',         sub: 'Java / Android',icon: Icons.construction,         color: Color(0xFF1BA9AC)),
  (key: 'build_artifacts', name: 'Artifacts',      sub: 'Build dirs',    icon: Icons.folder_delete_outlined,color: Color(0xFF607D8B)),
  (key: 'env_vars',        name: 'Env Vars',       sub: 'PATH issues',   icon: Icons.settings_suggest,     color: Color(0xFFEF6C00)),
  (key: 'dump_files',      name: 'Dump Files',     sub: 'Crash logs',    icon: Icons.warning_amber_rounded,color: Color(0xFF6D4C41)),
  (key: 'android_sdk',     name: 'Android SDK',    sub: 'Old SDKs',      icon: Icons.android,              color: Color(0xFF3DDC84)),
  (key: 'ide_cache',       name: 'IDE Caches',     sub: 'JetBrains / VS',icon: Icons.developer_mode,       color: Color(0xFFE91E8C)),
  (key: 'windows_temp',    name: 'Win Temp',       sub: 'Temp files',    icon: Icons.auto_delete,          color: Color(0xFF0078D4)),
  (key: 'rustup',          name: 'Rustup',         sub: 'Old toolchains',icon: Icons.system_update_alt,    color: Color(0xFFBF360C)),
  (key: 'browser_cache',   name: 'Browser Cache',  sub: 'Chrome / Edge', icon: Icons.public,               color: Color(0xFF1A73E8)),
  (key: 'flutter_pub',     name: 'Flutter / Dart', sub: 'Pub cache',     icon: Icons.flutter_dash,         color: Color(0xFF02569B)),
];

// ── Main page ─────────────────────────────────────────────────────────────────

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool _scannersExpanded = true;
  bool _resultsExpanded  = true;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ScanProvider, ConfigProvider>(
      builder: (context, scan, config, _) {
        final hasContent = scan.state == ScanState.done ||
            scan.state == ScanState.error;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Scanner section ───────────────────────────────────────────
            _SectionHeader(
              label: 'Scanners',
              badge:
                  '${config.scanners.values.where((v) => v).length} / ${_kScanners.length}',
              expanded: _scannersExpanded,
              onToggle: () =>
                  setState(() => _scannersExpanded = !_scannersExpanded),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInOut,
              child: _scannersExpanded
                  ? _buildScannerGrid(context, config)
                  : const SizedBox.shrink(),
            ),

            // ── Action toolbar ────────────────────────────────────────────
            _buildToolbar(context, scan),

            // ── Results section ───────────────────────────────────────────
            if (hasContent) ...[
              _SectionHeader(
                label: 'Results',
                badge: scan.state == ScanState.done
                    ? '${scan.totalCount} items · ${_hs(scan.totalSize)}'
                    : 'Error',
                expanded: _resultsExpanded,
                onToggle: () =>
                    setState(() => _resultsExpanded = !_resultsExpanded),
              ),
              if (_resultsExpanded)
                Expanded(child: _buildResultsArea(context, scan)),
            ] else
              Expanded(child: _buildIdleState(context, scan)),
          ],
        );
      },
    );
  }

  // ── Scanner grid ────────────────────────────────────────────────────────────

  Widget _buildScannerGrid(BuildContext context, ConfigProvider config) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF111920) : theme.colorScheme.surface,
      child: LayoutBuilder(builder: (ctx, constraints) {
        final cols = constraints.maxWidth > 960
            ? 4
            : constraints.maxWidth > 640
                ? 3
                : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisExtent: 48,
            mainAxisSpacing: 1,
            crossAxisSpacing: 1,
          ),
          itemCount: _kScanners.length,
          itemBuilder: (_, i) {
            final s = _kScanners[i];
            final enabled = config.scanners[s.key] ?? false;
            return _ScannerRow(
              def: s,
              enabled: enabled,
              onToggle: (v) => config.updateScanner(s.key, v),
            );
          },
        );
      }),
    );
  }

  // ── Toolbar ─────────────────────────────────────────────────────────────────

  Widget _buildToolbar(BuildContext context, ScanProvider scan) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isScanning = scan.state == ScanState.scanning;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1923) : theme.colorScheme.surfaceContainer,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        children: [
          // Scan button
          SizedBox(
            height: 34,
            child: FilledButton.icon(
              onPressed: isScanning ? null : () {
                scan.startScan();
                // auto-expand results when scan starts
                setState(() {
                  _resultsExpanded  = true;
                  _scannersExpanded = false;
                });
              },
              icon: const Icon(Icons.search, size: 16),
              label: const Text('Start Scan'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ),
          if (isScanning) ...[
            const SizedBox(width: 8),
            SizedBox(
              height: 34,
              child: OutlinedButton.icon(
                onPressed: scan.abortScan,
                icon: const Icon(Icons.stop, size: 14),
                label: const Text('Abort'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(color: theme.colorScheme.error),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
          ],
          const SizedBox(width: 16),
          // Status text
          Expanded(
            child: _buildStatusText(context, scan),
          ),
          // Scan complete action
          if (scan.state == ScanState.done)
            TextButton.icon(
              onPressed: () => setState(() {
                _resultsExpanded  = true;
                _scannersExpanded = false;
              }),
              icon: const Icon(Icons.arrow_downward, size: 14),
              label: const Text('View Results'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusText(BuildContext context, ScanProvider scan) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return switch (scan.state) {
      ScanState.scanning => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Scanning  ${scan.progress}',
                style: style,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (scan.scannersTotal > 0) ...[
              const SizedBox(width: 8),
              Text(
                '${scan.scannersDone}/${scan.scannersTotal}',
                style: style,
              ),
            ],
          ],
        ),
      ScanState.done => Text(
          '${scan.totalCount} items found  ·  ${_hs(scan.totalSize)} reclaimable',
          style: style?.copyWith(color: theme.colorScheme.primary),
        ),
      ScanState.error => Text(
          scan.error ?? 'Scan failed',
          style: style?.copyWith(color: theme.colorScheme.error),
        ),
      _ => const SizedBox.shrink(),
    };
  }

  // ── Results area ─────────────────────────────────────────────────────────────

  Widget _buildResultsArea(BuildContext context, ScanProvider scan) {
    if (scan.state == ScanState.error) {
      return _buildEmptyState(context,
          icon: Icons.error_outline,
          title: 'Scan failed',
          subtitle: scan.error ?? 'Unknown error');
    }

    final items = scan.filteredItems;
    if (items.isEmpty) {
      return _buildEmptyState(context,
          icon: Icons.cleaning_services_rounded,
          title: scan.searchQuery.isNotEmpty
              ? 'No items match your search'
              : 'Nothing to clean — dev environment is tidy 🎉',
          subtitle: '');
    }

    return Stack(
      children: [
        Column(
          children: [
            _buildResultsToolbar(context, scan),
            Expanded(child: _buildResultsList(context, scan, items)),
            if (scan.selectedCount > 0) _buildBottomBar(context, scan),
          ],
        ),
        if (scan.isDeleting) _buildDeleteOverlay(context, scan),
      ],
    );
  }

  Widget _buildResultsToolbar(BuildContext context, ScanProvider scan) {
    final theme = Theme.of(context);
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border(
            bottom: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.4))),
      ),
      child: Row(
        children: [
          // Search
          SizedBox(
            width: 260,
            height: 28,
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search…',
                hintStyle: theme.textTheme.bodySmall,
                prefixIcon: const Icon(Icons.search, size: 14),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 12),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          _searchCtrl.clear();
                          scan.setSearch('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                isDense: true,
              ),
              style: theme.textTheme.bodySmall,
              onChanged: scan.setSearch,
            ),
          ),
          const SizedBox(width: 12),
          // Sort
          Text('Sort:', style: theme.textTheme.bodySmall),
          const SizedBox(width: 4),
          DropdownButton<String>(
            value: scan.sortBy,
            isDense: true,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurface),
            borderRadius: BorderRadius.circular(6),
            items: const [
              DropdownMenuItem(value: 'size',    child: Text('Size')),
              DropdownMenuItem(value: 'name',    child: Text('Name')),
              DropdownMenuItem(value: 'scanner', child: Text('Scanner')),
              DropdownMenuItem(value: 'type',    child: Text('Type')),
            ],
            onChanged: (v) {
              if (v != null) scan.setSort(v, scan.sortAscending);
            },
          ),
          IconButton(
            icon: Icon(
              scan.sortAscending
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,
              size: 14,
            ),
            onPressed: () =>
                scan.setSort(scan.sortBy, !scan.sortAscending),
            padding: const EdgeInsets.all(2),
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
          const Spacer(),
          // Select all / none
          TextButton(
            onPressed: () => scan.selectAll(true),
            style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: const Text('All', style: TextStyle(fontSize: 12)),
          ),
          TextButton(
            onPressed: () => scan.selectAll(false),
            style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: const Text('None', style: TextStyle(fontSize: 12)),
          ),
          // Item count
          const SizedBox(width: 4),
          Text(
            '${scan.filteredItems.length} / ${scan.totalCount}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList(
      BuildContext context, ScanProvider scan, List<CleanItem> items) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 44,
        color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
      ),
      itemBuilder: (ctx, i) => _buildResultRow(ctx, scan, items[i]),
    );
  }

  Widget _buildResultRow(
      BuildContext context, ScanProvider scan, CleanItem item) {
    final theme = Theme.of(context);

    Color typeColor(String t) => switch (t) {
          'cache'            => const Color(0xFF1E88E5),
          'build_artifact'   => const Color(0xFFF57C00),
          'old_version'      => const Color(0xFF8E24AA),
          'node_modules'     => const Color(0xFF43A047),
          'invalid_env_var'  => const Color(0xFFE53935),
          'invalid_path_entry' => const Color(0xFFE53935),
          'dump_file'        => const Color(0xFF6D4C41),
          'temp_directory'   => const Color(0xFF00897B),
          _                  => Colors.grey,
        };

    return GestureDetector(
      onSecondaryTapUp: (d) =>
          _showCtxMenu(context, scan, item, d.globalPosition),
      child: InkWell(
        onTap: () => scan.toggleItem(item),
        child: SizedBox(
          height: 38,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                // Checkbox
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: item.selected,
                    onChanged: (_) => scan.toggleItem(item),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                // Type color bar
                Container(
                  width: 3,
                  height: 22,
                  decoration: BoxDecoration(
                    color: typeColor(item.itemType),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                // Name / package
                Expanded(
                  flex: 3,
                  child: Text(
                    item.packageName != null
                        ? '${item.packageName}'
                            '${item.version != null ? "  ${item.version}" : ""}'
                        : item.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Path
                Expanded(
                  flex: 4,
                  child: Text(
                    item.path,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFamily: 'Consolas, monospace',
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Scanner label
                SizedBox(
                  width: 80,
                  child: Text(
                    item.scanner,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 8),
                // Type tag
                _MiniTag(
                    label: item.itemType.replaceAll('_', ' '),
                    color: typeColor(item.itemType)),
                const SizedBox(width: 6),
                // Size
                SizedBox(
                  width: 64,
                  child: Text(
                    item.humanSize,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Context menu ─────────────────────────────────────────────────────────────

  Future<void> _showCtxMenu(BuildContext context, ScanProvider scan,
      CleanItem item, Offset pos) async {
    final config = context.read<ConfigProvider>();
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(pos.dx, pos.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      elevation: 8,
      items: [
        PopupMenuItem(
          value: 'explorer',
          height: 36,
          child: Row(children: [
            Icon(Icons.folder_open_outlined,
                size: 15,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            const Text('Open in Explorer',
                style: TextStyle(fontSize: 13)),
          ]),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          value: 'whitelist',
          height: 36,
          child: Row(children: [
            Icon(Icons.playlist_add_check,
                size: 15,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            const Text('Add to whitelist',
                style: TextStyle(fontSize: 13)),
          ]),
        ),
      ],
    );

    if (!context.mounted) return;
    switch (result) {
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ));
        }
    }
  }

  // ── Bottom bar ───────────────────────────────────────────────────────────────

  Widget _buildBottomBar(BuildContext context, ScanProvider scan) {
    final theme = Theme.of(context);
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border(
            top: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Icon(Icons.check_box_outlined,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            '${scan.selectedCount} selected  ·  ${_hs(scan.selectedSize)} will be freed',
            style: theme.textTheme.bodySmall,
          ),
          const Spacer(),
          SizedBox(
            height: 30,
            child: FilledButton.icon(
              onPressed: () => _confirmDelete(context, scan),
              icon: const Icon(Icons.delete_sweep, size: 15),
              label: Text('Delete ${scan.selectedCount} items'),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, ScanProvider scan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Confirm Deletion'),
        content: Text(
            'Delete ${scan.selectedCount} items and free ${_hs(scan.selectedSize)}?\n\nThis cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
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
    if (confirmed == true && context.mounted) scan.deleteSelected();
  }

  // ── Delete overlay ────────────────────────────────────────────────────────────

  Widget _buildDeleteOverlay(BuildContext context, ScanProvider scan) {
    final theme = Theme.of(context);
    final progress =
        scan.deleteTotal > 0 ? scan.deleteProgress / scan.deleteTotal : null;
    return Container(
      color: Colors.black.withValues(alpha: 0.50),
      child: Center(
        child: Card(
          elevation: 16,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Deleting…',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(
                width: 260,
                child: LinearProgressIndicator(
                    value: progress, minHeight: 5),
              ),
              const SizedBox(height: 6),
              Text(
                '${scan.deleteProgress} / ${scan.deleteTotal}  ·  ${_hs(scan.freedBytes)} freed',
                style: theme.textTheme.bodySmall,
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Idle / empty state ────────────────────────────────────────────────────────

  Widget _buildIdleState(BuildContext context, ScanProvider scan) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF0D1520) : const Color(0xFFF7F9FB),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.manage_search_rounded,
              size: 56,
              color: theme.colorScheme.outlineVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Ready to scan',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select scanners above and click Start Scan',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle}) {
    final theme = Theme.of(context);
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 52, color: theme.colorScheme.outlineVariant),
        const SizedBox(height: 12),
        Text(title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(subtitle,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline)),
        ],
      ]),
    );
  }

  String _hs(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final String badge;
  final bool expanded;
  final VoidCallback onToggle;

  const _SectionHeader({
    required this.label,
    required this.badge,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: onToggle,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF0F1923)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          border: Border(
            bottom: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.4)),
          ),
        ),
        child: Row(
          children: [
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badge,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Compact scanner row ────────────────────────────────────────────────────────

class _ScannerRow extends StatelessWidget {
  final _Def def;
  final bool enabled;
  final ValueChanged<bool> onToggle;

  const _ScannerRow(
      {required this.def, required this.enabled, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () => onToggle(!enabled),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        color: enabled
            ? (isDark
                ? def.color.withValues(alpha: 0.08)
                : def.color.withValues(alpha: 0.05))
            : Colors.transparent,
        child: Row(
          children: [
            // Colored icon
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: enabled
                    ? def.color
                    : def.color.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Icon(def.icon,
                  size: 14,
                  color: enabled
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.6)),
            ),
            const SizedBox(width: 8),
            // Name + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    def.name,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: enabled
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface
                              .withValues(alpha: 0.45),
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    def.sub,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.6),
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Switch
            Transform.scale(
              scale: 0.70,
              child: Switch(
                value: enabled,
                onChanged: onToggle,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                activeColor: def.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mini tag ───────────────────────────────────────────────────────────────────

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
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 9, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
