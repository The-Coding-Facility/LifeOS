# Welle A: Kalender und Finanzen – Design

Stand: 26.11.2026 · Version 0.3.0 · Grundlage: Master-Projektauftrag (Bereiche 1 und 2), Architektur Abschnitt 12 (Phase 8)

## Absicht

LifeOS soll Termine und Geld so verwalten, wie es im Auftrag beschrieben ist, lokal und zwischen PC und Handy synchronisiert. Der Kalender ist die Grundlage für spätere Module (Projekttermine, Trainingstermine, Daily Report, Google Kalender). Die Finanzen sind die Grundlage für die Einkaufsliste („gekauft“ erzeugt eine Ausgabe).

Erfolg heißt: Der Nutzer trägt auf einem Gerät einen Termin oder eine Ausgabe ein, sieht sie nach dem Sync auf dem anderen, und eine Erinnerung kommt nur auf dem Gerät, das er dafür gewählt hat.

## Ziele

**Kalender**
- Ansichten Monat, Woche, Tag; Wechsel per Umschalter; „Heute“ und vor/zurück.
- Termine anlegen, bearbeiten, löschen; ganztägig oder mit Uhrzeit; Ort und Beschreibung.
- Termine per Drag-and-drop verschieben: in der Monatsansicht auf einen anderen Tag (Uhrzeit bleibt), in Woche/Tag auf eine andere Uhrzeit (15-Minuten-Raster).
- Tags mit Farbe. „Alle“ ist der Standardkalender. Ein Tag-Filter zeigt nur Termine mit diesem Tag (z. B. nur „Sport“).
- Wiederholungen: täglich, wöchentlich (mit Wochentagen), monatlich, jährlich; „alle n“; Ende offen oder bis Datum. Einzelnen Termin einer Serie löschen oder verschieben („nur dieser“ / „alle“).
- Erinnerung je Termin: keine, zum Beginn, 5/10/15/30 Minuten, 1 Stunde, 1 Tag vorher. Auswahl, auf welchen Geräten sie kommt (Standard: alle Geräte).

**Finanzen**
- Einnahmen und Ausgaben eintragen (Betrag, Titel, Datum, Tags).
- Kontostand (Saldo) und Verlauf der letzten 30 und 365 Tage als Liniendiagramm; Einnahmen/Ausgaben je Monat als Balken.
- Wiederkehrende Buchungen (Daueraufträge): wöchentlich, monatlich, jährlich, „alle n“, optional mit Enddatum.
- Tags mit optionalem Monatslimit (Budget). Je Budget: ausgegeben, übrig, Balken, Vergleich zum Vormonat („20 € weniger als letzten Monat“), Verlauf der Buchungen dieses Tags.
- Sparziele mit Zielbetrag und optionalem Zieldatum; Einzahlen und Entnehmen; Fortschritt.
- Jahresliste: alle Ausgaben eines Jahres, nach Monat gruppiert, mit Summen.

**Rundherum**
- Übersicht: Kacheln „Heute im Kalender“ und „Finanzen“ (Saldo, Budgets über 80 %).
- Navigation für mehr Module: Handy zeigt 4 Einträge plus „Mehr“, PC zeigt alle in der Seitenleiste.
- Fester Android-Signaturschlüssel, damit Updates sich über die alte App installieren lassen.

## Nicht-Ziele (kommen später)

Google Kalender (Phase 9), frei konfigurierbares Dashboard, mehrere Konten oder Währungen (nur Euro), Termine mit Teilnehmern, Anhänge, Import aus Bankdateien, Startmenü-Hintergrundbetrieb unter Windows.

## Anti-Ziele

- Eine Erinnerung kommt auf einem Gerät, das nicht ausgewählt war, oder doppelt.
- Ein wiederkehrender Betrag wird doppelt gebucht, weil zwei Geräte ihn erzeugen.
- Geld wird als Kommazahl gerechnet und ergibt Rundungscent.
- Ein Sync zwischen alter und neuer App-Version beschädigt Daten (wird schon heute über die Schemaversion abgelehnt).

## Rahmenbedingungen

- Bestehende Architektur bleibt: Tabellen zentral in `packages/persistence` (ADR-0002), jede Änderung über `ChangeRecorder` mit Feldgruppen, Sync über `EntitySchema` je Tabelle.
- Kein Flutter-SDK beim Schreiben; der Build in GitHub Actions ist der Compiler. Deshalb möglichst wenige neue Pakete und nur solche, deren aktuelle API geprüft ist.
- Datenbank-Schema 2 → 3. Geräte mit unterschiedlicher Version synchronisieren nicht miteinander (bestehende Prüfung). Beide Geräte müssen aktualisiert werden.

## Ansätze

| Frage | Möglichkeiten | Gewählt und warum |
| --- | --- | --- |
| Kalenderansichten | (a) eigenes Raster mit Flutter-Bordmitteln (`LongPressDraggable`/`DragTarget`), (b) Paket wie `kalender` oder `calendar_view`, (c) Syncfusion | **(a)**. Volle Kontrolle über Drag-and-drop, Tags und Serien; keine fremde API, die sich ungeprüft ändert; Syncfusion braucht eine Lizenz. Mehr eigener Code, dafür testbar. |
| Diagramme | (a) eigene Diagramme mit `CustomPaint`, (b) `fl_chart` | **(a)**. Es braucht nur Linie, Balken und Fortschrittsbalken. Spart eine Abhängigkeit, deren API sich häufig ändert. |
| Erinnerungen | (a) vom Betriebssystem geplant (`flutter_local_notifications` + `zonedSchedule`), (b) Zeitgeber in der App | **Android/iOS (a)**, damit Erinnerungen auch bei geschlossener App kommen. **Windows (b)**: ohne MSIX-Paket kann das Plugin geplante Meldungen unter Windows nicht zurücknehmen, geänderte Termine würden falsch erinnern. Die App zeigt die Meldung selbst, solange LifeOS läuft (auch minimiert). |
| Zeitzonen | (a) Zonenname je Termin + `timezone`-Datenbank, (b) Zeitpunkt in UTC, Serien in Ortszeit des Geräts | **(b)**. Einzeltermine sind feste Zeitpunkte. Serien bleiben zur gleichen Uhrzeit vor Ort, auch über Sommerzeit. Für Google (Phase 9) wird der Zonenname ergänzt. |

## Gemeinsame Bausteine

**Tags** – neue Tabelle `tags` für alle Module, Spalte `scope` (`calendar`, `finance`, später `recipes`). ID deterministisch aus `scope` und normalisiertem Namen (`Ids.deterministic`), damit „Sport“ auf zwei Geräten offline angelegt zu einem Tag zusammenläuft. Felder: Name, Farbe (Index in fester Palette), Monatslimit in Cent (nur Finanzen). Feldgruppen: `name`, `color`, `limit`.

**Geld** – immer ganze Cent (`int`). Eigene Formatierung `1.234,56 €` und eigenes Einlesen („12,5“, „12.50“, „-3“).

**Navigation** – `AdaptiveShell` bekommt eine Höchstzahl für das Handy (4) und einen Eintrag „Mehr“, der die übrigen Bereiche in einem Blatt zeigt. Reihenfolge: Übersicht, Kalender, Aufgaben, Finanzen | Notizen, Einstellungen.

## Kalender im Detail

**Tabelle `calendar_events`** (mit `SyncColumns`)

| Spalte | Bedeutung |
| --- | --- |
| `title`, `description`, `location` | Text, Beschreibung und Ort optional |
| `all_day` | ganztägig |
| `start_at`, `end_at` | UTC-Millisekunden. Ganztägig: UTC-Mitternacht des Kalendertags, Ende exklusiv |
| `recurrence` | JSON oder leer: `{freq, interval, weekdays?, until?}` |
| `exdates` | JSON-Liste ausgelassener Vorkommen (Startdatum `yyyy-mm-dd`) |
| `tag_ids` | JSON-Liste von Tag-IDs |
| `reminder_minutes` | leer = keine Erinnerung, sonst Minuten vor Beginn |
| `reminder_devices` | JSON-Liste von Geräte-IDs, `["*"]` = alle |

Feldgruppen: `title` [title], `details` [description, location], `time` [all_day, start_at, end_at], `recurrence` [recurrence, exdates], `tags` [tag_ids], `reminder` [reminder_minutes, reminder_devices].

**Serien** – Vorkommen werden nur für den sichtbaren Zeitraum berechnet (reines Dart, getestet). Wiederholung in Ortszeit über `DateTime(j, m, t + n, h, min)`, damit Sommerzeit stimmt. Monatlich am 31. fällt in kürzeren Monaten aus (wie bei Google). „Nur dieser Termin“ ändern = Datum in `exdates` der Serie + neuer Einzeltermin mit der Änderung. „Alle“ verschiebt den Serienstart um denselben Abstand.

**Ansichten** – Monat: 6×7-Raster, bis zu 3 Termine je Tag plus „+n“, Tippen auf einen Tag öffnet die Tagesansicht. Woche/Tag: Stundenraster 0–24 Uhr, scrollt zu 7 Uhr, Zeile für ganztägige Termine, Linie für „jetzt“. Termin antippen öffnet die Bearbeitung. Lange drücken und ziehen verschiebt. Bei Serien fragt die App „Nur diesen“ oder „Alle“.

**Erinnerungen** – Ein `ReminderPlanner` (reines Dart, getestet) berechnet aus allen Terminen die Erinnerungen der nächsten 30 Tage, die für dieses Gerät gelten, höchstens 50 (iOS erlaubt 64 geplante). Nach jeder Änderung an Terminen, auch per Sync, wird neu geplant: Android/iOS `cancelAll` und `zonedSchedule` (genau, `exactAllowWhileIdle`); Windows Zeitgeber in der App mit `show`. Android fragt beim ersten Einschalten einer Erinnerung nach der Benachrichtigungs-Erlaubnis. Grenze: Ein Gerät kann nur an Termine erinnern, die es vorher per Sync bekommen hat.

## Finanzen im Detail

**Tabellen** (alle mit `SyncColumns`)

- `finance_entries`: `kind` (`income`, `expense`, `saving`, `withdrawal`), `amount_cents` (immer positiv), `title`, `date` (`yyyy-mm-dd`), `tag_ids` (JSON), `saving_goal_id`, `recurring_id`. Feldgruppen: `amount` [kind, amount_cents], `title`, `date`, `tags`, `link` [saving_goal_id, recurring_id].
- `finance_recurring`: `kind`, `amount_cents`, `title`, `tag_ids`, `freq` (`weekly`, `monthly`, `yearly`), `interval`, `start_date`, `end_date`. Feldgruppen: `amount`, `title`, `tags`, `schedule` [freq, interval, start_date, end_date].
- `saving_goals`: `name`, `target_cents`, `target_date`. Feldgruppen: `name`, `target` [target_cents, target_date].

**Daueraufträge** – Beim Start und beim Öffnen der Finanzen erzeugt die App fällige Buchungen bis heute. Die ID jeder erzeugten Buchung ist deterministisch aus Auftrag und Datum. Erzeugen beide Geräte dieselbe Buchung, ist es derselbe Datensatz. Eine gelöschte erzeugte Buchung bleibt gelöscht (Tombstone wird nicht neu angelegt).

**Rechnen** (reines Dart, getestet) – `kind` hat vier Werte: `income`, `expense`, `saving` (Einzahlung auf ein Sparziel), `withdrawal` (Entnahme). `amount_cents` ist immer positiv. Saldo = Einnahmen − Ausgaben − Einzahlungen + Entnahmen. Gespart je Ziel = Einzahlungen − Entnahmen. Budget eines Tags = Ausgaben mit diesem Tag im laufenden Monat; Vergleich mit dem Vormonat bis zum selben Tag des Monats. Eine Buchung mit mehreren Tags zählt in jedem Budget voll. Den Startbetrag trägt man als Einnahme „Startguthaben“ ein; die Finanzseite bietet das an, solange es keine Buchung gibt.

**Ansichten** – Reiter Übersicht (Saldo, Monat, Verlauf 30/365, Monatsbalken, Budgets), Buchungen (nach Tag gruppiert, Suche), Budgets (Liste; Antippen zeigt Verlauf und Buchungen des Tags), Sparziele, Jahr. Eintragen über ein Formular: Ausgabe/Einnahme, Betrag, Titel, Datum, Tags, Schalter „Wiederholen“.

## Android-Signatur und Plattform

- Schlüssel liegt als GitHub-Secret vor; `prepare.ps1` ergänzt `build.gradle.kts` um eine Release-Signatur aus Umgebungsvariablen (ohne Variablen: Debug-Signatur wie bisher) und um Core-Library-Desugaring (Pflicht für `flutter_local_notifications`).
- `AndroidManifest.xml`: `RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM` (bis API 32), `USE_EXACT_ALARM`, die beiden Empfänger des Plugins.
- Windows: Startmenü-Verknüpfung mit derselben AppUserModelID wie in der App, damit Meldungen den Namen LifeOS tragen.

## Tests

Serienberechnung (Sommerzeit, Monatsende, Ausnahmen), Erinnerungsplanung (Gerätefilter, Zeitfenster, Obergrenze), Finanzrechnungen (Saldo, Budget, Vormonat, Sparziel), Daueraufträge (idempotent, deterministische IDs, Tombstone), Sync-Rundreise für Termine und Buchungen zwischen zwei Testgeräten, Migration 2 → 3.

## Dem Bauenden überlassen

Genaue Farben der Tag-Palette, Layout der Formulare, Texte der leeren Zustände, Aufteilung in Dateien innerhalb der Module, Schritte der Achsenbeschriftung in Diagrammen.
