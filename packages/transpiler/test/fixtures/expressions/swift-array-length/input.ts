/**
 * @public
 */
export class Sizes {
    // `new Array<T>(n)` is a length, never a one-element array
    public filled(): number[] {
        return new Array<number>(31).fill(40);
    }

    public named(count: number): string[] {
        return new Array<string>(count);
    }
}
