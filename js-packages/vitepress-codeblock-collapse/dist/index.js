// src/collapse.ts
var DEFAULT_OPTIONS = {
  maxHeight: 380,
  selector: '.vp-doc div[class*="language-"]',
  dataAttr: "collapsed"
};
var nextBlockId = 0;
var blockControllers = /* @__PURE__ */ new WeakMap();
function createChevronSvg() {
  const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  svg.setAttribute("width", "16");
  svg.setAttribute("height", "16");
  svg.setAttribute("viewBox", "0 0 24 24");
  svg.setAttribute("fill", "none");
  svg.setAttribute("stroke", "currentColor");
  svg.setAttribute("stroke-width", "2");
  svg.setAttribute("stroke-linecap", "round");
  svg.setAttribute("stroke-linejoin", "round");
  svg.setAttribute("aria-hidden", "true");
  const polyline = document.createElementNS("http://www.w3.org/2000/svg", "polyline");
  polyline.setAttribute("points", "6 9 12 15 18 9");
  svg.appendChild(polyline);
  return svg;
}
function toggleBlock(block, pre, overlay, btn, maxHeight, dataAttr) {
  const isCollapsed = block.dataset[dataAttr] === "true";
  if (isCollapsed) {
    pre.style.maxHeight = "none";
    pre.style.overflow = "auto";
    block.dataset[dataAttr] = "false";
    overlay.classList.add("expanded");
    btn.classList.add("expanded");
    btn.setAttribute("aria-expanded", "true");
    btn.setAttribute("aria-label", "Collapse code block");
  } else {
    const viewportOffset = btn.getBoundingClientRect().top;
    pre.style.maxHeight = `${maxHeight}px`;
    pre.style.overflow = "hidden";
    pre.scrollTo(0, 0);
    block.dataset[dataAttr] = "true";
    overlay.classList.remove("expanded");
    btn.classList.remove("expanded");
    btn.setAttribute("aria-expanded", "false");
    btn.setAttribute("aria-label", "Expand code block");
    const newViewportOffset = btn.getBoundingClientRect().top;
    window.scrollTo(0, window.scrollY + (newViewportOffset - viewportOffset));
  }
}
function collapseCodeblocks(options = {}) {
  if (typeof document === "undefined") return;
  const { maxHeight, selector, dataAttr } = { ...DEFAULT_OPTIONS, ...options };
  const blocks = document.querySelectorAll(selector);
  for (const block of blocks) {
    if (block.dataset[dataAttr] !== void 0) continue;
    const pre = block.querySelector("pre");
    if (!pre || pre.scrollHeight <= maxHeight) continue;
    const blockId = `codeblock-${nextBlockId++}`;
    pre.id = blockId;
    const controller = new AbortController();
    const { signal } = controller;
    blockControllers.set(block, controller);
    block.dataset[dataAttr] = "true";
    pre.style.maxHeight = `${maxHeight}px`;
    pre.style.overflow = "hidden";
    const overlay = document.createElement("div");
    overlay.className = "codeblock-collapse-overlay";
    const btn = document.createElement("button");
    btn.className = "codeblock-collapse-btn";
    btn.setAttribute("type", "button");
    btn.setAttribute("aria-label", "Expand code block");
    btn.setAttribute("aria-expanded", "false");
    btn.setAttribute("aria-controls", blockId);
    btn.appendChild(createChevronSvg());
    btn.addEventListener("click", () => {
      toggleBlock(block, pre, overlay, btn, maxHeight, dataAttr);
    }, { signal });
    overlay.addEventListener("click", (e) => {
      if (e.target !== btn && !btn.contains(e.target)) {
        btn.click();
      }
    }, { signal });
    overlay.appendChild(btn);
    block.style.position = "relative";
    block.appendChild(overlay);
  }
}
function cleanupCodeblocks(options = {}) {
  if (typeof document === "undefined") return;
  const { selector, dataAttr } = { ...DEFAULT_OPTIONS, ...options };
  const blocks = document.querySelectorAll(selector);
  for (const block of blocks) {
    if (block.dataset[dataAttr] === void 0) continue;
    const controller = blockControllers.get(block);
    if (controller) {
      controller.abort();
      blockControllers.delete(block);
    }
    const overlay = block.querySelector(".codeblock-collapse-overlay");
    overlay?.remove();
    const pre = block.querySelector("pre");
    if (pre) {
      pre.style.maxHeight = "";
      pre.style.overflow = "";
      pre.removeAttribute("id");
    }
    delete block.dataset[dataAttr];
    block.style.position = "";
  }
}

// src/composable.ts
import { nextTick, onMounted, onUnmounted, watch } from "vue";
function useCodeblockCollapse(pagePath, options) {
  const run = () => nextTick(() => collapseCodeblocks(options));
  onMounted(run);
  const stopWatch = watch(pagePath, run);
  onUnmounted(() => {
    stopWatch();
    cleanupCodeblocks(options);
  });
}
export {
  cleanupCodeblocks,
  collapseCodeblocks,
  useCodeblockCollapse
};
