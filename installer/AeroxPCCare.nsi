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
!define EXENAME   "AeroxPCCare.exe"
!define OLDEXE    "AEROX PC Care.exe"
!define PUBLISHER "AEROX"
!define WEBSITE   "https://github.com/Aerox62550/AeroxPCCare"
!define UNINSTKEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\AeroxPCCare"

Name "${APPNAME}"
OutFile "${OUTFILE}"
InstallDir "$PROGRAMFILES64\AeroxPCCare"
; Le dossier choisi lors d'une installation précédente est relu dans .onInit (registre 64 bits)
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
!include "FileFunc.nsh"
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

; Mode mise à jour (/UPDATE, lancé par le logiciel) : pas de questions, juste la barre de progression,
; puis le logiciel se relance tout seul.
Var IsUpdate
Function SkipIfUpdate
  ${If} $IsUpdate == 1
    Abort
  ${EndIf}
FunctionEnd

!define MUI_PAGE_CUSTOMFUNCTION_PRE SkipIfUpdate
!insertmacro MUI_PAGE_WELCOME
!define MUI_PAGE_CUSTOMFUNCTION_PRE SkipIfUpdate
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_PAGE_CUSTOMFUNCTION_PRE SkipIfUpdate
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "French"

; ------------------------------------------------------------------ Logiciel ouvert ?
; Le logiciel est-il ouvert ? (noms exacts : l'installateur lui-même s'appelle aussi « AeroxPCCare_Setup… »)

Function CheckRunning
  StrCpy $3 0
  retry:
    StrCpy $2 ""
    nsExec::ExecToStack 'tasklist /FI "IMAGENAME eq ${EXENAME}" /NH'
    Pop $0
    Pop $1
    ${StrStr} $2 $1 "${EXENAME}"
    ${If} $2 == ""
      nsExec::ExecToStack 'tasklist /FI "IMAGENAME eq ${OLDEXE}" /NH'
      Pop $0
      Pop $1
      ${StrStr} $2 $1 "${OLDEXE}"
    ${EndIf}
    ${If} $2 != ""
    ${AndIf} $IsUpdate == 1
    ${AndIf} $3 < 15
      IntOp $3 $3 + 1
      Sleep 1000
      Goto retry
    ${EndIf}
    ${If} $2 != ""
      MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION "${APPNAME} est ouvert.$\r$\n$\r$\nFerme-le, puis clique sur Réessayer." /SD IDCANCEL IDRETRY retry
      Abort
    ${EndIf}
FunctionEnd

Function un.CheckRunning
  retry:
    StrCpy $2 ""
    nsExec::ExecToStack 'tasklist /FI "IMAGENAME eq ${EXENAME}" /NH'
    Pop $0
    Pop $1
    ${UnStrStr} $2 $1 "${EXENAME}"
    ${If} $2 == ""
      nsExec::ExecToStack 'tasklist /FI "IMAGENAME eq ${OLDEXE}" /NH'
      Pop $0
      Pop $1
      ${UnStrStr} $2 $1 "${OLDEXE}"
    ${EndIf}
    ${If} $2 != ""
      MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION "${APPNAME} est ouvert.$\r$\n$\r$\nFerme-le, puis clique sur Réessayer." /SD IDCANCEL IDRETRY retry
      Abort
    ${EndIf}
FunctionEnd

Function .onInit
  StrCpy $IsUpdate 0
  ${GetParameters} $R0
  ClearErrors
  ${GetOptions} $R0 "/UPDATE" $R1
  ${IfNot} ${Errors}
    StrCpy $IsUpdate 1
  ${EndIf}
  ${IfNot} ${RunningX64}
    MessageBox MB_YESNO|MB_ICONEXCLAMATION "Ce PC fonctionne en 32 bits. ${APPNAME} marchera, mais sans les températures.$\r$\n$\r$\nContinuer quand même ?" /SD IDYES IDYES +2
    Abort
  ${EndIf}
  SetRegView 64
  ; Mise à jour / réinstallation : on garde le dossier déjà utilisé (sauf si /D= est donné)
  ${If} "$INSTDIR" == "$PROGRAMFILES64\AeroxPCCare"
    ReadRegStr $R2 HKLM "${UNINSTKEY}" "Dossier"
    ${If} $R2 != ""
    ${AndIf} ${FileExists} "$R2\*.*"
      StrCpy $INSTDIR $R2
    ${EndIf}
  ${EndIf}
FunctionEnd

; Mise à jour automatique ratée : on relance quand même le logiciel (ancienne version) pour ne pas laisser l'utilisateur sans rien
Function .onInstFailed
  ${If} $IsUpdate == 1
  ${AndIf} ${FileExists} "$INSTDIR\${EXENAME}"
    Exec '"$INSTDIR\${EXENAME}"'
  ${EndIf}
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
  copie:
  ClearErrors
  File /nonfatal "${SRC}\${EXENAME}"
  File /nonfatal "${SRC}\AeroxPCCare.ps1"
  File /nonfatal "${SRC}\AeroxPCCare.Native.dll"
  File /nonfatal "${SRC}\aerox.ico"
  File /nonfatal "${SRC}\LISEZMOI.txt"
  ${If} ${Errors}
    MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION "Windows ou ton antivirus empêche de copier les fichiers d'${APPNAME} dans :$\r$\n$INSTDIR$\r$\n$\r$\nCe qu'il faut faire :$\r$\n1. Ouvre ton antivirus, va dans la Quarantaine et restaure (ou supprime) les éléments « AEROX ».$\r$\n2. Ajoute ce dossier aux exceptions de l'antivirus.$\r$\n3. Clique sur Réessayer.$\r$\n$\r$\nTu peux aussi Annuler et relancer l'installation en choisissant un autre dossier." /SD IDCANCEL IDRETRY copie
    Abort "Installation annulée : les fichiers n'ont pas pu être copiés."
  ${EndIf}

  ; Ancien emplacement (versions 1.0.0 à 1.0.2) : on fait le ménage
  ${StrStr} $0 "$INSTDIR" "$PROGRAMFILES64\${APPNAME}"
  ${If} $0 == ""
    ; Fichiers des versions 1.0.0 à 1.0.2 (supprimés au redémarrage s'ils sont bloqués)
    Delete /REBOOTOK "$PROGRAMFILES64\${APPNAME}\${OLDEXE}"
    Delete /REBOOTOK "$PROGRAMFILES64\${APPNAME}\AeroxPCCare.ps1"
    Delete /REBOOTOK "$PROGRAMFILES64\${APPNAME}\AeroxPCCare.Native.dll"
    Delete /REBOOTOK "$PROGRAMFILES64\${APPNAME}\aerox.ico"
    Delete /REBOOTOK "$PROGRAMFILES64\${APPNAME}\LISEZMOI.txt"
    Delete /REBOOTOK "$PROGRAMFILES64\${APPNAME}\Desinstaller.exe"
    RMDir /r /REBOOTOK "$PROGRAMFILES64\${APPNAME}"
  ${EndIf}

  WriteUninstaller "$INSTDIR\Desinstaller.exe"

  CreateShortCut "$DESKTOP\${APPNAME}.lnk" "$INSTDIR\${EXENAME}" "" "$INSTDIR\aerox.ico" 0
  CreateShortCut "$SMPROGRAMS\${APPNAME}.lnk" "$INSTDIR\${EXENAME}" "" "$INSTDIR\aerox.ico" 0

  WriteRegStr   HKLM "${UNINSTKEY}" "DisplayName"          "${APPNAME}"
  WriteRegStr   HKLM "${UNINSTKEY}" "DisplayVersion"       "${VERSION}"
  WriteRegStr   HKLM "${UNINSTKEY}" "Publisher"            "${PUBLISHER}"
  WriteRegStr   HKLM "${UNINSTKEY}" "DisplayIcon"          "$INSTDIR\aerox.ico"
  WriteRegStr   HKLM "${UNINSTKEY}" "InstallLocation"      "$INSTDIR"
  WriteRegStr   HKLM "${UNINSTKEY}" "Dossier"              "$INSTDIR"
  WriteRegStr   HKLM "${UNINSTKEY}" "UninstallString"      '"$INSTDIR\Desinstaller.exe"'
  WriteRegStr   HKLM "${UNINSTKEY}" "QuietUninstallString" '"$INSTDIR\Desinstaller.exe" /S'
  WriteRegStr   HKLM "${UNINSTKEY}" "URLInfoAbout"         "${WEBSITE}"
  WriteRegStr   HKLM "${UNINSTKEY}" "HelpLink"             "${WEBSITE}/issues"
  WriteRegDWORD HKLM "${UNINSTKEY}" "NoModify" 1
  WriteRegDWORD HKLM "${UNINSTKEY}" "NoRepair" 1
  WriteRegDWORD HKLM "${UNINSTKEY}" "EstimatedSize" 600

  ${If} $IsUpdate == 1
    SetAutoClose true
    Exec '"$INSTDIR\${EXENAME}"'
  ${EndIf}
SectionEnd

; ------------------------------------------------------------------ Désinstallation
Section "Uninstall"
  Call un.CheckRunning
  SetShellVarContext all
  Delete "$DESKTOP\${APPNAME}.lnk"
  Delete "$SMPROGRAMS\${APPNAME}.lnk"
  Delete "$INSTDIR\${EXENAME}"
  Delete "$INSTDIR\${OLDEXE}"
  Delete "$INSTDIR\AeroxPCCare.ps1"
  Delete "$INSTDIR\AeroxPCCare.Native.dll"
  Delete "$INSTDIR\aerox.ico"
  Delete "$INSTDIR\LISEZMOI.txt"
  Delete "$INSTDIR\Desinstaller.exe"
  ; Uniquement les fichiers du logiciel (jamais un dossier entier choisi par l'utilisateur)
  Delete "$INSTDIR\maj\AeroxPCCare_Setup_*.exe"
  RMDir "$INSTDIR\maj"
  RMDir "$INSTDIR"
  DeleteRegKey HKLM "${UNINSTKEY}"

  ; Journaux, réglages et outils téléchargés (températures, FPS) : au choix
  SetShellVarContext current
  IfSilent done
  MessageBox MB_YESNO|MB_ICONQUESTION "Supprimer aussi tes réglages, tes journaux et les outils téléchargés (températures, FPS) ?$\r$\n$\r$\n(Dossier $LOCALAPPDATA\AeroxPCCare)" IDNO done
    RMDir /r "$LOCALAPPDATA\AeroxPCCare"
  done:
SectionEnd
