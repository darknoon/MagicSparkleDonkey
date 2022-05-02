// Core

/// Entity is a very minimal type wrapping around an id and a store, maybe not needed?
public struct Entity {

    // TODO: make this configurable, ie conform to BinaryInteger or something
    
    /// A type representing the stable identity of the entity associated with
    /// an instance.
    
    public typealias ID = Int
    
    let id: ID
    // Hold a re
    private unowned let componentStorage: ComponentStore.Storage
    
    internal init(id: ID, componentStorage: ComponentStore.Storage) {
        self.id = id
        self.componentStorage = componentStorage
    }
    
    public subscript<T: Component>(_ : T.Type) -> T? {
        get {
            componentStorage.get(entity: id)
        }
        // {set}?: should we allow nilling out a component?
        // or default-reset to ComponentType.init()
    }

    public subscript<T: Component>(_ : T.Type) -> T {
        get {
            componentStorage.get(entity: id)!
        }
        // TODO: _read etc would allow us to improve performance by not copying in-out any values
//        _read {
//            guard let entry: ComponentCollection<T> = componentStorage.findStorageEntry(componentType: ObjectIdentifier(T.self))
//            else { throw }
//            yield entry[id]
//        }
        set {
            componentStorage.set(id: id, component: newValue)
        }
    }

}
