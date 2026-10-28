/**
 * @public
 */
export class Store {
    private _data = new Map<string, unknown>();

    public get<T>(key: string, def: T): T {
        return this._data.has(key) ? (this._data.get(key) as T) : def;
    }

    public set<T>(key: string, value: T): void {
        this._data.set(key, value);
    }
}

/**
 * @public
 */
export class Publisher {
    public align(store: Store, values: number[]): void {
        const extent = store.get<[number, number]>('extent', [0, 0]);
        store.set('extent', extent);
        for (const v of values) {
            if (v > extent[0]) {
                extent[0] = v;
            }
        }
    }
}
