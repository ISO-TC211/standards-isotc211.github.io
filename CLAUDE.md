# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ISO/TC 211 URI dereferencing service (https://standards.isotc211.org). Every URI used in published geographic information standards for requirements, recommendations, permissions, and conformance tests resolves to a generated page here.

## Build Commands

```sh
make all          # Full build (deps + Ruby data generator + astro build → dist/)
make serve        # Astro dev server
make test         # RSpec suite for the generator engine
make clean        # Remove dist/, .astro/, generated src/data JSON
```

Requires Ruby 3.4 and Node.js 22. Dependencies: `bundle install`, `npm install`.

## Architecture

**Astro site** (`src/`): static output via `astro build` → `dist/`. Shared UI from `@isotc211/astro-ui` (git-pinned until first npm release). `scripts/postbuild.mjs` moves news pages to the legacy `/site/update/{yyyy}/{mm}/{dd}/{slug}.html` file paths. Note `compressHTML: false` and the legacy-rendering overrides in `src/styles/global.css` + `src/styles/legacy-theme.css` — see `migrate/README.md` before touching styles.

**Data generator** (`npm run build` prebuild step): `script/generate_site_data.rb` loads:
1. `SiteScanner` — discovers directories under `source/_data/{StandardNumber}/{Part}/{Edition}/`
2. `Standard` — loads `_meta.yaml` and `*-rc.yaml`/`*-cc.yaml` via modspec-ruby models
3. `CrossReferenceIndex` — maps req↔conf identifier relationships for cross-linking
4. `ModelSerializer` — converts modspec-ruby models to renderable hashes (single point of serialization)
5. `FieldPolicy` — strips copyright-restricted fields per `_meta.yaml` `hide_fields`

and emits `src/data/standards-catalog.json` (81 entries) + `src/data/standards-pages.json` (984 pages), rendered by `src/pages/[...page].astro` (standard_index/provision_class) and `src/pages/index.astro` (catalog sections).

The engine classes live in `source/_plugins/standards/` (no longer Jekyll plugins — just plain requires; `jekyll` remains a Gemfile dependency only for those classes' API surface and their specs).

**Legacy UI quirks are load-bearing**: the pre-migration site rendered with no Tailwind utilities, no preflight, and an unlayered cascade; parity with production depends on `legacy-theme.css`, the `global.css` overrides, and `compressHTML: false`. `migrate/visual-diff.mjs` (against a `_site/` baseline) verifies changes stay identical.

## Adding a Standard

Only YAML files needed — no HTML, config, or template changes. Create `source/_data/{Number}/{Part}/{Edition}/` with `_meta.yaml`, `*-rc.yaml` (requirements classes), and `*-cc.yaml` (conformance classes). See `README.adoc` for full schema.

For standards with data in Metanorma OGC ModSpec YAML format (`groups/scopes`), use `script/convert_modspec_yaml.rb` to convert to the site format.

## Testing

```sh
bundle exec rspec spec/     # Run all specs (56 examples)
```

Specs cover SiteScanner, Standard, CrossReferenceIndex, ModelSerializer, PageFactory, FieldPolicy, and a full pipeline integration test with fixture data.

## Deployment

GitHub Pages via Actions (`.github/workflows/build_deploy.yml`): Ruby generator + `astro build` on all pushes/PRs; deploys `dist/` only from `main`. `links.yml` link-checks the built artifact served locally (never production). `discover_standards.yml` opens PRs weekly when new ISO publications are detected.
