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
    typealias Index = Array<Element>.Index
    
    struct Header {
        var used: Int
    }
    
    internal typealias Page = ManagedBuffer<Header, Index>
    
    typealias DenseElement = (index: Index, element: Element)
    
    static var pageSize: Index { 4096 }
    // Pages that we have space for
    var pageCount: Int { sparse.count }
    // Pages actually in use
    var usedPageCount: Int { sparse.map{$0 == nil ? 0 : 1 }.reduce(.zero, +) }

    static var elementsPerPage: Index { pageSize / MemoryLayout<Index>.stride }
    
    var count: Int { dense.count }
    var sparse: [Page?] = []
    var dense: [DenseElement] = []
    
    
    static func makePage() -> Page {
        Page.create(minimumCapacity: Self.pageSize / MemoryLayout<Index>.stride, makingHeaderWith: { _ in Header(used: 0) })
    }
    
    mutating func clear() {
        sparse = []
    }
    
    func page(for index: Index) -> (page: Index, offset: Index) {
        (page: index / Self.elementsPerPage, offset: index % Self.elementsPerPage)
    }
    
    mutating func assure(page: Index) -> Page {
        let realPage: Page
        if page < pageCount, let current = sparse[page] {
            // We already have a page for this index
            realPage = current
        } else if page < pageCount {
            // We have space for a pointer to a page, but no page
            realPage = Self.makePage()
            sparse[page] = realPage
        } else {
            // We need to grow the page array
            sparse.reserveCapacity(page + 1)
            sparse.append(contentsOf: Array(repeating: nil, count: page - pageCount + 1))
            realPage = Self.makePage()
            sparse[page] = realPage
        }
        return realPage
    }
    
    mutating func set(_ e: Element, at index: Index) {
        let (page, offset) = page(for: index)
        let idx = count
        dense.append((index, e))
        assure(page: page).withUnsafeMutablePointers{
            $0.pointee.used += 1
            // Make sparse[e] point to the index in dense of e
            ($1 + offset).pointee = idx
        }
    }
    
    func has(_ index: Index) -> Bool {
        let (page, offset) = page(for: index)
        guard page < pageCount, let sparsePage = sparse[page] else {
            return false
        }
        
        // Does this offer a speedup?
        // guard sparsePage.header.used > 0 else { return false}
        
        return sparsePage.withUnsafeMutablePointerToElements{
            let idx = ($0 + offset).pointee
            return idx < count && dense[idx].index == index
        }
    }
    
    mutating func remove(at idx: Index) {
        let (page, offset) = page(for: idx)
        
        guard page < pageCount, let sparsePage = sparse[page] else {
            print("Removed an element that didn't even have a page allocated: \(idx)")
            return
        }
        sparsePage.header.used -= 1
        // If using nulls, assign here.
        // Otherwise… safe to ignore because we will just check the array and find out it doesn't match up
        // sparsePage.withUnsafeMutablePointers{
        //            $0.pointee.used -= 1
        //($1 + offset)
        // }
        if sparsePage.header.used == 0 {
            sparse[page] = nil
        }
        // Move the last element into this position
        let end = dense.count - 1
        dense.swapAt(offset, end)
        // Now remove the element (should be == e)
        dense.removeLast()
    }
    
    func forEach(_ body: (DenseElement) -> Void) {
        dense.forEach(body)
    }
    
    func map<T>(_ body: (DenseElement) -> T) -> [T] {
        dense.map(body)
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
