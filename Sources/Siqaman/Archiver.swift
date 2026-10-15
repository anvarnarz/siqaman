import Foundation

/// Thin wrapper over the bundled 7-Zip (`7zz`). Passwords go through stdin, never argv.
enum Archiver {
    static let archiveExtensions: Set<String> = ["zip", "zipx", "rar", "7z", "tar", "gz", "tgz", "bz2", "tbz", "tbz2", "xz", "txz", "zst", "lz", "lzma", "cab", "iso", "arj", "z", "001"]

    enum Format: String, CaseIterable, Identifiable { case zip, sevenZip = "7z"; var id: String { rawValue } }
    enum Level: Int, CaseIterable, Identifiable {
        case fast = 1, balanced = 5, smallest = 9
        var id: Int { rawValue }
        var title: String { switch self { case .fast: "Fast"; case .balanced: "Balanced"; case .smallest: "Smallest" } }
    }

    enum Failure: LocalizedError {
        case wrongPassword, cancelled, failed(String)
        var errorDescription: String? {
            switch self {
            case .wrongPassword: "Wrong password."
            case .cancelled: "Cancelled."
            case .failed(let msg): msg
            }
        }
    }

    static var binary: URL {
        Bundle.main.url(forAuxiliaryExecutable: "7zz") ?? URL(fileURLWithPath: "/opt/homebrew/bin/7zz")
    }

    static func isArchive(_ url: URL) -> Bool { archiveExtensions.contains(url.pathExtension.lowercased()) }

    /// "name.ext" -> "name 2.ext" until free.
    static func unique(_ url: URL) -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return url }
        let dir = url.deletingLastPathComponent(), ext = url.pathExtension, base = url.deletingPathExtension().lastPathComponent
        for i in 2... {
            let candidate = dir.appendingPathComponent(ext.isEmpty ? "\(base) \(i)" : "\(base) \(i).\(ext)")
            if !fm.fileExists(atPath: candidate.path) { return candidate }
        }
        fatalError("unreachable")
    }

    // MARK: - Compress

    static func compress(_ items: [URL], format: Format, level: Level, password: String?, encryptNames: Bool,
                         task: ProcessBox, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let parent = items[0].deletingLastPathComponent()
        let base = items.count == 1 ? items[0].deletingPathExtension().lastPathComponent : "Archive"
        let out = unique(parent.appendingPathComponent(base).appendingPathExtension(format.rawValue))
        var args = ["a", "-t\(format.rawValue)", "-mx=\(level.rawValue)", "-bsp1", "-y", "-spd", "-xr!.DS_Store", "-xr!__MACOSX"] // -spd: names like "a*.txt" are literal
        if let password, !password.isEmpty {
            args.append("-p") // value read from stdin
            if format == .zip { args.append("-mem=AES256") }
            if format == .sevenZip && encryptNames { args.append("-mhe=on") }
        }
        args += ["--", out.path]
        args += items.map { $0.deletingLastPathComponent() == parent ? $0.lastPathComponent : $0.path }
        do {
            try await run(args, cwd: parent, password: password, task: task, progress: progress)
        } catch {
            try? FileManager.default.removeItem(at: out) // no half-written archives left behind
            throw error
        }
        return out
    }

    // MARK: - Extract

    /// Extracts next to the archive. A single top-level item is lifted out; a lone .tar is unpacked too.
    static func extract(_ archive: URL, password: String?, task: ProcessBox,
                        progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let fm = FileManager.default
        let parent = archive.deletingLastPathComponent()
        var stem = archive.deletingPathExtension().lastPathComponent
        if stem.lowercased().hasSuffix(".tar") { stem = String(stem.dropLast(4)) }
        // Extract into a hidden staging dir so naming below never collides with half-done output.
        let staging = parent.appendingPathComponent(".siqaman-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: staging) }
        try await run(["x", archive.path, "-o\(staging.path)", "-y", "-bsp1"], cwd: parent, password: password ?? "", task: task, progress: progress)
        var contents = (try? fm.contentsOfDirectory(at: staging, includingPropertiesForKeys: nil)) ?? []
        if contents.count == 1, contents[0].pathExtension.lowercased() == "tar" {
            let tar = contents[0]
            try await run(["x", tar.path, "-o\(staging.path)", "-y", "-bsp1"], cwd: staging, password: "", task: task, progress: progress)
            try fm.removeItem(at: tar)
            contents = (try? fm.contentsOfDirectory(at: staging, includingPropertiesForKeys: nil)) ?? []
        }
        propagateQuarantine(from: archive, into: staging)
        let (from, name) = contents.count == 1 ? (contents[0], contents[0].lastPathComponent) : (staging, stem)
        let dest = unique(parent.appendingPathComponent(name))
        try fm.moveItem(at: from, to: dest)
        return dest
    }

    /// Like Archive Utility: files from a downloaded archive stay quarantined, so Gatekeeper still checks them.
    private static func propagateQuarantine(from archive: URL, into dir: URL) {
        let key = "com.apple.quarantine"
        var buf = [UInt8](repeating: 0, count: 1024)
        let n = getxattr(archive.path, key, &buf, buf.count, 0, 0)
        guard n > 0 else { return }
        var paths = [dir.path]
        if let e = FileManager.default.enumerator(atPath: dir.path) { paths += e.compactMap { "\(dir.path)/\($0 as! String)" } }
        for path in paths { setxattr(path, key, buf, n, 0, XATTR_NOFOLLOW) }
    }

    // MARK: - Process

    private static func run(_ args: [String], cwd: URL, password: String?, task: ProcessBox,
                            progress: @escaping @Sendable (Double) -> Void) async throws {
        let p = Process()
        p.executableURL = binary
        p.arguments = args
        p.currentDirectoryURL = cwd
        let stdin = Pipe(), stdout = Pipe(), stderr = Pipe()
        p.standardInput = stdin; p.standardOutput = stdout; p.standardError = stderr
        let log = LogBuffer()
        stdout.fileHandleForReading.readabilityHandler = { h in
            let s = String(decoding: h.availableData, as: UTF8.self)
            log.append(s)
            // -bsp1 prints "  42% 3 + file" frames separated by backspaces
            if let m = s.matches(of: /(\d{1,3})%/).last, let v = Double(m.1) { progress(min(v, 100) / 100) }
        }
        stderr.fileHandleForReading.readabilityHandler = { h in log.append(String(decoding: h.availableData, as: UTF8.self)) }

        let status: Int32 = try await withCheckedThrowingContinuation { cont in
            p.terminationHandler = { cont.resume(returning: $0.terminationStatus) }
            do { try p.run() } catch { cont.resume(throwing: error); return }
            task.attach(p)
            if let password { stdin.fileHandleForWriting.write(Data((password + "\n").utf8)) }
            try? stdin.fileHandleForWriting.close()
        }
        stdout.fileHandleForReading.readabilityHandler = nil
        stderr.fileHandleForReading.readabilityHandler = nil
        task.attach(nil)
        if task.cancelled { throw Failure.cancelled }
        guard status == 0 else {
            let text = log.text
            // stdout echoes paths, so only trust 7-Zip's own error lines
            let markers = ["ERROR: Wrong password", "ERROR: Data Error in encrypted file", "Cannot open encrypted archive"]
            if text.split(separator: "\n").contains(where: { line in markers.contains { line.hasPrefix($0) } }) { throw Failure.wrongPassword }
            let lines = text.split(separator: "\n").filter { $0.contains("ERROR") || $0.contains("Error") }
            throw Failure.failed(lines.isEmpty ? "7-Zip failed (code \(status))." : lines.joined(separator: "\n"))
        }
        progress(1)
    }
}

/// Holds the running process so the UI can cancel it.
final class ProcessBox: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var _cancelled = false
    var cancelled: Bool { lock.withLock { _cancelled } }
    func cancel() { lock.withLock { _cancelled = true; process?.terminate() } }
    /// A cancel that landed before the process was attached still stops it.
    func attach(_ p: Process?) { lock.withLock { process = p; if _cancelled { p?.terminate() } } }
}

private final class LogBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var buf = ""
    func append(_ s: String) { lock.withLock { buf += s } }
    var text: String { lock.withLock { buf } }
}
