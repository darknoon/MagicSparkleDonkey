//
//  ComponentStoreTests.swift
//  Tests-macOS
//
//  Created by Andrew Pouliot on 4/16/21.
//

import XCTest
@testable import MSD
import simd

class ComponentStoreTests_macOS: XCTestCase {

    struct TestComponent : Component, Equatable {
        var hello: Int
    }

    func testComponentCollection() {
        let entry = ComponentCollection<TestComponent>()
        let eid = Entity.ID()
        
        // No component is stored for this id until one is added
        XCTAssertNil(entry[eid])
        XCTAssertEqual(entry.count, 0)
        
        let c = TestComponent(hello: 42)
        entry[eid] = c
        
        XCTAssertEqual(entry[eid]!, c)
        XCTAssertEqual(entry.count, 1)

        // Re-assigning should keep count
        entry[eid] = c
        XCTAssertEqual(entry.count, 1)

        let anyEntry = entry.eraseToAny()
        
        let eimpl = anyEntry.impl as? ComponentCollection<TestComponent>
        XCTAssertEqual(eimpl![eid]!, c)
    }
    
    func testIterateAllTransforms() {
        // Create 3 entities with transforms
        var store = ComponentStore()
        
        let entKp = (0...4).map{ i -> (Entity.ID, Transform) in
            let id = store.createEntity()
            let c = TransformComponent(transform: .init(scale: simd_float3(repeating: Float(i))))
            store.set(id: id, component: c)
            return (id, c.transform)
        }
        let expected = Dictionary(uniqueKeysWithValues: entKp)
        
        var actual = [Entity.ID : Transform]()
        store.forEach { (id: Entity.ID, t: inout TransformComponent) in
            actual[id] = t.transform
        }
        XCTAssertEqual(expected, actual)
        
    }
    
    func testIterateAllEntities() {
        var store = ComponentStore()
        
        let end  = 123
        for _ in 0..<end {
            let _ = store.createEntity()
        }

        let actual = store.ids.map{$0.index}
        
        XCTAssertEqual(Set(actual), Set(0..<Entity.ID(end) ))
    }
    
}
