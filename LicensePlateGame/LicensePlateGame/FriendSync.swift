import CloudKit
import Observation

/// Shares this phone's players with a friend group through CloudKit's public database.
///
/// Each player on each phone is one `Member` record named `<group code>-<player id>`, so a phone
/// only ever writes its own records. Friends are found by querying `groupCode`.
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
            if !isNew, try await fetchMembers(code).isEmpty {
                error = "No group found with code \(code). Check the code, and make sure both phones have the TestFlight version."
                return
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
            let members = try await fetchMembers(code)
            guard store.groupCode == code else { return }
            let localIDs = Set(store.players.map(\.id))
            store.setFriends(members.filter { !localIDs.contains($0.id) })
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

    private func fetchMembers(_ code: String) async throws -> [Player] {
        let query = CKQuery(recordType: Self.recordType, predicate: NSPredicate(format: "groupCode == %@", code))
        let (results, _) = try await database.records(matching: query, resultsLimit: 200)
        return results.compactMap { _, result in (try? result.get()).flatMap(Self.player(from:)) }
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
