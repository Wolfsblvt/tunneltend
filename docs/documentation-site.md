# Documentation site integration

## Meaning

This note defines the public Markdown sources, page identities, navigation, and integration checks for TunnelTend's documentation entrance and FAQ. It is a source contribution for the website being designed separately. It does not establish a deployed site, domain, release, or completed Windows qualification.

## Reader and editorial decisions

The first reader has a working MCP service but need not have used the official tunnel client. The entrance explains the ownership relationship before asking the reader to install anything. Getting started supplies one concrete existing-tunnel setup and gives a human and a local coding agent the same operational source.

The FAQ owns evaluation, relationships, and honest comparisons. Its twenty answers are grouped into fit and relationships, access and trust, automation and control, and cost and leaving. Detailed setup, command syntax, and failure handling live in their guides; the FAQ links there instead of duplicating those procedures.

The voice is **quiet caretaker, sharp operator**. The promise is **Register once. Leave the routine to TunnelTend.** Describe defaults and their limits plainly. Do not imply an OpenAI affiliation, hosted TunnelTend service, subscription entitlement, production certification, or a remote call for the reader’s untested service.

## Canonical source and page identity

Consume these files directly, or generate pages from them during the website build. Do not maintain another writable copy in the website. The routes below are proposed integration routes, not claims about a currently deployed URL. Use a single selected production origin when the website establishes it.

| Source | Proposed route | Browser title | Description |
| --- | --- | --- | --- |
| [user-guide.md](user-guide.md) | `/docs/` | TunnelTend Docs | Register and operate MCP services with TunnelTend: first setup, daily control, diagnostics, and honest connection checks. |
| [getting-started.md](getting-started.md) | `/docs/getting-started/` | Get started · TunnelTend Docs | Install TunnelTend on Windows, register an existing MCP service, and verify the connection from your consumer. |
| [registration.md](registration.md) | `/docs/registration/` | Service registration · TunnelTend Docs | Register a project, stdio command, HTTP MCP endpoint, or existing official alias with explicit launch and tunnel settings. |
| [product-model.md](product-model.md) | `/docs/service-state/` | Service state · TunnelTend Docs | Understand registration, durable intent, current-session activity, health, readiness, and observed service state. |
| [OPERATIONS.md](OPERATIONS.md) | `/docs/operations/` | Operations · TunnelTend Docs | Control sign-in startup, deliberate stops, bounded recovery, source watching, and official-client maintenance. |
| [cli-reference.md](cli-reference.md) | `/docs/cli/` | CLI reference · TunnelTend Docs | Look up TunnelTend commands, read and apply boundaries, structured output, global options, and exit codes. |
| [troubleshooting.md](troubleshooting.md) | `/docs/troubleshooting/` | Troubleshooting · TunnelTend Docs | Diagnose failed starts, missing automation, deferred recovery, client updates, and consumer connection failures. |
| [PRIVACY-AND-DATA.md](PRIVACY-AND-DATA.md) | `/docs/privacy-and-data/` | Privacy and data · TunnelTend Docs | See what TunnelTend stores locally, how credential references work, and what remains with external services. |
| [SECURITY.md](SECURITY.md) | `/docs/security/` | Security · TunnelTend Docs | Understand TunnelTend's process ownership, credential, download, and local execution trust boundaries. |
| [LOGGING.md](LOGGING.md) | `/docs/logging/` | Logging · TunnelTend Docs | Find operational logs and understand their contents, retention, redaction, and diagnostic sharing limits. |
| [faq.md](faq.md) | `/faq/` | FAQ · TunnelTend | Answers about TunnelTend's purpose, OpenAI relationship, local operation, privacy, automation, release status, and license. |

Use `en` as the content language. The documentation surface is **TunnelTend Docs**; the FAQ belongs to the **TunnelTend** product surface. Apply each title once, without repeating the site name in a template suffix. Generate normal social cards from the selected page identity and approved brand assets unless the website has a specifically authored alternative.

The new and rewritten public page payloads begin with useful reader content. They do not need a source-description `Meaning` section. This integration note and the repository map retain that internal documentation structure.

## Navigation and links

Expose **Docs** and **FAQ** as direct product navigation destinations. The docs sidebar follows the table's guide order, with the FAQ available as an adjacent product link. The docs entrance offers **Get started**, **Install with a local agent**, and **FAQ** as explicit choices. Do not make an internal project map the first reading assignment.

Resolve source-relative Markdown links through the source-to-route mapping above, preserving fragments. Links to repository-only material remain GitHub source links at the selected published revision: examples, schemas, license, contribution/security-reporting guidance, release evidence, and the repository's `AGENTS.md`. Do not turn them into nonexistent website routes.

This is an allowlist. Do not publish every file under `docs/`. The repository documentation map, this note, Vision, Direction, Decisions, architecture and development records, research snapshots, release procedures, and assignment carriers are not ordinary public website pages merely because they are present in the repository. Explicit links to public repository evidence remain valid without ingesting that evidence into site navigation.

No versioned documentation selector is needed while one current manual serves the supported release line. Introduce one only when concurrently supported versions create a real reader need.

## FAQ anchors and rendering

Every FAQ answer has an explicit semantic lowercase-kebab ID on its actual `<h3>` heading. Preserve these authored IDs when rendering or converting the Markdown. They are the stable link contract; changing a question's visible wording must not change its ID. Preserve old destinations or add redirects if an answer later moves.

The Markdown is complete with ordinary visible answers. If the design uses disclosures, carry each existing ID onto the actual rendered question heading or disclosure, preserve the heading hierarchy, and make fragment navigation open and reveal the target. Do not require a reader to expand every answer before browser find, a shared link, or an agent can find the content. Keyboard operation, focus visibility, and accessible expanded state belong to the rendered integration check.

Render code as code and keep examples copyable. Tables express exact ownership and command/effect comparisons; allow them to scroll within their container on narrow screens without causing page-wide overflow. Do not infer a new component framework from raw heading IDs.

## Brand and status

Use the approved **Fold** identity and **Moonpool After Dark** palette in the website's design system. This content change does not redraw the mark or create a competing set of brand assets. Cyan is identity/action color, not a healthy-state signal. Health, degradation, failure, and neutral state need their own semantic treatment and visible text; color alone is insufficient.

Keep current release availability, prerequisites and material qualification limits visible at the documentation entrance and first installation. A published documentation page does not itself turn the software into a released or Windows-qualified product. Change the release wording when actual release evidence changes, not when the design looks finished.

## Agent handoff

The contextual install action should copy one task plus the canonical getting-started URL and use the prerequisites and completion checks from that page. The setup prompt currently links to the GitHub guide. Once the website's canonical guide is real and checked, update that destination in the same integration. Do not ship a placeholder domain or a PR-branch URL as the ordinary setup destination.

The operational interface remains the existing installer and CLI. This contribution does not require a new MCP server, WebMCP surface, or copied instruction packet. A docs-assistant entry or footer is part of the website integration and must not imply that a cloud-only conversation can operate the reader's Windows machine.

## Publication and verification boundaries

At actual production publication, give these ordinary public pages self-canonical URLs and include them in the intended navigation, sitemap, and search discovery. Keep draft and preview deployments `noindex`; verify that policy on the deployed preview rather than inferring it from source. Do not invent a domain, Search Console property, FAQ rich-result promise, or deployed status in this candidate.

Integration is complete when the selected renderer preserves links and FAQ IDs, page titles and descriptions appear once, the intended pages are reachable, draft/production indexing intent is correct, and desktop/mobile reading and keyboard navigation work. Run a fresh small-model link handoff against the actual guide destination and inspect whether it finds prerequisites, local steps, boundaries, and completion evidence without an extra briefing packet.

Markdown/link checks, a rendered website, a successful Windows installation, unattended Windows lifecycle behavior, and a real consumer tool call are distinct evidence. This documentation candidate supplies source content and integration intent. It must not be reported as proof of the remaining surfaces.
