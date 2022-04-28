//
//  File.swift
//  
//
//  Created by Andrew Pouliot on 4/22/21.
//

struct MeshComponent : Component {
    let resource: Int?
}

class RenderSystem : System {
    typealias Inputs = (TransformComponent, MeshComponent)
    
    typealias Outputs = ()
    
    struct Display {
        let transform: Transform
        let resource: Int
    }
    
    // Eh, is this the best?
    var displayList: [Display] = []
    
    func update(stepInfo: StepInfo, scene: Scene) {
        
        displayList.removeAll()

        scene.store.forEach{(id, transform: inout TransformComponent, mesh: inout MeshComponent) in
            let t = transform.transform
            if let m = mesh.resource {
                print("Render this mesh with transform \(t)")
                displayList.append(Display(transform: t, resource: m))
            }
        }
    }
}
