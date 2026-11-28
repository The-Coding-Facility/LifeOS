# Welle D: Lernen und Sport – Umsetzungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** LifeOS 0.6.0 mit Lernbereichen (Glossar, Karten, Notizen, Ressourcen, Lernen, Prüfung, Statistik) und Sport (Körperdaten, Tracker, Übungen, Pläne mit Abspielen, Dashboard), verknüpft mit Projekten und Kalender.

**Architecture:** Schema 6 (11 Tabellen, Spalten `notes.learning_area_id`, `calendar_events.training_plan_id`). Neuer Helfer `RecordWriter` in `lifeos_persistence` für Anlegen/Ändern/Löschen mit Protokoll, damit die vielen neuen Tabellen nicht je eigenen Schreibcode brauchen. Pakete `lifeos_learning` und `lifeos_sport`; reine Logik (Kartenreihenfolge, Prüfung, Statistik, Abspielen, Summen) getestet ohne Oberfläche.

**Tech Stack:** wie bisher, keine neuen Pakete.

**Spec:** `docs/superpowers/specs/2026-11-28-lernen-sport-design.md`

## Global Constraints

- Körperdaten-ID: `Ids.deterministic('body', isoDate(date))`, jede Messung eigene Feldgruppe.
- Sportziele: eine Zeile mit fester ID `goals`.
- Lerneinheiten und Trainingseinheiten werden nur angelegt (und gelöscht), nie geändert: eine Feldgruppe `data`.
- Prüfung: unbeantwortete Fragen zählen als falsch; bestanden = richtig/gesamt ≥ Grenze.
- Migration: `calendar_events.training_plan_id` nur per `addColumn`, wenn von Schema ≥ 3 aktualisiert wird.

## Review Focus

- Zeitlimit läuft ab, während die App im Hintergrund ist → beim Zurückkommen sofort Ergebnis → Test der Restzeit-Berechnung in Task 2.
- Glossar mit nur einem Eintrag → Prüfungsfrage mit Selbstbewertung statt Auswahl → Test in Task 2.
- Plan mit Vorgabezeit 0 → wartet auf „Weiter“ → Test in Task 4.
- Letzte Übung ohne anschließende Ruhe → Test in Task 4.
- Messwert löschen (Feld leeren) → Wert verschwindet auch auf dem anderen Gerät → Test in Task 4.

---

### Task 1: Schema 6, RecordWriter, Erweiterungen Notizen und Kalender
Produces: Tabellen `LearningAreas`, `GlossaryEntries`, `Flashcards`, `LearningResources`, `StudySessions`, `BodyMeasurements`, `NutritionLogs`, `SportGoals`, `Exercises`, `TrainingPlans`, `WorkoutSessions`; `RecordWriter(db, recorder)` mit `insert`, `update`, `delete`, `allGroups`, `changedGroups`; `NoteRepository.create(learningAreaId:)`, `watchByLearningArea`, `learningAreaNotesProvider`; `CalendarEvent.trainingPlanId`, `EventDraft.trainingPlanId`, `TrainingPlanChoice`, `trainingPlanChoicesProvider`, `startTrainingProvider`.
Tests: Migration 2/3/4/5 → 6, RecordWriter schreibt und protokolliert.

### Task 2: Lernlogik und Speicher (`lifeos_learning`)
Produces: Modelle, `answerStats`, `learningOrder`, `buildExam`, `scoreExam`, `remainingTime`, `studyTrend`, `mostMissed`, `LearningRepository`, Provider.
Tests: Reihenfolge, Prüfungsaufbau, Glossar-Auswahl, Auswertung, Zeit, Trend, Speicher.

### Task 3: Lern-Oberfläche
Produces: `LearningPage`, `LearningAreaPage`, Lern- und Prüfungsablauf.

### Task 4: Sportlogik und Speicher (`lifeos_sport`)
Produces: Modelle, `intakeOn`, `measureSeries`, `effectiveSleep`, `exerciseSeries`, `TrainingPlayback`, `SportRepository`, Provider.
Tests: Summen, Reihen, Schlaf aus Daily Report, Abspielen, Körperdaten über Sync.

### Task 5: Sport-Oberfläche
Produces: `SportPage`, `PlaybackPage`, `SportTile`.

### Task 6: Projekte ↔ Lernen, App, Build, Downloads
App 0.6.0+6, Navigation, Übersicht, Ports für Kalender und Lernen, README, ADR-0008. CI auf `welle-d` grün, `main` vorspulen, Artifacts prüfen.
