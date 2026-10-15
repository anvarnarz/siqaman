import SwiftUI
import UniformTypeIdentifiers

private let accent = LinearGradient(colors: [Color(red: 0.36, green: 0.30, blue: 0.95), Color(red: 0.62, green: 0.32, blue: 0.95)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing)

struct ContentView: View {
    @Environment(Model.self) private var model

    var body: some View {
        ZStack {
            switch model.screen {
            case .home: HomeView()
            case .compose(let urls): ComposeView(items: urls)
            case .working(let title, let file): WorkingView(title: title, file: file)
            case .password(let url, let retry): PasswordView(archive: url, retry: retry)
            case .done(let title, let urls): DoneView(title: title, outputs: urls)
            case .failed(let message): FailedView(message: message)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(duration: 0.35), value: model.screen)
        .tint(Color(red: 0.45, green: 0.32, blue: 0.95))
    }
}

// MARK: - Home

private struct HomeView: View {
    @Environment(Model.self) private var model
    @State private var targeted = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(targeted ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(targeted ? Color.accentColor : Color.secondary.opacity(0.35),
                                  style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                VStack(spacing: 12) {
                    Image(systemName: targeted ? "arrow.down.doc.fill" : "archivebox.fill")
                        .font(.system(size: 52, weight: .medium))
                        .foregroundStyle(accent)
                        .symbolEffect(.bounce, value: targeted)
                        .contentTransition(.symbolEffect(.replace))
                    Text("Drop files here").font(.title2.weight(.semibold))
                    Text("Files are compressed · ZIP, RAR and 7z are extracted")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
                Task {
                    var urls: [URL] = []
                    for p in providers {
                        if let url = try? await p.loadItem(forTypeIdentifier: UTType.fileURL.identifier) as? Data,
                           let u = URL(dataRepresentation: url, relativeTo: nil) { urls.append(u) }
                    }
                    model.open(urls)
                }
                return true
            }
            HStack {
                Label("Tip: right-click files in Finder → Services", systemImage: "cursorarrow.click.2")
                    .font(.caption).foregroundStyle(.tertiary)
                Spacer()
                Button("Choose Files…") { model.chooseFiles() }
                    .controlSize(.large)
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
    @FocusState private var focused: Bool

    private var mismatch: Bool { protect && !confirm.isEmpty && password != confirm }
    private var canGo: Bool { !protect || (!password.isEmpty && password == confirm) }

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(nsImage: NSWorkspace.shared.icon(forFiles: items.map(\.path)) ?? NSWorkspace.shared.icon(forFile: items[0].path))
                    .resizable().frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(items.count == 1 ? items[0].lastPathComponent : "\(items.count) items")
                        .font(.headline).lineLimit(1).truncationMode(.middle)
                    Text(items[0].deletingLastPathComponent().path)
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.head)
                }
            }

            Form {
                Picker("Format", selection: $model.format) {
                    Text("ZIP").tag(Archiver.Format.zip)
                    Text("7z").tag(Archiver.Format.sevenZip)
                }
                .pickerStyle(.segmented)
                Picker("Compression", selection: $model.level) {
                    ForEach(Archiver.Level.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Toggle("Protect with password", isOn: $protect.animation())
                if protect {
                    SecureField("Password", text: $password).focused($focused)
                    SecureField("Confirm", text: $confirm)
                    if model.format == .sevenZip { Toggle("Encrypt file names", isOn: $model.encryptNames) }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .padding(.horizontal, -20)
            .onChange(of: protect) { _, on in focused = on }

            HStack {
                if mismatch {
                    Label("Passwords don’t match", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.red)
                } else if protect {
                    Label("AES-256 encryption", systemImage: "lock.fill").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { model.screen = .home }.keyboardShortcut(.cancelAction)
                Button("Compress") { model.startCompress(items, password: protect ? password : "") }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canGo)
            }
            .controlSize(.large)
        }
    }
}

// MARK: - Working

private struct WorkingView: View {
    @Environment(Model.self) private var model
    let title: String
    let file: String

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: title == "Compressing" ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(accent)
                .symbolEffect(.pulse)
            VStack(spacing: 4) {
                Text(title).font(.title3.weight(.semibold))
                Text(file).font(.callout).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            GeometryReader { geo in
                Capsule().fill(.quaternary)
                    .overlay(alignment: .leading) {
                        Capsule().fill(accent).frame(width: max(8, geo.size.width * model.progress))
                            .animation(.easeOut(duration: 0.25), value: model.progress)
                    }
            }
            .frame(height: 8)
            Text("\(Int(model.progress * 100))%").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            Button("Cancel") { model.cancel() }.keyboardShortcut(.cancelAction).controlSize(.large)
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
    @State private var shake = 0
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(accent)
                .symbolEffect(.bounce, value: shake)
            VStack(spacing: 4) {
                Text("Password required").font(.title3.weight(.semibold))
                Text("“\(archive.lastPathComponent)” is encrypted.")
                    .font(.callout).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(submit)
            if retry {
                Label("Wrong password — try again", systemImage: "xmark.circle.fill").font(.caption).foregroundStyle(.red)
            }
            HStack {
                Button("Skip") { model.skipArchive() }.keyboardShortcut(.cancelAction)
                Button("Extract", action: submit).buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(password.isEmpty)
            }
            .controlSize(.large)
        }
        .frame(maxWidth: 300)
        .onAppear { focused = true; if retry { shake += 1 } }
    }

    private func submit() { if !password.isEmpty { model.submitPassword(password) } }
}

// MARK: - Done / Failed

private struct DoneView: View {
    @Environment(Model.self) private var model
    let title: String
    let outputs: [URL]
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white, .green)
                .symbolEffect(.bounce, value: appeared)
            VStack(spacing: 4) {
                Text(title).font(.title3.weight(.semibold))
                Text(outputs.count == 1 ? outputs[0].lastPathComponent : "\(outputs.count) items")
                    .font(.callout).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            HStack {
                Button("Show in Finder") { model.reveal(outputs) }
                Button("Done") { model.screen = .home }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
        }
        .onAppear { appeared = true }
    }
}

private struct FailedView: View {
    @Environment(Model.self) private var model
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 48)).foregroundStyle(.orange)
            Text("Something went wrong").font(.title3.weight(.semibold))
            ScrollView { Text(message).font(.callout).foregroundStyle(.secondary).textSelection(.enabled) }
                .frame(maxHeight: 90)
            Button("OK") { model.screen = .home }.buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.defaultAction)
        }
    }
}
