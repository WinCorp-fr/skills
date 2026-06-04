# WinCorp — skills partagés (tier shared)

Dépôt **partagé** des skills de process dev WinCorp, accessible à TOUS les devs de l'organisation.

## Règle d'or — deny-by-default

Tout ce qui entre ici est **visible de tous les devs**. N'y mettre QUE des skills génériques WinCorp —
**jamais** de données client, de données perso, ni de mémoire individuelle.

- Chaque skill doit porter `tier: shared` dans son frontmatter. Sans ce marqueur valide → refusé.
- Une barrière CI (`.github/workflows/leak-scan.yml`, *required check*) scanne chaque PR et **refuse le merge**
  au moindre marqueur confidentiel (identifiants société, chemins machine perso, noms cabinet/société, refs mémoire…).
- Pas de push direct sur `main` : tout passe par Pull Request.

## Structure

- `skills/<nom>/` — skills partagés (tier shared uniquement).
- `knowledge/` — base de savoir d'équipe (conventions, feedbacks dev assainis). *(Phase B)*
- `ci/leak-scan.sh` — scanner anti-fuite, **source unique** de la CI et du hook local.
  Auto-test : `bash ci/leak-scan.sh --self-check`.
- `MANIFEST.md` — index des skills et de leur tier.

## Ajouter / modifier un skill

1. Branche + ajout sous `skills/<nom>/` avec `tier: shared` au frontmatter.
2. `bash ci/leak-scan.sh --tree .` en local (doit être vert).
3. Pull Request → la CI `leak-scan` doit passer → merge.
