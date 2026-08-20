import SwiftUI
import Combine
import UniformTypeIdentifiers

struct HouseArrestView: View {
    @StateObject private var cache = HouseArrestCache()

    var body: some View {
        NavigationStack { HouseArrestDirectoryView(directory: HouseArrestService.applicationsRoot, title: "HouseArrest") }
            .environmentObject(cache)
    }
}

@MainActor
private final class HouseArrestCache: ObservableObject {
    private var listings: [String: [HouseArrestItem]] = [:]

    func listing(for directory: URL) -> [HouseArrestItem]? {
        listings[directory.standardizedFileURL.path]
    }

    func store(_ items: [HouseArrestItem], for directory: URL) {
        listings[directory.standardizedFileURL.path] = items
    }

    func invalidate(_ directory: URL) {
        listings.removeValue(forKey: directory.standardizedFileURL.path)
    }
}

private struct HouseArrestDirectoryView: View {
    @EnvironmentObject private var cache: HouseArrestCache
    let directory: URL
    let title: String
    @State private var items: [HouseArrestItem] = []
    @State private var query = ""
    @State private var isLoading = true
    @State private var importPresented = false
    @State private var errorMessage: String?
    @State private var itemToDelete: HouseArrestItem?
    @State private var itemToRename: HouseArrestItem?
    @State private var renameText = ""

    private var visibleItems: [HouseArrestItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? items : items.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        Group {
            if isLoading { ProgressView("Loading files...") }
            else if visibleItems.isEmpty { ContentUnavailableView(query.isEmpty ? "Folder is empty" : "No matching files", systemImage: "folder") }
            else {
                List {
                    ForEach(visibleItems) { item in
                        if item.isDirectory {
                            NavigationLink {
                                HouseArrestDirectoryView(directory: item.url, title: item.name)
                                    .environmentObject(cache)
                            } label: { itemRow(item) }
                                .contextMenu { renameButton(for: item) }
                        } else {
                            NavigationLink { HouseArrestFileView(item: item) } label: { itemRow(item) }
                                .contextMenu {
                                    renameButton(for: item)
                                    deleteButton(for: item)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button { beginRename(item) } label: { Label("Rename", systemImage: "pencil") }
                                    Button(role: .destructive) { itemToDelete = item } label: { Label("Delete", systemImage: "trash") }
                                }
                        }
                    }
                }.listStyle(.insetGrouped)
            }
        }
        .navigationTitle(title)
        .searchable(text: $query, prompt: "Search files")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { importPresented = true } label: { Image(systemName: "square.and.arrow.down") }.accessibilityLabel("Import file")
            }
        }
        .task { load() }
        .refreshable { load(forceRefresh: true) }
        .fileImporter(isPresented: $importPresented, allowedContentTypes: [.data], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                Task {
                    do {
                        try await Self.importFiles(urls, to: directory)
                        cache.invalidate(directory)
                        load(forceRefresh: true)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            case .failure(let error): errorMessage = error.localizedDescription
            }
        }
        .confirmationDialog("Delete this file?", isPresented: Binding(get: { itemToDelete != nil }, set: { if !$0 { itemToDelete = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let itemToDelete {
                    do { try HouseArrestService.delete(itemToDelete); cache.invalidate(directory); load(forceRefresh: true) }
                    catch { errorMessage = error.localizedDescription }
                }
                self.itemToDelete = nil
            }
            Button("Cancel", role: .cancel) { itemToDelete = nil }
        }
        .sheet(item: $itemToRename) { item in
            NavigationStack {
                Form {
                    TextField("Name", text: $renameText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .navigationTitle("Rename Item")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { itemToRename = nil } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Rename") {
                            do { try HouseArrestService.rename(item, to: renameText); itemToRename = nil; cache.invalidate(directory); load(forceRefresh: true) }
                            catch { errorMessage = error.localizedDescription }
                        }
                        .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.height(180)])
        }
        .alert("File Browser Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    private func itemRow(_ item: HouseArrestItem) -> some View {
        Label { Text(item.name).lineLimit(1) } icon: { Image(systemName: item.iconName).foregroundStyle(item.isDirectory ? Color.accentColor : .secondary) }
    }

    @ViewBuilder
    private func renameButton(for item: HouseArrestItem) -> some View {
        Button { beginRename(item) } label: { Label("Rename", systemImage: "pencil") }
    }

    private func deleteButton(for item: HouseArrestItem) -> some View {
        Button(role: .destructive) { itemToDelete = item } label: { Label("Delete", systemImage: "trash") }
    }

    private func beginRename(_ item: HouseArrestItem) {
        renameText = item.name
        itemToRename = item
    }

    private func load(forceRefresh: Bool = false) {
        isLoading = true
        let directory = directory
        if !forceRefresh, let cached = cache.listing(for: directory) {
            items = cached
            isLoading = false
            return
        }
        Task {
            do {
                let result = try await Self.loadListing(for: directory)
                cache.store(result, for: directory)
                items = result
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private nonisolated static func loadListing(for directory: URL) async throws -> [HouseArrestItem] {
        try await Task.detached(priority: .userInitiated) {
            try HouseArrestService.list(directory)
        }.value
    }

    private nonisolated static func importFiles(_ urls: [URL], to directory: URL) async throws {
        try await Task.detached(priority: .userInitiated) {
            for url in urls {
                _ = try HouseArrestService.importFile(from: url, to: directory)
            }
        }.value
    }
}

private struct HouseArrestFileView: View {
    let item: HouseArrestItem
    @State private var text = ""
    @State private var editing = false
    @State private var textEncoding: String.Encoding = .utf8
    @State private var binaryEditing = false
    @State private var plistFormat: PropertyListSerialization.PropertyListFormat?
    @State private var errorMessage: String?
    @State private var cautionData: Data?
    @State private var exportPresented = false
    @State private var exportDocument = HouseArrestExportDocument(data: Data())
    @State private var isLoading = true
    @State private var tooLarge = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading...")
            } else if tooLarge {
                ContentUnavailableView("File Too Large to Preview", systemImage: "doc.questionmark", description: Text("Use Save to Files to export it."))
            } else if editing {
                TextEditor(text: $text).font(.system(size: 13, design: .monospaced))
            } else {
                ScrollView { Text(text).font(.system(size: 13, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding() }
            }
        }
        .navigationTitle(item.name)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if editing {
                    Button("Cancel") { editing = false }
                    Button("Save") { save() }
                } else if !item.isDirectory && !tooLarge {
                    Button { beginEditing() } label: { Image(systemName: "square.and.pencil") }.accessibilityLabel("Edit file")
                }
                Button { prepareExport() } label: { Image(systemName: "folder.badge.plus") }
                    .accessibilityLabel("Save to Files")
            }
        }
        .task { load() }
        .fileExporter(
            isPresented: $exportPresented,
            document: exportDocument,
            contentType: .data,
            defaultFilename: item.name
        ) { result in
            if case .failure(let error) = result {
                errorMessage = error.localizedDescription
            }
        }
        .alert("File Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
        .confirmationDialog("Proceed with caution?", isPresented: Binding(
            get: { cautionData != nil },
            set: { if !$0 { cautionData = nil } }
        ), titleVisibility: .visible) {
            Button("Edit File") {
                if let cautionData {
                    startEditing(cautionData)
                    self.cautionData = nil
                }
            }
            Button("Cancel", role: .cancel) { cautionData = nil }
        } message: {
            Text("This file type is unknown. Text changes or byte changes can make the file unusable.")
        }
    }

    private func load() {
        isLoading = true
        tooLarge = false
        let url = item.url
        Task {
            do {
                let size = HouseArrestService.fileSize(url) ?? 0
                if size > HouseArrestService.maxPreviewBytes {
                    tooLarge = true
                    isLoading = false
                    return
                }
                let data = try await Self.readData(url)
                let result = try await Self.decodeOffMain(data)
                text = result.text
                textEncoding = result.encoding
                binaryEditing = result.isBinary
                plistFormat = result.plistFormat
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func beginEditing() {
        let url = item.url
        Task {
            do {
                let size = HouseArrestService.fileSize(url) ?? 0
                guard size <= HouseArrestService.maxPreviewBytes else {
                    errorMessage = HouseArrestError.fileTooLarge(size).localizedDescription
                    return
                }
                let data = try await Self.readData(url)
                if HouseArrestService.needsEditingWarning(url) {
                    cautionData = data
                } else {
                    startEditing(data)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func startEditing(_ data: Data) {
        Task {
            do {
                let result = try await Self.decodeOffMain(data)
                text = result.text
                textEncoding = result.encoding
                binaryEditing = result.isBinary
                plistFormat = result.plistFormat
                editing = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func prepareExport() {
        let url = item.url
        Task {
            do {
                let data = try await Self.readData(url)
                exportDocument = HouseArrestExportDocument(data: data)
                exportPresented = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private nonisolated static func readData(_ url: URL) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            try HouseArrestService.read(url)
        }.value
    }

    private struct DecodeResult: Sendable {
        let text: String
        let encoding: String.Encoding
        let isBinary: Bool
        let plistFormat: PropertyListSerialization.PropertyListFormat?
    }

    private nonisolated static func decodeOffMain(_ data: Data) async throws -> DecodeResult {
        try await Task.detached(priority: .userInitiated) {
            try Self.decode(data)
        }.value
    }

    private nonisolated static func decode(_ data: Data) throws -> DecodeResult {
        if var format = PropertyListSerialization.PropertyListFormat?.some(.xml), !data.isEmpty,
           let object = try? PropertyListSerialization.propertyList(from: data, options: [], format: &format) {
            if JSONSerialization.isValidJSONObject(object),
               let json = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) {
                return DecodeResult(text: String(decoding: json, as: UTF8.self), encoding: .utf8, isBinary: false, plistFormat: format)
            }
            if let xml = try? PropertyListSerialization.data(fromPropertyList: object, format: .xml, options: 0) {
                return DecodeResult(text: String(decoding: xml, as: UTF8.self), encoding: .utf8, isBinary: false, plistFormat: format)
            }
        }

        let encodings: [String.Encoding] = [.utf8, .utf16, .utf16LittleEndian, .utf16BigEndian, .utf32, .utf32LittleEndian, .utf32BigEndian, .ascii, .isoLatin1, .windowsCP1252, .macOSRoman]
        for encoding in encodings {
            guard let value = String(data: data, encoding: encoding), looksLikeText(value) else { continue }
            return DecodeResult(text: value, encoding: encoding, isBinary: false, plistFormat: nil)
        }

        return DecodeResult(text: hexDump(data), encoding: .utf8, isBinary: true, plistFormat: nil)
    }

    private nonisolated static func hexDump(_ data: Data) -> String {
        let hexChars: [UInt8] = Array("0123456789ABCDEF".utf8)
        var output = [UInt8]()
        output.reserveCapacity(data.count * 3)
        var first = true
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            for byte in raw {
                if !first { output.append(0x20) }
                first = false
                output.append(hexChars[Int(byte >> 4)])
                output.append(hexChars[Int(byte & 0x0F)])
            }
        }
        return String(decoding: output, as: UTF8.self)
    }

    private nonisolated static func looksLikeText(_ value: String) -> Bool {
        guard !value.isEmpty else { return true }
        let invalidCount = value.unicodeScalars.reduce(into: 0) { count, scalar in
            let code = scalar.value
            if code == 9 || code == 10 || code == 13 { return }
            if code < 32 || (code >= 0x7F && code <= 0x9F) { count += 1 }
        }
        return Double(invalidCount) / Double(value.unicodeScalars.count) < 0.01
    }

    private func save() {
        do {
            let data: Data
            if binaryEditing {
                let pieces = text.split { $0 == " " || $0 == "\n" || $0 == "\t" || $0 == "\r" }
                guard pieces.allSatisfy({ $0.count == 2 && UInt8($0, radix: 16) != nil }) else {
                    throw HouseArrestError.accessDenied("Binary edits must contain two-digit hexadecimal bytes separated by spaces.")
                }
                data = Data(pieces.compactMap { UInt8($0, radix: 16) })
            } else if let format = plistFormat {
                let edited = Data(text.utf8)
                let object: Any
                if let json = try? JSONSerialization.jsonObject(with: edited) {
                    object = json
                } else {
                    object = try PropertyListSerialization.propertyList(from: edited, options: [], format: nil)
                }
                data = try PropertyListSerialization.data(fromPropertyList: object, format: format, options: 0)
            } else {
                guard let encoded = text.data(using: textEncoding) else { throw HouseArrestError.accessDenied("Could not encode text") }
                data = encoded
            }
            try HouseArrestService.write(data, to: item.url)
            editing = false
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct HouseArrestExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}