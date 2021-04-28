//
//  File.swift
//  
//
//  Created by Andrew Pouliot on 4/17/21.
//

/// Component is the fundamental extension mechanism in MSD
/// Components are stored in contiguous arrays in ComponentStore. There is always one component of a given type associated with each Entity
/// To create a custom component:
/// ```swift
/// struct DebugInfoComponent : Component {
///   var info: Info
/// }
/// ```
public protocol Component {}
