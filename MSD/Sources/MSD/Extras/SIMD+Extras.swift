//
//  Extras.swift
//  MagicSparkleDonkey
//
//  Created by Andrew Pouliot on 4/6/21.
//

import Foundation
import simd

// = .identity
extension simd_float4x4 {
    public static let identity = matrix_identity_float4x4
}

// = .identity
extension simd_float3x3 {
    public static let identity = matrix_identity_float3x3
}

public extension simd_float4x4 {
    init(translation t: simd_float3) {
        self.init(
            simd_float4(  1,   0,   0,   0),
            simd_float4(  0,   1,   0,   0),
            simd_float4(  0,   0,   1,   0),
            simd_float4(t.x, t.y, t.z,   1)
        )
    }
    
    init(axes: (simd_float3, simd_float3, simd_float3), offset t: simd_float3) {
        self.init(
            simd_float4(  axes.0,   0),
            simd_float4(  axes.1,   0),
            simd_float4(  axes.2,   0),
            simd_float4(  t,        1)
        )
    }
    
    init(scale x: simd_float3) {
        self.init(diagonal: simd_float4(x.x, x.y, x.z, 1.0))
    }
}


public extension matrix_float4x4 {
    // Generic matrix math utility functions
    init(rotation radians: Float, axis: SIMD3<Float>) {
        let unitAxis = normalize(axis)
        let ct = cosf(radians)
        let st = sinf(radians)
        let ci = 1 - ct
        let x = unitAxis.x, y = unitAxis.y, z = unitAxis.z
        self.init(columns:(vector_float4(    ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
                                             vector_float4(x * y * ci - z * st,     ct + y * y * ci, z * y * ci + x * st, 0),
                                             vector_float4(x * z * ci + y * st, y * z * ci - x * st,     ct + z * z * ci, 0),
                                             vector_float4(                  0,                   0,                   0, 1)))
    }
}

extension simd_float4x4 {
    
    public static func perspectiveRightHand(fovyRadians fovy: Float, aspectRatio: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
        let ys = 1 / tanf(fovy * 0.5)
        let xs = ys / aspectRatio
        let zs = farZ / (nearZ - farZ)
        return Self.init(columns:(vector_float4(xs,  0, 0,   0),
                                             vector_float4( 0, ys, 0,   0),
                                             vector_float4( 0,  0, zs, -1),
                                             vector_float4( 0,  0, zs * nearZ, 0)))
    }
}

// Grab translation vector from matrix
public extension simd_float4x4 {
    @inline(__always)
    var translation: simd_float3 {
        get {
            return columns.3.xyz
        }
        set {
            columns.3.xyz = newValue
        }
    }
}

// a.xy, a.yx etc
extension SIMD4 {
    var xy: SIMD2<Scalar> {
        .init(x, y)
    }

    @inline(__always)
    var xyz: SIMD3<Scalar> {
        get {
            .init(x, y, z)
        }
        set {
            x = newValue.x
            y = newValue.y
            z = newValue.z
        }
    }
    @inline(__always)
    var yx: SIMD2<Scalar> {
        .init(y, x)
    }
}



public func toRadians(degrees: Float) -> Float {
    return (degrees / 180) * .pi
}
