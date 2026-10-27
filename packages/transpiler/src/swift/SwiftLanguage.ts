// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
import path from 'node:path';
import type AstTransformer from '../AstTransformer';
import type { LanguageDescriptor } from '../AstTransformer';
import type EmitterContextBase from '../EmitterContextBase';
import type { HandlerRegistry } from '../HandlerRegistry';
import { KotlinLanguage } from '../kotlin/KotlinLanguage';

/**
 * Swift language descriptor. The transform is Kotlin's (same parameter
 * reassignment lowering, enum casts, record fix-ups); Swift differences
 * live in the printer and `SwiftTargetStrategy`. Wraps registered here
 * run on top of Kotlin's.
 */
export const SwiftLanguage: LanguageDescriptor = {
    fileExtension: '.swift',

    attributeNames: {
        ...KotlinLanguage.attributeNames,
        deprecatedAttributeName: 'available'
    },

    buildFileName(fileName: string, context: EmitterContextBase, isTestFile: boolean): string {
        const firstDir = fileName.indexOf(path.sep);
        const base = fileName.substring(firstDir + 1).replace(/\.[^/.]+$/, '');
        return path.join(isTestFile ? context.testOutDir : context.srcOutDir, `${base}.swift`);
    },

    registerHandlers(registry: HandlerRegistry): void {
        KotlinLanguage.registerHandlers(registry);
    },

    postInit(transformer: AstTransformer): void {
        KotlinLanguage.postInit!(transformer);
    }
};
