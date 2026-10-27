/**
 * @public
 */
export class Parts {
    // a literal index is an Int literal, also inside a comparison
    public isSlash(text: string): boolean {
        const parts = text.split('/');
        return parts[1] === '/' && parts[0] !== '';
    }
}
