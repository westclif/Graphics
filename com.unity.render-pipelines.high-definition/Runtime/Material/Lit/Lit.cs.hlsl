//
// This file was automatically generated. Please don't edit by hand.
//

#ifndef LIT_CS_HLSL
#define LIT_CS_HLSL
//
// UnityEngine.Rendering.HighDefinition.Lit+MaterialFeatureFlags:  static fields
//
#define MATERIALFEATUREFLAGS_LIT_STANDARD (1)
#define MATERIALFEATUREFLAGS_LIT_SPECULAR_COLOR (2)
#define MATERIALFEATUREFLAGS_LIT_SUBSURFACE_SCATTERING (4)
#define MATERIALFEATUREFLAGS_LIT_TRANSMISSION (8)
#define MATERIALFEATUREFLAGS_LIT_ANISOTROPY (16)
#define MATERIALFEATUREFLAGS_LIT_IRIDESCENCE (32)
#define MATERIALFEATUREFLAGS_LIT_CLEAR_COAT (64)

//
// UnityEngine.Rendering.HighDefinition.Lit+SurfaceData:  static fields
//
#define DEBUGVIEW_LIT_SURFACEDATA_MATERIAL_FEATURES (1000)
#define DEBUGVIEW_LIT_SURFACEDATA_BASE_COLOR (1001)
#define DEBUGVIEW_LIT_SURFACEDATA_NORMAL (1002)
#define DEBUGVIEW_LIT_SURFACEDATA_NORMAL_VIEW_SPACE (1003)
#define DEBUGVIEW_LIT_SURFACEDATA_AMBIENT_OCCLUSION (1004)
#define DEBUGVIEW_LIT_SURFACEDATA_TEXTURE_RAMP_SHADING (1005)
#define DEBUGVIEW_LIT_SURFACEDATA_TEXTURE_RAMP_SPECULAR (1006)
#define DEBUGVIEW_LIT_SURFACEDATA_TEXTURE_RAMP_RIM (1007)
#define DEBUGVIEW_LIT_SURFACEDATA_GEOMETRIC_NORMAL (1008)
#define DEBUGVIEW_LIT_SURFACEDATA_GEOMETRIC_NORMAL_VIEW_SPACE (1009)
#define DEBUGVIEW_LIT_SURFACEDATA_TANGENT (1010)
#define DEBUGVIEW_LIT_SURFACEDATA_INDEX_OF_REFRACTION (1011)
#define DEBUGVIEW_LIT_SURFACEDATA_TRANSMITTANCE_COLOR (1012)
#define DEBUGVIEW_LIT_SURFACEDATA_TRANSMITTANCE_ABSORPTION_DISTANCE (1013)
#define DEBUGVIEW_LIT_SURFACEDATA_TRANSMITTANCE_MASK (1014)

//
// UnityEngine.Rendering.HighDefinition.Lit+BSDFData:  static fields
//
#define DEBUGVIEW_LIT_BSDFDATA_MATERIAL_FEATURES (1050)
#define DEBUGVIEW_LIT_BSDFDATA_DIFFUSE_COLOR (1051)
#define DEBUGVIEW_LIT_BSDFDATA_FRESNEL0 (1052)
#define DEBUGVIEW_LIT_BSDFDATA_AMBIENT_OCCLUSION (1053)
#define DEBUGVIEW_LIT_BSDFDATA_NORMAL_WS (1054)
#define DEBUGVIEW_LIT_BSDFDATA_NORMAL_VIEW_SPACE (1055)
#define DEBUGVIEW_LIT_BSDFDATA_TEXTURE_RAMP_SHADING (1056)
#define DEBUGVIEW_LIT_BSDFDATA_TEXTURE_RAMP_SPECULAR (1057)
#define DEBUGVIEW_LIT_BSDFDATA_TEXTURE_RAMP_RIM (1058)
#define DEBUGVIEW_LIT_BSDFDATA_TANGENT_WS (1059)
#define DEBUGVIEW_LIT_BSDFDATA_BITANGENT_WS (1060)
#define DEBUGVIEW_LIT_BSDFDATA_ROUGHNESS_T (1061)
#define DEBUGVIEW_LIT_BSDFDATA_ROUGHNESS_B (1062)
#define DEBUGVIEW_LIT_BSDFDATA_GEOMETRIC_NORMAL (1063)
#define DEBUGVIEW_LIT_BSDFDATA_GEOMETRIC_NORMAL_VIEW_SPACE (1064)
#define DEBUGVIEW_LIT_BSDFDATA_IOR (1065)

// Generated from UnityEngine.Rendering.HighDefinition.Lit+SurfaceData
// PackingRules = Exact
struct SurfaceData
{
    uint materialFeatures;
    real3 baseColor;
    float3 normalWS;
    real ambientOcclusion;
    uint textureRampShading;
    uint textureRampSpecular;
    uint textureRampRim;
    real3 geomNormalWS;
    float3 tangentWS;
    real ior;
    real3 transmittanceColor;
    real atDistance;
    real transmittanceMask;
};

// Generated from UnityEngine.Rendering.HighDefinition.Lit+BSDFData
// PackingRules = Exact
struct BSDFData
{
    uint materialFeatures;
    real3 diffuseColor;
    real3 fresnel0;
    real ambientOcclusion;
    float3 normalWS;
    uint textureRampShading;
    uint textureRampSpecular;
    uint textureRampRim;
    float3 tangentWS;
    float3 bitangentWS;
    real roughnessT;
    real roughnessB;
    real3 geomNormalWS;
    real ior;
};

//
// Debug functions
//
void GetGeneratedSurfaceDataDebug(uint paramId, SurfaceData surfacedata, inout float3 result, inout bool needLinearToSRGB)
{
    switch (paramId)
    {
        case DEBUGVIEW_LIT_SURFACEDATA_MATERIAL_FEATURES:
            result = GetIndexColor(surfacedata.materialFeatures);
            break;
        case DEBUGVIEW_LIT_SURFACEDATA_BASE_COLOR:
            result = surfacedata.baseColor;
            needLinearToSRGB = true;
            break;
        case DEBUGVIEW_LIT_SURFACEDATA_NORMAL:
            result = IsNormalized(surfacedata.normalWS)? surfacedata.normalWS * 0.5 + 0.5 : float3(1.0, 0.0, 0.0);
            break;
        case DEBUGVIEW_LIT_SURFACEDATA_NORMAL_VIEW_SPACE:
            result = IsNormalized(surfacedata.normalWS)? surfacedata.normalWS * 0.5 + 0.5 : float3(1.0, 0.0, 0.0);
            break;
        case DEBUGVIEW_LIT_SURFACEDATA_AMBIENT_OCCLUSION:
            result = surfacedata.ambientOcclusion.xxx;
            break;
        case DEBUGVIEW_LIT_SURFACEDATA_TEXTURE_RAMP_SHADING:
            result = GetIndexColor(surfacedata.textureRampShading);
            break;
        case DEBUGVIEW_LIT_SURFACEDATA_TEXTURE_RAMP_SPECULAR:
            result = GetIndexColor(surfacedata.textureRampSpecular);
            break;
        case DEBUGVIEW_LIT_SURFACEDATA_TEXTURE_RAMP_RIM:
            result = GetIndexColor(surfacedata.textureRampRim);
            break;
        case DEBUGVIEW_LIT_SURFACEDATA_GEOMETRIC_NORMAL:
            result = IsNormalized(surfacedata.geomNormalWS)? surfacedata.geomNormalWS * 0.5 + 0.5 : float3(1.0, 0.0, 0.0);
            break;
        case DEBUGVIEW_LIT_SURFACEDATA_GEOMETRIC_NORMAL_VIEW_SPACE:
            result = IsNormalized(surfacedata.geomNormalWS)? surfacedata.geomNormalWS * 0.5 + 0.5 : float3(1.0, 0.0, 0.0);
            break;
        case DEBUGVIEW_LIT_SURFACEDATA_TANGENT:
            result = surfacedata.tangentWS * 0.5 + 0.5;
            break;
        case DEBUGVIEW_LIT_SURFACEDATA_INDEX_OF_REFRACTION:
            result = surfacedata.ior.xxx;
            break;
        case DEBUGVIEW_LIT_SURFACEDATA_TRANSMITTANCE_COLOR:
            result = surfacedata.transmittanceColor;
            break;
        case DEBUGVIEW_LIT_SURFACEDATA_TRANSMITTANCE_ABSORPTION_DISTANCE:
            result = surfacedata.atDistance.xxx;
            break;
        case DEBUGVIEW_LIT_SURFACEDATA_TRANSMITTANCE_MASK:
            result = surfacedata.transmittanceMask.xxx;
            break;
    }
}

//
// Debug functions
//
void GetGeneratedBSDFDataDebug(uint paramId, BSDFData bsdfdata, inout float3 result, inout bool needLinearToSRGB)
{
    switch (paramId)
    {
        case DEBUGVIEW_LIT_BSDFDATA_MATERIAL_FEATURES:
            result = GetIndexColor(bsdfdata.materialFeatures);
            break;
        case DEBUGVIEW_LIT_BSDFDATA_DIFFUSE_COLOR:
            result = bsdfdata.diffuseColor;
            needLinearToSRGB = true;
            break;
        case DEBUGVIEW_LIT_BSDFDATA_FRESNEL0:
            result = bsdfdata.fresnel0;
            break;
        case DEBUGVIEW_LIT_BSDFDATA_AMBIENT_OCCLUSION:
            result = bsdfdata.ambientOcclusion.xxx;
            break;
        case DEBUGVIEW_LIT_BSDFDATA_NORMAL_WS:
            result = IsNormalized(bsdfdata.normalWS)? bsdfdata.normalWS * 0.5 + 0.5 : float3(1.0, 0.0, 0.0);
            break;
        case DEBUGVIEW_LIT_BSDFDATA_NORMAL_VIEW_SPACE:
            result = IsNormalized(bsdfdata.normalWS)? bsdfdata.normalWS * 0.5 + 0.5 : float3(1.0, 0.0, 0.0);
            break;
        case DEBUGVIEW_LIT_BSDFDATA_TEXTURE_RAMP_SHADING:
            result = GetIndexColor(bsdfdata.textureRampShading);
            break;
        case DEBUGVIEW_LIT_BSDFDATA_TEXTURE_RAMP_SPECULAR:
            result = GetIndexColor(bsdfdata.textureRampSpecular);
            break;
        case DEBUGVIEW_LIT_BSDFDATA_TEXTURE_RAMP_RIM:
            result = GetIndexColor(bsdfdata.textureRampRim);
            break;
        case DEBUGVIEW_LIT_BSDFDATA_TANGENT_WS:
            result = bsdfdata.tangentWS * 0.5 + 0.5;
            break;
        case DEBUGVIEW_LIT_BSDFDATA_BITANGENT_WS:
            result = bsdfdata.bitangentWS * 0.5 + 0.5;
            break;
        case DEBUGVIEW_LIT_BSDFDATA_ROUGHNESS_T:
            result = bsdfdata.roughnessT.xxx;
            break;
        case DEBUGVIEW_LIT_BSDFDATA_ROUGHNESS_B:
            result = bsdfdata.roughnessB.xxx;
            break;
        case DEBUGVIEW_LIT_BSDFDATA_GEOMETRIC_NORMAL:
            result = IsNormalized(bsdfdata.geomNormalWS)? bsdfdata.geomNormalWS * 0.5 + 0.5 : float3(1.0, 0.0, 0.0);
            break;
        case DEBUGVIEW_LIT_BSDFDATA_GEOMETRIC_NORMAL_VIEW_SPACE:
            result = IsNormalized(bsdfdata.geomNormalWS)? bsdfdata.geomNormalWS * 0.5 + 0.5 : float3(1.0, 0.0, 0.0);
            break;
        case DEBUGVIEW_LIT_BSDFDATA_IOR:
            result = bsdfdata.ior.xxx;
            break;
    }
}


#endif
