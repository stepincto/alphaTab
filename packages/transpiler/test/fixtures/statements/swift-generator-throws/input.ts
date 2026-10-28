/**
 * @public
 */
export class ThrowingWalker {
    public *items(limit: number): Generator<number> {
        if (limit < 0) {
            throw new Error('negative');
        }
        yield limit;
    }
}
