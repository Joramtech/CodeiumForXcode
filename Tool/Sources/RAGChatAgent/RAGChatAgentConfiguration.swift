import CodableWrappers
import Foundation

public struct RAGChatAgentConfiguration: Codable {
    public struct ModelConfiguration: Codable {
        public var maxTokens: Int
        public var minimumReplyTokens: Int
        public var temperature: Double
        public var systemPrompt: String

        public init(
            maxTokens: Int,
            minimumReplyTokens: Int,
            temperature: Double,
            systemPrompt: String
        ) {
            self.maxTokens = maxTokens
            self.minimumReplyTokens = minimumReplyTokens
            self.temperature = temperature
            self.systemPrompt = systemPrompt
        }
    }

    public struct ConversationConfiguration: Codable {
        public var maxTurns: Int
        public var isConversationIsolated: Bool
        public var respondInLanguage: String

        public init(maxTurns: Int, isConversationIsolated: Bool, respondInLanguage: String) {
            self.maxTurns = maxTurns
            self.isConversationIsolated = isConversationIsolated
            self.respondInLanguage = respondInLanguage
        }
    }

    public enum ServiceProvider: Codable {
        case chatModel(id: String)
        case extensionService(id: String)
    }

    public var id: String
    public var name: String
    public var serviceProvider: ServiceProvider
    @FallbackDecoding<EmptySet>
    public var capabilityIds: Set<String>

    public var modelConfiguration: ModelConfiguration
    public var conversationConfiguration: ConversationConfiguration
    var _otherConfigurations: Data

    public init<OtherConfiguration: Codable>(
        id: String,
        name: String,
        serviceProvider: ServiceProvider,
        capabilityIds: Set<String>,
        modelConfiguration: ModelConfiguration,
        conversationConfiguration: ConversationConfiguration,
        otherConfigurations: OtherConfiguration
    ) throws {
        self.id = id
        self.name = name
        self.serviceProvider = serviceProvider
        self.capabilityIds = capabilityIds
        self.modelConfiguration = modelConfiguration
        self.conversationConfiguration = conversationConfiguration
        _otherConfigurations = try JSONEncoder().encode(otherConfigurations)
    }

    public func otherConfigurations<Configuration: Codable>(
        as: Configuration.Type = Configuration.self
    ) throws -> Configuration {
        try JSONDecoder().decode(Configuration.self, from: _otherConfigurations)
    }

    public mutating func setOtherConfigurations<Configuration: Codable>(
        _ otherConfigurations: Configuration
    ) throws {
        _otherConfigurations = try JSONEncoder().encode(otherConfigurations)
    }
}

