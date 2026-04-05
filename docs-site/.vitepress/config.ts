import { defineConfig } from 'vitepress'
import { withMermaid } from 'vitepress-plugin-mermaid'
import { apiSidebar } from './generated/api-sidebar'
import { guideSidebar } from './generated/guide-sidebar'
import { dartpadPlugin } from './theme/plugins/dartpad'
import llmstxt from 'vitepress-plugin-llms'

function normalizeDocsBasePath(raw = process.env.DOCS_BASE_PATH ?? '/'): string {
  const trimmed = raw.trim()
  if (!trimmed || trimmed === '/') return '/'

  let normalized = trimmed
  if (!normalized.startsWith('/')) {
    normalized = `/${normalized}`
  }
  if (!normalized.endsWith('/')) {
    normalized = `${normalized}/`
  }
  return normalized
}

function withDocsBasePath(path: string): string {
  const normalizedPath = path.replace(/^\/+/, '')
  return `${docsBasePath}${normalizedPath}`
}

const docsBasePath = normalizeDocsBasePath()

export default withMermaid(defineConfig({
  title: 'dartdoc_modern',
  description: 'Modern API documentation generator for Dart — VitePress fork of dartdoc',
  base: docsBasePath,
  head: [
    ['link', { rel: 'icon', type: 'image/svg+xml', href: withDocsBasePath('/logo.svg') }],
  ],
  ignoreDeadLinks: true,
  vite: {
    plugins: [llmstxt()],
    optimizeDeps: {
      include: ['mermaid'],
    },
    ssr: {
      noExternal: ['mermaid'],
    },
  },
  markdown: {
    config: (md) => {
      md.use(dartpadPlugin)
    },
  },
  themeConfig: {
    logo: { src: '/logo.svg', width: 36, height: 36 },
    search: {
      provider: 'local',
    },
    nav: [
      { text: 'Guide', link: '/guide/' },
      { text: 'API Reference', link: '/api/' },
    ],
    sidebar: {
      ...apiSidebar,
      ...guideSidebar,
    },
    socialLinks: [{ icon: 'github', link: 'https://github.com/777genius/dartdoc_modern' }],
  },
}))
