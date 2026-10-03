# Threshold Carrier: TunnelTend durable identity, icon, and open-source presentation

## Seat and mode

This is a live owner co-design between Wolf and Nyxara. It is not an implementation assignment, a naming lottery, or permission to replace settled product meaning with generic infrastructure branding.

The implementation name is **TunnelTend** and the command/repository slug is **`tunneltend`**. Treat that as the default to defend. A rename is allowed only when the session produces a clearly stronger durable identity and explains the migration cost honestly.

## Source package

Read before proposing anything:

1. Repository root `AGENTS.md`.
2. `README.md`.
3. `docs/product-model.md`.
4. `docs/ARCHITECTURE.md`.
5. `docs/OPERATIONS.md`.
6. `docs/branding.md`.
7. `docs/SECURITY.md`.
8. `docs/cli-reference.md`.

The product is an unofficial, local-first desired-state manager for OpenAI's official tunnel client. Users register MCP services once; TunnelTend owns routine startup, tunnel connection, health observation, recovery, source-change restarts, safe client updates, and Windows automation afterward.

## Product truth to preserve

The identity must communicate most of these truths without becoming an enterprise word salad:

- Register once, then stop babysitting it.
- One or many MCP services are managed as durable desired state.
- Tunnels are kept available automatically.
- Recovery is cautious, bounded, and observable.
- It is small, local-first, open source, and agent-friendly.
- It manages the official client; it is not itself an official OpenAI product.
- `status`, `health`, and `doctor` tell the truth; mutation is explicit.
- The emotional promise is dependable tending, not aggressive orchestration theater.

Avoid branding that implies a hosted platform, Kubernetes clone, VPN product, generic reverse proxy, OpenAI endorsement, or security guarantee.

## Questions the session must resolve

### 1. Durable name

Return a real owner fork, not forty names without judgment:

- **Keep TunnelTend** and strengthen its story.
- **Rename** only if one alternative is materially better.
- At most two serious rename candidates may survive to the owner decision.

For each surviving direction, cover:

- Spoken and written feel.
- CLI and repository slug.
- Searchability and likely collision risk.
- Fit for a small local daemon/manager rather than a cloud platform.
- How naturally it supports verbs, service names, logs, and documentation.
- Migration cost from `tunneltend`.
- Trademark/domain caveats requiring later legal confirmation.

Do not promise legal clearance. Perform bounded web/repository/package-name research and cite it.

### 2. Identity concept

Define one coherent visual metaphor. Candidate territory may include tending, keeping, lighthouses, signal paths, knots, guarded passages, living roots, or another original direction, but do not mash several metaphors into a logo casserole.

The concept must work for:

- 16 px favicon.
- 24 px CLI/docs mark.
- 64–128 px application/repository avatar.
- Monochrome terminal and print use.
- Dark and light backgrounds.
- A future tray application without requiring one now.

### 3. Icon and SVG system

Return an implementation-ready icon brief and candidate SVG source, but keep generated artwork clearly marked as a candidate until Wolf approves it.

Required constraints:

- Original geometry, no OpenAI logo imitation.
- 24×24 canonical viewBox.
- Lucide-adjacent construction: 2 px strokes, rounded caps and joins, centered geometry, no incidental fill unless the concept genuinely needs it.
- A simplified solid or reduced-stroke favicon variant where necessary.
- Accessible contrast on dark and light surfaces.
- No tiny decorative details that dissolve below 24 px.
- No lock/shield cliché unless security is genuinely the primary promise. It is not.

Return:

- Primary mark SVG.
- Monochrome SVG.
- Favicon simplification.
- Geometry rationale.
- Clear-space and minimum-size guidance.
- What must never be changed.

### 4. Palette and typography

Define a small palette with semantic roles, not a bucket of attractive hex values:

- Dark canvas.
- Light canvas.
- Primary signal/accent.
- Healthy, degraded, failed, and neutral operational states.
- Text and muted text.

Check contrast. Do not let healthy green and brand color become indistinguishable.

Prefer system/OSS-friendly typography. The CLI must remain typography-independent.

### 5. Voice and product language

Define wording for:

- One-line description.
- README hero.
- Repository description.
- Release tagline.
- `doctor`, recovery, and failure messages.
- Unofficial-project disclaimer.

The voice should be calm, capable, and human. It may have a little personality, but operational errors are not stand-up comedy while somebody's tooling is down.

### 6. Open-source presentation

Design the first public impression:

- README opening sequence.
- Installation promise.
- “Ask your agent to install it” prompt.
- Three-command human quick start.
- Architecture diagram direction.
- Screenshots or terminal recording worth producing.
- GitHub social preview concept.
- Release notes framing.

The project is open source; do not invent a commercial funnel or hosted service roadmap unless it follows naturally from the product and is explicitly marked speculative.

## Required output

Return one co-design package with:

1. **Meaning recap**: the product promise in plain language.
2. **Recommended direction**: name, identity metaphor, palette, voice, and why they belong together.
3. **Owner forks**: only the decisions where Wolf's taste can still materially improve the result.
4. **Rejected directions**: brief and useful, so dead ideas stay dead.
5. **Candidate assets**: SVG source and rendering notes.
6. **README opening candidate**: hero through first quick-start block.
7. **Brand specification**: compact enough to live in `docs/branding.md`.
8. **Implementation consequence list**: exact files, identifiers, task names, package names, and migration work affected by any rename.
9. **Research appendix**: cited naming/collision/package/repository findings and unresolved legal checks.

## Owner decisions to bring back

The session must end with a small decision surface, preferably:

- Keep `tunneltend` or adopt one named alternative.
- Choose between at most two visual directions.
- Confirm the primary accent family.
- Confirm whether the tone leans more “quiet caretaker” or “small sharp operator.”

Everything else should arrive as a recommendation, not homework for Wolf.

## Boundaries

- Do not modify the repository during this co-design session.
- Do not publish packages, domains, repositories, or social accounts.
- Do not present generated SVG as final approval.
- Do not borrow protected marks or imply OpenAI affiliation.
- Do not erase the agent-install story or local-first operational meaning in pursuit of a prettier logo.

## Return carrier

Return the complete package into the originating room. Include copy-ready decisions and SVG source. Clearly label what is recommended, what remains an owner fork, and what requires external legal or availability verification.
