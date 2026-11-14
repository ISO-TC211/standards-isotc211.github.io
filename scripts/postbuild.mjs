#!/usr/bin/env node
// Jekyll emitted posts as .html FILES at /site/update/{yyyy}/{mm}/{dd}/{slug}.html;
// those URLs are referenced by third parties and the feed, so the Astro output
// (directory format → …/index.html) is moved to the exact legacy file paths.
import { existsSync, mkdirSync, renameSync, rmSync, readdirSync } from 'node:fs'
import { join, dirname } from 'node:path'

const dist = join(process.cwd(), 'dist')
const root = join(dist, 'site', 'update')
if (!existsSync(root)) {
  console.log('postbuild: no site/update output; nothing to do')
  process.exit(0)
}

let moved = 0
function walk(dir) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name)
    if (entry.isDirectory()) {
      walk(full)
      // a directory whose only content is index.html becomes a sibling .html file
      if (existsSync(join(full, 'index.html')) && readdirSync(full).length === 1) {
        const target = `${full}.html`
        mkdirSync(dirname(target), { recursive: true })
        renameSync(join(full, 'index.html'), target)
        rmSync(full, { recursive: true })
        moved++
        console.log(`postbuild: ${target.replace(dist, '')}`)
      }
    }
  }
}
walk(root)
console.log(`postbuild: moved ${moved} post page(s) to legacy .html paths`)
