# Dart

Dart and Flutter specifics. A `!` is a claim made only where a check proves it, decoded JSON is read with a pattern, and a switch over a sealed class has no wildcard arm.

## First

1. Read `pubspec.yaml`, its `environment: sdk:` lower bound, and `analysis_options.yaml`. The lower bound decides which language features the package may use.
2. Find how the repo reads JSON. Generated models (`json_serializable`, `built_value`) are followed, not joined by a second way; a hand-written reader takes the pattern form below even where its neighbors cast.

## Toolchain

`mise` pins Flutter, which carries its Dart SDK, or Dart alone for a package with no Flutter. A pinned tool can sit off the non-interactive `PATH`, so run it through `mise exec --` or the repo's task. In a pub workspace — the root `pubspec.yaml` lists members under `workspace:` — `pub get` runs once at the root.

- `dart analyze --fatal-infos`: lints report at info level, and without the flag a lint never fails the run. `flutter analyze` in a Flutter package makes infos fatal by default.
- `dart format`. Since 3.7 the formatter adds and removes trailing commas itself; do not place them to force a layout.
- `dart test`, or `flutter test` in a package that depends on Flutter.
- If `dio` is in the tree, don't add `http`.
- Generated `*.g.dart` files come from `build_runner` and are never edited by hand; change the source and regenerate.

A model's memory of Dart lags the language, so check the SDK lower bound before writing a feature from memory, and before rejecting one as invalid:

- 3.8 added null-aware elements: `[?maybe]`, `{key: ?maybe}`.
- 3.10 added dot shorthands: `.center` where the context type is known.
- 3.12 allows private named parameters: `Point({required this._x})`.
- 3.13 added primary constructors (`class Point(final int x, final int y);`, `new(...)` in a body) and made `final` or `var` on an ordinary parameter a compile error.

## Types

- **Read decoded data with a pattern.** `jsonDecode`, platform channels, files and another program's output arrive as `dynamic`. Read them once at the edge, `switch (json) { {'id': final String id, 'moves': final List<Object?> moves} => …, _ => throw FormatException('expected a game', json) }`, so a bad shape fails there with the input attached. A chain of `json['id']! as String` fails deep in the code with `Null check operator used on a null value`, naming no field.
- **Two pattern traps on decoded JSON.** A map pattern fails when a key it names is absent, so an optional key is read on its own (`json['name']`), never as `'name': final String? name`. Decoded lists are `List<dynamic>`, so `final List<String> moves` never matches real input; match `List<Object?>` and check each element. A test that passes typed literals (`<String>['e2e4']`) hides both, so feed readers `jsonDecode` output.
- **Decoded JSON is `Map<String, Object?>`**, never `Map<String, dynamic>`: `dynamic` turns every later member access into an unchecked call.
- **No `!` to silence the analyzer.** Promote with a check (`if (x case final value?)`, an early return on `null`), or fix the type. `late` makes the same unchecked claim about initialization; use it only where a framework guarantees the order, as `initState` does.
- **A switch over a sealed class or enum has no `_` or `default` arm.** The analyzer then rejects every switch that misses a new subtype; a wildcard arm makes it accept them all. The analyzer's own fix suggests adding a default case — add the missing case instead.
- **Fields are `final`**, and a value type gets a `const` constructor. A class meant to be implemented or extended says so with `interface`, `base` or `sealed`; any other public class is `final`.

## Async

- A `Future` that can fail — a write, a request — is awaited or returned. `unawaited(...)` marks a fire-and-forget as deliberate but still drops its error, so it suits an animation or a haptic, not a save.
- `Future` for one answer, `Stream` for many. Whoever calls `listen` keeps the `StreamSubscription` and cancels it.
- An answer that lands after the state moved on is dropped, not applied. Take a generation counter before the `await` and compare it after, `if (!mounted || generation != _generation) return;`; `mounted` alone lets a slow early request overwrite a fast later one.

## Packages and errors

- A package's public surface is `lib/<package>.dart` exporting files from `lib/src/`; that file is the only re-export. From outside, import the package's library, never another package's `src/`.
- An exception is a `final class … implements Exception` with its facts as fields, including an enum `kind` when callers react differently. Callers use `on TheException catch (e)` and switch on the kind.
- `Error` subclasses (`StateError`, `ArgumentError`, `TypeError`) are bugs. Throw them for a violated precondition; never catch them.
- A deliberate degradation — a saved document from another build read as empty — catches the one type that failure throws, usually `FormatException` from the reader, and says why in one line. `on Object` or `catch (_)` there also turns every bug in the code it wraps into the same silent fallback.

## Testing

- No real time: inject `package:clock` and drive timers with `fakeAsync`.
- A suppression (`// ignore:`, `// ignore_for_file:`) carries its reason.

## Red flags

- `as String`, `as int` or `!` chained over decoded JSON instead of one pattern at the edge
- A map pattern naming an optional key, or `List<String>` matched against decoded JSON
- `Map<String, dynamic>` held past the line that decoded it
- A `_` or `default` arm on a switch over a sealed class or enum
- `!` or `late` where a null check or a non-nullable type would do
- `setState` after an `await` guarded by `mounted` alone, where a later request may already have answered
- `on Object` or `catch (_)` around a reader, where `FormatException` is the failure meant
- Catching `Error`
- A write or request left unawaited, or wrapped in `unawaited` so its error is lost
- An import of another package's `src/`
- A hand edit to a generated `*.g.dart` file
- A language feature newer than the package's SDK lower bound, or a valid newer one rewritten as if it were an error

## Setup

Config bodies for a new package. Match an existing repo's pins rather than upgrading as a side effect.

### `analysis_options.yaml`

```yaml
include: package:lints/recommended.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true

linter:
  rules:
    - avoid_dynamic_calls
    - prefer_final_locals
    - unawaited_futures
```

A Flutter package includes `package:flutter_lints/flutter.yaml` instead. In a workspace, keep this file at the root and have each member's file include it next to its lint set, so a rule is stated once. `strict-casts` stops `dynamic` from flowing into a typed variable unchecked, which is what makes reading with a pattern enforceable.

### `pubspec.yaml`

```yaml
environment:
  sdk: ^3.12.0

dev_dependencies:
  lints: ^6.0.0
  test: ^1.25.0
```

Wire a `PostToolUse` hook on `Edit|Write` that runs `dart format` on the touched file, so the format check is a formality.
