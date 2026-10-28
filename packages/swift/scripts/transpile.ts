// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
import createEmit from '@coderline/alphatab-transpiler/src/swift/SwiftEmitter';
import transpiler from '@coderline/alphatab-transpiler/src/TranspilerBase';
import { execSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import url from 'node:url';

const __dirname = url.fileURLToPath(new URL('.', import.meta.url));

// The tiers generated so far; widen this list until the filter goes away and the whole of alphaTab is generated.
// Not generated: the audio synth engine (synth/), the browser and worker platform, alphaSkia (see SKIPPED.md).
const sources = [
    '/alphatab/src/rendering/skyline/',
    '/alphatab/src/rendering/utils/ObjectPool.ts',
    '/alphatab/test/rendering/skyline/',
    // tier "model": the model and its tests, plus the small modules they import (closure stays inside
    // this list). platform/ICanvas is in: it brings TextAlign for the model.
    '/alphatab/src/model/',
    '/alphatab/src/generated/model/',
    '/alphatab/test/model/',
    '/alphatab/src/AlphaTabError.ts',
    '/alphatab/src/FormatError.ts',
    '/alphatab/src/LogLevel.ts',
    '/alphatab/src/Logger.ts',
    '/alphatab/src/LayoutMode.ts',
    '/alphatab/src/NotationSettings.ts',
    '/alphatab/src/io/ByteBuffer.ts',
    '/alphatab/src/io/IOHelper.ts',
    '/alphatab/src/io/IReadable.ts',
    '/alphatab/src/io/IWriteable.ts',
    '/alphatab/src/io/JsonHelper.ts',
    '/alphatab/src/io/TypeConversions.ts',
    '/alphatab/src/midi/ControllerType.ts',
    '/alphatab/src/midi/MidiEvent.ts',
    '/alphatab/src/midi/MidiFile.ts',
    '/alphatab/src/midi/MidiUtils.ts',
    '/alphatab/src/platform/ICanvas.ts',
    '/alphatab/src/rendering/utils/BeamDirection.ts',
    '/alphatab/src/synth/SynthConstants.ts',
    '/alphatab/src/util/Lazy.ts',
    // tier "io-alphatex": all of io/, the alphaTex importer and its tests. GeneralMidi and
    // UnsupportedFormatError are in the closure.
    '/alphatab/src/io/',
    '/alphatab/src/importer/AlphaTexImporter.ts',
    '/alphatab/src/importer/alphaTex/',
    '/alphatab/src/importer/ScoreImporter.ts',
    '/alphatab/src/importer/UnsupportedFormatError.ts',
    '/alphatab/src/midi/GeneralMidi.ts',
    '/alphatab/test/importer/AlphaTex',
    // runtime:snapshot: the vitest snapshot printer behind toMatchSnapshot
    '/alphatab/test/PrettyFormat.ts',
    // tier "io-alphatex": the export roundtrip in AlphaTexImporter.test.ts (113 tests) needs the exporter
    // and ComparisonHelpers (which calls TestPlatform.typedArrayAsUnknownArray).
    '/alphatab/src/exporter/AlphaTexExporter.ts',
    '/alphatab/src/exporter/ScoreExporter.ts',
    // tier "settings-importers": the real Settings (all groups and their generated serializers), every
    // importer, ScoreLoader, xml/, zip/ and test/TestPlatform, for the model tests that load files.
    '/alphatab/src/Settings.ts',
    '/alphatab/src/CoreSettings.ts',
    '/alphatab/src/DisplaySettings.ts',
    '/alphatab/src/EngravingSettings.ts',
    '/alphatab/src/ExporterSettings.ts',
    '/alphatab/src/ImporterSettings.ts',
    '/alphatab/src/PlayerSettings.ts',
    '/alphatab/src/RenderingResources.ts',
    '/alphatab/src/SmuflMetadata.ts',
    '/alphatab/src/StaveProfile.ts',
    '/alphatab/src/FileLoadError.ts',
    '/alphatab/src/generated/',
    '/alphatab/src/importer/',
    '/alphatab/src/xml/',
    '/alphatab/src/zip/',
    '/alphatab/src/rendering/utils/Bounds.ts',
    '/alphatab/src/rendering/utils/BarBounds.ts',
    '/alphatab/src/rendering/utils/BeatBounds.ts',
    '/alphatab/src/rendering/utils/BoundsLookup.ts',
    '/alphatab/src/rendering/utils/MasterBarBounds.ts',
    '/alphatab/src/rendering/utils/NoteBounds.ts',
    '/alphatab/src/rendering/utils/StaffSystemBounds.ts',
    '/alphatab/test/TestPlatform.ts',
    // tier "rendering": the layout and drawing engine, the canvases, Environment and the rendering tests.
    // Left out: platform/javascript, platform/worker, platform/skia (browser, worker, alphaSkia) and synth/.
    '/alphatab/src/rendering/',
    '/alphatab/src/platform/ICanvas.ts',
    '/alphatab/src/platform/svg/',
    '/alphatab/src/platform/Json.ts',
    '/alphatab/src/Environment.ts',
    '/alphatab/src/midi/',
    '/alphatab/src/profiling/',
    // the data and interface types of the player that the midi generator and the UI facade name
    '/alphatab/src/synth/IAlphaSynth.ts',
    '/alphatab/src/synth/ISynthOutput.ts',
    '/alphatab/src/synth/PlaybackRange.ts',
    '/alphatab/src/synth/PlayerState.ts',
    '/alphatab/src/synth/PlayerStateChangedEventArgs.ts',
    '/alphatab/src/synth/PlaybackRangeChangedEventArgs.ts',
    '/alphatab/src/synth/PositionChangedEventArgs.ts',
    '/alphatab/src/synth/MidiEventsPlayedEventArgs.ts',
    '/alphatab/src/synth/ActiveBeatsChangedEventArgs.ts',
    '/alphatab/test/rendering/',
    // the API object the rendering tests drive (through TestUiFacade), with the player-facing types it names
    '/alphatab/src/AlphaTabApiBase.ts',
    '/alphatab/src/CursorHandler.ts',
    '/alphatab/src/ScrollHandlers.ts',
    '/alphatab/src/ResizeEventArgs.ts',
    '/alphatab/src/ProgressEventArgs.ts',
    '/alphatab/src/platform/Cursors.ts',
    '/alphatab/src/platform/IContainer.ts',
    '/alphatab/src/platform/IMouseEventArgs.ts',
    '/alphatab/src/platform/IUiFacade.ts',
    '/alphatab/src/synth/AlphaSynthWrapper.ts',
    '/alphatab/src/synth/IAudioExporter.ts',
    '/alphatab/test/visualTests/TestUiFacade.ts',
    '/alphatab/test/importer/MusicXmlImporterTestHelper.ts'
];
// files inside the source list left out: whole test files (each reason is in Tests/AlphaTabTests/SKIPPED.md),
// and VersionInfo, which only Environment reads and whose build date and commit would change the
// generated output on every fresh clone
const excluded: string[] = ['/alphatab/src/generated/VersionInfo.ts', '/alphatab/src/EventEmitter.ts'];
// single test cases left out of files whose other tests run; each reason is in Tests/AlphaTabTests/SKIPPED.md
const excludedTests: string[] = [];
// members of generated files whose body the Swift target traps instead of translating; reasons in SKIPPED.md
const stubbedMembers: Record<string, string> = {
    '/alphatab/test/visualTests/TestUiFacade.ts#TestUiFacade.createWorkerPlayer': 'the audio synth is not part of the Swift target'
};
const fileFilter = (fileName: string) => {
    const f = fileName.replaceAll('\\', '/');
    return sources.some(s => f.includes(s)) && !excluded.some(s => f.endsWith(s));
};

// alphaTab's build writes src/generated/VersionInfo.ts (gitignored) and Environment imports it; a fresh
// clone has none, so write the same class here when it is missing (version from package.json, commit from git).
const versionInfo = path.resolve(__dirname, '../../alphatab/src/generated/VersionInfo.ts');
if (!fs.existsSync(versionInfo)) {
    const { version } = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../../alphatab/package.json'), 'utf-8'));
    const commit = execSync('git rev-parse HEAD').toString().trim();
    fs.writeFileSync(
        versionInfo,
        `// <auto-generated>
// This code was auto-generated by packages/swift/scripts/transpile.ts.
// Changes to this file may cause incorrect behavior and will be lost if
// the code is regenerated.
// </auto-generated>

/**
 * @internal
 */
export class VersionInfo {
    public static readonly version: string = '${version}';
    public static readonly date: string = '${new Date().toISOString()}';
    public static readonly commit: string = '${commit}';

    public static print(print: (message: string) => void) {
        print(\`alphaTab \${VersionInfo.version}\`);
        print(\`commit: \${VersionInfo.commit}\`);
        print(\`build date: \${VersionInfo.date}\`);
    }
}
`
    );
}

const srcOut = path.resolve(__dirname, '../Sources/AlphaTab/Generated');
const testOut = path.resolve(__dirname, '../Tests/AlphaTabTests/Generated');
// emit into a scratch copy, then sync: only changed files are rewritten, so SwiftPM rebuilds what changed
// instead of the whole module; output of a source that left the filter is deleted so it cannot linger
// outside Sources/ and Tests/, so a crashed run never leaves a second copy that SwiftPM compiles
const scratch = (dir: string) => path.resolve(__dirname, '../.build/transpile-next', dir === srcOut ? 'src' : 'test');
for (const dir of [srcOut, testOut]) {
    fs.rmSync(scratch(dir), { recursive: true, force: true });
}

function syncDir(from: string, to: string) {
    const files = (d: string) =>
        fs.existsSync(d) ? (fs.readdirSync(d, { recursive: true }) as string[]).filter(f => fs.statSync(path.join(d, f)).isFile()) : [];
    const next = new Set(files(from));
    for (const f of files(to)) {
        if (!next.has(f)) fs.rmSync(path.join(to, f));
    }
    for (const f of next) {
        const src = fs.readFileSync(path.join(from, f));
        const dst = path.join(to, f);
        if (fs.existsSync(dst) && fs.readFileSync(dst).equals(src)) continue;
        fs.mkdirSync(path.dirname(dst), { recursive: true });
        fs.writeFileSync(dst, src);
    }
    fs.rmSync(from, { recursive: true, force: true });
}
// the transpiler ends with ts.sys.exit, so code after its call never runs; sync on exit instead
process.on('exit', () => {
    for (const dir of [srcOut, testOut]) {
        syncDir(scratch(dir), dir);
    }
});

transpiler(
    [
        {
            name: 'Swift',
            emit: createEmit(scratch(srcOut), scratch(testOut), excludedTests, stubbedMembers)
        }
    ],
    true,
    fileFilter
);
