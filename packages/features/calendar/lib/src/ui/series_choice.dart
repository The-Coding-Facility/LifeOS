import 'package:flutter/material.dart';

/// Ob eine Änderung an einer Serie nur ein Vorkommen oder alle betrifft.
enum SeriesChoice { onlyThis, all }

/// Fragt „Nur diesen Termin“ oder „Alle Termine der Serie“.
Future<SeriesChoice?> askSeriesChoice(BuildContext context, {required String title}) {
  return showDialog<SeriesChoice>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(title),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.of(context).pop(SeriesChoice.onlyThis),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Nur diesen Termin'),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.of(context).pop(SeriesChoice.all),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Alle Termine der Serie'),
          ),
        ),
      ],
    ),
  );
}
