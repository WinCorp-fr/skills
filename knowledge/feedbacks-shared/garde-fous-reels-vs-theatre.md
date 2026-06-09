---
tier: shared
shared_since: 2026-06-09
---

# Garde-fous réels vs garde-fous de théâtre

## Principe

Tout garde-fou (skill, agent, processus) qui repose sur **l'auto-évaluation d'un modèle de langage sur sa propre production** est présumé théâtral : rejet par défaut, preuve empirique exigée avant adoption. Un modèle qui note sa propre copie satisfait trivialement le critère — ce n'est pas de l'enforcement.

## Les seuls garde-fous qui valent

Un garde-fou réel passe par une **source de vérité externe au producteur** :

1. **Couche dépôt** — hooks git (pré-commit / pré-push), blocage de secrets, blocage de commandes dangereuses. Déterministe, hors du contrôle du modèle.
2. **Couche test** — tests automatisés, lint, typecheck, build qui passe. Valident le *comportement*, pas le texte.
3. **Couche humaine** — revue par un second regard **indépendant** (autre contexte, autre personne) ; audit multi-agent avant tout changement structurant.
4. **Couche spécification** — interface définie avant le code, checklist de sortie obligatoire.

## Grille de rejet rapide (audit 5 min)

| Si le garde-fou repose sur… | Verdict |
|---|---|
| Un auto-score bloquant (seuil « 7/10 », « score ≥ X ») | Rejet |
| Plusieurs personas simulées dans un seul contexte, présentées comme « cross-validation » | Rejet ferme (anti-pattern racine) |
| Une checklist auto-cochée par le producteur, sans sortie vérifiable | Rejet |
| Un « agent superviseur » qui lit la sortie sans source de vérité externe | Rejet |
| Un booster d'effort (« réfléchis plus », « plus en profondeur ») | Rejet — l'effort est déjà au maximum côté runtime |

**Un seul critère matche → rejet sans audit complet.** Aucun ne matche → audit exhaustif justifié.

## Récupération en posture

Si l'idée sous-jacente est juste (ex. argumenter le contre avant de critiquer, poser un checkpoint en session longue), l'intégrer comme **ligne de préférence** dans la configuration, pas comme une skill avec score simulé.
