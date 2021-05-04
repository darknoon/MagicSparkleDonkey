//
//  ComponentStoreTests.swift
//  Tests-macOS
//
//  Created by Andrew Pouliot on 4/16/21.
//

import XCTest
@testable import MSD
import simd

// Old ones
fileprivate extension ComponentStore {

    mutating func set<T: Component>(id: Entity.ID, component: T) {
        let componentType = ObjectIdentifier(T.Type.self)
        let entry: ComponentCollection<T> = findOrCreateStorageEntry(componentType: componentType)
        entry[id] = component
    }
    
    func get<T: Component>(entity: Entity.ID) -> T? {
        let componentType = ObjectIdentifier(T.Type.self)
        guard let entry: ComponentCollection<T> = findStorageEntry(componentType: componentType)
        else { return nil }
        return entry.storage[entity]
    }

}

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
    
    struct Counter : Component {
        var count: Int
        mutating func increment() {
            count += 1
        }
    }
    
    func testMutateSingle() {
        var store = ComponentStore()

        let ents = (0...9).map{ _ in store.createEntity() }
        
        // Create counters initialized 0...9
        for (i, entity) in ents.enumerated() {
            store.set(id: entity, component: Counter(count: i))
        }

        // Update counters by 1
        store.forEach{ (id: Entity.ID, counter: inout Counter) in
            counter.increment()
        }
        
        // Now check that they have been incremented
        let values: [Counter] = ents.map{ store.get(entity: $0)! }
        
        XCTAssertEqual(values.map{$0.count}, Array(1...10))
    }
    
    func testMutateTwoComponents() {
        var store = ComponentStore()

        let ents = (0...9).map{ _ in store.createEntity() }
        
        // Create counters initialized 0...9
        for (i, entity) in ents.enumerated() {
            store.set(id: entity, component: Counter(count: i))
            store.set(id: entity, component: TestComponent(hello: i))
        }

        // Update counters by 1
        store.forEach{ (id: Entity.ID, counter: inout Counter, testComponent: inout TestComponent) in
            counter.increment()
            testComponent.hello -= 1
        }
        
        // Now check that they have been incremented
        let counterValues: [Counter] = ents.map{ store.get(entity: $0)! }
        let testValues: [TestComponent] = ents.map{ store.get(entity: $0)! }

        XCTAssertEqual(counterValues.map{$0.count}, Array(1...10))
        XCTAssertEqual(testValues.map{$0.hello}, Array(-1...8))
    }
    
    func testMutateOneComponentIteratingTwo() {
        var store = ComponentStore()

        let r = 0...3
        let ents = r.map{ _ in store.createEntity() }
        
        // Create counters initialized 0...9
        for (i, entity) in ents.enumerated() {
            store.set(id: entity, component: Counter(count: i))
            store.set(id: entity, component: TestComponent(hello: i % 2))
        }

        // Update counters by 1, but just read testComponent, don't need to mutate it
        store.forEach{ (id: Entity.ID, counter: inout Counter, testComponent: TestComponent) in
            if testComponent.hello == 0 {
                counter.increment()
            }
        }
        
        // Now check that they have been incremented
        let counterValues: [Counter] = ents.map{ store.get(entity: $0)! }
        let testValues: [TestComponent] = ents.map{ store.get(entity: $0)! }

        XCTAssertEqual(counterValues.map{$0.count}, [1, 1, 3, 3])
        XCTAssertEqual(testValues.map{$0.hello}, [0, 1, 0, 1])
    }
    
}
