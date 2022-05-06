
public class Scene {

    public init() {
        var root = store.createEntity()
        root.transform = .init(.identity)
        root.children = []
        self.root = root.id
    }

    // TODO: cane we make this an Entity
    public var root: Entity.ID

    public var rootEntity: Entity {
        get {
            Entity(id: root, componentStorage: store.storage)
        }
        // Clients that want to set something here don't really want to overwrite this with a copy, they want to access properties off of this.
        _modify {
            var e = Entity(id: root, componentStorage: store.storage)
            yield &e
        }
    }

    public var store = ComponentStore()
    
    // This is just to be able to grab the renderList, not a great design
    public var renderSystem = RenderSystem()
}
