import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class AppTitleBar extends StatefulWidget {
  const AppTitleBar({super.key});

  @override
  State<AppTitleBar> createState() => _AppTitleBarState();
}

class _AppTitleBarState extends State<AppTitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _checkMaximized() async {
    final v = await windowManager.isMaximized();
    if (mounted) setState(() => _isMaximized = v);
  }

  @override
  void onWindowMaximize() => setState(() => _isMaximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark
        ? const Color(0xFF0F1923)
        : theme.colorScheme.surfaceContainer;

    return DragToMoveArea(
      child: Container(
        height: 40,
        color: bg,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 14),
            // App icon
            SizedBox(
              width: 20,
              height: 20,
              child: CustomPaint(
                painter: _BroomIconPainter(color: theme.colorScheme.primary),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'DevCleaner',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
              ),
            ),
            const Spacer(),
            _WinButton(
              icon: Icons.remove,
              tooltip: 'Minimize',
              onTap: () => windowManager.minimize(),
            ),
            _WinButton(
              icon: _isMaximized ? Icons.filter_none : Icons.crop_square,
              tooltip: _isMaximized ? 'Restore' : 'Maximize',
              iconSize: _isMaximized ? 13 : 15,
              onTap: () => _isMaximized
                  ? windowManager.unmaximize()
                  : windowManager.maximize(),
            ),
            _WinButton(
              icon: Icons.close,
              tooltip: 'Close',
              onTap: () => windowManager.close(),
              isClose: true,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Window control button ──────────────────────────────────────────────────────

class _WinButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isClose;
  final double iconSize;

  const _WinButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isClose = false,
    this.iconSize = 15,
  });

  @override
  State<_WinButton> createState() => _WinButtonState();
}

class _WinButtonState extends State<_WinButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hoverBg = widget.isClose
        ? const Color(0xFFE81123)
        : theme.colorScheme.onSurface.withValues(alpha: 0.10);

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 800),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 46,
            height: 40,
            color: _hovered ? hoverBg : Colors.transparent,
            child: Icon(
              widget.icon,
              size: widget.iconSize,
              color: (_hovered && widget.isClose)
                  ? Colors.white
                  : theme.colorScheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Broom icon painter ─────────────────────────────────────────────────────────

class _BroomIconPainter extends CustomPainter {
  final Color color;
  _BroomIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Handle
    final handlePaint = Paint()
      ..color = color
      ..strokeWidth = w * 0.13
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(w * 0.73, h * 0.07),
      Offset(w * 0.36, h * 0.56),
      handlePaint,
    );

    // Brush head
    final headPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(w * 0.06, h * 0.60)
      ..lineTo(w * 0.50, h * 0.48)
      ..lineTo(w * 0.57, h * 0.63)
      ..lineTo(w * 0.52, h * 0.83)
      ..lineTo(w * 0.06, h * 0.83)
      ..close();
    canvas.drawPath(path, headPaint);

    // Dust dots
    final dotPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.73, h * 0.73), w * 0.07, dotPaint);
    canvas.drawCircle(Offset(w * 0.85, h * 0.57), w * 0.05, dotPaint);
    canvas.drawCircle(Offset(w * 0.91, h * 0.80), w * 0.06, dotPaint);
  }

  @override
  bool shouldRepaint(_BroomIconPainter old) => old.color != color;
}
