# ADR-0004: Sync-Testversion mit gemeinsamem Bestandsschlüssel

- Status: angenommen für Version 0.2, wird mit Gerätezertifikaten ersetzt
- Datum: 2026-11-26

## Kontext

Die Architektur (Abschnitte 5 und 6) sieht HTTPS mit gegenseitiger Zertifikatsprüfung, einen Schlüssel je Gerät und die Kopplung per QR-Code vor. Für eine erste Testversion auf zwei Geräten soll der Sync schnell und robust funktionieren. Zertifikate erzeugen und prüfen ist in Dart aufwendig und fehleranfällig. QR-Scannen braucht ein Kamera-Plugin.

## Entscheidung

- **Transport:** HTTP im lokalen Netz. Jede Nachricht ist mit ChaCha20-Poly1305 verschlüsselt und authentifiziert (Paket `cryptography`). Die zusätzlichen Daten (AAD) binden sie an Richtung, Pfad und Absender-ID.
- **Schlüssel:** Ein zufälliger 256-Bit-Bestandsschlüssel je Datenbestand, gespeichert in der verschlüsselten Datenbank.
- **Kopplung:** Das Gerät mit den Daten zeigt Adresse und einen 16-stelligen Einmalcode (80 Bit Zufall, 10 Minuten gültig, höchstens 5 Fehlversuche). Aus dem Code wird per HKDF-SHA256 ein Kopplungsschlüssel. Damit wird der Bestandsschlüssel an das neue Gerät übertragen.
- **Erkennung:** Noch kein mDNS. Die Adresse wird bei der Kopplung eingetippt und danach bei jedem Kontakt automatisch aktualisiert.
- **Zusammenführen:** Wie in Abschnitt 7: Feldgruppen, HLC, Konflikte werden gespeichert, Löschen gewinnt.

## Folgen

- Vertraulichkeit und Integrität im WLAN sind gegeben. Ein Wiederholen alter Nachrichten richtet keinen Schaden an, weil das Anwenden idempotent ist.
- **Grenzen:** Keine Forward Secrecy. Ein gekoppeltes Gerät könnte sich als anderes gekoppeltes Gerät ausgeben. „Entfernen“ wirkt nur lokal: Das entfernte Gerät kennt den Schlüssel weiter. Das ist für zwei eigene Testgeräte vertretbar.
- **Nächster Schritt:** Gerätezertifikate mit mTLS, Widerruf mit Schlüsselwechsel, mDNS-Erkennung, QR-Code.
