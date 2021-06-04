//
//  File.swift
//  
//
//  Created by Andrew Pouliot on 4/30/21.
//

import XCTest
@testable import MSD

class ComponentIDTests : XCTestCase {

    struct A : Component {
        let i: Int
    }
    struct B : Component {
        let i: Int
    }
    
    func test() {
        let ai = A.ID
        let bi = B.ID
        print("ai is \(ai), bi is \(bi)")
        
        XCTAssertNotEqual(ai, bi)
    }
}
