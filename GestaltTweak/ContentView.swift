//
//  ContentView.swift
//  GestaltTweak
//
//  Licensed under the MIT License. Portions derived from frs0n/GestaltEdit.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var viewModel: GestaltViewModel

    @State private var showsSettings = false

    var body: some View {
        Group {
            if GestaltAccess.isRunningSupportedOS() {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            hero

                            deviceCard

                            sectionTitle("Modules")
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: 14),
                                    GridItem(.flexible()),
                                ],
                                spacing: 14
                            ) {
                                featureCard(
                                    icon: "paintbrush",
                                    tint: .pink,
                                    title: "MobileGestalt",
                                    subtitle: "Flip flags, pick a subtype, rename"
                                ) {
                                    TweakWorkbench()
                                }
                                featureCard(
                                    icon: "square.and.pencil",
                                    tint: .blue,
                                    title: "Advanced Fields",
                                    subtitle: "Hand-edit any raw key"
                                ) {
                                    AdvancedGestaltEditor()
                                }
                                featureCard(
                                    icon: "archivebox",
                                    tint: .orange,
                                    title: "Backups",
                                    subtitle: "Snapshots you can roll back"
                                ) {
                                    BackupLibrary()
                                }
                                featureCard(
                                    icon: "photo.on.rectangle.angled",
                                    tint: .purple,
                                    title: "PosterBoard",
                                    subtitle: "Drop in wallpaper packs"
                                ) {
                                    PosterView()
                                }
                            }

                            sectionTitle("Actions")
                            HStack(spacing: 14) {
                                quickAction(
                                    icon: "bolt.fill",
                                    tint: .green,
                                    title: "Run Exploit"
                                ) {
                                    viewModel.runExploit()
                                }
                                quickAction(
                                    icon: "arrow.counterclockwise",
                                    tint: .red,
                                    title: "Respring"
                                ) {
                                    viewModel.respring()
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .background(Color(.systemGroupedBackground), ignoresSafeAreaEdges: .all)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showsSettings = true
                            } label: {
                                Image(systemName: "gear")
                            }
                        }
                    }
                    .sheet(isPresented: $showsSettings) {
                        SettingsView()
                    }
                }
                .task { viewModel.load() }
            } else {
                UnsupportedOSView()
            }
        }
        .overlay {
            if viewModel.isRespringing {
                NeoSpringView()
            }
        }
        .alert(item: $viewModel.notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var hero: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 58, height: 58)
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("GestaltTweak")
                    .font(.title2.weight(.bold))
                Text("Tame your system file")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var deviceCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "iphone")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.aiRegionProfile?.marketingName ?? "Current Device")
                    .font(.headline)
                Text("Build \(GestaltAccess.currentOSBuild())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if viewModel.plist == nil {
                if viewModel.isBusy || !viewModel.hasAttemptedLoad {
                    ProgressView()
                        .controlSize(.small)
                    Text("Reading...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Unavailable")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                        Button("Retry", action: viewModel.load)
                            .font(.caption)
                    }
                }
            } else {
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }
        }
        .padding(14)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .textCase(.uppercase)
            .kerning(0.8)
            .foregroundStyle(.secondary)
    }

    private func featureCard(
        icon: String,
        tint: Color,
        title: String,
        subtitle: String,
        @ViewBuilder destination: () -> some View
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(tint)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .padding(14)
            .background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    private func quickAction(
        icon: String,
        tint: Color,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(tint)
                    )
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct UnsupportedOSView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Unsupported OS Version")
                .font(.title2.weight(.semibold))
            Text("GestaltTweak supports only iOS and iPadOS 27 beta 1 through beta 4.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }
}

private struct TweakWorkbench: View {
    @EnvironmentObject private var viewModel: GestaltViewModel
    @State private var query = ""

    var body: some View {
        Group {
            if viewModel.plist != nil {
                workbenchContent
            } else {
                loadState
            }
        }
        .navigationTitle("MobileGestalt")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $query, prompt: "Filter tweaks")
        .refreshable { viewModel.load() }
        .safeAreaInset(edge: .bottom) {
            if viewModel.plist != nil {
                applyBar
            }
        }
    }

    private var workbenchContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                summaryCard

                deviceIdentityCard

                if !hasAnyResults {
                    ContentUnavailableView.search
                } else {
                    ForEach(GestaltTweakCategory.allCases) { category in
                        categoryCard(category)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var loadState: some View {
        VStack(spacing: 12) {
            if viewModel.isBusy || !viewModel.hasAttemptedLoad {
                ProgressView()
                    .controlSize(.large)
                Text("Reading MobileGestalt…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Unable to load MobileGestalt")
                    .font(.headline)
                Button("Retry", action: viewModel.load)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Summary

    private var summaryCard: some View {
        HStack(spacing: 16) {
            statBox(value: viewModel.activeTweaks.count, label: "Active", tint: .green)
            statBox(value: viewModel.stagedChangeCount, label: "Staged", tint: .orange)
            statBox(value: GestaltTweakCatalog.definitions.count, label: "Total", tint: .secondary)

            Spacer(minLength: 0)

            Image(systemName: "lock.doc")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
        )
    }

    private func statBox(value: Int, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(tint)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Device identity

    private var deviceIdentityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeader(icon: "iphone.gen3", title: "Device Identity", tint: .indigo)

            VStack(alignment: .leading, spacing: 8) {
                Text("Dynamic Island Subtype")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        subtypeChip(nil, title: "No Change")
                        ForEach(DynamicIslandOption.all) { option in
                            subtypeChip(option.subtype, title: "\(option.subtype) · \(option.title)")
                        }
                    }
                }
            }

            Divider()

            Toggle(isOn: $viewModel.changesModelName) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Custom Model Name")
                        .font(.subheadline.weight(.medium))
                    Text("Shown in Settings > General > About")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.accentColor)

            if viewModel.changesModelName {
                TextField("Model Name", text: $viewModel.modelName)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
            }
        }
        .padding(14)
        .background(cardBackground)
    }

    private func subtypeChip(_ value: Int?, title: String) -> some View {
        let selected = viewModel.dynamicIslandSubtype == value
        return Button {
            viewModel.dynamicIslandSubtype = value
        } label: {
            Text(title)
                .font(.footnote.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(selected ? Color.accentColor : Color(.tertiarySystemFill))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: Categories

    @ViewBuilder
    private func categoryCard(_ category: GestaltTweakCategory) -> some View {
        let definitions = GestaltTweakCatalog.definitions.filter { $0.category == category }
        let visible = filtered(definitions)
        let showAI = category == .region && aiRegionMatchesQuery
        let staged = visible.filter {
            viewModel.selectedTweaks.contains($0.id) || viewModel.removedTweaks.contains($0.id)
        }.count

        if !visible.isEmpty || showAI {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: categoryIcon(category))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(categoryTint(category))
                    Text(category.label)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if staged > 0 {
                        Text("\(staged) staged")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.orange))
                    }
                }
                .padding(.horizontal, 2)

                VStack(spacing: 10) {
                    if showAI {
                        aiRegionRow
                    }
                    ForEach(visible) { definition in
                        TweakCard(
                            definition: definition,
                            isOn: Binding(
                                get: { viewModel.isTweakEnabled(definition.id) },
                                set: { viewModel.setTweak(definition.id, enabled: $0) }
                            )
                        )
                    }
                }
            }
            .padding(12)
            .background(cardBackground)
        }
    }

    private var aiRegionRow: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Apple Intelligence")
                        .font(.body.weight(.semibold))
                    if viewModel.requiresForcedAIEnable {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .accessibilityLabel("High Risk")
                    }
                }
                if viewModel.requiresForcedAIEnable {
                    Text("Unsupported device: force enable with device identity spoofing. Face ID or system stability may be affected.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Spoofs the region and regulatory model to enable Apple Intelligence.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            Toggle("", isOn: Binding(
                get: { viewModel.aiRegionToggleState },
                set: { viewModel.setAIRegion(enabled: $0) }
            ))
            .labelsHidden()
            .tint(.accentColor)
        }
        .padding(12)
        .background(rowBackground)
    }

    private func filtered(_ definitions: [GestaltTweakDefinition]) -> [GestaltTweakDefinition] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return definitions }
        return definitions.filter {
            $0.title.localizedCaseInsensitiveContains(q) ||
            $0.detail.localizedCaseInsensitiveContains(q)
        }
    }

    private var aiRegionMatchesQuery: Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return true }
        return "apple intelligence".localizedCaseInsensitiveContains(q)
            || "region".localizedCaseInsensitiveContains(q)
    }

    private var hasAnyResults: Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return true }
        if aiRegionMatchesQuery { return true }
        return GestaltTweakCatalog.definitions.contains {
            $0.title.localizedCaseInsensitiveContains(q) ||
            $0.detail.localizedCaseInsensitiveContains(q)
        }
    }

    private func categoryIcon(_ category: GestaltTweakCategory) -> String {
        switch category {
        case .region: "globe.americas"
        case .display: "rectangle.3.group"
        case .hardware: "cpu"
        case .ipad: "ipad"
        case .internalFeatures: "flask"
        }
    }

    private func categoryTint(_ category: GestaltTweakCategory) -> Color {
        switch category {
        case .region: .blue
        case .display: .teal
        case .hardware: .orange
        case .ipad: .mint
        case .internalFeatures: .pink
        }
    }

    private func cardHeader(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
        }
        .padding(.horizontal, 2)
    }

    private var cardBackground: some ShapeStyle {
        AnyShapeStyle(.regularMaterial)
    }

    private var rowBackground: some ShapeStyle {
        AnyShapeStyle(Color(.secondarySystemBackground))
    }

    // MARK: Apply bar

    private var applyBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(pendingText)
                    .font(.subheadline.weight(.semibold))
                Text("A backup is saved before every write")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                viewModel.applySelectedTweaks()
            } label: {
                Label("Apply", systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .disabled(!viewModel.hasStagedTweaks || viewModel.isBusy)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var pendingText: String {
        let count = viewModel.stagedChangeCount
        if count == 0 { return "No pending changes" }
        return "\(count) pending change\(count == 1 ? "" : "s")"
    }
}

private struct TweakCard: View {
    @EnvironmentObject private var viewModel: GestaltViewModel
    let definition: GestaltTweakDefinition
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(definition.title)
                        .font(.body.weight(.semibold))
                    if let status {
                        Text(status.0)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(status.1))
                    }
                }
                Text(definition.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if definition.isLocked {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Locked")
            } else if definition.isRisky, status == nil {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .accessibilityLabel("High Risk")
            }
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .disabled(definition.isLocked)
                .tint(.accentColor)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .opacity(definition.isLocked ? 0.55 : 1)
    }

    private var status: (String, Color)? {
        if definition.isLocked { return ("Locked", .gray) }
        if viewModel.selectedTweaks.contains(definition.id) { return ("Pending", .orange) }
        if viewModel.removedTweaks.contains(definition.id) { return ("Pending", .orange) }
        if viewModel.isTweakEnabled(definition.id) { return ("Active", .green) }
        return nil
    }
}

private struct BackupLibrary: View {
    @EnvironmentObject private var viewModel: GestaltViewModel
    @State private var backupToRestore: GestaltBackup?
    @State private var showsBackupImporter = false

    var body: some View {
        List {
            Section {
                Button {
                    viewModel.createBackup()
                } label: {
                    Label("Back Up Current MobileGestalt", systemImage: "plus.circle.fill")
                }
                .disabled(viewModel.plist == nil || viewModel.isBusy)

                Button {
                    showsBackupImporter = true
                } label: {
                    Label("Import Backup", systemImage: "square.and.arrow.down")
                }
                .disabled(viewModel.isBusy)
            } footer: {
                Text("Importing only adds a file to the backup library. It does not write immediately. The original plist is also backed up before every write.")
            }

                Section("Local Backups") {
                    if viewModel.backups.isEmpty {
                        Label("No Backups", systemImage: "archivebox")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.backups) { backup in
                            BackupRow(backup: backup) {
                                backupToRestore = backup
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets { viewModel.delete(viewModel.backups[index]) }
                        }
                    }
                }
            }
            .navigationTitle("Backups")
            .refreshable { viewModel.refreshBackups() }
            .onAppear { viewModel.refreshBackups() }
            .fileImporter(
                isPresented: $showsBackupImporter,
                allowedContentTypes: [.propertyList],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first { viewModel.importBackup(from: url) }
                case .failure(let error):
                    viewModel.notice = GestaltNotice(kind: .error, message: error.localizedDescription)
                }
            }
            .confirmationDialog(
                "Restore This MobileGestalt Backup?",
                isPresented: Binding(
                    get: { backupToRestore != nil },
                    set: { if !$0 { backupToRestore = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Restore and Write", role: .destructive) {
                    if let backupToRestore { viewModel.restore(backupToRestore) }
                    backupToRestore = nil
                }
                Button("Cancel", role: .cancel) { backupToRestore = nil }
} message: {
                Text("The current file will be backed up first. SpringBoard will refresh automatically after restoring.")
            }
    }
}

private struct BackupRow: View {
    let backup: GestaltBackup
    let restore: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(backup.createdAt, format: .dateTime.year().month().day().hour().minute().second())
                Text(ByteCountFormatter.string(fromByteCount: backup.byteCount, countStyle: .file))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ShareLink(item: backup.url) {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("Export Backup")
            Button("Restore", action: restore)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
            .accessibilityLabel("Restore Backup")
        }
    }
}

private struct AdvancedGestaltEditor: View {
    @EnvironmentObject private var viewModel: GestaltViewModel

    @State private var searchText = ""
    @State private var activeEditor: FieldEditorRoute?

    private var cacheExtraKeys: [String] {
        filtered(viewModel.plist?.cacheExtraKeys ?? [], section: .cacheExtra)
    }

    private var topLevelKeys: [String] {
        filtered(
            viewModel.plist?.topLevelKeys.filter { $0 != "CacheExtra" } ?? [],
            section: .topLevel
        )
    }

    var body: some View {
        List {
            if viewModel.plist != nil {
                KeySection(
                    title: "CacheExtra",
                    keys: cacheExtraKeys,
                    value: { value(for: PlistKey(section: .cacheExtra, key: $0)) },
                    select: {
                        activeEditor = .edit(
                            PlistKey(section: .cacheExtra, key: $0)
                        )
                    }
                )

                KeySection(
                    title: "Top Level",
                    keys: topLevelKeys,
                    value: { value(for: PlistKey(section: .topLevel, key: $0)) },
                    select: {
                        activeEditor = .edit(
                            PlistKey(section: .topLevel, key: $0)
                        )
                    }
                )
            }
        }
        .navigationTitle("Advanced Fields")
        .searchable(text: $searchText, prompt: "Search key or value")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    activeEditor = .addCacheExtra
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add CacheExtra Field")
                .disabled(viewModel.plist == nil || viewModel.isBusy)

                Button("Save", action: viewModel.applyChanges)
                    .fontWeight(.semibold)
                    .disabled(!viewModel.isDirty || viewModel.isBusy)
            }
        }
        .sheet(item: $activeEditor) { editor in
            Group {
                switch editor {
                case .edit(let key):
                    ValueEditor(
                        key: key.key,
                        initialValue: value(for: key),
                        save: { update($0, for: key) },
                        delete: key.section == .cacheExtra
                            ? { deleteCacheExtraField(key.key) }
                            : nil
                    )
                case .addCacheExtra:
                    AddCacheExtraFieldEditor(save: addCacheExtraField)
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func filtered(_ keys: [String], section: PlistSection) -> [String] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return keys }

        return keys.filter { key in
            let reference = PlistKey(section: section, key: key)
            let info = PlistValueInfo.info(for: value(for: reference))
            return key.localizedCaseInsensitiveContains(query)
                || info.searchText.localizedCaseInsensitiveContains(query)
        }
    }

    private func value(for key: PlistKey) -> Any? {
        switch key.section {
        case .cacheExtra:
            viewModel.plist?.cacheExtra[key.key]
        case .topLevel:
            viewModel.plist?.value(forKey: key.key)
        }
    }

    private func update(_ value: Any, for key: PlistKey) {
        guard var plist = viewModel.plist else { return }
        switch key.section {
        case .cacheExtra:
            plist.setCacheExtra(value, forKey: key.key)
        case .topLevel:
            plist.setValue(value, forKey: key.key)
        }
        viewModel.plist = plist
        viewModel.isDirty = true
    }

    private func addCacheExtraField(key: String, value: Any) throws {
        guard var plist = viewModel.plist else { return }
        let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKey.isEmpty else {
            throw AddFieldError.emptyKey
        }
        guard plist.cacheExtra[normalizedKey] == nil else {
            throw AddFieldError.duplicateKey(normalizedKey)
        }

        plist.setCacheExtra(value, forKey: normalizedKey)
        viewModel.plist = plist
        viewModel.isDirty = true
    }

    private func deleteCacheExtraField(_ key: String) {
        guard var plist = viewModel.plist else { return }
        plist.removeCacheExtraValue(forKey: key)
        viewModel.plist = plist
        viewModel.isDirty = true
    }
}

private enum PlistSection: String {
    case cacheExtra
    case topLevel
}

private struct PlistKey: Identifiable {
    let section: PlistSection
    let key: String
    var id: String { "\(section.rawValue)/\(key)" }
}

private enum FieldEditorRoute: Identifiable {
    case edit(PlistKey)
    case addCacheExtra

    var id: String {
        switch self {
        case .edit(let key): "edit/\(key.id)"
        case .addCacheExtra: "add/cacheExtra"
        }
    }
}

private enum AddFieldError: LocalizedError {
    case emptyKey
    case duplicateKey(String)

    var errorDescription: String? {
        switch self {
        case .emptyKey:
            "Key cannot be empty."
        case .duplicateKey(let key):
            String(format: "CacheExtra already contains the field: %@", key)
        }
    }
}

private struct KeySection: View {
    let title: String
    let keys: [String]
    let value: (String) -> Any?
    let select: (String) -> Void

    var body: some View {
        Section(title) {
            if keys.isEmpty {
                Text("No Results")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(keys, id: \.self) { key in
                    Button { select(key) } label: {
                        KeyRow(key: key, value: value(key))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct KeyRow: View {
    let key: String
    let value: Any?

    var body: some View {
        let info = PlistValueInfo.info(for: value)
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(key)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(info.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

private struct ValueEditor: View {
    @Environment(\.dismiss) private var dismiss

    let key: String
    let initialValue: Any?
    let save: (Any) -> Void
    let delete: (() -> Void)?

    @State private var kind: PlistValueKind
    @State private var text: String
    @State private var errorMessage: String?
    @State private var showsDeleteConfirmation = false

    init(
        key: String,
        initialValue: Any?,
        save: @escaping (Any) -> Void,
        delete: (() -> Void)? = nil
    ) {
        self.key = key
        self.initialValue = initialValue
        self.save = save
        self.delete = delete
        let kind = PlistValueKind.kind(of: initialValue)
        _kind = State(initialValue: kind)
        _text = State(initialValue: PlistValueInfo.encode(initialValue, as: kind))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Type", selection: $kind) {
                        ForEach(PlistValueKind.allCases) { kind in
                            Text(kind.label).tag(kind)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Value") {
                    TextEditor(text: $text)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 140)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                if delete != nil {
                    Section {
                        Button("Delete Field", role: .destructive) {
                            showsDeleteConfirmation = true
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(key)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done", action: commit)
                        .fontWeight(.semibold)
                }
            }
            .confirmationDialog(
                "Delete CacheExtra Field?",
                isPresented: $showsDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    delete?()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The field will be removed from the file after you return to the editor and tap Save.")
            }
        }
    }

    private func commit() {
        do {
            save(try PlistValueInfo.parse(text, as: kind))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AddCacheExtraFieldEditor: View {
    @Environment(\.dismiss) private var dismiss

    let save: (String, Any) throws -> Void

    @State private var key = ""
    @State private var kind: PlistValueKind = .string
    @State private var text = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Field") {
                    LabeledContent("Location", value: "CacheExtra")
                    TextField("Key", text: $key)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section("Type") {
                    Picker("Type", selection: $kind) {
                        ForEach(PlistValueKind.allCases) { kind in
                            Text(kind.label).tag(kind)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Value") {
                    TextEditor(text: $text)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 120)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Field")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add", action: commit)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func commit() {
        do {
            let value = try PlistValueInfo.parse(text, as: kind)
            try save(key, value)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(GestaltViewModel())
}