# vitepress-mermaid-zoom

Click-to-zoom fullscreen overlay for Mermaid diagrams in VitePress.

Adds a small expand icon to each diagram. Clicking opens the diagram in a fullscreen overlay with backdrop blur. Press **Escape** or click outside to close.

## Installation

```bash
npm install vitepress-mermaid-zoom
```

## Usage

### VitePress (recommended)

Use the Vue composable in your custom theme layout:

```ts
// .vitepress/theme/Layout.vue
<script setup>
import { computed } from 'vue';
import { useData } from 'vitepress';
import DefaultTheme from 'vitepress/theme';
import { useMermaidZoom } from 'vitepress-mermaid-zoom';
import 'vitepress-mermaid-zoom/style.css';

const { page } = useData();
const pagePath = computed(() => page.value.relativePath);

useMermaidZoom(pagePath);
</script>

<template>
  <DefaultTheme.Layout />
</template>
```

The composable automatically:
- Processes diagrams on mount
- Re-processes on page navigation
- Cleans up listeners on unmount
- Adds keyboard support (Escape to close)

### Standalone

```ts
import { setupMermaidZoom, cleanupMermaidZoom, addKeyboardListener } from 'vitepress-mermaid-zoom';
import 'vitepress-mermaid-zoom/style.css';

// Setup
setupMermaidZoom();
const removeKeyboardListener = addKeyboardListener();

// Cleanup when done
removeKeyboardListener();
cleanupMermaidZoom();
```

## API

### `setupMermaidZoom(options?)`

Scans the DOM for Mermaid diagrams and adds click-to-zoom behavior. Safe to call multiple times.

### `cleanupMermaidZoom(options?)`

Removes all zoom UI and event listeners. Closes any zoomed diagram first.

### `closeDiagram()`

Closes the currently zoomed diagram programmatically.

### `addKeyboardListener()`

Adds a global Escape key listener. Returns a cleanup function.

### `useMermaidZoom(pagePath, options?)`

Vue composable that handles the full lifecycle automatically.

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `selector` | `string` | `'.mermaid'` | CSS selector for diagram containers |
| `dataAttr` | `string` | `'zoomable'` | Data attribute to track processed diagrams |

## Features

- Fullscreen overlay with backdrop blur
- Keyboard support (Escape to close)
- iOS-safe scroll lock
- SVG dimension handling (saves/restores width/height, auto-creates viewBox)
- Focus management (saves/restores focus)
- Dark mode support (VitePress `.dark` class)
- Reduced motion support (`prefers-reduced-motion`)
- ARIA attributes for accessibility
- Tree-shakeable ESM + CJS

## Browser Support

All modern browsers. Uses `backdrop-filter` (Safari 9+, Chrome 76+, Firefox 103+).

## License

MIT
