//
//  ComponentStoreTests.swift
//  Tests-macOS
//
//  Created by Andrew Pouliot on 4/16/21.
//

import XCTest
@testable import MSD
import simd

fileprivate extension Entity {
    var testComponent: EntityTests.TestComponent? {
        get { self[EntityTests.TestComponent.self] }
        set { self[EntityTests.TestComponent.self] = newValue }
    }
}

class EntityTests: XCTestCase {

    struct TestComponent : Component, Equatable {
        var hello: Int
    }

    func testCreateEntity() {
        let scene = MSD.Scene()
        var root = scene.rootEntity
        
        XCTAssertEqual(root.testComponent, nil)
        
        root.testComponent = TestComponent(hello: 123)

        XCTAssertEqual(root.testComponent, TestComponent(hello: 123))
    }
    
    func testCreateChild() {
        let scene = MSD.Scene()
        var root = scene.rootEntity
        
        let offset = simd_float3(x: 0, y: 1, z: 0)
        
        var rootChildren = root.children!
        var child = scene.store.createEntity()
        child.transform = TransformComponent(Transform(translation: offset))
        rootChildren.append(child)
        root.children = rootChildren

        // Iterate children of root, should have 1 child with the given offset
        XCTAssertEqual(root.childEntities?.map{$0.transform?.transform}, [Optional(Transform(translation: offset))])
        
    }
    
}
