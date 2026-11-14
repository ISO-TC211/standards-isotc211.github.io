#!/usr/bin/env node
// Build a manifest of every file in a build directory: path, size, SHA-256.
//
// Usage: node migrate/inventory.mjs <build-dir> -o manifest.json
import { createHash } from 'node:crypto'
import { readdirSync, statSync, readFileSync, writeFileSync } from 'node:fs'
import { join, relative } from 'node:path'

function parseArgs(argv) {
  const args = { out: null }
  const positional = []
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '-o') args.out = argv[++i]
    else positional.push(argv[i])
  }
  if (positional.length !== 1 || !args.out) {
    console.error('Usage: node migrate/inventory.mjs <build-dir> -o manifest.json')
    process.exit(2)
  }
  return { dir: positional[0], out: args.out }
}

function walk(dir, base = dir, files = []) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name)
    if (entry.isDirectory()) {
      walk(full, base, files)
    } else if (entry.isFile()) {
      files.push(relative(base, full).split('\\').join('/'))
    }
  }
  return files
}

const { dir, out } = parseArgs(process.argv.slice(2))

const paths = walk(dir).sort()
let totalBytes = 0
const files = paths.map((rel) => {
  const buf = statSync(join(dir, rel))
  totalBytes += buf.size
  return { path: rel, bytes: buf.size }
})

// Hash in a second pass to keep memory flat on large trees.
for (const f of files) {
  const buf = readFileSync(join(dir, f.path))
  f.sha256 = createHash('sha256').update(buf).digest('hex')
}

const manifest = {
  tool: 'migrate/inventory.mjs',
  dir,
  fileCount: files.length,
  totalBytes,
  files,
}
writeFileSync(out, JSON.stringify(manifest, null, 2) + '\n')
console.log(`inventoried ${files.length} files (${(totalBytes / 1024 / 1024).toFixed(1)} MiB) -> ${out}`)
