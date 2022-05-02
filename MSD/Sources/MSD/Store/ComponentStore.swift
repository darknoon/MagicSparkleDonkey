//
//  ComponentStore.swift
//  MagicSparkleDonkey
//
//  Created by Andrew Pouliot on 4/7/21.
//

import Foundation

public struct ComponentStore {
    
    internal init() {}

    // TODO: private, make iterating this somewhat logical...
    internal var ids: SparseIntSet = []
    public var nextId: Entity.ID = 0
    internal var storage: Storage = .init()

    public mutating func createEntityId() -> Entity.ID {
        let id = nextId
        ids.insert(id)
        nextId += 1
        return id
    }

    public mutating func createEntity() -> Entity {
        return Entity(id: createEntityId(), componentStorage: storage)
    }
    
    mutating func deleteEntity(id: Entity.ID) {
        ids.remove(nextId)
    }

    // identifier of the metatype for each component struct
    typealias ComponentType = ObjectIdentifier
   
    // We wrap a storage class so we can have reference semantics internally but externally be Value-typed
    // Technically, we should do a CoW optimization here b/c you can copy and mutate this
    internal class Storage {
        var storage: [ComponentType: AnyComponentCollection] = [:]
        
        init() {}

        // Entries store the actual
        func findOrCreateStorageEntry<T: Component>(componentType: ComponentType) -> ComponentCollection<T> {
            let entry: ComponentCollection<T>
            // Create entry if needed
            if let anyEntry = storage[componentType] {
                guard let entry_ = anyEntry.impl as? ComponentCollection<T> else { abort() }
                entry = entry_
            } else {
                entry = ComponentCollection<T>()
                storage[componentType] = entry.eraseToAny()
            }
            return entry
        }
        
        func findStorageEntry<T: Component>(componentType: ComponentType) -> ComponentCollection<T>? {
            storage[componentType]?.impl as? ComponentCollection<T>
        }
        
    }
}


// Weird ones store[entity] = TransformComponent()
//extension ComponentStore {
//    public subscript<T: Component>(entity: Entity.ID) -> T? {
//        get {
//            let componentType = ObjectIdentifier(T.Type.self)
//            guard let entry: ComponentCollection<T> = storage.findStorageEntry(componentType: componentType)
//            else { return nil }
//            return entry.storage[entity]
//        }
//        // {set}?: should we allow nilling out a component?
//        // or default-reset to ComponentType.init()
//    }
//
//    public subscript<T: Component>(entity: Entity.ID) -> T {
//        get {
//            let componentType = ObjectIdentifier(T.Type.self)
//            let entry: ComponentCollection<T> = storage.findStorageEntry(componentType: componentType)!
//            return entry.storage[entity]!
//        }
//        set(newValue) {
//            let componentType = ObjectIdentifier(T.Type.self)
//            let entry: ComponentCollection<T> = storage.findOrCreateStorageEntry(componentType: componentType)
//            entry.storage[entity] = newValue
//        }
//    }
//
//}

// Old ones (but actually decent) componentStore.set(id, TransformComponent()) | componentStore.get() as TransformComponent
extension ComponentStore {
    
    @usableFromInline
    mutating func set<T: Component>(id: Entity.ID, component: T) {
        storage.set(id: id, component: component)
    }
    
    @usableFromInline
    func get<T: Component>(entity: Entity.ID) -> T? {
        storage.get(entity: entity)
    }

}

// Internal componentStore.storage.set()
internal extension ComponentStore.Storage {

    func set<T: Component>(id: Entity.ID, component: T) {
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

// New subscripts
public extension ComponentStore {
    enum Failure: Error {
        case entityDoesNotExist
    }
    
    subscript(entity: Entity.ID) -> Entity? {
        get {
            ids.has(entity) ? Entity(id: entity, componentStorage: storage) : nil
        }
        // {set}?: should we allow nilling out a component?
        // or default-reset to ComponentType.init()
    }

    subscript(entity: Entity.ID) -> Entity {
        get throws {
            guard ids.has(entity) else { throw Failure.entityDoesNotExist }
            return Entity(id: entity, componentStorage: storage)
        }
    }

}


// Contiguous chunk of components, indexed by id
class ComponentCollection<ComponentType: Component> {
    // TODO: make this more like dictionary, ie https://developer.apple.com/documentation/swift/dictionary/index
    typealias Index = Entity.ID
    typealias Element = ComponentType
    
    init() {}
    
    @usableFromInline
    var count: Int { storage.count }
    var storage = SparseArrayPaged<ComponentType>()

    // Safe
    subscript(index: Index) -> Element? {
        get {
            return storage[index]
        }
    }

    subscript(index: Index) -> Element {
        get {
            return storage[index]!
        }
        set(newValue) {
            // TODO: should we allow nilling out a component?
            // or default-reset to ComponentType.init()
            storage[index] = newValue
        }
    }

    
    internal func eraseToAny() -> AnyComponentCollection {
        AnyComponentCollection(e: self)
    }
    
}

// Collection
extension ComponentCollection : RandomAccessCollection {
    var startIndex: Int {
        return 0
    }
    
    var endIndex: Int {
        return count
    }
}


// TODO: this could provide sensible methods?
struct AnyComponentCollection {
    var impl: Any
    fileprivate init<T: Component>(e: ComponentCollection<T>) {
        impl = e
    }
}
