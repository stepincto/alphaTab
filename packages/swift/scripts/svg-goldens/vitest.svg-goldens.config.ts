// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

// Runs alphaTab's own visual tests (test/visualTests) in Node with the VisualTestHelper swapped for
// SvgGoldenHelper.ts, which writes SVG goldens instead of comparing PNGs. `npm run svg-goldens` in packages/swift
// runs it (from packages/alphatab, where the tests' relative paths start).
import path from 'node:path';
import url from 'node:url';
import { mergeConfig } from 'vitest/config';
import { defineVitestConfig } from '../../../tooling/src/vitest';

const helper = path.resolve(url.fileURLToPath(new URL('.', import.meta.url)), 'SvgGoldenHelper.ts');

const base = defineVitestConfig({ setupFiles: ['./test/global-hooks.ts'], truncateThreshold: 0 });

// mergeConfig concatenates arrays: the visual tests only, not the whole suite the base config includes
(base.test as { include: string[] }).include = ['test/visualTests/**/*.test.ts'];

export default mergeConfig(base, {
    plugins: [
        {
            name: 'svg-golden-helper',
            enforce: 'pre' as const,
            async resolveId(source: string, importer: string | undefined) {
                if (/(^|\/)VisualTestHelper(\.ts)?$/.test(source) && importer && !importer.endsWith('SvgGoldenHelper.ts')) {
                    return helper;
                }
                return null;
            }
        }
    ],
    root: process.cwd(),
    server: { fs: { strict: false } }
});
