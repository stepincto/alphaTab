/**
 * @public
 */
export interface INode {
    start: number;
}

/**
 * Structurally the same as INode, but Swift sees only the declared supertypes.
 * @public
 */
export interface IValue extends INode {}

/**
 * @public
 */
export class Node implements INode {
    public start: number = 0;
}

/**
 * `as` is a coercion only to a declared supertype; any other cast is `as!`.
 * @public
 */
export class Casts {
    public upcast(value: IValue): INode {
        return value as INode;
    }

    public toSibling(node: INode): IValue {
        return node as IValue;
    }

    public toClass(value: IValue): Node {
        return value as Node;
    }

    public narrowed(node: Node | undefined): IValue | undefined {
        if (node?.start === 1) {
            return node as IValue;
        }
        return undefined;
    }
}
