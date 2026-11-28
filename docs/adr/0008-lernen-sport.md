# ADR-0008: Lernen und Sport (Welle D)

Status: angenommen · 28.11.2026 · Details: `docs/superpowers/specs/2026-11-28-lernen-sport-design.md`

## Entscheidungen

- **Zwei neue Module** `lifeos_learning` und `lifeos_sport`. Projekte hängen von Lernen ab (verknüpfte Bereiche im Projekt), Lernen kennt Projekte nur über einen Port der App. Der Kalender kennt Sport nur über `trainingPlanChoicesProvider` und `startTrainingProvider`, die die App setzt. Kein Abhängigkeitskreis.
- **`RecordWriter`** in der Persistenz schreibt Datensatz und Änderungsprotokoll in einem Schritt. Neue Repositories nutzen ihn statt eigener Hilfsfunktionen.
- **Lerneinheiten und Trainings sind unveränderlich**: eine Feldgruppe für alles. Antworten und Ergebnisse stehen als JSON im Datensatz.
- **Karten-Antwortmöglichkeiten und Plan-Schritte als JSON-Liste** im Datensatz, wie Rezeptzutaten. Reihenfolge bleibt zusammen.
- **Körperdaten: ein Datensatz pro Tag**, ID aus dem Datum, eine Feldgruppe je Messung. Gewicht am PC und Puls am Handy am selben Tag ergeben einen Eintrag; ein geleertes Feld wird auch auf dem anderen Gerät leer.
- **Schlafdauer** kommt aus dem Daily Report, wenn sie unter „Über mich“ fehlt. Gespeichert wird nur, was eingetippt wurde.
- **Tagesziele** in einer Zeile mit fester ID.
- **Abspielen als reine Zustandsmaschine** (`TrainingPlayback`), die Oberfläche liefert nur die Zeit. Vorgabezeit 0 heißt „ohne Countdown, weiter per Knopf“. Nach der letzten Übung keine Ruhe.

## Folgen

- Schema 6. Beide Geräte müssen auf 0.6.0.
- Der Ton beim Wechsel ist der Systemton; eigene Töne kommen mit dem Wecker.
