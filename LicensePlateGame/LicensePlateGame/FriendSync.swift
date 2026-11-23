import CloudKit
import Observation

/// Shares this phone's players with its friend groups through CloudKit's public database.
///
/// Each player on each phone is one `Member` record per group, named `<group code>-<player id>`,
/// so a phone only ever writes its own records. Friends are found by querying `groupCode`. Each
/// record also carries its group's game mode and when it was changed; the latest change wins.
@MainActor
@Observable
final class FriendSync {
    static let containerID = "iCloud.com.nikhilmath.licenseplategame"
    private static let recordType = "Member"
    private static let codeLength = 6
    private static let codeAlphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")

    let store: GameStore
    private(set) var isWorking = false
    /// When each group last synced, by group code.
    private(set) var lastSynced: [String: Date] = [:]
    var error: String?

    @ObservationIgnored private lazy var container = CKContainer(identifier: Self.containerID)
    @ObservationIgnored private var database: CKDatabase { container.publicCloudDatabase }
    @ObservationIgnored private var uploadTask: Task<Void, Never>?
    /// Local changes not yet saved to CloudKit, including on launch in case the last upload failed.
    @ObservationIgnored private var needsUpload = true
    @ObservationIgnored private var pendingDeletes: Set<UUID> = []

    init(store: GameStore) {
        self.store = store
    }

    // MARK: Group membership

    /// Starts a new group and makes it the active one. It begins in the mode on screen now.
    func createGroup(named name: String?) async {
        let code = String((0..<Self.codeLength).map { _ in Self.codeAlphabet.randomElement()! })
        await join(code, name: name, isNew: true)
    }

    /// Joins a group (or creates it when `isNew`) alongside any groups this phone is already in,
    /// and makes it the active one.
    func join(_ rawCode: String, name: String? = nil, isNew: Bool = false) async {
        let code = rawCode.uppercased().filter { $0.isLetter || $0.isNumber }
        guard code.count == Self.codeLength else {
            error = "Group codes are \(Self.codeLength) letters and numbers."
            return
        }
        if store.group(code) != nil {
            store.activeGroupCode = code
            return
        }
        #if DEBUG
        if DemoData.isEnabled {
            store.addGroup(code: code, name: name, mode: store.mode, modeChangedAt: store.modeChangedAt)
            store.activeGroupCode = code
            lastSynced[code] = Date()
            return
        }
        #endif
        isWorking = true
        defer { isWorking = false }
        do {
            guard try await container.accountStatus() == .available else {
                error = "Sign in to iCloud in Settings to play with friends."
                return
            }
            var mode = (mode: store.mode, changedAt: store.modeChangedAt)
            if !isNew {
                let group = try await fetchMembers(code)
                if group.players.isEmpty {
                    error = "No group found with code \(code). Check the code, and make sure both phones have the latest version."
                    return
                }
                // A joiner takes on the group's mode. A group nobody has changed is competitive.
                mode = group.mode ?? (.competitive, .distantPast)
            }
            let trimmed = name?.trimmingCharacters(in: .whitespaces)
            store.addGroup(code: code, name: trimmed?.isEmpty == false ? trimmed : nil,
                           mode: mode.mode, modeChangedAt: mode.changedAt)
            store.activeGroupCode = code
            error = nil
            needsUpload = true
            await sync()
        } catch {
            self.error = describe(error)
        }
    }

    func leave(_ code: String) {
        guard store.group(code) != nil else { return }
        let ids = store.players.map(\.id)
        store.removeGroup(code)
        lastSynced[code] = nil
        error = nil
        Task { await deleteRecords(ids, code: code) }
    }

    // MARK: Syncing

    /// Call whenever this phone's players change; saves them to every group after a short pause.
    func playersChanged(from old: [Player], to new: [Player]) {
        pendingDeletes.formUnion(Set(old.map(\.id)).subtracting(new.map(\.id)))
        needsUpload = true
        uploadTask?.cancel()
        uploadTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await sync()
        }
    }

    /// Call after the player changes the active group's mode, so the rest of the group picks it up.
    func modeChanged() {
        guard store.activeGroup != nil else { return }
        needsUpload = true
        Task { await sync() }
    }

    /// Saves any local changes to every group, then downloads each group's latest plates.
    func sync() async {
        let codes = store.groups.map(\.code)
        guard !codes.isEmpty else { return }
        #if DEBUG
        if DemoData.isEnabled {
            // Demo friends live only on this phone. Never read or write the real groups.
            for code in codes where lastSynced[code] == nil { lastSynced[code] = Date() }
            return
        }
        #endif
        var failure: Error?
        if needsUpload {
            do {
                try await upload(codes)
            } catch {
                failure = error
            }
        }
        // Download even if the upload failed: reading the public database doesn't need iCloud.
        for code in codes {
            do {
                try await refresh(code)
            } catch {
                failure = failure ?? error
            }
        }
        self.error = failure.map(describe)
    }

    private func refresh(_ code: String) async throws {
        let group = try await fetchMembers(code)
        guard let local = store.group(code) else { return }
        let localIDs = Set(store.players.map(\.id))
        store.setFriends(group.players.filter { !localIDs.contains($0.id) }, inGroup: code)
        if let mode = group.mode, mode.changedAt > local.modeChangedAt {
            store.setMode(mode.mode, changedAt: mode.changedAt, inGroup: code)
            // Copy it onto this phone's records, so it survives the friend who set it leaving.
            needsUpload = true
        }
        lastSynced[code] = Date()
    }

    /// Saves every player on this phone to each of these groups, and deletes removed players.
    private func upload(_ codes: [String]) async throws {
        let deletes = pendingDeletes
        let groups = codes.compactMap { store.group($0) }
        let records = groups.flatMap { group in store.players.map { record(for: $0, in: group) } }
        let deleteIDs = groups.flatMap { group in deletes.map { recordID(group.code, $0) } }
        let (saved, _) = try await database.modifyRecords(saving: records, deleting: deleteIDs,
                                                         savePolicy: .allKeys)
        for case .failure(let failure) in saved.values {
            throw failure
        }
        pendingDeletes.subtract(deletes)
        needsUpload = false
    }

    private func deleteRecords(_ ids: [UUID], code: String) async {
        #if DEBUG
        if DemoData.isEnabled { return }
        #endif
        _ = try? await database.modifyRecords(saving: [], deleting: ids.map { recordID(code, $0) })
    }

    /// The group's players, plus its game mode: the most recently changed one on any member's record.
    private func fetchMembers(_ code: String) async throws
        -> (players: [Player], mode: (mode: GameMode, changedAt: Date)?) {
        let query = CKQuery(recordType: Self.recordType, predicate: NSPredicate(format: "groupCode == %@", code))
        let (results, _) = try await database.records(matching: query, resultsLimit: 200)
        let records = results.compactMap { _, result in try? result.get() }
        let mode = records
            .compactMap { record -> (mode: GameMode, changedAt: Date)? in
                guard let raw = record["mode"] as? String, let mode = GameMode(rawValue: raw),
                      let changedAt = record["modeChangedAt"] as? Date else { return nil }
                return (mode, changedAt)
            }
            .max { $0.changedAt < $1.changedAt }
        return (records.compactMap(Self.player(from:)), mode)
    }

    // MARK: Records

    private func recordID(_ code: String, _ playerID: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: "\(code)-\(playerID.uuidString)")
    }

    private func record(for player: Player, in group: FriendGroup) -> CKRecord {
        let record = CKRecord(recordType: Self.recordType, recordID: recordID(group.code, player.id))
        record["groupCode"] = group.code
        record["playerID"] = player.id.uuidString
        record["name"] = player.name
        record["count"] = player.count
        record["spotted"] = (try? JSONEncoder().encode(player.spotted)).flatMap { String(data: $0, encoding: .utf8) }
        // Builds before co-op don't write these, and a never-changed mode isn't worth sending.
        if group.modeChangedAt > .distantPast {
            record["mode"] = group.mode.rawValue
            record["modeChangedAt"] = group.modeChangedAt
        }
        return record
    }

    private static func player(from record: CKRecord) -> Player? {
        guard let idString = record["playerID"] as? String, let id = UUID(uuidString: idString),
              let name = record["name"] as? String else { return nil }
        let spotted = (record["spotted"] as? String)
            .flatMap { try? JSONDecoder().decode([String: Date].self, from: Data($0.utf8)) } ?? [:]
        return Player(id: id, name: name, colorIndex: 0, spotted: spotted)
    }

    private func describe(_ error: Error) -> String {
        guard let ckError = error as? CKError else { return error.localizedDescription }
        if ckError.localizedDescription.localizedCaseInsensitiveContains("container configuration") {
            return "iCloud is still setting up Plate Chase's storage. Your plates will sync once it's ready."
        }
        switch ckError.code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited:
            return "Can't reach iCloud right now. Friends' plates will update when you're back online."
        case .notAuthenticated, .permissionFailure:
            // Saving to the public database without an iCloud account fails with a permission error.
            return "Sign in to iCloud in Settings so friends can see your plates."
        case .unknownItem:
            return "No group found with that code."
        case .invalidArguments where ckError.localizedDescription.localizedCaseInsensitiveContains("queryable"):
            return "CloudKit setup isn't finished: groupCode needs a Queryable index (see README)."
        default:
            return ckError.localizedDescription
        }
    }
}
