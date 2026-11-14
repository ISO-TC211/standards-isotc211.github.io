#!/usr/bin/env node
// Verify redirect outputs in a built tree.
//
// Two redirect classes exist on the ISO/TC 211 sites:
//   "data"  — the real target file must be copied to the old path
//             (XML parsers cannot follow HTML redirects)
//   "page"  — the old path must serve an HTML page with a meta refresh
//             (plus canonical link) pointing at the target
//
// The data/file decision follows the DATA_EXTENSIONS list from
// schemas.isotc211.org/_plugins/schema_site/models.rb.
//
// Input JSON format:
// [
//   { "from": "/19155/gpi/1.0/gpi.xsd", "to": "/19155/-/gpi/1.0/gpi.xsd" },
//   { "from": "/transforms/",           "to": "/resources/" }
// ]
//
// Usage: node migrate/redirects-check.mjs <dist-dir> redirects.json
import { createHash } from 'node:crypto'
import { readFileSync, existsSync } from 'node:fs'
import { join } from 'node:path'

const DATA_EXTENSIONS = new Set([
  '.xsd', '.xml', '.xsl', '.xslt', '.sch', '.json', '.zip',
  '.gml', '.svg', '.png', '.txt', '.adoc', '.ent', '.dtd',
])

function parseArgs(argv) {
  if (argv.length !== 2) {
    console.error('Usage: node migrate/redirects-check.mjs <dist-dir> redirects.json')
    process.exit(2)
  }
  return { dir: argv[0], listFile: argv[1] }
}

const sha256 = (p) => createHash('sha256').update(readFileSync(p)).digest('hex')

const { dir, listFile } = parseArgs(process.argv.slice(2))
const redirects = JSON.parse(readFileSync(listFile, 'utf8'))

function candidatesFor(from) {
  // A "from" ending in / is a directory-style page redirect; also accept a
  // bare path without extension as such.
  if (from.endsWith('/')) return [join(dir, from, 'index.html')]
  if (!from.endsWith('.html') && !DATA_EXTENSIONS.has(from.slice(from.lastIndexOf('.')))) {
    return [join(dir, from, 'index.html'), join(dir, `${from}.html`)]
  }
  return [join(dir, from)]
}

let failures = 0
for (const { from, to } of redirects) {
  const isData = !from.endsWith('/') && DATA_EXTENSIONS.has(from.slice(from.lastIndexOf('.')))
  if (isData) {
    const fromPath = join(dir, from)
    const toPath = join(dir, to.endsWith('/') ? join(to, 'index.html') : to)
    if (!existsSync(fromPath)) {
      console.log(`  ! MISSING data redirect target file: ${from}`)
      failures++
    } else if (sha256(fromPath) !== sha256(toPath)) {
      console.log(`  ! BYTES DIFFER: ${from} != ${to}`)
      failures++
    } else {
      console.log(`  ok data   ${from}`)
    }
  } else {
    const page = candidatesFor(from).find((p) => existsSync(p))
    if (!page) {
      console.log(`  ! MISSING page redirect: ${from} (no index.html found)`)
      failures++
      continue
    }
    const html = readFileSync(page, 'utf8')
    const hasRefresh = /http-equiv=["']?refresh/i.test(html) && html.includes(to)
    const hasCanonical =
      /rel=["']?canonical/i.test(html) && html.includes(to)
    if (!hasRefresh || !hasCanonical) {
      console.log(`  ! BAD page redirect ${from}: meta-refresh=${hasRefresh} canonical=${hasCanonical}`)
      failures++
    } else {
      console.log(`  ok page   ${from} -> ${to}`)
    }
  }
}

console.log(failures === 0 ? `redirects-check OK (${redirects.length} entries)` : `redirects-check FAILED (${failures})`)
process.exit(failures === 0 ? 0 : 1)
