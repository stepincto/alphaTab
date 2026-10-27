// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

@testable import AlphaTab
import AlphaTabRuntime
import Foundation
import Testing

/// vitest's `toMatchSnapshot` against the `.snap` files the TypeScript tests wrote (Kotlin's
/// `Expector.toMatchSnapshot` with `@SnapshotFile`/`@TestName`). Swift has no such annotations, so
/// both come from the running test: the `.snap` path from its generated file
/// (`Generated/importer/X.test.swift` -> `packages/alphatab/test/importer/__snapshots__/X.test.ts.snap`)
/// and the `describe` names from the `@Suite("...")` lines that enclose it in that file.
enum Snapshot {
    private static let _lock = NSLock()
    nonisolated(unsafe) private static var _counters: [String: Int] = [:]
    nonisolated(unsafe) private static var _sources: [String: [Substring]] = [:]

    /// Matches `value` with the next snapshot of the running test; returns the failure text, or nil.
    static func match(_ value: Any?, _ hint: String) -> String? {
        guard let test = Test.current else {
            return "toMatchSnapshot called outside a test"
        }
        let location = test.sourceLocation
        guard let snapPath = snapshotPath(forTestFile: location.filePath) else {
            return "No snapshot file for generated test file \(location.filePath)"
        }
        guard FileManager.default.fileExists(atPath: snapPath) else {
            return "Could not find snapshot file at \(snapPath)"
        }
        // tests run in parallel; the counters and the generated SnapshotFileRepository cache are not thread-safe
        _lock.lock()
        defer { _lock.unlock() }
        do {
            let lines = try _sourceLines(location.filePath)
            let parts = suiteNames(lines, line: location.line) + [test.displayName ?? test.name]
            let name = _useSnapshotValue(parts.joined(separator: " > "), hint)
            return try SnapshotFileRepository.loadSnapshotFile(snapPath).match(name, value)
        } catch {
            return "Snapshot match failed: \(error)"
        }
    }

    /// vitest's key: `<suites and test joined by " > ">[ > hint] <n>`, n counting from 1 per key.
    static func useSnapshotValue(_ baseName: String, _ hint: String) -> String {
        _lock.lock()
        defer { _lock.unlock() }
        return _useSnapshotValue(baseName, hint)
    }

    private static func _useSnapshotValue(_ baseName: String, _ hint: String) -> String {
        let fullName = hint.isEmpty ? baseName : "\(baseName) > \(hint)"
        let n = (_counters[fullName] ?? 0) + 1
        _counters[fullName] = n
        return "\(fullName) \(n)"
    }

    /// `<root>/packages/swift/Tests/AlphaTabTests/Generated/<dir>/<name>.swift` ->
    /// `<root>/packages/alphatab/test/<dir>/__snapshots__/<name with .ts>.snap`.
    static func snapshotPath(forTestFile filePath: String) -> String? {
        let marker = "/packages/swift/Tests/AlphaTabTests/Generated/"
        guard let range = filePath.range(of: marker), filePath.hasSuffix(".swift") else {
            return nil
        }
        let root = filePath[..<range.lowerBound]
        let relative = filePath[range.upperBound...].dropLast(".swift".count)
        let slash = relative.lastIndex(of: "/")
        let dir = slash.map { String(relative[...$0]) } ?? ""
        let name = slash.map { String(relative[relative.index(after: $0)...]) } ?? String(relative)
        return "\(root)/packages/alphatab/test/\(dir)__snapshots__/\(name).ts.snap"
    }

    /// The `@Suite("...")` names enclosing the declaration on 1-based `line`, outermost first. Generated
    /// code indents each nesting level, so the enclosing suite is the nearest `@Suite` above with less indent.
    static func suiteNames(_ lines: [Substring], line: Int) -> [String] {
        guard line >= 1, line <= lines.count else {
            return []
        }
        var want = _indent(lines[line - 1])
        var names: [String] = []
        var i = line - 2
        while i >= 0, want > 0 {
            let text = lines[i]
            let indent = _indent(text)
            if indent < want, let name = _suiteName(text.dropFirst(indent)) {
                names.insert(name, at: 0)
                want = indent
            }
            i -= 1
        }
        return names
    }

    private static func _sourceLines(_ path: String) throws -> [Substring] {
        if let cached = _sources[path] {
            return cached
        }
        let lines = try String(contentsOfFile: path, encoding: .utf8).split(separator: "\n", omittingEmptySubsequences: false)
        _sources[path] = lines
        return lines
    }

    private static func _indent(_ text: Substring) -> Int {
        return text.prefix { $0 == " " }.count
    }

    /// `@Suite("name")` -> `name`, with the Swift string escapes the printer writes undone.
    private static func _suiteName(_ text: Substring) -> String? {
        let prefix = "@Suite(\""
        guard text.hasPrefix(prefix), let end = text.range(of: "\")", options: .backwards) else {
            return nil
        }
        return _unescape(text[text.index(text.startIndex, offsetBy: prefix.count)..<end.lowerBound])
    }

    private static func _unescape(_ s: Substring) -> String {
        var out = ""
        var it = s.makeIterator()
        while let c = it.next() {
            guard c == "\\", let e = it.next() else {
                out.append(c)
                continue
            }
            switch e {
            case "n": out.append("\n")
            case "t": out.append("\t")
            case "r": out.append("\r")
            case "0": out.append("\0")
            case "u":
                var hex = ""
                while let h = it.next(), h != "}" {
                    if h != "{" {
                        hex.append(h)
                    }
                }
                if let v = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(v) {
                    out.unicodeScalars.append(scalar)
                }
            default: out.append(e)
            }
        }
        return out
    }
}

@Suite("Snapshot")
struct SnapshotTests {
    private static let source: [Substring] = """
    @Suite("Outer")
    final class Outer {
        @Suite("first \\"quoted\\"")
        final class First {
            @Test("a")
            func a() async throws {}
        }
        @Suite("second")
        final class Second {
            @Test("b")
            func b() async throws {}
        }
        @Test("top")
        func top() async throws {}
    }
    """.split(separator: "\n", omittingEmptySubsequences: false)

    @Test("suite names come from the enclosing @Suite lines, skipping closed siblings")
    func suiteNames() {
        #expect(Snapshot.suiteNames(SnapshotTests.source, line: 5) == ["Outer", "first \"quoted\""])
        #expect(Snapshot.suiteNames(SnapshotTests.source, line: 11) == ["Outer", "second"])
        #expect(Snapshot.suiteNames(SnapshotTests.source, line: 14) == ["Outer"])
    }

    @Test("snapshot path maps the generated test file to the vitest .snap file")
    func snapshotPath() {
        #expect(
            Snapshot.snapshotPath(forTestFile: "/r/packages/swift/Tests/AlphaTabTests/Generated/importer/AlphaTexLexer.test.swift")
                == "/r/packages/alphatab/test/importer/__snapshots__/AlphaTexLexer.test.ts.snap"
        )
        #expect(
            Snapshot.snapshotPath(forTestFile: "/r/packages/swift/Tests/AlphaTabTests/Generated/X.test.swift")
                == "/r/packages/alphatab/test/__snapshots__/X.test.ts.snap"
        )
        #expect(Snapshot.snapshotPath(forTestFile: "/r/packages/swift/Tests/AlphaTabTests/Runtime/X.swift") == nil)
    }

    @Test("snapshot keys count per name and hint, as vitest")
    func useSnapshotValue() {
        let base = "SnapshotTests > counters \(UUID())"
        #expect(Snapshot.useSnapshotValue(base, "") == "\(base) 1")
        #expect(Snapshot.useSnapshotValue(base, "") == "\(base) 2")
        #expect(Snapshot.useSnapshotValue(base, "lexer-diagnostics") == "\(base) > lexer-diagnostics 1")
        #expect(Snapshot.useSnapshotValue(base, "") == "\(base) 3")
    }
}
