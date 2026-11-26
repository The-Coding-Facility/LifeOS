import 'package:flutter/material.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';

/// Wird angezeigt, wenn die Datenbank nicht geöffnet werden kann.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildLifeosTheme(Brightness.light),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'LifeOS konnte nicht starten',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    const Text('Es wurden keine Daten verändert. Technische Details:'),
                    const SizedBox(height: 8),
                    SelectableText('$error'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
