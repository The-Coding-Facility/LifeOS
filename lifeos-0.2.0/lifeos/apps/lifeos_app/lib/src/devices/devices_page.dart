import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';
import 'package:lifeos_sync/lifeos_sync.dart';

import '../app_providers.dart';
import 'join_dialog.dart';
import 'pairing_offer_dialog.dart';

/// Geräteverwaltung: Sync-Status, eigene Adresse, gekoppelte Geräte, Koppeln.
class DevicesPage extends ConsumerWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(syncServiceProvider);
    final state = ref.watch(syncStateProvider).value ?? service.state;
    final devices = ref.watch(pairedDevicesProvider);
    final theme = Theme.of(context);

    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            text,
            style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
          ),
        );

    Future<void> showResult(Future<bool?> dialog, String success) async {
      final messenger = ScaffoldMessenger.of(context);
      if (await dialog == true) {
        messenger.showSnackBar(SnackBar(content: Text(success)));
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Geräte & Synchronisation')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          header('Synchronisation'),
          ListTile(
            leading: Icon(_phaseIcon(state.phase)),
            title: Text(_phaseText(state)),
            subtitle: Text(_stateDetails(state)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: state.phase == SyncPhase.syncing ? null : service.syncNow,
                icon: const Icon(Icons.sync),
                label: const Text('Jetzt synchronisieren'),
              ),
            ),
          ),
          if (state.conflicts > 0)
            ListTile(
              leading: Icon(Icons.call_split, color: theme.colorScheme.tertiary),
              title: Text(
                state.conflicts == 1
                    ? '1 gleichzeitige Änderung gespeichert'
                    : '${state.conflicts} gleichzeitige Änderungen gespeichert',
              ),
              subtitle: const Text(
                'Die spätere Version wird angezeigt, die andere ist aufbewahrt. '
                'Die Übersicht zum Auswählen folgt in einer späteren Version.',
              ),
            ),
          header('Dieses Gerät'),
          ListTile(
            leading: Icon(_platformIcon(service.identity.platform)),
            title: Text(service.identity.name),
            subtitle: Text(
              service.serverRunning
                  ? 'Empfang aktiv auf Port ${service.port}'
                  : 'Empfang nicht aktiv. Dieses Gerät kann nur selbst abgleichen.',
            ),
          ),
          _OwnAddressesTile(port: service.port),
          header('Gekoppelte Geräte'),
          devices.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
            error: (error, _) => ListTile(title: Text('Fehler: $error')),
            data: (items) => items.isEmpty
                ? const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Noch kein Gerät gekoppelt'),
                    subtitle: Text('Koppeln geht nur, wenn beide Geräte im selben WLAN sind.'),
                  )
                : Column(
                    children: [for (final device in items) _DeviceTile(device: device)],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () => showResult(
                    showDialog<bool>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => PairingOfferDialog(service: service),
                    ),
                    'Gerät gekoppelt. Die Daten werden jetzt abgeglichen.',
                  ),
                  icon: const Icon(Icons.add_link),
                  label: const Text('Gerät hinzufügen'),
                ),
                OutlinedButton.icon(
                  onPressed: () => showResult(
                    showDialog<bool>(
                      context: context,
                      builder: (_) => JoinDialog(service: service),
                    ),
                    'Verbunden. Die Daten werden jetzt abgeglichen.',
                  ),
                  icon: const Icon(Icons.link),
                  label: const Text('Mit Code verbinden'),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'So geht es: Auf dem Gerät mit deinen Daten (z. B. dem PC) auf „Gerät hinzufügen“ tippen. '
              'Auf dem neuen Gerät „Mit Code verbinden“ wählen und Adresse und Code eintippen. '
              'Danach gleichen sich beide Geräte automatisch ab, sobald die App offen ist.',
            ),
          ),
        ],
      ),
    );
  }

  static IconData _phaseIcon(SyncPhase phase) => switch (phase) {
        SyncPhase.localOnly => Icons.phone_android_outlined,
        SyncPhase.syncing => Icons.sync,
        SyncPhase.synced => Icons.cloud_done_outlined,
        SyncPhase.offline => Icons.cloud_off_outlined,
      };

  static String _phaseText(SyncState state) => switch (state.phase) {
        SyncPhase.localOnly => 'Nur lokal – noch kein Gerät gekoppelt',
        SyncPhase.syncing => 'Synchronisiert gerade …',
        SyncPhase.synced => state.pending == 0
            ? 'Synchronisiert'
            : 'Teilweise synchronisiert, ${state.pending} Änderungen ausstehend',
        SyncPhase.offline => state.pending == 0
            ? 'Offline-Modus'
            : 'Offline-Modus, ${state.pending} Änderungen ausstehend',
      };

  static String _stateDetails(SyncState state) {
    final parts = <String>[
      if (state.lastSync != null) 'Zuletzt: ${formatDateTime(state.lastSync!)}',
      if (state.message != null) state.message!,
    ];
    return parts.isEmpty ? 'Abgleich automatisch alle 30 Sekunden bei geöffneter App.' : parts.join('\n');
  }
}

IconData _platformIcon(String platform) => switch (platform) {
      'windows' => Icons.desktop_windows_outlined,
      'android' => Icons.phone_android_outlined,
      'ios' => Icons.phone_iphone_outlined,
      _ => Icons.devices_other_outlined,
    };

/// `26.11.2026, 14:05` in Ortszeit.
String formatDateTime(DateTime time) {
  final local = time.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year}, ${two(local.hour)}:${two(local.minute)}';
}

class _OwnAddressesTile extends StatefulWidget {
  const _OwnAddressesTile({required this.port});

  final int port;

  @override
  State<_OwnAddressesTile> createState() => _OwnAddressesTileState();
}

class _OwnAddressesTileState extends State<_OwnAddressesTile> {
  late final Future<List<String>> _addresses = localAddresses();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _addresses,
      builder: (context, snapshot) {
        final addresses = snapshot.data ?? const <String>[];
        return ListTile(
          leading: const Icon(Icons.lan_outlined),
          title: const Text('Adresse im WLAN'),
          subtitle: Text(
            addresses.isEmpty
                ? (snapshot.connectionState == ConnectionState.done
                    ? 'Keine WLAN-Adresse gefunden'
                    : 'Wird ermittelt …')
                : addresses.map((address) => '$address:${widget.port}').join('\n'),
          ),
        );
      },
    );
  }
}

class _DeviceTile extends ConsumerWidget {
  const _DeviceTile({required this.device});

  final PairedDevice device;

  Future<void> _changeAddress(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: device.address ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Adresse von ${device.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(hintText: '192.168.178.20:47321'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.trim().isEmpty) return;
    await ref.read(syncServiceProvider).updateAddress(device.deviceId, result);
  }

  Future<void> _forget(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${device.name} entfernen?'),
        content: const Text(
          'Dieses Gerät gleicht dann nicht mehr mit ihm ab. Die Daten auf beiden Geräten bleiben erhalten.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Entfernen')),
        ],
      ),
    );
    if (confirmed == true) await ref.read(syncServiceProvider).forget(device.deviceId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastSync = device.lastSyncAt;
    return ListTile(
      leading: Icon(_platformIcon(device.platform)),
      title: Text(device.name),
      subtitle: Text(
        '${device.address ?? 'Adresse unbekannt'}\n'
        '${lastSync == null ? 'Noch nie abgeglichen' : 'Zuletzt abgeglichen: ${formatDateTime(DateTime.fromMillisecondsSinceEpoch(lastSync, isUtc: true))}'}',
      ),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        onSelected: (value) => value == 'address' ? _changeAddress(context, ref) : _forget(context, ref),
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'address', child: Text('Adresse ändern')),
          PopupMenuItem(value: 'forget', child: Text('Entfernen')),
        ],
      ),
    );
  }
}
