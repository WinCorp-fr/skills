---
name: audit-dette
description: "Audit dette silencieuse — scan SKILL.md (pre-check, skips typés, drift), refs path:line mortes, dette-tracker.jsonl. Génère rapport actionnable. Use: audit dette, dette report, dette tracker, scan dette."
allowed-tools: Bash, Read, Write
tier: shared
shared_since: 2026-06-09
---

# Workflow "Audit dette" — couche d'audit du système dette-zéro

## Objectif

Scanner l'écosystème pour les dettes silencieuses non couvertes par les hooks runtime (pre-check des binaires externes, détection de marqueurs debug). Génère un rapport actionnable `dette-report-YYYY-MM-DD.md`.

## Quand l'invoquer

- **Auto** : le rituel de début de session affiche un résumé court ; déclenche l'audit complet si le dernier rapport date de plus d'un jour.
- **Manuel** : à tout moment via `/audit-dette` (audit complet immédiat).
- **Avant une fin de session** d'un chantier majeur : pour énumérer les dettes ajoutées.

## Configuration (multi-dev)

Le scanner résout son schéma au runtime depuis l'environnement du dev courant. Variables surchargeables — à renseigner dans le profil dev local si votre arborescence diffère :

| Variable | Rôle | Défaut |
|---|---|---|
| `AUDIT_DETTE_WORKSPACE_NAME` | nom du dossier workspace | `wincorp-workspace` |
| `AUDIT_DETTE_MEMORY_DIRNAME` | dossier des notes de mémoire | `memory` |
| `AUDIT_DETTE_NOTE_PREFIX` | préfixe des notes scannées pour refs mortes | `feedback_` |
| `AUDIT_DETTE_SLUG_SUFFIX` | suffixe du slug projet (dossier mémoire) | `-Documents-<workspace>` |

## Procédure — Exécuter dans l'ordre

### Étape 1 — Lancer le scan

```bash
SKILL_DIR="$HOME/.claude/skills/audit-dette"
SCAN_PY="$SKILL_DIR/scan.py"

if [ ! -f "$SCAN_PY" ]; then
  echo "[skip-anomalie] scan.py absent dans $SKILL_DIR — skill non installé correctement"
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "[skip-anomalie] python3 absent — installer Python 3.10+"
  exit 1
fi

# Mode : --summary (stats compactes) | --full (rapport markdown complet, défaut)
MODE="${1:---full}"
python3 "$SCAN_PY" "$MODE"
```

### Étape 2 — Présenter le rapport

Si `--full` : le scan génère `<workspace>/.claude/dette-reports/dette-report-YYYY-MM-DD.md`. Le présenter en lecture brève + invitation à drill-down.

Si `--summary` : afficher les lignes de stats (TODO non tracés, drift skills, frontmatter mismatch, content anomalies, templates corrompus, refs mortes, marqueurs debug).

### Étape 3 — Proposer 3 actions

1. **Sprint dette ciblé** — si > 30 entrées non tracées OU dette > 90 jours → chantier dédié de cleanup.
2. **Fix immédiat** — si dette critique (drift skills, ref path:line morte sur règle active) → fix dans la session courante.
3. **Tracer + ignorer** — si dette acceptable → ajouter une ref datée au TODO existant pour le tracer.

Ne jamais auto-fixer sans validation utilisateur explicite (sauf trivial : ajout de ref date sur un TODO).

## Périmètre du scan

| Cible | Détection |
|---|---|
| `~/.claude/skills/*/SKILL.md` | Commandes externes sans pre-check, redirections silencieuses, skips non typés ; drift hash cross-skills ; frontmatter mismatch ; contenu non-markdown ; templates corrompus |
| `<workspace>/.claude/rules/*.md` + notes de mémoire | Refs `path:line` ou wikilinks pointant vers des fichiers absents |
| `<workspace>/.claude/dette-tracker.jsonl` | TODO/FIXME/HACK/XXX non tracés |
| code applicatif du workspace (`.ts/.js/.py`) | Marqueurs debug oubliés (`console.log`, `debugger`, `pdb.set_trace`), hors chemins CLI/scripts/workers/tests |

## Format du rapport

`<workspace>/.claude/dette-reports/dette-report-YYYY-MM-DD.md` :

```markdown
# Rapport audit dette — YYYY-MM-DD
## Résumé chiffré
## Skills sans pre-check
## Drift entre skills (hash compare)
## Frontmatter mismatch
## Content anomalies
## Templates corrompus
## Refs path:line mortes
## TODO/FIXME non tracés — top 10 par âge
## Marqueurs debug oubliés
## Recommandation
```

## Règles

- Ne JAMAIS modifier de fichier sans validation user (lecture seule par défaut).
- Le rapport markdown est versionné dans le workspace pour traçabilité historique.
- `dette-tracker.jsonl` est append-only — l'audit lit, ne réécrit pas.
- Premier passage (tracker absent) : message neutre, pas d'alerte.
- Pre-check `python3` obligatoire — si absent, skip-anomalie.
