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
            VStack(alignment: .leading, spacing: 14) {
                if isLocked {
                    banner(.locked)
                }
                if !helperInstalled {
                    banner(.setup)
                }

                sitesSection
                appsSection
            }
            .padding(16)
        }
    }

    // MARK: - Sections

    private var sitesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Sites", count: sites.count)

            HStack(spacing: 6) {
                TextField("example.com", text: $newDomain)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .onSubmit(addSite)
                    .disabled(isLocked)
                Button("Add", action: addSite)
                    .controlSize(.small)
                    .disabled(isLocked || cleanedDomain.isEmpty)
            }

            if sites.isEmpty {
                emptyHint("No blocked sites yet")
            } else {
                groupedList(sites) { siteRow($0) }
            }
        }
    }

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Apps", count: apps.count)

            Button {
                pickApp()
            } label: {
                Label("Add App…", systemImage: "plus")
            }
            .controlSize(.small)
            .disabled(isLocked)

            if apps.isEmpty {
                emptyHint("No blocked apps yet")
            } else {
                groupedList(apps) { appRow($0) }
            }
        }
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(.secondary)
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.15), in: Capsule())
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func groupedList<T: Identifiable, RowContent: View>(
        _ items: [T],
        @ViewBuilder row: @escaping (T) -> RowContent
    ) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                if idx > 0 {
                    Divider().padding(.leading, 10)
                }
                row(item)
            }
        }
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Banners

    enum BannerKind { case locked, setup }

    @ViewBuilder
    private func banner(_ kind: BannerKind) -> some View {
        switch kind {
        case .locked:
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.tint)
                Text("Locked during focus")
                    .font(.subheadline)
                Spacer()
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        case .setup:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Site blocking needs setup")
                        .font(.subheadline.weight(.semibold))
                }
                Text("Run once in Terminal:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("bash setup-sudoers.sh")
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                Button("Re-check") {
                    helperInstalled = HostsManager().isInstalled
                }
                .controlSize(.small)
                .padding(.top, 2)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func emptyHint(_ text: String) -> some View {
        HStack {
            Spacer()
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 14)
        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Rows

    private func siteRow(_ site: BlockedSite) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { site.enabled },
                set: { site.enabled = $0; try? ctx.save() }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .disabled(isLocked)

            Text(site.domain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(isLocked ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.middle)

            Button {
                ctx.delete(site)
                try? ctx.save()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(isLocked)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private func appRow(_ app: BlockedApp) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { app.enabled },
                set: { app.enabled = $0; try? ctx.save() }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .disabled(isLocked)

            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                    .lineLimit(1)
                Text(app.bundleID)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(isLocked ? .secondary : .primary)

            Button {
                ctx.delete(app)
                try? ctx.save()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(isLocked)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
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
