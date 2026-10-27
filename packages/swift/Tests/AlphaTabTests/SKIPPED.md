# Tests left out of the Swift target

Each test the Swift target does not run, and why. A test leaves this list when the module it needs
is ported. The list in `scripts/transpile.ts` (`excluded`, `excludedTests`) is what applies; this file
holds the reasons.

## Single test cases (`excludedTests`)

| Test | File | Why |
|---|---|---|
| `hamonics-rendering-text-issue79` | `test/importer/AlphaTexImporter.test.ts` | Renders the score to SVG (`ScoreRenderer`, `VisualTestHelper.prepareAlphaSkia`, `StaveProfile`, `RenderFinishedEventArgs`, `harmonicToString`) and checks the text. Rendering is a later tier; the other tests in the file only import and export. |

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
