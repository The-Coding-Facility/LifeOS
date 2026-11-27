# Welle C: Küche und Einkaufsliste – Design

Stand: 27.11.2026 · Version 0.5.0 · Grundlage: Master-Projektauftrag Bereich 7, Architektur Abschnitt 2 (Modul Küche)

## Absicht

Rezepte mit Nährwerten verwalten, Zutaten nur einmal erfassen und danach per Vorschlag wiederverwenden, mit einem Knopf alle Zutaten auf die Einkaufsliste setzen. Beim Einkaufen abhaken, „Gekauft“ drücken, Summe und Finanz-Tag eingeben: Die Ausgabe landet in den Finanzen, die Artikel verschwinden von der Liste.

Erfolg heißt: Der Nutzer legt „Pfannkuchen“ einmal mit Vollmilch, Mehl und Eiern an, sieht die kcal pro Portion, setzt sie in den Einkaufswagen, kauft am Handy ein und sieht am PC die Ausgabe im Budget „Essen“ samt der gekauften Artikel.

## Ziele

**Zutaten**
- Zutat mit Name, Mengeneinheit (g, ml oder Stück) und Nährwerten kcal, Protein, Fett. Bei g und ml je 100 g bzw. 100 ml, bei Stück je Stück.
- Beim Tippen im Rezept erscheinen passende vorhandene Zutaten (Suchleiste mit Vorschlägen). Nach Auswahl nur noch die Menge eingeben. Unbekannte Zutat: einmal Einheit und Nährwerte erfassen.
- Eigener Reiter „Zutaten“ zum Nachschlagen und Korrigieren der Werte.

**Rezepte**
- Titel, Zubereitungszeit in Minuten, Portionen, Tags (eigene, z. B. Frühstück, Mittag), Zutatenliste mit Mengen, großes Textfeld für die Zubereitung.
- kcal, Protein und Fett werden aus den Zutaten berechnet: gesamt und pro Portion. Ändert man die Werte einer Zutat, stimmen alle Rezepte sofort.
- Rezeptliste mit Name, Zeit und kcal pro Portion, Suche und Tag-Filter. Antippen zeigt alle Details.
- Einkaufswagen-Knopf in der Liste und im Rezept: alle Zutaten auf die Einkaufsliste.

**Einkaufsliste**
- Einträge aus Rezepten (mit Menge und Einheit) und von Hand („Klopapier“).
- Ist eine Zutat schon offen auf der Liste, wird die Menge addiert statt doppelt eingetragen.
- Abhaken, dann „Gekauft“: fragt nach Summe und Finanz-Tags (aus den Finanzen), bucht eine Ausgabe „Einkauf: Möhren, Vollmilch …“ und entfernt die abgehakten Einträge. Nicht abgehakte bleiben.
- Der Verlauf steht in den Finanzen beim jeweiligen Budget (vorhandene Buchungsliste des Tags).

**Rundherum**
- Übersicht: Kachel „Einkaufsliste“ mit Anzahl offener Einträge.
- Navigation: „Küche“ kommt am Handy unter „Mehr“.

## Nicht-Ziele (später)

- **Bilder zu Rezepten.** Brauchen die Dateiübertragung zwischen den Geräten (Architektur Abschnitt 5, Schritt 8), die es noch nicht gibt. Sie kommt zusammen mit eigenen Wecktönen.
- Wochen-Essensplaner (offene Entscheidung aus der Architektur: später).
- Kohlenhydrate und weitere Nährwerte, Nährwert-Datenbank aus dem Internet, Portionen beim Einkaufen hochrechnen.

## Anti-Ziele

- Dieselbe Zutat existiert zweimal, weil zwei Geräte sie offline angelegt haben.
- Ein Einkauf bucht die Ausgabe, aber die Artikel bleiben auf der Liste (oder umgekehrt).
- Kommazahlen bei Mengen werden falsch gelesen („1,5 Stück“).

## Ansätze

| Frage | Möglichkeiten | Gewählt und warum |
| --- | --- | --- |
| Zutaten eindeutig halten | (a) ID aus dem normalisierten Namen, (b) beliebige ID + Zusammenführen | **(a)** wie bei Tags. „Vollmilch“ auf zwei Geräten wird ein Datensatz. |
| Zutaten eines Rezepts | (a) JSON-Liste im Rezept, (b) eigene Tabelle Rezeptzutat | **(a)**. Reihenfolge und Mengen bleiben zusammen, eine Feldgruppe; gleichzeitige Änderungen am selben Rezept löst der bekannte Konfliktmechanismus. |
| Nährwerte des Rezepts | (a) aus den Zutaten berechnen, (b) von Hand eintragen | **(a)**, so wie im Auftrag beschrieben („man muss nur die Menge eingeben“). |
| „Gekauft“ | (a) Ausgabe buchen und Einträge entfernen in einer Transaktion, (b) nacheinander | **(a)**. Beides gelingt oder nichts. Das Küchenmodul nutzt dafür das Finanzmodul direkt. |

## Daten (Schema 5)

| Tabelle | Spalten | Feldgruppen |
| --- | --- | --- |
| `ingredients` (ID aus Name) | `name`, `unit` (`g`, `ml`, `piece`), `kcal`, `protein`, `fat` (je 100 g/ml bzw. je Stück, Kommazahl) | `name`, `unit`, `nutrition` [kcal, protein, fat] |
| `recipes` | `title`, `minutes`, `servings`, `tag_ids`, `ingredients` (JSON `[{id, amount}]`), `preparation` | `title`, `details` [minutes, servings], `tags`, `ingredients`, `preparation` |
| `shopping_items` | `name`, `amount`, `unit`, `ingredient_id`, `recipe_id`, `checked` | `item` [name, amount, unit, ingredient_id], `source` [recipe_id], `checked` |

Tags: neuer Bereich `recipes` in der vorhandenen Tag-Tabelle.

## Tests

Nährwerte je 100 g und je Stück, pro Portion; Mengen lesen und anzeigen („1,5“, „250 g“); Zutat auf zwei Geräten → eine; Rezept speichern und laden; Rezept zweimal in den Wagen → Menge addiert; „Gekauft“ bucht Ausgabe mit Tags, entfernt nur abgehakte Einträge; Migration 4 → 5 (und von 2 und 3); Rezeptliste zeigt kcal pro Portion.
