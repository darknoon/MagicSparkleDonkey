//
//  File.swift
//  
//
//  Created by Andrew Pouliot on 4/27/21.
//

import Foundation

import XCTest
@testable import MSD
import simd

class SparseSetTests_macOS: XCTestCase {

    func testBasicCreate() {
        var set = SparseIntSet()
        
        set.insert(0)
        set.insert(1)
        set.insert(3)
        set.insert(4)
        
        XCTAssertEqual(set.map{$0}, [0,1,3,4])
    }
    
    func testAddRemove() {
        var set: SparseIntSet = [0, 1, 3, 4]
        
        // Should do nothing
        set.remove(2)
        XCTAssertEqual(set.count, 4)
        XCTAssertEqual(Set(set.map{$0}), Set([0,1,3,4]))

        // Should remove 1
        set.remove(1)
        XCTAssertEqual(set.count, 3)
        XCTAssertEqual(Set(set.map{$0}), Set([0,3,4]))

    }
    
    func testEquality() {
        let a: SparseIntSet = [0, 1, 3, 4]
        let b: SparseIntSet = [4, 3, 1, 0]

        XCTAssertEqual(a, b)
    }
    
    func testAddSecondPage() {
        var set = SparseIntSet()
        
        XCTAssertEqual(set.activePageCount, 0)
        
        
        // Force-allocate a later page
        let elementsPerPage = type(of: set).SparseArray.elementsPerPage
        for i in 0..<elementsPerPage {
            set.insert(4 * elementsPerPage + i)
        }
        
        XCTAssertEqual(set.activePageCount, 1)
    }
    
    func testAddRandom() {
        var set = SparseIntSet()

        for i in (0..<10_000).reversed() {
            set.insert(i)
        }
        
        let elementsPerPage = type(of: set).SparseArray.elementsPerPage
        XCTAssertEqual(set.activePageCount, (10_000 + elementsPerPage - 1) / elementsPerPage)

        for i in 0..<5_000 {
            set.remove(i)
        }
        XCTAssertEqual(set.activePageCount, 11)
    }
    
    func testRemoveItemNotInSet() {
        
    }
    
    func testMultiplesThrash() {
        let max = 10_000
        
        var set = SparseIntSet()

        // Add multiples of each integer in this range
        for (addBy, remBy) in [(3, 5), (7, 9)] {
            // Add
            for j in stride(from: 0, to: max, by: addBy) {
                set.insert(j)
            }
            
            for j in stride(from: 0, to: max, by: remBy) {
                set.remove(j)
            }
        }
    }
    
    func testDeallocatePages() {
        var set = SparseIntSet()
        
        let page = 511
        
        set.insert(12)
        set.insert(12 + page)
        set.insert(12 + 2 * page)
        
        
        XCTAssertEqual(set.count, 3)
        XCTAssertEqual(set.activePageCount, 3)
        
        set.remove(12)
        XCTAssertEqual(set.activePageCount, 2)

        set.remove(12 + 2 * page)
        XCTAssertEqual(set.activePageCount, 1)

        set.remove(12 + page)
        XCTAssertEqual(set.activePageCount, 0)
    }

}
