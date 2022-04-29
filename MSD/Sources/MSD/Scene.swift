
public class Scene {
    public init() {
        root = Entity.ID()
        store[root] = TransformComponent(.identity)
    }

    public var root: Entity.ID
    
    public var store = ComponentStore()
    
    public var renderSystem = RenderSystem()
}
