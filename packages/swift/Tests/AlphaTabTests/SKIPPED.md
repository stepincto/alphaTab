# Tests left out of the Swift target

Each test the Swift target does not run, and why. A test leaves this list when the module it needs
is ported. The list in `scripts/transpile.ts` (`excluded`, `excludedTests`) is what applies; this file
holds the reasons.

## Single test cases (`excludedTests`)

None. The renderer-only cases (`TabBarRendererFactory.canCreate` x4, `hamonics-rendering-text-issue79`) run since the rendering tier is generated.

## Whole files (`excluded`)

None.

## Members of generated files whose body traps (`stubbedMembers` in `scripts/transpile.ts`)

| Member | Why |
|---|---|
| `TestUiFacade.createWorkerPlayer` (`test/visualTests/TestUiFacade.ts`) | Builds an `AlphaSynth` on a `TestOutput`: the audio synth is not part of the Swift target. No rendering test enables the player. |

## Hand-written stand-ins for what the Swift target cannot have

| Stand-in | Replaces | Why |
|---|---|---|
| `SkiaCanvas` (`Sources/AlphaTab/Platform.swift`) | `platform/skia/SkiaCanvas.ts` | alphaSkia is a native rasterizer. `Environment` registers the `skia` engine by name, so the type exists; creating it traps. |
| `ExternalMediaPlayer` (same) | `synth/ExternalMediaPlayer.ts` | Extends the backing track player, which extends the audio synth. `AlphaTabApiBase` names it for `PlayerMode.EnabledExternalMedia`. |
| `VisualTestHelper`, `VisualTestOptions`, `VisualTestRun` (`Runtime/VisualTestHelper.swift`) | `test/visualTests/VisualTestHelper.ts` | The TS draws with alphaSkia and compares PNGs. |
| `EventEmitter`, `EventEmitterOfT` (`Sources/AlphaTab/EventEmitter.swift`) | `EventEmitter.ts` | `off(listener)` compares closures with `!==`; Swift closures have no identity. |
| `VersionInfo` (same file as `SkiaCanvas`) | `generated/VersionInfo.ts` | Written per build with date and commit. |

## Test cases not emitted (`@target web`)

`rendering/ScaleToWidthCallCount.test.ts` is `@target web` as a whole (it monkey-patches a prototype), so the
transpiler drops both of its cases for every non-web target:

| Test | Why |
|---|---|
| `ScaleToWidthCallCount > §H Step 7: vertical layout - scaleToWidth runs exactly once per renderer per cycle` | web-only |
| `ScaleToWidthCallCount > §H Step 7: horizontal layout - scaleToWidth runs exactly once per renderer per cycle` | web-only |
| `JsonConverter > settings-from-object` | builds settings from a JS object literal; the transpiler drops it for every non-web target (C# and Kotlin too) |

