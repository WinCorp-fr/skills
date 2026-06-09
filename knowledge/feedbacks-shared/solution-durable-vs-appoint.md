---
tier: shared
shared_since: 2026-06-09
---

# Recommander la solution durable dès la v1.0, pas l'appoint différé

## Principe

Face à un choix structurant où coexistent une option rapide (qui crée de la dette) et une option durable (qui pose une base saine), **recommander celle qui pose une base durable dès la v1.0**, dès lors que son coût marginal est raisonnable. Ne pas présenter « on livre vite et on consolidera plus tard » comme recommandation quand le « plus tard » a toutes les chances de ne jamais venir.

## Les 4 questions avant toute recommandation entre 2+ options

1. **L'option d'appoint crée-t-elle un faux sentiment de sécurité ?** Un champ qui existe mais n'applique aucune règle, un garde-fou qui n'attrape rien.
2. **Génère-t-elle une dette documentée mais non échéancée ?** Une « phase ultérieure » sans date = report indéfini.
3. **Le coût marginal de l'option durable est-il raisonnable ?** Le chiffrer : +X h maintenant vs +Y h plus tard + risque d'incident entre-temps. Si X est proche de Y ou inférieur, le durable gagne.
4. **La base posée resservira-t-elle aux itérations suivantes ?** Si oui, investir maintenant évite la reprise.

## Quand recommander quand même l'option rapide

Uniquement si les trois conditions sont réunies :

- le coût de l'option durable est **nettement prohibitif** (ordre de grandeur ≥ 3×),
- **et** aucun appelant futur n'existe encore (pas de cascade de reprise),
- **et** la partie transitoire est explicitement documentée comme telle (aucun faux sentiment de sécurité).

Dans ce cas, présenter le compromis **chiffré**, jamais un simple « option A, plus simple » sans contexte.

## Format de recommandation

Quand deux options coexistent, fournir un tableau comparatif (effort v1.0, dette, risque d'incident entre-temps, reprise ultérieure) **et conclure par une recommandation explicite et argumentée**, pas un « à toi de choisir » neutre.

## Anti-patterns à surveiller

- Sous-estimer la dette de l'option rapide (biais optimiste).
- Sous-estimer le coût de reprise futur — évalué à 1× alors qu'il est souvent 2 à 3×.
- Ne pas chiffrer l'effort de l'option durable → elle paraît plus chère qu'elle ne l'est.
- Proposer « solution transitoire qu'on améliorera après » en sachant que « après » = jamais.
- **Biais de budget restant** : recommander l'option rapide parce qu'on croit manquer de temps dans la session courante. Si le durable demande une session dédiée, le recommander quand même et proposer une reprise propre — ne pas le déclasser en « trop gros pour maintenant ».
