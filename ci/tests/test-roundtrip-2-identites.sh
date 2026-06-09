#!/usr/bin/env bash
# Test DÉCISIF (Phase C, plan §176) — round-trip 2 identités en HOME jetable, sans GitHub réel.
# Prouve la frontière : Fhosty synchronise vers SON miroir privé, jamais le ratatoskr de Tan,
# jamais le vault ; ses commits portent SON identité ; un round-trip 2-PC transporte sa mémoire.
# Mock `gh repo clone` + remotes bare locaux. Lance : bash ci/tests/test-roundtrip-2-identites.sh
#
# (Fichier sous ci/ = exclu du leak-scan : il peut nommer ratatoskr/tanfeuille pour les asserts.)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
BOOT="$REPO/bootstrap-personal-mirror.sh"
PS="$REPO/personal-sync.sh"

pass=0; fail=0
ok() { echo "  ✓ $1"; pass=$((pass+1)); }
ko() { echo "  ✗ $1"; fail=$((fail+1)); }

SANDBOX="$(mktemp -d)"; trap 'rm -rf "$SANDBOX"' EXIT
export MOCK_REMOTES="$SANDBOX/remotes"

# --- Remote bare "fhosty/wincorp-ratatoskr-perso" (faux GitHub) ---
mkdir -p "$MOCK_REMOTES/fhosty"
git init --bare -q "$MOCK_REMOTES/fhosty/wincorp-ratatoskr-perso.git"

# --- Mock gh (clone/view depuis les remotes bare locaux) ---
mkdir -p "$SANDBOX/bin"
cat > "$SANDBOX/bin/gh" <<'GH'
#!/usr/bin/env bash
if [ "$1" = "repo" ] && [ "$2" = "clone" ]; then
  git clone -q "file://$MOCK_REMOTES/$3.git" "$4"; exit $?
fi
if [ "$1" = "repo" ] && [ "$2" = "view" ]; then
  [ -d "$MOCK_REMOTES/$3.git" ] && exit 0 || exit 1
fi
exit 0
GH
chmod +x "$SANDBOX/bin/gh"
export PATH="$SANDBOX/bin:$PATH"

profile() {  # $1 = home dir
  mkdir -p "$1/.claude"
  cat > "$1/.claude/profile.env" <<EOF
DEV_NAME=fhosty
DEV_EMAIL_WINCORP=fhosty@example.test
DEV_TIERS=shared,personal
DEV_PERSONAL_REPO=fhosty/wincorp-ratatoskr-perso
HAS_ACCESS_GARM=true
HAS_ACCESS_VAULT=false
EOF
}

echo "=== ROUND-TRIP 2 identités (frontière Fhosty ⟂ Tan) ==="

# ============ PC1 (Fhosty machine 1) ============
H1="$SANDBOX/pc1"; mkdir -p "$H1/Documents/wincorp-workspace"; profile "$H1"
P1="$H1/.claude/projects/C--Users-fhosty-Documents-wincorp-workspace/memory"
mkdir -p "$P1"; printf 'note de session Fhosty PC1\n' > "$P1/session-fhosty.md"

# bootstrap miroir (résolution HOME) + branchement du remote bare + seed
HOME="$H1" bash "$BOOT" --apply >/dev/null 2>&1
MIR1="$H1/Documents/wincorp-workspace/wincorp-ratatoskr-perso"
[ -d "$MIR1/.git" ] && ok "PC1: bootstrap a créé le miroir (résolu depuis HOME+profil)" || ko "PC1: miroir non créé"
git -C "$MIR1" remote add origin "file://$MOCK_REMOTES/fhosty/wincorp-ratatoskr-perso.git"
git -C "$MIR1" push -u origin main -q 2>/dev/null && ok "PC1: seed du remote bare" || ko "PC1: seed remote KO"

# /bonne-nuit-team backup (mémoire -> miroir -> push)
out_b="$(HOME="$H1" bash "$PS" --backup 2>&1)"
echo "$out_b" | grep -q "wincorp-ratatoskr-perso" && ok "PC1: backup cible le miroir perso de Fhosty" || ko "PC1: backup mauvaise cible"
[ -f "$MIR1/claude-memory/wincorp-workspace/session-fhosty.md" ] && ok "PC1: mémoire copiée dans le miroir" || ko "PC1: mémoire absente du miroir"
# Commit identité = Fhosty (pas de git config dans la sandbox -> doit lire le profil)
ae="$(git -C "$MIR1" log -1 --format='%ae' 2>/dev/null)"
[ "$ae" = "fhosty@example.test" ] && ok "PC1: commit authored = dev ($ae)" || ko "PC1: commit authored = '$ae' (attendu fhosty@example.test)"

# ============ Sentinelle Tan (doit rester INTOUCHÉE) ============
TANSENT="$SANDBOX/tan-sentinel/wincorp-ratatoskr/claude-memory/wincorp-workspace"
mkdir -p "$TANSENT"; printf 'SENTINELLE-NON-CLIENT (miroir du mainteneur, doit rester intouche)\n' > "$TANSENT/etat_courant.md"
TAN_SUM_BEFORE="$(cd "$SANDBOX/tan-sentinel" && find . -type f -exec sha1sum {} \; | sort)"

# ============ PC2 (Fhosty machine 2, fraîche) ============
H2="$SANDBOX/pc2"; mkdir -p "$H2/Documents/wincorp-workspace"; profile "$H2"
# Slug projet présent (créé par Claude Code à l'ouverture), mémoire vide
P2="$H2/.claude/projects/C--Users-fhosty-Documents-wincorp-workspace/memory"; mkdir -p "$P2"
# /bonjour-team restore : miroir absent -> gh mock clone -> pull -> restore
out_r="$(HOME="$H2" bash "$PS" --restore 2>&1)"
MIR2="$H2/Documents/wincorp-workspace/wincorp-ratatoskr-perso"
[ -d "$MIR2/.git" ] && ok "PC2: miroir cloné (via gh mock)" || ko "PC2: clone KO"
[ -f "$P2/session-fhosty.md" ] && grep -q "Fhosty PC1" "$P2/session-fhosty.md" \
  && ok "PC2: ROUND-TRIP OK — mémoire PC1 restaurée sur PC2" || ko "PC2: round-trip cassé (mémoire non restaurée)"

# ============ ASSERTIONS FRONTIÈRE ============
# 1. Sentinelle Tan intouchée
TAN_SUM_AFTER="$(cd "$SANDBOX/tan-sentinel" && find . -type f -exec sha1sum {} \; | sort)"
[ "$TAN_SUM_BEFORE" = "$TAN_SUM_AFTER" ] && ok "FRONTIÈRE: ratatoskr de Tan (sentinelle) intouché" || ko "FRONTIÈRE VIOLÉE: sentinelle Tan modifiée"
# 2. La mémoire de Fhosty n'a JAMAIS atterri chez Tan
if grep -rq "Fhosty PC1" "$SANDBOX/tan-sentinel" 2>/dev/null; then ko "FRONTIÈRE VIOLÉE: mémoire Fhosty trouvée chez Tan"; else ok "FRONTIÈRE: mémoire Fhosty absente de chez Tan"; fi
# 3. Aucun vault touché (HAS_ACCESS_VAULT=false ; le flux -team ne pull pas le vault)
if find "$H1" "$H2" -path '*wincorp-vault*' 2>/dev/null | grep -q .; then ko "FRONTIÈRE: un vault a été créé (interdit)"; else ok "FRONTIÈRE: aucun vault touché (vault=false respecté)"; fi
# 4. Le push de Fhosty est allé vers SON bare, pas ailleurs
( cd "$MOCK_REMOTES/fhosty/wincorp-ratatoskr-perso.git" && git log --all --format='%ae' 2>/dev/null | grep -q "fhosty@example.test" ) \
  && ok "FRONTIÈRE: remote bare de Fhosty contient SES commits" || ko "remote bare Fhosty vide/incorrect"

# 5. Backward-compat Tan (résolveur _lib, si présent sur cette machine)
RP="$HOME/.claude/skills/_lib/resolve-paths.sh"
if [ -f "$RP" ]; then
  d="$( unset DEV_PERSONAL_REPO; . "$RP"; DEV_PERSONAL_REPO=tanfeuille/wincorp-ratatoskr; resolve_personal_dir )"
  case "$d" in
    */wincorp-ratatoskr) ok "Backward-compat: Tan résout vers wincorp-ratatoskr (pas -perso)";;
    *) ko "Backward-compat KO: Tan résout vers '$d'";;
  esac
else
  echo "  ~ [skip] _lib/resolve-paths.sh absent (CI) — assert backward-compat Tan ignoré"
fi

echo ""
echo "=== Bilan round-trip : $pass OK / $fail KO ==="
[ "$fail" -eq 0 ]
