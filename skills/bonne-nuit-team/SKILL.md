---
tier: shared
name: bonne-nuit-team
description: 'Fin de session dev WinCorp (équipe) : scan modifs + tests + commit Conventional Commits FR + push (avec confirmation). Invoquer via /bonne-nuit-team. Use: bonne nuit team, fin de session équipe, team end of day, on clôture la journée.'
---

# Bonne nuit (équipe) — Fin de session dev WinCorp

Rituel **léger et générique** de fin de session : repère les repos modifiés, lance les tests des repos touchés, puis commit + push **avec confirmation**. Aucune dépendance à une mémoire ou config personnelle.

> Il existe une variante personnelle `/bonne-nuit` (mémoire, dashboard, vault, secrets) propre au mainteneur. Cette version `-team` ne couvre **que** le noyau partagé. Elle **ne touche jamais `wincorp-garm`** (coffre de secrets, lecture seule côté dev — la rotation est un acte délibéré du mainteneur). Invoquer explicitement via `/bonne-nuit-team`.

## CRITICAL RULES

- MANDATORY : exécuter les étapes DANS L'ORDRE.
- **Confirmation explicite avant commit ET avant push** — jamais d'écriture distante implicite.
- Conventional Commits en français : `feat(scope): …`, `fix(scope): …`, `docs: …`, `chore: …`. 1 commit = 1 changement logique.
- Jamais `git push --force`. Jamais `git add` d'un `.env`, d'une clé ou d'un token.
- **Ne jamais committer/pousser `wincorp-garm`** (coffre secrets — exclu des boucles).
- Un test qui échoue se corrige **avant** le commit (« Fait » = vérifié).
- Respecter `.claude/rules/05-skill-writing.md` avant toute modification de cette skill.

## INITIALIZATION

- `WORKSPACE` = `$HOME/Documents/wincorp-workspace`
- `date` = système

## EXECUTION

### Étape 1 — Scanner les repos modifiés

`wincorp-garm` est exclu d'office (coffre secrets, D6).

```bash
WORKSPACE="$HOME/Documents/wincorp-workspace"
echo "=== Bonne nuit équipe — scan des repos modifiés ==="
if ! command -v git >/dev/null 2>&1; then
  echo "  ✗ git introuvable dans le PATH — rien à faire."; exit 0
fi
cd "$WORKSPACE" 2>/dev/null || { echo "  ✗ $WORKSPACE introuvable"; exit 0; }
shopt -s nullglob
modified=0
# 2>/dev/null sur git status : silence le bruit si un dossier wincorp-* n'est pas un repo propre.
for repo in wincorp-*/; do
  [ -d "$repo/.git" ] || continue
  [ "${repo%/}" = "wincorp-garm" ] && continue   # coffre secrets, lecture seule côté dev (D6)
  if [ -n "$(git -C "$repo" status --short 2>/dev/null)" ]; then
    modified=$((modified + 1))
    echo "  ● ${repo%/} :"
    git -C "$repo" status --short 2>/dev/null | sed 's/^/      /'
  fi
done
shopt -u nullglob
[ "$modified" -eq 0 ] && echo "  Aucun repo modifié — rien à committer."
```

### Étape 2 — Tests des repos modifiés (pré-checks dette-zero)

Pour chaque repo modifié, lancer les tests si un harnais est détecté. Chaque binaire externe est pré-vérifié (`command -v`) et l'**exit code réel** est capturé (`PIPESTATUS`) — un test rouge est signalé explicitement.

```bash
WORKSPACE="$HOME/Documents/wincorp-workspace"
echo ""
echo "=== Tests des repos modifiés ==="
cd "$WORKSPACE" 2>/dev/null || exit 0
shopt -s nullglob
# 2>/dev/null sur git status : silence le bruit sur un dossier non-repo.
for repo in wincorp-*/; do
  [ -d "$repo/.git" ] || continue
  [ "${repo%/}" = "wincorp-garm" ] && continue   # coffre secrets (D6)
  [ -n "$(git -C "$repo" status --short 2>/dev/null)" ] || continue
  name="${repo%/}"; rc=0
  # Détection JS : clé "test" stricte (évite faux positif "testimonials"/"test-suite").
  if [ -f "$repo/package.json" ] && grep -qE '"test"[[:space:]]*:' "$repo/package.json" 2>/dev/null; then
    if command -v pnpm >/dev/null 2>&1; then
      echo "  → $name : pnpm test"; ( cd "$repo" && pnpm test ) 2>&1 | tail -15; rc=${PIPESTATUS[0]}
    elif command -v npm >/dev/null 2>&1; then
      echo "  → $name : npm test"; ( cd "$repo" && npm test ) 2>&1 | tail -15; rc=${PIPESTATUS[0]}
    else
      echo "  [skip-anomalie] $name : test JS détecté mais ni pnpm ni npm installé"; continue
    fi
  elif [ -f "$repo/pyproject.toml" ] || [ -f "$repo/pytest.ini" ] || [ -d "$repo/tests" ]; then
    if command -v pytest >/dev/null 2>&1; then
      echo "  → $name : pytest"; ( cd "$repo" && pytest -q ) 2>&1 | tail -15; rc=${PIPESTATUS[0]}
    else
      echo "  [skip-attendu] $name : tests python détectés mais pytest absent (pip install pytest)"; continue
    fi
  else
    echo "  = $name : pas de harnais de test détecté"; continue
  fi
  [ "$rc" -ne 0 ] && echo "  ✗ $name : TESTS ROUGES (rc=$rc) — corriger AVANT de committer"
done
shopt -u nullglob
```

### Étape 3 — Commit (confirmation) puis Push (confirmation)

Pour **chaque** repo modifié (hors `wincorp-garm`), un à la fois :
1. Lire `git -C <repo> diff --stat` + `git -C <repo> status --short` pour comprendre les changements réels.
2. Proposer un message Conventional Commits FR adapté.
3. **Demander confirmation du message** à l'utilisateur.
4. `git add -A` puis vérifier qu'aucun `.env`/clé/token n'est staged (`git -C <repo> diff --cached --name-only`) — si oui, désindexer et alerter, ne jamais committer un secret.
5. Committer.
6. **Demander confirmation avant le push.**
7. Pousser.

Modèle (à adapter par repo — ne pas exécuter en boucle aveugle) :

```bash
# cd "$HOME/Documents/wincorp-workspace/<repo>"
# git diff --stat && git status --short          # comprendre les changements
# git add -A
# git diff --cached --name-only | grep -E '\.(env|key|pem|p12|pfx|secret)$' && echo "STOP: secret staged" 
# git commit -m "feat(<scope>): <description en français>"
# git push
```

Jamais `--force`. Jamais committer `wincorp-garm`.

### Étape 4 — Checklist de sortie

Lister chaque repo modifié avec son statut : tests `OK / ROUGE / skip`, commit `OK / —`, push `OK / —`. Signaler explicitement tout repo laissé non commité (travail en cours volontaire). Aucun statut omis.
