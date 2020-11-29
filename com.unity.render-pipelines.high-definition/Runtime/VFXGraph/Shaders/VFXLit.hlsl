// Upgrade NOTE: replaced 'defined at' with 'defined (at)'

#ifdef DEBUG_DISPLAY
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Debug/DebugDisplay.hlsl"
#endif
#ifndef SHADERPASS
#error SHADERPASS must be defined (at) this point
#endif

// Make VFX only sample probe volumes as SH0 for performance.
#define PROBE_VOLUMES_SAMPLING_MODE PROBEVOLUMESENCODINGMODES_SPHERICAL_HARMONICS_L0

#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Material.hlsl"

#if (SHADERPASS == SHADERPASS_FORWARD)
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/Lighting.hlsl"

    #define HAS_LIGHTLOOP

    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/LightLoop/LightLoopDef.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Lit/Lit.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/LightLoop/LightLoop.hlsl"

#else // (SHADERPASS == SHADERPASS_FORWARD)

    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Lit/Lit.hlsl"
#endif // (SHADERPASS == SHADERPASS_FORWARD)

#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/BuiltinUtilities.hlsl"

float3 VFXGetPositionRWS(VFX_VARYING_PS_INPUTS i)
{
    float3 posWS = (float3)0;
    #ifdef VFX_VARYING_POSWS
    posWS = i.VFX_VARYING_POSWS;
    #endif
    return VFXGetPositionRWS(posWS);
}

BuiltinData VFXGetBuiltinData(const VFX_VARYING_PS_INPUTS i,const PositionInputs posInputs, const SurfaceData surfaceData, const VFXUVData uvData, float opacity = 1.0f)
{
    BuiltinData builtinData = (BuiltinData)0;

    InitBuiltinData(posInputs, opacity, surfaceData.normalWS, -surfaceData.normalWS, (float4)0, (float4)0, builtinData); // We dont care about uvs are we dont sample lightmaps

    #if HDRP_USE_EMISSIVE
    builtinData.emissiveColor = float3(1,1,1);
    #if HDRP_USE_EMISSIVE_MAP
    float emissiveScale = 1.0f;
    #ifdef VFX_VARYING_EMISSIVESCALE
    emissiveScale = i.VFX_VARYING_EMISSIVESCALE;
    #endif
    builtinData.emissiveColor *= SampleTexture(VFX_SAMPLER(emissiveMap),uvData).rgb * emissiveScale;
    #endif
    #if defined(VFX_VARYING_EMISSIVE) && (HDRP_USE_EMISSIVE_COLOR || HDRP_USE_ADDITIONAL_EMISSIVE_COLOR)
    builtinData.emissiveColor *= i.VFX_VARYING_EMISSIVE;
    #endif
	#ifdef VFX_VARYING_EXPOSUREWEIGHT
	builtinData.emissiveColor *= lerp(GetInverseCurrentExposureMultiplier(),1.0f,i.VFX_VARYING_EXPOSUREWEIGHT);
	#endif
    #endif
    builtinData.emissiveColor *= opacity;

    PostInitBuiltinData(GetWorldSpaceNormalizeViewDir(posInputs.positionWS),posInputs,surfaceData, builtinData);



    return builtinData;
}


#ifndef VFX_SHADERGRAPH

SurfaceData VFXGetSurfaceData(const VFX_VARYING_PS_INPUTS i, float3 normalWS,const VFXUVData uvData, uint diffusionProfileHash, out float opacity)
{
    SurfaceData surfaceData = (SurfaceData)0;

    float4 color = float4(1,1,1,1);
    #if HDRP_USE_BASE_COLOR
    color *= VFXGetParticleColor(i);
    #elif HDRP_USE_ADDITIONAL_BASE_COLOR
    #if defined(VFX_VARYING_COLOR)
    color.xyz *= i.VFX_VARYING_COLOR;
    #endif
    #if defined(VFX_VARYING_ALPHA)
    color.a *= i.VFX_VARYING_ALPHA;
    #endif
    #endif
    #if HDRP_USE_BASE_COLOR_MAP
    float4 colorMap = SampleTexture(VFX_SAMPLER(baseColorMap),uvData);
    #if HDRP_USE_BASE_COLOR_MAP_COLOR
    color.xyz *= colorMap.xyz;
    #endif
    #if HDRP_USE_BASE_COLOR_MAP_ALPHA
    color.a *= colorMap.a;
    #endif
    #endif
    color.a *= VFXGetSoftParticleFade(i);
    VFXClipFragmentColor(color.a,i);
    surfaceData.baseColor = saturate(color.rgb);

    #if IS_OPAQUE_PARTICLE
    opacity = 1.0f;
    #else
    opacity = saturate(color.a);
    #endif

    surfaceData.normalWS = normalWS;
    #ifdef VFX_VARYING_SMOOTHNESS
   // surfaceData.perceptualSmoothness = i.VFX_VARYING_SMOOTHNESS;
    #endif
   // surfaceData.specularOcclusion = 1.0f;
    surfaceData.ambientOcclusion = 1.0f;

    #if HDRP_USE_MASK_MAP
    float4 mask = SampleTexture(VFX_SAMPLER(maskMap),uvData);
    surfaceData.metallic *= mask.r;
    surfaceData.ambientOcclusion *= mask.g;
    surfaceData.perceptualSmoothness *= mask.a;
    #endif

    surfaceData.textureRampShading = 3;
    surfaceData.textureRampSpecular = 3;
    surfaceData.textureRampRim = 0;

    return surfaceData;
}


#endif
