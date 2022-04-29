
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
    private let update: (StepInfo, Scene) -> Void
    init<SystemType: System>(_ system: SystemType) {
        update = system.update
    }
    public func update(stepInfo: StepInfo, scene: Scene) {
        update(stepInfo, scene)
    }
}

// Just a generic pace to put your systems, and execute them
// Not much utility without better scheduling…
class SystemStore: Updatable {
    // Whatever existential is necessary to represent systems, ie if System is a PAT
    
    // Array of existentials for now
    var systems: [AnySystem] = []
    
    func add<S: System>(system: S) {
        systems.append(AnySystem(system))
    }
    
    func update(stepInfo: StepInfo, scene: Scene) {
        // TODO: topologically-sort systems before execution
        systems.forEach{
            $0.update(stepInfo: stepInfo, scene: scene)
        }
    }
}
