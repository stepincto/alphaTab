/**
 * @public
 */
export class Marker {
    public bar: number = 0;
    public next: Marker | null = null;
}

/**
 * @public
 */
export class Holder {
    public items: number[] = [];
    public optional?: number[];
    public marker: Marker | null = null;

    // `!` on a field that is not nullable: nothing to unwrap
    public sum(): number {
        let s = 0;
        for (const i of this.items!) {
            s += i;
        }
        return s;
    }

    // a narrowed nullable local is unwrapped once, even under a TS `!`
    public walk(markers: Marker[]): number {
        let previous: Marker | null = null;
        for (const m of markers) {
            if (previous) {
                previous!.next = m;
            }
            previous = m;
        }
        return previous ? previous.bar : 0;
    }

    // `!!x` is `Boolean(x)`: one truthiness test
    public isSet(): boolean {
        return !!this.marker && this.marker.bar > 0;
    }

    // `?.` on a value narrowed to non-null
    public count(obj: Holder | null): number {
        if (!obj) {
            return 0;
        }
        if (obj.optional) {
            return obj.optional?.map(i => i * 2).length ?? 0;
        }
        return 0;
    }
}
