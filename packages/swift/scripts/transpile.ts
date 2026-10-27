// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
import createEmit from '@coderline/alphatab-transpiler/src/swift/SwiftEmitter';
import transpiler from '@coderline/alphatab-transpiler/src/TranspilerBase';
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
    // generated/SettingsSerializer, RenderingResources, platform/ICanvas, rendering/utils/AccidentalHelper,
    // importer/* (ScoreLoader, GpxImporter), test/TestPlatform, rendering/TabBarRendererFactory.
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
    '/alphatab/src/rendering/utils/BeamDirection.ts',
    '/alphatab/src/synth/SynthConstants.ts',
    '/alphatab/src/util/Lazy.ts'
];
const fileFilter = (fileName: string) => sources.some(s => fileName.replaceAll('\\', '/').includes(s));

transpiler(
    [
        {
            name: 'Swift',
            emit: createEmit(
                path.resolve(__dirname, '../Sources/AlphaTab/Generated'),
                path.resolve(__dirname, '../Tests/AlphaTabTests/Generated')
            )
        }
    ],
    true,
    fileFilter
);
