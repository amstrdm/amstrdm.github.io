import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

const writeups = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/writeups' }),
  schema: z.object({
    title: z.string(),
    subtitle: z.string(),
    accent: z.enum(['mint', 'blue', 'orange', 'teal', 'red', 'purple']),
    date: z.string(),
    status: z.string(),
    stack: z.array(z.string()),
    repo: z.string().url().optional(),
    live: z.string().url().optional(),
    // optional link out to the full version of this writeup
    fullSource: z
      .object({ label: z.string(), url: z.string().url() })
      .optional(),
    order: z.number(),
  }),
});

export const collections = { writeups };
