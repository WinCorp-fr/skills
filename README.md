# WinCorp — skills partagés (tier shared)

Dépôt **partagé** des skills de process dev WinCorp, accessible à TOUS les devs de l'organisation.

## Règle d'or — deny-by-default

Tout ce qui entre ici est **visible de tous les devs**. N'y mettre QUE des skills génériques WinCorp —
**jamais** de données client, de données perso, ni de mémoire individuelle.

- Chaque skill doit porter `tier: shared` dans son frontmatter. Sans ce marqueur valide → refusé.
- Une barrière CI (`.github/workflows/leak-scan.yml`, *required check*) scanne chaque PR et **refuse le merge**
  au moindre marqueur confidentiel (identifiants société, chemins machine perso, noms cabinet/société, refs mémoire…).
- Pas de push direct sur `main` : tout passe par Pull Request.

## Pour les nouveaux développeurs

Setup complet (machine vierge → mémoire Claude Code synchronisée entre tes PC) : **voir
[`EXPLOITATION.md`](EXPLOITATION.md)** (runbook 5 min). En résumé :

```bash
gh repo clone WinCorp-fr/skills wincorp-skills
bash wincorp-skills/install-skills.sh                       # déploie skills + helpers
cp wincorp-skills/profile.env.template ~/.claude/profile.env # puis édite tes valeurs
bash ~/.claude/skills/bootstrap-personal-mirror.sh --apply --push   # crée ton miroir privé
```

Ensuite, `/bonjour-team` (début de session) et `/bonne-nuit-team` (fin) gèrent tout.

## Structure

- `skills/<nom>/` — skills partagés (tier shared uniquement).
- `knowledge/` — base de savoir d'équipe (conventions, feedbacks dev assainis). *(Phase B)*
- `install-skills.sh` — déploie `skills/*` + les helpers vers `~/.claude/skills/`.
- `bootstrap-personal-mirror.sh` — crée le dépôt miroir **privé personnel** d'un dev (mémoire/config).
- `personal-sync.sh` — sauvegarde/restaure la mémoire d'un dev vers/depuis son miroir (`--backup`/`--restore`).
- `profile.env.template` — modèle de profil d'identité dev (à copier en `~/.claude/profile.env`).
- `EXPLOITATION.md` — runbook d'usage + onboarding + limitations v1.
- `ci/leak-scan.sh` — scanner anti-fuite, **source unique** de la CI et du hook local.
  Auto-test : `bash ci/leak-scan.sh --self-check`.
- `MANIFEST.md` — index des skills et de leur tier.

## Ajouter / modifier un skill

1. Branche + ajout sous `skills/<nom>/` avec `tier: shared` au frontmatter.
2. `bash ci/leak-scan.sh --tree .` en local (doit être vert).
3. Pull Request → la CI `leak-scan` doit passer → merge.
