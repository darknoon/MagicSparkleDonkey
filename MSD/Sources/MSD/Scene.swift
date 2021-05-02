//
//  File.swift
//  
//
//  Created by Andrew Pouliot on 4/17/21.
//

public struct Scene {
    public init() {
        root = Entity.ID()
        store.set(id: root, component: TransformComponent(transform: .identity))
    }

    public var root: Entity.ID
    
    public var store = ComponentStore()
}


extension ComponentStore {
    
    func forEach<T: Component>(_ block: (Entity.ID, inout T) -> Void ) {
        guard let entry: ComponentCollection<T> = findStorageEntry(componentType: T.ID)
        else { return }
        
        entry.storage.forEach{ (index, entry) in
            // TODO: get a pointer here!
            var e = entry
            block(index, &e)
        }
    }

    func forEach<A: Component, B: Component>(_ block: (Entity.ID, inout A, inout B) -> Void ) {
        let ea: ComponentCollection<A> = findStorageEntry(componentType: A.ID)!
        let eb: ComponentCollection<B> = findStorageEntry(componentType: B.ID)!

        ea.storage.forEach{ (entity, a) in
            var a = a
            guard var b = eb[entity] else { return }
            block(entity, &a, &b)
            ea.storage[entity] = a
            eb.storage[entity] = b
//            assert(ia.key == ib.key)
//            block(ia.key, &ea.storage[ia.value], &eb.storage[ib.value])
        }
    }

}

