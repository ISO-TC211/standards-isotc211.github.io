#!/usr/bin/env node
// Compare two feed files (Atom from jekyll-feed, RSS/Atom from @astrojs/rss).
// Absolute URLs, or site-relative URLs resolved against --base, are compared
// as multisets (order-insensitive).
//
// Usage: node migrate/feed-check.mjs <old-feed.xml> <new-feed.xml> [--base https://schemas.isotc211.org] [--host schemas.isotc211.org]
import { readFileSync } from 'node:fs'

function parseArgs(argv) {
  const args = { base: null, host: null }
  const positional = []
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--base') args.base = argv[++i]
    else if (argv[i] === '--host') args.host = argv[++i]
    else positional.push(argv[i])
  }
  if (positional.length !== 2) {
    console.error('Usage: node migrate/feed-check.mjs <old-feed.xml> <new-feed.xml> [--base https://example.org] [--host example.org]')
    process.exit(2)
  }
  return { oldFile: positional[0], newFile: positional[1], ...args }
}

function extractUrls(file, base) {
  const xml = readFileSync(file, 'utf8')
  const urls = []
  for (const m of xml.matchAll(/<(?:loc|guid|id)(?:\s[^>]*)?>([^<]+)<\/(?:loc|guid|id)>/g)) {
    let v = m[1].trim()
    if (/^https?:\/\//.test(v)) urls.push(v)
    else if (base && v.startsWith('/')) urls.push(base.replace(/\/$/, '') + v)
  }
  for (const m of xml.matchAll(/<link\b[^>]*\bhref=["']([^"']+)["'][^>]*>/g)) {
    let v = m[1]
    if (/^https?:\/\//.test(v)) urls.push(v)
    else if (base && v.startsWith('/')) urls.push(base.replace(/\/$/, '') + v)
  }
  return urls
}

function count(list) {
  const m = new Map()
  for (const u of list) m.set(u, (m.get(u) || 0) + 1)
  return m
}

const { oldFile, newFile, base, host } = parseArgs(process.argv.slice(2))
const keep = host ? (u) => u.includes(host) : () => true

const oldUrls = extractUrls(oldFile, base).filter(keep)
const newUrls = extractUrls(newFile, base).filter(keep)

const oldCount = count(oldUrls)
const newCount = count(newUrls)
const missing = [...oldCount.keys()].filter((u) => (newCount.get(u) || 0) < oldCount.get(u))
const extra = [...newCount.keys()].filter((u) => (oldCount.get(u) || 0) < newCount.get(u))

console.log(`feed-check: old ${oldUrls.length} URLs, new ${newUrls.length} URLs${base ? ` (base: ${base})` : ''}`)
for (const u of missing) console.log(`  ! MISSING from new feed: ${u}`)
for (const u of extra) console.log(`  ! EXTRA in new feed: ${u}`)

const ok = missing.length === 0 && extra.length === 0
console.log(ok ? 'feed-check OK' : 'feed-check FAILED')
process.exit(ok ? 0 : 1)
