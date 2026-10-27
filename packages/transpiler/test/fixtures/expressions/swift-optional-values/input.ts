/**
 * @public
 */
export class Config {
    public clef: number = 0;
}

/**
 * @public
 */
export class Sheet {
    public config: Config = new Config();
    public items: Config[] = [];
}

/**
 * @public
 */
export class Lookups {
    // a map whose values may be null: Swift's get returns V??, flattened with `?? nil`
    public find(m: Map<string, number[] | null>, key: string): number[] | null | undefined {
        const v = m.get(key);
        return v;
    }

    public first(m: Map<string, number[] | null>): number[] {
        return m.get('a')!;
    }

    // `config` is not optional: inside the chain Swift continues with `.`
    public clef(s: Sheet | undefined): number | undefined {
        return s?.config?.clef;
    }

    // a list element is not optional in Swift: TS's `!` has nothing to unwrap
    public firstClef(s: Sheet): number {
        return s.items[0]!.clef;
    }
}
