---
tier: shared
name: agent-team-dev
description: >
  Templates Agent Teams pour le développement WinCorp. Lance des équipes
  d'agents spécialisés (production + challengers) qui travaillent en parallèle
  avec boucles d'itération. Utiliser pour les tâches de dev complexes :
  multi-fichiers, cross-repo, refactoring majeur, nouvelle feature.
---

# Agent Teams — Templates de développement WinCorp

Prérequis : `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` dans `~/.claude/settings.json`.

## Quand utiliser

- Développement touchant 3+ fichiers
- Refactoring cross-repo (ex: wincorp-mimir + wincorp-heimdall + wincorp-bifrost)
- Nouvelle feature avec architecture à concevoir
- Bug multi-couche (API + Web + DB)
- Tout développement où la qualité justifie le coût en tokens

## Quand NE PAS utiliser

- Fix simple, tâche mono-fichier
- Création de skill/agent
- Tâches métier d'un domaine client (comptabilité, fiscalité, juridique…) — utiliser les skills/subagents dédiés
- Tâches purement exploratoires (utiliser Agent Explore)

## Critère de scission — à vérifier AVANT de composer l'équipe

Ne scinder le travail en plusieurs teammates QUE si au moins un critère est vrai :

- **Outils/permissions différents** (ex : l'un écrit le code, l'autre est en lecture seule pour la review)
- **Modèle différent** (ex : Sonnet build vs Opus review)
- **Garde-fous différents** (ex : producteur vs challenger à mandat adverse)

Sinon : UN teammate qui boucle. Une mécanique séquentielle (« chercher → extraire → résumer »)
= 1 teammate, jamais 3 — scinder par étape mécanique est de la sur-ingénierie, pas de la rigueur.

## Règle 80/20 — la spec de la tâche prime sur le persona

80 % de l'effort dans la description de la tâche et sa sortie attendue, 20 % dans le rôle.
Un persona affûté ne rattrape jamais un mandat flou. Chaque teammate spawné reçoit OBLIGATOIREMENT :

- **1 tâche = 1 objectif** — jamais « analyse ET corrige ET documente » dans un même mandat
- **Sortie attendue explicite** : format (fichier, diff, liste), structure (sections attendues),
  marqueurs de qualité (path:line, preuves, tests référencés)

Les blocs « Sortie attendue par teammate » des templates ci-dessous sont à adapter, jamais à supprimer.

---

## Template 1 — Production + Challengers (standard)

Pour le développement de features ou de modules :

```
Crée une agent team pour {description de la tâche}.

Équipe production (travaillent en parallèle) :
- Un teammate "architecte" qui conçoit la structure, les interfaces
  et le data flow. Produit un fichier ARCHITECTURE.md avant que
  l'implémentation commence.
- Un teammate "implementeur" qui code les fonctions en respectant
  les conventions du repo ({conventions spécifiques}).
  Attend l'ARCHITECTURE.md de l'architecte avant de coder.
- Un teammate "testeur" qui écrit les tests (pattern TDD red-green-refactor)
  au fur et à mesure que l'implémenteur produit du code.

Équipe challengers (contestent les résultats) :
- Un teammate "bug-hunter" qui cherche activement les bugs,
  edge cases, erreurs logiques, et failles de sécurité.
- Un teammate "reviewer" qui challenge les choix d'architecture
  et propose des alternatives si pertinent.

Sortie attendue par teammate (1 tâche = 1 objectif) :
- architecte : ARCHITECTURE.md avec sections Interfaces / Data flow / Arbitrages
  (2-3 options par arbitrage, parti pris tranché)
- implementeur : code + liste des fichiers modifiés en path:line
- testeur : tests nommés d'après la règle vérifiée, rouges avant le code, verts après
- bug-hunter : findings numérotés — fichier:ligne, symptôme, preuve reproductible
- reviewer : verdict par choix d'archi (VALIDE / CONTESTE + alternative argumentée)

Règles :
- Les challengers envoient leur feedback directement aux producteurs
- Les producteurs corrigent et les challengers re-vérifient
- Itérer jusqu'à 0 objection majeure + tous les tests passent
- Conventions : {TypeScript strict | Python 3.12+ Ruff | etc.}
- Ne pas toucher aux fichiers hors scope : {liste des fichiers protégés}
```

## Template 2 — Debug par hypothèses concurrentes

Pour les bugs difficiles multi-couche :

```
Crée une agent team pour investiguer {description du bug}.

Équipe investigation (hypothèses parallèles) :
- Un teammate "frontend" qui cherche la cause côté React/Next.js
  (state, rendering, fetch, cookies, middleware)
- Un teammate "backend" qui cherche la cause côté FastAPI/Python
  (endpoints, validation, auth, DB queries)
- Un teammate "data" qui cherche la cause côté Supabase/PostgreSQL
  (RLS policies, migrations, data integrity)

Sortie attendue par investigateur (1 tâche = 1 objectif) :
- hypothèse + verdict CONFIRMÉE / RÉFUTÉE + preuves sourcées
  (logs, requête, path:line) — jamais d'interprétation sans fait

Règles adversariales :
- Chaque investigateur doit non seulement prouver sa théorie mais
  CONTESTER celles des autres avec des arguments factuels
- Quand un consensus émerge, un investigateur implémente le fix
  et les autres vérifient que ça résout effectivement le bug
- Produire un post-mortem à la fin : cause racine + fix + leçons (1 fichier .md)
```

## Template 3 — Refactoring cross-repo

Pour les refactorings qui touchent plusieurs repos wincorp :

```
Crée une agent team pour refactorer {description}.

Équipe :
- Un teammate "common" qui modifie wincorp-mimir (la librairie partagée)
  et s'assure que les tests passent (pytest)
- Un teammate "api" qui adapte wincorp-heimdall aux changements de common
  et vérifie les endpoints (pytest-asyncio)
- Un teammate "web" qui adapte wincorp-bifrost côté frontend
  et vérifie le build (vitest + next build)
- Un teammate "integration" qui vérifie que tout fonctionne ensemble
  (tests end-to-end, pas de régression)

Sortie attendue par teammate (1 tâche = 1 objectif) :
- common / api / web : diff + résultat des vérifications de son repo
  (commande exacte + exit code), transmis au teammate integration
- integration : rapport de non-régression listant les commandes rejouées et leur statut

Ordre de dépendance : common → api → web → integration
Le teammate integration ne commence que quand les 3 autres ont fini.
```

---

## Conventions à injecter

Selon le repo ciblé, injecter les conventions appropriées :

| Repo | Conventions |
|------|------------|
| wincorp-mimir | Python 3.12+, pytest, Ruff, Decimal pour les montants, typage strict |
| wincorp-heimdall | Python 3.12+, FastAPI, pytest-asyncio, Supabase asyncpg, JWT auth |
| wincorp-bifrost | TypeScript strict, Next.js 14 App Router, React 19, Tailwind, @supabase/ssr |
| wincorp-thor | TypeScript, Playwright, Claude Vision, profiles YAML |

## Consommation de tokens

Les Agent Teams consomment 3-10x plus qu'une session simple selon le nombre d'agents.
Recommandation :
- **3 agents** : tâche moyenne (1 producteur + 1 testeur + 1 reviewer)
- **5 agents** : tâche complexe (template standard production + challengers)
- **Ne jamais dépasser 5 agents** sauf cas exceptionnel validé par l'utilisateur
