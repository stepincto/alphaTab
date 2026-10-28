/**
 * @public
 */
export class Spread {
    public merge(target: number[], extra: number[]): void {
        target.push(...extra);
        target.splice(0, 0, ...extra);
    }
}
