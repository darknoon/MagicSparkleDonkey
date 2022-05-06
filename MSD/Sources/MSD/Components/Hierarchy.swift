//
//  File.swift
//  
//
//  Created by Andrew Pouliot on 4/17/21.
//

import Foundation

// Define a component that holds up to N child IDs in a fixed-size array
public struct EntityChildCollection: MutableCollection, RandomAccessCollection, Equatable {
    // Don't expose this detail to consumers, can increase the max child count in the future
    private var impl: _FixedArray16<Entity.ID>
    
    public init() {
        impl = []
    }
    
    public typealias Element = Entity.ID
    
    public var startIndex: Int { impl.startIndex }
    public var endIndex: Int { impl.endIndex }
    
    public subscript(index: Int) -> Element {
        get {
            impl[index]
        }
        set {
            impl[index] = newValue
        }
    }

    public mutating func append(_ element: Element) {
        impl.append(element)
    }
    
    public mutating func append(_ entity: Entity) {
        impl.append(entity.id)
    }

    public static func == (lhs: EntityChildCollection, rhs: EntityChildCollection) -> Bool {
        lhs.impl == rhs.impl
    }
}

extension EntityChildCollection: Component { }

extension EntityChildCollection: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Element...) {
        self.init()
        for element in elements {
            impl.append(element)
        }
    }
    
}

public extension Entity {
    var children: EntityChildCollection? {
        get {
            self[EntityChildCollection.self]
        }
        set {
            self[EntityChildCollection.self] = newValue
        }
    }
    
}

// Wrapper that exposes children as entities without dynamically allocating an Array of Entity or other pathological ways of solving this
public extension Entity {
    var childEntities: EntityChildEntityCollection? {
        get {
            EntityChildEntityCollection(self, componentStorage: componentStorage)
        }
    }

    struct EntityChildEntityCollection: RandomAccessCollection {
        public typealias Element = Entity
        
        public typealias Index = EntityChildCollection.Index
        
        // Doesn't let you actually mutate the children currently
        private let entityIds: EntityChildCollection
        private unowned let componentStorage: ComponentStore.Storage

        internal init?(_ e: Entity, componentStorage s: ComponentStore.Storage) {
            guard let children = e.children else { return nil }
            entityIds = children
            componentStorage = s
        }
        
        public var startIndex: Int { entityIds.startIndex }
        public var endIndex: Int { entityIds.endIndex }
        
        public subscript(index: Int) -> Entity {
            get {
                Entity(id: entityIds[index], componentStorage: componentStorage)
            }
        }

    }
    
}
