//
//  File.swift
//  
//
//  Created by Andrew Pouliot on 4/27/21.
//

import Foundation


typealias SparseSet = SparseSetPaged


// Based on sparse arrays in EnTT, and reference from fireblade-ecs swift
// https://research.swtch.com/sparse
struct SparseSetPaged<Element> where Element : BinaryInteger {
    typealias Index = Array<Element>.Index
    
    struct Header {
        var used: Int
    }
    
    internal typealias Page = ManagedBuffer<Header, Index>
    
    static var pageSize: Index { 4096 }
    // Pages that we have space for
    var pageCount: Int { sparse.count }
    // Pages actually in use
    var usedPageCount: Int { sparse.map{$0 == nil ? 0 : 1 }.reduce(.zero, +) }

    static var elementsPerPage: Index { pageSize / MemoryLayout<Index>.stride }
    
    var count: Int { dense.count }
    var sparse: [Page?] = []
    var dense: [Element] = []
    
    
    static func makePage() -> Page {
        Page.create(minimumCapacity: Self.pageSize / MemoryLayout<Index>.stride, makingHeaderWith: { _ in Header(used: 0) })
    }
    
    mutating func clear() {
        sparse = []
    }
    
    func page(_ e: Element) -> (page: Index, offset: Index) {
        (page: Index(e) / Self.elementsPerPage, offset: Index(e) % Self.elementsPerPage)
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
    
    mutating func insert(_ e: Element) {
        let (page, offset) = page(e)
        let idx = count
        dense.append(e)
        assure(page: page).withUnsafeMutablePointers{
            $0.pointee.used += 1
            // Make sparse[e] point to the index in dense of e
            ($1 + offset).pointee = idx
        }
    }
    
    func has(_ e: Element) -> Bool {
        let (page, offset) = page(e)
        guard page < pageCount, let sparsePage = sparse[page] else {
            return false
        }
        
        // Does this offer a speedup?
        // guard sparsePage.header.used > 0 else { return false}
        
        return sparsePage.withUnsafeMutablePointerToElements{
            let idx = ($0 + offset).pointee
            return idx < count && dense[idx] == e
        }
    }
    
    mutating func remove(_ e: Element) {
        let (page, offset) = page(e)
        
        guard page < pageCount, let sparsePage = sparse[page] else {
            print("Removed an element that didn't even have a page allocated: \(e)")
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
    
    @inlinable
    func forEach(_ body: (Element) -> Void) {
        dense.forEach(body)
    }
    
    func map<T>(_ body: (Element) -> T) -> [T] {
        dense.map(body)
    }
    
}
