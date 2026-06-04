---
tier: shared
name: distill
description: 'Compression lossless (pas summary) de docs source pour consommation LLM. Stages Analyze/Compress/Verify. Use when user says "distill", "distille", "compresse pour LLM", ou avant un /recall lourd.'
---

# Distill — Document Distillation Engine

Source : adapté de `bmad-distillator` (BMAD-METHOD v6, 2026-04-08).

**Compression ≠ summarization.** Les résumés sont lossy. Les distillats sont une compression lossless optimisée pour consommation LLM downstream. Préserve **chaque fait, décision, contrainte, relation** des sources tout en strippant l'overhead humain.

## CRITICAL RULES

- MANDATORY : Execute ALL steps IN EXACT ORDER
- HALT immediately on missing inputs
- NEVER summarize — preserve all facts. Strip only redundancy, formatting overhead, and prose connectors.
- Respecter `.claude/rules/05-skill-writing.md` (convention d'écriture des skills) avant toute modification de cette skill

## Inputs

- **source_documents** (requis) — Chemins/globs vers docs à distiller
- **downstream_consumer** (optionnel) — Quel workflow consomme le distillat ? (ex : "préparation /recall", "handoff Opus→Sonnet", "story file"). Sert à juger signal vs bruit. Si omis : tout préserver.
- **token_budget** (optionnel) — Taille cible. Si dépassement : trigger split sémantique.
- **output_path** (optionnel) — Défaut : adjacent au doc primaire avec suffixe `-distillate.md`
- **--validate** (flag) — Round-trip : reconstruire et diff vs original

## Cas d'usage prioritaires

1. **Notes / mémoire de projet volumineuses** → distillat avant un chargement de contexte lourd (gain contexte massif)
2. **Corpus de veille** (lot de vidéos / articles) → distillat unique consommable par un orchestrateur
3. **Specs multiples** → distillat "carte des contrats" pour onboarding d'un nouveau chantier
4. **Pré-handoff entre modèles** (ex : Opus → Sonnet) → distillat de la conversation avant ouverture d'une nouvelle session

## EXECUTION

<workflow>

<step n="1" goal="Validate inputs">
  <action>Vérifier que source_documents existe(nt)</action>
  <check if="absent ou vide">
    <output>HALT — aucune source à distiller</output>
  </check>
  <action>Estimer tokens totaux des sources (heuristique : chars/4)</action>
</step>

<step n="2" goal="Analyze & route">
  <action>Si ≤3 fichiers ET ≤15K tokens estimés → mode SINGLE</action>
  <action>Sinon → mode SPLIT (regrouper par thématique sémantique avant compression)</action>
  <action>Annoncer le routage à l'utilisateur</action>
</step>

<step n="3" goal="Compress">
  <action>Pour chaque groupe : extraire faits/décisions/contraintes/relations</action>
  <action>Strip : prose connectors, exemples redondants, formatage humain (titres décoratifs, listes à puces décoratives)</action>
  <action>Préserver : chiffres exacts, dates, noms propres, IDs, citations courtes, contraintes, edge cases</action>
  <action>Format de sortie : Markdown dense, sections par thème, tableaux quand applicable</action>
  <check if="downstream_consumer fourni">
    <action>Filtrer ce qui n'est pas pertinent pour ce consumer</action>
  </check>
</step>

<step n="4" goal="Verify">
  <action>Completeness check : chaque source est référencée au moins une fois</action>
  <action>Format check : valid Markdown</action>
  <action>Si --validate : reconstruire mentalement à partir du distillat, diff vs original, signaler pertes</action>
</step>

<step n="5" goal="Output">
  <action>Écrire le distillat à output_path (défaut : suffixe -distillate.md)</action>
  <action>Reporter : taille originale → taille distillat, ratio compression, nombre de faits préservés</action>
</step>

</workflow>

## Checklist de sortie

- [ ] Tous les fichiers sources lus en entier (jamais tronqués silencieusement ; >1500 lignes : chunker via offset/limit plutôt que de couper)
- [ ] Chaque fait/décision/contrainte préservé
- [ ] Aucune invention (zero hallucination)
- [ ] Format Markdown valide
- [ ] Ratio compression reporté
- [ ] Si --validate : diff round-trip exécuté
