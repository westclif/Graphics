// Continuation of LightEvaluation.hlsl.
// use #define MATERIAL_INCLUDE_TRANSMISSION to include thick transmittance evaluation
// use #define MATERIAL_INCLUDE_PRECOMPUTED_TRANSMISSION to apply pre-computed transmittance (or thin transmittance only)
// use #define OVERRIDE_SHOULD_EVALUATE_THICK_OBJECT_TRANSMISSION to provide a new version of ShouldEvaluateThickObjectTransmission
//-----------------------------------------------------------------------------
// Directional and punctual lights (infinitesimal solid angle)
//-----------------------------------------------------------------------------
DirectLighting ShadeSurface_Infinitesimal(PreLightData preLightData, BSDFData bsdfData,
                                          float3 V, float3 L, float3 lightColor,
                                          float diffuseDimmer, float specularDimmer)
{
    DirectLighting lighting;
    ZERO_INITIALIZE(DirectLighting, lighting);

    if (Max3(lightColor.r, lightColor.g, lightColor.b) > 0)
    {
        CBSDF cbsdf = EvaluateBSDF(V, L, preLightData, bsdfData);
        lighting.diffuse  = cbsdf.diffR * lightColor * diffuseDimmer;
        lighting.specular = 0;
    }

#ifdef DEBUG_DISPLAY
    if (_DebugLightingMode == DEBUGLIGHTINGMODE_LUX_METER)
    {
        // Only lighting, no BSDF.
        lighting.diffuse = lightColor * saturate(dot(bsdfData.normalWS, L));
    }
#endif

    return lighting;
}

//-----------------------------------------------------------------------------
// Directional lights
//-----------------------------------------------------------------------------

DirectLighting ShadeSurface_Directional(LightLoopContext lightLoopContext,
                                        PositionInputs posInput, BuiltinData builtinData,
                                        PreLightData preLightData, DirectionalLightData light,
                                        BSDFData bsdfData, float3 V)
{
    DirectLighting lighting;
    ZERO_INITIALIZE(DirectLighting, lighting);

    float3 L = -light.forward;

    // Is it worth evaluating the light?
    if ((light.lightDimmer > 0) && IsNonZeroBSDF(V, L, preLightData, bsdfData))
    {
        float4 lightColor = EvaluateLight_Directional(lightLoopContext, posInput, light);
        lightColor.rgb *= lightColor.a; // Composite

        SHADOW_TYPE shadow = EvaluateShadow_Directional(lightLoopContext, posInput, light, builtinData, GetNormalForShadowBias(bsdfData));
        float NdotL  = dot(bsdfData.normalWS, L); // No microshadowing when facing away from light (use for thin transmission as well)
        shadow *= NdotL >= 0.0 ? ComputeMicroShadowing(GetAmbientOcclusionForMicroShadowing(bsdfData), NdotL, _MicroShadowOpacity) : 1.0;
        lightColor.rgb *= ComputeShadowColor(shadow, light.shadowTint, light.penumbraTint);

        // Simulate a sphere/disk light with this hack.
        // Note that it is not correct with our precomputation of PartLambdaV
        // (means if we disable the optimization it will not have the
        // same result) but we don't care as it is a hack anyway.
        ClampRoughness(preLightData, bsdfData, light.minRoughness);

        lighting = ShadeSurface_Infinitesimal(preLightData, bsdfData, V, L, lightColor.rgb,
                                              light.diffuseDimmer, light.specularDimmer);
    }
    return lighting;
}

//-----------------------------------------------------------------------------
// Punctual lights
//-----------------------------------------------------------------------------
DirectLighting ShadeSurface_Punctual(LightLoopContext lightLoopContext,
                                     PositionInputs posInput, BuiltinData builtinData,
                                     PreLightData preLightData, LightData light,
                                     BSDFData bsdfData, float3 V)
{
    DirectLighting lighting;
    ZERO_INITIALIZE(DirectLighting, lighting);

    float3 L;
    float4 distances; // {d, d^2, 1/d, d_proj}
    GetPunctualLightVectors(posInput.positionWS, light, L, distances);

    // Is it worth evaluating the light?
    if ((light.lightDimmer > 0) && IsNonZeroBSDF(V, L, preLightData, bsdfData))
    {
        float4 lightColor = EvaluateLight_Punctual(lightLoopContext, posInput, light, L, distances);
        lightColor.rgb *= lightColor.a; // Composite

        // This code works for both surface reflection and thin object transmission.
        SHADOW_TYPE shadow = EvaluateShadow_Punctual(lightLoopContext, posInput, light, builtinData, GetNormalForShadowBias(bsdfData), L, distances);
        lightColor.rgb *= ComputeShadowColor(shadow, light.shadowTint, light.penumbraTint);

#ifdef DEBUG_DISPLAY
        // The step with the attenuation is required to avoid seeing the screen tiles at the end of lights because the attenuation always falls to 0 before the tile ends.
        // Note: g_DebugShadowAttenuation have been setup in EvaluateShadow_Punctual
        if (_DebugShadowMapMode == SHADOWMAPDEBUGMODE_SINGLE_SHADOW && light.shadowIndex == _DebugSingleShadowIndex)
            g_DebugShadowAttenuation *= step(FLT_EPS, lightColor.a);
#endif

        // Simulate a sphere/disk light with this hack.
        // Note that it is not correct with our precomputation of PartLambdaV
        // (means if we disable the optimization it will not have the
        // same result) but we don't care as it is a hack anyway.
        ClampRoughness(preLightData, bsdfData, light.minRoughness);

        lighting = ShadeSurface_Infinitesimal(preLightData, bsdfData, V, L, lightColor.rgb,
                                              light.diffuseDimmer, light.specularDimmer);
    }

    return lighting;
}


