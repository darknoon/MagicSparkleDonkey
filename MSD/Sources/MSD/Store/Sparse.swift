//
//  File.swift
//  
//
//  Created by Andrew Pouliot on 4/27/21.
//

import Foundation

struct Nothing: Equatable {
    
}

typealias SparseIntSet = SparseArrayPaged<Nothing>

// Based on sparse arrays in EnTT, and reference from fireblade-ecs swift
// https://research.swtch.com/sparse
// Useful in situations similar to [Index: Element], where Index is always relatively small
// (ie at least n / pageSize) memory will be consumed where n = maximum index used
@usableFromInline struct SparseArrayPaged<Element> {
    @usableFromInline
    typealias Index = Int
    // We  can store indices more compactly than Int, though we want to deal in Int  for convenience. If only 2^16 entries are required, could use UInt16
    typealias StoredIndex = UInt32
    typealias Key = Int
    typealias DenseElement = (index: Index, element: Element)
    
    // Pages that we have space for
    var pageCapacity: Int { sparse.pageCapacity }
    // Pages actually in use
    var activePageCount: Int { sparse.activePageCount }

    public var count: Int { dense.count }
    
    var sparse = SparseArray()
    var dense: [DenseElement] = []
    
    mutating func clear() {
        sparse = .init()
    }
    
    func has(_ index: Index) -> Bool {
        guard let denseIndex = sparse[index],
              denseIndex < dense.count
              else { return false }

        return dense[denseIndex].index == index
    }
    
    ///
    /// @return whether the item existed when removed
    @discardableResult
    mutating func remove(at index: Index) -> Bool {
        guard let denseIndex = sparse.remove(at: index)
        else {
            // Removed an index for which there wasn't a page. Throw?
            abort()
        }
        
        guard (0..<dense.count).contains(denseIndex),
              dense[denseIndex].index == index
        else {
            // Remove item not in the set
            return false
        }
        
        // Move the last element into this position
        let end = dense.count - 1
        dense.swapAt(denseIndex, end)
        // Now remove the element (should be == e)
        dense.removeLast()
        return true
    }
    
    func forEach(_ body: (Entity.ID, Element) -> Void) {
        dense.forEach(body)
    }

    // Experimental: mutating forEach
    public mutating func forEach(_ body: (Entity.ID, inout Element) -> Void) {
        dense.withUnsafeMutableBufferPointer{ ptr in
            for i in ptr.indices {
                body(ptr[i].index, &ptr[i].element)
            }
        }
    }
    
    func map<T>(_ body: (DenseElement) -> T) -> [T] {
        dense.map(body)
    }
}

extension SparseArrayPaged : RandomAccessCollection {
    
    public var startIndex: Array<Element>.Index {
        dense.startIndex
    }
    
    public var endIndex: Array<Element>.Index {
        dense.endIndex
    }

    @usableFromInline
    subscript(index: Index) -> Element? {
        get {
            guard let denseIndex = sparse[index]
            else { return nil }
            
            guard (0..<dense.count).contains(denseIndex),
                  dense[denseIndex].index == index
            else { return nil }

            return dense[denseIndex].element
        }
        
        set {
            guard let newValue = newValue
            else {
                remove(at: index)
                return
            }
            
            // Do the checks to make sure the value we get from sparse still corresponds with what's in dense
            if let denseIndex = sparse[index],
               (0..<dense.count).contains(denseIndex),
               dense[denseIndex].index == index {
                dense[denseIndex] = (index, newValue)
            } else {
                let denseIndex = dense.count
                sparse[index] = denseIndex
                dense.append((index, newValue))
            }
        }
    

    }

}

extension SparseArrayPaged {
    
    // Sparse array holds indices of items in dense array
    // Internally it holds an array of Pages, which can be deallocated
    
    // it's kinda like [Index: Index]

    internal struct SparseArray {
        
        struct Header {
            // Number of used items within this page, up to a max of elementsPerPage, though they will not be in order
            var used: Int
        }

        typealias Page = ManagedBuffer<Header, Index>

        var storage: [Page?] = []
        
        // Pages that we have space for
        var pageCapacity: Int {
            storage.count
        }

        // Pages actually in use
        var activePageCount: Int {
            storage.map{$0 == nil ? 0 : 1 }.reduce(.zero, +)
        }

        // Tunable parameter
        static var pageSize: Index { 4096 - MemoryLayout<Header>.stride }

        static var elementsPerPage: Index { pageSize / MemoryLayout<Index>.stride }

        
        // Still need to compare with what you got from dense, b/c this may be out of date
        // May return invalid memory, ie completely bogus indices
        subscript(index: Int) -> Index? {
            get {
                let (page, offset) = page(for: index)
                guard page < pageCapacity, let sparsePage = storage[page] else {
                    return nil
                }

                // Does this offer a speedup?
                // guard sparsePage.header.used > 0 else { return false}

                return sparsePage.withUnsafeMutablePointerToElements{ ptr in
                    let buf = UnsafeBufferPointer(start: ptr, count: Self.elementsPerPage)
                    return buf[offset]
                }
            }
            // sparse[idx] = nil ->
            set {
                // Setting nil doesn't make sense, sorry!
                guard let newValue = newValue else { abort() }

                let (page, offset) = page(for: index)
                assure(page: page).withUnsafeMutablePointers{ header, elements in
                    header.pointee.used += 1
                    let buf = UnsafeMutableBufferPointer(start: elements, count: Self.elementsPerPage)
                    // Make sparse[e] point to the index in dense of e
                    buf[offset] = newValue
                }

            }
        }
        
        
        mutating func assure(page: Index) -> Page {
            let realPage: Page
            if page < pageCapacity, let current = storage[page] {
                // We already have a page for this index
                realPage = current
            } else if page < pageCapacity {
                // We have space for a pointer to a page, but no page
                realPage = Self.makePage()
                storage[page] = realPage
            } else {
                // We need to grow the page array.
                // Is this the optimal way in swift?
                storage.append(contentsOf: Array(repeating: nil, count: page - pageCapacity + 1))
                realPage = Self.makePage()
                storage[page] = realPage
            }
            return realPage
        }
        

        static func makePage() -> Page {
            Page.create(minimumCapacity: Self.pageSize / MemoryLayout<Index>.stride, makingHeaderWith: { _ in Header(used: 0) })
        }
        
        func page(for index: Index) -> (page: Index, offset: Index) {
            (page: index / Self.elementsPerPage, offset: index % Self.elementsPerPage)
        }

        mutating func remove(at index: Index) -> Index? {
            
            let (page, offset) = page(for: index)
            
            guard page < pageCapacity, let sparsePage = storage[page] else {
                print("Removed an element that didn't even have a page allocated: \(index)")
                return nil
            }

            // If we were using nulls, assign here?

            // Otherwise… safe to not change our entry in the array because we will just check the array and find out it doesn't match up
            // sparsePage.withUnsafeMutablePointers{
            //            $0.pointee.used -= 1
            //($1 + offset)
            // }
            
            // Deallocate this page if its refcount reached zero
            sparsePage.header.used -= 1
            if sparsePage.header.used == 0 {
                storage[page] = nil
            }
            
            return sparsePage[offset]
            
        }
        
    }
    
    

}

// Hmm, is it telling us something that this isn't provided?
extension ManagedBuffer {
    subscript(index: Int) -> Element {
        get {
            withUnsafeMutablePointerToElements{
                UnsafeBufferPointer(start: $0, count: capacity)[index]
            }
        }
        set {
            withUnsafeMutablePointerToElements{
                let buf = UnsafeMutableBufferPointer(start: $0, count: capacity)
                buf[index] = newValue
            }
        }
    }
}

extension SparseArrayPaged: Equatable where Element : Equatable {

    @usableFromInline
    static func == (lhs: SparseArrayPaged<Element>, rhs: SparseArrayPaged<Element>) -> Bool {
        // 1st check both have same pages
        guard lhs.activePageCount == rhs.activePageCount else { return false }
        
        // Now check that they both have the same dense elements, though they don't have to be in the same ordere
        for (idx, l) in lhs.dense {
            let r = rhs[idx]
            if r != l {
                return false
            }
        }

        for (idx, r) in rhs.dense {
            let l = lhs[idx]
            if l != r {
                return false
            }
        }

        return true
    }
    
}

extension SparseArrayPaged where Element == Nothing {
    
    mutating func insert(_ e: Index) {
        self[e] = Nothing()
    }
    
    mutating func remove(_ idx: Index) {
        remove(at: idx)
    }

    func forEach(_ body: (Index) -> Void) {
        dense.forEach{body($0.index)}
    }
    
    func map<T>(_ body: (Index) -> T) -> [T] {
        dense.map{body($0.index)}
    }

}


extension SparseIntSet: ExpressibleByArrayLiteral {
    @usableFromInline
    init(arrayLiteral: Index...) {
        self.init()
        for element in arrayLiteral {
            self.insert(element)
        }
    }
}

