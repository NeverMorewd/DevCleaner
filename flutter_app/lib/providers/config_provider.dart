import 'package:flutter/foundation.dart';
import '../services/daemon_service.dart';

class ConfigProvider extends ChangeNotifier {
  final DaemonService _daemon;
  Map<String, dynamic> _config = {};
  bool _loading = true;
  String? _error;

  ConfigProvider(this._daemon) {
    _load();
  }

  Map<String, dynamic> get config => _config;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> _load() async {
    try {
      final resp = await _daemon.getConfig();
      if (resp['result'] != null) {
        _config = Map<String, dynamic>.from(resp['result'] as Map);
      }
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> reload() async {
    _loading = true;
    _error = null;
    notifyListeners();
    await _load();
  }

  Future<void> save(Map<String, dynamic> newConfig) async {
    final resp = await _daemon.setConfig(newConfig);
    if (resp['result'] != null) {
      _config = newConfig;
      notifyListeners();
    } else if (resp['error'] != null) {
      throw Exception((resp['error'] as Map)['message']);
    }
  }

  void updateScanner(String key, bool value) {
    final scanners =
        Map<String, dynamic>.from(_config['scanners'] as Map? ?? {});
    scanners[key] = value;
    _config = Map<String, dynamic>.from(_config)..['scanners'] = scanners;
    notifyListeners();
  }

  void updateArtifact(String key, bool value) {
    final artifacts =
        Map<String, dynamic>.from(_config['artifacts'] as Map? ?? {});
    artifacts[key] = value;
    _config = Map<String, dynamic>.from(_config)..['artifacts'] = artifacts;
    notifyListeners();
  }

  void addWhitelistPattern(String pattern) {
    final filter =
        Map<String, dynamic>.from(_config['filter'] as Map? ?? {});
    final patterns =
        List<String>.from(filter['whitelist_patterns'] as List? ?? []);
    if (!patterns.contains(pattern)) {
      patterns.add(pattern);
      filter['whitelist_patterns'] = patterns;
      _config = Map<String, dynamic>.from(_config)..['filter'] = filter;
      notifyListeners();
    }
  }

  void removeWhitelistPattern(String pattern) {
    final filter =
        Map<String, dynamic>.from(_config['filter'] as Map? ?? {});
    final patterns =
        List<String>.from(filter['whitelist_patterns'] as List? ?? []);
    patterns.remove(pattern);
    filter['whitelist_patterns'] = patterns;
    _config = Map<String, dynamic>.from(_config)..['filter'] = filter;
    notifyListeners();
  }

  void addProjectRoot(String path) {
    final artifacts =
        Map<String, dynamic>.from(_config['artifacts'] as Map? ?? {});
    final roots = List<String>.from(artifacts['project_roots'] as List? ?? []);
    if (!roots.contains(path)) {
      roots.add(path);
      artifacts['project_roots'] = roots;
      _config = Map<String, dynamic>.from(_config)..['artifacts'] = artifacts;
      notifyListeners();
    }
  }

  void removeProjectRoot(String path) {
    final artifacts =
        Map<String, dynamic>.from(_config['artifacts'] as Map? ?? {});
    final roots = List<String>.from(artifacts['project_roots'] as List? ?? []);
    roots.remove(path);
    artifacts['project_roots'] = roots;
    _config = Map<String, dynamic>.from(_config)..['artifacts'] = artifacts;
    notifyListeners();
  }

  List<String> get whitelistPatterns {
    final filter = _config['filter'] as Map? ?? {};
    return List<String>.from(filter['whitelist_patterns'] as List? ?? []);
  }

  List<String> get projectRoots {
    final artifacts = _config['artifacts'] as Map? ?? {};
    return List<String>.from(artifacts['project_roots'] as List? ?? []);
  }

  Map<String, bool> get scanners {
    final s = _config['scanners'] as Map? ?? {};
    return s.map((k, v) => MapEntry(k.toString(), v as bool? ?? false));
  }

  Map<String, bool> get artifacts {
    final a = _config['artifacts'] as Map? ?? {};
    return a
        .entries
        .where((e) => e.value is bool)
        .fold({}, (map, e) {
      map[e.key.toString()] = e.value as bool;
      return map;
    });
  }

  Future<void> saveToFile() async {
    await save(_config);
  }
}
