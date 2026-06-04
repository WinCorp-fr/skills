#!/usr/bin/env bash
# leak-scan.sh — barriere anti-fuite confidentielle (donnees client/perso) pour WinCorp-fr/skills
#
# Source UNIQUE de detection, appelee par DEUX consommateurs (zero duplication, anti-drift) :
#   - la CI GitHub (mode --tree, scanne l'arbre entier a chaque PR) = barriere serveur fail-closed
#   - le hook local block-confidential-to-shared.sh (mode --files, scanne le diff sortant)
#
# Modele : ALLOWLIST (deny-by-default, niveau fichier, tous types) + denylist de contenu
# (defense en profondeur). CRITIQUE : a l'inverse de block-secrets-commit.sh, ce scanner ne
# SKIP jamais un fichier (binaire / gros / non prouve) en l'AUTORISANT — tout skip = VIOLATION.
#
# Exit : 0 = propre, 2 = fuite detectee, 3 = erreur d'usage/config (le hook traite 2 ET 3 comme deny).
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATTERNS_FILE="${LEAK_PATTERNS_FILE:-$SCRIPT_DIR/leak-patterns.txt}"
ALLOW_FILE="${LEAK_ALLOW_FILE:-$SCRIPT_DIR/leak-scan.allow}"
IGNORE_MARK='LEAK-SCAN-IGNORE'

VIOLATIONS=0
report() { printf '  X [%s] %s\n' "$1" "$2" >&2; VIOLATIONS=$((VIOLATIONS + 1)); }
usage()  { echo "usage: leak-scan.sh --tree [DIR] | --files F1 [F2...] | --self-check" >&2; exit 3; }

# --- Chargement de la taxonomie (fail-closed : pas de patterns = erreur, jamais 'tout propre') ---
[ -f "$PATTERNS_FILE" ] || { echo "FATAL: taxonomie introuvable: $PATTERNS_FILE" >&2; exit 3; }
PAT_LABELS=(); PAT_REGEX=()
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in ''|\#*) continue ;; esac
  case "$line" in *'|||'*) ;; *) continue ;; esac
  PAT_LABELS+=("${line%%|||*}")
  PAT_REGEX+=("${line#*|||}")
done < "$PATTERNS_FILE"
[ "${#PAT_REGEX[@]}" -gt 0 ] || { echo "FATAL: 0 pattern charge depuis $PATTERNS_FILE" >&2; exit 3; }

# Denylist LOCALE optionnelle (noms cabinet/societes/clients) — JAMAIS versionnee (surtout pas
# dans ce depot public). Chargee en complement des motifs structurels publics. Sur la CI publique
# elle est absente -> seuls les motifs structurels + la grille allowlist s'appliquent.
LOCAL_PATTERNS="${LEAK_LOCAL_PATTERNS:-$HOME/.claude/leak-patterns.local.txt}"
if [ -f "$LOCAL_PATTERNS" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|\#*) continue ;; esac
    case "$line" in *'|||'*) ;; *) continue ;; esac
    PAT_LABELS+=("local:${line%%|||*}")
    PAT_REGEX+=("${line#*|||}")
  done < "$LOCAL_PATTERNS"
fi

# --- Allowlist des fichiers non-.md (globs) ---
ALLOW_GLOBS=()
if [ -f "$ALLOW_FILE" ]; then
  while IFS= read -r g || [ -n "$g" ]; do
    case "$g" in ''|\#*) continue ;; esac
    ALLOW_GLOBS+=("$g")
  done < "$ALLOW_FILE"
fi

is_allowlisted() {  # $1 = relpath
  local p="$1" g
  case "$p" in */.gitkeep|.gitkeep) return 0 ;; esac
  for g in "${ALLOW_GLOBS[@]:-}"; do
    [ -z "$g" ] && continue
    # shellcheck disable=SC2254
    case "$p" in $g) return 0 ;; esac
  done
  return 1
}

is_skipped() {  # $1 = relpath — infra du scanner, non scannable (contient les patterns par nature)
  case "$1" in
    .git/*|*/.git/*) return 0 ;;
    ci/*)           return 0 ;;
    .github/*)      return 0 ;;
  esac
  return 1
}

is_binary() {  # $1 = abspath — NUL dans les 8 premiers Ko = binaire
  LC_ALL=C od -An -tx1 -N 8192 "$1" 2>/dev/null | grep -q ' 00'
}

scan_filename() {  # $1 = relpath — un nom de fichier peut encoder un SIREN/marqueur client
  local p="$1" i
  for i in "${!PAT_REGEX[@]}"; do
    printf '%s' "$p" | grep -qE "${PAT_REGEX[$i]}" && report "${PAT_LABELS[$i]}/nom-fichier" "$p"
  done
}

scan_content() {  # $1 = abspath, $2 = relpath
  local abs="$1" rel="$2" i hits
  for i in "${!PAT_REGEX[@]}"; do
    hits=$(grep -nE "${PAT_REGEX[$i]}" "$abs" 2>/dev/null | grep -v "$IGNORE_MARK" | head -2)
    [ -n "$hits" ] && report "${PAT_LABELS[$i]}" "$rel : $(printf '%s' "$hits" | tr '\n' ' ' | cut -c1-160)"
  done
}

require_tier_shared() {  # $1 = abspath, $2 = relpath — frontmatter strict, deny-by-default
  head -n 30 "$1" 2>/dev/null | grep -qE '^tier:[[:space:]]*shared[[:space:]]*$' \
    || report "tier-non-shared" "$2 (frontmatter 'tier: shared' absent/invalide — deny-by-default)"
}

scan_file() {  # $1 = relpath, $2 = abspath
  local rel="$1" abs="$2"
  is_skipped "$rel" && return 0
  [ -f "$abs" ] || return 0
  scan_filename "$rel"
  # Grille de type (allowlist deny-by-default)
  case "$rel" in
    README.md|MANIFEST.md)   : ;;                                   # meta depot — contenu scanne, pas de tier requis
    */.gitkeep|.gitkeep)     : ;;
    *.md)                    require_tier_shared "$abs" "$rel" ;;   # tout .md doit prouver tier: shared
    *)                       is_allowlisted "$rel" || report "non-md-non-allowliste" "$rel" ;;
  esac
  # Contenu : scanner si textuel ; un binaire non allowliste = non prouvable = VIOLATION
  if is_binary "$abs"; then
    is_allowlisted "$rel" || report "binaire-non-allowliste" "$rel (binaire non scannable, non prouve propre)"
  else
    scan_content "$abs" "$rel"
  fi
}

MODE="${1:-}"; [ -n "$MODE" ] || usage; shift
case "$MODE" in
  --tree)
    ROOT="${1:-.}"
    [ -d "$ROOT" ] || { echo "FATAL: dossier introuvable: $ROOT" >&2; exit 3; }
    ROOT="$(cd "$ROOT" && pwd)"
    while IFS= read -r abs; do
      scan_file "${abs#"$ROOT"/}" "$abs"
    done < <(find "$ROOT" -type f -not -path '*/.git/*' | sort)
    ;;
  --files)
    [ "$#" -gt 0 ] || usage
    for f in "$@"; do
      abs="$f"; [ -f "$abs" ] || abs="$(pwd)/$f"
      scan_file "$f" "$abs"
    done
    ;;
  --self-check)
    [ -f "$SCRIPT_DIR/tests/run-tests.sh" ] || { echo "FATAL: tests/run-tests.sh absent" >&2; exit 3; }
    exec bash "$SCRIPT_DIR/tests/run-tests.sh"
    ;;
  *) usage ;;
esac

if [ "$VIOLATIONS" -gt 0 ]; then
  echo "LEAK-SCAN: $VIOLATIONS violation(s) detectee(s) — BLOQUE" >&2
  exit 2
fi
echo "LEAK-SCAN: propre (0 violation)"
exit 0
