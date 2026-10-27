/**
 * @public
 */
export class Reader {
    public static unwrap(e: unknown): unknown {
        return (e as Error).cause instanceof RangeError ? (e as Error).cause : e;
    }
}
