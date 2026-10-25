# TunnelTend website

## Meaning

This is the product website at `https://tunneltend.com` and Starlight manual at `https://docs.tunneltend.com/`, served by one host-aware Worker and one Astro artifact. The product host retains the FAQ, legal pages, online installer at `/install.ps1` and brand mirror at `/brand/tunneltend/`; old `/docs/*` addresses permanently redirect to the manual. The website owns reader-facing content; the repository's `docs/` tree stays maintainer documentation. A local build or preview establishes none of hosting, DNS, indexing or Windows qualification.

## Build and use locally

Use Node 24 (`.node-version`). From this directory:

```powershell
npm ci
npm run dev          # local preview at http://127.0.0.1:4321 (no search index in dev)
npm test             # brand bundle checks, Astro diagnostics, static build, output check
npm run preview      # serve the built artifacts/site/
npm run brand:export # regenerate ../brand/bundle/tunneltend from its masters
npm run brand:check  # validate the TunnelTend bundle and the vendored Works bundle
```

Output is `artifacts/site/`. `npm run check:publish` additionally refuses demonstration identity and fixture legal data; production supplies the private `WOLFSBLVT_LEGAL_OPERATOR_B64` projection.

Miniflare's Undici dependency is overridden to the compatible 7.30.1 patch while Wrangler 4.151.2 selects 7.29.1. This repairs the upstream [EventSource memory exhaustion](https://github.com/nodejs/undici/security/advisories/GHSA-4qv8-2p9j-2685), [integrity-token bypass](https://github.com/nodejs/undici/security/advisories/GHSA-f72v-6w45-q472) and [content-encoding crash](https://github.com/nodejs/undici/security/advisories/GHSA-xjj6-f33q-929c) advisories without changing the Worker or publication controller. The affected dependency runs in local development/deployment tooling, not in the static reader bundle or the deployed Worker's native `Request`/`Response` implementation. Remove the override when the selected Miniflare dependency carries the patch itself; qualify the locked build and local Worker when changing it.

`astro dev` and `astro preview` show internal build routes; they do not exercise the host bridge. For local Worker routing use `node node_modules/wrangler/bin/wrangler.js dev --local --local-upstream docs.tunneltend.com` and open `/` or `/getting-started/`. Use `--local-upstream tunneltend.com` for product-host behavior. Public links intentionally name their canonical hosts. A controlled browser request route can map both canonical origins to separate local upstream instances without contacting production. [Website integration](../docs/documentation-site.md) owns that serving contract and the Ops admission/rollback join.

## Source map

| Path | Owns |
| --- | --- |
| `site.config.mjs` | Identity, canonical URL, destinations, footer groups, legal facts |
| `src/data/` | Public page inventory, selected constants (release, OpenAI links, agent task), icons, destinations |
| `src/pages/` | Home, FAQ, legal pages, 404 |
| `src/components/home/` | The home sections: hero, how it fits, a day with TunnelTend, install, OpenAI, inspect, trust |
| `src/components/` | The shared header, footer, search, theme control, Fold, Wordmark, Works sponsor binding |
| `src/content/docs/docs/` | The user-facing manual (Starlight), written for a ChatGPT user first and a developer second |
| `src/styles/` | Moonpool tokens, the surface grammar, Starlight mapping |
| `src/lib/` | Pre-paint theme and reader-mode script, shared client behaviour, search, clipboard |
| `scripts/` | Identity model, asset generation (favicons, social cards, brand mirror, installer copy), brand export, publication checks |
| `vendor/brand/works/` | The vendored Wolfsblvt Works brand bundle (sponsor banner and component), validated as a byte copy |
| `src/worker.mjs`, `src/lib/public-routes.mjs` | Host routing, permanent compatibility bridge and shared public destinations |
| `scripts/finalize-public-routes.mjs` | Canonical emitted anchors and host-specific sitemaps from the single build |
| `wrangler.jsonc` | One Cloudflare Worker, the apex and Docs custom domains, and one static-assets binding |

## Reader mode

The site has two readings. Plain words are the default. "Excuse me, I'm a dev?!" (in the hero and in the how-it-works section) flips `<html data-reader>` to `dev`; elements carry `for-plain` or `for-dev` and the stylesheet hides the inactive one. Both modes share every fact; the dev view shows more of them.

On the two HTTPS public hosts, `tunneltend.preferences` shares appearance, theme traversal direction and reader mode through a Secure, SameSite=Lax, domain-scoped functional cookie. Its one-year lifetime is renewed by a choice, not by ordinary visits. It contains only fixed preference values, with no identifier; browsers send it on requests to the product domain and its subdomains. Each origin's local storage is a fallback. A pre-existing local choice migrates on a visit to that origin only when no valid shared choice exists; an unvisited origin's old local storage cannot be read. The shared choice wins over older local copies. Back/forward cache restoration rereads preferences. Cookie refusal leaves per-origin persistence; complete storage refusal leaves a usable page-local control. Local previews do not set the shared public-domain cookie. Clearing the cookie and both origins' local storage resets preferences. The privacy page discloses this data flow.

## Content rules

Write for someone who uses ChatGPT and has not met MCP, stdio or a tunnel; explain a term the first time it appears, then keep going. Keep every command, switch, path and default exact to the CLI. Never imply OpenAI affiliation, a hosted TunnelTend service or that a subscription includes tunnel access. Say "intended to run", not "always online". A product fact that changes in the repository docs is carried into the matching page here in the same change. The FAQ's answer ids are the stable link contract.

## Publish

`.github/workflows/website.yml` builds on relevant changes and publishes accepted `main` to Cloudflare Workers Static Assets once the repository variables `WEBSITE_TARGET=workers` and `CLOUDFLARE_ACCOUNT_ID` and the secrets `CLOUDFLARE_API_TOKEN` and `WOLFSBLVT_LEGAL_OPERATOR_B64` exist. Until then it builds and checks only. `wrangler.jsonc` declares the intended apex custom domain and disables provider/version aliases; those source choices are not provider readback. Hosting admission, DNS, the `www` redirect and Search Console follow the Wolf Ops public Home admission checklist. Ops activates the production inputs only after reconciling existing resources and the exact accepted source.
