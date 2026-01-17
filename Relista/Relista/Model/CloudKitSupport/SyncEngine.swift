//
//  SyncEngine.swift
//  Relista
//
//  Created by Nicolas Helbig on 07.01.26.
//
//  Generic sync coordinator that handles CloudKit sync for any Syncable type.
//  Features:
//  - Thread-safe with actor isolation
//  - Automatic retry with exponential backoff
//  - Debounced push to batch rapid changes
//  - Incremental sync (only fetches what changed)
//  - Timestamp-based conflict resolution
//

import Foundation
import CloudKit

/// Generic CloudKit sync coordinator for any Syncable type
///
/// Example usage:
/// ```swift
/// let agentEngine = SyncEngine<Agent>(database: container.privateCloudDatabase)
///
/// // Push a changed agent
/// await agentEngine.markForPush(agent.id)
/// try await agentEngine.performPush()
///
/// // Pull changes from CloudKit
/// let cloudAgents = try await agentEngine.pull(since: lastSyncDate)
/// ```
actor SyncEngine<Item: Syncable> {
    // MARK: - Properties

    /// CloudKit database (private or shared)
    private let database: CKDatabase

    /// CloudKit record type name (e.g., "Agent")
    private let recordType: String

    /// CloudKit record type for deletion tombstones
    private let deletionRecordType = "DeletionRecord"

    /// Last time we successfully synced with CloudKit (for incremental sync)
    private(set) var lastSyncDate: Date?

    /// IDs of items pending push to CloudKit
    private var pendingPushes = Set<UUID>()

    /// IDs of items pending deletion from CloudKit
    private var pendingDeletes = Set<UUID>()

    /// Task for debounced push (cancelled if new changes come in)
    private var debouncedPushTask: Task<Void, Never>?

    /// Delay before actually pushing (batches rapid changes together)
    /// Reduced to 0.5s to minimize chance of app being backgrounded before push completes
    private let pushDebounceDelay: TimeInterval = 0.5

    // MARK: - Retry Configuration

    /// Maximum number of retry attempts for failed operations
    private let maxRetries = 3

    /// Base delay for exponential backoff (1s, 2s, 4s)
    private let baseRetryDelay: TimeInterval = 1.0

    // MARK: - Initialization

    /// Create a sync engine for a specific Syncable type
    /// - Parameter database: The CloudKit database to use (typically container.privateCloudDatabase)
    init(database: CKDatabase) {
        self.database = database
        self.recordType = Item.recordType

        // Load last sync date from UserDefaults
        let key = "lastSyncDate_\(recordType)"
        if let savedDate = UserDefaults.standard.object(forKey: key) as? Date {
            self.lastSyncDate = savedDate
        }

        print("🔄 SyncEngine<\(recordType)> initialized (last sync: \(lastSyncDate?.description ?? "never"))")
    }

    // MARK: - Change Tracking

    /// Mark an item for push to CloudKit (will be pushed after debounce delay)
    /// - Parameter id: The ID of the item to push
    func markForPush(_ id: UUID) {
        pendingPushes.insert(id)
        print("  📝 Marked \(recordType) \(id.uuidString.prefix(8))... for push")
    }

    /// Mark an item for deletion from CloudKit
    /// - Parameter id: The ID of the item to delete
    func markForDelete(_ id: UUID) {
        let wasNew = pendingDeletes.insert(id).inserted
        pendingPushes.remove(id) // Don't push if we're deleting
        if wasNew {
            print("  🗑️ Marked \(recordType) \(id.uuidString.prefix(8))... for deletion")
        } else {
            print("  ⚠️ \(recordType) \(id.uuidString.prefix(8))... ALREADY marked for deletion (duplicate call)")
        }
    }

    /// Check if there are any pending changes
    func hasPendingChanges() -> Bool {
        return !pendingPushes.isEmpty || !pendingDeletes.isEmpty
    }

    // MARK: - Debounced Push

    /// Start debounced push (cancels previous pending push if any)
    /// This batches rapid changes together to avoid CloudKit rate limiting
    func startDebouncedPush(items: @escaping () async -> [Item]) {
        // Cancel previous debounced push
        debouncedPushTask?.cancel()

        // Schedule new push after delay
        debouncedPushTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(pushDebounceDelay * 1_000_000_000))

            if !Task.isCancelled {
                do {
                    try await performPush(items: await items())
                } catch {
                    print("❌ Debounced push failed: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Push Operations

    /// Perform all pending pushes and deletions
    /// - Parameter items: All items (to find items to push by ID)
    func performPush(items: [Item]) async throws {
        guard hasPendingChanges() else {
            print("  ⏭️ No pending changes for \(recordType), skipping push")
            return
        }

        print("📤 Pushing changes for \(recordType): \(pendingPushes.count) items, \(pendingDeletes.count) deletions")

        var succeededPushes = Set<UUID>()
        var succeededDeletes = Set<UUID>()

        // Process deletions first
        for id in pendingDeletes {
            do {
                try await delete(id)
                succeededDeletes.insert(id)
            } catch {
                print("❌ Failed to delete \(recordType) \(id.uuidString.prefix(8)): \(error.localizedDescription)")
            }
        }

        // Batch push items (more efficient and avoids rate limiting)
        let itemsToPush = items.filter { pendingPushes.contains($0.id) }
        if !itemsToPush.isEmpty {
            do {
                let pushedIDs = try await pushBatch(itemsToPush)
                succeededPushes.formUnion(pushedIDs)
            } catch {
                print("❌ Batch push failed, falling back to individual pushes: \(error.localizedDescription)")
                // Fallback to individual pushes if batch fails
                for item in itemsToPush {
                    do {
                        try await push(item)
                        succeededPushes.insert(item.id)
                    } catch {
                        print("❌ Failed to push \(recordType) \(item.id.uuidString.prefix(8)): \(error.localizedDescription)")
                    }
                }
            }
        }

        // Clear successful operations
        pendingPushes.subtract(succeededPushes)
        pendingDeletes.subtract(succeededDeletes)

        print("✅ Push complete: \(succeededPushes.count) items pushed, \(succeededDeletes.count) deleted")
        if !pendingPushes.isEmpty || !pendingDeletes.isEmpty {
            print("⚠️  Pending retry: \(pendingPushes.count) pushes, \(pendingDeletes.count) deletes")
        }
    }

    /// Push multiple items to CloudKit in a single batch operation
    /// - Parameter items: The items to push
    /// - Returns: Set of successfully pushed item IDs
    private func pushBatch(_ items: [Item]) async throws -> Set<UUID> {
        guard !items.isEmpty else { return Set() }

        print("  📦 Batch pushing \(items.count) \(recordType)(s)...")

        // Convert all items to CloudKit records
        var records: [CKRecord] = []
        for item in items {
            do {
                let record = try item.toCloudKitRecord()
                records.append(record)
            } catch {
                print("  ⚠️  Failed to convert \(recordType) \(item.id.uuidString.prefix(8)) to record: \(error)")
            }
        }

        guard !records.isEmpty else {
            throw SyncError.invalidData("No valid records to push")
        }

        // Use CKModifyRecordsOperation for batch save
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Set<UUID>, Error>) in
            let modifyOp = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
            modifyOp.savePolicy = .allKeys  // Save all fields (overwrite server if needed)
            modifyOp.configuration.allowsCellularAccess = true

            var succeededIDs = Set<UUID>()

            modifyOp.perRecordSaveBlock = { recordID, result in
                switch result {
                case .success(let savedRecord):
                    if let uuid = UUID(uuidString: savedRecord.recordID.recordName) {
                        succeededIDs.insert(uuid)
                        print("  ✅ Batched push: \(self.recordType) \(uuid.uuidString.prefix(8))...")
                    }
                case .failure(let error):
                    print("  ❌ Batched push failed for \(recordID.recordName.prefix(8)): \(error.localizedDescription)")
                }
            }

            modifyOp.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    print("  ✅ Batch operation complete: \(succeededIDs.count)/\(records.count) succeeded")
                    continuation.resume(returning: succeededIDs)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            self.database.add(modifyOp)
        }
    }

    /// Push a single item to CloudKit
    /// - Parameter item: The item to push
    private func push(_ item: Item) async throws {
        try await executeWithRetry(operationName: "push(\(recordType))") {
            let record = try item.toCloudKitRecord()

            // Use save policy that overwrites server record if different (avoids conflicts)
            // This implements "last write wins" without needing to fetch and compare
            let configuration = CKOperation.Configuration()
            configuration.allowsCellularAccess = true

            do {
                let modifyOp = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
                modifyOp.savePolicy = .changedKeys  // Only update changed fields
                modifyOp.configuration = configuration

                // Use async/await wrapper for operation
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    modifyOp.modifyRecordsResultBlock = { result in
                        switch result {
                        case .success:
                            print("  ✅ Pushed \(self.recordType) \(item.id.uuidString.prefix(8))...")
                            continuation.resume()
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                    self.database.add(modifyOp)
                }
            } catch let error as CKError where error.code == .serverRecordChanged {
                // Record already exists - fetch and update if our version is newer
                print("  ⚠️  Server record conflict for \(self.recordType), resolving...")

                let recordID = CKRecord.ID(recordName: item.id.uuidString)
                guard let existingRecord = try? await self.database.record(for: recordID) else {
                    throw error
                }

                // Compare timestamps
                let cloudTimestamp = existingRecord["lastModified"] as? Date ?? Date.distantPast
                if item.lastModified > cloudTimestamp {
                    // Our version is newer - update fields on the existing record
                    // (CloudKit requires modifying the fetched record, not creating a new one)
                    let newRecord = try item.toCloudKitRecord()

                    // Copy all user fields from new record to existing record
                    for key in newRecord.allKeys() {
                        existingRecord[key] = newRecord[key]
                    }

                    _ = try await self.database.save(existingRecord)
                    print("  ✅ Resolved conflict: updated existing record (our version was newer)")
                } else {
                    // Cloud version is newer - skip push
                    print("  ⏭️  Skipping push: cloud version is newer")
                }
            }
        }
    }

    // MARK: - Pull Operations

    /// Pull items from CloudKit that have changed since last sync
    /// - Parameter since: Only fetch items modified after this date (nil = fetch all)
    /// - Returns: Array of items from CloudKit
    func pull(since: Date? = nil) async throws -> [Item] {
        let syncDate = since ?? lastSyncDate

        // Build query predicate
        let predicate: NSPredicate
        if let syncDate = syncDate {
            predicate = NSPredicate(format: "lastModified > %@", syncDate as NSDate)
            print("📥 Pulling \(recordType) modified since \(syncDate)")
        } else {
            predicate = NSPredicate(value: true)
            print("📥 Pulling all \(recordType) (first sync)")
        }

        let query = CKQuery(recordType: recordType, predicate: predicate)

        // Fetch records
        let results = try await database.records(matching: query)

        var items: [Item] = []
        var errors: [(String, Error)] = []

        for (_, result) in results.matchResults {
            switch result {
            case .success(let record):
                do {
                    let item = try Item.fromCloudKitRecord(record)
                    items.append(item)
                } catch {
                    errors.append((record.recordID.recordName, error))
                    print("  ⚠️  Failed to decode \(recordType) record: \(error.localizedDescription)")
                }
            case .failure(let error):
                print("  ⚠️  Error fetching \(recordType) record: \(error.localizedDescription)")
                errors.append(("unknown", error))
            }
        }

        print("  📦 Fetched \(items.count) \(recordType)(s) from CloudKit")
        if !errors.isEmpty {
            print("  ⚠️  \(errors.count) record(s) failed to decode")
        }

        // Update last sync date
        lastSyncDate = Date.now
        let key = "lastSyncDate_\(recordType)"
        UserDefaults.standard.set(lastSyncDate, forKey: key)

        return items
    }

    // MARK: - Delete Operations

    /// Delete an item from CloudKit and create a deletion tombstone
    /// - Parameter id: The ID of the item to delete
    func delete(_ id: UUID) async throws {
        // First, delete the actual record (idempotent - succeeds even if already deleted)
        do {
            try await executeWithRetry(operationName: "delete(\(recordType))") {
                let recordID = CKRecord.ID(recordName: id.uuidString)
                _ = try await self.database.deleteRecord(withID: recordID)
                print("  ✅ Deleted \(self.recordType) \(id.uuidString.prefix(8))... from CloudKit")
            }
        } catch let error as CKError where error.code == .unknownItem {
            // Record doesn't exist - already deleted, which is fine
            print("  ✅ \(self.recordType) \(id.uuidString.prefix(8))... already deleted from CloudKit")
        } catch {
            // Other errors should still be thrown
            throw error
        }

        // Then, create a deletion tombstone so other devices know to delete it
        try await createDeletionTombstone(for: id)
    }

    /// Create a deletion tombstone record
    /// This tells other devices that an item was deleted
    private func createDeletionTombstone(for id: UUID) async throws {
        let deletionRecord = CKRecord(recordType: deletionRecordType)
        deletionRecord["deletedRecordID"] = id.uuidString as CKRecordValue
        deletionRecord["deletedRecordType"] = recordType as CKRecordValue
        deletionRecord["deletionDate"] = Date.now as CKRecordValue

        do {
            _ = try await database.save(deletionRecord)
            print("  🪦 Created deletion tombstone for \(recordType) \(id.uuidString.prefix(8))...")
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Tombstone already exists - that's fine
            print("  🪦 Deletion tombstone for \(recordType) \(id.uuidString.prefix(8))... already exists")
        } catch {
            // Don't fail the deletion just because tombstone creation failed
            // The deletion itself succeeded, so we should still clear it from pendingDeletes
            print("  ⚠️  Failed to create deletion tombstone (non-fatal): \(error.localizedDescription)")
        }
    }

    /// Pull deletion tombstones and return IDs of deleted items
    /// Call this during refresh to find items deleted on other devices
    /// - Returns: Array of UUIDs that were deleted
    func pullDeletions() async throws -> [UUID] {
        // Only fetch deletions from the last 30 days to avoid unbounded growth
        let thirtyDaysAgo = Date.now.addingTimeInterval(-30 * 24 * 60 * 60)
        let predicate = NSPredicate(format: "deletionDate > %@ AND deletedRecordType == %@",
                                   thirtyDaysAgo as NSDate,
                                   recordType)
        let query = CKQuery(recordType: deletionRecordType, predicate: predicate)

        print("  🪦 Querying CloudKit for \(recordType) deletion tombstones since \(thirtyDaysAgo)...")

        let results = try await database.records(matching: query)
        let totalResults = results.matchResults.count
        print("  🪦 CloudKit returned \(totalResults) deletion record(s)")

        var deletedIDs: [UUID] = []

        for (_, result) in results.matchResults {
            switch result {
            case .success(let record):
                guard let deletedIDString = record["deletedRecordID"] as? String,
                      let deletedID = UUID(uuidString: deletedIDString),
                      let deletedType = record["deletedRecordType"] as? String else {
                    print("  ⚠️  Malformed deletion record: \(record)")
                    continue
                }

                // Double-check the type matches (predicate should handle this, but be safe)
                if deletedType == recordType {
                    deletedIDs.append(deletedID)
                    print("  🪦 Found deletion tombstone for \(recordType) \(deletedID.uuidString.prefix(8))...")
                } else {
                    print("  ⚠️  Skipping tombstone for wrong type: \(deletedType) (expected \(recordType))")
                }
            case .failure(let error):
                print("  ⚠️  Error fetching deletion record: \(error.localizedDescription)")
            }
        }

        if deletedIDs.isEmpty && totalResults > 0 {
            print("  ⚠️  Found \(totalResults) tombstone record(s) but none were valid \(recordType) deletions")
        }

        return deletedIDs
    }

    // MARK: - Retry Logic

    /// Execute an operation with automatic retry and exponential backoff
    /// - Parameters:
    ///   - operationName: Name for logging (e.g., "push(Agent)")
    ///   - operation: The async operation to execute
    /// - Returns: Result of the operation
    /// - Throws: The last error if all retries fail
    private func executeWithRetry<T>(
        operationName: String,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0...maxRetries {
            do {
                let result = try await operation()
                // Success!
                if attempt > 0 {
                    print("  ✅ \(operationName) succeeded on retry \(attempt)")
                }
                return result
            } catch let error as CKError {
                lastError = error

                // Check if we should retry
                let shouldRetry = error.code == .networkFailure ||
                                 error.code == .networkUnavailable ||
                                 error.code == .serviceUnavailable ||
                                 error.code == .requestRateLimited

                if shouldRetry && attempt < maxRetries {
                    // Calculate exponential backoff delay
                    let delay = baseRetryDelay * pow(2.0, Double(attempt))
                    print("  ⚠️  \(operationName) failed (attempt \(attempt + 1)/\(maxRetries + 1)): \(error.localizedDescription)")
                    print("     Retrying in \(String(format: "%.1f", delay))s...")

                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                } else {
                    // Non-retryable error or max retries reached
                    throw error
                }
            } catch {
                // Non-CloudKit error
                lastError = error
                throw error
            }
        }

        // All retries exhausted
        throw lastError ?? SyncError.serverError("Unknown error in \(operationName)")
    }
}
