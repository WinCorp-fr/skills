---
tier: shared
name: seo-audit
description: "Audit SEO technique d'un site Next.js — Lighthouse, sitemap, metadata, structured data, Core Web Vitals. Use: SEO, audit SEO, performance web, sitemap, metadata, lighthouse, core web vitals."
allowed-tools: Bash, Read, Glob, Grep, Write, Edit
---

## Pré-requis environnement (.claude/rules/06-dette-zero.md)

```bash
command -v node >/dev/null 2>&1 || echo "[skip-anomalie] node absent — installer Node.js 20+"
command -v npx >/dev/null 2>&1 || echo "[skip-anomalie] npx absent — installer Node.js 20+ (npx fourni avec npm)"
```

# Skill /seo-audit — Audit SEO technique

## Objectif

Auditer un projet Next.js pour identifier les problemes SEO techniques et proposer des corrections. Couvre : metadata, sitemap, robots.txt, Core Web Vitals, structured data, images, liens.

## Procedure

### Etape 1 — Identifier le projet

Determiner le repo Next.js cible. Si non precise, demander.
Projets Next.js WinCorp : `wincorp-bifrost`, `wincorp-skadi`.

```bash
WORKSPACE="$(cygpath "$USERPROFILE")/Documents/wincorp-workspace"
PROJECT="${1:-wincorp-bifrost}"
PROJECT_DIR="$WORKSPACE/$PROJECT"

echo "=== Audit SEO : $PROJECT ==="
[ -f "$PROJECT_DIR/next.config.js" ] || [ -f "$PROJECT_DIR/next.config.mjs" ] || [ -f "$PROJECT_DIR/next.config.ts" ] || echo "WARN: pas un projet Next.js"
```

### Etape 2 — Verifier next-sitemap

```bash
cd "$PROJECT_DIR"
echo "--- next-sitemap ---"
grep -q "next-sitemap" package.json 2>/dev/null && echo "OK: installe" || echo "MISSING: pnpm add next-sitemap"
ls next-sitemap.config.* 2>/dev/null || echo "MISSING: next-sitemap.config.js"
ls public/sitemap*.xml 2>/dev/null || echo "WARN: pas de sitemap genere"
ls public/robots.txt 2>/dev/null || echo "WARN: pas de robots.txt"
```

Si `next-sitemap` est absent, proposer l'installation :

```javascript
// next-sitemap.config.js
module.exports = {
  siteUrl: process.env.SITE_URL || 'https://domain.com',
  generateRobotsTxt: true,
  sitemapSize: 7000,
}
```

Et ajouter au `package.json` scripts : `"postbuild": "next-sitemap"`

### Etape 3 — Scanner les metadata

Chercher les metadata dans les layouts et pages :

```bash
echo "--- Metadata ---"
grep -rn "export const metadata" "$PROJECT_DIR/src/" 2>/dev/null | head -20
grep -rn "generateMetadata" "$PROJECT_DIR/src/" 2>/dev/null | head -20
```

Verifier pour chaque page/layout :
- [ ] `title` present et < 60 caracteres
- [ ] `description` present et < 160 caracteres
- [ ] `openGraph` (title, description, images)
- [ ] `alternates.canonical` defini

Reporter les pages sans metadata.

### Etape 4 — Verifier les images

```bash
echo "--- Images ---"
# Chercher les <img> natifs (devrait etre next/image)
grep -rn "<img " "$PROJECT_DIR/src/" 2>/dev/null | grep -v "node_modules" | head -10
echo ""
# Chercher les imports next/image
grep -rn "from.*next/image" "$PROJECT_DIR/src/" 2>/dev/null | wc -l
echo " composants utilisent next/image"
```

Signaler :
- Images `<img>` natives (remplacer par `next/image`)
- Images sans `alt`
- Images non-WebP dans `public/`

### Etape 5 — Structured Data (JSON-LD)

```bash
echo "--- Schema.org ---"
grep -rn "application/ld+json" "$PROJECT_DIR/src/" 2>/dev/null | head -10
grep -rn "schema.org" "$PROJECT_DIR/src/" 2>/dev/null | head -10
```

Si absent, proposer un schema de base :

```typescript
// components/JsonLd.tsx
export function JsonLd({ data }: { data: Record<string, unknown> }) {
  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(data) }}
    />
  )
}
```

### Etape 6 — Core Web Vitals (si deploye)

```bash
SITE_URL="${2:-}"
if [ -n "$SITE_URL" ]; then
  echo "--- Lighthouse ---"
  npx lighthouse "$SITE_URL" --output=json --output-path=./lighthouse-report.json --chrome-flags="--headless" 2>&1 | tail -5

  # Extraire les metriques cles
  node -e "
    const r = require('./lighthouse-report.json');
    const a = r.audits;
    console.log('LCP:', a['largest-contentful-paint']?.displayValue);
    console.log('INP:', a['interaction-to-next-paint']?.displayValue || 'N/A');
    console.log('CLS:', a['cumulative-layout-shift']?.displayValue);
    console.log('Performance:', r.categories.performance?.score * 100 + '%');
    console.log('SEO:', r.categories.seo?.score * 100 + '%');
  " 2>/dev/null
  rm -f lighthouse-report.json
fi
```

### Etape 7 — Rapport

Generer un rapport structure :

```
## Rapport SEO — [projet]

### Score global
- Performance : X%
- SEO Lighthouse : X%

### Problemes critiques
1. ...

### Ameliorations recommandees
1. ...

### Checklist
- [ ] Sitemap soumis a Google Search Console
- [ ] robots.txt correct
- [ ] Canonical URLs sur chaque page
- [ ] Meta title/description sur chaque page
- [ ] OpenGraph + Twitter cards
- [ ] Schema.org JSON-LD
- [ ] Core Web Vitals dans les seuils
- [ ] Images optimisees (next/image, WebP, alt)
- [ ] Pas de liens casses
- [ ] HTTPS + redirects 301
```

## Stack SEO recommandee

**Gratuit (a deployer sur chaque projet web)**
- **Google Search Console** : impressions, clics, indexation, Core Web Vitals
- **Lighthouse CLI** : `npx lighthouse https://site.com --view` (LCP < 2.5s, INP < 200ms, CLS < 0.1)
- **next-sitemap** : `pnpm add next-sitemap` — sitemap.xml + robots.txt auto
- **Screaming Frog** : audit technique desktop, gratuit jusqu'a 500 URLs
- **Ahrefs Webmaster Tools** : backlinks gratuit (site propre uniquement)
- **Google Keyword Planner** / **Google Trends** : recherche mots-cles + tendances

**Payant (selon palier)**
- **SE Ranking** (~$44/mo) : keyword research, site audits, rank tracking, competitor analysis
- **Ahrefs** ($129/mo) : backlinks leader, Content Explorer
- **Surfer SEO** ($99/mo) : content score, NLP terms, optimisation redactionnelle

## Regles

- Ne JAMAIS modifier de fichier sans demander (audit = lecture seule par defaut)
- Proposer les corrections sous forme de diff, attendre validation
- Toujours verifier si le site est deploye avant de lancer Lighthouse
- Pour les recommandations d'outils, voir la section « Stack SEO recommandee » ci-dessus
