import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lifeos_security/lifeos_security.dart';

import 'app_providers.dart';
import 'router.dart';

/// Einstellungen: Sperre, Wiederherstellungscode, Gerät, Version.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _regenerateRecoveryCode(BuildContext context, AppLockController lock) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Neuen Wiederherstellungscode erzeugen?'),
        content: const Text('Der bisherige Code wird damit ungültig.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Erzeugen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final code = await lock.regenerateRecoveryCode();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Dein neuer Wiederherstellungscode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Drucke ihn aus oder speichere ihn im Passwortmanager. Er wird nur jetzt angezeigt.'),
            const SizedBox(height: 16),
            SelectableText(
              code,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 18, letterSpacing: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Clipboard.setData(ClipboardData(text: code)),
            icon: const Icon(Icons.copy),
            label: const Text('Kopieren'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Gesichert'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lock = ref.watch(appLockControllerProvider);
    final deviceId = ref.watch(deviceIdProvider);
    final theme = Theme.of(context);

    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        children: [
          header('Sicherheit'),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Jetzt sperren'),
            subtitle: Text('Automatisch nach ${lock.timeout.inMinutes} Minuten ohne Eingabe'),
            onTap: lock.lockNow,
          ),
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: const Text('Neuen Wiederherstellungscode erzeugen'),
            onTap: () => _regenerateRecoveryCode(context, lock),
          ),
          header('Dieses Gerät'),
          ListTile(
            leading: const Icon(Icons.devices_outlined),
            title: const Text('Geräte-ID'),
            subtitle: SelectableText(deviceId),
          ),
          ListTile(
            leading: const Icon(Icons.devices_other_outlined),
            title: const Text('Geräte & Synchronisation'),
            subtitle: const Text('Geräte koppeln, Sync-Status, jetzt synchronisieren'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(Routes.devices),
          ),
          header('Über'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('LifeOS 0.2.0 – Testversion'),
            subtitle: Text('Aufgaben, Notizen, App-Sperre, Gerätekopplung und Sync im WLAN'),
          ),
        ],
      ),
    );
  }
}
