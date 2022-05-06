// Copyright 2020 Jordan Rose
// MIT License, go ahead and use it for stuff.

//public func testOptimization(_ tuple: (Int, Int, Int)) -> Int {
//    let collection = TupleCollection(tuple, of: Int.self)
//    return collection.reduce(0, &+)
//}

struct TupleCollection<Tuple, Element>: MutableCollection, RandomAccessCollection {
    var tuple: Tuple

    init(_ tuple: Tuple, of element: Element.Type = Element.self) {
        precondition(MemoryLayout<Tuple>.stride % MemoryLayout<Element>.stride == 0)
        precondition(MemoryLayout<Tuple>.alignment == MemoryLayout<Element>.alignment)
        self.tuple = tuple
    }

    var startIndex: Int { 0 }
    var endIndex: Int { MemoryLayout<Tuple>.stride / MemoryLayout<Element>.stride }

    subscript(index: Int) -> Element {
        get {
            precondition(self.indices.contains(index))
            return withUnsafePointer(to: tuple) {
                // This "assumingMemoryBound(to:)" is safe because a tuple's elements are
                // "related types".
                // https://swift.org/migration-guide-swift3/se-0107-migrate.html#unsaferawpointerassumingmemoryboundto
                UnsafeRawPointer($0).assumingMemoryBound(to: Element.self)[index]
            }
        }
        set {
            precondition(self.indices.contains(index))
            withUnsafeMutablePointer(to: &tuple) {
                UnsafeMutableRawPointer($0).assumingMemoryBound(to: Element.self)[index] = newValue
            }
        }
    }
}

extension TupleCollection: Equatable where Element: Equatable {
    static func == (lhs: TupleCollection<Tuple, Element>, rhs: TupleCollection<Tuple, Element>) -> Bool {
        return lhs.elementsEqual(rhs)
    }
}

extension TupleCollection: Hashable where Element: Hashable {
    func hash(into hasher: inout Hasher) {
        self.forEach { hasher.combine($0) }
    }
}

// Added by darknoon
extension TupleCollection {
    init(repeating element: Element) {
        let endIndex = MemoryLayout<Tuple>.stride / MemoryLayout<Element>.stride
        self.tuple = withUnsafeTemporaryAllocation(of: Element.self, capacity: endIndex) { tempPtr in
            for i in 0..<endIndex {
                (tempPtr.baseAddress! + i).initialize(to: element)
            }
            return UnsafeRawPointer(tempPtr.baseAddress!).assumingMemoryBound(to: Tuple.self).pointee
        }
    }

    init(with builder: (Int) throws -> Element ) rethrows {
        let endIndex = MemoryLayout<Tuple>.stride / MemoryLayout<Element>.stride
        self.tuple = try withUnsafeTemporaryAllocation(of: Element.self, capacity: endIndex) { tempPtr in
            for i in 0..<endIndex {
                (tempPtr.baseAddress! + i).initialize(to: try builder(i))
            }
            return UnsafeRawPointer(tempPtr.baseAddress!).assumingMemoryBound(to: Tuple.self).pointee
        }
    }

}
