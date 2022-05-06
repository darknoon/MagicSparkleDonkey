//
//  File.swift
//  
//
//  Created by Andrew Pouliot on 5/2/22.
//

import Foundation
import Metal

extension MTLDevice {
    /// Options that should be set on a buffer that is used as an "upload" buffer for CPU → GPU communication.
    /// On iOS we can use shared memory (not private), whereas on macOS we must use managed memory
    /// Not sure if there is much difference with writeCombined memory, but since we don't read it should be effective
    var uploadBufferOptions: MTLResourceOptions {
#if os(macOS)
        hasUnifiedMemory ? [.storageModeShared, .cpuCacheModeWriteCombined] : [.storageModeManaged, .cpuCacheModeWriteCombined]
#else
        [.storageModeManaged, .cpuCacheModeWriteCombined]
#endif
    }
}

// This class implements a simple bump allocator for per-frame GPU memory
// If we run out of memory, the client needs to retry rendering with a new buffer, because the pointers into this buffer will be invalid
public final class GPUMemoryPool {
    
    enum Failure: Error {
        case allocationError
        case invalidInput
    }
    
    let device: MTLDevice
    
    /// If not specified, resourceOptions will default to an appropriate mode for CPU-write-GPU-read memory
    /// ie `.storageModeShared` on iOS / Apple Silicon and `[.storageModeManaged]` on macOS discrete/integrated GPUs
    init(device: MTLDevice, size: Int = 128_000) throws {
        self.device = device
        self.size = size
        guard size < device.recommendedMaxWorkingSetSize
        else { throw Failure.allocationError }

        buffers = try TupleCollection{ i in
            guard let buf = device.makeBuffer(length: size, options: device.uploadBufferOptions),
                  buf.allocatedSize == size
            else { throw Failure.allocationError }
            buf.label = "GPUMemoryPool \(i)"
            return buf
        }
        
        inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
    }
    

    var bufferIndex = 0
    let maxBuffersInFlight = 3
    let inFlightSemaphore: DispatchSemaphore

    var buffers: TupleCollection<(MTLBuffer, MTLBuffer, MTLBuffer), MTLBuffer>
    // TODO: make this a single buffer with usable sub-ranges?
    var currentBuffer: MTLBuffer { buffers[bufferIndex] }
    var baseAddress: UnsafeMutableRawPointer { currentBuffer.contents() }
    
    var size: Int
    
    // Allocation boundary
    var currentOffset: Int = 0
    
    // Start writing a frame of data. If we run out of space in the buffer, we will need to grow it, and copy any data already written to the new space
    // It is up to the consumer to ensure that this buffer is done being used at this point
    func beginFrame() {
        currentOffset = 0
    }
    
    func finishFrame() {
        // Make sure that any memory we wrote to is flushed (discrete GPU only)
        if currentBuffer.resourceOptions.contains(.storageModeManaged) {
            currentBuffer.didModifyRange(0..<currentOffset)
        }
        next()
    }
    
    /// Advance to the next buffer in the set
    func next() {
        bufferIndex = (bufferIndex + 1) % maxBuffersInFlight
    }

    
    // TODO: enforce alignment for the allocation
    internal func allocate(bytes: Int) -> UnsafeMutableRawPointer? {
        // Remaining space in this direction
        let space = size - currentOffset
        if space >= bytes {
            let retVal = baseAddress + currentOffset
            currentOffset += bytes
            return retVal
        } else {
            return nil
        }
    }

    // Append a value of type T, returns offset in the buffer
    func append<T>(_ value: T) throws -> Int  /* Failure.allocationError */ {
        guard let ptr = allocate(bytes: MemoryLayout<T>.stride)
        else { throw Failure.allocationError }
        let typed = ptr.bindMemory(to: T.self, capacity: 1)
        typed.pointee = value
        return ptr - baseAddress
    }

    // Returns the memory address to assign to the binding
//    func emplace<T>(_ fn: (UnsafeMutablePointer<T>) -> Void) -> UnsafeRawPointer? {
//        if let ptr = allocate(bytes: MemoryLayout<T>.stride) {
//            let typed = ptr.bindMemory(to: T.self, capacity: 1)
//            fn(typed)
//            return UnsafeRawPointer(ptr)
//        } else {
//            // No space remaining
//            return nil
//        }
//    }
    
}
