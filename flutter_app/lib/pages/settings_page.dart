import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/config_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _rootController = TextEditingController();
  final _patternController = TextEditingController();
  String? _patternError;
  bool _saving = false;
  String? _saveError;
  String? _saveSuccess;

  @override
  void dispose() {
    _rootController.dispose();
    _patternController.dispose();
    super.dispose();
  }

  bool _validatePattern(String pattern) {
    try {
      RegExp(pattern);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConfigProvider>(
      builder: (context, config, _) {
        if (config.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildScannersSection(context, config),
                  const SizedBox(height: 24),
                  _buildArtifactsSection(context, config),
                  const SizedBox(height: 24),
                  _buildProjectRootsSection(context, config),
                  const SizedBox(height: 24),
                  _buildWhitelistSection(context, config),
                  const SizedBox(height: 32),
                  _buildSaveButton(context, config),
                  const SizedBox(height: 24),
                ],
              ),
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
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Text(
            'Settings',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (_saveSuccess != null)
            Text(
              _saveSuccess!,
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          if (_saveError != null)
            Text(
              _saveError!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title, {String? subtitle}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        if (subtitle != null)
          Text(subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildScannersSection(BuildContext context, ConfigProvider config) {
    final scanners = [
      ('nuget', 'NuGet (.NET)', 'Global NuGet package cache'),
      ('cargo', 'Cargo (Rust)', 'Cargo registry & git sources'),
      ('golang', 'Go Modules', 'Go module download cache'),
      ('node', 'Node.js (npm/yarn/pnpm)', 'Global Node package caches'),
      ('pip', 'pip / uv (Python)', 'pip & uv caches'),
      ('maven', 'Maven (Java)', 'Local Maven repository'),
      ('gradle', 'Gradle (Java)', 'Gradle caches and wrappers'),
      ('cpp_vcpkg', 'vcpkg (C++)', 'vcpkg package cache'),
      ('cpp_conan', 'Conan (C++)', 'Conan package cache'),
      ('build_artifacts', 'Build Artifacts', 'obj/, bin/, target/, build/'),
      ('env_vars', 'Env Vars', 'Invalid PATH & environment entries'),
      ('dump_files', 'Dump Files', '.dmp crash files & WER reports'),
      ('android_sdk', 'Android SDK', 'Old SDK components'),
      ('ide_cache', 'IDE Caches', 'VS Code, JetBrains caches'),
      ('windows_temp', 'Windows Temp', 'TEMP, Prefetch, Windows Update'),
      ('rustup', 'Rustup', 'Old toolchain versions'),
      ('browser_cache', 'Browser Cache', 'Chrome, Edge, Firefox, Brave'),
      ('flutter_pub', 'Flutter/Dart Pub', 'Pub package cache'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, 'Enabled Scanners',
                subtitle: 'Toggle which scanners run when you start a scan.'),
            ...scanners.map((entry) {
              final (key, label, desc) = entry;
              final enabled = config.scanners[key] ?? false;
              return SwitchListTile(
                value: enabled,
                onChanged: (v) => config.updateScanner(key, v),
                title: Text(label),
                subtitle: Text(desc,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant)),
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 0),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildArtifactsSection(BuildContext context, ConfigProvider config) {
    final artifactTypes = [
      ('scan_csharp_obj_bin', 'C# / .NET — obj/ bin/'),
      ('scan_rust_target', 'Rust — target/'),
      ('scan_node_modules', 'Node.js — node_modules/'),
      ('scan_frontend_dist', 'JS/TS — .next/ .nuxt/ .svelte-kit/ dist/'),
      ('scan_java_build', 'Java — Maven target/ Gradle build/'),
      ('scan_python_cache', 'Python — __pycache__/ .pytest_cache/ build/'),
      ('scan_cmake_build', 'C/C++ — CMakeFiles/ cmake-build-*/'),
      ('scan_flutter_build', 'Flutter — build/ .dart_tool/'),
      ('scan_go_vendor', 'Go — vendor/'),
    ];

    final arts = config.artifacts;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, 'Build Artifact Types',
                subtitle: 'Which artifact directories to include in scans.'),
            ...artifactTypes.map((entry) {
              final (key, label) = entry;
              final enabled = arts[key] ?? false;
              return CheckboxListTile(
                value: enabled,
                onChanged: (v) => config.updateArtifact(key, v ?? false),
                title: Text(label),
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                controlAffinity: ListTileControlAffinity.leading,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectRootsSection(BuildContext context, ConfigProvider config) {
    final roots = config.projectRoots;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, 'Project Roots',
                subtitle:
                    'Extra directories to scan for build artifacts (auto-discovery is always enabled).'),
            ...roots.map((root) => ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(root,
                      style: const TextStyle(fontFamily: 'monospace')),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => config.removeProjectRoot(root),
                    tooltip: 'Remove',
                    color: Theme.of(context).colorScheme.error,
                  ),
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                )),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _rootController,
                    decoration: const InputDecoration(
                      hintText: 'C:\\Users\\you\\projects',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () {
                    final path = _rootController.text.trim();
                    if (path.isNotEmpty) {
                      config.addProjectRoot(path);
                      _rootController.clear();
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhitelistSection(BuildContext context, ConfigProvider config) {
    final patterns = config.whitelistPatterns;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, 'Whitelist (Ignore Patterns)',
                subtitle:
                    'Regex patterns matched against full paths. Matching items are excluded from scan results.'),
            ...patterns.map((pattern) => ListTile(
                  leading: const Icon(Icons.block, size: 18),
                  title: Text(pattern,
                      style: const TextStyle(fontFamily: 'monospace')),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => config.removeWhitelistPattern(pattern),
                    tooltip: 'Remove',
                    color: Theme.of(context).colorScheme.error,
                  ),
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                )),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _patternController,
                        decoration: InputDecoration(
                          hintText: r'C:\\keep\\this\\path',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          isDense: true,
                          errorText: _patternError,
                        ),
                        onChanged: (_) {
                          if (_patternError != null) {
                            setState(() => _patternError = null);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () {
                    final pattern = _patternController.text.trim();
                    if (pattern.isEmpty) return;
                    if (!_validatePattern(pattern)) {
                      setState(() => _patternError = 'Invalid regex pattern');
                      return;
                    }
                    setState(() => _patternError = null);
                    config.addWhitelistPattern(pattern);
                    _patternController.clear();
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
            if (_patternController.text.isNotEmpty &&
                _patternError == null) ...[
              const SizedBox(height: 8),
              Text(
                'Pattern looks valid.',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context, ConfigProvider config) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _saving ? null : () => _save(context, config),
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save),
        label: const Text('Save Settings'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context, ConfigProvider config) async {
    setState(() {
      _saving = true;
      _saveError = null;
      _saveSuccess = null;
    });
    try {
      await config.saveToFile();
      if (mounted) {
        setState(() => _saveSuccess = 'Settings saved!');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _saveSuccess = null);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _saveError = 'Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
