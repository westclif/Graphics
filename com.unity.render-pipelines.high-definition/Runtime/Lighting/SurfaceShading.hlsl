// Continuation of LightEvaluation.hlsl.
// use #define MATERIAL_INCLUDE_TRANSMISSION to include thick transmittance evaluation
// use #define MATERIAL_INCLUDE_PRECOMPUTED_TRANSMISSION to apply pre-computed transmittance (or thin transmittance only)
// use #define OVERRIDE_SHOULD_EVALUATE_THICK_OBJECT_TRANSMISSION to provide a new version of ShouldEvaluateThickObjectTransmission
//-----------------------------------------------------------------------------
// Directional and punctual lights (infinitesimal solid angle)
//-----------------------------------------------------------------------------

//_AO3400_RampArray

TEXTURE2D_ARRAY(_AO3400_RampArray);

DirectLighting ShadeSurface_Infinitesimal(PreLightData preLightData, BSDFData bsdfData,
                                          float3 V, float3 L, float3 lightColor,
                                          float diffuseDimmer, float shadow)
{
    DirectLighting lighting;
    ZERO_INITIALIZE(DirectLighting, lighting);
//#if !defined(_SURFACE_TYPE_TRANSPARENT)
    float NdotL = saturate(dot(bsdfData.normalWS, L))  * 0.5 + 0.5;
    float3 h = normalize (L + V);
    float nh = max (0, dot (bsdfData.normalWS, h));

    lightColor *= diffuseDimmer;

    lighting.diffuse = lightColor * SAMPLE_TEXTURE2D_ARRAY_LOD(_AO3400_RampArray, s_point_clamp_sampler, float2(NdotL,0),bsdfData.textureRampShading, 0.0);

  lighting.specular = lightColor * SAMPLE_TEXTURE2D_ARRAY_LOD(_AO3400_RampArray, s_point_clamp_sampler, float2(pow (nh,  32),0),bsdfData.textureRampSpecular, 0.0);

 //    float specIndex = saturate(dot(bsdfData.normalWS,normalize(V + L)));
 //    lighting.diffuse += lightColor * SAMPLE_TEXTURE2D_ARRAY_LOD(_AO3400_RampArray, s_point_clamp_sampler, float2(specIndex,0),bsdfData.textureRampSpecular, 0.0) *2;

  //   lighting.diffuse += lightColor * SAMPLE_TEXTURE2D_ARRAY_LOD(_AO3400_RampArray, s_point_clamp_sampler, float2(xIndex,0),bsdfData.textureRampRim, 0.0) *2;
//#else
   // lighting.diffuse = lightColor * (saturate(dot(bsdfData.normalWS, L))  * 0.5 + 0.5);
//#endif
   // if (Max3(lightColor.r, lightColor.g, lightColor.b) > 0)
   // {
   //     CBSDF cbsdf = EvaluateBSDF(V, L, preLightData, bsdfData);
   //     lighting.diffuse  = cbsdf.diffR * lightColor * diffuseDimmer;
   //     lighting.specular = 0;
   // }

//lighting.diffuse = lightColor * saturate(dot(bsdfData.normalWS, L));
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
    if (light.lightDimmer > 0)
    {
        float4 lightColor = EvaluateLight_Directional(lightLoopContext, posInput, light);
        lightColor.rgb *= lightColor.a; // Composite

        SHADOW_TYPE shadow = EvaluateShadow_Directional(lightLoopContext, posInput, light, builtinData, GetNormalForShadowBias(bsdfData));
        float NdotL  = dot(bsdfData.normalWS, L); // No microshadowing when facing away from light (use for thin transmission as well)
        shadow *= NdotL >= 0.0 ? ComputeMicroShadowing(GetAmbientOcclusionForMicroShadowing(bsdfData), NdotL, _MicroShadowOpacity) : 1.0;
        lightColor.rgb *= ComputeShadowColor(shadow, light.shadowTint, light.penumbraTint);

        lighting = ShadeSurface_Infinitesimal(preLightData, bsdfData, V, L, lightColor.rgb,
                                              light.diffuseDimmer, shadow);
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
    if (light.lightDimmer > 0)
    {
        float4 lightColor = EvaluateLight_Punctual(lightLoopContext, posInput, light, L, distances);
        lightColor.rgb *= lightColor.a; // Composite

        // This code works for both surface reflection and thin object transmission.
        SHADOW_TYPE shadow = EvaluateShadow_Punctual(lightLoopContext, posInput, light, builtinData, GetNormalForShadowBias(bsdfData), L, distances);
        lightColor.rgb *= ComputeShadowColor(shadow, light.shadowTint, light.penumbraTint);

        lighting = ShadeSurface_Infinitesimal(preLightData, bsdfData, V, L, lightColor.rgb,
                                              light.diffuseDimmer, shadow);
    }

    return lighting;
}


