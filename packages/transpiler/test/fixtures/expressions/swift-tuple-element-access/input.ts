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
