# TunnelTend Vision

## Meaning

TunnelTend should make private MCP connectivity feel like a configured local capability rather than a process the operator must repeatedly remember, launch, diagnose, and repair. This Vision preserves the full owner-selected destination: register a service once, then let a small local manager keep it available, current, observable, and recoverable without becoming a hosted platform or hiding consequential actions.

Status: Provisional

## Origin

TunnelTend began with a concrete annoyance in October 2026: the official OpenAI tunnel client was releasing frequently, while a manually downloaded Windows copy had fallen several versions behind and offered no trusted self-update route. The first idea was a safe updater. The conversation exposed the larger missing product: updates were only one part of the repeated manual work around starting, reconnecting, observing, and recovering several local MCP tunnels.

Wolf selected the wider direction and the name `tunneltend`: a small local tool that remembers registered services and tends them automatically.

## Product promise

A user should be able to point TunnelTend at an MCP service once and receive a durable local outcome:

- the service and official tunnel runtime start when expected;
- current desired state and deliberate manual stops are respected;
- unhealthy or missing runtimes are detected and recovered safely;
- source changes can restart the registered service when explicitly configured;
- official-client updates are verified, transactional, and recoverable;
- one or many services remain understandable through status, health, and doctor output; and
- humans and local coding agents can install and operate it without hand-writing internal state.

## Intended experience

TunnelTend should feel like a quiet caretaker with sharp operational boundaries:

- autonomous by default, not merely automatable;
- explicit about facts, plans, and mutations;
- conservative around secrets, process termination, updates, and ambiguity;
- compact enough to install from a command line;
- inspectable enough that a local agent can reason about it; and
- calm when degraded, with actionable output instead of magical self-repair claims.

The operator should not become the recurring scheduler, restart button, or integration glue.

## Product character

TunnelTend is local-first and Windows-first. It manages the official client rather than replacing the protocol. It is flexible through registered service definitions, not through a generic orchestration platform. It should remain useful for one service and coherent for many.

The project is open source. Agent-native setup is a first-class use case, but the human CLI remains complete and understandable on its own.

## Boundaries

TunnelTend is not:

- an official OpenAI product;
- a hosted tunnel control plane;
- a general Windows service manager;
- a deployment system;
- a source-control or dependency updater;
- a secret manager; or
- a promise that every unhealthy dependency can be repaired automatically.

These boundaries protect the useful product from expanding into a local Kubernetes tribute act.

## Complete destination

The complete selected destination is a trustworthy local manager that can register, inspect, start, stop, reconcile, update, and recover an MCP tunnel fleet with minimal ongoing operator attention. Source publication, Windows qualification, branding, and the first release are delivery steps toward that destination. They are not substitutes for the actual lived operation.
