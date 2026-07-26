; aw-cli Inno Setup configuration
; Compiles via Minionguyjpro/Inno-Setup-Action@v1.2.2 in CI/CD
; Version and paths are substituted by the CI pipeline at build time.

#define MyAppName "aw-cli"
#define MyAppVersion "@VERSION@"
#define MyAppPublisher "aw-cli Contributors"
#define MyAppExeName "aw-cli.exe"
#define MyAppURL "https://github.com/axelumatica/aw-cli-powershell"

[Setup]
AppId={{E8A1C2D3-4F5B-6A7C-8D9E-0F1A2B3C4D5E}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=dist
OutputBaseFilename=aw-cli-{#MyAppVersion}-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; The standalone EXE
Source: "dist\aw-cli.exe"; DestDir: "{app}"; Flags: ignoreversion
; The PowerShell module (src folder as zip)
Source: "dist\aw-cli-module.zip"; DestDir: "{app}\module"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: quicklaunchicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// Check if PowerShell 5.1+ is installed
function IsPowerShellInstalled: Boolean;
begin
  Result := FileExists(ExpandConstant('{sys}\WindowsPowerShell\v1.0\PowerShell.exe'));
end;

// Add app directory to User PATH
procedure CurStepChanged(CurStep: TSetupStep);
var
  PathEntry: String;
  CurrentPath: String;
begin
  if CurStep = ssPostInstall then
  begin
    PathEntry := ExpandConstant('{app}');

    // Ensure Path key exists
    if not RegValueExists(HKCU, 'Environment', 'Path') then
      RegWriteStringValue(HKCU, 'Environment', 'Path', '');

    // Append our path to the existing one
    CurrentPath := RegQueryStringValue(HKCU, 'Environment', 'Path');
    if Pos(PathEntry, CurrentPath) = 0 then
    begin
      RegWriteExpandStringValue(HKCU, 'Environment', 'Path', CurrentPath + ';' + PathEntry);
      // Notify Windows of the environment change
      SendMessage(HWND_BROADCAST, WM_SETTINGCHANGE, 0, 'Environment');
    end;
  end;
end;

procedure InitializeWizard;
begin
  if not IsPowerShellInstalled then
  begin
    MsgBox('PowerShell 5.1 non trovato. Assicurati che Windows sia aggiornato.', mbInformation, MB_OK);
  end;
end;
end;