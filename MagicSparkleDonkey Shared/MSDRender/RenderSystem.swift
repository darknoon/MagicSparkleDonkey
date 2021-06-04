//
//  File.swift
//  
//
//  Created by Andrew Pouliot on 4/22/21.
//

struct MeshComponent : Component {
    let resource: Int?
}

class RenderSystem<API: GPUAPI> : System {
    typealias Inputs = (TransformComponent, MeshComponent)
    
    typealias Outputs = ()
    
    init(device: API) {
        self.device = device
    }
    
    let device: API
    
    func update(stepInfo: StepInfo, scene: Scene) {
        
        scene.store.forEach{(id, transform: inout TransformComponent, mesh: inout MeshComponent) in
            let t = transform.transform
            if let m = mesh.resource {
                
                print("Render this mesh with transform \(t)")
            }
            // TODO: Render model at the given transform?
        }
    }
}
