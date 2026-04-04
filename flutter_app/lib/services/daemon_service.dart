import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class DaemonService extends ChangeNotifier {
  Process? _process;
  int _nextId = 1;
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  final _scanProgressController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _scanItemsController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _deleteProgressController =
      StreamController<Map<String, dynamic>>.broadcast();

  String? _startError;

  Stream<Map<String, dynamic>> get scanProgress =>
      _scanProgressController.stream;
  /// Emitted once per scanner as soon as that scanner finishes.
  Stream<Map<String, dynamic>> get scanItems => _scanItemsController.stream;
  Stream<Map<String, dynamic>> get deleteProgress =>
      _deleteProgressController.stream;

  bool get isConnected => _process != null;

  /// Set when the daemon process could not be started.
  String? get startError => _startError;
  void setStartError(String msg) {
    _startError = msg;
    notifyListeners();
  }

  Future<void> start() async {
    final exe = _locateExe();
    _process = await Process.start(exe, ['--daemon']);
    _process!.stderr
        .transform(utf8.decoder)
        .listen((msg) => debugPrint('[daemon stderr] $msg'));
    _process!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleLine, onDone: _onProcessDone);
    notifyListeners();
  }

  void _handleLine(String line) {
    if (line.trim().isEmpty) return;
    final Map<String, dynamic> msg;
    try {
      msg = jsonDecode(line) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[daemon] invalid JSON: $line');
      return;
    }

    // Notification (no id field, has "method")
    if (!msg.containsKey('id') && msg.containsKey('method')) {
      final method = msg['method'] as String?;
      final params = msg['params'] as Map<String, dynamic>? ?? {};
      if (method == 'scan_progress') _scanProgressController.add(params);
      if (method == 'scan_items')    _scanItemsController.add(params);
      if (method == 'delete_progress') _deleteProgressController.add(params);
      return;
    }

    // Response (has id)
    final rawId = msg['id'];
    if (rawId != null) {
      final id = (rawId as num).toInt();
      final completer = _pending.remove(id);
      if (completer != null) completer.complete(msg);
    }
  }

  void _onProcessDone() {
    _process = null;
    for (final c in _pending.values) {
      c.completeError(Exception('Daemon process exited'));
    }
    _pending.clear();
    notifyListeners();
  }

  Future<Map<String, dynamic>> _call(String method, [dynamic params]) async {
    if (_process == null) {
      throw Exception('Daemon not running');
    }
    final id = _nextId++;
    final req = {
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      if (params != null) 'params': params,
    };
    final line = '${jsonEncode(req)}\n';
    _process!.stdin.write(line);
    await _process!.stdin.flush();
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    return completer.future;
  }

  void _notify(String method, [dynamic params]) {
    if (_process == null) return;
    final req = {
      'jsonrpc': '2.0',
      'method': method,
      if (params != null) 'params': params,
    };
    _process!.stdin.writeln(jsonEncode(req));
  }

  Future<Map<String, dynamic>> getConfig() => _call('get_config');

  Future<Map<String, dynamic>> setConfig(Map<String, dynamic> config) =>
      _call('set_config', config);

  Future<Map<String, dynamic>> startScan() =>
      _call('start_scan').timeout(const Duration(hours: 1));

  Future<Map<String, dynamic>> deleteItems(
          String scanId, List<String> paths) =>
      _call('delete_items', {'scan_id': scanId, 'paths': paths})
          .timeout(const Duration(hours: 1));

  void abortScan() => _notify('abort_scan');

  String _locateExe() {
    // 1. Environment variable override
    final env = Platform.environment['DEVCLEANER_EXE'];
    if (env != null && File(env).existsSync()) return env;

    // 2. Same directory as this Flutter exe (release mode)
    final runnerDir = File(Platform.resolvedExecutable).parent;
    final sameDir = File(p.join(runnerDir.path, 'devcleaner.exe'));
    if (sameDir.existsSync()) return sameDir.path;

    // 3. Debug mode: walk up from runner dir to repo root
    // flutter_app\build\windows\x64\runner\Debug\ -> up levels -> repo root
    var dir = runnerDir;
    for (var i = 0; i < 8; i++) {
      final candidate =
          File(p.join(dir.path, 'target', 'debug', 'devcleaner.exe'));
      if (candidate.existsSync()) return candidate.path;
      final candidateRelease =
          File(p.join(dir.path, 'target', 'release', 'devcleaner.exe'));
      if (candidateRelease.existsSync()) return candidateRelease.path;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }

    throw StateError(
      'Cannot find devcleaner.exe. Set DEVCLEANER_EXE environment variable '
      'or place devcleaner.exe next to the Flutter executable.',
    );
  }

  @override
  void dispose() {
    _process?.kill();
    _scanProgressController.close();
    _scanItemsController.close();
    _deleteProgressController.close();
    super.dispose();
  }
}
