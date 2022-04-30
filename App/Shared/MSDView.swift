//
//  MSDView.swift
//  MagicSparkleDonkey
//
//  Created by Andrew Pouliot on 5/18/21.
//

import SwiftUI
import MetalKit
import MSD
import MetalRender

// Associates a simple rotation with a component
struct RotationComponent: Component {
    var rotation: Float
}

struct SimpleRotateSystem: System {
    typealias Inputs = (Transform)
    typealias Outputs = (Transform)
    
    func update(stepInfo: StepInfo, scene: MSD.Scene) {
        scene.store.forEach{(id, transform: inout TransformComponent, rotation: inout RotationComponent) in
            rotation.rotation += 0.01
            let rotationAxis = SIMD3<Float>(1, 1, 0)
            let modelMatrix = simd_float4x4(rotation: rotation.rotation, axis: rotationAxis)
            transform.transform = modelMatrix
        }
    }
    
}

// Insert a render output view into a SwiftUI hierarchy
struct MSDView : PlatformViewRepresentable {
    // Type inference has issues with PlatformViewRepresentable
    typealias NSViewType = MTKView
    typealias UIViewType = MTKView

    init() {
        device = MTLCreateSystemDefaultDevice()!
    }
    
    let device: MTLDevice
    
    // Renderer and scene initialized when we are actually making the view
    class Coordinator {
        var renderer: RendererMetal? = nil
        var scene = MSD.Scene()
        // Additional systems besides render
        var systems: [AnySystem] = [SimpleRotateSystem().eraseToAnySystem()]
        var currentError: Error? = nil
        
        func updateAndDisplay() -> RenderSystem.DisplayList {
            // TODO: get info about display link? to pass in here
            let step = StepInfo(timestep: 1.0/60.0)
            for system in systems {
                system.update(stepInfo: step, scene: scene)
            }
            scene.renderSystem.update(stepInfo: step, scene: scene)
            return scene.renderSystem.displayList
        }
    }
    
    var renderer: RendererMetal!
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeView(context: Context) -> MTKView {

        let v = MTKView(frame: .zero, device: device)
        v.clearColor = .init(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        v.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        v.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        v.sampleCount = 1

        let renderConfig = v.renderConfig
        do {
            let r = try RendererMetal(config: renderConfig, device: v.device!)
            context.coordinator.renderer = r
            addDefaultObject(to: context.coordinator.scene)

            r.displayListCallback = context.coordinator.updateAndDisplay
            v.delegate = r
        } catch {
            context.coordinator.currentError = error
        }
        return v
    }

    func updateView(_ platformView: MTKView, context: Context) {}

}

func addDefaultObject(to scene: MSD.Scene) {
    let testObject = scene.store.createEntity()
    scene.store[testObject] = TransformComponent(.identity)
    // Render default mesh
    scene.store[testObject] = MeshComponent(0)
    scene.store[testObject] = RotationComponent(rotation: 0)

    var children: EntityChildCollection = scene.store[scene.root]
    children.append(testObject)
    scene.store[scene.root] = children
}

