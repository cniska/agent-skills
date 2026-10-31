---
name: security-review
description: Review a change for security failures an attacker can reach, finding broken trust boundaries, unsafe execution, exposed secrets and insecure defaults, each with its attack path. Use when reviewing any diff, or when assessing a system's security before a release.
---

# Security Review

Review the diff for security failures someone can exploit. The Scope buckets below are where attack paths hide, not a checklist to sweep.

## Scope

### 1. Trust boundaries and access control

- auth and trust boundaries
- authorization gaps between clients, sessions and operations
- endpoint exposure and listener defaults

### 2. Transport and encryption

- transport security (HTTP vs HTTPS, WS vs WSS)
- sensitive payloads crossing an insecure channel
- keys and secrets sourced from the environment and stored encrypted

### 3. Execution boundaries

- path boundaries on file operations, and traversal out of the project root
- shell and command execution
- queries or commands built by string concatenation where parameterization is available
- dynamic operations with no explicit allowlist
- destructive operations with no guard

### 4. Protocol abuse and resource exhaustion

- malformed payloads and schema validation
- queue flooding, oversized input and replayable requests
- inconsistent timeout, retry and cancel handling
- unbounded work, logs or memory growth

### 5. Secret exposure

- secrets in logs, errors, traces or test fixtures
- error messages that expose tokens, paths or private context

### 6. Defaults and dependencies

- config defaults that make behavior insecure
- unsafe opt-out flags or weak default modes
- a broad bypass that disables enforcement where a narrower exception would do
- unpinned or known-vulnerable dependencies

## Evidence threshold

Report only a concrete attack path, trust-boundary failure or unsafe default, and say who can reach it. A recommendation with no plausible abuse path is no finding.

## Workflow

1. Map the entry points and trust boundaries in the diff. Sort a hole that was there before the change as the review report in `principles` says.
2. Classify each entry point as local-only, authenticated, remote-accessible or privileged.
3. Check validation, authorization and safe defaults at each boundary. When an audit spans more than one pass can cover and you can start agents, start a fast-tier reader per boundary or subsystem to gather candidates, then check each against the code yourself.
4. Find the exploitable paths: read, write, execute, network and persist.
5. Report each exploitable path.

## Output

Report each attack path in the review report shape from `principles`: **Where** lists the affected files, **Why** the attack or failure path and who can reach it, and **Instead** the fix and a test that would prove it. Severity follows reachability: **critical** is reachable by remote unauthenticated input, **major** needs authentication or the same network, **minor** needs local access or is defense-in-depth.

- Reject: "The WebSocket uses WS not WSS — should be encrypted." (no reachable attack path)
- Report, as critical: **Why:** `server.ts:42` binds `0.0.0.0` with `auth:false` by default, so any LAN host can call `/exec` and run shell commands (unauthenticated network → execute).

No finding is a valid result.
