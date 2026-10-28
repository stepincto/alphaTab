/**
 * @public
 */
export class Resolvers {
    public async run(fail: boolean): Promise<boolean> {
        const r = Promise.withResolvers<boolean>();
        if (fail) {
            r.reject(new Error('failed'));
        } else {
            r.resolve(true);
        }
        await r.promise;
        return true;
    }
}
