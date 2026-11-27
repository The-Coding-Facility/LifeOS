# ADR-0007: Küche und Einkaufsliste (Welle C)

Status: angenommen · 27.11.2026 · Details: `docs/superpowers/specs/2026-11-27-kueche-einkauf-design.md`

## Entscheidungen

- **Zutaten-ID aus dem Namen** (wie bei Tags). „Vollmilch“ auf zwei Geräten offline angelegt wird ein Datensatz.
- **Nährwerte je 100 g/ml oder je Stück**, als Kommazahl gespeichert. Rezeptwerte werden immer aus den Zutaten berechnet; ändert man eine Zutat, stimmen alle Rezepte.
- **Rezeptzutaten als JSON-Liste im Rezept**, eine Feldgruppe. Reihenfolge und Mengen bleiben zusammen.
- **Einkaufsliste addiert Mengen** gleicher Zutat in gleicher Einheit, solange der Eintrag offen ist.
- **„Gekauft“ in einer Transaktion:** Ausgabe über das Finanzmodul buchen und abgehakte Einträge entfernen. Titel „Einkauf: …“, höchstens 120 Zeichen. Der Verlauf steht in den Finanzen beim Budget des gewählten Tags.
- **Keine Bilder** in dieser Welle. Sie brauchen die Dateiübertragung zwischen Geräten und kommen mit eigenen Wecktönen.

## Folgen

- Schema 5. Beide Geräte müssen auf 0.5.0.
- Das Küchenmodul hängt vom Finanz- und Tag-Modul ab (Richtung nach unten, kein Kreis).
