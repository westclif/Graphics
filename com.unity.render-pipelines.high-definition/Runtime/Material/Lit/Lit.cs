using UnityEngine.Rendering.HighDefinition.Attributes;
using UnityEngine.Experimental.Rendering;

namespace UnityEngine.Rendering.HighDefinition
{
    partial class Lit : RenderPipelineMaterial
    {
        // Currently we have only one materialId (Standard GGX), so it is not store in the GBuffer and we don't test for it

        // If change, be sure it match what is done in Lit.hlsl: MaterialFeatureFlagsFromGBuffer
        // Material bit mask must match the size define LightDefinitions.s_MaterialFeatureMaskFlags value
        [GenerateHLSL(PackingRules.Exact)]
        public enum MaterialFeatureFlags
        {
            LitStandard             = 1 << 0,   // For material classification we need to identify that we are indeed use as standard material, else we are consider as sky/background element
            LitSpecularColor        = 1 << 1,   // LitSpecularColor is not use statically but only dynamically
            LitSubsurfaceScattering = 1 << 2,
            LitTransmission         = 1 << 3,
            LitAnisotropy           = 1 << 4,
            LitIridescence          = 1 << 5,
            LitClearCoat            = 1 << 6
        };

        //-----------------------------------------------------------------------------
        // SurfaceData
        //-----------------------------------------------------------------------------

        // Main structure that store the user data (i.e user input of master node in material graph)
        [GenerateHLSL(PackingRules.Exact, false, false, true, 1000)]
        public struct SurfaceData
        {
            // Standard
            [MaterialSharedPropertyMapping(MaterialSharedProperty.Albedo)]
            [SurfaceDataAttributes("Base Color", false, true, FieldPrecision.Real)]
            public Vector3 baseColor;

            [MaterialSharedPropertyMapping(MaterialSharedProperty.Normal)]
            [SurfaceDataAttributes(new string[] {"Normal", "Normal View Space"}, true, checkIsNormalized = true)]
            public Vector3 normalWS;

            [MaterialSharedPropertyMapping(MaterialSharedProperty.AmbientOcclusion)]
            [SurfaceDataAttributes("Ambient Occlusion", precision = FieldPrecision.Real)]
            public float ambientOcclusion;

            [SurfaceDataAttributes("textureRampShading")]
            public uint textureRampShading;
            [SurfaceDataAttributes("textureRampSpecular")]
            public uint textureRampSpecular;
            [SurfaceDataAttributes("textureRampRim")]
            public uint textureRampRim;
            [SurfaceDataAttributes("Reflection", precision = FieldPrecision.Real)]
            public float reflection;

            // Forward property only
            [SurfaceDataAttributes(new string[] { "Geometric Normal", "Geometric Normal View Space" }, true, precision = FieldPrecision.Real, checkIsNormalized = true)]
            public Vector3 geomNormalWS;

            [SurfaceDataAttributes("Tangent", true)]
            public Vector3 tangentWS;

            // Transparency
            // Reuse thickness from SSS

            [SurfaceDataAttributes("Index of refraction", precision = FieldPrecision.Real)]
            public float ior;
            [SurfaceDataAttributes("Transmittance Color", precision = FieldPrecision.Real)]
            public Vector3 transmittanceColor;
            [SurfaceDataAttributes("Transmittance Absorption Distance", precision = FieldPrecision.Real)]
            public float atDistance;
            [SurfaceDataAttributes("Transmittance Mask", precision = FieldPrecision.Real)]
            public float transmittanceMask;
        };

        //-----------------------------------------------------------------------------
        // BSDFData
        //-----------------------------------------------------------------------------

        [GenerateHLSL(PackingRules.Exact, false, false, true, 1050)]
        public struct BSDFData
        {
            [SurfaceDataAttributes("", false, true, FieldPrecision.Real)]
            public Vector3 diffuseColor;

            [SurfaceDataAttributes(precision = FieldPrecision.Real)]
            public float ambientOcclusion; // Caution: This is accessible only if light layer is enabled, otherwise it is 1

            [SurfaceDataAttributes(new string[] { "Normal WS", "Normal View Space" }, true, checkIsNormalized: true)]
            public Vector3 normalWS;

            public uint textureRampShading;
            public uint textureRampSpecular;
            public uint textureRampRim;

            [SurfaceDataAttributes(precision = FieldPrecision.Real)]
            public float reflection;

            // Anisotropic
            [SurfaceDataAttributes("", true)]
            public Vector3 tangentWS;

            // Forward property only
            [SurfaceDataAttributes(new string[] { "Geometric Normal", "Geometric Normal View Space" }, true, precision = FieldPrecision.Real, checkIsNormalized = true)]
            public Vector3 geomNormalWS;

            // Transparency
            [SurfaceDataAttributes(precision = FieldPrecision.Real)]
            public float ior;
        };

        //-----------------------------------------------------------------------------
        // GBuffer management
        //-----------------------------------------------------------------------------

        public override bool IsDefferedMaterial() { return true; }

        protected void GetGBufferOptions(HDRenderPipelineAsset asset, out int gBufferCount, out bool supportShadowMask, out bool supportLightLayers)
        {
            // Caution: This must be in sync with GBUFFERMATERIAL_COUNT definition in
            supportShadowMask = asset.currentPlatformRenderPipelineSettings.supportShadowMask;
            supportLightLayers = asset.currentPlatformRenderPipelineSettings.supportLightLayers;
            gBufferCount = 4 + (supportShadowMask ? 1 : 0) + (supportLightLayers ? 1 : 0);
#if ENABLE_VIRTUALTEXTURES
            gBufferCount++;
#endif
        }

        // This must return the number of GBuffer to allocate
        public override int GetMaterialGBufferCount(HDRenderPipelineAsset asset)
        {
            int gBufferCount;
            bool unused0;
            bool unused1;
            GetGBufferOptions(asset, out gBufferCount, out unused0, out unused1);

            return gBufferCount;
        }

        public override void GetMaterialGBufferDescription(HDRenderPipelineAsset asset, out GraphicsFormat[] RTFormat, out GBufferUsage[] gBufferUsage, out bool[] enableWrite)
        {
            int gBufferCount;
            bool supportShadowMask;
            bool supportLightLayers;
            GetGBufferOptions(asset, out gBufferCount, out supportShadowMask, out supportLightLayers);

            RTFormat = new GraphicsFormat[gBufferCount];
            gBufferUsage = new GBufferUsage[gBufferCount];
            enableWrite = new bool[gBufferCount];

            RTFormat[0] = GraphicsFormat.R8G8B8A8_SRGB; // Albedo sRGB / SSSBuffer
            gBufferUsage[0] = GBufferUsage.SubsurfaceScattering;
            enableWrite[0] = true;
            RTFormat[1] = GraphicsFormat.R8G8B8A8_UNorm; // Normal Buffer
            gBufferUsage[1] = GBufferUsage.Normal;
            enableWrite[1] = true;                    // normal buffer is used as RWTexture to composite decals in forward
            RTFormat[2] = GraphicsFormat.R8G8B8A8_UNorm; // Data
            gBufferUsage[2] = GBufferUsage.None;
            enableWrite[2] = true;
            RTFormat[3] = Builtin.GetLightingBufferFormat();
            gBufferUsage[3] = GBufferUsage.None;
            enableWrite[3] = true;

            #if ENABLE_VIRTUALTEXTURES
                int index = 4;
                RTFormat[index] = VTBufferManager.GetFeedbackBufferFormat();
                gBufferUsage[index] = GBufferUsage.VTFeedback;
                enableWrite[index] = false;
                index++;
            #else
                int index = 4;
            #endif

            if (supportLightLayers)
            {
                RTFormat[index] = GraphicsFormat.R8G8B8A8_UNorm;
                gBufferUsage[index] = GBufferUsage.LightLayers;
                index++;
            }

            // All buffer above are fixed. However shadow mask buffer can be setup or not depends on light in view.
            // Thus it need to be the last one, so all indexes stay the same
            if (supportShadowMask)
            {
                RTFormat[index] = Builtin.GetShadowMaskBufferFormat();
                gBufferUsage[index] = GBufferUsage.ShadowMask;
                index++;
            }
        }


        //-----------------------------------------------------------------------------
        // Init precomputed texture
        //-----------------------------------------------------------------------------

        public Lit() {}

        public override void Build(HDRenderPipelineAsset hdAsset, RenderPipelineResources defaultResources)
        {
            PreIntegratedFGD.instance.Build(PreIntegratedFGD.FGDIndex.FGD_GGXAndDisneyDiffuse);
            LTCAreaLight.instance.Build();
        }

        public override void Cleanup()
        {
            PreIntegratedFGD.instance.Cleanup(PreIntegratedFGD.FGDIndex.FGD_GGXAndDisneyDiffuse);
            LTCAreaLight.instance.Cleanup();
        }

        public override void RenderInit(CommandBuffer cmd)
        {
            PreIntegratedFGD.instance.RenderInit(PreIntegratedFGD.FGDIndex.FGD_GGXAndDisneyDiffuse, cmd);
        }

        public override void Bind(CommandBuffer cmd)
        {
            PreIntegratedFGD.instance.Bind(cmd, PreIntegratedFGD.FGDIndex.FGD_GGXAndDisneyDiffuse);
            LTCAreaLight.instance.Bind(cmd);
        }
    }
}
