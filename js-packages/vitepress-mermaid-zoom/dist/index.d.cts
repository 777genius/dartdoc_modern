import { Ref } from 'vue';

interface MermaidZoomOptions {
    /**
     * CSS selector for Mermaid diagram containers.
     * @default '.mermaid'
     */
    selector?: string;
    /**
     * Data attribute used to track whether a diagram has been processed.
     * @default 'zoomable'
     */
    dataAttr?: string;
}
/**
 * Closes the currently zoomed diagram, restoring it to its original position.
 */
declare function closeDiagram(): void;
/**
 * Scans the DOM for Mermaid diagrams and adds click-to-zoom behavior.
 * Safe to call multiple times — already-processed diagrams are skipped.
 */
declare function setupMermaidZoom(options?: MermaidZoomOptions): void;
/**
 * Removes all zoom UI and event listeners from processed diagrams.
 * Closes any currently zoomed diagram.
 */
declare function cleanupMermaidZoom(options?: MermaidZoomOptions): void;
/**
 * Adds global keyboard listener (Escape to close).
 * Returns a cleanup function to remove the listener.
 */
declare function addKeyboardListener(): () => void;

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
declare function useMermaidZoom(pagePath: Ref<string>, options?: MermaidZoomOptions): void;

export { type MermaidZoomOptions, addKeyboardListener, cleanupMermaidZoom, closeDiagram, setupMermaidZoom, useMermaidZoom };
