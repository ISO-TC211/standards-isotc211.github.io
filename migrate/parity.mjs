#!/usr/bin/env node
// Compare two inventory manifests (from inventory.mjs).
//
// Without an allowlist, ANY difference fails.
// With --allowlist, differences listed there are expected and only reported.
//
// Allowlist format (JSON):
// {
//   "added":   ["404.html", "docs/**"],
//   "removed": ["package.json", "redirects.json"],
//   "changed": ["feed.xml"]        // same path, different bytes (HTML may differ)
// }
// Entries are exact relative paths, or end in "/**" for prefix matching.
//
// Usage: node migrate/parity.mjs <old.json> <new.json> [--allowlist allowlist.json] [--json out.json]
import { readFileSync, writeFileSync } from 'node:fs'

function parseArgs(argv) {
  const args = { allowlist: null, json: null }
  const positional = []
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--allowlist') args.allowlist = argv[++i]
    else if (argv[i] === '--json') args.json = argv[++i]
    else positional.push(argv[i])
  }
  if (positional.length !== 2) {
    console.error('Usage: node migrate/parity.mjs <old.json> <new.json> [--allowlist allowlist.json] [--json out.json]')
    process.exit(2)
  }
  return { oldFile: positional[0], newFile: positional[1], ...args }
}

function loadManifest(file) {
  const m = JSON.parse(readFileSync(file, 'utf8'))
  return new Map(m.files.map((f) => [f.path, f.sha256]))
}

function matches(entry, path) {
  if (entry.endsWith('/**')) return path.startsWith(entry.slice(0, -2))
  return entry === path
}

function classify(list, path) {
  return (list || []).some((entry) => matches(entry, path))
}

const { oldFile, newFile, allowlist: allowlistFile, json: jsonOut } = parseArgs(process.argv.slice(2))

const oldMap = loadManifest(oldFile)
const newMap = loadManifest(newFile)

const added = [...newMap.keys()].filter((p) => !oldMap.has(p))
const removed = [...oldMap.keys()].filter((p) => !newMap.has(p))
const changed = [...oldMap.keys()].filter((p) => newMap.has(p) && oldMap.get(p) !== newMap.get(p))

const allow = allowlistFile
  ? JSON.parse(readFileSync(allowlistFile, 'utf8'))
  : { added: [], removed: [], changed: [] }

const unexpected = { added: [], removed: [], changed: [] }
const expected = { added: [], removed: [], changed: [] }
for (const [bucket, list] of Object.entries({ added, removed, changed })) {
  for (const path of list) {
    const target = classify(allow[bucket], path) ? expected : unexpected
    target[bucket].push(path)
  }
}

// Allowlist entries that matched nothing — stale entries worth pruning.
const matchedPaths = new Set([...added, ...removed, ...changed])
const staleAllowlist = {}
for (const bucket of ['added', 'removed', 'changed']) {
  const stale = (allow[bucket] || []).filter(
    (entry) =>
      !matchedPaths.has(entry) &&
      !(entry.endsWith('/**') && [...matchedPaths].some((p) => matches(entry, p)))
  )
  if (stale.length) stale[bucket] = stale
}

const ok =
  unexpected.added.length === 0 &&
  unexpected.removed.length === 0 &&
  unexpected.changed.length === 0

const report = { ok, expected, unexpected, staleAllowlist }
if (jsonOut) writeFileSync(jsonOut, JSON.stringify(report, null, 2) + '\n')

const oldLabel = JSON.parse(readFileSync(oldFile, 'utf8')).dir
const newLabel = JSON.parse(readFileSync(newFile, 'utf8')).dir
console.log(`parity: ${oldLabel}  ->  ${newLabel}`)
console.log(`  added:   ${added.length} (${expected.added.length} allowlisted)`)
console.log(`  removed: ${removed.length} (${expected.removed.length} allowlisted)`)
console.log(`  changed: ${changed.length} (${expected.changed.length} allowlisted)`)

for (const bucket of ['added', 'removed', 'changed']) {
  if (expected[bucket].length) console.log(`\nallowlisted ${bucket}:`)
  for (const p of expected[bucket]) console.log(`  ~ ${p}`)
  if (unexpected[bucket].length) console.log(`\nUNEXPECTED ${bucket}:`)
  for (const p of unexpected[bucket]) console.log(`  ! ${p}`)
}
for (const bucket of Object.keys(staleAllowlist)) {
  for (const entry of staleAllowlist[bucket]) console.log(`\nSTALE allowlist entry (${bucket}): ${entry}`)
}
console.log(ok && Object.keys(staleAllowlist).length === 0
  ? '\nparity OK'
  : ok
    ? '\nparity OK (stale allowlist entries — prune them)'
    : '\nparity FAILED')

process.exit(ok ? 0 : 1)
