    import XCTest
    @testable import MSD

    final class SceneTests: XCTestCase {

        struct TestComponent : Component, Equatable {
            var hello: Int
        }
        
        var scene = Scene()
        
        func testInitScene() {
            // Create an empty scene
            let s = scene
            // Get the root's transform
            
            let t = (scene.store.get(entity: s.root) as TransformComponent?)?.transform
            
            // Should be identity
            XCTAssertEqual(t, .identity)
        }
        
        func testCustomComponent() {
            scene.registerComponent(TestComponent.self)

            let e = scene.root
            
            scene.store.set(id: e, component: TestComponent(hello: 111))
            scene.store.set(id: e, component: TestComponent(hello: 123))
            
            let t = (scene.store.get(entity: e) as TestComponent?)?.hello
            XCTAssertEqual(t!, 123)
            
        }

    }
