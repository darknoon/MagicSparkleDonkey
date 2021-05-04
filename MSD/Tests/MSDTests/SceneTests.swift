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
        }
        
        func testCustomComponent() {
            let e = scene.root
            
            scene.store[e] = TestComponent(hello: 111)
            scene.store[e] = TestComponent(hello: 123)

            let t = (scene.store[e] as TestComponent?)?.hello
            XCTAssertEqual(t!, 123)
            
        }

    }
