//
//  GPUBufferQueue.swift
//  MagicSparkleDonkey
//
//  Created by Andrew Pouliot on 2/27/22.
//

import Metal


// Stores a GPU buffer with 3 entries that can be cycled between, as a property wrapper
@propertyWrapper
final class GPUBufferQueue<T> {
    // The 256 byte aligned size of our uniform structure
    let alignedUniformsSize = (MemoryLayout<T>.size + 0xFF) & -0x100

    let maxBuffersInFlight = 3

    let inFlightSemaphore: DispatchSemaphore
    
    let dynamicUniformBuffer: MTLBuffer
    
    var bufferOffset: Int {
        alignedUniformsSize * bufferIndex
    }
    
    var bufferIndex = 0
    
    var pointer: UnsafeMutablePointer<T> {
        UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + bufferOffset).bindMemory(to:T.self, capacity:1)
    }
    
    var wrappedValue: T {
        _read {
            yield pointer.pointee
        }
        _modify {
            yield &pointer.pointee
        }
    }
    
    struct GPUState {
        let offset: Int
        let buffer: MTLBuffer
    }
    
    /// Provides `renderEncoder.setVertexBuffer($uniforms.buffer, offset:$uniforms.offset, index: BufferIndex.uniforms.rawValue)`

    var projectedValue: GPUState {
        return GPUState(offset: bufferOffset, buffer: dynamicUniformBuffer)
    }
    
    init(device: MTLDevice) throws {
        let uniformBufferSize = alignedUniformsSize * maxBuffersInFlight
        inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
        
        guard let buffer = device.makeBuffer(length:uniformBufferSize, options:[MTLResourceOptions.storageModeShared]) else { throw RendererError.metalAllocationError }
        buffer.label = "GPUBufferQueue<\(T.self)>"
        dynamicUniformBuffer = buffer
    }
    
    /// Advance to the next buffer in the set
    func next() {
        bufferIndex = (bufferIndex + 1) % maxBuffersInFlight
    }

}

