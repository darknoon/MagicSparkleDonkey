import XCTest
@testable import MSD

final class SceneTests: XCTestCase {

    struct TestComponent : Component {
        var hello: Int
    }
    
    var scene = Scene()
    
    func testInitScene() {
        // Create an empty scene
        let s = scene
        // Get the root's transform
        
        let t = (scene.store[s.root] as TransformComponent?)?.transform
        
        // Should be identity
        XCTAssertEqual(t, .identity)
        
        // Should have children array, but not children
        let c = scene.store[s.root] as EntityChildCollection?
        XCTAssertEqual(c, EntityChildCollection())
    }
    
    func testCustomComponent() {
        let e = scene.root
        
        scene.store[e] = TestComponent(hello: 111)
        scene.store[e] = TestComponent(hello: 123)

        let t = (scene.store[e] as TestComponent?)?.hello
        XCTAssertEqual(t!, 123)
    }
    
    func testParentChild() {
        // add children
        var child0 = scene.store.createEntity()
        child0[TransformComponent.self] = .init(.identity)

        var child1 = scene.store.createEntity()
        child1[TransformComponent.self] = .init(.identity)

        scene.rootEntity[EntityChildCollection.self] = [child0.id, child1.id]
        
        // Very simple function to iterate depth-first
        func traverse(scene: Scene, childrenOf entity: Entity.ID, fn: (Entity.ID) -> Void) {
            fn(entity)
            if let children = scene.store[entity] as EntityChildCollection? {
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

