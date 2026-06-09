#!/usr/bin/env bash
# Test TDD — bootstrap-personal-mirror.sh (Phase C symétrique, miroir perso d'un dev).
# Standalone, aucun accès GitHub (pas de --push). Sandbox jetable.
# Lance : bash wincorp-skills/ci/tests/test-bootstrap-personal-mirror.sh
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
BOOT="$REPO/bootstrap-personal-mirror.sh"

pass=0; fail=0
ok() { echo "  ✓ $1"; pass=$((pass+1)); }
ko() { echo "  ✗ $1"; fail=$((fail+1)); }

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

echo "=== test bootstrap-personal-mirror ==="

[ -f "$BOOT" ] || { echo "  ✗ $BOOT introuvable"; exit 1; }

# 1. DRY-RUN par défaut : ne crée RIEN, exit 0, mentionne dry-run
out1="$(bash "$BOOT" --remote testdev/test-mirror --dir "$SANDBOX/m1" 2>&1)"; rc1=$?
[ "$rc1" -eq 0 ] && ok "dry-run exit 0" || ko "dry-run exit $rc1"
echo "$out1" | grep -qiE "dry.run|simulation" && ok "dry-run annoncé" || ko "dry-run non annoncé"
[ ! -e "$SANDBOX/m1/claude-memory" ] && ok "dry-run ne crée rien" || ko "dry-run a créé la structure"

# 2. --apply : crée la structure + git init + commit
out2="$(bash "$BOOT" --apply --remote testdev/test-mirror --dir "$SANDBOX/m2" 2>&1)"; rc2=$?
[ "$rc2" -eq 0 ] && ok "apply exit 0" || { ko "apply exit $rc2"; echo "$out2" | sed 's/^/      /'; }
for d in claude-memory claude-global .claude/skills-snapshot .claude/agents-snapshot \
         .claude/hooks-snapshot .claude/plans-snapshot .claude/scheduled-tasks-snapshot; do
  [ -f "$SANDBOX/m2/$d/.gitkeep" ] && ok "structure: $d/.gitkeep" || ko "manque $d/.gitkeep"
done
[ -f "$SANDBOX/m2/.gitignore" ] && ok ".gitignore créé" || ko ".gitignore manquant"
[ -f "$SANDBOX/m2/README.md" ] && ok "README.md créé" || ko "README.md manquant"
[ -d "$SANDBOX/m2/.git" ] && ok "git init" || ko "pas de .git"
( cd "$SANDBOX/m2" && [ -n "$(git log --oneline 2>/dev/null)" ] ) && ok "commit initial présent" || ko "pas de commit"

# 3. Idempotent : re-apply ne casse pas, pas de doublon
out3="$(bash "$BOOT" --apply --remote testdev/test-mirror --dir "$SANDBOX/m2" 2>&1)"; rc3=$?
[ "$rc3" -eq 0 ] && ok "ré-apply idempotent (exit 0)" || ko "ré-apply exit $rc3"

# 4. Exige DEV_PERSONAL_REPO : sans --remote ni profil → échec clair
out4="$(env -u DEV_PERSONAL_REPO HOME="$SANDBOX/nohome" bash "$BOOT" --apply --dir "$SANDBOX/m4" 2>&1)"; rc4=$?
[ "$rc4" -ne 0 ] && ok "exige dépôt perso (exit != 0 sans remote/profil)" || ko "n'a pas exigé le dépôt perso"
[ ! -e "$SANDBOX/m4/claude-memory" ] && ok "pas de structure si dépôt manquant" || ko "structure créée sans dépôt"

# 5. Frontière .gitignore : protège les secrets
gi="$SANDBOX/m2/.gitignore"
grep -q 'keys.txt' "$gi" && ok ".gitignore: keys.txt" || ko ".gitignore sans keys.txt"
grep -qE '^\.env' "$gi" && ok ".gitignore: .env" || ko ".gitignore sans .env"
grep -q '*.age' "$gi" && ok ".gitignore: *.age" || ko ".gitignore sans *.age"

# 6. Public-safe : le script + README générés ne contiennent AUCUNE ref perso/client
if grep -riE "tanfeuille|spinex|trimat|fulll|feedback_|ratatoskr/claude-memory" "$BOOT" "$SANDBOX/m2/README.md" >/dev/null 2>&1; then
  ko "FUITE : ref perso/client dans le script ou le README généré"
  grep -rinE "tanfeuille|spinex|trimat|fulll|feedback_" "$BOOT" "$SANDBOX/m2/README.md" | sed 's/^/      /'
else
  ok "public-safe : aucune ref perso/client"
fi

# 7. profil par défaut résolu depuis DEV_PERSONAL_REPO (env) si pas de --remote
out7="$(DEV_PERSONAL_REPO=envdev/env-mirror bash "$BOOT" --apply --dir "$SANDBOX/m7" 2>&1)"; rc7=$?
[ "$rc7" -eq 0 ] && [ -f "$SANDBOX/m7/claude-memory/.gitkeep" ] && ok "lit DEV_PERSONAL_REPO de l'env" || ko "n'a pas lu DEV_PERSONAL_REPO env (rc=$rc7)"

echo ""
echo "=== Bilan : $pass OK / $fail KO ==="
[ "$fail" -eq 0 ]
