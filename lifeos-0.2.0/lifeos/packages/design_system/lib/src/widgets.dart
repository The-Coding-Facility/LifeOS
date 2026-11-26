import 'package:flutter/material.dart';

/// Zustand der Synchronisation, angezeigt auf dem Dashboard.
enum SyncStatus { syncing, synced, offline, localOnly }

/// Kleines Symbol mit Text: „Syncing“, „Synced“, „Offline-Modus“ oder „Nur lokal“.
class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip({super.key, required this.status, this.pendingChanges = 0});

  final SyncStatus status;

  /// Zahl der noch nicht übertragenen Änderungen (nur im Offline-Modus).
  final int pendingChanges;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (status) {
      SyncStatus.syncing => (Icons.sync, 'Syncing'),
      SyncStatus.synced => (Icons.cloud_done_outlined, 'Synced'),
      SyncStatus.offline => (
          Icons.cloud_off_outlined,
          pendingChanges > 0 ? 'Offline-Modus · $pendingChanges ausstehend' : 'Offline-Modus',
        ),
      SyncStatus.localOnly => (Icons.phone_android_outlined, 'Nur lokal'),
    };
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Karte mit Überschrift für Dashboard-Kacheln und Abschnitte.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.action,
  });

  final String title;
  final IconData? icon;
  final Widget child;

  /// Z. B. ein „Alle anzeigen“-Knopf rechts in der Kopfzeile.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                ],
                Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
                if (action != null) action!,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

/// Hinweis, wenn eine Liste leer ist.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
