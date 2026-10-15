---
name: security-review
description: Review security risks, trust boundaries, and unsafe defaults — concrete attack paths only. Use when reviewing security posture or assessing risk before release.
---

# Security Review

Review the diff for exploitable security failures. Report only findings with a concrete attack path, trust-boundary failure, or unsafe default — the Scope buckets below are where attack paths hide, not a checklist to sweep.

## Scope

### 1. Trust boundaries and access control

- auth and trust boundaries
- authorization gaps between clients, sessions, and operations
- endpoint exposure and listener defaults

### 2. Transport and encryption

- transport security (HTTP vs HTTPS, WS vs WSS)
- sensitive payloads traversing insecure channels
- key/secret handling: env-based sourcing, redacted logs, no plaintext persistence

### 3. Execution boundaries

- path boundary enforcement for file operations
- path traversal and escaping project roots
- shell/command execution safety
- queries or commands built by string concatenation instead of parameterization
- dynamic operations without an explicit allowlist
- destructive operations without appropriate guards

### 4. Protocol abuse and resource exhaustion

- malformed payload handling and schema validation
- queue flooding, oversized input, replayable requests
- timeout/retry/cancel consistency
- unbounded work, logs, or memory growth

### 5. Secret exposure

- secrets in logs, errors, traces, or test fixtures
- error messages exposing tokens, paths, or private context

### 6. Defaults and dependencies

- config defaults creating insecure behavior
- unsafe opt-out flags or weak default modes
- broad bypass options that disable enforcement when a narrower exception would do
- unpinned or known-vulnerable dependencies

## Evidence threshold

Only report findings with a concrete attack path, trust-boundary failure, or unsafe default. No speculative recommendations without a plausible abuse path.

## Workflow

1. Map entry points and trust boundaries in the diff; flag pre-existing code only where the change newly makes it reachable.
2. Classify each: local-only, authenticated, remote-accessible, privileged.
3. Check validation, authorization, safe defaults at each boundary. For large audits, fan out **fast-tier** readers — one per boundary or subsystem — to collect raw candidates. Verify each against the code before reporting.
4. Identify exploitable paths (read, write, execute, network, persist).
5. Report each exploitable path found.

## Output

Report each attack path in the review report shape from `principles`: **Where** lists the affected files, **Why** the attack or failure path and who can reach it, and **Instead** the fix and a test that would prove it. Severity follows reachability: **critical** is reachable by remote unauthenticated input, **major** needs authentication or the same network, **minor** needs local access or is defense-in-depth.

- Reject: "The WebSocket uses WS not WSS — should be encrypted." (no reachable attack path)
- Report, as critical: **Why:** `server.ts:42` binds `0.0.0.0` with `auth:false` by default, so any LAN host can call `/exec` and run shell commands (unauthenticated network → execute).

Findings `none` is a valid result.

## See also

- `review`, which runs this review on a branch beside the others
- `principles` for the review report an attack path is written in

## Red flags

- Fear-driven recommendations without concrete attack paths
- Policy-heavy rewrites instead of minimal hardening
- Treating hypothetical deployment models as current vulnerabilities
- Security advice that is not actionable or testable
