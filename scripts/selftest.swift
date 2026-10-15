// Engine self-test: swiftc -parse-as-library -enable-bare-slash-regex Sources/Siqaman/Archiver.swift scripts/selftest.swift
import Foundation

@main struct SelfTest {
    static func main() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("siqaman-selftest-\(UUID().uuidString)")
        let src = root.appendingPathComponent("Docs")
        try fm.createDirectory(at: src.appendingPathComponent("sub"), withIntermediateDirectories: true)
        try "hello".write(to: src.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try "world".write(to: src.appendingPathComponent("sub/b.txt"), atomically: true, encoding: .utf8)
        try "junk".write(to: src.appendingPathComponent(".DS_Store"), atomically: true, encoding: .utf8)
        defer { try? fm.removeItem(at: root) }

        for format in Archiver.Format.allCases {
            let arc = try await Archiver.compress([src], format: format, level: .balanced, password: "s3cret", encryptNames: true,
                                                  task: ProcessBox()) { _ in }
            check(arc.lastPathComponent == "Docs.\(format.rawValue)", arc.path)
            for bad in [nil, "nope"] as [String?] {
                do { _ = try await Archiver.extract(arc, password: bad, task: ProcessBox()) { _ in }; fatalError("\(format) opened with \(bad ?? "no password")") }
                catch Archiver.Failure.wrongPassword {}
            }
            let left = try fm.contentsOfDirectory(atPath: root.path)
            check(left.count == 2, "failed extraction left files: \(left)")
            let out = try await Archiver.extract(arc, password: "s3cret", task: ProcessBox()) { _ in }
            check(out.lastPathComponent == "Docs 2", out.path) // lifted single folder, unique name
            check(try String(contentsOf: out.appendingPathComponent("sub/b.txt"), encoding: .utf8) == "world", "content")
            check(!fm.fileExists(atPath: out.appendingPathComponent(".DS_Store").path))
            try fm.removeItem(at: out); try fm.removeItem(at: arc)
            print("✓ \(format.rawValue): password, wrong password, unwrap")
        }

        // tar.gz → both layers peeled
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        p.arguments = ["-czf", "Docs.tar.gz", "Docs"]; p.currentDirectoryURL = root
        try p.run(); p.waitUntilExit()
        let out = try await Archiver.extract(root.appendingPathComponent("Docs.tar.gz"), password: nil, task: ProcessBox()) { _ in }
        check(try String(contentsOf: out.appendingPathComponent("a.txt"), encoding: .utf8) == "hello", out.path)
        print("✓ tar.gz unwrapped to \(out.lastPathComponent)")
        // wildcard names are literal; corrupt archive in a misleading folder is not "wrong password"
        let odd = root.appendingPathComponent("my encrypted archive Wrong password")
        try fm.createDirectory(at: odd, withIntermediateDirectories: true)
        try "1".write(to: odd.appendingPathComponent("a*.txt"), atomically: true, encoding: .utf8)
        try "2".write(to: odd.appendingPathComponent("ab.txt"), atomically: true, encoding: .utf8)
        let star = try await Archiver.compress([odd.appendingPathComponent("a*.txt")], format: .zip, level: .fast, password: nil, encryptNames: false, task: ProcessBox()) { _ in }
        let starOut = try await Archiver.extract(star, password: nil, task: ProcessBox()) { _ in }
        check(starOut.lastPathComponent == "a* 2.txt" || starOut.lastPathComponent.hasPrefix("a*"), "wildcard expanded: \(starOut.lastPathComponent)")
        try Data("PK\u{03}\u{04}garbage-not-a-zip".utf8).write(to: odd.appendingPathComponent("bad.zip"))
        do { _ = try await Archiver.extract(odd.appendingPathComponent("bad.zip"), password: nil, task: ProcessBox()) { _ in }; check(false, "corrupt zip opened") }
        catch Archiver.Failure.wrongPassword { check(false, "corrupt zip misread as wrong password") } catch {}
        print("✓ literal wildcard names, corrupt ≠ wrong password")
        print("ALL OK")
    }
}

func check(_ ok: Bool, _ msg: String = "") { if !ok { print("✗ \(msg)"); exit(1) } }
