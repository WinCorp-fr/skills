#!/usr/bin/env bash
# test-audit-dette-agents.sh : controle « champ name = nom du fichier » des agents par
# skills/audit-dette/scan.py, sur un faux poste (HOME temporaire) et un faux workspace.
# Le banc passe par le chemin de production (sous-processus --summary puis --full), jamais par
# un appel direct des fonctions : un controle debranche du rapport doit faire echouer le banc.
# Usage : bash ci/tests/test-audit-dette-agents.sh   (exit 0 = tout vert, 1 = echec, 2 = banc casse)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
SCAN="${AUDIT_DETTE_SCAN_PY:-$REPO/skills/audit-dette/scan.py}"
ROOT="$(mktemp -d)" || { echo "ABORT : dossier temporaire impossible"; exit 2; }
trap 'rm -rf "$ROOT"' EXIT
PASSED=0; FAILED=0
# Sentinelle : un banc qui saute des cas ne doit pas passer pour vert.
EXPECTED=34

abort() { echo "ABORT (banc casse) : $*"; exit 2; }
ok()    { printf '  PASS  %s\n' "$1"; PASSED=$((PASSED + 1)); }
ko()    { printf '  FAIL  %s\n' "$1"; FAILED=$((FAILED + 1)); }
out_has()   { case "$OUT" in *"$1"*) ok "$2" ;; *) ko "$2" ;; esac; }
out_hasnt() { case "$OUT" in *"$1"*) ko "$2" ;; *) ok "$2" ;; esac; }

[ -f "$SCAN" ] || abort "scan.py introuvable : $SCAN"
PY=""
for cand in python3 python; do
  # 2>/dev/null : un interpreteur absent ou factice (alias du magasin Windows) est un candidat ecarte
  if command -v "$cand" >/dev/null 2>&1 && "$cand" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)' 2>/dev/null; then
    PY="$cand"; break
  fi
done
[ -n "$PY" ] || abort "aucun interpreteur Python >= 3.9"

# Chemins au format natif pour Python sous Windows (un chemin /c/... passe tel quel serait relu C:\c\...).
native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s\n' "$1"; fi; }
FAKE_HOME="$ROOT/poste"
WS="$FAKE_HOME/Documents/ws-banc"
AGENTS="$FAKE_HOME/.claude/agents"
REPORTS="$WS/.claude/dette-reports"
mkdir -p "$FAKE_HOME/.claude/skills" "$WS/.claude" || abort "arborescence du faux poste"
printf '{}\n' > "$WS/.claude/settings.json"

scan() { # <mode> -> OUT (sortie complete) ; echec du scanner = banc casse
  local home_native; home_native="$(native "$FAKE_HOME")"
  # Un seul rapport a la fois : un banc a cheval sur minuit lirait sinon celui de la veille.
  rm -f -- "$REPORTS"/dette-report-*.md
  OUT="$(cd "$WS" && HOME="$home_native" USERPROFILE="$home_native" \
    AUDIT_DETTE_WORKSPACE_NAME=ws-banc PYTHONIOENCODING=utf-8 PYTHONDONTWRITEBYTECODE=1 \
    "$PY" "$(native "$SCAN")" "$1" 2>&1)" \
    || abort "scan.py $1 a plante : $OUT"
}
report() { cat "$REPORTS"/dette-report-*.md 2>/dev/null; }   # 2>/dev/null : rapport absent = chaine vide, c'est le verdict du controle
full()   { scan --full; OUT="$(report)"; }
agent()  { printf -- '---\nname: %s\nmodel: sonnet\n---\n%s\n' "$2" "$3" > "$AGENTS/$1"; }

echo "== 1. dossier agents absent : pas de plantage, etat dit"
scan --summary
out_has "Agents au nom divergent ou absent : 0 (dossier agents absent)" "1a. absence du dossier annoncee"
full
out_has "- dossier agents absent (rien a controler)" "1b. absence dite au rapport complet"

echo "== 2. parc sain (guillemets, CRLF, BOM, espace avant les deux-points, commentaire, name du corps)"
mkdir -p "$AGENTS/sous-dossier"
agent alpha.md alpha "sain"
agent bravo.md bravo "sain"
printf -- '---\nname: "charlie"\n---\ncorps\n' > "$AGENTS/charlie.md"
printf -- '---\r\nname: delta\r\n---\r\ncorps\r\n' > "$AGENTS/delta.md"
printf -- '\xef\xbb\xbf---\nname: echo\n---\ncorps\n' > "$AGENTS/echo.md"
printf -- '---\nname : foxtrot\n---\ncorps\n' > "$AGENTS/foxtrot.md"
printf -- '---\nname: golf # agent de demonstration\n---\n\nname: alpha dans le corps\n' > "$AGENTS/golf.md"
printf 'Notes libres, sans frontmatter.\n' > "$AGENTS/LISEZ-MOI.md"
agent sous-dossier/hotel.md alpha "hors racine plate"
printf -- '---\nname: alpha\n---\nscript range ici par erreur\n' > "$AGENTS/outil.sh"
scan --summary
out_has "Agents au nom divergent ou absent : 0 (sur 7 agents examines)" "2a. 0 divergence, 7 agents lus (vivacite)"
full
out_has "## Agents : champ name different du nom du fichier, ou absent" "2b. section presente au rapport"
out_has "- aucun (7 agents examines" "2c. section saine avec le compte examine"
out_has "**Statut OK**" "2d. recommandation : statut OK"

echo "== 3. rotation : un agent porte le contenu d'un autre"
agent bravo.md alpha "contenu de alpha"
scan --summary
out_has "Agents au nom divergent ou absent : 1 (sur 7 agents examines)" "3a. 1 divergence comptee"
full
out_has '- `bravo.md` -> `name: alpha` (attendu: `bravo`) : contenu d'"'"'un autre agent existant (`alpha.md`)' "3b. rotation nommee au rapport"
out_has "**Fix immediat**" "3c. recommandation : fix immediat"
out_hasnt "**Statut OK**" "3d. plus de statut OK"
agent bravo.md bravo "retabli"

echo "== 4. variantes d'ecriture d'un agent ecrase"
printf -- '---\r\nname: alpha\r\n---\r\ncorps\r\n' > "$AGENTS/delta.md"
full
out_has '- `delta.md` -> `name: alpha` (attendu: `delta`)' "4a. ecrase en CRLF detecte"
agent delta.md delta "retabli"
printf -- '\xef\xbb\xbf---\nname: alpha\n---\ncorps\n' > "$AGENTS/echo.md"
full
out_has '- `echo.md` -> `name: alpha` (attendu: `echo`)' "4b. ecrase avec BOM detecte"
agent echo.md echo "retabli"
printf -- '---\nname: "alpha"\n---\ncorps\n' > "$AGENTS/charlie.md"
full
out_has '- `charlie.md` -> `name: alpha` (attendu: `charlie`)' "4c. ecrase avec guillemets detecte"
out_hasnt '`name: "alpha"`' "4d. guillemets retires du nom affiche"
agent charlie.md charlie "retabli"
printf -- '---\nname : alpha\n---\ncorps\n' > "$AGENTS/foxtrot.md"
full
out_has '- `foxtrot.md` -> `name: alpha` (attendu: `foxtrot`)' "4e. ecrase avec espace avant les deux-points detecte"
agent foxtrot.md foxtrot "retabli"
printf -- '---\nname: alpha # copie\n---\ncorps\n' > "$AGENTS/golf.md"
full
out_has '- `golf.md` -> `name: alpha` (attendu: `golf`) : contenu d'"'"'un autre agent' "4f. commentaire de fin de ligne retire du nom"
agent golf.md golf "retabli"

echo "== 5. nom inconnu : signale, sans le dire ecrase"
agent bravo.md bravo-pro "renomme"
scan --summary
out_has "Agents au nom divergent ou absent : 1 (sur 7 agents examines)" "5a. divergence comptee"
full
out_has '- `bravo.md` -> `name: bravo-pro` (attendu: `bravo`) : nom inconnu' "5b. qualifie de nom inconnu"
out_hasnt "contenu d'un autre agent" "5c. pas qualifie de rotation"
agent bravo.md alp "debut du nom d'un voisin"
full
out_has '- `bravo.md` -> `name: alp` (attendu: `bravo`) : nom inconnu' "5d. debut du nom d'un voisin : pas une rotation"
agent bravo.md "bravo x" "nom en deux mots"
full
out_has '- `bravo.md` -> `name: bravo x` (attendu: `bravo`) : nom inconnu' "5e. valeur lue en entier, jamais tronquee au premier mot"
agent bravo.md bravo "retabli"
agent Kilo.md kilo "casse differente"
full
out_has '- `Kilo.md` -> `name: kilo` (attendu: `Kilo`) : nom inconnu' "5f. difference de casse : divergence"
rm -f -- "$AGENTS/Kilo.md"

echo "== 6. perimetre : hors racine plate, hors .md, sans frontmatter"
full
out_hasnt "hotel.md" "6a. sous-dossier hors perimetre"
out_hasnt "LISEZ-MOI.md" "6b. fichier sans frontmatter ignore"
out_hasnt "outil.sh" "6c. fichier non .md ignore"
out_has "- aucun (7 agents examines" "6d. parc retabli : section saine"

echo "== 7. deux divergences : chacune listee"
agent alpha.md bravo "croise"; agent bravo.md alpha "croise"
scan --summary
out_has "Agents au nom divergent ou absent : 2 (sur 7 agents examines)" "7a. 2 divergences comptees"
full
out_has '- `alpha.md` -> `name: bravo` (attendu: `alpha`)' "7b. premiere divergence listee"
out_has '- `bravo.md` -> `name: alpha` (attendu: `bravo`)' "7c. seconde divergence listee"
agent alpha.md alpha "retabli"; agent bravo.md bravo "retabli"

echo "== 8. frontmatter sans champ name : signale, le corps n'est jamais lu"
printf -- '---\nmodel: sonnet\n---\n\nname: alpha dans le corps\n' > "$AGENTS/india.md"
scan --summary
out_has "Agents au nom divergent ou absent : 1 (sur 8 agents examines)" "8a. compte dans les examines et dans les divergences"
full
out_has '- `india.md` -> frontmatter sans champ `name:` (attendu: `india`)' "8b. absence du champ nommee au rapport"
out_hasnt '`india.md` -> `name: alpha' "8c. name du corps jamais pris pour celui de l'agent"
out_has "**Fix immediat**" "8d. recommandation : fix immediat"
printf -- '---\n  name: india\nmodel: sonnet\n---\ncorps\n' > "$AGENTS/india.md"
full
out_has '- `india.md` -> frontmatter sans champ `name:`' "8e. name indente (cle imbriquee) non lu"

echo
TOTAL=$((PASSED + FAILED))
[ "$TOTAL" -eq "$EXPECTED" ] || abort "$TOTAL controles executes, $EXPECTED attendus (cas saute ou ajoute sans mise a jour)"
if [ "$FAILED" -eq 0 ]; then echo "Resultat : $PASSED PASS / 0 FAIL"; exit 0; fi
echo "Resultat : $PASSED PASS / $FAILED FAIL"; exit 1
