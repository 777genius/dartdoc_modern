import { nextTick, onMounted, onUnmounted, type Ref, watch } from 'vue';
import {
  addKeyboardListener,
  cleanupMermaidZoom,
  setupMermaidZoom,
  type MermaidZoomOptions,
} from './zoom';

/**
 * Vue composable for VitePress — adds click-to-zoom on Mermaid diagrams
 * on mount and re-processes on page navigation.
 *
 * @param pagePath - A reactive ref that changes when the page navigates
 *   (e.g. `computed(() => page.value.relativePath)` from VitePress `useData`)
 * @param options - Zoom configuration
 *
 * @example
 * ```ts
 * // .vitepress/theme/index.ts
 * import { computed } from 'vue';
 * import { useData } from 'vitepress';
 * import { useMermaidZoom } from 'vitepress-mermaid-zoom';
 * import 'vitepress-mermaid-zoom/style.css';
 *
 * const { page } = useData();
 * const pagePath = computed(() => page.value.relativePath);
 * useMermaidZoom(pagePath);
 * ```
 */
export function useMermaidZoom(
  pagePath: Ref<string>,
  options?: MermaidZoomOptions,
): void {
  let removeKeyboardListener: (() => void) | undefined;

  const run = () => nextTick(() => setupMermaidZoom(options));

  onMounted(() => {
    removeKeyboardListener = addKeyboardListener();
    run();
  });

  const stopWatch = watch(pagePath, () => {
    cleanupMermaidZoom(options);
    run();
  });

  onUnmounted(() => {
    stopWatch();
    removeKeyboardListener?.();
    cleanupMermaidZoom(options);
  });
}
