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

    public mutating func createEntity() -> Entity.ID {
        let id = nextId
        ids.insert(id)
        nextId += 1
        return id
    }
    
    mutating func deleteEntity(id: Entity.ID) {
        ids.remove(nextId)
    }

    // identifier of the metatype for each component struct
    typealias ComponentType = ObjectIdentifier
    
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
    
    public subscript<T: Component>(entity: Entity.ID) -> T? {
        get {
            let componentType = ObjectIdentifier(T.Type.self)
            guard let entry: ComponentCollection<T> = findStorageEntry(componentType: componentType)
            else { return nil }
            return entry.storage[entity]
        }
        // {set}?: should we allow nilling out a component?
        // or default-reset to ComponentType.init()
    }

    public subscript<T: Component>(entity: Entity.ID) -> T {
        get {
            let componentType = ObjectIdentifier(T.Type.self)
            let entry: ComponentCollection<T> = findStorageEntry(componentType: componentType)!
            return entry.storage[entity]!
        }
        set(newValue) {
            let componentType = ObjectIdentifier(T.Type.self)
            let entry: ComponentCollection<T> = findOrCreateStorageEntry(componentType: componentType)
            entry.storage[entity] = newValue
        }
    }

    private var storage: [ComponentType: AnyComponentCollection] = [:]

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
