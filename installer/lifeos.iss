; LifeOS – Windows-Installer (Inno Setup 6)
;
; Wird von tool\build-windows.ps1 aufgerufen. Werte können per /D überschrieben werden.

#ifndef MyAppVersion
  #define MyAppVersion "0.2.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\apps\lifeos_app\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\dist"
#endif

#define MyAppName "LifeOS"
#define MyAppExe "lifeos_app.exe"
#define FirewallRule "LifeOS Sync"

[Setup]
AppId={{8C5D2F7A-3B41-4E6A-9F0C-5A7B2D1E4C38}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppName}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename=LifeOS-Setup-{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Admin-Rechte nur für die Firewall-Freigabe der Synchronisation.
PrivilegesRequired=admin
UninstallDisplayIcon={app}\{#MyAppExe}
CloseApplications=yes

[Languages]
Name: "german"; MessagesFile: "compiler:Languages\German.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Gleiche AppUserModelID wie in der App, damit Erinnerungen als „LifeOS“ erscheinen.
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExe}"; AppUserModelID: "de.lifeos.LifeOS"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExe}"; Tasks: desktopicon

[Run]
; Eingehende Verbindungen nur aus dem eigenen Netz (Subnetz) erlauben.
; Die Daten selbst sind zusätzlich verschlüsselt und nur für gekoppelte Geräte lesbar.
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""{#FirewallRule}"""; Flags: runhidden
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""{#FirewallRule}"" dir=in action=allow program=""{app}\{#MyAppExe}"" enable=yes profile=any remoteip=localsubnet"; Flags: runhidden; StatusMsg: "Firewall-Freigabe für die Synchronisation im Heimnetz ..."
Filename: "{app}\{#MyAppExe}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent runasoriginaluser

[UninstallRun]
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""{#FirewallRule}"""; Flags: runhidden; RunOnceId: "RemoveLifeOSFirewallRule"
