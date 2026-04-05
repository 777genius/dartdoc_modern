<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useData, useRoute } from 'vitepress'

const props = defineProps<{
  mobile?: boolean
}>()

const PROJECT_JASPR_DOCS_URL = 'https://777genius.github.io/dartdoc_modern/jaspr/'
const PROJECT_VITEPRESS_DOCS_URL = 'https://777genius.github.io/dartdoc_modern/vitepress/'

const { site } = useData()
const route = useRoute()

const jasprHref = ref(PROJECT_JASPR_DOCS_URL)
const vitepressHref = ref(PROJECT_VITEPRESS_DOCS_URL)
const SHARED_API_LIBRARY_DIRS = new Set(['dartdoc', 'options'])

const isProjectDocs = computed(() => {
  const title = site.value.title?.trim() ?? ''
  return title === 'dartdoc_modern' || title === 'dartdoc_modern API'
})

function trimTrailingSlash(value: string): string {
  if (!value || value === '/') return ''

  let path = value
  while (path.length > 1 && path.endsWith('/')) {
    path = path.slice(0, -1)
  }
  return path
}

function normalizeRoutePath(value: string): string {
  if (!value || value === '/') return '/'

  let path = value
  if (!path.startsWith('/')) {
    path = `/${path}`
  }
  while (path.length > 1 && path.endsWith('/')) {
    path = path.slice(0, -1)
  }
  return path
}

function joinBasePath(basePath: string, routePath: string): string {
  const normalizedBase = trimTrailingSlash(basePath)
  if (routePath === '/') {
    return normalizedBase ? `${normalizedBase}/` : '/'
  }
  return normalizedBase ? `${normalizedBase}${routePath}` : routePath
}

function resolveRelativeRoute(pathname: string): string {
  const normalizedPath = normalizeRoutePath(pathname)
  const vitepressBasePath = trimTrailingSlash(new URL(PROJECT_VITEPRESS_DOCS_URL).pathname)
  const jasprBasePath = trimTrailingSlash(new URL(PROJECT_JASPR_DOCS_URL).pathname)

  if (!vitepressBasePath && !jasprBasePath) {
    return normalizedPath
  }

  if (normalizedPath === vitepressBasePath || normalizedPath === jasprBasePath) {
    return '/'
  }
  if (vitepressBasePath && normalizedPath.startsWith(`${vitepressBasePath}/`)) {
    return normalizeRoutePath(normalizedPath.slice(vitepressBasePath.length))
  }
  if (jasprBasePath && normalizedPath.startsWith(`${jasprBasePath}/`)) {
    return normalizeRoutePath(normalizedPath.slice(jasprBasePath.length))
  }

  return normalizedPath
}

function sharedApiFallback(target: 'jaspr' | 'vitepress'): string {
  return target === 'jaspr' ? '/api' : '/api/'
}

function sharedApiLibraryDir(pathname: string): string | null {
  const segments = normalizeRoutePath(pathname).split('/').filter(Boolean)
  if (segments.length < 2 || segments[0] !== 'api') {
    return null
  }

  const libraryDir = segments[1]
  return SHARED_API_LIBRARY_DIRS.has(libraryDir) ? libraryDir : null
}

function guideRouteForTarget(pathname: string, target: 'jaspr' | 'vitepress'): string {
  const normalizedPath = normalizeRoutePath(pathname)
  if (normalizedPath === '/guide' || normalizedPath === '/guide/') {
    return target === 'jaspr' ? '/guide' : '/guide/'
  }
  if (!normalizedPath.startsWith('/guide/')) {
    return normalizedPath
  }
  if (target === 'jaspr' && !normalizedPath.endsWith('.html')) {
    return `${normalizedPath}.html`
  }
  return normalizedPath
}

function routeForTarget(pathname: string, target: 'jaspr' | 'vitepress'): string {
  const currentPath = resolveRelativeRoute(pathname)
  const sharedLibraryDir = sharedApiLibraryDir(currentPath)

  if (currentPath === '/guide' || currentPath === '/guide/' || currentPath.startsWith('/guide/')) {
    return guideRouteForTarget(currentPath, target)
  }

  if (target === 'vitepress') {
    if (currentPath === '/api') {
      return '/api/'
    }

    const libraryMatch = currentPath.match(/^\/api\/([^/]+)\/library$/)
    if (libraryMatch) {
      const libraryDir = libraryMatch[1]
      return SHARED_API_LIBRARY_DIRS.has(libraryDir)
        ? `/api/${libraryDir}/`
        : sharedApiFallback(target)
    }

    if (currentPath.startsWith('/api/') && sharedLibraryDir == null) {
      return sharedApiFallback(target)
    }

    return currentPath
  }

  if (currentPath === '/api' || currentPath === '/api/') {
    return '/api'
  }

  const segments = normalizeRoutePath(currentPath).split('/').filter(Boolean)
  if (segments.length === 2 && segments[0] === 'api') {
    return sharedLibraryDir == null
      ? sharedApiFallback(target)
      : `/api/${sharedLibraryDir}/library`
  }

  if (currentPath.startsWith('/api/') && sharedLibraryDir == null) {
    return sharedApiFallback(target)
  }

  return normalizeRoutePath(currentPath)
}

function buildTargetUrl(target: 'jaspr' | 'vitepress'): string {
  const baseUrl = new URL(
    target === 'jaspr' ? PROJECT_JASPR_DOCS_URL : PROJECT_VITEPRESS_DOCS_URL,
  )
  const currentPathname =
    typeof window === 'undefined' ? route.path : window.location.pathname
  const currentSearch = typeof window === 'undefined' ? '' : window.location.search
  const currentHash = typeof window === 'undefined' ? '' : window.location.hash
  const targetRoute = routeForTarget(currentPathname, target)

  baseUrl.pathname = joinBasePath(baseUrl.pathname, targetRoute)
  baseUrl.search = currentSearch
  baseUrl.hash = currentHash
  return baseUrl.toString()
}

function refreshLinks() {
  jasprHref.value = buildTargetUrl('jaspr')
  vitepressHref.value = buildTargetUrl('vitepress')
}

watch(() => route.path, refreshLinks, { immediate: true })
</script>

<template>
  <div
    v-if="isProjectDocs"
    class="docs-version-switch"
    :class="{ 'is-mobile': props.mobile }"
    aria-label="Documentation version switch"
  >
    <a class="docs-version-switch__option" :href="jasprHref">Jaspr</a>
    <a class="docs-version-switch__option is-active" :href="vitepressHref">VitePress</a>
  </div>
</template>
