// ===========================================================================
//                              WARNING:
// On PS4, texture/sampler declarations need to be outside of CBuffers
// Otherwise those parameters are not bound correctly at runtime.
// ===========================================================================

TEXTURE2D(_DistortionVectorMap);
SAMPLER(sampler_DistortionVectorMap);

TEXTURE2D(_EmissiveColorMap);
SAMPLER(sampler_EmissiveColorMap);

TEXTURE2D(_DiffuseLightingMap);
SAMPLER(sampler_DiffuseLightingMap);

TEXTURE2D(_BaseColorMap);
SAMPLER(sampler_BaseColorMap);

TEXTURE2D(_NormalMap);
SAMPLER(sampler_NormalMap);

CBUFFER_START(UnityPerMaterial)

float _ShadingToonRamp;
float _LightWrapValue;
//float _RimToonRamp;
//float _Translucency;
float _Reflectivity;

float _AlphaCutoff;
float4 _DoubleSidedConstants;
float _DistortionScale;
float _DistortionVectorScale;
float _DistortionVectorBias;
float _DistortionBlurScale;
float _DistortionBlurRemapMin;
float _DistortionBlurRemapMax;
float _BlendMode;
//float _EnableBlendModePreserveSpecularLighting;

//float _PPDMaxSamples;
//float _PPDMinSamples;
//float _PPDLodThreshold;

float3 _EmissiveColor;
//float _EmissiveExposureWeight;

//int  _SpecularOcclusionMode;

// Transparency
float3 _TransmittanceColor;
float _Ior;
float _ATDistance;

// Caution: C# code in BaseLitUI.cs call LightmapEmissionFlagsProperty() which assume that there is an existing "_EmissionColor"
// value that exist to identify if the GI emission need to be enabled.
// In our case we don't use such a mechanism but need to keep the code quiet. We declare the value and always enable it.
// TODO: Fix the code in legacy unity so we can customize the beahvior for GI
float3 _EmissionColor;
float4 _EmissiveColorMap_ST;
float _TexWorldScaleEmissive;
float4 _UVMappingMaskEmissive;

float4 _InvPrimScale; // Only XY are used

// Wind
//float _InitialBend;
//float _Stiffness;
//float _Drag;
//float _ShiverDrag;
//float _ShiverDirectionality;

// Specular AA
//float _EnableGeometricSpecularAA;
//float _SpecularAAScreenSpaceVariance;
//float _SpecularAAThreshold;

// Raytracing
//float _RayTracing;

// Set of users variables
float4 _BaseColor;
float4 _BaseColorMap_ST;
//float4 _BaseColorMap_TexelSize;
//float4 _BaseColorMap_MipInfo;

float _NormalScale;

// Tessellation specific

#ifdef TESSELLATION_ON
float _TessellationFactor;
float _TessellationFactorMinDistance;
float _TessellationFactorMaxDistance;
float _TessellationFactorTriangleSize;
float _TessellationShapeFactor;
float _TessellationBackFaceCullEpsilon;
float _TessellationObjectScale;
float _TessellationTilingScale;
#endif

// Following three variables are feeded by the C++ Editor for Scene selection
int _ObjectId;
int _PassValue;
float4 _SelectionID;

CBUFFER_END

