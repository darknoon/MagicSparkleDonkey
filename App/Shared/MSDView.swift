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
    typealias Inputs = (RotationComponent)
    typealias Outputs = (Transform)
    
    func update(stepInfo: StepInfo, scene: MSD.Scene) {
        scene.store.forEach{(id, transform: inout TransformComponent, rotation: inout RotationComponent) in
            rotation.rotation += 0.01
            let rotationAxis = SIMD3<Float>(1, 1, 0)
            var modelMatrix = simd_float4x4(rotation: rotation.rotation, axis: rotationAxis)
            modelMatrix.translation = transform.transform.translation
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
        var systems: SystemStore = [
            SimpleRotateSystem().eraseToAnySystem(),
            RenderSystem().eraseToAnySystem()
        ]
        var currentError: Error? = nil
        
        func updateAndDisplay() -> RenderSystem.DisplayList {
            // TODO: get info about display link? to pass in here
            let step = StepInfo(timestep: 1.0/60.0)
            systems.update(stepInfo: step, scene: scene)
            return scene.store[scene.root] as RenderSystem.DisplayList
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
    
    var children: EntityChildCollection = scene.store[scene.root]
    for x in 1..<10 {
        let rowEntity = scene.store.createEntity()
        scene.store[rowEntity] = TransformComponent(.identity)
        var subChildren: EntityChildCollection = .init()
        for y in 1..<10 {
            let entity = scene.store.createEntity()
            let t = simd_float4x4(translation: simd_float3(x: Float(x) * 0.2, y: Float(y) * 0.2, z: 0))
            scene.store[entity] = TransformComponent(t)
            // Render default mesh
            scene.store[entity] = MeshComponent(0)
            scene.store[entity] = RotationComponent(rotation: Float.random(in: 0...1))
            subChildren.append(entity)
        }
        scene.store[rowEntity] = subChildren
        children.append(rowEntity)
    }
    
    scene.store[scene.root] = children
}

