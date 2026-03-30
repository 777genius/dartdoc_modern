export interface CodeblockCollapseOptions {
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

const DEFAULT_OPTIONS: Required<CodeblockCollapseOptions> = {
  maxHeight: 380,
  selector: '.vp-doc div[class*="language-"]',
  dataAttr: 'collapsed',
};

let nextBlockId = 0;

const blockControllers = new WeakMap<HTMLElement, AbortController>();

function createChevronSvg(): SVGSVGElement {
  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  svg.setAttribute('width', '16');
  svg.setAttribute('height', '16');
  svg.setAttribute('viewBox', '0 0 24 24');
  svg.setAttribute('fill', 'none');
  svg.setAttribute('stroke', 'currentColor');
  svg.setAttribute('stroke-width', '2');
  svg.setAttribute('stroke-linecap', 'round');
  svg.setAttribute('stroke-linejoin', 'round');
  svg.setAttribute('aria-hidden', 'true');

  const polyline = document.createElementNS('http://www.w3.org/2000/svg', 'polyline');
  polyline.setAttribute('points', '6 9 12 15 18 9');
  svg.appendChild(polyline);

  return svg;
}

function toggleBlock(
  block: HTMLElement,
  pre: HTMLElement,
  overlay: HTMLElement,
  btn: HTMLElement,
  maxHeight: number,
  dataAttr: string,
): void {
  const isCollapsed = block.dataset[dataAttr] === 'true';

  if (isCollapsed) {
    pre.style.maxHeight = 'none';
    pre.style.overflow = 'auto';
    block.dataset[dataAttr] = 'false';
    overlay.classList.add('expanded');
    btn.classList.add('expanded');
    btn.setAttribute('aria-expanded', 'true');
    btn.setAttribute('aria-label', 'Collapse code block');
  } else {
    const viewportOffset = btn.getBoundingClientRect().top;
    pre.style.maxHeight = `${maxHeight}px`;
    pre.style.overflow = 'hidden';
    pre.scrollTo(0, 0);
    block.dataset[dataAttr] = 'true';
    overlay.classList.remove('expanded');
    btn.classList.remove('expanded');
    btn.setAttribute('aria-expanded', 'false');
    btn.setAttribute('aria-label', 'Expand code block');

    const newViewportOffset = btn.getBoundingClientRect().top;
    window.scrollTo(0, window.scrollY + (newViewportOffset - viewportOffset));
  }
}

/**
 * Scans the DOM for tall code blocks and adds collapse/expand UI.
 * Safe to call multiple times — already-processed blocks are skipped.
 */
export function collapseCodeblocks(options: CodeblockCollapseOptions = {}): void {
  if (typeof document === 'undefined') return;

  const { maxHeight, selector, dataAttr } = { ...DEFAULT_OPTIONS, ...options };

  const blocks = document.querySelectorAll<HTMLElement>(selector);

  for (const block of blocks) {
    if (block.dataset[dataAttr] !== undefined) continue;

    const pre = block.querySelector('pre');
    if (!pre || pre.scrollHeight <= maxHeight) continue;

    const blockId = `codeblock-${nextBlockId++}`;
    pre.id = blockId;

    const controller = new AbortController();
    const { signal } = controller;
    blockControllers.set(block, controller);

    block.dataset[dataAttr] = 'true';
    pre.style.maxHeight = `${maxHeight}px`;
    pre.style.overflow = 'hidden';

    const overlay = document.createElement('div');
    overlay.className = 'codeblock-collapse-overlay';

    const btn = document.createElement('button');
    btn.className = 'codeblock-collapse-btn';
    btn.setAttribute('type', 'button');
    btn.setAttribute('aria-label', 'Expand code block');
    btn.setAttribute('aria-expanded', 'false');
    btn.setAttribute('aria-controls', blockId);
    btn.appendChild(createChevronSvg());

    btn.addEventListener('click', () => {
      toggleBlock(block, pre, overlay, btn, maxHeight, dataAttr);
    }, { signal });

    overlay.addEventListener('click', (e) => {
      if (e.target !== btn && !btn.contains(e.target as Node)) {
        btn.click();
      }
    }, { signal });

    overlay.appendChild(btn);
    block.style.position = 'relative';
    block.appendChild(overlay);
  }
}

/**
 * Removes all collapse UI and event listeners from processed blocks.
 */
export function cleanupCodeblocks(options: CodeblockCollapseOptions = {}): void {
  if (typeof document === 'undefined') return;

  const { selector, dataAttr } = { ...DEFAULT_OPTIONS, ...options };

  const blocks = document.querySelectorAll<HTMLElement>(selector);

  for (const block of blocks) {
    if (block.dataset[dataAttr] === undefined) continue;

    const controller = blockControllers.get(block);
    if (controller) {
      controller.abort();
      blockControllers.delete(block);
    }

    const overlay = block.querySelector('.codeblock-collapse-overlay');
    overlay?.remove();

    const pre = block.querySelector('pre');
    if (pre) {
      pre.style.maxHeight = '';
      pre.style.overflow = '';
      pre.removeAttribute('id');
    }

    delete block.dataset[dataAttr];
    block.style.position = '';
  }
}
