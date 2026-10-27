/**
 * @public
 */
export class Describer {
    // `String(x)` and `'a' + x` of an `unknown` value: Swift has no `String + Any?`
    public describe(value: unknown): string {
        return 'value: ' + value;
    }

    public wrapError(action: () => void): void {
        try {
            action();
        } catch (e) {
            throw new Error(String(e));
        }
    }
}
