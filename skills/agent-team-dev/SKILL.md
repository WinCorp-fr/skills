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

Règles adversariales :
- Chaque investigateur doit non seulement prouver sa théorie mais
  CONTESTER celles des autres avec des arguments factuels
- Quand un consensus émerge, un investigateur implémente le fix
  et les autres vérifient que ça résout effectivement le bug
- Produire un post-mortem à la fin : cause racine + fix + leçons
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
