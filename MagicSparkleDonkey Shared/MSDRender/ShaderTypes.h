//
//  ShaderTypes.h
//  MagicSparkleDonkey Shared
//
//  Created by Andrew Pouliot on 4/6/21.
//

//
//  Header containing types and enum constants shared between Metal shaders and Swift/ObjC source
//
#ifndef ShaderTypes_h
#define ShaderTypes_h

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NS_SWIFT_NAME(_name)
#define NSInteger metal::int32_t
#else
#import <Foundation/Foundation.h>
#endif

#include <simd/simd.h>

typedef NS_ENUM(NSInteger, MSDBufferIndex)
{
    MSDBufferIndexMeshPositions = 0,
    MSDBufferIndexMeshGenerics  = 1,
    MSDBufferIndexUniforms      = 2
} NS_SWIFT_NAME(BufferIndex);

typedef NS_ENUM(NSInteger, MSDVertexSemantic)
{
    MSDVertexSemanticPosition,
    MSDVertexSemanticNormal,
    MSDVertexSemanticTangent,
    MSDVertexSemanticColor,
    MSDVertexSemanticBoneIndices,
    MSDVertexSemanticBoneWeights,
    MSDVertexSemanticTexcoord0,
    MSDVertexSemanticTexcoord1,
    MSDVertexSemanticTexcoord2,
    MSDVertexSemanticTexcoord3,
    MSDVertexSemanticTexcoord4,
    MSDVertexSemanticTexcoord5,
    MSDVertexSemanticTexcoord6,
    MSDVertexSemanticTexcoord7
} NS_SWIFT_NAME(VertexSemantic);

typedef NS_ENUM(NSInteger, MSDTextureIndex)
{
    MSDTextureIndexColor    = 0,
} NS_SWIFT_NAME(TextureIndex);

typedef struct
{
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 modelViewMatrix;
} MSDUniforms NS_SWIFT_NAME(Uniforms);

#endif /* ShaderTypes_h */

