/**
 * @public
 */
export class TupleWrite {
    public widen(values: number[]): number {
        const extent: [number, number] = [0, 0];
        for (const v of values) {
            if (v > extent[0]) {
                extent[0] = v;
            }
            if (v < extent[1]) {
                extent[1] = v;
            }
        }
        const fixed: [number, number] = [1, 2];
        return extent[0] - extent[1] + fixed[0];
    }
}
