//
//  ModelList.swift
//  Relista
//
//  Created by Nicolas Helbig on 15.11.25.
//

import Foundation
import SwiftUI

enum ModelProvider: String, CaseIterable, Decodable {
    case openAI = "OpenAI"
    case mistral = "Mistral"
    case anthropic = "Anthropic"
    case perplexity = "Perplexity"
    case google = "Google"
    case deepSeek = "DeepSeek"
    case uncategorized = "Uncategorized"
}

struct AIModel: Identifiable, Hashable {
    var id = UUID()
    let name: String
    let modelID: String
    let provider: ModelProvider
    
    let family: String?
    let specifier: String?
    
    let isFree: Bool
}

struct RemoteAIModel: Codable {
    let name: String
    let modelID: String
    let provider: String
    let family: String?
    let specifier: String?
    let isFree: Bool
    
    func toLocal() -> AIModel? {
        let providerEnum = ModelProvider(rawValue: provider) ?? .uncategorized
        
        return AIModel(
            id: UUID(),
            name: name,
            modelID: modelID,
            provider: providerEnum,
            family: family,
            specifier: specifier,
            isFree: isFree
        )
    }
}

class ModelList{
    @AppStorage("AppDefaultModel") static var placeHolderModel: String = "mistralai/mistral-medium-3.1"
    static var AllModels: [AIModel] = []
    static var areModelsLoaded = false
    
    @MainActor
    static func loadModels() async {
        if await updateFromRemote() {
            if let models = loadFromCache() {
                AllModels = models.compactMap { $0.toLocal() }
                areModelsLoaded = true
                debugPrint("Models are loaded")
                return
            }
        }

        if let models = loadFromCache() {
            AllModels = models.compactMap { $0.toLocal() }
            areModelsLoaded = true
            debugPrint("Models are loaded")
            return
        }

        AllModels = loadBundledDefaults()
        // ChatCache.shared.selectedModel = Models.first ?? getModelFromSlug(slug: placeHolderModel)
        areModelsLoaded = true
        debugPrint("Models are loaded")
    }
    
    private static let remoteModelURL = URL(string: "https://raw.githubusercontent.com/Blindside-Studios/Relista/refs/heads/main/featured_models.json")!
    
    private static var cacheFileURL: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("models.json")
    }
    
    private static func updateFromRemote() async -> Bool {
        do {
            let (data, response) = try await URLSession.shared.data(from: remoteModelURL)
            
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                return false
            }
            
            _ = try JSONDecoder().decode([RemoteAIModel].self, from: data)
            
            try data.write(to: cacheFileURL, options: .atomic)
            
            return true
        } catch {
            return false
        }
    }
    
    private static func loadFromCache() -> [RemoteAIModel]? {
        do {
            let data = try Data(contentsOf: cacheFileURL)
            return try JSONDecoder().decode([RemoteAIModel].self, from: data)
        } catch {
            return nil
        }
    }
    
    private static func loadBundledDefaults() -> [AIModel] {
        debugPrint("Loading Local Preset")
        guard let url = Bundle.main.url(forResource: "featured_models_default", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([RemoteAIModel].self, from: data)
        else {
            debugPrint("Returning existing variable instead")
            return AllModels
        }
        return decoded.compactMap { $0.toLocal() }
    }
    
    public static func getModelFromSlug(slug: String) -> AIModel{
        let filteredModels = AllModels.filter({$0.modelID == slug})
        if !filteredModels.isEmpty{
            return filteredModels.first!
        }
        else{
            let parsedSlug = parseSlug(slug)
            return AIModel(
                id: UUID(),
                name: slug,
                modelID: slug,
                provider: .uncategorized,
                family: parsedSlug.family,
                specifier: parsedSlug.specifier,
                isFree: false
            )
        }
    }
    
    private static func parseSlug(_ slug: String) -> (family: String, specifier: String) {
        let parts = slug.split(separator: "/", maxSplits: 1).map(String.init)
        return (parts.first ?? "", parts.count > 1 ? parts[1] : "")
    }

}
