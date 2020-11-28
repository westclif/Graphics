#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Macros.hlsl"

#if SHADEROPTIONS_PROBE_VOLUMES_EVALUATION_MODE == PROBEVOLUMESEVALUATIONMODES_LIGHT_LOOP
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/BuiltinUtilities.hlsl"
#else
// Required to have access to the indirectDiffuseMode enum in forward pass where we don't include BuiltinUtilities
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/ScreenSpaceLighting/ScreenSpaceGlobalIllumination.cs.hlsl"
#endif

#ifndef SCALARIZE_LIGHT_LOOP
// We perform scalarization only for forward rendering as for deferred loads will already be scalar since tiles will match waves and therefore all threads will read from the same tile.
// More info on scalarization: https://flashypixels.wordpress.com/2018/11/10/intro-to-gpu-scalarization-part-2-scalarize-all-the-lights/
#define SCALARIZE_LIGHT_LOOP (defined(PLATFORM_SUPPORTS_WAVE_INTRINSICS) && !defined(LIGHTLOOP_DISABLE_TILE_AND_CLUSTER) && SHADERPASS == SHADERPASS_FORWARD)
#endif

void LightLoop( float3 V, PositionInputs posInput, PreLightData preLightData, BSDFData bsdfData, BuiltinData builtinData, uint featureFlags,
                out LightLoopOutput lightLoopOutput)
{
    // Init LightLoop output structure
    ZERO_INITIALIZE(LightLoopOutput, lightLoopOutput);

    LightLoopContext context;

    context.shadowContext    = InitShadowContext();
    context.shadowValue      = 1;
    context.sampleReflection = 0;

    // With XR single-pass and camera-relative: offset position to do lighting computations from the combined center view (original camera matrix).
    // This is required because there is only one list of lights generated on the CPU. Shadows are also generated once and shared between the instanced views.
    ApplyCameraRelativeXR(posInput.positionWS);

    // Initialize the contactShadow and contactShadowFade fields
    InitContactShadow(posInput, context);

    // First of all we compute the shadow value of the directional light to reduce the VGPR pressure
    if (featureFlags & LIGHTFEATUREFLAGS_DIRECTIONAL)
    {
        // Evaluate sun shadows.
        if (_DirectionalShadowIndex >= 0)
        {
            DirectionalLightData light = _DirectionalLightDatas[_DirectionalShadowIndex];

#if defined(SCREEN_SPACE_SHADOWS_ON) && !defined(_SURFACE_TYPE_TRANSPARENT)
            if ((light.screenSpaceShadowIndex & SCREEN_SPACE_SHADOW_INDEX_MASK) != INVALID_SCREEN_SPACE_SHADOW)
            {
                context.shadowValue = GetScreenSpaceColorShadow(posInput, light.screenSpaceShadowIndex).SHADOW_TYPE_SWIZZLE;
            }
            else
#endif
            {
                // TODO: this will cause us to load from the normal buffer first. Does this cause a performance problem?
                float3 L = -light.forward;

                // Is it worth sampling the shadow map?
                if ((light.lightDimmer > 0) && (light.shadowDimmer > 0) && // Note: Volumetric can have different dimmer, thus why we test it here
                    IsNonZeroBSDF(V, L, preLightData, bsdfData))
                {
                    context.shadowValue = GetDirectionalShadowAttenuation(context.shadowContext,
                                                                          posInput.positionSS, posInput.positionWS, GetNormalForShadowBias(bsdfData),
                                                                          light.shadowIndex, L);
                }
            }
        }
    }

    // This struct is define in the material. the Lightloop must not access it
    // PostEvaluateBSDF call at the end will convert Lighting to diffuse and specular lighting
    AggregateLighting aggregateLighting;
    ZERO_INITIALIZE(AggregateLighting, aggregateLighting); // LightLoop is in charge of initializing the struct

    if (featureFlags & LIGHTFEATUREFLAGS_PUNCTUAL)
    {
        uint lightCount, lightStart;

#ifndef LIGHTLOOP_DISABLE_TILE_AND_CLUSTER
        GetCountAndStart(posInput, LIGHTCATEGORY_PUNCTUAL, lightStart, lightCount);
#else   // LIGHTLOOP_DISABLE_TILE_AND_CLUSTER
        lightCount = _PunctualLightCount;
        lightStart = 0;
#endif

        bool fastPath = false;
    #if SCALARIZE_LIGHT_LOOP
        uint lightStartLane0;
        fastPath = IsFastPath(lightStart, lightStartLane0);

        if (fastPath)
        {
            lightStart = lightStartLane0;
        }
    #endif

        // Scalarized loop. All lights that are in a tile/cluster touched by any pixel in the wave are loaded (scalar load), only the one relevant to current thread/pixel are processed.
        // For clarity, the following code will follow the convention: variables starting with s_ are meant to be wave uniform (meant for scalar register),
        // v_ are variables that might have different value for each thread in the wave (meant for vector registers).
        // This will perform more loads than it is supposed to, however, the benefits should offset the downside, especially given that light data accessed should be largely coherent.
        // Note that the above is valid only if wave intriniscs are supported.
        uint v_lightListOffset = 0;
        uint v_lightIdx = lightStart;

        while (v_lightListOffset < lightCount)
        {
            v_lightIdx = FetchIndex(lightStart, v_lightListOffset);
#if SCALARIZE_LIGHT_LOOP
            uint s_lightIdx = ScalarizeElementIndex(v_lightIdx, fastPath);
#else
            uint s_lightIdx = v_lightIdx;
#endif
            if (s_lightIdx == -1)
                break;

            LightData s_lightData = FetchLight(s_lightIdx);

            // If current scalar and vector light index match, we process the light. The v_lightListOffset for current thread is increased.
            // Note that the following should really be ==, however, since helper lanes are not considered by WaveActiveMin, such helper lanes could
            // end up with a unique v_lightIdx value that is smaller than s_lightIdx hence being stuck in a loop. All the active lanes will not have this problem.
            if (s_lightIdx >= v_lightIdx)
            {
                v_lightListOffset++;
                if (IsMatchingLightLayer(s_lightData.lightLayers, builtinData.renderingLayers))
                {
                    DirectLighting lighting = EvaluateBSDF_Punctual(context, V, posInput, preLightData, s_lightData, bsdfData, builtinData);
                    AccumulateDirectLighting(lighting, aggregateLighting);
                }
            }
        }
    }


    // Define macro for a better understanding of the loop
    // TODO: this code is now much harder to understand...
#define EVALUATE_BSDF_ENV_SKY(envLightData, TYPE, type) \
        IndirectLighting lighting = EvaluateBSDF_Env(context, V, posInput, preLightData, envLightData, bsdfData, envLightData.influenceShapeType, MERGE_NAME(GPUIMAGEBASEDLIGHTINGTYPE_, TYPE), MERGE_NAME(type, HierarchyWeight)); \
        AccumulateIndirectLighting(lighting, aggregateLighting);

// Environment cubemap test lightlayers, sky don't test it
#define EVALUATE_BSDF_ENV(envLightData, TYPE, type) if (IsMatchingLightLayer(envLightData.lightLayers, builtinData.renderingLayers)) { EVALUATE_BSDF_ENV_SKY(envLightData, TYPE, type) }

    // First loop iteration
    if (featureFlags & (LIGHTFEATUREFLAGS_ENV | LIGHTFEATUREFLAGS_SKY | LIGHTFEATUREFLAGS_SSREFRACTION | LIGHTFEATUREFLAGS_SSREFLECTION))
    {
        float reflectionHierarchyWeight = 0.0; // Max: 1.0
        float refractionHierarchyWeight = _EnableSSRefraction ? 0.0 : 1.0; // Max: 1.0

        uint envLightStart, envLightCount;

        // Fetch first env light to provide the scene proxy for screen space computation
#ifndef LIGHTLOOP_DISABLE_TILE_AND_CLUSTER
        GetCountAndStart(posInput, LIGHTCATEGORY_ENV, envLightStart, envLightCount);
#else   // LIGHTLOOP_DISABLE_TILE_AND_CLUSTER
        envLightCount = _EnvLightCount;
        envLightStart = 0;
#endif

        bool fastPath = false;
    #if SCALARIZE_LIGHT_LOOP
        uint envStartFirstLane;
        fastPath = IsFastPath(envLightStart, envStartFirstLane);
    #endif

        // Reflection / Refraction hierarchy is
        //  1. Screen Space Refraction / Reflection
        //  2. Environment Reflection / Refraction
        //  3. Sky Reflection / Refraction

        // Apply SSR.
    #if (defined(_SURFACE_TYPE_TRANSPARENT) && !defined(_DISABLE_SSR_TRANSPARENT)) || (!defined(_SURFACE_TYPE_TRANSPARENT) && !defined(_DISABLE_SSR))
        {
            IndirectLighting indirect = EvaluateBSDF_ScreenSpaceReflection(posInput, preLightData, bsdfData,
                                                                           reflectionHierarchyWeight);
            AccumulateIndirectLighting(indirect, aggregateLighting);
        }
    #endif

        EnvLightData envLightData;
        if (envLightCount > 0)
        {
            envLightData = FetchEnvLight(envLightStart, 0);
        }
        else
        {
            envLightData = InitSkyEnvLightData(0);
        }

        if ((featureFlags & LIGHTFEATUREFLAGS_SSREFRACTION) && (_EnableSSRefraction > 0))
        {
            IndirectLighting lighting = EvaluateBSDF_ScreenspaceRefraction(context, V, posInput, preLightData, bsdfData, envLightData, refractionHierarchyWeight);
            AccumulateIndirectLighting(lighting, aggregateLighting);
        }

        // Only apply the sky IBL if the sky texture is available
        if ((featureFlags & LIGHTFEATUREFLAGS_SKY) && _EnvLightSkyEnabled)
        {
            // The sky is a single cubemap texture separate from the reflection probe texture array (different resolution and compression)
            context.sampleReflection = SINGLE_PASS_CONTEXT_SAMPLE_SKY;

            // The sky data are generated on the fly so the compiler can optimize the code
            EnvLightData envLightSky = InitSkyEnvLightData(0);

            // Only apply the sky if we haven't yet accumulated enough IBL lighting.
            if (reflectionHierarchyWeight < 1.0)
            {
                EVALUATE_BSDF_ENV_SKY(envLightSky, REFLECTION, reflection);
            }

            if ((featureFlags & LIGHTFEATUREFLAGS_SSREFRACTION) && (refractionHierarchyWeight < 1.0))
            {
                EVALUATE_BSDF_ENV_SKY(envLightSky, REFRACTION, refraction);
            }
        }
    }
#undef EVALUATE_BSDF_ENV
#undef EVALUATE_BSDF_ENV_SKY

    uint i = 0; // Declare once to avoid the D3D11 compiler warning.
    if (featureFlags & LIGHTFEATUREFLAGS_DIRECTIONAL)
    {
        for (i = 0; i < _DirectionalLightCount; ++i)
        {
            if (IsMatchingLightLayer(_DirectionalLightDatas[i].lightLayers, builtinData.renderingLayers))
            {
                DirectLighting lighting = EvaluateBSDF_Directional(context, V, posInput, preLightData, _DirectionalLightDatas[i], bsdfData, builtinData);
                AccumulateDirectLighting(lighting, aggregateLighting);
            }
        }
    }

#if !defined(_SURFACE_TYPE_TRANSPARENT)
    // If we use the texture ssgi for ssgi or rtgi, we want to combine it with the value in the bake diffuse lighting value
    if (_IndirectDiffuseMode != INDIRECTDIFFUSEMODE_OFF)
    {
        BuiltinData builtinDataSSGI;
        ZERO_INITIALIZE(BuiltinData, builtinDataSSGI);
        builtinDataSSGI.bakeDiffuseLighting = LOAD_TEXTURE2D_X(_IndirectDiffuseTexture, posInput.positionSS).xyz * GetInverseCurrentExposureMultiplier();
        builtinDataSSGI.bakeDiffuseLighting *= GetIndirectDiffuseMultiplier(builtinData.renderingLayers);

        // TODO: try to see if we can share code with probe volume
#ifdef MODIFY_BAKED_DIFFUSE_LIGHTING
#ifdef DEBUG_DISPLAY
        // When the lux meter is enabled, we don't want the albedo of the material to modify the diffuse baked lighting
        if (_DebugLightingMode != DEBUGLIGHTINGMODE_LUX_METER)
#endif
            ModifyBakedDiffuseLighting(V, posInput, preLightData, bsdfData, builtinDataSSGI);

#endif
        builtinData.bakeDiffuseLighting = builtinDataSSGI.bakeDiffuseLighting + builtinData.bakeDiffuseLighting;

        // In the alpha channel, we have the interpolation value that we use to blend the result of SSGI/RTGI with the other GI thechnique
      //  builtinData.bakeDiffuseLighting = lerp(builtinData.bakeDiffuseLighting,
      //                                      builtinDataSSGI.bakeDiffuseLighting,
       //                                     LOAD_TEXTURE2D_X(_IndirectDiffuseTexture, posInput.positionSS).w);
    }
#endif

    // Note: We can't apply the IndirectDiffuseMultiplier here as with GBuffer, Emissive is part of the bakeDiffuseLighting.
    // so IndirectDiffuseMultiplier is apply in PostInitBuiltinData or related location (like for probe volume)
    aggregateLighting.indirect.specularReflected *= GetIndirectSpecularMultiplier(builtinData.renderingLayers);

    // Also Apply indiret diffuse (GI)
    // PostEvaluateBSDF will perform any operation wanted by the material and sum everything into diffuseLighting and specularLighting
    PostEvaluateBSDF(   context, V, posInput, preLightData, bsdfData, builtinData, aggregateLighting, lightLoopOutput);
}
