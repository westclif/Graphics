real3 ADD_FUNC_SUFFIX(ADD_NORMAL_FUNC_SUFFIX(SampleUVMappingNormal))(TEXTURE2D_PARAM(textureName, samplerName), UVMapping uvMapping, real scale, real param)
{
    return UNPACK_NORMAL_FUNC(SAMPLE_TEXTURE_FUNC(textureName, samplerName, uvMapping.uv, param), scale);
}
