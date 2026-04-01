(() => {
  const pswpCssUrl =
    'https://cdn.jsdelivr.net/npm/photoswipe@5/dist/photoswipe.css';
  const pswpModuleUrl =
    'https://cdn.jsdelivr.net/npm/photoswipe@5/dist/photoswipe.esm.min.js';
  const lightCodeColorMap = new Map([
    ['#b9eeff', '#1f2937'],
    ['#d4d4d4', '#334155'],
    ['#569cd6', '#005cc5'],
    ['#4ec9b0', '#0f766e'],
    ['#5caeef', '#2563eb'],
    ['#dfb976', '#9a6700'],
    ['#b5cea8', '#116329'],
    ['#dcdcaa', '#6f42c1'],
    ['#608b4e', '#57606a'],
    ['#ce9178', '#9a3412'],
    ['#c172d9', '#7c3aed'],
  ]);

  let modulePromise = null;
  let enhancementTimer = null;
  let enhancementAttempts = 0;
  let themeObserver = null;

  function ensureStylesheet() {
    if (document.querySelector('link[data-docs-pswp-css]')) return;
    const link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = pswpCssUrl;
    link.dataset.docsPswpCss = 'true';
    document.head.appendChild(link);
  }

  function ensurePhotoSwipe() {
    if (modulePromise) return modulePromise;
    modulePromise = import(pswpModuleUrl);
    return modulePromise;
  }

  function measureSvg(svg) {
    const viewBox = svg.viewBox?.baseVal;
    if (viewBox && viewBox.width > 0 && viewBox.height > 0) {
      return { width: Math.round(viewBox.width), height: Math.round(viewBox.height) };
    }
    const rect = svg.getBoundingClientRect();
    return {
      width: Math.max(1, Math.round(rect.width || 1200)),
      height: Math.max(1, Math.round(rect.height || 700)),
    };
  }

  async function openLightbox(item, cleanup) {
    ensureStylesheet();
    const { default: PhotoSwipe } = await ensurePhotoSwipe();
    const gallery = new PhotoSwipe({
      dataSource: [item],
      index: 0,
      showHideAnimationType: 'zoom',
      bgOpacity: 0.92,
      wheelToZoom: true,
      spacing: 0.12,
      pswpModule: PhotoSwipe,
    });
    if (cleanup) {
      gallery.on('destroy', cleanup);
    }
    gallery.init();
  }

  function shouldEnhanceImage(img) {
    if (!(img instanceof HTMLImageElement)) return false;
    if (!img.src || img.closest('.docs-search-overlay, .header-container, .sidebar-container, .toc')) {
      return false;
    }
    if (img.closest('[data-docs-lightbox-ignore]')) return false;
    return true;
  }

  function enhanceImages(root = document) {
    root.querySelectorAll('.content img').forEach((img) => {
      if (!shouldEnhanceImage(img)) return;
      img.setAttribute('data-docs-lightbox-image', 'true');
      img.style.cursor = 'zoom-in';
    });
  }

  function enhanceMermaid(root = document) {
    root.querySelectorAll('.mermaid-diagram').forEach((node) => {
      const frame = node.querySelector('.mermaid-frame');
      const svg = node.querySelector('.mermaid-host svg');
      if (!frame || !svg) return;
      frame.setAttribute('data-docs-lightbox-mermaid', 'true');
      frame.style.cursor = 'zoom-in';
    });
  }

  function enhanceAll(root = document) {
    normalizeMemberSignatures(root);
    applyCodePalette(root);
    enhanceImages(root);
    enhanceMermaid(root);
  }

  function currentTheme() {
    return document.documentElement?.getAttribute('data-theme') === 'dark'
      ? 'dark'
      : 'light';
  }

  function normalizeColor(value) {
    if (!value) return null;
    const trimmed = value.trim().toLowerCase();
    if (trimmed.startsWith('#')) {
      if (trimmed.length === 4) {
        return `#${trimmed[1]}${trimmed[1]}${trimmed[2]}${trimmed[2]}${trimmed[3]}${trimmed[3]}`;
      }
      return trimmed;
    }
    return trimmed;
  }

  function extractInlineColor(node) {
    const style = node.getAttribute('style') || '';
    const match = style.match(/color:\s*([^;]+)/i);
    return match ? normalizeColor(match[1]) : null;
  }

  function applyCodePalette(root = document) {
    const isDark = currentTheme() === 'dark';
    root
      .querySelectorAll('.content .code-block code [style*="color"], .dartpad-preview code [style*="color"]')
      .forEach((node) => {
        if (!(node instanceof HTMLElement)) return;

        const original =
          node.dataset.docsOriginalColor || extractInlineColor(node);
        if (!original) return;

        if (!node.dataset.docsOriginalColor) {
          node.dataset.docsOriginalColor = original;
        }

        const nextColor = isDark
          ? original
          : lightCodeColorMap.get(original) || original;

        node.style.setProperty('color', nextColor, 'important');
      });
  }

  function needsMermaidEnhancement(root = document) {
    return Array.from(root.querySelectorAll('.mermaid-diagram')).some((node) => {
      const frame = node.querySelector('.mermaid-frame');
      const svg = node.querySelector('.mermaid-host svg');
      return !!frame && !!svg && !frame.hasAttribute('data-docs-lightbox-mermaid');
    });
  }

  function scheduleEnhancementPasses(root = document) {
    if (enhancementTimer) {
      window.clearInterval(enhancementTimer);
      enhancementTimer = null;
    }

    enhancementAttempts = 0;
    const run = () => {
      enhancementAttempts += 1;
      enhanceAll(root);
      if (!needsMermaidEnhancement(root) || enhancementAttempts >= 16) {
        window.clearInterval(enhancementTimer);
        enhancementTimer = null;
      }
    };

    run();
    enhancementTimer = window.setInterval(run, 180);
  }

  function shouldInsertSignatureSpace(previousText, nextText) {
    if (!previousText || !nextText) return false;

    if (previousText === '.' || previousText === '?.' || previousText === '..') {
      return false;
    }

    if (
      nextText.startsWith('(') ||
      nextText.startsWith('[') ||
      /^[,.;:)\]}>]/.test(nextText)
    ) {
      return false;
    }

    if (/^(?:\(|\[|\{|<)$/.test(previousText)) {
      return false;
    }

    return true;
  }

  function normalizeMemberSignatures(root = document) {
    root.querySelectorAll('.member-signature-code').forEach((node) => {
      if (node.hasAttribute('data-signature-normalized')) return;
      const parts = [];

      for (const child of Array.from(node.childNodes)) {
        if (child.nodeType === Node.TEXT_NODE) {
          const text = (child.textContent || '').replace(/\s+/g, ' ').trim();
          if (text) {
            parts.push({ type: 'text', text });
          }
          continue;
        }

        if (child.nodeType === Node.ELEMENT_NODE) {
          const element = child.cloneNode(true);
          const text = (child.textContent || '').replace(/\s+/g, ' ').trim();
          if (text) {
            parts.push({ type: 'element', text, element });
          }
        }
      }

      if (parts.length === 0) return;

      node.replaceChildren();
      let previousText = '';
      for (const part of parts) {
        if (shouldInsertSignatureSpace(previousText, part.text)) {
          node.append(document.createTextNode(' '));
        }

        if (part.type === 'text') {
          node.append(document.createTextNode(part.text));
        } else {
          node.append(part.element);
        }

        previousText = part.text;
      }

      node.setAttribute('data-signature-normalized', 'true');
    });
  }

  document.addEventListener('click', async (event) => {
    const target = event.target;
    if (!(target instanceof Element)) return;

    const image = target.closest('[data-docs-lightbox-image]');
    if (image instanceof HTMLImageElement) {
      event.preventDefault();
      await openLightbox({
        src: image.currentSrc || image.src,
        width: image.naturalWidth || Math.max(1, Math.round(image.clientWidth * 2)),
        height: image.naturalHeight || Math.max(1, Math.round(image.clientHeight * 2)),
        alt: image.alt || '',
      });
      return;
    }

    const mermaidFrame = target.closest('[data-docs-lightbox-mermaid]');
    if (mermaidFrame instanceof HTMLElement) {
      const svg = mermaidFrame.querySelector('svg');
      if (!(svg instanceof SVGSVGElement)) return;
      event.preventDefault();

      const serialized = new XMLSerializer().serializeToString(svg);
      const blob = new Blob([serialized], { type: 'image/svg+xml;charset=utf-8' });
      const objectUrl = URL.createObjectURL(blob);
      const { width, height } = measureSvg(svg);

      await openLightbox(
        {
          src: objectUrl,
          width,
          height,
          alt: 'Mermaid diagram',
        },
        () => URL.revokeObjectURL(objectUrl),
      );
    }
  });

  function handleNavigationEnhancement() {
    window.setTimeout(() => scheduleEnhancementPasses(document), 60);
  }

  function handleMermaidEnhancement() {
    window.setTimeout(() => scheduleEnhancementPasses(document), 30);
  }

  document.addEventListener('docs:navigation', handleNavigationEnhancement);
  window.addEventListener('docs:navigation', handleNavigationEnhancement);
  document.addEventListener('docs:mermaid-rendered', handleMermaidEnhancement);
  window.addEventListener('docs:mermaid-rendered', handleMermaidEnhancement);

  if (!themeObserver) {
    themeObserver = new MutationObserver(() => {
      window.setTimeout(() => enhanceAll(document), 30);
    });
    themeObserver.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ['data-theme'],
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
      scheduleEnhancementPasses(document);
    }, { once: true });
  } else {
    scheduleEnhancementPasses(document);
  }
})();
