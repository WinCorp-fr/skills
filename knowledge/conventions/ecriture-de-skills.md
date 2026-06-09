---
tier: shared
shared_since: 2026-06-09
---

# Convention d'écriture des skills

À appliquer pour toute nouvelle skill et lors du refactor des skills existantes.

## Règles globales (chaque step)

1. **Path:line cliquable.** Toute référence au code utilise le format relatif au répertoire courant `chemin:ligne` (sans `/` initial) pour rester cliquable dans les terminaux IDE. Ex : `src/module.py:42`.
2. **Front-load then shut up.** Présenter tout l'output d'un step en UN seul message cohérent. Ne pas questionner en milieu de step, ne pas drip-feeder, ne pas faire de pause entre sections.
3. **Langue.** Communication et documents dans la langue de l'équipe ; identifiants de code en anglais, commentaires dans la langue de l'équipe.
4. **Critical Rules en tête.** Toute skill non triviale commence par un bloc `## CRITICAL RULES` :
   - `MANDATORY: Execute ALL steps IN EXACT ORDER`
   - `HALT immediately when halt-conditions are met`
   - `Each action within a step is REQUIRED to complete that step`

## Structure recommandée

### Skills < 100 lignes
Tout dans `SKILL.md` (frontmatter + workflow inline).

### Skills > 100 lignes ou multi-étapes

```
ma-skill/
├── SKILL.md           # Frontmatter mince + « Follow the instructions in ./workflow.md. »
├── workflow.md        # Goal + Critical Rules + INITIALIZATION + EXECUTION
├── steps/             # 1 fichier par étape complexe
├── templates/         # Templates Markdown remplissables
├── checklist.md       # Checklist de sortie obligatoire
└── data/              # CSV, YAML de référence
```

## Frontmatter SKILL.md

```
---
name: nom-skill
description: 'Description en 1-2 phrases. Use when [trigger précis].'
---
```

## Bloc INITIALIZATION standard

Toute skill dépendante du contexte charge ses variables explicitement : domaine courant, client si applicable, langue de communication, date système, racine du projet.

## Bloc EXECUTION — pattern XML structuré

```
<workflow>
<step n="1" goal="Charger le contexte">
  <action>...</action>
  <check if="fichier absent">
    <output>Erreur explicite</output>
    <action>HALT</action>
  </check>
</step>
</workflow>
```

## Anti-patterns LLM à prévenir (checklist universelle)

À cocher avant toute remise à un agent build ou avant commit :

- [ ] Pas de réinvention de roue (une fonction / skill existante fait-elle déjà le job ?).
- [ ] Bonne bibliothèque (dépendance listée dans le manifeste du projet).
- [ ] Bons emplacements de fichiers (respect de l'arborescence).
- [ ] Pas de régression (tests verts avant ET après).
- [ ] Implémentation précise (pas de `# TODO`, pas de `pass`, pas de stub).
- [ ] Pas de mensonge sur la complétion (les tests existent réellement et passent).
- [ ] Apprentissage des erreurs passées (vérifier les notes de principe pertinentes).

## Checklist de sortie obligatoire

Toute skill produit un `checklist.md` validant : inputs reçus et conformes, étapes exécutées dans l'ordre, outputs créés aux bons emplacements, tests / validations passés, documentation à jour si pertinent.

## Variabilisation

Préférer des variables (`{communication_language}`, `{document_output_language}`, `{current_domain}`) aux valeurs en dur — une seule skill réutilisable multi-contextes.
