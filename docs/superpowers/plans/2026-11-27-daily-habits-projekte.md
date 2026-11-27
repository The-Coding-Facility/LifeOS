# Welle B: Daily Report, Habits, Projekte – Umsetzungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** LifeOS 0.4.0 mit Daily Report, Habits, Projekten und angehefteten Notizen.

**Architecture:** Schema 4 in `lifeos_persistence`; drei neue Feature-Pakete `lifeos_daily_report`, `lifeos_habits`, `lifeos_projects`. Projekte nutzen Aufgaben (`project_id`), Notizen und Termine (neue Spalte `project_id`). Der Kalender bekommt Projektauswahl über einen Provider, den die App füllt (kein Abhängigkeitskreis).

**Tech Stack:** wie Welle A, keine neuen Pakete.

**Spec:** `docs/superpowers/specs/2026-11-27-daily-habits-projekte-design.md`

## Global Constraints

- Ein Bericht je Tag: ID `Ids.deterministic('daily_report', isoDate(date))`.
- Habit-Haken: ID `Ids.deterministic('habit_check', '$habitId|${isoDate(date)}')`, nie löschen, nur `done` umschalten.
- Uhrzeiten als `HH:mm`, intern Minuten seit Mitternacht.
- Aufgabenliste zeigt nur Aufgaben ohne `project_id`.
- Migration: `calendar_events.project_id` nur per `addColumn`, wenn von Schema 3 aktualisiert wird (bei 2 → 4 legt `createTable` die Spalte schon an).

## Review Focus

- Upgrade direkt von Schema 2 auf 4 (Gerät hat 0.3.0 übersprungen) → Test in Task 1.
- Schlafen 23:30, Aufstehen 07:00 → 7:30 h; Schlafen 01:00, Aufstehen 09:00 → 8 h → Test in Task 3.
- Habit nur Mo–Fr: Wochenende unterbricht die Serie nicht → Test in Task 4.
- Heute noch nicht abgehakt: Serie zählt bis gestern weiter → Test in Task 4.
- Zwei Geräte füllen denselben Tag aus → ein Bericht → Test in Task 3.

---

### Task 1: Schema 4, Sync-Schemas, Erweiterungen von Aufgaben, Notizen, Terminen
Files: `packages/persistence/lib/src/tables.dart`, `database.dart`, `test/migration_test.dart`; `packages/sync/lib/src/entity_schema.dart`; `packages/features/tasks/lib/src/{task_item,task_repository,providers}.dart`; `packages/features/notes/lib/src/{note_item,note_repository,providers}.dart`, `ui/note_editor_page.dart`, neu `ui/pinned_notes_tile.dart`; `packages/features/calendar/lib/src/{model/event,event_repository,providers,series_edit}.dart`, `ui/event_editor_page.dart`.
Produces: `TaskRepository.create(title, {details, projectId})`, `watchByProject(id)`, `projectTasksProvider(id)`; `NoteRepository.create({title, body, projectId})`, `setPinned(id, bool)`, `watchPinned()`, `watchByProject(id)`, `pinnedNotesProvider`, `projectNotesProvider(id)`, `PinnedNotesTile`; `CalendarEvent.projectId`, `EventDraft.projectId`, `projectChoicesProvider` (Standard: leer), `ProjectChoice {id, name}`, `openEventEditor(..., initialProjectId)` exportiert.
Tests: Migration 2→4 und 3→4; Projektaufgaben nicht in `watchAll`; angeheftete Notiz in `watchPinned`; Termin mit Projekt übersteht den Sync.

### Task 2: Daily Report
Files: Paket `packages/features/daily_report` (`model.dart`, `report_math.dart`, `daily_report_repository.dart`, `providers.dart`, `ui/daily_report_page.dart`, `ui/daily_report_tile.dart`).
Produces: `DailyReport`, `parseClock`, `formatClock`, `sleepDuration`, `reportStreak`, `DailyReportRepository` (`idFor`, `watchAll`, `find`, `save`, `delete`), `dailyReportsProvider`, `DailyReportPage`, `DailyReportTile({onOpen})`.
Tests: Schlafdauer, Serie, ein Bericht je Tag auf zwei Geräten, nur geänderte Feldgruppen, Seite zeigt Felder.

### Task 3: Habits
Files: Paket `packages/features/habits` (`model.dart`, `habit_math.dart`, `habit_repository.dart`, `providers.dart`, `ui/habits_page.dart`, `ui/habits_tile.dart`).
Produces: `Habit`, `isDueOn`, `habitStreak`, `completionRate`, `HabitRepository` (`watchHabits`, `create`, `update`, `archive`, `watchChecks`, `setDone`), `habitsProvider`, `habitChecksProvider`, `HabitsPage`, `HabitsTile`.
Tests: fällig je Wochentag, Serie mit freien Tagen, offener Tag, Erfüllung in Prozent, An-/Abhaken über Sync.

### Task 4: Projekte
Files: Paket `packages/features/projects` (`model.dart`, `project_repository.dart`, `providers.dart`, `ui/projects_page.dart`, `ui/project_detail_page.dart`, `ui/project_editor.dart`, `ui/projects_tile.dart`).
Produces: `Project`, `ProjectStatus`, `progressOf`, `deadlineText`, `ProjectRepository`, `projectsProvider`, `ProjectsPage({onOpenProject})`, `ProjectDetailPage({projectId, onOpenNote, onClose})`, `ProjectsTile`.
Tests: Fortschritt, Deadline-Texte, Anlegen/Abschließen/Löschen, Seite zeigt Fortschritt.

### Task 5: App, Navigation, Build
Files: App (`pubspec.yaml` 0.4.0+4, `main.dart`, `bootstrap.dart`, `router.dart`, `dashboard_page.dart`), Shell (Seitenleiste scrollbar), Wurzel-`pubspec.yaml`, `tool/test.ps1`, `README.md`, `docs/adr/0006-daily-habits-projekte.md`, Workflow-Branch `welle-*`.
Check: CI auf `welle-b` grün, `main` vorspulen, Artifacts beider Jobs vorhanden.
