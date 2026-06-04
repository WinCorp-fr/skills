---
name: bonjour
description: Rituel de DÉBUT de session WinCorp / Yggdrasil. Synchronise le workspace (git pull de tous les repos wincorp), re-déploie les git hooks (ADR-004), charge le contexte depuis saga (ADR-001), et fait un rapport d'état orienté action. À lancer en début de journée ou de session de travail sur l'écosystème WinCorp / Yggdrasil.
tier: shared
---

# /bonjour — Rituel de début de session WinCorp

Tu démarres une session de travail sur l'écosystème **Yggdrasil** (racine de travail : `wincorp-workspace/`). Exécute les étapes ci-dessous **dans l'ordre**, puis fais un rapport final concis. N'invente pas d'infra : si un script référencé n'existe pas encore, **skip proprement avec une note** (l'écosystème est en cours de construction).

Référence : `saga/decisions/ADR-001-hooks-git-vs-skills.md`, `saga/decisions-source/ADR-004-*.md`, `saga/README.md`.

## Étape 1 — Inventaire du workspace

Liste les sous-dossiers du workspace et identifie pour chacun : est-ce un repo git (présence `.git/`) ? remote origin, branche courante, nombre de modifs non commitées.

## Étape 2 — Sync (git pull) de tous les repos

Pour **chaque repo git** du workspace :
- S'il est **propre** (0 modif non commitée) et sur une branche avec upstream → `git pull --ff-only`.
- S'il a des **modifs non commitées** ou est sur une **branche feature sans upstream** → **NE PAS pull**. Fais juste `git fetch --all` et signale-le (ne jamais écraser du travail en cours).
- Reporte par repo : ✅ à jour / ⬇️ N commits récupérés / ⚠️ skip (raison).

## Étape 2bis — Re-déploiement des git hooks (ADR-004)

Les hooks pre-commit/pre-push ne sont **pas versionnés** et doivent être redéployés après clone ou changement de machine.
- Si le script `deploy-git-hooks.sh` du workspace existe (`.claude/hooks/`) → l'exécuter (idempotent).
- Sinon → note : « hooks non déployés (deploy-git-hooks.sh absent, cf. ADR-004) » et continue.

## Étape 3 — Repos manquants

Compare les repos clonés à l'org GitHub (`gh repo list WinCorp-fr`). Liste ceux qui manquent en local (ignore les repos vides et le repo méta `.github`). **Ne clone pas automatiquement** : propose-le.

## Étape 4-bis — Chargement du contexte (mémoire structurelle)

- Si la bibliothèque vivante `saga/library/INDEX.md` existe → la lire (ADR-001).
- Sinon → lire `saga/README.md` + `saga/yggdrasil.md` (glossaire) comme contexte de repli.
- **Alerte fraîcheur** : si la bibliothèque (ou `saga` en repli) date de **plus de 7 jours**, signale « ⚠️ lib stale > 7j — pense à `/bonne-nuit` sur le PC canonique » (ADR-001).

## Étape 5 — Rapport final

Affiche un rapport court :
- État de chaque repo (à jour / skip / manquant)
- Hooks déployés ? oui/non
- Alerte staleness ?
- **Sur quoi reprendre** : s'il existe un prompt de reprise laissé par `/bonne-nuit`, le surfacer ; sinon demander à l'utilisateur l'objectif du jour.

Reste factuel, pas de blabla. Termine par une question : « On attaque quoi aujourd'hui ? »
