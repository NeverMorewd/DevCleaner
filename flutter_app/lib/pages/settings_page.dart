import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/config_provider.dart';

class SettingsPage extends StatefulWidget {
  /// Called whenever auto-save completes or fails.
  /// Passes null to clear the status.
  final void Function(String? status, bool isError)? onStatus;

  const SettingsPage({super.key, this.onStatus});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _rootCtrl    = TextEditingController();
  final _patternCtrl = TextEditingController();
  String? _patternError;
  Timer?  _saveTimer;

  @override
  void dispose() {
    _saveTimer?.cancel();
    _rootCtrl.dispose();
    _patternCtrl.dispose();
    super.dispose();
  }

  // ── Auto-save ─────────────────────────────────────────────────────────────

  /// Debounced save — used after toggle changes.
  void _scheduleSave(ConfigProvider config) {
    widget.onStatus?.call('Saving…', false);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), () {
      _doSave(config);
    });
  }

  /// Immediate save — used after add / remove actions.
  Future<void> _immediateSave(ConfigProvider config) async {
    _saveTimer?.cancel();
    widget.onStatus?.call('Saving…', false);
    await _doSave(config);
  }

  Future<void> _doSave(ConfigProvider config) async {
    try {
      await config.saveToFile();
      widget.onStatus?.call('Saved', false);
      // Clear status after 2 s
      Future.delayed(const Duration(seconds: 2), () {
        widget.onStatus?.call(null, false);
      });
    } catch (e) {
      widget.onStatus?.call('Save failed: $e', true);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<ConfigProvider>(
      builder: (context, config, _) {
        if (config.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            _buildArtifactsSection(context, config),
            const SizedBox(height: 12),
            _buildProjectRootsSection(context, config),
            const SizedBox(height: 12),
            _buildWhitelistSection(context, config),
          ],
        );
      },
    );
  }

  // ── Section wrapper ───────────────────────────────────────────────────────

  Widget _section(BuildContext context,
      {required String title,
      String? subtitle,
      required Widget child}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
              letterSpacing: 0.3,
            )),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
        ],
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  // ── Artifacts ─────────────────────────────────────────────────────────────

  Widget _buildArtifactsSection(BuildContext context, ConfigProvider config) {
    const artifacts = [
      ('scan_csharp_obj_bin', 'C# / .NET',    'obj/ bin/'),
      ('scan_rust_target',    'Rust',          'target/'),
      ('scan_node_modules',   'Node.js',       'node_modules/'),
      ('scan_frontend_dist',  'JS / TS',       '.next/ .nuxt/ dist/'),
      ('scan_java_build',     'Java',          'Maven target/ Gradle build/'),
      ('scan_python_cache',   'Python',        '__pycache__/ .pytest_cache/'),
      ('scan_cmake_build',    'C / C++',       'CMakeFiles/ cmake-build-*/'),
      ('scan_flutter_build',  'Flutter',       'build/ .dart_tool/'),
      ('scan_go_vendor',      'Go',            'vendor/'),
    ];

    final arts = config.artifacts;

    return _section(
      context,
      title: 'Build Artifact Types',
      subtitle: 'Which artifact directories to include when scanning.',
      child: _twoColGrid(
        children: artifacts.map((a) {
          final (key, label, desc) = a;
          final enabled = arts[key] ?? false;
          return _CompactCheckbox(
            label: label,
            description: desc,
            value: enabled,
            onChanged: (v) {
              config.updateArtifact(key, v);
              _scheduleSave(config);
            },
          );
        }).toList(),
      ),
    );
  }

  // ── Project roots ─────────────────────────────────────────────────────────

  Widget _buildProjectRootsSection(
      BuildContext context, ConfigProvider config) {
    final roots = config.projectRoots;
    return _section(
      context,
      title: 'Project Roots',
      subtitle:
          'Extra directories to scan for build artifacts (auto-discovery always enabled).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (roots.isEmpty)
            _emptyHint(context, 'No custom roots — using auto-discovery only.')
          else
            ...roots.map((root) => _ListRow(
                  label: root,
                  mono: true,
                  onDelete: () async {
                    config.removeProjectRoot(root);
                    await _immediateSave(config);
                  },
                )),
          const SizedBox(height: 6),
          _AddRow(
            controller: _rootCtrl,
            hint: r'C:\Users\you\projects',
            onAdd: () async {
              final p = _rootCtrl.text.trim();
              if (p.isEmpty) return;
              config.addProjectRoot(p);
              _rootCtrl.clear();
              await _immediateSave(config);
            },
          ),
        ],
      ),
    );
  }

  // ── Whitelist ─────────────────────────────────────────────────────────────

  Widget _buildWhitelistSection(
      BuildContext context, ConfigProvider config) {
    final patterns = config.whitelistPatterns;
    return _section(
      context,
      title: 'Whitelist  (Ignore Patterns)',
      subtitle:
          'Regex patterns matched against full paths. Matching items are excluded from results.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (patterns.isEmpty)
            _emptyHint(context, 'No patterns — all scanned items are shown.')
          else
            ...patterns.map((p) => _ListRow(
                  label: p,
                  mono: true,
                  onDelete: () async {
                    config.removeWhitelistPattern(p);
                    await _immediateSave(config);
                  },
                )),
          const SizedBox(height: 6),
          _AddRow(
            controller: _patternCtrl,
            hint: r'C:\\Users\\you\\keep\\this',
            errorText: _patternError,
            onAdd: () async {
              final p = _patternCtrl.text.trim();
              if (p.isEmpty) return;
              try {
                RegExp(p);
              } catch (_) {
                setState(() => _patternError = 'Invalid regex pattern');
                return;
              }
              setState(() => _patternError = null);
              config.addWhitelistPattern(p);
              _patternCtrl.clear();
              await _immediateSave(config);
            },
            onChanged: (_) {
              if (_patternError != null) {
                setState(() => _patternError = null);
              }
            },
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _twoColGrid({required List<Widget> children}) {
    return LayoutBuilder(builder: (ctx, c) {
      final cols = c.maxWidth > 520 ? 2 : 1;
      if (cols == 1) {
        return Column(children: children);
      }
      // Build 2-column table manually
      final rows = <Widget>[];
      for (var i = 0; i < children.length; i += 2) {
        rows.add(Row(
          children: [
            Expanded(child: children[i]),
            const SizedBox(width: 4),
            Expanded(
                child: i + 1 < children.length
                    ? children[i + 1]
                    : const SizedBox.shrink()),
          ],
        ));
      }
      return Column(children: rows);
    });
  }

  Widget _emptyHint(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
                fontStyle: FontStyle.italic,
              )),
    );
  }
}

// ── Compact checkbox row ──────────────────────────────────────────────────────

class _CompactCheckbox extends StatelessWidget {
  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CompactCheckbox({
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
        child: Row(
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: value
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.45),
                      )),
                  Text(description,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.6),
                      ),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── List row with delete ───────────────────────────────────────────────────────

class _ListRow extends StatelessWidget {
  final String label;
  final bool mono;
  final VoidCallback onDelete;

  const _ListRow({
    required this.label,
    required this.onDelete,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          Icon(Icons.subdirectory_arrow_right,
              size: 13,
              color: theme.colorScheme.onSurfaceVariant
                  .withValues(alpha: 0.4)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: mono ? 'Consolas, monospace' : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: onDelete,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close,
                  size: 14, color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add row ────────────────────────────────────────────────────────────────────

class _AddRow extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? errorText;
  final VoidCallback onAdd;
  final ValueChanged<String>? onChanged;

  const _AddRow({
    required this.controller,
    required this.hint,
    required this.onAdd,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            onSubmitted: (_) => onAdd(),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontSize: 11),
              errorText: errorText,
              border: const OutlineInputBorder(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 36,
          child: FilledButton.tonal(
            onPressed: onAdd,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Add', style: TextStyle(fontSize: 13)),
          ),
        ),
      ],
    );
  }
}
