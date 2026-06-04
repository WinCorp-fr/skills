## ⚠ Dépôt PARTAGÉ entre tous les devs WinCorp

Tout ce qui est mergé ici devient visible de l'ensemble des devs de l'organisation.

- [ ] Aucune donnée client, perso, ni mémoire individuelle.
- [ ] Chaque skill/fichier ajouté porte `tier: shared`.
- [ ] `bash ci/leak-scan.sh --tree .` est vert en local.

La CI `leak-scan` (required check) refuse le merge au moindre marqueur confidentiel — deny-by-default.
