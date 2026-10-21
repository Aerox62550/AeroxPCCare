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
!define TASKNAME  "AEROX PC Care (mode discret)"

Name "${APPNAME}"
OutFile "${OUTFILE}"
; Dossier d'installation IMPOSÉ (pas de page de choix, /D= ignoré, voir .onInit) : Program Files, que seuls les
; administrateurs peuvent modifier. AEROX est lancé avec les droits admin (et peut l'être à chaque démarrage de Windows) :
; dans un dossier libre, n'importe quel programme du compte pourrait remplacer le lanceur et se faire exécuter en administrateur.
InstallDir "$PROGRAMFILES64\AeroxPCCare"
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
!define MUI_WELCOMEPAGE_TEXT "${APPNAME} analyse ton PC, t'explique chaque problème et le répare en un clic : nettoyage, mises à jour, réparations, performances, températures et FPS.$\r$\n$\r$\nRien n'est modifié sur ton PC sans ton accord.$\r$\n$\r$\nIl s'installe dans le dossier protégé de Windows (Program Files) : personne d'autre que toi ne peut le modifier.$\r$\n$\r$\nClique sur Suivant pour continuer."
!define MUI_FINISHPAGE_RUN "$INSTDIR\${EXENAME}"
!define MUI_FINISHPAGE_RUN_TEXT "Lancer ${APPNAME}"
!define MUI_FINISHPAGE_SHOWREADME "$INSTDIR\LISEZMOI.txt"
!define MUI_FINISHPAGE_SHOWREADME_TEXT "Lire le mode d'emploi"
!define MUI_FINISHPAGE_SHOWREADME_NOTCHECKED

; Mode mise à jour (/UPDATE, lancé par le logiciel) : pas de questions, juste la barre de progression,
; puis le logiciel se relance tout seul.
Var IsUpdate
; Dossier d'une installation précédente faite ailleurs que dans Program Files (ancien choix libre) : reprise en fin d'installation
Var OldDir
Function SkipIfUpdate
  ${If} $IsUpdate == 1
    Abort
  ${EndIf}
FunctionEnd

!define MUI_PAGE_CUSTOMFUNCTION_PRE SkipIfUpdate
!insertmacro MUI_PAGE_WELCOME
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
      MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION "${APPNAME} est ouvert.$\r$\n$\r$\nFerme-le, puis clique sur Réessayer.$\r$\n(S'il est caché près de l'horloge : clic droit sur son icône > Quitter.)" /SD IDCANCEL IDRETRY retry
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
      MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION "${APPNAME} est ouvert.$\r$\n$\r$\nFerme-le, puis clique sur Réessayer.$\r$\n(S'il est caché près de l'horloge : clic droit sur son icône > Quitter.)" /SD IDCANCEL IDRETRY retry
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
  ; Dossier imposé : Program Files, quoi qu'il y ait dans la ligne de commande (/D=…) ou dans une installation précédente
  StrCpy $INSTDIR "$PROGRAMFILES64\AeroxPCCare"
  ; Installation précédente dans un autre dossier (les versions d'avant laissaient choisir) : ses fichiers sont repris en fin d'installation
  StrCpy $OldDir ""
  ReadRegStr $R2 HKLM "${UNINSTKEY}" "Dossier"
  ${If} $R2 == ""
    ReadRegStr $R2 HKLM "${UNINSTKEY}" "InstallLocation"
  ${EndIf}
  ; sans « \ » final
  StrCpy $R3 $R2 1 -1
  ${If} $R3 == "\"
    StrCpy $R2 $R2 -1
  ${EndIf}
  ; Jamais le dossier d'installation actuel ni l'un de ses dossiers parents (sinon on effacerait ce qu'on vient d'installer).
  ; Comparaison sans tenir compte des majuscules : « $INSTDIR\ » commence-t-il par « $R2\ » ? (Une dernière vérification, sur le
  ; disque, est faite avant tout nettoyage : voir la section d'installation.)
  ${If} $R2 != ""
    StrLen $R4 "$R2\"
    StrCpy $R3 "$INSTDIR\" $R4
    ${If} $R3 != "$R2\"
      StrCpy $OldDir $R2
    ${EndIf}
  ${EndIf}
FunctionEnd

; Mise à jour automatique ratée : on relance quand même le logiciel (ancienne version) pour ne pas laisser l'utilisateur sans rien
Function .onInstFailed
  ${If} $IsUpdate == 1
    ${If} ${FileExists} "$INSTDIR\${EXENAME}"
      Exec '"$INSTDIR\${EXENAME}"'
    ${ElseIf} $OldDir != ""
    ${AndIf} ${FileExists} "$OldDir\${EXENAME}"
      Exec '"$OldDir\${EXENAME}"'
    ${EndIf}
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
    MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION "Windows ou ton antivirus empêche de copier les fichiers d'${APPNAME} dans :$\r$\n$INSTDIR$\r$\n$\r$\nCe qu'il faut faire :$\r$\n1. Ouvre ton antivirus, va dans la Quarantaine et restaure (ou supprime) les éléments « AEROX ».$\r$\n2. Ajoute ce dossier aux exceptions de l'antivirus.$\r$\n3. Clique sur Réessayer." /SD IDCANCEL IDRETRY copie
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

  ; Installation précédente faite dans un autre dossier (les versions d'avant laissaient choisir) : on retire UNIQUEMENT les
  ; fichiers d'AEROX qui y étaient (jamais le dossier entier : la personne y gardait peut-être autre chose). Le dossier est
  ; supprimé seulement s'il est devenu vide. Les copies installées ci-dessus sont déjà en place, donc rien n'est perdu si ça échoue.
  ; Vérification sur le disque : un fichier-témoin posé dans le nouveau dossier ne doit PAS apparaître dans l'ancien. S'il y apparaît,
  ; c'est le même dossier écrit autrement (nom court 8.3, lien, majuscules…) : on n'y touche surtout pas.
  ${If} $OldDir != ""
    FileOpen $R5 "$INSTDIR\.aerox-temoin" w
    FileClose $R5
    ${If} ${FileExists} "$OldDir\.aerox-temoin"
      StrCpy $OldDir ""
    ${EndIf}
    Delete "$INSTDIR\.aerox-temoin"
  ${EndIf}
  ${If} $OldDir != ""
    Delete /REBOOTOK "$OldDir\${EXENAME}"
    Delete /REBOOTOK "$OldDir\${OLDEXE}"
    Delete /REBOOTOK "$OldDir\AeroxPCCare.ps1"
    Delete /REBOOTOK "$OldDir\AeroxPCCare.Native.dll"
    Delete /REBOOTOK "$OldDir\aerox.ico"
    Delete /REBOOTOK "$OldDir\LISEZMOI.txt"
    Delete /REBOOTOK "$OldDir\Desinstaller.exe"
    Delete "$OldDir\maj\AeroxPCCare_Setup_*.exe"
    RMDir "$OldDir\maj"
    RMDir "$OldDir"
  ${EndIf}

  ; Lancement avec Windows (mode discret) : si la tâche existe, elle doit viser le logiciel installé ICI (jamais l'ancien
  ; dossier). Si Windows refuse de la modifier, on la supprime : la personne la réactive en un clic dans Gaming.
  nsExec::Exec 'schtasks.exe /Query /TN "${TASKNAME}"'
  Pop $0
  ${If} $0 == 0
    nsExec::Exec 'schtasks.exe /Change /TN "${TASKNAME}" /TR "\"$INSTDIR\${EXENAME}\" --discret"'
    Pop $0
    ${If} $0 != 0
      nsExec::Exec 'schtasks.exe /Delete /TN "${TASKNAME}" /F'
      Pop $0
    ${EndIf}
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
  ; Dossier protégé : outils téléchargés (températures, FPS, débit), installateurs de mise à jour, raccourcis temporaires.
  ; Les données (réglages, historique, bilans : protege\donnees) et leurs sceaux restent, sauf si la personne choisit de les supprimer.
  RMDir /r "$PROGRAMFILES64\AeroxPCCare\protege\outils"
  RMDir /r "$PROGRAMFILES64\AeroxPCCare\protege\maj"
  RMDir /r "$PROGRAMFILES64\AeroxPCCare\protege\session"
  RMDir /r "$PROGRAMFILES64\AeroxPCCare\protege\module"
  DeleteRegKey HKLM "${UNINSTKEY}"
  ; Lancement avec Windows en mode discret (option de l'onglet Gaming)
  nsExec::Exec 'schtasks.exe /Delete /TN "${TASKNAME}" /F'
  Pop $0

  ; Journaux, réglages et outils téléchargés (températures, FPS) : au choix
  SetShellVarContext current
  IfSilent done
  MessageBox MB_YESNO|MB_ICONQUESTION "Supprimer aussi tes réglages, tes journaux, ton historique et tes bilans ?" IDNO done
    RMDir /r "$PROGRAMFILES64\AeroxPCCare\protege"
    RMDir /r "$INSTDIR\protege"
    RMDir /r "$LOCALAPPDATA\AeroxPCCare"
  done:
  RMDir "$INSTDIR"
SectionEnd
