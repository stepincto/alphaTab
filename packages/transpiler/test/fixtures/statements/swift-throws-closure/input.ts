/**
 * @public
 */
export class Json {
    public static forEach(o: Map<string, unknown>, fn: (v: unknown, k: string) => void): void {
        o.forEach(fn);
    }

    public static check(k: string): void {
        if (k.length === 0) {
            throw new Error('empty key');
        }
    }

    // a closure that throws makes the call it is passed to throw; the callee has to be `rethrows`,
    // as the hand-written runtime helpers are (a generated callee is not yet: see CONVENTIONS.md)
    public static read(o: Map<string, unknown>): void {
        Json.forEach(o, (v, k) => {
            Json.check(k);
        });
    }
}
