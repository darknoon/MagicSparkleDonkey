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
    public typealias Inputs = (TransformComponent, MeshComponent, PerspectiveCamera)
    public typealias Outputs = (DisplayList)
    
    public struct DisplayList: Component {
        public let displays: [Display]
        public let viewMatrix: Transform
        
        public static let empty = DisplayList(displays: [], viewMatrix: .identity)
    }
    
    public struct Display {
        public let transform: Transform
        public let resource: Resource.ID
        public let entity: Entity.ID
    }
    
    public init() {}
    
    // Find the first camera in the scene that has a transform, or a default camera
    func findActiveCamera(scene: Scene) -> (Entity.ID, PerspectiveCamera, Transform) {
        // TODO: allow setting active camera?
        var _cam: (Entity.ID, PerspectiveCamera, Transform)? = nil
        scene.store.forEach { (id, c: inout PerspectiveCamera, t: inout TransformComponent) in
            guard _cam == nil else { return }
            _cam = (id, c, t.transform)
        }
        let defaultCameraT =  Transform(translation: .init(x: 0, y: 0, z: -8))
        return _cam ?? (0, PerspectiveCamera(fieldOfView: 90), defaultCameraT)
    }
    
    public func update(stepInfo: StepInfo, scene: Scene) {
        var displayList: [Display] = []
        var currentTransform: Transform = .identity
        

        // Traverse the scene looking for children, adding them to the displaylist
        // Not particularly sophisticated here
        func traverse(childrenOf entity: Entity) {
            // save transform
            let previousTransform = currentTransform

            if let transform = entity[TransformComponent.self]?.transform {
                currentTransform = currentTransform * transform
            } else {
                print("Parent with no transform: \(entity)")
            }

            if let mesh = entity[MeshComponent.self], let meshResource = mesh.resource {
                let d = Display(transform: currentTransform, resource: meshResource, entity: entity.id)
                displayList.append(d)
            }
            
            // get this entity's children (if any)
            if let children = entity[EntityChildCollection.self] {
                for childId in children {
                    // Add children to render list
                    if let child = scene.store[childId] {
                        traverse(childrenOf: child)
                    } else {
                        print("Referenced nonexistant child \(childId)")
                    }
                }
            }
            // restore transform
            currentTransform = previousTransform
        }

        traverse(childrenOf: scene.rootEntity)
        
        let (_, _, viewMatrix) = findActiveCamera(scene: scene)
        scene.rootEntity[DisplayList.self] = DisplayList(displays: displayList, viewMatrix: viewMatrix)
    }
}
