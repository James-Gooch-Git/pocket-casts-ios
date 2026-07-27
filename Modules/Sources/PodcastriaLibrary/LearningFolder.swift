import Foundation

/// A nestable folder that can hold podcasts, sub-folders, or both.
///
/// Existing Pocket Casts `Folder` is flat — one level. Podcastria's USP is
/// deep topic hierarchies ("History > Ancient Rome > Punic Wars") and smart
/// folders that auto-populate from a query.
///
/// The data is kept in the module's own storage rather than extending the
/// inherited Folder table, because sub-folder nesting and smart-folder rules
/// are Podcastria-only concepts and shouldn't leak into the shared data model.
public struct LearningFolder: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var parentID: UUID?
    public var name: String
    public var color: Int32
    public var sortOrder: Int32
    public var smartRule: SmartFolderRule?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        parentID: UUID? = nil,
        name: String,
        color: Int32 = 0,
        sortOrder: Int32 = 0,
        smartRule: SmartFolderRule? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.parentID = parentID
        self.name = name
        self.color = color
        self.sortOrder = sortOrder
        self.smartRule = smartRule
        self.createdAt = createdAt
    }

    public var isSmart: Bool { smartRule != nil }
    public var isRoot: Bool { parentID == nil }
}

/// Defines how a smart folder auto-populates with podcasts.
///
/// Smart folders evaluate their rule against the user's subscribed podcasts
/// and surface matching shows without manual curation. Rules can match on
/// podcast metadata (title, author, category) or on episode content
/// (subjects, series keys).
public struct SmartFolderRule: Codable, Equatable, Sendable {
    public enum Field: String, Codable, Sendable {
        case title
        case author
        case category
        case subject
        case seriesKey = "series_key"
    }

    public enum Operator: String, Codable, Sendable {
        case contains
        case equals
        case startsWith = "starts_with"
    }

    public let field: Field
    public let op: Operator
    public let value: String

    public init(field: Field, op: Operator, value: String) {
        self.field = field
        self.op = op
        self.value = value
    }

    enum CodingKeys: String, CodingKey {
        case field
        case op = "operator"
        case value
    }
}

/// A tree built from a flat list of `LearningFolder` for UI rendering.
public struct LearningFolderNode: Identifiable {
    public let folder: LearningFolder
    public var children: [LearningFolderNode]

    public var id: UUID { folder.id }

    public static func buildTree(from folders: [LearningFolder]) -> [LearningFolderNode] {
        let byParent = Dictionary(grouping: folders, by: \.parentID)
        return buildChildren(parentID: nil, lookup: byParent)
    }

    private static func buildChildren(
        parentID: UUID?,
        lookup: [UUID?: [LearningFolder]]
    ) -> [LearningFolderNode] {
        guard let children = lookup[parentID] else { return [] }
        return children
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { folder in
                LearningFolderNode(
                    folder: folder,
                    children: buildChildren(parentID: folder.id, lookup: lookup)
                )
            }
    }
}

/// Membership: which podcasts live in which folder.
///
/// A podcast can appear in multiple folders (a show about "Roman Britain"
/// might sit in both "Ancient Rome" and "Great Britain"). Smart folders
/// compute membership dynamically; manual folders store it here.
public struct LearningFolderMembership: Codable, Equatable, Sendable {
    public let folderID: UUID
    public let podcastUUID: String
    public var sortOrder: Int32

    public init(folderID: UUID, podcastUUID: String, sortOrder: Int32 = 0) {
        self.folderID = folderID
        self.podcastUUID = podcastUUID
        self.sortOrder = sortOrder
    }

    enum CodingKeys: String, CodingKey {
        case folderID = "folder_id"
        case podcastUUID = "podcast_uuid"
        case sortOrder = "sort_order"
    }
}
