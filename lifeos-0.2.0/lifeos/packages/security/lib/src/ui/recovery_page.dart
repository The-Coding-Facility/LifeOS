import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_lock_controller.dart';
import '../pin_hasher.dart';
import 'auth_layout.dart';
import 'recovery_code_view.dart';

/// PIN mit dem Wiederherstellungscode zurücksetzen.
class RecoveryPage extends ConsumerStatefulWidget {
  const RecoveryPage({super.key, required this.onCancel});

  /// Zurück zum Sperrbildschirm.
  final VoidCallback onCancel;

  @override
  ConsumerState<RecoveryPage> createState() => _RecoveryPageState();
}

class _RecoveryPageState extends ConsumerState<RecoveryPage> {
  final _code = TextEditingController();
  final _pin = TextEditingController();
  final _repeat = TextEditingController();
  String? _codeError;
  String? _pinError;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    _pin.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _submit(AppLockController lock) async {
    setState(() {
      _codeError = null;
      _pinError = null;
    });
    if (!PinHasher.isValidPin(_pin.text)) {
      setState(() => _pinError = 'Bitte 6 bis 12 Ziffern eingeben.');
      return;
    }
    if (_pin.text != _repeat.text) {
      setState(() => _pinError = 'Die beiden PINs stimmen nicht überein.');
      return;
    }
    setState(() => _busy = true);
    try {
      final next = await lock.resetWithRecoveryCode(_code.text, _pin.text);
      if (!mounted) return;
      if (next == null) {
        setState(() => _codeError = 'Dieser Code passt nicht.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(appLockControllerProvider);
    return ListenableBuilder(
      listenable: lock,
      builder: (context, _) {
        final code = lock.pendingRecoveryCode;
        if (code != null) {
          return AuthLayout(
            icon: Icons.key_outlined,
            title: 'Neue PIN gesetzt',
            subtitle: 'Dein alter Wiederherstellungscode gilt nicht mehr. Hier ist der neue.',
            children: [
              RecoveryCodeView(code: code, onConfirmed: lock.confirmRecoveryCodeSaved),
            ],
          );
        }
        return AuthLayout(
          icon: Icons.key_outlined,
          title: 'PIN zurücksetzen',
          subtitle: 'Gib deinen Wiederherstellungscode und eine neue PIN ein.',
          children: [
            TextField(
              controller: _code,
              enabled: !_busy,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Wiederherstellungscode',
                hintText: 'XXXX-XXXX-XXXX-XXXX-XXXX-XXXX',
                errorText: _codeError,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            PinField(controller: _pin, label: 'Neue PIN', enabled: !_busy),
            const SizedBox(height: 12),
            PinField(
              controller: _repeat,
              label: 'Neue PIN wiederholen',
              errorText: _pinError,
              enabled: !_busy,
              onSubmitted: (_) => _submit(lock),
            ),
            const SizedBox(height: 24),
            BusyButton(label: 'PIN zurücksetzen', busy: _busy, onPressed: () => _submit(lock)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : widget.onCancel,
              child: const Text('Zurück'),
            ),
          ],
        );
      },
    );
  }
}
