# Welle D: Lernen und Sport – Design

Stand: 28.11.2026 · Version 0.6.0 · Grundlage: Master-Projektauftrag Bereiche 8 und 9, Architektur Abschnitt 2

## Absicht

**Lernen:** Lernbereiche mit Glossar, Karteikarten, Notizen und Ressourcen; Karten durchlernen, Prüfungen mit Zeitlimit und Bestehensgrenze ablegen, in der Statistik sehen, ob man besser oder schlechter wird und was man oft falsch hat. Bereiche lassen sich mit Projekten verknüpfen; das Projekt-Dashboard zeigt, wie oft und wie gut geübt wurde.

**Sport:** Körperdaten täglich erfassen, Ernährung und Wasser gegen Tagesziele tracken, Übungen in einem Katalog pflegen, Trainingspläne mit Vorgabe- und Ruhezeit abspielen und dabei Werte notieren. Ein Termin im Kalender kann einen Trainingsplan enthalten und von dort gestartet werden.

## Ziele – Lernen

- Lernbereich: Name, Beschreibung, Farbe, optional verknüpftes Projekt.
- **Glossar:** Begriff und Erklärung, Suchleiste.
- **Karten:** Frage und Antwort als Text, oder Multiple Choice mit beliebig vielen Antworten (mindestens eine richtig).
- **Notizen:** Notizen des Bereichs (vorhandenes Notizmodul, neue Spalte `learning_area_id`).
- **Ressourcen:** Titel, Link oder Fundort, Notiz. Link zum Kopieren.
- **Lernen:** geht alle Karten durch, zuerst die oft falsch beantworteten und neuen, sonst gemischt. Frage → „Lösen“ → Antwort → „Richtig“ / „Falsch“. Multiple Choice: Antwort wählen, dann wird automatisch gewertet.
- **Prüfung:** einstellbar Quelle (Karten, Glossar oder beides), Anzahl Fragen, Zeitlimit in Minuten (0 = ohne), Bestehensgrenze in Prozent. Glossar-Fragen: Begriff mit vier Erklärungen zur Auswahl (aus anderen Einträgen; bei zu wenigen Einträgen Selbstbewertung). Text-Karten: Selbstbewertung nach „Lösen“. Am Ende oder bei Ablauf der Zeit: Ergebnis, bestanden ja/nein, jede Frage mit richtig/falsch und richtiger Antwort.
- **Statistik:** Lerneinheiten der letzten 30 Tage, Trefferquote der letzten 5 Einheiten gegen die 5 davor („+12 Prozentpunkte“), letzte Prüfungen mit Ergebnis, die 5 am häufigsten falsch beantworteten Fragen.
- **Projekt-Dashboard:** verknüpfte Lernbereiche mit Anzahl Einheiten und Trefferquote.

## Ziele – Sport

- **Über mich:** Pro Tag ein Eintrag mit Gewicht, Größe, Körperfett, Bauch-, Brust-, Oberarm-, Unterarm-, Hüft-, Taillen-, Oberschenkelumfang, Ruhepuls, Schlafdauer. Alles optional. Fehlt die Schlafdauer, wird sie aus dem Daily Report des Tages genommen.
- **Tracker:** Einträge mit kcal, Protein, Fett, Wasser für einen Tag; Schnellknöpfe „+250 ml Wasser“; „Rezeptportion“ aus der Küche übernimmt deren Nährwerte. Tagesziele für alle vier Werte, Fortschrittsbalken.
- **Übungskatalog:** Übung mit Name, Bereich (Kraft, Ausdauer) und Beschreibung, Suchleiste, Filter nach Bereich.
- **Trainingspläne:** Name, Art (Kraft, Ausdauer, Gemischt), Schritte aus Übung, Vorgabezeit und Ruhezeit. Bearbeiten, löschen, Reihenfolge ändern.
- **Abspielen:** Übung für Übung mit Countdown der Vorgabezeit, dann Ruhe-Countdown, Ton beim Wechsel, Weiter/Zurück/Pause. Je Übung optional Werte eintragen: Gewicht, Wiederholungen, Distanz, Zeit, Durchschnitts- und Maximalpuls. Am Ende wird die Trainingseinheit gespeichert.
- **Dashboard:** Verlauf einer gewählten Körpermessung (90/365 Tage), heutiger Tracker-Stand, letzte Trainingseinheiten, Verlauf einer gewählten Übung (z. B. Gewicht beim Bankdrücken).
- **Kalender:** Termin mit Trainingsplan; im Termin erscheint „Training starten“.

## Nicht-Ziele (später)

Abgestufte Wiederholung wie bei Anki, Bilder in Karten, Import von Kartensets, Links direkt im Browser öffnen, Daten von Uhren oder Gesundheits-Apps, Bildschirm beim Training wachhalten, Kohlenhydrate.

## Anti-Ziele

- Eine Prüfung läuft nach Ablauf der Zeit weiter oder zählt unbeantwortete Fragen als richtig.
- Zwei Geräte erfassen für denselben Tag Körperdaten und es entstehen zwei Einträge (oder einer überschreibt das Gewicht, obwohl nur der Puls geändert wurde).
- Ein Training geht verloren, weil die App zwischendurch in den Hintergrund ging.

## Ansätze

| Frage | Möglichkeiten | Gewählt und warum |
| --- | --- | --- |
| Antworten speichern | (a) Lerneinheit mit JSON-Liste der Antworten, (b) Tabelle je Antwort | **(a)**. Eine Einheit entsteht auf einem Gerät am Stück; Statistik rechnet aus allen Einheiten. |
| Körperdaten je Tag | (a) ID aus Datum, jede Messung eigene Feldgruppe, (b) Zeile je Messung | **(a)**. Ein Eintrag pro Tag wie beim Daily Report; Gewicht am PC und Puls am Handy verschmelzen ohne Konflikt. |
| Trainingsplan-Schritte | (a) JSON-Liste im Plan, (b) eigene Tabelle | **(a)**, Reihenfolge bleibt zusammen (wie Rezeptzutaten). |
| Termin ↔ Plan | (a) Spalte `training_plan_id` am Termin, Auswahl und Start über Provider der App, (b) Kalender kennt Sport | **(a)**, wie bei Projekten; kein Abhängigkeitskreis. |
| Lernen ↔ Projekt | (a) Spalte `project_id` am Lernbereich, Projekte lesen Lernstatistik, (b) umgekehrt | **(a)**. Projekte hängen von Lernen ab, Lernen bekommt die Projektauswahl über einen Provider. |

## Daten (Schema 6)

| Tabelle | Spalten |
| --- | --- |
| `learning_areas` | name, description, color_index, project_id |
| `glossary_entries` | area_id, term, explanation |
| `flashcards` | area_id, question, answer, kind (`text`/`choice`), choices (JSON `[{text, correct}]`) |
| `learning_resources` | area_id, title, link, note |
| `study_sessions` | area_id, mode (`learn`/`exam`), started_at, duration_seconds, total, correct, pass_percent, answers (JSON `[{kind, id, correct}]`) |
| `body_measurements` (ID aus Datum) | date + 12 Messwerte (Kommazahl, optional) |
| `nutrition_logs` | date, label, kcal, protein, fat, water_ml |
| `sport_goals` (feste ID) | kcal, protein, fat, water_ml |
| `exercises` | name, category (`strength`/`endurance`), description |
| `training_plans` | name, kind (`strength`/`endurance`/`mixed`), steps (JSON `[{exercise_id, seconds, rest_seconds}]`) |
| `workout_sessions` | plan_id, started_at, duration_seconds, results (JSON `[{exercise_id, weight, reps, distance_km, minutes, avg_pulse, max_pulse}]`) |
| `notes` + Spalte | learning_area_id |
| `calendar_events` + Spalte | training_plan_id |

## Pakete

`lifeos_learning` (nutzt Notizen), `lifeos_sport` (nutzt Daily Report, Küche, Kalender für nichts außer dem Port), Projekte nutzen `lifeos_learning`. Der Kalender bekommt `trainingPlanChoicesProvider` und `startTrainingProvider` von der App.

## Tests

Kartenreihenfolge (falsch beantwortete zuerst), Prüfung: Fragen aus Quelle, Glossar-Auswahl mit vier Optionen ohne Doppel, Auswertung und Bestehen, Zeitablauf wertet Offenes als falsch; Statistik-Trend; Körperdaten: ein Eintrag je Tag auf zwei Geräten, Schlaf aus Daily Report; Tracker-Summen und Ziele; Plan-Schritte und Gesamtdauer; Abspiel-Ablauf (Übung → Ruhe → nächste, letzte ohne Ruhe); Termin mit Plan übersteht den Sync; Migration 5 → 6.
