//
//  ComponentStore.swift
//  MagicSparkleDonkey
//
//  Created by Andrew Pouliot on 4/7/21.
//

import Foundation

public struct ComponentStore {
    
    internal init() {}

    public var registry = ComponentTypeRegistry()
    
    public var validIds: Set<Entity.ID> = []
    public var nextId: Entity.ID = 0

    mutating func createEntity() -> Entity.ID {
        let id = nextId
        validIds.insert(id)
        nextId += 1
        return id
    }
    
    mutating func deleteEntity(id: Entity.ID) {
        validIds.remove(nextId)
    }

    // Monotonically increasing ID for components
    struct ComponentType: Identifiable, Hashable {
        var id: UInt32
    }
    
    // Entries store the actual
    mutating internal func findOrCreateStorageEntry<T: Component>(componentType: ComponentType) -> ComponentCollection<T> {
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
    
    internal func findStorageEntry<T: Component>(componentType: ComponentType) -> ComponentCollection<T>? {
        storage[componentType]?.impl as? ComponentCollection<T>
    }
    
    mutating func set<T: Component>(id: Entity.ID, component: T) {
        let componentType = registry.find(componentType: T.self)!
        let entry: ComponentCollection<T> = findOrCreateStorageEntry(componentType: componentType)
        entry.append(id: id, component: component)
    }
    
    internal func get<T: Component>(entity: Entity.ID) -> T? {
        return get(entity: entity, componentType: registry.find(componentType: T.self)!)
    }

    internal func get<T: Component>(entity: Entity.ID, componentType: ComponentType) -> T? {
        guard let entry: ComponentCollection<T> = findStorageEntry(componentType: componentType),
              let i = entry.idToIndex[entity] else { return nil }
        return entry.storage[i]
    }
    
    private var storage: [ComponentType: AnyComponentCollection] = [:]

}

// Contiguous chunk of components, indexed by id
class ComponentCollection<ComponentType: Component> : Collection {
    typealias Index = Int
    typealias Element = ComponentType
    
    init() {
        capacity = 100
        count = 0
        storage = UnsafeMutablePointer<ComponentType>.allocate(capacity: capacity)
    }
    var count: Int
    var capacity: Int
    var storage: UnsafeMutablePointer<ComponentType>

    // This could be more efficient
    var idToIndex: [Entity.ID : Index] = [:]

    subscript(id: Entity.ID) -> ComponentType? {
        get {
            guard let index = idToIndex[id] else { return nil }
            return storage[index]
        }
        set(newValue) {
            // TODO: should we allow nilling out a component?
            // or default-reset to ComponentType.init()
            let newValue = newValue!
            if let index = idToIndex[id] {
                storage[index] = newValue
            } else {
                append(id: id, component: newValue)
            }
        }
    }

    
    func append(id: Entity.ID, component: ComponentType) {
        assert(count < capacity)
        let ptr = storage + count
        ptr.initialize(to: component)
        idToIndex[id] = count
        count += 1
    }
    
    internal func eraseToAny() -> AnyComponentCollection {
        AnyComponentCollection(e: self)
    }
    
    // Collection
    var startIndex: Int {
        return 0
    }
    
    var endIndex: Int {
        return count
    }
    
    func index(after i: Index) -> Index {
        return i + 1
    }

    subscript(position: Int) -> Element {
        get {
            guard position >= 0 && position < count else { abort() }
            return storage[position]
        }
        set {
            storage[position] = newValue
        }
    }
    
}


struct AnyComponentCollection {
    var impl: Any
    fileprivate init<T: Component>(e: ComponentCollection<T>) {
        impl = e
    }
}


/// Component Registry is a mapping between your ComponentStruct.Type and a UInt32

public struct ComponentTypeRegistry {
    var store = [(Component.Type, ComponentStore.ComponentType)]()
    private var maxTypeId: UInt32 = 0

    mutating func register<T: Component>(component: T.Type) {
        store.append((T.self, ComponentStore.ComponentType(id: maxTypeId)))
        maxTypeId += 1
    }

    mutating func unregister<T: Component>(component: T.Type) {
        store.removeAll{$0.0 == T.self}
    }

    func find<T: Component>(componentType: T.Type) -> ComponentStore.ComponentType? {
        store.first(where: {$0.0 == T.self})?.1
    }
}


