#!/usr/bin/env node
// Structural smoke checks over generated HTML: every page must carry the
// shared chrome (nav header, dark-mode FOUC script, skip link), and forbidden
// strings must appear nowhere.
//
// Self-contained SPA pages (lutaml browse pages) are excluded by default.
//
// Usage: node migrate/html-smoke.mjs <dir> [--config smoke.json] [--json out.json]
//
// Optional config (JSON), overriding/extending defaults:
// {
//   "forbidden": ["/schemas/19"],                       // substrings no page may contain
//   "required": { "nav-header": "id=\"nav-header\"" },  // substrings every page must contain
//   "excludePaths": ["**/browse/**"],                   // prefix or exact relative paths
//   "excludeContains": ["/vite-dev/"]                   // skip dev-built trees entirely
// }
import { readdirSync, readFileSync, writeFileSync } from 'node:fs'
import { join, relative } from 'node:path'

function parseArgs(argv) {
  const args = { config: null, json: null }
  const positional = []
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--config') args.config = argv[++i]
    else if (argv[i] === '--json') args.json = argv[++i]
    else positional.push(argv[i])
  }
  if (positional.length !== 1) {
    console.error('Usage: node migrate/html-smoke.mjs <dir> [--config smoke.json] [--json out.json]')
    process.exit(2)
  }
  return { dir: positional[0], ...args }
}

function walk(dir, base = dir, files = []) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name)
    if (entry.isDirectory()) walk(full, base, files)
    else if (entry.isFile() && entry.name.endsWith('.html'))
      files.push(relative(base, full).split('\\').join('/'))
  }
  return files
}

const DEFAULTS = {
  forbidden: [],
  required: {
    'nav-header': 'id="nav-header"',
    'dark-mode FOUC script': 'iso-tc211-theme',
    'skip link': 'skip-link',
  },
  excludePaths: ['**/browse/**'],
  excludeContains: [],
}

const { dir, config: configFile, json: jsonOut } = parseArgs(process.argv.slice(2))
const cfg = configFile
  ? { ...DEFAULTS, ...JSON.parse(readFileSync(configFile, 'utf8')) }
  : DEFAULTS

// Supports exact paths, "dir/**" prefixes, and "**/dir/**" substring patterns.
function matchesPattern(path, entry) {
  const anchored = !entry.startsWith('**/')
  const e = anchored ? entry : entry.slice(3)
  if (e.endsWith('/**')) {
    const prefix = e.slice(0, -2)
    return anchored ? path.startsWith(prefix) : path.includes(prefix)
  }
  return anchored ? path === entry : path.includes(entry)
}

function excluded(path) {
  if ((cfg.excludePaths || []).some((e) => matchesPattern(path, e))) return true
  return (cfg.excludeContains || []).some((s) => path.includes(s))
}

const htmlFiles = walk(dir).filter((p) => !excluded(p))

const violations = []
let checked = 0
for (const rel of htmlFiles) {
  const html = readFileSync(join(dir, rel), 'utf8')
  checked++
  for (const [label, needle] of Object.entries(cfg.required)) {
    if (!html.includes(needle)) violations.push({ path: rel, kind: 'missing', detail: label })
  }
  for (const needle of cfg.forbidden) {
    if (html.includes(needle)) violations.push({ path: rel, kind: 'forbidden', detail: needle })
  }
}

const report = { ok: violations.length === 0, checked, violations }
if (jsonOut) writeFileSync(jsonOut, JSON.stringify(report, null, 2) + '\n')
console.log(`html-smoke: ${checked} pages checked (${htmlFiles.length} total .html, rest excluded)`)
for (const v of violations.slice(0, 50)) console.log(`  ! ${v.kind}: ${v.path} — ${v.detail}`)
if (violations.length > 50) console.log(`  … and ${violations.length - 50} more`)
console.log(violations.length === 0 ? 'html-smoke OK' : `html-smoke FAILED (${violations.length} violations)`)
process.exit(violations.length === 0 ? 0 : 1)
