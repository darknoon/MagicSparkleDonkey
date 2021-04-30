//
//  File.swift
//  
//
//  Created by Andrew Pouliot on 4/27/21.
//

import Foundation


typealias SparseIntSet = SparseArrayPaged<Void>


// Based on sparse arrays in EnTT, and reference from fireblade-ecs swift
// https://research.swtch.com/sparse
@usableFromInline struct SparseArrayPaged<Element> {
    @usableFromInline
    typealias Index = Array<Element>.Index
    typealias Key = Int
    typealias DenseElement = (index: Index, element: Element)
    
    // Pages that we have space for
    var pageCapacity: Int { sparse.pageCapacity }
    // Pages actually in use
    var activePageCount: Int { sparse.activePageCount }

    var count: Int { dense.count }
    var sparse = SparseArray()
    var dense: [DenseElement] = []
    
    
    mutating func clear() {
        sparse = .init()
    }
    
    mutating func set(_ e: Element, at index: Index) {
        let denseIndex = count
        dense.append((index, e))
        sparse[index] = denseIndex
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
        guard let denseIdx = sparse.remove(at: index)
        else {
            // Removed an index for which there wasn't a page. Throw?
            abort()
        }
        
        guard (0..<dense.count).contains(denseIdx),
              dense[denseIdx].index == index
        else {
            // Remove item not in the set
            return false
        }
        
        // Move the last element into this position
        let end = dense.count - 1
        dense.swapAt(denseIdx, end)
        // Now remove the element (should be == e)
        dense.removeLast()
        return true
    }
    
    func forEach(_ body: (DenseElement) -> Void) {
        dense.forEach(body)
    }
    
    func map<T>(_ body: (DenseElement) -> T) -> [T] {
        dense.map(body)
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
        subscript(index: Int) -> Index? {
            get {
                let (page, offset) = page(for: index)
                guard page < pageCapacity, let sparsePage = storage[page] else {
                    return nil
                }

                // Does this offer a speedup?
                // guard sparsePage.header.used > 0 else { return false}

                let buf = sparsePage.withUnsafeMutablePointerToElements{
                    UnsafeBufferPointer(start: $0, count: pageCapacity)
                }
                return buf[offset]
            }
            // sparse[idx] = nil ->
            set {
                // Setting nil doesn't make sense, sorry!
                guard let newValue = newValue else { abort() }

                let (page, offset) = page(for: index)
                assure(page: page).withUnsafeMutablePointers{
                    $0.pointee.used += 1
                    // Make sparse[e] point to the index in dense of e
                    ($1 + offset).pointee = newValue
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
                storage.reserveCapacity(page + 1)
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

extension SparseArrayPaged where Element == Void {
    
    mutating func insert(_ e: Index) {
        set(Void(), at: e)
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

