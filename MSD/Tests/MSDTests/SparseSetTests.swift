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
        var set = SparseSet<Int>()
        
        set.insert(0)
        set.insert(1)
        set.insert(3)
        set.insert(4)
        
        XCTAssertEqual(set.map{$0}, [0,1,3,4])
    }
    
    func testAddRemove() {
        var set = SparseSet<Int>()
        
        set.insert(0)
        set.insert(1)
        set.insert(2)
        set.insert(3)
        set.insert(4)
        
        set.remove(2)
        
        XCTAssertEqual(Set(set.map{$0}), Set([0,1,3,4]))
    }
    
    func testAddSecondPage() {
        var set = SparseSet<Int>()
        
        XCTAssertEqual(set.usedPageCount, 0)
        
        
        // Force-allocate a later page
        let elementsPerPage = type(of: set).elementsPerPage
        for i in 0..<elementsPerPage {
            set.insert(4 * elementsPerPage + i)
        }
        
        XCTAssertEqual(set.usedPageCount, 1)
    }
    
    func testAddRandom() {
        var set = SparseSet<Int>()

        for i in (0..<10_000).reversed() {
            set.insert(i)
        }
        
        let elementsPerPage = type(of: set).elementsPerPage
        XCTAssertEqual(set.usedPageCount, (10_000 + elementsPerPage - 1) / elementsPerPage)

        for i in 0..<5_000 {
            set.remove(i)
        }
        XCTAssertEqual(set.usedPageCount, 11)

    }

}
