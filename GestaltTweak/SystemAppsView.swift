import SwiftUI

private struct SystemApp: Identifiable {
    let name: String
    let bundleID: String

    var id: String { bundleID }
}

private enum SystemAppLauncher {
    static func open(bundleID: String) -> Bool {
        guard let workspaceClass = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
              let workspace = workspaceClass.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() as? NSObject else {
            return false
        }
        let selector = NSSelectorFromString("openApplicationWithBundleID:")
        guard workspace.responds(to: selector) else { return false }
        return workspace.perform(selector, with: bundleID) != nil
    }
}

struct SystemAppsView: View {
    @State private var apps: [SystemApp] = []
    @State private var isLoading = true
    @State private var customBundleID = ""
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("HouseArrest System Apps") {
                if isLoading {
                    ProgressView("Finding apps...")
                } else if apps.isEmpty {
                    Text("No com.apple apps were found.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(apps) { app in
                    Button { open(app.bundleID) } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name)
                                Text(app.bundleID).font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "app.fill").foregroundStyle(Color.accentColor)
                        }
                    }
                    .foregroundStyle(.primary)
                    }
                }
            }

            Section("Custom Bundle ID") {
                TextField("com.apple.example", text: $customBundleID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Open App", systemImage: "arrow.up.forward.app") {
                    open(customBundleID)
                }
                .disabled(customBundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } footer: {
                Text("Hidden or protected apps may refuse to open. Use the app's bundle identifier.")
            }
        }
        .navigationTitle("System Apps")
        .navigationBarTitleDisplayMode(.large)
        .listStyle(.insetGrouped)
        .task { loadApps() }
        .refreshable { loadApps() }
        .alert("Could Not Open App", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func open(_ bundleID: String) {
        let identifier = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !identifier.isEmpty, !SystemAppLauncher.open(bundleID: identifier) else {
            if identifier.isEmpty { errorMessage = "Enter a bundle identifier first." }
            else { errorMessage = "The system refused to open \(identifier)." }
            return
        }
    }

    private func loadApps() {
        isLoading = true
        Task {
            do {
                let result = try await Self.findSystemApps()
                apps = result
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private nonisolated static func findSystemApps() async throws -> [SystemApp] {
        try await Task.detached(priority: .userInitiated) {
            try HouseArrestService.list(HouseArrestService.applicationsRoot)
                .filter { $0.isDirectory && $0.name.hasPrefix("com.apple.") }
                .map {
                    let bundleID = $0.name
                    let shortName = String(bundleID.dropFirst("com.apple.".count))
                    return SystemApp(name: shortName.isEmpty ? bundleID : shortName, bundleID: bundleID)
                }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }.value
    }
}