//-----------------------------------------------------------------------------
// Includes
//-----------------------------------------------------------------------------

// SurfaceData is define in Lit.cs which generate Lit.cs.hlsl
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Lit/Lit.cs.hlsl"
// Those define allow to include desired SSS/Transmission functions
#define MATERIAL_INCLUDE_SUBSURFACESCATTERING
#define MATERIAL_INCLUDE_TRANSMISSION
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/BuiltinGIUtilities.hlsl" //For IsUninitializedGI
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/SubsurfaceScattering/SubsurfaceScattering.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/NormalBuffer.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/VolumeRendering.hlsl"

//-----------------------------------------------------------------------------
// Configuration
//-----------------------------------------------------------------------------

#define USE_DIFFUSE_LAMBERT_BRDF

// Enable reference mode for IBL and area lights
// Both reference define below can be define only if LightLoop is present, else we get a compile error
#ifdef HAS_LIGHTLOOP
// #define LIT_DISPLAY_REFERENCE_AREA
// #define LIT_DISPLAY_REFERENCE_IBL
#endif

//-----------------------------------------------------------------------------
// Texture and constant buffer declaration
//-----------------------------------------------------------------------------

// GBuffer texture declaration
TEXTURE2D_X(_GBufferTexture0);
TEXTURE2D_X(_GBufferTexture1);
TEXTURE2D_X(_GBufferTexture2);
TEXTURE2D_X(_GBufferTexture3); // Bake lighting and/or emissive
TEXTURE2D_X(_GBufferTexture4); // VTFeedbakc or Light layer or shadow mask
TEXTURE2D_X(_GBufferTexture5); // Light layer or shadow mask
TEXTURE2D_X(_GBufferTexture6); // shadow mask


TEXTURE2D_X(_LightLayersTexture);
#ifdef SHADOWS_SHADOWMASK
TEXTURE2D_X(_ShadowMaskTexture); // Alias for shadow mask, so we don't need to know which gbuffer is used for shadow mask
#endif

#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/LTCAreaLight/LTCAreaLight.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/PreIntegratedFGD/PreIntegratedFGD.hlsl"

//-----------------------------------------------------------------------------
// Definition
//-----------------------------------------------------------------------------

#ifdef UNITY_VIRTUAL_TEXTURING
#define OUT_GBUFFER_VTFEEDBACK outGBuffer4
#define OUT_GBUFFER_OPTIONAL_SLOT_1 outGBuffer5
#define OUT_GBUFFER_OPTIONAL_SLOT_2 outGBuffer6
#else
#define OUT_GBUFFER_OPTIONAL_SLOT_1 outGBuffer4
#define OUT_GBUFFER_OPTIONAL_SLOT_2 outGBuffer5
#endif

#if defined(LIGHT_LAYERS) && defined(SHADOWS_SHADOWMASK)
#define OUT_GBUFFER_LIGHT_LAYERS OUT_GBUFFER_OPTIONAL_SLOT_1
#define OUT_GBUFFER_SHADOWMASK OUT_GBUFFER_OPTIONAL_SLOT_2
#elif defined(LIGHT_LAYERS)
#define OUT_GBUFFER_LIGHT_LAYERS OUT_GBUFFER_OPTIONAL_SLOT_1
#elif defined(SHADOWS_SHADOWMASK)
#define OUT_GBUFFER_SHADOWMASK OUT_GBUFFER_OPTIONAL_SLOT_1
#endif

#define HAS_REFRACTION (defined(_REFRACTION_PLANE) || defined(_REFRACTION_SPHERE) || defined(_REFRACTION_THIN))

// It is safe to include this file after the G-Buffer macros above.
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/MaterialGBufferMacros.hlsl"

//-----------------------------------------------------------------------------
// Light and material classification for the deferred rendering path
// Configure what kind of combination is supported
//-----------------------------------------------------------------------------

// Lighting architecture and material are suppose to be decoupled files.
// However as we use material classification it is hard to be fully separated
// the dependecy is define in this include where there is shared define for material and lighting in case of deferred material.
// If a user do a lighting architecture without material classification, this can be remove
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/LightLoop/LightLoop.cs.hlsl"

// Currently disable SSR until critical editor fix is available
#undef LIGHTFEATUREFLAGS_SSREFLECTION
#define LIGHTFEATUREFLAGS_SSREFLECTION 0

// Combination need to be define in increasing "comlexity" order as define by FeatureFlagsToTileVariant
static const uint kFeatureVariantFlags[NUM_FEATURE_VARIANTS] =
{
    // Precomputed illumination (no dynamic lights) with standard
    /*  0 */ LIGHTFEATUREFLAGS_SKY | LIGHTFEATUREFLAGS_ENV | LIGHTFEATUREFLAGS_SSREFLECTION | MATERIALFEATUREFLAGS_LIT_STANDARD,
    // Precomputed illumination (no dynamic lights) with standard, SSS and transmission
    /*  1 */ LIGHTFEATUREFLAGS_SKY | LIGHTFEATUREFLAGS_ENV | LIGHTFEATUREFLAGS_SSREFLECTION | MATERIALFEATUREFLAGS_LIT_SUBSURFACE_SCATTERING | MATERIALFEATUREFLAGS_LIT_TRANSMISSION | MATERIALFEATUREFLAGS_LIT_STANDARD,
    // Precomputed illumination (no dynamic lights) for all material types
    /*  2 */ LIGHTFEATUREFLAGS_SKY | LIGHTFEATUREFLAGS_ENV | LIGHTFEATUREFLAGS_PROBE_VOLUME | LIGHTFEATUREFLAGS_SSREFLECTION | MATERIAL_FEATURE_MASK_FLAGS,

    /*  3 */ LIGHTFEATUREFLAGS_SKY | LIGHTFEATUREFLAGS_DIRECTIONAL | LIGHTFEATUREFLAGS_PUNCTUAL | MATERIALFEATUREFLAGS_LIT_STANDARD,
    /*  4 */ LIGHTFEATUREFLAGS_SKY | LIGHTFEATUREFLAGS_DIRECTIONAL | LIGHTFEATUREFLAGS_AREA | MATERIALFEATUREFLAGS_LIT_STANDARD,
    /*  5 */ LIGHTFEATUREFLAGS_SKY | LIGHTFEATUREFLAGS_DIRECTIONAL | LIGHTFEATUREFLAGS_ENV | LIGHTFEATUREFLAGS_PROBE_VOLUME | LIGHTFEATUREFLAGS_SSREFLECTION | MATERIALFEATUREFLAGS_LIT_STANDARD,
    /*  6 */ LIGHTFEATUREFLAGS_SKY | LIGHTFEATUREFLAGS_DIRECTIONAL | LIGHTFEATUREFLAGS_PUNCTUAL | LIGHTFEATUREFLAGS_ENV | LIGHTFEATUREFLAGS_PROBE_VOLUME | LIGHTFEATUREFLAGS_SSREFLECTION | MATERIALFEATUREFLAGS_LIT_STANDARD,
    /*  7 */ LIGHT_FEATURE_MASK_FLAGS_OPAQUE | MATERIALFEATUREFLAGS_LIT_STANDARD,

    // Standard with SSS and Transmission
    /*  8 */ LIGHTFEATUREFLAGS_SKY | LIGHTFEATUREFLAGS_DIRECTIONAL | LIGHTFEATUREFLAGS_PUNCTUAL | MATERIALFEATUREFLAGS_LIT_SUBSURFACE_SCATTERING | MATERIALFEATUREFLAGS_LIT_TRANSMISSION | MATERIALFEATUREFLAGS_LIT_STANDARD,
    /*  9 */ LIGHTFEATUREFLAGS_SKY | LIGHTFEATUREFLAGS_DIRECTIONAL | LIGHTFEATUREFLAGS_AREA | MATERIALFEATUREFLAGS_LIT_SUBSURFACE_SCATTERING | MATERIALFEATUREFLAGS_LIT_TRANSMISSION | MATERIALFEATUREFLAGS_LIT_STANDARD,
    /* 10 */ LIGHTFEATUREFLAGS_SKY | LIGHTFEATUREFLAGS_DIRECTIONAL | LIGHTFEATUREFLAGS_ENV | LIGHTFEATUREFLAGS_PROBE_VOLUME | LIGHTFEATUREFLAGS_SSREFLECTION | MATERIALFEATUREFLAGS_LIT_SUBSURFACE_SCATTERING | MATERIALFEATUREFLAGS_LIT_TRANSMISSION | MATERIALFEATUREFLAGS_LIT_STANDARD,
    /* 11 */ LIGHTFEATUREFLAGS_SKY | LIGHTFEATUREFLAGS_DIRECTIONAL | LIGHTFEATUREFLAGS_PUNCTUAL | LIGHTFEATUREFLAGS_ENV | LIGHTFEATUREFLAGS_PROBE_VOLUME | LIGHTFEATUREFLAGS_SSREFLECTION | MATERIALFEATUREFLAGS_LIT_SUBSURFACE_SCATTERING | MATERIALFEATUREFLAGS_LIT_TRANSMISSION | MATERIALFEATUREFLAGS_LIT_STANDARD,
    /* 12 */ LIGHT_FEATURE_MASK_FLAGS_OPAQUE | MATERIALFEATUREFLAGS_LIT_SUBSURFACE_SCATTERING | MATERIALFEATUREFLAGS_LIT_TRANSMISSION | MATERIALFEATUREFLAGS_LIT_STANDARD,

    // Anisotropy
    /* 13 */ LIGHTFEATUREFLAGS_SKY | LIGHTFEATUREFLAGS_DIRECTIONAL | LIGHTFEATUREFLAGS_PUNCTUAL | MATERIALFEATUREFLAGS_LIT_ANISOTROPY | MATERIALFEATUREFLAGS_LIT_STANDARD,
    /* 14 */ LIGHTFEATUREFLAGS_SKY | LIGHTFEATUREFLAGS_DIRECTIONAL | LIGHTFEATUREFLAGS_AREA | MATERIALFEATUREFLAGS_LIT_ANISOTROPY | MATERIALFEATUREFLAGS_LIT_STANDARD,
    /* 15 */ LIGHTFEATUREFLAGS_SKY | LIGHTFEATUREFLAGS_DIRECTIONAL | LIGHTFEATUREFLAGS_ENV | LIGHTFEATUREFLAGS_PROBE_VOLUME | LIGHTFEATUREFLAGS_SSREFLECTION | MATERIALFEATUREFLAGS_LIT_ANISOTROPY | MATERIALFEATUREFLAGS_LIT_STANDARD,
    /* 16 */ LIGHTFEATUREFLAGS_SKY | LIGHTFEATUREFLAGS_DIRECTIONAL | LIGHTFEATUREFLAGS_PUNCTUAL | LIGHTFEATUREFLAGS_ENV | LIGHTFEATUREFLAGS_PROBE_VOLUME | LIGHTFEATUREFLAGS_SSREFLECTION | MATERIALFEATUREFLAGS_LIT_ANISOTROPY | MATERIALFEATUREFLAGS_LIT_STANDARD,
    /* 17 */ LIGHT_FEATURE_MASK_FLAGS_OPAQUE | MATERIALFEATUREFLAGS_LIT_ANISOTROPY | MATERIALFEATUREFLAGS_LIT_STANDARD,

    // Standard with clear coat
    /* 18 */ LIGHTFEATUREFLAGS_SKY | LIGHTFEATUREFLAGS_DIRECTIONAL | LIGHTFEATUREFLAGS_PUNCTUAL | MATERIALFEATUREFLAGS_LIT_CLEAR_COAT | MATERIALFEATUREFLAGS_LIT_STANDARD,
    /* 19 */ LIGHTFEATUREFLAGS_SKY | LIGHTFEATUREFLAGS_DIRECTIONAL | LIGHTFEATUREFLAGS_AREA | MATERIALFEATUREFLAGS_LIT_CLEAR_COAT | MATERIALFEATUREFLAGS_LIT_STANDARD,
    /* 20 */ LIGHTFEATUREFLAGS_SKY | LIGHTFEATUREFLAGS_DIRECTIONAL | LIGHTFEATUREFLAGS_ENV | LIGHTFEATUREFLAGS_PROBE_VOLUME | LIGHTFEATUREFLAGS_SSREFLECTION | MATERIALFEATUREFLAGS_LIT_CLEAR_COAT | MATERIALFEATUREFLAGS_LIT_STANDARD,
    /* 21 */ LIGHTFEATUREFLAGS_SKY | LIGHTFEATUREFLAGS_DIRECTIONAL | LIGHTFEATUREFLAGS_PUNCTUAL | LIGHTFEATUREFLAGS_ENV | LIGHTFEATUREFLAGS_PROBE_VOLUME | LIGHTFEATUREFLAGS_SSREFLECTION | MATERIALFEATUREFLAGS_LIT_CLEAR_COAT | MATERIALFEATUREFLAGS_LIT_STANDARD,
    /* 22 */ LIGHT_FEATURE_MASK_FLAGS_OPAQUE | MATERIALFEATUREFLAGS_LIT_CLEAR_COAT | MATERIALFEATUREFLAGS_LIT_STANDARD,

    // Standard with Iridescence
    /* 23 */ LIGHTFEATUREFLAGS_SKY | LIGHTFEATUREFLAGS_DIRECTIONAL | LIGHTFEATUREFLAGS_PUNCTUAL | MATERIALFEATUREFLAGS_LIT_IRIDESCENCE | MATERIALFEATUREFLAGS_LIT_STANDARD,
    /* 24 */ LIGHTFEATUREFLAGS_SKY | LIGHTFEATUREFLAGS_DIRECTIONAL | LIGHTFEATUREFLAGS_AREA | MATERIALFEATUREFLAGS_LIT_IRIDESCENCE | MATERIALFEATUREFLAGS_LIT_STANDARD,
    /* 25 */ LIGHTFEATUREFLAGS_SKY | LIGHTFEATUREFLAGS_DIRECTIONAL | LIGHTFEATUREFLAGS_ENV | LIGHTFEATUREFLAGS_PROBE_VOLUME | LIGHTFEATUREFLAGS_SSREFLECTION | MATERIALFEATUREFLAGS_LIT_IRIDESCENCE | MATERIALFEATUREFLAGS_LIT_STANDARD,
    /* 26 */ LIGHTFEATUREFLAGS_SKY | LIGHTFEATUREFLAGS_DIRECTIONAL | LIGHTFEATUREFLAGS_PUNCTUAL | LIGHTFEATUREFLAGS_ENV | LIGHTFEATUREFLAGS_PROBE_VOLUME | LIGHTFEATUREFLAGS_SSREFLECTION | MATERIALFEATUREFLAGS_LIT_IRIDESCENCE | MATERIALFEATUREFLAGS_LIT_STANDARD,
    /* 27 */ LIGHT_FEATURE_MASK_FLAGS_OPAQUE | MATERIALFEATUREFLAGS_LIT_IRIDESCENCE | MATERIALFEATUREFLAGS_LIT_STANDARD,

    /* 28 */ LIGHT_FEATURE_MASK_FLAGS_OPAQUE | MATERIAL_FEATURE_MASK_FLAGS, // Catch all case with MATERIAL_FEATURE_MASK_FLAGS is needed in case we disable material classification
};

uint FeatureFlagsToTileVariant(uint featureFlags)
{
    for (int i = 0; i < NUM_FEATURE_VARIANTS; i++)
    {
        if ((featureFlags & kFeatureVariantFlags[i]) == featureFlags)
            return i;
    }
    return NUM_FEATURE_VARIANTS - 1;
}

#ifdef USE_INDIRECT

uint TileVariantToFeatureFlags(uint variant, uint tileIndex)
{
    if (variant == NUM_FEATURE_VARIANTS - 1)
    {
        // We don't have any compile-time feature information.
        // Therefore, we load the feature classification data at runtime to avoid
        // entering every single branch based on feature flags.
        return g_TileFeatureFlags[tileIndex];
    }
    else
    {
        // Return the compile-time feature flags.
        return kFeatureVariantFlags[variant];
    }
}

#endif // USE_INDIRECT

//-----------------------------------------------------------------------------
// Helper functions/variable specific to this material
//-----------------------------------------------------------------------------

// This function return diffuse color or an equivalent color (in case of metal). Alpha channel is 0 is dieletric or 1 if metal, or in between value if it is in between
// This is use for MatCapView and reflection probe pass
// replace is 0.0 if we want diffuse color or 1.0 if we want default color
float4 GetDiffuseOrDefaultColor(BSDFData bsdfData, float replace)
{
    return float4(bsdfData.diffuseColor, 0);
}

float3 GetNormalForShadowBias(BSDFData bsdfData)
{
    // In forward we can used geometric normal for shadow bias which improve quality
#if (SHADERPASS == SHADERPASS_FORWARD)
    return bsdfData.geomNormalWS;
#else
    return bsdfData.normalWS;
#endif
}

float GetAmbientOcclusionForMicroShadowing(BSDFData bsdfData)
{
    float sourceAO;
#if (SHADERPASS == SHADERPASS_DEFERRED_LIGHTING)
    // Note: In deferred pass we don't have space in GBuffer to store ambientOcclusion so we use specularOcclusion instead
    sourceAO = bsdfData.specularOcclusion;
#else
    sourceAO = bsdfData.ambientOcclusion;
#endif
    return sourceAO;
}

#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/LightDefinition.cs.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/Reflection/VolumeProjection.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/ScreenSpaceLighting/ScreenSpaceTracing.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/ScreenSpaceLighting/ScreenSpaceLighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Refraction.hlsl"

#if HAS_REFRACTION
    // Note that this option is referred as "Box" in the UI, we are keeping _REFRACTION_PLANE as shader define to avoid complication with already created materials.
    #if defined(_REFRACTION_PLANE)
    #define REFRACTION_MODEL(V, posInputs, bsdfData) RefractionModelBox(V, posInputs.positionWS, bsdfData.normalWS, bsdfData.ior, bsdfData.thickness)
    #elif defined(_REFRACTION_SPHERE)
    #define REFRACTION_MODEL(V, posInputs, bsdfData) RefractionModelSphere(V, posInputs.positionWS, bsdfData.normalWS, bsdfData.ior, bsdfData.thickness)
    #elif defined(_REFRACTION_THIN)
    #define REFRACTION_THIN_DISTANCE 0.005
    #define REFRACTION_MODEL(V, posInputs, bsdfData) RefractionModelBox(V, posInputs.positionWS, bsdfData.normalWS, bsdfData.ior, bsdfData.thickness)
    #endif
#endif

void FillMaterialTransparencyData(float3 baseColor, float metallic, float ior, float3 transmittanceColor, float atDistance, float thickness, float transmittanceMask, inout BSDFData bsdfData)
{
    // Uses thickness from SSS's property set
    bsdfData.ior = ior;

    // IOR define the fresnel0 value, so update it also for consistency (and even if not physical we still need to take into account any metal mask)
    bsdfData.fresnel0 = lerp(IorToFresnel0(ior).xxx, baseColor, metallic);

    bsdfData.absorptionCoefficient = TransmittanceColorAtDistanceToAbsorption(transmittanceColor, atDistance);
    bsdfData.transmittanceMask = transmittanceMask;
    bsdfData.thickness = max(thickness, 0.0001);
}

// This function is use to help with debugging and must be implemented by any lit material
// Implementer must take into account what are the current override component and
// adjust SurfaceData properties accordingdly
void ApplyDebugToSurfaceData(float3x3 tangentToWorld, inout SurfaceData surfaceData)
{
#ifdef DEBUG_DISPLAY
    // Override value if requested by user
    // this can be use also in case of debug lighting mode like diffuse only
    bool overrideAlbedo = _DebugLightingAlbedo.x != 0.0;
    bool overrideSmoothness = _DebugLightingSmoothness.x != 0.0;
    bool overrideNormal = _DebugLightingNormal.x != 0.0;
    bool overrideAO = _DebugLightingAmbientOcclusion.x != 0.0;

    if (overrideAlbedo)
    {
        float3 overrideAlbedoValue = _DebugLightingAlbedo.yzw;
        surfaceData.baseColor = overrideAlbedoValue;
    }

    if (overrideSmoothness)
    {
        float overrideSmoothnessValue = _DebugLightingSmoothness.y;
        surfaceData.perceptualSmoothness = overrideSmoothnessValue;
    }

    if (overrideNormal)
    {
        surfaceData.normalWS = tangentToWorld[2];
    }

    if (overrideAO)
    {
        float overrideAOValue = _DebugLightingAmbientOcclusion.y;
        surfaceData.ambientOcclusion = overrideAOValue;
    }

    // There is no metallic with SSS and specular color mode
    float metallic = HasFlag(surfaceData.materialFeatures, MATERIALFEATUREFLAGS_LIT_SPECULAR_COLOR | MATERIALFEATUREFLAGS_LIT_SUBSURFACE_SCATTERING | MATERIALFEATUREFLAGS_LIT_TRANSMISSION) ? 0.0 : surfaceData.metallic;

    float3 diffuseColor = ComputeDiffuseColor(surfaceData.baseColor, metallic);
    bool specularWorkflow = HasFlag(surfaceData.materialFeatures, MATERIALFEATUREFLAGS_LIT_SPECULAR_COLOR);
    float3 specularColor =  specularWorkflow ? surfaceData.specularColor : ComputeFresnel0(surfaceData.baseColor, surfaceData.metallic, DEFAULT_SPECULAR_VALUE);

    if (_DebugFullScreenMode == FULLSCREENDEBUGMODE_VALIDATE_DIFFUSE_COLOR)
    {
        surfaceData.baseColor = pbrDiffuseColorValidate(diffuseColor, specularColor, metallic > 0.0, !specularWorkflow).xyz;
    }
    else if (_DebugFullScreenMode == FULLSCREENDEBUGMODE_VALIDATE_SPECULAR_COLOR)
    {
        surfaceData.baseColor = pbrSpecularColorValidate(diffuseColor, specularColor, metallic > 0.0, !specularWorkflow).xyz;
    }

#endif
}

// This function is similar to ApplyDebugToSurfaceData but for BSDFData
void ApplyDebugToBSDFData(inout BSDFData bsdfData)
{
#ifdef DEBUG_DISPLAY
    // Override value if requested by user
    // this can be use also in case of debug lighting mode like specular only
    bool overrideSpecularColor = _DebugLightingSpecularColor.x != 0.0;

    if (overrideSpecularColor)
    {
        float3 overrideSpecularColor = _DebugLightingSpecularColor.yzw;
        bsdfData.fresnel0 = overrideSpecularColor;
    }
#endif
}

NormalData ConvertSurfaceDataToNormalData(SurfaceData surfaceData)
{
    NormalData normalData;
    normalData.normalWS = surfaceData.normalWS;
    normalData.perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(surfaceData.perceptualSmoothness);
    return normalData;
}

void UpdateSurfaceDataFromNormalData(uint2 positionSS, inout BSDFData bsdfData)
{
    NormalData normalData;

    DecodeFromNormalBuffer(positionSS, normalData);

    bsdfData.normalWS = normalData.normalWS;
    bsdfData.perceptualRoughness = normalData.perceptualRoughness;
}

//-----------------------------------------------------------------------------
// conversion function for forward
//-----------------------------------------------------------------------------

BSDFData ConvertSurfaceDataToBSDFData(uint2 positionSS, SurfaceData surfaceData)
{
    BSDFData bsdfData;
    ZERO_INITIALIZE(BSDFData, bsdfData);

    // IMPORTANT: In case of foward or gbuffer pass all enable flags are statically know at compile time, so the compiler can do compile time optimization
    bsdfData.materialFeatures    = surfaceData.materialFeatures;

    // Standard material
    bsdfData.ambientOcclusion    = surfaceData.ambientOcclusion;
    bsdfData.specularOcclusion   = surfaceData.specularOcclusion;
    bsdfData.normalWS            = surfaceData.normalWS;
    bsdfData.geomNormalWS        = surfaceData.geomNormalWS;
    bsdfData.perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(surfaceData.perceptualSmoothness);

    bsdfData.diffuseColor = surfaceData.baseColor;
    bsdfData.fresnel0     = 0;

    // Note: we have ZERO_INITIALIZE the struct so bsdfData.anisotropy == 0.0
    // Note: DIFFUSION_PROFILE_NEUTRAL_ID is 0

    // In forward everything is statically know and we could theorically cumulate all the material features. So the code reflect it.
    // However in practice we keep parity between deferred and forward, so we should constrain the various features.
    // The UI is in charge of setuping the constrain, not the code. So if users is forward only and want unleash power, it is easy to unleash by some UI change

    bsdfData.diffusionProfileIndex = FindDiffusionProfileIndex(surfaceData.diffusionProfileHash);

    bsdfData.roughnessT = 0;
    bsdfData.roughnessB = 0;

#if HAS_REFRACTION
    // Note: Reuse thickness of transmission's property set
    FillMaterialTransparencyData(surfaceData.baseColor, surfaceData.metallic, surfaceData.ior, surfaceData.transmittanceColor,
    #ifdef _REFRACTION_THIN
                                 // We set both atDistance and thickness to the same, small value
                                 REFRACTION_THIN_DISTANCE, REFRACTION_THIN_DISTANCE,
    #else
                                 surfaceData.atDistance, surfaceData.thickness,
    #endif
                                 surfaceData.transmittanceMask, bsdfData);
#endif

    ApplyDebugToBSDFData(bsdfData);

    return bsdfData;
}

//-----------------------------------------------------------------------------
// conversion function for deferred
//-----------------------------------------------------------------------------

// GBuffer layout.
// GBuffer2 and GBuffer0.a interpretation depends on material feature enabled

//GBuffer0      RGBA8 sRGB  Gbuffer0 encode baseColor and so is sRGB to save precision. Alpha is not affected.
//GBuffer1      RGBA8
//GBuffer2      RGBA8
//GBuffer3      RGBA8

//FeatureName   Standard
//GBuffer0      baseColor.r,    baseColor.g,    baseColor.b,    specularOcclusion
//GBuffer1      normal.xy (1212),   perceptualRoughness
//GBuffer2      f0.r,   f0.g,   f0.b,   featureID(3) / coatMask(5)
//GBuffer3      bakedDiffuseLighting.rgb

// Note:
// For standard we have chose to always encode fresnel0. Even when we use metal/baseColor parametrization. This avoid
// compiler optimization problem that was using VGPR to deal with the various combination of metal non metal.

// Encode SurfaceData (BSDF parameters) into GBuffer
// Must be in sync with RT declared in HDRenderPipeline.cs ::Rebuild
void EncodeIntoGBuffer( SurfaceData surfaceData
                        , BuiltinData builtinData
                        , uint2 positionSS
                        , out GBufferType0 outGBuffer0
                        , out GBufferType1 outGBuffer1
                        , out GBufferType2 outGBuffer2
                        , out GBufferType3 outGBuffer3
#if GBUFFERMATERIAL_COUNT > 4
                        , out GBufferType4 outGBuffer4
#endif
#if GBUFFERMATERIAL_COUNT > 5
                        , out GBufferType5 outGBuffer5
#endif
#if GBUFFERMATERIAL_COUNT > 6
                        , out GBufferType5 outGBuffer6
#endif
                        )
{
    // RT0 - 8:8:8:8 sRGB
    // Warning: the contents are later overwritten for Standard and SSS!
    outGBuffer0 = float4(surfaceData.baseColor, surfaceData.specularOcclusion);

    // This encode normalWS and PerceptualSmoothness into GBuffer1
    EncodeIntoNormalBuffer(ConvertSurfaceDataToNormalData(surfaceData), outGBuffer1);

    // RT2 - 8:8:8:8
    // In the case of standard or specular color we always convert to specular color parametrization before encoding,
    // so decoding is more efficient (it allow better optimization for the compiler and save VGPR)
    // This mean that on the decode side, MATERIALFEATUREFLAGS_LIT_SPECULAR_COLOR doesn't exist anymore
    uint materialFeatureId = GBUFFER_LIT_STANDARD;

    float3 diffuseColor = surfaceData.baseColor;
    outGBuffer0.rgb = diffuseColor;               // sRGB RT
    outGBuffer2.rgb = 0; // TODO: optimize     // outGBuffer2 is not sRGB, so use a fast encode/decode sRGB to keep precision

    // Ensure that surfaceData.coatMask is 0 if the feature is not enabled
    // Note: no need to store MATERIALFEATUREFLAGS_LIT_STANDARD, always present
    outGBuffer2.a  = PackFloatInt8bit(0.0, materialFeatureId, 8);

#ifdef DEBUG_DISPLAY
    if (_DebugLightingMode >= DEBUGLIGHTINGMODE_DIFFUSE_LIGHTING && _DebugLightingMode <= DEBUGLIGHTINGMODE_EMISSIVE_LIGHTING)
    {
        // With deferred, Emissive is store in builtinData.bakeDiffuseLighting. If we ask for emissive lighting only
        // then remove bakeDiffuseLighting part.
        if (_DebugLightingMode == DEBUGLIGHTINGMODE_EMISSIVE_LIGHTING)
        {
    #if SHADEROPTIONS_PROBE_VOLUMES_EVALUATION_MODE == PROBEVOLUMESEVALUATIONMODES_LIGHT_LOOP
            if (!IsUninitializedGI(builtinData.bakeDiffuseLighting))
    #endif
            {
                builtinData.bakeDiffuseLighting = real3(0.0, 0.0, 0.0);
            }
        }
        else
        {
            builtinData.emissiveColor = real3(0.0, 0.0, 0.0);
        }
    }
#endif

    // RT3 - 11f:11f:10f
    // In deferred we encode emissive color with bakeDiffuseLighting. We don't have the room to store emissiveColor.
    // It mean that any futher process that affect bakeDiffuseLighting will also affect emissiveColor, like SSAO for example.
#if SHADEROPTIONS_PROBE_VOLUMES_EVALUATION_MODE == PROBEVOLUMESEVALUATIONMODES_LIGHT_LOOP

    if (IsUninitializedGI(builtinData.bakeDiffuseLighting))
    {
        // builtinData.bakeDiffuseLighting contain uninitializedGI sentinel value.

        // This means probe volumes will not get applied to this pixel, only emissiveColor will.
        // When length(emissiveColor) is much greater than length(probeVolumeOutgoingRadiance), this will visually look reasonable.
        // Unfortunately this will break down when emissiveColor is faded out (result will pop).
        // TODO: If evaluating probe volumes in lightloop, only write out sentinel value here, and re-render emissive surfaces.
        // Pre-expose lighting buffer
        outGBuffer3 = float4(all(builtinData.emissiveColor == 0.0) ? builtinData.bakeDiffuseLighting : builtinData.emissiveColor * GetCurrentExposureMultiplier(), 0.0);
    }
    else
#endif
    {
        outGBuffer3 = float4(builtinData.bakeDiffuseLighting * surfaceData.ambientOcclusion + builtinData.emissiveColor, 0.0);
        // Pre-expose lighting buffer
        outGBuffer3.rgb *= GetCurrentExposureMultiplier();
    }

#ifdef LIGHT_LAYERS
    // Note: we need to mask out only 8bits of the layer mask before encoding it as otherwise any value > 255 will map to all layers active
    OUT_GBUFFER_LIGHT_LAYERS = float4(0.0, 0.0, 0.0, (builtinData.renderingLayers & 0x000000FF) / 255.0);
#endif

#ifdef SHADOWS_SHADOWMASK
    OUT_GBUFFER_SHADOWMASK = BUILTIN_DATA_SHADOW_MASK;
#endif

#ifdef UNITY_VIRTUAL_TEXTURING
    OUT_GBUFFER_VTFEEDBACK = builtinData.vtPackedFeedback;
#endif
}

// Fills the BSDFData. Also returns the (per-pixel) material feature flags inferred
// from the contents of the G-buffer, which can be used by the feature classification system.
// Note that return type is not part of the MACRO DECODE_FROM_GBUFFER, so it is safe to use return value for our need
// 'tileFeatureFlags' are compile-time flags provided by the feature classification system.
// If you're not using the feature classification system, pass UINT_MAX.
// Also, see comment in TileVariantToFeatureFlags. When we are the worse case (i.e last variant), we read the featureflags
// from the structured buffer use to generate the indirect draw call. It allow to not go through all branch and the branch is scalar (not VGPR)
uint DecodeFromGBuffer(uint2 positionSS, uint tileFeatureFlags, out BSDFData bsdfData, out BuiltinData builtinData)
{
    // Note: we have ZERO_INITIALIZE the struct, so bsdfData.diffusionProfileIndex == DIFFUSION_PROFILE_NEUTRAL_ID,
    // bsdfData.anisotropy == 0, bsdfData.subsurfaceMask == 0, etc...
    ZERO_INITIALIZE(BSDFData, bsdfData);
    // Note: Some properties of builtinData are not used, just init all at 0 to silent the compiler
    ZERO_INITIALIZE(BuiltinData, builtinData);

    // Isolate material features.
    tileFeatureFlags &= MATERIAL_FEATURE_MASK_FLAGS;

    GBufferType0 inGBuffer0 = LOAD_TEXTURE2D_X(_GBufferTexture0, positionSS);
    GBufferType1 inGBuffer1 = LOAD_TEXTURE2D_X(_GBufferTexture1, positionSS);
    GBufferType2 inGBuffer2 = LOAD_TEXTURE2D_X(_GBufferTexture2, positionSS);

    // BuiltinData
    builtinData.bakeDiffuseLighting = LOAD_TEXTURE2D_X(_GBufferTexture3, positionSS).rgb;  // This also contain emissive (and * AO if no lightlayers)

#if SHADEROPTIONS_PROBE_VOLUMES_EVALUATION_MODE == PROBEVOLUMESEVALUATIONMODES_LIGHT_LOOP
    if (!IsUninitializedGI(builtinData.bakeDiffuseLighting))
#endif
    {
        // Inverse pre-exposure
        builtinData.bakeDiffuseLighting *= GetInverseCurrentExposureMultiplier(); // zero-div guard
    }

    // In deferred ambient occlusion isn't available and is already apply on bakeDiffuseLighting for the GI part.
    // Caution: even if we store it in the GBuffer we need to apply it on GI and not on emissive color, so AO must be 1.0 in deferred
    bsdfData.ambientOcclusion = 1.0;

    // Avoid to introduce a new variant for light layer as it is already long to compile
    if (_EnableLightLayers)
    {
        float4 inGBuffer4 = LOAD_TEXTURE2D_X(_LightLayersTexture, positionSS);
        builtinData.renderingLayers = uint(inGBuffer4.w * 255.5);
    }
    else
    {
        builtinData.renderingLayers = DEFAULT_LIGHT_LAYERS;
    }

    // We know the GBufferType no need to use abstraction
#ifdef SHADOWS_SHADOWMASK
    float4 shadowMaskGbuffer = LOAD_TEXTURE2D_X(_ShadowMaskTexture, positionSS);
    builtinData.shadowMask0 = shadowMaskGbuffer.x;
    builtinData.shadowMask1 = shadowMaskGbuffer.y;
    builtinData.shadowMask2 = shadowMaskGbuffer.z;
    builtinData.shadowMask3 = shadowMaskGbuffer.w;
#else
    builtinData.shadowMask0 = 1.0;
    builtinData.shadowMask1 = 1.0;
    builtinData.shadowMask2 = 1.0;
    builtinData.shadowMask3 = 1.0;
#endif

    // SurfaceData

    // Material classification only uses the G-Buffer 2.
    float coatMask;
    uint materialFeatureId;
    UnpackFloatInt8bit(inGBuffer2.a, 8, coatMask, materialFeatureId);

    uint pixelFeatureFlags    = MATERIALFEATUREFLAGS_LIT_STANDARD; // Only sky/background do not have the Standard flag.
    bsdfData.materialFeatures = MATERIALFEATUREFLAGS_LIT_STANDARD; // Only sky/background do not have the Standard flag.
    tileFeatureFlags = MATERIALFEATUREFLAGS_LIT_STANDARD;

    // Decompress feature-agnostic data from the G-Buffer.
    float3 baseColor = inGBuffer0.rgb;

    NormalData normalData;
    DecodeFromNormalBuffer(inGBuffer1, normalData);
    bsdfData.normalWS = normalData.normalWS;
    bsdfData.geomNormalWS = bsdfData.normalWS; // No geometric normal in deferred, use normal map
    bsdfData.perceptualRoughness = 1;


    bsdfData.diffuseColor = baseColor;
    bsdfData.fresnel0     = 0; // Later possibly overwritten by SSS
    bsdfData.specularOcclusion = inGBuffer0.a;

    bsdfData.roughnessT = 1;
    bsdfData.roughnessB = 1;

    ApplyDebugToBSDFData(bsdfData);

    return pixelFeatureFlags;
}

// Function call from the material classification compute shader
uint MaterialFeatureFlagsFromGBuffer(uint2 positionSS)
{
    BSDFData bsdfData;
    BuiltinData unused;
    // Call the regular function, compiler will optimized out everything not used.
    // Note that all material feature flag bellow are in the same GBuffer (inGBuffer2) and thus material classification only sample one Gbuffer
    return DecodeFromGBuffer(positionSS, UINT_MAX, bsdfData, unused);
}

//-----------------------------------------------------------------------------
// Debug method (use to display values)
//-----------------------------------------------------------------------------

void GetSurfaceDataDebug(uint paramId, SurfaceData surfaceData, inout float3 result, inout bool needLinearToSRGB)
{
    GetGeneratedSurfaceDataDebug(paramId, surfaceData, result, needLinearToSRGB);

    // Overide debug value output to be more readable
    switch (paramId)
    {
    case DEBUGVIEW_LIT_SURFACEDATA_NORMAL_VIEW_SPACE:
        {
            float3 vsNormal = TransformWorldToViewDir(surfaceData.normalWS);
            result = IsNormalized(vsNormal) ?  vsNormal * 0.5 + 0.5 : float3(1.0, 0.0, 0.0);
            break;
        }
    case DEBUGVIEW_LIT_SURFACEDATA_MATERIAL_FEATURES:
        result = (surfaceData.materialFeatures.xxx) / 255.0; // Aloow to read with color picker debug mode
        break;
    case DEBUGVIEW_LIT_SURFACEDATA_GEOMETRIC_NORMAL_VIEW_SPACE:
        {
            float3 vsGeomNormal = TransformWorldToViewDir(surfaceData.geomNormalWS);
            result = IsNormalized(vsGeomNormal) ?  vsGeomNormal * 0.5 + 0.5 : float3(1.0, 0.0, 0.0);
            break;
        }
    case DEBUGVIEW_LIT_SURFACEDATA_INDEX_OF_REFRACTION:
        result = saturate((surfaceData.ior - 1.0) / 1.5).xxx;
        break;
    }
}

void GetBSDFDataDebug(uint paramId, BSDFData bsdfData, inout float3 result, inout bool needLinearToSRGB)
{
    GetGeneratedBSDFDataDebug(paramId, bsdfData, result, needLinearToSRGB);

    // Overide debug value output to be more readable
    switch (paramId)
    {
    case DEBUGVIEW_LIT_BSDFDATA_NORMAL_VIEW_SPACE:
        // Convert to view space
        {
            float3 vsNormal = TransformWorldToViewDir(bsdfData.normalWS);
            result = IsNormalized(vsNormal) ?  vsNormal * 0.5 + 0.5 : float3(1.0, 0.0, 0.0);
            break;
        }
    case DEBUGVIEW_LIT_BSDFDATA_MATERIAL_FEATURES:
        result = (bsdfData.materialFeatures.xxx) / 255.0; // Aloow to read with color picker debug mode
        break;
    case DEBUGVIEW_LIT_BSDFDATA_GEOMETRIC_NORMAL_VIEW_SPACE:
        {
            float3 vsGeomNormal = TransformWorldToViewDir(bsdfData.geomNormalWS);
            result = IsNormalized(vsGeomNormal) ?  vsGeomNormal * 0.5 + 0.5 : float3(1.0, 0.0, 0.0);
            break;
        }
    case DEBUGVIEW_LIT_BSDFDATA_IOR:
        result = saturate((bsdfData.ior - 1.0) / 1.5).xxx;
        break;
    }
}

void GetPBRValidatorDebug(SurfaceData surfaceData, inout float3 result)
{
    result = surfaceData.baseColor;
}

//-----------------------------------------------------------------------------
// PreLightData
//-----------------------------------------------------------------------------

// Precomputed lighting data to send to the various lighting functions
struct PreLightData
{
    float NdotV;                     // Could be negative due to normal mapping, use ClampNdotV()

    // GGX
    float partLambdaV;
    float energyCompensation;

    // IBL
    float3 iblR;                     // Reflected specular direction, used for IBL in EvaluateBSDF_Env()
    float  iblPerceptualRoughness;

    float3 specularFGD;              // Store preintegrated BSDF for both specular and diffuse
    float  diffuseFGD;

#if HAS_REFRACTION
    // Refraction
    float3 transparentRefractV;      // refracted view vector after exiting the shape
    float3 transparentPositionWS;    // start of the refracted ray after exiting the shape
    float3 transparentTransmittance; // transmittance due to absorption
    float transparentSSMipLevel;     // mip level of the screen space gaussian pyramid for rough refraction
#endif
};

//
// ClampRoughness helper specific to this material
//
void ClampRoughness(inout PreLightData preLightData, inout BSDFData bsdfData, float minRoughness)
{
    bsdfData.roughnessT    = max(minRoughness, bsdfData.roughnessT);
    bsdfData.roughnessB    = max(minRoughness, bsdfData.roughnessB);
    bsdfData.coatRoughness = max(minRoughness, bsdfData.coatRoughness);
}

PreLightData GetPreLightData(float3 V, PositionInputs posInput, inout BSDFData bsdfData)
{
    PreLightData preLightData;
    ZERO_INITIALIZE(PreLightData, preLightData);

    float3 N = bsdfData.normalWS;
    preLightData.NdotV = dot(N, V);
    preLightData.iblPerceptualRoughness = bsdfData.perceptualRoughness;

    float clampedNdotV = ClampNdotV(preLightData.NdotV);

    // Handle IBL + area light + multiscattering.
    // Note: use the not modified by anisotropy iblPerceptualRoughness here.
    float specularReflectivity;
    GetPreIntegratedFGDGGXAndDisneyDiffuse(clampedNdotV, preLightData.iblPerceptualRoughness, bsdfData.fresnel0, preLightData.specularFGD, preLightData.diffuseFGD, specularReflectivity);
#ifdef USE_DIFFUSE_LAMBERT_BRDF
    preLightData.diffuseFGD = 1.0;
#endif

#ifdef LIT_USE_GGX_ENERGY_COMPENSATION
    // Ref: Practical multiple scattering compensation for microfacet models.
    // We only apply the formulation for metals.
    // For dielectrics, the change of reflectance is negligible.
    // We deem the intensity difference of a couple of percent for high values of roughness
    // to not be worth the cost of another precomputed table.
    // Note: this formulation bakes the BSDF non-symmetric!
    preLightData.energyCompensation = 1.0 / specularReflectivity - 1.0;
#else
    preLightData.energyCompensation = 0.0;
#endif // LIT_USE_GGX_ENERGY_COMPENSATION

    float3 iblN;
    preLightData.partLambdaV = GetSmithJointGGXPartLambdaV(clampedNdotV, bsdfData.roughnessT);
    iblN = N;
    preLightData.iblR = reflect(-V, iblN);

    // refraction (forward only)
#if HAS_REFRACTION
    RefractionModelResult refraction = REFRACTION_MODEL(V, posInput, bsdfData);
    preLightData.transparentRefractV = refraction.rayWS;
    preLightData.transparentPositionWS = refraction.positionWS;
    preLightData.transparentTransmittance = exp(-bsdfData.absorptionCoefficient * refraction.dist);

    // Empirical remap to try to match a bit the refraction probe blurring for the fallback
    // Use IblPerceptualRoughness so we can handle approx of clear coat.
    preLightData.transparentSSMipLevel = PositivePow(preLightData.iblPerceptualRoughness, 1.3) * uint(max(_ColorPyramidLodCount - 1, 0));
#endif

    return preLightData;
}

//-----------------------------------------------------------------------------
// bake lighting function
//-----------------------------------------------------------------------------

// This define allow to say that we implement a ModifyBakedDiffuseLighting function to be call in PostInitBuiltinData
#define MODIFY_BAKED_DIFFUSE_LIGHTING

// This function allow to modify the content of (back) baked diffuse lighting when we gather builtinData
// This is use to apply lighting model specific code, like pre-integration, transmission etc...
// It is up to the lighting model implementer to chose if the modification are apply here or in PostEvaluateBSDF
void ModifyBakedDiffuseLighting(float3 V, PositionInputs posInput, PreLightData preLightData, BSDFData bsdfData, inout BuiltinData builtinData)
{
    // Premultiply (back) bake diffuse lighting information with DisneyDiffuse pre-integration
    // Note: When baking reflection probes, we approximate the diffuse with the fresnel0
    builtinData.bakeDiffuseLighting *= preLightData.diffuseFGD * GetDiffuseOrDefaultColor(bsdfData, _ReplaceDiffuseForIndirect).rgb;
}

//-----------------------------------------------------------------------------
// light transport functions
//-----------------------------------------------------------------------------

LightTransportData GetLightTransportData(SurfaceData surfaceData, BuiltinData builtinData, BSDFData bsdfData)
{
    LightTransportData lightTransportData;

    // diffuseColor for lightmapping should basically be diffuse color.
    // But rough metals (black diffuse) still scatter quite a lot of light around, so
    // we want to take some of that into account too.

    float roughness = PerceptualRoughnessToRoughness(bsdfData.perceptualRoughness);
    lightTransportData.diffuseColor = bsdfData.diffuseColor + bsdfData.fresnel0 * roughness * 0.5 * surfaceData.metallic;
    lightTransportData.emissiveColor = builtinData.emissiveColor;

    return lightTransportData;
}

//-----------------------------------------------------------------------------
// LightLoop related function (Only include if required)
// HAS_LIGHTLOOP is define in Lighting.hlsl
//-----------------------------------------------------------------------------

#ifdef HAS_LIGHTLOOP

//-----------------------------------------------------------------------------
// BSDF share between directional light, punctual light and area light (reference)
//-----------------------------------------------------------------------------

bool IsNonZeroBSDF(float3 V, float3 L, PreLightData preLightData, BSDFData bsdfData)
{
    float NdotL = dot(bsdfData.normalWS, L);
    return NdotL > 0.0;
}

CBSDF EvaluateBSDF(float3 V, float3 L, PreLightData preLightData, BSDFData bsdfData)
{
    CBSDF cbsdf;
    ZERO_INITIALIZE(CBSDF, cbsdf);

    float3 N = bsdfData.normalWS;

    float NdotV = preLightData.NdotV;
    float NdotL = dot(N, L);
    float clampedNdotV = ClampNdotV(NdotV);
    float clampedNdotL = saturate(NdotL);
    float flippedNdotL = ComputeWrappedDiffuseLighting(-NdotL, TRANSMISSION_WRAP_LIGHT);

    float LdotV, NdotH, LdotH, invLenLV;
    GetBSDFAngle(V, L, NdotL, NdotV, LdotV, NdotH, LdotH, invLenLV);

    float diffTerm = Lambert();

    // The compiler should optimize these. Can revisit later if necessary.
    cbsdf.diffR = clampedNdotL * 0.5 + 0.5;
    cbsdf.diffT = cbsdf.diffR;

    cbsdf.specR = 0;

    // We don't multiply by 'bsdfData.diffuseColor' here. It's done only once in PostEvaluateBSDF().
    return cbsdf;
}

//-----------------------------------------------------------------------------
// Surface shading (all light types) below
//-----------------------------------------------------------------------------

#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/LightEvaluation.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/MaterialEvaluation.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/SurfaceShading.hlsl"

//-----------------------------------------------------------------------------
// EvaluateBSDF_Directional
//-----------------------------------------------------------------------------

DirectLighting EvaluateBSDF_Directional(LightLoopContext lightLoopContext,
                                        float3 V, PositionInputs posInput,
                                        PreLightData preLightData, DirectionalLightData lightData,
                                        BSDFData bsdfData, BuiltinData builtinData)
{
    return ShadeSurface_Directional(lightLoopContext, posInput, builtinData, preLightData, lightData, bsdfData, V);
}

//-----------------------------------------------------------------------------
// EvaluateBSDF_Punctual (supports spot, point and projector lights)
//-----------------------------------------------------------------------------

DirectLighting EvaluateBSDF_Punctual(LightLoopContext lightLoopContext,
                                     float3 V, PositionInputs posInput,
                                     PreLightData preLightData, LightData lightData,
                                     BSDFData bsdfData, BuiltinData builtinData)
{
    return ShadeSurface_Punctual(lightLoopContext, posInput, builtinData, preLightData, lightData, bsdfData, V);
}

#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Lit/LitReference.hlsl"

//-----------------------------------------------------------------------------
// EvaluateBSDF_SSLighting for screen space lighting
// ----------------------------------------------------------------------------

IndirectLighting EvaluateBSDF_ScreenSpaceReflection(PositionInputs posInput,
                                                    PreLightData   preLightData,
                                                    BSDFData       bsdfData,
                                                    inout float    reflectionHierarchyWeight)
{
    IndirectLighting lighting;
    ZERO_INITIALIZE(IndirectLighting, lighting);

    // TODO: this texture is sparse (mostly black). Can we avoid reading every texel? How about using Hi-S?
    float4 ssrLighting = LOAD_TEXTURE2D_X(_SsrLightingTexture, posInput.positionSS);
    InversePreExposeSsrLighting(ssrLighting);

    // Apply the weight on the ssr contribution (if required)
    ApplyScreenSpaceReflectionWeight(ssrLighting);

    // TODO: we should multiply all indirect lighting by the FGD value only ONCE.
    // In case this material has a clear coat, we shou not be using the specularFGD. The condition for it is a combination
    // of a materia feature and the coat mask.
    float clampedNdotV = ClampNdotV(preLightData.NdotV);
    lighting.specularReflected = ssrLighting.rgb * (HasFlag(bsdfData.materialFeatures, MATERIALFEATUREFLAGS_LIT_CLEAR_COAT) ?
                                                    lerp(preLightData.specularFGD, F_Schlick(CLEAR_COAT_F0, clampedNdotV), bsdfData.coatMask)
                                                    : preLightData.specularFGD);
    reflectionHierarchyWeight  = ssrLighting.a;

    return lighting;
}

IndirectLighting EvaluateBSDF_ScreenspaceRefraction(LightLoopContext lightLoopContext,
                                                    float3 V, PositionInputs posInput,
                                                    PreLightData preLightData, BSDFData bsdfData,
                                                    EnvLightData envLightData,
                                                    inout float hierarchyWeight)
{
    IndirectLighting lighting;
    ZERO_INITIALIZE(IndirectLighting, lighting);

#if HAS_REFRACTION
    // Refraction process:
    //  1. Depending on the shape model, we calculate the refracted point in world space and the optical depth
    //  2. We calculate the screen space position of the refracted point
    //  3. If this point is available (ie: in color buffer and point is not in front of the object)
    //    a. Get the corresponding color depending on the roughness from the gaussian pyramid of the color buffer
    //    b. Multiply by the transmittance for absorption (depends on the optical depth)

    // Proxy raycasting
    ScreenSpaceProxyRaycastInput ssRayInput;
    ZERO_INITIALIZE(ScreenSpaceProxyRaycastInput, ssRayInput);

    ssRayInput.rayOriginWS = preLightData.transparentPositionWS;
    ssRayInput.rayDirWS = preLightData.transparentRefractV;
    ssRayInput.proxyData = envLightData;

    ScreenSpaceRayHit hit;
    ZERO_INITIALIZE(ScreenSpaceRayHit, hit);
    bool hitSuccessful = false;
    float hitWeight = 1;
    hitSuccessful = ScreenSpaceProxyRaycastRefraction(ssRayInput, hit);

    if (!hitSuccessful)
        return lighting;

    // Resolve weight and color

    // Fade pixels near the texture buffers' borders
    float weight = EdgeOfScreenFade(hit.positionNDC, _SSRefractionInvScreenWeightDistance) * hitWeight;

    // Exit if texel is discarded
    if (weight == 0)
        // Do nothing and don't update the hierarchy weight so we can fall back on refraction probe
        return lighting;

    // This is an empirically set hack/modifier to reduce haloes of objects visible in the refraction.
    float refractionOffsetMultiplier = max(0.0f, 1.0f - preLightData.transparentSSMipLevel * 0.08f);

    // using LoadCameraDepth() here instead of hit.hitLinearDepth allow to fix an issue with VR single path instancing
    // as it use the macro LOAD_TEXTURE2D_X_LOD
    float hitDeviceDepth = LoadCameraDepth(hit.positionSS);
    float hitLinearDepth = LinearEyeDepth(hitDeviceDepth, _ZBufferParams);

    // If the hit object is in front of the refracting object, we use posInput.positionNDC to sample the color pyramid
    // This is equivalent of setting samplingPositionNDC = posInput.positionNDC when hitLinearDepth <= posInput.linearDepth
    refractionOffsetMultiplier *= (hitLinearDepth > posInput.linearDepth);

    float2 samplingPositionNDC = lerp(posInput.positionNDC, hit.positionNDC, refractionOffsetMultiplier);
    float3 preLD = SAMPLE_TEXTURE2D_X_LOD(_ColorPyramidTexture, s_trilinear_clamp_sampler, samplingPositionNDC * _RTHandleScaleHistory.xy, preLightData.transparentSSMipLevel).rgb;
                                        // Offset by half a texel to properly interpolate between this pixel and its mips

    // Inverse pre-exposure
    preLD *= GetInverseCurrentExposureMultiplier();

    // We use specularFGD as an approximation of the fresnel effect (that also handle smoothness)
    float3 F = preLightData.specularFGD;
    lighting.specularTransmitted = (1.0 - F) * preLD.rgb * preLightData.transparentTransmittance * weight;

    UpdateLightingHierarchyWeights(hierarchyWeight, weight); // Shouldn't be needed, but safer in case we decide to change hierarchy priority

#else // HAS_REFRACTION
    // No refraction, no need to go further
    hierarchyWeight = 1.0;
#endif

    return lighting;
}

//-----------------------------------------------------------------------------
// EvaluateBSDF_Env
// ----------------------------------------------------------------------------
// _preIntegratedFGD and _CubemapLD are unique for each BRDF
IndirectLighting EvaluateBSDF_Env(  LightLoopContext lightLoopContext,
                                    float3 V, PositionInputs posInput,
                                    PreLightData preLightData, EnvLightData lightData, BSDFData bsdfData,
                                    int influenceShapeType, int GPUImageBasedLightingType,
                                    inout float hierarchyWeight)
{
    IndirectLighting lighting;
    ZERO_INITIALIZE(IndirectLighting, lighting);
#if !HAS_REFRACTION
    if (GPUImageBasedLightingType == GPUIMAGEBASEDLIGHTINGTYPE_REFRACTION)
        return lighting;
#endif

    float3 envLighting;
    float3 positionWS = posInput.positionWS;
    float weight = 1.0;

#ifdef LIT_DISPLAY_REFERENCE_IBL

    envLighting = IntegrateSpecularGGXIBLRef(lightLoopContext, V, preLightData, lightData, bsdfData);

    // TODO: Do refraction reference (is it even possible ?)
    // TODO: handle clear coat


//    #ifdef USE_DIFFUSE_LAMBERT_BRDF
//    envLighting += IntegrateLambertIBLRef(lightData, V, bsdfData);
//    #else
//    envLighting += IntegrateDisneyDiffuseIBLRef(lightLoopContext, V, preLightData, lightData, bsdfData);
//    #endif

#else

    float3 R = preLightData.iblR;

#if HAS_REFRACTION
    if (GPUImageBasedLightingType == GPUIMAGEBASEDLIGHTINGTYPE_REFRACTION)
    {
        positionWS = preLightData.transparentPositionWS;
        R = preLightData.transparentRefractV;
    }
    else
#endif
    {
        if (!IsEnvIndexTexture2D(lightData.envIndex)) // ENVCACHETYPE_CUBEMAP
        {
            R = GetSpecularDominantDir(bsdfData.normalWS, R, preLightData.iblPerceptualRoughness, ClampNdotV(preLightData.NdotV));
            // When we are rough, we tend to see outward shifting of the reflection when at the boundary of the projection volume
            // Also it appear like more sharp. To avoid these artifact and at the same time get better match to reference we lerp to original unmodified reflection.
            // Formula is empirical.
            float roughness = PerceptualRoughnessToRoughness(preLightData.iblPerceptualRoughness);
            R = lerp(R, preLightData.iblR, saturate(smoothstep(0, 1, roughness * roughness)));
        }
    }

    // Note: using influenceShapeType and projectionShapeType instead of (lightData|proxyData).shapeType allow to make compiler optimization in case the type is know (like for sky)
    float intersectionDistance = EvaluateLight_EnvIntersection(positionWS, bsdfData.normalWS, lightData, influenceShapeType, R, weight);

    float3 F = preLightData.specularFGD;

    float4 preLD = SampleEnvWithDistanceBaseRoughness(lightLoopContext, posInput, lightData, R, preLightData.iblPerceptualRoughness, intersectionDistance);
    weight *= preLD.a; // Used by planar reflection to discard pixel

    if (GPUImageBasedLightingType == GPUIMAGEBASEDLIGHTINGTYPE_REFLECTION)
    {
        envLighting = F * preLD.rgb;
    }
#if HAS_REFRACTION
    else
    {
        // No clear coat support with refraction

        // specular transmisted lighting is the remaining of the reflection (let's use this approx)
        // With refraction, we don't care about the clear coat value, only about the Fresnel, thus why we use 'envLighting ='
        envLighting = (1.0 - F) * preLD.rgb * preLightData.transparentTransmittance;
    }
#endif

#endif // LIT_DISPLAY_REFERENCE_IBL

    UpdateLightingHierarchyWeights(hierarchyWeight, weight);
    envLighting *= weight * lightData.multiplier;

    if (GPUImageBasedLightingType == GPUIMAGEBASEDLIGHTINGTYPE_REFLECTION)
        lighting.specularReflected = envLighting;
#if HAS_REFRACTION
    else
        lighting.specularTransmitted = envLighting * preLightData.transparentTransmittance;
#endif

    return lighting;
}

//-----------------------------------------------------------------------------
// PostEvaluateBSDF
// ----------------------------------------------------------------------------

void PostEvaluateBSDF(  LightLoopContext lightLoopContext,
                        float3 V, PositionInputs posInput,
                        PreLightData preLightData, BSDFData bsdfData, BuiltinData builtinData, AggregateLighting lighting,
                        out LightLoopOutput lightLoopOutput)
{
    AmbientOcclusionFactor aoFactor;
    // Use GTAOMultiBounce approximation for ambient occlusion (allow to get a tint from the baseColor)
#if 0
    GetScreenSpaceAmbientOcclusion(posInput.positionSS, preLightData.NdotV, bsdfData.perceptualRoughness, bsdfData.ambientOcclusion, bsdfData.specularOcclusion, aoFactor);
#else
    GetScreenSpaceAmbientOcclusionMultibounce(posInput.positionSS, preLightData.NdotV, bsdfData.perceptualRoughness, bsdfData.ambientOcclusion, bsdfData.specularOcclusion, bsdfData.diffuseColor, bsdfData.fresnel0, aoFactor);
#endif

    ApplyAmbientOcclusionFactor(aoFactor, builtinData, lighting);

    // Apply the albedo to the direct diffuse lighting (only once). The indirect (baked)
    // diffuse lighting has already multiply the albedo in ModifyBakedDiffuseLighting().
    // Note: In deferred bakeDiffuseLighting also contain emissive and in this case emissiveColor is 0
    lightLoopOutput.diffuseLighting = bsdfData.diffuseColor * lighting.direct.diffuse + builtinData.bakeDiffuseLighting + builtinData.emissiveColor;

    // If refraction is enable we use the transmittanceMask to lerp between current diffuse lighting and refraction value
    // Physically speaking, transmittanceMask should be 1, but for artistic reasons, we let the value vary
    //
    // Note we also transfer the refracted light (lighting.indirect.specularTransmitted) into diffuseLighting
    // since we know it won't be further processed: it is called at the end of the LightLoop(), but doing this
    // enables opacity to affect it (in ApplyBlendMode()) while the rest of specularLighting escapes it.
#if HAS_REFRACTION
    lightLoopOutput.diffuseLighting = lerp(lightLoopOutput.diffuseLighting, lighting.indirect.specularTransmitted, bsdfData.transmittanceMask * _EnableSSRefraction);
#endif

    lightLoopOutput.specularLighting = lighting.direct.specular + lighting.indirect.specularReflected;
    // Rescale the GGX to account for the multiple scattering.
    lightLoopOutput.specularLighting *= 1.0 + bsdfData.fresnel0 * preLightData.energyCompensation;

#ifdef DEBUG_DISPLAY
    PostEvaluateBSDFDebugDisplay(aoFactor, builtinData, lighting, bsdfData.diffuseColor, lightLoopOutput);
#endif
}

#endif // #ifdef HAS_LIGHTLOOP
