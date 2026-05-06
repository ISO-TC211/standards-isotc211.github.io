# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ISO/TC 211 URI dereferencing service (https://standards.isotc211.org). Every URI used in published geographic information standards for requirements, recommendations, permissions, and conformance tests resolves to a generated page here.

## Build Commands

```sh
make all          # Full build (install deps + jekyll build → _site/)
make serve        # Dev server with live reload
make clean        # Clean _site/ and build_source/
```

Requires Ruby 3.1+ and Node.js 20+. Dependencies: `bundle install`, `npm install`.

## Architecture

**Build source indirection** — `source/` is the canonical directory but Jekyll reads from `build_source/`. The Makefile copies `source/*` → `build_source/` before each build (`.build_source_stamp` target). Generated files like `_data/standards_catalog.yaml` are written into `build_source/`.

**Plugin pipeline** (`source/_plugins/standards_generator.rb` triggers on `:after_reset` hook):
1. `SiteScanner` — discovers directories under `_data/{StandardNumber}/{Part}/{Edition}/`
2. `Standard` — loads `_meta.yaml` and `*-rc.yaml`/`*-cc.yaml` files via modspec-ruby models
3. `CrossReferenceIndex` — maps req↔conf identifier relationships for cross-linking
4. `ModelSerializer` — converts modspec-ruby models to renderable hashes (single point of serialization)
5. `PageFactory` — creates Jekyll pages using ModelSerializer and writes `standards_catalog.yaml`
6. `FieldPolicy` — strips copyright-restricted fields per `_meta.yaml` `hide_fields`

**Layouts**: `standard_index` (standard landing page), `provision_class` (req/conf class and individual provision pages). Both wrap the theme's `default` layout.

**Frontend**: Vite + Tailwind CSS v4 + PostCSS. Entry points in `_frontend/`. Vite config resolves the theme gem's `_frontend/` directory as `#theme` alias when available.

## Adding a Standard

Only YAML files needed — no HTML, config, or template changes. Create `source/_data/{Number}/{Part}/{Edition}/` with `_meta.yaml`, `*-rc.yaml` (requirements classes), and `*-cc.yaml` (conformance classes). See `README.adoc` for full schema.

For standards with data in Metanorma OGC ModSpec YAML format (`groups/scopes`), use `script/convert_modspec_yaml.rb` to convert to the site format.

## Testing

```sh
bundle exec rspec spec/     # Run all specs (56 examples)
```

Specs cover SiteScanner, Standard, CrossReferenceIndex, ModelSerializer, PageFactory, FieldPolicy, and a full pipeline integration test with fixture data.

## Deployment

GitHub Pages via Actions (`.github/workflows/build_deploy.yml`). Builds on all pushes/PRs; deploys only from `main`.
