import 'package:flutter/material.dart';
import 'package:lifeos_sync/lifeos_sync.dart';

/// Verbindet dieses Gerät mit einem anderen, das gerade einen Code anzeigt.
/// Schließt sich mit `true`, wenn die Kopplung geklappt hat.
class JoinDialog extends StatefulWidget {
  const JoinDialog({super.key, required this.service});

  final SyncService service;

  @override
  State<JoinDialog> createState() => _JoinDialogState();
}

class _JoinDialogState extends State<JoinDialog> {
  final _address = TextEditingController();
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _address.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.joinWith(address: _address.text, code: _code.text);
      if (mounted) Navigator.of(context).pop(true);
    } on FormatException {
      if (mounted) setState(() => _error = 'Bitte die Adresse eingeben, z. B. 192.168.178.20:47321.');
    } on Object catch (error) {
      if (mounted) setState(() => _error = describeSyncError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mit Code verbinden'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Öffne auf dem anderen Gerät „Gerät hinzufügen“ und tippe die angezeigte Adresse und den Code ein. '
              'Beide Geräte müssen im selben WLAN sein.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _address,
              enabled: !_busy,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Adresse',
                hintText: '192.168.178.20:47321',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              enabled: !_busy,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Code',
                hintText: 'XXXX-XXXX-XXXX-XXXX',
                errorText: _error,
                errorMaxLines: 3,
              ),
              onSubmitted: (_) => _connect(),
            ),
            const SizedBox(height: 12),
            Text(
              'Hinweis: Gibt es auf diesem Gerät schon Einträge, werden sie mit denen des anderen Geräts zusammengeführt.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _busy ? null : _connect,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Verbinden'),
        ),
      ],
    );
  }
}
