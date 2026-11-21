Unicode true

!include "MUI2.nsh"
!include "x64.nsh"
!include "nsDialogs.nsh"
!include "FileFunc.nsh"

!define SETUP_VERSION "0.1.2"
!define DEFAULT_INSTALL_ROOT "$LOCALAPPDATA\Programs\PocketLeft"
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\PocketLeft"
!define RUN_KEY "Software\Microsoft\Windows\CurrentVersion\Run"
!define POCKET_MUTEX "PocketLeft.Windows.0565FA1A-EFFD-45A3-AC83-D182CFABB2B7"
!define OWNER_MARKER ".pocketleft-install"

Name "Pocket"
Caption "Pocket Setup"
BrandingText "PocketLeft"
OutFile "${POCKET_SETUP}"
InstallDir "${DEFAULT_INSTALL_ROOT}"
InstallDirRegKey HKCU "${UNINSTALL_KEY}" "InstallLocation"
RequestExecutionLevel user
SetCompressor /SOLID lzma
ShowInstDetails hide
VIProductVersion "${SETUP_VERSION}.0"
VIAddVersionKey "ProductName" "Pocket"
VIAddVersionKey "FileDescription" "Pocket for Windows Setup"
VIAddVersionKey "CompanyName" "PocketLeft"
VIAddVersionKey "FileVersion" "${SETUP_VERSION}"
VIAddVersionKey "LegalCopyright" "PocketLeft"

!define MUI_ICON "Pocket.ico"
!define MUI_UNICON "Pocket.ico"
!define MUI_WELCOMEPAGE_TITLE "Install Pocket"
!define MUI_WELCOMEPAGE_TEXT "Pocket opens from the tray beside the Windows clock. Choose where to install Pocket and which shortcuts to add. Your ledger stays in your Windows user profile."
!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_TEXT "Open Pocket"
!define MUI_FINISHPAGE_RUN_FUNCTION LaunchPocket

!insertmacro MUI_PAGE_WELCOME
!define MUI_DIRECTORYPAGE_TEXT_TOP "Choose a folder on your SSD or HDD. If you change drives, use a folder such as D:\Apps\PocketLeft."
!define MUI_DIRECTORYPAGE_VERIFYONLEAVE
!define MUI_PAGE_CUSTOMFUNCTION_LEAVE CheckDirectoryPage
!insertmacro MUI_PAGE_DIRECTORY
Page custom ShowOptions SaveOptions
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Var PocketMutex
Var PreviousRoot
Var HadDesktopShortcut
Var AddDesktopShortcut
Var StartAtSignIn
Var DesktopCheckbox
Var SignInCheckbox
Var SetupError
Var SetupLog
Var SetupOwnsTarget
Var MoveFrom
Var MoveTo
Var MoveError

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

!macro RemoveOwnedFiles ROOT
  RMDir /r "${ROOT}\app"
  RMDir /r "${ROOT}\app.new"
  RMDir /r "${ROOT}\app.previous"
  Delete "${ROOT}\Uninstall.exe"
  Delete "${ROOT}\${OWNER_MARKER}"
  RMDir "${ROOT}"
!macroend

!macro SetupStep TEXT
  StrCpy $SetupError "${TEXT}"
  DetailPrint "$SetupError"
  ClearErrors
!macroend

Section "Pocket" PocketPayload
  Call CheckTarget
  ${If} $SetupError != ""
    Goto InstallFailed
  ${EndIf}

  !insertmacro SetupStep "Creating the installation folder"
  SetOutPath "$INSTDIR"
  IfErrors InstallFailed
  FileOpen $0 "$INSTDIR\${OWNER_MARKER}" w
  IfErrors InstallFailed
  FileWriteUTF16LE /BOM $0 "$INSTDIR"
  FileClose $0
  IfErrors InstallFailed
  StrCpy $SetupOwnsTarget 1

  ${If} ${FileExists} "$INSTDIR\app.previous\Pocket.exe"
  ${AndIfNot} ${FileExists} "$INSTDIR\app\Pocket.exe"
    !insertmacro SetupStep "Restoring the previous installation"
    StrCpy $MoveFrom "$INSTDIR\app.previous"
    StrCpy $MoveTo "$INSTDIR\app"
    Call MoveFolder
    IfErrors InstallFailed
  ${EndIf}
  !insertmacro SetupStep "Removing files left by an earlier setup"
  RMDir /r "$INSTDIR\app.new"
  RMDir /r "$INSTDIR\app.previous"
  ${If} ${FileExists} "$INSTDIR\app.new\*"
  ${OrIf} ${FileExists} "$INSTDIR\app.previous\*"
    Goto InstallFailed
  ${EndIf}

  !insertmacro SetupStep "Extracting Pocket app files"
  SetOutPath "$INSTDIR\app.new"
  IfErrors InstallFailed
  AllowSkipFiles off
  ${If} ${IsNativeARM64}
    File /r /x "*.pdb" /x "*.xml" "${POCKET_PAYLOAD}/win-arm64/*"
  ${Else}
    File /r /x "*.pdb" /x "*.xml" "${POCKET_PAYLOAD}/win-x64/*"
  ${EndIf}
  IfErrors InstallFailed

  !insertmacro SetupStep "Writing the Pocket uninstaller"
  SetOutPath "$INSTDIR"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  IfErrors InstallFailed
  ${If} ${FileExists} "$INSTDIR\app\*"
    !insertmacro SetupStep "Saving the previous app files"
    StrCpy $MoveFrom "$INSTDIR\app"
    StrCpy $MoveTo "$INSTDIR\app.previous"
    Call MoveFolder
    IfErrors InstallFailed
  ${EndIf}
  !insertmacro SetupStep "Putting the new app files in place"
  StrCpy $MoveFrom "$INSTDIR\app.new"
  StrCpy $MoveTo "$INSTDIR\app"
  Call MoveFolder
  ${If} ${Errors}
    ${If} ${FileExists} "$INSTDIR\app.previous\Pocket.exe"
      Push $MoveError
      StrCpy $MoveFrom "$INSTDIR\app.previous"
      StrCpy $MoveTo "$INSTDIR\app"
      Call MoveFolder
      Pop $MoveError
    ${EndIf}
    Goto InstallFailed
  ${EndIf}

  !insertmacro SetupStep "Registering Pocket in Installed apps"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "Pocket"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "${SETUP_VERSION}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "Publisher" "PocketLeft"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\app\Pocket.exe"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" '$\"$INSTDIR\Uninstall.exe$\"'
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1
  IfErrors InstallFailed

  !insertmacro SetupStep "Creating the selected shortcuts"
  SetOutPath "$INSTDIR\app"
  CreateShortCut "$SMPROGRAMS\Pocket.lnk" "$INSTDIR\app\Pocket.exe"
  ${If} $AddDesktopShortcut == ${BST_CHECKED}
    CreateShortCut "$DESKTOP\Pocket.lnk" "$INSTDIR\app\Pocket.exe"
    WriteRegDWORD HKCU "${UNINSTALL_KEY}" "DesktopShortcut" 1
  ${ElseIf} $HadDesktopShortcut == 1
    Delete "$DESKTOP\Pocket.lnk"
    WriteRegDWORD HKCU "${UNINSTALL_KEY}" "DesktopShortcut" 0
  ${EndIf}
  IfErrors InstallFailed

  !insertmacro SetupStep "Saving the sign-in preference"
  ${If} $StartAtSignIn == ${BST_CHECKED}
    WriteRegStr HKCU "${RUN_KEY}" "PocketLeft" '$\"$INSTDIR\app\Pocket.exe$\" --background'
    IfErrors InstallFailed
  ${Else}
    ReadRegStr $0 HKCU "${RUN_KEY}" "PocketLeft"
    ${If} $0 != ""
      ClearErrors
      DeleteRegValue HKCU "${RUN_KEY}" "PocketLeft"
      IfErrors InstallFailed
    ${EndIf}
  ${EndIf}

  RMDir /r "$INSTDIR\app.previous"
  ; Clean up the registered old location only after the new copy is ready.
  ${If} $PreviousRoot != ""
  ${AndIf} $PreviousRoot != $INSTDIR
    StrCpy $1 ""
    ${If} ${FileExists} "$PreviousRoot\${OWNER_MARKER}"
      ClearErrors
      FileOpen $0 "$PreviousRoot\${OWNER_MARKER}" r
      ${IfNot} ${Errors}
        FileReadUTF16LE $0 $1
        FileClose $0
      ${EndIf}
    ${EndIf}
    ; A different drive letter can refer to the same folder through a drive mapping.
    ${If} $1 != $INSTDIR
      ${If} ${FileExists} "$PreviousRoot\${OWNER_MARKER}"
      ${OrIf} $PreviousRoot == "${DEFAULT_INSTALL_ROOT}"
        !insertmacro RemoveOwnedFiles "$PreviousRoot"
      ${EndIf}
    ${EndIf}
  ${EndIf}
  DetailPrint "Pocket was installed in $INSTDIR."
  Goto Done

  InstallFailed:
    SetOutPath "$TEMP"
    ${If} $SetupOwnsTarget == 1
      RMDir /r "$INSTDIR\app.new"
    ${EndIf}
    Call ReportSetupError
    SetErrorLevel 1
    Abort
  Done:
SectionEnd

Function .onInit
  ${If} ${IsNativeARM64}
    SectionSetSize ${PocketPayload} ${POCKET_ARM64_SIZE}
  ${ElseIf} ${IsNativeAMD64}
    SectionSetSize ${PocketPayload} ${POCKET_X64_SIZE}
  ${Else}
    MessageBox MB_OK|MB_ICONEXCLAMATION "Pocket requires a 64-bit Intel, AMD, or ARM PC." /SD IDOK
    SetErrorLevel 1
    Abort
  ${EndIf}
  SetShellVarContext current
  SetRegView 64
  !insertmacro LockPocket

  StrCpy $SetupLog "$TEMP\Pocket-Setup.log"
  ReadRegStr $PreviousRoot HKCU "${UNINSTALL_KEY}" "InstallLocation"
  ReadRegDWORD $HadDesktopShortcut HKCU "${UNINSTALL_KEY}" "DesktopShortcut"
  StrCpy $AddDesktopShortcut ${BST_UNCHECKED}
  ${If} $HadDesktopShortcut == 1
    StrCpy $AddDesktopShortcut ${BST_CHECKED}
  ${EndIf}
  StrCpy $StartAtSignIn ${BST_UNCHECKED}
  ReadRegStr $0 HKCU "${RUN_KEY}" "PocketLeft"
  ${If} $0 != ""
    StrCpy $StartAtSignIn ${BST_CHECKED}
  ${EndIf}

  ${GetParameters} $0
  ClearErrors
  ${GetOptions} $0 "/DESKTOP" $1
  ${IfNot} ${Errors}
    StrCpy $AddDesktopShortcut ${BST_CHECKED}
  ${EndIf}
  ClearErrors
  ${GetOptions} $0 "/STARTUP" $1
  ${IfNot} ${Errors}
    StrCpy $StartAtSignIn ${BST_CHECKED}
  ${EndIf}
  ClearErrors
FunctionEnd

Function CheckDirectoryPage
  GetInstDirError $0
  ${If} $0 == 2
    StrCpy $SetupError "The selected drive does not have enough space for the app files"
  ${ElseIf} $0 == 1
    StrCpy $SetupError "Select a valid installation folder on a local drive"
  ${Else}
    Call CheckTarget
  ${EndIf}
  ${If} $SetupError != ""
    Call ReportSetupError
    Abort
  ${EndIf}
FunctionEnd

Function CheckTarget
  StrCpy $SetupError ""
  StrCpy $MoveError "0"
  StrCpy $0 $INSTDIR 3
  StrCpy $1 $0 2 1
  ${If} $1 != ":\"
  ${OrIf} $INSTDIR == $0
    StrCpy $SetupError "Choose a folder on a local drive, such as D:\Apps\PocketLeft"
    Return
  ${EndIf}
  System::Call 'kernel32::GetDriveTypeW(w r0) i .r1'
  ${If} $1 != 2
  ${AndIf} $1 != 3
    StrCpy $SetupError "The selected drive is unavailable. Choose a connected SSD or HDD"
    Return
  ${EndIf}

  System::Call 'kernel32::GetFullPathNameW(w "$INSTDIR", i ${NSIS_MAX_STRLEN}, w .r1, p 0) i .r2'
  ${If} $2 == 0
  ${OrIf} $2 >= ${NSIS_MAX_STRLEN}
  ${OrIf} $1 == $0
    StrCpy $SetupError "Choose a valid installation folder inside the drive"
    Return
  ${EndIf}
  StrCpy $INSTDIR $1
  StrCpy $1 $INSTDIR 1 -1
  ${If} $1 == "\"
    StrCpy $INSTDIR $INSTDIR -1
  ${EndIf}
  ${If} $PreviousRoot != ""
  ${AndIf} $PreviousRoot != $INSTDIR
    StrLen $0 "$PreviousRoot\"
    StrCpy $1 "$INSTDIR\" $0
    StrLen $0 "$INSTDIR\"
    StrCpy $2 "$PreviousRoot\" $0
    ${If} $1 == "$PreviousRoot\"
    ${OrIf} $2 == "$INSTDIR\"
      StrCpy $SetupError "Choose a folder outside the existing Pocket installation"
      Return
    ${EndIf}
  ${EndIf}

  ${If} $INSTDIR != $PreviousRoot
  ${AndIf} $INSTDIR != "${DEFAULT_INSTALL_ROOT}"
  ${AndIfNot} ${FileExists} "$INSTDIR\${OWNER_MARKER}"
    ${If} ${FileExists} "$INSTDIR\app"
    ${OrIf} ${FileExists} "$INSTDIR\app.new"
    ${OrIf} ${FileExists} "$INSTDIR\app.previous"
    ${OrIf} ${FileExists} "$INSTDIR\Uninstall.exe"
      StrCpy $SetupError "That folder already contains files named app or Uninstall.exe. Choose a new PocketLeft subfolder"
      Return
    ${EndIf}
  ${EndIf}

  ClearErrors
  CreateDirectory "$INSTDIR"
  ${IfNot} ${Errors}
    GetTempFileName $0 "$INSTDIR"
  ${EndIf}
  ${If} ${Errors}
    StrCpy $SetupError "Windows would not let Setup write to this folder. Choose a folder you can write to"
    Return
  ${EndIf}
  Delete "$0"
FunctionEnd

Function ShowOptions
  !insertmacro MUI_HEADER_TEXT "Installation options" "Choose how Pocket appears in Windows."
  nsDialogs::Create 1018
  Pop $0
  ${If} $0 == error
    Abort
  ${EndIf}
  ${NSD_CreateCheckbox} 0 0 100% 14u "Create a desktop shortcut"
  Pop $DesktopCheckbox
  ${NSD_SetState} $DesktopCheckbox $AddDesktopShortcut
  ${NSD_CreateCheckbox} 0 23u 100% 14u "Start Pocket at sign-in"
  Pop $SignInCheckbox
  ${NSD_SetState} $SignInCheckbox $StartAtSignIn
  nsDialogs::Show
FunctionEnd

Function SaveOptions
  ${NSD_GetState} $DesktopCheckbox $AddDesktopShortcut
  ${NSD_GetState} $SignInCheckbox $StartAtSignIn
FunctionEnd

Function MoveFolder
  StrCpy $0 6
  RetryMove:
    System::Call 'kernel32::MoveFileExW(w "$MoveFrom", w "$MoveTo", i 0) i .r1 ?e'
    Pop $MoveError
    ${If} $1 != 0
      StrCpy $MoveError "0"
      ClearErrors
      Return
    ${EndIf}
    IntOp $0 $0 - 1
    ${If} $0 > 0
      ${If} $MoveError == 5
      ${OrIf} $MoveError == 32
      ${OrIf} $MoveError == 33
        Sleep 350
        Goto RetryMove
      ${EndIf}
    ${EndIf}
    SetErrors
FunctionEnd

Function SaveSetupError
  StrCpy $1 "$SetupError.$\r$\n$\r$\nInstallation folder: $INSTDIR"
  ${If} $MoveError != ""
  ${AndIf} $MoveError != 0
    StrCpy $1 "$1$\r$\nWindows file error: $MoveError"
  ${EndIf}
  ClearErrors
  FileOpen $0 "$SetupLog" w
  ${IfNot} ${Errors}
    FileWriteUTF16LE /BOM $0 "Pocket Setup ${SETUP_VERSION}$\r$\n$1$\r$\n"
    FileClose $0
    StrCpy $1 "$1$\r$\n$\r$\nLog: $SetupLog"
  ${EndIf}
  DetailPrint "$SetupError ($INSTDIR)"
FunctionEnd

Function ReportSetupError
  Call SaveSetupError
  MessageBox MB_OK|MB_ICONEXCLAMATION "$1" /SD IDOK
FunctionEnd

Function .onInstFailed
  ${If} $SetupError != ""
    Call SaveSetupError
  ${EndIf}
FunctionEnd

Function LaunchPocket
  StrCpy $0 $PocketMutex
  System::Call 'kernel32::ReleaseMutex(p r0)'
  System::Call 'kernel32::CloseHandle(p r0)'
  ExecShell "open" "$INSTDIR\app\Pocket.exe"
FunctionEnd

Function un.onInit
  SetShellVarContext current
  SetRegView 64
  ReadRegStr $0 HKCU "${UNINSTALL_KEY}" "InstallLocation"
  ${If} $0 == ""
  ${OrIf} $0 != $INSTDIR
    MessageBox MB_OK|MB_ICONEXCLAMATION "Open Windows Settings, then go to Apps and Installed apps to remove the registered copy of Pocket." /SD IDOK
    SetErrorLevel 1
    Abort
  ${EndIf}
  !insertmacro LockPocket
FunctionEnd

Section "Uninstall"
  SetOutPath "$TEMP"
  ClearErrors
  ${If} ${FileExists} "$INSTDIR\app\*"
    RMDir /r "$INSTDIR\app"
    ${If} ${Errors}
      MessageBox MB_OK|MB_ICONEXCLAMATION "Windows could not remove Pocket from $INSTDIR. Close Pocket and try again." /SD IDOK
      SetErrorLevel 1
      Abort
    ${EndIf}
  ${EndIf}
  ReadRegDWORD $0 HKCU "${UNINSTALL_KEY}" "DesktopShortcut"
  ${If} $0 == 1
    Delete "$DESKTOP\Pocket.lnk"
  ${EndIf}
  Delete "$SMPROGRAMS\Pocket.lnk"
  ReadRegStr $0 HKCU "${RUN_KEY}" "PocketLeft"
  ${If} $0 == '$\"$INSTDIR\app\Pocket.exe$\" --background'
    DeleteRegValue HKCU "${RUN_KEY}" "PocketLeft"
  ${EndIf}
  DeleteRegKey HKCU "${UNINSTALL_KEY}"
  !insertmacro RemoveOwnedFiles "$INSTDIR"
SectionEnd
