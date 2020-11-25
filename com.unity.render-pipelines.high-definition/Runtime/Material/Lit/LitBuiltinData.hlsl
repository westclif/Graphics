#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/BuiltinUtilities.hlsl"

void GetBuiltinData(FragInputs input, float3 V, inout PositionInputs posInput, SurfaceData surfaceData, float alpha, float3 bentNormalWS, float depthOffset, float3 emissiveColor, out BuiltinData builtinData)
{
    // For back lighting we use the oposite vertex normal
    InitBuiltinData(posInput, alpha, bentNormalWS, -input.tangentToWorld[2], input.texCoord1, input.texCoord2, builtinData);

    builtinData.emissiveColor = emissiveColor;

#if (SHADERPASS == SHADERPASS_DISTORTION) || defined(DEBUG_DISPLAY)
    float3 distortion = SAMPLE_TEXTURE2D(_DistortionVectorMap, sampler_DistortionVectorMap, input.texCoord0.xy).rgb;
    distortion.rg = distortion.rg * _DistortionVectorScale.xx + _DistortionVectorBias.xx;
    builtinData.distortion = distortion.rg * _DistortionScale;
    builtinData.distortionBlur = clamp(distortion.b * _DistortionBlurScale, 0.0, 1.0) * (_DistortionBlurRemapMax - _DistortionBlurRemapMin) + _DistortionBlurRemapMin;
#endif

    builtinData.depthOffset = depthOffset;

    PostInitBuiltinData(V, posInput, surfaceData, builtinData);
}

float3 GetEmissiveColor(SurfaceData surfaceData)
{
    return _EmissiveColor;
}

#ifdef _EMISSIVE_COLOR_MAP
float3 GetEmissiveColor(SurfaceData surfaceData, UVMapping emissiveMapMapping)
{
    float3 emissiveColor = GetEmissiveColor(surfaceData);
    emissiveColor *= SAMPLE_UVMAPPING_TEXTURE2D(_EmissiveColorMap, sampler_EmissiveColorMap, emissiveMapMapping).rgb;
    return emissiveColor;
}
#endif // _EMISSIVE_COLOR_MAP

void GetBuiltinData(FragInputs input, float3 V, inout PositionInputs posInput, SurfaceData surfaceData, float alpha, float3 bentNormalWS, float depthOffset, out BuiltinData builtinData)
{
#ifdef _EMISSIVE_COLOR_MAP
    // Use layer0 of LayerTexCoord to retrieve emissive color mapping information
    LayerTexCoord layerTexCoord;
    ZERO_INITIALIZE(LayerTexCoord, layerTexCoord);
//    layerTexCoord.vertexNormalWS = input.tangentToWorld[2].xyz;
 //   layerTexCoord.triplanarWeights = ComputeTriplanarWeights(layerTexCoord.vertexNormalWS);
    int mappingType = UV_MAPPING_UVSET;

     layerTexCoord.base.uv = input.texCoord0.xy * _EmissiveColorMap_ST.xy + _EmissiveColorMap_ST.zw;

    UVMapping emissiveMapMapping = layerTexCoord.base;
    GetBuiltinData(input, V, posInput, surfaceData, alpha, bentNormalWS, depthOffset, GetEmissiveColor(surfaceData, emissiveMapMapping), builtinData);
#else
    GetBuiltinData(input, V, posInput, surfaceData, alpha, bentNormalWS, depthOffset, GetEmissiveColor(surfaceData), builtinData);
#endif
}

void GetBuiltinData(FragInputs input, float3 V, inout PositionInputs posInput, SurfaceData surfaceData, float alpha, float3 bentNormalWS, float depthOffset, UVMapping emissiveMapMapping, out BuiltinData builtinData)
{
#ifdef _EMISSIVE_MAPPING_BASE
    GetBuiltinData(input, V, posInput, surfaceData, alpha, bentNormalWS, depthOffset, GetEmissiveColor(surfaceData, emissiveMapMapping), builtinData);
#else
    GetBuiltinData(input, V, posInput, surfaceData, alpha, bentNormalWS, depthOffset, builtinData);
#endif
}
