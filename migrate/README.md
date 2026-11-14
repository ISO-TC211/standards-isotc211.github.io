# standards.isotc211.org migration notes

Jekyll 4.3 + jekyll-vite → Astro 7 + Vite 8 + Tailwind 4 (`@isotc211/astro-ui`).
The Ruby side survives as a **prebuild data generator**: `script/generate_site_data.rb`
(ports of `SiteScanner`/`Standard`/`ModelSerializer`/`CrossReferenceIndex` under
`source/_plugins/standards/`) emits `src/data/standards-{catalog,pages}.json`
(81 catalog entries, 984 pages), and `npm run build` renders them through
`src/pages/[...page].astro`. Posts, home, about, news and 404 are hand-ported.

## Gate results (against the pre-migration `_site/` baseline)

- **parity** (`parity.mjs`): OK — every non-HTML file byte-identical (assets,
  feed, robots.txt); routes equal (990 HTML pages both sides). Allowlist covers
  only the asset-bundle rename (`vite/assets/*` → `_astro/*`) and the HTML
  files themselves, which are gated by smoke + visual instead of bytes.
- **html-smoke**: OK — 990/990 pages carry the shared chrome.
- **feed-check**: OK — 7/7 URLs.
- **visual-diff** (`--threshold 0.2`): 51/60 route×viewport×theme combos
  pixel-identical; the remainder differ only in sub-glyph antialiasing on
  text (counts are not even stable across runs of the same build: one route
  measured 93 px then 6087 px with no change in between). No structural
  difference remains anywhere.

## Legacy-rendering quirks reproduced for parity

The old Jekyll-vite pipeline was subtly broken, and the migration reproduces
its output exactly (see `src/styles/global.css` and `src/styles/legacy-theme.css`):

1. **No Tailwind utilities were ever generated** (content scanning never ran),
   so every utility class in the legacy markup is a no-op. The Astro build
   imports a utilities-free theme preset (`legacy-theme.css`) for the same
   reason.
2. **No preflight**: UA body margin (8px), content-box sizing, unstyled
   `.skip-link` (visible text at page top), theme-gem inline
   `main { padding-top: 64px !important }`.
3. **Fully unlayered cascade**: astro-ui layers its prose defaults in
   `@layer base`, which loses to `@layer components` — the legacy build had
   no layers, so e.g. `.documentation code` (0,1,1) outranked
   `.standards-url-demo__code` (14px, not 15px). Mirrored unlayered.
4. **AsciiDoc rendering quirks preserved** in the converted 2026 post:
   `--` became `&thinsp;—&thinsp;`; the malformed
   `<code><strong>-rc.yaml</code> and <code></strong>-cc.yaml</code>` markup
   (which ate the `*` characters and left the word "and" bold) is reproduced
   as `` `-rc.yaml` **and** `-cc.yaml` ``.
5. **Xref badge quirk**: the legacy generator only matched `conf_test` for
   conformance badges — kind `test` rendered no badge at all
   (`src/components/XrefList.astro`).
6. The deployed homepage predates the `hero-inner` wrapper in the current
   source; the port matches the **deployed** markup (Tailwind-utility hero
   container), not the unreleased source.
7. `compressHTML: false` in `astro.config.mjs` — the default compaction
   glues text and inline elements (`reference<code>…`), changing line
   breaking and pixel output.
8. The old feed's relative URLs, `.html` entry hrefs and extensionless ids
   are matched by a hand-written raw-Atom `src/pages/feed.xml.ts`.
9. `public/robots.txt` carries the stray trailing backslashes the legacy
   file has always served.

## Jekyll removal

Removed: `_config.yml`, `source/_layouts`, `source/_includes`,
`source/_posts`, `source/{index.html,404.html,about,news,assets,robots.txt}`,
`source/_plugins/standards_generator.rb` (Jekyll wrapper), `_frontend/`,
`config/`, root `postcss.config.js`/`vite.config.ts`, root `robots.txt`.
Kept: `source/_data/` (generator input), `source/_plugins/standards/`
(generator engine), `Gemfile` (modspec; jekyll stays only as a dependency of
the engine classes and their RSpec lock — 56 specs green), `Makefile`
trimmed to build/serve/test/clean.

## Toolkit

Same as registry/www/schemas: `inventory.mjs`, `parity.mjs`,
`html-smoke.mjs`, `feed-check.mjs`, `visual-diff.mjs`. Regenerate:

```sh
npm run build
node migrate/inventory.mjs _site -o migrate/manifest-old.json
node migrate/inventory.mjs dist -o migrate/manifest-new.json
node migrate/parity.mjs migrate/manifest-{old,new}.json --allowlist migrate/parity-allowlist.json
node migrate/html-smoke.mjs dist --config migrate/smoke.json
node migrate/feed-check.mjs _site/feed.xml dist/feed.xml --base https://standards.isotc211.org
# visual (from migrate/, needs playwright + pixelmatch + pngjs):
python3 -m http.server 5010 --directory _site &
python3 -m http.server 5011 --directory dist &
node visual-diff.mjs --base http://localhost:5010 --candidate http://localhost:5011 \
  --routes routes.txt --threshold 0.2
```
