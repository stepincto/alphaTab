/**
 * @public
 */
export class Token {
    public text: string = '';
}

/**
 * @public
 */
export class Named {
    public toString(): string {
        return 'named';
    }
}

/**
 * @public
 */
export class Messages {
    // `${obj}` calls the object's toString(); without one JS prints "[object Object]"
    public describe(token: Token, named: Named, size: number): string {
        return `token '${token}', ${named}, size ${size}`;
    }
}
