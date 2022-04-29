//
//  File.swift
//  
//
//  Created by Andrew Pouliot on 4/17/21.
//

import Foundation

typealias MaxChildrenTuple = (
    // 16 children
    Entity.ID, Entity.ID, Entity.ID, Entity.ID,
    Entity.ID, Entity.ID, Entity.ID, Entity.ID,
    Entity.ID, Entity.ID, Entity.ID, Entity.ID,
    Entity.ID, Entity.ID, Entity.ID, Entity.ID
)

public struct EntityChildCollection {
    private var impl: TupleCollection<MaxChildrenTuple, Entity.ID>
}

public protocol HasHierarchy {
    var children: EntityChildCollection { get set }
}
