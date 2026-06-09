---
tier: shared
shared_since: 2026-06-09
---

# knowledge/ — base de savoir partagée de l'équipe

Notes de **principe** réutilisables par tous les devs : méthodes de travail, postures, conventions, garde-fous d'architecture. C'est le « comment on travaille », pas un journal de bord ni une mémoire personnelle.

## Contrat (deny-by-default)

Tout fichier ici est **visible de tous les devs** et franchit la barrière `ci/leak-scan.sh` (PR obligatoire + check requis). Donc :

- **Réécriture, pas extraction.** Une note est rédigée *from scratch* comme un principe générique. On ne copie jamais une note de mémoire personnelle, un plan ou une décision interne : ils contiennent des références (clients, chemins machine, identifiants) qui n'ont pas leur place dans un dépôt partagé.
- **Anonyme par construction.** Aucun nom de client, aucun identifiant de société (SIREN / SIRET), aucun chemin personnel, aucune référence à la mémoire d'un dev. Le principe se suffit à lui-même.
- **`tier: shared` obligatoire** dans le frontmatter de chaque `.md`, sinon la barrière refuse le fichier.

## Sous-dossiers

- `feedbacks-shared/` — principes de méthode et de posture (le « comment on décide / on construit »).
- `conventions/` — conventions techniques et de process (écriture de skills, développement piloté par la spécification…).

## Avant de committer une note

1. `bash ci/leak-scan.sh --files knowledge/<...>.md` → vert.
2. Faire relire la note par un regard adversarial « cherche le cas client, l'analogie, la référence interne » avant d'ouvrir la PR.
3. La CI re-scanne l'arbre entier au merge.
