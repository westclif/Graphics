void ADD_IDX(ComputeLayerTexCoord)( // Uv related parameters
                                    float2 texCoord0, float2 texCoord1, float2 texCoord2, float2 texCoord3, float4 uvMappingMask, float4 uvMappingMaskDetails,
                                    // scale and bias for base and detail + global tiling factor (for layered lit only)
                                    float2 texScale, float2 texBias, float2 texScaleDetails, float2 texBiasDetails, float additionalTiling, float linkDetailsWithBase,
                                    // parameter for planar/triplanar
                                    float3 positionRWS, float worldScale,
                                    // mapping type and output
                                    int mappingType, inout LayerTexCoord layerTexCoord)
{
    // Apply tiling options
    ADD_IDX(layerTexCoord.base).uv = texCoord0 * texScale + texBias;
}


// Caution: Duplicate from GetBentNormalTS - keep in sync!
float3 ADD_IDX(GetNormalTS)(FragInputs input, LayerTexCoord layerTexCoord, float3 detailNormalTS, float detailMask)
{
    float3 normalTS;

#ifdef _NORMALMAP_IDX
    normalTS = SAMPLE_UVMAPPING_NORMALMAP(ADD_IDX(_NormalMap), SAMPLER_NORMALMAP_IDX, ADD_IDX(layerTexCoord.base), ADD_IDX(_NormalScale));
#else
    normalTS = float3(0.0, 0.0, 1.0);
#endif

    return normalTS;
}

// Caution: Duplicate from GetNormalTS - keep in sync!
float3 ADD_IDX(GetBentNormalTS)(FragInputs input, LayerTexCoord layerTexCoord, float3 normalTS, float3 detailNormalTS, float detailMask)
{
    return normalTS;
}

// Return opacity
float ADD_IDX(GetSurfaceData)(FragInputs input, LayerTexCoord layerTexCoord, out SurfaceData surfaceData, out float3 normalTS, out float3 bentNormalTS)
{
    float3 detailNormalTS = float3(0.0, 0.0, 0.0);
    float detailMask = 0.0;
    float4 color = SAMPLE_UVMAPPING_TEXTURE2D(ADD_IDX(_BaseColorMap), ADD_ZERO_IDX(sampler_BaseColorMap), ADD_IDX(layerTexCoord.base)).rgba * ADD_IDX(_BaseColor).rgba;
    surfaceData.baseColor = color.rgb;
    float alpha = color.a;

    surfaceData.specularOcclusion = 1.0; // Will be setup outside of this function

    surfaceData.normalWS = float3(0.0, 0.0, 0.0); // Need to init this to keep quiet the compiler, but this is overriden later (0, 0, 0) so if we forget to override the compiler may comply.
    surfaceData.geomNormalWS = float3(0.0, 0.0, 0.0); // Not used, just to keep compiler quiet.

    normalTS = ADD_IDX(GetNormalTS)(input, layerTexCoord, detailNormalTS, detailMask);
    bentNormalTS = ADD_IDX(GetBentNormalTS)(input, layerTexCoord, normalTS, detailNormalTS, detailMask);

    surfaceData.perceptualSmoothness = 0;

    surfaceData.metallic = 0;
    surfaceData.ambientOcclusion = 1.0;

    surfaceData.diffusionProfileHash = 0;
    surfaceData.subsurfaceMask = 0;

    surfaceData.thickness = 0;

    // These static material feature allow compile time optimization
    surfaceData.materialFeatures = MATERIALFEATUREFLAGS_LIT_STANDARD;

#ifdef _TANGENTMAP
    #ifdef _NORMALMAP_TANGENT_SPACE_IDX // Normal and tangent use same space
    // Tangent space vectors always use only 2 channels.
    float3 tangentTS = UnpackNormalmapRGorAG(SAMPLE_UVMAPPING_TEXTURE2D(_TangentMap, sampler_TangentMap, layerTexCoord.base), 1.0);
    surfaceData.tangentWS = TransformTangentToWorld(tangentTS, input.tangentToWorld);
    #else // Object space
    // Note: There is no such a thing like triplanar with object space normal, so we call directly 2D function
    float3 tangentOS = UnpackNormalRGB(SAMPLE_TEXTURE2D(_TangentMapOS, sampler_TangentMapOS,  layerTexCoord.base.uv), 1.0);
    surfaceData.tangentWS = TransformObjectToWorldNormal(tangentOS);
    #endif
#else
    // Note we don't normalize tangentWS either with a tangentmap above or using the interpolated tangent from the TBN frame
    // as it will be normalized later with a call to Orthonormalize():
    surfaceData.tangentWS = input.tangentToWorld[0].xyz; // The tangent is not normalize in tangentToWorld for mikkt. TODO: Check if it expected that we normalize with Morten. Tag: SURFACE_GRADIENT
#endif

    surfaceData.anisotropy = 1.0;
    surfaceData.specularColor = 0;

#if HAS_REFRACTION
    if (_EnableSSRefraction)
    {
        surfaceData.ior = _Ior;
        surfaceData.transmittanceColor = _TransmittanceColor;
        surfaceData.atDistance = _ATDistance;
        // Rough refraction don't use opacity. Instead we use opacity as a transmittance mask.
        surfaceData.transmittanceMask = (1.0 - alpha);
        alpha = 1.0;
    }
    else
    {
        surfaceData.ior = 1.0;
        surfaceData.transmittanceColor = float3(1.0, 1.0, 1.0);
        surfaceData.atDistance = 1.0;
        surfaceData.transmittanceMask = 0.0;
        alpha = 1.0;
    }
#else
    surfaceData.ior = 1.0;
    surfaceData.transmittanceColor = float3(1.0, 1.0, 1.0);
    surfaceData.atDistance = 1.0;
    surfaceData.transmittanceMask = 0.0;
#endif

    surfaceData.coatMask = 0.0;
    surfaceData.iridescenceThickness = 0.0;
    surfaceData.iridescenceMask = 0.0;


    return alpha;
}
