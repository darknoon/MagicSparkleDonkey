//
//  File.swift
//  
//
//  Created by Andrew Pouliot on 5/23/21.
//

struct MeshResource {
    let id: Resource.ID
    let path: String
    
    struct Runtime<API: GPUAPI> : RuntimeResource {
        let id: Resource.ID
        let runtime: API.MeshRuntimeType
    }
}
