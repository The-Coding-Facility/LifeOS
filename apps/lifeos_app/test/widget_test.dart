import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/src/startup_error_app.dart';

// Diese Datei ersetzt den Beispieltest, den `flutter create` sonst anlegt.
// Logik und Oberfläche der Module werden in ihren eigenen Paketen getestet.
void main() {
  testWidgets('Startfehler wird verständlich angezeigt', (tester) async {
    await tester.pumpWidget(StartupErrorApp(error: StateError('Schlüssel fehlt')));
    expect(find.text('LifeOS konnte nicht starten'), findsOneWidget);
    expect(find.textContaining('Schlüssel fehlt'), findsOneWidget);
  });
}
