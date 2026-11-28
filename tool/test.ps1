# LifeOS – Analyse und alle Tests
#
# Voraussetzung: prepare.ps1, `flutter pub get` und die Drift-Code-Generierung
# sind gelaufen (setup.ps1 erledigt das).

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

function Invoke-InPackage {
    param([string] $Directory, [string] $Tool)
    Write-Host ''
    Write-Host "==> $Tool test: $Directory" -ForegroundColor Cyan
    Push-Location (Join-Path $root $Directory)
    try {
        & $Tool test
        if ($LASTEXITCODE -ne 0) { throw "Tests fehlgeschlagen in $Directory" }
    }
    finally {
        Pop-Location
    }
}

Push-Location $root
try {
    # Nur echte Fehler brechen ab. Hinweise und Warnungen werden angezeigt.
    flutter analyze --no-fatal-infos --no-fatal-warnings
    if ($LASTEXITCODE -ne 0) { throw 'Die statische Analyse hat Fehler gefunden.' }
}
finally {
    Pop-Location
}

foreach ($package in @('packages/core', 'packages/persistence', 'packages/sync')) {
    Invoke-InPackage $package 'dart'
}
$flutterPackages = @(
    'packages/security',
    'packages/design_system',
    'packages/features/tags',
    'packages/features/tasks',
    'packages/features/notes',
    'packages/features/calendar',
    'packages/features/finance',
    'packages/features/daily_report',
    'packages/features/habits',
    'packages/features/projects',
    'packages/features/kitchen',
    'packages/features/learning',
    'packages/features/sport',
    'apps/lifeos_app'
)
foreach ($package in $flutterPackages) {
    Invoke-InPackage $package 'flutter'
}

Write-Host ''
Write-Host 'Alle Tests bestanden.' -ForegroundColor Green
