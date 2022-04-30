//
//  File.swift
//  
//
//  Created by Andrew Pouliot on 4/17/21.
//

import Foundation

public struct EntityChildCollection: MutableCollection, RandomAccessCollection {
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

}

extension EntityChildCollection: Component {
}

public protocol HasHierarchy {
    var children: EntityChildCollection { get set }
}
