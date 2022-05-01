//
//  File.swift
//  
//
//  Created by Andrew Pouliot on 4/22/21.
//
import simd

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
        
        var currentTransform: Transform = .identity

        func traverse(childrenOf entity: Entity.ID) {
            // push transform
            let previousTransform = currentTransform
            if let transform = (scene.store[entity] as TransformComponent?)?.transform {
                currentTransform = simd_mul(currentTransform, transform)
            }

            if let mesh = scene.store[entity] as MeshComponent?, let meshResource = mesh.resource {
                let d = Display(transform: currentTransform, resource: meshResource)
                displayList.append(d)
            }
            
            // get this entity's children (if any)
            if let children = scene.store[entity] as EntityChildCollection? {
                for child in children {
                    // Add children to render list
                    traverse(childrenOf: child)
                }
            }
            // pop transform
            currentTransform = previousTransform
        }

        traverse(childrenOf: scene.root)
    }
}
