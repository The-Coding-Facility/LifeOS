# Welle A: Kalender und Finanzen – Umsetzungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** LifeOS 0.3.0 mit Kalender (Monat/Woche/Tag, Drag-and-drop, Tags, Serien, Erinnerungen je Gerät) und Finanzen (Buchungen, Saldo-Verlauf, Daueraufträge, Budgets, Sparziele, Jahresliste).

**Architecture:** Neue Tabellen zentral in `lifeos_persistence` (Schema 3), je Tabelle ein `EntitySchema` im Sync. Drei neue Feature-Pakete: `lifeos_tags` (gemeinsame Tags), `lifeos_calendar`, `lifeos_finance`. Reine Rechenlogik (Serien, Erinnerungsplanung, Finanzen, Daueraufträge) ohne Flutter-Abhängigkeit und mit Tests. Benachrichtigungen nur in der App (`flutter_local_notifications`), hinter einer `ReminderSink`-Schnittstelle.

**Tech Stack:** Flutter 3.50, Riverpod 3, go_router 18, Drift 2.35, flutter_local_notifications ^22.3.3, timezone ^0.11.0.

**Spec:** `docs/superpowers/specs/2026-11-26-kalender-finanzen-design.md`

## Global Constraints

- Geld nur als `int` Cent; Anzeige `1.234,56 €`.
- Datumswerte ohne Uhrzeit als `yyyy-mm-dd`; Zeitpunkte als UTC-Millisekunden.
- Jede Schreiboperation über `ChangeRecorder.record` mit den Feldgruppen aus der Spec, in einer Transaktion mit dem Schreiben der Zeile.
- Gelöscht = Tombstone (`deleted_hlc`), nie physisch löschen.
- Keine neuen Pakete außer flutter_local_notifications und timezone.
- Erinnerungen: Fenster 30 Tage, höchstens 50, nur für dieses Gerät oder `"*"`.
- Texte der Oberfläche auf Deutsch.
- Kein Flutter-SDK lokal: Der Build in GitHub Actions (Branch `welle-a`) ist der Compiler.

## Review Focus

- Termin über den Sommerzeitwechsel (29.03./25.10.): Serie bleibt bei derselben Ortszeit → Test in Task 3.
- Monatliche Serie am 31.: Kalender lässt kurze Monate aus, Dauerauftrag bucht am Monatsletzten → Tests in Task 3 und Task 6.
- Dauerauftrag auf zwei Geräten erzeugt: dieselbe ID, keine Doppelbuchung; gelöschte Buchung kommt nicht zurück → Test in Task 6.
- Betragseingabe „1.234,56“, „12,5“, „-3“, „abc“ → Test in Task 1.
- Ganztägiger Termin bleibt am selben Kalendertag, egal in welcher Zeitzone das Gerät gerade ist → Test in Task 3.

---

### Task 1: Geld und Datum im Kern

**Files:** Create `packages/core/lib/src/money.dart`, `packages/core/lib/src/local_date.dart`; Modify `packages/core/lib/lifeos_core.dart`; Test `packages/core/test/money_test.dart`, `packages/core/test/local_date_test.dart`

**Interfaces – Produces:** `String formatCents(int cents, {bool withSign = false})`, `int? parseCents(String input)`, `String isoDate(DateTime d)`, `DateTime parseIsoDate(String s)` (lokale Mitternacht), `DateTime dateOnly(DateTime d)`.

- [ ] Tests: `formatCents(123456) == '1.234,56 €'`, `formatCents(-5) == '-0,05 €'`, `formatCents(500, withSign: true) == '+5,00 €'`; `parseCents('12,5') == 1250`, `parseCents('12.50') == 1250`, `parseCents('1.234,56') == 123456`, `parseCents('1.234') == 123400`, `parseCents('-3') == -300`, `parseCents('') == null`, `parseCents('abc') == null`, `parseCents('1,234') == null`; `isoDate(DateTime(2026, 3, 5, 23, 59)) == '2026-03-05'`, `parseIsoDate('2026-03-05') == DateTime(2026, 3, 5)`.
- [ ] Umsetzen. Regel für `parseCents`: kommen `.` und `,` vor, ist das letzte das Dezimalzeichen; nur `.` mit genau drei Ziffern danach = Tausenderpunkt; mehr als zwei Nachkommastellen = ungültig.
- [ ] Commit.

### Task 2: Tabellen, Migration, Sync-Schemas

**Files:** Modify `packages/persistence/lib/src/tables.dart`, `database.dart`; Modify `packages/sync/lib/src/entity_schema.dart`; Test `packages/persistence/test/migration_test.dart`

**Interfaces – Produces:** Tabellen `Tags` (`TagRow`), `CalendarEvents` (`CalendarEventRow`), `FinanceEntries` (`FinanceEntryRow`), `FinanceRecurring` (`FinanceRecurringRow`), `SavingGoals` (`SavingGoalRow`) mit den Spalten der Spec; `FinanceRecurring.intervalCount` statt `interval`. `schemaVersion == 3`. Einträge `tags`, `calendar_events`, `finance_entries`, `finance_recurring`, `saving_goals` in `defaultEntitySchemas` mit den Feldgruppen der Spec; Tags zusätzlich Gruppe `scope`.

- [ ] Test: frische DB hat `schemaVersion == 3` und alle fünf Tabellen sind abfragbar.
- [ ] Tabellen, `onUpgrade` (`from < 3` → `createTable` für alle fünf), Schemas mit `insertDefaults` für Pflichtspalten.
- [ ] Commit.

### Task 3: Kalender-Modelle und Serien

**Files:** Create package `packages/features/calendar` (`lifeos_calendar`) mit `lib/src/model/event.dart`, `lib/src/model/recurrence.dart`, `lib/src/occurrences.dart`; Test `test/occurrences_test.dart`

**Interfaces – Produces:** `enum RecurrenceFreq { daily, weekly, monthly, yearly }`; `class Recurrence { freq, interval, weekdays (Set<int>, 1=Mo), until (DateTime?, Datum inkl.) ; toJson(); Recurrence.fromJson() }`; `class CalendarEvent { id, title, description, location, allDay, start, end (UTC), recurrence, exdates (Set<String>), tagIds, reminderMinutes, reminderDevices }`; `class Occurrence { event, start, end (lokal), dateKey (String) }`; `List<Occurrence> expandOccurrences(CalendarEvent event, DateTime from, DateTime to)`.

- [ ] Tests: Einzeltermin im Fenster/außerhalb; täglich alle 2 Tage; wöchentlich Mo+Mi; monatlich am 31. lässt Apr/Jun aus; jährlich 29.02. nur in Schaltjahren; `until` inklusive; `exdates` werden ausgelassen; Serie 18:00 Berlin bleibt 18:00 nach dem 29.03.2026; ganztägig 2026-05-01 ergibt `dateKey '2026-05-01'`; Fenster weit nach Serienstart liefert trotzdem Treffer (kein Abbruch durch Obergrenze).
- [ ] Umsetzen (Ortszeit über `DateTime(j, m, t + n, h, min)`; Startindex springen statt ab Serienstart zählen; Obergrenze 1000 Vorkommen je Aufruf).
- [ ] Commit.

### Task 4: Termine speichern und Erinnerungen planen

**Files:** Create `packages/features/calendar/lib/src/event_repository.dart`, `lib/src/reminder_planner.dart`, `lib/src/providers.dart`; Test `test/event_repository_test.dart`, `test/reminder_planner_test.dart`, `test/sync_roundtrip_test.dart`

**Interfaces – Produces:** `class EventDraft {title, description, location, allDay, start, end, recurrence, tagIds, reminderMinutes, reminderDevices}`; `EventRepository(LifeosDatabase, ChangeRecorder)` mit `watchAll()`, `create(EventDraft) → Future<String>`, `update(String id, EventDraft)`, `move(String id, DateTime newStart)`, `excludeOccurrence(String id, String dateKey)`, `detachOccurrence(String id, String dateKey, EventDraft) → Future<String>`, `delete(String id)`; `class PlannedReminder {notificationId, eventId, title, body, fireAt (UTC)}`; `List<PlannedReminder> planReminders({events, deviceId, now, window = 30 Tage, limit = 50})`; Provider `eventRepositoryProvider`, `eventsProvider`, `deviceChoicesProvider` (`StreamProvider<List<DeviceChoice>>`, in der App überschrieben), `class DeviceChoice {id, name}`.

- [ ] Tests: `update` schreibt nur geänderte Feldgruppen; `detachOccurrence` setzt Ausnahme und legt Einzeltermin an; Erinnerung nur bei `"*"` oder eigener ID; keine vergangenen; Obergrenze 50, früheste zuerst; ganztägig = 9:00 Ortszeit minus Vorlauf; stabile `notificationId` für dasselbe Vorkommen; Termin kommt per `SyncEngine` auf dem zweiten Testgerät an.
- [ ] Umsetzen.
- [ ] Commit.

### Task 5: Tags-Paket und Design-Bausteine

**Files:** Create package `packages/features/tags` (`lifeos_tags`): `tag_item.dart`, `tag_repository.dart`, `providers.dart`, `ui/tag_selector.dart`; Create `packages/design_system/lib/src/charts.dart`, `tag_palette.dart`; Modify `adaptive_shell.dart`; Tests `packages/features/tags/test/tag_repository_test.dart`, `packages/design_system/test/charts_test.dart`

**Interfaces – Produces:** `enum TagScope { calendar, finance }` (`key`); `TagItem {id, scope, name, colorIndex, monthlyLimitCents}`; `TagRepository` mit `watch(TagScope)`, `create(TagScope, String name, {int? colorIndex, int? monthlyLimitCents}) → Future<String>`, `update(String id, {String? name, int? colorIndex, int? monthlyLimitCents, bool clearLimit = false})`, `delete(String id)`; `tagRepositoryProvider`, `tagsProvider` (family nach `TagScope`); `TagSelector({scope, selectedIds, onChanged})`; `Color tagColor(int index)`, `tagPaletteSize`; `LineChartView`, `BarChartView` mit `BarGroup`/`BarValue`, `BudgetBar`; `AdaptiveShell(compactMax: 4)` mit „Mehr“.

- [ ] Tests: gleicher Name (Groß/Klein, Leerzeichen) ergibt dieselbe ID; gelöschter Tag wird beim Neuanlegen wiederbelebt; Diagramme bauen ohne Fehler mit 0, 1 und 365 Werten; Shell zeigt bei 6 Zielen auf schmalem Bildschirm 5 Einträge.
- [ ] Umsetzen.
- [ ] Commit.

### Task 6: Finanzen – Logik und Speicher

**Files:** Create package `packages/features/finance` (`lifeos_finance`): `model.dart`, `finance_math.dart`, `recurring.dart`, `finance_repository.dart`, `providers.dart`; Tests `test/finance_math_test.dart`, `test/recurring_test.dart`, `test/finance_repository_test.dart`

**Interfaces – Produces:** `enum EntryKind { income, expense, saving, withdrawal }`; `FinanceEntry`, `RecurringRule` (`RecurringFreq { weekly, monthly, yearly }`), `SavingGoal`; `int signedCents(FinanceEntry)`; `List<int> balanceSeries(entries, {today, days})`; `List<MonthTotals> monthTotals(entries, {today, months = 12})`; `BudgetStatus budgetFor(TagItem, entries, DateTime today)` mit `limitCents, spentCents, remainingCents, lastMonthCents, deltaCents`; `int savedFor(String goalId, entries)`; `List<MonthGroup> yearExpenses(entries, int year)`; `List<DateTime> dueDates(RecurringRule, {today})`; `String recurringEntryId(String ruleId, DateTime date)`; `FinanceRepository` mit `watchEntries/watchRecurring/watchGoals`, `addEntry/updateEntry/deleteEntry`, `addRecurring/updateRecurring/deleteRecurring`, `addGoal/updateGoal/deleteGoal`, `deposit/withdraw`, `generateDueRecurring({DateTime? today}) → Future<int>`.

- [ ] Tests: Saldo mit allen vier Arten; Verlauf 30 Tage hat 30 Werte, letzter = aktueller Saldo; Budget 100 € mit Einkauf 100 € → übrig 0; Vormonat bis zum selben Tag (31.03. vergleicht bis 28.02.); Mehrfach-Tag zählt in beiden Budgets; Dauerauftrag monatlich am 31. bucht am 30.04.; Enddatum beendet; zweimal `generateDueRecurring` erzeugt nichts doppelt; gelöschte erzeugte Buchung bleibt gelöscht; zwei Geräte erzeugen dieselbe ID.
- [ ] Umsetzen.
- [ ] Commit.

### Task 7: Kalender-Oberfläche

**Files:** Create `packages/features/calendar/lib/src/ui/calendar_page.dart`, `month_view.dart`, `time_grid_view.dart`, `event_editor_page.dart`, `series_choice.dart`, `calendar_dashboard_tile.dart`, `format.dart`; Test `test/calendar_page_test.dart`

**Interfaces – Consumes:** Task 3–5. **Produces:** `CalendarPage()`, `CalendarDashboardTile({onOpen})`.

- [ ] Widget-Test: Seite mit zwei Terminen zeigt beide in der Monatsansicht; Tag-Filter blendet den ohne Tag aus; Wechsel auf Woche zeigt Stundenraster.
- [ ] Umsetzen (Drag mit `LongPressDraggable<Occurrence>`/`DragTarget`; Serie → Dialog „Nur diesen“/„Alle“).
- [ ] Commit.

### Task 8: Finanzen-Oberfläche

**Files:** Create `packages/features/finance/lib/src/ui/finance_page.dart`, `overview_tab.dart`, `entries_tab.dart`, `budgets_tab.dart`, `goals_tab.dart`, `year_tab.dart`, `entry_editor_page.dart`, `budget_detail_page.dart`, `finance_dashboard_tile.dart`; Test `test/finance_page_test.dart`

**Interfaces – Consumes:** Task 5–6. **Produces:** `FinancePage()`, `FinanceDashboardTile({onOpen})`.

- [ ] Widget-Test: leere Finanzen bieten „Startguthaben eintragen“ an; mit Buchungen zeigt die Übersicht den Saldo `formatCents`.
- [ ] Umsetzen.
- [ ] Commit.

### Task 9: App verdrahten, Erinnerungen, Plattform, Build

**Files:** Modify `apps/lifeos_app/pubspec.yaml` (0.3.0+3), `lib/main.dart`, `lib/src/bootstrap.dart`, `lib/src/router.dart`, `lib/src/dashboard_page.dart`; Create `lib/src/reminders/reminder_service.dart`, `reminder_sinks.dart`; Modify root `pubspec.yaml`, `tool/prepare.ps1`, `tool/test.ps1`, `installer/lifeos.iss`, `.github/workflows/build.yml`, `README.md`, ADR `docs/adr/0005-kalender-finanzen.md`

- [ ] `ReminderService(events: Stream, deviceId, sink)` plant bei jeder Änderung neu; `PluginReminderSink` (Android/iOS: `cancelAll` + `zonedSchedule`, `AndroidScheduleMode.exactAllowWhileIdle`); `InAppReminderSink` (Windows: Zeitgeber + `show`).
- [ ] Router: Reihenfolge Übersicht, Kalender, Aufgaben, Finanzen, Notizen, Einstellungen.
- [ ] `prepare.ps1`: Rechte und Empfänger im Manifest, Desugaring und Release-Signatur aus `LIFEOS_KEYSTORE*` in `build.gradle.kts`.
- [ ] Workflow: Keystore aus Secret, Branch `welle-a`; Installer: AppUserModelID `de.lifeos.LifeOS`.
- [ ] CI grün auf `welle-a`, dann `main` vorspulen.
