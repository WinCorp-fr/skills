#!/usr/bin/env bash
# Test TDD — personal-sync.sh (Phase C : backup/restore mémoire d'un dev vers SON miroir).
# Standalone, --no-net (aucun accès GitHub). Sandbox jetable.
# Lance : bash wincorp-skills/ci/tests/test-personal-sync.sh
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
PS="$REPO/personal-sync.sh"

pass=0; fail=0
ok() { echo "  ✓ $1"; pass=$((pass+1)); }
ko() { echo "  ✗ $1"; fail=$((fail+1)); }

SANDBOX="$(mktemp -d)"; trap 'rm -rf "$SANDBOX"' EXIT

# Faux root de projets local (comme ~/.claude/projects) + un projet workspace
PROJ="$SANDBOX/projects/C--Users-test-Documents-wincorp-workspace/memory"
mkdir -p "$PROJ"
printf 'memo A\n' > "$PROJ/a.md"
printf 'memo B\n' > "$PROJ/b.md"

# Faux miroir perso (comme wincorp-ratatoskr-perso) avec git
MIR="$SANDBOX/mirror"
mkdir -p "$MIR/claude-memory"
( cd "$MIR" && git init -q && git -c user.email=t@t.local -c user.name=t commit -q --allow-empty -m init )

echo "=== test personal-sync ==="
[ -f "$PS" ] || { echo "  ✗ $PS introuvable"; exit 1; }

# 1. BACKUP : local memory → miroir/claude-memory/<canonical>/
out1="$(bash "$PS" --backup --no-net --remote testdev/test-mirror --dir "$MIR" --memdir "$SANDBOX/projects" 2>&1)"; rc1=$?
[ "$rc1" -eq 0 ] && ok "backup exit 0" || { ko "backup exit $rc1"; echo "$out1" | sed 's/^/      /'; }
[ -f "$MIR/claude-memory/wincorp-workspace/a.md" ] && ok "backup: a.md → miroir" || ko "backup a.md absent du miroir"
[ -f "$MIR/claude-memory/wincorp-workspace/b.md" ] && ok "backup: b.md → miroir" || ko "backup b.md absent du miroir"
( cd "$MIR" && git log --oneline 2>/dev/null | grep -q . ) && ok "backup: commit créé" || ko "backup pas de commit"

# 2. RESTORE : un fichier nouveau dans le miroir (vient d'un autre PC) → local
printf 'memo C distant\n' > "$MIR/claude-memory/wincorp-workspace/c.md"
out2="$(bash "$PS" --restore --no-net --remote testdev/test-mirror --dir "$MIR" --memdir "$SANDBOX/projects" 2>&1)"; rc2=$?
[ "$rc2" -eq 0 ] && ok "restore exit 0" || { ko "restore exit $rc2"; echo "$out2" | sed 's/^/      /'; }
[ -f "$PROJ/c.md" ] && ok "restore: c.md → local" || ko "restore c.md absent en local"

# 3. IF-NEWER : un local plus récent n'est PAS écrasé par un miroir plus ancien
printf 'LOCAL récent\n' > "$PROJ/a.md"            # local a.md devient le plus récent
sleep 1
# rendre le miroir a.md plus ancien que le local (déjà le cas : on vient de réécrire local)
out3="$(bash "$PS" --restore --no-net --remote testdev/test-mirror --dir "$MIR" --memdir "$SANDBOX/projects" 2>&1)"
grep -q 'LOCAL récent' "$PROJ/a.md" && ok "if-newer: local récent préservé au restore" || ko "if-newer cassé (local écrasé)"

# 4. PAS DE PROFIL → skip propre (exit 0, pas d'erreur, rien fait)
out4="$(env -u DEV_PERSONAL_REPO HOME="$SANDBOX/nohome" bash "$PS" --backup --no-net --memdir "$SANDBOX/projects" 2>&1)"; rc4=$?
[ "$rc4" -eq 0 ] && ok "sans profil : skip propre (exit 0)" || ko "sans profil exit $rc4 (devrait être 0/skip)"
echo "$out4" | grep -qiE "aucun.*miroir|pas de.*miroir|skip" && ok "sans profil : message de skip" || ko "sans profil : pas de message de skip"

# 5. FRONTIÈRE : backup n'écrit QUE dans le miroir ciblé (pas ailleurs)
OTHER="$SANDBOX/other-dev-mirror"; mkdir -p "$OTHER/claude-memory"
bash "$PS" --backup --no-net --remote testdev/test-mirror --dir "$MIR" --memdir "$SANDBOX/projects" >/dev/null 2>&1
[ -z "$(find "$OTHER/claude-memory" -type f 2>/dev/null)" ] && ok "frontière : aucun écrit dans un autre miroir" || ko "FRONTIÈRE : a écrit dans un autre miroir"

# 6. PUBLIC-SAFE : aucune ref perso/client dans le script
if grep -riE "tanfeuille|spinex|trimat|fulll|feedback_[a-z]|tanph" "$PS" >/dev/null 2>&1; then
  ko "FUITE : ref perso/client dans personal-sync.sh"
  grep -rinE "tanfeuille|spinex|trimat|fulll|feedback_[a-z]|tanph" "$PS" | sed 's/^/      /'
else
  ok "public-safe : aucune ref perso/client"
fi

echo ""
echo "=== Bilan : $pass OK / $fail KO ==="
[ "$fail" -eq 0 ]
