import { describe, expect, it, beforeEach, vi } from 'vitest';
import { collapseCodeblocks, cleanupCodeblocks } from '../src/collapse';

function createCodeBlock(scrollHeight: number): HTMLElement {
  const block = document.createElement('div');
  block.className = 'language-ts';

  const pre = document.createElement('pre');
  Object.defineProperty(pre, 'scrollHeight', { value: scrollHeight, configurable: true });
  pre.scrollTo = vi.fn();

  block.appendChild(pre);
  return block;
}

function mountBlock(block: HTMLElement): void {
  const container = document.createElement('div');
  container.className = 'vp-doc';
  container.appendChild(block);
  document.body.appendChild(container);
}

function clearBody(): void {
  while (document.body.firstChild) {
    document.body.removeChild(document.body.firstChild);
  }
}

beforeEach(() => {
  clearBody();
  window.scrollTo = vi.fn() as any;
});

describe('collapseCodeblocks', () => {
  it('collapses blocks taller than maxHeight', () => {
    const block = createCodeBlock(500);
    mountBlock(block);

    collapseCodeblocks();

    expect(block.dataset.collapsed).toBe('true');
    const pre = block.querySelector('pre') as HTMLElement;
    expect(pre.style.maxHeight).toBe('380px');
    expect(pre.style.overflow).toBe('hidden');
  });

  it('skips blocks shorter than maxHeight', () => {
    const block = createCodeBlock(200);
    mountBlock(block);

    collapseCodeblocks();

    expect(block.dataset.collapsed).toBeUndefined();
    expect(block.querySelector('.codeblock-collapse-overlay')).toBeNull();
  });

  it('skips blocks at exact maxHeight boundary', () => {
    const block = createCodeBlock(380);
    mountBlock(block);

    collapseCodeblocks();

    expect(block.dataset.collapsed).toBeUndefined();
    expect(block.querySelector('.codeblock-collapse-overlay')).toBeNull();
  });

  it('respects custom maxHeight', () => {
    const block = createCodeBlock(300);
    mountBlock(block);

    collapseCodeblocks({ maxHeight: 250 });

    expect(block.dataset.collapsed).toBe('true');
    const pre = block.querySelector('pre') as HTMLElement;
    expect(pre.style.maxHeight).toBe('250px');
  });

  it('does not re-process already collapsed blocks', () => {
    const block = createCodeBlock(500);
    mountBlock(block);

    collapseCodeblocks();
    collapseCodeblocks();

    const overlays = block.querySelectorAll('.codeblock-collapse-overlay');
    expect(overlays.length).toBe(1);
  });

  it('adds overlay with button', () => {
    const block = createCodeBlock(500);
    mountBlock(block);

    collapseCodeblocks();

    const overlay = block.querySelector('.codeblock-collapse-overlay');
    expect(overlay).not.toBeNull();

    const btn = block.querySelector('.codeblock-collapse-btn');
    expect(btn).not.toBeNull();
    expect(btn?.getAttribute('type')).toBe('button');
    expect(btn?.getAttribute('aria-label')).toBe('Expand code block');
    expect(btn?.getAttribute('aria-expanded')).toBe('false');
  });

  it('button has aria-controls linked to pre id', () => {
    const block = createCodeBlock(500);
    mountBlock(block);

    collapseCodeblocks();

    const btn = block.querySelector('.codeblock-collapse-btn') as HTMLElement;
    const pre = block.querySelector('pre') as HTMLElement;
    const controlsId = btn.getAttribute('aria-controls');

    expect(controlsId).toBeTruthy();
    expect(pre.id).toBe(controlsId);
  });

  it('button has chevron SVG', () => {
    const block = createCodeBlock(500);
    mountBlock(block);

    collapseCodeblocks();

    const svg = block.querySelector('.codeblock-collapse-btn svg');
    expect(svg).not.toBeNull();
    expect(svg?.querySelector('polyline')).not.toBeNull();
  });

  it('clicking button expands the block', () => {
    const block = createCodeBlock(500);
    mountBlock(block);

    collapseCodeblocks();

    const btn = block.querySelector('.codeblock-collapse-btn') as HTMLElement;
    const overlay = block.querySelector('.codeblock-collapse-overlay') as HTMLElement;
    const pre = block.querySelector('pre') as HTMLElement;

    btn.click();

    expect(block.dataset.collapsed).toBe('false');
    expect(pre.style.maxHeight).toBe('none');
    expect(pre.style.overflow).toBe('auto');
    expect(overlay.classList.contains('expanded')).toBe(true);
    expect(btn.classList.contains('expanded')).toBe(true);
    expect(btn.getAttribute('aria-expanded')).toBe('true');
    expect(btn.getAttribute('aria-label')).toBe('Collapse code block');
  });

  it('clicking button again collapses the block', () => {
    const block = createCodeBlock(500);
    mountBlock(block);

    collapseCodeblocks();

    const btn = block.querySelector('.codeblock-collapse-btn') as HTMLElement;

    btn.click();
    btn.click();

    const pre = block.querySelector('pre') as HTMLElement;
    expect(block.dataset.collapsed).toBe('true');
    expect(pre.style.maxHeight).toBe('380px');
    expect(pre.style.overflow).toBe('hidden');
    expect(btn.getAttribute('aria-expanded')).toBe('false');
    expect(btn.getAttribute('aria-label')).toBe('Expand code block');
  });

  it('clicking overlay (not button) also toggles', () => {
    const block = createCodeBlock(500);
    mountBlock(block);

    collapseCodeblocks();

    const overlay = block.querySelector('.codeblock-collapse-overlay') as HTMLElement;
    overlay.click();

    expect(block.dataset.collapsed).toBe('false');
  });

  it('sets position: relative on block', () => {
    const block = createCodeBlock(500);
    mountBlock(block);

    collapseCodeblocks();

    expect(block.style.position).toBe('relative');
  });

  it('supports custom selector', () => {
    const block = document.createElement('div');
    block.className = 'my-code-block';
    const pre = document.createElement('pre');
    Object.defineProperty(pre, 'scrollHeight', { value: 500 });
    pre.scrollTo = vi.fn();
    block.appendChild(pre);
    document.body.appendChild(block);

    collapseCodeblocks({ selector: '.my-code-block' });

    expect(block.dataset.collapsed).toBe('true');
  });

  it('supports custom dataAttr', () => {
    const block = createCodeBlock(500);
    mountBlock(block);

    collapseCodeblocks({ dataAttr: 'folded' });

    expect(block.dataset.folded).toBe('true');
    expect(block.dataset.collapsed).toBeUndefined();
  });

  it('handles blocks without pre element', () => {
    const container = document.createElement('div');
    container.className = 'vp-doc';
    const block = document.createElement('div');
    block.className = 'language-ts';
    container.appendChild(block);
    document.body.appendChild(container);

    expect(() => collapseCodeblocks()).not.toThrow();
    expect(block.querySelector('.codeblock-collapse-overlay')).toBeNull();
  });

  it('processes multiple blocks independently', () => {
    const short = createCodeBlock(200);
    const tall = createCodeBlock(600);
    const container = document.createElement('div');
    container.className = 'vp-doc';
    container.appendChild(short);
    container.appendChild(tall);
    document.body.appendChild(container);

    collapseCodeblocks();

    expect(short.dataset.collapsed).toBeUndefined();
    expect(tall.dataset.collapsed).toBe('true');
  });
});

describe('cleanupCodeblocks', () => {
  it('removes overlay and restores styles', () => {
    const block = createCodeBlock(500);
    mountBlock(block);

    collapseCodeblocks();
    expect(block.querySelector('.codeblock-collapse-overlay')).not.toBeNull();

    cleanupCodeblocks();

    expect(block.querySelector('.codeblock-collapse-overlay')).toBeNull();
    expect(block.dataset.collapsed).toBeUndefined();

    const pre = block.querySelector('pre') as HTMLElement;
    expect(pre.style.maxHeight).toBe('');
    expect(pre.style.overflow).toBe('');
    expect(block.style.position).toBe('');
  });

  it('allows re-processing after cleanup', () => {
    const block = createCodeBlock(500);
    mountBlock(block);

    collapseCodeblocks();
    cleanupCodeblocks();
    collapseCodeblocks();

    expect(block.dataset.collapsed).toBe('true');
    expect(block.querySelectorAll('.codeblock-collapse-overlay').length).toBe(1);
  });

  it('does nothing on unprocessed blocks', () => {
    const block = createCodeBlock(200);
    mountBlock(block);

    collapseCodeblocks();
    expect(() => cleanupCodeblocks()).not.toThrow();
  });
});
