/**
 * @public
 */
export class Walker {
    public *items(): Generator<number> {
        yield 1;
        yield 2;
    }

    public sum(source: Generator<number> | undefined): number {
        let total = 0;
        if (!source) {
            return total;
        }
        for (const v of source) {
            total += v;
        }
        for (const v of this.items()) {
            total += v;
        }
        return total;
    }
}
