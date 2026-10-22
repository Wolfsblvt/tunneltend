# Website integration

## Meaning

This note records how the product website under `website/` relates to this repository: which content it owns, which repository material it consumes, its public routes and page identities, the agent handoff destination, the brand mirror, the online installer, and what publication still requires. It does not establish a deployed site, DNS, Search Console standing or a completed Windows qualification.

## One writable copy per audience

The website authors its own user-facing manual in `website/src/content/docs/docs/` (Starlight). It is written for a reader who uses ChatGPT and may not know what MCP, stdio or a tunnel is, and only then for a developer. The repository's `docs/` tree remains the maintainer and contributor documentation; it is not generated into the site, and website pages carry no source-description sections. A product fact that changes in `docs/` is carried into the matching website page in the same change ([D-010](DECISIONS.md#d-010-the-website-authors-its-own-user-facing-manual)).

The website consumes three repository inputs directly at build time: the brand bundle `brand/bundle/tunneltend/`, the online installer `scripts/Install-TunnelTend-Online.ps1`, and nothing else from `docs/`.

## Routes and page identity

| Route | Browser title | Owner |
| --- | --- | --- |
| `/` | TunnelTend | `website/src/pages/index.astro` |
| `/faq/` | FAQ · TunnelTend | `website/src/pages/faq.astro`; answer ids are the stable link contract |
| `/docs/` | TunnelTend Docs | `website/src/content/docs/docs/index.md` |
| `/docs/how-it-works/` | How it works · TunnelTend Docs | the plain-words chain from a tool on the PC to ChatGPT |
| `/docs/getting-started/` | Get started · TunnelTend Docs | the complete first journey |
| `/docs/install-with-an-agent/` | Install with an agent · TunnelTend Docs | the canonical agent handoff destination |
| `/docs/registration/`, `/docs/service-state/`, `/docs/operations/`, `/docs/cli/` | … · TunnelTend Docs | use |
| `/docs/troubleshooting/`, `/docs/privacy-and-data/`, `/docs/security/`, `/docs/logging/` | … · TunnelTend Docs | understand |
| `/impressum/`, `/privacy/` | Impressum / Privacy and data · TunnelTend | legal, `noindex, nosnippet`, outside sitemap and search |
| `/install.ps1` | plain text | the online installer, served verbatim |
| `/brand/tunneltend/…` | files | the brand bundle, served verbatim per the Brand Bundle Contract |

The canonical origin is `https://tunneltend.com`; `www.tunneltend.com` is an alias that must redirect once the Home is admitted. Titles use the `Page · Surface` form; the docs surface is **TunnelTend Docs**. Social cards are generated from the Fold on a graphite field for every indexed page.

## Agent handoff

The homepage and the FAQ copy one task plus the canonical guide URL:

```text
Install TunnelTend for my current Windows user and register the MCP service I identify, following this guide: https://tunneltend.com/docs/install-with-an-agent/
```

That page carries the contract an agent needs without a second briefing: prerequisites, the exact install commands, credential references, the registration shape, the read-only completion checks, the policy switches and the boundaries. There is no MCP server, WebMCP surface or separate instruction packet.

## Build, check and publish

From `website/`: `npm ci`, then `npm test` (Astro diagnostics, static build into `website/artifacts/site/`, output check), `npm run dev` for a local preview, `npm run brand:export` and `npm run brand:check` for the bundle. The site uses no web font, no analytics and no cookies; theme preference is the only browser storage.

`.github/workflows/website.yml` builds on relevant changes and publishes accepted `main` to Cloudflare Workers Static Assets (`website/wrangler.jsonc`) once Wolf Ops supplies `WEBSITE_TARGET`, `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_API_TOKEN` and the private legal operator projection `WOLFSBLVT_LEGAL_OPERATOR_B64`. Until then the workflow builds and checks only. Hosting admission, DNS, the `www` redirect and Search Console follow the Wolf Ops public Home admission checklist and are not claimed by this repository.
