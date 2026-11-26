# LifeOS – Technische Architekturplanung (Phase 1)

Stand: 2026-11-26

## Kurzfassung

Die Architektur ist umsetzbar: Flutter, eine verschlüsselte SQLite-Datenbank je Gerät und eine eigene Peer-to-Peer-Synchronisation über ein Änderungsprotokoll erfüllen den Local-First-Anspruch ohne Server. Drei Teile des Konzepts sind so aber nicht zuverlässig umsetzbar. Dafür gibt es unten Alternativen.

**Kernentscheidungen**

- **Plattform:** Flutter/Dart, eine Codebasis, plattformspezifische Teile hinter Adapter-Schnittstellen.
- **Datenbank:** SQLite über Drift, verschlüsselt mit SQLite3MultipleCiphers (SQLCipher-kompatibel), Schlüssel im Schlüsselspeicher des Betriebssystems.
- **Sync:** Jede Änderung landet in derselben Transaktion im Änderungsprotokoll. Geräte tauschen per Versionsvektor nur fehlende Einträge aus, auch indirekt (iPhone → PC → Android).
- **Konflikte:** Feldgruppen-genaues Last-Writer-Wins mit Hybrid Logical Clocks. Gleichzeitige Änderungen werden erkannt und der unterlegene Wert bleibt zur manuellen Prüfung erhalten. Kein vollwertiges CRDT-Framework.
- **Transport:** TLS mit gegenseitiger Zertifikatsprüfung (mTLS) und beim Koppeln fest hinterlegten Gerätezertifikaten. Kopplung per QR-Code in beide Richtungen.
- **Google:** Optionales Plugin-Modul, Polling mit Sync-Tokens, deterministische IDs gegen Duplikate.

**Nicht zuverlässig umsetzbar – mit Alternative**

| Anforderung | Problem | Vorschlag |
| --- | --- | --- |
| „PIN vergessen“ per E-Mail | Eine App ohne Server kann keine E-Mail sicher versenden. Ein eingebettetes SMTP-Passwort wäre für jeden auslesbar. | E-Mail entfällt als Pflicht. PIN-Reset über ein anderes gekoppeltes Gerät, Wiederherstellungscode beim Einrichten, Biometrie als Komfort. |
| Lichtwecker auf iOS | iOS erlaubt keiner App, den Bildschirm im Hintergrund einzuschalten. | Echter Wecker über AlarmKit (ab iOS 26). Lichtwecken nur im „Nachttisch-Modus“ bei geöffneter App. Auf Android voll umsetzbar. |
| Hintergrund-Sync zwischen zwei Handys | iOS pausiert Apps im Hintergrund, Android drosselt sie. Zwei Handys synchronisieren nur, wenn beide die App offen haben. | Der Windows-PC läuft als dauerhaft erreichbarer Peer im Infobereich. Er ist kein Server, nur das Gerät, das am häufigsten wach ist. |

Weitere Einschränkungen, die das Konzept nicht kippen: Google-Termine werden nur abgefragt, nicht live geschickt, weil Push einen öffentlichen Server bräuchte. Ein Wecker oder eine Erinnerung klingelt nur auf eingeschalteten Geräten. Ein widerrufenes Gerät behält die Daten, die es bereits hat.

## 1. Technologieauswahl

Flutter und Drift bleiben, wie von dir bevorzugt. Geändert wird die Verschlüsselungsbibliothek: SQLite3MultipleCiphers statt des separaten SQLCipher-Pakets. Plattformnahe Funktionen (Wecker, Hintergrund, Benachrichtigungen) brauchen trotz Flutter eigenen Kotlin-, Swift- und C++-Code. Das ist eingeplant, nicht vermeidbar.

| Baustein | Wahl | Begründung | Kritische Bewertung |
| --- | --- | --- | --- |
| UI und Laufzeit | Flutter (stable), Dart 3 | Eine Codebasis für Windows, Android, iOS. Desktop-Unterstützung ist stabil. | iOS-Builds brauchen einen Mac mit Xcode (eigener Mac oder gemieteter Mac-Build-Dienst). Nur der Build, nicht die App, hängt davon ab. |
| Zustand und Abhängigkeiten | Riverpod | Testbar ohne Widget-Baum, saubere Abhängigkeitsinjektion zwischen Modulen. | Alternative Bloc ist gleichwertig. Wichtig ist nur, sich auf eines festzulegen. |
| Navigation | go\_router mit adaptiver Shell | Seitenleiste auf Windows, Tab-Leiste auf dem Handy, gleiche Routen. | Unkritisch. |
| Lokale Datenbank | SQLite über Drift | Typsichere Abfragen, Migrationen mit Schema-Tests, reaktive Streams für die UI. | Ausgereift. Alle Tabellen liegen in einer Datei, damit modulübergreifende Aktionen atomar bleiben. |
| Verschlüsselung der DB | SQLite3MultipleCiphers über das sqlite3-Paket (Build-Hooks) | Seit Drift 2.32 und sqlite3 3.x genügt eine Zeile in der pubspec. Das separate sqlcipher\_flutter\_libs entfällt ([Drift-Doku](https://drift.simonbinder.eu/docs/platforms/encryption/)). | Bietet das SQLCipher-Format an, daher ist deine SQLCipher-Anforderung erfüllt. Risiko: Build-Hooks sind relativ neu. Versionen fest pinnen und in Phase 2 auf allen drei Plattformen bauen. |
| Schlüsselspeicher | flutter\_secure\_storage | iOS Keychain, Android Keystore, Windows an das Benutzerkonto gebunden. | Windows bietet ohne TPM-Bindung schwächeren Schutz als Mobilgeräte. BitLocker empfehlen. |
| Kryptografie | dart:io-TLS (BoringSSL) für den Transport, libsodium (sodium\_libs) für Argon2id und Backup-Verschlüsselung | Etablierte Implementierungen, nichts selbst gebaut. | Zertifikate werden per Fingerabdruck geprüft, nicht über eine Zertifizierungsstelle. Das ist Absicht (siehe Abschnitt 6). |
| Geräteerkennung | bonsoir (mDNS/DNS-SD) | Nutzt die Systemdienste: Android NSD, Apple Bonjour, Windows-DNS-API ([bonsoir\_windows](https://pub.dev/documentation/bonsoir_windows/5.1.2)). | Nicht multicast\_dns verwenden: rohe Multicast-Sockets brauchen auf iOS eine Sonderberechtigung von Apple. Alternative bei Problemen: nsd. |
| Sync-Transport | HTTPS-Server und -Client aus dart:io mit gegenseitiger Zertifikatsprüfung | Kein Fremdframework, gut debugbar, stapelweise Datenübertragung. | Windows-Firewall und WLAN-Client-Isolation können blockieren (Abschnitt 11). |
| Benachrichtigungen | flutter\_local\_notifications | Unterstützt Android, iOS und seit Version 19 auch Windows, inklusive zeitgesteuerter Toasts ([zonedSchedule](https://pub.dev/documentation/flutter_local_notifications/latest/flutter_local_notifications/FlutterLocalNotificationsWindows/zonedSchedule.html)). | Windows kennt keine wiederholenden Benachrichtigungen. Die App plant jede Erinnerung einzeln. |
| Wecker | Eigene Plattformkanäle: Android AlarmManager, iOS AlarmKit, Windows In-App | Nur die Systemmechanismen klingeln zuverlässig bei gesperrtem Gerät. | Höchster nativer Anteil im Projekt. Details in Abschnitt 11. |
| Hintergrundarbeit | workmanager (Android), BGTaskScheduler (iOS), Infobereich und Autostart (Windows) | Plattformkonforme, sparsame Ausführung. | iOS und Android entscheiden selbst, wann das passiert. Nichts Wichtiges darf davon abhängen. |
| QR-Codes | qr\_flutter zum Anzeigen, mobile\_scanner zum Scannen | Bewährt. | PCs haben oft keine Kamera. Deshalb funktioniert die Kopplung in beide Richtungen. |
| Diagramme | fl\_chart | Kostenlos, flexibel, alle Plattformen. | Ausreichend für Linien-, Balken- und Fortschrittsdiagramme. |
| Kalender-UI | Prototyp in Phase 4: freies Paket (z. B. kalender) gegen Syncfusion Calendar | Monats-, Wochen- und Tagesansicht mit Drag-and-drop ist eines der größten UI-Stücke. | Syncfusion ist proprietär, die Community-Lizenz gilt nur unter Umsatzgrenzen. Entscheidung nach dem Prototyp. |
| Google | googleapis-Paket, google\_sign\_in auf Android/iOS, eigener Loopback-PKCE-Flow auf Windows | Offizielle Calendar API v3. | google\_sign\_in unterstützt Windows nicht. Details in Abschnitt 8. |
| Monorepo | Dart Pub Workspaces | Mehrere Pakete, ein Abhängigkeitsstand. | Melos nur, falls Skripte nötig werden. |

**Bewusst verworfen**

- **Isar, Hive, ObjectBox:** keine relationalen Abfragen für Statistiken und Finanzauswertungen. Isar wird kaum noch gepflegt.
- **Realm, Couchbase Lite, PowerSync, ElectricSQL:** Sync-Funktionen setzen einen Server voraus, sind eingestellt oder ohne offizielle Dart-Unterstützung.
- **Automerge oder Yjs als CRDT-Framework:** kein ausgereifter Dart-Port. Für eure Datenmodelle reicht ein schlankeres Verfahren (Abschnitt 7).
- **Datenbankdatei synchronisieren:** wie gefordert ausgeschlossen. Es würde Datenverlust bei gleichzeitigen Änderungen garantieren.

## 2. Komponentenübersicht

Die App besteht aus 12 Fachmodulen und 9 Kernkomponenten. Die Modulliste in Abschnitt 7 deines Auftrags weicht vom Konzept ab. Finanzen, Daily Report, Projekte, Lernen, Wecker und Dashboard fehlen dort. Der Essensplaner mit Wochenplanung steht dagegen nicht im Konzept. Die Tabelle führt beides zusammen.

**Fachmodule**

| Modul | Inhalt | Wichtigste Daten | Spricht mit |
| --- | --- | --- | --- |
| Dashboard | Baukasten aus Kacheln, Sync-Status, Daily-Report-Haken, Todos | Layout je Geräteklasse, Kachel-Konfiguration | Alle Module über die Kachel-Registry |
| Kalender | Monat, Woche, Tag, Drag-and-drop, Tags, Filteransichten, Erinnerungen | Termin, Wiederholungsregel, Ausnahme, Erinnerung | Projekte, Sport (Trainingsplan-Termin), Google |
| Aufgaben | Todos und Projekt-Unterpunkte als ein Datentyp | Aufgabe (optional mit Projekt-ID), Erledigt-Status | Projekte, Dashboard |
| Finanzen | Ein- und Ausgaben, Wiederholungen, Saldo, 30/365-Tage-Verlauf, Budgets je Tag, Vormonatsvergleich, Sparziele, Jahresliste | Buchung (Betrag in Cent), Wiederholungsregel, Budget, Sparziel | Einkaufsliste |
| Notizen | Notizen in Markdown, an Dashboards anheftbar | Notiz, Anheftung (Notiz → beliebiges Ziel) | Dashboard, Projekte, Lernen |
| Daily Report | Genau ein Bericht pro Tag mit Erfolgen, Gelerntem, Zielhaken, Schlafzeiten, Aktivitäten | Tagesbericht (ID aus dem Datum abgeleitet) | Sport (Schlafdauer), Dashboard |
| Habits | Allgemeine und wochentagsbezogene Gewohnheiten, Abhaken | Gewohnheit, Erledigung pro Tag | Dashboard |
| Projekte | Deadlines, Unterpunkte mit Fortschritt in Prozent, Projekt-Dashboard, Notizen, Termine, Lernverknüpfung | Projekt, Verknüpfungen | Aufgaben, Kalender, Notizen, Lernen |
| Küche | Rezepte mit Bild und Nährwerten, Zutatendatenbank mit Vorschlägen, Einkaufsliste, „Gekauft“ mit Summe und Finanz-Tag. Wochenplanung als spätere Erweiterung. | Rezept, Zutat (Nährwerte je 100 g/ml oder Stück), Rezeptzutat, Listeneintrag, Einkauf | Finanzen |
| Lernen | Lernbereiche, Glossar mit Suche, Karteikarten (Text oder Multiple Choice), Notizen, Ressourcen, Lernmodus, Prüfung mit Zeitlimit, Statistik | Lernbereich, Begriff, Karte, Lernsitzung, Antwort, Prüfung | Projekte |
| Sport | Sport-Dashboard, Ernährungs- und Wassertracker mit Zielen, tägliche Körperdaten, Übungskatalog mit Suche, Trainingspläne mit Abspielmodus | Messung, Eintrag (+250 ml usw.), Übung, Plan, Trainingseinheit | Kalender, Daily Report |
| Wecker | Eigene Töne, Lichtwecken mit Farbe, Lautstärke, Auswahl der Geräte, nur Benachrichtigung | Wecker, Geräteauswahl, Ton (als Datei) | Erinnerungsplaner |

Ziele und Statistiken aus deiner Liste werden keine eigenen Module. Ziele leben dort, wo sie entstehen (Sparziel, kcal-Ziel, Projekt-Deadline). Statistiken liefert jedes Modul über eine Kennzahlen-Schnittstelle, das Dashboard zeigt sie an. So gibt es keine zweite Wahrheit über dieselben Daten.

**Kernkomponenten**

| Komponente | Aufgabe |
| --- | --- |
| Core | IDs (UUIDv7, deterministische UUIDv5), Hybrid Logical Clock, Fehler- und Ergebnistypen, gemeinsames Tag-System mit Geltungsbereich (Kalender, Finanzen, Rezepte) |
| Persistenz | Drift-Datenbank, Migrationen, Repository-Basis, die jede Schreiboperation automatisch ins Änderungsprotokoll schreibt |
| Sync-Engine | Änderungsprotokoll, Versionsvektoren, Zusammenführen, Konflikterkennung, Protokoll, Transport, Erkennung im Netz |
| Geräte und Kopplung | Geräteidentität, Zertifikate, Liste vertrauenswürdiger Geräte, Widerruf |
| Sicherheit | App-Sperre mit PIN, Sperre nach 10 Minuten, Biometrie, Schlüsselverwaltung, Wiederherstellung |
| Backup | Verschlüsselter Export und Import |
| Erinnerungsplaner | Sammelt Erinnerungen aller Module, plant sie nur auf den gewählten Geräten, hält Plattformgrenzen ein |
| Integrationen | Google-Kalender als abschaltbares Modul |
| Plattformadapter | Schnittstellen für Benachrichtigung, Wecker, Hintergrund, Schlüsselspeicher, Erkennung, Dateien, Biometrie, je eine Implementierung pro Plattform |

**Wie Module miteinander reden, ohne sich zu kennen**

1. Ein Vertragspaket enthält nur Schnittstellen, z. B. `ShoppingListPort.addIngredients()` oder `FinancePort.recordExpense()`.
2. Jedes Fachmodul hängt nur vom Core und vom Vertragspaket ab, nie von einem anderen Fachmodul.
3. Die App-Schale verdrahtet beim Start, welches Modul welche Schnittstelle erfüllt.
4. Modulübergreifende Aktionen laufen in einer einzigen Datenbanktransaktion. Beispiel „Gekauft“: Ausgabe buchen, Kauf protokollieren und Einträge entfernen gelingen gemeinsam oder gar nicht.
5. Nach dem Speichern verschickt ein Ereignisbus Fachereignisse wie `PurchaseCompleted`. Statistiken und Dashboard reagieren darauf, ohne dass der Absender sie kennt.
6. Ein abgeschaltetes Modul (z. B. Google) meldet seine Schnittstellen einfach nicht an. Aufrufer prüfen, ob es da ist.

## 3. Architekturdiagramm

```text
┌─ Ein Gerät · Windows, Android oder iOS ───────────────────────────┐
│ Präsentation: App-Shell · Navigation · Dashboard-Kacheln          │
│        ▼                                                          │      ┌ Google Calendar ┐
│ Fachmodule (12), nur über Ports verbunden ◄── Google-Modul (opt.) ◄─────► (optional, Internet)
│        ▼                                                          │      └─────────────────┘
│ Kerndienste: App-Sperre · Erinnerungsplaner · Backup · Kopplung   │
│        ▼                                                          │      ┌ Geräte im LAN ──┐
│ Persistenz: Drift + SQLite3MultipleCiphers ◄──► Sync-Engine ◄────────────► Windows-PC      │
│   (Daten + Änderungsprotokoll, ein Commit)      HLC · Vektoren    │      │ Android-Handy   │
│        ▼                                        Merge · mTLS      │      │ iPhone          │
│ Plattformadapter: Benachrichtigung · Wecker · Hintergrund · Keys  │      └─────────────────┘
└───────────────────────────────────────────────────────────────────┘
```

Jede Schicht nutzt nur die darunterliegende. Fachmodule sehen weder die Sync-Engine noch andere Fachmodule. Die Sync-Engine liest das Änderungsprotokoll aus der Persistenz und ist der einzige Weg zu anderen Geräten. Google hängt als abschaltbares Modul am Kalender-Port und ist für den Rest der App unsichtbar.

## 4. Datenbankstrategie

Jedes Gerät hat genau eine verschlüsselte SQLite-Datei. Jede fachliche Änderung schreibt in derselben Transaktion einen Eintrag ins Änderungsprotokoll. Ohne diesen Eintrag gibt es keine Änderung. Das ist die wichtigste Regel des gesamten Datenmodells.

**Speicherort und Schutz je Plattform**

| Plattform | Ort | Zusätzlicher Schutz |
| --- | --- | --- |
| Android | App-privates Verzeichnis | Schlüssel im Android Keystore. Automatisches Android-Backup für die DB-Datei abschalten. |
| iOS | Application Support im App-Container | Schlüssel im Keychain mit „nach erstem Entsperren, nur dieses Gerät“. Datei aus dem iCloud-Backup ausschließen, sonst landen Daten ungefragt in der Cloud. Dateischutzklasse „bis zum ersten Entsperren“, damit Hintergrund-Sync die DB öffnen kann. |
| Windows | Lokaler App-Datenordner des Benutzers | Schlüssel an das Windows-Konto gebunden. BitLocker empfehlen, weil Windows-Apps nicht voneinander abgeschottet sind. |

**Verschlüsselung**

- SQLite3MultipleCiphers im SQLCipher-4-Format (AES-256, HMAC-SHA512). So lässt sich die Datei zur Fehlersuche mit gängigen SQLCipher-Werkzeugen öffnen.
- Schlüssel: 256 Bit aus dem Zufallsgenerator des Systems, als Rohschlüssel übergeben. Er wird nicht aus der PIN abgeleitet, Begründung in Abschnitt 9.
- Bilder und Wecktöne liegen als Dateien neben der DB. Sie sind mit eigenem Schlüssel verschlüsselt und nach ihrem SHA-256-Hash benannt. Gleiche Datei bedeutet gleicher Name, das vereinfacht die Übertragung.

**Pflichtfelder jeder synchronisierten Tabelle**

| Feld | Inhalt | Zweck |
| --- | --- | --- |
| `id` | UUIDv7 oder deterministische UUIDv5 | Weltweit eindeutig, zeitlich sortierbar |
| `created_at`, `created_by` | UTC-Zeitpunkt, Geräte-ID | Herkunft |
| `updated_hlc`, `updated_by` | Hybrid-Logical-Clock-Zeitstempel, Geräte-ID | Letzte Änderung, Reihenfolge trotz falsch gehender Uhren |
| `deleted_hlc` | HLC oder leer | Tombstone statt physischem Löschen |

Dazu kommen zwei Systemtabellen, damit die Fachtabellen schlank bleiben:

- **`row_clock`**: HLC je Feldgruppe einer Zeile. Das ist die Versionsinformation, die die Konflikterkennung braucht.
- **`change_log`**: Schlüssel ist (Ursprungsgerät, laufende Nummer). Er enthält Tabelle, Zeilen-ID, Operation, geänderte Feldgruppen mit neuem Wert und Vorgänger-HLC sowie eine Transaktions-ID.

Der Sync-Status eines Datensatzes wird abgeleitet, nicht gespeichert. Ein Datensatz gilt als „noch nicht synchronisiert“, solange seine letzte Änderung von keinem anderen Gerät bestätigt wurde.

**Datenregeln**

- Geldbeträge als ganze Cent, nie als Gleitkommazahl.
- Zeitpunkte in UTC plus IANA-Zeitzone des Termins. Ganztägige Termine als reines Datum ohne Uhrzeit.
- Volltextsuche über SQLite FTS5 für Glossar, Zutaten, Übungen und Notizen.
- Mengen von Zuordnungen (Tags an Terminen, Zutaten in Rezepten) als eigene Zeilen, nie als Liste in einem Feld. Nur so lassen sie sich konfliktfrei zusammenführen.
- Zählwerte wie Wasser als einzelne Einträge (+250 ml), nie als Summenfeld. Die Summe ergibt sich beim Lesen.

**Migrationen**

- Drift-Schemaversionen mit gespeicherten Schema-Abzügen und automatisch erzeugten Migrationstests für jeden Versionssprung.
- Felder werden nur hinzugefügt. Ein Feld umbenennen oder entfernen geht nur über zwei Versionen.
- Das Änderungsprotokoll speichert logische Feldnamen, keine Spaltenpositionen.
- Schema-Sperre beim Sync: Geräte tauschen ihre Schemaversion aus. Liefert ein neueres Gerät Felder, die das ältere nicht kennt, pausiert der Sync mit dem Hinweis „Bitte App aktualisieren“. Das ist realistisch, weil iOS-Updates durch Apples Prüfung länger brauchen als Windows-Updates.

**Lokale Backups und Wiederherstellung**

- Automatischer Schnappschuss täglich per `VACUUM INTO`, 7 Generationen, verschlüsselt wie die DB.
- Export auf Wunsch als eine Datei mit DB-Abzug und allen Bildern und Tönen. Sie ist mit einem eigenen Backup-Passwort verschlüsselt (Argon2id, XChaCha20-Poly1305 via libsodium).
- Nach jeder Wiederherstellung erhält das Gerät eine neue Geräte-ID. Grund: Die wiederhergestellte laufende Nummer liegt hinter dem Stand, den andere Geräte schon kennen. Neue Änderungen würden sonst als „bereits gesehen“ verworfen.
- Protokoll-Verdichtung: Einträge, die alle gekoppelten Geräte bestätigt haben, werden auf den letzten Stand je Zeile zusammengefasst. Tombstones bleiben.

## 5. Synchronisationskonzept

Geräte tauschen Änderungen aus, keine Datenbankzustände. Jede Änderung trägt einen eindeutigen Schlüssel (Ursprungsgerät, laufende Nummer). Ein Versionsvektor hält fest, bis zu welcher Nummer ein Gerät die Änderungen jedes anderen Geräts kennt. Zwei Geräte vergleichen ihre Vektoren und schicken sich genau die fehlenden Einträge. Das gilt auch für Einträge dritter Geräte: Was das iPhone dem PC gegeben hat, gibt der PC später an das Android-Handy weiter.

**Bausteine**

| Baustein | Funktion |
| --- | --- |
| Hybrid Logical Clock (HLC) | Zeitstempel aus Systemzeit und Zähler. Eine Ursache hat immer einen kleineren Zeitstempel als ihre Folge, auch wenn eine Geräteuhr falsch geht. Bei mehr als 24 h Abweichung in die Zukunft warnt die App statt zu übernehmen. |
| Änderungsprotokoll (Outbox) | Wird in derselben Transaktion wie die fachliche Änderung geschrieben. Empfangene Einträge werden ebenfalls gespeichert, damit das Gerät sie weiterreichen kann. |
| Versionsvektor | Je Ursprungsgerät die höchste lückenlos angewendete Nummer. |
| Bestätigungsvektor je Partner | Was ein Partner nachweislich hat. Grundlage für „Synced“ und für die Protokoll-Verdichtung. |

**Ablauf einer Sync-Sitzung**

1. **Erkennen:** Jedes Gerät kündigt per mDNS den Dienst `_lifeos._tcp` an. Der TXT-Eintrag enthält nur eine anonyme Kennung des eigenen Datenbestands, eine kurze Gerätekennung, Protokollversion und Port. Fremde Geräte im WLAN sehen keine Namen.
2. **Verbinden:** HTTPS mit gegenseitiger Zertifikatsprüfung. Beide Seiten prüfen den Fingerabdruck der Gegenseite gegen die Liste gekoppelter Geräte. Unbekannt oder widerrufen bedeutet sofortiger Abbruch.
3. **Begrüßen:** Austausch von App-, Schema- und Protokollversion, Versionsvektor und Stand der Geräteliste. Passt das Schema nicht, endet die Sitzung mit Hinweis.
4. **Geräteliste zuerst:** Änderungen an der Liste gekoppelter Geräte werden vor allen Fachdaten übertragen. Ein Widerruf verbreitet sich so mit Vorrang.
5. **Differenz bestimmen:** Jede Seite ermittelt die Einträge, deren Nummer über dem Vektor der Gegenseite liegt.
6. **Übertragen:** In Stapeln zu je 500 Einträgen, sortiert nach HLC, in beide Richtungen. Die Sortierung sorgt dafür, dass eine Änderung nie vor ihrer Ursache ankommt.
7. **Anwenden:** Jeder Stapel in einer Transaktion: bereits bekannte Einträge überspringen, Feldgruppen zusammenführen (Abschnitt 7), Konflikte notieren, Eintrag ins eigene Protokoll übernehmen, Vektor erhöhen. Erst dann Commit.
8. **Dateien nachladen:** Fehlende Bilder und Töne per Hash abrufen. Nach Prüfung des Hashes in eine temporäre Datei schreiben, dann umbenennen. Bis dahin zeigt die App einen Platzhalter.
9. **Bestätigen:** Beide Seiten melden ihren neuen Vektor. Das Sync-Symbol springt auf „Synced“.

**Warum ein Abbruch nichts beschädigt**

- Ein Stapel wird ganz oder gar nicht übernommen. Bricht die Verbindung ab, bleibt der Vektor auf dem alten Stand.
- Beim nächsten Versuch kommen dieselben Einträge noch einmal. Bekannte Schlüssel werden ignoriert, das Anwenden ist idempotent.
- Das Zusammenführen hängt nur von den HLC-Zeitstempeln ab, nicht von der Reihenfolge der Partner. Alle Geräte landen beim selben Ergebnis, egal wer mit wem zuerst synchronisiert.
- Dateien werden erst nach Hash-Prüfung sichtbar. Halbe Dateien gibt es nicht.

**Wann synchronisiert wird**

| Auslöser | Windows | Android | iOS |
| --- | --- | --- | --- |
| App wird geöffnet oder kommt in den Vordergrund | ja | ja | ja |
| Lokale Änderung (nach 2 s Ruhe) | ja | ja, wenn geöffnet | ja, wenn geöffnet |
| Partner taucht im Netz auf | ja, dauerhaft im Infobereich | ja, wenn geöffnet | ja, wenn geöffnet |
| Wechsel ins WLAN | ja | ja, über WorkManager | nur wenn die App aktiv ist |
| Regelmäßig im Hintergrund | dauerhaft, solange angemeldet | etwa alle 15 min, vom System gesteuert | gelegentlich, wann iOS es erlaubt |
| Knopf „Jetzt synchronisieren“ | ja | ja | ja |

**Sync-Symbol auf dem Dashboard**

- **Syncing:** eine Sitzung läuft.
- **Synced:** jeder erreichbare Partner hat die letzte lokale Änderung bestätigt.
- **Offline-Modus:** kein Partner erreichbar. Die Zahl ausstehender Änderungen steht daneben.

In der Geräteverwaltung steht pro Gerät der Zeitpunkt der letzten Synchronisation. „Synced“ heißt also nicht, dass ein ausgeschaltetes Gerät schon alles hat.

**Dein Beispiel durchgespielt**

1. Du legst auf dem iPhone einen Termin an, der PC ist aus. Termin und Protokolleintrag (iPhone, Nr. 42) werden lokal gespeichert. Das Symbol zeigt „Offline-Modus, 1 ausstehend“.
2. Später startest du den PC. Er kündigt sich per mDNS an.
3. Sobald du die App auf dem iPhone öffnest, findet sie den PC. Der Vektor des PCs kennt vom iPhone nur Nr. 41, also geht Nr. 42 hinüber.
4. Der PC bestätigt, das iPhone zeigt „Synced“. In der Gegenrichtung läuft es genauso.

Wichtig für deine Erwartung: Liegt das iPhone gesperrt in der Tasche, passiert Schritt 3 erst beim nächsten Öffnen der App oder wenn iOS eine Hintergrundaufgabe zulässt. Mehr verspricht iOS keiner App.

**Rückfallwege, wenn die automatische Erkennung scheitert**

- Letzte bekannte Adresse jedes Partners wird gespeichert und direkt angefragt.
- Manuelle Eingabe von IP und Port in der Geräteverwaltung.
- Der Kopplungs-QR-Code enthält ebenfalls die aktuelle Adresse.

## 6. Geräteautorisierung

Jedes Gerät besitzt ein eigenes Schlüsselpaar. Vertrauen entsteht nur durch eine Kopplung, die du auf einem bereits berechtigten Gerät bestätigst. Dein Vorschlag mit dem QR-Code bleibt der Kern. Ich erweitere ihn so, dass er auch funktioniert, wenn der PC keine Kamera hat.

**Identitäten**

- **Datenbestand:** Beim Einrichten des ersten Geräts entstehen eine zufällige Bestands-ID und ein Erkennungsschlüssel. Daraus wird die anonyme Kennung im mDNS-Eintrag berechnet.
- **Gerät:** Beim ersten Start erzeugt jedes Gerät ein ECDSA-P-256-Schlüsselpaar und ein selbstsigniertes Zertifikat. Der private Schlüssel verlässt das Gerät nie.
- **Liste gekoppelter Geräte:** Eine synchronisierte Tabelle mit Geräte-ID, Name, Plattform, SHA-256-Fingerabdruck des Zertifikats, hinzugefügt von, hinzugefügt am, widerrufen am.

Einschränkung: Der TLS-Stack von Dart braucht den privaten Schlüssel im Arbeitsspeicher. Nicht exportierbare Hardware-Schlüssel (Secure Enclave, StrongBox) sind dafür nicht nutzbar. Der Schlüssel liegt deshalb verschlüsselt im Schlüsselspeicher des Systems.

**Kopplung per QR-Code**

Das Gerät, das den Code zeigt, und das Gerät, das scannt, sind frei wählbar. Typisch zeigt der PC den Code und das Handy scannt.

1. Auf dem berechtigten Gerät: Geräteverwaltung → „Gerät hinzufügen“. Es zeigt einen QR-Code, 5 Minuten gültig, einmal verwendbar.
2. Inhalt des Codes: Adresse und Port, Zertifikats-Fingerabdruck des anzeigenden Geräts, ein 128-Bit-Einmalgeheimnis, Ablaufzeit.
3. Das scannende Gerät verbindet sich per TLS. Es prüft, dass das Zertifikat der Gegenseite zum Fingerabdruck im Code passt. Damit ist ausgeschlossen, dass sich jemand dazwischenschaltet.
4. Das neue Gerät legt sein eigenes Zertifikat vor und beweist per HMAC über beide Fingerabdrücke, dass es das Einmalgeheimnis kennt.
5. Beide Bildschirme zeigen denselben 6-stelligen Prüfcode, abgeleitet aus dem Verbindungsprotokoll. Das berechtigte Gerät fragt: „iPhone (iOS) hinzufügen? Prüfcode 482 913“.
6. Nach deiner Bestätigung wird das neue Gerät in die Liste eingetragen. Es erhält Bestands-ID, Erkennungsschlüssel und die Geräteliste.
7. Erstbefüllung: Das neue Gerät bekommt einen Abzug des aktuellen Stands mit Tombstones und Versionsvektor, nicht die ganze Historie. Danach läuft der normale Sync.
8. Die anderen Geräte erfahren beim nächsten Sync von dem neuen Gerät, weil die Geräteliste mit Vorrang übertragen wird.

**Ohne Kamera:** Beide Geräte finden sich per mDNS. Sie zeigen einen 6-stelligen Vergleichscode wie beim Bluetooth-Koppeln. Du bestätigst auf beiden Geräten, dass die Zahlen gleich sind. Das ist genauso sicher, solange du wirklich vergleichst.

**Regel für neue Geräte:** Ein Gerät tritt nur leer einem Datenbestand bei. Hat es schon eigene Daten, bietet die App vorher einen Export an. Zwei gewachsene Bestände zusammenzuführen wäre möglich, aber fehleranfällig und für eine Person kaum nötig.

**Widerruf**

- „Gerät entfernen“ setzt den Widerrufszeitpunkt. Die Änderung verbreitet sich mit Vorrang, danach lehnt jedes Gerät dieses Zertifikat ab.
- Ein Widerruf ist endgültig. Gleichzeitige gegenseitige Widerrufe führen dazu, dass beide Geräte ausgeschlossen sind. Zurück geht es nur über eine neue Kopplung.
- Nach einem Widerruf wird der Erkennungsschlüssel erneuert. Das widerrufene Gerät erkennt deine anderen Geräte dann nicht einmal mehr im Netz.
- Meldet sich ein widerrufenes Gerät, bekommt es die Antwort „widerrufen“ und bietet an, seine lokalen Daten zu löschen.
- **Grenze:** Ein gestohlenes Gerät kooperiert nicht. Seine bereits vorhandenen Daten schützen dann nur Gerätesperre, DB-Verschlüsselung und App-PIN. Fernlöschung ohne Server ist nicht möglich.

Feinere Berechtigungen, etwa ein Gerät nur lesend, sind technisch machbar. Für eine Person mit eigenen Geräten empfehle ich sie nicht für die erste Version.

## 7. Konfliktbehandlung

Keine Änderung geht unbemerkt verloren. Bei gleichzeitigen Änderungen an derselben Feldgruppe gewinnt automatisch der spätere HLC-Zeitstempel, damit alle Geräte gleich aussehen. Der unterlegene Wert wird aber als Konflikt aufbewahrt, wo er wichtig ist, und du entscheidest.

**Mechanik**

1. **Feldgruppen:** Felder, die nur zusammen Sinn ergeben, bilden eine Gruppe. Beispiel Termin: Start, Ende, ganztägig, Zeitzone und Wiederholungsregel. So entsteht nie ein Termin mit dem Start vom PC und dem Ende vom Handy.
2. **Vorgänger merken:** Jede Änderung speichert den HLC des Werts, von dem sie ausging.
3. **Vergleichen beim Empfang:** Ist der lokale HLC gleich diesem Vorgänger, wurde nacheinander geändert. Die neue Version gilt, kein Konflikt.
4. **Gleichzeitig geändert:** Weicht der Vorgänger ab, gewinnt der höhere HLC, bei Gleichstand die höhere Geräte-ID. Sind beide Werte gleich, ist nichts zu tun.
5. **Konflikt notieren:** Bei wichtigen Feldgruppen entsteht ein Konflikteintrag mit dem unterlegenen Wert. Seine ID wird aus Zeile, Feldgruppe und beiden Zeitstempeln berechnet. Deshalb legen alle Geräte denselben Eintrag an statt mehrerer Kopien.
6. **Auflösen:** Deine Entscheidung ist eine ganz normale neue Änderung. Sie löst den Konflikt auf allen Geräten.

**Dein Beispiel:** Du änderst auf dem PC die Uhrzeit und auf dem Handy den Titel. Das sind verschiedene Feldgruppen, beides bleibt erhalten, kein Konflikt. Änderst du auf beiden Geräten die Uhrzeit, gilt die spätere. Der Termin bekommt ein Konfliktsymbol mit „Andere Version: 14:00“ und dem Knopf „Stattdessen übernehmen“.

**Regeln je Datentyp**

| Daten | Automatisch | Manuelle Entscheidung |
| --- | --- | --- |
| Termin: Zeit und Wiederholung | Spätere Version gilt | Ja, Konflikt wird angezeigt |
| Termin: Titel, Ort, Beschreibung | Je Feld, spätere Version gilt | Nur bei Beschreibung, als Konfliktkopie |
| Notiztext, Zubereitung, lange Texte | Spätere Version gilt | Ja, der andere Text bleibt als Konfliktkopie sichtbar. Keine automatische Textverschmelzung. |
| Tags, Rezeptzutaten, Anheftungen | Zusammenführen, weil jede Zuordnung eine eigene Zeile ist | Nein |
| Erledigt-Haken (Todo, Habit, Einkaufsliste) | Spätere Version gilt | Nein |
| Wasser, Kalorien, Lernantworten, Prüfungen | Einzelne Einträge, werden nur addiert | Nein, Konflikte sind unmöglich |
| Finanzbuchung: Betrag, Datum, Tag | Spätere Version gilt | Ja, weil es um Geld geht |
| Daily Report | Feste ID aus dem Datum, beide Geräte schreiben denselben Bericht. Haken: spätere Version | Texte als Konfliktkopie |
| Wiederkehrende Buchungen, Habit-Erledigungen, Tagesmesswerte | Feste ID aus Regel und Datum, daher keine Duplikate | Nein |
| Zutaten und Tags mit gleichem Namen | Feste ID aus normalisiertem Namen und Einheit, beide Geräte meinen dieselbe Zutat | Nur wenn die Nährwerte voneinander abweichen |
| Projektfortschritt in Prozent | Wird berechnet, nie gespeichert | Nein |
| Gerätebezogene Einstellungen (Benachrichtigung, Wecker-Gerät) | Pro Gerät eigener Eintrag, keine Überschneidung | Nein |
| Geräteliste | Widerruf gewinnt immer | Nein |

**Löschen gegen Bearbeiten**

- Löschen setzt einen Tombstone. Der Datensatz wandert in einen Papierkorb und lässt sich 30 Tage wiederherstellen.
- Wurde der Datensatz gleichzeitig woanders bearbeitet, gewinnt das Löschen. Du bekommst den Hinweis „Gelöscht, aber auf dem iPhone geändert – wiederherstellen?“.
- Wird ein Projekt gelöscht, während woanders ein Unterpunkt dazukommt, landet der neue Unterpunkt mit dem Projekt im Papierkorb.

**Fachlicher Sonderfall Einkauf:** Drückst du auf zwei Geräten für dieselben Artikel „Gekauft“, entstehen zwei Ausgaben. Jeder Artikel merkt sich die Kauf-ID. Hat ein Artikel zwei verschiedene Kauf-IDs, meldet die App „Möglicherweise doppelt gebucht“ und zeigt beide Ausgaben zur Auswahl.

**Konfliktübersicht:** Ein Eintrag „Konflikte“ unter Synchronisation listet alle offenen Fälle mit beiden Versionen nebeneinander. Die Anzahl erscheint als Zahl am Sync-Symbol.

**Warum kein CRDT-Framework:** Das Verfahren oben entspricht bereits einfachen CRDT-Bausteinen: ein Register je Feldgruppe mit „letzter gewinnt“, Mengen als einzelne Zeilen, Zähler als einzelne Einträge. Ein volles CRDT lohnt sich nur für gleichzeitiges Bearbeiten desselben langen Textes. Das kommt bei einer Person auf mehreren Geräten selten vor, und für Dart gibt es keine ausgereifte Implementierung. Sollten Notizen später zum Schwerpunkt werden, lässt sich für den Notiztext ein Text-CRDT nachrüsten, ohne den Rest zu ändern.

## 8. Google-Kalender-Integration

Google wird behandelt wie ein weiteres, gelegentlich erreichbares Gerät. Änderungen von Google laufen durch dieselbe Konfliktlogik wie Änderungen vom PC. Ist das Modul aus, gibt es keine Netzwerkzugriffe zu Google und keine gespeicherten Tokens.

**Anmeldung je Plattform**

| Plattform | Verfahren | Client-Secret |
| --- | --- | --- |
| Android | google\_sign\_in (Android-Autorisierungs-API), Zugriffstoken auf Anfrage | Keins |
| iOS | google\_sign\_in (Google-Sign-In-SDK), iOS-Client-Typ | Keins |
| Windows | System-Browser, Weiterleitung an 127.0.0.1 mit zufälligem Port, PKCE, Client-Typ „Desktop-App“ | Technisch nötig, aber kein Geheimnis |

**Ehrliche Einschränkung bei Windows:** Deine Vorgabe „keine Client-Secrets einbetten“ ist dort wörtlich nicht erfüllbar. Google vergibt für Desktop-Clients immer ein Secret. Der Token-Endpunkt verlangt es nach Entwicklerberichten auch mit PKCE ([Google Developer Forum](https://discuss.google.dev/t/google-auth-platform-question-about-desktop-app-client-and-secret/178938)). Google selbst stuft Desktop-Apps als öffentliche Clients ein, die nichts geheim halten können, und verlangt PKCE ([Google-Doku](https://developers.google.com/youtube/data/guides/auth/installed-apps?authuser=7)). Die Sicherheit kommt also aus PKCE und der lokalen Weiterleitung, nicht aus dem Secret. Es einzubetten ist damit vertretbar, es schützt nur nichts.

**Google-Projekt richtig einstellen**

- Bereich (Scope) `calendar.events` plus Leserecht auf die Kalenderliste. Kein Vollzugriff auf alle Kalendereinstellungen.
- Im Status „Testing“ laufen Berechtigungen nach 7 Tagen ab, auch die Refresh-Tokens ([Google-Hilfe](https://support.google.com/cloud/answer/15549945?authuser=7)). Du müsstest dich wöchentlich neu anmelden.
- Für den Eigengebrauch: Status auf „In production“ stellen. Ohne Verifizierung erscheint ein Hinweis „App nicht überprüft“, und es gilt eine Obergrenze von 100 Nutzern. Für dich reicht das.
- Soll die App später an andere gehen, ist eine Google-Verifizierung für den Kalender-Bereich nötig. Das kostet Zeit, aber kein Geld.

**Zuordnung lokal ↔ Google**

- Tabelle `google_link`: lokale Termin-ID, Google-Kalender-ID, Google-Event-ID, ETag, Google-Änderungszeit. Sie wird per LAN mitsynchronisiert.
- **Lokal nach Google:** Die Google-Event-ID wird aus der lokalen UUID berechnet (base32hex). Google erlaubt selbst gewählte IDs mit den Zeichen a–v und 0–9 und 5 bis 1024 Zeichen Länge ([API-Referenz](https://developers.google.com/calendar/v3/reference/events/insert)). Legen zwei Geräte denselben Termin an, lehnt Google den zweiten als Duplikat ab, und die App wertet das als Erfolg.
- **Google nach lokal:** Die lokale ID wird aus Kalender-ID und Google-Event-ID berechnet. Importieren zwei Geräte denselben Termin, entsteht derselbe lokale Datensatz.
- Dadurch kann jedes Gerät mit Google synchronisieren, ohne Duplikate. Jedes Gerät meldet sich selbst bei Google an. Tokens werden nie zwischen Geräten übertragen.

**Abgleich**

1. Erster Abruf je Kalender: alle Termine inklusive gelöschter, Serien als Haupttermin plus Ausnahmen. Am Ende liefert Google ein Sync-Token.
2. Folgeabrufe nur mit Sync-Token. Antwortet Google mit 410 (Token ungültig), wird das Token verworfen und neu voll abgerufen.
3. Abgesagte Termine (Status „cancelled“) werden lokal zu Tombstones.
4. Lokale Änderungen seit dem letzten Abgleich werden aus dem Änderungsprotokoll gelesen. Eine eigene Warteschlange ist nicht nötig. Offline wartet die Änderung einfach dort.
5. Hochladen mit `If-Match` und ETag. Antwortet Google mit 412 (inzwischen geändert), wird die Google-Fassung geholt und wie eine gleichzeitige Änderung behandelt. Der Konflikt erscheint dann als „Google-Version“.
6. Auslöser: App-Start, alle 15 Minuten bei geöffneter App, Knopf „Mit Google abgleichen“.

Live-Benachrichtigungen von Google (Push-Kanäle) brauchen einen öffentlich erreichbaren HTTPS-Server. Den gibt es hier bewusst nicht, deshalb wird abgefragt.

**Fachliche Details**

- **Wiederholungen:** Das lokale Modell spiegelt Googles Modell aus Haupttermin, Regel und Ausnahme-Instanzen. Regeln, die die eigene Oberfläche nicht bearbeiten kann, bleiben erhalten und werden als „komplexe Wiederholung“ nur angezeigt.
- **Ganztägig:** Google speichert das Enddatum ganztägiger Termine exklusiv, ein eintägiger Termin endet also am Folgetag. Die Umrechnung gehört in einen eigenen, getesteten Konverter.
- **Zeitzonen:** Immer IANA-Zone mitschicken. Zeiten nie als lokale Uhrzeit ohne Zone speichern.
- **App-eigene Felder** (Tags, Projekt, Trainingsplan) bleiben lokal. Optional können sie in Googles privaten Zusatzfeldern gespeichert werden. Das ist standardmäßig aus, weil diese Daten sonst Google erreichen.
- **Mehrere Google-Kalender:** Jeder wird zu einer lokalen Kalenderquelle mit Farbe. Nur-Lese-Kalender wie Feiertage werden nur importiert.
- **Was zu Google geht:** Nur Termine in einem mit Google verknüpften lokalen Kalender. Optional per Regel, z. B. „Tag Arbeit → Google-Kalender Arbeit“.

**Abschalten:** Token bei Google widerrufen und lokal löschen. Danach fragt die App, ob importierte Termine als lokale Kopien bleiben oder entfernt werden.

## 9. Sicherheitsstrategie

Die Daten schützt ein zufälliger Schlüssel im Schlüsselspeicher des Systems, nicht die PIN. Die PIN ist eine App-Sperre gegen Zugriff auf ein entsperrtes Gerät. Diese Trennung macht ein PIN-Reset ohne Datenverlust überhaupt erst möglich.

**Warum die PIN nicht der Datenbankschlüssel ist**

Eine 6-stellige PIN hat 1 Million Möglichkeiten. Wäre der DB-Schlüssel daraus abgeleitet, könnte jemand mit einer Kopie der Datei alle PINs offline durchprobieren, auch mit Argon2id in überschaubarer Zeit. Ein zufälliger 256-Bit-Schlüssel im Hardware-gestützten Keystore ist dagegen praktisch nicht zu erraten. Außerdem wären bei vergessener PIN alle Daten unwiederbringlich verloren.

**App-Sperre (dein Konzept, angepasst)**

- **Einrichtung:** PIN mit 6 bis 12 Ziffern. Die E-Mail-Adresse wird nicht mehr benötigt. Wenn du sie willst, bleibt sie ein reines Profilfeld.
- **Eine PIN für alle Geräte:** Der PIN-Hash (Argon2id mit Salt) wird mitsynchronisiert. Eine Änderung gilt überall.
- **Sperre nach 10 Minuten:** nach 10 Minuten ohne Eingabe oder nach 10 Minuten im Hintergrund, einstellbar. Beim Sperren werden Inhalte ausgeblendet, auch in der App-Übersicht von iOS und Android.
- **Fehlversuche:** Ab dem 5. Fehlversuch wächst die Wartezeit, beginnend bei 30 Sekunden und jeweils verdoppelt.
- **Biometrie:** Fingerabdruck, Face ID oder Windows Hello zum schnellen Entsperren, PIN als Rückfall.

**PIN vergessen – drei Wege ohne Server**

1. **Über ein anderes Gerät:** Auf dem entsperrten PC wählst du „PIN auf iPhone zurücksetzen“. Der PC sendet eine signierte, 10 Minuten gültige Freigabe per LAN. Das iPhone lässt dich eine neue PIN setzen.
2. **Wiederherstellungscode:** Bei der Einrichtung zeigt die App einmalig einen 24-stelligen Code zum Ausdrucken oder Speichern im Passwortmanager.
3. **Letzter Ausweg:** App neu installieren und aus einem Backup mit Backup-Passwort wiederherstellen oder neu mit einem gekoppelten Gerät verbinden.

Eine Reset-E-Mail würde einen Mailserver brauchen. Dafür müsste die App Zugangsdaten enthalten, die jeder auslesen kann. Das wäre unsicherer als die drei Wege oben.

**Schlüsselübersicht**

| Schlüssel | Ort | Zweck | Synchronisiert |
| --- | --- | --- | --- |
| DB-Schlüssel (256 Bit) | Schlüsselspeicher | SQLite-Verschlüsselung | Nein, je Gerät eigener |
| Datei-Schlüssel | Schlüsselspeicher | Bilder und Töne | Nein |
| Geräteschlüssel (ECDSA P-256) | Schlüsselspeicher | TLS-Identität | Nein, verlässt das Gerät nie |
| Erkennungsschlüssel | Datenbank | Anonyme mDNS-Kennung | Ja, wird nach Widerruf erneuert |
| PIN-Hash, Wiederherstellungscode-Hash | Datenbank | App-Sperre | Ja |
| Backup-Schlüssel | Aus dem Backup-Passwort abgeleitet (Argon2id) | Export-Datei | Nein |
| Google-Tokens | Schlüsselspeicher | Google Calendar API | Nein |

**Bedrohungen und Gegenmaßnahmen**

| Bedrohung | Schutz | Restrisiko |
| --- | --- | --- |
| Gesperrtes Handy gestohlen | Geräteverschlüsselung, DB-Verschlüsselung, Keystore | Gering |
| Entsperrtes Gerät in fremder Hand | App-PIN, automatische Sperre | Gering |
| Angreifer im selben WLAN | mTLS mit festen Zertifikaten, anonyme mDNS-Kennung, Kopplungsport nur offen, während ein QR-Code angezeigt wird, Begrenzung der Verbindungsversuche | Gering |
| Schadsoftware unter deinem Windows-Konto | Verschlüsselung hilft kaum, weil sie mit deinen Rechten läuft | **Hoch, nicht lösbar durch die App.** Windows aktuell halten. |
| Backup-Datei gestohlen | Backup-Passwort mit Argon2id, authentifizierte Verschlüsselung | Abhängig von der Passwortstärke |
| Widerrufenes oder verlorenes Gerät | Ablehnung beim Sync, neuer Erkennungsschlüssel | Bereits vorhandene Daten bleiben dort |
| Manipulierte Abhängigkeit | Wenige, gepinnte Pakete, Lockfile, Prüfung bei Updates | Mittel, wie bei jeder App |

**Datenschutz**

- Keine Telemetrie, keine Analyse-SDKs, kein Absturz-Upload. Absturzberichte landen lokal und lassen sich bei Bedarf manuell exportieren.
- Netzwerkverkehr nur ins lokale Netz, zu Google nur bei aktivierter Integration.
- Protokolldateien enthalten nie Inhalte, Schlüssel oder Tokens. Das wird in Phase 11 automatisiert geprüft.
- Berechtigungsdialoge erklären vorher in eigenen Worten, wofür das lokale Netzwerk gebraucht wird.

## 10. Projektstruktur

Ein Monorepo mit Dart Pub Workspaces: eine Flutter-App als dünne Hülle und daneben eigenständige Pakete. Core und Sync sind reines Dart ohne Flutter. Dadurch läuft die Sync-Logik in schnellen Tests und in einem Kommandozeilen-Simulator ohne echte Geräte.

```text
lifeos/
├─ pubspec.yaml              Workspace-Wurzel, sqlite3-Quelle auf sqlite3mc gestellt
├─ analysis_options.yaml     Gemeinsame Lint-Regeln, Import-Regeln
├─ docs/
│  ├─ adr/                   Architekturentscheidungen (ADR-0001 ...)
│  ├─ sync-protocol.md       Versionierte Protokollbeschreibung
│  └─ threat-model.md
├─ apps/
│  └─ lifeos_app/            Flutter-App: Start, Shell, Verdrahtung
│     ├─ lib/
│     │  ├─ main.dart
│     │  ├─ bootstrap/       Sperre, DB öffnen, Module registrieren
│     │  ├─ shell/           Seitenleiste (Windows) / Tab-Leiste (Handy)
│     │  └─ di/              Welche Implementierung erfüllt welchen Port
│     ├─ android/            Kotlin: Wecker, Vollbild-Weckansicht, Hintergrund
│     ├─ ios/                Swift: AlarmKit-Brücke, BGTask, Info.plist-Einträge
│     └─ windows/            C++: Infobereich, Autostart, MSIX mit Firewall-Regel
├─ packages/
│  ├─ core/                  IDs, HLC, Ergebnis-Typen, Geld, Zeit, Tags (reines Dart)
│  ├─ contracts/             Ports zwischen Modulen, Fachereignisse, Kachel-API
│  ├─ persistence/           Drift-DB, Systemtabellen, Migrationen, Repository-Basis
│  ├─ sync/                  Zusammenführen, Vektoren, Protokoll, Transport (reines Dart)
│  ├─ devices/               Identität, Zertifikate, Kopplung, Widerruf
│  ├─ security/              App-Sperre, Schlüssel, Wiederherstellung, Backup-Krypto
│  ├─ platform/              Adapter: Benachrichtigung, Wecker, Hintergrund, Erkennung
│  ├─ design_system/         Theme, Typografie, gemeinsame Widgets, adaptive Layouts
│  ├─ integrations/
│  │  └─ google_calendar/
│  └─ features/
│     ├─ dashboard/   ├─ calendar/   ├─ tasks/      ├─ finance/
│     ├─ notes/       ├─ daily_report/ ├─ habits/   ├─ projects/
│     ├─ kitchen/     ├─ learning/   ├─ sport/      └─ alarm/
└─ tools/
   ├─ sync_simulator/        N virtuelle Geräte, Zufallsoperationen, Konvergenzprüfung
   └─ schema_dumps/          Drift-Schemastände für Migrationstests
```

**Aufbau jedes Fachmoduls** (Beispiel Finanzen)

```text
features/finance/
├─ lib/
│  ├─ finance.dart       Öffentliche API: Modul-Manifest, Port-Implementierungen
│  └─ src/
│     ├─ domain/         Entitäten, Regeln (reines Dart)
│     ├─ application/    Anwendungsfälle wie RecordExpense
│     ├─ data/           Drift-Tabellen, DAOs, Feldgruppen und Merge-Regeln
│     └─ presentation/   Screens, Widgets, Provider, Dashboard-Kacheln
└─ test/
```

**Modul-Manifest:** Jedes Fachmodul meldet beim Start an, was es mitbringt: Tabellen mit Feldgruppen und Merge-Regeln für die Sync-Engine, Routen, Dashboard-Kacheln, Port-Implementierungen, Erinnerungen für den Erinnerungsplaner und Kennzahlen für Statistiken. Die Sync-Engine kennt keine Fachmodule, nur diese Beschreibungen.

**Abhängigkeitsregeln** (per Lint-Regel automatisch geprüft)

| Paket | Darf nutzen | Darf nie nutzen |
| --- | --- | --- |
| features/\* | core, contracts, persistence, platform, design\_system | andere features |
| sync | core, persistence | features, Flutter |
| core | nichts außer der Dart-Standardbibliothek | alles andere |
| integrations/\* | core, contracts, persistence | features |
| apps/lifeos\_app | alles | – |

**Dokumentation:** Jede größere Entscheidung bekommt eine ADR mit Kontext, Entscheidung und Folgen. Jedes Paket hat eine README mit seiner öffentlichen Schnittstelle. Das Sync-Protokoll ist versioniert beschrieben, damit ältere und neuere App-Versionen klar wissen, ob sie miteinander reden können.

## 11. Plattformabhängige Einschränkungen

iOS setzt die engsten Grenzen bei Hintergrund-Sync und Wecker, Windows bei Netzwerk-Freigaben und Schutz vor Schadsoftware. Die Architektur ist so gebaut, dass jede Funktion bei geöffneter App auf allen drei Plattformen korrekt arbeitet. Alles im Hintergrund ist Bonus, nicht Voraussetzung.

**Netzwerk und Hintergrund**

| Thema | Windows | Android | iOS |
| --- | --- | --- | --- |
| Zugriff aufs lokale Netz | Firewall-Abfrage beim ersten Start. Im Netzwerkprofil „Öffentlich“ sind eingehende Verbindungen gesperrt. Das MSIX-Paket bringt eine Firewall-Regel mit. | Ab Android 17 braucht eine App mit Ziel-SDK 37 die Laufzeitberechtigung `ACCESS_LOCAL_NETWORK` ([Android-Doku](https://developer.android.com/privacy-and-security/local-network-permission)). Von Anfang an einplanen. | Abfrage „Lokales Netzwerk“ beim ersten Zugriff. Info.plist braucht eine Begründung und den Diensttyp `_lifeos._tcp`. Bonjour mit deklariertem Typ braucht keine Multicast-Sonderberechtigung ([Apple FAQ](https://developer.apple.com/forums/thread/663875)). |
| Geräteerkennung (mDNS) | DNS-SD-API von Windows | Android NSD | Bonjour |
| Erreichbar als Sync-Partner | Solange angemeldet und wach, App läuft im Infobereich mit Autostart | Nur bei geöffneter App. Dauerhaft nur mit Vordergrunddienst und Dauerbenachrichtigung, für Daten-Sync zeitlich begrenzt. Nicht empfohlen. | Nur bei geöffneter App. iOS pausiert Apps im Hintergrund nach wenigen Sekunden. |
| Sync im Hintergrund | Dauerhaft | WorkManager, frühestens alle 15 Minuten, bei Energiesparen seltener | Hintergrundaufgaben nach Ermessen von iOS. Kann stunden- oder tagelang ausbleiben. |
| Netze, in denen nichts geht | Gäste-WLANs mit Client-Isolation, viele Firmennetze, aktive VPNs blockieren mDNS oder direkte Verbindungen. Dann helfen nur Handy-Hotspot oder manuelle IP. | gleich | gleich |

**Benachrichtigungen und Wecker**

| Thema | Windows | Android | iOS |
| --- | --- | --- | --- |
| Termin-Erinnerungen | Zeitgesteuerte Toasts. Nur wenn der PC an ist. Keine Wiederholungen, die App plant jede einzeln. | Laufzeitberechtigung für Benachrichtigungen. Exakte Zeiten über `USE_EXACT_ALARM`, das Kalender- und Wecker-Apps zusteht ([Android-Doku](https://developer.android.com/about/versions/14/changes/schedule-exact-alarms)). Nach Neustart neu planen. | Höchstens 64 geplante Benachrichtigungen je App. Der Erinnerungsplaner plant immer die nächsten 64 und füllt beim Öffnen nach. |
| „Auf welchem Gerät benachrichtigen“ | Machbar: Jedes Gerät plant nur Erinnerungen, bei denen es als Ziel eingetragen ist. Ein ausgeschaltetes Gerät meldet sich nicht. | gleich | gleich |
| Wecker klingelt bei gesperrtem Gerät | Nur wenn die App läuft und der PC nicht schläft | Ja, über AlarmManager und Vollbild-Benachrichtigung. Diese ist ab Android 14 standardmäßig nur Anruf- und Wecker-Apps erlaubt ([AOSP](https://source.android.com/docs/core/permissions/fsi-limits?authuser=580)). | Ja, über AlarmKit ab iOS 26, auch im Lautlos-Modus |
| Eigener Weckton | Ja | Ja | Eingeschränkt. AlarmKit spielte eigene Töne lange nur aus dem App-Paket ab, nicht aus nachträglich hinzugefügten Dateien ([Apple-Forum](https://developer.apple.com/forums/thread/798140)). Hochgeladene Töne vor dem Bau testen, sonst mitgelieferte Töne anbieten. |
| Lichtwecken | Ja, Vollbildfenster mit Farbverlauf | Ja, Weckansicht 5 Minuten vorher über dem Sperrbildschirm, Helligkeit steigt | **Nein im Hintergrund.** Nur „Nachttisch-Modus“: App bleibt geöffnet, Bildschirm an, am besten am Ladekabel. |

**Sicherheit, Dateien, Verteilung**

| Thema | Windows | Android | iOS |
| --- | --- | --- | --- |
| Schlüsselspeicher | An das Windows-Konto gebunden, ohne Hardware-Trennung | Android Keystore (TEE, teils StrongBox) | Keychain mit Secure Enclave |
| Kamera für QR | Oft keine, deshalb Kopplung in Gegenrichtung | Ja | Ja |
| Export und Backup-Dateien | Freie Ordnerwahl | Teilen-Dialog oder Dateiauswahl des Systems | Teilen-Dialog oder Dateien-App |
| App wird beendet | Fenster schließen kann in den Infobereich minimieren | Prozess kann jederzeit enden | App kann im Hintergrund jederzeit enden |
| Installation | MSIX oder Installer. Ohne Code-Signatur warnt SmartScreen. | APK direkt oder Play Store. Play verlangt Begründungen für exakte Alarme und Vollbild-Benachrichtigungen. | Apple Developer Program (99 US-Dollar pro Jahr) für dauerhafte Installation über TestFlight oder App Store. Ohne bezahltes Konto laufen selbst installierte Apps nach 7 Tagen ab. Build nur auf einem Mac. |

Aus der letzten Zeile folgt eine Konsequenz für Phase 2. Kläre früh, ob du einen Mac hast oder einen Mac-Build-Dienst nutzen willst. Ohne das lässt sich iOS nicht „von Anfang an“ mitentwickeln.

## 12. Entwicklungs- und Testplan

Realistisch sind 12 bis 15 Monate Vollzeit für eine Person. Eine erste nutzbare Version mit Sync, Kalender, Aufgaben, Notizen und Finanzen steht nach etwa 7 Monaten. Die Zahlen sind grobe Schätzungen. Die größte Unsicherheit liegt in Kalender-UI, Wecker und Gerätetests, die sich kaum beschleunigen lassen.

**Änderungen an deiner Phasenfolge**

- **Verschlüsselung von Phase 10 nach Phase 3.** Eine unverschlüsselte DB später umzustellen ist doppelte Arbeit. Die Sicherheitsphase (neu Phase 11) prüft und härtet nur noch.
- **Sync-Metadaten (HLC, Änderungsprotokoll) gleich in Phase 3.** Nachträglich in alle Tabellen einzubauen wäre der teuerste Umbau im Projekt.
- **Ein echtes Modul vor dem Sync.** Aufgaben und Notizen in Phase 4, damit der Sync mit echten Daten statt Testtabellen gebaut wird.
- **Kalender vor Google.** Die Google-Integration braucht das Kalendermodul. Sie wandert hinter die erste Modulwelle.
- **App-Sperre in Phase 4.** Sie fehlt in deiner Liste, betrifft aber jeden Bildschirm.
- **Module in Wellen statt einer großen Phase 9.** Jede Welle endet mit einer installierbaren Version.

**Angepasste Phasen**

| Phase | Inhalt | Abnahmekriterium | Aufwand (Wochen) |
| --- | --- | --- | --- |
| 1 Architektur | Dieses Dokument, ADRs, offene Entscheidungen klären | Entscheidungen unten beantwortet | 1 |
| 2 Grundgerüst und Machbarkeitstests | Monorepo, Build für alle drei Plattformen. Kurztests für die riskanten Annahmen: verschlüsselte DB öffnet sich, mDNS findet Geräte, mTLS zwischen iPhone und PC, Toast auf Windows | Alle Kurztests auf echten Geräten grün, Ergebnisse als ADR | 2–3 |
| 3 Datenbank und Kern | Drift, Verschlüsselung, Schlüsselspeicher, HLC, Änderungsprotokoll, Migrationstests | Jede Schreiboperation erzeugt einen Protokolleintrag (automatisch geprüft). DB-Datei ohne Schlüssel unlesbar. | 3 |
| 4 UI-Grundgerüst | Design-System, adaptive Shell, App-Sperre mit PIN und Biometrie, Module Aufgaben und Notizen | Läuft auf allen drei Plattformen, Sperre nach 10 Minuten greift | 4 |
| 5 Erkennung und Kopplung | mDNS, Zertifikate, QR-Kopplung in beide Richtungen, Zahlenvergleich, Widerruf | Kopplung in allen 6 Geräterichtungen erfolgreich, widerrufenes Gerät wird abgelehnt | 3 |
| 6 LAN-Sync | Protokoll, Stapelübertragung, Weiterreichen, Dateien, Sync-Symbol, Auslöser | Simulator: 5 Geräte, 10.000 Zufallsoperationen, alle gleich. Abbruch an jeder Stelle verliert nichts. | 4 |
| 7 Konflikte und Integrität | Feldgruppen, Konflikteinträge, deterministische IDs, Papierkorb, Konfliktübersicht | Jede Regel aus Abschnitt 7 hat einen Test | 3 |
| 8 Modulwelle A | Kalender mit Erinnerungsplaner, Finanzen | Erinnerung kommt nur auf den gewählten Geräten | 9 |
| 9 Google-Kalender | OAuth je Plattform, Abgleich, Zuordnung, Wiederholungen | Termin offline anlegen, später bei Google sichtbar, ohne Duplikat von zwei Geräten | 3 |
| 10 Modulwellen B bis D | Küche und Einkauf, Daily Report, Habits, Projekte, Dashboard-Baukasten, Lernen, Sport, Wecker | Je Welle eine installierbare Version | 23 |
| 11 Sicherheit und Backups | Export und Import, Sicherheitstests, Abhängigkeitsprüfung | Wiederherstellung auf leerem Gerät klappt, Protokolle enthalten keine Inhalte | 2 |
| 12 Plattformtests und Verteilung | Testmatrix, Leistung, MSIX, Play oder APK, TestFlight | Testmatrix vollständig, Apple-Prüfung bestanden | 4–5 |

**Teststrategie**

- **Fachlogik und Merge-Regeln:** Unit-Tests in reinem Dart, laufen in Sekunden.
- **Sync-Simulator:** Virtuelle Geräte führen Zufallsoperationen aus und synchronisieren in zufälliger Reihenfolge, mit Netztrennungen und Abbrüchen mitten im Stapel. Geprüft wird: alle Geräte haben am Ende denselben Zustand, keine Änderung fehlt (sie ist sichtbar, im Konflikt oder im Papierkorb), doppeltes Einspielen ändert nichts. Jeder gefundene Fehler wird mit seinem Zufallswert als fester Test gespeichert.
- **Migrationen:** Automatisch erzeugte Tests für jeden Schemasprung, mit Beispieldaten.
- **UI:** Widget- und Screenshot-Tests für Handy- und Desktopgrößen.
- **Zeit:** Sommerzeitwechsel, Zeitzonenwechsel auf Reisen, ganztägige Termine, falsch gehende Uhren.
- **Gerätetests (manuell, mit Checkliste):** Heim-WLAN, Mesh-WLAN, Gäste-WLAN, Handy-Hotspot, aktives VPN, Windows-Netzprofil privat und öffentlich.
- **Plattformmatrix:** Windows 10 und 11, Android 10 bis 17, iOS 26 und neuer.

**Automatisierung:** Jeder Commit baut Windows und Android, Tests für reines Dart laufen immer. iOS-Builds laufen auf einem Mac oder Mac-Build-Dienst mindestens einmal täglich, damit iOS nie hinterherhängt.

## Offene Entscheidungen für dich

Diese Punkte brauche ich vor Phase 2. Bei jedem steht meine Empfehlung.

- [ ] **Mac für iOS-Builds:** eigener Mac oder gemieteter Mac-Build-Dienst? Ohne eins von beiden kein iOS. *Empfehlung: Build-Dienst, falls kein Mac vorhanden.*
- [ ] **E-Mail beim Einrichten:** streichen oder als reines Profilfeld behalten? *Empfehlung: streichen.*
- [ ] **PIN-Reset:** Reichen die drei Wege aus Abschnitt 9 (anderes Gerät, Wiederherstellungscode, Backup)? *Empfehlung: ja.*
- [ ] **Mindestversionen:** Windows 10 und 11, Android 10, iOS 26? iOS 26 vermeidet einen zweiten Wecker-Weg ohne AlarmKit. *Empfehlung: ja.*
- [ ] **Verteilung:** nur für dich (APK, MSIX, TestFlight) oder öffentlich in den Stores? Das bestimmt Google-Verifizierung und Play-Richtlinien. *Empfehlung: zuerst nur privat.*
- [ ] **Wecker auf iOS:** AlarmKit mit mitgelieferten Tönen plus Nachttisch-Modus für Lichtwecken akzeptabel? *Empfehlung: ja, eigene Töne in Phase 2 testen.*
- [ ] **Kalender-UI:** freies Paket oder Syncfusion mit Community-Lizenz? *Empfehlung: Entscheidung nach Prototyp in Phase 4.*
- [ ] **Essensplaner mit Wochenplanung:** in Version 1 oder später? Er steht nur im Auftrag, nicht im Konzept. *Empfehlung: später.*
- [ ] **Ziele und Statistiken** ohne eigene Module, wie in Abschnitt 2 beschrieben? *Empfehlung: ja.*
