/**
 * @public
 */
export type Printer = (value: number) => string;

/**
 * @public
 */
export class Format {
    public static print(value: number): string {
        if (value < 0) {
            throw new Error('negative');
        }
        return value.toString();
    }

    // a throwing method passed where a function type is expected: the type alias throws, so does
    // every call through it and every function that calls one
    public static join(values: number[], printer: Printer): string {
        return values.map(v => printer(v)).join(',');
    }

    public static run(values: number[]): string {
        return Format.join(values, Format.print);
    }
}
