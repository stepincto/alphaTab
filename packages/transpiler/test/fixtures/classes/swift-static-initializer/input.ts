/**
 * @public
 */
export default class Registry {
    private static _names: string[] = [];

    public constructor(public name: string) {}

    public static count(): number {
        return Registry._names.length;
    }

    public static initialize() {
        Registry._names.push('a');
    }
}

Registry.initialize();
