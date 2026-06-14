#!/usr/bin/env python3
"""Skill audit-dette — Scan ecosysteme dette silencieuse.

Audite la dette technique non couverte par les hooks runtime (pre-check
binaires, marqueurs debug oublies). Le schema scanne (nom du workspace,
dossier de notes, prefixe des notes) est externalise en constantes
surchargeables par variables d'environnement (cf bloc CONFIG) : aucun chemin
specifique en dur, le scanner fonctionne pour n'importe quel dev / workspace.

Modes :
  --summary  : stats compactes
  --full     : rapport markdown complet dans dette-reports/

Sources scannees (resolues au runtime depuis l'environnement du dev courant) :
  ~/.claude/skills/*/SKILL.md             : pre-check absents, drift hash,
                                            frontmatter mismatch, content anomaly
  <workspace>/.claude/rules/              : refs path:line mortes
  <dossier de notes>/<prefixe>*.md        : refs path:line mortes
  <workspace>/.claude/dette-tracker.jsonl : TODO/marqueurs debug

Sortie :
  --summary -> stdout
  --full    -> ecrit dette-report-YYYY-MM-DD.md + stdout chemin

Detections SKILL.md (defense en profondeur, 3 niveaux complementaires) :
  1. detect_skill_drift          : hash bit-pour-bit identique entre 2 skills
  2. detect_frontmatter_mismatch : pas de --- ou name != nom_dossier
  3. detect_skill_content_anomaly: shebang, imports Python, contenu non-markdown
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import os
import re
import sys
from collections import Counter, defaultdict


# --- CONFIG : schema de scan externalise (multi-dev / depot partage) ---
# Defauts = schema de l'auteur ; surchargeables par variables d'environnement
# (renseignees via le profil dev local). Aucun littéral confidentiel ici : les
# valeurs par defaut restent generiques (un dossier de notes, un prefixe).
WORKSPACE_NAME = os.environ.get("AUDIT_DETTE_WORKSPACE_NAME", "wincorp-workspace")
MEMORY_DIRNAME = os.environ.get("AUDIT_DETTE_MEMORY_DIRNAME", "memory")
NOTE_PREFIX = os.environ.get("AUDIT_DETTE_NOTE_PREFIX", "feedback_")
PROJECT_SLUG_SUFFIX = os.environ.get(
    "AUDIT_DETTE_SLUG_SUFFIX", "-Documents-" + WORKSPACE_NAME
)


# Binaires sous enforcement (miroir du hook de pre-check des binaires)
ENFORCED_BINARIES = [
    "obsidian", "gh", "node", "npm", "npx", "pnpm", "yarn", "tsc",
    "python", "python3", "pip", "pip3", "pytest", "mypy", "ruff",
    "eslint", "prettier", "jq", "sops", "age", "docker",
    "docker-compose", "psql", "mysql",
]

BASH_BLOCK_REGEX = re.compile(r"```(?:bash|sh)\n(.*?)```", re.DOTALL)
BYPASS_REGEX = re.compile(r"precheck-handled(?:-elsewhere)?", re.IGNORECASE)
# path doit commencer par `.` (ex: .claude/hooks/X.py) ou `\w`
# (ex: repo-exemple/...). Lookbehind exclut `/`, `\w`, `.`, `-` pour eviter de matcher
# au milieu d'un autre path (ex: `repo-exemple/...` matchait aussi `exemple/...` apres `-`,
# `repo.exemple/...` matchait aussi `sous/...` apres `.`). Apres le 1er char, autoriser `()`
# (Next.js Route Groups: app/(payload)/api/...).
PATH_LINE_REGEX = re.compile(
    r"(?<![/\w.\-])([\.\w][\w./\-()]*\.(?:md|py|ts|tsx|js|jsx|sh|json|yaml|yml)):(\d+)"
)
WIKILINK_REGEX = re.compile(r"\[\[([\w_\-]+)(?:\|[^\]]+)?\]\]")
TRACKED_TODO_REGEX = re.compile(
    r"\b(?:TODO|FIXME|HACK|XXX)\(\d{4}-\d{2}-\d{2}\s*,\s*[^\)]+\)"
)

# Paths où console.log/debugger/pdb sont l'output legit (output legitime dans scripts CLI / workers / tests).
# Pas appliqué aux TODO/FIXME/HACK/XXX qui restent dette partout (sauf tests).
LEGIT_DEBUG_PATH_PATTERNS = (
    "/scripts/", "\\scripts\\", "scripts/",  # CLI tools (relatif ou absolu)
    "/cli/", "\\cli\\",
    "/bin/", "\\bin\\",
    "/worker/", "\\worker\\",
    "/__tests__/", "\\__tests__\\",
    "/tests/", "\\tests\\",
    ".test.", ".spec.",
)


def is_legit_debug_path(file_path: str) -> bool:
    """True si console.log/debugger/pdb dans ce fichier est l'output legit (chemins CLI/scripts/workers/tests)."""
    if not file_path:
        return False
    norm = file_path.replace("\\", "/").lower()
    # Tests : pattern .test. / .spec. ou répertoire dédié
    if "/__tests__/" in norm or "/tests/" in norm:
        return True
    if ".test." in norm or ".spec." in norm:
        return True
    # CLI / scripts / workers
    if "/scripts/" in norm or norm.startswith("scripts/"):
        return True
    if "/cli/" in norm or norm.startswith("cli/"):
        return True
    if "/bin/" in norm or norm.startswith("bin/"):
        return True
    if "/worker/" in norm or norm.startswith("worker/"):
        return True
    # Seeds Prisma (prisma/seed.ts) : batch one-off, console.log = output legit
    if "/prisma/" in norm or norm.startswith("prisma/"):
        return True
    # Scripts build/setup/post/emit (.mjs/.cjs hors src/) : tooling, jamais applicatif
    if norm.endswith((".mjs", ".cjs")) and "/src/" not in norm:
        return True
    # Outils CLI (package *-cli, fichier *-cli.* ou cli.*) : console.log = output principal
    if "-cli/" in norm or "-cli." in norm or "/cli." in norm or norm.startswith("cli."):
        return True
    # Throwaway / expérimentations ponctuelles (chantiers/)
    if "/chantiers/" in norm or norm.startswith("chantiers/"):
        return True
    # Infra Claude Code & sync : les hooks DEFINISSENT ces patterns (faux positif self),
    # skills/scan = outillage, pas du code produit.
    if (".claude/" in norm or "/hooks/" in norm or "hooks-snapshot" in norm
            or "claude-sync-source/" in norm):
        return True
    return False


# console.warn / console.error sont des channels production legit (Sentry, Coolify logs).
# Le hook detect-debt-markers les filtre desormais (regex log|debug|info uniquement),
# mais les anciennes entrees dans dette-tracker.jsonl ont type=console.log pour tous
# les console.X. On filtre par contexte pour les anciennes entrees.
CONSOLE_LEGIT_CHANNEL_REGEX = re.compile(r"console\.(warn|error)\s*\(")


def is_legit_debug_entry(entry: dict) -> bool:
    """True si entry est un faux positif debug (faux positif debug + channels production)."""
    if is_legit_debug_path(entry.get("file", "")):
        return True
    # console.warn/error = channels production legit (pas debug oublie)
    if entry.get("type") == "console.log":
        ctx = entry.get("context", "") or ""
        if CONSOLE_LEGIT_CHANNEL_REGEX.search(ctx):
            return True
    return False


# --- Scan LIVE des debug markers (robuste vs dette-tracker.jsonl append) ---
# Le tracker accumule des entrées historiques (console.log depuis supprimés du
# code) → sur-rapport chronique. Le scan live reflète l'état RÉEL du code.
DEBUG_SCAN_EXTS = (".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".py")
DEBUG_PRUNE_DIRS = {
    "node_modules", "dist", ".next", "build", "coverage", "out",
    ".git", ".turbo", "__pycache__", ".venv", "venv", ".cache",
}
CONSOLE_LOG_RE = re.compile(r"console\.log\s*\(")
DEBUGGER_RE = re.compile(r"(?:^|[\s;{])debugger\s*;?\s*$")
PDB_RE = re.compile(r"pdb\.set_trace\s*\(|(?:^|\s)breakpoint\s*\(\s*\)")
ESLINT_DISABLE_NOCONSOLE_RE = re.compile(r"eslint-disable.*no-console")


def scan_debug_markers_live(workspace_root: str) -> "tuple[Counter, dict]":
    """Scan live des debug markers oubliés dans le code applicatif.

    Source de vérité = le code réel (PAS dette-tracker.jsonl qui accumule des
    entrées stale). Exclut : chemins CLI (scripts/worker/cli/bin/tests),
    console.warn/error (channels prod), console.log justifié par
    `eslint-disable no-console` (pattern légitime du codebase). Cf conventions de chemins CLI/tests.
    """
    counts: Counter = Counter()
    hits: dict = {"console.log": [], "debugger": [], "pdb.set_trace": []}
    for root, dirs, files in os.walk(workspace_root):
        dirs[:] = [d for d in dirs if d not in DEBUG_PRUNE_DIRS]
        for fn in files:
            ext = os.path.splitext(fn)[1].lower()
            if ext not in DEBUG_SCAN_EXTS:
                continue
            fpath = os.path.join(root, fn)
            rel = os.path.relpath(fpath, workspace_root).replace("\\", "/")
            if is_legit_debug_path(rel):
                continue
            try:
                with open(fpath, encoding="utf-8", errors="replace") as fh:
                    file_lines = fh.read().splitlines()
            except OSError:
                continue
            is_py = ext == ".py"
            for idx, line in enumerate(file_lines):
                if is_py:
                    if PDB_RE.search(line):
                        counts["pdb.set_trace"] += 1
                        hits["pdb.set_trace"].append(f"{rel}:{idx + 1}")
                    continue
                if CONSOLE_LOG_RE.search(line):
                    prev = file_lines[idx - 1] if idx > 0 else ""
                    if not (ESLINT_DISABLE_NOCONSOLE_RE.search(line)
                            or ESLINT_DISABLE_NOCONSOLE_RE.search(prev)):
                        counts["console.log"] += 1
                        hits["console.log"].append(f"{rel}:{idx + 1}")
                if DEBUGGER_RE.search(line):
                    counts["debugger"] += 1
                    hits["debugger"].append(f"{rel}:{idx + 1}")
    return counts, hits


def home() -> str:
    return os.path.expanduser("~")


def find_workspace_root() -> str:
    """Trouve le workspace en partant de cwd, fallback HOME/Documents/<name>."""
    cwd = os.getcwd()
    home_dir = home()
    p = cwd
    while True:
        if os.path.basename(p) == WORKSPACE_NAME:
            return p
        # `.claude/settings.json` marque un workspace de projet — mais exclure le
        # `.claude` GLOBAL de HOME (~/.claude), qui n'est PAS un workspace projet.
        if p != home_dir and os.path.isfile(
            os.path.join(p, ".claude", "settings.json")
        ):
            return p
        parent = os.path.dirname(p)
        if parent == p:
            break
        p = parent
    fallback = os.path.join(home_dir, "Documents", WORKSPACE_NAME)
    if os.path.isdir(fallback):
        return fallback
    return cwd


def has_precheck(content: str, binary: str) -> bool:
    patterns = [
        rf"\bcommand\s+-v\s+{re.escape(binary)}\b",
        rf"\bwhich\s+{re.escape(binary)}\b",
        rf"\btype\s+-p\s+{re.escape(binary)}\b",
        rf"\b{re.escape(binary)}\s+--help\b",
        rf"\b{re.escape(binary)}\s+--version\b",
    ]
    return any(re.search(p, content) for p in patterns)


def scan_skill_for_unprotected_binaries(skill_path: str) -> list[str]:
    try:
        with open(skill_path, "r", encoding="utf-8") as f:
            content = f.read()
    except Exception:
        return []
    if BYPASS_REGEX.search(content):
        return []
    violations: list[str] = []
    for match in BASH_BLOCK_REGEX.finditer(content):
        block = match.group(1)
        for binary in ENFORCED_BINARIES:
            if binary in violations:
                continue
            usage = rf"(?m)^\s*(?:[A-Z_]+=\$\([^)]*\)\s*)?{re.escape(binary)}\b"
            if re.search(usage, block) and not has_precheck(content, binary):
                violations.append(binary)
    return violations


def hash_content(path: str) -> str:
    try:
        with open(path, "rb") as f:
            return hashlib.sha256(f.read()).hexdigest()[:12]
    except Exception:
        return ""


def detect_skill_drift(skills_root: str) -> list[tuple[str, str, int]]:
    """Detecte les SKILL.md identiques bit-a-bit ou >95% similaires en taille."""
    skills: dict[str, tuple[str, int]] = {}
    if not os.path.isdir(skills_root):
        return []
    for entry in sorted(os.listdir(skills_root)):
        skill_dir = os.path.join(skills_root, entry)
        skill_md = os.path.join(skill_dir, "SKILL.md")
        if not os.path.isfile(skill_md):
            continue
        h = hash_content(skill_md)
        try:
            size = os.path.getsize(skill_md)
        except Exception:
            continue
        skills[entry] = (h, size)

    drifts: list[tuple[str, str, int]] = []
    by_hash: dict[str, list[str]] = defaultdict(list)
    for name, (h, _) in skills.items():
        if h:
            by_hash[h].append(name)
    for h, names in by_hash.items():
        if len(names) > 1:
            for i, a in enumerate(names):
                for b in names[i + 1:]:
                    drifts.append((a, b, skills[a][1]))
    return drifts


def detect_skill_content_anomaly(skills_root: str) -> list[tuple[str, str]]:
    """Detecte SKILL.md dont le contenu n'est PAS du markdown.

    Complementaire a detect_frontmatter_mismatch : dit POURQUOI un SKILL.md
    est corrompu (shebang, code Python, etc.) au lieu de juste "<no-frontmatter>".

    Complement utile quand un SKILL.md a ete ecrase par un script (shebang) ou
    par du code (imports Python) : sans ce check, on ne verrait que
    `<no-frontmatter>` sans pointer vers la cause reelle.

    Patterns suspects detectes (10 premieres lignes) :
    - shebang `#!/` en ligne 1 (script bash/python a la place d'un .md)
    - 1ere ligne non-vide ne commence pas par `---` (frontmatter), `#` (titre),
      ou `>` (blockquote) — SKILL.md doit etre du markdown
    - `from __future__` / `import os` / `import sys` dans les 10 premieres lignes

    Retourne liste de (skill_dir_name, reason).
    """
    anomalies: list[tuple[str, str]] = []
    if not os.path.isdir(skills_root):
        return anomalies
    for entry in sorted(os.listdir(skills_root)):
        skill_md = os.path.join(skills_root, entry, "SKILL.md")
        if not os.path.isfile(skill_md):
            continue
        try:
            with open(skill_md, "r", encoding="utf-8") as f:
                first_lines: list[tuple[int, str]] = []
                for i, raw in enumerate(f):
                    if i >= 10:
                        break
                    line = raw.rstrip("\n").rstrip("\r")
                    first_lines.append((i, line))
        except Exception:
            continue
        if not first_lines:
            continue
        # Trouver la premiere ligne non-vide
        first_nonblank: tuple[int, str] | None = None
        for idx, line in first_lines:
            if line.strip():
                first_nonblank = (idx, line)
                break
        if first_nonblank is None:
            continue
        first_idx, first_line = first_nonblank
        # Check 1 : shebang en debut
        if first_line.startswith("#!/"):
            anomalies.append((entry, f"shebang ligne {first_idx + 1} : `{first_line[:60]}`"))
            continue
        # Check 2 : premier non-vide ne commence pas par marqueur markdown valide
        # (frontmatter `---`, titre `#`, blockquote `>`, separator HTML `<!--`)
        valid_starts = ("---", "#", ">", "<!--")
        if not any(first_line.startswith(s) for s in valid_starts):
            anomalies.append(
                (entry, f"ligne {first_idx + 1} non-markdown : `{first_line[:60]}`")
            )
            continue
        # Check 3 : import / class / def Python dans les 10 premieres lignes
        # (au cas ou shebang absent mais code Python present)
        python_markers = ("from __future__", "import os", "import sys", "import re")
        for idx, line in first_lines:
            stripped = line.lstrip()
            if any(stripped.startswith(m) for m in python_markers):
                anomalies.append(
                    (entry, f"Python import ligne {idx + 1} : `{line.strip()[:60]}`")
                )
                break
    return anomalies


def detect_frontmatter_mismatch(skills_root: str) -> list[tuple[str, str]]:
    """Detecte les SKILL.md avec `frontmatter name` qui ne correspond pas au dossier.

    Drift partiel (different du hash-identique) : un SKILL.md dont le frontmatter
    `name:` ne correspond plus au nom du dossier (contenu different mais
    frontmatter cassee), invisible pour detect_skill_drift (hash-different).

    Retourne liste de (skill_dir_name, actual_frontmatter_name).
    """
    mismatches: list[tuple[str, str]] = []
    if not os.path.isdir(skills_root):
        return mismatches
    for entry in sorted(os.listdir(skills_root)):
        skill_dir = os.path.join(skills_root, entry)
        skill_md = os.path.join(skill_dir, "SKILL.md")
        if not os.path.isfile(skill_md):
            continue
        try:
            with open(skill_md, "r", encoding="utf-8") as f:
                first = f.readline().rstrip("\n").rstrip("\r")
                if first != "---":
                    # Pas de frontmatter — signaler comme mismatch (skill orpheline)
                    mismatches.append((entry, "<no-frontmatter>"))
                    continue
                # Parse frontmatter ligne par ligne jusqu'au --- de fermeture
                fm_name = ""
                for line in f:
                    line = line.rstrip("\n").rstrip("\r")
                    if line == "---":
                        break
                    if line.startswith("name:"):
                        fm_name = line.split(":", 1)[1].strip()
                        break
        except Exception:
            continue
        if fm_name and fm_name != entry:
            mismatches.append((entry, fm_name))
    return mismatches


def detect_template_corruption(skills_root: str) -> list[tuple[str, str]]:
    """Detecte les fichiers */templates/*.md ecrases par le contenu d'un SKILL.md.

    Angle mort de detect_frontmatter_mismatch (qui ne scanne que les SKILL.md) :
    un fichier */templates/*.md peut se retrouver ecrase par le SKILL.md d'une
    autre skill (ecrasement par un voisin lors d'une sync). Meme classe de bug
    que la corruption de frontmatter.

    Critere de corruption (un template n'est PAS un SKILL.md) :
      - frontmatter present ET contient `disable-model-invocation:` (champ exclusif SKILL.md), OU
      - `name:` dont la valeur est un nom de skill REELLEMENT existant dans skills_root.
    Un template legitime avec `name: <module>` non-skill (ex PLAN-AMONT `name: <module>.plan`)
    n'est PAS flagge.

    Retourne liste de (template_relpath, raison).
    """
    corrupt: list[tuple[str, str]] = []
    if not os.path.isdir(skills_root):
        return corrupt
    skill_names = {
        e for e in os.listdir(skills_root)
        if os.path.isdir(os.path.join(skills_root, e))
    }
    for entry in sorted(skill_names):
        tpl_dir = os.path.join(skills_root, entry, "templates")
        if not os.path.isdir(tpl_dir):
            continue
        for root, _dirs, files in os.walk(tpl_dir):
            for fname in sorted(files):
                if not fname.endswith(".md"):
                    continue
                fpath = os.path.join(root, fname)
                rel = os.path.relpath(fpath, skills_root).replace("\\", "/")
                try:
                    with open(fpath, "r", encoding="utf-8") as f:
                        first = f.readline().rstrip("\n").rstrip("\r")
                        if first != "---":
                            continue  # pas de frontmatter -> template markdown sain
                        fm_name = ""
                        has_dmi = False
                        for line in f:
                            line = line.rstrip("\n").rstrip("\r")
                            if line == "---":
                                break
                            if line.startswith("name:"):
                                fm_name = line.split(":", 1)[1].strip()
                            if line.startswith("disable-model-invocation:"):
                                has_dmi = True
                except Exception:
                    continue
                if has_dmi:
                    corrupt.append((rel, "contient `disable-model-invocation` (signature SKILL.md ecrasant le template)"))
                elif fm_name and fm_name in skill_names and fm_name != entry:
                    corrupt.append((rel, f"`name: {fm_name}` = skill existante (SKILL.md copie dans le template)"))
    return corrupt


def load_dette_tracker(workspace_root: str) -> list[dict]:
    jsonl = os.path.join(workspace_root, ".claude", "dette-tracker.jsonl")
    if not os.path.isfile(jsonl):
        return []
    entries: list[dict] = []
    try:
        with open(jsonl, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entries.append(json.loads(line))
                except Exception:
                    continue
    except Exception:
        return []
    return entries


def days_since(ts_str: str) -> int:
    try:
        ts = datetime.datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
        now = datetime.datetime.now(datetime.timezone.utc)
        return (now - ts).days
    except Exception:
        return 0


def deduplicate_dette(entries: list[dict]) -> list[dict]:
    """Garde la premiere apparition de chaque (file, line, type, context)."""
    seen: set[tuple] = set()
    out: list[dict] = []
    for e in entries:
        key = (e.get("file", ""), e.get("line", 0), e.get("type", ""), e.get("context", ""))
        if key in seen:
            continue
        seen.add(key)
        out.append(e)
    return out


def scan_dead_refs(rules_root: str, memory_root: str) -> list[tuple[str, str]]:
    """Scanne les refs path:line dans rules/ et les notes de memoire.

    Retourne liste de (source_file, missing_ref).
    """
    dead: list[tuple[str, str]] = []
    sources: list[str] = []
    if os.path.isdir(rules_root):
        sources.extend(
            os.path.join(rules_root, f)
            for f in os.listdir(rules_root)
            if f.endswith(".md")
        )
    if os.path.isdir(memory_root):
        sources.extend(
            os.path.join(memory_root, f)
            for f in os.listdir(memory_root)
            if f.startswith(NOTE_PREFIX) and f.endswith(".md")
        )

    # Bases candidates pour resolution multi-format :
    # - workspace_root : refs CWD-relatif `<repo>/...` (format canonique)
    # - memory_root : refs vers une note du dossier de notes
    # - home : refs `../../../Documents/...` ou `../../../../Documents/...`
    # - dirname(src) : refs relatives au fichier source lui-meme
    workspace_root = os.path.dirname(os.path.dirname(rules_root))
    home_dir = os.path.expanduser("~")

    def _try_resolve(ref: str, src_dir: str) -> bool:
        """True si la ref se resout vers un fichier existant depuis n'importe quelle base."""
        bases = [workspace_root, memory_root, home_dir, src_dir]
        for base in bases:
            if not base:
                continue
            # normpath gere les '../' correctement (mais sur Windows convertit / en \)
            cand = os.path.normpath(os.path.join(base, ref))
            if os.path.isfile(cand):
                return True
        return False

    for src in sources:
        try:
            with open(src, "r", encoding="utf-8") as f:
                content = f.read()
        except Exception:
            continue
        src_dir = os.path.dirname(src)
        for match in PATH_LINE_REGEX.finditer(content):
            ref_path = match.group(1)
            # Ignore les refs internes au dossier de notes (deja resolues par ref croisee)
            if ref_path.startswith(MEMORY_DIRNAME + "/") or ref_path.startswith(NOTE_PREFIX):
                candidate = os.path.join(memory_root, os.path.basename(ref_path))
                if not os.path.isfile(candidate):
                    dead.append((os.path.basename(src), ref_path))
                continue
            # Refs avec / -> tenter resolution multi-base avant de declarer mort
            if "/" in ref_path and not ref_path.startswith("wincorp-"):
                if not _try_resolve(ref_path, src_dir):
                    dead.append((os.path.basename(src), ref_path))
    return dead


def render_summary(stats: dict) -> str:
    lines = [
        f"Dette totale : {stats['total']} entrees ({stats['total_tracked']} tracees, "
        f"{stats['total_untracked']} non tracees)",
        f"Plus ancienne dette : {stats['oldest_days']} jours",
        f"Skills sans pre-check : {stats['skills_no_precheck']}",
        f"Drift skills detectes : {stats['drifts']}",
        f"Frontmatter mismatch : {stats['frontmatter_mismatch']}",
        f"Content anomalies : {stats['content_anomalies']}",
        f"Templates corrompus : {stats['template_corruption']}",
        f"Refs path:line mortes : {stats['dead_refs']}",
        f"Marqueurs debug : console.log={stats['console_log']}, "
        f"debugger={stats['debugger']}, pdb={stats['pdb']}",
    ]
    return "\n".join(lines)


def render_full_report(stats: dict, today: str) -> str:
    lines = [f"# Rapport audit dette — {today}", ""]
    lines.append("## Resume chiffre")
    lines.append(f"- Dette totale : **{stats['total']}** entrees")
    lines.append(
        f"- Tracee (format conforme) : {stats['total_tracked']} / {stats['total']} "
        f"({stats['tracked_pct']}%)"
    )
    lines.append(f"- Non tracee : **{stats['total_untracked']}**")
    if stats["total"] > 0:
        lines.append(f"- Plus ancienne : {stats['oldest_days']} jours")
    lines.append("")

    lines.append("## Skills sans pre-check (violations Couche 2 residuelles)")
    if not stats["skills_violations"]:
        lines.append("- aucune (hook actif)")
    else:
        for skill, binaries in stats["skills_violations"]:
            lines.append(f"- `{skill}` : {', '.join(binaries)}")
    lines.append("")

    lines.append("## Drift entre skills (hash compare)")
    if not stats["drift_pairs"]:
        lines.append("- aucun drift detecte")
    else:
        for a, b, size in stats["drift_pairs"]:
            lines.append(f"- `{a}` == `{b}` (hash identique, {size} octets)")
    lines.append("")

    lines.append("## Frontmatter mismatch (drift partiel)")
    if not stats["frontmatter_mismatch_list"]:
        lines.append("- aucun (chaque SKILL.md a `name: <dossier>`)")
    else:
        for skill_dir, actual_name in stats["frontmatter_mismatch_list"]:
            lines.append(f"- `{skill_dir}/SKILL.md` -> `name: {actual_name}` (attendu: `{skill_dir}`)")
    lines.append("")

    lines.append("## Content anomalies (SKILL.md non-markdown)")
    if not stats["content_anomaly_list"]:
        lines.append("- aucune (chaque SKILL.md est du markdown valide)")
    else:
        for skill_dir, reason in stats["content_anomaly_list"]:
            lines.append(f"- `{skill_dir}/SKILL.md` -> {reason}")
    lines.append("")

    lines.append("## Templates corrompus (template ecrase par un voisin)")
    if not stats["template_corruption_list"]:
        lines.append("- aucun (chaque */templates/*.md est un template, pas un SKILL.md copie)")
    else:
        for rel, reason in stats["template_corruption_list"]:
            lines.append(f"- `{rel}` -> {reason}")
    lines.append("")

    lines.append("## Refs path:line mortes")
    if not stats["dead_refs_list"]:
        lines.append("- aucune")
    else:
        for src, ref in stats["dead_refs_list"][:30]:
            lines.append(f"- `{src}` -> `{ref}` (introuvable)")
        if len(stats["dead_refs_list"]) > 30:
            lines.append(f"- ... et {len(stats['dead_refs_list']) - 30} autres")
    lines.append("")

    lines.append("## TODO/FIXME non traces — top 10 par age")
    untracked = stats["untracked_top"]
    if not untracked:
        lines.append("- aucun")
    else:
        lines.append("| Age | Type | Fichier | Ligne | Contexte |")
        lines.append("|-----|------|---------|-------|----------|")
        for e in untracked[:10]:
            ctx = (e.get("context") or "").replace("|", "\\|")[:80]
            lines.append(
                f"| {e['_age']}j | {e['type']} | `{e['file']}` | {e['line']} | `{ctx}` |"
            )
    lines.append("")

    lines.append("## Marqueurs debug oublies (scan live du code applicatif)")
    lines.append(f"- `console.log` : {stats['console_log']}")
    lines.append(f"- `debugger` : {stats['debugger']}")
    lines.append(f"- `pdb.set_trace` / `breakpoint` : {stats['pdb']}")
    debug_hits = stats.get("debug_hits", {})
    for marker in ("console.log", "debugger", "pdb.set_trace"):
        hit_list = debug_hits.get(marker, [])
        if hit_list:
            lines.append(f"\n  Localisation `{marker}` ({len(hit_list)}) :")
            for h in hit_list[:20]:
                lines.append(f"  - {h}")
            if len(hit_list) > 20:
                lines.append(f"  - … +{len(hit_list) - 20} autres")
    lines.append("")

    lines.append("## Recommandation")
    if stats["total_untracked"] > 30 or stats["oldest_days"] > 90:
        lines.append(
            "**Sprint dette dedie** recommande : > 30 entrees non tracees ou "
            "dette > 90j detectee."
        )
    elif (stats["skills_violations"] or stats["drift_pairs"]
          or stats["frontmatter_mismatch_list"] or stats["content_anomaly_list"]
          or stats["template_corruption_list"]):
        lines.append(
            "**Fix immediat** recommande : drift skills, frontmatter mismatch, "
            "content anomaly, template corrompu ou pre-check residuel detecte."
        )
    else:
        lines.append(
            "**Statut OK** — niveau dette acceptable. Continuer a tracer les "
            "TODO via format `(YYYY-MM-DD, project_*.md)`."
        )
    lines.append("")

    return "\n".join(lines)


def compute_stats() -> dict:
    workspace_root = find_workspace_root()
    skills_root = os.path.join(home(), ".claude", "skills")
    rules_root = os.path.join(workspace_root, ".claude", "rules")

    # Memory root : slug Windows-friendly
    candidates_mem = [
        d for d in os.listdir(os.path.join(home(), ".claude", "projects"))
        if d.endswith(PROJECT_SLUG_SUFFIX)
    ] if os.path.isdir(os.path.join(home(), ".claude", "projects")) else []
    memory_root = ""
    if candidates_mem:
        memory_root = os.path.join(
            home(), ".claude", "projects", candidates_mem[0], "memory"
        )

    # Skills sans pre-check
    skills_violations: list[tuple[str, list[str]]] = []
    if os.path.isdir(skills_root):
        for entry in sorted(os.listdir(skills_root)):
            skill_md = os.path.join(skills_root, entry, "SKILL.md")
            if os.path.isfile(skill_md):
                viol = scan_skill_for_unprotected_binaries(skill_md)
                if viol:
                    skills_violations.append((entry, viol))

    # Drift hash skills
    drift_pairs = detect_skill_drift(skills_root)

    # Frontmatter mismatch (drift partiel)
    frontmatter_mismatch_list = detect_frontmatter_mismatch(skills_root)

    # Content anomaly (SKILL.md non-markdown)
    content_anomaly_list = detect_skill_content_anomaly(skills_root)

    # Template corruption (angle mort frontmatter_mismatch)
    template_corruption_list = detect_template_corruption(skills_root)

    # Refs path:line mortes
    dead_refs_list = scan_dead_refs(rules_root, memory_root) if memory_root else []

    # Dette tracker
    raw_entries = load_dette_tracker(workspace_root)
    entries = deduplicate_dette(raw_entries)

    todo_types = {"TODO", "FIXME", "HACK", "XXX"}

    # TODO/FIXME : dette partout SAUF tests (chemins CLI/scripts/workers/tests)
    todo_entries = [
        e for e in entries
        if e.get("type") in todo_types and not (
            "/__tests__/" in (e.get("file", "") or "").replace("\\", "/").lower()
            or "/tests/" in (e.get("file", "") or "").replace("\\", "/").lower()
            or ".test." in (e.get("file", "") or "").lower()
            or ".spec." in (e.get("file", "") or "").lower()
        )
    ]
    # Debug markers (console.log/debugger/pdb) : SCAN LIVE du code réel, PAS le
    # dette-tracker.jsonl (qui accumule des entrées stale → sur-rapport chronique).
    # Honore `eslint-disable no-console` (pattern légitime). Cf conventions de chemins CLI/tests.
    live_debug_counts, live_debug_hits = scan_debug_markers_live(workspace_root)
    total_debug = sum(live_debug_counts.values())

    tracked = sum(1 for e in todo_entries if e.get("tracked"))
    untracked_entries = [e for e in todo_entries if not e.get("tracked")]
    for e in untracked_entries:
        e["_age"] = days_since(e.get("ts", ""))
    untracked_entries.sort(key=lambda e: e["_age"], reverse=True)

    oldest_days = max((e["_age"] for e in untracked_entries), default=0)

    return {
        "workspace_root": workspace_root,
        "skills_violations": skills_violations,
        "drifts": len(drift_pairs),
        "drift_pairs": drift_pairs,
        "frontmatter_mismatch": len(frontmatter_mismatch_list),
        "frontmatter_mismatch_list": frontmatter_mismatch_list,
        "content_anomalies": len(content_anomaly_list),
        "content_anomaly_list": content_anomaly_list,
        "template_corruption": len(template_corruption_list),
        "template_corruption_list": template_corruption_list,
        "dead_refs": len(dead_refs_list),
        "dead_refs_list": dead_refs_list,
        "total": len(todo_entries) + total_debug,
        "total_tracked": tracked,
        "total_untracked": len(untracked_entries),
        "tracked_pct": round(100 * tracked / max(len(todo_entries), 1), 1),
        "oldest_days": oldest_days,
        "skills_no_precheck": len(skills_violations),
        "untracked_top": untracked_entries,
        "console_log": live_debug_counts.get("console.log", 0),
        "debugger": live_debug_counts.get("debugger", 0),
        "pdb": live_debug_counts.get("pdb.set_trace", 0),
        "debug_hits": live_debug_hits,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--summary",
        action="store_true",
        help="Affiche 5 lignes de stats (defaut /bonjour 6ter)",
    )
    parser.add_argument(
        "--full",
        action="store_true",
        help="Genere rapport markdown complet dans dette-reports/ (defaut)",
    )
    args = parser.parse_args()

    stats = compute_stats()

    if args.summary:
        print(render_summary(stats))
        return

    today = datetime.date.today().isoformat()
    report = render_full_report(stats, today)

    out_dir = os.path.join(stats["workspace_root"], ".claude", "dette-reports")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, f"dette-report-{today}.md")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(report)

    print(f"Rapport ecrit : {out_path}")
    print()
    print(render_summary(stats))


if __name__ == "__main__":
    main()
