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

  Map<String, bool> get envVarsOptions {
    final o = _config['env_vars_options'] as Map? ?? {};
    return {
      'check_invalid_values': o['check_invalid_values'] as bool? ?? true,
      'check_path_entries': o['check_path_entries'] as bool? ?? true,
    };
  }

  void updateEnvVarsOption(String key, bool value) {
    final opts =
        Map<String, dynamic>.from(_config['env_vars_options'] as Map? ?? {});
    opts[key] = value;
    _config =
        Map<String, dynamic>.from(_config)..['env_vars_options'] = opts;
    notifyListeners();
  }

  Map<String, bool> get windowsTempOptions {
    final o = _config['windows_temp_options'] as Map? ?? {};
    return {
      'user_temp':   o['user_temp']   as bool? ?? true,
      'system_temp': o['system_temp'] as bool? ?? true,
      'prefetch':    o['prefetch']    as bool? ?? true,
      'wu_download': o['wu_download'] as bool? ?? true,
      'inet_cache':  o['inet_cache']  as bool? ?? true,
      'wer':         o['wer']         as bool? ?? true,
    };
  }

  void updateWindowsTempOption(String key, bool value) {
    final opts = Map<String, dynamic>.from(
        _config['windows_temp_options'] as Map? ?? {});
    opts[key] = value;
    _config =
        Map<String, dynamic>.from(_config)..['windows_temp_options'] = opts;
    notifyListeners();
  }

  Map<String, bool> get ideCacheOptions {
    final o = _config['ide_cache_options'] as Map? ?? {};
    return {
      'jetbrains': o['jetbrains'] as bool? ?? true,
      'vscode': o['vscode'] as bool? ?? true,
    };
  }

  void updateIdeCacheOption(String key, bool value) {
    final opts =
        Map<String, dynamic>.from(_config['ide_cache_options'] as Map? ?? {});
    opts[key] = value;
    _config =
        Map<String, dynamic>.from(_config)..['ide_cache_options'] = opts;
    notifyListeners();
  }

  Map<String, bool> get browserCacheOptions {
    final o = _config['browser_cache_options'] as Map? ?? {};
    return {
      'chrome': o['chrome'] as bool? ?? true,
      'edge': o['edge'] as bool? ?? true,
      'firefox': o['firefox'] as bool? ?? true,
    };
  }

  void updateBrowserCacheOption(String key, bool value) {
    final opts = Map<String, dynamic>.from(
        _config['browser_cache_options'] as Map? ?? {});
    opts[key] = value;
    _config =
        Map<String, dynamic>.from(_config)..['browser_cache_options'] = opts;
    notifyListeners();
  }

  Map<String, bool> get dumpFilesOptions {
    final o = _config['dump_files_options'] as Map? ?? {};
    return {
      'wer': o['wer'] as bool? ?? true,
      'crash_dumps': o['crash_dumps'] as bool? ?? true,
      'minidumps': o['minidumps'] as bool? ?? true,
    };
  }

  void updateDumpFilesOption(String key, bool value) {
    final opts =
        Map<String, dynamic>.from(_config['dump_files_options'] as Map? ?? {});
    opts[key] = value;
    _config =
        Map<String, dynamic>.from(_config)..['dump_files_options'] = opts;
    notifyListeners();
  }

  Map<String, bool> get androidSdkOptions {
    final o = _config['android_sdk_options'] as Map? ?? {};
    return {
      'old_platforms': o['old_platforms'] as bool? ?? true,
      'old_build_tools': o['old_build_tools'] as bool? ?? true,
      'system_images': o['system_images'] as bool? ?? true,
      'emulator': o['emulator'] as bool? ?? true,
    };
  }

  void updateAndroidSdkOption(String key, bool value) {
    final opts = Map<String, dynamic>.from(
        _config['android_sdk_options'] as Map? ?? {});
    opts[key] = value;
    _config =
        Map<String, dynamic>.from(_config)..['android_sdk_options'] = opts;
    notifyListeners();
  }

  Future<void> saveToFile() async {
    await save(_config);
  }
}
