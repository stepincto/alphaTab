/**
 * @public
 */
export class Args {
    public static count(values: (string | undefined)[]): number {
        return values.filter(v => v !== undefined).length;
    }

    // a `string[]` passed as `(string | undefined)[]`: Swift cannot cast a List to a wider element type
    public static run(values: string[]): number {
        return Args.count(values);
    }
}
