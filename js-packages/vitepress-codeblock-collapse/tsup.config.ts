import { copyFileSync } from 'node:fs';
import { defineConfig } from 'tsup';

export default defineConfig({
  entry: ['src/index.ts'],
  format: ['esm', 'cjs'],
  dts: true,
  clean: true,
  external: ['vue', 'vitepress'],
  onSuccess: async () => {
    copyFileSync('src/style.css', 'dist/style.css');
  },
});
