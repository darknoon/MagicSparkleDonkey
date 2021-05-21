//
//  PlatformViewRepresentable.swift
//  MagicSparkleDonkey
//
//  Created by Andrew Pouliot on 5/21/21.
//

import SwiftUI

#if os(macOS)

protocol PlatformViewRepresentable : NSViewRepresentable where ViewType == NSViewType  {
    associatedtype ViewType
    
    func makeView(context: Context) -> NSViewType
    func updateView(_ platformView: NSViewType, context: Context)
}

extension PlatformViewRepresentable {
    func makeNSView(context: Context) -> NSViewType {
        makeView(context: context)
    }
    func updateNSView(_ nsView: NSViewType, context: Context) {
        updateView(nsView, context: context)
    }
}

#else

protocol PlatformViewRepresentable : UIViewRepresentable where ViewType == UIViewType  {
    associatedtype ViewType
    
    func makeView(context: Context) -> UIViewType
    func updateView(_ platformView: UIViewType, context: Context)
}

extension PlatformViewRepresentable {
    func makeUIView(context: Context) -> UIViewType {
        makeView(context: context)
    }
    func updateUIView(_ UIView: UIViewType, context: Context) {
        updateView(UIView, context: context)
    }
}

#endif
