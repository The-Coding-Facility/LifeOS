# ADR-0006: Daily Report, Habits, Projekte (Welle B)

Status: angenommen · 27.11.2026 · Details: `docs/superpowers/specs/2026-11-27-daily-habits-projekte-design.md`

## Entscheidungen

- **Ein Bericht pro Tag über die ID.** Die ID des Daily Reports entsteht aus dem Datum. Füllen zwei Geräte denselben Tag offline aus, wird daraus ein Datensatz; je Feldgruppe gewinnt die spätere Änderung, die andere bleibt als Konflikt erhalten.
- **Habit-Haken als umschaltbares Feld.** Eine Zeile je Habit und Tag (ID aus beiden), nur `done` ändert sich. Kein Löschen und Neuanlegen, damit Tombstones nicht mit erneutem Abhaken kollidieren.
- **Serien zählen nur fällige Tage.** Ein Habit nur für Werktage verliert am Wochenende seine Serie nicht. Ist ein Habit heute noch offen, zählt die Serie bis gestern.
- **Projekt-Unterpunkte sind Aufgaben** mit `project_id`. Die Aufgabenliste zeigt nur Aufgaben ohne Projekt.
- **Notizen und Termine** bekommen eine Spalte `project_id`; Notizen zusätzlich `pinned` für die Übersicht.
- **Abhängigkeiten nur nach unten:** Projekte und Daily Report nutzen Aufgaben, Notizen und Kalender direkt. Der Kalender kennt Projekte nicht; seine Projektauswahl liefert die App über `projectChoicesProvider`.

## Folgen

- Schema 4. Die Migration legt `calendar_events.project_id` nur beim Sprung von 3 an; bei 2 → 4 entsteht die Spalte schon mit der Tabelle.
- Beide Geräte müssen auf 0.4.0, sonst synchronisieren sie nicht.
