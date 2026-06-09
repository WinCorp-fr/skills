#!/usr/bin/env bash
# bootstrap-personal-mirror.sh — crée le dépôt miroir PERSONNEL d'un développeur WinCorp.
#
# Chaque dev possède un dépôt privé qui sauvegarde et synchronise multi-PC SA mémoire et SA
# config Claude Code (jamais celle d'un autre dev). Ce script crée la structure d'accueil,
# de façon générique et idempotente. Il est volontairement AUTONOME (aucune dépendance aux
# helpers _lib perso, qui ne sont pas livrés aux devs d'équipe) et PUBLIC-SAFE (aucune
# référence client/perso : il lit le nom du dépôt dans le profil d'identité local).
#
# Usage (depuis le clone wincorp-skills/ ou ~/.claude/skills/) :
#   bash bootstrap-personal-mirror.sh                       # DRY-RUN : montre le plan
#   bash bootstrap-personal-mirror.sh --apply               # crée la structure locale + commit
#   bash bootstrap-personal-mirror.sh --apply --push        # + crée le dépôt distant privé et pousse
#   bash bootstrap-personal-mirror.sh --remote me/mon-repo --apply   # dépôt explicite
#   bash bootstrap-personal-mirror.sh --dir /tmp/x --apply  # dossier local explicite (tests)
#
# Le dépôt perso est résolu, par priorité : --remote  >  $DEV_PERSONAL_REPO  >  ~/.claude/profile.env
# Aucun défaut : un dev DOIT déclarer son dépôt (DEV_PERSONAL_REPO=owner/nom dans son profil).
#
# Frontière (non négociable) : ce dépôt est strictement personnel. Jamais de donnée client,
# jamais de secret en clair (le .gitignore généré protège en défense-en-profondeur).

set -euo pipefail

APPLY=0; PUSH=0; REMOTE=""; DIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --apply)  APPLY=1 ;;
    --push)   PUSH=1 ;;
    --remote) REMOTE="${2:-}"; shift ;;
    --dir)    DIR="${2:-}"; shift ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "✗ argument inconnu : $1" >&2; exit 2 ;;
  esac
  shift
done

# Lecteur d'une clé du profil d'identité local (\042 = guillemet, \047 = apostrophe, strip des quotes).
_pf() { grep -E "^$1=" "$HOME/.claude/profile.env" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\042\047'; }

# --- Résolution du dépôt perso (priorité : --remote > env > profil) ---
[ -z "$REMOTE" ] && REMOTE="${DEV_PERSONAL_REPO:-}"
[ -z "$REMOTE" ] && REMOTE="$(_pf DEV_PERSONAL_REPO)"
if [ -z "$REMOTE" ]; then
  echo "✗ Aucun dépôt perso déclaré." >&2
  echo "  Renseigne DEV_PERSONAL_REPO=owner/nom dans ~/.claude/profile.env," >&2
  echo "  ou passe --remote owner/nom. (Cf guide onboarding-dev.)" >&2
  exit 1
fi

NAME="${REMOTE##*/}"   # segment après le dernier / (owner/nom -> nom ; nom seul -> nom)
case "$REMOTE" in */*) ;; *) echo "  ⚠ dépôt '$REMOTE' sans '/' — format attendu owner/nom (gh résoudra sur ton compte)." ;; esac
[ -z "$DIR" ] && DIR="$HOME/Documents/wincorp-workspace/$NAME"

echo "=== bootstrap miroir perso ==="
echo "  Dépôt  : $REMOTE"
echo "  Dossier: $DIR"
echo "  Mode   : $([ "$APPLY" -eq 1 ] && echo APPLY || echo 'DRY-RUN (simulation)')$([ "$PUSH" -eq 1 ] && echo ' +PUSH')"

# Structure cible (équivalent générique du dépôt perso du mainteneur).
# LEAK-SCAN-IGNORE sur la 1re entrée : "claude-memory" est ici un nom de dossier CRÉÉ
# (structure générique du miroir), pas une lecture du tier perso d'un autre dev — exception
# auditée du scanner frontière (cf ci/leak-scan.sh:91 grep -v IGNORE_MARK, revue 2026-06-09).
SUBDIRS=(
  "claude-memory"  # LEAK-SCAN-IGNORE: nom de structure générique (création), pas lecture tier perso
  "claude-global"
  ".claude/skills-snapshot"
  ".claude/agents-snapshot"
  ".claude/hooks-snapshot"
  ".claude/plans-snapshot"
  ".claude/scheduled-tasks-snapshot"
)

if [ "$APPLY" -eq 0 ]; then
  echo ""
  echo "  [DRY-RUN] Seraient créés (rien n'est écrit) :"
  for d in "${SUBDIRS[@]}"; do echo "    $DIR/$d/.gitkeep"; done
  echo "    $DIR/.gitignore   $DIR/README.md   (+ git init + commit initial)"
  [ "$PUSH" -eq 1 ] && echo "    + dépôt distant privé $REMOTE (gh repo create) + push"
  echo "  → Relance avec --apply pour créer."
  exit 0
fi

# --- APPLY : créer la structure (idempotent) ---
mkdir -p "$DIR"
created=0
for d in "${SUBDIRS[@]}"; do
  if [ ! -f "$DIR/$d/.gitkeep" ]; then
    mkdir -p "$DIR/$d"; : > "$DIR/$d/.gitkeep"; created=$((created+1))
  fi
done

if [ ! -f "$DIR/.gitignore" ]; then
  cat > "$DIR/.gitignore" <<'GI'
# Secrets — JAMAIS dans un miroir perso (défense en profondeur, cf coffre garm pour les secrets).
keys.txt
*.age
*.key
*.pem
*.p12
*.pfx
*.secret
*.jks
*.kdbx
id_rsa*
.env
.env.*
.envrc
*.tfvars
credentials*.json
secrets-bootstrap/
# Denylist locale éventuelle de noms (jamais versionnée).
**/leak-patterns.local.txt
.local-patterns.txt
GI
  created=$((created+1))
fi

if [ ! -f "$DIR/README.md" ]; then
  cat > "$DIR/README.md" <<'RM'
# Miroir personnel Claude Code

Dépôt **privé personnel** d'un développeur WinCorp. Sauvegarde et synchronise multi-PC,
dans des dossiers dédiés :

- la **mémoire** Claude Code (notes de session, état projet, apprentissages personnels) ;
- la **config globale** (CLAUDE.md, settings, dotfiles) ;
- les **snapshots runtime** (skills personnels, agents, hooks, plans).

## Frontière — non négociable

Ce dépôt est **strictement personnel et privé**. Il ne doit JAMAIS contenir :

- de donnée client (noms, SIREN, dossiers) — secret professionnel ;
- de secret en clair (clés, tokens, `.env`) — voir `.gitignore`.

## Cycle

Géré automatiquement par les rituels d'équipe :

- `/bonjour-team` — restaure mémoire + config depuis ce dépôt au début de session ;
- `/bonne-nuit-team` — sauvegarde mémoire + config vers ce dépôt en fin de session.

Créé par `bootstrap-personal-mirror.sh` (dépôt partagé `WinCorp-fr/skills`).
RM
  created=$((created+1))
fi

if [ ! -d "$DIR/.git" ]; then
  git -C "$DIR" init -q
  git -C "$DIR" symbolic-ref HEAD refs/heads/main 2>/dev/null || true
fi

# Identité du commit : config existante > profil > fallback neutre (pour sandbox/CI).
c_name="$(git -C "$DIR" config user.name 2>/dev/null || true)"
c_mail="$(git -C "$DIR" config user.email 2>/dev/null || true)"
[ -z "$c_name" ] && c_name="${DEV_NAME:-$(_pf DEV_NAME)}"; [ -z "$c_name" ] && c_name="wincorp-dev"
[ -z "$c_mail" ] && c_mail="${DEV_EMAIL_WINCORP:-$(_pf DEV_EMAIL_WINCORP)}"; [ -z "$c_mail" ] && c_mail="dev@wincorp.local"

git -C "$DIR" add -A
if ! git -C "$DIR" diff --cached --quiet 2>/dev/null; then
  git -C "$DIR" -c user.name="$c_name" -c user.email="$c_mail" \
    commit -q -m "chore(mirror): structure initiale du miroir perso

Créé par bootstrap-personal-mirror.sh (Phase C sync multi-dev)."
  echo "  ✓ commit initial ($created élément(s) créé(s))"
else
  echo "  = déjà à jour (idempotent, rien à committer)"
fi

# --- PUSH (outward-facing, opt-in explicite) ---
if [ "$PUSH" -eq 1 ]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "  ⚠ gh CLI absent — push manuel requis : créer le dépôt privé $REMOTE puis 'git push -u origin main'."
  else
    # Capturer le code retour AVANT le pipe `tail` (sinon l'échec est masqué — bug HIGH 2026-06-09).
    if gh repo view "$REMOTE" >/dev/null 2>&1; then
      git -C "$DIR" remote get-url origin >/dev/null 2>&1 || git -C "$DIR" remote add origin "https://github.com/$REMOTE.git"
      push_out="$(git -C "$DIR" push -u origin main 2>&1)"; push_rc=$?
    else
      echo "  → création du dépôt distant PRIVÉ $REMOTE + push…"
      push_out="$(cd "$DIR" && gh repo create "$REMOTE" --private --source=. --remote=origin --push 2>&1)"; push_rc=$?
    fi
    echo "$push_out" | tail -3 | sed 's/^/    /'
    if [ "$push_rc" -eq 0 ]; then
      echo "  ✓ dépôt distant prêt : $REMOTE (privé)"
    else
      echo "  ✗ création/push distant ÉCHOUÉ (rc=$push_rc) — voir ci-dessus ; le miroir local reste valide."
    fi
  fi
else
  echo "  (push non demandé — relance avec --push pour créer/pousser le dépôt distant privé)"
fi

echo "  Miroir perso prêt : $DIR"
