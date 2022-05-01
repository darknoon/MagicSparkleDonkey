import Foundation

// Additions not originally in the _FixedArray16 from Swift open source

extension _FixedArray16: ExpressibleByArrayLiteral {
    
    // Init all to .zero
    init() {
        _count = 0
        storage = withUnsafeTemporaryAllocation(of: Element.self, capacity: 16) { tempPtr in
            let raw = UnsafeRawPointer(tempPtr.baseAddress!)
            // Do we need to to zero this?
            return raw.assumingMemoryBound(to: Storage.self).pointee
        }
    }
    
    init(arrayLiteral elements: Element...) {
        self.init()
        for element in elements {
            append(element)
        }
    }
    
}


extension _FixedArray16: Equatable where Element: Equatable {

    static func == (lhs: _FixedArray16<T>, rhs: _FixedArray16<T>) -> Bool {
        lhs.count == rhs.count && lhs.elementsEqual(rhs)
    }
    
}
