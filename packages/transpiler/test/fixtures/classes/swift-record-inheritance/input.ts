/**
 * @public
 */
export enum Kind {
    Number,
    Text
}

/**
 * @record
 * @public
 */
export interface Location {
    line: number;
}

/**
 * @public
 */
export interface INode {
    kind: Kind;
    start?: Location;
}

/**
 * A record whose required fields have no zero value: the init sets them, so they are plain types.
 * @record
 * @public
 */
export interface Node extends INode {}

/**
 * @public
 */
export interface IValue extends INode {
    indices?: Map<number, number>;
}

/**
 * A sub-record conforms to IRecord through its base; it sets its own fields before super.init.
 * @record
 * @public
 */
export interface TextNode extends Node {
    text: string;
}

/**
 * `indices` implements IValue, not a member of the base class: no `override`.
 * @record
 * @public
 */
export interface StringLiteral extends TextNode, IValue {
    kind: Kind.Text;
}
