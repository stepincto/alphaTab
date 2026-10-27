/**
 * @public
 */
export class Target {
    public value: number = 0;
    public raw: number = 0;

    private static _read(o: Map<string, unknown>, k: string): unknown {
        return o.get(k);
    }

    // `unknown` to number through a TS `!`, a narrowing `typeof`, a call, and an `any` lambda parameter
    public setProperty(property: string, v: unknown): boolean {
        switch (property) {
            case 'value':
                this.value = v! as number;
                return true;
            case 'raw':
                if (typeof v === 'number') {
                    this.raw = v! as number;
                }
                return true;
        }
        return false;
    }

    public fromMap(o: Map<string, unknown>): number {
        return Target._read(o, 'value') as number;
    }

    public lengths(values: any[]): number[] {
        return values.map((d: any) => (d as number) * 2);
    }
}
