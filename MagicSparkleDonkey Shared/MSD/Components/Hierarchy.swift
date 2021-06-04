//
//  File.swift
//  
//
//  Created by Andrew Pouliot on 4/17/21.
//

import Foundation

public struct EntityChildCollection {
    private var impl: [Entity.ID]
}

public protocol HasHierarchy {
    var children: EntityChildCollection { get set }
}

extension HasHierarchy {
    
}
