/**
 * @public
 */
export class Pairs {
    // a TS tuple is a native Swift tuple: x[0] reads .0, not Kotlin's .v0
    public first(p: [number, string]): number {
        return p[0];
    }

    public second(p: [number, string] | null): string | undefined {
        return p?.[1];
    }
}

/**
 * A union of tuples has no Swift tuple type; a hand-written class stands in for it (as Kotlin's partial),
 * so its elements keep the shared `.v0` spelling.
 * @target web
 */
type Shape = [number, string] | [number, string, boolean] | null;

/**
 * @public
 */
export class Shapes {
    public first(s: Shape): number {
        if (!s) {
            return 0;
        }
        return s[0];
    }
}
