//
//  GestaltViewModel.swift
//  GestaltTweak
//
//  Licensed under the MIT License. Portions derived from frs0n/GestaltEdit.
//

import Combine
import Foundation

@MainActor
final class GestaltViewModel: ObservableObject {
    @Published var plist: GestaltPlist?
    @Published var isDirty = false
    @Published var isBusy = false
    @Published var notice: GestaltNotice?
    @Published private(set) var hasAttemptedLoad = false
    @Published private(set) var backups: [GestaltBackup] = []
    @Published var selectedTweaks: Set<GestaltTweakID> = []
    @Published private(set) var removedTweaks: Set<GestaltTweakID> = []
    @Published var dynamicIslandSubtype: Int?
    @Published var changesModelName = false
    @Published var modelName = ""
    @Published var stagesAIRegion = false
    @Published private(set) var isRespringing = false
    @Published var posterFiles: [URL] = []

    private let access = GestaltAccess.shared()

    var aiRegionProfile: AIRegionProfile? {
        plist.flatMap(AIRegionProfile.init(plist:))
    }

    var requiresForcedAIEnable: Bool {
        plist != nil && aiRegionProfile == nil
    }

    var isAIRegionConfigured: Bool {
        guard let profile = aiRegionProfile,
              let cacheExtra = plist?.cacheExtra else { return false }
        return cacheExtra["h63QSdBCiT/z0WU6rdQv6Q"] as? String == "LL"
            && cacheExtra["yK+xavymRGZ3xWc1tb8XDg"] as? String == "LL/A"
            && cacheExtra["97JDvERpVwO+GHtthIh7hA"] as? String == profile.regulatoryModel
    }

    var hasStagedTweaks: Bool {
        !selectedTweaks.isEmpty
            || !removedTweaks.isEmpty
            || dynamicIslandSubtype != nil
            || (changesModelName && !modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            || stagesAIRegion
    }

    var stagedChangeCount: Int {
        selectedTweaks.count
            + removedTweaks.count
            + (dynamicIslandSubtype == nil ? 0 : 1)
            + (changesModelName ? 1 : 0)
            + (stagesAIRegion ? 1 : 0)
    }

    func load() {
        guard !isBusy else { return }
        hasAttemptedLoad = true
        isBusy = true
        notice = nil

        defer { isBusy = false }
        do {
            try access.connect()
            guard let dictionary = try access.readGestalt() as? [String: Any] else {
                throw GestaltEditError.invalidPlist
            }
            plist = GestaltPlist(dict: dictionary)
            isDirty = false
            refreshBackups()
        } catch {
            plist = nil
            report(error)
        }
    }

    func runExploit() {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try access.connect()
            notice = GestaltNotice(
                kind: .success,
                message: "Exploit succeeded. MobileGestalt is writable."
            )
        } catch {
            report(error)
        }
    }

    func respring() {
        guard !isRespringing else { return }
        isRespringing = true
    }

    func appendPosterFile(_ url: URL) {
        guard isPBArchive(url) else {
            print("(pb) ignoring unsupported file: \(url.lastPathComponent)")
            return
        }
        if posterFiles.contains(url) { return }
        _ = url.startAccessingSecurityScopedResource()
        posterFiles.append(url)
    }

    func removePosterFiles(at offsets: IndexSet) {
        for index in offsets {
            posterFiles[index].stopAccessingSecurityScopedResource()
        }
        posterFiles.remove(atOffsets: offsets)
    }

    func clearPosterFiles() {
        for url in posterFiles {
            url.stopAccessingSecurityScopedResource()
        }
        posterFiles.removeAll()
    }

    func setTweak(_ id: GestaltTweakID, enabled: Bool) {
        if enabled {
            selectedTweaks.insert(id)
            removedTweaks.remove(id)
            if id == .enableLiquidGlassLowPerformance {
                selectedTweaks.remove(.disableLiquidGlassLowPerformance)
                if isCurrentlyApplied(.disableLiquidGlassLowPerformance) {
                    removedTweaks.insert(.disableLiquidGlassLowPerformance)
                }
            } else if id == .disableLiquidGlassLowPerformance {
                selectedTweaks.remove(.enableLiquidGlassLowPerformance)
                if isCurrentlyApplied(.enableLiquidGlassLowPerformance) {
                    removedTweaks.insert(.enableLiquidGlassLowPerformance)
                }
            }
        } else {
            selectedTweaks.remove(id)
            if isCurrentlyApplied(id) {
                removedTweaks.insert(id)
            }
        }
    }

    func isTweakEnabled(_ id: GestaltTweakID) -> Bool {
        if removedTweaks.contains(id) { return false }
        if selectedTweaks.contains(id) { return true }
        return activeTweaks.contains(id)
    }

    var activeTweaks: Set<GestaltTweakID> {
        guard let cacheExtra = plist?.cacheExtra else { return [] }
        var result = Set<GestaltTweakID>()
        for definition in GestaltTweakCatalog.definitions {
            if definition.isApplied(in: cacheExtra) {
                result.insert(definition.id)
            }
        }
        return result
    }

    private func isCurrentlyApplied(_ id: GestaltTweakID) -> Bool {
        guard let definition = GestaltTweakCatalog.definition(for: id),
              let cacheExtra = plist?.cacheExtra else { return false }
        return definition.isApplied(in: cacheExtra)
    }

    func setAIRegion(enabled: Bool) {
        stagesAIRegion = enabled
        if enabled, requiresForcedAIEnable {
            notice = GestaltNotice(
                kind: .riskWarning,
                message: "This device does not officially support Apple Intelligence. Force enabling spoofs the product, hardware, and CPU model. It may temporarily break Face ID, cause system instability or boot loops, and could require restoring the device. A backup will be created before writing."
            )
        }
    }

    func applySelectedTweaks() {
        guard !isBusy, var pending = plist else { return }
        do {
            for id in selectedTweaks {
                guard let definition = GestaltTweakCatalog.definition(for: id) else { continue }
                try pending.apply(definition: definition)
            }
            for id in removedTweaks {
                guard let definition = GestaltTweakCatalog.definition(for: id) else { continue }
                for key in definition.values.keys {
                    pending.removeCacheExtraValue(forKey: key)
                }
            }
            if let dynamicIslandSubtype {
                try pending.setDynamicIslandSubtype(dynamicIslandSubtype)
            }
            if changesModelName {
                let name = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { throw GestaltEditError.emptyModelName }
                try pending.setModelName(name)
            }
            var expectedConfiguration: AIRegionConfiguration?
            if stagesAIRegion {
                let configuration = AIRegionConfiguration.resolve(for: pending)
                let profile = configuration.profile
                if let productType = configuration.spoofedProductType,
                   let hardwareModel = configuration.spoofedHardwareModel,
                   let cpuModel = configuration.spoofedCPUModel {
                    pending.setCacheExtra(1, forKey: "A62OafQ85EJAiiqKn4agtg")
                    pending.setCacheExtra(productType, forKey: "h9jDsbgj7xIVeIQ8S3/X3Q")
                    pending.setCacheExtra(hardwareModel, forKey: "oYicEKzVTz4/CxxE05pEgQ")
                    pending.setCacheExtra(cpuModel, forKey: "5pYKlGnYYBzGvAlIU8RjEQ")
                }
                pending.setCacheExtra("LL", forKey: "h63QSdBCiT/z0WU6rdQv6Q")
                pending.setCacheExtra("LL/A", forKey: "yK+xavymRGZ3xWc1tb8XDg")
                pending.setCacheExtra(profile.regulatoryModel, forKey: "97JDvERpVwO+GHtthIh7hA")
                expectedConfiguration = configuration
            }
            save(pending, expectedAIRegion: expectedConfiguration) { [weak self] in
                self?.selectedTweaks.removeAll()
                self?.removedTweaks.removeAll()
                self?.dynamicIslandSubtype = nil
                self?.changesModelName = false
                self?.modelName = ""
                self?.stagesAIRegion = false
            }
        } catch {
            report(error)
        }
    }

    func applyChanges() {
        guard !isBusy, let plist else { return }
        save(plist, expectedAIRegion: nil)
    }

    func createBackup() {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try access.connect()
            let data = try access.readGestaltData()
            let backup = try GestaltBackupStore.create(from: data)
            refreshBackups()
            notice = GestaltNotice(
                kind: .backupCreated,
                message: String(format: "Saved %@.plist. You can export it from the Restore tab.", backup.name)
            )
        } catch {
            report(error)
        }
    }

    func importBackup(from url: URL) {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let data = try Data(contentsOf: url)
            var format = PropertyListSerialization.PropertyListFormat.binary
            guard let dictionary = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: &format
            ) as? [String: Any],
                  dictionary["CacheExtra"] is [String: Any] else {
                throw GestaltEditError.invalidBackup
            }
            let backup = try GestaltBackupStore.create(from: data)
            refreshBackups()
            notice = GestaltNotice(
                kind: .backupCreated,
                message: String(format: "Imported %@ and saved it as %@.plist.", url.lastPathComponent, backup.name)
            )
        } catch {
            report(error)
        }
    }

    func restore(_ backup: GestaltBackup) {
        guard !isBusy else { return }
        do {
            let data = try GestaltBackupStore.data(for: backup)
            var format = PropertyListSerialization.PropertyListFormat.binary
            guard let dictionary = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: &format
            ) as? [String: Any] else {
                throw GestaltEditError.invalidBackup
            }
            save(GestaltPlist(dict: dictionary), expectedAIRegion: nil)
        } catch {
            report(error)
        }
    }

    func delete(_ backup: GestaltBackup) {
        do {
            try GestaltBackupStore.delete(backup)
            refreshBackups()
        } catch {
            report(error)
        }
    }

    func refreshBackups() {
        do {
            backups = try GestaltBackupStore.list()
        } catch {
            report(error)
        }
    }

    private func save(
        _ pendingPlist: GestaltPlist,
        expectedAIRegion: AIRegionConfiguration?,
        completion: (() -> Void)? = nil
    ) {
        isBusy = true
        notice = nil

        do {
            let originalData = try access.readGestaltData()
            _ = try GestaltBackupStore.create(from: originalData)
            try access.saveGestalt(pendingPlist.dict)
            guard let verification = try access.readGestalt() as? [String: Any] else {
                throw GestaltEditError.invalidPlist
            }
            let verifiedPlist = GestaltPlist(dict: verification)

            if let expectedAIRegion {
                let cacheExtra = verifiedPlist.cacheExtra
                guard cacheExtra["h63QSdBCiT/z0WU6rdQv6Q"] as? String == "LL",
                      cacheExtra["yK+xavymRGZ3xWc1tb8XDg"] as? String == "LL/A",
                      cacheExtra["97JDvERpVwO+GHtthIh7hA"] as? String == expectedAIRegion.profile.regulatoryModel else {
                    throw GestaltEditError.verificationFailed
                }
                if expectedAIRegion.requiresDeviceSpoofing {
                    guard cacheExtra["A62OafQ85EJAiiqKn4agtg"] as? Int == 1,
                          cacheExtra["h9jDsbgj7xIVeIQ8S3/X3Q"] as? String == expectedAIRegion.spoofedProductType,
                          cacheExtra["oYicEKzVTz4/CxxE05pEgQ"] as? String == expectedAIRegion.spoofedHardwareModel,
                          cacheExtra["5pYKlGnYYBzGvAlIU8RjEQ"] as? String == expectedAIRegion.spoofedCPUModel else {
                        throw GestaltEditError.verificationFailed
                    }
                }
            }

            plist = verifiedPlist
            isDirty = false
            completion?()
            refreshBackups()
            isBusy = false
            isRespringing = true
        } catch {
            isDirty = true
            report(error)
            isBusy = false
        }
    }

    private func report(_ error: Error) {
        notice = GestaltNotice(kind: .error, message: error.localizedDescription)
    }
}

private enum GestaltEditError: LocalizedError {
    case invalidPlist
    case invalidBackup
    case verificationFailed
    case emptyModelName

    var errorDescription: String? {
        switch self {
        case .invalidPlist: "The MobileGestalt plist is not a valid dictionary."
        case .invalidBackup: "The backup is not a valid MobileGestalt plist."
        case .verificationFailed: "The MobileGestalt values after writing do not match the expected values."
        case .emptyModelName: "The device model name cannot be empty."
        }
    }
}