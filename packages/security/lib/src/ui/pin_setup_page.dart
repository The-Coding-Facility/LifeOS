import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_lock_controller.dart';
import '../pin_hasher.dart';
import 'auth_layout.dart';
import 'recovery_code_view.dart';

/// Ersteinrichtung: PIN festlegen, dann Wiederherstellungscode sichern.
class PinSetupPage extends ConsumerStatefulWidget {
  const PinSetupPage({super.key});

  @override
  ConsumerState<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends ConsumerState<PinSetupPage> {
  final _pin = TextEditingController();
  final _repeat = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _pin.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _submit(AppLockController lock) async {
    if (!PinHasher.isValidPin(_pin.text)) {
      setState(() => _error = 'Bitte 6 bis 12 Ziffern eingeben.');
      return;
    }
    if (_pin.text != _repeat.text) {
      setState(() => _error = 'Die beiden PINs stimmen nicht überein.');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await lock.setupPin(_pin.text);
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
            title: 'Dein Wiederherstellungscode',
            children: [
              RecoveryCodeView(code: code, onConfirmed: lock.confirmRecoveryCodeSaved),
            ],
          );
        }
        return AuthLayout(
          title: 'Willkommen bei LifeOS',
          subtitle: 'Lege eine PIN mit 6 bis 12 Ziffern fest. '
              'Deine Daten bleiben verschlüsselt auf deinen Geräten.',
          children: [
            PinField(controller: _pin, label: 'PIN', autofocus: true, enabled: !_busy),
            const SizedBox(height: 12),
            PinField(
              controller: _repeat,
              label: 'PIN wiederholen',
              errorText: _error,
              enabled: !_busy,
              onSubmitted: (_) => _submit(lock),
            ),
            const SizedBox(height: 24),
            BusyButton(label: 'PIN festlegen', busy: _busy, onPressed: () => _submit(lock)),
          ],
        );
      },
    );
  }
}
