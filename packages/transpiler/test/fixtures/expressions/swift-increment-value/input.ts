/**
 * @public
 */
export class Counter {
    private static _nextId: number = 0;
    public id: number = Counter._nextId++;
    public position: number = 0;

    // `++`/`--` as a statement stays `+= 1`; as a value it goes through the runtime
    public fill(array: number[]): number {
        let n = 0;
        array[n++] = 1;
        array[++n] = 2;
        this.position++;
        const before = this.position--;
        for (let i = 0; i < 2; i++) {
            n--;
        }
        return before + --n;
    }
}
