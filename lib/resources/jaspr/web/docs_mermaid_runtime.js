(() => {
  const currentTheme = () =>
    document.documentElement.getAttribute('data-theme') === 'dark'
      ? 'dark'
      : 'light';
  const mermaidScriptUrl =
    'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js';

  let lastTheme = currentTheme();
  let bootAttempts = 0;
  let bootTimer = null;
  let mermaidLoadPromise = null;

  function setGlobalLoadError(error) {
    const nodes = Array.from(document.querySelectorAll('.mermaid-diagram'));
    for (const node of nodes) {
      const placeholder = node.querySelector('[data-mermaid-placeholder]');
      const fallback = node.querySelector('[data-mermaid-fallback]');
      const fallbackMessage = node.querySelector(
        '[data-mermaid-fallback-message]',
      );
      node.setAttribute('data-rendered', 'false');
      node.setAttribute('data-mermaid-state', 'error');
      node.setAttribute('data-mermaid-error', String(error));
      if (placeholder) placeholder.setAttribute('hidden', 'hidden');
      if (fallback) {
        fallback.removeAttribute('hidden');
        fallback.style.display = 'block';
      }
      if (fallbackMessage) {
        fallbackMessage.textContent =
          `Unable to load Mermaid. ${String(error)}. Showing Mermaid source instead.`;
      }
    }
  }

  function ensureMermaid() {
    if (window.mermaid) return Promise.resolve(window.mermaid);
    if (mermaidLoadPromise) return mermaidLoadPromise;

    mermaidLoadPromise = new Promise((resolve, reject) => {
      const existing = document.querySelector('script[data-docs-mermaid-cdn]');
      if (existing) {
        existing.addEventListener('load', () => resolve(window.mermaid), {
          once: true,
        });
        existing.addEventListener(
          'error',
          () => reject(new Error('Failed to load Mermaid CDN script.')),
          { once: true },
        );
        return;
      }

      const script = document.createElement('script');
      script.src = mermaidScriptUrl;
      script.defer = true;
      script.dataset.docsMermaidCdn = 'true';
      script.onload = () => resolve(window.mermaid);
      script.onerror = () =>
        reject(new Error('Failed to load Mermaid CDN script.'));
      document.head.appendChild(script);
    });

    return mermaidLoadPromise;
  }

  async function renderMermaid(force = false) {
    let mermaid;
    try {
      mermaid = await ensureMermaid();
    } catch (error) {
      setGlobalLoadError(error);
      return false;
    }

    const nodes = Array.from(document.querySelectorAll('.mermaid-diagram'));
    if (nodes.length === 0) return true;

    mermaid.initialize({
      startOnLoad: false,
      theme: currentTheme() === 'dark' ? 'dark' : 'default',
      securityLevel: 'loose',
      suppressErrorRendering: true,
    });

    let renderedAny = false;
    for (const [index, node] of nodes.entries()) {
      if (!force && node.getAttribute('data-rendered') === 'true') continue;

      const host = node.querySelector('[data-mermaid-host]');
      const placeholder = node.querySelector('[data-mermaid-placeholder]');
      const fallback = node.querySelector('[data-mermaid-fallback]');
      const fallbackMessage = node.querySelector(
        '[data-mermaid-fallback-message]',
      );
      const source = node.getAttribute('data-source-base64');
      if (!host) continue;

      if (placeholder) placeholder.removeAttribute('hidden');
      if (fallback) {
        fallback.setAttribute('hidden', 'hidden');
        fallback.style.display = 'none';
      }
      if (fallbackMessage) {
        fallbackMessage.textContent =
          'Unable to render diagram. Showing Mermaid source instead.';
      }

      host.innerHTML = '';
      host.setAttribute('hidden', 'hidden');
      host.setAttribute('aria-hidden', 'true');
      node.setAttribute('data-rendered', 'false');
      node.setAttribute('data-mermaid-state', 'pending');
      node.removeAttribute('data-mermaid-error');

      if (!source) continue;

      try {
        const graph = atob(source);
        const renderId = `docs-mermaid-${index}-${Date.now()}`;
        const { svg, bindFunctions } = await mermaid.render(renderId, graph);

        host.innerHTML = svg;
        bindFunctions?.(host);
        host.removeAttribute('hidden');
        host.setAttribute('aria-hidden', 'false');
        node.setAttribute('data-rendered', 'true');
        node.setAttribute('data-mermaid-state', 'rendered');
        if (placeholder) placeholder.setAttribute('hidden', 'hidden');
        if (fallback) {
          fallback.setAttribute('hidden', 'hidden');
          fallback.style.display = 'none';
        }
        if (fallbackMessage) {
          fallbackMessage.textContent =
            'Unable to render diagram. Showing Mermaid source instead.';
        }
        renderedAny = true;
        window.dispatchEvent(new CustomEvent('docs:mermaid-rendered'));
      } catch (error) {
        node.setAttribute('data-rendered', 'false');
        node.setAttribute('data-mermaid-state', 'error');
        node.setAttribute('data-mermaid-error', String(error));
        if (placeholder) placeholder.setAttribute('hidden', 'hidden');
        if (fallback) {
          fallback.removeAttribute('hidden');
          fallback.style.display = 'block';
        }
        if (fallbackMessage) {
          fallbackMessage.textContent =
            `Unable to render diagram. ${String(error)}. Showing Mermaid source instead.`;
        }
        host.innerHTML = '';
        host.setAttribute('hidden', 'hidden');
        host.setAttribute('aria-hidden', 'true');
      }
    }

    return renderedAny;
  }

  function scheduleBoot() {
    if (bootTimer) return;
    const tick = async () => {
      bootAttempts += 1;
      const rendered = await renderMermaid();
      if (rendered || bootAttempts >= 24) {
        window.clearInterval(bootTimer);
        bootTimer = null;
      }
    };
    tick();
    bootTimer = window.setInterval(tick, 250);
  }

  document.addEventListener('docs:navigation', () => {
    window.setTimeout(() => {
      renderMermaid(true);
    }, 50);
  });

  window.setInterval(() => {
    const nextTheme = currentTheme();
    if (nextTheme === lastTheme) return;
    lastTheme = nextTheme;
    renderMermaid(true);
  }, 300);

  window.docsRenderMermaid = renderMermaid;
  scheduleBoot();
})();
