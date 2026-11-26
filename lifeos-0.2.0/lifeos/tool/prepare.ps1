# LifeOS – Plattformordner erzeugen und anpassen
#
# Erzeugt mit `flutter create` die Ordner windows, android und ios der App
# (falls sie fehlen) und passt sie an. Kann beliebig oft laufen.
# Wird von setup.ps1 und vom automatischen Build (GitHub Actions) genutzt.

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$app = Join-Path $root 'apps/lifeos_app'

function Update-TextFile {
    param([string] $Path, [scriptblock] $Change)
    if (-not (Test-Path $Path)) { return }
    $before = [IO.File]::ReadAllText($Path)
    $after = & $Change $before
    if ($after -ne $before) {
        [IO.File]::WriteAllText($Path, $after)
        Write-Host "Angepasst: $Path"
    }
}

if (-not (Test-Path (Join-Path $app 'windows'))) {
    Push-Location $app
    try {
        flutter create --platforms=windows,android,ios --org de.lifeos --project-name lifeos_app .
        if ($LASTEXITCODE -ne 0) { throw 'flutter create ist fehlgeschlagen.' }
    }
    finally {
        Pop-Location
    }
}

# Android: Netzwerkzugriff für den Sync, kein Cloud-Backup, Name „LifeOS“.
Update-TextFile (Join-Path $app 'android/app/src/main/AndroidManifest.xml') {
    param($text)
    if ($text -notmatch 'android\.permission\.INTERNET') {
        $permission = "`n    <uses-permission android:name=`"android.permission.INTERNET`" />"
        $text = [regex]::Replace($text, '(<manifest[^>]*>)', '$1' + $permission)
    }
    if ($text -notmatch 'allowBackup') {
        $text = $text.Replace('<application', '<application android:allowBackup="false" android:fullBackupContent="false" android:usesCleartextTraffic="true"')
    }
    $text.Replace('android:label="lifeos_app"', 'android:label="LifeOS"')
}

# Android: Mindestversion 8.0 (API 26), damit alle Plugins passen.
Update-TextFile (Join-Path $app 'android/app/build.gradle.kts') {
    param($text)
    $text.Replace('minSdk = flutter.minSdkVersion', 'minSdk = 26')
}
Update-TextFile (Join-Path $app 'android/app/build.gradle') {
    param($text)
    $text.Replace('minSdkVersion flutter.minSdkVersion', 'minSdkVersion 26')
}

# Windows: Fenstertitel und Programmname „LifeOS“.
Update-TextFile (Join-Path $app 'windows/runner/main.cpp') {
    param($text)
    $text.Replace('L"lifeos_app"', 'L"LifeOS"')
}
Update-TextFile (Join-Path $app 'windows/runner/Runner.rc') {
    param($text)
    $text = [regex]::Replace($text, 'VALUE "CompanyName", "[^"]*"', 'VALUE "CompanyName", "LifeOS"')
    $text = [regex]::Replace($text, 'VALUE "ProductName", "[^"]*"', 'VALUE "ProductName", "LifeOS"')
    [regex]::Replace($text, 'VALUE "FileDescription", "[^"]*"', 'VALUE "FileDescription", "LifeOS"')
}

# iOS: angezeigter Name „LifeOS“.
Update-TextFile (Join-Path $app 'ios/Runner/Info.plist') {
    param($text)
    $text.Replace('<string>Lifeos App</string>', '<string>LifeOS</string>')
}

Write-Host 'Plattformordner sind bereit.'
