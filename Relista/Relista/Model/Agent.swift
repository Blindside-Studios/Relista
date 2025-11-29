//
//  Agent.swift
//  Relista
//
//  Created by Nicolas Helbig on 19.11.25.
//

import Foundation
import Combine

struct Agent: Identifiable, Hashable, Codable{
    var id = UUID()
    var name: String
    var description: String
    var icon: String
    var model: String?
    var systemPrompt: String
    var temperature: Double
    var shownInSidebar: Bool
    var lastModified: Date

    // Custom Codable implementation for backwards compatibility
    enum CodingKeys: String, CodingKey {
        case id, name, description, icon, model, systemPrompt, temperature, shownInSidebar, lastModified
    }

    init(id: UUID = UUID(), name: String, description: String, icon: String, model: String?, systemPrompt: String, temperature: Double, shownInSidebar: Bool, lastModified: Date = Date.now) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.model = model
        self.systemPrompt = systemPrompt
        self.temperature = temperature
        self.shownInSidebar = shownInSidebar
        self.lastModified = lastModified
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        icon = try container.decode(String.self, forKey: .icon)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        systemPrompt = try container.decode(String.self, forKey: .systemPrompt)
        temperature = try container.decode(Double.self, forKey: .temperature)
        shownInSidebar = try container.decode(Bool.self, forKey: .shownInSidebar)
        // Backwards compatible: default to now if missing
        lastModified = try container.decodeIfPresent(Date.self, forKey: .lastModified) ?? Date.now
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(icon, forKey: .icon)
        try container.encode(model, forKey: .model)
        try container.encode(systemPrompt, forKey: .systemPrompt)
        try container.encode(temperature, forKey: .temperature)
        try container.encode(shownInSidebar, forKey: .shownInSidebar)
        try container.encode(lastModified, forKey: .lastModified)
    }
}

public class AgentManager: ObservableObject {
    static let shared = AgentManager()

    @Published var customAgents: [Agent] = []
    
    init(){
        try? initializeStorage()
        try? customAgents = loadAgents()
    }
    
    private let documentsURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }()
    
    private var relistaURL: URL {
        documentsURL.appendingPathComponent("Relista")
    }
    
    private var fileURL: URL {
        relistaURL.appendingPathComponent("agents.json")
    }
    
    func initializeStorage() throws {
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: relistaURL.path) {
            try fileManager.createDirectory(at: relistaURL, withIntermediateDirectories: true)
        }
    }
    
    func saveAgents() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let data = try encoder.encode(customAgents)
        try data.write(to: fileURL)

        // Mark agents as changed and sync to CloudKit (debounced to avoid rate limiting)
        CloudKitSyncManager.shared.markAgentsChanged()
        CloudKitSyncManager.shared.debouncedPush()
    }
    
    func loadAgents() throws -> [Agent] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []  // No index yet, return empty
        }
        
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode([Agent].self, from: data)
    }
    
    static func createNewAgent() -> Agent {
        return Agent(name: "", description: "", icon: "", model: "mistralai/mistral-medium-3.1", systemPrompt: "", temperature: 0.3, shownInSidebar: true, lastModified: Date.now)
    }
    
    static func getAgent(fromUUID: UUID) -> Agent?{
        return AgentManager.shared.customAgents.filter { $0.id == fromUUID }.first
    }

    /// Updates an agent's lastModified timestamp - call before saving
    func touchAgent(id: UUID) {
        if let index = customAgents.firstIndex(where: { $0.id == id }) {
            customAgents[index].lastModified = Date.now
        }
    }

    /// Updates multiple agents' lastModified timestamps - call before saving
    func touchAllAgents() {
        for index in customAgents.indices {
            customAgents[index].lastModified = Date.now
        }
    }
}
