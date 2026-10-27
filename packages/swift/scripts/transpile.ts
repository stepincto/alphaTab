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

// shortcut: the skyline spike (spec 027 T016) generates one self-contained module; widen this list
// module by module until the filter goes away and the whole of alphaTab is generated.
const sources = [
    '/alphatab/src/rendering/skyline/',
    '/alphatab/src/rendering/utils/ObjectPool.ts',
    '/alphatab/test/rendering/skyline/',
    // tier "model": the model and its tests, plus the small modules they import (closure stays inside
    // this list). Left out on purpose because their import closure is the whole library: Settings,
    // generated/SettingsSerializer, RenderingResources, rendering/utils/AccidentalHelper,
    // importer/* (ScoreLoader, GpxImporter), test/TestPlatform, rendering/TabBarRendererFactory.
    // Settings reaches everything through CoreSettings -> Environment (importers, renderers, workers),
    // so it waits for the tier that drops this filter. Until then Sources/AlphaTab/Settings.swift and
    // SettingsSerializer.swift are hand-written stand-ins with only the members the model names.
    // platform/ICanvas is in: it brings TextAlign for the model and adds no missing type beyond Settings.
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
    // tier "io-alphatex": all of io/, the alphaTex importer and its tests. ScoreLoader is left out: it
    // pulls Environment (the whole library). GeneralMidi and UnsupportedFormatError are in the closure.
    '/alphatab/src/io/',
    '/alphatab/src/importer/AlphaTexImporter.ts',
    '/alphatab/src/importer/alphaTex/',
    '/alphatab/src/importer/ScoreImporter.ts',
    '/alphatab/src/importer/UnsupportedFormatError.ts',
    '/alphatab/src/midi/GeneralMidi.ts',
    '/alphatab/test/importer/AlphaTex',
    // runtime:snapshot: the vitest snapshot printer behind toMatchSnapshot (TestPlatform is hand-written in Tests/Runtime)
    '/alphatab/test/PrettyFormat.ts',
    // tier "io-alphatex": the export roundtrip in AlphaTexImporter.test.ts (113 tests) needs the exporter
    // and ComparisonHelpers (which calls TestPlatform.typedArrayAsUnknownArray). Environment and ScoreLoader
    // stay out (whole library); Settings.swift holds stand-ins for the members named here.
    '/alphatab/src/exporter/AlphaTexExporter.ts',
    '/alphatab/src/exporter/ScoreExporter.ts'
];
// tier "model": tests whose bodies need modules left out above (importers via ScoreLoader/GpxImporter,
// test/TestPlatform file IO, Settings/SettingsSerializer, AccidentalHelper, TabBarRendererFactory).
// They come back with the tier that brings those modules.
const excluded = [
    '/alphatab/test/model/Bar.test.ts',
    '/alphatab/test/model/JsonConverter.test.ts',
    '/alphatab/test/model/Lyrics.test.ts',
    '/alphatab/test/model/ModelUtils.test.ts',
    '/alphatab/test/model/NoteSteps.test.ts',
    '/alphatab/test/model/NoteStepsAdditional.test.ts',
    '/alphatab/test/model/PercussionTablature.test.ts'
];
// single test cases left out of files whose other tests run; each reason is in Tests/AlphaTabTests/SKIPPED.md
const excludedTests = [
    '/alphatab/test/importer/AlphaTexImporter.test.ts#hamonics-rendering-text-issue79',
    // these pass in JS only through a TypeError (null deref, bad cast) the test catches; Swift traps instead
    '/alphatab/test/importer/AlphaTexImporter.test.ts#at219 > score optional',
    '/alphatab/test/importer/AlphaTexImporter.test.ts#at219 > bar optional',
    '/alphatab/test/importer/AlphaTexImporter.test.ts#at219 > whammybartype',
    '/alphatab/test/importer/AlphaTexImporter.test.ts#at219 > bendtype',
    '/alphatab/test/importer/AlphaTexImporter.test.ts#at219 > bendstyle',
    '/alphatab/test/importer/AlphaTexParameter.test.ts#handler-validation > props > optional overload > wrong type'
];
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
            emit: createEmit(scratch(srcOut), scratch(testOut), excludedTests)
        }
    ],
    true,
    fileFilter
);
