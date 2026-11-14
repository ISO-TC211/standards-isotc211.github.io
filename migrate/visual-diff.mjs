#!/usr/bin/env node
// Pixel-compare pages served from two builds (e.g. Jekyll `_site` vs Astro
// `dist`) to prove the migrated site looks identical.
//
// Requires dev dependencies in the repo running this script:
//   npm i -D playwright pixelmatch pngjs && npx playwright install chromium
//
// Usage:
//   node migrate/visual-diff.mjs \
//     --base http://localhost:5000 \
//     --candidate http://localhost:5001 \
//     --routes migrate/routes.txt \
//     [--viewports 1280x800,390x844] \
//     [--themes light,dark] \
//     [--threshold 0] \
//     [--out migrate/screenshots]
//
// routes.txt: one absolute path per line (e.g. "/docs/xml-catalogs/").
// Blank lines and lines starting with # are ignored.
//
// With --threshold 0 (default) any pixel difference fails. Raise it (0.0-1.0,
// per-pixel color distance) only to absorb antialiasing noise — layout or
// color differences still produce visible diff images.
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)
const { chromium } = require('playwright')
const { PNG } = require('pngjs')
const pixelmatch = require('pixelmatch')

function parseArgs(argv) {
  const args = {
    viewports: '1280x800,390x844',
    themes: 'light,dark',
    threshold: 0,
    out: 'migrate/screenshots',
  }
  const required = ['base', 'candidate', 'routes']
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]
    if (a === '--base') args.base = argv[++i]
    else if (a === '--candidate') args.candidate = argv[++i]
    else if (a === '--routes') args.routes = argv[++i]
    else if (a === '--viewports') args.viewports = argv[++i]
    else if (a === '--themes') args.themes = argv[++i]
    else if (a === '--threshold') args.threshold = Number(argv[++i])
    else if (a === '--out') args.out = argv[++i]
  }
  const missing = required.filter((k) => !args[k])
  if (missing.length) {
    console.error(`Missing required options: ${missing.map((m) => `--${m}`).join(', ')}`)
    console.error('Usage: node migrate/visual-diff.mjs --base URL --candidate URL --routes routes.txt [--viewports ...] [--themes ...] [--threshold N] [--out dir]')
    process.exit(2)
  }
  return args
}

const BLOCKED_HOSTS = ['google-analytics.com', 'googletagmanager.com', 'kit.fontawesome.com']

const args = parseArgs(process.argv.slice(2))

const routes = readFileSync(args.routes, 'utf8')
  .split('\n')
  .map((l) => l.trim())
  .filter((l) => l && !l.startsWith('#'))

const viewports = args.viewports.split(',').map((v) => {
  const [w, h] = v.split('x').map(Number)
  return { width: w, height: h, label: v }
})
const themes = args.themes.split(',')

mkdirSync(args.out, { recursive: true })

const browser = await chromium.launch()

async function capture(url, viewport, theme, shotPath) {
  const context = await browser.newContext({ viewport })
  if (theme === 'dark') {
    await context.addInitScript(() => {
      window.localStorage.setItem('iso-tc211-theme', 'dark')
    })
  }
  await context.route('**/*', (route) => {
    const reqUrl = route.request().url()
    if (BLOCKED_HOSTS.some((h) => reqUrl.includes(h))) return route.abort()
    route.continue()
  })
  const page = await context.newPage()
  await context.addInitScript(() => {
    const css = document.createElement('style')
    css.textContent = '*, *::before, *::after { animation: none !important; transition: none !important; }'
    document.documentElement.appendChild(css)
  })
  await page.goto(url, { waitUntil: 'networkidle', timeout: 60000 })
  await page.waitForTimeout(1800) // font + island hydration settle
  await page.screenshot({ path: shotPath, fullPage: true })
  await context.close()
}

function compare(aPath, bPath, diffPath) {
  const a = PNG.sync.read(readFileSync(aPath))
  const b = PNG.sync.read(readFileSync(bPath))
  if (a.width !== b.width || a.height !== b.height) {
    return { sizeMismatch: true, sizeA: `${a.width}x${a.height}`, sizeB: `${b.width}x${b.height}` }
  }
  const diff = new PNG({ width: a.width, height: a.height })
  const diffPixels = pixelmatch(a.data, b.data, diff.data, a.width, a.height, {
    threshold: args.threshold,
  })
  writeFileSync(diffPath, PNG.sync.write(diff))
  return { sizeMismatch: false, diffPixels, totalPixels: a.width * a.height }
}

const results = []
for (const route of routes) {
  for (const viewport of viewports) {
    for (const theme of themes) {
      const slug = `${route.replace(/^\/|\/$/g, '').split('/').join('-') || 'index'}-${viewport.label}-${theme}`
      const baseShot = join(args.out, `base-${slug}.png`)
      const candShot = join(args.out, `cand-${slug}.png`)
      const url = `${args.base}${route}`
      const candUrl = `${args.candidate}${route}`
      process.stdout.write(`capturing ${route} [${viewport.label} ${theme}] … `)
      try {
        await capture(url, viewport, theme, baseShot)
        await capture(candUrl, viewport, theme, candShot)
        const diffPath = join(args.out, `diff-${slug}.png`)
        const result = compare(baseShot, candShot, diffPath)
        if (result.sizeMismatch) {
          results.push({ route, viewport: viewport.label, theme, ok: false, reason: `size mismatch base=${result.sizeA} candidate=${result.sizeB}` })
          console.log('SIZE MISMATCH')
        } else {
          const diffRatio = result.diffPixels / result.totalPixels
          const ok = result.diffPixels === 0
          results.push({ route, viewport: viewport.label, theme, ok, diffPixels: result.diffPixels, diffRatio })
          console.log(ok ? 'identical' : `${result.diffPixels} px differ (${(diffRatio * 100).toFixed(3)}%) -> ${diffPath}`)
        }
      } catch (err) {
        results.push({ route, viewport: viewport.label, theme, ok: false, reason: String(err) })
        console.log(`ERROR: ${err}`)
      }
    }
  }
}

await browser.close()

const failures = results.filter((r) => !r.ok)
const report = { base: args.base, candidate: args.candidate, threshold: args.threshold, results }
writeFileSync(join(args.out, 'report.json'), JSON.stringify(report, null, 2) + '\n')
console.log(`\nvisual-diff: ${results.length - failures.length}/${results.length} identical`)
for (const f of failures) console.log(`  ! ${f.route} [${f.viewport} ${f.theme}] ${f.reason || `${f.diffPixels} px differ`}`)
console.log(failures.length === 0 ? 'visual-diff OK' : 'visual-diff FAILED')
process.exit(failures.length === 0 ? 0 : 1)
