// @ts-check
import { defineConfig } from 'astro/config';

// User page: served from the domain root (amstrdm.github.io), so no base path.
export default defineConfig({
  site: 'https://amstrdm.github.io',
  base: '/',
  trailingSlash: 'ignore',
  build: { format: 'directory' },
});
