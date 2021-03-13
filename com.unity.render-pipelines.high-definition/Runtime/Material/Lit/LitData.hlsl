//-------------------------------------------------------------------------------------
// Defines
//-------------------------------------------------------------------------------------

//-------------------------------------------------------------------------------------
// Fill SurfaceData/Builtin data function
//-------------------------------------------------------------------------------------
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Sampling/SampleUVMapping.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/MaterialUtilities.hlsl"
#ifndef SHADER_STAGE_RAY_TRACING
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Decal/DecalUtilities.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Lit/LitDecalData.hlsl"
#endif

//#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/SphericalCapPivot/SPTDistribution.hlsl"
//#define SPECULAR_OCCLUSION_USE_SPTD

// Struct that gather UVMapping info of all layers + common calculation
// This is use to abstract the mapping that can differ on layers
struct LayerTexCoord
{
    UVMapping base;
};

#ifndef LAYERED_LIT_SHADER

// Want to use only one sampler for normalmap/bentnormalmap either we use OS or TS. And either we have normal map or bent normal or both.
#if defined(_NORMALMAP)
#define SAMPLER_NORMALMAP_IDX sampler_NormalMap
#elif defined(_BENTNORMALMAP)
#define SAMPLER_NORMALMAP_IDX sampler_BentNormalMap
#endif

#define SAMPLER_DETAILMAP_IDX sampler_DetailMap
#define SAMPLER_MASKMAP_IDX sampler_MaskMap
#define SAMPLER_HEIGHTMAP_IDX sampler_HeightMap

#define SAMPLER_SUBSURFACE_MASK_MAP_IDX sampler_SubsurfaceMaskMap
#define SAMPLER_THICKNESSMAP_IDX sampler_ThicknessMap

// include LitDataIndividualLayer to define GetSurfaceData
#define LAYER_INDEX 0
#define ADD_IDX(Name) Name
#define ADD_ZERO_IDX(Name) Name
#ifdef _NORMALMAP
#define _NORMALMAP_IDX
#endif
#ifdef _NORMALMAP_TANGENT_SPACE
#define _NORMALMAP_TANGENT_SPACE_IDX
#endif
#ifdef _DETAIL_MAP
#define _DETAIL_MAP_IDX
#endif
#ifdef _SUBSURFACE_MASK_MAP
#define _SUBSURFACE_MASK_MAP_IDX
#endif
#ifdef _THICKNESSMAP
#define _THICKNESSMAP_IDX
#endif
#ifdef _MASKMAP
#define _MASKMAP_IDX
#endif
#ifdef _BENTNORMALMAP
#define _BENTNORMALMAP_IDX
#endif
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Lit/LitDataIndividualLayer.hlsl"

// This maybe call directly by tessellation (domain) shader, thus all part regarding surface gradient must be done
// in function with FragInputs input as parameters
// layerTexCoord must have been initialize to 0 outside of this function
void GetLayerTexCoord(float2 texCoord0, float2 texCoord1, float2 texCoord2, float2 texCoord3,
                      float3 positionRWS, float3 vertexNormalWS, inout LayerTexCoord layerTexCoord)
{
//    layerTexCoord.vertexNormalWS = vertexNormalWS;
    layerTexCoord.base.uv = texCoord0 * _BaseColorMap_ST.xy + _BaseColorMap_ST.zw;
}

// This is call only in this file
// layerTexCoord must have been initialize to 0 outside of this function
void GetLayerTexCoord(FragInputs input, inout LayerTexCoord layerTexCoord)
{
    layerTexCoord.base.uv = input.texCoord0.xy * _BaseColorMap_ST.xy + _BaseColorMap_ST.zw;
}

#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Lit/LitBuiltinData.hlsl"


void clipBlueNoise(half2 pos, half alpha)
{
    //alpha = clamp(alpha,0,1);

    uint taaFrameIndex = _TaaFrameInfo.z;
    float sampleJitterAngle = InterleavedGradientNoise(pos, taaFrameIndex);
    float2 sampleJitter = float2(sin(sampleJitterAngle), cos(sampleJitterAngle));

    clip(alpha-sampleJitterAngle);


    //pos += sampleJitterAngle.xx;

//float4x4 thresholdMatrix =
//{ 1.0 / 17.0,  9.0 / 17.0,  3.0 / 17.0, 11.0 / 17.0,
//  13.0 / 17.0,  5.0 / 17.0, 15.0 / 17.0,  7.0 / 17.0,
//   4.0 / 17.0, 12.0 / 17.0,  2.0 / 17.0, 10.0 / 17.0,
//  16.0 / 17.0,  8.0 / 17.0, 14.0 / 17.0,  6.0 / 17.0
//};
//float4x4 _RowAccess = { 1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1 };
//clip(alpha- thresholdMatrix[fmod(pos.x + sampleJitter.x, 4)] * _RowAccess[fmod(pos.y +sampleJitter.y, 4)]);
}

#if defined(_FADE_INFRONT_PLAYER)
    uniform float4 _PlayerPosition;
    uniform float4 _PlayerPositionVP;
#endif

float4 _ClippingMasks[4];

void GetSurfaceAndBuiltinData(FragInputs input, float3 V, inout PositionInputs posInput, out SurfaceData surfaceData, out BuiltinData builtinData RAY_TRACING_OPTIONAL_PARAMETERS)
{
#ifdef _DOUBLESIDED_ON
    float3 doubleSidedConstants = _DoubleSidedConstants.xyz;
#else
    float3 doubleSidedConstants = float3(1.0, 1.0, 1.0);
#endif

  //  ApplyDoubleSidedFlipOrMirror(input, doubleSidedConstants); // Apply double sided flip on the vertex normal

    LayerTexCoord layerTexCoord;
    ZERO_INITIALIZE(LayerTexCoord, layerTexCoord);
    GetLayerTexCoord(input, layerTexCoord);

    //layerTexCoord.base.uv =  input.texCoord0.xy;

    float depthOffset = 0;
#ifdef _DEPTHOFFSET_ON
    ApplyDepthOffsetPositionInput(V, depthOffset, GetViewForwardDir(), GetWorldToHClipMatrix(), posInput);
#endif

#if defined(_FADE_INFRONT_PLAYER)
//TODO PAT dithering feature? can be disabled for items and alike?
#if SHADERPASS != SHADERPASS_SHADOWS
     float2 dirTreePlayer  = normalize(_PlayerPosition.xz - GetAbsolutePositionWS(posInput.positionWS).xz);
      float2 dirPlayerCamera  = normalize(_PlayerPosition.xz - _WorldSpaceCameraPos.xz);
      float alphaAngle = 1- dot(float3(dirTreePlayer,0), float3(dirPlayerCamera,0));
      clipBlueNoise(posInput.positionSS.xy, alphaAngle*1.4);
#endif
#endif

#if defined(_ALPHATEST_ON)
    float alphaValue = SAMPLE_UVMAPPING_TEXTURE2D(_BaseColorMap, sampler_BaseColorMap, layerTexCoord.base).a * _BaseColor.a;
    float alphaCutoff = _AlphaCutoff;
    clip(alphaValue - alphaCutoff);

    //clipBlueNoise(posInput.positionSS.xy,0-alphaCutoff);
#endif



    // We perform the conversion to world of the normalTS outside of the GetSurfaceData
    // so it allow us to correctly deal with detail normal map and optimize the code for the layered shaders
    float3 normalTS;
    float3 bentNormalTS;
    float3 bentNormalWS;
    float alpha = GetSurfaceData(input, layerTexCoord, surfaceData, normalTS, bentNormalTS);
    GetNormalWS(input, normalTS, surfaceData.normalWS, doubleSidedConstants);

    surfaceData.geomNormalWS = input.tangentToWorld[2];


#if HAVE_DECALS
    if (_EnableDecals)
    {
        // Both uses and modifies 'surfaceData.normalWS'.
        DecalSurfaceData decalSurfaceData = GetDecalSurfaceData(posInput, input.tangentToWorld[2], alpha);
        ApplyDecalToSurfaceData(decalSurfaceData, input.tangentToWorld[2], surfaceData);
    }
#endif

    bentNormalWS = surfaceData.normalWS;

    // Caution: surfaceData must be fully initialize before calling GetBuiltinData
    GetBuiltinData(input, V, posInput, surfaceData, alpha, bentNormalWS, depthOffset, layerTexCoord.base, builtinData);

#if SHADERPASS != SHADERPASS_SHADOWS
 //   GENERIC_ALPHA_TEST(0,1);
    //add polygon support?
    //https://www.ronja-tutorials.com/2018/06/10/polygon-clipping.html

    float clipColor = 0;
    [unroll]
    for(int i2 = 0; i2 < 4; i2++)
    {
        float4 ClippingMask = _ClippingMasks[i2];
        float3 camerarelativPos = GetCameraRelativePositionWS(ClippingMask.xyz);
        float2 clipRectStart = camerarelativPos.xz - ClippingMask.w;
        float2 clipRectEnd = camerarelativPos.xz + ClippingMask.w;
        float2 inside = step(clipRectStart, posInput.positionWS.xz) * step(posInput.positionWS.xz, clipRectEnd);
        float isClipped = inside.x * inside.y;
        clipColor += isClipped;
       // if(clipColor >= 1)
       //     break;
    }
  //  surfaceData.baseColor *= clipColor;
  //  surfaceData.textureRampShading *= clipColor;
  //  surfaceData.reflection *= clipColor;
    #if defined(_FADE_BUILDING_ROOF)
        float3 camerarelativPos = GetCameraRelativePositionWS(_ClippingMasks[0]);
        float clipAlpha = 1-  step(camerarelativPos.y,posInput.positionWS.y) * clipColor;
        clipBlueNoise(posInput.positionSS.xy, clipAlpha);
    #endif
#endif


#if defined(_FADE_INFRONT_PLAYER)
//TransformWorldToObjectDir
//TransformObjectToWorldDir
//TransformWorldToView

          //Hide faces looking away from the _Player
//tangentToWorld

        float3 dx = ddx(posInput.positionWS);
	    float3 dy = ddy(posInput.positionWS);
	    float3 normal = normalize(cross(dy, dx));

        float normaldot = dot(V, normal);
     //   normaldot = dot(V, GetViewForwardDir());
       clipBlueNoise(posInput.positionSS.xy,  normaldot*3-1);

     //  clip(normaldot - 0.6);
#endif


#ifdef _ALPHATEST_ON
    // Used for sharpening by alpha to mask
    builtinData.alphaClipTreshold = alphaCutoff;
#endif

    RAY_TRACING_OPTIONAL_ALPHA_TEST_PASS
}

#endif // #ifndef LAYERED_LIT_SHADER
