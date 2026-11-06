#!/usr/bin/env bash
# test-install-skills.sh : install-skills.sh sur un faux poste (HOME temporaire) et un faux depot.
# Regle attendue : seule une version deja publiee est remplacee ; une edition, un fichier non
# publie ou un skill perso du meme nom restent intacts. Aucune bibliotheque du mainteneur requise.
# Usage : bash ci/tests/test-install-skills.sh   (exit 0 = tout vert, 1 = echec, 2 = banc casse)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
SCRIPT="$REPO/install-skills.sh"
ROOT="$(mktemp -d)" || { echo "ABORT : dossier temporaire impossible"; exit 2; }
trap 'rm -rf "$ROOT"' EXIT
PASSED=0; FAILED=0
# Sentinelle : un banc qui saute des cas ne doit pas passer pour vert.
EXPECTED=66

abort() { echo "ABORT (banc casse) : $*"; exit 2; }
ok()    { printf '  PASS  %s\n' "$1"; PASSED=$((PASSED + 1)); }
ko()    { printf '  FAIL  %s\n' "$1"; FAILED=$((FAILED + 1)); }
check() { # <libelle> <commande...>
  local l="$1"; shift
  if "$@"; then ok "$l"; else ko "$l"; fi
}
same_text() { [ "$(cat "$1" 2>/dev/null)" = "$2" ]; }   # 2>/dev/null : fichier absent = faux, c'est le verdict attendu
absent()    { [ ! -e "$1" ]; }
out_has()   { case "$OUT" in *"$1"*) return 0 ;; esac; return 1; }
out_hasnt() { ! out_has "$1"; }

no_tmp()    { [ -z "$(find "$1" -name '*.install.*')" ]; }

g() { git -C "$DEPOT" -c core.safecrlf=false -c user.name=banc -c user.email=banc@example.invalid -c commit.gpgsign=false "$@"; }

# Faux depot : v1 puis v2. v2 modifie SKILL.md et ref/notes.md, retire retire.md, modifie le helper.
DEPOT="$ROOT/depot"
mkdir -p "$DEPOT/skills/alpha/ref" "$DEPOT/skills/beta" "$DEPOT/skills/gamma"
cp "$SCRIPT" "$DEPOT/install-skills.sh" || abort "script introuvable : $SCRIPT"
printf '*.md text eol=lf\n*.sh text eol=lf\n' > "$DEPOT/.gitattributes"
printf -- '---\nname: alpha\ntier: shared\n---\nalpha v1\n' > "$DEPOT/skills/alpha/SKILL.md"
printf 'notes v1\n' > "$DEPOT/skills/alpha/ref/notes.md"
printf 'espace v1\n' > "$DEPOT/skills/alpha/ref/avec espace.md"
printf 'retire v1\n' > "$DEPOT/skills/alpha/retire.md"
printf -- '---\nname: beta\ntier: shared\n---\nbeta v1\n' > "$DEPOT/skills/beta/SKILL.md"
printf -- '---\nname: gamma\n---\ngamma v1 sans marqueur\n' > "$DEPOT/skills/gamma/SKILL.md"
printf '# helper v1\n' > "$DEPOT/personal-sync.sh"
printf '# autre helper v1\n' > "$DEPOT/bootstrap-personal-mirror.sh"
git -C "$DEPOT" init -q || abort "git init"
g add -A && g commit -qm v1 || abort "commit v1"

passer_en_v2() {
  printf -- '---\nname: alpha\ntier: shared\n---\nalpha v2\n' > "$DEPOT/skills/alpha/SKILL.md"
  printf 'notes v2\n' > "$DEPOT/skills/alpha/ref/notes.md"
  printf 'espace v2\n' > "$DEPOT/skills/alpha/ref/avec espace.md"
  rm -f "$DEPOT/skills/alpha/retire.md"
  printf -- '---\nname: gamma\ntier: shared\n---\ngamma v2\n' > "$DEPOT/skills/gamma/SKILL.md"
  printf '# helper v2\n' > "$DEPOT/personal-sync.sh"
  g add -A && g commit -qm v2 || abort "commit v2"
}
installer_sur() { # <home> [depot] : pose OUT et RC
  OUT="$(HOME="$1" bash "${2:-$DEPOT}/install-skills.sh" 2>&1)"; RC=$?
}
H=""; S=""
poste_neuf() { H="$ROOT/home$((N += 1))"; S="$H/.claude/skills"; mkdir -p "$H"; }
N=0
poste_en_v1() { poste_neuf; installer_sur "$H" "$DEPOT_V1"; [ "$RC" = 0 ] || abort "installation v1 : $OUT"; }

# Une copie figee en v1, pour poser des postes en v1 une fois le depot passe en v2.
DEPOT_V1="$ROOT/depot-v1"
git clone -q "$DEPOT" "$DEPOT_V1" || abort "clone v1"

echo "=== install-skills : premiere installation ==="
poste_neuf; installer_sur "$H"
check "C1 code retour 0"               [ "$RC" = 0 ]
check "C1 SKILL.md copie"              same_text "$S/alpha/SKILL.md" "$(cat "$DEPOT/skills/alpha/SKILL.md")"
check "C1 sous-dossier copie"          same_text "$S/alpha/ref/notes.md" "notes v1"
check "C1 nom avec espace copie"       same_text "$S/alpha/ref/avec espace.md" "espace v1"
check "C1 helper copie"                same_text "$S/personal-sync.sh" "# helper v1"
check "C1 signale la skill"            out_has "✓ alpha"

echo "=== relance sans changement ==="
installer_sur "$H"
check "C2 code retour 0"               [ "$RC" = 0 ]
check "C2 aucune ligne de copie"       out_hasnt "✓"
check "C2 aucun fichier garde"         out_hasnt "[gardé]"

passer_en_v2
[ "$(g rev-list --count HEAD)" = 2 ] || abort "le faux depot doit porter 2 versions"

echo "=== version deja publiee : remplacee ==="
poste_en_v1; installer_sur "$H"
check "C3 code retour 0"               [ "$RC" = 0 ]
check "C3 SKILL.md en v2"              same_text "$S/alpha/SKILL.md" "$(cat "$DEPOT/skills/alpha/SKILL.md")"
check "C3 sous-dossier en v2"          same_text "$S/alpha/ref/notes.md" "notes v2"
check "C3 nom avec espace en v2"       same_text "$S/alpha/ref/avec espace.md" "espace v2"
check "C3 helper en v2"                same_text "$S/personal-sync.sh" "# helper v2"
check "C3 fichier retire du depot ote" absent "$S/alpha/retire.md"
check "C3 aucun fichier temporaire"    no_tmp "$S"
check "C15 version publiee avant le marqueur reconnue" same_text "$S/gamma/SKILL.md" "$(cat "$DEPOT/skills/gamma/SKILL.md")"

echo "=== fin de ligne Windows sur une version publiee ==="
poste_en_v1
printf 'notes v1\r\n' > "$S/alpha/ref/notes.md"
installer_sur "$H"
check "C4 reconnue et remplacee"       same_text "$S/alpha/ref/notes.md" "notes v2"

echo "=== edition du poste : gardee ==="
poste_en_v1
printf 'mon edition\n' >> "$S/alpha/SKILL.md"
edite="$(cat "$S/alpha/SKILL.md")"
installer_sur "$H"
check "C5 code retour 0"               [ "$RC" = 0 ]
check "C5 edition intacte"             same_text "$S/alpha/SKILL.md" "$edite"
check "C5 les autres fichiers avancent" same_text "$S/alpha/ref/notes.md" "notes v2"
check "C5 alerte visible et nommee"    out_has "[gardé] skills/alpha/SKILL.md"

echo "=== edition en fins de ligne Windows : reste une copie partagee ==="
poste_en_v1
printf -- '---\r\nname: alpha\r\ntier: shared\r\n---\r\nmon edition\r\n' > "$S/alpha/SKILL.md"
installer_sur "$H"
check "C18 les autres fichiers avancent" same_text "$S/alpha/ref/notes.md" "notes v2"
check "C18 edition intacte"            grep -q "mon edition" "$S/alpha/SKILL.md"

echo "=== fichiers non publies : gardes ==="
poste_en_v1
printf 'note perso\n' > "$S/alpha/ma-note.md"
mkdir -p "$S/alpha/__pycache__"; printf 'x' > "$S/alpha/__pycache__/scan.pyc"
printf 'retire edite\n' > "$S/alpha/retire.md"
installer_sur "$H"
check "C6 fichier perso intact"        same_text "$S/alpha/ma-note.md" "note perso"
check "C6 cache intact"                same_text "$S/alpha/__pycache__/scan.pyc" "x"
check "C6 fichier retire mais edite intact" same_text "$S/alpha/retire.md" "retire edite"

echo "=== skill perso du meme nom : intact ==="
poste_neuf
mkdir -p "$S/alpha"
printf -- '---\nname: alpha\n---\nma skill perso\n' > "$S/alpha/SKILL.md"
printf 'perso\n' > "$S/alpha/perso.md"
installer_sur "$H"
check "C7 code retour 0"               [ "$RC" = 0 ]
check "C7 SKILL.md perso intact"       same_text "$S/alpha/SKILL.md" "$(printf -- '---\nname: alpha\n---\nma skill perso')"
check "C7 fichier perso intact"        same_text "$S/alpha/perso.md" "perso"
check "C7 aucun fichier partage ajoute" absent "$S/alpha/ref"
check "C7 alerte visible et nommee"    out_has "[gardé] skill alpha"
check "C7 les autres skills s'installent" same_text "$S/beta/SKILL.md" "$(cat "$DEPOT/skills/beta/SKILL.md")"

echo "=== dossier du meme nom sans SKILL.md : intact ==="
poste_neuf
mkdir -p "$S/alpha"; printf 'x\n' > "$S/alpha/autre.md"
installer_sur "$H"
check "C8 rien d'ajoute"               absent "$S/alpha/SKILL.md"
check "C8 alerte visible et nommee"    out_has "[gardé] skill alpha"

echo "=== skill perso citant le marqueur hors de son en-tete : intact ==="
poste_neuf
mkdir -p "$S/alpha"
printf -- '---\nname: alpha\n---\ntier: shared\n' > "$S/alpha/SKILL.md"
installer_sur "$H"
check "C19 aucun fichier partage ajoute" absent "$S/alpha/ref"
check "C19 alerte visible et nommee"   out_has "[gardé] skill alpha"

echo "=== geste de reprise conseille : editer, supprimer, relancer ==="
poste_en_v1
printf 'mon edition\n' >> "$S/alpha/SKILL.md"
installer_sur "$H"
check "C20 d'abord gardee"             out_has "[gardé] skills/alpha/SKILL.md"
rm -f "$S/alpha/SKILL.md"
installer_sur "$H"
check "C20 SKILL.md repris du depot"   same_text "$S/alpha/SKILL.md" "$(cat "$DEPOT/skills/alpha/SKILL.md")"
check "C20 plus aucune alerte"         out_hasnt "[gardé]"

echo "=== deploiement coupe : dossier vide, puis relance ==="
poste_neuf
mkdir -p "$S/alpha"
installer_sur "$H"
check "C21 skill installe"             same_text "$S/alpha/SKILL.md" "$(cat "$DEPOT/skills/alpha/SKILL.md")"

echo "=== copie qui echoue a mi-chemin : le poste garde son fichier ==="
CASSE="$ROOT/outils-casses"; mkdir -p "$CASSE/cp" "$CASSE/rm"
printf '#!/bin/sh\nfor dernier; do :; done\n: > "$dernier"\nexit 1\n' > "$CASSE/cp/cp"
printf '#!/bin/sh\nexit 1\n' > "$CASSE/rm/rm"
chmod +x "$CASSE/cp/cp" "$CASSE/rm/rm"
poste_en_v1
OUT="$(HOME="$H" PATH="$CASSE/cp:$PATH" bash "$DEPOT/install-skills.sh" 2>&1)"; RC=$?
check "C22 code retour non nul"        [ "$RC" != 0 ]
check "C22 fichier du poste intact"    same_text "$S/alpha/ref/notes.md" "notes v1"
check "C22 aucun fichier temporaire"   no_tmp "$S"

echo "=== script coupe en pleine copie : ni temporaire, ni fichier abime ==="
mkdir -p "$CASSE/coupe"
printf '#!/bin/sh\nfor dernier; do :; done\n: > "$dernier"\nkill -TERM "$PPID"\nsleep 2\nexit 1\n' > "$CASSE/coupe/cp"
chmod +x "$CASSE/coupe/cp"
poste_en_v1
OUT="$(HOME="$H" PATH="$CASSE/coupe:$PATH" bash "$DEPOT/install-skills.sh" 2>&1)"; RC=$?
check "C24 aucun fichier temporaire"   no_tmp "$S"
check "C24 fichier du poste intact"    same_text "$S/alpha/ref/notes.md" "notes v1"

echo "=== retrait qui echoue : visible, et la suite continue ==="
poste_en_v1
OUT="$(HOME="$H" PATH="$CASSE/rm:$PATH" bash "$DEPOT/install-skills.sh" 2>&1)"; RC=$?
check "C23 code retour non nul"        [ "$RC" != 0 ]
check "C23 alerte visible"             out_has "✗ skills/alpha/retire.md"
check "C23 le bilan s'affiche"         out_has "1 échec(s)"

echo "=== helper edite : garde ==="
poste_en_v1
printf '# helper a moi\n' > "$S/personal-sync.sh"
installer_sur "$H"
check "C9 helper edite intact"         same_text "$S/personal-sync.sh" "# helper a moi"
check "C9 alerte visible et nommee"    out_has "[gardé] personal-sync.sh"

echo "=== copie impossible : echec visible ==="
poste_en_v1
rm -rf "$S/alpha/ref"; printf 'bloque\n' > "$S/alpha/ref"
installer_sur "$H"
check "C10 code retour non nul"        [ "$RC" != 0 ]
check "C10 fichier en travers intact"  same_text "$S/alpha/ref" "bloque"
check "C10 alerte visible"             out_has "✗"

echo "=== depot sans historique (archive) : rien d'ecrase ==="
SANS_GIT="$ROOT/archive"; mkdir -p "$SANS_GIT"
( cd "$DEPOT" && cp -r skills install-skills.sh personal-sync.sh bootstrap-personal-mirror.sh "$SANS_GIT/" ) || abort "copie archive"
poste_en_v1; installer_sur "$H" "$SANS_GIT"
check "C11 code retour 0"              [ "$RC" = 0 ]
check "C11 version du poste gardee"    same_text "$S/alpha/ref/notes.md" "notes v1"
check "C11 limite annoncee"            out_has "historique git"
poste_neuf; installer_sur "$H" "$SANS_GIT"
check "C11 poste neuf installe"        same_text "$S/alpha/ref/notes.md" "notes v2"

echo "=== archive posee dans un autre depot : l'historique d'a cote ne compte pas ==="
PARENT="$ROOT/parent"; git clone -q "$DEPOT" "$PARENT" || abort "clone parent"
cp -r "$SANS_GIT" "$PARENT/copie-imbriquee" || abort "copie imbriquee"
poste_en_v1; installer_sur "$H" "$PARENT/copie-imbriquee"
check "C16 version du poste gardee"    same_text "$S/alpha/ref/notes.md" "notes v1"
check "C16 limite annoncee"            out_has "historique git"

echo "=== clone partiel : rien d'ecrase ==="
PARTIEL="$ROOT/partiel"
racine="$(cd "$DEPOT" && { pwd -W 2>/dev/null || pwd; })"   # 2>/dev/null : -W n'existe que sous Git Bash, repli sur pwd
git clone -q --depth 1 "file:///${racine#/}" "$PARTIEL" || abort "clone partiel"
poste_en_v1; installer_sur "$H" "$PARTIEL"
check "C13 version du poste gardee"    same_text "$S/alpha/ref/notes.md" "notes v1"
check "C13 limite annoncee"            out_has "historique git"

echo "=== le vrai depot sur un poste neuf ==="
poste_neuf
OUT="$(HOME="$H" bash "$SCRIPT" 2>&1)"; RC=$?
check "C14 code retour 0"              [ "$RC" = 0 ]
check "C14 poste identique au depot"   diff -r -x __pycache__ -x .gitkeep -x personal-sync.sh -x bootstrap-personal-mirror.sh "$REPO/skills" "$S"

echo "=== cache python du clone : pas deploye ==="
mkdir -p "$DEPOT/skills/beta/__pycache__"; printf 'x' > "$DEPOT/skills/beta/__pycache__/a.pyc"
poste_neuf; installer_sur "$H"
check "C17 cache absent du poste"      absent "$S/beta/__pycache__"

echo "=== appel depuis bonjour-team : alertes visibles ==="
ligne="$(grep -F 'bash "$SKREPO/install-skills.sh"' "$REPO/skills/bonjour-team/SKILL.md")"
[ -n "$ligne" ] || abort "appel introuvable dans bonjour-team"
case "$ligne" in
  *'| tail'*) ko "C12 la sortie n'est pas tronquee" ;;
  *) ok "C12 la sortie n'est pas tronquee" ;;
esac

TOTAL=$((PASSED + FAILED))
echo "--- $PASSED/$TOTAL verts, $FAILED echec(s)"
[ "$TOTAL" = "$EXPECTED" ] || abort "$TOTAL controles joues, $EXPECTED attendus"
[ "$FAILED" = 0 ]
