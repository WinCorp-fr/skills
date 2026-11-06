#!/usr/bin/env bash
# install-skills.sh : déploie les skills partagés WinCorp dans ~/.claude/skills/
#
# Usage (depuis le clone wincorp-skills/) :
#   bash install-skills.sh                 # déploie la version locale
#   git pull && bash install-skills.sh     # met à jour puis déploie
#
# Ne remplace jamais ce qui n'a pas été publié. Fichier par fichier, l'historique git de ce dépôt
# tranche (empreinte de git, donc fins de ligne comprises) :
#   absent du poste                          -> copié
#   version déjà publiée à ce chemin         -> remplacée (ou ôtée si elle a quitté le dépôt)
#   contenu jamais publié (édition, note...) -> gardé, avec une ligne [gardé] s'il existe au dépôt
# Un dossier du même nom sans « tier: shared » est un skill perso : rien n'y est écrit.
# Sans historique (archive, clone partiel), une version ancienne ne se reconnaît pas : gardée aussi.
# Limites assumées : une édition revenue mot pour mot à une version publiée passe pour cette version
# (rien de perdu, elle est dans l'historique) ; un skill retiré en entier du dépôt reste au poste.
# Seuls git et un shell POSIX sont requis. Code retour 1 si une copie ou un retrait échoue.
# Banc d'essai : ci/tests/test-install-skills.sh

set -euo pipefail

for outil in awk cmp cp find mkdir mv rm; do
  if ! command -v "$outil" >/dev/null 2>&1; then
    echo "✗ '$outil' introuvable : shell POSIX requis (Git Bash sur Windows)." >&2
    exit 1
  fi
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO_ROOT/skills"
DEST="${HOME:?}/.claude/skills"
mkdir -p "$DEST"

# Historique utilisable : ce dossier est la racine d'un dépôt git. Les 2>/dev/null ci-dessous
# répondent seulement « non » hors dépôt (cas prévu, annoncé juste après).
HISTORY=0
if command -v git >/dev/null 2>&1 \
  && git -C "$REPO_ROOT" rev-parse --verify -q HEAD >/dev/null 2>&1 \
  && [ -z "$(git -C "$REPO_ROOT" rev-parse --show-cdup 2>/dev/null)" ]; then
  HISTORY=1
fi
if [ "$HISTORY" = 0 ] || [ "$(git -C "$REPO_ROOT" rev-parse --is-shallow-repository 2>/dev/null)" = true ]; then
  echo "  ⚠ historique git absent ou partiel : une version ancienne ne se distingue pas d'une édition, elle est gardée. Pour recevoir les mises à jour : cloner le dépôt en entier."
fi

KEPT=0; FAILED=0; CHANGED=0; TMP=""
# Script interrompu en pleine copie (Ctrl+C) : ne pas laisser le temporaire. || : rien de plus à faire.
trap '[ -z "$TMP" ] || rm -f "$TMP" || :' EXIT

# published <chemin dans le dépôt> <fichier> : ce contenu exact a-t-il déjà été publié à ce chemin ?
# Lu dans une variable : un « git log | grep -q » coupé net échouerait au hasard sous pipefail.
# Les 2>/dev/null : une lecture impossible répond « non publié », donc gardé (sens sûr).
published() {
  [ "$HISTORY" = 1 ] || return 1
  local blob hist
  blob="$(git -C "$REPO_ROOT" hash-object --path="$1" -- "$2" 2>/dev/null)" || return 1
  hist="$(git -C "$REPO_ROOT" --literal-pathspecs log --format= --raw --no-abbrev --no-renames -- "$1" 2>/dev/null)" || return 1
  case "$hist" in *" $blob "*) return 0 ;; esac
  return 1
}

# place <source> <cible sur le poste> <chemin dans le dépôt>
place() {
  local src="$1" tg="$2" path="$3" tmp
  if [ -e "$tg" ] || [ -L "$tg" ]; then
    if [ -f "$tg" ] && cmp -s "$src" "$tg"; then return 0; fi
    if [ ! -f "$tg" ] || ! published "$path" "$tg"; then
      KEPT=$((KEPT + 1))
      echo "  ⊙ [gardé] $path : version absente de l'historique de ce clone (édition sur ce poste ?). La proposer au dépôt par une PR, ou supprimer $tg puis relancer pour reprendre la version du dépôt."
      return 0
    fi
  fi
  # Copie puis renommage : une copie interrompue ne laisse pas un fichier tronqué, que l'on
  # prendrait ensuite pour une édition.
  tmp="$tg.install.$$"
  TMP="$tmp"
  if mkdir -p "$(dirname "$tg")" && cp -p "$src" "$tmp" && mv -f "$tmp" "$tg"; then
    TMP=""
    CHANGED=1
  else
    rm -f "$tmp" || :   # || : le temporaire qui résiste ne change pas le verdict, déjà un échec
    TMP=""
    FAILED=$((FAILED + 1))
    echo "  ✗ $path : copie vers $tg impossible, le poste garde ce qu'il avait."
  fi
}

# shared_copy <nom> : le dossier du poste est-il une copie de ce skill partagé ?
# Oui si « tier: shared » figure dans l'en-tête du SKILL.md, si ce SKILL.md est une version publiée
# (d'avant le marqueur). Sans SKILL.md (supprimé pour reprendre la version du dépôt, déploiement
# coupé) : oui si le dossier est vide ou porte au moins un fichier publié.
shared_copy() {
  local dir="$DEST/$1" md="$DEST/$1/SKILL.md" f vide=1
  [ -d "$dir" ] || return 1
  if [ -f "$md" ]; then
    if awk 'NR==1 && !/^---[[:space:]]*$/ {exit} NR>1 && /^---[[:space:]]*$/ {exit} /^tier:[[:space:]]*shared[[:space:]]*$/ {f=1; exit} END {exit !f}' "$md"; then
      return 0
    fi
    published "skills/$1/SKILL.md" "$md"
    return
  fi
  while IFS= read -r -d '' f; do
    vide=0
    if published "skills/$1/${f#"$dir/"}" "$f"; then return 0; fi
  done < <(find -H "$dir" -type f -not -path '*/__pycache__/*' -print0)
  [ "$vide" = 1 ]
}

count=0; updated=0; homonyms=0
for skill in "$SRC"/*/; do
  skill="${skill%/}"   # sans barre finale : le find de macOS en doublerait une dans les chemins
  name="$(basename "$skill")"
  [[ -n "$name" ]] || continue
  count=$((count + 1))
  if [ -e "$DEST/$name" ] && ! shared_copy "$name"; then
    homonyms=$((homonyms + 1))
    echo "  ⊙ [gardé] skill $name : un dossier du même nom sans « tier: shared » existe sur ce poste, rien n'y est écrit et le skill partagé n'est pas installé. Pour l'avoir : renommer ce dossier puis relancer."
    continue
  fi
  CHANGED=0
  while IFS= read -r -d '' src; do
    rel="${src#"$skill/"}"
    place "$src" "$DEST/$name/$rel" "skills/$name/$rel"
  done < <(find "$skill" -type f -not -path '*/__pycache__/*' -print0)
  # Version publiée puis retirée du dépôt : on l'ôte. Tout autre fichier en plus reste au poste.
  while IFS= read -r -d '' tg; do
    rel="${tg#"$DEST/$name/"}"
    [ ! -e "$skill/$rel" ] || continue
    if published "skills/$name/$rel" "$tg"; then
      if rm -f "$tg"; then
        CHANGED=1
      else
        FAILED=$((FAILED + 1))
        echo "  ✗ skills/$name/$rel : retiré du dépôt, mais $tg n'a pas pu être ôté."
      fi
    fi
  done < <(find -H "$DEST/$name" -type f -not -path '*/__pycache__/*' -print0)
  if [ "$CHANGED" = 1 ]; then
    updated=$((updated + 1))
    echo "  ✓ $name"
  fi
done

# Helpers partagés (scripts génériques appelés par les skills -team), déployés à plat dans
# ~/.claude/skills/ pour un chemin d'appel fixe, indépendant de l'emplacement du clone.
for helper in personal-sync.sh bootstrap-personal-mirror.sh; do
  if [ -f "$REPO_ROOT/$helper" ]; then
    CHANGED=0
    place "$REPO_ROOT/$helper" "$DEST/$helper" "$helper"
    if [ "$CHANGED" = 1 ]; then echo "  ✓ (helper) $helper"; fi
  fi
done

echo "→ $count skill(s) partagé(s) dans $DEST : $updated mis à jour, $KEPT fichier(s) et $homonyms skill(s) gardés, $FAILED échec(s)"
[ "$FAILED" = 0 ]
