# Python

## Toolchain

Tool config is inherited, not authored: a shared project template carries the reviewed ruff, mypy, pytest, coverage, uv and mise setup. A project outside the template copies its config with its reasons, since the ignore list is a standard other repos are lined up on. A deviation is a decision, commented on the line that deviates.

- `uv` is the only package manager: `uv sync --locked`, `uv run`, `uv add`, `uv lock`. Never `pip install` into a project, and never poetry, pipenv or conda. The lockfile is committed and CI installs with `--locked`.
- `ruff` lints at `select = ["ALL"]` and formats; each ignore carries its reason. `mypy --strict`, with tests relaxed by an override, never excluded.
- `mise` pins python and uv and wraps the gates as tasks; `prek` runs them as git hooks.
- Resolve and publish only through the one configured package index; CI authenticates to it with short-lived OIDC credentials read from `UV_INDEX_<NAME>_USERNAME` / `UV_INDEX_<NAME>_PASSWORD`.

Modern means: the interpreter the template pins as the floor, PEP 695 `type` aliases and `def f[T]()` generics, `X | None` over `Optional`, built-in generics over `typing.List`, `StrEnum` for wire values, `datetime.UTC`, `pathlib` over `os.path`, `tomllib`, `asyncio.TaskGroup` over bare `gather`, `Self` and `@override`.

## Stack defaults

| Need | Default | Heavier option (only when justified) |
|---|---|---|
| Tests | `pytest` + `pytest-mock` | `pytest-asyncio` when the code under test is async |
| HTTP client | `httpx` | — |
| Validation / settings | `dataclasses` for internal shapes | `pydantic` 2 at I/O boundaries where coercion and error messages earn it |
| CLI | `argparse` | `typer` only for a multi-command tool with real UX needs |
| Config files | `tomllib` | — |
| Date/time | `datetime` with `datetime.UTC`, `zoneinfo` for zones | — |
| Logging | stdlib `logging` | `python-json-logger` for structured output in a deployed service |
| AWS | `boto3` | — |
| Retry | a small explicit loop | `tenacity` when policy gets genuinely complex |

## Modules

- Module docstring at the top of every file: what the module is for, and any invariant a reader needs.
- `__init__.py` re-exports the package's public surface and nothing else.
- Underscore-prefix internal functions; it is the only access signal Python gives.
- Import order is ruff's job (`I`), never hand-maintained.

## Typing

- Type every public function's parameters and return.
- `Protocol` for structural interfaces, especially a test double that satisfies a boundary without inheriting; `ABC` only when shared implementation lives in the base.
- `StrEnum` when a value crosses a wire or lands in a file; `Literal` when it stays in-process.
- `from __future__ import annotations` only in a module that needs a forward reference.
- No `Any` without a comment saying why the type cannot be known.

## Errors

- One hierarchy per package, rooted at `<Package>Error`; callers catch the base to mean "this package failed" and a subclass for something specific.
- `raise ... from exc` whenever you re-raise.
- Lowercase messages, no trailing period, naming the value that broke it and never a credential.
- `except Exception` only at a top-level boundary (a CLI `main`, a request handler, a Lambda entry), where it logs and converts. In a loop over many items, a per-item failure is recorded and skipped.

## Logging

- `logger = logging.getLogger(__name__)` at module scope; never the root logger or `logging.info(...)`.
- Lazy `%s` interpolation, not f-strings; ruff's `G` rules enforce it.
- Handlers configured once, in the entry point; a library never calls `basicConfig`.
- `logger.exception(...)` inside an `except` block. `print` is for a CLI's output only.

## Async

- `asyncio.run(main())` at the entry point, once.
- `asyncio.TaskGroup` over `gather`, `except*` for its branches, `asyncio.timeout` for deadlines.
- A function is `async` only if it awaits.

## Testing

- `tests/` mirrors the package tree as `test_<module>.py`; fixtures in `conftest.py` at the narrowest scope that covers their users.
- `class Test<Subject>:` per unit, no `unittest.TestCase` in new code; names `test_<subject>_<behavior>`.
- Plain `assert`; `@pytest.mark.parametrize` with `ids=`; `pytest.raises(SomeError, match="...")`, never `raises(Exception)`.
- Fixtures as `@pytest.fixture(name="thing")` on `def fixture_thing()`. Prefer `tmp_path`, `monkeypatch`, `capsys`, `caplog` and `mocker` over hand-rolled temp dirs, `os.environ` mutation or manual patching.
- A hermetic gate needs no credential: a module whose heavy dependency is imported inside the function that needs it keeps its pure logic testable with the standard library alone.

## Verification

Through the repo's mise tasks (`mise run lint`, `mise run test`) where they exist; otherwise `uv run ruff format --check .`, `uv run ruff check .`, `uv run mypy`, `uv run pytest`. Silencing a lint is a change to the project's standards and carries the same reason comment as any ignore.

## Red flags

- A hand-written ruff, mypy or pytest config in a repo that could have taken the template's
- `pip install`, `poetry` or `requirements.txt` in a project that has `uv.lock`
- `typing.List` / `Dict` / `Optional` / `Union` in new code
- A public function with no annotations, or an `Any` with no comment
- `except Exception: pass`, a bare `except:`, or `raise` inside an `except` without `from`
- f-strings inside a `logger.*` call, or `logging.basicConfig` in a library
- A `noqa`, `type: ignore` or ruff ignore with no reason comment
- `datetime.now()` without a timezone
- A mutable default argument

## Setup

Copy the template's config rather than writing an equivalent; match an existing project's pins rather than upgrading as a side effect.

```toml
[project]
name = "example-service"
version = "0.1.0"
requires-python = ">=3.12,<3.13"
dependencies = ["httpx>=0.28,<0.29"]

[dependency-groups]
dev = ["mypy>=1.19", "pytest>=9", "pytest-mock>=3.15", "ruff>=0.15,<0.16"]

[[tool.uv.index]]
name = "internal"
url = "https://packages.example.com/python/simple/"
publish-url = "https://packages.example.com/python/upload/"
default = true

[tool.mypy]
files = "."
exclude_gitignore = true
strict = true
show_error_codes = true
explicit_package_bases = true

[[tool.mypy.overrides]]
module = ["*.tests.*"]
disallow_untyped_defs = false
warn_return_any = false

[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = ["--import-mode=importlib"]
asyncio_mode = "auto"
asyncio_default_fixture_loop_scope = "function"
```

- `requires-python` is a narrow range so a new interpreter is an explicit decision; dependencies carry a lower bound and a major cap, and ruff, being pre-1.0, a minor cap.
- ruff: `line-length = 120`, `select = ["ALL"]`, `convention = "google"`, whole tools off with a reason (`ARG`, `EM`, `ERA`, `FBT`, `FIX`, `INP`, `PLR`, `TD`), and per-file ignores for `tests/`, `scripts/` and `__init__.py`. Adjust `extend-exclude` and `known-first-party` locally.
- `mise.toml` pins `python`, `uv` and `prek`, with `boot` (`mise install --locked`, `uv sync --locked`, `prek install`), `lint` (`prek run -a --hook-stage manual`) and `test` (`uv run --locked pytest`) tasks.
- `prek` runs `ruff check --fix` and `ruff format` on commit, `uv lock` when a manifest changes, and mypy plus the import linters at the `manual` stage. An agent harness also runs `ruff format` on each written file.
- CI: OIDC to the index (`id-token: write`), `astral-sh/setup-uv` with `enable-cache: true` and `prune-cache: false`, `actions/setup-python` with `python-version-file: pyproject.toml`, `uv sync --locked`, then `mise run lint` and `mise run test`. Third-party actions are pinned to a full commit SHA.
