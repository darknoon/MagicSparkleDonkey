//
//  File.swift
//  
//
//  Created by Andrew Pouliot on 4/17/21.
//

import Foundation

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
