import Metal

extension MTLComputeCommandEncoder {
    func setStruct<T>(_ s : T, index: Int) {
        var s = s
        setBytes(&s, length: MemoryLayout<T>.size, index: index)
    }
}

extension MTLRenderCommandEncoder {
    func setFragmentStruct<T>(_ s : T, index: Int) {
        var s = s
        setFragmentBytes(&s, length: MemoryLayout<T>.size, index: index)
    }

    func setVertexStruct<T>(_ s : T, index: Int) {
        var s = s
        setVertexBytes(&s, length: MemoryLayout<T>.size, index: index)
    }
}
