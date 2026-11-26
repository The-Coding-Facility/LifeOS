import 'package:flutter/material.dart';
import 'package:lifeos_core/lifeos_core.dart';

import '../finance_math.dart';
import '../model.dart';

/// Achsenbeschriftung ohne Cent: `1.234 €`.
String formatEuroShort(int cents) => formatCents((cents / 100).round() * 100).replaceAll(',00', '');

/// Farbe für Einnahmen (grün) und Ausgaben (rot), passend zum Theme.
Color incomeColor(BuildContext context) => const Color(0xFF2E9E6B);
Color expenseColor(BuildContext context) => Theme.of(context).colorScheme.error;

/// Betrag einer Buchung mit Vorzeichen und Farbe.
class SignedAmount extends StatelessWidget {
  const SignedAmount({super.key, required this.entry, this.style});

  final FinanceEntry entry;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final signed = signedCents(entry);
    final color = switch (entry.kind) {
      EntryKind.income => incomeColor(context),
      EntryKind.expense => expenseColor(context),
      EntryKind.saving || EntryKind.withdrawal => Theme.of(context).colorScheme.tertiary,
    };
    return Text(
      formatCents(signed, withSign: true),
      style: (style ?? Theme.of(context).textTheme.titleSmall)?.copyWith(color: color),
    );
  }
}

/// „20,00 € weniger als letzten Monat“ bzw. „mehr“ bzw. „gleich viel“.
String describeDelta(int deltaCents) {
  if (deltaCents == 0) return 'Gleich viel wie letzten Monat';
  final amount = formatCents(deltaCents.abs());
  return deltaCents < 0 ? '$amount weniger als letzten Monat' : '$amount mehr als letzten Monat';
}

/// Fragt einen Betrag ab. Gibt Cent zurück (immer positiv) oder `null`.
Future<int?> askAmount(BuildContext context, {required String title, String confirmLabel = 'OK'}) {
  return showDialog<int>(
    context: context,
    builder: (context) => _AmountDialog(title: title, confirmLabel: confirmLabel),
  );
}

class _AmountDialog extends StatefulWidget {
  const _AmountDialog({required this.title, required this.confirmLabel});

  final String title;
  final String confirmLabel;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final cents = parseCents(_controller.text);
    if (cents == null || cents == 0) {
      setState(() => _error = 'Bitte einen Betrag eingeben, z. B. 12,50');
      return;
    }
    Navigator.of(context).pop(cents.abs());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: 'Betrag in €', errorText: _error),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
