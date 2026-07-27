import Foundation
import Testing
@testable import PodcastriaLibrary

// MARK: - Tree building

@Test func buildsTreeFromFlatList() {
    let root = LearningFolder(name: "History")
    let child = LearningFolder(parentID: root.id, name: "Ancient Rome", sortOrder: 0)
    let grandchild = LearningFolder(parentID: child.id, name: "Punic Wars", sortOrder: 0)
    let sibling = LearningFolder(parentID: root.id, name: "Medieval", sortOrder: 1)

    let tree = LearningFolderNode.buildTree(from: [root, child, grandchild, sibling])

    #expect(tree.count == 1)
    #expect(tree[0].folder.name == "History")
    #expect(tree[0].children.count == 2)
    #expect(tree[0].children[0].folder.name == "Ancient Rome")
    #expect(tree[0].children[0].children.count == 1)
    #expect(tree[0].children[0].children[0].folder.name == "Punic Wars")
    #expect(tree[0].children[1].folder.name == "Medieval")
}

@Test func multipleRootsAreSortedBySortOrder() {
    let b = LearningFolder(name: "Science", sortOrder: 1)
    let a = LearningFolder(name: "History", sortOrder: 0)

    let tree = LearningFolderNode.buildTree(from: [b, a])

    #expect(tree.count == 2)
    #expect(tree[0].folder.name == "History")
    #expect(tree[1].folder.name == "Science")
}

@Test func emptyInputProducesEmptyTree() {
    let tree = LearningFolderNode.buildTree(from: [])
    #expect(tree.isEmpty)
}

// MARK: - Smart folder rules

@Test func smartFolderIsIdentifiedCorrectly() {
    let smart = LearningFolder(
        name: "All Roman shows",
        smartRule: SmartFolderRule(field: .category, op: .contains, value: "Rome")
    )
    let manual = LearningFolder(name: "My picks")

    #expect(smart.isSmart)
    #expect(!manual.isSmart)
}

@Test func smartFolderRuleRoundTrips() throws {
    let rule = SmartFolderRule(field: .seriesKey, op: .startsWith, value: "punic")
    let data = try JSONEncoder().encode(rule)
    let decoded = try JSONDecoder().decode(SmartFolderRule.self, from: data)
    #expect(decoded == rule)
}

// MARK: - Membership

@Test func membershipRoundTrips() throws {
    let m = LearningFolderMembership(
        folderID: UUID(),
        podcastUUID: "7F31CCEE-87A8-4E62-B3DB-0D5FE03C8E62",
        sortOrder: 3
    )
    let data = try JSONEncoder().encode(m)
    let decoded = try JSONDecoder().decode(LearningFolderMembership.self, from: data)
    #expect(decoded == m)
}

// MARK: - Folder model

@Test func rootFolderHasNilParent() {
    let folder = LearningFolder(name: "Top-level")
    #expect(folder.isRoot)
}

@Test func childFolderIsNotRoot() {
    let parent = LearningFolder(name: "Parent")
    let child = LearningFolder(parentID: parent.id, name: "Child")
    #expect(!child.isRoot)
}
