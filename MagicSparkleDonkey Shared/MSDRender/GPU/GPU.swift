import Foundation

// GPU abstraction for renderer

enum GPUFailure : Error {
    case shaderCompilation
    case unsupportedPixelFormat
}

enum GPUStorageMode: Int {
    case shared = 0
    case `private` = 2
}

enum GPUTextureCacheMode {
    case `private`
}

enum GPUVertexFormat {
    case float2
    case float3
}

enum GPUIndexType : UInt {
    case uint16 = 0
    case uint32 = 1
}


enum GPUPrimitiveType {
    case triangle
}

struct GPUSwapChainConfiguration {
    let format: GPUPixelFormat
    let depthStencilFormat: GPUPixelFormat
    let sampleCount: Int
}

struct GPUTextureLoadingOptions {
    let generateMipMaps: Bool
    // let usage: GPUTextureUsage
}

struct GPUDepthStencilDescriptor {
    let writeDepth: Bool
}

struct GPURenderPipelineDescriptor<Function: GPUFunction> {
    let label: String?
    let vertexFunction: Function
    let fragmentFunction: Function
    let sampleCount: Int
    let descriptor: GPUVertexDescriptor?
    struct ColorAttachment {
        let pixelFormat: GPUPixelFormat
    }
    let colorAttachments: [ColorAttachment]
    let depthAttachmentPixelFormat: GPUPixelFormat?
    let stencilAttachmentPixelFormat: GPUPixelFormat?
}

struct GPUVertexDescriptor {

    struct VertexAttribute {
        let format: GPUVertexFormat
        let offset: Int
        let bufferIndex: Int
    }
    
    struct VertexBufferLayoutDescriptor {
        let stride: Int
    }

    let attributes: [Int: VertexAttribute]
    let layouts: [Int: VertexBufferLayoutDescriptor]
}

enum GPUPixelFormat: UInt32, CaseIterable {
    case depth32Float_stencil8
    case rgba16Float
}

enum GPUCullMode {
    case front
    case back
    case none
}

enum GPUWindingMode {
    case clockwise
    case counterClockwise
}

protocol GPUAPI {
    typealias Device = Self
    
    // Can have a custom error type or use the generic enum
    associatedtype Failure: Error = GPUFailure

    // State objects
    associatedtype DepthStencilState: GPUDepthStencilState
    associatedtype RenderPassDescriptor: GPURenderPassDescriptor
    associatedtype RenderPipelineState: GPURenderPipelineState
    
    func makeDepthStencilState(descriptor: GPUDepthStencilDescriptor) -> DepthStencilState?
    func makeRenderPipelineState(descriptor: GPURenderPipelineDescriptor<Function>) throws -> RenderPipelineState

    // Function objects
    associatedtype ShaderLibrary: GPUShaderLibrary where
        ShaderLibrary.Function == Self.Function
    associatedtype Function: GPUFunction
    var defaultLibrary: ShaderLibrary? { get }

    // Memory objects
    associatedtype Texture: GPUTexture
    associatedtype Buffer: GPUBuffer & GPUDebugLabeled
    
    func makeBuffer(length: Int, storageMode: GPUStorageMode) -> Buffer?

    // Surfaces
    associatedtype SwapChain: GPUSwapChain where
        SwapChain.RenderPassDescriptor == Self.RenderPassDescriptor,
        SwapChain.Device == Self,
        SwapChain.Drawable == Self.Drawable
    associatedtype Drawable: GPUDrawable

    // Queue
    associatedtype CommandQueue: GPUCommandQueue where
        CommandQueue.CommandBuffer == Self.CommandBuffer
    
    // Encoding
    associatedtype CommandBuffer: GPUCommandBuffer where
        CommandBuffer.MeshRuntimeType == Self.MeshRuntimeType,
        CommandBuffer.RenderPassDescriptor == Self.RenderPassDescriptor,
        CommandBuffer.RenderEncoder == Self.RenderEncoder,
        CommandBuffer.Drawable == Self.Drawable
    associatedtype RenderEncoder: GPURenderEncoder & GPUDebugLabeled & GPUDebugGrouped where
        RenderEncoder.DepthStencilState == Self.DepthStencilState,
        RenderEncoder.RenderPipelineState == Self.RenderPipelineState,
        RenderEncoder.Buffer == Self.Buffer
    
    func makeCommandQueue() -> CommandQueue?

    // Texture Utils
    // TextureLoader may be created with .init(device: self)
    associatedtype TextureLoader: GPUTextureLoader where
        TextureLoader.Device == Self,
        TextureLoader.Texture == Self.Texture

    // Mesh Utils
    associatedtype MeshBufferAllocator: GPUMeshBufferAllocator where
        MeshBufferAllocator.Device == Self
    associatedtype MeshRuntimeType: GPUMesh where
        MeshRuntimeType.SubmeshCollection: Collection,
        MeshRuntimeType.SubmeshCollection.Element == Self.Submesh,
        MeshRuntimeType.SubmeshCollection.Index == Int,
        MeshRuntimeType.VertexBufferCollection: Collection,
        MeshRuntimeType.VertexBufferCollection.Element == Self.MeshBuffer,
        MeshRuntimeType.VertexBufferCollection.Index == Int
    associatedtype Submesh: GPUSubmesh where
        Submesh.MeshIndexBuffer == Self.MeshIndexBuffer
    associatedtype MeshIndexBuffer: GPUMeshBuffer where
        MeshIndexBuffer.Buffer == Self.Buffer
    associatedtype MeshBuffer: GPUMeshBuffer where
        MeshBuffer.Buffer == Self.Buffer

    // Mesh type as loaded from resources / filesystem. Could be ModelIO, custom format, etc
    func prepareMesh<T: GPUMeshInput>(mesh: T, vertexDescriptor: GPUVertexDescriptor) throws -> MeshRuntimeType

    // Make concrete types available as aliases in a conforming GPU api's namespace
    typealias VertexDescriptor = GPUVertexDescriptor
}

protocol GPUMeshInput {
    
}

protocol GPUDebugLabeled {
    var label: String? { get set }
}

protocol GPUDebugGrouped {
    func pushDebugGroup(_ string: String)
    func popDebugGroup()
}

protocol GPUDrawable {}

protocol GPUSwapChain {
    associatedtype Device
    associatedtype RenderPassDescriptor
    associatedtype Drawable

    var device: Device { get }
    var currentRenderPassDescriptor: RenderPassDescriptor? { get }
    var configuration: GPUSwapChainConfiguration { get set }
    
    var currentDrawable: Drawable? { get }
}

protocol GPUCommandQueue {
    associatedtype CommandBuffer
    func makeCommandBuffer() -> CommandBuffer?
}

protocol GPUCommandBuffer {
    associatedtype MeshRuntimeType
    associatedtype RenderPassDescriptor
    associatedtype RenderPipelineState
    associatedtype DepthStencilState
    associatedtype Drawable
    associatedtype RenderEncoder

    func addCompletedHandler(_ block: @escaping (Self) -> Void)
    
    func commit()
    
    func present(_ drawable: Drawable)
  
    func makeRenderCommandEncoder(descriptor: RenderPassDescriptor) -> RenderEncoder?
    
    // This needs to be rethough…
//    func draw(mesh: MeshRuntimeType, pass: RenderPassDescriptor, pipelineState: RenderPipelineState, depthState: DepthStencilState) throws

}

protocol GPUCommandEncoder {
    func endEncoding()
}

protocol GPURenderEncoder : GPUCommandEncoder {
    associatedtype DepthStencilState
    associatedtype RenderPipelineState
    associatedtype Buffer
    associatedtype Texture

    func setFrontFacing(_ frontFacingWinding: GPUWindingMode)
    func setCullMode(_ cullMode: GPUCullMode)
    func setDepthStencilState(_ depthStencilState: DepthStencilState)
    func setRenderPipelineState(_ state: RenderPipelineState)
    
    func setVertexBuffer(_ buffer: Buffer, offset: Int, index: Int)
    func setFragmentBuffer(_ buffer: Buffer, offset: Int, index: Int)

    func drawIndexedPrimitives(type primitiveType: GPUPrimitiveType, indexCount: Int, indexType: GPUIndexType, indexBuffer: Buffer, indexBufferOffset: Int)

    // TODO: push constants
//    func setVertexBytes(_ buffer: Buffer, offset: Int, index: Int)
//    func setFragmentBytes(_ buffer: Buffer, offset: Int, index: Int)
}

protocol GPURenderPassDescriptor {
}

protocol GPUFunction {
}

protocol GPUDepthStencilState {
}

protocol GPURenderPipelineState {
}

protocol GPUShaderLibrary {
    associatedtype Function
    var functionNames: [String] { get }
    func makeFunction(named: String) throws -> Function
}

protocol GPUMesh {
    associatedtype SubmeshCollection
    associatedtype VertexBufferCollection
    var submeshes: SubmeshCollection { get }
    var vertexBuffers: VertexBufferCollection { get }
    var vertexDescriptor: GPUVertexDescriptor { get }
}

protocol GPUSubmesh {
    associatedtype MeshIndexBuffer
    var primitiveType: GPUPrimitiveType { get }

    var indexType: GPUIndexType { get }

    var indexBuffer: MeshIndexBuffer { get }

    var indexCount: Int { get }
    
}

protocol GPUTexture {
}

protocol GPUBuffer {
    var length: Int { get }
    // Sometimes the buffer doesn't have a CPU address
    var data: UnsafeMutableRawPointer? { get }
}

protocol GPUMeshBuffer {
    associatedtype Buffer
    var offset: Int { get }
    var buffer: Buffer { get }
}

protocol GPUTextureLoader {
    associatedtype Device
    associatedtype Texture
    init(device: Device)
    
    func makeTexture(url: URL, options: GPUTextureLoadingOptions) throws -> Texture
}

protocol GPUMeshBufferAllocator {
    associatedtype Device
    init(device: Device)
}
