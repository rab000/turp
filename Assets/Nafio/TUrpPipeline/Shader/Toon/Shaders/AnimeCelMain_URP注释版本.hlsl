#ifndef STAR_ANIMECELMAIN_URP_INCLUDED
#define STAR_ANIMECELMAIN_URP_INCLUDED

#include "AnimeCelInput.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

// appdata
struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT;
    float2 texcoord     : TEXCOORD0;
    float2 lightmapUV   : TEXCOORD1;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

// v2f
struct Varyings
{
	float2 uv                       : TEXCOORD0;
    DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1); // no lightmap

#ifdef _ADDITIONAL_LIGHTS
    float3 positionWS               : TEXCOORD2;
#endif

#ifdef _NORMALMAP
    float4 normalWS                 : TEXCOORD3;    // xyz: normal, w: viewDir.x
    float4 tangentWS                : TEXCOORD4;    // xyz: tangent, w: viewDir.y
    float4 bitangentWS              : TEXCOORD5;    // xyz: bitangent, w: viewDir.z
#else
    float3 normalWS                 : TEXCOORD3;
    float3 viewDirWS                : TEXCOORD4;
#endif

    half4 fogFactorAndVertexLight   : TEXCOORD6; // x: fogFactor, yzw: vertex light

#ifdef _MAIN_LIGHT_SHADOWS
    float4 shadowCoord              : TEXCOORD7;
#endif

    float4 positionCS               : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

struct CelData
{
    half3 diffuse; // diffuse Color;
    half3 specular; // Speclor Color;
    half3 rim; // rimColor;
};

struct CelSurfaceData
{
    half4 mainTexCol;
    half4 shadowTexCol;
    half4 shadowMaskCol;
    float brightOffset;
    half3 brightCol;
    half3 darkCol;
};

void InitializeInputData(Varyings input, half3 normalTS, out InputData inputData)
{
    inputData = (InputData)0;

#ifdef _ADDITIONAL_LIGHTS
    inputData.positionWS = input.positionWS;
#endif

#ifdef _NORMALMAP
    half3 viewDirWS = half3(input.normalWS.w, input.tangentWS.w, input.bitangentWS.w);
    inputData.normalWS = TransformTangentToWorld(normalTS,
        half3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz));
#else
    half3 viewDirWS = input.viewDirWS;
    inputData.normalWS = input.normalWS;
#endif

    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    viewDirWS = SafeNormalize(viewDirWS);

    inputData.viewDirectionWS = viewDirWS;
#if defined(_MAIN_LIGHT_SHADOWS) && !defined(_RECEIVE_SHADOWS_OFF)
    inputData.shadowCoord = input.shadowCoord;
#else
    inputData.shadowCoord = float4(0, 0, 0, 0);
#endif
    inputData.fogCoord = input.fogFactorAndVertexLight.x;
    inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
    inputData.bakedGI = SAMPLE_GI(input.lightmapUV, input.vertexSH, inputData.normalWS);
}

void InitializeSurfaceData(float2 uv, out CelSurfaceData outSurfaceData)
{
    outSurfaceData.mainTexCol = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
    outSurfaceData.shadowTexCol = SAMPLE_TEXTURE2D(_ShadowTex, sampler_ShadowTex, uv);
    outSurfaceData.shadowMaskCol = SAMPLE_TEXTURE2D(_ShadowMaskTex, sampler_ShadowMaskTex, uv);
    //ninfo这个被设置成了0，暂时没用到，后面再看是做什么用的
    //_ShadowMaskTexBlueAsBrightOffset描述sm b通道参与brightOffset的程度
    //_SMTBlueBrightOffsetScale，_ShadowMaskTexBlueAsBrightOffset两个都修正了outSurfaceData.shadowMaskCol.b对brightOffset的贡献，感觉可以省掉一个
    //从后面看，在计算阴影时，这个brightOffset参与了，作用可以认为是用sm 的b通道能消除不想显示阴影的位置
    outSurfaceData.brightOffset = lerp(0, outSurfaceData.shadowMaskCol.b * _SMTBlueBrightOffsetScale, _ShadowMaskTexBlueAsBrightOffset);
    //ninfo dark好理解，bright是什么呢，就是非阴影部分
    outSurfaceData.brightCol = lerp(outSurfaceData.mainTexCol.rgb, outSurfaceData.mainTexCol.rgb * _BaseColor.rgb, _BaseColor.a);
    outSurfaceData.darkCol = lerp(outSurfaceData.shadowTexCol.rgb, outSurfaceData.shadowTexCol.rgb * _ShadowColor.rgb, _ShadowColor.a);
}

half4 AnimeCelFragToon(Light light, CelSurfaceData surfaceData, InputData inputData, out CelData outCelData, float isMainLight = 1)
{
    float3 N = inputData.normalWS;
    float3 V = inputData.viewDirectionWS;
	float NdotV = dot(N, V);

    float3 L = light.direction;
    //ninfo 半角向量与N差异越大反射越强，billinPhong替代phong的就是用的这个
    float3 H = normalize(L + V);
    float NdotL = dot(N, L);
    float NdotH = dot(N, H);

    half4 color = surfaceData.mainTexCol;
    half3 lightColor = light.color * light.distanceAttenuation;

    //ninfo 这里g是ao遮罩
    // 1. Base & Dark Cel color calculation
    // half lambert
	// NdotL from [-1, 1] --> [0, 1]
	float hlNdotL = saturate(0.5 * (NdotL + (surfaceData.shadowMaskCol.g - 1.0)) + 0.5);

    //ninfo _SysShadowValue为计算出的阴影衰减计算出了一个最小衰减值
    //light.shadowAttenuation可以理解为灯光远近导致的阴影的自然衰减
    float shadowAtten = clamp(light.shadowAttenuation, 1 - _SysShadowValue, 1);

    //ninfo 离散的关键，这里的attenNdot意义为
    //hlNdotL法线方向如果背离光方向，那么阴影肯定更强，反正更弱
    //后面的surfaceData.brightOffset使用shadowMask.b对阴影做一次修正，比如脸部不想显示阴影就可以不显示
    //所以这里的attenNdotL也就是经过hlNdotL加权的一个阴影衰减值
	float attenNdotL = saturate(hlNdotL * shadowAtten + surfaceData.brightOffset);
    //ninfo 这里跟brightOffset的计算方式一致
    //_ShadowMaskTexAlphaAsShadowSoftness,_AlphaShadowSoftnessScale,这两个变量共同决定shadowMaskCol.a对baseShadowRadius的贡献
    //shadowMask.a越大，baseShadowRadius也会越大
    //baseShadowRadius阴影渐变区的宽度，这里baseShadowRadius=_BaseShadowRadius  shadowMask.a因为没sm贴图，设置为不起作用
    float baseShadowRadius = saturate(_BaseShadowRadius + lerp(0, surfaceData.shadowMaskCol.a, _ShadowMaskTexAlphaAsShadowSoftness) * lerp(1, _AlphaShadowSoftnessScale, _ShadowMaskTexAlphaAsShadowSoftness));
	
    //ninfo 对attenNdotL做进一步修正，
    //假设attenNdotL（0-1）是0.3
    //_BaseShadowThreshold=0.5 baseShadowRadius = 0.1
    //那么修正后attenNdotL就变为了0.5+0.1 * 2 * 0.3 ，变为了一个在0.5周围的值
    //调整发现_BaseShadowThreshold能决定阴影范围比例，简单说明，一个球被光照后，%50是阴影，
    //这个_BaseShadowThreshold起到的作用就是能把阴影范围扩大到%100或者缩小到%0
    attenNdotL = smoothstep(_BaseShadowThreshold - baseShadowRadius, _BaseShadowThreshold + baseShadowRadius, attenNdotL);
    outCelData.diffuse = lerp(surfaceData.darkCol, surfaceData.brightCol, attenNdotL).rgb;
    color.rgb =  outCelData.diffuse * lightColor;

    // 2. Specular
#if defined(_ENABLE_SPECULAR)
	// Highlight
	float spec = min(1.0, pow(saturate(NdotH), exp2(lerp(10, 0, _SpecularPower))));

	#if defined(_CLAMP_SPECULAR)
		float hardSpec = smoothstep(_SpecularThreshold - _SpecularRadius, _SpecularThreshold + _SpecularRadius, spec);
		#if defined(_HARD_SPECULAR)
			spec = hardSpec;
		#else
			spec *= hardSpec;
		#endif
	#endif
	outCelData.specular = _SpecularColor.rgb * spec * attenNdotL;
    color.rgb += outCelData.specular * lightColor;
#else
    outCelData.specular = half3(0, 0, 0);
#endif

    // 3. rim light will be used in forward add pass for Multi Lights RimLight Mode.
#if defined(_ENABLE_RIM_LIGHT)
    // Rim Light
	float rim = saturate(pow(saturate(1.0 - abs(NdotV)), exp2(lerp(4, 0, _RimLightPower))));

    #if defined(_CLAMP_RIM_LIGHT)
	    float hardRimLight = smoothstep(_RimLightThreshold - _RimLightRadius, _RimLightThreshold + _RimLightRadius, rim);
	    #if defined(_HARD_RIM_LIGHT)
		    rim = hardRimLight;
	    #else
		    rim *= hardRimLight;
	    #endif
    #endif

    outCelData.rim = _RimLightColor.rgb * rim * lerp(0, _BaseLightRimLightIntensity, isMainLight);
    color.rgb += lerp(outCelData.rim, outCelData.rim * lightColor, _RimLightXLightColor);
    // color.a = rim;
#else
    outCelData.rim = half3(0, 0, 0);
#endif // end of Rim Light

    return color;
}

Varyings vert(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
    half3 viewDirWS = GetCameraPositionWS() - vertexInput.positionWS;
    half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
    half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
    output.uv = TRANSFORM_TEX(input.texcoord, _MainTex);
    
#ifdef _NORMALMAP
    output.normalWS = half4(normalInput.normalWS, viewDirWS.x);
    output.tangentWS = half4(normalInput.tangentWS, viewDirWS.y);
    output.bitangentWS = half4(normalInput.bitangentWS, viewDirWS.z);
#else
    output.normalWS = NormalizeNormalPerVertex(normalInput.normalWS);
    output.viewDirWS = viewDirWS;
#endif

    OUTPUT_SH(output.normalWS.xyz, output.vertexSH); // no Lightmap, do SampleSHVertex()
    output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);

#ifdef _ADDITIONAL_LIGHTS
    output.positionWS = vertexInput.positionWS;
#endif

#if defined(_MAIN_LIGHT_SHADOWS) && !defined(_RECEIVE_SHADOWS_OFF)
    output.shadowCoord = GetShadowCoord(vertexInput);
#endif
    output.positionCS = vertexInput.positionCS;

    return output;
}

half4 frag(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    // float3 normalTS = SampleNormal(uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
    float3 normalTS = float3(0, 0, 0.5);

    CelSurfaceData surfaceData;
    InitializeSurfaceData(input.uv, surfaceData);

    InputData inputData;
    InitializeInputData(input, normalTS, inputData);
    half4 color = half4(1, 1, 1, 1);
    Light mainLight = GetMainLight(inputData.shadowCoord);

    // ToDo GlobalIllumination


    // Do mainLight Toon Lighting
    CelData celData = (CelData)0;
    color = AnimeCelFragToon(mainLight, surfaceData, inputData, celData, 1);
    half3 mainDiffuse = celData.diffuse;

#ifdef _ADDITIONAL_LIGHTS
    uint pixelLightCount = GetAdditionalLightsCount();
    for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
    {
        Light light = GetAdditionalLight(lightIndex, inputData.positionWS);
        color += AnimeCelFragToon(light, surfaceData, inputData, celData, 0);
    }
#endif

#ifdef _ADDITIONAL_LIGHTS_VERTEX
    color.rgb += inputData.vertexLighting.rgb * mainDiffuse;
#endif

    color.rgb = MixFog(color.rgb, inputData.fogCoord);
    return color;
}


#endif // STAR_ANIMECELMAIN_URP_INCLUDED