; =====================================================================
; ProksiFi v2.0 Official Inno Setup Installer Script
; Чистый нативный установщик Windows без ложных срабатываний антивирусов
; =====================================================================

#define MyAppName "ProksiFi"
#define MyAppVersion "2.0.0"
#define MyAppPublisher "ProksiFi Project"
#define MyAppURL "https://t.me/antigravity_proxy"
#define MyAppExeName "ProksiFi_Tray.exe"

[Setup]
AppId={{C7E3B182-5A19-4F90-B8E2-998C1E456201}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DisableDirPage=no
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\release
OutputBaseFilename=ProksiFi_v2.0_Setup
SetupIconFile=app.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
CloseApplications=yes
RestartApplications=no
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\app.ico
VersionInfoVersion=2.0.0.0
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription=ProksiFi v2.0 Service & Tray Setup
VersionInfoCopyright=© 2026 ProksiFi Project. All rights reserved.

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "autostart"; Description: "Автоматически запускать ProksiFi в системном трее при входе в Windows"; GroupDescription: "Параметры автозапуска:"

[Files]
; 1. Главный агент трея Windows 11
Source: "..\bin\ProksiFi_Tray.exe"; DestDir: "{app}"; Flags: ignoreversion

; 2. Ядро маршрутизации и служба WinSW
Source: "..\bin\core.exe"; DestDir: "{app}\bin"; Flags: ignoreversion
Source: "..\bin\service.exe"; DestDir: "{app}\bin"; Flags: ignoreversion
Source: "..\bin\wintun.dll"; DestDir: "{app}\bin"; Flags: ignoreversion

; 3. Скрипты управления и установки
Source: "..\install.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\manage.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\uninstall.ps1"; DestDir: "{app}"; Flags: ignoreversion

; 4. Конфигурация и модули
Source: "..\config\*"; DestDir: "{app}\config"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\modules\*"; DestDir: "{app}\modules"; Flags: ignoreversion recursesubdirs createallsubdirs

; 5. Иконка
Source: "app.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\app.ico"
Name: "{group}\Диагностика ProksiFi"; Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -Command ""& '{app}\manage.ps1' -Action diag; Write-Host ''; Write-Host 'Нажмите любую клавишу для продолжения...' -ForegroundColor Yellow; $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')"""; IconFilename: "{app}\app.ico"
Name: "{group}\Удалить {#MyAppName}"; Filename: "{uninstallexe}"

[Registry]
; Автозапуск агента трея
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "ProksiFi_Tray"; ValueData: """{app}\{#MyAppExeName}"""; Tasks: autostart; Flags: uninsdeletevalue

[Run]
; Шаг 1: Автоматическая установка и запуск службы ProksiFiService через install.ps1
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\install.ps1"""; StatusMsg: "Настройка и запуск службы ProksiFiService (Frankfurt VPS)..."; Flags: runhidden

; Шаг 2: Запуск агента в системном трее Windows 11
Filename: "{app}\{#MyAppExeName}"; Description: "Запустить ProksiFi в системном трее"; Flags: nowait postinstall skipifsilent runascurrentuser

[UninstallRun]
; Остановка и удаление перед деинсталляцией
Filename: "taskkill"; Parameters: "/F /IM ProksiFi_Tray.exe"; Flags: runhidden
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\uninstall.ps1"" -FullClean"; Flags: runhidden
