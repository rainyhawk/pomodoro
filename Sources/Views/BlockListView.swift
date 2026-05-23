import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct BlockListView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(TimerEngine.self) private var engine
    @Query(sort: \BlockedSite.createdAt) private var sites: [BlockedSite]
    @Query(sort: \BlockedApp.name) private var apps: [BlockedApp]

    @State private var newDomain: String = ""
    @State private var helperInstalled: Bool = HostsManager().isInstalled

    private var isLocked: Bool {
        engine.phase == .focus && engine.state != .idle
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if isLocked {
                    lockedBanner
                }
                if !helperInstalled {
                    setupBanner
                }

                section(title: "Sites") {
                    HStack {
                        TextField("youtube.com", text: $newDomain)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(addSite)
                            .disabled(isLocked)
                        Button("Add", action: addSite)
                            .disabled(isLocked || cleanedDomain.isEmpty)
                    }
                    if sites.isEmpty {
                        emptyHint("No blocked sites yet.")
                    } else {
                        ForEach(sites) { site in
                            siteRow(site)
                        }
                    }
                }

                section(title: "Apps") {
                    Button {
                        pickApp()
                    } label: {
                        Label("Add App…", systemImage: "plus")
                    }
                    .disabled(isLocked)
                    if apps.isEmpty {
                        emptyHint("No blocked apps yet.")
                    } else {
                        ForEach(apps) { app in
                            appRow(app)
                        }
                    }
                }
            }
            .padding()
        }
    }

    private var lockedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
            Text("Blocks are locked during focus.")
                .font(.subheadline)
            Spacer()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.15))
        .cornerRadius(8)
    }

    // MARK: - Sections

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
    }

    private var setupBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Site blocking needs a one-time setup", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
            Text("Run this once in Terminal:")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("bash ~/pomodoro/setup-sudoers.sh")
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
            Button("I've done it — re-check") {
                helperInstalled = HostsManager().isInstalled
            }
            .controlSize(.small)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.15))
        .cornerRadius(8)
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.vertical, 4)
    }

    // MARK: - Rows

    private func siteRow(_ site: BlockedSite) -> some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { site.enabled },
                set: { site.enabled = $0; try? ctx.save() }
            ))
            .labelsHidden()
            .disabled(isLocked)
            Text(site.domain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(isLocked ? .secondary : .primary)
            Button {
                ctx.delete(site)
                try? ctx.save()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .disabled(isLocked)
        }
    }

    private func appRow(_ app: BlockedApp) -> some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { app.enabled },
                set: { app.enabled = $0; try? ctx.save() }
            ))
            .labelsHidden()
            .disabled(isLocked)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                Text(app.bundleID)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(isLocked ? .secondary : .primary)
            Button {
                ctx.delete(app)
                try? ctx.save()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .disabled(isLocked)
        }
    }

    // MARK: - Actions

    private var cleanedDomain: String {
        var s = newDomain
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if let range = s.range(of: "://") {
            s = String(s[range.upperBound...])
        }
        if s.hasPrefix("www.") {
            s = String(s.dropFirst(4))
        }
        // Drop path, query, fragment, and any port — hosts file only takes hostnames.
        for sep in ["/", "?", "#", ":"] {
            if let i = s.firstIndex(of: Character(sep)) {
                s = String(s[..<i])
            }
        }
        return s
    }

    private func addSite() {
        let domain = cleanedDomain
        guard !domain.isEmpty else { return }
        if sites.contains(where: { $0.domain == domain }) {
            newDomain = ""
            return
        }
        ctx.insert(BlockedSite(domain: domain))
        try? ctx.save()
        newDomain = ""
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Block"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let bundle = Bundle(url: url)
        let bundleID = bundle?.bundleIdentifier ?? url.deletingPathExtension().lastPathComponent
        let name = (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent

        if apps.contains(where: { $0.bundleID == bundleID }) { return }
        ctx.insert(BlockedApp(bundleID: bundleID, name: name))
        try? ctx.save()
    }
}
