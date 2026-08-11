# Convention d'écriture des skills WinCorp

> Déplacé depuis `wincorp-workspace/.claude/rules/05-skill-writing.md` le 2026-08-11
> (dégraissage vague 1, item R5a : 128 lignes chargées à CHAQUE session pour un usage
> ~1×/mois — le préambule de session n'est pas gratuit). Contenu inchangé hors 2 fixes :
> réf sandbox bmad morte supprimée (R5b), `project_root` variabilisé (R5c).
> Source : patterns extraits de BMAD-METHOD v6 (2026-04-08), adaptés à l'écosystème Yggdrasil.
> À appliquer pour toute **nouvelle** skill et lors du refactor des skills existantes.

## Règles globales (s'appliquent à chaque step)

1. **Path:line obligatoire.** Toute référence code utilise le format CWD-relatif `path:line` (sans `/` initial) pour rester cliquable dans les terminaux IDE. Ex : `wincorp-mimir/src/pcg.py:42`.
2. **Front-load then shut up.** Présenter tout l'output d'un step en UN seul message cohérent. Ne pas questionner mid-step, ne pas drip-feed, ne pas pauser entre sections.
3. **Langue.** Communication en FR. Output documents en FR sauf code (commentaires FR, identifiants EN).
4. **Critical Rules en tête.** Chaque skill non triviale commence par un bloc `## CRITICAL RULES` :
   - `MANDATORY: Execute ALL steps IN EXACT ORDER`
   - `HALT immediately when halt-conditions are met`
   - `Each action within a step is REQUIRED to complete that step`

## Structure recommandée

### Skills < 100 lignes
Tout dans `SKILL.md` (frontmatter + workflow inline).

### Skills > 100 lignes ou multi-étapes
```
ma-skill/
├── SKILL.md           # Frontmatter mince + "Follow the instructions in ./workflow.md."
├── workflow.md        # Goal + Critical Rules + INITIALIZATION + EXECUTION (steps inline ou refs)
├── steps/             # 1 fichier par étape complexe
│   ├── step-01-init.md
│   ├── step-02-context.md
│   └── ...
├── templates/         # Templates Markdown remplissables
├── checklist.md       # Checklist de sortie obligatoire
└── data/              # CSV, YAML de référence (ex: methods.csv)
```

## Frontmatter SKILL.md

```markdown
---
name: nom-skill
description: 'Description en 1-2 phrases. Use when [trigger précis].'
---
```

## Bloc INITIALIZATION standard

Toute skill qui dépend du contexte projet charge ses variables explicitement :

```markdown
## INITIALIZATION

### Configuration Loading
- `current_domain` (SPINEX | WinCorp | TRIMAT)
- `current_client` (si applicable)
- `communication_language` = FR
- `date` = système
- `project_root` = résolu au runtime (`resolve-paths.sh` / `~/Documents/wincorp-workspace`) — JAMAIS de chemin machine en dur (fichier sync 2 PC)

### Paths
- ...
```

## Bloc EXECUTION — pattern XML structuré

```markdown
## EXECUTION

<workflow>

<step n="1" goal="Charger le contexte">
  <action>Lire wincorp-urd/referentiels/...</action>
  <check if="fichier absent">
    <output>Erreur explicite</output>
    <action>HALT</action>
  </check>
</step>

<step n="2" goal="Produire le livrable">
  <action>...</action>
  <ask>Confirmer avant écriture ? [y/n]</ask>
</step>

</workflow>
```

## Anti-patterns LLM à prévenir (checklist universelle)

À cocher avant toute remise à un agent build (Sonnet/Haiku) ou avant commit :

- [ ] Pas de réinvention de roue (vérifier si une fonction/skill existante fait déjà le job)
- [ ] Bonne bibliothèque (pas de dépendance non listée dans `pyproject.toml` / `package.json`)
- [ ] Bons emplacements de fichiers (respect arbo `wincorp-{repo}/`)
- [ ] Pas de régression (tests verts avant ET après)
- [ ] Implémentation précise (pas de `# TODO`, pas de `pass`, pas de stub)
- [ ] Pas de mensonge sur la complétion (les tests existent réellement et passent)
- [ ] Apprentissage des erreurs passées (vérifier MEMORY.md `feedback_*` pertinents)

## Checklist de sortie obligatoire

Toute skill doit produire un `checklist.md` qui valide :
- Inputs reçus et conformes
- Étapes exécutées dans l'ordre
- Outputs créés aux bons emplacements
- Tests/validations passés
- Mémoire / spec / changelog mis à jour si pertinent

## Table de diagnostic (skills multi-étapes)

Toute skill multi-étapes (`workflow.md` + `steps/`) se clôt sur une table de dépannage à 3 colonnes :

```markdown
| Symptôme observé | Cause probable | Correction |
|---|---|---|
| <sortie/erreur telle que vue à l'écran> | <cause vérifiée> | <action précise, path:line si code> |
```

Règles :
- Alimentée UNIQUEMENT par des incidents réels (feedbacks mémoire, sessions passées) — jamais de cas hypothétiques.
- Créée avec les cas connus au moment de l'écriture ; enrichie à chaque nouvel incident (cycle post-erreur, étape 3 : correction à la source).
- Convention souple (pas de hook) : vérifiée à la relecture de skill, comme le reste de ce fichier.

Pattern emprunté aux skills officielles CrewAI (`getting-started`, table de 15 lignes symptôme→cause→fix) — greffe du 2026-07-15.

## Variabilisation

Préférer `{communication_language}`, `{document_output_language}`, `{current_domain}` à des valeurs en dur. Permet de maintenir une seule skill réutilisable cross-domaines.
