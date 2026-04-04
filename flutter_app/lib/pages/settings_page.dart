import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/config_provider.dart';

class SettingsPage extends StatefulWidget {
  final void Function(String? status, bool isError)? onStatus;
  const SettingsPage({super.key, this.onStatus});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _rootCtrl = TextEditingController();
  Timer? _saveTimer;

  @override
  void dispose() {
    _saveTimer?.cancel();
    _rootCtrl.dispose();
    super.dispose();
  }

  Future<void> _immediateSave(ConfigProvider config) async {
    _saveTimer?.cancel();
    widget.onStatus?.call('Saving\u2026', false);
    await _doSave(config);
  }

  Future<void> _doSave(ConfigProvider config) async {
    try {
      await config.saveToFile();
      if (!mounted) return;
      widget.onStatus?.call('Saved', false);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) widget.onStatus?.call(null, false);
      });
    } catch (e) {
      if (!mounted) return;
      widget.onStatus?.call('Save failed: $e', true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConfigProvider>(
      builder: (context, config, _) {
        if (config.loading) return const Center(child: CircularProgressIndicator());
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [_buildProjectRootsSection(context, config)],
        );
      },
    );
  }

  Widget _section(BuildContext context,
      {required String title, String? subtitle, required Widget child}) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700, color: theme.colorScheme.primary, letterSpacing: 0.3,
      )),
      if (subtitle != null) ...[
        const SizedBox(height: 2),
        Text(subtitle, style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
      const SizedBox(height: 8),
      child,
    ]);
  }

  Widget _buildProjectRootsSection(BuildContext context, ConfigProvider config) {
    final roots = config.projectRoots;
    return _section(
      context,
      title: 'Project Roots',
      subtitle: 'Extra directories to scan for build artifacts (auto-discovery always enabled).',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (roots.isEmpty)
          _emptyHint(context, 'No custom roots \u2014 using auto-discovery only.')
        else
          ...roots.map((root) => _ListRow(
            label: root, mono: true,
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
            final messenger = ScaffoldMessenger.of(context);
            if (!await Directory(p).exists()) {
              if (mounted) {
                messenger.showSnackBar(SnackBar(
                  content: Text('Path does not exist: $p'),
                  duration: const Duration(seconds: 3),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ));
              }
              return;
            }
            config.addProjectRoot(p);
            _rootCtrl.clear();
            await _immediateSave(config);
          },
        ),
      ]),
    );
  }

  Widget _emptyHint(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.outline, fontStyle: FontStyle.italic,
      )),
    );
  }
}

class _ListRow extends StatelessWidget {
  final String label;
  final bool mono;
  final VoidCallback onDelete;

  const _ListRow({required this.label, required this.onDelete, this.mono = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 32,
      child: Row(children: [
        Icon(Icons.subdirectory_arrow_right, size: 13,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
        const SizedBox(width: 4),
        Expanded(child: Text(label,
            style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: mono ? 'Consolas, monospace' : null),
            overflow: TextOverflow.ellipsis)),
        InkWell(
          onTap: onDelete,
          borderRadius: BorderRadius.circular(4),
          child: Padding(padding: const EdgeInsets.all(4),
              child: Icon(Icons.close, size: 14, color: theme.colorScheme.error)),
        ),
      ]),
    );
  }
}

class _AddRow extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback onAdd;

  const _AddRow({required this.controller, required this.hint, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(
        child: TextField(
          controller: controller,
          onSubmitted: (_) => onAdd(),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            isDense: true,
          ),
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
        ),
      ),
      const SizedBox(width: 8),
      FilledButton.tonal(
        onPressed: onAdd,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: const Text('Add', style: TextStyle(fontSize: 13)),
      ),
    ]);
  }
}
