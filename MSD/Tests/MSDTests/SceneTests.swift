import XCTest
@testable import MSD

final class SceneTests: XCTestCase {

    struct TestComponent : Component {
        var hello: Int
    }
    
    var scene = Scene()
    
    func testInitScene() {
        // Get the root's transform
        let t = scene.rootEntity[TransformComponent.self]?.transform
        
        // Should be identity
        XCTAssertEqual(t, .identity)
        
        // Should have children array, but not children
        let c: EntityChildCollection? = scene.rootEntity.children
        XCTAssertEqual(c, EntityChildCollection())
    }
    
    func testCustomComponent() {
        var e = scene.rootEntity
        
        e[TestComponent.self] = TestComponent(hello: 111)
        e[TestComponent.self] = TestComponent(hello: 123)

        let t = e[TestComponent.self]?.hello
        XCTAssertEqual(t!, 123)
    }
    
    func testParentChild() {
        // add children
        var child0 = scene.store.createEntity()
        child0.transform = .init(.identity)

        var child1 = scene.store.createEntity()
        child1.transform = .init(.identity)

        scene.rootEntity.children = [child0.id, child1.id]
        
        // Very simple function to iterate depth-first
        func traverse(scene: Scene, childrenOf entity: Entity.ID, fn: (Entity.ID) -> Void) {
            fn(entity)
            if let children = scene.store[entity]?.children {
                for child in children {
                    traverse(scene: scene, childrenOf: child, fn: fn)
                }
            }
        }

        var traversal: [Entity.ID] = []
        traverse(scene: scene, childrenOf: scene.root) { child in
            traversal.append(child)
        }
        
        XCTAssertEqual(traversal, [scene.root, child0.id, child1.id])
    }

}

