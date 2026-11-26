# LifeOS – Windows-Installationsdatei bauen
#
# Aufruf aus dem Projektordner (nach setup.ps1):
#   powershell -ExecutionPolicy Bypass -File tool\build-windows.ps1
#
# Voraussetzung: Inno Setup 6 (https://jrsoftware.org/isdl.php).
# Ergebnis: dist\LifeOS-Setup-<Version>.exe

param([string] $Version = '')

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$app = Join-Path $root 'apps/lifeos_app'

if (-not $Version) {
    $match = Select-String -Path (Join-Path $app 'pubspec.yaml') -Pattern '^version:\s*([0-9.]+)'
    $Version = $match.Matches[0].Groups[1].Value
}
Write-Host "Version $Version"

Push-Location $app
try {
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw 'flutter build windows ist fehlgeschlagen.' }
}
finally {
    Pop-Location
}

$release = Join-Path $app 'build/windows/x64/runner/Release'
if (-not (Test-Path (Join-Path $release 'lifeos_app.exe'))) {
    throw "lifeos_app.exe wurde nicht gefunden in $release"
}

# Visual-C++-Laufzeit mitliefern, damit die App auch auf PCs ohne sie startet.
foreach ($dll in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
    $source = Join-Path $env:WINDIR "System32\$dll"
    if (Test-Path $source) { Copy-Item $source $release -Force }
}

$iscc = $null
$command = Get-Command iscc.exe -ErrorAction SilentlyContinue
if ($command) { $iscc = $command.Source }
$candidates = @(
    (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
    (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe')
)
foreach ($candidate in $candidates) {
    if (-not $iscc -and (Test-Path $candidate)) { $iscc = $candidate }
}
if (-not $iscc) {
    throw 'Inno Setup 6 wurde nicht gefunden. Download: https://jrsoftware.org/isdl.php'
}

$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
& $iscc "/DMyAppVersion=$Version" "/DSourceDir=$release" "/DOutputDir=$dist" (Join-Path $root 'installer/lifeos.iss')
if ($LASTEXITCODE -ne 0) { throw 'Inno Setup ist fehlgeschlagen.' }

Write-Host ''
Write-Host "Fertig: $dist\LifeOS-Setup-$Version.exe" -ForegroundColor Green
