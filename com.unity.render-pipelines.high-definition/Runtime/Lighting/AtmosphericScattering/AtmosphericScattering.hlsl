#ifndef UNITY_ATMOSPHERIC_SCATTERING_INCLUDED
#define UNITY_ATMOSPHERIC_SCATTERING_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/VolumeRendering.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Filtering.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/GeometricTools.hlsl"

#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/AtmosphericScattering/AtmosphericScattering.cs.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/VolumetricLighting/VBuffer.hlsl"
//#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Sky/PhysicallyBasedSky/PhysicallyBasedSkyCommon.hlsl"

#ifdef DEBUG_DISPLAY
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Debug/DebugDisplay.hlsl"
#endif

TEXTURE3D(_VBufferLighting);

float3 ExpLerp(float3 A, float3 B, float t, float x, float y)
{
    // Remap t: (exp(10 k t) - 1) / (exp(10 k) - 1) = exp(x t) y - y.
    t = exp(x * t) * y - y;
    // Perform linear interpolation using the new value of t.
    return lerp(A, B, t);
}

float3 GetFogColor(float3 V, float fragDist)
{
    return SampleSkyTexture(-V, 0, 0).rgb;
}

float3 GetViewForwardDir1(float4x4 viewMatrix)
{
    return -viewMatrix[2].xyz;
}

void EvaluateAtmosphericScattering(PositionInputs posInput, float3 V, out float3 color, out float3 opacity)
{
    color = opacity = 0;

#ifdef DEBUG_DISPLAY
    // Don't sample atmospheric scattering when lighting debug more are enabled so fog is not visible
    if (_DebugLightingMode >= DEBUGLIGHTINGMODE_DIFFUSE_LIGHTING && _DebugLightingMode <= DEBUGLIGHTINGMODE_EMISSIVE_LIGHTING)
        return;

    if (_DebugShadowMapMode == SHADOWMAPDEBUGMODE_SINGLE_SHADOW || _DebugLightingMode == DEBUGLIGHTINGMODE_LUX_METER || _DebugLightingMode == DEBUGLIGHTINGMODE_LUMINANCE_METER)
        return;
#endif

    // TODO: do not recompute this, but rather pass it directly.
    // Note1: remember the hacked value of 'posInput.positionWS'.
    // Note2: we do not adjust it anymore to account for the distance to the planet. This can lead to wrong results (since the planet does not write depth).
    float fogFragDist = distance(posInput.positionWS, GetCurrentViewPosition());

    if (_FogEnabled)
    {
        float4 volFog = float4(0.0, 0.0, 0.0, 0.0);

        float expFogStart = 0.0f;

        if (_EnableVolumetricFog != 0)
        {
            bool doBiquadraticReconstruction = _VolumetricFilteringEnabled == 0; // Only if filtering is disabled.
            float4 value = SampleVBuffer(TEXTURE3D_ARGS(_VBufferLighting, s_linear_clamp_sampler),
                                         posInput.positionNDC,
                                         fogFragDist,
                                         _VBufferViewportSize,
                                         _VBufferLightingViewportScale.xyz,
                                         _VBufferLightingViewportLimit.xyz,
                                         _VBufferDistanceEncodingParams,
                                         _VBufferDistanceDecodingParams,
                                         true, doBiquadraticReconstruction, false);

            // TODO: add some slowly animated noise (dither?) to the reconstructed value.
            // TODO: re-enable tone mapping after implementing pre-exposure.
            volFog = DelinearizeRGBA(float4(/*FastTonemapInvert*/(value.rgb), value.a));
            expFogStart = _VBufferLastSliceDist;
        }

        // TODO: if 'posInput.linearDepth' is computed using 'posInput.positionWS',
        // and the latter resides on the far plane, the computation will be numerically unstable.
        float distDelta = fogFragDist - expFogStart;

        if ((distDelta > 0))
        {
            // Apply the distant (fallback) fog.
            float3 positionWS = GetCurrentViewPosition() - V * expFogStart;
            float  startHeight = positionWS.y;
            float  cosZenith = -V.y;

            // For both homogeneous and exponential media,
            // Integrate[Transmittance[x] * Scattering[x], {x, 0, t}] = Albedo * Opacity[t].
            // Note that pulling the incoming radiance (which is affected by the fog) out of the
            // integral is wrong, as it means that shadow rays are not volumetrically shadowed.
            // This will result in fog looking overly bright.

            float3 volAlbedo = _HeightFogBaseScattering.xyz / _HeightFogBaseExtinction;
            float  odFallback = OpticalDepthHeightFog(_HeightFogBaseExtinction, _HeightFogBaseHeight,
                _HeightFogExponents, cosZenith, startHeight, distDelta);
            float  trFallback = TransmittanceFromOpticalDepth(odFallback);
            float  trCamera = 1 - volFog.a;

            volFog.rgb += trCamera * GetFogColor(V, fogFragDist) * GetCurrentExposureMultiplier() * volAlbedo * (1 - trFallback);
            volFog.a = 1 - (trCamera * trFallback);
        }

        color = volFog.rgb; // Already pre-exposed
        opacity = volFog.a;
    }
}


#endif
