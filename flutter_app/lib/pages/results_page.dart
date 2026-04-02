import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/scan_provider.dart';
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

  Widget _buildToolbar(BuildContext context, ScanProvider scan) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Scan Results',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (scan.state == ScanState.done) ...[
                const SizedBox(width: 12),
                Chip(
                  label: Text(
                    '${scan.totalCount} items',
                    style: theme.textTheme.labelSmall,
                  ),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
              const Spacer(),
              if (scan.state == ScanState.done) ...[
                TextButton.icon(
                  onPressed: () => scan.selectAll(true),
                  icon: const Icon(Icons.select_all, size: 18),
                  label: const Text('Select All'),
                ),
                TextButton.icon(
                  onPressed: () => scan.selectAll(false),
                  icon: const Icon(Icons.deselect, size: 18),
                  label: const Text('None'),
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
                      hintText: 'Search by path, package, scanner...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                scan.setSearch('');
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
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
    return Row(
      children: [
        Text('Sort:', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: scan.sortBy,
          isDense: true,
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
            size: 18,
          ),
          onPressed: () => scan.setSort(scan.sortBy, !scan.sortAscending),
          tooltip: scan.sortAscending ? 'Ascending' : 'Descending',
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, ScanProvider scan) {
    switch (scan.state) {
      case ScanState.idle:
        return _buildEmptyState(context,
            icon: Icons.search,
            title: 'No scan yet',
            subtitle: 'Go to the Home tab and click "Start Scan" to begin.');

      case ScanState.scanning:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Scanning ${scan.progress}...'),
            ],
          ),
        );

      case ScanState.error:
        return _buildEmptyState(context,
            icon: Icons.error_outline,
            title: 'Scan failed',
            subtitle: scan.error ?? 'Unknown error');

      case ScanState.done:
        final items = scan.filteredItems;
        if (items.isEmpty) {
          return _buildEmptyState(context,
              icon: Icons.cleaning_services,
              title: scan.searchQuery.isNotEmpty
                  ? 'No items match your search'
                  : 'Nothing to clean!',
              subtitle: scan.searchQuery.isNotEmpty
                  ? 'Try adjusting your search query.'
                  : 'Your dev environment is tidy.');
        }
        return _buildItemList(context, scan, items);
    }
  }

  Widget _buildItemList(
      BuildContext context, ScanProvider scan, List<CleanItem> items) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildItemTile(context, scan, item, index);
      },
    );
  }

  Widget _buildItemTile(
      BuildContext context, ScanProvider scan, CleanItem item, int index) {
    final theme = Theme.of(context);

    Color typeColor(String type) {
      switch (type) {
        case 'cache':
          return Colors.blue;
        case 'build_artifact':
          return Colors.orange;
        case 'old_version':
          return Colors.purple;
        case 'node_modules':
          return Colors.green;
        case 'invalid_env_var':
        case 'invalid_path_entry':
          return Colors.red;
        case 'dump_file':
          return Colors.brown;
        default:
          return Colors.grey;
      }
    }

    return CheckboxListTile(
      value: item.selected,
      onChanged: (_) => scan.toggleItem(item),
      title: Row(
        children: [
          Expanded(
            child: Text(
              item.packageName != null
                  ? '${item.packageName}${item.version != null ? " (${item.version})" : ""}'
                  : item.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: typeColor(item.itemType).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: typeColor(item.itemType).withValues(alpha: 0.5)),
            ),
            child: Text(
              item.itemType.replaceAll('_', ' '),
              style: theme.textTheme.labelSmall?.copyWith(
                color: typeColor(item.itemType),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              item.humanSize,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          Icon(Icons.folder_outlined,
              size: 12, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              item.path,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.scanner,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
    );
  }

  Widget _buildBottomBar(BuildContext context, ScanProvider scan) {
    final theme = Theme.of(context);

    String humanSize(int bytes) {
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      if (bytes < 1024 * 1024 * 1024) {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            '${scan.selectedCount} items selected  •  ${humanSize(scan.selectedSize)} will be freed',
            style: theme.textTheme.bodyMedium,
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: () => _confirmDelete(context, scan),
            icon: const Icon(Icons.delete_sweep, size: 18),
            label: Text(
              'Delete ${scan.selectedCount} items (${humanSize(scan.selectedSize)})',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
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
        title: const Text('Confirm Deletion'),
        content: Text(
          'Delete ${scan.selectedCount} items and free '
          '${_humanSize(scan.selectedSize)}?\n\n'
          'This action cannot be undone.',
        ),
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
    if (confirmed == true && context.mounted) {
      scan.deleteSelected();
    }
  }

  Widget _buildDeleteOverlay(BuildContext context, ScanProvider scan) {
    final theme = Theme.of(context);
    final progress =
        scan.deleteTotal > 0 ? scan.deleteProgress / scan.deleteTotal : null;

    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Deleting Files...',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 320,
                  child: LinearProgressIndicator(value: progress),
                ),
                const SizedBox(height: 8),
                Text(
                  '${scan.deleteProgress} / ${scan.deleteTotal} files  •  ${_humanSize(scan.freedBytes)} freed',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text(title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
          const SizedBox(height: 8),
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
