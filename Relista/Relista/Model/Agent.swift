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
        return Agent(name: "", description: "", icon: "", model: "mistralai/mistral-medium-3.1", systemPrompt: "", temperature: 0.3, shownInSidebar: true)
    }
    
    static func getAgent(fromUUID: UUID) -> Agent?{
        return AgentManager.shared.customAgents.filter { $0.id == fromUUID }.first
    }
}
