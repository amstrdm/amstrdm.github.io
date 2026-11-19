// @ts-check
import { defineConfig } from 'astro/config';

// Custom domain, served from the root, so no base path.
export default defineConfig({
  site: 'https://amstrdm.dev',
  base: '/',
  trailingSlash: 'ignore',
  build: { format: 'directory' },
});
