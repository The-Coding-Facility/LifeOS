# LifeOS – Einrichtung unter Windows
#
# Aufruf aus dem Projektordner:
#   powershell -ExecutionPolicy Bypass -File tool\setup.ps1
#
# Das Skript
#   1. erzeugt und passt die Plattformordner der App an (prepare.ps1),
#   2. holt alle Pakete,
#   3. erzeugt den Drift-Code der Datenbank,
#   4. prüft den Code und führt alle Tests aus (test.ps1).

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'Flutter wurde nicht gefunden. Bitte zuerst die Einrichtung aus der README durchführen.'
}

& (Join-Path $PSScriptRoot 'prepare.ps1')

flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get ist fehlgeschlagen.' }

Push-Location (Join-Path $root 'packages/persistence')
try {
    dart run build_runner build --delete-conflicting-outputs
    if ($LASTEXITCODE -ne 0) { throw 'Die Code-Generierung (Drift) ist fehlgeschlagen.' }
}
finally {
    Pop-Location
}

& (Join-Path $PSScriptRoot 'test.ps1')

Write-Host ''
Write-Host 'Fertig. Starten unter Windows:' -ForegroundColor Green
Write-Host '  cd apps\lifeos_app'
Write-Host '  flutter run -d windows'
Write-Host 'Installationsdatei bauen:'
Write-Host '  powershell -ExecutionPolicy Bypass -File tool\build-windows.ps1'
