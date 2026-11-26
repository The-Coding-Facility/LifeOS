import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_lock_controller.dart';
import 'auth_layout.dart';

/// Sperrbildschirm: PIN eingeben.
class LockPage extends ConsumerStatefulWidget {
  const LockPage({super.key, required this.onForgotPin});

  /// Öffnet den Reset mit Wiederherstellungscode.
  final VoidCallback onForgotPin;

  @override
  ConsumerState<LockPage> createState() => _LockPageState();
}

class _LockPageState extends ConsumerState<LockPage> {
  final _pin = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _pin.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref.read(appLockControllerProvider).unlock(_pin.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _pin.clear();
      _error = switch (result) {
        UnlockSuccess() => null,
        UnlockWrongPin(retryAfter: final DateTime until) =>
          'Falsche PIN. Nächster Versuch ab ${formatClockTime(until)}.',
        UnlockWrongPin() => 'Falsche PIN.',
        UnlockBlocked(:final retryAfter) =>
          'Zu viele Fehlversuche. Nächster Versuch ab ${formatClockTime(retryAfter)}.',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'LifeOS ist gesperrt',
      subtitle: 'Gib deine PIN ein.',
      children: [
        PinField(
          controller: _pin,
          label: 'PIN',
          autofocus: true,
          errorText: _error,
          enabled: !_busy,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 24),
        BusyButton(label: 'Entsperren', busy: _busy, onPressed: _submit),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy ? null : widget.onForgotPin,
          child: const Text('PIN vergessen?'),
        ),
      ],
    );
  }
}
