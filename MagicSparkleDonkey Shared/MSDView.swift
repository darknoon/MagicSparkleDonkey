//
//  MSDView.swift
//  MagicSparkleDonkey
//
//  Created by Andrew Pouliot on 5/18/21.
//

import SwiftUI
import MetalKit

struct MSDView : PlatformViewRepresentable {
    typealias NSViewType = MTKView
    typealias UIViewType = MTKView

    init() {
        device = MTLCreateSystemDefaultDevice()!
    }
    
    let device: MTLDevice
    
    class Coordinator {
        var renderer: Renderer? = nil
    }
    
    var renderer: Renderer!
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeView(context: Context) -> MTKView {
        let v = MTKView(frame: .zero, device: device)
        context.coordinator.renderer = Renderer(metalKitView: v)
        v.delegate = context.coordinator.renderer
        return v
    }

    func updateView(_ platformView: MTKView, context: Context) {}

    
}
