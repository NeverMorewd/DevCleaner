import 'package:flutter/material.dart';
import '../providers/scan_provider.dart';

/// Full-screen blocking overlay shown while a scan is in progress.
/// Only the Cancel button is interactive; all other UI is disabled.
class ScanOverlay extends StatelessWidget {
  final ScanProvider scan;

  const ScanOverlay({super.key, required this.scan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = scan.scannersTotal > 0
        ? (scan.scannersDone / scan.scannersTotal).clamp(0.0, 1.0)
        : null;

    return GestureDetector(
      // Absorb all pointer events that fall outside the card
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
        color: Colors.black.withValues(alpha: 0.60),
        child: Center(
          child: Card(
            elevation: 24,
            shadowColor: Colors.black54,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(48, 40, 48, 36),
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Large circular progress
                    SizedBox(
                      width: 76,
                      height: 76,
                      child: CircularProgressIndicator(
                        strokeWidth: 5.5,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'Scanning…',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Current scanner name
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: 20,
                        maxWidth: 300,
                      ),
                      child: Text(
                        scan.progress.isNotEmpty
                            ? scan.progress
                            : 'Initializing…',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),

                    // Progress bar + fraction
                    if (scan.scannersTotal > 0) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        width: 300,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 7,
                                backgroundColor:
                                    theme.colorScheme.surfaceContainerHighest,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${scan.scannersDone} / ${scan.scannersTotal} scanners',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else
                      const SizedBox(height: 20),

                    const SizedBox(height: 24),

                    // Cancel button — the ONLY interactive element
                    OutlinedButton.icon(
                      onPressed: () => scan.abortScan(),
                      icon: const Icon(Icons.stop_circle_outlined, size: 18),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        side: BorderSide(color: theme.colorScheme.error),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
