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
        return expected instanceof Set ? 1 : 0;
    }

    // `x as T[]` from `unknown`: a JSON list may hold `T | null` elements
    public first(json: Map<string, unknown>): Map<string, unknown> {
        const items = json.get('items') as Map<string, unknown>[];
        return items[0];
    }

    // `x as bigint` from `unknown`, and `===` on values cast to `undefined`
    public sameBig(expected: unknown, actual: unknown): boolean {
        if ((actual as undefined) === (expected as undefined)) {
            return true;
        }
        return (actual as bigint) === (expected as bigint);
    }
}
