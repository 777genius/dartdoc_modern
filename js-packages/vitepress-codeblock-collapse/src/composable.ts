import { nextTick, onMounted, onUnmounted, type Ref, watch } from 'vue';
import { cleanupCodeblocks, collapseCodeblocks, type CodeblockCollapseOptions } from './collapse';

/**
 * Vue composable for VitePress — auto-collapses tall code blocks on mount
 * and re-processes on page navigation.
 *
 * @param pagePath - A reactive ref that changes when the page navigates
 *   (e.g. `computed(() => page.value.relativePath)` from VitePress `useData`)
 * @param options - Collapse configuration
 *
 * @example
 * ```ts
 * // .vitepress/theme/Layout.vue
 * import { computed } from 'vue';
 * import { useData } from 'vitepress';
 * import { useCodeblockCollapse } from 'vitepress-codeblock-collapse';
 * import 'vitepress-codeblock-collapse/style.css';
 *
 * const { page } = useData();
 * const pagePath = computed(() => page.value.relativePath);
 * useCodeblockCollapse(pagePath);
 * ```
 */
export function useCodeblockCollapse(
  pagePath: Ref<string>,
  options?: CodeblockCollapseOptions,
): void {
  const run = () => nextTick(() => collapseCodeblocks(options));

  onMounted(run);

  const stopWatch = watch(pagePath, run);

  onUnmounted(() => {
    stopWatch();
    cleanupCodeblocks(options);
  });
}
