# TypeScript

## Toolchain

`mise` pins the runtime. Bun is the runtime, package manager and test runner unless the host pins Node, as a serverless platform does; then Node with pnpm. `tsc --noEmit` typechecks; Biome 2 lints and formats, with no ESLint or Prettier beside it. zod 4 validates boundaries.

Drift a model's memory gets wrong:

- TypeScript 7 is the native compiler with `strict` on by default. It removed `baseUrl`, `outFile`, `downlevelIteration`, `moduleResolution: "node10"`, `target: "es5"`, and `esModuleInterop` / `allowSyntheticDefaultImports` set to `false`; a config naming one fails to load. `erasableSyntaxOnly` keeps code runnable under type stripping.
- zod 4 moved string formats to top-level schemas (`z.email()`, `z.uuid()`, `z.url()`), replaced `.passthrough()` and `.merge()` with `z.looseObject()` and `.extend(other.shape)`, folded `z.nativeEnum` into `z.enum`, and renamed the `message` parameter to `error`.
- Next.js 16 ships its docs in `node_modules/next/dist/docs/`; its APIs and file conventions differ from what a model remembers, so read them there first.

A repo script is TypeScript too, run through type stripping (`bun <path>.ts`, or `node --experimental-strip-types <path>.ts`), never a new `.mjs`. Shell stays shell where the job is process orchestration.

## Stack defaults

| Need | Default |
|---|---|
| Web app | Next.js App Router with React 19, on Vercel |
| Content site | Astro with Tailwind 4, on Vercel |
| UI | Tailwind 4 and shadcn/ui on `radix-ui`, `lucide-react` icons, `sonner` toasts |
| Client data | TanStack Query |
| Translations | `next-intl` |
| HTTP API | Hono with `@hono/zod-openapi`, so the zod schemas are the API's contract |
| Tokens | `jose` |
| Server logging | `pino` |
| Errors in production | Sentry |
| Dates | `date-fns` |
| Markdown | `unified` with `remark` plugins |
| Model calls | the AI SDK with its provider packages |
| Unit tests | `bun test` in a Bun repo; Vitest with Testing Library and jsdom in a Node repo |
| Browser tests | Playwright |

## Types

- **`null` is the empty value.** A deliberately empty field, return or wire value is `T | null`, never `x?: T` or `T | undefined`: `undefined` also means unset, misspelled or never assigned. `undefined` stays where the language produces it — an optional parameter, an index read — and is checked there, not passed on. `tsc --strict` accepts `x !== undefined` on a `string | null`, and that branch runs for every value, empty or not.
- **Schema first.** A string union or a shared type is a zod schema, and the type is inferred from it (`type Role = z.infer<typeof Role>`). `z.strictObject` for shapes you own, `z.looseObject` for shapes you don't.
- **Variants** are a union discriminated on one field: `{ kind: "loading" } | { kind: "ready"; diff: Diff } | { kind: "error"; error: string }`.
- **Non-empty** is `[T, ...T[]]`.
- **Brand primitives that must not be mixed** (`type UserId = string & { readonly __brand: "UserId" }`), built only by the parser that validates them.
- **`unknown`, never `any`**, for external data. `JSON.parse` and `response.json()` return `any`, which satisfies every type it is assigned to; take the result as `unknown` and parse it.
- **No `as` to silence the compiler.** Narrow with a check, assert with `invariant(condition, message)`, or fix the type. `as const` and `satisfies` check rather than claim.
- **A `switch` over a union** ends in `default: return unreachable(value)` with `value: never`. Find the repo's `invariant` / `unreachable` helpers, or add them, before reaching for `!` or `as`.
- **`readonly`** on every field and array that crosses a module boundary.
- **No barrel `index.ts`** and no `export * from`.

## Errors and async

- Rethrow with the original attached: `new ServiceError("fetch failed", { cause: err })`. Catch as `unknown` and narrow; never assume `err.message` exists.
- A promise is awaited, returned, or detached with a handler.
- `Promise.allSettled` when one failure must not cancel the rest; deadlines through `AbortSignal.timeout()` passed to `fetch` and long operations.
- `@ts-expect-error` over `@ts-ignore`, so the suppression fails once the error is gone.

## React

- **A surface has one data owner.** Server components read and render by default, refreshed with `router.refresh()`; a surface whose reads change with interaction rather than navigation owns its data in TanStack Query end to end. A server prop copied into `useState` is a second owner that goes stale — pass it as the query's initial data. A draft being typed is client state and stays local.
- **An effect is the last resort.** What `useEffect` gets reached for is usually derived state, a handler on the event itself, or a subscription (`useSyncExternalStore`). Where an app names its effect shapes in one module, import them from there, never `useEffect` raw.

## Verification

Without declared tasks: `bunx biome check --write .`, `bunx tsc --noEmit`, `bun test`.

## Red flags

- `x !== undefined` on a value typed `T | null`, or an optional field standing for a deliberately empty value
- `as T` on parsed data, `!`, `any` or `@ts-ignore`
- `enum` or `namespace` in new code
- A tsconfig option TypeScript 7 removed, or a zod 3 API in a zod 4 tree
- ESLint or Prettier beside Biome

## Setup

Match an existing repo's pins rather than upgrading as a side effect.

`tsconfig.json`:

```jsonc
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "moduleDetection": "force",
    "verbatimModuleSyntax": true,
    "erasableSyntaxOnly": true,
    "noUncheckedIndexedAccess": true,
    "resolveJsonModule": true,
    "skipLibCheck": true,
    "noEmit": true,
    "types": ["bun"]
  },
  "include": ["src/**/*.ts"]
}
```

`strict` is the default in TypeScript 7 and needs no line. `noUncheckedIndexedAccess` is not, and is the one most worth adding. On Node, `"module": "NodeNext"` with `"moduleResolution": "NodeNext"` replaces the bundler pair, and `"types": ["node"]` replaces Bun's.

`biome.json`:

```json
{
  "formatter": { "enabled": true, "indentStyle": "space", "indentWidth": 2, "lineWidth": 110 },
  "linter": {
    "enabled": true,
    "rules": {
      "preset": "recommended",
      "style": {
        "noNonNullAssertion": "error",
        "noEnum": "error",
        "noNamespace": "error",
        "noParameterProperties": "error",
        "noExportedImports": "error",
        "useImportType": "error"
      },
      "suspicious": { "noExplicitAny": "error" },
      "performance": { "noBarrelFile": "error", "noReExportAll": "error" },
      "nursery": {
        "noFloatingPromises": "error",
        "useExhaustiveSwitchCases": "error",
        "noUnsafeTypeAssertion": "error"
      }
    }
  },
  "assist": { "actions": { "source": { "organizeImports": "on" } } }
}
```

Nursery rules can change between Biome minors; pin Biome's version so a minor arrives as a reviewed change. Wire a `PostToolUse` hook on `Edit|Write` that runs `biome check --write` on the touched file.
