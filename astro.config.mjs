import { defineConfig } from 'astro/config'
import tailwindcss from '@tailwindcss/vite'
import vue from '@astrojs/vue'

export default defineConfig({
  site: 'https://standards.isotc211.org',
  trailingSlash: 'always',
  build: { format: 'directory' },
  // Legacy parity: Jekyll/kramdown emitted source whitespace verbatim. The
  // default compressHTML glues text and inline elements together (e.g.
  // "reference<code>…"), changing line-breaking and pixel output.
  compressHTML: false,
  vite: { plugins: [tailwindcss()] },
  integrations: [vue()],
})
