# Welle B: Daily Report, Habits, Projekte – Design

Stand: 27.11.2026 · Version 0.4.0 · Grundlage: Master-Projektauftrag (Bereiche 3, 4, 5, 6), Architektur Abschnitt 12 (Phase 10)

## Absicht

Die Alltagsmodule: jeden Tag einen kurzen Bericht schreiben, Gewohnheiten abhaken, Projekte mit Unterpunkten und Fortschritt verfolgen. Sie bauen auf Kalender, Aufgaben und Notizen auf. Ihre Daten speisen später das frei gestaltbare Dashboard und den Sportbereich (Schlafdauer).

Erfolg heißt: Der Nutzer füllt abends am Handy den Daily Report aus, hakt Habits ab und sieht am PC dieselben Haken; ein Projekt zeigt Fortschritt in Prozent, seine Notizen und Termine an einem Ort.

## Ziele

**Daily Report**
- Genau ein Bericht pro Tag. Felder: Datum, Erfolge, Gelerntes, Kalender abgearbeitet (Haken), kcal-Ziel erreicht (Haken), Wasser-Ziel erreicht (Haken), schlafen gegangen und aufgestanden (Uhrzeiten), besondere Aktivitäten.
- Neben „Kalender abgearbeitet“ stehen die Termine des Tages zum Nachsehen.
- Verlauf aller Berichte, Serie („7 Tage in Folge“), Schlafdauer aus den beiden Uhrzeiten.
- Übersicht: Haken, ob der heutige Bericht erledigt ist.

**Habits**
- Habit mit Name, Farbe und Rhythmus: jeden Tag oder an bestimmten Wochentagen.
- Ansicht „Heute“ (nur fällige Habits zum Abhaken) und „Woche“ (7 Spalten mit Haken).
- Serie je Habit und Erfüllung der letzten 30 Tage in Prozent.
- Übersicht: heutige Habits zum direkten Abhaken.

**Projekte**
- Projekt mit Name, Beschreibung, optionaler Deadline, Farbe, Status (aktiv/abgeschlossen).
- Unterpunkte zum Abhaken, daraus der Fortschritt in Prozent.
- Projekt-Dashboard: Fortschritt, Deadline („noch 12 Tage“), Unterpunkte, Notizen des Projekts, Termine des Projekts (mit „Termin anlegen“, landet im Kalender).
- Übersicht: aktive Projekte mit Fortschrittsbalken.

**Notizen anheften (Bereich 3)**
- Eine Notiz kann einem Projekt gehören (erscheint im Projekt-Dashboard) und/oder an die Übersicht angeheftet werden.

## Nicht-Ziele (später)

Verknüpfung Projekt ↔ Lernbereich (kommt mit dem Lernmodul), frei gestaltbares Dashboard, tägliche Erinnerung an den Daily Report, Habits mit Zählziel („8 Gläser“), Unterpunkte mit Unter-Unterpunkten.

## Anti-Ziele

- Zwei Geräte füllen denselben Tag aus und es entstehen zwei Berichte.
- Ein Haken bei einem Habit geht beim Sync verloren oder springt hin und her.
- Projekt-Unterpunkte verstopfen die normale Aufgabenliste.

## Rahmenbedingungen

- Bestehende Bausteine: Tabellen zentral, `ChangeRecorder`, `EntitySchema`, deterministische IDs, Tombstones.
- Schema 3 → 4. Beide Geräte müssen wieder aktualisiert werden.
- Keine neuen Pakete von außen.

## Ansätze

| Frage | Möglichkeiten | Gewählt und warum |
| --- | --- | --- |
| Ein Bericht pro Tag | (a) ID aus dem Datum, (b) beliebige ID + Prüfung beim Anlegen | **(a)**. Füllen PC und Handy denselben Tag offline aus, wird es derselbe Datensatz; je Feld gewinnt die spätere Änderung, die andere bleibt als Konflikt erhalten. (b) ergäbe Doppelte. |
| Habit-Haken | (a) Zeile je Habit und Tag mit ID aus beiden, Feld `done`, (b) Zeile anlegen/löschen | **(a)**. An- und Abhaken ist dieselbe Feldgruppe, der Sync entscheidet sauber nach Zeit. Löschen und Neuanlegen würde mit Tombstones kollidieren. |
| Projekt-Unterpunkte | (a) bestehende Aufgaben mit `project_id`, (b) eigene Tabelle | **(a)**. Die Spalte gibt es schon; Unterpunkte sind Aufgaben. Die Aufgabenliste zeigt nur Aufgaben ohne Projekt. |
| Projektnotizen und -termine | (a) Spalte `project_id` an Notizen und Terminen, (b) Verknüpfungstabelle | **(a)**. Eine Notiz/ein Termin gehört zu höchstens einem Projekt; einfacher und sync-freundlich. |
| Modulabhängigkeiten | (a) Projekte und Daily Report nutzen Kalender-, Aufgaben- und Notiz-Paket direkt, (b) nur über Schnittstellen der App | **(a)**. Die Richtung ist eindeutig (höhere Module nutzen Grundmodule), kein Kreis. |

## Daten

| Tabelle | Spalten | Feldgruppen |
| --- | --- | --- |
| `daily_reports` (ID = deterministisch aus Datum) | `date`, `successes`, `learned`, `calendar_done`, `kcal_goal_met`, `water_goal_met`, `slept_at` (`HH:mm`), `woke_at` (`HH:mm`), `activities` | `date`, `successes`, `learned`, `checks` [calendar_done, kcal_goal_met, water_goal_met], `sleep` [slept_at, woke_at], `activities` |
| `habits` | `name`, `color_index`, `weekdays` (JSON, leer = täglich), `archived` | `name`, `color`, `schedule` [weekdays], `archived` |
| `habit_checks` (ID = aus Habit und Datum) | `habit_id`, `date`, `done` | `key` [habit_id, date], `done` |
| `projects` | `name`, `description`, `deadline`, `color_index`, `status` | `name`, `description`, `deadline`, `color`, `status` |
| `notes` + Spalten | `project_id`, `pinned` | neue Gruppen `project`, `pinned` |
| `calendar_events` + Spalte | `project_id` | neue Gruppe `project` |

Schlafdauer: Aufstehen minus Schlafengehen; liegt Aufstehen früher als Schlafengehen, über Mitternacht (23:30 → 07:00 = 7:30 h).

## Navigation

Handy: Übersicht, Kalender, Aufgaben, Finanzen, Mehr (Daily Report, Habits, Projekte, Notizen, Einstellungen). PC: alle in der Seitenleiste. Die Übersicht verlinkt direkt zu Daily Report und Habits.

## Tests

Bericht-ID je Tag gleich auf zwei Geräten und Zusammenführen; Schlafdauer über Mitternacht; Serie des Daily Reports; Habit fällig je Wochentag, Serie mit freien Tagen (Wochentags-Habits brechen am Wochenende nicht ab), Erfüllung in Prozent, Ab- und Anhaken über Sync; Projektfortschritt, Unterpunkte nicht in der Aufgabenliste, Projektnotizen und -termine, Migration 3 → 4.

## Dem Bauenden überlassen

Layout der Formulare, Texte leerer Zustände, Reihenfolge der Kacheln, Farben.
