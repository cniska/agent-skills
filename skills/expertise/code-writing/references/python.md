# Python

## Toolchain

These tools are suggestions for a new project; a project's own tools win. Where a shared project template carries the reviewed tool config, it is inherited, not authored, and a deviation is a decision with its reason.

- `uv` as the package manager: `uv sync --locked`, `uv run`, `uv add`, `uv lock`. Whatever the package manager, the lockfile is committed and CI installs from it.
- `ruff` lints at `select = ["ALL"]` and formats, its config turning off only what the skill's rule on flagged code allows; `mypy --strict` type checks every file, tests typed like the rest.
- `mise` pins python and uv and wraps the gates as tasks; `prek` runs them as git hooks.
- Resolve and publish through one configured package index; with uv, CI authenticates to it with short-lived OIDC credentials read from `UV_INDEX_<NAME>_USERNAME` / `UV_INDEX_<NAME>_PASSWORD`.

Modern means: the interpreter the project pins as the floor, PEP 695 `type` aliases and `def f[T]()` generics, `X | None` over `Optional`, built-in generics over `typing.List`, `StrEnum` for wire values, `datetime.UTC`, `pathlib` over `os.path`, `tomllib`, `asyncio.TaskGroup` over bare `gather`, `Self` and `@override`.

## Stack defaults

Defaults for a new project; the libraries already in use win.

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

- `__init__.py` re-exports the package's public surface and nothing else.
- Underscore-prefix internal functions; it is the only access signal Python gives.
- Import order is the formatter's or linter's job, never hand-maintained.

## Typing

- Type every public function's parameters and return.
- `Protocol` for structural interfaces, especially a test double that satisfies a boundary without inheriting; `ABC` only when shared implementation lives in the base.
- `StrEnum` when a value crosses a wire or lands in a file; `Literal` when it stays in-process.
- `from __future__ import annotations` only in a module that needs a forward reference.
- Write a type wherever one can be written, and parse a value into it rather than typing it `Any`.

## Errors

- One hierarchy per package, rooted at `<Package>Error`; callers catch the base to mean "this package failed" and a subclass for something specific.
- `raise ... from exc` whenever you re-raise.
- `json.load` turns `null` into `None` and leaves an absent key absent, and `dict.get` makes the two look the same; read a key whose absence matters with an explicit `in`.
- Lowercase messages, no trailing period, naming the value that broke it and never a credential.
- `except Exception` only at a top-level boundary (a CLI `main`, a request handler, a Lambda entry), where it logs and converts. In a loop over many items, a per-item failure is recorded and skipped.

## Logging

- `logger = logging.getLogger(__name__)` at module scope; never the root logger or `logging.info(...)`.
- Lazy `%s` interpolation, not f-strings.
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

Through the repo's mise tasks (`mise run lint`, `mise run test`) where they exist; otherwise the project's own format, lint, type and test commands, such as `uv run ruff format --check .`, `uv run ruff check .`, `uv run mypy`, `uv run pytest`. Fix the code rather than writing `noqa` or `type: ignore` in source, and turn a rule off in the project's tool config only as the skill's rule on flagged code allows.

## Setup

A starting point for a project with no template of its own; where a template exists, copy its config rather than writing an equivalent.

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

[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = ["--import-mode=importlib"]
asyncio_mode = "auto"
asyncio_default_fixture_loop_scope = "function"
```

- `requires-python` is a narrow range so a new interpreter is an explicit decision; dependencies carry a lower bound and a major cap, and ruff, being pre-1.0, a minor cap.
- ruff: `line-length = 120`, `select = ["ALL"]`, with `D` off, since its fix is a docstring no comments forbids, and `COM812` off, since `ruff format` owns trailing commas and rewrites them; in `tests/`, `S101` off for the plain `assert` above and `PLR2004` off for wire values pinned as literals. Every other rule stays on. Adjust `extend-exclude` and `known-first-party` locally.
- `prek` runs `ruff check --fix` and `ruff format` on commit, `uv lock` when a manifest changes, and mypy plus the import linters at the `manual` stage. An agent harness also runs `ruff format` on each written file.
