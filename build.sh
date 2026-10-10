#!/usr/bin/env bash
# Construit AEROX PC Care : le zip (mises à jour automatiques) et l'installateur Windows.
# Prérequis (Linux) : mono-devel (mcs), nsis, zip, python3.   Usage : ./build.sh
set -euo pipefail
cd "$(dirname "$0")"

VER=$(sed -n "s/^\$AppVersion = '\([0-9.]*\)'.*/\1/p" src/1_head.ps1)
[ -n "$VER" ] || { echo "Version introuvable dans src/1_head.ps1"; exit 1; }
echo "== AEROX PC Care $VER"
OUT="build/AEROX PC Care"
rm -rf build && mkdir -p "$OUT"

# Numéro de version commun aux deux programmes
printf 'using System.Reflection;\n[assembly: AssemblyVersion("%s.0")]\n[assembly: AssemblyFileVersion("%s.0")]\n' "$VER" "$VER" > build/Version.cs

MCS="mcs -langversion:5 -sdk:4.5 -optimize+ -nologo"
$MCS -target:library -out:"$OUT/AeroxPCCare.Native.dll" \
     -r:System.Windows.Forms.dll -r:System.IO.Compression.dll -r:System.IO.Compression.FileSystem.dll -r:System.Xml.dll \
     native/AeroxNative.cs build/Version.cs
$MCS -target:winexe -platform:anycpu -win32icon:launcher/aerox.ico -out:"$OUT/AeroxPCCare.exe" \
     -r:System.Windows.Forms.dll -r:System.Drawing.dll launcher/Launcher.cs build/Version.cs

# Script : les 4 parties assemblées, en UTF-8 avec BOM et fins de ligne Windows (obligatoire pour PowerShell 5.1)
python3 - "$OUT/AeroxPCCare.ps1" src/1_head.ps1 src/1b_native.ps1 src/2_lib.ps1 src/3_ui.ps1 <<'PY'
import sys
out, parts = sys.argv[1], sys.argv[2:]
text = ''.join(open(p, encoding='utf-8-sig').read().replace('\r\n', '\n') for p in parts)
open(out, 'w', encoding='utf-8-sig', newline='\r\n').write(text)
PY

cp launcher/aerox.ico "$OUT/"
python3 -c "import sys; t=open('docs/LISEZMOI.txt',encoding='utf-8-sig').read().replace('\r\n','\n'); open(sys.argv[1],'w',encoding='utf-8-sig',newline='\r\n').write(t)" "$OUT/LISEZMOI.txt"

(cd build && zip -qr "AeroxPCCare_v$VER.zip" "AEROX PC Care")
# Version portable (clé USB) : le même dossier + « portable.txt », qui garde réglages et journaux sur la clé
PORT="build/portable/AEROX PC Care (portable)"
rm -rf build/portable && mkdir -p build/portable && cp -r "$OUT" "$PORT"
printf '%s\r\n' "Version portable d'AEROX PC Care : ne supprime pas ce fichier." \
  "Tant qu'il est là, AEROX ne s'installe pas sur le PC : réglages, journaux et historique restent sur la clé," \
  "dans le dossier « donnees » (un sous-dossier par PC)." > "$PORT/portable.txt"
rm -f build/AeroxPCCare_Portable.zip
(cd build/portable && zip -qr ../AeroxPCCare_Portable.zip "AEROX PC Care (portable)")
makensis -V2 -DVERSION="$VER" -DSRC="$PWD/$OUT" -DOUTFILE="$PWD/build/AeroxPCCare_Setup.exe" installer/AeroxPCCare.nsi
echo "== Terminé :"
ls -la build/*.zip build/*.exe
