//
//  MSDComponent.swift
//  MagicSparkleDonkey
//
//  Created by Andrew Pouliot on 4/6/21.
//

import Foundation
import simd

// Core

/// Entity is a very minimal type wrapping around an id and a store, maybe not needed?
public struct Entity {

    // TODO: make this configurable, ie conform to BinaryInteger or something
    
    /// A type representing the stable identity of the entity associated with
    /// an instance.
    
    public typealias ID = Int
}
