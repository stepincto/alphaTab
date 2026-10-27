// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
import type * as ts from 'typescript';
import { toIdentifier, toPascalCase } from '../casing';
import type EmitterContextBase from '../EmitterContextBase';
import type * as cs from '../ir/Ir';
import type { TargetStrategy } from '../TargetStrategy';
import { AlphaTabCore } from '../typeRegistry';
import type SwiftEmitterContext from './SwiftEmitterContext';

/**
 * Swift implementation of `TargetStrategy`, the twin of
 * `KotlinTargetStrategy`. Names stay qualified in the IR (the shared
 * transformer builds `alphaTab.core.X` strings); the printer drops the
 * module prefixes, since Swift has one flat module.
 */
export default class SwiftTargetStrategy implements TargetStrategy {
    private readonly _ctx: EmitterContextBase;

    public constructor(ctx: EmitterContextBase) {
        this._ctx = ctx;
        // As for Kotlin: optionals make the value-type-not-null smart cast redundant.
        ctx.smartCast.valueTypeNotNullEnabled = false;
    }

    public readonly targetTag: string = 'swift';

    public alphaSkiaModule(): string {
        return 'alphaTab.platform.skia';
    }

    public toMethodNameCase(text: string): string {
        return toIdentifier(text);
    }

    public toPropertyNameCase(text: string): string {
        return toIdentifier(text);
    }

    public toNamespaceNameCase(text: string): string {
        return text;
    }

    public toTypeNameCase(text: string): string {
        return toPascalCase(text);
    }

    public toCoreTypeName(s: string): string {
        return s;
    }

    public makeExceptionType(): string {
        return 'JsError';
    }

    public makeIterableType(): string {
        return 'any Sequence';
    }

    public makeIteratorType(): string {
        return 'any IteratorProtocol';
    }

    public makeGeneratorType(): string {
        return 'any IteratorProtocol';
    }

    public getDefaultUsings(): string[] {
        return [`${AlphaTabCore.rootModule}.core`];
    }

    public getClassName(type: cs.NamedTypeDeclaration, expr?: cs.Node): string {
        let className = type.name;
        // set by `PartialsPass`; the strategy is wired to a SwiftEmitterContext by SwiftEmitter
        const swiftContext = this._ctx as SwiftEmitterContext;
        if (expr && swiftContext.partialSuffixExpressions.has(expr)) {
            className += 'Partials';
        }
        return className;
    }

    public getNameFromSymbol(symbol: ts.Symbol): string {
        const parent = 'parent' in symbol ? (symbol.parent as ts.Symbol) : undefined;

        if (symbol.name === 'dispose' && (!parent || parent.name === 'SymbolConstructor')) {
            return 'dispose';
        }

        if (symbol.name === 'iterator' && (!parent || parent.name === 'SymbolConstructor')) {
            return 'makeIterator';
        }

        return '';
    }

    /** Swift: `override` only for superclass members, never for protocol conformance. */
    public readonly overrideLookupAllowsInterfaces = false;
}
