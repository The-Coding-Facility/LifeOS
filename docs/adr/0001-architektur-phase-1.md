# ADR-0001: Grundarchitektur

- Status: angenommen
- Datum: 2026-11-26

## Kontext

LifeOS soll auf Windows, Android und iOS laufen, vollständig offline funktionieren und sich ausschließlich direkt über das lokale Netzwerk synchronisieren. Es gibt keinen Server.

## Entscheidung

Die Architektur aus [docs/architektur.md](../architektur.md) gilt. Kernpunkte:

- Flutter mit einer Codebasis, Pakete im Pub Workspace
- SQLite über Drift, verschlüsselt mit SQLite3MultipleCiphers (SQLCipher-4-Format)
- Jede Änderung schreibt in derselben Transaktion einen Eintrag ins Änderungsprotokoll, mit Hybrid Logical Clock und Vorgänger-Zeitstempel je Feldgruppe
- Sync später als Austausch von Protokolleinträgen über HTTPS mit gegenseitiger Zertifikatsprüfung
- Kein E-Mail-Reset der PIN. Stattdessen Wiederherstellungscode, später zusätzlich Reset über ein gekoppeltes Gerät

## Folgen

- Fachdaten werden nie direkt, sondern immer über ein Repository mit `ChangeRecorder` geschrieben.
- Die App funktioniert ohne Netzwerk vollständig.
- Ein Teil der Plattformfunktionen (Wecker, Hintergrund) braucht später nativen Code.
