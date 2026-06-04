---
name: recall
description: Relit la mémoire structurelle WinCorp / Yggdrasil en cours de session pour se réorienter. Lit la bibliothèque vivante saga/library/INDEX.md (ADR-001), recherche dans les ADRs/specs/glossaire, et surface ce qui est pertinent pour la tâche en cours. À utiliser pour « rappelle-moi le contexte », « où en est X », « qu'est-ce qu'on avait décidé sur Y », ou avant d'attaquer un sujet sur l'écosystème WinCorp.
tier: shared
---

# /recall — Rappel de contexte Yggdrasil

Tu dois te réorienter sur l'écosystème **Yggdrasil** sans relancer une session complète. Lis la mémoire structurelle et **surface uniquement ce qui est pertinent** pour la question/tâche en cours. Ne fais pas de sync git (c'est le rôle de `/bonjour`).

Référence : `saga/README.md`, `saga/decisions-source/ADR-001-*.md` (« lue par /recall »).

## Étape 1 — Cadrer la requête

Identifie le sujet du rappel à partir de la demande de l'utilisateur (un repo ? une décision ? un statut ? un terme du glossaire ?). Si c'est vague, lis l'INDEX global et résume l'état d'ensemble.

## Étape 2 — Lire la bibliothèque vivante

- Si `saga/library/INDEX.md` existe → c'est le point d'entrée. Suis les liens vers la section pertinente : fiches repos, specs, décisions, glossaire.
- Sinon (lib pas encore générée) → repli sur les sources : `saga/README.md`, `saga/yggdrasil.md` (glossaire mythologie → repos), `saga/decisions-source/` (ADRs), `saga/specs/` et `saga/specifications/`.

## Étape 3 — Recherche ciblée

Cherche le sujet dans `saga/` : ADRs, specs, guides. Privilégie les sources de vérité ; ne devine pas.

## Étape 4 — Restituer

Réponds de façon **dense et actionnable** :
- Ce qui est connu / décidé (avec la référence `chemin:ligne` cliquable).
- Statut actuel (livré / en cours / en pause / verrou).
- Ce qui reste ouvert ou à challenger (les docs d'archi/specs datées 2024 sont à challenger, cf. README saga).

Si l'info n'existe pas dans la doc, dis-le clairement plutôt que d'inventer — et propose de l'acter via `/bonne-nuit`.
