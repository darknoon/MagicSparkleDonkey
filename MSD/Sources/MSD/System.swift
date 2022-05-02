
// Input to each frame iteration
public struct StepInfo {
    public init(timestep: Double) {
        self.timestep = timestep
    }
    let timestep: Double
}

public protocol Updatable {
    func update(stepInfo: StepInfo, scene: Scene)
}

public protocol System: Updatable {
    associatedtype Inputs
    associatedtype Outputs
}

public extension System {
    func eraseToAnySystem() -> AnySystem {
        AnySystem(self)
    }
}

public struct AnySystem: Updatable {
    #if DEBUG
    private let type: ObjectIdentifier
    #endif
    private let update: (StepInfo, Scene) -> Void
    init<SystemType: System>(_ system: SystemType) {
        type = ObjectIdentifier(SystemType.self)
        update = system.update
    }
    public func update(stepInfo: StepInfo, scene: Scene) {
        update(stepInfo, scene)
    }
}

// Just a generic pace to put your systems, and execute them
// Not much utility without better scheduling…
public final class SystemStore: Updatable {
    // Whatever existential is necessary to represent systems, ie if System is a PAT
    
    // Array of existentials for now
    var systems: [AnySystem] = []
    
    public func add<S: System>(system: S) {
        systems.append(AnySystem(system))
    }
    
    public func update(stepInfo: StepInfo, scene: Scene) {
        // TODO: topologically-sort systems before execution
        systems.forEach{
            $0.update(stepInfo: stepInfo, scene: scene)
        }
    }
}

extension SystemStore: ExpressibleByArrayLiteral {
    convenience public init(arrayLiteral systems: AnySystem...) {
        self.init()
        self.systems = systems
    }
}
