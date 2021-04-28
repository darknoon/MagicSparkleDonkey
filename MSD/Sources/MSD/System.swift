//
//  File.swift
//  
//
//  Created by Andrew Pouliot on 4/17/21.
//

// Input to a frame
struct StepInfo {
    let timestep: Double
}

protocol System {
    associatedtype Inputs
    associatedtype Outputs

    func update(stepInfo: StepInfo, scene: Scene)
}

struct AnySystem {
    var impl: Any
    init<SystemType: System>(_ system: SystemType) {
        impl = system
    }
}

class SystemStore {
    // Whatever existential is necessary to represent systems, ie if System is a PAT
    
    // Array of existentials for now
    var systems: [AnySystem] = []
    
    func add<S: System>(system: S) {
        systems.append(AnySystem(system))
    }
}
