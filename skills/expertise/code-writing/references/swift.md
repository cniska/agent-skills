# Swift

Swift and SwiftUI specifics. Swift 6 language mode everywhere, an optional unwrapped by a check and never by `!`, a switch over an enum with no `default`, and a model that is a plain `@Observable` class.

## Toolchain

Suggestions only: the tools a project already uses take precedence. On macOS the Swift compiler, SwiftPM and `swift-format` come with Xcode, which `mise` cannot manage. A suggested `.xcode-version` at the repo root holds the Xcode version on one line, the file `xcodes` and fastlane read, and the repo's check compares it with `xcodebuild -version` before a build; that one pin fixes the Swift compiler and `swift format`, in the toolchain since Swift 6. `mise` pins only command-line tools the toolchain does not ship.

- `swift format lint --strict --recursive --parallel Sources Tests`: without `--strict` findings print as warnings and the run exits 0, so the lint never fails.
- `swift format format --in-place --recursive Sources Tests`.
- `swift build`, `swift test`; an app target builds and tests through `xcodebuild -scheme <scheme> -destination <destination> test`.
- Swift 6 language mode makes strict concurrency checking complete and its diagnostics errors, so `SWIFT_STRICT_CONCURRENCY` has no job beside it. `swift package init` already writes `swiftLanguageModes: [.v6]`; Xcode 26's app templates still write `SWIFT_VERSION = 5.0`, so set it to 6 on a new project.
- Shared code lives in a SwiftPM package the app target depends on; the app target holds the `App` and what Xcode needs. No third-party runtime dependency by default: Foundation, Observation, CryptoKit, Security and LocalAuthentication cover the stack below, and a package added past them says why.

A model's memory of Swift lags the toolchain, so read the installed version before writing an API from memory, and before rejecting one as invalid:

- Swift 6.2 (Xcode 26): a module's default actor isolation can be `MainActor` (SE-0466); under `NonisolatedNonsendingByDefault` a nonisolated `async` function runs on its caller's actor and `@concurrent` moves it off (SE-0461); a global-actor type's conformances are isolated too (SE-0470); `Observations` streams `@Observable` changes as an `AsyncSequence` (SE-0475), on OS 26 and later; strict memory safety is an opt-in warning mode (SE-0458); Swift Testing adds exit tests and attachments.
- Swift 6.3 (Xcode 26.6): `Module::name` selects between modules that export the same name; Swift Testing adds `Test.cancel()` and issue severities.
- Xcode 26's app template sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES` and `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES`.
- Xcode 27 makes SwiftUI's `@State` a macro (TN3211): an `init` assigns every other stored property before any `@State` one, a `@State` property takes no second wrapper, and a view with private `@State` writes its own memberwise `init`.

## Stack defaults

What to reach for with nothing chosen yet; a project's own frameworks and test tools stand.

| Need | Default |
|---|---|
| UI | SwiftUI |
| State | Observation (`@Observable`) |
| Shared code | A SwiftPM package per concern |
| HTTP | `URLSession`'s async methods |
| JSON, plists | `Codable` through `JSONDecoder` / `PropertyListDecoder` |
| Object graph on disk | SwiftData |
| Secrets | Keychain through the Security framework |
| Cryptography | CryptoKit |
| Logging | `os.Logger` with a subsystem and category |
| Shared mutable state | An `actor`; `Mutex` from `Synchronization` where a lock earns it |
| Time | `ContinuousClock`, `Duration`, `Task.sleep(for:)` |
| Unit tests | Swift Testing |
| UI tests | XCTest with XCUIAutomation |

## Types

- **`nil` is the empty value.** A field, return or wire value that may be empty on purpose is `T?`; never `""`, `[]`, `0` or `-1` standing in. Unwrap with `if let` or `guard let`, never `!`. A dictionary of optionals makes two empties (`[String: String?]` reads back `String??`, where `.some(nil)` and `nil` differ), so a value that can be empty is removed from the dictionary, not stored as `nil`.
- **Parse at the boundary with `Codable`.** JSON, plists, files and another program's output decode into a `Decodable` type at the edge; `[String: Any]` from `JSONSerialization` never passes it. `JSONDecoder` ignores unknown keys, and a container keyed by `CodingKeys` lists only the keys it knows, so a shape you own declares its `CodingKeys` enum as `CaseIterable` (a synthesized one is not) and writes `init(from:)` that calls one shared helper: it opens a second container keyed by a `CodingKey` type built from any string, subtracts `CodingKeys.allCases` from its `allKeys`, and throws `DecodingError.dataCorrupted` naming the extra keys; a shape another system defines takes the default decoder and declares only the fields it reads. Past the edge an id is its own `struct` with a `rawValue`, a time is a `Date`, and a secret is `Data` or a `SymmetricKey`, never a `String`.
- **Variants are an enum with associated values**: `enum Load { case loading, ready(Diff), failed(LoadError) }`, never a struct with an `isLoading` flag beside an optional result and an optional error.
- **A switch over an enum you own has no `default`.** The compiler then rejects every switch a new case misses. `@unknown default` goes only on an enum a binary framework declares nonfrozen, where Swift 6 mode demands it.
- **Make the illegal value unconstructable.** A struct whose `init` throws or returns `nil` guards the invariant once, and `let` fields keep it; a non-empty list is such a struct wrapping its first element and the rest.
- **Value types by default.** `struct` and `enum` with `let` fields, `Equatable` and `Hashable` synthesized; a `final class` only for identity, an `@Observable` model included. Existentials are spelled `any P` (SE-0335) and a parameter or return is `some P` where one type is meant.
- **Access is `private` by default**, `internal` within the module, `package` across a package's modules (SE-0386), and `public` only on a package product's surface.

## Errors

- One `enum <Module>Error: Error` per module, its facts as associated values; callers `catch` a case, never match on `localizedDescription`. An `OSStatus`, `NSError` or framework error such as `LAError` is mapped into the module's enum where it arrives.
- **Typed throws where the error set is closed** (SE-0413): `throws(ModuleError)` inside a module or package, and on a public API whose errors are its own. A public function that forwards errors it did not make, or whose errors may grow, throws untyped. `throws(Never)` is a non-throwing function, not a claim.
- **Outside tests, handle the failure instead of `try!`, `!`, `as!` or `fatalError()`.** `precondition` marks an invariant the caller broke. `try?` is a silent catch-and-continue, kept only where `nil` is the honest answer and the function's name says so.
- `throws` over `Result`; `Result` stores an outcome, it does not replace control flow.
- The text shown to a person comes from one `LocalizedError.errorDescription` per module, so a message is never assembled at a call site.

## Concurrency

- **Structured first.** `async let` and `withThrowingTaskGroup` run children that finish or cancel with their parent. `Task { }` starts only where no async context exists, such as a button action; SwiftUI's `.task` modifier owns the view's async work and cancels with it. `Task.detached` almost never.
- **Write new concurrency with `async`/`await`**, with no GCD and no completion handlers: no `DispatchQueue`, `DispatchGroup`, `DispatchSemaphore`, `OperationQueue` or `Thread`, and nothing that blocks a thread waiting on async work. A framework API that still takes a completion handler is wrapped once in `withCheckedThrowingContinuation`, resumed exactly once.
- **Isolation is a module decision.** An app and its UI-facing packages build with `MainActor` default isolation (SE-0466) and approachable concurrency, so unannotated code is main-actor and a model class needs no `@MainActor`. A library package keeps the `nonisolated` default so callers choose where its code runs. Under `NonisolatedNonsendingByDefault` a nonisolated `async` function runs where it is called; CPU-heavy work off the main actor is `@concurrent` and takes only `Sendable` arguments.
- **Shared mutable state off the main actor is an `actor`.** Model classes stay on the main actor and are not `Sendable`; `Sendable` belongs to value types. `@unchecked Sendable` and `nonisolated(unsafe)` are claims the compiler cannot check; where a lock really earns its place it is `Mutex`.
- **Cancellation is cooperative.** A loop calls `try Task.checkCancellation()`, `Task.sleep(for:)` throws when cancelled, and time comes from a `Clock` so a test can drive it.
- A callback stream becomes an `AsyncStream`; a model's changes outside SwiftUI stream through `Observations` on OS 26, `withObservationTracking` before it.
- A response arriving for a state the caller has left is discarded: in SwiftUI `.task(id:)` cancels and restarts; elsewhere compare a generation taken before the `await`.

## SwiftUI

- **Each piece of state has one owner.** A value a view owns is `@State private var`, shared down as a `Binding`; an `@Observable` model a view creates is `@State private var model = Model()`; one passed in is a plain `let model: Model`, or `@Bindable var model` where a control needs `$model.field`; one the whole app shares goes in with `.environment(model)` at the root and `@Environment(Model.self)` below. A model property copied into `@State` is a second owner that goes stale. `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject`, `@EnvironmentObject` and Combine are not written in new code; an `ObservableObject` held in `@State` updates the view only when the reference changes.
- **SwiftUI tracks what `body` reads.** Only properties read in `body` re-render the view, computed ones included, so a model holds plain stored properties and derived values are computed properties, not stored copies.
- **A view renders; a model decides.** Logic lives in the `@Observable` model, where Swift Testing reaches it without a view. Async work starts in `.task` or `.task(id:)`, not in `onAppear` with `Task { }`.
- **`onChange(of:)` is the last resort.** What it gets reached for is derived state, already a computed property, or a response to an event, which goes in that event's handler.

## Security

- **CryptoKit over CommonCrypto and `SecKey`.** `AES.GCM` or `ChaChaPoly` seal and open with a nonce CryptoKit draws fresh when the call omits it; `HKDF` derives a key from a shared secret or a master key. Nothing under `Insecure` in new code. CryptoKit has no password hash and `HKDF` is not one: a key from a passphrase goes through PBKDF2 in CommonCrypto with a per-user salt and an iteration count measured on the device. CryptoKit zeroes its key memory on release; a secret kept as a `String` lives on in copies.
- **A keychain item carries its access control.** `SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .userPresence, &error)` goes in under `kSecAttrAccessControl`, which replaces `kSecAttrAccessible`. `WhenPasscodeSet` is the most restrictive class: nothing stores without a passcode and removing it deletes the item; `ThisDeviceOnly` keeps the item out of iCloud Keychain and other devices' restores; `AfterFirstUnlock` only where a background process reads. `.biometryCurrentSet` makes the item unreadable once a face or finger is enrolled or removed, where `.userPresence` lets the system pick biometrics or passcode. Reading a protected item may prompt and block, so it runs off the main actor and passes `kSecUseAuthenticationContext` with an `LAContext` already evaluated, so one prompt covers a batch. `errSecItemNotFound` is the empty value and returns `nil`; every other `OSStatus` becomes the module's error.
- **LocalAuthentication proves presence; access control enforces it.** `LAContext.evaluatePolicy(_:localizedReason:)` as its async form, after `canEvaluatePolicy`, with `.deviceOwnerAuthentication` so a passcode backs biometrics, and `NSFaceIDUsageDescription` in `Info.plist`. Its `Bool` gates nothing the system enforces: the secret itself is bound to a keychain or Secure Enclave access control, so a bypassed `if` opens nothing. `domainState.biometry.stateHash` changes when biometric enrollment does, and `evaluatedPolicyDomainState`, which it replaced on macOS 15 and iOS 18, is a deprecation warning the setup below turns into an error; `invalidate()` ends a context once its batch is done.
- **The Secure Enclave holds NIST P-256 keys only**, for ECDSA signing and ECDH key agreement, made inside it and never imported or exported; `SecureEnclave.isAvailable` says whether the device has one. `SecureEnclave.P256.KeyAgreement.PrivateKey(accessControl:authenticationContext:)` makes one; its default access control is `AfterFirstUnlockThisDeviceOnly` with no flags, so pass one with `.privateKeyUsage` and the presence flag the item needs. Its `dataRepresentation` is a blob only this device's enclave can load: store it in the keychain and rebuild the key with `init(dataRepresentation:authenticationContext:)`. Data at rest is sealed with a symmetric key derived through `HKDF` from an agreement with the enclave key, so the enclave gates every unseal.
- **`os.Logger` redacts interpolated values by default.** A secret, token or account never gets `privacy: .public` and never goes through `print`.

## Testing

- Swift Testing: a `struct` suite is a fresh instance per test, so setup is its `init` and tests share nothing through it. `#expect(throws: ModuleError.self)` pins the error type; a parameterized `@Test(arguments:)` replaces a loop; `confirmation` counts a callback; an exit test proves a `precondition` fires. Tests run in parallel, so `.serialized` marks only a suite whose tests share a resource. Internal API comes through `@testable import`.
- A test seam is compiled in: `#if DEBUG`, or a SwiftPM `.define("...", .when(configuration: .debug))`, never a runtime variable the shipped code reads.
- The keychain, the enclave and biometrics sit behind a protocol the unit tests stub; the real ones are an opt-in integration run with their own `kSecAttrService`, cleaned up after.
- UI tests are `XCTestCase`s driving `XCUIApplication`, in their own target, finding controls by accessibility identifier, where the project uses XCTest for UI tests.

## Verification

The project's own commands; without declared tasks: `swift format format --in-place --recursive Sources Tests`, `swift format lint --strict --recursive --parallel Sources Tests`, `swift build`, `swift test`, and for an app `xcodebuild -scheme <scheme> -destination <destination> test`, and where the project keeps `.xcode-version`, after `xcodebuild -version` matches it.

## Setup

Suggested for a new package. If the project keeps `.xcode-version`, it holds one line, such as `26.6`.

`Package.swift` for a library package, the `nonisolated` default kept:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "Example",
  platforms: [.macOS(.v15), .iOS(.v18)],
  products: [.library(name: "Example", targets: ["Example"])],
  targets: [
    .target(
      name: "Example",
      swiftSettings: [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .treatAllWarnings(as: .error),
      ]
    ),
    .testTarget(name: "ExampleTests", dependencies: ["Example"]),
  ],
  swiftLanguageModes: [.v6]
)
```

A UI-facing package adds `.defaultIsolation(MainActor.self)` to its `swiftSettings`. `InferIsolatedConformances` and `NonisolatedNonsendingByDefault` are the half of approachable concurrency that Swift 6 mode does not already enable; `DisableOutwardActorInference`, `GlobalActorIsolatedTypesUsability` and `InferSendableFromCaptures` are on in Swift 6 mode. `.treatAllWarnings(as:)` and `.defaultIsolation` need tools version 6.2.

An app target's `.xcconfig`, which Swift 6 mode already covers for strict concurrency:

```
SWIFT_VERSION = 6
SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor
SWIFT_APPROACHABLE_CONCURRENCY = YES
SWIFT_UPCOMING_FEATURE_EXISTENTIAL_ANY = YES
SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES
SWIFT_TREAT_WARNINGS_AS_ERRORS = YES
```

A suggested `.swift-format` at the repo root, which tests share: a test unwraps a fixture with `try #require(...)`, never `!`:

```json
{
  "version": 1,
  "lineLength": 100,
  "indentation": { "spaces": 2 },
  "rules": {
    "NeverForceUnwrap": true,
    "NeverUseForceTry": true,
    "NeverUseImplicitlyUnwrappedOptionals": true,
    "NoLeadingUnderscores": true,
    "OmitExplicitReturns": true,
    "UseEarlyExits": true
  }
}
```

`swift format dump-configuration` prints the defaults the rest come from; `AllPublicDeclarationsHaveDocumentation` stays off, since its fix is a doc comment no comments forbids. Wire a `PostToolUse` hook on `Edit|Write` that runs `swift format format --in-place` on the touched `.swift` file, so the format check is a formality.
