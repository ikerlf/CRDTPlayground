///
/// Observed-Remove naive implementation
///

import Foundation
import XCTest

// MARK: - ORSet type implementation

class ORSet {
    
    typealias Tag = UUID
    
    struct TagProvider {
        var tag: () -> Tag
        static let live = TagProvider(tag: { .init() })
    }
    
    private(set)lazy var addSet: [AnyHashable : Set<Tag>] = [:]
    private(set)lazy var removeSet: [AnyHashable : Set<Tag>] = [:]
    private let tagProvider: TagProvider
    
    init(tagProvider: TagProvider = .live) {
        self.tagProvider = tagProvider
    }
    
    func add(_ value: AnyHashable) {
        if var previousSet = addSet[value] {
            // add new tag to existing stored value
            previousSet.insert(tagProvider.tag())
            addSet[value] = previousSet
        } else {
            var emptySet = Set<Tag>()
            emptySet.insert(tagProvider.tag())
            addSet[value] = emptySet
        }
    }
    
    func remove(_ value: AnyHashable) {
        guard let addedTagsSet = addSet[value] else { return }
        removeSet[value] = addedTagsSet
    }
    
    func merge(with other: ORSet) {
        addSet.merge(other.addSet) { initialTagSet, otherTagSet in
            initialTagSet.union(otherTagSet)
        }
        removeSet.merge(other.removeSet) { initialTagSet, otherTagSet in
            initialTagSet.union(otherTagSet)
        }
    }
    
    func contains(_ value: AnyHashable) -> Bool {
        guard var addTagSet = addSet[value] else { return false }
        let removeSet = removeSet[value] ?? .init()
        addTagSet.subtract(removeSet)
        return !addTagSet.isEmpty
    }
}

// MARK: - Testing

class ORSetTests: XCTestCase {
    
    var sut: ORSet!
    
    override func setUp() {
        super.setUp()
        sut = ORSet()
    }
    
    func testAdditionOnSingleORSet() {
        // Given - sut already initialized
        // When
        sut.add(1)
        // Then
        XCTAssert(sut.contains(1))
    }
    
    func testAdditionAndSubstractionOnSingleORSet() {
        // Given - sut already initialized
        // When
        sut.add(1)
        sut.remove(1)
        XCTAssertFalse(sut.contains(1))
    }
    
    func testORMergeWithoutValueCollision() {
        // Given
        let otherSet = ORSet()
        // When
        sut.add(1)
        sut.add(2)
        otherSet.add(3)
        otherSet.add(4)
        sut.merge(with: otherSet)
        // Then
        XCTAssert(sut.contains(1))
        XCTAssert(sut.contains(2))
        XCTAssert(sut.contains(3))
        XCTAssert(sut.contains(4))
    }
    
    func testORMergeWithValueAdditionCollision() {
        // Given
        let otherSet = ORSet()
        // When
        sut.add(1)
        sut.add(2)
        otherSet.add(2)
        otherSet.add(3)
        sut.merge(with: otherSet)
        // Then
        XCTAssert(sut.contains(1))
        XCTAssert(sut.contains(2))
        XCTAssert(sut.contains(3))
    }
    
    func testORMergeWithValueAdditionAndRemovalCollision() {
        // Given
        let otherSet = ORSet()
        // When
        sut.add(1)
        sut.remove(1)
        otherSet.add(1)
        otherSet.remove(1)
        otherSet.add(1)
        sut.merge(with: otherSet)
        // Then
        XCTAssert(sut.contains(1))
    }
}

ORSetTests.defaultTestSuite.run()
