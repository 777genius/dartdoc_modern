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

const isProjectDocs = computed(() => site.value.title === 'dartdoc_modern API')

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

function routeForTarget(pathname: string, target: 'jaspr' | 'vitepress'): string {
  const currentPath = resolveRelativeRoute(pathname)

  if (target === 'vitepress') {
    if (currentPath === '/api') {
      return '/api/'
    }

    const libraryMatch = currentPath.match(/^\/api\/([^/]+)\/library$/)
    if (libraryMatch) {
      return `/api/${libraryMatch[1]}/`
    }

    return currentPath
  }

  if (currentPath === '/api' || currentPath === '/api/') {
    return '/api'
  }

  const segments = normalizeRoutePath(currentPath).split('/').filter(Boolean)
  if (segments.length === 2 && segments[0] === 'api') {
    return `/api/${segments[1]}/library`
  }

  return normalizeRoutePath(currentPath)
}

function buildTargetUrl(target: 'jaspr' | 'vitepress'): string {
  if (typeof window === 'undefined') {
    return target === 'jaspr' ? PROJECT_JASPR_DOCS_URL : PROJECT_VITEPRESS_DOCS_URL
  }

  const currentUrl = new URL(window.location.href)
  const baseUrl = new URL(
    target === 'jaspr' ? PROJECT_JASPR_DOCS_URL : PROJECT_VITEPRESS_DOCS_URL,
  )
  const targetRoute = routeForTarget(currentUrl.pathname, target)

  baseUrl.pathname = joinBasePath(baseUrl.pathname, targetRoute)
  baseUrl.search = currentUrl.search
  baseUrl.hash = currentUrl.hash
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
