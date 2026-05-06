import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'
import { resolve } from 'path'
import { existsSync } from 'fs'
import { execSync } from 'child_process'

function resolveThemeFrontend() {
  const local = resolve(__dirname, '../jekyll-theme-isotc211/_frontend')
  if (existsSync(local)) return local

  try {
    const gemRoot = execSync('bundle show jekyll-theme-isotc211', { encoding: 'utf-8' }).trim()
    const gemFrontend = resolve(gemRoot, '_frontend')
    if (existsSync(gemFrontend)) return gemFrontend
  } catch {}

  return null
}

const themeFrontend = resolveThemeFrontend()

export default defineConfig(({ mode }) => ({
  plugins: [RubyPlugin()],
  resolve: {
    alias: themeFrontend ? { '#theme': themeFrontend } : {}
  },
  css: {
    devSourcemap: true,
  },
  build: {
    sourcemap: mode === 'development',
    minify: 'terser',
    terserOptions: {
      compress: {
        drop_console: mode === 'production',
      },
    },
  },
}))
