import CloudKit
import Observation

/// Shares this phone's players with a friend group through CloudKit's public database.
///
/// Each player on each phone is one `Member` record named `<group code>-<player id>`, so a phone
/// only ever writes its own records. Friends are found by querying `groupCode`. Each record also
/// carries the game mode and when it was changed; the latest change in the group wins.
@MainActor
@Observable
final class FriendSync {
    static let containerID = "iCloud.com.nikhilmath.licenseplategame"
    private static let recordType = "Member"
    private static let codeLength = 6
    private static let codeAlphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")

    let store: GameStore
    private(set) var isWorking = false
    private(set) var lastSynced: Date?
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

    func createGroup() async {
        let code = String((0..<Self.codeLength).map { _ in Self.codeAlphabet.randomElement()! })
        await join(code, isNew: true)
    }

    func join(_ rawCode: String, isNew: Bool = false) async {
        let code = rawCode.uppercased().filter { $0.isLetter || $0.isNumber }
        guard code.count == Self.codeLength else {
            error = "Group codes are \(Self.codeLength) letters and numbers."
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            guard try await container.accountStatus() == .available else {
                error = "Sign in to iCloud in Settings to play with friends."
                return
            }
            if !isNew {
                let group = try await fetchMembers(code)
                if group.players.isEmpty {
                    error = "No group found with code \(code). Check the code, and make sure both phones have the TestFlight version."
                    return
                }
                // A joiner takes on the group's mode, whatever this phone was set to before.
                // A group nobody has changed is competitive.
                store.setMode(group.mode?.mode ?? .competitive, changedAt: group.mode?.changedAt ?? .distantPast)
            }
            if let old = store.groupCode, old != code {
                await deleteRecords(store.players.map(\.id), code: old)
            }
            store.groupCode = code
            store.setFriends([])
            needsUpload = true
            try await upload(code: code)
            await refresh()
        } catch {
            self.error = describe(error)
        }
    }

    func leave() {
        guard let code = store.groupCode else { return }
        let ids = store.players.map(\.id)
        store.groupCode = nil
        store.setFriends([])
        error = nil
        lastSynced = nil
        Task { await deleteRecords(ids, code: code) }
    }

    // MARK: Syncing

    /// Call whenever this phone's players change; saves them to the group after a short pause.
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

    /// Call when the game mode changes, so the rest of the group picks it up.
    func modeChanged() {
        guard store.groupCode != nil else { return }
        needsUpload = true
        Task { await sync() }
    }

    /// Saves any local changes, then downloads friends' latest plates.
    func sync() async {
        guard let code = store.groupCode else { return }
        if needsUpload {
            do {
                try await upload(code: code)
            } catch {
                self.error = describe(error)
                return
            }
        }
        await refresh()
    }

    private func refresh() async {
        guard let code = store.groupCode else { return }
        do {
            let group = try await fetchMembers(code)
            guard store.groupCode == code else { return }
            let localIDs = Set(store.players.map(\.id))
            store.setFriends(group.players.filter { !localIDs.contains($0.id) })
            if let mode = group.mode, mode.changedAt > store.modeChangedAt {
                store.setMode(mode.mode, changedAt: mode.changedAt)
                // Copy it onto this phone's records, so it survives the friend who set it leaving.
                needsUpload = true
            }
            lastSynced = Date()
            error = nil
        } catch {
            self.error = describe(error)
        }
    }

    private func upload(code: String) async throws {
        let deletes = pendingDeletes
        let records = store.players.map { record(for: $0, code: code) }
        let (saved, _) = try await database.modifyRecords(saving: records,
                                                         deleting: deletes.map { recordID(code, $0) },
                                                         savePolicy: .allKeys)
        for case .failure(let failure) in saved.values {
            throw failure
        }
        pendingDeletes.subtract(deletes)
        needsUpload = false
    }

    private func deleteRecords(_ ids: [UUID], code: String) async {
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

    private func record(for player: Player, code: String) -> CKRecord {
        let record = CKRecord(recordType: Self.recordType, recordID: recordID(code, player.id))
        record["groupCode"] = code
        record["playerID"] = player.id.uuidString
        record["name"] = player.name
        record["count"] = player.count
        record["spotted"] = (try? JSONEncoder().encode(player.spotted)).flatMap { String(data: $0, encoding: .utf8) }
        // Builds before co-op don't write these, and a never-changed mode isn't worth sending.
        if store.modeChangedAt > .distantPast {
            record["mode"] = store.mode.rawValue
            record["modeChangedAt"] = store.modeChangedAt
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
        case .notAuthenticated:
            return "Sign in to iCloud in Settings to play with friends."
        case .unknownItem:
            return "No group found with that code."
        case .invalidArguments where ckError.localizedDescription.localizedCaseInsensitiveContains("queryable"):
            return "CloudKit setup isn't finished: groupCode needs a Queryable index (see README)."
        default:
            return ckError.localizedDescription
        }
    }
}
