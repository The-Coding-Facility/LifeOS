# LifeOS

Lokaler Lebensplaner für Windows, Android und iOS. Alle Daten bleiben auf deinen Geräten. Synchronisiert wird direkt über dein WLAN, ohne Server und ohne Cloud.

Die vollständige Architektur steht in [docs/architektur.md](docs/architektur.md).

## Stand: Version 0.2.0 – Testversion für zwei Geräte

**Drin**

- Verschlüsselte Datenbank, Änderungsprotokoll mit Hybrid Logical Clock
- App-Sperre: PIN, Sperre nach 10 Minuten, Wiederherstellungscode
- Module **Aufgaben** und **Notizen**, Übersicht mit Sync-Symbol
- **Gerätekopplung per Code und Synchronisation im WLAN:** automatisch alle 30 Sekunden, 2 Sekunden nach jeder Änderung, beim Öffnen der App und auf Knopfdruck. Gleichzeitige Änderungen werden erkannt, die unterlegene Version wird aufbewahrt.
- Windows-Installer (.exe) mit Firewall-Freigabe, Android-App (.apk)

**Noch nicht drin**

- Automatisches Finden der Geräte im WLAN (die Adresse wird einmal eingetippt)
- QR-Code beim Koppeln, Gerätezertifikate, echter Widerruf (siehe [ADR-0004](docs/adr/0004-sync-testversion.md))
- Übersicht zum Auflösen von Konflikten
- Kalender, Finanzen und alle weiteren Module
- iOS-Build (braucht einen Mac oder Mac-Build-Dienst)

## Installationsdateien bekommen – ohne eigene Entwicklungsumgebung

Am einfachsten baut GitHub die Dateien für dich. Du brauchst nur ein kostenloses GitHub-Konto.

1. Auf github.com ein neues, **privates** Repository anlegen, z. B. `lifeos`.
2. Den Inhalt dieses Ordners hochladen. Entweder per „uploading an existing file“ im Browser (alle Dateien und Ordner hineinziehen, auch den versteckten Ordner `.github`) oder mit Git:
   ```powershell
   git init
   git add -A
   git commit -m "LifeOS 0.2.0"
   git branch -M main
   git remote add origin https://github.com/<dein-name>/lifeos.git
   git push -u origin main
   ```
3. Im Repository auf **Actions** klicken. Der Lauf „Build“ startet automatisch und dauert etwa 15 Minuten.
4. Lauf anklicken, unten unter **Artifacts** liegen:
   - `LifeOS-Windows-Installer` → enthält `LifeOS-Setup-0.2.0.exe`
   - `LifeOS-Android-APK` → enthält `LifeOS-0.2.0.apk`

Schlägt ein Schritt fehl, kopiere die rote Fehlermeldung aus dem Lauf und schick sie an Claude.

## Installieren

**Windows**

1. `LifeOS-Setup-0.2.0.exe` starten. Windows SmartScreen warnt, weil die Datei nicht signiert ist: „Weitere Informationen“ → „Trotzdem ausführen“.
2. Der Installer fragt nach Admin-Rechten. Die braucht er nur für die Firewall-Freigabe der Synchronisation (nur aus dem eigenen Netz).

**Android**

1. `LifeOS-0.2.0.apk` aufs Handy kopieren (z. B. per USB, Mail an dich selbst oder Cloud-Ordner) und antippen.
2. Android fragt, ob die Quelle Apps installieren darf: erlauben.
3. Hinweis: Jede neue Testversion ist mit einem anderen Testschlüssel signiert. Vor einem Update die alte Version deinstallieren. Deine Daten kommen danach per Sync vom PC zurück.

## Zwei Geräte koppeln

Beide Geräte müssen im **selben WLAN** sein (kein Gäste-WLAN). Auf beiden Geräten zuerst die PIN einrichten.

1. **PC:** Einstellungen → Geräte & Synchronisation → **Gerät hinzufügen**. Es erscheinen Adresse (z. B. `192.168.178.20:47321`) und Code.
2. **Handy:** Einstellungen → Geräte & Synchronisation → **Mit Code verbinden**. Adresse und Code eintippen → Verbinden.
3. Fertig. Auf der Übersicht zeigt das Symbol oben rechts „Synced“. Eine Aufgabe auf dem Handy erscheint nach wenigen Sekunden auf dem PC und umgekehrt.

Gleichzeitig muss die App auf beiden Geräten **geöffnet** sein. Android und iOS lassen eine App im Hintergrund nicht dauerhaft lauschen. Änderungen gehen dabei nicht verloren, sie werden beim nächsten Öffnen übertragen.

Ändert sich die Adresse eines Geräts (neuer Router, andere IP), findet das andere Gerät es beim nächsten Kontakt meist von selbst. Sonst unter „Gekoppelte Geräte“ → ⋮ → „Adresse ändern“.

## Selbst entwickeln unter Windows

Nur nötig, wenn du selbst am Code arbeiten willst.

1. **Git** installieren: https://git-scm.com/download/win
2. **Entwicklermodus** einschalten: Einstellungen → System → Für Entwickler.
3. **Visual Studio 2022 Community** mit Workload „Desktopentwicklung mit C++“ und der Einzelkomponente „C++ ATL für neueste Buildtools“.
4. **Flutter**: https://docs.flutter.dev/get-started/install/windows/desktop
5. **Android Studio** (für Android): https://developer.android.com/studio, danach `flutter doctor --android-licenses`.
6. **Inno Setup 6** (für die .exe): https://jrsoftware.org/isdl.php
7. Im Projektordner:
   ```powershell
   powershell -ExecutionPolicy Bypass -File tool\setup.ps1          # vorbereiten und testen
   cd apps\lifeos_app; flutter run -d windows                      # starten
   powershell -ExecutionPolicy Bypass -File tool\build-windows.ps1  # dist\LifeOS-Setup-0.2.0.exe
   ```

## Projektstruktur

```text
apps/lifeos_app/            App: Start, Router, Übersicht, Einstellungen, Geräte
packages/core/              IDs und Hybrid Logical Clock (reines Dart)
packages/persistence/       Drift-Datenbank, Verschlüsselung, Änderungsprotokoll
packages/sync/              Zusammenführen, Verschlüsselung, Server, Client, Kopplung
packages/security/          PIN, Wiederherstellungscode, App-Sperre, Schlüsselspeicher
packages/design_system/     Theme, adaptive Navigation, gemeinsame Bausteine
packages/features/tasks/    Modul Aufgaben
packages/features/notes/    Modul Notizen
installer/lifeos.iss        Windows-Installer (Inno Setup)
tool/                       Vorbereiten, Testen, Bauen
.github/workflows/          Automatischer Build von .exe und .apk
docs/                       Architektur und Architekturentscheidungen (ADR)
```

## Wenn etwas nicht klappt

- **„Gerät nicht erreichbar“:** Beide im selben WLAN? App auf dem anderen Gerät geöffnet? Auf dem PC die Firewall-Freigabe zugelassen? Ohne Installer fragt Windows beim ersten Start danach.
- **„Code falsch oder abgelaufen“:** Der Code gilt 10 Minuten und nach 5 Fehlversuchen nicht mehr. Auf dem PC einen neuen Code erzeugen.
- **Fehler beim Bauen:** Die komplette Fehlermeldung an Claude schicken. Der Code wurde ohne Flutter-SDK geschrieben. Kleine Fehler beim ersten Build sind möglich und meist schnell behoben.
- **Daten zurücksetzen (nur zum Testen):** App deinstallieren. Unter Windows zusätzlich den Ordner `%APPDATA%\LifeOS` löschen. Achtung: Alle Daten auf diesem Gerät sind dann weg.
