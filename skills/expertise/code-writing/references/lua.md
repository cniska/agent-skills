# Lua

## Toolchain

The project's tools stand. Where it has none, suggest `mise` pinning the interpreter and tools, StyLua to format, selene to lint (luacheck where a project already runs it), the Lua Language Server (LuaLS) to type check from annotations, and busted to test.

- **StyLua formats.** Its `stylua.toml` sets `syntax` to the runtime's dialect, such as `"Lua51"`, so a construct the runtime lacks fails to parse instead of being formatted. `stylua --check .` exits 1 on any unformatted file.
- **selene lints.** `selene.toml` names its `std`; a custom std is `<name>.yml` beside it, YAML that sets `base: lua51` and lists the host's globals under `globals:`, so a misspelled global or one the host never defines is an error. luacheck's `.luacheckrc` does the same with `std`, `globals` (writable) and `read_globals` (read-only).
- **LuaLS carries the types.** `.luarc.json` sets `runtime.version` to the runtime's version and `workspace.library` to the host API's annotation files. `lua-language-server --check .` exits 1 on any diagnostic at Warning or above; `--checklevel=Information` lowers that bar.

Modern means: `local` for every name, a file that returns one module table, LuaLS annotations on every function that crosses a file, and the formatter, linter and type check run on every commit. A runtime pinned to Lua 5.1 keeps all of that; what it lacks is listed under [WoW addons](#wow-addons).

## Stack defaults

For a new project; a library the tree already holds wins.

| Need | Default |
|---|---|
| Interpreter | the version the host embeds; `lua` through `mise` for a standalone program |
| Format | StyLua |
| Lint | selene |
| Types | LuaLS annotations, checked by `lua-language-server --check` |
| Tests | busted, from LuaRocks; a plain Lua script of `assert` calls where LuaRocks is not wanted |

## Types

- **`nil` is the one empty value.** Whatever may be empty on purpose is typed `T?` or `T|nil` in its annotation, and nothing stands in for it: no `false`, `""` or `0` meaning absent. `false` is a boolean, so `if x then` treats it as absent too; where a value may be `false`, test `x ~= nil`.
- **A table holds no `nil` as an element.** Assigning `nil` deletes the key, so a list with a `nil` inside has a hole: `#` may return the index before any hole, `ipairs` stops at the first one, and `unpack` and `table.insert` act on whichever length `#` gave. Keep lists dense with `table.remove`, keep a count beside a sparse table, or key it by id. Count varargs with `select("#", ...)`, which counts trailing `nil`s that `#{...}` drops.
- **Parse at the edge.** Saved data, a host event's arguments, a network message and a config table go through one parser per shape that checks `type()` of every field read and returns a typed table or a coded error. Past it, an annotated `---@class` states what holds, and no code below checks again.
- **Annotate the shape once.** `---@class Name` with `---@field` lines declares a table's shape; `---@param` and `---@return` type each function that crosses a file. Annotations carry the type alone, with no prose after it, since they are the one comment a tool reads.
- **A closed set is a lookup table.** Its members are the keys of one table, annotated as `---@alias Mode "a"|"b"` or `---@enum`, and code dispatches by indexing that table rather than an `if` chain over strings. LuaLS does not prove a dispatch covers every member, so a test iterates the set's table and asserts each member has a handler, and a lookup that misses raises a coded error instead of returning `nil`.
- **Freeze what must not change.** Lua calls `__newindex` only for a key the table lacks, so one helper returns an empty proxy whose `__index` is the data and whose `__newindex` raises a coded error. Callers hold only the proxy, so every write fails where it happens; iterate the data through the helper, since `pairs` and `#` on the empty proxy see nothing.

## Modules and errors

- **`local` everything.** A file declares its names `local` and returns one table, and nothing assigns a global except where the host requires one by name. The linter's global check holds this.
- **Small modules.** One concern per file, named for it. A caller reads a module through `require` or, where the host has none, through the namespace the host passes the file.
- **Errors are tables with a code.** `error({ code = "ParseFailed", field = "x" })` through one `fail(code, facts)` per module, so every throw has the same shape and callers branch on `err.code`. Lua adds no position to a table error, so a fact that locates the failure is a field. A string error carries no code a caller can match.
- **Catch at a boundary.** `pcall` or `xpcall` wraps a host callback or a program's entry point, maps each code to what it prints in one table keyed by every code, and lets an error with no code rethrow. An expected case is a return value, such as `nil` and a code, never a caught error.

## Testing

- busted runs `describe` and `it` blocks with `assert.are.same` for deep equality; a `.busted` file at the root holds its options.
- Test pure modules: a parser, a dispatch table, a formatter. A host API reached through a thin adapter is stubbed at that adapter in the test, so the logic runs under plain Lua outside the host.
- Without busted, a `tests/run.lua` that requires each test file and counts failed `assert`s, exiting non-zero on any, is the whole harness.

## WoW addons

World of Warcraft runs addons in its own Lua 5.1. WoW: Forever runs a mainline client, with retail's UI architecture, so an addon targets the mainline API plus the changes on warcraft.wiki.gg's API changes page for Forever's patch. The stack is plain Lua against that API. Take no framework such as Ace3 and no waypoint addon such as TomTom; embed one small library only when a job needs it, vendored under `libs/` and listed in the `.toc`.

### Lua 5.1

- **Absent in an addon:** `goto` (5.2), `//` and the bitwise operators `& | ~ << >>` (5.3), the `utf8` library (5.3), `<const>` and `<close>` (5.4), `table.unpack` and `_ENV` (5.2). Use the global `unpack` and the `bit` library WoW provides (`bit.band`, `bit.bor`, `bit.lshift`).
- **Absent in WoW's Lua:** `io` and `os` beyond `date`, `difftime` and `time`, and `require`. Files share code through the addon namespace.
- **Set every tool to 5.1:** `syntax = "Lua51"` in StyLua, a selene std on `base: lua51`, and `runtime.version` `"Lua 5.1"` in LuaLS, so a 5.2+ construct fails the check instead of the game's load.

### The `.toc` and namespace

- `## Interface:` holds the client's interface number; read it in game with `/dump select(4, GetBuildInfo())` rather than from memory. Forever loads a `<AddonName>_Forever.toc` in place of the plain `.toc` when both exist, so a flavor-specific `.toc` goes beside the plain one.
- `## SavedVariables:` and `## SavedVariablesPerCharacter:` name the globals the addon owns; beyond them it writes only the names the host reads, such as `SLASH_<NAME>1` and its `SlashCmdList` entry for a slash command.
- Files load top to bottom in the order the `.toc` lists them, so a file that defines a module comes before the files that use it.
- Each file opens with `local addonName, ns = ...`: the addon's name and a table every file of the addon shares. Modules hang off `ns`, never off `_G`.

### Saved data and events

- **Parse saved data on load.** SavedVariables exist from `ADDON_LOADED` for this addon, and only then. Parse the table there into a typed value with a `version` field, migrate older versions forward, and replace a table that fails to parse with a fresh one and a printed notice, since it is the player's file and may hold anything.
- **One event frame, one dispatch table.** A single frame registers every event, and its `OnEvent` script indexes a table keyed by event name. An event's arguments are parsed in its handler before use, since a payload's shape varies between client flavors.
- **Throttle `OnUpdate`.** An `OnUpdate` script runs every frame, so it accumulates `elapsed` and does work only past an interval. Prefer `C_Timer.After` for a delay and `C_Timer.NewTicker` for a repeat, and keep `OnUpdate` for a period of a few frames.

### Combat and taint

- **Combat lockdown.** While `InCombatLockdown()` returns true, a protected frame cannot be shown, hidden, moved or have its attributes changed. Check it first, and queue the change for `PLAYER_REGEN_ENABLED`.
- **Taint.** Everything an addon writes carries taint, and Blizzard code that reads a tainted value cannot call a protected function. Leave Blizzard's globals and functions as they are: post-hook a function with `hooksecurefunc` and a script with `frame:HookScript`.

### Client flavors

A `C_` namespace and its functions differ between client flavors, and between patches of one flavor. Check each API against the mainline documentation and that patch's API changes. Guard one a flavor may lack with a check that its namespace and function exist, and fail loudly when a function the addon needs is missing.

## Verification

Without declared tasks: `stylua --check .`, `selene .`, `lua-language-server --check .`, `busted`.

## Setup

- `mise.toml` pins `lua` (5.1 for an addon), `stylua` and `lua-language-server`, and defines `fmt`, `lint`, `typecheck` and `test` tasks that CI runs.
- selene is installed through `mise` from its GitHub releases, and busted through LuaRocks.
- For an addon, LuaLS takes the WoW API's types from Ketho's mainline annotations in `vscode-wow-api`, and `.luarc.json` sets `diagnostics.globals` to the addon's SavedVariables and host-read names; the selene std lists the same globals as writable and the Blizzard API as read-only.
- A `PostToolUse` hook on `Edit|Write` runs `stylua` on each touched `.lua` file.
