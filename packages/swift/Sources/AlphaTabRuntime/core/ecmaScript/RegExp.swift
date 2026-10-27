// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation

/// JS `RegExp` over `NSRegularExpression` (ICU), which reads the patterns alphaTab uses the same
/// way JS does and counts in UTF-16 units like JS. Flags: g, i, m, s; others are ignored.
/// shortcut: no `lastIndex`, so `test` on a global regex does not advance between calls as in JS;
/// alphaTab never reuses a global regex for `test` or `exec`. No `split`: nothing generated calls it.
public final class RegExp: @unchecked Sendable {
    // Immutable after init; NSRegularExpression is thread safe for matching.
    let regex: NSRegularExpression
    let global: Bool

    public init(_ pattern: String, _ flags: String = "") {
        var options: NSRegularExpression.Options = []
        for c in flags {
            switch c {
            case "i": options.insert(.caseInsensitive)
            case "m": options.insert(.anchorsMatchLines)
            case "s": options.insert(.dotMatchesLineSeparators)
            default: break
            }
        }
        global = flags.contains("g")
        do {
            regex = try NSRegularExpression(pattern: pattern, options: options)
        } catch {
            // JS throws SyntaxError; generated callers carry no `try`.
            fatalError("Invalid regular expression: /\(pattern)/: \(error)")
        }
    }

    public func test(_ s: String) -> Bool {
        return regex.firstMatch(in: s, range: NSRange(location: 0, length: (s as NSString).length)) != nil
    }

    /// JS `exec`: the match then each capture group, or nil when nothing matches. A group that did not
    /// take part is "" (JS: `undefined`), as in `replace` callbacks.
    public func exec(_ s: String) -> List<String>? {
        let ns = s as NSString
        guard let m = regex.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else {
            return nil
        }
        return List(contentsOf: (0..<m.numberOfRanges).map { RegExp.group(m, ns, $0) })
    }

    /// Calls `replacement` per match (the first only without `g`) and splices the results in.
    func replaceMatches(_ s: String, _ replacement: (NSTextCheckingResult, NSString) -> String) -> String {
        let ns = s as NSString
        let all = NSRange(location: 0, length: ns.length)
        let matches = global ? regex.matches(in: s, range: all) : (regex.firstMatch(in: s, range: all).map { [$0] } ?? [])
        if matches.isEmpty {
            return s
        }
        var out = ""
        var pos = 0
        for m in matches {
            out += ns.substring(with: NSRange(location: pos, length: m.range.location - pos))
            out += replacement(m, ns)
            pos = m.range.location + m.range.length
        }
        out += ns.substring(from: pos)
        return out
    }

    /// Capture group `i` of `m`, or "" when it did not take part (JS passes `undefined`).
    static func group(_ m: NSTextCheckingResult, _ ns: NSString, _ i: Int) -> String {
        guard i < m.numberOfRanges else {
            return ""
        }
        let r = m.range(at: i)
        return r.location == NSNotFound ? "" : ns.substring(with: r)
    }

    /// JS GetSubstitution (ECMA-262 22.1.3.19.1): $$, $&, $`, $', $n, $nn. Named groups unsupported.
    static func substitute(_ template: String, _ m: NSTextCheckingResult, _ ns: NSString) -> String {
        let t = Swift.Array(template.utf16)
        let groups = m.numberOfRanges - 1
        var out: [UInt16] = []
        var i = 0
        func digit(_ k: Int) -> Int? {
            return k < t.count && t[k] >= 0x30 && t[k] <= 0x39 ? Int(t[k] - 0x30) : nil
        }
        while i < t.count {
            guard t[i] == 0x24, i + 1 < t.count else {
                out.append(t[i])
                i += 1
                continue
            }
            let next = t[i + 1]
            var piece: String?
            var used = 2
            switch next {
            case 0x24: piece = "$"
            case 0x26: piece = ns.substring(with: m.range)
            case 0x60: piece = ns.substring(to: m.range.location)
            case 0x27: piece = ns.substring(from: m.range.location + m.range.length)
            default:
                if let d1 = digit(i + 1) {
                    if let d2 = digit(i + 2), d1 * 10 + d2 >= 1, d1 * 10 + d2 <= groups {
                        piece = group(m, ns, d1 * 10 + d2)
                        used = 3
                    } else if d1 >= 1, d1 <= groups {
                        piece = group(m, ns, d1)
                    }
                }
            }
            if let piece {
                out.append(contentsOf: piece.utf16)
                i += used
            } else {
                out.append(t[i])
                i += 1
            }
        }
        return String(decoding: out, as: UTF16.self)
    }
}

/// `String.prototype.replace(regexp, ...)` (Kotlin's partials in `Globals.kt`), JS semantics.
extension String {
    public func replace(_ pattern: RegExp, _ replacement: String) -> String {
        return pattern.replaceMatches(self) { m, ns in RegExp.substitute(replacement, m, ns) }
    }

    public func replace(_ pattern: RegExp, _ replacement: (_ match: String, _ group1: String) -> String) -> String {
        return pattern.replaceMatches(self) { m, ns in replacement(ns.substring(with: m.range), RegExp.group(m, ns, 1)) }
    }

    public func replace(_ pattern: RegExp, _ replacement: (_ match: String) -> String) -> String {
        return pattern.replaceMatches(self) { m, ns in replacement(ns.substring(with: m.range)) }
    }

    public func replaceAll(_ pattern: RegExp, _ replacement: String) -> String {
        return replace(pattern, replacement)
    }

    public func replaceAll(_ pattern: RegExp, _ replacement: (_ match: String) -> String) -> String {
        return replace(pattern, replacement)
    }
}
