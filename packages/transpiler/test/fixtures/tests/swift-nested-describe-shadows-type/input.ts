import { describe, it } from 'vitest';

/**
 * @public
 */
export enum BarNumberDisplay {
    AllBars = 0,
    Hide = 1
}

describe('Importer', () => {
    describe('barNumberDisplay', () => {
        const expected = BarNumberDisplay.Hide;

        it('reads hide', () => {
            const actual: BarNumberDisplay = BarNumberDisplay.Hide;
            if (actual !== expected) {
                throw new Error('fail');
            }
        });
    });
});
