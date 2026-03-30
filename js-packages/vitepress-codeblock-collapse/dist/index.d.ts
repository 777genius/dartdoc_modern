import { Ref } from 'vue';

interface CodeblockCollapseOptions {
    /**
     * Max height (px) before a code block is collapsed.
     * @default 380
     */
    maxHeight?: number;
    /**
     * CSS selector for code block containers.
     * @default '.vp-doc div[class*="language-"]'
     */
    selector?: string;
    /**
     * Data attribute used to track collapse state on elements.
     * @default 'collapsed'
     */
    dataAttr?: string;
}
/**
 * Scans the DOM for tall code blocks and adds collapse/expand UI.
 * Safe to call multiple times — already-processed blocks are skipped.
 */
declare function collapseCodeblocks(options?: CodeblockCollapseOptions): void;
/**
 * Removes all collapse UI and event listeners from processed blocks.
 */
declare function cleanupCodeblocks(options?: CodeblockCollapseOptions): void;

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
declare function useCodeblockCollapse(pagePath: Ref<string>, options?: CodeblockCollapseOptions): void;

export { type CodeblockCollapseOptions, cleanupCodeblocks, collapseCodeblocks, useCodeblockCollapse };
