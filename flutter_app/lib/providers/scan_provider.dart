import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/daemon_service.dart';
import '../models/rpc_types.dart';

enum ScanState { idle, scanning, done, error }

// ── Delete-error models ────────────────────────────────────────────────────────

class LockingProcess {
  final int pid;
  final String name;
  const LockingProcess({required this.pid, required this.name});

  factory LockingProcess.fromJson(Map<String, dynamic> j) =>
      LockingProcess(pid: (j['pid'] as num).toInt(), name: j['name'] as String);
}

class DeleteError {
  final String path;
  final String message;
  final bool accessDenied;
  final List<LockingProcess> lockingProcesses;

  const DeleteError({
    required this.path,
    required this.message,
    required this.accessDenied,
    required this.lockingProcesses,
  });

  factory DeleteError.fromJson(Map<String, dynamic> j) => DeleteError(
        path: j['path'] as String? ?? '',
        message: j['message'] as String? ?? 'Unknown error',
        accessDenied: j['access_denied'] as bool? ?? false,
        lockingProcesses: (j['locking_processes'] as List<dynamic>? ?? [])
            .map((e) => LockingProcess.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ── Provider ───────────────────────────────────────────────────────────────────

class ScanProvider extends ChangeNotifier {
  final DaemonService _daemon;
  ScanState _state = ScanState.idle;
  List<ScanResultGroup> _groups = [];
  String? _scanId;
  String _progress = '';
  int _scannersDone = 0;
  int _scannersTotal = 0;
  String? _error;
  bool _isDeleting = false;
  int _deleteProgress = 0;
  int _deleteTotal = 0;
  int _freedBytes = 0;
  String _searchQuery = '';
  String _sortBy = 'size';
  bool _sortAscending = false;

  /// Errors from the most recent deleteSelected() call.
  List<DeleteError> _lastDeleteErrors = [];

  StreamSubscription<Map<String, dynamic>>? _scanProgressSub;

  ScanProvider(this._daemon) {
    _scanProgressSub = _daemon.scanProgress.listen(_onScanProgress);
  }

  ScanState get state => _state;
  List<ScanResultGroup> get groups => _groups;
  String get progress => _progress;
  int get scannersDone => _scannersDone;
  int get scannersTotal => _scannersTotal;
  String? get error => _error;
  bool get isDeleting => _isDeleting;
  int get deleteProgress => _deleteProgress;
  int get deleteTotal => _deleteTotal;
  int get freedBytes => _freedBytes;
  String get searchQuery => _searchQuery;
  String get sortBy => _sortBy;
  bool get sortAscending => _sortAscending;
  String? get scanId => _scanId;
  List<DeleteError> get lastDeleteErrors => _lastDeleteErrors;

  List<CleanItem> get allItems =>
      _groups.expand((g) => g.items).toList();

  List<CleanItem> get filteredItems {
    var items = allItems;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items
          .where((item) =>
              item.path.toLowerCase().contains(q) ||
              item.description.toLowerCase().contains(q) ||
              item.scanner.toLowerCase().contains(q) ||
              (item.packageName?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    items.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case 'name':
          cmp = (a.packageName ?? a.description)
              .compareTo(b.packageName ?? b.description);
        case 'scanner':
          cmp = a.scanner.compareTo(b.scanner);
        case 'type':
          cmp = a.itemType.compareTo(b.itemType);
        default: // size
          cmp = a.size.compareTo(b.size);
      }
      return _sortAscending ? cmp : -cmp;
    });
    return items;
  }

  int get selectedCount => allItems.where((i) => i.selected).length;
  int get selectedSize =>
      allItems.where((i) => i.selected).fold(0, (s, i) => s + i.size);
  int get totalSize => allItems.fold(0, (s, i) => s + i.size);
  int get totalCount => allItems.length;

  void setSearch(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void setSort(String by, bool ascending) {
    _sortBy = by;
    _sortAscending = ascending;
    notifyListeners();
  }

  void selectAll(bool val) {
    for (final i in filteredItems) {
      i.selected = val;
    }
    notifyListeners();
  }

  void toggleItem(CleanItem item) {
    item.selected = !item.selected;
    notifyListeners();
  }

  /// Remove a single item from results (e.g. after adding to whitelist).
  void removeItem(CleanItem item) {
    for (final group in _groups) {
      group.items.remove(item);
    }
    _groups.removeWhere((g) => g.items.isEmpty);
    notifyListeners();
  }

  void _onScanProgress(Map<String, dynamic> params) {
    _progress = params['scanner_name'] as String? ?? '';
    _scannersDone = (params['scanners_done'] as num? ?? 0).toInt();
    _scannersTotal = (params['scanners_total'] as num? ?? 0).toInt();
    notifyListeners();
  }

  Future<void> startScan() async {
    _state = ScanState.scanning;
    _groups = [];
    _error = null;
    _scannersDone = 0;
    _scannersTotal = 0;
    _progress = '';
    notifyListeners();

    try {
      final resp = await _daemon.startScan();
      if (resp.containsKey('error') && resp['error'] != null) {
        final err = resp['error'] as Map<String, dynamic>;
        _error = err['message'] as String?;
        _state = ScanState.error;
      } else {
        final result = resp['result'] as Map<String, dynamic>? ?? {};
        _scanId = result['scan_id'] as String?;
        _groups = (result['results'] as List<dynamic>? ?? [])
            .map((e) => ScanResultGroup.fromJson(e as Map<String, dynamic>))
            .toList();
        _state = ScanState.done;
      }
    } catch (e) {
      _error = e.toString();
      _state = ScanState.error;
    }
    notifyListeners();
  }

  void abortScan() {
    _daemon.abortScan();
  }

  Future<void> deleteSelected() async {
    final selected = allItems.where((i) => i.selected).toList();
    if (selected.isEmpty || _scanId == null) return;

    _isDeleting = true;
    _deleteProgress = 0;
    _deleteTotal = selected.length;
    _freedBytes = 0;
    _lastDeleteErrors = [];
    notifyListeners();

    // Track which paths succeed via progress notifications
    final successPaths = <String>{};
    final subscription = _daemon.deleteProgress.listen((params) {
      _deleteProgress = (params['items_done'] as num? ?? 0).toInt();
      _freedBytes = (params['freed_bytes'] as num? ?? 0).toInt();
      // A null 'error' field means this item was deleted successfully
      if (params['error'] == null) {
        final p = params['path'] as String?;
        if (p != null) successPaths.add(p);
      }
      notifyListeners();
    });

    try {
      final paths = selected.map((i) => i.path).toList();
      final resp = await _daemon.deleteItems(_scanId!, paths);

      // Parse errors from final response
      final result = resp['result'] as Map<String, dynamic>? ?? {};
      final rawErrors = result['errors'] as List<dynamic>? ?? [];
      _lastDeleteErrors = rawErrors
          .map((e) => DeleteError.fromJson(e as Map<String, dynamic>))
          .toList();

      // Remove only successfully deleted items from the result list
      final failedPaths = _lastDeleteErrors.map((e) => e.path).toSet();
      for (final group in _groups) {
        group.items.removeWhere(
            (item) => paths.contains(item.path) && !failedPaths.contains(item.path));
      }
      _groups.removeWhere((g) => g.items.isEmpty);
    } finally {
      await subscription.cancel();
      _isDeleting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _scanProgressSub?.cancel();
    super.dispose();
  }
}
