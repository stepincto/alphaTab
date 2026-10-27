// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
import createEmit from '@coderline/alphatab-transpiler/src/swift/SwiftEmitter';
import transpiler from '@coderline/alphatab-transpiler/src/TranspilerBase';
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
const fileFilter = (fileName: string) => {
    const f = fileName.replaceAll('\\', '/');
    return sources.some(s => f.includes(s)) && !excluded.some(s => f.endsWith(s));
};

const srcOut = path.resolve(__dirname, '../Sources/AlphaTab/Generated');
const testOut = path.resolve(__dirname, '../Tests/AlphaTabTests/Generated');
// the emitter only writes files, so output of a source that left the filter would linger and still compile
for (const dir of [srcOut, testOut]) {
    fs.rmSync(dir, { recursive: true, force: true });
}

transpiler(
    [
        {
            name: 'Swift',
            emit: createEmit(srcOut, testOut)
        }
    ],
    true,
    fileFilter
);
