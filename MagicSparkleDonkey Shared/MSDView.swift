//
//  MSDView.swift
//  MagicSparkleDonkey
//
//  Created by Andrew Pouliot on 5/18/21.
//

import SwiftUI
import MetalKit
import MSD


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
        var currentError: Error? = nil
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
            v.delegate = r
        } catch {
            context.coordinator.currentError = error
        }
        return v
    }

    func updateView(_ platformView: MTKView, context: Context) {}

}
