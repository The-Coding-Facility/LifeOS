# ADR-0002: Drift-Tabellen liegen zentral im Paket `lifeos_persistence`

- Status: angenommen
- Datum: 2026-11-26

## Kontext

Laut Architektur (Abschnitt 10) besitzt jedes Fachmodul seine eigenen Tabellen. Drift erzeugt die Datenklassen aber in der Datenbank-Bibliothek. Lägen die Tabellen in den Fachmodulen, bräuchten die Module die erzeugten Klassen aus `persistence` und `persistence` die Tabellen aus den Modulen. Das ist eine zyklische Abhängigkeit. Drifts „modulare Codegenerierung“ löst das, ist aber deutlich komplexer einzurichten.

## Entscheidung

Alle Drift-Tabellen werden in `packages/persistence/lib/src/tables.dart` definiert. Die Fachmodule besitzen weiterhin ihre Domäne, ihre Repositories, ihre Feldgruppen und ihre Oberfläche.

## Folgen

- Ein neues Modul ergänzt eine Tabelle in `tables.dart` und erhöht `schemaVersion` mit Migration.
- Fachmodule hängen von `persistence` ab, aber nie voneinander.
- Wird die Zahl der Tabellen unübersichtlich, kann später auf modulare Codegenerierung umgestellt werden, ohne die Repositories zu ändern.
