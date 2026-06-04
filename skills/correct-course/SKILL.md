---
tier: shared
name: correct-course
description: 'Gérer un changement significatif en cours de sprint sans tout casser. Analyse impact cross-artifacts et produit une Sprint Change Proposal. Use when user says "correct course", "on change de cap", "pivot sprint", ou "j''ai un imprévu".'
---

# Correct Course — Sprint Change Management

Source : adapté de `bmad-correct-course` (BMAD-METHOD v6, 2026-04-08). Comble un gap fréquent : les pivots de sprint gérés à la main avec des notes de reprise éparpillées.

**Goal :** Quand un imprévu surgit en cours de sprint (bug bloquant, demande client urgente, découverte technique, contrainte réglementaire), analyser l'impact sur tous les artefacts du sprint et produire une **Sprint Change Proposal** actionnable avec handoff clair.

## CRITICAL RULES

- MANDATORY : Execute ALL steps IN EXACT ORDER
- NE JAMAIS modifier de code avant validation explicite de la proposal
- TOUJOURS produire la proposal en fichier Markdown (pas seulement en réponse)
- Si le trigger touche un module gelé / en pause → bloquer immédiatement et alerter

## Inputs

- **trigger** (requis) — Description de l'imprévu (1-3 phrases)
- **sprint_context** (optionnel) — Chemin vers le plan ou les notes du sprint en cours. Si absent, la skill fonctionne en mode dégradé gracieux : elle demande le contexte minimal à l'utilisateur au lieu d'échouer.
- **frozen_modules** (optionnel) — Liste de modules / repos gelés ou en pause à protéger. Si le trigger les touche → alerte bloquante.
- **severity** (optionnel) — blocker | high | medium | low

## EXECUTION

<workflow>

<step n="1" goal="Capter le trigger">
  <action>Si trigger absent → demander 1 description précise (1-3 phrases)</action>
  <action>Identifier severity si non fourni</action>
  <check if="frozen_modules fourni ET le trigger touche l'un d'eux">
    <output>⚠️ Module gelé / en pause concerné. Ce changement est-il vraiment urgent ? Si non → HALT et reporter.</output>
    <ask>Continuer malgré le gel ? [y/n]</ask>
  </check>
</step>

<step n="2" goal="Charger le contexte sprint actuel">
  <action>Si sprint_context fourni → le lire ; sinon demander à l'utilisateur les stories/tasks en cours (mode dégradé gracieux, ne pas échouer en l'absence de notes)</action>
  <action>Lister les stories/tasks actuellement in-progress</action>
  <action>Identifier les specs SDD impactées</action>
  <action>Identifier les notes / apprentissages pertinents si disponibles</action>
</step>

<step n="3" goal="Analyse d'impact cross-artifacts">
  <action>Pour chaque artefact, lister explicitement l'impact :</action>
  <action>- Code : fichiers à toucher (path:line)</action>
  <action>- Specs SDD : versions à bumper</action>
  <action>- Tests : suites concernées</action>
  <action>- Stories en cours : à pauser, modifier, abandonner ?</action>
  <action>- Documentation : à mettre à jour</action>
  <action>- Notes / apprentissages : à créer ?</action>
  <action>- Hooks / règles projet : à ajuster ?</action>
</step>

<step n="4" goal="Produire la Sprint Change Proposal">
  <action>Créer fichier `sprint-changes/sprint-change-{date}-{slug}.md` (à la racine du projet)</action>
  <action>Structure :
    1. Trigger (description + severity)
    2. Contexte sprint au moment du changement
    3. Impact cross-artifacts (tableau)
    4. Options possibles (au moins 2 — ex: rollback, pivot, parallèle)
    5. Recommandation argumentée
    6. Plan d'action si validation
    7. Risques résiduels</action>
</step>

<step n="5" goal="Handoff">
  <action>Présenter la proposal en résumé (5-10 lignes max)</action>
  <ask>Valider la recommandation ? [y/n/discuter]</ask>
  <check if="validé">
    <action>Mettre à jour le plan / les notes du sprint avec le nouveau cap (si sprint_context fourni)</action>
    <action>Créer une story file si chantier multi-fichiers</action>
    <action>HANDOFF — ne pas implémenter dans cette skill</action>
  </check>
</step>

</workflow>

## Checklist de sortie

- [ ] Trigger documenté
- [ ] Modules gelés / en pause vérifiés (gel respecté)
- [ ] Tous les artefacts impactés listés
- [ ] Au moins 2 options évaluées
- [ ] Recommandation justifiée
- [ ] Proposal écrite à l'emplacement standard
- [ ] Plan / notes du sprint mis à jour si validation
- [ ] Aucun code touché par cette skill
