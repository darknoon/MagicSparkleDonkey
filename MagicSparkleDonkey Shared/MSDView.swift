//
//  MSDView.swift
//  MagicSparkleDonkey
//
//  Created by Andrew Pouliot on 5/18/21.
//

import SwiftUI
import MetalKit

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
    class Coordinator: NSObject, MTKViewDelegate {
        var renderer: RendererGeneric<GPUMetal>? = nil
        var scene = Scene()
        var currentError: Error? = nil

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            renderer?.mtkView(GPUMetal.SwapChain(view: view), drawableSizeWillChange: size)
        }
        
        func draw(in view: MTKView) {
            renderer?.draw(in: GPUMetal.SwapChain(view: view))
        }
    }

    var renderer: RendererMetal!
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeView(context: Context) -> MTKView {
        let v = MTKView(frame: .zero, device: device)
        do {
            let r = try RendererGeneric<GPUMetal>(swapChain: GPUMetal.SwapChain(view: v))
            context.coordinator.renderer = r
            v.delegate = context.coordinator
        } catch {
            context.coordinator.currentError = error
        }
        return v
    }

    func updateView(_ platformView: MTKView, context: Context) {}

}
