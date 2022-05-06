/// Component is the fundamental extension mechanism in MSD
/// Components are stored in contiguous arrays in ComponentStore. There is always at most one component of a given type associated with each Entity
/// To create a custom component:
/// ```swift
/// struct DebugInfoComponent: Component {
///   var info: Info
/// }
/// ```
/// It is important for performance not to store any heap-allocated structures in the array:
/// ie **do not** do this
/// ```swift
/// struct DebugInfoComponent: Component {
///   // Heap allocation inside Array.
///   // If you need a variable-sized structure, use a tuple or wrapper around a tuple like `_FixedArray16`
///   var info: [Info]
/// }
/// ```
public protocol Component {}

public typealias ComponentType = ObjectIdentifier

extension Component {
    // A component uses its metatype pointer as an identifier
    public static var ID: ObjectIdentifier {
        ObjectIdentifier(Self.Type.self)
    }
}
