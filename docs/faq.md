# Frequently asked questions

TunnelTend tends the local work around your MCP tunnels. These answers explain where it helps, what it owns, and what you can expect from the current preview.

Looking for your first connection? [Start with the setup guide](getting-started.md). Looking for a particular command? Use the [CLI reference](cli-reference.md).

## Fit and relationships

<h3 id="what-tunneltend-does">What does TunnelTend actually do?</h3>

It remembers your registered MCP services and manages their local lifecycle: startup, the official tunnel connection, health observations, bounded recovery, source-change restarts, and verified official-client updates. It is for Windows users who want those routines to continue without repeatedly assembling them by hand.

You bring a working MCP service and the required OpenAI access. TunnelTend supplies the local operating policy. [See where each part fits](user-guide.md#where-tunneltend-fits).

<h3 id="openai-relationship">Is this an OpenAI product?</h3>

No. TunnelTend is an independent Wolfsblvt Works project. It is not affiliated with, endorsed by, or supported by OpenAI.

It uses OpenAI's official `tunnel-client` as a separate dependency. OpenAI owns that client's protocol, hosted infrastructure, and access requirements; TunnelTend owns the local management around it.

<h3 id="official-client-alone">Why not just use the official tunnel client?</h3>

You can. The official client already connects MCP services, runs detached runtimes, and provides runtime inspection and control. If that is enough for your setup, TunnelTend is optional.

TunnelTend adds remembered service intent, current-user Windows automation, bounded watchdog recovery, source watching, and verified client maintenance. The distinction is ongoing local care, not exclusive access to tunnels. [Read the official client's guide](https://github.com/openai/tunnel-client#readme) or [compare the responsibilities](user-guide.md#where-tunneltend-fits).

<h3 id="existing-mcp-service">Do I need an MCP service already?</h3>

Yes. TunnelTend can register a project, an explicit command, or an HTTP MCP endpoint, but the service still needs to be runnable with its own dependencies and configuration. It does not turn an arbitrary project or web API into an MCP server.

Project discovery helps find a launch target. It refuses an ambiguous choice instead of guessing which program you meant. [Choose a registration method](registration.md).

<h3 id="local-or-hosted">Is TunnelTend a hosting service?</h3>

No. TunnelTend runs on your computer. It manages locally launched services or connects the official client to a registered HTTP MCP endpoint; it does not provide hosting. There is no TunnelTend cloud account, hosted dashboard, or central TunnelTend control plane.

If you need availability independent of your desktop, use a suitable always-on host and operating model. TunnelTend does not make a sleeping or powered-off PC serve requests. [See the Windows session boundary](#windows-session).

<h3 id="platform-support">Does it work on macOS or Linux?</h3>

The supported setup is Windows 11 with PowerShell 7.4 or newer. Installation, process handling, and unattended automation are Windows-first. This preview does not offer a supported macOS or Linux installation.

The official client's own platform support is a separate matter. [Check TunnelTend's prerequisites](getting-started.md#before-installation).

<h3 id="preview-status">Is it ready for unattended production use?</h3>

It is a source preview with no published release yet. The implementation is available to inspect and try, but the full Windows lifecycle qualification remains incomplete.

A successful build or green CI does not establish behavior across real sign-in, sleep/resume, recovery, and remote MCP use. The [release checklist](release-checklist.md) names the evidence needed before a public release.

## Access and trust

<h3 id="openai-access">Which OpenAI products and accounts can use it?</h3>

TunnelTend uses OpenAI's Secure MCP Tunnel route. OpenAI documents consumers including ChatGPT, Codex, the Responses API, and AgentKit; actual availability, organization or workspace scope, and permissions are controlled by OpenAI.

Installing TunnelTend does not grant tunnel access or configure a consumer automatically. Start with the [OpenAI prerequisites in the setup guide](getting-started.md#prepare-your-openai-tunnel), then follow the [current official guide](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels) for your consumer. We do not assume that a particular subscription includes access.

<h3 id="network-exposure">Do I have to expose my MCP server publicly?</h3>

The official secure-tunnel route connects a private or local MCP service through OpenAI's infrastructure, so a directly public MCP endpoint is not required. TunnelTend does not ask you to configure router port forwarding.

Your network must still allow the official client's connection. A tunnel also does not change the listening address or authentication of an HTTP service you already run. [OpenAI's network and deployment guidance](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels) owns those upstream requirements.

<h3 id="data-and-credentials">What stays on my computer, and where do keys go?</h3>

TunnelTend stores service definitions, operating policy, observations, logs, and client backups locally. It has no central TunnelTend telemetry service. MCP requests and responses still travel through the official client and OpenAI's infrastructure.

TunnelTend stores credential references such as `env:CONTROL_PLANE_API_KEY` or `file:C:\secure\runtime-key.txt`, not raw runtime keys in its registry. The referenced secret still exists in your environment or file and is resolved when needed. Your account permissions and local file protection matter. [Read privacy and data](PRIVACY-AND-DATA.md) and [credential setup](getting-started.md#prepare-your-openai-tunnel).

<h3 id="agent-setup">Can my local coding agent set it up?</h3>

Yes, if it can work on your Windows computer. Give it the [setup guide](getting-started.md#install-with-a-local-agent), the service you want registered, and your chosen policy. It uses the same installer and CLI as you do; there is no separate agent-only installation mechanism.

The agent should work with credential references and report what it actually observed. A cloud-only chat without access to your computer cannot perform the local installation or prove that a remote tool call succeeds.

## Automation and control

<h3 id="windows-session">What happens when I close the terminal, sign out, or sleep?</h3>

Closing the setup terminal is compatible with unattended operation: TunnelTend uses current-user Windows Scheduled Tasks and detached runtimes. Eligible service startup happens when you sign in, not as a system service before anyone logs in.

Do not rely on availability while signed out, asleep, disconnected, or powered off. The default task configuration does not promise to wake the computer. A new sign-in establishes a new session; sleep/resume behavior still needs the preview's Windows qualification. [Read the automation model](OPERATIONS.md#automation-modes).

<h3 id="stopping-services">Will it restart something I deliberately stopped?</h3>

An ordinary `service stop` saves a durable stopped state. The watchdog and later sign-in startup respect that state. A start or restart command explicitly restores running intent.

`service stop --session-only` is a temporary alternative. The watchdog respects it, but a new sign-in or explicit manual start, restart, or applying manual reconciliation can resume the service. Choose a durable stop when that is what you mean. [See the exact commands and effects](OPERATIONS.md#manual-intent).

<h3 id="source-and-app-updates">Will it rebuild my project or pull new code?</h3>

No automatic build or pull is inferred. Project-path registration enables source watching by default, which can restart the service after stable local file changes. Use `--no-source-watch` if you want manual restarts.

Application-update commands are a separate, explicit opt-in. In this preview, maintenance can run an enabled update command even for a stopped or disabled registration; stopping the service does not pause that update policy. [Read the source and application-update rules](OPERATIONS.md#source-watching-and-application-updates) before enabling it.

<h3 id="automatic-updates">What gets updated automatically?</h3>

The recommended policy checks for updates to OpenAI's official tunnel client. TunnelTend selects the official Windows asset, verifies its published digest, stages and checks it before replacement, and keeps a backup for rollback. Automatic client updates can be disabled.

This is not an automatic updater for TunnelTend itself or for your project dependencies. Verification checks provenance and expected capabilities; it does not guarantee that every upstream change works with every service. [Read the update and rollback behavior](OPERATIONS.md#update-operation).

<h3 id="recovery-limits">What if a service keeps failing?</h3>

The watchdog limits attempts within a rolling recovery window and uses backoff. Exhaustion is visible in diagnostics; later attempts can become eligible as older attempts leave the window. One failing service does not prevent the rest of the fleet from being considered.

Inspect `doctor` and the relevant logs before applying a repair. `--force` does not authorize killing an unrelated process or bypassing credential, scope, or download checks. [Follow the failure diagnosis route](troubleshooting.md#recovery-has-stopped).

<h3 id="health-and-readiness">Does “healthy” mean ChatGPT can use my tools?</h3>

No single local status proves that. TunnelTend can inspect the host, official runtime, and configured health and readiness endpoints. Health and readiness are separate observations, and an unconfigured probe is not an MCP test.

Consumer access also depends on upstream scope, credentials, connector configuration, and the service's actual MCP behavior. Complete setup with a real, harmless tool call from your intended consumer. [See the verification steps](getting-started.md#verify-the-whole-connection).

<h3 id="existing-supervision">Can I keep my existing aliases or supervisor?</h3>

You can deliberately import an existing official alias. Import makes its target part of TunnelTend's managed registry; it is not a reason to run two supervisors against the same runtime. If you already have a service manager or script that reliably handles the lifecycle you need, keeping it may be simpler.

Choose one owner for a managed process or runtime. Review an alias before importing or replacing its definition, and stop an old manually managed runtime before starting a competing one. [See alias admission and import](registration.md#import-an-existing-official-alias).

## Cost and leaving

<h3 id="cost-and-license">What does it cost, and what is the license?</h3>

TunnelTend is available as source under [AGPL-3.0-only](../LICENSE). There is no TunnelTend subscription or account required by this local application. Read the license for the terms that apply to your use and changes.

The official OpenAI client is a separate work under its own license. OpenAI access and any provider charges are separate from TunnelTend; this project does not promise a free upstream service.

<h3 id="leaving-tunneltend">Can I remove it without losing my projects?</h3>

Yes. Normal uninstall attempts to stop registered services and removes TunnelTend's tasks, program payload, and managed PATH entry while preserving local state. The default official client inside the installation is removed with the program files; an external client remains untouched. Your project source and remote OpenAI tunnel objects are not deleted.

Optional switches can leave runtimes running or deliberately purge the selected state. Inspect uninstall warnings rather than assuming every runtime stopped. [Use the uninstall guide](getting-started.md#uninstall-or-preserve-state) to choose the result you want.
