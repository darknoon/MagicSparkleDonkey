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
        
        entry.idToIndex.forEach{ i in
            block(i.key, &entry.storage[i.value])
        }
    }

    func forEach<A: Component, B: Component>(_ block: (Entity.ID, inout A, inout B) -> Void ) {
        let ea: ComponentCollection<A> = findStorageEntry(componentType: A.ID)!
        let eb: ComponentCollection<B> = findStorageEntry(componentType: B.ID)!

        let all = zip(ea.idToIndex, eb.idToIndex)
        
        all.forEach{ (ia, ib) in
            assert(ia.key == ib.key)
            block(ia.key, &ea.storage[ia.value], &eb.storage[ib.value])
        }
    }

}

