//
//  PosterView.swift
//  GestaltTweak
//
//  PosterBoard screen and tendies explorer derived from rooootdev/mond's
//  views/tweaks/posterboard (AGPL-3.0).
//  Licensed under the MIT License.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct PosterView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: GestaltViewModel

    @State private var show_importer = false
    @State private var show_explorer = false
    @State private var busy = false
    @State private var alert: PosterAlert?

    var body: some View {
        List {
            Section {
                Button {
                    apply()
                } label: {
                    HStack {
                        if busy {
                            ProgressView()
                        }

                        Text("Apply")
                    }
                }
                .disabled(viewModel.posterFiles.isEmpty || busy)

                Button {
                    reset()
                } label: {
                    Text("Reset")
                }
                .disabled(busy)
            } footer: {
                Text("Writes the imported packs into PosterBoard and restarts it.")
            }

            Section {
                Button {
                    show_importer = true
                } label: {
                    Text("Import Tendies")
                }
                .disabled(busy)

                Button {
                    show_explorer = true
                } label: {
                    Text("Explore Tendies")
                }
                .disabled(busy)
            } footer: {
                Text("Up to 5 packs per session.")
            }

            if !viewModel.posterFiles.isEmpty {
                Section {
                    ForEach(viewModel.posterFiles, id: \.self) { url in
                        Text(url.lastPathComponent)
                    }
                    .onDelete { offsets in
                        viewModel.removePosterFiles(at: offsets)
                    }
                } header: {
                    Label("Imported", systemImage: "document.on.document")
                }
            }
        }
        .navigationTitle("PosterBoard")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $show_explorer) {
            TendiesView()
        }
        .fileImporter(isPresented: $show_importer, allowedContentTypes: [.data], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                urls.forEach { viewModel.appendPosterFile($0) }
            case .failure(let error):
                print("(pb) import failed: \(error)")
            }
        }
        .alert(item: $alert) { alert in
            if let actionLabel = alert.actionLabel {
                return Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text(actionLabel)) { alert.action?() },
                    secondaryButton: .cancel()
                )
            } else {
                return Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private func apply() {
        guard !busy else { return }
        busy = true
        let files = viewModel.posterFiles

        Task.detached(priority: .userInitiated) {
            do {
                let count = try pb.apply(at: files)
                print("(pb) applied \(count) descriptor(s).")
                await MainActor.run {
                    self.busy = false
                    self.alert = PosterAlert(
                        title: "Successfully applied PosterBoard!",
                        message: "For changes to take effect:\n1. Click 'Open' to launch Posterboard\n2. Close it from the App Switcher",
                        actionLabel: "Open",
                        action: {
                            self.openPosterBoard()
                        }
                    )
                }
            } catch {
                print("(pb) failed: \(error.localizedDescription)\n")
                await MainActor.run {
                    self.busy = false
                    self.alert = PosterAlert(
                        title: "Failed to apply PosterBoard!",
                        message: "Restart the app and try again."
                    )
                }
            }
        }
    }

    private func reset() {
        guard !busy else { return }
        busy = true

        Task.detached(priority: .userInitiated) {
            do {
                try pb.reset()
                print("(pb) reset done.")
                await MainActor.run {
                    self.busy = false
                    self.alert = PosterAlert(
                        title: "Successfully reverted PosterBoard!",
                        message: "Respring your device for changes to take effect.",
                        actionLabel: "Respring",
                        action: {
                            self.viewModel.respring()
                        }
                    )
                }
            } catch {
                print("(pb) failed: \(error.localizedDescription)")
                await MainActor.run {
                    self.busy = false
                    self.alert = PosterAlert(
                        title: "Failed to revert PosterBoard!",
                        message: "Restart the app and try again."
                    )
                }
            }
        }
    }

    private func openPosterBoard() {
        guard let workspaceClass = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
              let workspace = workspaceClass.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() as? NSObject else {
            return
        }
        _ = workspace.perform(NSSelectorFromString("openApplicationWithBundleID:"), with: "com.apple.PosterBoard")
    }
}

private struct PosterAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let actionLabel: String?
    let action: (() -> Void)?

    init(title: String, message: String, actionLabel: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.actionLabel = actionLabel
        self.action = action
    }
}

struct TendiesView: View {
    @EnvironmentObject private var viewModel: GestaltViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("dismiss_after_import") private var dismiss_after_import = false
    @StateObject private var vm = TendiesVM()
    @State private var import_error: String?

    var body: some View {
        NavigationStack {
            Group {
                if vm.loading && vm.wallpapers.isEmpty {
                    ProgressView("Loading wallpapers...")
                } else if let error = vm.error_msg, vm.wallpapers.isEmpty {
                    ContentUnavailableView {
                        Label("Wallpapers unavailable", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Try Again") {
                            Task {
                                await vm.load()
                            }
                        }
                    }
                } else {
                    tendies_list
                }
            }
            .navigationTitle("Tendies")
            .searchable(
                text: $vm.query,
                prompt: "Search wallpapers"
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await vm.load()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(vm.loading)
                }
            }
            .task {
                await vm.load()
            }
        }
        .alert("Import Failed", isPresented: Binding(
            get: { import_error != nil },
            set: { if !$0 { import_error = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(import_error ?? "")
        }
    }

    private var tendies_list: some View {
        ScrollView {
            MasonryLayout(columns: 2, spacing: 16) {
                ForEach(vm.filtered) { wallpaper in
                    tendies_cell(wallpaper)
                }
            }
            .padding(.horizontal)
        }
        .overlay {
            if vm.filtered.isEmpty &&
                !vm.loading &&
                !vm.query.isEmpty {
                ContentUnavailableView.search
            }
        }
    }

    private func tendies_cell(_ wallpaper: tendies) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            NavigationLink {
                TendiesDetail(wallpaper: wallpaper, dismiss_explorer: { dismiss() })
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    AsyncImage(url: wallpaper.preview_url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(height: 300)
                                .background(.quaternary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .background(.quaternary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                        case .failure:
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 300)
                                .background(.quaternary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                        @unknown default:
                            EmptyView()
                        }
                    }

                    HStack {
                        Text(wallpaper.name)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .foregroundStyle(.primary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .contextMenu {
            if wallpaper.download_url != nil {
                Button {
                    Task {
                        await add_to_imported(wallpaper)
                    }
                } label: {
                    Label("Add to Imported", systemImage: "arrow.down.circle")
                }
            }
        }
    }

    private func add_to_imported(_ wallpaper: tendies) async {
        do {
            let destination = try await download_tendies(wallpaper)
            viewModel.appendPosterFile(destination)
            print("(pb) imported \(destination.lastPathComponent)")

            if dismiss_after_import {
                dismiss()
            }
        } catch {
            print("(pb) download failed: \(error.localizedDescription)")
            import_error = error.localizedDescription
        }
    }
}

private struct MasonryLayout: Layout {
    var columns = 2
    var spacing: CGFloat = 16

    private func column_width(in width: CGFloat) -> CGFloat {
        (width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
    }

    private func shortest_column(_ heights: [CGFloat]) -> Int {
        heights.firstIndex(of: heights.min() ?? 0) ?? 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        let cell_width = column_width(in: width)
        var heights = [CGFloat](repeating: 0, count: columns)

        for subview in subviews {
            let height = subview.sizeThatFits(ProposedViewSize(width: cell_width, height: nil)).height
            let column = shortest_column(heights)
            heights[column] += height + spacing
        }

        return CGSize(width: width, height: (heights.max() ?? 0) - spacing)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let cell_width = column_width(in: bounds.width)
        var heights = [CGFloat](repeating: 0, count: columns)

        for subview in subviews {
            let column = shortest_column(heights)
            let size = subview.sizeThatFits(ProposedViewSize(width: cell_width, height: nil))
            subview.place(
                at: CGPoint(x: bounds.minX + CGFloat(column) * (cell_width + spacing), y: bounds.minY + heights[column]),
                proposal: ProposedViewSize(width: cell_width, height: size.height)
            )
            heights[column] += size.height + spacing
        }
    }
}

struct TendiesDetail: View {
    let wallpaper: tendies
    let dismiss_explorer: () -> Void

    @EnvironmentObject private var viewModel: GestaltViewModel
    @AppStorage("dismiss_after_import") private var dismiss_after_import = false

    @State private var importing = false
    @State private var import_error: String?

    var body: some View {
        List {
            Section {
                AsyncImage(url: wallpaper.preview_url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 500)

                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 20))

                    case .failure:
                        ContentUnavailableView("Preview Unavailable", systemImage: "photo", description: Text("The wallpaper preview couldn't be loaded."))

                    @unknown default:
                        EmptyView()
                    }
                }

                VStack(alignment: .leading) {
                    Text(wallpaper.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    if let description = wallpaper.description, !description.isEmpty {
                        Text(description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                if let authors = wallpaper.authors, !authors.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "person")
                            .foregroundStyle(.secondary)
                        Text(authors)
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "number")
                        .foregroundStyle(.secondary)
                    Text(String(wallpaper.id))
                }

                if let contest = wallpaper.contest {
                    HStack(spacing: 6) {
                        Image(systemName: "trophy")
                            .foregroundStyle(.secondary)
                        Text(contest)
                    }
                }

                if wallpaper.download_url != nil {
                    Button {
                        Task {
                            await import_wallpaper()
                        }
                    } label: {
                        if importing {
                            HStack {
                                ProgressView()
                                Text("Downloading...")
                            }
                        } else {
                            Text("Add to Imported")
                        }
                    }
                    .disabled(importing)
                }
            }
        }
        .navigationTitle(wallpaper.name)
        .alert("Download Failed", isPresented: Binding(
            get: { import_error != nil },
            set: { if !$0 { import_error = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(import_error ?? "")
        }
    }

    private func import_wallpaper() async {
        importing = true
        defer { importing = false }

        do {
            let destination = try await download_tendies(wallpaper)
            viewModel.appendPosterFile(destination)
            print("(pb) imported \(destination.lastPathComponent)")

            if dismiss_after_import {
                dismiss_explorer()
            }
        } catch {
            print("(pb) download failed: \(error.localizedDescription)")
            import_error = error.localizedDescription
        }
    }
}