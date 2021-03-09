#ifndef UNITY_LIGHT_EVALUATION_INCLUDED
#define UNITY_LIGHT_EVALUATION_INCLUDED

 #pragma warning (disable : 3571)

// This files include various function uses to evaluate lights
// use #define LIGHT_EVALUATION_NO_HEIGHT_FOG to disable Height fog attenuation evaluation
// use #define LIGHT_EVALUATION_NO_COOKIE to disable cookie evaluation
// use #define LIGHT_EVALUATION_NO_CONTACT_SHADOWS to disable contact shadow evaluation
// use #define LIGHT_EVALUATION_NO_SHADOWS to disable evaluation of shadow including contact shadow (but not micro shadow)
// use #define OVERRIDE_EVALUATE_ENV_INTERSECTION to provide a new version of EvaluateLight_EnvIntersection

// Samples the area light's associated cookie
//  cookieIndex, the index of the cookie texture in the Texture2DArray
//  L, the 4 local-space corners of the area light polygon transformed by the LTC M^-1 matrix
//  F, the *normalized* vector irradiance
float3 SampleAreaLightCookie(float4 cookieScaleOffset, float4x3 L, float3 F)
{
    // L[0..3] : LL UL UR LR

    float3  origin = L[0];
    float3  right = L[3] - origin;
    float3  up = L[1] - origin;

    float3  normal = cross(right, up);
    float   sqArea = dot(normal, normal);
    normal *= rsqrt(sqArea);

    // Compute intersection of irradiance vector with the area light plane
    float   hitDistance = dot(origin, normal) / dot(F, normal);
    float3  hitPosition = hitDistance * normal;
    hitPosition -= origin;  // Relative to bottom-left corner

    // Here, right and up vectors are not necessarily orthonormal
    // We create the orthogonal vector "ortho" by projecting "up" onto the vector orthogonal to "right"
    //  ortho = up - (up.right') * right'
    // Where right' = right / sqrt( dot( right, right ) ), the normalized right vector
    float   recSqLengthRight = 1.0 / dot(right, right);
    float   upRightMixing = dot(up, right);
    float3  ortho = up - upRightMixing * right * recSqLengthRight;

    // The V coordinate along the "up" vector is simply the projection against the ortho vector
    float   v = dot(hitPosition, ortho) / dot(ortho, ortho);

    // The U coordinate is not only the projection against the right vector
    //  but also the subtraction of the influence of the up vector upon the right vector
    //  (indeed, if the up & right vectors are not orthogonal then a certain amount of
    //  the up coordinate also influences the right coordinate)
    //
    //       |    up
    // ortho ^....*--------*
    //       |   /:       /
    //       |  / :      /
    //       | /  :     /
    //       |/   :    /
    //       +----+-->*----->
    //            : right
    //          mix of up into right that needs to be subtracted from simple projection on right vector
    //
    float   u = (dot(hitPosition, right) - upRightMixing * v) * recSqLengthRight;
    // We create automatic quad emissive mesh for area light. For those to be displayed in the direction
    // of the light when they are single sided, we need to reverse the winding order.
    // Because of this reverse of winding order, to get a matching area light reflection,
    // we need to flip the x axis.
    float2  hitUV = float2(1 - u, v);

    // Assuming the original cosine lobe distribution Do is enclosed in a cone of 90 deg  aperture,
    //  following the idea of orthogonal projection upon the area light's plane we find the intersection
    //  of the cone to be a disk of area PI*d^2 where d is the hit distance we computed above.
    // We also know the area of the transformed polygon A = sqrt( sqArea ) and we pose the ratio of covered area as PI.d^2 / A.
    //
    // Knowing the area in square texels of the cookie texture A_sqTexels = texture width * texture height (default is 128x128 square texels)
    //  we can deduce the actual area covered by the cone in square texels as:
    //  A_covered = Pi.d^2 / A * A_sqTexels
    //
    // From this, we find the mip level as: mip = log2( sqrt( A_covered ) ) = log2( A_covered ) / 2
    // Also, assuming that A_sqTexels is of the form 2^n * 2^n we get the simplified expression: mip = log2( Pi.d^2 / A ) / 2 + n
    //
    // Compute the cookie mip count using the cookie size in the atlas
    float   cookieWidth = cookieScaleOffset.x * _CookieAtlasSize.x; // cookies and atlas are guaranteed to be POT
    float   cookieMipCount = round(log2(cookieWidth));
    float   mipLevel = 0.5 * log2(1e-8 + PI * hitDistance*hitDistance * rsqrt(sqArea)) + cookieMipCount;
    mipLevel = clamp(mipLevel, 0, cookieMipCount);

    return SampleCookie2D(saturate(hitUV), cookieScaleOffset, mipLevel);
}

// This function transforms a rectangular area light according the the barn door inputs defined by the user.
void RectangularLightApplyBarnDoor(inout LightData lightData, float3 pointPosition)
{
    // If we are above 89° or the depth is smaller than 5cm this is not worth it.
    if (lightData.size.z > 0.017f && lightData.size.w > 0.05f)
    {
        // Compute the half size of the light source
        float halfWidth  = lightData.size.x * 0.5;
        float halfHeight = lightData.size.y * 0.5;

        // Transform the point to light source space. First position then orientation
        float3 lightRelativePointPos = -(lightData.positionRWS - pointPosition);
        float3 pointLS = float3(dot(lightRelativePointPos, lightData.right), dot(lightRelativePointPos, lightData.up), dot(lightRelativePointPos, lightData.forward));

        // Compute the depth of the point in the pyramid space
        float pointDepth = min(pointLS.z, lightData.size.z * lightData.size.w);

        // Compute the ratio between the point's depth and the maximal depth of the pyramid
        float pointDepthRatio = pointDepth / (lightData.size.z * lightData.size.w);
        float sinTheta = sqrt(1 - max(0, lightData.size.z * lightData.size.z));

        // Compute the barn door projection
        float barnDoorProjection = sinTheta * lightData.size.w * pointDepthRatio;

        // Compute the sign of the point when in the local light space
        float2 pointSign = sign(pointLS.xy);
        // Clamp the point to the closest edge
        pointLS.xy = float2(pointSign.x, pointSign.y) * max(abs(pointLS.xy), float2(halfWidth, halfHeight) + barnDoorProjection.xx);

        // Compute the closest rect lignt corner, offset by the barn door size
        float3 closestLightCorner = float3(pointSign.x * (halfWidth + barnDoorProjection), pointSign.y * (halfHeight + barnDoorProjection), pointDepth);

        // Compute the point projection onto the edge and deduce the size that should be removed from the light dimensions
        float3 pointProjection  = pointLS - closestLightCorner;
        // Phi being the angle between the point projection point and the forward vector of the light source
        float  cosPhi = max(0, pointProjection.z);
        // If the angle is too perpendicular, we make the point infinitely far
        float2 tanPhi = cosPhi > 0.001f ? abs(pointProjection.xy) / cosPhi : 99999.0f;
        float2 projectionDistance = pointDepth * tanPhi;

        // Compute the positions of the new vertices of the culled light
        float2 topRight = float2(-halfWidth, halfWidth);
        float2 bottomLeft = float2(-halfHeight, halfHeight);
        topRight += (projectionDistance.x - barnDoorProjection) * float2(max(0, -pointSign.x), -max(0, pointSign.x));
        bottomLeft += (projectionDistance.y - barnDoorProjection) * float2(max(0, -pointSign.y), -max(0, pointSign.y));
        topRight = clamp(topRight, -halfWidth, halfWidth);
        bottomLeft = clamp(bottomLeft, -halfHeight, halfHeight);

        // Compute the offset that needs to be applied to the origin points to match the culling of the barn door
        float2 lightCenterOffset = 0.5f * float2(topRight.x + topRight.y, bottomLeft.x + bottomLeft.y);

        // Change the input data of the light to adjust the rectangular area light
        lightData.size.xy = float2(topRight.y - topRight.x, bottomLeft.y - bottomLeft.x);
        lightData.positionRWS = lightData.positionRWS + lightData.right * lightCenterOffset.x + lightData.up * lightCenterOffset.y;
    }
}

//-----------------------------------------------------------------------------
// Directional Light evaluation helper
//-----------------------------------------------------------------------------

uniform half4		_Azure_DynamicCloudLayer1Direction, _Azure_DynamicCloudLayer1Color1, _Azure_DynamicCloudLayer1Color2;
uniform half        _Azure_DynamicCloudLayer1Altitude, _Azure_DynamicCloudLayer1Density, _DynamicLightningColor, _Azure_Exposure;

TEXTURE2D(_Azure_CloudNoise);
SAMPLER(sampler_Azure_CloudNoise);

float3 EvaluateCookie_Directional(LightLoopContext lightLoopContext, DirectionalLightData light,
                                  float3 lightToSample)
{
    lightToSample.xz *= 0.002;
    float2 positionNDC = lightToSample.xz*0.5 + 0.5;

    float2 CloudPos = lightToSample.xz * 0.08 * _Azure_DynamicCloudLayer1Altitude;
    float2 cloudSpeed = _Azure_DynamicCloudLayer1Direction.xy;
    float4 tex1 = SAMPLE_TEXTURE2D_LOD(_Azure_CloudNoise, sampler_Azure_CloudNoise, CloudPos.xy * 0.25 - 0.005 + cloudSpeed, 0);
    float4 tex2 = SAMPLE_TEXTURE2D_LOD(_Azure_CloudNoise, sampler_Azure_CloudNoise, CloudPos.xy * 0.35 -0.0065 + cloudSpeed, 0);

    float noise1 = pow(tex1.g + tex2.g*2 * tex2.r, 0.2);
    float noise2 = pow(tex2.b * tex1.r*2 , 0.5);

    const float3 W = float3(0.2125, 0.7154, 0.0721);
    float cloudopacity = (dot(_Azure_DynamicCloudLayer1Color1.rgb,W) * dot(_Azure_DynamicCloudLayer1Color2.rgb,W))*0.03;

    float mixCloud = noise1 * noise2 * (1.35-_Azure_DynamicCloudLayer1Density) + (_Azure_DynamicCloudLayer1Density-0.5)*1.75;
    return lerp(cloudopacity,1,smoothstep(1,0,saturate(mixCloud)));
}

// Returns unassociated (non-premultiplied) color with alpha (attenuation).
// The calling code must perform alpha-compositing.
float4 EvaluateLight_Directional(LightLoopContext lightLoopContext, PositionInputs posInput,
                                 DirectionalLightData light)
{
    float4 color = float4(light.color, 1.0);

    float3 L = -light.forward;

#ifndef LIGHT_EVALUATION_NO_HEIGHT_FOG
    // Height fog attenuation.
    {
        // TODO: should probably unify height attenuation somehow...
        float  cosZenithAngle = L.y;
        float  fragmentHeight = posInput.positionWS.y;
        float3 oDepth = OpticalDepthHeightFog(_HeightFogBaseExtinction, _HeightFogBaseHeight,
                                              _HeightFogExponents, cosZenithAngle, fragmentHeight);
        // Cannot do this once for both the sky and the fog because the sky may be desaturated. :-(
        float3 transm = TransmittanceFromOpticalDepth(oDepth);
        color.rgb *= transm;
    }
#endif


    float3 lightToSample =  posInput.positionWS - light.positionRWS;
    float3 cookie = EvaluateCookie_Directional(lightLoopContext, light, lightToSample);
    color.rgb *= cookie;

    return color;
}

SHADOW_TYPE EvaluateShadow_Directional( LightLoopContext lightLoopContext, PositionInputs posInput,
                                        DirectionalLightData light, BuiltinData builtinData, float3 N)
{
#ifndef LIGHT_EVALUATION_NO_SHADOWS
    SHADOW_TYPE shadow  = 1.0;
    if ((light.shadowIndex >= 0) && (light.shadowDimmer > 0))
    {
        shadow = lerp(1, lightLoopContext.shadowValue, light.shadowDimmer);
    }

    return shadow;
#else // LIGHT_EVALUATION_NO_SHADOWS
    return 1.0;
#endif
}

//-----------------------------------------------------------------------------
// Punctual Light evaluation helper
//-----------------------------------------------------------------------------

#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/PunctualLightCommon.hlsl"

float4 EvaluateCookie_Punctual(LightLoopContext lightLoopContext, LightData light,
                               float3 lightToSample)
{
#ifndef LIGHT_EVALUATION_NO_COOKIE
    int lightType = light.lightType;

    // Translate and rotate 'positionWS' into the light space.
    // 'light.right' and 'light.up' are pre-scaled on CPU.
    float3x3 lightToWorld = float3x3(light.right, light.up, light.forward);
    float3   positionLS   = mul(lightToSample, transpose(lightToWorld));

    float4 cookie;

    UNITY_BRANCH if (lightType == GPULIGHTTYPE_POINT)
    {
        cookie.rgb = SamplePointCookie(mul(lightToWorld, lightToSample), light.cookieScaleOffset);
        cookie.a   = 1;
    }
    else
    {
        // Perform orthographic or perspective projection.
        float  perspectiveZ = (lightType != GPULIGHTTYPE_PROJECTOR_BOX) ? positionLS.z : 1.0;
        float2 positionCS   = positionLS.xy / perspectiveZ;

        float z = positionLS.z;
        float r = light.range;

        // Box lights have no range attenuation, so we must clip manually.
        bool isInBounds = Max3(abs(positionCS.x), abs(positionCS.y), abs(z - 0.5 * r) - 0.5 * r + 1) <= light.boxLightSafeExtent;
        if (lightType != GPULIGHTTYPE_PROJECTOR_PYRAMID && lightType != GPULIGHTTYPE_PROJECTOR_BOX)
        {
            isInBounds = isInBounds && (dot(positionCS, positionCS) <= light.iesCut * light.iesCut);
        }

        float2 positionNDC = positionCS * 0.5 + 0.5;

        // Manually clamp to border (black).
        cookie.rgb = SampleCookie2D(positionNDC, light.cookieScaleOffset);
        cookie.a   = isInBounds ? 1.0 : 0.0;
    }

#else

    // When we disable cookie, we must still perform border attenuation for pyramid and box
    // as by default we always bind a cookie white texture for them to mimic it.
    float4 cookie = float4(1.0, 1.0, 1.0, 1.0);

    int lightType = light.lightType;

    if (lightType == GPULIGHTTYPE_PROJECTOR_PYRAMID || lightType == GPULIGHTTYPE_PROJECTOR_BOX)
    {
        // Translate and rotate 'positionWS' into the light space.
        // 'light.right' and 'light.up' are pre-scaled on CPU.
        float3x3 lightToWorld = float3x3(light.right, light.up, light.forward);
        float3 positionLS     = mul(lightToSample, transpose(lightToWorld));

        // Perform orthographic or perspective projection.
        float  perspectiveZ = (lightType != GPULIGHTTYPE_PROJECTOR_BOX) ? positionLS.z : 1.0;
        float2 positionCS   = positionLS.xy / perspectiveZ;

        float z = positionLS.z;
        float r = light.range;

        // Box lights have no range attenuation, so we must clip manually.
        bool isInBounds = Max3(abs(positionCS.x), abs(positionCS.y), abs(z - 0.5 * r) - 0.5 * r + 1) <= light.boxLightSafeExtent;

        // Manually clamp to border (black).
        cookie.a = isInBounds ? 1.0 : 0.0;
    }
#endif

    return cookie;
}

// Returns unassociated (non-premultiplied) color with alpha (attenuation).
// The calling code must perform alpha-compositing.
// distances = {d, d^2, 1/d, d_proj}, where d_proj = dot(lightToSample, light.forward).
float4 EvaluateLight_Punctual(LightLoopContext lightLoopContext, PositionInputs posInput,
    LightData light, float3 L, float4 distances)
{
    float4 color = float4(light.color, 1.0);

    color.a *= PunctualLightAttenuation(distances, light.rangeAttenuationScale, light.rangeAttenuationBias,
                                        light.angleScale, light.angleOffset);

#ifndef LIGHT_EVALUATION_NO_HEIGHT_FOG
    // Height fog attenuation.
    // TODO: add an if()?
    {
        float cosZenithAngle = L.y;
        float distToLight = (light.lightType == GPULIGHTTYPE_PROJECTOR_BOX) ? distances.w : distances.x;
        float fragmentHeight = posInput.positionWS.y;
        color.a *= TransmittanceHeightFog(_HeightFogBaseExtinction, _HeightFogBaseHeight,
                                          _HeightFogExponents, cosZenithAngle,
                                          fragmentHeight, distToLight);
    }
#endif

    // Projector lights (box, pyramid) always have cookies, so we can perform clipping inside the if().
    // Thus why we don't disable the code here based on LIGHT_EVALUATION_NO_COOKIE but we do it
    // inside the EvaluateCookie_Punctual call
    if (light.cookieMode != COOKIEMODE_NONE)
    {
        float3 lightToSample = posInput.positionWS - light.positionRWS;
        float4 cookie = EvaluateCookie_Punctual(lightLoopContext, light, lightToSample);

        color *= cookie;
    }

    return color;
}

// distances = {d, d^2, 1/d, d_proj}, where d_proj = dot(lightToSample, light.forward).
SHADOW_TYPE EvaluateShadow_Punctual(LightLoopContext lightLoopContext, PositionInputs posInput,
                                    LightData light, BuiltinData builtinData, float3 N, float3 L, float4 distances)
{
#ifndef LIGHT_EVALUATION_NO_SHADOWS
    float shadow        = 1.0;
    float shadowMask    = 1.0;
    if ((light.shadowIndex >= 0) && (light.shadowDimmer > 0))
    {
        shadow = GetPunctualShadowAttenuation(lightLoopContext.shadowContext, posInput.positionSS, posInput.positionWS, N, light.shadowIndex, L, distances.x, light.lightType == GPULIGHTTYPE_POINT, light.lightType != GPULIGHTTYPE_PROJECTOR_BOX);
        shadow = lerp(shadowMask, shadow, light.shadowDimmer);
    }


#ifdef DEBUG_DISPLAY
    if (_DebugShadowMapMode == SHADOWMAPDEBUGMODE_SINGLE_SHADOW && light.shadowIndex == _DebugSingleShadowIndex)
        g_DebugShadowAttenuation = shadow;
#endif
    return shadow;
#else // LIGHT_EVALUATION_NO_SHADOWS
    return 1.0;
#endif
}


SHADOW_TYPE EvaluateShadow_RectArea( LightLoopContext lightLoopContext, PositionInputs posInput,
                                     LightData light, BuiltinData builtinData, float3 N, float3 L, float dist)
{
#ifndef LIGHT_EVALUATION_NO_SHADOWS
    float shadow        = 1.0;
    float shadowMask    = 1.0;
    float NdotL         = dot(N, L); // Disable contact shadow and shadow mask when facing away from light (i.e transmission)

#ifdef SHADOWS_SHADOWMASK
    // shadowMaskSelector.x is -1 if there is no shadow mask
    // Note that we override shadow value (in case we don't have any dynamic shadow)
    shadow = shadowMask = (light.shadowMaskSelector.x >= 0.0 && NdotL > 0.0) ? dot(BUILTIN_DATA_SHADOW_MASK, light.shadowMaskSelector) : 1.0;
#endif

#if defined(SCREEN_SPACE_SHADOWS_ON) && !defined(_SURFACE_TYPE_TRANSPARENT)
    if ((light.screenSpaceShadowIndex & SCREEN_SPACE_SHADOW_INDEX_MASK) != INVALID_SCREEN_SPACE_SHADOW)
    {
        shadow = GetScreenSpaceShadow(posInput, light.screenSpaceShadowIndex);
    }
    else
#endif
    if ((light.shadowIndex >= 0) && (light.shadowDimmer > 0))
    {
        shadow = GetRectAreaShadowAttenuation(lightLoopContext.shadowContext, posInput.positionSS, posInput.positionWS, N, light.shadowIndex, L, dist);

#ifdef SHADOWS_SHADOWMASK
        // See comment for punctual light shadow mask
        shadow = light.nonLightMappedOnly ? min(shadowMask, shadow) : shadow;
#endif
        shadow = lerp(shadowMask, shadow, light.shadowDimmer);
    }

#ifdef DEBUG_DISPLAY
    if (_DebugShadowMapMode == SHADOWMAPDEBUGMODE_SINGLE_SHADOW && light.shadowIndex == _DebugSingleShadowIndex)
        g_DebugShadowAttenuation = shadow;
#endif
    return shadow;
#else // LIGHT_EVALUATION_NO_SHADOWS
    return 1.0;
#endif
}

//-----------------------------------------------------------------------------
// Reflection probe evaluation helper
//-----------------------------------------------------------------------------

#ifndef OVERRIDE_EVALUATE_ENV_INTERSECTION
// Environment map share function
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/Reflection/VolumeProjection.hlsl"

// From Moving Frostbite to PBR document
// This function fakes the roughness based integration of reflection probes by adjusting the roughness value
float ComputeDistanceBaseRoughness(float distIntersectionToShadedPoint, float distIntersectionToProbeCenter, float perceptualRoughness)
{
    float newPerceptualRoughness = clamp(distIntersectionToShadedPoint / distIntersectionToProbeCenter * perceptualRoughness, 0, perceptualRoughness);
    return lerp(newPerceptualRoughness, perceptualRoughness, perceptualRoughness);
}

// return projectionDistance, can be used in ComputeDistanceBaseRoughness formula
// return in R the unormalized corrected direction which is used to fetch cubemap but also its length represent the distance of the capture point to the intersection
// Length R can be reuse as a parameter of ComputeDistanceBaseRoughness for distIntersectionToProbeCenter
float EvaluateLight_EnvIntersection(float3 positionWS, float3 normalWS, EnvLightData light, int influenceShapeType, inout float3 R, inout float weight)
{
    // Guideline for reflection volume: In HDRenderPipeline we separate the projection volume (the proxy of the scene) from the influence volume (what pixel on the screen is affected)
    // However we add the constrain that the shape of the projection and influence volume is the same (i.e if we have a sphere shape projection volume, we have a shape influence).
    // It allow to have more coherence for the dynamic if in shader code.
    // Users can also chose to not have any projection, in this case we use the property minProjectionDistance to minimize code change. minProjectionDistance is set to huge number
    // that simulate effect of no shape projection

    float3x3 worldToIS = WorldToInfluenceSpace(light); // IS: Influence space
    float3 positionIS = WorldToInfluencePosition(light, worldToIS, positionWS);
    float3 dirIS = normalize(mul(R, worldToIS));

    float3x3 worldToPS = WorldToProxySpace(light); // PS: Proxy space
    float3 positionPS = WorldToProxyPosition(light, worldToPS, positionWS);
    float3 dirPS = mul(R, worldToPS);

    float projectionDistance = 0;

    // Process the projection
    // In Unity the cubemaps are capture with the localToWorld transform of the component.
    // This mean that location and orientation matter. So after intersection of proxy volume we need to convert back to world.
    if (influenceShapeType == ENVSHAPETYPE_SPHERE)
    {
        projectionDistance = IntersectSphereProxy(light, dirPS, positionPS);
        // We can reuse dist calculate in LS directly in WS as there is no scaling. Also the offset is already include in light.capturePositionRWS
        R = (positionWS + projectionDistance * R) - light.capturePositionRWS;

        weight = InfluenceSphereWeight(light, normalWS, positionWS, positionIS, dirIS);
    }
    else if (influenceShapeType == ENVSHAPETYPE_BOX)
    {
        projectionDistance = IntersectBoxProxy(light, dirPS, positionPS);
        // No need to normalize for fetching cubemap
        // We can reuse dist calculate in LS directly in WS as there is no scaling. Also the offset is already include in light.capturePositionRWS
        R = (positionWS + projectionDistance * R) - light.capturePositionRWS;

        weight = InfluenceBoxWeight(light, normalWS, positionWS, positionIS, dirIS);
    }

    // Smooth weighting
    weight = Smoothstep01(weight);
    weight *= light.weight;

    return projectionDistance;
}

// Call SampleEnv function with distance based roughness
float4 SampleEnvWithDistanceBaseRoughness(LightLoopContext lightLoopContext, PositionInputs posInput, EnvLightData lightData, float3 R, float perceptualRoughness, float intersectionDistance, int sliceIdx = 0)
{
    return SampleEnv(lightLoopContext, lightData.envIndex, R, PerceptualRoughnessToMipmapLevel(perceptualRoughness) * lightData.roughReflections, lightData.rangeCompressionFactorCompensation, posInput.positionNDC, sliceIdx);
}

void InversePreExposeSsrLighting(inout float4 ssrLighting)
{
    // Raytrace reflection use the current frame exposure - TODO: currently the buffer don't use pre-exposure.
    // Screen space reflection reuse color buffer from previous frame
    float exposureMultiplier = _EnableRayTracedReflections ? 1.0 : GetInversePreviousExposureMultiplier();
    ssrLighting.rgb *= exposureMultiplier;
}

void ApplyScreenSpaceReflectionWeight(inout float4 ssrLighting)
{
    // Note: RGB is already premultiplied by A for SSR
    // TODO: check why it isn't consistent between SSR and RTR
    float weight = _EnableRayTracedReflections ? 1.0 : ssrLighting.a;
    ssrLighting.rgb *= ssrLighting.a;
}
#endif

#endif // UNITY_LIGHT_EVALUATION_INCLUDED
