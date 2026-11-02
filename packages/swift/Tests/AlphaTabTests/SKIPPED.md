# Tests left out of the Swift target

Each test the Swift target does not run, and why. A test leaves this list when the module it needs
is ported. What applies is `scripts/transpile.ts` (the filter, `excluded`, `excludedTests`, `stubbedMembers`); this file
holds the reasons.

## Single test cases (`excludedTests`)

None. The renderer-only cases (`TabBarRendererFactory.canCreate` x4, `hamonics-rendering-text-issue79`) run since the rendering tier is generated.

## Whole files (not in the filter)

`test/AlphaTabApiMouse.test.ts` (5 cases) sets `PlayerMode.EnabledSynthesizer`: the API creates the audio synth
(`AlphaSynth` on a `TestOutput`) to highlight beats while pressing. The audio synth is not part of the Swift target
(a `Voice` class of the synth and the model's `Voice` share one Swift module).

| Test | Why |
|---|---|
| `render-during-press-on-single-beat` | needs the audio synth |
| `render-after-click-without-range-reset` | needs the audio synth |
| `render-during-press-across-beats-uses-new-layout` | needs the audio synth |
| `api-highlight-survives-render-without-range-selection` | needs the audio synth |
| `release-outside-beats-ends-press` | needs the audio synth |

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
| `AlphaSkiaCanvas` (`Runtime/VisualTestHelper.swift`) | alphaSkia's raster canvas | Draws nothing; the debug overlays of three visual test files call it (see below). |
| `VersionInfo` (same file as `SkiaCanvas`) | `generated/VersionInfo.ts` | Written per build with date and commit. |

## Visual tests (`test/visualTests`): SVG goldens instead of PNGs

The TS visual tests draw with alphaSkia and compare PNGs, which the Swift target cannot do. All 481 cases run
anyway (and the MusicXML importer tests that render their reference files, 190 more goldens under `SvgGoldens/test-data/`), through the hand-written `VisualTestHelper` (`Runtime/VisualTestHelper.swift`): it renders with the SVG engine
and compares the SVG text with a golden in `Tests/AlphaTabTests/SvgGoldens/`. The goldens come from the TS original,
never from Swift: `npm run svg-goldens` (packages/swift) runs the same test files under Node with
`scripts/svg-goldens/SvgGoldenHelper.ts` in place of the TS `VisualTestHelper`.

- Golden file = `total <w> <h>` plus, per partial result, `partial <x> <y> <w> <h>` and its SVG. A reference image
  that several tests name keeps every distinct rendering; the Swift side accepts any of them.
- Comparison is exact, and on Linux every case matches byte for byte: V8 computes `Math.sin`, `cos`, `atan`, `atan2`,
  `asin`, `log` and `log2` with its own fdlibm port, which differs from glibc in the last bit for a few percent of
  the arguments, so the runtime does the same arithmetic (`Ieee754.swift`, checked bit for bit against Node by
  `Runtime/Ieee754Tests.swift`). If a platform's libm still differs in a function that is not ported (`pow`,
  `exp`), the texts are compared again with every decimal number that has a fraction
  (`-?[0-9]+\.[0-9]+(e[+-]?[0-9]+)?`) rounded to 2 decimals (`%.2f`, `-0.00` as `0.00`), everything else
  (integers, ids, code points, text, markup) untouched. A pass by that fallback prints `note: <golden> equals its
  golden only after rounding numbers to 2 decimals`; on this machine none does.
- What the SVG cannot show is not compared: the overlays the tests draw on the finished PNG with
  `prepareFullImage` (bounds lookup rectangles in `BoundsLookup.test.ts`, skyline outlines in `skyline/Skyline*Coverage`).
  The Swift `AlphaSkiaCanvas` stand-in draws nothing; the overlay code still runs on the rendered result.
- Both helpers apply the same settings (`engine = svg`, scale 1, Noto font families) and start the render ids at 0.

## Visual tests on Core Graphics: PNG check (macOS, opt in)

`CoreGraphics/PngVisualCheck.swift` renders every visual case again with the Core Graphics engine (`AlphaTabIOS`)
and compares it with the TS reference PNG through the translated PixelMatch with the TS options (threshold 0.3,
anti-aliasing ignored, the case's tolerance, 0 by default). It runs only with `ALPHATAB_PNG_CHECK=1` (writes
`packages/swift/.visual-png/results.tsv` and diff images) or `ALPHATAB_PNG_STRICT=1` (also fails the case); the
SVG goldens stay the pass/fail check. Known limits, measured 2026-11-02 on macOS (685 cases, none within 0%):
414 differ by under 0.5%, 151 by 0.5-1%, 99 by 1-2%, 15 by 2-5%, 6 by 5% or more.
- Text: widths and heights equal alphaSkia's (all 203 distinct measureText calls of notation-legend replayed in
  Node), but FreeType hints glyph outlines to whole pixels vertically and Core Graphics cannot, so text pixels
  differ slightly on every page with text.
- Emoji: Noto Color Emoji holds only CBDT bitmaps, which Core Text cannot draw; Apple Color Emoji stands in
  (`general/font-fallback`, 18%).
- Not yet investigated: `musicxml-samples/Echigo` (1026 px high, reference 1007) and `musicxml-testsuite/32a-Notations`
  (793 vs 792), `musicxml3/chord-diagram` (9.9%), `32b-Articulations-Texts` (14.7%), `staff-display-config/cascade-numbered-only` (5.5%).

## Test cases not emitted (`@target web`)

`rendering/ScaleToWidthCallCount.test.ts` is `@target web` as a whole (it monkey-patches a prototype), so the
transpiler drops both of its cases for every non-web target:

| Test | Why |
|---|---|
| `ScaleToWidthCallCount > §H Step 7: vertical layout - scaleToWidth runs exactly once per renderer per cycle` | web-only |
| `ScaleToWidthCallCount > §H Step 7: horizontal layout - scaleToWidth runs exactly once per renderer per cycle` | web-only |
| `JsonConverter > settings-from-object` | builds settings from a JS object literal; the transpiler drops it for every non-web target (C# and Kotlin too) |

