# Tests left out of the Swift target

Each test the Swift target does not run, and why. A test leaves this list when the module it needs
is ported. The list in `scripts/transpile.ts` (`excluded`, `excludedTests`) is what applies; this file
holds the reasons.

## Single test cases (`excludedTests`)

| Test | File | Why |
|---|---|---|
| `hamonics-rendering-text-issue79` | `test/importer/AlphaTexImporter.test.ts` | Renders the score to SVG (`ScoreRenderer`, `VisualTestHelper.prepareAlphaSkia`, `StaveProfile`, `RenderFinishedEventArgs`, `harmonicToString`) and checks the text. Rendering is a later tier; the other tests in the file only import and export. |

## Test cases that trap in Swift (`excludedTests`)

These do not need an unported module, so they break the rule above; they are listed here so the
rest of `swift test` can run (a trap kills the whole test process). Each passes in JS, C# and Kotlin
only because a runtime error (JS TypeError, NullReferenceException/InvalidCastException,
NullPointerException/ClassCastException) is thrown inside `readScore` and caught by the test helper,
which then snapshots empty or partial diagnostics. Swift's `!` and `as!` trap instead of throwing.
They come back when the emitter lowers `!` and downcasts to throwing runtime helpers
(`try TypeHelper.unwrap(x)`, `try TypeHelper.cast(x, T.self)`), which makes every function that
uses them `throws` (a `SwiftThrows` seed) and is a larger change.

| Test | File | Trap |
|---|---|---|
| `at219 > score optional` | `test/importer/AlphaTexImporter.test.ts` | `as!` `AlphaTexNumberLiteral` to `AlphaTexTextNode` |
| `at219 > bar optional` | `test/importer/AlphaTexImporter.test.ts` | same cast |
| `at219 > whammybartype` | `test/importer/AlphaTexImporter.test.ts` | `p.arguments!` is nil (`tb` handler) |
| `at219 > bendtype` | `test/importer/AlphaTexImporter.test.ts` | `p.arguments!` is nil (`b` handler) |
| `at219 > bendstyle` | `test/importer/AlphaTexImporter.test.ts` | argument index out of range (JS reads undefined, then TypeError) |
| `handler-validation > props > optional overload > wrong type` | `test/importer/AlphaTexParameter.test.ts` | `as!` string node to `AlphaTexNumberLiteral` in `_applyBrush` (JS reads `undefined` and goes on) |

## Renderer-only test cases (`excludedTests`)

`TabBarRendererFactory` is a renderer: it extends `BarRendererFactory` and creates a `TabBarRenderer`,
whose import closure is the whole rendering engine (`ScoreRenderer`, layouts, glyphs). The other seven
tests in the file (`Note.isPercussion`, `Staff.finish`) run.

| Test | File |
|---|---|
| `TabBarRendererFactory.canCreate > allows creation for percussion staff with virtual tuning and showTablature` | `test/model/PercussionTablature.test.ts` |
| `TabBarRendererFactory.canCreate > rejects percussion staff when showTablature is false` | `test/model/PercussionTablature.test.ts` |
| `TabBarRendererFactory.canCreate > rejects percussion staff without tuning` | `test/model/PercussionTablature.test.ts` |
| `TabBarRendererFactory.canCreate > allows creation for regular guitar staff` | `test/model/PercussionTablature.test.ts` |

## Whole files (`excluded`)

None. The seven model files left out until round 1 of the settings-importers tier (Bar, JsonConverter,
Lyrics, ModelUtils, NoteSteps, NoteStepsAdditional, PercussionTablature) are back. NoteSteps and
NoteStepsAdditional call `AccidentalHelper.calculateNoteSteps`, a pure static of a renderer class; they
run against the hand-written stand-in `Sources/AlphaTab/AccidentalHelper.swift` (that one function, ported
line by line) until the renderer tier generates `AccidentalHelper`.

## Test cases not emitted (`@target web`)

`JsonConverter.test.ts#settings-from-object` builds settings from a JS object literal; the transpiler
drops it for every non-web target (C# and Kotlin too).
