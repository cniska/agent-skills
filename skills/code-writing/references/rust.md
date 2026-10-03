# Rust

## Toolchain

Edition 2024 for new code. `rustfmt` and `clippy` from an exact pinned version in `rust-toolchain.toml` (`1.xx.y`; a bare `stable` resolves to whatever each machine has, so machines and CI drift), `cargo-deny` for dependencies, and the `xb`/`xt`/`xc`/`xd` cargo aliases. No `unsafe` without a `// SAFETY:` comment.

Modern means: native `async fn` in traits (stable since 1.75), `LazyLock` / `OnceLock` over `lazy_static` / `ctor`, `let-else` and `if let` chains where they clarify intent.

## Stack defaults

| Need | Default | Heavier option (only when justified) |
|---|---|---|
| Errors | `thiserror` 2 | `anyhow` only in a binary's top-of-stack code, never across a library boundary |
| HTTP (inbound + outbound) | `hyper` 1 directly | `axum` 0.8 for typed routing on a complex REST surface; `reqwest` 0.12 when JSON/streaming ergonomics save real code |
| CLI | `clap` 4 derive | — |
| Serialization | `serde` 1 derive + `serde_json` 1, `#[serde(deny_unknown_fields)]` on shapes you own | — |
| Date/time | `std::time` | `chrono` only for real date/timezone math |
| Lazy static state | `std::sync::LazyLock` / `OnceLock` | — |
| Async traits | native `async fn` in traits | `async-trait` 0.1 only when `dyn Trait` object safety is required |
| Parameterized tests | `rstest` | — |

`tokio` enables only the features used (`rt-multi-thread`, `net`, `time`, `macros`, `signal`), never `full` in a library crate; `tracing-subscriber` likewise, since its defaults pull a large tree. serde reads a missing `Option<T>` field as `None`, so an absent key and `null` are one value unless the shape says otherwise; decide which the format means and pin it with a test. If `hyper` is in the tree, don't add `reqwest`; if `std::time` covers the work, don't add `chrono`.

## Module structure

- An area is a directory one level under `src/`, whose `mod.rs` declares its files and nothing else. Both layouts are idiomatic — `foo/mod.rs`, or `foo.rs` beside `foo/` — so a crate picks one and holds to it.
- A sub-thing spanning several files takes a name prefix (`lfs.rs`, `lfs_handler.rs`, `lfs_forward.rs`) rather than nesting a directory inside an area.
- No `pub use` re-export in `mod.rs`; import a crate item from the file that defines it.
- `mod x;` (no `pub`) for a file nothing outside its area needs. Not a 300-line `lib.rs`.

## Errors

- One error enum per crate, named `<Crate>Error`, with `#[from]` for upstream errors and structured variants where callers match on fields.
- Lowercase `#[error("...")]` messages, each Display roundtrip tested in the file's `#[cfg(test)] mod tests`.
- `Result<T, &'static str>` is fine for in-crate private guards; promote to the enum at module/crate boundaries.

## Logging

Log through the workspace's shared logger crate; in a standalone repo, wrap `tracing` in a local `logger` module so policy lives in one place. Never `use tracing::...` outside the wrapper.

## Types and dispatch

- Type aliases for cheap structural shapes (`pub type Coord = (usize, usize);`). Newtype wrappers only when a custom `Display` or invariant earns it.
- `Default` and `new()` paired; `with_x()` for variants.
- `Display` for human output and `Serialize` for machine output on the same type.
- Enum-of-structs over `Box<dyn Trait>` when the set of implementations is fixed and in-tree: static dispatch, no allocation, exhaustive matching. `Box<dyn Trait>` only when implementations come from outside the crate.
- Spawn sparingly; most request lifecycles don't need `tokio::spawn`.

## Testing

- Integration tests in `tests/<area>.rs`, shared helpers in `tests/utils.rs` referenced as `mod utils;`.
- Test-binary-wide setup through `LazyLock`; `ctor::ctor` only when init must run before any test code.
- Names `test_<subject>_<behavior>`, long and descriptive.
- Multi-line string fixtures aligned with `\` continuation so their structure reads.

## Documentation

A crate published to crates.io carries `///` on every public item and `//!` with a usage example at the top of `lib.rs`. A suppression is `#[expect(lint, reason = "...")]`, which carries its reason without a comment and warns once the lint no longer fires.

## Verification

`cargo fmt --all -- --check`, `cargo xc` (or `cargo clippy --workspace -- -W warnings`), `cargo xt` (or `cargo test --workspace`).

## Red flags

- A `pub fn` returning `Result<T, String>` at a module boundary — promote to `thiserror`
- `anyhow` in a library crate
- `use tracing::{...};` outside the logging wrapper
- `Box<dyn Trait>` for a fixed in-tree set of implementations
- `lazy_static`, `once_cell` or `async-trait` where std or native async traits cover it
- `unwrap()` or `expect()` on a `Result` where the failure mode is reachable
- `#[allow(...)]` where `#[expect(..., reason = "...")]` fits, an advisory ignore in `deny.toml` without its reason, or `unsafe` without `// SAFETY:`

## Setup

Versions are starting points; when a workspace `Cargo.toml` or `rust-toolchain.toml` is present, use what's already pinned.

- `rust-toolchain.toml` pins a stable channel. Components `rustfmt`, `clippy`; profile `minimal`.
- `rustfmt.toml`: `edition = "2024"` for new repos, the workspace's edition otherwise; `max_width = 100`, `use_field_init_shorthand = true`.
- `deny.toml`: license allowlist, RustSec denials, `unknown-registry = "deny"`, `unknown-git = "warn"`, no advisory ignores from day one.
- Workspace lints: `unsafe_code = "deny"`, `clippy::all = { level = "warn", priority = -1 }`.
- `.cargo/config.toml` aliases: `xb` (build), `xt` (test), `xc` (clippy), `xd` (doc).
- A `PostToolUse` hook on `Edit|Write` runs `rustfmt "$f"` on each touched `.rs` file, in place rather than with `--check`; `rustfmt` reads the repo's `rustfmt.toml` for its edition, so let-chains format correctly.

Logging wrapper:

```rust
// src/logger.rs
pub use tracing::{debug, error, info, instrument, trace, warn};

pub struct LogGuard { _guard: Option<tracing_appender::non_blocking::WorkerGuard> }

pub fn init() -> LogGuard { /* ... */ }
```

- Every other module imports `use crate::logger::{info, warn, debug};`, or the shared logger crate in a workspace.
- `init` returns a guard held in `main()` so async flushes complete on shutdown.
- `EnvFilter` driven by an `<APP>_LOG` env var. Stderr human format by default; a structured JSON layer for production.
- `#[instrument]` on async handlers wraps the request lifecycle in a span.

Cargo:

- `[workspace.dependencies]` for shared crates; `[workspace.package]` for `version`, `edition`, `license`, `repository`.
- Internal crates declare both `version = "x.y.z"` and `path = "..."`; cargo-deny rejects path-only deps on published crates.
- Publish through CI, never `cargo publish` locally. Conventional Commits and release-please for bumps, with `CHANGELOG.md` `[Unreleased]` updated per change.
