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
    '/alphatab/test/rendering/skyline/'
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
