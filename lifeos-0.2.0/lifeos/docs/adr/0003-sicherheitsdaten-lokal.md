# ADR-0003: PIN-Daten vorerst nur lokal

- Status: angenommen, wird mit Phase 6 überarbeitet
- Datum: 2026-11-26

## Kontext

Die Architektur (Abschnitt 9) sieht eine PIN für alle Geräte vor, deren Hash mitsynchronisiert wird. In Version 0.1.0 gibt es noch keinen Sync.

## Entscheidung

PIN-Hash (Argon2id), Hash des Wiederherstellungscodes, Fehlversuche und Wartezeit liegen in der Systemtabelle `local_meta` der verschlüsselten Datenbank. Sie erzeugen keine Einträge im Änderungsprotokoll.

## Folgen

- Mit Phase 6 wandern PIN-Hash und Wiederherstellungscode-Hash in eine synchronisierte Tabelle. Fehlversuche und Wartezeit bleiben gerätebezogen in `local_meta`.
- Die Argon2id-Parameter sind bewusst moderat (8 MiB, 2 Durchläufe). Der Hash liegt in der verschlüsselten Datenbank. Wer ihn lesen kann, hat die Daten ohnehin. Die PIN schützt vor Zugriff auf ein entsperrtes Gerät.
