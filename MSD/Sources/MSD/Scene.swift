//
//  File.swift
//  
//
//  Created by Andrew Pouliot on 4/17/21.
//

public struct Scene {
    public init() {
        store.registry.register(component: TransformComponent.self)
        root = Entity.ID()
        store.set(id: root, component: TransformComponent(transform: .identity))
    }

    public var root: Entity.ID
    
    public var store = ComponentStore()
}


extension ComponentStore {
    func find<T: Component>(componentType: T.Type) -> ComponentStore.ComponentType? {
        registry.find(componentType: T.self)
    }
    
    func forEach<T: Component>(_ block: (Entity.ID, inout T) -> Void ) {
        let t = find(componentType: T.self)!
        guard let entry: ComponentCollection<T> = findStorageEntry(componentType: t.self)
        else { return }
        
        entry.idToIndex.forEach{ i in
            block(i.key, &entry.storage[i.value])
        }
    }

    func forEach<A: Component, B: Component>(_ block: (Entity.ID, inout A, inout B) -> Void ) {
        let ta = find(componentType: A.self)!
        let tb = find(componentType: B.self)!
        let ea: ComponentCollection<A> = findStorageEntry(componentType: ta.self)!
        let eb: ComponentCollection<B> = findStorageEntry(componentType: tb.self)!

        let all = zip(ea.idToIndex, eb.idToIndex)
        
        all.forEach{ (ia, ib) in
            assert(ia.key == ib.key)
            block(ia.key, &ea.storage[ia.value], &eb.storage[ib.value])
        }
    }

}

extension Scene {
    mutating func registerComponent<T: Component>(_ t: T.Type) {
        store.registry.register(component: t)
    }
    mutating func unregisterComponent<T: Component>(_ t: T.Type) {
        store.registry.unregister(component: t)
    }
}
