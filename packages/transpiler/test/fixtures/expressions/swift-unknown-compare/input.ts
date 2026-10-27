/**
 * @public
 */
export class Compare {
    // `===` on two `unknown` values, and a cast from an `unknown` TS narrowed with `instanceof`
    public same(expected: unknown, actual: unknown): boolean {
        if (actual !== expected) {
            return false;
        }
        return actual === expected;
    }

    public size(expected: unknown): number {
        if (expected instanceof Map) {
            const m = expected as Map<string, unknown>;
            return m.size;
        }
        return 0;
    }
}
