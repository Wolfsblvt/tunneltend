import { defineCollection } from 'astro:content';
import { z } from 'astro/zod';
import { docsLoader } from '@astrojs/starlight/loaders';
import { docsSchema } from '@astrojs/starlight/schema';
import site from '../site.config.mjs';

const identitySchema = z.object({
  role: z.enum(['public', 'unlisted', 'task', 'legal', 'error', 'private', 'preview', 'resource']).optional(),
  section: z.string().optional(),
  descriptor: z.string().nullable().optional(),
  language: z.string().optional(),
  locale: z.string().optional(),
  indexing: z.enum(['index', 'noindex']).optional(),
  sharing: z.enum(['share', 'none']).optional(),
  canonical: z.union([z.string(), z.literal(false)]).optional(),
  home: z.boolean().optional(),
  social: z.object({
    image: z.string().optional(),
    alt: z.string().optional(),
    generate: z.boolean().optional(),
    eyebrow: z.string().optional(),
    fact: z.string().optional(),
  }).optional(),
}).optional();

export const collections = site.docs.mode === 'manual'
  ? {
      docs: defineCollection({
        loader: docsLoader(),
        schema: docsSchema({
          extend: z.object({
            description: z.string().min(1),
            identity: identitySchema,
          }),
        }),
      }),
    }
  : {};
