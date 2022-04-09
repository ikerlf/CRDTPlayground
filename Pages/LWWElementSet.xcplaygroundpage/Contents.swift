///
/// Conflict-free Replicated Data Types playground
///

import Foundation
import XCTest

/// Last Write Win Element Set implementation
public class LWWElementSet {
    
    // MARK: - Internal types
    
    enum Bias {
        case adds
        case removals
    }
    
    // MARK: - Properties
    
    private lazy var addSet: [AnyHashable: Date] = [:]
    private lazy var removeSet: [AnyHashable: Date] = [:]
    
    let bias: Bias
    
    init(bias: Bias = .adds) {
        self.bias = bias
    }
    
    func add(_ value: AnyHashable, at date: Date) {
        addSet[value] = date
    }
    
    func remove(_ value: AnyHashable, at date: Date) {
        removeSet[value] = date
    }
    
    func merge(with other: LWWElementSet) {
        addSet.merge(other.addSet){ initialDate, otherDate in
            initialDate > otherDate ? initialDate : otherDate
        }
        removeSet.merge(other.removeSet){ initialDate, otherDate in
            initialDate > otherDate ? initialDate : otherDate
        }
    }
    
    func contains(_ value: AnyHashable) -> Bool {
        guard let additionTimestamp = addSet[value] else { return false}
        // If the value is contained on the addSet we need to evaluate the removeSet
        if let removalTimestamp = removeSet[value] {
            if additionTimestamp == removalTimestamp {
                // In case that the timestamp of the value stored in both sets is the same
                // apply the bias
                switch bias {
                case .adds: return true
                case .removals: return false
                }
            } else {
                return additionTimestamp > removalTimestamp
            }
        } else {
            return true
        }
    }
}

extension Date {
    static let firstMoment: Date = Date(timeIntervalSince1970: 1000000)
    static let secondMoment: Date = Date(timeIntervalSince1970: 1300000)
    static let lastMoment: Date = Date(timeIntervalSince1970: 1400000)
}

class LWWElementSetTests: XCTestCase {
    var sut: LWWElementSet!
    
    override func setUp() {
        super.setUp()
        sut = LWWElementSet()
    }
    
    func testAdditionOnSingleSet() {
        // Given - sut already initialized with a .adds bias
        // When
        sut.add(1, at: .firstMoment)
        // Then
        XCTAssert(sut.contains(1))
    }
    
    func testAdditionAndSubstractionOnSingleSet() {
        // Given - sut already initialized with a .adds bias
        // When
        sut.add(1, at: .firstMoment)
        sut.remove(1, at: .secondMoment)
        // Then
        XCTAssertFalse(sut.contains(1))
    }
    
    func testSetMergeWithoutConcurrentConflictingEvents() {
        // Given
        let otherSet = LWWElementSet()
        // When
        sut.add(1, at: .firstMoment)
        sut.add(2, at: .firstMoment)
        otherSet.add(1, at: .secondMoment)
        otherSet.remove(2, at: .secondMoment)
        sut.merge(with: otherSet)
        // Then
        XCTAssert(sut.contains(1))
        XCTAssertFalse(sut.contains(2))
    }
    
    func testAddBiasWithConcurrentConflictingEvents() {
        // Given
        let otherSet = LWWElementSet()
        // When
        sut.add(1, at: .firstMoment)
        sut.add(2, at: .secondMoment)
        otherSet.add(1, at: .secondMoment)
        otherSet.remove(2, at: .secondMoment)
        sut.merge(with: otherSet)
        // Then
        XCTAssert(sut.contains(1))
        XCTAssert(sut.contains(2))
    }
    
    func testRemovalBiasWithConcurrentConflictingEvents() {
        // Given
        sut = LWWElementSet(bias: .removals)
        let otherSet = LWWElementSet()
        // When
        sut.add(1, at: .firstMoment)
        sut.add(2, at: .secondMoment)
        otherSet.add(1, at: .secondMoment)
        otherSet.remove(2, at: .secondMoment)
        sut.merge(with: otherSet)
        // Then
        XCTAssert(sut.contains(1))
        XCTAssertFalse(sut.contains(2))
    }
}

LWWElementSetTests.defaultTestSuite.run()

