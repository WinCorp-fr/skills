---
tier: shared
shared_since: 2026-06-09
---

# Un module produit est multi-tenant par défaut, dès la spécification

## Principe

Tout module à **vocation commerciale** (destiné à être revendu ou réutilisé par plusieurs organisations) embarque le multi-tenant **dès la rédaction de la spécification**, pas en « phase ultérieure ». Le multi-tenant n'est pas l'absence de noms de clients en dur dans le code — c'est la **présence** de structures dédiées : table des locataires, propagation d'un identifiant de locataire, ressources en base, et un interrupteur d'activation granulaire.

Les librairies pures (utilitaires sans état ni données métier) en sont exemptées.

## Ce que « multi-tenant by design » exige

1. **Table des locataires** : identifiant, profil, état actif/inactif, plan tarifaire, plafond budgétaire, date de création.
2. **Propagation de l'identifiant de locataire** dans tous les modèles métier par organisation (préférences, résultats, abonnements), dans l'instrumentation d'usage, et dans les requêtes (idéalement via row-level security).
3. **Ressources en base, jamais en dur** : listes de suivi, configuration des sources, canaux, quotas.
4. **Interrupteur d'activation à 4 niveaux** : global (infra), locataire (drapeau en base), source / fonctionnalité, canal de diffusion.
5. **Sûr par défaut** : tout est inactif à la création ; l'activation est un choix conscient.

## Le coût se paie maintenant ou double plus tard

- Coût marginal **à l'origine** : de l'ordre de 5 % (une table locataires + propagation de la clé étrangère + sécurité de base).
- Coût de **rétrofit** après une livraison mono-locataire : la moitié du module ou plus (réécriture des requêtes, migration des données, refonte des appelants, tests à refaire).

## Anti-patterns à surveiller

- **« On verra le multi-tenant plus tard. »** Toujours faux : à faire dès la phase 0.
- **« Le client pilote est typique, on code en dur pour simplifier. »** Le client pilote est **une configuration de locataire**, jamais une exception au design.
- **« Le module est interne, pas commercialisable. »** La quasi-totalité des outils ont vocation à servir une autre organisation. Présomption multi-tenant.
- **« Multi-tenant, c'est complexe. »** Non : une table locataires + une colonne d'identifiant partout + une fonction « locataire courant » couvrent l'essentiel.
- **« Multi-tenant par convention de dossiers » (un répertoire par client).** Faux multi-tenant : pas de requête transverse, pas d'inscription, pas d'interrupteur programmatique.
- **Brique technique « techniquement multi-tenant » mais sans couche métier, sans inscription, sans tarification.** Résultat typique : zéro client réel, car ouvrir un vrai client demande alors d'inventer l'inscription, la facturation et la page commerciale — un rétrofit de plusieurs jours.

## Critère de sortie

Avant de déclarer un module prêt pour la production : au moins **deux locataires distincts en jeux d'essai**. Un seul = code mono-locataire déguisé en multi-tenant. La spécification inclut « comment ajouter un nouveau locataire » et le mode d'emploi commercial (qui contacter, comment tarifer, comment intégrer).
