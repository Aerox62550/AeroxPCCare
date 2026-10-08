; AEROX PC Care - installateur Windows (NSIS 3)
; Compilé par build.sh :  makensis -DVERSION=1.0.0 -DSRC=<dossier du logiciel> -DOUTFILE=<setup.exe> installer/AeroxPCCare.nsi

Unicode true
SetCompressor /SOLID lzma
ManifestDPIAware true
RequestExecutionLevel admin

!ifndef VERSION
  !define VERSION "1.0.0"
!endif
!ifndef SRC
  !define SRC "..\build\AEROX PC Care"
!endif
!ifndef OUTFILE
  !define OUTFILE "AeroxPCCare_Setup_v${VERSION}.exe"
!endif

!define APPNAME   "AEROX PC Care"
!define EXENAME   "AEROX PC Care.exe"
!define PUBLISHER "AEROX"
!define WEBSITE   "https://github.com/Aerox62550/AeroxPCCare"
!define UNINSTKEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\AeroxPCCare"

Name "${APPNAME}"
OutFile "${OUTFILE}"
InstallDir "$PROGRAMFILES64\${APPNAME}"
InstallDirRegKey HKLM "${UNINSTKEY}" "InstallLocation"
BrandingText "${APPNAME} ${VERSION}"

VIProductVersion "${VERSION}.0"
VIAddVersionKey /LANG=1036 "ProductName" "${APPNAME}"
VIAddVersionKey /LANG=1036 "ProductVersion" "${VERSION}"
VIAddVersionKey /LANG=1036 "FileVersion" "${VERSION}"
VIAddVersionKey /LANG=1036 "FileDescription" "Installation de ${APPNAME}"
VIAddVersionKey /LANG=1036 "CompanyName" "${PUBLISHER}"
VIAddVersionKey /LANG=1036 "LegalCopyright" "${PUBLISHER}"

!include "MUI2.nsh"
!include "x64.nsh"
!include "LogicLib.nsh"
!include "StrFunc.nsh"
${StrStr}
${UnStrStr}

!define MUI_ICON   "${SRC}\aerox.ico"
!define MUI_UNICON "${SRC}\aerox.ico"
!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TITLE "Bienvenue dans l'installation d'${APPNAME} ${VERSION}"
!define MUI_WELCOMEPAGE_TEXT "${APPNAME} analyse ton PC, t'explique chaque problème et le répare en un clic : nettoyage, mises à jour, réparations, performances, températures et FPS.$\r$\n$\r$\nRien n'est modifié sur ton PC sans ton accord.$\r$\n$\r$\nClique sur Suivant pour continuer."
!define MUI_FINISHPAGE_RUN "$INSTDIR\${EXENAME}"
!define MUI_FINISHPAGE_RUN_TEXT "Lancer ${APPNAME}"
!define MUI_FINISHPAGE_SHOWREADME "$INSTDIR\LISEZMOI.txt"
!define MUI_FINISHPAGE_SHOWREADME_TEXT "Lire le mode d'emploi"
!define MUI_FINISHPAGE_SHOWREADME_NOTCHECKED

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "French"

; ------------------------------------------------------------------ Logiciel ouvert ?
Function CheckRunning
  retry:
    nsExec::ExecToStack 'tasklist /FI "IMAGENAME eq ${EXENAME}" /NH'
    Pop $0
    Pop $1
    ${StrStr} $2 $1 "${EXENAME}"
    ${If} $2 != ""
      MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION "${APPNAME} est ouvert.$\r$\n$\r$\nFerme-le, puis clique sur Réessayer." IDRETRY retry
      Abort
    ${EndIf}
FunctionEnd

Function un.CheckRunning
  retry:
    nsExec::ExecToStack 'tasklist /FI "IMAGENAME eq ${EXENAME}" /NH'
    Pop $0
    Pop $1
    ${UnStrStr} $2 $1 "${EXENAME}"
    ${If} $2 != ""
      MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION "${APPNAME} est ouvert.$\r$\n$\r$\nFerme-le, puis clique sur Réessayer." IDRETRY retry
      Abort
    ${EndIf}
FunctionEnd

Function .onInit
  ${IfNot} ${RunningX64}
    MessageBox MB_YESNO|MB_ICONEXCLAMATION "Ce PC fonctionne en 32 bits. ${APPNAME} marchera, mais sans les températures.$\r$\n$\r$\nContinuer quand même ?" IDYES +2
    Abort
  ${EndIf}
  SetRegView 64
FunctionEnd

Function un.onInit
  SetRegView 64
FunctionEnd

; ------------------------------------------------------------------ Installation
Section "Installer"
  Call CheckRunning
  SetShellVarContext all
  SetOutPath "$INSTDIR"
  SetOverwrite on
  File "${SRC}\${EXENAME}"
  File "${SRC}\AeroxPCCare.ps1"
  File "${SRC}\AeroxPCCare.Native.dll"
  File "${SRC}\aerox.ico"
  File "${SRC}\LISEZMOI.txt"

  WriteUninstaller "$INSTDIR\Desinstaller.exe"

  CreateShortCut "$DESKTOP\${APPNAME}.lnk" "$INSTDIR\${EXENAME}" "" "$INSTDIR\aerox.ico" 0
  CreateShortCut "$SMPROGRAMS\${APPNAME}.lnk" "$INSTDIR\${EXENAME}" "" "$INSTDIR\aerox.ico" 0

  WriteRegStr   HKLM "${UNINSTKEY}" "DisplayName"          "${APPNAME}"
  WriteRegStr   HKLM "${UNINSTKEY}" "DisplayVersion"       "${VERSION}"
  WriteRegStr   HKLM "${UNINSTKEY}" "Publisher"            "${PUBLISHER}"
  WriteRegStr   HKLM "${UNINSTKEY}" "DisplayIcon"          "$INSTDIR\aerox.ico"
  WriteRegStr   HKLM "${UNINSTKEY}" "InstallLocation"      "$INSTDIR"
  WriteRegStr   HKLM "${UNINSTKEY}" "UninstallString"      '"$INSTDIR\Desinstaller.exe"'
  WriteRegStr   HKLM "${UNINSTKEY}" "QuietUninstallString" '"$INSTDIR\Desinstaller.exe" /S'
  WriteRegStr   HKLM "${UNINSTKEY}" "URLInfoAbout"         "${WEBSITE}"
  WriteRegStr   HKLM "${UNINSTKEY}" "HelpLink"             "${WEBSITE}/issues"
  WriteRegDWORD HKLM "${UNINSTKEY}" "NoModify" 1
  WriteRegDWORD HKLM "${UNINSTKEY}" "NoRepair" 1
  WriteRegDWORD HKLM "${UNINSTKEY}" "EstimatedSize" 600
SectionEnd

; ------------------------------------------------------------------ Désinstallation
Section "Uninstall"
  Call un.CheckRunning
  SetShellVarContext all
  Delete "$DESKTOP\${APPNAME}.lnk"
  Delete "$SMPROGRAMS\${APPNAME}.lnk"
  Delete "$INSTDIR\${EXENAME}"
  Delete "$INSTDIR\AeroxPCCare.ps1"
  Delete "$INSTDIR\AeroxPCCare.Native.dll"
  Delete "$INSTDIR\aerox.ico"
  Delete "$INSTDIR\LISEZMOI.txt"
  Delete "$INSTDIR\Desinstaller.exe"
  ; Fichiers ajoutés par les mises à jour automatiques : seulement si c'est bien le dossier du logiciel
  ${UnStrStr} $0 "$INSTDIR" "${APPNAME}"
  ${If} $0 != ""
    RMDir /r "$INSTDIR"
  ${Else}
    RMDir "$INSTDIR"
  ${EndIf}
  DeleteRegKey HKLM "${UNINSTKEY}"

  ; Journaux, réglages et outils téléchargés (températures, FPS) : au choix
  SetShellVarContext current
  IfSilent done
  MessageBox MB_YESNO|MB_ICONQUESTION "Supprimer aussi tes réglages, tes journaux et les outils téléchargés (températures, FPS) ?$\r$\n$\r$\n(Dossier $LOCALAPPDATA\AeroxPCCare)" IDNO done
    RMDir /r "$LOCALAPPDATA\AeroxPCCare"
  done:
SectionEnd
