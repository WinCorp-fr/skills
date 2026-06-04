#!/usr/bin/env bash
# run-tests.sh — self-check de leak-scan.sh sur un corpus synthetique.
# Donnees 100% FICTIVES (SIREN 123456789, nom de demo ZZ-CLIENT-DEMO-ZZ ; jamais un vrai client/nom).
# Construit un arbre temporaire et verifie : skills propres -> exit 0 ; toute fuite -> exit 2.
# Teste AUSSI le mecanisme de denylist locale via une taxonomie locale synthetique (LEAK_LOCAL_PATTERNS).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCAN="$HERE/../leak-scan.sh"
ROOT="$(mktemp -d 2>/dev/null || echo "/tmp/leakscan.$$")"; mkdir -p "$ROOT"
trap 'rm -rf "$ROOT"' EXIT
PASSED=0; FAILED=0

# Denylist locale SYNTHETIQUE (teste le mecanisme sans aucun nom reel dans ce depot public)
export LEAK_LOCAL_PATTERNS="$ROOT/.local-patterns.txt"
printf 'demo-client|||ZZ-CLIENT-DEMO-ZZ\n' > "$LEAK_LOCAL_PATTERNS"

run_case() {  # $1=nom $2=relpath $3=exit_attendu ; contenu sur stdin
  local name="$1" rel="$2" want="$3"
  mkdir -p "$ROOT/$(dirname "$rel")"
  cat > "$ROOT/$rel"
  local got; ( cd "$ROOT" && bash "$SCAN" --files "$rel" ) >/dev/null 2>&1; got=$?
  if [ "$got" -eq "$want" ]; then
    printf '  PASS  %-18s (exit %s)\n' "$name" "$got"; PASSED=$((PASSED + 1))
  else
    printf '  FAIL  %-18s (attendu %s, obtenu %s)\n' "$name" "$want" "$got"; FAILED=$((FAILED + 1))
  fi
}

echo "=== leak-scan self-check (corpus synthetique) ==="

# --- Doivent PASSER (exit 0) ---
run_case clean-skill "skills/clean/SKILL.md" 0 <<'EOF'
---
name: clean
tier: shared
---
# Clean
Process de dev generique, aucun marqueur confidentiel.
EOF

run_case readme-meta "README.md" 0 <<'EOF'
# WinCorp skills
Depot des skills de process partages de l'equipe.
EOF

run_case ignore-hatch "skills/doc/SKILL.md" 0 <<'EOF'
---
name: doc
tier: shared
---
# Doc
Exemple documente d'un chemin neutralise /Users/Tanfeuille/x LEAK-SCAN-IGNORE
EOF

# --- Doivent ETRE BLOQUES (exit 2) ---
run_case missing-tier "skills/notier/SKILL.md" 2 <<'EOF'
---
name: notier
---
# Sans tier
Deny-by-default : pas de tier shared.
EOF

run_case tier-client "skills/cli/SKILL.md" 2 <<'EOF'
---
name: cli
tier: client
---
# Client
EOF

run_case siren-9 "skills/s1/SKILL.md" 2 <<'EOF'
---
name: s1
tier: shared
---
Dossier fictif SIREN 123456789 a ne pas laisser passer.
EOF

run_case siren-separe "skills/s2/SKILL.md" 2 <<'EOF'
---
name: s2
tier: shared
---
Numero fictif 123 456 789 separe par espaces.
EOF

run_case local-name "skills/ln/SKILL.md" 2 <<'EOF'
---
name: ln
tier: shared
---
Reference a un nom via la denylist locale : ZZ-CLIENT-DEMO-ZZ.
EOF

run_case perso-path "skills/pp/SKILL.md" 2 <<'EOF'
---
name: pp
tier: shared
---
Chemin perso /Users/Tanfeuille/Documents/x en dur.
EOF

run_case feedback-ref "skills/fb/SKILL.md" 2 <<'EOF'
---
name: fb
tier: shared
---
Voir feedback_robust_over_temporary en memoire.
EOF

run_case nonmd-csv "skills/data/extra.csv" 2 <<'EOF'
col1,col2
1,2
EOF

run_case filename-siren "skills/x/report-123456789.md" 2 <<'EOF'
---
name: x
tier: shared
---
# Contenu propre, mais le NOM de fichier encode un SIREN.
EOF

echo ""
echo "=== Resultat : $PASSED OK / $FAILED FAIL ==="
[ "$FAILED" -eq 0 ] || { echo "SELF-CHECK ECHOUE"; exit 1; }
echo "SELF-CHECK OK"
exit 0
