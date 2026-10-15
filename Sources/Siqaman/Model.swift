import AppKit
import Observation

@MainActor @Observable
final class Model {
    enum Screen: Equatable {
        case home
        case compose([URL])
        case working(title: String, file: String)
        case password(URL, retry: Bool)
        case done(String, [URL])
        case failed(String)
    }

    var screen: Screen = .home
    var progress = 0.0
    var format: Archiver.Format = .zip
    var level: Archiver.Level = .balanced
    var encryptNames = true

    private var box = ProcessBox()
    private var queue: [URL] = []      // archives still to extract
    private var outputs: [URL] = []    // results of the current batch

    /// Archives go straight to extraction; anything else opens the compress sheet.
    func open(_ urls: [URL]) {
        guard !urls.isEmpty, !isBusy else { return }
        NSApp.activate()
        if urls.allSatisfy(Archiver.isArchive) { extract(urls) } else { screen = .compose(urls) }
    }


    var isBusy: Bool { if case .working = screen { true } else { false } }

    func startCompress(_ items: [URL], password: String) {
        box = ProcessBox()
        progress = 0
        let name = items.count == 1 ? items[0].lastPathComponent : "\(items.count) items"
        screen = .working(title: "Compressing", file: name)
        let (box, format, level, names) = (box, format, level, encryptNames)
        Task {
            do {
                let out = try await Archiver.compress(items, format: format, level: level,
                                                      password: password.isEmpty ? nil : password, encryptNames: names,
                                                      task: box) { p in Task { @MainActor in self.progress = p } }
                screen = .done("Compressed", [out])
            } catch { finish(error) }
        }
    }

    func extract(_ archives: [URL]) {
        queue = archives
        outputs = []
        next(password: nil)
    }

    func submitPassword(_ password: String) { next(password: password) }

    func skipArchive() {
        queue.removeFirst()
        next(password: nil)
    }

    private func next(password: String?) {
        guard let archive = queue.first else {
            screen = outputs.isEmpty ? .home : .done("Extracted", outputs)
            return
        }
        box = ProcessBox()
        progress = 0
        screen = .working(title: "Extracting", file: archive.lastPathComponent)
        let box = box
        Task {
            do {
                let out = try await Archiver.extract(archive, password: password, task: box) { p in Task { @MainActor in self.progress = p } }
                outputs.append(out)
                queue.removeFirst()
                next(password: nil)
            } catch Archiver.Failure.wrongPassword {
                screen = .password(archive, retry: password != nil)
            } catch { queue = []; finish(error) }
        }
    }

    func cancel() { box.cancel() }

    private func finish(_ error: Error) {
        if case Archiver.Failure.cancelled = error { screen = .home } else { screen = .failed(error.localizedDescription) }
    }

    func reveal(_ urls: [URL]) { NSWorkspace.shared.activateFileViewerSelecting(urls) }

    func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.prompt = "Choose"
        if panel.runModal() == .OK { open(panel.urls) }
    }
}
