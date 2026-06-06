---
tier: shared
name: bonjour-team
description: 'Début de session dev WinCorp (équipe) : pull des repos clonés + check secrets partagés + état git. Invoquer via /bonjour-team. Use: bonjour team, début de session équipe, team daily start, on démarre la journée.'
---

# Bonjour (équipe) — Début de session dev WinCorp

Rituel **léger et générique** de début de session pour tout dev WinCorp. Met à jour les repos clonés localement, vérifie les secrets partagés, et affiche un état des lieux git. Aucune dépendance à une mémoire ou config personnelle.

> Il existe une variante personnelle `/bonjour` (mémoire, vault, configs perso du mainteneur). Cette version `-team` ne couvre **que** le noyau partagé utile à tous. Invoquer explicitement via `/bonjour-team`.

## CRITICAL RULES

- MANDATORY : exécuter les étapes DANS L'ORDRE.
- Lecture seule : **aucun commit ni push** ici (c'est le rôle de `/bonne-nuit-team`).
- Jamais de `git pull` sur un repo aux modifs locales non commitées → signaler et passer au suivant.
- Aucun secret en clair n'est manipulé : on appelle le script du coffre, on ne lit jamais une valeur déchiffrée.
- Respecter `.claude/rules/05-skill-writing.md` avant toute modification de cette skill.

## INITIALIZATION

- `WORKSPACE` = `$HOME/Documents/wincorp-workspace` (racine où sont clonés les repos `wincorp-*`)
- `date` = système

## EXECUTION

### Étape 1 — Pull de tous les repos clonés

Parcourir les dossiers `wincorp-*/` du workspace et faire un `git pull --ff-only` sur ceux qui sont propres. Le résultat est jugé sur l'**exit code** + comparaison de SHA (robuste, indépendant de la locale git).

```bash
WORKSPACE="$HOME/Documents/wincorp-workspace"
echo "=== Bonjour équipe — pull des repos WinCorp ($(date '+%Y-%m-%d %H:%M')) ==="
if ! command -v git >/dev/null 2>&1; then
  echo "  ✗ git introuvable dans le PATH — installer git puis rouvrir le terminal."
elif [ ! -d "$WORKSPACE" ]; then
  echo "  ✗ $WORKSPACE introuvable — cloner les repos sous ce dossier (cf guide onboarding-dev)."
else
  cd "$WORKSPACE" || exit 0
  shopt -s nullglob
  # 2>/dev/null sur git status : silence le bruit si un dossier wincorp-* n'est pas un repo propre.
  for repo in wincorp-*/; do
    [ -d "$repo/.git" ] || continue
    name="${repo%/}"
    if [ -n "$(git -C "$repo" status --short 2>/dev/null)" ]; then
      echo "  ~ $name : modifs locales → [skip-attendu] pull (commiter d'abord via /bonne-nuit-team)"
    else
      before=$(git -C "$repo" rev-parse HEAD 2>/dev/null)
      if git -C "$repo" pull --ff-only >/dev/null 2>&1; then
        after=$(git -C "$repo" rev-parse HEAD 2>/dev/null)
        if [ "$before" = "$after" ]; then echo "  = $name : à jour"; else echo "  ✓ $name : mis à jour"; fi
      else
        echo "  ✗ $name : pull échoué (pas d'upstream, detached HEAD, ou non fast-forward) — à vérifier"
      fi
    fi
  done
  shopt -u nullglob
fi
```

### Étape 2 — Secrets partagés (coffre garm) — vérification lecture seule

Si le coffre `wincorp-garm` est cloné et la clé age présente, pull + `--self-check` (ne modifie rien). On **n'applique pas** automatiquement (le déploiement reste un acte explicite).

```bash
WORKSPACE="$HOME/Documents/wincorp-workspace"
GARM="$WORKSPACE/wincorp-garm"
echo ""
echo "=== Secrets partagés (garm) ==="
if [ -d "$GARM/.git" ]; then
  git -C "$GARM" pull --ff-only 2>&1 | tail -1   # tail -1 : ne garder que la ligne de résultat du pull
  if [ -f "$GARM/sync-secrets.sh" ] && [ -f "$HOME/.config/sops/age/keys.txt" ]; then
    bash "$GARM/sync-secrets.sh" --self-check 2>&1 | tail -8
    echo "  → En cas d'écart : 'bash wincorp-garm/sync-secrets.sh --apply' puis rouvrir le terminal."
  elif [ ! -f "$HOME/.config/sops/age/keys.txt" ]; then
    echo "  [skip-attendu] clé age absente (~/.config/sops/age/keys.txt) — voir le guide onboarding pour le bootstrap."
  else
    echo "  [skip-anomalie] sync-secrets.sh introuvable dans wincorp-garm — coffre incomplet ?"
  fi
else
  echo "  [skip-attendu] wincorp-garm non cloné — secrets partagés non configurés (cf guide onboarding)."
fi
```

### Étape 3 — État git de l'écosystème

Afficher, par repo : branche, dernier commit, état (propre / modifs).

```bash
WORKSPACE="$HOME/Documents/wincorp-workspace"
echo ""
echo "=== État des repos ==="
cd "$WORKSPACE" 2>/dev/null || exit 0
shopt -s nullglob
# 2>/dev/null sur les commandes git : silence le bruit éventuel sur un dossier non-repo.
for repo in wincorp-*/; do
  [ -d "$repo/.git" ] || continue
  name="${repo%/}"
  branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null)
  last=$(git -C "$repo" log -1 --format="%cr — %s" 2>/dev/null | cut -c1-55)
  if [ -n "$(git -C "$repo" status --short 2>/dev/null)" ]; then dirty="● modifs"; else dirty="propre  "; fi
  printf "  %-22s [%-10s] %s | %s\n" "$name" "$branch" "$dirty" "$last"
done
shopt -u nullglob
```

### Étape 4 — Récap

Afficher en clair :
- Nombre de repos à jour vs avec modifs locales (à traiter via `/bonne-nuit-team`) vs en échec de pull.
- Rappel : avant de coder sur un repo, lire son `README.md` + `.claude/CLAUDE.md` (chaque repo documente son propre démarrage : Python, Next.js, Vite…).
- Rappel : « Fait » = vérifié (tests verts), pas « ça devrait marcher ».
