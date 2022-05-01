
public class Scene {

    public init() {
        root = store.createEntity()
        store[root] = TransformComponent(.identity)
        store[root] = EntityChildCollection()
    }

    public var root: Entity.ID
    
    public var store = ComponentStore()
    
    // This is just to be able to grab the renderList, not a great design
    public var renderSystem = RenderSystem()
}
