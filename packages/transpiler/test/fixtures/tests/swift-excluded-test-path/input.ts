import { describe, it } from 'vitest';

describe('Outer', () => {
    describe('parser', () => {
        it('wrong type', () => {
            const x = 1;
        });
    });
    describe('importer', () => {
        it('wrong type', () => {
            const y = 2;
        });
        it('kept', () => {
            const z = 3;
        });
    });
});
