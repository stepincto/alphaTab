// Writes Tests/AlphaTabTests/Runtime/Ieee754Vectors.txt: what Node's Math.sin, cos, atan2, asin, log and log2 return
// for a spread of arguments, as hex bit patterns. The Swift runtime must give the same bits (Ieee754Tests.swift).
//   node scripts/ieee754-vectors.mjs > Tests/AlphaTabTests/Runtime/Ieee754Vectors.txt
const buf = new DataView(new ArrayBuffer(8));
const hex = d => {
    buf.setFloat64(0, d);
    return buf.getBigUint64(0).toString(16).padStart(16, '0');
};
let seed = 987654;
const rnd = () => {
    seed = (seed * 1664525 + 1013904223) >>> 0;
    return seed / 4294967296;
};
const sign = () => (rnd() < 0.5 ? -1 : 1);
const scale = () => Math.pow(10, rnd() * 16 - 10); // 1e-10 .. 1e6
const out = [];
for (let i = 0; i < 500; i++) {
    const a = sign() * scale();
    out.push(`sin ${hex(a)} ${hex(Math.sin(a))}`);
    out.push(`cos ${hex(a)} ${hex(Math.cos(a))}`);
    const y = sign() * scale();
    const x = sign() * scale();
    out.push(`atan2 ${hex(y)} ${hex(x)} ${hex(Math.atan2(y, x))}`);
    const r = sign() * (rnd() < 0.5 ? rnd() : 1 - Math.pow(10, -rnd() * 12));
    out.push(`asin ${hex(r)} ${hex(Math.asin(r))}`);
    const p = scale() * scale();
    out.push(`log ${hex(p)} ${hex(Math.log(p))}`);
    out.push(`log2 ${hex(p)} ${hex(Math.log2(p))}`);
}
for (const k of [0.5, 1, 1.5, 2, 3, 4, 8]) {
    for (const d of [0, 1e-9, -1e-9, 1e-5]) {
        const v = k * (Math.PI / 2) + d;
        out.push(`sin ${hex(v)} ${hex(Math.sin(v))}`);
        out.push(`cos ${hex(v)} ${hex(Math.cos(v))}`);
    }
}
for (const v of [0, -0, 1, -1, Infinity, -Infinity, 1e-320]) {
    out.push(`log ${hex(v)} ${hex(Math.log(v))}`);
    out.push(`log2 ${hex(v)} ${hex(Math.log2(v))}`);
    out.push(`asin ${hex(v)} ${hex(Math.asin(v))}`);
}
for (const y of [0, -0, 1, Infinity, -Infinity]) {
    for (const x of [0, -0, 1, -1, Infinity, -Infinity]) {
        out.push(`atan2 ${hex(y)} ${hex(x)} ${hex(Math.atan2(y, x))}`);
    }
}
console.log(out.join('\n'));
