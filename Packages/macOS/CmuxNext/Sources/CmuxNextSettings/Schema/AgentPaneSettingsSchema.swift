import CmuxNextDesign

/// The agent pane's settings rows.
/// - Replies (decisions D4 and D5): what a path chip outside the session's folders does, and when
///   a web image in a reply loads. Both decide what leaves the project or the machine, so an agent
///   may not change them (``SettingsSchema/agentRefusedKeys``).
/// - The edited-files card (General > Agent Chats): looks only, so agents may change them.
nonisolated enum AgentPaneSettingsSchema {
    static var descriptors: [SettingDescriptor] { replyDescriptors + editedFilesDescriptors }

    static var replyDescriptors: [SettingDescriptor] {
        let group = SettingsText.keyed("settings.group.agentChat", "Agent Chat")
        return [
            SettingDescriptor(
                AgentPaneReplySetting.outsideRootsPath, section: .general, group: group,
                title: SettingsText.keyed("settings.agentPane.outsideRoots", "Files Outside the Project"),
                help: SettingsText.keyed("settings.agentPane.outsideRoots.help",
                                         "What a file link in a reply does when the file is outside the chat's folders. Keys and .env files never open."),
                kind: .choice([
                    SettingChoice("confirm", SettingsText.keyed("settings.choice.agentPaneConfirm", "Ask First")),
                    SettingChoice("text", SettingsText.keyed("settings.choice.agentPaneText", "Show as Text")),
                    SettingChoice("open", SettingsText.keyed("settings.choice.agentPaneOpen", "Open")),
                ]),
                default: .string(AgentPaneReplySetting.fallback.outsideRoots.rawValue),
                keywords: ["agent", "chat", "link", "path", "file", "outside", "project"]
            ),
            SettingDescriptor(
                AgentPaneReplySetting.remoteImagesPath, section: .general, group: group,
                title: SettingsText.keyed("settings.agentPane.remoteImages", "Web Images in Replies"),
                help: SettingsText.keyed("settings.agentPane.remoteImages.help",
                                         "A web image loads from its site, which then sees that you read the reply."),
                kind: .choice([
                    SettingChoice("click", SettingsText.keyed("settings.choice.agentPaneClick", "Load on Click")),
                    SettingChoice("never", SettingsText.keyed("settings.choice.never", "Never")),
                    SettingChoice("always", SettingsText.keyed("settings.choice.always", "Always")),
                ]),
                default: .string(AgentPaneReplySetting.fallback.remoteImages.rawValue),
                keywords: ["agent", "chat", "image", "remote", "web", "privacy", "tracking"]
            ),
        ]
    }

    static var editedFilesDescriptors: [SettingDescriptor] {
        let group = SettingsText.keyed("settings.group.agentChats", "Agent Chats")
        typealias S = AgentPaneEditedFilesSetting
        let fallback = S.fallback
        return [
            SettingDescriptor(
                S.showPath, section: .general, group: group,
                title: SettingsText.keyed("settings.agentPane.editedFiles.show", "Edited Files Card"),
                help: SettingsText.keyed("settings.agentPane.editedFiles.show.help",
                                         "The card that lists a turn's edited files, with Undo and View changes."),
                kind: .choice([
                    SettingChoice("always", SettingsText.keyed("settings.choice.editedFilesAlways", "Always")),
                    SettingChoice("collapsed", SettingsText.keyed("settings.choice.editedFilesCollapsed", "Collapsed")),
                    SettingChoice("never", SettingsText.keyed("settings.choice.editedFilesNever", "Never")),
                ]),
                default: .string(fallback.show), keywords: ["edited", "files", "undo", "changes", "agent"]
            ),
            SettingDescriptor(
                S.maxRowsPath, section: .general, group: group,
                title: SettingsText.keyed("settings.agentPane.editedFiles.maxRows", "Edited Files Shown"),
                kind: .number(SettingNumber(S.maxRowsRange, step: 1, unit: .count)), default: .number(Double(fallback.maxRows)),
                keywords: ["edited", "files", "rows", "agent"]
            ),
            SettingDescriptor(
                S.scopePath, section: .general, group: group,
                title: SettingsText.keyed("settings.agentPane.editedFiles.scope", "Edited Files Card Covers"),
                kind: .choice([
                    SettingChoice("turn", SettingsText.keyed("settings.choice.editedFilesTurn", "Each Turn")),
                    SettingChoice("session", SettingsText.keyed("settings.choice.editedFilesSession", "The Whole Chat")),
                ]),
                default: .string(fallback.scope), keywords: ["edited", "files", "session", "turn", "agent"]
            ),
        ]
    }

    /// The reply rows' ids.
    static var keys: Set<String> { Set(replyDescriptors.map(\.id)) }

    /// Looks only: agents may change the edited-files rows (not the reply rows).
    static var agentSettableKeys: Set<String> { Set(editedFilesDescriptors.map(\.id)) }
}
