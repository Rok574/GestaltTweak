import Foundation
import UniformTypeIdentifiers

struct HouseArrestItem: Identifiable, Hashable, Sendable {
    let url: URL
    let isDirectory: Bool
    let displayName: String?

    var id: String { url.path }
    var name: String { displayName ?? url.lastPathComponent }
    var isHidden: Bool { name.hasPrefix(".") }
    var contentType: UTType? { try? url.resourceValues(forKeys: [.contentTypeKey]).contentType }

    var iconName: String {
        if isDirectory { return "folder.fill" }
        if contentType?.conforms(to: .image) == true { return "photo" }
        if contentType?.conforms(to: .audio) == true { return "waveform" }
        if contentType?.conforms(to: .movie) == true || contentType?.conforms(to: .video) == true { return "play.rectangle" }
        return HouseArrestService.isEditable(url) ? "doc.text" : "doc"
    }

    init(url: URL, isDirectory: Bool? = nil, displayName: String? = nil) {
        self.url = url
        self.displayName = displayName
        if let isDirectory {
            self.isDirectory = isDirectory
        } else {
            var directory = ObjCBool(false)
            self.isDirectory = FileManager.default.fileExists(atPath: url.path, isDirectory: &directory) && directory.boolValue
        }
    }
}

enum HouseArrestService {
    static let applicationsRoot = URL(fileURLWithPath: "/var/mobile/Containers/Data/Application", isDirectory: true)

    nonisolated static func list(_ directory: URL) throws -> [HouseArrestItem] {
        let lease = try acquire(directory.path)
        defer { lease.invalidate() }
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey, .contentTypeKey], options: [])
        if directory.standardizedFileURL.path == applicationsRoot.path {
            return urls.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
                .map { HouseArrestItem(url: $0, isDirectory: true, displayName: bundleIdentifier(for: $0) ?? $0.lastPathComponent) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        return urls.map { HouseArrestItem(url: $0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    nonisolated static func read(_ url: URL) throws -> Data {
        let lease = try acquire(url.path)
        defer { lease.invalidate() }
        return try Data(contentsOf: url, options: .mappedIfSafe)
    }

    nonisolated static func write(_ data: Data, to url: URL) throws {
        let lease = try acquire(url.deletingLastPathComponent().path)
        defer { lease.invalidate() }
        try data.write(to: url, options: .atomic)
    }

    nonisolated static func importFile(from source: URL, to directory: URL) throws -> URL {
        let sourceAccess = source.startAccessingSecurityScopedResource()
        defer { if sourceAccess { source.stopAccessingSecurityScopedResource() } }
        let lease = try acquire(directory.path)
        defer { lease.invalidate() }
        let destination = directory.appendingPathComponent(safeFileName(source.lastPathComponent), isDirectory: false)
        if FileManager.default.fileExists(atPath: destination.path) { throw HouseArrestError.fileAlreadyExists }
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    nonisolated static func delete(_ item: HouseArrestItem) throws {
        guard !item.isDirectory else { throw HouseArrestError.directoryDeletionDisabled }
        let lease = try acquire(item.url.deletingLastPathComponent().path)
        defer { lease.invalidate() }
        try FileManager.default.removeItem(at: item.url)
    }

    nonisolated static func rename(_ item: HouseArrestItem, to name: String) throws {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, cleaned != ".", cleaned != "..", !cleaned.contains("/") else {
            throw HouseArrestError.invalidFileName
        }
        let lease = try acquire(item.url.deletingLastPathComponent().path)
        defer { lease.invalidate() }
        let destination = item.url.deletingLastPathComponent().appendingPathComponent(cleaned, isDirectory: item.isDirectory)
        if destination.standardizedFileURL.path == item.url.standardizedFileURL.path { return }
        if FileManager.default.fileExists(atPath: destination.path) {
            throw HouseArrestError.fileAlreadyExists
        }
        try FileManager.default.moveItem(at: item.url, to: destination)
    }

    nonisolated static func isEditable(_ url: URL) -> Bool {
        ["txt", "json", "xml", "plist", "strings", "md", "csv", "log", "conf", "ini", "yaml", "yml"].contains(url.pathExtension.lowercased())
    }

    private nonisolated static func acquire(_ path: String) throws -> BadQueryLease {
        var message: NSString?
        guard let lease = GTLeaseForPath(path, &message) else { throw HouseArrestError.accessDenied((message as String?) ?? path) }
        return lease
    }

    private nonisolated static func bundleIdentifier(for container: URL) -> String? {
        let metadata = container.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
        guard let data = try? read(metadata), let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else { return nil }
        return plist["MCMMetadataIdentifier"] as? String
    }

    private nonisolated static func safeFileName(_ name: String) -> String {
        let cleaned = name.replacingOccurrences(of: "/", with: "-")
        return cleaned.isEmpty ? "Imported File" : cleaned
    }
}

enum HouseArrestError: LocalizedError, Sendable {
    case accessDenied(String)
    case directoryDeletionDisabled
    case invalidFileName
    case fileAlreadyExists

    var errorDescription: String? {
        switch self {
        case .accessDenied(let path): "House Arrest could not access \(path). Run the exploit again and retry."
        case .directoryDeletionDisabled: "Folders cannot be deleted from this browser. Delete files individually."
        case .invalidFileName: "Enter a valid name without path separators."
        case .fileAlreadyExists: "An item with that name already exists in this folder."
        }
    }
}