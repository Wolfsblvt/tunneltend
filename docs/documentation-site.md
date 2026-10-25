# Website integration

## Meaning

This note records how the product website under `website/` relates to this repository: which content it owns, which repository material it consumes, its public routes and page identities, the agent handoff destination, the brand mirror, the online installer, and what publication still requires. It does not establish a deployed site, DNS, Search Console standing or a completed Windows qualification.

## One writable copy per audience

The website authors its own user-facing manual in `website/src/content/docs/docs/` (Starlight). It is written for a reader who uses ChatGPT and may not know what MCP, stdio or a tunnel is, and only then for a developer. The repository's `docs/` tree remains the maintainer and contributor documentation; it is not generated into the site, and website pages carry no source-description sections. A product fact that changes in `docs/` is carried into the matching website page in the same change ([D-010](DECISIONS.md#d-010-the-website-authors-its-own-user-facing-manual)).

The website consumes three repository inputs directly at build time: the brand bundle `brand/bundle/tunneltend/`, the online installer `scripts/Install-TunnelTend-Online.ps1`, and nothing else from `docs/`.

## Routes and page identity

Product routes below use `https://tunneltend.com`; manual routes use `https://docs.tunneltend.com`.

| Route | Browser title | Owner |
| --- | --- | --- |
| `/` | TunnelTend | `website/src/pages/index.astro` |
| `/faq/` | FAQ · TunnelTend | `website/src/pages/faq.astro`; answer ids are the stable link contract |
| Docs `/` | TunnelTend Docs | `website/src/content/docs/docs/index.md` |
| Docs `/how-it-works/` | How it works · TunnelTend Docs | the plain-words chain from a tool on the PC to ChatGPT |
| Docs `/getting-started/` | Get started · TunnelTend Docs | the complete first journey |
| Docs `/install-with-an-agent/` | Install with an agent · TunnelTend Docs | the canonical agent handoff destination |
| Docs `/registration/`, `/service-state/`, `/operations/`, `/cli/`, `/agents/` | … · TunnelTend Docs | use |
| Docs `/troubleshooting/`, `/privacy-and-data/`, `/security/`, `/logging/` | … · TunnelTend Docs | understand |
| `/impressum/`, `/privacy/` | Impressum / Privacy and data · TunnelTend | legal, `noindex, nosnippet`, outside sitemap and search |
| `/install.ps1` | plain text | the online installer, served verbatim |
| `/brand/tunneltend/…` | files | the brand bundle, served verbatim per the Brand Bundle Contract |

The product origin is `https://tunneltend.com`, with `www.tunneltend.com` as its alias. The manual's canonical Home is `https://docs.tunneltend.com/` ([D-013](DECISIONS.md#d-013-the-manual-has-a-canonical-docs-home)). Titles use the `Page · Surface` form; the docs surface and host identity are **TunnelTend Docs**. Social cards are generated from the Fold on a graphite field for every indexed page. Existing `/docs/*` addresses permanently redirect with status 308 to the corresponding manual path, preserving query parameters; slashless directory links go directly to the final trailing-slash URL. Fragments remain browser-owned and are retained through redirects.

## Agent handoff

The homepage and the FAQ copy one task plus the canonical guide URL:

```text
Install TunnelTend for my current Windows user and register the MCP service I identify, following this guide: https://docs.tunneltend.com/install-with-an-agent/
```

That page carries the contract an agent needs without a second briefing: prerequisites, the exact install commands, credential references, the registration shape, the read-only completion checks, the policy switches and the boundaries. There is no MCP server, WebMCP surface or separate instruction packet.

## Build, check and publish

From `website/`: `npm ci`, then `npm test` (Astro diagnostics, routing tests, static build into `website/artifacts/site/`, output check), `npm run dev` for an authoring preview, `npm run brand:export` and `npm run brand:check` for the bundle. The site uses no analytics or cookies; its existing theme/reader preferences and Starlight navigation state remain browser-local.

One Astro build emits product pages and the Starlight manual. The manual keeps `/docs/` as an internal artifact coordinate so Starlight can calculate active navigation and pagination. `scripts/finalize-public-routes.mjs` projects emitted anchors to the canonical public hosts and writes separate host sitemaps. `src/lib/public-routes.mjs` supplies the same destinations to page identity, the agent task, search results and the Worker. Pagefind indexes the single content set; its original artifact URLs are mapped before a result becomes a clickable link.

`src/worker.mjs` runs before assets: apex `/docs/*` is redirected; the Docs host's `/guide/` requests resolve to internal `/docs/guide/` assets. Both hosts use the same static CSS, JavaScript, images and Pagefind index. Product/FAQ/legal/installer links return to the apex. The Worker contains no credentials, remote proxy or durable state. The left rail uses the same available-width coordinate as the header; both docs rails are sticky within the article frame and release before the shared footer. The FAQ inherits the shared `.wrap` grid.

`.github/workflows/website.yml` builds on relevant changes and publishes accepted `main` to Cloudflare Workers Static Assets (`website/wrangler.jsonc`) once Wolf Ops supplies `WEBSITE_TARGET`, `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_API_TOKEN` and the private legal operator projection `WOLFSBLVT_LEGAL_OPERATOR_B64`. Until then the workflow builds and checks only. Hosting admission, DNS, the `www` redirect and Search Console follow the Wolf Ops public Home admission checklist and are not claimed by this repository.

## Docs migration operating join

Before integration triggers publication, Wolf Ops reconciles the existing `tunneltend-website` Worker and the new `docs.tunneltend.com` custom domain, DNS and TLS. `wrangler.jsonc` now selects that host alongside the apex, the `ASSETS` binding and selective Worker-first routing. HTML, discovery and redirects invoke the Worker; shared CSS, JavaScript, images and Pagefind assets retain native static serving. This adds request invocations for host-dependent responses; Ops reconciles the existing plan's limits and cost before deployment. The same relevant-main workflow deploys both; no second pipeline, token or recurring operator ritual is needed. Existing `www` edge redirects must send `/docs/*` directly to the final Docs URL, ahead of any generic www-to-apex rule, to avoid a redirect chain.

Each origin exposes its own `/robots.txt`, `/sitemap-index.xml` and `/sitemap-0.xml`; product and docs indexable URLs are disjoint, and legal pages remain excluded. Docs sitemap files use `docs-sitemap-*.xml` internally and are not public apex endpoints. Reconcile both canonical sitemap endpoints under the existing `sc-domain:tunneltend.com` Search Console property; a new property is unnecessary.

Ops reads back the apex, Docs Home, one guide, old apex and www links (including query/fragment), search, installer, legal links, both sitemaps and TLS after publication. Preserve the previous deployed Worker version and admission state for rollback. If source is rolled back, reconcile the Docs custom-domain route with that version's capabilities rather than serving a product homepage as Docs. Source/build/local Worker evidence does not establish these live outcomes or Google processing/indexing.
