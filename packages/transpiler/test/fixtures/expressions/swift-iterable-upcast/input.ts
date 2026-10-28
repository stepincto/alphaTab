/**
 * @public
 */
export interface IShape {
    area: number;
}

/**
 * @public
 */
export class Square implements IShape {
    public area: number = 1;
}

/**
 * @public
 */
export class Shapes {
    public squares: Square[] = [];

    public get all(): Iterable<IShape> {
        return this.squares;
    }

    public total(shapes: Iterable<IShape>): number {
        let t = 0;
        for (const s of shapes) {
            t += s.area;
        }
        return t;
    }

    public run(): number {
        return this.total(this.squares);
    }
}
