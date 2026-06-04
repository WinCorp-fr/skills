---
name: bonne-nuit
description: Rituel de FIN de session WinCorp / Yggdrasil. Fait le housekeeping (docs, mémoire), régénère la bibliothèque saga sur le PC canonique (ADR-001 étape 2.7), pose le marqueur .session-state=clean lu par le hook pre-push (ADR-004), commit/push, et génère un prompt de reprise pour la prochaine session. À lancer en fin de session de travail sur l'écosystème WinCorp / Yggdrasil.
tier: shared
---

# /bonne-nuit — Rituel de fin de session WinCorp

Tu clôtures une session de travail sur **Yggdrasil**. Le but : laisser le workspace propre, la doc à jour, et préparer la reprise. Exécute dans l'ordre. Si un script d'infra n'existe pas, **skip avec note** (ne pas inventer).

Référence : `saga/decisions/ADR-001-hooks-git-vs-skills.md` (« Skill /bonne-nuit »), `saga/decisions-source/ADR-001-*.md` (étape 2.7), `saga/README.md`.

## Étape 1 — Bilan de session

Récapitule ce qui a été fait cette session (repos touchés, commits, specs/docs modifiées). Demande à l'utilisateur s'il manque quelque chose à acter.

## Étape 2 — Housekeeping docs & mémoire

- Vérifie que les changements de comportement / décisions sont reflétés dans la doc concernée (`saga/`, CLAUDE.md du repo, ADR si décision structurante).
- Mémoire : propose les notes à enregistrer. Pas de duplication chiffrée (pointer vers `urd/`).
- Pour toute **décision structurante**, proposer un ADR dans `saga/decisions-source/` (format MADR, numérotation ADR-NNN globale).

## Étape 2.7 — Régénération de la bibliothèque vivante (ADR-001)

**PC canonique uniquement** (env `WINCORP_LIB_CANONICAL=true`).
- Si canonique **et** `saga/scripts/build-library.mjs` existe → `node saga/scripts/build-library.mjs` puis commit du `saga/library/` régénéré.
- Si non canonique → ne pas régénérer (évite les conflits inter-PC), note : « lib récupérée via git pull sur ce PC ».
- Si le script n'existe pas → note : « build-library.mjs absent, lib non régénérée (cf. ADR-001) ».

## Étape 3 — État git de chaque repo

Pour chaque repo touché : vérifie qu'il n'y a pas de fichiers non commités oubliés. Propose des commits (Conventional Commits **en français**, cf. `saga/guides/conventions-code.md`). **Ne commit/push jamais sans validation explicite de l'utilisateur.**

⚠️ Avant tout commit, vérifie `git rev-parse --show-toplevel` pour t'assurer de cibler le bon repo et de ne pas committer dans un repo parent involontaire.

## Étape 4 — Marqueur de session propre (ADR-004)

Le hook pre-push vérifie un marqueur `.session-state`. Une fois le housekeeping fait et les repos propres :
- Écris `clean` dans le `.session-state` attendu par les hooks du workspace.
- Si les hooks ne sont pas déployés → note simplement que le marqueur est posé pour usage futur.

## Étape 5 — Prompt de reprise

Génère un **prompt de reprise** court pour la prochaine session : où on s'est arrêté, prochaine action concrète, fichiers/branches concernés. Stocke-le là où `/bonjour` le relira.

## Étape 6 — Rapport final

Résume : repos propres ✅, lib régénérée ? marqueur posé ? prompt de reprise écrit ? Termine par « Bonne nuit 🌙 — reprise prête. »
