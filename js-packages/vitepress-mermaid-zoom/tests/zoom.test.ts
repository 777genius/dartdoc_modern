import { describe, expect, it, beforeEach, vi } from 'vitest';
import {
  setupMermaidZoom,
  cleanupMermaidZoom,
  closeDiagram,
  addKeyboardListener,
} from '../src/zoom';

function createDiagram(svgWidth = 800, svgHeight = 400): HTMLElement {
  const diagram = document.createElement('div');
  diagram.className = 'mermaid';

  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  svg.setAttribute('width', String(svgWidth));
  svg.setAttribute('height', String(svgHeight));
  diagram.appendChild(svg);

  return diagram;
}

function clearBody(): void {
  while (document.body.firstChild) {
    document.body.removeChild(document.body.firstChild);
  }
}

// jsdom doesn't implement window.scrollTo
window.scrollTo = vi.fn() as unknown as typeof window.scrollTo;

beforeEach(() => {
  cleanupMermaidZoom();
  clearBody();
  document.body.style.overflow = '';
  document.body.style.position = '';
  document.body.style.top = '';
  document.body.style.left = '';
  document.body.style.right = '';
});

describe('setupMermaidZoom', () => {
  it('marks diagrams as zoomable', () => {
    const diagram = createDiagram();
    document.body.appendChild(diagram);

    setupMermaidZoom();

    expect(diagram.dataset.zoomable).toBe('true');
    expect(diagram.style.cursor).toBe('zoom-in');
  });

  it('adds zoom hint icon', () => {
    const diagram = createDiagram();
    document.body.appendChild(diagram);

    setupMermaidZoom();

    const hint = diagram.querySelector('.mermaid-zoom-hint');
    expect(hint).not.toBeNull();
    expect(hint?.getAttribute('aria-hidden')).toBe('true');
    expect(hint?.querySelector('svg')).not.toBeNull();
  });

  it('skips already-processed diagrams', () => {
    const diagram = createDiagram();
    document.body.appendChild(diagram);

    setupMermaidZoom();
    setupMermaidZoom();

    const hints = diagram.querySelectorAll('.mermaid-zoom-hint');
    expect(hints.length).toBe(1);
  });

  it('sets position: relative on diagram', () => {
    const diagram = createDiagram();
    document.body.appendChild(diagram);

    setupMermaidZoom();

    expect(diagram.style.position).toBe('relative');
  });

  it('supports custom selector', () => {
    const diagram = document.createElement('div');
    diagram.className = 'my-diagram';
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    diagram.appendChild(svg);
    document.body.appendChild(diagram);

    setupMermaidZoom({ selector: '.my-diagram' });

    expect(diagram.dataset.zoomable).toBe('true');
  });

  it('supports custom dataAttr', () => {
    const diagram = createDiagram();
    document.body.appendChild(diagram);

    setupMermaidZoom({ dataAttr: 'enhanced' });

    expect(diagram.dataset.enhanced).toBe('true');
    expect(diagram.dataset.zoomable).toBeUndefined();
  });

  it('handles empty DOM gracefully', () => {
    expect(() => setupMermaidZoom()).not.toThrow();
  });

  it('processes multiple diagrams independently', () => {
    const d1 = createDiagram();
    const d2 = createDiagram();
    document.body.appendChild(d1);
    document.body.appendChild(d2);

    setupMermaidZoom();

    expect(d1.dataset.zoomable).toBe('true');
    expect(d2.dataset.zoomable).toBe('true');
    expect(d1.querySelector('.mermaid-zoom-hint')).not.toBeNull();
    expect(d2.querySelector('.mermaid-zoom-hint')).not.toBeNull();
  });
});

describe('click to zoom', () => {
  it('creates backdrop and zooms diagram on click', () => {
    const diagram = createDiagram();
    document.body.appendChild(diagram);

    setupMermaidZoom();
    diagram.click();

    const backdrop = document.querySelector('.mermaid-zoom-backdrop');
    expect(backdrop).not.toBeNull();
    expect(backdrop?.getAttribute('role')).toBe('dialog');
    expect(backdrop?.getAttribute('aria-modal')).toBe('true');
    expect(document.body.style.position).toBe('fixed');
    expect(document.body.style.overflow).toBe('hidden');
  });

  it('leaves placeholder in original position', async () => {
    const parent = document.createElement('div');
    const diagram = createDiagram();
    parent.appendChild(diagram);
    document.body.appendChild(parent);

    setupMermaidZoom();
    diagram.click();
    await new Promise((r) => requestAnimationFrame(r));

    // Parent should have a placeholder div
    const children = parent.children;
    expect(children.length).toBe(1);
    expect(children[0].tagName).toBe('DIV');
  });

  it('saves and removes SVG dimensions on zoom', async () => {
    const diagram = createDiagram(800, 400);
    document.body.appendChild(diagram);

    setupMermaidZoom();

    const svg = diagram.querySelector('svg')!;
    expect(svg.getAttribute('width')).toBe('800');

    diagram.click();
    await new Promise((r) => requestAnimationFrame(r));

    expect(svg.getAttribute('width')).toBeNull();
    expect(svg.getAttribute('height')).toBeNull();
    expect(diagram.dataset.origSvgWidth).toBe('800');
    expect(diagram.dataset.origSvgHeight).toBe('400');
  });

  it('closes when clicking on the zoomed diagram', async () => {
    const parent = document.createElement('div');
    const diagram = createDiagram();
    parent.appendChild(diagram);
    document.body.appendChild(parent);

    setupMermaidZoom();
    diagram.click();
    await new Promise((r) => requestAnimationFrame(r));

    const backdrop = document.querySelector('.mermaid-zoom-backdrop')!;
    expect(backdrop.classList.contains('active')).toBe(true);

    // Click on the diagram inside backdrop — should close
    diagram.dispatchEvent(new MouseEvent('click', { bubbles: true }));

    expect(backdrop.classList.contains('active')).toBe(false);
    expect(parent.contains(diagram)).toBe(true);
  });

  it('ignores click when another diagram is already zoomed', async () => {
    const d1 = createDiagram();
    const d2 = createDiagram();
    document.body.appendChild(d1);
    document.body.appendChild(d2);

    setupMermaidZoom();
    d1.click();
    await new Promise((r) => requestAnimationFrame(r));

    d2.click();
    await new Promise((r) => requestAnimationFrame(r));

    // d1 is in the backdrop (zoomed), d2 should not be zoomed
    expect(d1.classList.contains('mermaid-zoomed')).toBe(true);
    expect(d2.classList.contains('mermaid-zoomed')).toBe(false);
  });
});

describe('closeDiagram', () => {
  it('restores diagram to original position', () => {
    const parent = document.createElement('div');
    const diagram = createDiagram();
    parent.appendChild(diagram);
    document.body.appendChild(parent);

    setupMermaidZoom();
    diagram.click();

    closeDiagram();

    expect(parent.contains(diagram)).toBe(true);
    expect(diagram.classList.contains('mermaid-zoomed')).toBe(false);
    expect(document.body.style.position).toBe('');
    expect(document.body.style.overflow).toBe('');
  });

  it('restores SVG dimensions', () => {
    const diagram = createDiagram(800, 400);
    document.body.appendChild(diagram);

    setupMermaidZoom();
    diagram.click();

    const svg = diagram.querySelector('svg')!;
    expect(svg.getAttribute('width')).toBeNull();

    closeDiagram();

    expect(svg.getAttribute('width')).toBe('800');
    expect(svg.getAttribute('height')).toBe('400');
  });

  it('does nothing when no diagram is zoomed', () => {
    expect(() => closeDiagram()).not.toThrow();
  });

  it('deactivates backdrop', async () => {
    const diagram = createDiagram();
    document.body.appendChild(diagram);

    setupMermaidZoom();
    diagram.click();
    await new Promise((r) => requestAnimationFrame(r));

    const backdrop = document.querySelector('.mermaid-zoom-backdrop')!;
    expect(backdrop.classList.contains('active')).toBe(true);

    closeDiagram();

    expect(backdrop.classList.contains('active')).toBe(false);
  });
});

describe('cleanupMermaidZoom', () => {
  it('removes hints and restores state', () => {
    const diagram = createDiagram();
    document.body.appendChild(diagram);

    setupMermaidZoom();
    expect(diagram.querySelector('.mermaid-zoom-hint')).not.toBeNull();

    cleanupMermaidZoom();

    expect(diagram.querySelector('.mermaid-zoom-hint')).toBeNull();
    expect(diagram.dataset.zoomable).toBeUndefined();
    expect(diagram.style.cursor).toBe('');
    expect(diagram.style.position).toBe('');
  });

  it('removes backdrop', () => {
    const diagram = createDiagram();
    document.body.appendChild(diagram);

    setupMermaidZoom();
    diagram.click();

    cleanupMermaidZoom();

    expect(document.querySelector('.mermaid-zoom-backdrop')).toBeNull();
  });

  it('closes zoomed diagram before cleanup', () => {
    const parent = document.createElement('div');
    const diagram = createDiagram();
    parent.appendChild(diagram);
    document.body.appendChild(parent);

    setupMermaidZoom();
    diagram.click();

    cleanupMermaidZoom();

    expect(parent.contains(diagram)).toBe(true);
    expect(diagram.classList.contains('mermaid-zoomed')).toBe(false);
  });

  it('allows re-processing after cleanup', () => {
    const diagram = createDiagram();
    document.body.appendChild(diagram);

    setupMermaidZoom();
    cleanupMermaidZoom();
    setupMermaidZoom();

    expect(diagram.dataset.zoomable).toBe('true');
    expect(diagram.querySelectorAll('.mermaid-zoom-hint').length).toBe(1);
  });
});

describe('addKeyboardListener', () => {
  it('closes diagram on Escape key', () => {
    const parent = document.createElement('div');
    const diagram = createDiagram();
    parent.appendChild(diagram);
    document.body.appendChild(parent);

    setupMermaidZoom();
    const removeListener = addKeyboardListener();

    diagram.click();
    expect(document.body.style.position).toBe('fixed');

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));

    expect(parent.contains(diagram)).toBe(true);
    expect(document.body.style.position).toBe('');

    removeListener();
  });

  it('returns cleanup function', () => {
    const removeListener = addKeyboardListener();
    expect(typeof removeListener).toBe('function');
    removeListener();
  });

  it('ignores non-Escape keys', () => {
    const diagram = createDiagram();
    document.body.appendChild(diagram);

    setupMermaidZoom();
    const removeListener = addKeyboardListener();

    diagram.click();
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter' }));

    // Should still be zoomed
    expect(document.body.style.position).toBe('fixed');

    closeDiagram();
    removeListener();
  });
});

describe('scroll lock (iOS-safe)', () => {
  it('applies position fixed on body when zoomed', () => {
    const diagram = createDiagram();
    document.body.appendChild(diagram);

    setupMermaidZoom();
    diagram.click();

    expect(document.body.style.position).toBe('fixed');
    expect(document.body.style.left).toBe('0px');
    expect(document.body.style.right).toBe('0px');
    expect(document.body.style.overflow).toBe('hidden');

    closeDiagram();
  });

  it('restores all body styles on close', () => {
    const diagram = createDiagram();
    document.body.appendChild(diagram);

    setupMermaidZoom();
    diagram.click();
    closeDiagram();

    expect(document.body.style.position).toBe('');
    expect(document.body.style.top).toBe('');
    expect(document.body.style.left).toBe('');
    expect(document.body.style.right).toBe('');
    expect(document.body.style.overflow).toBe('');
  });
});

describe('focus management', () => {
  it('moves focus to backdrop on open', async () => {
    const diagram = createDiagram();
    document.body.appendChild(diagram);

    setupMermaidZoom();
    diagram.click();
    await new Promise((r) => requestAnimationFrame(r));

    const backdrop = document.querySelector('.mermaid-zoom-backdrop');
    expect(backdrop?.getAttribute('tabindex')).toBe('-1');
  });

  it('restores focus to previously focused element on close', async () => {
    const btn = document.createElement('button');
    document.body.appendChild(btn);
    btn.focus();

    const diagram = createDiagram();
    document.body.appendChild(diagram);

    setupMermaidZoom();
    diagram.click();
    await new Promise((r) => requestAnimationFrame(r));

    closeDiagram();

    expect(document.activeElement).toBe(btn);
  });
});

describe('SVG viewBox handling', () => {
  it('creates viewBox if missing when zooming', () => {
    const diagram = document.createElement('div');
    diagram.className = 'mermaid';
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('width', '600');
    svg.setAttribute('height', '300');
    // No viewBox set
    diagram.appendChild(svg);
    document.body.appendChild(diagram);

    setupMermaidZoom();
    diagram.click();

    expect(svg.getAttribute('viewBox')).toBe('0 0 600 300');

    closeDiagram();
  });

  it('skips viewBox when dimensions are zero', () => {
    const diagram = document.createElement('div');
    diagram.className = 'mermaid';
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    // No width/height attributes, getBoundingClientRect returns 0 in jsdom
    diagram.appendChild(svg);
    document.body.appendChild(diagram);

    setupMermaidZoom();
    diagram.click();

    // Should not set a bogus "0 0 0 0" viewBox
    expect(svg.getAttribute('viewBox')).toBeNull();

    closeDiagram();
  });

  it('preserves existing viewBox', () => {
    const diagram = document.createElement('div');
    diagram.className = 'mermaid';
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('width', '600');
    svg.setAttribute('height', '300');
    svg.setAttribute('viewBox', '0 0 1200 600');
    diagram.appendChild(svg);
    document.body.appendChild(diagram);

    setupMermaidZoom();
    diagram.click();

    expect(svg.getAttribute('viewBox')).toBe('0 0 1200 600');

    closeDiagram();
  });
});
