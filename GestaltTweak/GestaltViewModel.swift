//
//  GestaltViewModel.swift
//  GestaltTweak
//
//  Licensed under the MIT License. Portions derived from frs0n/GestaltEdit.
//

import Combine
import Foundation
import SwiftUI

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
    @Published private(set) var stagedSubtype: DynamicIslandChange?
    @Published var modelName = ""
    @Published private(set) var stagesModelName = false
    @Published private(set) var unstagesModelName = false
    @Published var stagesAIRegion = false
    @Published private(set) var unstageAIRegion = false
    @Published private(set) var isRespringing = false
    @Published var posterFiles: [URL] = []

    private let access = GestaltAccess.shared()

    /// Baseline values used to unapply tweaks. This is the stock snapshot
    /// captured on first read (persisted so it survives resprings), falling
    /// back to the session-start state. Unapplying restores these values
    /// instead of deleting the keys outright, which could corrupt the
    /// MobileGestalt schema and block later writes.
    private var pristineCacheExtra: [String: Any]?

    /// Top-level CacheData from the same baseline, used to undo the iPadOS
    /// mode patch when that tweak is unapplied.
    private var pristineCacheData: Data?

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

    var aiRegionToggleState: Bool {
        if unstageAIRegion { return false }
        if stagesAIRegion { return true }
        return isAIRegionConfigured
    }

    /// A custom model name is "on" when the current artwork description
    /// differs from the stock baseline, plus any pending stage.
    var modelNameToggleState: Bool {
        if unstagesModelName { return false }
        if stagesModelName { return true }
        return isCustomModelNameApplied
    }

    var isCustomModelNameApplied: Bool {
        guard let current = currentArtworkProductDescription,
              let pristine = pristineCacheExtra?[Self.artworkKey] as? [String: Any],
              let stock = pristine["ArtworkDeviceProductDescription"] as? String else {
            return false
        }
        return current != stock
    }

    private var currentArtworkProductDescription: String? {
        guard let artwork = plist?.cacheExtra[Self.artworkKey] as? [String: Any] else {
            return nil
        }
        return artwork["ArtworkDeviceProductDescription"] as? String
    }

    /// The subtype currently in the plist, if the artwork dictionary has one.
    var currentSubtype: Int? {
        guard let artwork = plist?.cacheExtra[Self.artworkKey] as? [String: Any] else {
            return nil
        }
        return artwork["ArtworkDeviceSubType"] as? Int
    }

    /// What the subtype picker should show right now, mirroring the applied
    /// value so it is "detected" rather than defaulting to the stock value.
    var displayedSubtypeSelection: DynamicIslandSelection {
        if let stagedSubtype {
            switch stagedSubtype {
            case .set(let value): return .subtype(value)
            case .restore: return .original
            }
        } else if let current = currentSubtype {
            return .subtype(current)
        } else {
            return .original
        }
    }

    func setDynamicIslandSelection(_ selection: DynamicIslandSelection) {
        switch selection {
        case .original:
            stagedSubtype = .restore
        case .subtype(let value):
            if value == currentSubtype {
                stagedSubtype = nil
            } else {
                stagedSubtype = .set(value)
            }
        }
    }

    var hasStagedTweaks: Bool {
        !selectedTweaks.isEmpty
            || !removedTweaks.isEmpty
            || unstageAIRegion
            || stagedSubtype != nil
            || stagesModelName
            || unstagesModelName
            || stagesAIRegion
    }

    var stagedChangeCount: Int {
        selectedTweaks.count
            + removedTweaks.count
            + (unstageAIRegion ? 1 : 0)
            + (stagedSubtype == nil ? 0 : 1)
            + (stagesModelName ? 1 : 0)
            + (unstagesModelName ? 1 : 0)
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
            captureBaseline(from: dictionary)
            modelName = currentArtworkProductDescription ?? ""
            isDirty = false
            refreshBackups()
            Task.detached(priority: .utility) {
                _ = try? pb.find_pb_container()
            }
        } catch {
            plist = nil
            report(error)
        }
    }

    func runExploit() {
        guard !isBusy else { return }
        isBusy = true
        do {
            try access.connect()
            notice = GestaltNotice(
                kind: .success,
                message: "Exploit succeeded. MobileGestalt is writable."
            )
            if plist == nil,
               let dictionary = try access.readGestalt() as? [String: Any] {
                plist = GestaltPlist(dict: dictionary)
                captureBaseline(from: dictionary)
                isDirty = false
                refreshBackups()
            }
        } catch {
            report(error)
        }
        isBusy = false
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
        guard posterFiles.count < 5 else {
            print("(pb) session limit reached: up to 5 packs per session")
            return
        }
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
        let pristine = pristineCacheExtra ?? cacheExtra
        var result = Set<GestaltTweakID>()
        for definition in GestaltTweakCatalog.definitions {
            if definition.isApplied(in: cacheExtra),
               !definition.isApplied(in: pristine) {
                result.insert(definition.id)
            }
        }
        return result
    }

    /// True when the tweak's values are present right now and differ from the
    /// stock snapshot baseline. Stock keys that ship with the same value as
    /// the tweak are not treated as "applied".
    private func isCurrentlyApplied(_ id: GestaltTweakID) -> Bool {
        guard let definition = GestaltTweakCatalog.definition(for: id),
              let cacheExtra = plist?.cacheExtra else { return false }
        let pristine = pristineCacheExtra ?? cacheExtra
        return definition.isApplied(in: cacheExtra)
            && !definition.isApplied(in: pristine)
    }

    func setAIRegion(enabled: Bool) {
        if enabled {
            stagesAIRegion = true
            unstageAIRegion = false
            if requiresForcedAIEnable {
                notice = GestaltNotice(
                    kind: .riskWarning,
                    message: "This device does not officially support Apple Intelligence. Force enabling spoofs the product, hardware, and CPU model. It may temporarily break Face ID, cause system instability or boot loops, and could require restoring the device. A backup will be created before writing."
                )
            }
        } else {
            stagesAIRegion = false
            unstageAIRegion = isAIRegionConfigured
        }
    }

    func setModelNameToggled(_ on: Bool) {
        if on {
            stagesModelName = true
            unstagesModelName = false
            if modelName.isEmpty, let current = currentArtworkProductDescription {
                modelName = current
            }
        } else {
            stagesModelName = false
            unstagesModelName = isCustomModelNameApplied
        }
    }

    func clearModelNameStaging() {
        stagesModelName = false
        unstagesModelName = false
    }

    func applySelectedTweaks() {
        guard !isBusy, var pending = plist else { return }
        do {
            var addedKeys = Set<String>()
            for id in selectedTweaks {
                guard let definition = GestaltTweakCatalog.definition(for: id) else { continue }
                for key in definition.values.keys {
                    addedKeys.insert(key)
                }
                try pending.apply(definition: definition)
            }
            if let stagedSubtype {
                switch stagedSubtype {
                case .set(let value):
                    try pending.setDynamicIslandSubtype(value)
                    addedKeys.formUnion([Self.artworkKey, Self.dynamicIslandSupportKey])
                case .restore:
                    pending.restoreDynamicIsland(from: pristineCacheExtra)
                }
            }

            if stagesModelName {
                let name = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { throw GestaltEditError.emptyModelName }
                try pending.setModelName(name)
                addedKeys.insert(Self.artworkKey)
            } else if unstagesModelName {
                restoreArtworkProductDescription(in: &pending)
            }

            for id in removedTweaks {
                guard let definition = GestaltTweakCatalog.definition(for: id) else { continue }
                for key in definition.values.keys where !addedKeys.contains(key) {
                    restoreCacheExtraValue(forKey: key, in: &pending)
                }
                if id == .iPadOS, let pristine = pristineCacheData {
                    pending.dict["CacheData"] = pristine
                }
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
            } else if unstageAIRegion {
                restoreRegionKeys(in: &pending)
            }

            save(pending, expectedAIRegion: expectedConfiguration) { [weak self] in
                self?.clearStaging()
            }
        } catch {
            report(error)
        }
    }

    /// Clears every staged but not yet applied change.
    func clearStaging() {
        selectedTweaks.removeAll()
        removedTweaks.removeAll()
        stagedSubtype = nil
        stagesModelName = false
        unstagesModelName = false
        stagesAIRegion = false
        unstageAIRegion = false
    }

    /// Writes the stock snapshot back, undoing every applied tweak at once.
    func revertTweaks() {
        guard !isBusy else { return }
        guard let snapshot = GestaltBackupStore.loadStockSnapshot() else {
            notice = GestaltNotice(
                kind: .error,
                message: "No stock snapshot is available to revert to. The snapshot is captured the first time the MobileGestalt plist loads successfully, so reopen the app after running the exploit once."
            )
            return
        }
        save(GestaltPlist(dict: snapshot), expectedAIRegion: nil) { [weak self] in
            self?.clearStaging()
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

        var wrote = false
        do {
            // Backup is best-effort: a transient read or backup failure must
            // never block the write itself. The stock snapshot captured at
            // load time remains the primary safety net for reverts.
            if let originalData = try? access.readGestaltData() {
                do {
                    _ = try GestaltBackupStore.create(from: originalData)
                } catch {
                    print("(gestalt) backup skipped: \(error.localizedDescription)")
                }
            }
            try access.saveGestalt(pendingPlist.dict)
            wrote = true

            // The bytes were already verified by saveGestalt; this re-read
            // refreshes the in-memory copy and double-checks the AI region.
            if let verification = try? access.readGestalt() as? [String: Any] {
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
            } else {
                print("(gestalt) could not re-read the plist after a successful write")
            }
        } catch {
            isDirty = true
            report(error)
        }

        if wrote {
            // The write went through, so stop reporting these as pending even
            // if the post-write readback/verification failed.
            completion?()
            refreshBackups()
            isRespringing = true
        }
        isBusy = false
    }

    private func report(_ error: Error) {
        notice = GestaltNotice(kind: .error, message: error.localizedDescription)
    }

    private static let artworkKey = "oPeik/9e8lQWMszEjbPzng"
    private static let dynamicIslandSupportKey = "YlEtTtHlNesRBMal1CqRaA"
    private static let aiRegionKeys = [
        "h63QSdBCiT/z0WU6rdQv6Q",
        "yK+xavymRGZ3xWc1tb8XDg",
        "97JDvERpVwO+GHtthIh7hA",
        "A62OafQ85EJAiiqKn4agtg",
        "h9jDsbgj7xIVeIQ8S3/X3Q",
        "oYicEKzVTz4/CxxE05pEgQ",
        "5pYKlGnYYBzGvAlIU8RjEQ"
    ]

    /// Puts a key back the way it was when the plist was loaded. Keys that did
    /// not exist before are removed; keys that shipped with a value (usually 0)
    /// are restored to that value rather than being deleted.
    private func restoreCacheExtraValue(forKey key: String, in pending: inout GestaltPlist) {
        if let pristine = pristineCacheExtra?[key] {
            pending.setCacheExtra(pristine, forKey: key)
        } else {
            pending.removeCacheExtraValue(forKey: key)
        }
    }

    /// Sets the unapply baseline from the freshly read plist. The first ever
    /// successful read is persisted as the stock snapshot; every later load
    /// reuses that snapshot so tweaks stay reversible across resprings.
    private func captureBaseline(from dictionary: [String: Any]) {
        if let snapshot = GestaltBackupStore.loadStockSnapshot(),
           snapshot["CacheExtra"] is [String: Any] {
            pristineCacheExtra = snapshot["CacheExtra"] as? [String: Any]
            pristineCacheData = snapshot["CacheData"] as? Data
        } else {
            // The device may already carry tweaks applied by another tool
            // (Nugget, mond, ...). Clean provably tweak-only keys out of the
            // captured snapshot so Revert Tweaks restores a true stock state
            // instead of freezing the tweaked values in forever.
            let clean = Self.cleanedBaseline(from: dictionary)
            GestaltBackupStore.saveStockSnapshot(clean)
            pristineCacheExtra = clean["CacheExtra"] as? [String: Any]
            pristineCacheData = clean["CacheData"] as? Data
        }
    }

    /// Removes keys that never ship on stock devices from a possibly-tweaked
    /// plist. Keys that legitimately ship on some hardware (Face ID, the
    /// Dynamic Island subtype, charge limit, camera control, ...) are left
    /// untouched: removing them could break hardware features.
    private static func cleanedBaseline(from dictionary: [String: Any]) -> [String: Any] {
        guard var cacheExtra = dictionary["CacheExtra"] as? [String: Any] else {
            return dictionary
        }
        for definition in GestaltTweakCatalog.definitions where definition.isTweakOnly {
            for key in definition.values.keys {
                cacheExtra.removeValue(forKey: key)
            }
        }
        var cleaned = dictionary
        cleaned["CacheExtra"] = cacheExtra
        return cleaned
    }

    private func restoreRegionKeys(in pending: inout GestaltPlist) {
        for key in Self.aiRegionKeys {
            restoreCacheExtraValue(forKey: key, in: &pending)
        }
    }

    /// Puts the artwork's product description back to the stock baseline name.
    private func restoreArtworkProductDescription(in pending: inout GestaltPlist) {
        guard var artwork = pending.cacheExtra[Self.artworkKey] as? [String: Any] else {
            return
        }
        let stockName = (pristineCacheExtra?[Self.artworkKey] as? [String: Any])?["ArtworkDeviceProductDescription"] as? String
        if let stockName {
            artwork["ArtworkDeviceProductDescription"] = stockName
            pending.setCacheExtra(artwork, forKey: Self.artworkKey)
        } else {
            artwork.removeValue(forKey: "ArtworkDeviceProductDescription")
            pending.setCacheExtra(artwork, forKey: Self.artworkKey)
        }
    }
}

/// A pending write for the Dynamic Island subtype.
enum DynamicIslandChange: Hashable {
    case set(Int)
    case restore
}

/// What the subtype picker currently shows.
enum DynamicIslandSelection: Hashable {
    case original
    case subtype(Int)
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