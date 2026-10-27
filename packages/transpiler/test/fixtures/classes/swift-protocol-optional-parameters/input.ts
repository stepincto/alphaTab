/**
 * @public
 */
export interface Canvas {
    // a protocol requirement cannot carry defaults: an extension adds the shorter overloads
    fill(x: number, y?: number, center?: boolean): void;
    measure(text: string): number;
}

/**
 * @public
 */
export class Painter {
    public paint(canvas: Canvas): number {
        canvas.fill(1);
        canvas.fill(1, 2, true);
        return canvas.measure('a');
    }
}
