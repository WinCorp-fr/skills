---
tier: shared
name: diagnose
description: 'Diagnostic de chaîne complet avant tout correctif : énumère les maillons, collecte des preuves sourcées via sous-agents lecture seule, sépare faits et hypothèses, produit un plan de fix groupé + un artefact. Use when a bug, test failure ou comportement inattendu résiste à un premier correctif, AVANT une 2e/3e tentative sur le même symptôme, ou quand un garde-fou anti-boucle bloque un commit fix. Triggers : erreur intermittente, "j''ai déjà essayé X", whack-a-mole, symptôme récurrent, flaky, "ça remarche pas".'
---

# Diagnose — Diagnostic de chaîne avant correctif

**Goal :** Face à un bug qui résiste, établir la cause racine par un diagnostic structuré AVANT de toucher au code — énumérer la chaîne complète, collecter des preuves sourcées, séparer les faits des hypothèses, et ne proposer qu'un plan de fix **groupé** appuyé sur des faits. Produit un artefact réutilisable qui documente le raisonnement et débloque les garde-fous anti-boucle.

La discipline « pas de fix sans cause racine » est supposée acquise. Cette skill fournit la **procédure opérationnelle** qui la met en œuvre de façon reproductible : c'est l'outil qu'on déroule quand on décide de diagnostiquer (ou quand un garde-fou l'exige), pas un rappel moral.

**REQUIRED BACKGROUND :** la méthode cause-racine générique est dans superpowers:systematic-debugging (Iron Law : pas de fix sans cause racine prouvée). `/diagnose` en est la déclinaison opérationnelle : chaîne explicite + sous-agents lecture seule + artefact au format attendu par le garde-fou anti-boucle.

## CRITICAL RULES

- MANDATORY : exécuter TOUTES les étapes DANS L'ORDRE EXACT (0 → 5).
- **GEL TOTAL pendant le run** : aucun Edit, Write, ni commit tant que le plan de fix (étape 4) n'est pas présenté et validé. Le diagnostic n'écrit QUE son propre artefact.
- On ne corrige JAMAIS sur une hypothèse — seulement sur un **fait sourcé** (étape 3). Un symptôme (« 1 fois sur 5 », « parfois ») est une description, pas un diagnostic.
- Le plan de fix est **groupé** (tous les maillons fautifs traités ensemble), jamais symptôme-par-symptôme.
- L'artefact (étape 5) est obligatoire même si la cause est trouvée vite — il documente ET débloque le garde-fou.

## Inputs

- **symptom** (requis) — Le symptôme exact : message d'erreur, comportement observé, fréquence, conditions de déclenchement (1-3 phrases).
- **repo** (optionnel) — Repo / module concerné. Si absent, déduit du contexte de session.
- **prior_attempts** (optionnel) — Correctifs déjà tentés sur ce symptôme (à reverter s'ils s'avèrent traiter un faux symptôme).

## EXECUTION

<workflow>

<step n="0" goal="Figer le symptôme + geler les écritures">
  <action>Reformuler le symptôme en termes FALSIFIABLES : quoi exactement, dans quelles conditions, à quelle fréquence, depuis quand. Distinguer « ce qui est observé » de « ce qu'on en déduit ».</action>
  <action>Si prior_attempts fourni : les lister — ce sont des hypothèses déjà jouées, pas des faits acquis.</action>
  <action>Choisir le slug du diagnostic : `<date>-<symptôme-court-kebab>` (ex : `2026-06-13-export-500-intermittent`).</action>
  <action>GEL : annoncer qu'aucun code ne sera modifié avant l'étape 4. Toute pulsion de « petit fix rapide » est suspendue jusqu'à preuve.</action>
</step>

<step n="1" goal="Énumérer TOUS les maillons de la chaîne">
  <action>Tracer le flux complet du point d'entrée au point de sortie, sans présumer le coupable. Chaque maillon = un endroit où ça PEUT casser.</action>
  <action>Exemple de chaîne pour une requête : client → route/endpoint → middleware (auth, validation) → handler → service métier → requête data/IO → ressource externe (DB, API) → sérialisation réponse.</action>
  <action>Pour un test qui échoue : fixture/setup → données d'entrée → unité testée → dépendances mockées/réelles → assertion → teardown/état partagé.</action>
  <action>Numéroter les maillons. C'est le périmètre d'enquête de l'étape 2 — exhaustif, pas un raccourci vers le suspect favori.</action>
</step>

<step n="2" goal="Collecter des preuves par maillon via sous-agents LECTURE SEULE">
  <action>Dispatcher 2-3 sous-agents en LECTURE SEULE (interdiction stricte d'Edit/Write/commit), parallélisables car indépendants.</action>
  <action>Regrouper les maillons par SOURCE DE PREUVE, pas par maillons contigus : (A) observabilité — logs / stack trace / traces ; (B) code statique du chemin — handler → service → requête, + le diff des correctifs déjà tentés ; (C) données & repro — rejouer un cas isolé, comparer un cas qui échoue vs un qui passe. Chaque source révèle des faits que les autres ne voient pas ; un découpage par maillon contigu rate les corrélations transverses.</action>
  <action>Chaque sous-agent rapporte des FAITS SOURCÉS uniquement : extrait de log horodaté, ligne de code `path:line`, sortie de commande, schéma réel, résultat d'une repro. Pas d'opinion, pas de « probablement ».</action>
  <action>Sources typiques selon le maillon : logs applicatifs (filtrés sur l'endpoint/erreur + fenêtre temporelle), stack trace réelle, code du handler/service, schéma DB + requête exécutée, repro isolée (rejouer UN cas précis en boucle pour distinguer intermittent vs déterministe-par-donnée).</action>
  <action>Consigne anti-biais : un sous-agent qui ne trouve RIEN sur son maillon le dit explicitement (« maillon X : aucune trace d'erreur sur la fenêtre ») — l'absence de preuve est elle-même une information.</action>
</step>

<step n="3" goal="Séparer faits sourcés et hypothèses">
  <action>Construire le tableau à 2 colonnes :</action>
  <action>| ✅ Faits (sourcés) | ❓ Hypothèses (non prouvées) |
  Chaque fait porte sa preuve (log:ligne, path:line, sortie commande). Chaque hypothèse reste dans sa colonne tant qu'aucune preuve ne l'y fait basculer.</action>
  <action>Identifier la **cause racine** = le fait le plus EN AMONT de la chaîne qui explique le symptôme observé. Vérifier qu'elle explique AUSSI pourquoi les correctifs précédents (prior_attempts) ont échoué.</action>
  <check if="aucun fait n'établit la cause racine">
    <output>Diagnostic incomplet : la cause reste hypothétique. NE PAS proposer de fix. Retourner à l'étape 2 avec des sous-agents ciblés sur les maillons encore opaques (ou élargir la fenêtre de logs / la repro).</output>
    <action>Boucler étape 2 → 3 avec des sous-agents ciblés. CRITÈRE D'ARRÊT : après 2 tours sans nouveau fait, ou si les sources exploitables sont épuisées (pas de logs, repro impossible, accès manquant), STOP — conclure honnêtement « cause non établie » + lister les pistes restantes ET ce qu'il faudrait pour trancher (instrumentation à ajouter, accès à obtenir, repro à construire). Ne JAMAIS fixer à l'aveugle pour « avancer ».</action>
  </check>
</step>

<step n="4" goal="Proposer un plan de fix GROUPÉ — avant tout commit">
  <action>À partir des seuls faits : décrire UN plan qui traite TOUS les maillons fautifs ensemble (pas un patch par symptôme).</action>
  <action>Inclure systématiquement : (a) le test de régression à écrire AVANT le fix (rouge d'abord, prouve la cause) ; (b) le revert des prior_attempts qui traitaient un faux symptôme (sinon = dette qui masquera le prochain incident) ; (c) les effets de bord attendus sur les autres maillons.</action>
  <action>Si le fix dépend d'une RÈGLE MÉTIER ou réglementaire non établie (valeur par défaut d'un cas limite, libellé normé, traitement d'une exonération, règle d'arrondi…), elle devient un POINT DE VALIDATION BLOQUANT — jamais une décision silencieuse de Claude. Présenter les options, demander la règle, ne pas deviner.</action>
  <action>Présenter le plan en 5-10 lignes max et ATTENDRE validation explicite avant tout Edit/commit (fin du gel).</action>
  <ask>Valider le plan de fix groupé ? [y/n/discuter]</ask>
</step>

<step n="5" goal="Écrire l'artefact de diagnostic">
  <action>Écrire l'artefact dans `.claude/diagnostics/<date>-<slug>.md` à la racine du workspace (ou du repo concerné). Créer le dossier `.claude/diagnostics/` s'il n'existe pas.</action>
  <action>Cet artefact débloque les garde-fous anti-boucle (un détecteur de whack-a-mole sur les commits fix cherche un `.claude/diagnostics/*.md` récent comme preuve qu'un vrai diagnostic a eu lieu). Il doit donc exister AVANT le commit du fix.</action>
  <action>Remplir avec le template ci-dessous (symptôme figé + maillons + tableau faits/hypothèses + cause racine + plan groupé). Référencer les preuves par `path:line` / log horodaté.</action>
</step>

</workflow>

## Template artefact (`.claude/diagnostics/<date>-<slug>.md`)

```markdown
# Diagnostic — <symptôme court> (<date>)

> Repo : <repo> · Slug : <date>-<slug> · Sous-agents : <A/B/C> · Apparition : <date ou « à confirmer »>

## Symptôme figé
<quoi exactement · conditions · fréquence · depuis quand>

## Correctifs déjà tentés (et pourquoi insuffisants)
- <prior_attempt 1> — <pourquoi ça n'a pas tenu, à la lumière des faits>

## Maillons de la chaîne
1. <maillon> — <statut : preuve trouvée / RAS / opaque> [Fx si fait associé]
2. ...

## Faits vs hypothèses
| ✅ Faits (sourcés) | ❓ Hypothèses |
|---|---|
| <fait + preuve path:line / log> | <hypothèse non prouvée> |

## Cause racine
<le fait le plus en amont qui explique le symptôme ET l'échec des correctifs précédents>

## Plan de fix groupé
- Test de régression : <à écrire d'abord, rouge>
- Fix : <traite tous les maillons fautifs>
- Revert : <prior_attempts à annuler s'ils traitent un faux symptôme>
- Effets de bord : <maillons impactés>
```

## Checklist de sortie

- [ ] Symptôme reformulé de façon falsifiable (observé ≠ déduit)
- [ ] Tous les maillons de la chaîne énumérés (pas de raccourci vers le suspect favori)
- [ ] Preuves collectées par sous-agents LECTURE SEULE (aucun Edit pendant le run)
- [ ] Tableau faits sourcés vs hypothèses rempli, chaque fait porte sa preuve
- [ ] Cause racine = un fait en amont qui explique aussi l'échec des fixes précédents
- [ ] Plan de fix GROUPÉ présenté et validé AVANT tout commit (test de régression inclus)
- [ ] Artefact écrit dans `.claude/diagnostics/<date>-<slug>.md`
- [ ] Aucun code modifié par cette skill (le fix se fait APRÈS, hors skill)

## Erreurs courantes

| Piège | Réalité |
|---|---|
| « 1 fois sur 5 » → chercher une cause aléatoire (réseau, charge) | Une intermittence cache souvent un **déterminisme par donnée** : rejouer un cas précis en boucle le prouve ou l'infirme. |
| Sauter l'énumération des maillons, aller au suspect probable | Le suspect probable est une hypothèse. La chaîne complète évite de fixer le mauvais maillon. |
| Sous-agents qui « analysent » et concluent | Les sous-agents collectent des **faits sourcés**, le verdict se prend à l'étape 3 sur l'ensemble. |
| Fix rapide « juste pour débloquer » avant l'artefact | C'est le whack-a-mole que le garde-fou bloque. L'artefact d'abord, le fix ensuite. |
| Garder les correctifs-rustines précédents « au cas où » | Un fix qui traite un faux symptôme est de la dette qui masquera le prochain incident — le reverter fait partie du plan. |
