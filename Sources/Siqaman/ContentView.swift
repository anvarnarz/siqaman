import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(Model.self) private var model
    var showAbout: () -> Void = {}

    var body: some View {
        ZStack {
            switch model.screen {
            case .home: HomeView(showAbout: showAbout)
            case .compose(let urls): ComposeView(items: urls)
            case .working(let title, let file): WorkingView(title: title, file: file)
            case .password(let url, let retry): PasswordView(archive: url, retry: retry)
            case .done(let title, let urls): DoneView(title: title, outputs: urls)
            case .failed(let message): FailedView(message: message)
            }
        }
        .padding(.horizontal, 28).padding(.top, 36).padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BrandBackground())
        .foregroundStyle(Theme.text)
        .tint(Theme.accent)
        .animation(.easeOut(duration: 0.32), value: model.screen)
    }
}

/// Large line icon in a softly lit tile, used at the top of each state.
private struct Badge: View {
    let symbol: String
    var color: Color = Theme.accentInk
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 26, weight: .regular))
            .foregroundStyle(color)
            .frame(width: 64, height: 64)
            .card(radius: 16)
            .background(Circle().fill(color.opacity(0.25)).blur(radius: 24))
    }
}

private struct Heading: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(Theme.font(22, .semibold)).tracking(-0.2)
            Text(subtitle).font(Theme.font(14)).foregroundStyle(Theme.text2).lineLimit(1).truncationMode(.middle)
        }
    }
}

// MARK: - Home

private struct HomeView: View {
    @Environment(Model.self) private var model
    let showAbout: () -> Void
    @State private var targeted = false
    @AppStorage(Theme.darkModeKey) private var dark = false

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                Text("Siqaman").overline()
                Spacer()
                Button { dark.toggle(); Theme.applyAppearance(dark: dark) } label: {
                    Image(systemName: dark ? "sun.max" : "moon").font(.system(size: 14)).foregroundStyle(Theme.text3)
                }
                .buttonStyle(.plain).help(dark ? "Light mode" : "Dark mode")
                Button(action: showAbout) { Image(systemName: "info.circle").font(.system(size: 14)).foregroundStyle(Theme.text3) }
                    .buttonStyle(.plain).help("About Siqaman")
            }
            VStack(spacing: 14) {
                Image(systemName: targeted ? "arrow.down.circle" : "archivebox")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(Theme.accentInk)
                    .contentTransition(.symbolEffect(.replace))
                Text("Drop files here").font(Theme.font(22, .semibold)).tracking(-0.2)
                Text("Files are compressed · ZIP, RAR and 7z are extracted")
                    .font(Theme.font(13)).foregroundStyle(Theme.text2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(targeted ? Theme.accentSoft : Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(targeted ? Theme.accent : Theme.dash, style: StrokeStyle(lineWidth: 1.5, dash: [6, 6])))
            .animation(.easeOut(duration: 0.18), value: targeted)
            .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
                Task {
                    var urls: [URL] = []
                    for p in providers {
                        if let data = try? await p.loadItem(forTypeIdentifier: UTType.fileURL.identifier) as? Data,
                           let u = URL(dataRepresentation: data, relativeTo: nil) { urls.append(u) }
                    }
                    model.open(urls)
                }
                return true
            }
            HStack {
                Text("Right-click in Finder → Services").font(Theme.mono(11)).foregroundStyle(Theme.text3)
                Spacer()
                Button("Choose files") { model.chooseFiles() }.buttonStyle(SecondaryButton())
            }
        }
    }
}

// MARK: - Compose

private struct ComposeView: View {
    @Environment(Model.self) private var model
    let items: [URL]
    @State private var protect = false
    @State private var password = ""
    @State private var confirm = ""

    private var mismatch: Bool { protect && !confirm.isEmpty && password != confirm }
    private var canGo: Bool { !protect || (!password.isEmpty && password == confirm) }

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(nsImage: NSWorkspace.shared.icon(forFiles: items.map(\.path)) ?? NSWorkspace.shared.icon(forFile: items[0].path))
                    .resizable().frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(items.count == 1 ? items[0].lastPathComponent : "\(items.count) items")
                        .font(Theme.font(16, .semibold)).lineLimit(1).truncationMode(.middle)
                    Text(items[0].deletingLastPathComponent().path)
                        .font(Theme.mono(11)).foregroundStyle(Theme.text3).lineLimit(1).truncationMode(.head)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Format").overline()
                Segmented(options: [("ZIP", Archiver.Format.zip), ("7z", .sevenZip)], selection: $model.format)
                Text("Compression").overline().padding(.top, 4)
                Segmented(options: Archiver.Level.allCases.map { ($0.title, $0) }, selection: $model.level)
            }

            VStack(spacing: 10) {
                HStack {
                    Label("Protect with password", systemImage: "lock").font(Theme.font(14, .medium))
                    Spacer()
                    Toggle("Protect with password", isOn: $protect.animation(.easeOut(duration: 0.18))).labelsHidden().toggleStyle(.switch)
                }
                if protect {
                    BrandSecureField(placeholder: "Password", text: $password, autofocus: true)
                    BrandSecureField(placeholder: "Confirm password", text: $confirm, error: mismatch)
                    if model.format == .sevenZip {
                        HStack {
                            Text("Encrypt file names").font(Theme.font(13)).foregroundStyle(Theme.text2)
                            Spacer()
                            Toggle("Encrypt file names", isOn: $model.encryptNames).labelsHidden().toggleStyle(.switch).controlSize(.small)
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .card()

            Spacer(minLength: 0)
            HStack {
                if mismatch {
                    Text("Passwords don’t match").font(Theme.font(12)).foregroundStyle(Theme.danger)
                } else if protect {
                    Text("AES-256").font(Theme.mono(11)).foregroundStyle(Theme.text3)
                }
                Spacer()
                Button("Cancel") { model.screen = .home }.buttonStyle(SecondaryButton()).keyboardShortcut(.cancelAction)
                Button("Compress") { model.startCompress(items, password: protect ? password : "") }
                    .buttonStyle(PrimaryButton()).keyboardShortcut(.defaultAction).disabled(!canGo)
            }
        }
    }
}

// MARK: - Working

private struct WorkingView: View {
    @Environment(Model.self) private var model
    let title: String
    let file: String

    var body: some View {
        VStack(spacing: 20) {
            Badge(symbol: title == "Compressing" ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
            Heading(title: title, subtitle: file)
            VStack(spacing: 8) {
                GeometryReader { geo in
                    Capsule().fill(Theme.surfaceRaised)
                        .overlay(alignment: .leading) {
                            Capsule().fill(Theme.wave).frame(width: max(6, geo.size.width * model.progress))
                                .shadow(color: Theme.accent.opacity(0.5), radius: 6)
                                .animation(.easeOut(duration: 0.18), value: model.progress)
                        }
                }
                .frame(height: 6)
                Text("\(Int(model.progress * 100))%").font(Theme.mono(12)).foregroundStyle(Theme.text2)
            }
            Button("Cancel") { model.cancel() }.buttonStyle(SecondaryButton()).keyboardShortcut(.cancelAction)
        }
        .frame(maxWidth: 320)
    }
}

// MARK: - Password

private struct PasswordView: View {
    @Environment(Model.self) private var model
    let archive: URL
    let retry: Bool
    @State private var password = ""

    var body: some View {
        VStack(spacing: 18) {
            Badge(symbol: "lock")
            Heading(title: "Password required", subtitle: "“\(archive.lastPathComponent)” is encrypted")
            VStack(alignment: .leading, spacing: 6) {
                BrandSecureField(placeholder: "Password", text: $password, error: retry, autofocus: true, onSubmit: submit)
                if retry { Text("Wrong password, try again").font(Theme.font(12)).foregroundStyle(Theme.danger) }
            }
            HStack {
                Button("Skip") { model.skipArchive() }.buttonStyle(SecondaryButton()).keyboardShortcut(.cancelAction)
                Button("Extract", action: submit).buttonStyle(PrimaryButton()).keyboardShortcut(.defaultAction).disabled(password.isEmpty)
            }
        }
        .frame(maxWidth: 300)
    }

    private func submit() { if !password.isEmpty { model.submitPassword(password) } }
}

// MARK: - Done / Failed

private struct DoneView: View {
    @Environment(Model.self) private var model
    let title: String
    let outputs: [URL]

    var body: some View {
        VStack(spacing: 20) {
            Badge(symbol: "checkmark", color: Theme.success)
            Heading(title: title, subtitle: outputs.count == 1 ? outputs[0].lastPathComponent : "\(outputs.count) items")
            HStack {
                Button("Show in Finder") { model.reveal(outputs) }.buttonStyle(SecondaryButton())
                Button("Done") { model.screen = .home }.buttonStyle(PrimaryButton()).keyboardShortcut(.defaultAction)
            }
        }
    }
}

private struct FailedView: View {
    @Environment(Model.self) private var model
    let message: String

    var body: some View {
        VStack(spacing: 18) {
            Badge(symbol: "exclamationmark.triangle", color: Theme.danger)
            Text("Something went wrong").font(Theme.font(22, .semibold))
            ScrollView { Text(message).font(Theme.mono(12)).foregroundStyle(Theme.text2).textSelection(.enabled) }
                .frame(maxHeight: 80)
            Button("OK") { model.screen = .home }.buttonStyle(PrimaryButton()).keyboardShortcut(.defaultAction)
        }
    }
}

// MARK: - About

struct AboutView: View {
    static let telegram = URL(string: "https://t.me/ertagakech")!
    static var logoURL = Bundle.main.url(forResource: "ertagakech-logo", withExtension: "svg")
    @State private var hover = false

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 112, height: 112)
                .shadow(color: Theme.accent.opacity(0.35), radius: 24)
            Text("Siqaman").font(Theme.font(26, .bold)).tracking(-0.4).padding(.top, 14)
            Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")")
                .font(Theme.mono(11)).foregroundStyle(Theme.text3).padding(.top, 4)
            Text("ZIP, RAR and 7z for your Mac")
                .font(Theme.font(13)).foregroundStyle(Theme.text2).padding(.top, 10)

            Rectangle().fill(Theme.divider).frame(height: 1).padding(.vertical, 22)

            Text("Created by").overline()
            Text("Anvar Narzullaev").font(Theme.font(17, .semibold)).padding(.top, 6)

            Link(destination: Self.telegram) {
                VStack(spacing: 10) {
                    if let logo = Self.logoURL.flatMap(NSImage.init(contentsOf:)) {
                        // the wordmark ships white; render it as a template so it follows the text color
                        Image(nsImage: logo).renderingMode(.template).resizable().aspectRatio(contentMode: .fit).frame(height: 22)
                            .foregroundStyle(Theme.text)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "paperplane")
                        Text("t.me/ertagakech")
                    }
                    .font(Theme.mono(12))
                    .foregroundStyle(hover ? Theme.text : Theme.text2)
                }
                .padding(.horizontal, 22).padding(.vertical, 16)
                .card()
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.accent.opacity(hover ? 0.5 : 0)))
            }
            .buttonStyle(.plain)
            .onHover { hover = $0 }
            .animation(.easeOut(duration: 0.12), value: hover)
            .padding(.top, 16)
            .help("Open Ertaga kech on Telegram")
        }
        .padding(32)
        .frame(width: 360)
        .background(BrandBackground())
        .foregroundStyle(Theme.text)
    }
}
