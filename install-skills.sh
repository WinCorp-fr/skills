#!/usr/bin/env bash
# install-skills.sh — déploie les skills partagés WinCorp dans ~/.claude/skills/
#
# Usage (depuis le clone wincorp-skills/) :
#   bash install-skills.sh                 # déploie la version locale
#   git pull && bash install-skills.sh     # met à jour puis déploie
#
# Idempotent : remplace proprement chaque skill partagé. Ne touche QUE les
# dossiers listés sous skills/ (jamais les skills d'un autre dev/tier).

set -euo pipefail

if ! command -v cp >/dev/null 2>&1; then
  echo "✗ 'cp' introuvable — shell POSIX requis (Git Bash sur Windows)." >&2
  exit 1
fi

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/skills" && pwd)"
DEST="${HOME}/.claude/skills"
mkdir -p "$DEST"

count=0
for skill in "$SRC"/*/; do
  name="$(basename "$skill")"
  [[ -n "$name" ]] || continue
  rm -rf "${DEST:?}/$name"        # ${DEST:?} : refuse de tourner si DEST est vide
  cp -r "$skill" "$DEST/$name"
  echo "  ✓ $name"
  count=$((count + 1))
done

# Helpers partagés (scripts génériques appelés par les skills -team) — déployés à plat dans
# ~/.claude/skills/ pour un chemin d'appel fixe, indépendant de l'emplacement du clone.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for helper in personal-sync.sh bootstrap-personal-mirror.sh; do
  if [ -f "$REPO_ROOT/$helper" ]; then
    cp "$REPO_ROOT/$helper" "$DEST/$helper"
    echo "  ✓ (helper) $helper"
  fi
done

echo "→ $count skill(s) partagé(s) déployé(s) dans $DEST"
