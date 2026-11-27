; OpenChroma installer (Inno Setup 6). Built by scripts\build-release.ps1,
; which passes AppVersion, SourceDir (the packaged app) and OutputDir.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\dist"
#endif

#define AppName "OpenChroma"
#define AppExe "openchroma.exe"
#define AppUrl "https://github.com/Dnowdd/OpenChroma"

[Setup]
; Never change AppId: Windows uses it to find the installed copy on updates.
AppId={{6E0C7B7A-3F0B-4C1E-9D2A-0C5E8B1F4A21}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=OpenChroma
AppPublisherURL={#AppUrl}
AppSupportURL={#AppUrl}/issues
AppUpdatesURL={#AppUrl}/releases
VersionInfoVersion={#AppVersion}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
; Installs for the current user without asking for admin; the dialog lets
; the user pick "all users" instead.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
OutputDir={#OutputDir}
OutputBaseFilename={#AppName}-{#AppVersion}-setup
LicenseFile=..\LICENSE
setupiconfile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern dark
WizardBackColor=#0C0C0E
WizardImageBackColor=#0C0C0E
WizardImageFile=images\wizard-164.bmp,images\wizard-192.bmp,images\wizard-246.bmp,images\wizard-273.bmp,images\wizard-328.bmp,images\wizard-355.bmp,images\wizard-410.bmp
WizardSmallImageFile=images\small-55.bmp,images\small-64.bmp,images\small-83.bmp,images\small-92.bmp,images\small-110.bmp,images\small-119.bmp,images\small-138.bmp
; The app holds this mutex while it runs; setup asks to close it first.
AppMutex=Local\OpenChroma.Instance
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"
Name: "ptbr"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[CustomMessages]
ptbr.StartWithWindows=Iniciar o OpenChroma com o Windows (na bandeja)
en.StartWithWindows=Start OpenChroma with Windows (in the tray)
ptbr.StartupGroup=Inicialização:
en.StartupGroup=Startup:
ptbr.InstallPawnIO=Instalar o driver PawnIO (RGB da memória RAM, ventoinhas da placa-mãe e temperatura da CPU)
en.InstallPawnIO=Install the PawnIO driver (RAM lighting, motherboard fans and CPU temperature)
ptbr.DriversGroup=Drivers:
en.DriversGroup=Drivers:
ptbr.InstallingPawnIO=Instalando o driver PawnIO...
en.InstallingPawnIO=Installing the PawnIO driver...
ptbr.PawnIOFailed=O PawnIO não foi instalado. Sem ele, o RGB da memória RAM, as ventoinhas da placa-mãe e a temperatura da CPU não funcionam. Instale depois em https://pawnio.eu
en.PawnIOFailed=PawnIO was not installed. Without it, RAM lighting, motherboard fans and CPU temperature won't work. You can install it later from https://pawnio.eu
ptbr.InstallingWebView2=Instalando o Microsoft WebView2...
en.InstallingWebView2=Installing Microsoft WebView2...
ptbr.WebView2Failed=Não foi possível instalar o Microsoft WebView2 agora. Os efeitos HTML importados precisam dele: baixe em https://developer.microsoft.com/microsoft-edge/webview2/
en.WebView2Failed=Microsoft WebView2 couldn't be installed right now. Imported HTML effects need it: download it from https://developer.microsoft.com/microsoft-edge/webview2/
ptbr.RemoveUserData=Remover também as suas configurações, perfis, efeitos importados e plugins (%APPDATA%\OpenChroma)?
en.RemoveUserData=Also remove your settings, profiles, imported effects and plugins (%APPDATA%\OpenChroma)?
ptbr.RemovePawnIO=Desinstalar também o driver PawnIO?%n%nOutros programas (como FanControl ou LibreHardwareMonitor) podem usá-lo. Na dúvida, mantenha.
en.TaskLeft=The "OpenChroma" startup task (run as administrator) could not be removed. Remove it in Task Scheduler, or run this as administrator:%n%nschtasks /Delete /TN OpenChroma /F
ptbr.TaskLeft=Não foi possível remover a tarefa de inicialização "OpenChroma" (como administrador). Remova pelo Agendador de Tarefas ou rode como administrador:%n%nschtasks /Delete /TN OpenChroma /F
en.RemovePawnIO=Also uninstall the PawnIO driver?%n%nOther programs (such as FanControl or LibreHardwareMonitor) may use it. If unsure, keep it.

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "startup"; Description: "{cm:StartWithWindows}"; GroupDescription: "{cm:StartupGroup}"
Name: "pawnio"; Description: "{cm:InstallPawnIO}"; GroupDescription: "{cm:DriversGroup}"; Check: not HasPawnIO

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "redist\MicrosoftEdgeWebview2Setup.exe"; Flags: dontcopy noencryption
Source: "redist\PawnIO_setup.exe"; Flags: dontcopy noencryption

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent shellexec

[Registry]
; Same value the app's "Start with Windows" switch writes (lib/src/system/
; launch_settings.dart), so the switch shows it as on.
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "OpenChroma"; ValueData: """{app}\{#AppExe}"" --hidden"; Tasks: startup
; Settings the app writes, removed with it.
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: none; ValueName: "OpenChroma"; Flags: uninsdeletevalue dontcreatekey
Root: HKCU; Subkey: "Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"; ValueType: none; ValueName: "{app}\{#AppExe}"; Flags: uninsdeletevalue dontcreatekey
Root: HKCU; Subkey: "Software\OpenChroma"; Flags: uninsdeletekey dontcreatekey

[Code]
// The effects render in Microsoft Edge WebView2. Windows 11 ships it; some
// Windows 10 PCs do not, so setup installs it when missing.
const
  WebView2Key = 'SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}';

function HasWebView2(): Boolean;
var
  Version: String;
begin
  Result :=
    (RegQueryStringValue(HKLM, 'SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}', 'pv', Version) and (Version <> '') and (Version <> '0.0.0.0')) or
    (RegQueryStringValue(HKLM, WebView2Key, 'pv', Version) and (Version <> '') and (Version <> '0.0.0.0')) or
    (RegQueryStringValue(HKCU, WebView2Key, 'pv', Version) and (Version <> '') and (Version <> '0.0.0.0'));
end;

const
  PawnIOKey = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\PawnIO';
  ErrorSuccessRebootRequired = 3010;

function HasPawnIO(): Boolean;
var
  Version: String;
begin
  Result :=
    (RegQueryStringValue(HKLM64, PawnIOKey, 'DisplayVersion', Version) and (Version <> '')) or
    (RegQueryStringValue(HKLM32, PawnIOKey, 'DisplayVersion', Version) and (Version <> ''));
end;

// The PawnIO setup is redistributable unmodified only: never patch or repack it.
procedure InstallPawnIO();
var
  Code: Integer;
begin
  WizardForm.StatusLabel.Caption := CustomMessage('InstallingPawnIO');
  ExtractTemporaryFile('PawnIO_setup.exe');
  if not ShellExec('runas', ExpandConstant('{tmp}\PawnIO_setup.exe'), '-install -silent', '',
                   SW_HIDE, ewWaitUntilTerminated, Code)
     or ((Code <> 0) and (Code <> ErrorSuccessRebootRequired)) or not HasPawnIO() then
    MsgBox(CustomMessage('PawnIOFailed'), mbInformation, MB_OK);
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Code: Integer;
begin
  if (CurStep = ssPostInstall) and WizardIsTaskSelected('pawnio') and not HasPawnIO() then
    InstallPawnIO();
  if (CurStep = ssPostInstall) and not HasWebView2() then
  begin
    WizardForm.StatusLabel.Caption := CustomMessage('InstallingWebView2');
    ExtractTemporaryFile('MicrosoftEdgeWebview2Setup.exe');
    if not Exec(ExpandConstant('{tmp}\MicrosoftEdgeWebview2Setup.exe'), '/silent /install', '',
                SW_HIDE, ewWaitUntilTerminated, Code) or (Code <> 0) then
      MsgBox(CustomMessage('WebView2Failed'), mbInformation, MB_OK);
  end;
end;

function TaskExists(): Boolean;
var
  Code: Integer;
begin
  Result := Exec(ExpandConstant('{sys}\schtasks.exe'), '/Query /TN "OpenChroma"', '', SW_HIDE, ewWaitUntilTerminated, Code) and (Code = 0);
end;

// The "open as administrator at startup" task is created elevated, so a
// per-user uninstall can only delete it through UAC.
procedure DeleteLogonTask();
var
  Code: Integer;
begin
  if not TaskExists() then Exit;
  Exec(ExpandConstant('{sys}\schtasks.exe'), '/Delete /TN "OpenChroma" /F', '', SW_HIDE, ewWaitUntilTerminated, Code);
  if TaskExists() then
    ShellExec('runas', ExpandConstant('{sys}\schtasks.exe'), '/Delete /TN "OpenChroma" /F', '', SW_HIDE, ewWaitUntilTerminated, Code);
  if TaskExists() then
    SuppressibleMsgBox(CustomMessage('TaskLeft'), mbError, MB_OK, IDOK);
end;

function PawnIOUninstaller(): String;
var
  Command: String;
  Quote: Integer;
begin
  Result := '';
  if not (RegQueryStringValue(HKLM64, PawnIOKey, 'UninstallString', Command) or
          RegQueryStringValue(HKLM32, PawnIOKey, 'UninstallString', Command)) then Exit;
  Command := Trim(Command);
  if (Length(Command) > 1) and (Command[1] = '"') then
  begin
    Delete(Command, 1, 1);
    Quote := Pos('"', Command);
    if Quote > 0 then Result := Copy(Command, 1, Quote - 1);
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Code: Integer;
  Uninstaller: String;
begin
  if CurUninstallStep = usUninstall then
    DeleteLogonTask();
  if CurUninstallStep = usPostUninstall then
  begin
    if (not UninstallSilent()) and
       (MsgBox(CustomMessage('RemoveUserData'), mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES) then
      DelTree(ExpandConstant('{userappdata}\OpenChroma'), True, True, True);
    Uninstaller := PawnIOUninstaller();
    if (not UninstallSilent()) and (Uninstaller <> '') and FileExists(Uninstaller) and
       (MsgBox(CustomMessage('RemovePawnIO'), mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES) then
      ShellExec('runas', Uninstaller, '-uninstall -silent', '', SW_HIDE, ewWaitUntilTerminated, Code);
  end;
end;
