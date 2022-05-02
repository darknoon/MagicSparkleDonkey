//
//  Shaders.metal
//  MagicSparkleDonkey Shared
//
//  Created by Andrew Pouliot on 4/6/21.
//

// File for Metal kernel and shader functions

#include <metal_stdlib>
#include <simd/simd.h>

// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "ShaderTypes.h"

using namespace metal;

typedef struct
{
    float3 position [[attribute(MSDVertexSemanticPosition)]];
    float2 texCoord [[attribute(MSDVertexSemanticTexcoord0)]];
} Vertex;

typedef struct
{
    float4 position [[position]];
    float2 texCoord;
} ColorInOut;

vertex ColorInOut vertexShader(Vertex in [[stage_in]],
                               constant MSDUniforms& uniforms [[ buffer(MSDBufferIndexUniforms) ]],
                               constant MSDDraw& draw [[ buffer(MSDBufferIndexPerMeshData) ]]
                )
{
    ColorInOut out;

    float4 position = float4(in.position, 1.0);
    out.position = uniforms.projectionMatrix * draw.modelViewMatrix * position;
    out.texCoord = in.texCoord;

    return out;
}

fragment float4 fragmentShader(ColorInOut in [[stage_in]],
                               constant MSDUniforms& uniforms [[ buffer(MSDBufferIndexUniforms) ]],
                               texture2d<half> colorMap     [[ texture(MSDTextureIndexColor) ]])
{
    constexpr sampler colorSampler(mip_filter::linear,
                                   mag_filter::linear,
                                   min_filter::linear);

    half4 colorSample   = colorMap.sample(colorSampler, in.texCoord.xy);

    return float4(colorSample);
}
