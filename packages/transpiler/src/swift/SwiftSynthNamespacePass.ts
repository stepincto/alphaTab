import type EmitterContextBase from '../EmitterContextBase';
import * as cs from '../ir/Ir';
import type { IrPass } from '../passes/IrPass';

/**
 * Swift has one module for the whole library, where C# and Kotlin have namespaces. A type of the audio synth
 * that shares its name with a type outside it (the synth's `Voice` and the model's `Voice`) would clash, and so
 * would the two `Voice.swift` files. This pass prefixes such synth types with `Synth` and renames their files.
 * References point at the declaration, so the printer follows the new name.
 */
export class SwiftSynthNamespacePass implements IrPass {
    public readonly name = 'swift-synth-namespace';

    public run(files: readonly cs.SourceFile[], _context: EmitterContextBase): void {
        const isSynth = (f: cs.SourceFile) => f.fileName.replaceAll('\\', '/').includes('/synth/');
        const taken = new Set<string>();
        for (const f of files) {
            if (!isSynth(f)) {
                for (const d of f.namespace.declarations) {
                    taken.add((d as cs.NamedElement).name);
                }
            }
        }
        for (const f of files.filter(isSynth)) {
            for (const d of f.namespace.declarations) {
                const named = d as cs.NamedElement;
                if (taken.has(named.name)) {
                    const old = named.name;
                    named.name = `Synth${old}`;
                    f.fileName = f.fileName.replace(new RegExp(`${old}\\.swift$`), `Synth${old}.swift`);
                }
            }
        }
    }
}
