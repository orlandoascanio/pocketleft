Unicode true

!include "MUI2.nsh"
!include "x64.nsh"

!define INSTALL_ROOT "$LOCALAPPDATA\Programs\PocketLeft"
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\PocketLeft"
!define RUN_KEY "Software\Microsoft\Windows\CurrentVersion\Run"
!define POCKET_MUTEX "PocketLeft.Windows.0565FA1A-EFFD-45A3-AC83-D182CFABB2B7"

Name "Pocket"
Caption "Pocket Setup"
BrandingText "PocketLeft"
OutFile "${POCKET_SETUP}"
InstallDir "${INSTALL_ROOT}"
RequestExecutionLevel user
SetCompressor /SOLID lzma
ShowInstDetails nevershow
VIProductVersion "0.1.0.0"
VIAddVersionKey "ProductName" "Pocket"
VIAddVersionKey "FileDescription" "Pocket for Windows Setup"
VIAddVersionKey "CompanyName" "PocketLeft"
VIAddVersionKey "FileVersion" "0.1.0"
VIAddVersionKey "LegalCopyright" "PocketLeft"

!define MUI_ICON "Pocket.ico"
!define MUI_UNICON "Pocket.ico"
!define MUI_WELCOMEPAGE_TITLE "Install Pocket"
!define MUI_WELCOMEPAGE_TEXT "Pocket opens from the tray beside the Windows clock. Setup installs it for your Windows account and adds a Start menu shortcut."
!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_TEXT "Open Pocket"
!define MUI_FINISHPAGE_RUN_FUNCTION LaunchPocket

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Var PocketMutex

!macro LockPocket
  ; Reserve the same single-instance mutex used in Program.cs during file changes.
  System::Call 'kernel32::CreateMutexW(p 0, i 1, w "${POCKET_MUTEX}") p .r0 ?e'
  Pop $1
  ${If} $0 == 0
  ${OrIf} $1 == 183
    MessageBox MB_OK|MB_ICONEXCLAMATION "Close other Pocket setup windows and choose Quit Pocket from the tray, then try again." /SD IDOK
    SetErrorLevel 1
    Abort
  ${EndIf}
  StrCpy $PocketMutex $0
!macroend

Function .onInit
  ${IfNot} ${IsNativeAMD64}
  ${AndIfNot} ${IsNativeARM64}
    MessageBox MB_OK|MB_ICONEXCLAMATION "Pocket requires a 64-bit Intel, AMD, or ARM PC." /SD IDOK
    SetErrorLevel 1
    Abort
  ${EndIf}
  ; Keep binaries and uninstall files under a fixed, per-user location.
  StrCpy $INSTDIR "${INSTALL_ROOT}"
  SetShellVarContext current
  SetRegView 64
  !insertmacro LockPocket
FunctionEnd

Section "Pocket"
  ; Restore the previous install if setup was interrupted between the two renames.
  SetOutPath "$INSTDIR"
  ${If} ${FileExists} "$INSTDIR\app.previous\Pocket.exe"
    ${IfNot} ${FileExists} "$INSTDIR\app\Pocket.exe"
      ClearErrors
      Rename "$INSTDIR\app.previous" "$INSTDIR\app"
      IfErrors InstallFailed
    ${EndIf}
  ${EndIf}
  RMDir /r "$INSTDIR\app.new"
  RMDir /r "$INSTDIR\app.previous"

  ClearErrors
  SetOutPath "$INSTDIR\app.new"
  AllowSkipFiles off
  ${If} ${IsNativeARM64}
    File /r /x "*.pdb" /x "*.xml" "${POCKET_PAYLOAD}/win-arm64/*"
  ${Else}
    File /r /x "*.pdb" /x "*.xml" "${POCKET_PAYLOAD}/win-x64/*"
  ${EndIf}
  IfErrors InstallFailed

  SetOutPath "$INSTDIR"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  IfErrors InstallFailed
  ${If} ${FileExists} "$INSTDIR\app\*"
    Rename "$INSTDIR\app" "$INSTDIR\app.previous"
    IfErrors InstallFailed
  ${EndIf}
  Rename "$INSTDIR\app.new" "$INSTDIR\app"
  ${If} ${Errors}
    Rename "$INSTDIR\app.previous" "$INSTDIR\app"
    Goto InstallFailed
  ${EndIf}
  RMDir /r "$INSTDIR\app.previous"

  SetOutPath "$INSTDIR\app"
  CreateShortCut "$SMPROGRAMS\Pocket.lnk" "$INSTDIR\app\Pocket.exe"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "Pocket"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "0.1.0"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "Publisher" "PocketLeft"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\app\Pocket.exe"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" '$\"$INSTDIR\Uninstall.exe$\"'
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1

  ReadRegStr $0 HKCU "${RUN_KEY}" "PocketLeft"
  ${If} $0 != ""
    ; Preserve the user's opt-in when moving from the portable preview.
    WriteRegStr HKCU "${RUN_KEY}" "PocketLeft" '$\"$INSTDIR\app\Pocket.exe$\" --background'
  ${EndIf}
  Goto Done

  InstallFailed:
    SetOutPath "$INSTDIR"
    RMDir /r "$INSTDIR\app.new"
    MessageBox MB_OK|MB_ICONEXCLAMATION "Setup could not write the Pocket installation. Check the available disk space and try again." /SD IDOK
    SetErrorLevel 1
    Abort
  Done:
SectionEnd

Function LaunchPocket
  StrCpy $0 $PocketMutex
  System::Call 'kernel32::ReleaseMutex(p r0)'
  System::Call 'kernel32::CloseHandle(p r0)'
  ExecShell "open" "$INSTDIR\app\Pocket.exe"
FunctionEnd

Function un.onInit
  StrCpy $INSTDIR "${INSTALL_ROOT}"
  SetShellVarContext current
  SetRegView 64
  !insertmacro LockPocket
FunctionEnd

Section "Uninstall"
  SetOutPath "$TEMP"
  ClearErrors
  RMDir /r "$INSTDIR\app"
  ${If} ${Errors}
    MessageBox MB_OK|MB_ICONEXCLAMATION "Windows could not remove the Pocket app files. Close Pocket and try again." /SD IDOK
    SetErrorLevel 1
    Abort
  ${EndIf}
  RMDir /r "$INSTDIR\app.new"
  RMDir /r "$INSTDIR\app.previous"
  Delete "$SMPROGRAMS\Pocket.lnk"
  ReadRegStr $0 HKCU "${RUN_KEY}" "PocketLeft"
  ${If} $0 == '$\"$INSTDIR\app\Pocket.exe$\" --background'
    DeleteRegValue HKCU "${RUN_KEY}" "PocketLeft"
  ${EndIf}
  DeleteRegKey HKCU "${UNINSTALL_KEY}"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
SectionEnd
