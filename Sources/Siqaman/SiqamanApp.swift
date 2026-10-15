import AppKit
import SwiftUI

@main
struct SiqamanApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    // The window is AppKit-owned (see AppDelegate.showWindow): a SwiftUI Window scene
    // is not opened when Finder launches the app just to run a service.
    var body: some Scene {
        Settings { EmptyView() }
            .commands { CommandGroup(replacing: .appInfo) { Button("About Siqaman") { delegate.showAbout() } } }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = Model()
    private var window: NSWindow?
    private var aboutWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Theme.registerFonts()
        Theme.applyAppearance()
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        showWindow()
    }

    func showAbout() {
        if aboutWindow == nil {
            let w = NSWindow(contentRect: .zero, styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.isReleasedWhenClosed = false
            w.backgroundColor = Theme.windowBackground
            w.contentView = NSHostingView(rootView: AboutView())
            w.center()
            aboutWindow = w
        }
        aboutWindow?.makeKeyAndOrderFront(nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool { showWindow(); return true }

    func showWindow() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 400),
                             styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView], backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.isReleasedWhenClosed = false
            w.title = "Siqaman"
            w.backgroundColor = Theme.windowBackground
            w.contentView = NSHostingView(rootView: ContentView(showAbout: { [weak self] in self?.showAbout() })
                .environment(model).frame(width: 440, height: 400))
            w.center()
            window = w
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// Double-click / Open With on an archive.
    func application(_ application: NSApplication, open urls: [URL]) { showWindow(); model.open(urls) }

    // MARK: Finder services (right-click → Services)

    @objc func compressFiles(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let urls = fileURLs(pboard)
        guard !urls.isEmpty, !model.isBusy else { return }
        showWindow()
        model.screen = .compose(urls)
    }

    @objc func extractFiles(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let urls = fileURLs(pboard).filter(Archiver.isArchive)
        guard !urls.isEmpty, !model.isBusy else { return }
        showWindow()
        model.extract(urls)
    }

    private func fileURLs(_ pboard: NSPasteboard) -> [URL] {
        pboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
    }
}
