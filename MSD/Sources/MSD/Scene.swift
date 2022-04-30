
public class Scene {
    public init() {
        root = store.createEntity()
        store[root] = TransformComponent(.identity)
        store[root] = EntityChildCollection()
    }

    public var root: Entity.ID
    
    public var store = ComponentStore()
    
    public var renderSystem = RenderSystem()
}
