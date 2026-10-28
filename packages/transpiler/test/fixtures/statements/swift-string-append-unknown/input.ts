/**
 * @public
 */
export class Append {
    public result: unknown = 'x';

    public join(parts: string[]): string {
        let text: string = '';
        for (const p of parts) {
            text += p;
        }
        text += this.result;
        return text;
    }
}
