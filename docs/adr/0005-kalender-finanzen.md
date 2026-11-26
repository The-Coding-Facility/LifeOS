# ADR-0005: Kalender und Finanzen (Welle A)

Status: angenommen · 26.11.2026 · Details: `docs/superpowers/specs/2026-11-26-kalender-finanzen-design.md`

## Entscheidungen

- **Eigene Kalenderansichten statt Paket.** Monat, Woche und Tag mit Flutter-Bordmitteln (`LongPressDraggable`, `DragTarget`). Grund: volle Kontrolle über Serien, Tags und Verschieben; keine fremde API, die sich ungeprüft ändert; Syncfusion bräuchte eine Lizenz.
- **Eigene Diagramme mit `CustomPaint`.** Linie, Balken, Fortschritt. Spart eine Abhängigkeit.
- **Zeiten:** Einzeltermine als UTC-Zeitpunkt. Serien laufen in der Ortszeit des Geräts weiter, damit 18:00 auch nach der Zeitumstellung 18:00 bleibt. Ganztägige Termine als UTC-Mitternacht ihres Kalendertags. Für Google Kalender (Phase 9) kommt der Zonenname dazu.
- **Erinnerungen:** Jedes Gerät plant nur Erinnerungen, die für es gelten (`*` oder eigene ID), 30 Tage im Voraus, höchstens 50. Android/iOS über `flutter_local_notifications` vom Betriebssystem; Windows über Zeitgeber der laufenden App, weil ohne MSIX geplante Meldungen nicht zurückgenommen werden können.
- **Tags** für alle Module in einer Tabelle mit `scope`. ID aus Bereich und normalisiertem Namen, damit zwei Geräte offline denselben Tag anlegen können. Wiederbeleben eines gelöschten Tags setzt `deleted: false` in der Löschgruppe; der Sync hebt die Löschung dann auf.
- **Geld** als ganze Cent. Sparziel-Einzahlungen senken den Kontostand, Entnahmen erhöhen ihn.
- **Daueraufträge** erzeugen Buchungen mit deterministischer ID aus Auftrag und Datum. So entstehen auf zwei Geräten keine Doppelbuchungen, und eine gelöschte Buchung kommt nicht zurück.

## Folgen

- Schema 3. Geräte mit Schema 2 und 3 synchronisieren nicht miteinander, bis beide aktualisiert sind.
- Windows erinnert nicht, wenn LifeOS geschlossen ist. Abhilfe später: Start mit Windows und Symbol im Infobereich, oder MSIX-Paket.
