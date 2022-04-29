//
//  File.swift
//  
//
//  Created by Andrew Pouliot on 4/22/21.
//

public struct MeshComponent : Component {
    public let resource: Resource.ID?
    public init(_ resource: Resource.ID?) {
        self.resource = resource
    }
}

public class RenderSystem : System {
    public typealias Inputs = (TransformComponent, MeshComponent)
    public typealias Outputs = ()
    
    public typealias DisplayList = [Display]
    
    public struct Display {
        public let transform: Transform
        public let resource: Resource.ID
    }
    
    // Eh, is this the best?
    public private(set) var displayList: DisplayList = []
    
    public init() {}
    
    public func update(stepInfo: StepInfo, scene: Scene) {
        displayList.removeAll()

        scene.store.forEach{(id, transform: inout TransformComponent, mesh: inout MeshComponent) in
            let t = transform.transform
            if let m = mesh.resource {
                displayList.append(Display(transform: t, resource: m))
            }
        }
    }
}
