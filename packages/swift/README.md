# alphaTab Swift target

A third target for alphaTab's own TypeScript transpiler, beside C# and Kotlin, modelled on
the Kotlin target. The library and its tests are generated from alphaTab's TypeScript sources;
only the runtime and the iOS platform layer are written by hand.

Licensed MPL-2.0, like the rest of alphaTab.

## Layout

| Path | What |
|---|---|
| `../../Package.swift` | SwiftPM manifest at the repo root, pointing into this folder |
| `scripts/transpile.ts` | runs `TranspilerBase` with the Swift emitter (`packages/transpiler/src/swift/SwiftEmitter.ts`) |
| `Sources/AlphaTabRuntime/` | hand-written runtime: collections, ECMAScript shims, core (ported from the Kotlin runtime) |
| `Sources/AlphaTab/Generated/` | generated library, checked in; never edit by hand |
| `Sources/AlphaTabIOS/` | hand-written iOS platform layer (canvas, view, scroll, workers) |
| `Tests/AlphaTabTests/Generated/` | generated tests; never edit by hand |

Products: `AlphaTab` (targets `AlphaTabRuntime` and `AlphaTab`) and `AlphaTabIOS`.
Platforms: iOS 18, macOS 14 (for `swift test`). Swift 6 language mode.

## Transpile, build, test

```sh
npm ci                                   # repo root
npm run transpile -w packages/swift      # regenerate Sources/AlphaTab/Generated and Tests/.../Generated
swift build                              # repo root
swift test                               # repo root
```

The emitter is driven by the transpiler's fixture tests: every fixture folder under
`packages/transpiler/test/fixtures/` with an `expected.swift` is checked against the Swift
emitter (`npx vitest run` in `packages/transpiler`).

## Upstream base

Built from CoderLine/alphaTab `develop` at `c53d5adfcefd49af6c748fbadd5e054de8ce1b3c`
(2026-10-22).
