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

    float NdotL = saturate(dot(bsdfData.normalWS, L)) * 0.5 + 0.5;
    float3 h = normalize (L + V);
    float nh = max (0, dot (bsdfData.normalWS, h));
    float NdotV = dot(bsdfData.normalWS, V);


    //translucency https://colinbarrebrisebois.com/2012/04/09/approximating-translucency-revisited-with-simplified-spherical-gaussian/
    float fLTDistortion = 0.1; // fLTDistortion = Translucency Distortion Scale Factor
    float fLTPower = (1.35-bsdfData.translucency) * 7.0; // fLTPower = Power Factor
    float fLTScale =  3.0*bsdfData.translucency; // fLTScale = Scale Factor

    half3 vLTLight = L + bsdfData.normalWS * fLTDistortion;
  //  half fLTDot = pow(saturate(dot(V, -vLTLight)),fLTPower) * fLTScale;
  //  lighting.diffuse += lightColor * fLTDot;


  // lightColor *= SAMPLE_TEXTURE2D_ARRAY_LOD(_AO3400_RampArray, s_trilinear_clamp_sampler, float2(shadow,1),bsdfData.textureRampShading, 0.0).a;


   // lightColor *=  diffuseDimmer;

    float diffuseRim = SAMPLE_TEXTURE2D_ARRAY_LOD(_AO3400_RampArray, s_trilinear_clamp_sampler, float2(NdotL,NdotL*NdotV),bsdfData.textureRampShading, 0.0).a;
    float3 specular = SAMPLE_TEXTURE2D_ARRAY_LOD(_AO3400_RampArray, s_trilinear_clamp_sampler, float2(pow (nh,  32),1),bsdfData.textureRampShading, 0.0).rgb;
    float3 translucency = SAMPLE_TEXTURE2D_ARRAY_LOD(_AO3400_RampArray, s_trilinear_clamp_sampler, float2(saturate(dot(V, -vLTLight)),0),bsdfData.textureRampShading, 0.0).rgb;


   // float4 specRim = SAMPLE_TEXTURE2D_ARRAY_LOD(_AO3400_RampArray, s_trilinear_clamp_sampler, float2(pow (nh,  32),1.0 - NdotV),bsdfData.textureRampShading, 0.0)
   // float4 diffuseTranslucency = SAMPLE_TEXTURE2D_ARRAY_LOD(_AO3400_RampArray, s_trilinear_clamp_sampler, float2(NdotL,saturate(dot(V, -vLTLight))),bsdfData.textureRampShading, 0.0)

    lighting.diffuse = lightColor * (diffuseRim + translucency);
    lighting.specular = specular;


    lighting.specular = 0;
    lighting.diffuse = lightColor;

   // lighting.diffuse = lightColor * SAMPLE_TEXTURE2D_ARRAY_LOD(_AO3400_RampArray, s_trilinear_clamp_sampler, float2(NdotL,0),bsdfData.textureRampShading, 0.0);
   // lighting.specular = lightColor * SAMPLE_TEXTURE2D_ARRAY_LOD(_AO3400_RampArray, s_trilinear_clamp_sampler, float2(pow (nh,  32),0),bsdfData.textureRampSpecular, 0.0);


   // //rimlight
   // lighting.diffuse += lightColor * SAMPLE_TEXTURE2D_ARRAY_LOD(_AO3400_RampArray, s_trilinear_clamp_sampler, float2(1.0 - NdotV,0),bsdfData.textureRampRim, 0.0)*2;


   //translucency
   // lighting.diffuse += lightColor * SAMPLE_TEXTURE2D_ARRAY_LOD(_AO3400_RampArray, s_trilinear_clamp_sampler, float2(saturate(dot(V, -vLTLight)V,0),bsdfData.textureRampRim, 0.0)*2;

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

        SHADOW_TYPE shadow = EvaluateShadow_Directional(lightLoopContext, posInput, light, builtinData, GetNormalForShadowBias(bsdfData));
        shadow = max(shadow,light.shadowTint.r); //add the tint brightness if we ever want to use this to not have to dark shadows

        float NdotL = saturate(dot(bsdfData.normalWS, L)) * 0.5 + 0.5;

        NdotL *= shadow;

        float3 h = normalize (L + V);
        float nh = max (0, dot (bsdfData.normalWS, h));
        float NdotV = 1- saturate(dot(V,bsdfData.normalWS));

        lightColor.rgb *=light.lightDimmer;// * shadow;

        //translucency https://colinbarrebrisebois.com/2012/04/09/approximating-translucency-revisited-with-simplified-spherical-gaussian/
        float fLTDistortion = 0.1; // fLTDistortion = Translucency Distortion Scale Factor
        half3 vLTLight = L + bsdfData.normalWS * fLTDistortion;

        float diffuseRim = SAMPLE_TEXTURE2D_ARRAY_LOD(_AO3400_RampArray, s_trilinear_clamp_sampler, float2(NdotL, NdotV*NdotL),bsdfData.textureRampShading, 0.0).a;
        float3 specular = SAMPLE_TEXTURE2D_ARRAY_LOD(_AO3400_RampArray, s_trilinear_clamp_sampler, float2(pow (nh,  32),1),bsdfData.textureRampShading, 0.0).rgb;
        float3 translucency = SAMPLE_TEXTURE2D_ARRAY_LOD(_AO3400_RampArray, s_trilinear_clamp_sampler, float2(saturate(dot(V, -vLTLight)),0),bsdfData.textureRampShading, 0.0).rgb;

        lighting.diffuse = lightColor.rgb * (diffuseRim + translucency);
        lighting.specular = specular * lightColor.rgb * shadow;
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
        shadow = max(shadow,light.shadowTint.r); //add the tint brightness if we ever want to use this to not have to dark shadows

        float NdotL = saturate(dot(bsdfData.normalWS, L)) * 0.5 + 0.5;

        NdotL *= shadow;

        float3 h = normalize (L + V);
        float nh = max (0, dot (bsdfData.normalWS, h));
        float NdotV = 1- saturate(dot(V,bsdfData.normalWS));

        lightColor.rgb *=light.lightDimmer;// * shadow;

        //translucency https://colinbarrebrisebois.com/2012/04/09/approximating-translucency-revisited-with-simplified-spherical-gaussian/
        float fLTDistortion = 0.1; // fLTDistortion = Translucency Distortion Scale Factor
        half3 vLTLight = L + bsdfData.normalWS * fLTDistortion;

        float diffuseRim = SAMPLE_TEXTURE2D_ARRAY_LOD(_AO3400_RampArray, s_trilinear_clamp_sampler, float2(NdotL, NdotV*NdotL),bsdfData.textureRampShading, 0.0).a;
        float3 specular = SAMPLE_TEXTURE2D_ARRAY_LOD(_AO3400_RampArray, s_trilinear_clamp_sampler, float2(pow (nh,  32),1),bsdfData.textureRampShading, 0.0).rgb;
        float3 translucency = SAMPLE_TEXTURE2D_ARRAY_LOD(_AO3400_RampArray, s_trilinear_clamp_sampler, float2(saturate(dot(V, -vLTLight)),0),bsdfData.textureRampShading, 0.0).rgb;

        lighting.diffuse = lightColor.rgb * (diffuseRim + translucency);
        lighting.specular = specular * lightColor.rgb * shadow;
    }

    return lighting;
}


