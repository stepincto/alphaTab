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

## Whole files (`excluded`, tier "model")

Their test bodies need modules still outside the transpile filter: importers through `ScoreLoader`
or `GpxImporter`, `test/TestPlatform` file IO, `Settings`/`SettingsSerializer`, `AccidentalHelper`,
`TabBarRendererFactory`. They come back with the tier that brings those modules.

- `test/model/Bar.test.ts`
- `test/model/JsonConverter.test.ts`
- `test/model/Lyrics.test.ts`
- `test/model/ModelUtils.test.ts`
- `test/model/NoteSteps.test.ts`
- `test/model/NoteStepsAdditional.test.ts`
- `test/model/PercussionTablature.test.ts`
