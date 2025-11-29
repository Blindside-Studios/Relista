//
//  CloudKitSyncManager.swift
//  Relista
//
//  CloudKit synchronization manager for Agents, Conversations, and Messages
//

import Foundation
import CloudKit
import Combine

class CloudKitSyncManager: ObservableObject {
    static let shared = CloudKitSyncManager()

    private let container: CKContainer
    private let privateDatabase: CKDatabase

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?

    // Record type names
    private let agentRecordType = "Agent"
    private let conversationRecordType = "Conversation"
    private let messageRecordType = "Message"

    // Debounce mechanism to prevent too many rapid CloudKit calls
    private var pendingPushTask: Task<Void, Never>?
    private let pushDebounceDelay: TimeInterval = 2.0 // Wait 2 seconds before pushing
    private var hasPendingChanges = false // Track if there are actually changes to push

    // Change tracking - only push what changed
    private var changedAgentIDs = Set<UUID>()
    private var changedConversationIDs = Set<UUID>()
    private var changedConversationMessagesIDs = Set<UUID>() // Conversations whose messages changed

    // Deletion tracking
    private var deletedAgentIDs = Set<UUID>()
    private var deletedConversationIDs = Set<UUID>()

    private init() {
        self.container = CKContainer(identifier: "iCloud.Blindside-Studios.Relista")
        self.privateDatabase = container.privateCloudDatabase

        // Load last sync date
        self.lastSyncDate = UserDefaults.standard.object(forKey: "lastCloudKitSync") as? Date

        // Set up subscriptions for real-time sync
        Task {
            try? await setupSubscriptions()
        }
    }

    // MARK: - Public Sync Methods

    /// Mark agents as changed (call before saving)
    func markAgentsChanged() {
        for agent in AgentManager.shared.customAgents {
            changedAgentIDs.insert(agent.id)
        }
        hasPendingChanges = true
    }

    /// Mark a specific conversation as changed (call before saving)
    func markConversationChanged(_ id: UUID) {
        changedConversationIDs.insert(id)
        hasPendingChanges = true
    }

    /// Mark a conversation's messages as changed (call before saving messages)
    func markMessagesChanged(for conversationID: UUID) {
        changedConversationMessagesIDs.insert(conversationID)
        hasPendingChanges = true
    }

    /// Mark an agent as deleted (call before removing from local storage)
    func markAgentDeleted(_ id: UUID) {
        deletedAgentIDs.insert(id)
        changedAgentIDs.remove(id) // Remove from changed set if it was there
        hasPendingChanges = true
    }

    /// Mark a conversation as deleted (call before removing from local storage)
    func markConversationDeleted(_ id: UUID) {
        deletedConversationIDs.insert(id)
        changedConversationIDs.remove(id) // Remove from changed set if it was there
        changedConversationMessagesIDs.remove(id)
        hasPendingChanges = true
    }

    /// Debounced push - batches multiple push requests together
    func debouncedPush() {
        // Cancel any pending push
        let wasCancelled = pendingPushTask != nil
        pendingPushTask?.cancel()

        if wasCancelled {
            print("⏱️ CloudKit push rescheduled (previous cancelled)")
        } else {
            print("⏱️ CloudKit push scheduled (2s debounce)")
        }

        // Schedule a new push after delay
        pendingPushTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(pushDebounceDelay * 1_000_000_000))

            // If not cancelled and we have changes, do the push
            if !Task.isCancelled && hasPendingChanges {
                print("☁️ Starting debounced CloudKit push...")
                print("  Changed: \(changedAgentIDs.count) agents, \(changedConversationIDs.count) conversations, \(changedConversationMessagesIDs.count) message sets")
                print("  Deleted: \(deletedAgentIDs.count) agents, \(deletedConversationIDs.count) conversations")

                try? await pushChangedItems()

                // Clear change tracking
                changedAgentIDs.removeAll()
                changedConversationIDs.removeAll()
                changedConversationMessagesIDs.removeAll()
                deletedAgentIDs.removeAll()
                deletedConversationIDs.removeAll()
                hasPendingChanges = false

                print("✅ CloudKit push completed")
            }
        }
    }

    /// Performs a full sync (pull from CloudKit, then push local changes)
    func performFullSync() async throws {
        // Check if CloudKit is available
        let isAvailable = await checkiCloudStatus()
        guard isAvailable else {
            print("CloudKit is not available - skipping sync")
            return
        }

        await MainActor.run { isSyncing = true }
        defer { Task { await MainActor.run { isSyncing = false } } }

        do {
            let isFirstSync = lastSyncDate == nil

            if isFirstSync {
                print("First sync detected for this device")
                // On first sync, push everything to establish baseline
                try await pullAllChanges()
                try await pushAllChanges()
            } else {
                // Normal sync: only pull (push happens via debounced saves)
                print("Pulling changes from CloudKit...")
                try await pullAllChanges()
                print("Pull complete")
            }

            // Update last sync date
            let now = Date()
            await MainActor.run {
                lastSyncDate = now
                syncError = nil
            }
            UserDefaults.standard.set(now, forKey: "lastCloudKitSync")

        } catch {
            await MainActor.run { syncError = error }
            throw error
        }
    }

    /// Pulls all changes from CloudKit
    private func pullAllChanges() async throws {
        try await pullAgents()
        try await pullConversations()
        try await pullMessages()
    }

    /// Pushes all local data to CloudKit (used for initial sync)
    private func pushAllChanges() async throws {
        try await pushAgents()
        try await pushConversations()
        try await pushMessages()
    }

    /// Pushes only items that have changed (efficient)
    private func pushChangedItems() async throws {
        // Delete agents first
        for agentID in deletedAgentIDs {
            try? await deleteAgent(agentID)
        }

        // Delete conversations and their messages
        for conversationID in deletedConversationIDs {
            try? await deleteConversation(conversationID)
        }

        // Push changed agents
        if !changedAgentIDs.isEmpty {
            print("  📤 Pushing \(changedAgentIDs.count) changed agent(s)")
            for agentID in changedAgentIDs {
                if let agent = AgentManager.shared.customAgents.first(where: { $0.id == agentID }) {
                    try await pushAgent(agent)
                }
            }
        }

        // Push changed conversations
        if !changedConversationIDs.isEmpty {
            print("  📤 Pushing \(changedConversationIDs.count) changed conversation(s)")
            for conversationID in changedConversationIDs {
                if let conversation = ChatCache.shared.conversations.first(where: { $0.id == conversationID }) {
                    try await pushConversation(conversation)
                }
            }
        }

        // Push changed messages
        if !changedConversationMessagesIDs.isEmpty {
            var totalMessages = 0
            for conversationID in changedConversationMessagesIDs {
                let messages = try? ConversationManager.loadMessages(for: conversationID)
                totalMessages += messages?.count ?? 0
            }
            print("  📤 Pushing messages for \(changedConversationMessagesIDs.count) conversation(s) (\(totalMessages) total messages)")

            for conversationID in changedConversationMessagesIDs {
                try await pushMessages(for: conversationID)
            }
        }
    }

    // MARK: - Agent Sync

    func pushAgent(_ agent: Agent) async throws {
        let record = try agentToRecord(agent)
        do {
            _ = try await privateDatabase.save(record)
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Record already exists, fetch and update it
            let recordID = CKRecord.ID(recordName: agent.id.uuidString)
            if let existingRecord = try? await privateDatabase.record(for: recordID) {
                // Update existing record with new values
                existingRecord["name"] = agent.name as CKRecordValue
                existingRecord["description"] = agent.description as CKRecordValue
                existingRecord["icon"] = agent.icon as CKRecordValue
                existingRecord["model"] = (agent.model ?? "") as CKRecordValue
                existingRecord["systemPrompt"] = agent.systemPrompt as CKRecordValue
                existingRecord["temperature"] = agent.temperature as CKRecordValue
                existingRecord["shownInSidebar"] = (agent.shownInSidebar ? 1 : 0) as CKRecordValue
                existingRecord["lastModified"] = agent.lastModified as CKRecordValue
                _ = try await privateDatabase.save(existingRecord)
            } else {
                throw error
            }
        }
    }

    func pushAgents() async throws {
        let agents = AgentManager.shared.customAgents

        if !agents.isEmpty {
            print("  📤 Pushing \(agents.count) agent(s)")
        }

        for agent in agents {
            try await pushAgent(agent)
        }
    }

    func pullAgents() async throws {
        let query = CKQuery(recordType: agentRecordType, predicate: NSPredicate(value: true))
        let results = try await privateDatabase.records(matching: query)

        var cloudAgents: [Agent] = []

        for (_, result) in results.matchResults {
            switch result {
            case .success(let record):
                if let agent = try? recordToAgent(record) {
                    cloudAgents.append(agent)
                }
            case .failure(let error):
                print("Error fetching agent record: \(error)")
            }
        }

        // Merge with local agents
        await MainActor.run {
            mergeAgents(cloudAgents: cloudAgents)
        }
    }

    func deleteAgent(_ agentID: UUID) async throws {
        let recordID = CKRecord.ID(recordName: agentID.uuidString)
        try await privateDatabase.deleteRecord(withID: recordID)
    }

    private func mergeAgents(cloudAgents: [Agent]) {
        var mergedAgents = AgentManager.shared.customAgents
        let cloudAgentIDs = Set(cloudAgents.map { $0.id })

        // Update or add cloud agents with timestamp-based conflict resolution
        for cloudAgent in cloudAgents {
            if let index = mergedAgents.firstIndex(where: { $0.id == cloudAgent.id }) {
                // Compare lastModified timestamps - newest wins
                if cloudAgent.lastModified > mergedAgents[index].lastModified {
                    mergedAgents[index] = cloudAgent
                }
                // Otherwise keep local version - it will be pushed in the next step
            } else {
                // New agent from cloud
                mergedAgents.append(cloudAgent)
            }
        }

        // Remove local agents that don't exist in cloud (were deleted on another device)
        mergedAgents.removeAll { localAgent in
            !cloudAgentIDs.contains(localAgent.id)
        }

        AgentManager.shared.customAgents = mergedAgents
        try? AgentManager.shared.saveAgents(syncToCloudKit: false)
    }

    // MARK: - Conversation Sync

    func pushConversation(_ conversation: Conversation) async throws {
        let record = try conversationToRecord(conversation)
        do {
            _ = try await privateDatabase.save(record)
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Record already exists, fetch and update it
            let recordID = CKRecord.ID(recordName: conversation.id.uuidString)
            if let existingRecord = try? await privateDatabase.record(for: recordID) {
                // Update existing record with new values
                existingRecord["title"] = conversation.title as CKRecordValue
                existingRecord["lastInteracted"] = conversation.lastInteracted as CKRecordValue
                existingRecord["modelUsed"] = conversation.modelUsed as CKRecordValue
                existingRecord["agentUsed"] = (conversation.agentUsed?.uuidString ?? "") as CKRecordValue
                existingRecord["isArchived"] = (conversation.isArchived ? 1 : 0) as CKRecordValue
                existingRecord["hasMessages"] = (conversation.hasMessages ? 1 : 0) as CKRecordValue
                existingRecord["lastModified"] = conversation.lastModified as CKRecordValue
                _ = try await privateDatabase.save(existingRecord)
            } else {
                throw error
            }
        }
    }

    func pushConversations() async throws {
        let conversations = ChatCache.shared.conversations

        if !conversations.isEmpty {
            print("  📤 Pushing \(conversations.count) conversation(s)")
        }

        for conversation in conversations {
            try await pushConversation(conversation)
        }
    }

    func pullConversations() async throws {
        let query = CKQuery(recordType: conversationRecordType, predicate: NSPredicate(value: true))
        let results = try await privateDatabase.records(matching: query)

        var cloudConversations: [Conversation] = []

        for (_, result) in results.matchResults {
            switch result {
            case .success(let record):
                if let conversation = try? recordToConversation(record) {
                    cloudConversations.append(conversation)
                }
            case .failure(let error):
                print("Error fetching conversation record: \(error)")
            }
        }

        // Merge with local conversations
        await MainActor.run {
            mergeConversations(cloudConversations: cloudConversations)
        }
    }

    func deleteConversation(_ conversationID: UUID) async throws {
        let recordID = CKRecord.ID(recordName: conversationID.uuidString)
        try await privateDatabase.deleteRecord(withID: recordID)

        // Also delete associated messages
        try await deleteMessagesForConversation(conversationID)
    }

    private func mergeConversations(cloudConversations: [Conversation]) {
        var mergedConversations = ChatCache.shared.conversations
        let cloudConversationIDs = Set(cloudConversations.map { $0.id })

        for cloudConversation in cloudConversations {
            if let index = mergedConversations.firstIndex(where: { $0.id == cloudConversation.id }) {
                // Compare lastModified timestamps - newest wins
                if cloudConversation.lastModified > mergedConversations[index].lastModified {
                    mergedConversations[index] = cloudConversation
                }
                // Otherwise keep local version - it will be pushed in the next step
            } else {
                // New conversation from cloud
                mergedConversations.append(cloudConversation)
            }
        }

        // Remove local conversations that don't exist in cloud (were deleted on another device)
        let conversationsToDelete = mergedConversations.filter { localConversation in
            !cloudConversationIDs.contains(localConversation.id)
        }

        // Delete local files for removed conversations
        for conversation in conversationsToDelete {
            try? ConversationManager.deleteConversation(id: conversation.id)
        }

        mergedConversations.removeAll { localConversation in
            !cloudConversationIDs.contains(localConversation.id)
        }

        ChatCache.shared.conversations = mergedConversations
        try? ConversationManager.saveIndex(conversations: mergedConversations, syncToCloudKit: false)
    }

    // MARK: - Message Sync

    func pushMessage(_ message: Message, conversationID: UUID) async throws {
        let record = try messageToRecord(message, conversationID: conversationID)
        do {
            _ = try await privateDatabase.save(record)
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Record already exists, fetch and update it
            let recordID = CKRecord.ID(recordName: message.id.uuidString)
            if let existingRecord = try? await privateDatabase.record(for: recordID) {
                // Update existing record with new values
                existingRecord["conversationID"] = conversationID.uuidString as CKRecordValue
                existingRecord["text"] = message.text as CKRecordValue
                existingRecord["role"] = message.role.rawValue as CKRecordValue
                existingRecord["modelUsed"] = message.modelUsed as CKRecordValue
                existingRecord["timeStamp"] = message.timeStamp as CKRecordValue
                existingRecord["lastModified"] = message.lastModified as CKRecordValue
                existingRecord["attachmentLinks"] = message.attachmentLinks as CKRecordValue
                _ = try await privateDatabase.save(existingRecord)
            } else {
                throw error
            }
        }
    }

    func pushMessages(for conversationID: UUID) async throws {
        let messages = try ConversationManager.loadMessages(for: conversationID)

        if messages.isEmpty {
            // This might indicate why first messages don't sync
            if let conv = ChatCache.shared.conversations.first(where: { $0.id == conversationID }) {
                if conv.hasMessages {
                    print("  ⚠️ Conversation \(conversationID.uuidString.prefix(8)) has hasMessages=true but 0 messages on disk!")
                }
            }
        }

        for message in messages {
            try await pushMessage(message, conversationID: conversationID)
        }
    }

    func pushMessages() async throws {
        // Push messages for all conversations
        var totalMessages = 0
        var conversationDetails: [(UUID, Int, Bool)] = [] // (id, messageCount, hasMessages)

        for conversation in ChatCache.shared.conversations {
            let messages = try? ConversationManager.loadMessages(for: conversation.id)
            let count = messages?.count ?? 0
            totalMessages += count
            conversationDetails.append((conversation.id, count, conversation.hasMessages))
        }

        if totalMessages > 0 {
            print("  📤 Pushing \(totalMessages) message(s) across \(ChatCache.shared.conversations.count) conversation(s)")
            // Debug: Show details for conversations with mismatched state
            for (id, count, hasMessages) in conversationDetails {
                if (count == 0 && hasMessages) || (count > 0 && !hasMessages) {
                    print("  ⚠️ Conversation \(id.uuidString.prefix(8)) - hasMessages:\(hasMessages) but \(count) messages on disk")
                }
            }
        }

        for conversation in ChatCache.shared.conversations {
            try await pushMessages(for: conversation.id)
        }
    }

    func pullMessages(for conversationID: UUID) async throws {
        let predicate = NSPredicate(format: "conversationID == %@", conversationID.uuidString)
        let query = CKQuery(recordType: messageRecordType, predicate: predicate)

        let results = try await privateDatabase.records(matching: query)

        var cloudMessages: [Message] = []

        for (_, result) in results.matchResults {
            switch result {
            case .success(let record):
                if let message = try? recordToMessage(record) {
                    cloudMessages.append(message)
                }
            case .failure(let error):
                print("Error fetching message record: \(error)")
            }
        }

        // Merge with local messages
        await MainActor.run {
            mergeMessages(cloudMessages: cloudMessages, conversationID: conversationID)
        }
    }

    func pullMessages() async throws {
        // Pull messages for all conversations
        for conversation in ChatCache.shared.conversations {
            try await pullMessages(for: conversation.id)
        }
    }

    func deleteMessage(_ messageID: UUID) async throws {
        let recordID = CKRecord.ID(recordName: messageID.uuidString)
        try await privateDatabase.deleteRecord(withID: recordID)
    }

    private func deleteMessagesForConversation(_ conversationID: UUID) async throws {
        let predicate = NSPredicate(format: "conversationID == %@", conversationID.uuidString)
        let query = CKQuery(recordType: messageRecordType, predicate: predicate)
        let results = try await privateDatabase.records(matching: query)

        for (recordID, _) in results.matchResults {
            try? await privateDatabase.deleteRecord(withID: recordID)
        }
    }

    private func mergeMessages(cloudMessages: [Message], conversationID: UUID) {
        var localMessages = (try? ConversationManager.loadMessages(for: conversationID)) ?? []

        // Create a dictionary of local messages by ID for faster lookup and conflict resolution
        var localMessageDict = Dictionary(uniqueKeysWithValues: localMessages.map { ($0.id, $0) })

        // Merge cloud messages with timestamp-based conflict resolution
        for cloudMessage in cloudMessages {
            if let localMessage = localMessageDict[cloudMessage.id] {
                // Message exists locally - compare timestamps
                if cloudMessage.lastModified > localMessage.lastModified {
                    // Cloud version is newer
                    localMessageDict[cloudMessage.id] = cloudMessage
                }
                // Otherwise keep local version
            } else {
                // New message from cloud
                localMessageDict[cloudMessage.id] = cloudMessage
            }
        }

        // Convert back to array and sort by timestamp
        localMessages = Array(localMessageDict.values)
        localMessages.sort { $0.timeStamp < $1.timeStamp }

        // Save merged messages to disk (without triggering CloudKit sync to avoid infinite loop)
        try? ConversationManager.saveMessages(for: conversationID, messages: localMessages, syncToCloudKit: false)

        // Update cached chat if loaded
        if let loadedChat = ChatCache.shared.loadedChats[conversationID] {
            loadedChat.messages = localMessages
        }
    }

    // MARK: - Record Conversion Methods

    private func agentToRecord(_ agent: Agent) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: agent.id.uuidString)
        let record = CKRecord(recordType: agentRecordType, recordID: recordID)

        record["name"] = agent.name as CKRecordValue
        record["description"] = agent.description as CKRecordValue
        record["icon"] = agent.icon as CKRecordValue
        record["model"] = (agent.model ?? "") as CKRecordValue
        record["systemPrompt"] = agent.systemPrompt as CKRecordValue
        record["temperature"] = agent.temperature as CKRecordValue
        record["shownInSidebar"] = (agent.shownInSidebar ? 1 : 0) as CKRecordValue
        record["lastModified"] = agent.lastModified as CKRecordValue

        return record
    }

    private func recordToAgent(_ record: CKRecord) throws -> Agent {
        guard let name = record["name"] as? String,
              let description = record["description"] as? String,
              let icon = record["icon"] as? String,
              let systemPrompt = record["systemPrompt"] as? String,
              let temperature = record["temperature"] as? Double,
              let shownInSidebarInt = record["shownInSidebar"] as? Int else {
            throw NSError(domain: "CloudKitSyncManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid agent record"])
        }

        let model = record["model"] as? String
        let id = UUID(uuidString: record.recordID.recordName) ?? UUID()
        let lastModified = record["lastModified"] as? Date ?? Date.now

        return Agent(
            id: id,
            name: name,
            description: description,
            icon: icon,
            model: model?.isEmpty == true ? nil : model,
            systemPrompt: systemPrompt,
            temperature: temperature,
            shownInSidebar: shownInSidebarInt == 1,
            lastModified: lastModified
        )
    }

    private func conversationToRecord(_ conversation: Conversation) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: conversation.id.uuidString)
        let record = CKRecord(recordType: conversationRecordType, recordID: recordID)

        record["title"] = conversation.title as CKRecordValue
        record["lastInteracted"] = conversation.lastInteracted as CKRecordValue
        record["modelUsed"] = conversation.modelUsed as CKRecordValue
        record["agentUsed"] = (conversation.agentUsed?.uuidString ?? "") as CKRecordValue
        record["isArchived"] = (conversation.isArchived ? 1 : 0) as CKRecordValue
        record["hasMessages"] = (conversation.hasMessages ? 1 : 0) as CKRecordValue
        record["lastModified"] = conversation.lastModified as CKRecordValue

        return record
    }

    private func recordToConversation(_ record: CKRecord) throws -> Conversation {
        guard let title = record["title"] as? String,
              let lastInteracted = record["lastInteracted"] as? Date,
              let modelUsed = record["modelUsed"] as? String,
              let isArchivedInt = record["isArchived"] as? Int,
              let hasMessagesInt = record["hasMessages"] as? Int else {
            throw NSError(domain: "CloudKitSyncManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid conversation record"])
        }

        let agentUsedString = record["agentUsed"] as? String
        let agentUsed = agentUsedString?.isEmpty == false ? UUID(uuidString: agentUsedString!) : nil
        let id = UUID(uuidString: record.recordID.recordName) ?? UUID()
        let lastModified = record["lastModified"] as? Date ?? Date.now

        return Conversation(
            id: id,
            title: title,
            lastInteracted: lastInteracted,
            modelUsed: modelUsed,
            agentUsed: agentUsed,
            isArchived: isArchivedInt == 1,
            hasMessages: hasMessagesInt == 1,
            lastModified: lastModified
        )
    }

    private func messageToRecord(_ message: Message, conversationID: UUID) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: message.id.uuidString)
        let record = CKRecord(recordType: messageRecordType, recordID: recordID)

        record["conversationID"] = conversationID.uuidString as CKRecordValue
        record["text"] = message.text as CKRecordValue
        record["role"] = message.role.rawValue as CKRecordValue
        record["modelUsed"] = message.modelUsed as CKRecordValue
        record["timeStamp"] = message.timeStamp as CKRecordValue
        record["lastModified"] = message.lastModified as CKRecordValue

        // Store attachment links as an array (CloudKit expects STRING_LIST)
        record["attachmentLinks"] = message.attachmentLinks as CKRecordValue

        return record
    }

    private func recordToMessage(_ record: CKRecord) throws -> Message {
        guard let text = record["text"] as? String,
              let roleString = record["role"] as? String,
              let role = MessageRole(rawValue: roleString),
              let modelUsed = record["modelUsed"] as? String,
              let timeStamp = record["timeStamp"] as? Date else {
            throw NSError(domain: "CloudKitSyncManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid message record"])
        }

        // CloudKit stores this as an array (STRING_LIST)
        let attachmentLinks = record["attachmentLinks"] as? [String] ?? []
        let id = UUID(uuidString: record.recordID.recordName) ?? UUID()
        let lastModified = record["lastModified"] as? Date ?? Date.now

        return Message(
            id: id,
            text: text,
            role: role,
            modelUsed: modelUsed,
            attachmentLinks: attachmentLinks,
            timeStamp: timeStamp,
            lastModified: lastModified
        )
    }

    // MARK: - CloudKit Subscriptions (Real-time Sync)

    /// Sets up CloudKit subscriptions for push notifications when data changes
    private func setupSubscriptions() async throws {
        print("Setting up CloudKit subscriptions...")

        // Create subscriptions for each record type
        try await setupSubscription(for: agentRecordType, subscriptionID: "agent-changes")
        try await setupSubscription(for: conversationRecordType, subscriptionID: "conversation-changes")
        try await setupSubscription(for: messageRecordType, subscriptionID: "message-changes")

        print("CloudKit subscriptions set up successfully")
    }

    private func setupSubscription(for recordType: String, subscriptionID: String) async throws {
        // Check if subscription already exists
        let existingSubscriptions = try await privateDatabase.allSubscriptions()
        if existingSubscriptions.contains(where: { $0.subscriptionID == subscriptionID }) {
            print("Subscription \(subscriptionID) already exists")
            return
        }

        // Create query subscription (notifies on any changes to this record type)
        let predicate = NSPredicate(value: true) // All records of this type
        let subscription = CKQuerySubscription(recordType: recordType, predicate: predicate, subscriptionID: subscriptionID, options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion])

        // Configure notification
        let notification = CKSubscription.NotificationInfo()
        notification.shouldSendContentAvailable = true // Silent notification
        subscription.notificationInfo = notification

        // Save subscription
        _ = try await privateDatabase.save(subscription)
        print("Created subscription: \(subscriptionID)")
    }

    /// Handles remote CloudKit notifications (call this when app receives push notification)
    func handleRemoteNotification(userInfo: [AnyHashable: Any]) async {
        print("Received CloudKit notification")

        // Check if it's a CloudKit notification
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            return
        }

        // Perform a sync to get the changes
        do {
            try await performFullSync()
        } catch {
            print("Error syncing after notification: \(error)")
        }
    }

    // MARK: - Utility Methods

    /// Checks if iCloud is available
    func checkiCloudStatus() async -> Bool {
        do {
            _ = try await container.accountStatus()
            return true
        } catch {
            print("iCloud not available: \(error)")
            return false
        }
    }
}
