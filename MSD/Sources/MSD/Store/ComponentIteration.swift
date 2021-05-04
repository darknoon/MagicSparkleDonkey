//
//  File.swift
//  
//
//  Created by Andrew Pouliot on 5/2/21.
//

import Foundation

extension ComponentStore {
    
    // <mutable A>
    func forEach<T: Component>(_ block: (Entity.ID, inout T) -> Void ) {
        guard let entry: ComponentCollection<T> = findStorageEntry(componentType: T.ID)
        else { return }
        
        entry.storage.forEach{ (index, entry: inout T) in
            block(index, &entry)
        }
    }

    // <mutable A, mutable B>
    func forEach<A: Component, B: Component>(_ block: (Entity.ID, inout A, inout B) -> Void ) {
        guard
            let ca: ComponentCollection<A> = findStorageEntry(componentType: A.ID),
            let cb: ComponentCollection<B> = findStorageEntry(componentType: B.ID)
            else { return }
        

        ca.storage.forEach{ (entity, a: inout A) in
            // Establish a second variable looked up on cb
            guard var b = cb[entity] else { return }
            block(entity, &a, &b)
            // Write back b
            cb.storage[entity] = b
        }
    }
    
    // <mutable A, B>
    func forEach<A: Component, B: Component>(_ block: (Entity.ID, inout A, B) -> Void ) {
        guard
            let ca: ComponentCollection<A> = findStorageEntry(componentType: A.ID),
            let cb: ComponentCollection<B> = findStorageEntry(componentType: B.ID)
            else { return }
        
        ca.storage.forEach{ (entity, a: inout A) in
            guard let b = cb[entity] else { return }
            block(entity, &a, b)
        }
    }

}

