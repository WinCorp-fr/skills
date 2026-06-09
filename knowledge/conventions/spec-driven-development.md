---
tier: shared
shared_since: 2026-06-09
---

# Spec-Driven Development (SDD) — principes

## Qu'est-ce qu'un « module durable » ?

SDD est non négociable pour les **modules durables**. Un module est durable s'il coche au moins une case :

- il est importé par un autre module / dépôt (dépendance cross-fichier) ;
- il sera exécuté plus d'une fois (non jetable) ;
- il touche à de la logique métier réglementée ;
- il a vocation à être maintenu plus d'un sprint ;
- il manipule des données de production.

Sinon c'est un **quick script** (Niveau 0) : commentaire d'intention en tête, pas de spec formelle. En cas de doute, demander.

## Règles non négociables

1. **Spec first** — Avant d'implémenter un module, vérifier que `specs/<module>.spec.md` existe. Si oui → la lire en entier avant de coder. Si non → le signaler et proposer d'en créer une, adaptée au niveau de complexité.
2. **Interface sacrée** — L'interface définie dans la spec (noms, params, types, retours) est un contrat. Ne pas la modifier sans mise à jour de spec validée.
3. **Pas de devinette** — Si la spec est ambiguë ou silencieuse sur un point, demander avant d'interpréter.
4. **Tests = preuve** — Chaque règle métier et chaque edge case de la spec a au moins un test. Référencer la règle dans le nom du test.
5. **Modification = spec d'abord** — Pour toute modification d'un module existant : proposer le diff de spec AVANT de toucher au code, attendre validation, puis code → tests → changelog de la spec.
6. **Référence croisée** — Ajouter `@spec specs/<module>.spec.md vX.Y` en en-tête de chaque fichier source.

## Niveaux de complexité

- **Niveau 0** : quick script jetable — commentaire d'intention en tête, pas de spec.
- **Niveau 1** : module simple — spec légère (interface + règles principales).
- **Niveau ≥ 2** : module durable (importé cross-fichier ou métier réglementé) — spec complète, et un **plan amont** avant rédaction de la spec (grep des principes pertinents, arbitrages, décisions structurantes tranchées).

## Validation (avant de considérer un module terminé)

- [ ] Spec à jour avec un statut cohérent.
- [ ] Tous les tests passent.
- [ ] Référence `@spec` présente dans le code source.
- [ ] Changelog de la spec mis à jour si modification.
