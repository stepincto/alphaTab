/**
 * @public
 */
export class Escapes {
    // a backspace, a form feed, an escaped backslash before `b`/`f`/`u`, and a non-ASCII escape
    public static values(): string[] {
        return ['a\bb\fc', '\\bracket \\foo \\u0041', `\\beat ${1}`, 'é\u0001'];
    }
}
