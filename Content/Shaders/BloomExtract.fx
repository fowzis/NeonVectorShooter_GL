// Pixel shader extracts the brighter areas of an image.
// This is the first step in applying a bloom postprocess.

#if OPENGL
    #define VS_SHADERMODEL vs_2_0
    #define PS_SHADERMODEL ps_2_0
#else
    #define VS_SHADERMODEL vs_5_0
    #define PS_SHADERMODEL ps_5_0
#endif

sampler TextureSampler : register(s0);

float BloomThreshold;


float4 PixelShaderFunction(float2 texCoord : TEXCOORD0) : COLOR0
{
    // Look up the original image color.
    float4 c = tex2D(TextureSampler, texCoord);

    // Adjust it to keep only values brighter than the specified threshold.
    return saturate((c - BloomThreshold) / (1 - BloomThreshold));
}


technique BloomExtract
{
    pass Pass1
    {
        //PixelShader = compile ps_2_0 PixelShaderFunction();
        PixelShader = compile PS_SHADERMODEL PixelShaderFunction();
    }
}
