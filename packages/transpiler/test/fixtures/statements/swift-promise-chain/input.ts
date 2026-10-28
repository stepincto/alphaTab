/**
 * @public
 */
export class Loader {
    public async read(path: string): Promise<number> {
        return path.length;
    }

    public load(path: string, done: (value: number) => void, failed: (e: Error) => void): void {
        this.read(path)
            .then(v => {
                done(v);
            })
            .catch(failed);
    }
}
