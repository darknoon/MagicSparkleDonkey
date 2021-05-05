/// Component is the fundamental extension mechanism in MSD
/// Components are stored in contiguous arrays in ComponentStore. There is always at most one component of a given type associated with each Entity
/// To create a custom component:
/// ```swift
/// struct DebugInfoComponent : Component {
///   var info: Info
/// }
/// ```
public protocol Component {}

extension Component {
    // A component uses its metatype pointer as an identifier
    public static var ID: ObjectIdentifier {
        ObjectIdentifier(Self.Type.self)
    }
}
