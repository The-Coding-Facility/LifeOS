import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lifeos_sync/lifeos_sync.dart';

/// Zeigt Kopplungscode und Adresse an und wartet, bis sich das andere
/// Gerät meldet. Schließt sich mit `true`, sobald gekoppelt wurde.
class PairingOfferDialog extends StatefulWidget {
  const PairingOfferDialog({super.key, required this.service});

  final SyncService service;

  @override
  State<PairingOfferDialog> createState() => _PairingOfferDialogState();
}

class _PairingOfferDialogState extends State<PairingOfferDialog> {
  PairingOffer? _offer;
  Object? _error;
  Timer? _ticker;
  StreamSubscription<String>? _paired;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _paired = widget.service.onPaired.listen((_) {
      _done = true;
      if (mounted) Navigator.of(context).pop(true);
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _offer = null;
      _error = null;
    });
    try {
      final offer = await widget.service.startPairing();
      if (mounted) setState(() => _offer = offer);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _paired?.cancel();
    if (!_done) widget.service.cancelPairing();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final offer = _offer;
    final remaining = offer?.expiresAt.difference(DateTime.now());
    final expired = remaining != null && remaining.isNegative;

    Widget content;
    if (_error != null) {
      content = Text('Kopplung konnte nicht gestartet werden: ${describeSyncError(_error!)}');
    } else if (offer == null) {
      content = const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
    } else if (expired) {
      content = const Text('Der Code ist abgelaufen.');
    } else {
      final minutes = remaining!.inMinutes;
      final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Auf dem anderen Gerät: Einstellungen → Geräte & Synchronisation → „Mit Code verbinden“.'),
          const SizedBox(height: 16),
          Text('Adresse', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          if (offer.addresses.isEmpty)
            const Text('Keine WLAN-Adresse gefunden. Ist das Gerät im WLAN?')
          else
            for (final address in offer.addresses)
              SelectableText(
                '$address:${offer.port}',
                style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'monospace'),
              ),
          const SizedBox(height: 16),
          Text('Code', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          SelectableText(
            offer.code,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontFamily: 'monospace',
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Expanded(child: Text('Warte auf das andere Gerät … noch $minutes:$seconds min')),
            ],
          ),
          if (offer.addresses.length > 1) ...[
            const SizedBox(height: 12),
            Text(
              'Mehrere Adressen: Meist ist die mit 192.168. die richtige.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      );
    }

    return AlertDialog(
      title: const Text('Gerät hinzufügen'),
      content: SingleChildScrollView(child: content),
      actions: [
        if (expired || _error != null)
          TextButton(onPressed: _start, child: const Text('Neuer Code')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Schließen'),
        ),
      ],
    );
  }
}
