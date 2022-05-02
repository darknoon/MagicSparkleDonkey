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
    public typealias Outputs = (DisplayList)
    
    public struct DisplayList: Component {
        public let displays: [Display]
        
        public static let empty = DisplayList(displays: [])
    }
    
    public struct Display {
        public let transform: Transform
        public let resource: Resource.ID
        public let entity: Entity.ID
    }
    
    public init() {}
    
    public func update(stepInfo: StepInfo, scene: Scene) {
        var displayList: [Display] = []
        var currentTransform: Transform = .identity

        // Traverse the scene looking for children, adding them to the displaylist
        // Not particularly sophisticated here
        func traverse(childrenOf entity: Entity.ID) {
            // save transform
            let previousTransform = currentTransform

            if let transform = (scene.store[entity] as TransformComponent?)?.transform {
                currentTransform = currentTransform * transform
            } else {
                print("Parent with no transform: \(entity)")
            }

            if let mesh = scene.store[entity] as MeshComponent?, let meshResource = mesh.resource {
                let d = Display(transform: currentTransform, resource: meshResource, entity: entity)
                displayList.append(d)
            }
            
            // get this entity's children (if any)
            if let children = scene.store[entity] as EntityChildCollection? {
                for child in children {
                    // Add children to render list
                    traverse(childrenOf: child)
                }
            }
            // restore transform
            currentTransform = previousTransform
        }

        traverse(childrenOf: scene.root)
        
        scene.store[scene.root] = DisplayList(displays: displayList)
    }
}
