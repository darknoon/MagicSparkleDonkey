//
//  File.swift
//  
//
//  Created by Andrew Pouliot on 4/17/21.
//

import simd

public struct Camera : Component {
    public init() {}
    var perspective: Transform = .identity
}

