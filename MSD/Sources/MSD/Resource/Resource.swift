//
//  File.swift
//  
//
//  Created by Andrew Pouliot on 5/23/21.
//

import Foundation

// Runtime resource implementation
public struct Resource {
    public typealias ID = UInt32
    public let id: Resource.ID
    public let path: String
    // To make it public, have to re-imelement
    public init(id: Resource.ID, path: String) {
        self.id = id
        self.path = path
    }
}

public struct ResourceBundle {
    let bundle: Bundle
    public init(bundle: Bundle) { self.bundle = bundle }
}
