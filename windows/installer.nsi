; VentAI NSIS Installer Script
; Creates: VentAI-Setup-1.0.1.exe
; Updated: AES-256 encrypted build with secure logging

!include "MUI2.nsh"
!include "x64.nsh"

; Basic Settings
Name "VentAI"
OutFile "VentAI-Setup-1.0.1.exe"
InstallDir "$PROGRAMFILES\VentAI"
InstallDirRegKey HKCU "Software\VentAI" "InstallDir"

; Require admin for installation
RequestExecutionLevel admin

; UI Settings
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_LANGUAGE "English"

; Install Section
Section "Install"
  SetOutPath "$INSTDIR"

  ; Copy all files from Release folder
  File /r "${BUILT_DIR}\*.*"

  ; Create Start Menu shortcuts
  CreateDirectory "$SMPROGRAMS\VentAI"
  CreateShortcut "$SMPROGRAMS\VentAI\VentAI.lnk" "$INSTDIR\vent_ai.exe"
  CreateShortcut "$SMPROGRAMS\VentAI\Uninstall.lnk" "$INSTDIR\Uninstall.exe"

  ; Create Desktop shortcut
  CreateShortcut "$DESKTOP\VentAI.lnk" "$INSTDIR\vent_ai.exe"

  ; Store install folder in registry
  WriteRegStr HKCU "Software\VentAI" "InstallDir" "$INSTDIR"

  ; Write uninstall info
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\VentAI" \
    "DisplayName" "VentAI - Privacy-First Emotional Support"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\VentAI" \
    "UninstallString" "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\VentAI" \
    "DisplayIcon" "$INSTDIR\vent_ai.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\VentAI" \
    "Publisher" "Srinjoy Goswami & Resolveera"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\VentAI" \
    "DisplayVersion" "1.0.1"
SectionEnd

; Uninstall Section
Section "Uninstall"
  ; Remove files
  RMDir /r "$INSTDIR"

  ; Remove shortcuts
  RMDir /r "$SMPROGRAMS\VentAI"
  Delete "$DESKTOP\VentAI.lnk"

  ; Remove registry entries
  DeleteRegKey HKCU "Software\VentAI"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\VentAI"
SectionEnd
