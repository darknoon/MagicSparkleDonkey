//
//  File.swift
//  
//
//  Created by Andrew Pouliot on 4/16/21.
//

// GPUMetal assumes the platform supports Metal for rendering and ModelIO for mesh loading

import Metal
import MetalKit
import ModelIO

// Abstraction for metal rendering on the GPU
class GPUMetal : GPUAPI {

    init(device: MTLDevice) throws {
        self.device = device
        guard let lib = device.makeDefaultLibrary() else {
            throw Failure.shaderCompilation
        }
        self.defaultLibrary = ShaderLibrary(metalLibrary: lib)
        self.defaultAllocator = MeshBufferAllocator(device: device)
    }
    
    let device: MTLDevice
    let defaultLibrary: ShaderLibrary?
    let defaultAllocator: MeshBufferAllocator
    
    struct Texture {
        let texture: MTLTexture
    }
    
    struct CommandQueue {
        let queue: MTLCommandQueue
    }
    
    struct CommandBuffer  {
        let buffer: MTLCommandBuffer
    }
    
    struct RenderEncoder {
        let encoder: MTLRenderCommandEncoder
    }

    struct ShaderLibrary {
        let metalLibrary: MTLLibrary
    }
    
    struct CompiledShader {
        let vertexFunction: MTLFunction
        let fragmentFunction: MTLFunction
    }
    
    struct DepthStencilState: GPUDepthStencilState {
        let state: MTLDepthStencilState
    }
    
    class SwapChain {
        let view: MTKView
        init(view: MTKView) {
            self.view = view
        }
    }
    
    struct RenderPipelineState {
        let state: MTLRenderPipelineState
    }
    
    struct Drawable : GPUDrawable {
        let drawable: MTLDrawable
    }
  
    // We can use this class more or less directly by making a subclass
    // Other option would be `struct MeshBufferAllocator { let allocator: MTKMeshBufferAllocator }`
    class MeshBufferAllocator : MTKMeshBufferAllocator {
        typealias Device = GPUMetal
        required public init(device: Device) {
            super.init(device: device.device)
        }
        
        required internal override init(device: MTLDevice) {
            super.init(device: device)
        }
    }
    
    struct MeshRuntimeType {
        let mesh: MTKMesh
        let vertexDescriptor: GPUVertexDescriptor
    }

    struct Submesh {
        let submesh: MTKSubmesh
    }
    
    struct Buffer {
        let buffer: MTLBuffer
    }
    
    struct MeshBuffer {
        let mtkBuffer: MTKMeshBuffer
    }

    func makeBuffer(length: Int, storageMode: GPUStorageMode) -> Buffer? {
        device.makeBuffer(length: length, options: MTLResourceOptions(storageMode)).map(Buffer.init)
    }

    typealias MeshIndexBuffer = MeshBuffer

    struct Function {
        let function: MTLFunction
    }
    
    struct RenderPassDescriptor {
        let descriptor: MTLRenderPassDescriptor
    }
    
    class TextureLoader : MTKTextureLoader {
        required init(device: GPUMetal) {
            super.init(device: device.device)
        }
    }

    
    func makeCommandQueue() -> CommandQueue? {
        device.makeCommandQueue().map(CommandQueue.init)
    }
    
    // Load the given mesh into GPU buffers that match vertexDescriptor
    func prepareMesh<T: GPUMeshInput>(mesh: T, vertexDescriptor: GPUVertexDescriptor) throws -> MeshRuntimeType {
        if T.self == MDLMesh.self {
            return try prepareMesh(mesh: mesh as! MDLMesh, vertexDescriptor: vertexDescriptor)
        } else {
            throw Failure.unknownMeshInputType
        }
    }

    func prepareMesh(mesh: MDLMesh, vertexDescriptor: GPUVertexDescriptor) throws -> MeshRuntimeType {
        // Copy because we're changing vertex descriptor
        let m = MDLMesh(vertexBuffers: mesh.vertexBuffers, vertexCount: mesh.vertexCount, descriptor: mesh.vertexDescriptor, submeshes: mesh.submeshes as! [MDLSubmesh])
        m.vertexDescriptor = MDLVertexDescriptor(vertexDescriptor)
        let mtkMesh = try MTKMesh(mesh: m, device: device)
        return .init(mesh: mtkMesh, vertexDescriptor: vertexDescriptor)
    }

    func makeDepthStencilState(descriptor: GPUDepthStencilDescriptor) -> DepthStencilState? {
        let mtlDesc = MTLDepthStencilDescriptor()
        mtlDesc.isDepthWriteEnabled = descriptor.writeDepth
        return device.makeDepthStencilState(descriptor: mtlDesc).map(DepthStencilState.init)
    }
    
    func makeRenderPipelineState(descriptor: GPURenderPipelineDescriptor<Function>) throws -> RenderPipelineState {
        let pipe = MTLRenderPipelineDescriptor()
        pipe.label = descriptor.label
        pipe.sampleCount = descriptor.sampleCount
        pipe.vertexFunction = descriptor.vertexFunction.function
        pipe.fragmentFunction = descriptor.fragmentFunction.function
        if let vertexDescriptor = descriptor.vertexDescriptor {
            pipe.vertexDescriptor = MTLVertexDescriptor(vertexDescriptor)
        }
        for (i, attachment) in descriptor.colorAttachments.enumerated() {
            guard let mtlFormat = MTLPixelFormat(attachment.pixelFormat)
            else { throw Failure.unsupportedPixelFormat }
            pipe.colorAttachments[i].pixelFormat = mtlFormat
        }
        if let depthFormat = descriptor.depthAttachmentPixelFormat.flatMap(MTLPixelFormat.init) {
            pipe.depthAttachmentPixelFormat = depthFormat
        }
        if let stencilFormat = descriptor.stencilAttachmentPixelFormat.flatMap(MTLPixelFormat.init) {
            pipe.stencilAttachmentPixelFormat = stencilFormat
        }
        
        return RenderPipelineState(state: try device.makeRenderPipelineState(descriptor: pipe))
    }
    
    struct GeometricMeshUtils {
        
    }

}

extension MTLVertexDescriptor {
    convenience init(_ vertexDescriptor: GPUVertexDescriptor) {
        self.init()
        
        vertexDescriptor.layouts.forEach{ index, layout in
            layouts[index].stride = layout.stride
        }
        
        vertexDescriptor.attributes.forEach{ index, attribute in
            let a = attributes[index]!
            a.bufferIndex = attribute.bufferIndex
            a.format = MTLVertexFormat(attribute.format)
            a.offset = attribute.offset
        }

    }
}

extension MDLVertexFormat {
    init(_ ours: GPUVertexFormat) {
        switch ours {
        case .float2: self = .float2
        case .float3: self = .float3
        }
    }
}

extension MTLVertexFormat {
    init(_ ours: GPUVertexFormat) {
        switch ours {
        case .float2: self = .float2
        case .float3: self = .float3
        }
    }
}

extension MDLVertexDescriptor {
    
    // Convert our GPUVertexDescriptor generic format into one that ModelIO understands
    convenience init(_ vertexDescriptor: GPUVertexDescriptor) {
        self.init()
        let l = vertexDescriptor.layouts.map { index, layout in
            MDLVertexBufferLayout(stride: layout.stride)
        }
        layouts = NSMutableArray(array: l)

        let v = vertexDescriptor.attributes.map { index, attribute in
            MDLVertexAttribute(name: attribute.semantic.mdlAttributeName!, format: MDLVertexFormat(attribute.format), offset: attribute.offset, bufferIndex: attribute.bufferIndex)
        }
        attributes = NSMutableArray(array: v)
    }
}

// TODO: move this out of GPU abstraction!
extension VertexSemantic {
    var mdlAttributeName: String? {
        switch self {
        case .position:
            return MDLVertexAttributePosition
        case .normal:
            return MDLVertexAttributeNormal
        case .tangent:
            return MDLVertexAttributeTangent
        case .color:
            return MDLVertexAttributeColor
        case .boneIndices:
            return MDLVertexAttributeJointIndices
        case .boneWeights:
            return MDLVertexAttributeJointWeights
        case .texcoord0, .texcoord1, .texcoord2, .texcoord3, .texcoord4, .texcoord5, .texcoord6, .texcoord7:
            return MDLVertexAttributeTextureCoordinate
        @unknown default:
            return nil
        }
    }
}

extension GPUPixelFormat {
    init?(_ mtlFormat: MTLPixelFormat) {
        switch mtlFormat {
        case .depth32Float_stencil8: self = .depth32Float_stencil8
        case .bgra8Unorm_srgb: self = .bgra8Unorm_srgb
        case .rgba16Float: self = .rgba16Float
        default: return nil
        }
    }
}

extension MTLPixelFormat {
    init?(_ format: GPUPixelFormat) {
        switch format {
        case .depth32Float_stencil8: self = .depth32Float_stencil8
        case .bgra8Unorm_srgb: self = .bgra8Unorm_srgb
        case .rgba16Float: self = .rgba16Float
        }
    }
}

extension GPUCullMode {
    init?(_ cullMode: MTLCullMode) {
        switch cullMode {
        case .front: self =  .front
        case .back: self = .back
        case .none: self = .none
        @unknown default:
            return nil
        }
    }
}

extension MTLCullMode {
    init?(_ cullMode: GPUCullMode) {
        switch cullMode {
        case .front: self = .front
        case .back: self = .back
        case .none: self = .none
        }
    }
}


extension GPUWindingMode {
    init(_ winding: MTLWinding) {
        switch winding {
        case .clockwise: self = .clockwise
        case .counterClockwise: self = .counterClockwise
        @unknown default:
            fatalError("Unexpected winding mode \(winding)")
        }
    }
}

extension MTLWinding {
    init(_ winding: GPUWindingMode) {
        switch winding {
        case .clockwise: self = .clockwise
        case .counterClockwise: self = .counterClockwise
        }
    }
}

extension MTLResourceOptions {
    init(_ storage: GPUStorageMode) {
        switch storage {
        case .private: self = [.storageModePrivate]
        case .shared: self = [.storageModeShared]
        }
    }
}

extension MTLIndexType {
    init(_ indexType: GPUIndexType) {
        switch indexType {
        case .uint16: self = .uint16
        case .uint32: self = .uint32
        }
    }
}

extension GPUIndexType {
    init(_ indexType: MTLIndexType) {
        switch indexType {
        case .uint16: self = .uint16
        case .uint32: self = .uint32
        @unknown default:
            fatalError()
        }
    }
}



extension MTLPrimitiveType  {
    init(_ primitiveType: GPUPrimitiveType) {
        switch primitiveType {
        case .triangle: self = .triangle
        }
    }
}


extension GPUPrimitiveType  {
    init(_ primitiveType: MTLPrimitiveType) {
        switch primitiveType {
        case .triangle: self = .triangle
        default:
            fatalError("Only triangles are currently supported")
        }
    }
}

extension GPUMetal.RenderPipelineState : GPURenderPipelineState {}

extension GPUMetal.SwapChain : GPUSwapChain {
    typealias Device = GPUMetal
    typealias RenderPassDescriptor = GPUMetal.RenderPassDescriptor
    typealias Drawable = GPUMetal.Drawable

    var device: GPUMetal {
        try! GPUMetal(device: view.device!)
    }
    
    var currentDrawable: Drawable? {
        view.currentDrawable.map(Drawable.init)
    }

    var currentRenderPassDescriptor: RenderPassDescriptor? {
        view.currentRenderPassDescriptor.map(RenderPassDescriptor.init)
    }
    
    var configuration: GPUSwapChainConfiguration {
        get {
            GPUSwapChainConfiguration(format: GPUPixelFormat(view.colorPixelFormat)!,
                                      depthStencilFormat: GPUPixelFormat(view.depthStencilPixelFormat)!,
                                      sampleCount: view.sampleCount)
        }
        set {
            view.colorPixelFormat = MTLPixelFormat(newValue.format)!
            view.depthStencilPixelFormat = MTLPixelFormat(newValue.depthStencilFormat)!
            view.sampleCount = newValue.sampleCount
        }
    }
    
}

extension GPUMetal.Texture : GPUTexture {}

extension GPUMetal.Function : GPUFunction {}

extension GPUMetal.Buffer : GPUBuffer {
    var length: Int {
        buffer.length
    }
    
    var data: UnsafeMutableRawPointer? {
        switch buffer.storageMode {
        case .managed, .shared:
            return buffer.contents()
        default:
            return nil
        }
    }
}

extension GPUMetal.Buffer : GPUDebugLabeled {
    var label: String? {
        get {
            buffer.label
        }
        set {
            buffer.label = newValue
        }
    }
}

extension GPUMetal.CommandBuffer : GPUCommandBuffer {
    typealias RenderEncoder = GPUMetal.RenderEncoder
    typealias Drawable = GPUMetal.Drawable
    typealias MeshRuntimeType = GPUMetal.MeshRuntimeType
    typealias RenderPassDescriptor = GPUMetal.RenderPassDescriptor
    typealias RenderPipelineState = GPUMetal.RenderPipelineState
    typealias DepthStencilState = GPUMetal.DepthStencilState

    func addCompletedHandler(_ block: @escaping (GPUMetal.CommandBuffer) -> Void) {
        buffer.addCompletedHandler{
            block(Self(buffer: $0))
        }
    }
    
    func commit() {
        buffer.commit()
    }
    
    func present(_ drawable: Drawable) {
        buffer.present(drawable.drawable)
    }
    

    func makeRenderCommandEncoder(descriptor: RenderPassDescriptor) -> RenderEncoder? {
        buffer.makeRenderCommandEncoder(descriptor: descriptor.descriptor).map(RenderEncoder.init)
    }
}

extension GPUMetal.CommandBuffer : GPUDebugLabeled {
    var label: String? {
        get {
            buffer.label
        }
        set {
            buffer.label = newValue
        }
    }
}


extension GPUMetal.RenderEncoder : GPURenderEncoder {
    typealias DepthStencilState = GPUMetal.DepthStencilState
    typealias RenderPipelineState = GPUMetal.RenderPipelineState
    typealias Buffer = GPUMetal.Buffer
    typealias Texture = GPUMetal.Texture
    
    func setFrontFacing(_ frontFacingWinding: GPUWindingMode) {
        encoder.setFrontFacing(MTLWinding(frontFacingWinding))
    }
    
    func setCullMode(_ cullMode: GPUCullMode) {
        encoder.setCullMode(MTLCullMode(cullMode)!)
    }
    
    func setDepthStencilState(_ depthStencilState: GPUMetal.DepthStencilState) {
        encoder.setDepthStencilState(depthStencilState.state)
    }

    func setRenderPipelineState(_ state: GPUMetal.RenderPipelineState) {
        encoder.setRenderPipelineState(state.state)
    }
    
    func setVertexBuffer(_ buffer: Buffer, offset: Int, index: Int) {
        encoder.setVertexBuffer(buffer.buffer, offset: offset, index: index)
    }

    func setFragmentBuffer(_ buffer: GPUMetal.Buffer, offset: Int, index: Int) {
        encoder.setFragmentBuffer(buffer.buffer, offset: offset, index: index)
    }

    func setVertexTexture(_ texture: GPUMetal.Texture?, index: Int) {
        encoder.setVertexTexture(texture?.texture, index: index)
    }

    func setFragmentTexture(_ texture: GPUMetal.Texture?, index: Int) {
        encoder.setFragmentTexture(texture?.texture, index: index)
    }

    func drawIndexedPrimitives(type primitiveType: GPUPrimitiveType, indexCount: Int, indexType: GPUIndexType, indexBuffer: Buffer, indexBufferOffset: Int) {
        encoder.drawIndexedPrimitives(type: MTLPrimitiveType(primitiveType), indexCount: indexCount, indexType: MTLIndexType(indexType), indexBuffer: indexBuffer.buffer, indexBufferOffset: indexBufferOffset)
    }

    func endEncoding() {
        encoder.endEncoding()
    }

}

extension GPUMetal.RenderEncoder : GPUDebugLabeled {
    var label: String? {
        get {
            encoder.label
        }
        set {
            encoder.label = newValue
        }
    }
}

extension GPUMetal.RenderEncoder : GPUDebugGrouped {
    func pushDebugGroup(_ string: String) {
        encoder.pushDebugGroup(string)
    }
    
    func popDebugGroup() {
        encoder.popDebugGroup()
    }
}

extension GPUMetal.RenderPassDescriptor : GPURenderPassDescriptor {
    
}

extension GPUMetal.CompiledShader : GPUFunction {
    
}

extension GPUMetal.CommandQueue : GPUCommandQueue {
    typealias CommandBuffer = GPUMetal.CommandBuffer

    func makeCommandBuffer() -> GPUMetal.CommandBuffer? {
        queue.makeCommandBuffer().map(GPUMetal.CommandBuffer.init)
    }
}

extension GPUMetal.MeshRuntimeType : GPUMesh {
    
    struct VertexBufferCollection: Collection {
        let mesh: MTKMesh
        typealias Element = GPUMetal.MeshBuffer
        typealias Index = Int

        subscript(position: Int) -> GPUMetal.MeshBuffer {
            .init(mtkBuffer: mesh.vertexBuffers[position])
        }
        
        func index(after i: Int) -> Int {
            i + 1
        }
        var startIndex: Int {
            mesh.submeshes.startIndex
        }
        
        var endIndex: Int {
            mesh.submeshes.endIndex
        }
    }

    var vertexBuffers: VertexBufferCollection {
        .init(mesh: mesh)
    }

    // Create Submeshes on demand
    struct SubmeshCollection: Collection {
        let mesh: MTKMesh
        typealias Element = GPUMetal.Submesh
        typealias Index = Int

        subscript(position: Int) -> GPUMetal.Submesh {
            GPUMetal.Submesh(submesh: mesh.submeshes[position])
        }
        
        func index(after i: Int) -> Int {
            i + 1
        }
        var startIndex: Int {
            mesh.submeshes.startIndex
        }
        
        var endIndex: Int {
            mesh.submeshes.endIndex
        }
    }

    var submeshes: SubmeshCollection {
        .init(mesh: mesh)
    }

}

extension GPUMetal.Submesh : GPUSubmesh {
    typealias MeshIndexBuffer = GPUMetal.MeshIndexBuffer

    var indexBuffer: MeshIndexBuffer {
        .init(mtkBuffer: submesh.indexBuffer)
    }
    
    var indexCount: Int {
        submesh.indexCount
    }
    
    var primitiveType: GPUPrimitiveType {
        GPUPrimitiveType(submesh.primitiveType)
    }
    
    var indexType: GPUIndexType {
        GPUIndexType(submesh.indexType)
    }
        
}

extension GPUMetal.MeshBufferAllocator : GPUMeshBufferAllocator {
}

extension GPUMetal.MeshBuffer : GPUMeshBuffer {
    var offset: Int {
        mtkBuffer.offset
    }
    
    // We assume data is uploaded and static at this point
    var data: UnsafeMutableRawPointer? {
        nil
    }
    
    var buffer: GPUMetal.Buffer {
        .init(buffer: mtkBuffer.buffer)
    }
}

extension MDLMesh : GPUMeshInput {}

// Provide mesh creation utils
extension GPUMetal.GeometricMeshUtils: GPUGeometricMeshUtils {
    typealias MeshRuntimeType = GPUMetal.MeshRuntimeType
    typealias MeshBufferAllocator = GPUMetal.MeshBufferAllocator
    typealias MeshTemporaryType = MDLMesh
    
    static func newBox(withDimensions dimensions: vector_float3, segments: vector_uint3, inwardNormals: Bool, allocator: GPUMetal.MeshBufferAllocator?) -> MDLMesh {
        MDLMesh.newBox(withDimensions: dimensions, segments: segments, geometryType: MDLGeometryType.triangles, inwardNormals: inwardNormals, allocator: allocator)
    }

}



extension Dictionary where Key == MTKTextureLoader.Option, Value == Any {
    init(_ options: GPUTextureLoadingOptions) {
        if options.generateMipMaps {
            self = [.generateMipmaps: true]
        } else {
            self = [:]
        }
    }
}

extension GPUMetal.TextureLoader : GPUTextureLoader {
    typealias Device = GPUMetal
    typealias Texture = GPUMetal.Texture

    func makeTexture(url: URL, options: GPUTextureLoadingOptions) throws -> GPUMetal.Texture {
        let mtlTexture = try self.newTexture(URL: url, options: .init(options))
        return Texture(texture: mtlTexture)
    }
    
    func makeTexture(named name: String, options: GPUTextureLoadingOptions) throws -> Texture {
        let mtlTexture = try self.newTexture(name: name, scaleFactor: 1.0, bundle: nil, options: .init(options))
        return Texture(texture: mtlTexture)
    }
    
}

extension GPUMetal.ShaderLibrary : GPUShaderLibrary {
    typealias Function = GPUMetal.Function

    var functionNames: [String] {
        metalLibrary.functionNames
    }
    
    func makeFunction(named: String) throws -> Function {
        let desc = MTLFunctionDescriptor()
        desc.name = named
        return Function(function: try metalLibrary.makeFunction(descriptor: desc))
    }
    
}
