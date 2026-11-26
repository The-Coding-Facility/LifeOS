import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Zeigt einen Wiederherstellungscode an und verlangt die Bestätigung,
/// dass er gesichert wurde.
class RecoveryCodeView extends StatefulWidget {
  const RecoveryCodeView({super.key, required this.code, required this.onConfirmed});

  final String code;
  final VoidCallback onConfirmed;

  @override
  State<RecoveryCodeView> createState() => _RecoveryCodeViewState();
}

class _RecoveryCodeViewState extends State<RecoveryCodeView> {
  bool _saved = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Code kopiert. Lösche ihn danach aus der Zwischenablage.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Mit diesem Code setzt du eine vergessene PIN zurück. '
          'Er wird nur jetzt angezeigt. Drucke ihn aus oder speichere ihn in deinem Passwortmanager.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(
            widget.code,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: 'monospace',
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _copy,
            icon: const Icon(Icons.copy),
            label: const Text('Kopieren'),
          ),
        ),
        CheckboxListTile(
          value: _saved,
          onChanged: (value) => setState(() => _saved = value ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Ich habe den Code sicher aufbewahrt.'),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _saved ? widget.onConfirmed : null,
          child: const Text('Weiter'),
        ),
      ],
    );
  }
}
