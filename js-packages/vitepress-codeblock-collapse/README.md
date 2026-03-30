# vitepress-codeblock-collapse

Auto-collapse long code blocks in VitePress with an expand/collapse toggle.

- Collapses code blocks taller than a configurable height
- Gradient overlay with animated chevron button
- Keyboard accessible (Tab, Enter/Space, focus-visible)
- ARIA attributes (`aria-expanded`, `aria-controls`)
- Respects `prefers-reduced-motion`
- SSR-safe — no `document` access on the server
- Cleanup API to remove all UI and event listeners
- Works with any Vue 3 project (VitePress optional)

## Installation

```bash
npm install vitepress-codeblock-collapse
```

## Usage

### VitePress (recommended)

```ts
// .vitepress/theme/index.ts
import { computed } from 'vue'
import DefaultTheme from 'vitepress/theme'
import { useData } from 'vitepress'
import { useCodeblockCollapse } from 'vitepress-codeblock-collapse'
import 'vitepress-codeblock-collapse/style.css'

export default {
  extends: DefaultTheme,
  setup() {
    const { page } = useData()
    const pagePath = computed(() => page.value.relativePath)
    useCodeblockCollapse(pagePath)
  },
}
```

### Standalone (any Vue 3 app)

```ts
import { collapseCodeblocks } from 'vitepress-codeblock-collapse'
import 'vitepress-codeblock-collapse/style.css'

// Call after DOM is ready
collapseCodeblocks({
  selector: '.my-code-blocks div[class*="language-"]',
  maxHeight: 400,
})
```

## API

### `useCodeblockCollapse(pagePath, options?)`

Vue composable — auto-collapses on mount and re-processes on page navigation.

| Param | Type | Description |
|---|---|---|
| `pagePath` | `Ref<string>` | Reactive ref that changes on navigation |
| `options` | `CodeblockCollapseOptions` | Optional config |

### `collapseCodeblocks(options?)`

Scans the DOM for tall code blocks and adds collapse/expand UI. Safe to call multiple times.

### `cleanupCodeblocks(options?)`

Removes all collapse UI and event listeners from processed blocks.

### `CodeblockCollapseOptions`

| Option | Type | Default | Description |
|---|---|---|---|
| `maxHeight` | `number` | `380` | Max height (px) before collapse |
| `selector` | `string` | `'.vp-doc div[class*="language-"]'` | CSS selector for code block containers |
| `dataAttr` | `string` | `'collapsed'` | Data attribute for tracking state |

## License

[MIT](./LICENSE)
