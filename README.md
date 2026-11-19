# amstrdm.dev

My personal portfolio. A static site built with [Astro](https://astro.build),
painted in [`dutchpro`](https://github.com/amstrdm/dutchpro) — the Neovim
colorscheme I wrote.

## Develop

```bash
npm install
npm run dev        # http://localhost:4321
```

## Build

```bash
npm run build      # static output in ./dist
npm run preview    # serve the built output locally
```

## Content

- Page sections live in `src/pages/index.astro`.
- Long-form writeups are Markdown in `src/content/writeups/` (frontmatter schema
  in `src/content.config.ts`); each one gets its own page at `/writeups/<slug>`,
  can link to its canonical full version via `fullSource`, and embeds figures
  from `public/figures/`.
- Colors and type tokens are in `src/styles/global.css`.

## Social / OG images

Each page has a 1200×630 Open Graph image for link previews (LinkedIn, etc.):
`/og/default.png` for the home page and `/og/<slug>.png` per writeup. They're
committed under `public/og/`. To regenerate after changing titles (needs Chrome):

```bash
bash scripts/make-og.sh
```

The cards are rendered from `scripts/og-template.html`.

## Deploy

Pushing to `main` triggers `.github/workflows/deploy.yml`, which builds and
publishes to GitHub Pages. In the repo settings, set **Settings → Pages →
Build and deployment → Source** to **GitHub Actions** once.

Served from the custom domain root (`https://amstrdm.dev`), so `astro.config.mjs`
uses `base: '/'` and `public/CNAME` pins the domain into the build artifact (the
Actions deploy doesn't commit a CNAME on its own).
