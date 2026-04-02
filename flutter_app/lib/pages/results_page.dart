import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/scan_provider.dart';
import '../providers/config_provider.dart';
import '../models/rpc_types.dart';

class ResultsPage extends StatefulWidget {
  const ResultsPage({super.key});

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ScanProvider>(
      builder: (context, scan, _) {
        return Stack(
          children: [
            Column(
              children: [
                _buildToolbar(context, scan),
                Expanded(child: _buildContent(context, scan)),
                if (scan.selectedCount > 0) _buildBottomBar(context, scan),
              ],
            ),
            if (scan.isDeleting) _buildDeleteOverlay(context, scan),
          ],
        );
      },
    );
  }

  // ── Toolbar ───────────────────────────────────────────────────────────────

  Widget _buildToolbar(BuildContext context, ScanProvider scan) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF14202E)
            : theme.colorScheme.surfaceContainer,
        border: Border(
            bottom: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.5))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Results',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (scan.state == ScanState.done) ...[
                const SizedBox(width: 10),
                _Chip(
                    label:
                        '${scan.filteredItems.length} / ${scan.totalCount}'),
                const SizedBox(width: 6),
                _Chip(
                    label: _humanSize(scan.totalSize),
                    color: theme.colorScheme.tertiary),
              ],
              const Spacer(),
              if (scan.state == ScanState.done) ...[
                TextButton.icon(
                  onPressed: () => scan.selectAll(true),
                  icon: const Icon(Icons.select_all, size: 16),
                  label: const Text('All'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => scan.selectAll(false),
                  icon: const Icon(Icons.deselect, size: 16),
                  label: const Text('None'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ],
          ),
          if (scan.state == ScanState.done) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by path, package, scanner…',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                scan.setSearch('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    onChanged: scan.setSearch,
                  ),
                ),
                const SizedBox(width: 12),
                _buildSortControls(context, scan),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSortControls(BuildContext context, ScanProvider scan) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text('Sort:',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
        const SizedBox(width: 6),
        DropdownButton<String>(
          value: scan.sortBy,
          isDense: true,
          borderRadius: BorderRadius.circular(8),
          items: const [
            DropdownMenuItem(value: 'size', child: Text('Size')),
            DropdownMenuItem(value: 'name', child: Text('Name')),
            DropdownMenuItem(value: 'scanner', child: Text('Scanner')),
            DropdownMenuItem(value: 'type', child: Text('Type')),
          ],
          onChanged: (v) {
            if (v != null) scan.setSort(v, scan.sortAscending);
          },
        ),
        IconButton(
          icon: Icon(
            scan.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
            size: 16,
          ),
          onPressed: () => scan.setSort(scan.sortBy, !scan.sortAscending),
          tooltip: scan.sortAscending ? 'Ascending' : 'Descending',
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  // ── Content ───────────────────────────────────────────────────────────────

  Widget _buildContent(BuildContext context, ScanProvider scan) {
    switch (scan.state) {
      case ScanState.idle:
        return _buildEmptyState(context,
            icon: Icons.manage_search_rounded,
            title: 'No scan yet',
            subtitle: 'Go to Home and click "Start Scan" to begin.');

      case ScanState.scanning:
        return _buildEmptyState(context,
            icon: Icons.hourglass_top_rounded,
            title: 'Scan in progress',
            subtitle: 'Results will appear here when done.');

      case ScanState.error:
        return _buildEmptyState(context,
            icon: Icons.error_outline,
            title: 'Scan failed',
            subtitle: scan.error ?? 'Unknown error');

      case ScanState.done:
        final items = scan.filteredItems;
        if (items.isEmpty) {
          return _buildEmptyState(context,
              icon: Icons.cleaning_services_rounded,
              title: scan.searchQuery.isNotEmpty
                  ? 'No items match your search'
                  : 'Nothing to clean!',
              subtitle: scan.searchQuery.isNotEmpty
                  ? 'Try a different search query.'
                  : 'Your dev environment is tidy 🎉');
        }
        return _buildItemList(context, scan, items);
    }
  }

  Widget _buildItemList(
      BuildContext context, ScanProvider scan, List<CleanItem> items) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 56,
        endIndent: 16,
        color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
      ),
      itemBuilder: (context, index) {
        return _buildItemTile(context, scan, items[index]);
      },
    );
  }

  Widget _buildItemTile(
      BuildContext context, ScanProvider scan, CleanItem item) {
    final theme = Theme.of(context);

    Color typeColor(String type) {
      return switch (type) {
        'cache' => const Color(0xFF1E88E5),
        'build_artifact' => const Color(0xFFF57C00),
        'old_version' => const Color(0xFF8E24AA),
        'node_modules' => const Color(0xFF43A047),
        'invalid_env_var' || 'invalid_path_entry' => const Color(0xFFE53935),
        'dump_file' => const Color(0xFF6D4C41),
        'temp_directory' => const Color(0xFF00897B),
        _ => Colors.grey,
      };
    }

    return GestureDetector(
      onSecondaryTapUp: (details) =>
          _showContextMenu(context, scan, item, details.globalPosition),
      child: CheckboxListTile(
        value: item.selected,
        onChanged: (_) => scan.toggleItem(item),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.packageName != null
                    ? '${item.packageName}'
                        '${item.version != null ? "  ${item.version}" : ""}'
                    : item.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _TypeTag(
              label: item.itemType.replaceAll('_', ' '),
              color: typeColor(item.itemType),
            ),
            const SizedBox(width: 6),
            _SizeTag(size: item.humanSize, theme: theme),
          ],
        ),
        subtitle: Row(
          children: [
            Icon(Icons.folder_outlined,
                size: 11,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
            const SizedBox(width: 4),
            Expanded(
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
            const SizedBox(width: 8),
            Text(
              item.scanner,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
        shape: const RoundedRectangleBorder(),
      ),
    );
  }

  // ── Right-click context menu ───────────────────────────────────────────────

  Future<void> _showContextMenu(
    BuildContext context,
    ScanProvider scan,
    CleanItem item,
    Offset globalPosition,
  ) async {
    final config = context.read<ConfigProvider>();
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 8,
      items: [
        PopupMenuItem(
          value: 'explorer',
          child: Row(
            children: [
              Icon(Icons.folder_open_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 10),
              const Text('Open in Explorer'),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          value: 'whitelist',
          child: Row(
            children: [
              Icon(Icons.playlist_add_check,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              const Text('Add to whitelist'),
            ],
          ),
        ),
      ],
    );

    if (!context.mounted) return;

    switch (result) {
      case 'explorer':
        _openInExplorer(item.path);
      case 'whitelist':
        await _addToWhitelist(context, config, scan, item);
    }
  }

  void _openInExplorer(String path) {
    final type = FileSystemEntity.typeSync(path);
    if (type == FileSystemEntityType.directory) {
      Process.run('explorer.exe', [path]);
    } else {
      // Select file in its parent folder
      Process.run('explorer.exe', ['/select,', path]);
    }
  }

  Future<void> _addToWhitelist(
    BuildContext context,
    ConfigProvider config,
    ScanProvider scan,
    CleanItem item,
  ) async {
    // Escape the path as a regex literal so it matches exactly
    final escaped = item.path.replaceAllMapped(
      RegExp(r'[.*+?^${}()|[\]\\]'),
      (m) => '\\${m[0]}',
    );
    config.addWhitelistPattern(escaped);
    try {
      await config.saveToFile();
    } catch (_) {
      // Non-fatal — pattern is still in-memory
    }
    scan.removeItem(item);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added to whitelist and removed from results.',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onInverseSurface),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // ── Bottom action bar ──────────────────────────────────────────────────────

  Widget _buildBottomBar(BuildContext context, ScanProvider scan) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border(
            top: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              size: 15, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            '${scan.selectedCount} selected  •  ${_humanSize(scan.selectedSize)} will be freed',
            style: theme.textTheme.bodySmall,
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: () => _confirmDelete(context, scan),
            icon: const Icon(Icons.delete_sweep, size: 16),
            label: Text(
              'Delete ${scan.selectedCount} items',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, ScanProvider scan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Confirm Deletion'),
          ],
        ),
        content: Text(
          'Delete ${scan.selectedCount} items and free ${_humanSize(scan.selectedSize)}?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
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
      scan.deleteSelected();
    }
  }

  // ── Delete overlay ─────────────────────────────────────────────────────────

  Widget _buildDeleteOverlay(BuildContext context, ScanProvider scan) {
    final theme = Theme.of(context);
    final progress =
        scan.deleteTotal > 0 ? scan.deleteProgress / scan.deleteTotal : null;

    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Card(
          elevation: 20,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text('Deleting Files…',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                SizedBox(
                  width: 300,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                        value: progress, minHeight: 6),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${scan.deleteProgress} / ${scan.deleteTotal} items  •  '
                  '${_humanSize(scan.freedBytes)} freed',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle}) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 60,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7)),
          const SizedBox(height: 16),
          Text(title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 6),
          Text(subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              )),
        ],
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

// ── Small reusable tag widgets ─────────────────────────────────────────────────

class _TypeTag extends StatelessWidget {
  final String label;
  final Color color;
  const _TypeTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _SizeTag extends StatelessWidget {
  final String size;
  final ThemeData theme;
  const _SizeTag({required this.size, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        size,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color? color;
  const _Chip({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: c,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
