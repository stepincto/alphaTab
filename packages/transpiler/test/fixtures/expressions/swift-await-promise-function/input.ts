/**
 * @public
 */
export interface IStore {
    // returns a Promise without `async`: Swift makes it an `async` function
    read(name: string): Promise<number>;
}

/**
 * @public
 */
export class StoreReader {
    // awaiting a Promise-returning function is a plain `await`, no `.await()`
    public async sum(store: IStore): Promise<number> {
        const a = await store.read('a');
        return a + 1;
    }

    // `Promise<T | null>` keeps the `?` on the async return type
    public async find(store: IStore, name: string): Promise<number | null> {
        const v = await store.read(name);
        return v > 0 ? v : null;
    }
}
