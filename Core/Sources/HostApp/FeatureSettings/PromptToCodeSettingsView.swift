import SwiftUI

struct PromptToCodeSettingsView: View {
    final class Settings: ObservableObject {
        @AppStorage(\.hideCommonPrecedingSpacesInSuggestion)
        var hideCommonPrecedingSpacesInSuggestion
        @AppStorage(\.suggestionCodeFontSize)
        var suggestionCodeFontSize
        @AppStorage(\.promptToCodeGenerateDescription)
        var promptToCodeGenerateDescription
        @AppStorage(\.promptToCodeGenerateDescriptionInUserPreferredLanguage)
        var promptToCodeGenerateDescriptionInUserPreferredLanguage
        @AppStorage(\.promptToCodeChatModelId)
        var promptToCodeChatModelId
        @AppStorage(\.promptToCodeEmbeddingModelId)
        var promptToCodeEmbeddingModelId

        @AppStorage(\.chatModels) var chatModels
        @AppStorage(\.embeddingModels) var embeddingModels
        init() {}
    }

    @StateObject var settings = Settings()

    var body: some View {
        VStack(alignment: .center) {
            Form {
                Picker(
                    "Chat Model",
                    selection: $settings.promptToCodeChatModelId
                ) {
                    Text("Same as Chat Feature").tag("")
                    
                    if !settings.chatModels
                        .contains(where: { $0.id == settings.promptToCodeChatModelId }),
                        !settings.promptToCodeChatModelId.isEmpty
                    {
                        Text(
                            (settings.chatModels.first?.name).map { "\($0) (Default)" }
                                ?? "No Model Found"
                        )
                        .tag(settings.promptToCodeChatModelId)
                    }

                    ForEach(settings.chatModels, id: \.id) { chatModel in
                        Text(chatModel.name).tag(chatModel.id)
                    }
                }

                Picker(
                    "Embedding Model",
                    selection: $settings.promptToCodeEmbeddingModelId
                ) {
                    Text("Same as Chat Feature").tag("")
                    
                    if !settings.embeddingModels
                        .contains(where: { $0.id == settings.promptToCodeEmbeddingModelId }),
                        !settings.promptToCodeEmbeddingModelId.isEmpty
                    {
                        Text(
                            (settings.embeddingModels.first?.name).map { "\($0) (Default)" }
                                ?? "No Model Found"
                        )
                        .tag(settings.promptToCodeEmbeddingModelId)
                    }

                    ForEach(settings.embeddingModels, id: \.id) { embeddingModel in
                        Text(embeddingModel.name).tag(embeddingModel.id)
                    }
                }

                Toggle(isOn: $settings.promptToCodeGenerateDescription) {
                    Text("Generate Description")
                }

                Toggle(isOn: $settings.promptToCodeGenerateDescriptionInUserPreferredLanguage) {
                    Text("Generate Description in user preferred language")
                }
            }

            Divider()

            Text("Mirroring Settings of Suggestion Feature")
                .foregroundColor(.white)
                .padding(.vertical, 2)
                .padding(.horizontal, 8)
                .background(
                    Color.accentColor,
                    in: RoundedRectangle(cornerRadius: 20)
                )

            Form {
                Toggle(isOn: $settings.hideCommonPrecedingSpacesInSuggestion) {
                    Text("Hide Common Preceding Spaces")
                }.disabled(true)

                HStack {
                    TextField(text: .init(get: {
                        "\(Int(settings.suggestionCodeFontSize))"
                    }, set: {
                        settings.suggestionCodeFontSize = Double(Int($0) ?? 0)
                    })) {
                        Text("Font size of suggestion code")
                    }
                    .textFieldStyle(.roundedBorder)

                    Text("pt")
                }.disabled(true)
            }
        }
    }
}

struct PromptToCodeSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        PromptToCodeSettingsView()
    }
}

