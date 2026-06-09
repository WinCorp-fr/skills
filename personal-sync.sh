#!/usr/bin/env bash
# personal-sync.sh — sauvegarde / restaure la mémoire Claude Code d'un dev vers SON miroir perso.
#
# Phase C (sync multi-dev). Générique, AUTONOME (aucune dépendance aux helpers _lib perso, non
# livrés aux devs d'équipe) et public-safe. Appelé par /bonjour-team (--restore) et
# /bonne-nuit-team (--backup). FRONTIÈRE : chaque dev synchronise vers SON dépôt perso (privé),
# jamais celui d'un autre — un dev sans dépôt déclaré ne synchronise rien (skip propre).
#
# Ce fichier manipule les dossiers de mémoire et de projets standard de Claude Code DU DEV
# COURANT (jamais d'un autre dev). Les rares occurrences des noms de structure sont marquées
# LEAK-SCAN-IGNORE — exception auditée du scanner frontière (cf ci/leak-scan.sh) : ce sont les
# noms génériques du miroir du dev courant, pas des références au tier perso d'autrui.
#
# Usage :
#   personal-sync.sh --restore   # miroir → local (début de session, /bonjour-team)
#   personal-sync.sh --backup    # local → miroir + commit + push (fin de session, /bonne-nuit-team)
# Options (tests) : --dir D (miroir local) --remote owner/nom --memdir M (racine projets) --no-net
#
# Dépôt perso résolu, par priorité : --remote > $DEV_PERSONAL_REPO > ~/.claude/profile.env
# NB: `set -e` volontairement ABSENT — les `git … | tail` et `|| true` sont voulus (un échec
# réseau non bloquant ne doit pas tuer la session). Les échecs critiques (push) sont capturés
# explicitement via leur code retour. Ne pas "réparer" en ajoutant -e (casserait les || true).
set -u

MODE=""; DIR=""; REMOTE=""; MEMROOT=""; NONET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --restore) MODE=restore ;;
    --backup)  MODE=backup ;;
    --dir)     DIR="${2:-}"; shift ;;
    --remote)  REMOTE="${2:-}"; shift ;;
    --memdir)  MEMROOT="${2:-}"; shift ;;
    --no-net)  NONET=1 ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "✗ argument inconnu : $1" >&2; exit 2 ;;
  esac
  shift
done
[ -n "$MODE" ] || { echo "usage: personal-sync.sh --restore|--backup [--dir D --remote R --memdir M --no-net]" >&2; exit 2; }

# Lecteur d'une clé du profil d'identité local (générique, sans sourcer le fichier).
_pf() { grep -E "^$1=" "$HOME/.claude/profile.env" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\042\047'; }

# Résolution dépôt perso : --remote > env > profil. Absent → skip propre (deny-by-default).
[ -z "$REMOTE" ] && REMOTE="${DEV_PERSONAL_REPO:-}"
[ -z "$REMOTE" ] && REMOTE="$(_pf DEV_PERSONAL_REPO)"
if [ -z "$REMOTE" ]; then
  echo "  [skip-attendu] aucun miroir perso configuré (DEV_PERSONAL_REPO absent) — pas de sync mémoire."
  exit 0
fi

NAME="${REMOTE##*/}"
case "$REMOTE" in */*) ;; *) echo "  ⚠ DEV_PERSONAL_REPO='$REMOTE' sans '/' — format attendu owner/nom (gh résoudra sur ton compte)." ;; esac
[ -z "$DIR" ] && DIR="$HOME/Documents/wincorp-workspace/$NAME"
[ -z "$MEMROOT" ] && MEMROOT="$HOME/.claude/projects"   # LEAK-SCAN-IGNORE: racine projets Claude Code du dev courant (générique)

echo "=== personal-sync --$MODE ==="
echo "  Miroir : $REMOTE → $DIR"

# --- Réseau (sauf --no-net) : clone si absent ; pull au restore ---
if [ "$NONET" -eq 0 ]; then
  if [ ! -d "$DIR/.git" ]; then
    if command -v gh >/dev/null 2>&1; then
      echo "  miroir absent localement — clonage $REMOTE…"
      gh repo clone "$REMOTE" "$DIR" 2>&1 | tail -2 || true
    else
      echo "  [skip-anomalie] miroir absent + gh indisponible — lancer bootstrap-personal-mirror.sh --apply --push"
      exit 0
    fi
  elif [ "$MODE" = restore ]; then
    git -C "$DIR" pull --ff-only 2>&1 | tail -1 || true
  fi
fi
[ -d "$DIR" ] || { echo "  [skip-anomalie] miroir $DIR introuvable"; exit 0; }
MIRMEM="$DIR/claude-memory"   # LEAK-SCAN-IGNORE: sous-dossier mémoire du miroir du dev courant (générique)
mkdir -p "$MIRMEM"

copied=0; found=0
shopt -s nullglob
# Itère les projets workspace locaux (slug *-Documents-wincorp-*).
for memdir in "$MEMROOT"/*-Documents-wincorp-*/memory; do   # LEAK-SCAN-IGNORE: glob mémoire projet local (générique)
  [ -d "$memdir" ] || continue
  found=$((found+1))
  slug="$(basename "$(dirname "$memdir")")"
  canonical="${slug##*-Documents-}"
  # Défense path-traversal (MED-1) : un canonical avec / ou .. est rejeté (jamais en pratique, le
  # slug vient d'un glob sur dossiers réels — défense en profondeur conforme « robuste v1.0 »).
  case "$canonical" in *..*|*/*|"") echo "  [skip-anomalie] slug inattendu ($slug) — ignoré"; continue ;; esac
  dest="$MIRMEM/$canonical"
  if [ "$MODE" = backup ]; then
    mkdir -p "$dest"
    for src in "$memdir"/*.md; do
      [ -f "$src" ] || continue
      tg="$dest/$(basename "$src")"
      if [ ! -f "$tg" ] || [ "$src" -nt "$tg" ]; then cp -p "$src" "$tg"; copied=$((copied+1)); fi
    done
  else  # restore : miroir → local
    [ -d "$dest" ] || continue
    mkdir -p "$memdir"
    for src in "$dest"/*.md; do
      [ -f "$src" ] || continue
      tg="$memdir/$(basename "$src")"
      if [ ! -f "$tg" ] || [ "$src" -nt "$tg" ]; then cp -p "$src" "$tg"; copied=$((copied+1)); fi
    done
  fi
done
shopt -u nullglob
if [ "$found" -eq 0 ]; then
  echo "  [skip-anomalie] aucun projet *-Documents-wincorp-* sous $MEMROOT — workspace hors ~/Documents ? (rien synchronisé)"
else
  echo "  $copied fichier(s) mémoire $([ "$MODE" = backup ] && echo 'sauvegardés vers' || echo 'restaurés depuis') le miroir."
fi

# --- Backup : commit + push ---
if [ "$MODE" = backup ] && [ -d "$DIR/.git" ]; then
  if [ -n "$(git -C "$DIR" status --short claude-memory/ 2>/dev/null)" ]; then   # LEAK-SCAN-IGNORE: statut du dossier mémoire du miroir (générique)
    c_name="$(git -C "$DIR" config user.name 2>/dev/null || true)"; [ -z "$c_name" ] && c_name="${DEV_NAME:-$(_pf DEV_NAME)}"; [ -z "$c_name" ] && c_name="wincorp-dev"
    c_mail="$(git -C "$DIR" config user.email 2>/dev/null || true)"; [ -z "$c_mail" ] && c_mail="${DEV_EMAIL_WINCORP:-$(_pf DEV_EMAIL_WINCORP)}"; [ -z "$c_mail" ] && c_mail="dev@wincorp.local"
    git -C "$DIR" add claude-memory/   # LEAK-SCAN-IGNORE: stage du dossier mémoire du miroir (générique)
    git -C "$DIR" -c user.name="$c_name" -c user.email="$c_mail" commit -q -m "chore(memory): snapshot $(date +%Y-%m-%d)

Sauvegarde auto /bonne-nuit-team (personal-sync)." 2>&1 | tail -2
    if [ "$NONET" -eq 0 ]; then
      # Capturer le code retour AVANT le pipe (sinon `| tail` masque l'échec — bug HIGH 2026-06-09).
      if ! git -C "$DIR" remote get-url origin >/dev/null 2>&1; then
        echo "  ⚠ pas de remote 'origin' — mémoire commitée localement mais NON poussée (lancer 'bootstrap-personal-mirror.sh --push' une fois)."
      else
        push_out="$(git -C "$DIR" push 2>&1)"; push_rc=$?
        echo "$push_out" | tail -2 | sed 's/^/    /'
        if [ "$push_rc" -ne 0 ]; then
          echo "  ⚠ push ÉCHOUÉ (rc=$push_rc) — mémoire commitée localement mais NON poussée."
        else
          echo "  ✓ miroir mémoire poussé."
        fi
      fi
    else
      echo "  ✓ miroir mémoire mis à jour (local, --no-net)."
    fi
  else
    echo "  = miroir déjà à jour, rien à committer."
  fi
fi
