class CleanItem {
  final String path;
  final int size;
  final String description;
  final String scanner;
  final String itemType;
  final String? packageName;
  final String? version;
  bool selected;

  CleanItem({
    required this.path,
    required this.size,
    required this.description,
    required this.scanner,
    required this.itemType,
    this.packageName,
    this.version,
    this.selected = true,
  });

  factory CleanItem.fromJson(Map<String, dynamic> json) => CleanItem(
        path: json['path'] as String,
        size: (json['size'] as num).toInt(),
        description: json['description'] as String? ?? '',
        scanner: json['scanner'] as String? ?? '',
        itemType: json['item_type'] as String? ?? 'cache',
        packageName: json['package_name'] as String?,
        version: json['version'] as String?,
      );

  String get humanSize => _formatBytes(size);
}

class ScanResultGroup {
  final String scannerName;
  final List<CleanItem> items;
  final int totalSize;
  final String? error;

  ScanResultGroup({
    required this.scannerName,
    required this.items,
    required this.totalSize,
    this.error,
  });

  factory ScanResultGroup.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? [])
        .map((e) => CleanItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return ScanResultGroup(
      scannerName: json['scanner_name'] as String,
      items: items,
      totalSize: (json['total_size'] as num? ?? 0).toInt(),
      error: json['error'] as String?,
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
