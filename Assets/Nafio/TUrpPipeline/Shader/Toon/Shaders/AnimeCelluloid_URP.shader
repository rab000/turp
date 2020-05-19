Shader "Star/URP/Anime Celluloid/Base"
{
    Properties
    {
		[Enum(OFF,0,FRONT,1,BACK,2)] _CullMode("Cull Mode", int) = 0  //OFF/FRONT/BACK

		[Space]
		_Opacity("Opacity", Range(0, 1)) = 1.0

        _MainTex ("Base Texture", 2D) = "white" {}
        _ShadowTex ("Shadow Texture", 2D) = "white" {}

        _BaseColor("Base Color (Bright Area)", Color) = (1, 1, 1, 1)
        _ShadowColor("Shadow Color (Dark Area)", Color) = (1, 1, 1, 1)

        _BaseShadowThreshold("Base Shadow Threshold", Range(0, 1)) = 0.5
		_BaseShadowRadius("Base Shadow Radius", Range(0, 1)) = 0.01

        [Space]
		[ToggleOff(_RECEIVE_SHADOWS_OFF)]
		_ReceiveShadows("Receive Shadow (ON/OFF)", Int) = 1

        // 0 is not in shadow, 1 is in shadow
		_SysShadowValue("Sys Shadow Value", Range(0, 1)) = 1.0

        [Space]
		[Toggle(_ENABLE_SPECULAR)]
		_EnableSpecular("Specular (ON/OFF)", Int) = 1
        _SpecularColor("Specular Color", Color) = (1, 1, 1, 1)
		_SpecularPower("Specular Power", Range(0, 1)) = 0.5

        [Space]
		[Toggle(_CLAMP_SPECULAR)]
		_EnableClampSpecular("Clamp Specular (ON/OFF)", Int) = 0
		[Toggle(_HARD_SPECULAR)]
		_HardSpecular("Hard Specular (ON/OFF)", Int) = 0
		_SpecularThreshold("Specular Threshold", Range(0, 1)) = 0.2
		_SpecularRadius("Specular Radius", Range(0, 1)) = 0.1

        [Space]
		[Toggle(_ENABLE_RIM_LIGHT)]
		_EnableRimLight("Rim Light (ON/OFF)", Int) = 1
		_RimLightColor("Rim Light Color", Color) = (1, 1, 1, 1)
		_RimLightPower("Rim Light Power", Range(0, 1)) = 0.6

        [Space]
		[Toggle(_CLAMP_RIM_LIGHT)]
		_ClampRimLight("Clamp Rim Light (ON/OFF)", Int) = 0
		[Toggle(_HARD_RIM_LIGHT)]
		_HardRimLight("Hard Rim Light (ON/OFF)", Int) = 0
		_RimLightThreshold("Rim Light Threshold", Range(0, 1)) = 0.2
		_RimLightRadius("Rim Light Radius", Range(0, 1)) = 0

        [NKWToggle()]
		_RimLightXLightColor("Rim Light X Light Color", Int) = 0


        [Space]
		_ShadowMaskTex("Shadow Mask (R=None, G=AO Offset, B=Bright Offset, Alpha = Shadow Softness)", 2D) = "white" {}
		[NKWToggle]
		_ShadowMaskTexBlueAsBrightOffset("Use Shadow Mask Blue as Bright Offset", Int) = 0
		_SMTBlueBrightOffsetScale("Shadow Mask Blue Bright Offset Scale", Range(0, 1)) = 1.0

        [NKWToggle]
		_ShadowMaskTexAlphaAsShadowSoftness("Use Shadow Mask Alpha as Shadow Softness", Int) = 0
		_AlphaShadowSoftnessScale("Alpha Shadow Softness Sacle", Range(0, 1)) = 1

//        [Space]
//		[Toggle(_ENABLE_OUTLINE)]
//		_EnableOutline("Outline (ON/OFF)", Int) = 1
//
//		[Toggle(_OUTLINE_WITH_BASE_COLOR)]
//		_EnableOutlineWithBaseColor("Outline With Base Color (ON/OFF)", Int) = 1
//
//		_OutlineWidth ("Outline Width", Range(0, 5)) = 0.5
//        _OutlineColor ("Outline Color", Color) = (0, 0, 0, 1)
//        _OutlineMaskTex ("Outline Mask (R=Width)", 2D) = "white" {}
//
//       [Space]
//		[Toggle(_ENABLE_OUTLINE_DISTANCE_PARAMS)]
//		_EnableOutlineDistanceParams("Outline Distance Params (ON/OFF)", Int) = 0
//		_OutlineDistanceParams("Distance Params", Vector) = (0.3, 1, 10, 0.1)

        [Space]
		[Header(Light Probe and VertexLits)]
		[Toggle(_ENABLE_UNITY_GI)]
		_EnableUnityGI("Unity GI (ON/OFF)", Int) = 0
		_UnityGIIntensity("Unity GI Intensity", Range(0, 1)) = 0.2

        [Space]
		[MaterialKeywordEnum(NONE, Normal, RimLight)]
		_MultiLights("Multi Lights Mode", Int) = 1
		[Toggle(_MULTILIGHTS_DEBUG)]
		_EnableMultiLightsDebug("Multi Lights Debug (ON/OFF)", Int) = 0
		_BaseLightRimLightIntensity("Base Light Rim Light Intensity", Range(0, 1)) = 1
		_MultiLightsIntensity("Multi Lights Intensity", Range(0, 1)) = 1

        [Space]
		[Toggle(_ENABLE_OVER_BLEND_TEX)]
		_EnableOverBlendTex("Over Blend Tex (ON/OFF)", Int) = 0
		[Enum(AlphaBlend,0, Multiply, 1)]
		_OverBlendMode("Over Blend Mode", Int) = 0
		[NKWToggle]
		_OverBlendAffectedByLight("Over Blend Affected By Light", Int) = 0
		_OverBlendTex("Over Blend Tex (RGBA)", 2D) = "black" {}
    	_OverBlendIntensity("Over Blend Intensity", Range(0, 1)) = 1

        // Blending state
        _Mode ("Blend Mode", Float) = 0.0
        [MaterialToggle]_ZWrite ("ZWrite", Float) = 1.0

        _SrcBlend ("SrcBlend", Float) = 1.0
        _DstBlend ("DstBlend", Float) = 0.0
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "LightweightPipeline" "IgnoreProjector" = "True"}
        LOD 200

        Pass
        {
			Name "AnimeCelForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            Blend[_SrcBlend][_DstBlend]
            ZWrite[_ZWrite]
            Cull[_CullMode]

            HLSLPROGRAM
			
			#pragma prefer_hlslcc gles
            // #pragma exclude_renderers d3d11_9x
            #pragma target 3.0


			// Material Keywords
            // #pragma shader_feature 

			// Local Material Keywords
			// #pragma shader_feature_local
			#pragma shader_feature_local _ _ENABLE_SPECULAR
			#pragma shader_feature_local _ _CLAMP_SPECULAR
			#pragma shader_feature_local _ _HARD_SPECULAR
			#pragma shader_feature_local _ _ENABLE_RIM_LIGHT
			#pragma shader_feature_local _ _CLAMP_RIM_LIGHT
			#pragma shader_feature_local _ _HARD_RIM_LIGHT

			#pragma shader_feature_local _NORMALMAP
			#pragma shader_feature_local _RECEIVE_SHADOWS_OFF

			#pragma shader_feature_local _ _MULTILIGHTS_NORMAL _MULTILIGHTS_RIMLIGHT
			#pragma shader_feature_local _ _MULTILIGHTS_DEBUG

			// Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

            // Unity defined keywords
			#pragma multi_compile_fog

			#pragma vertex vert
            #pragma fragment frag
			
            #include "AnimeCelInput.hlsl"
			#include "AnimeCelMain_URP.hlsl"

            ENDHLSL
        }

		Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            Cull[_CullMode]

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _ALPHATEST_ON

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            Cull[_CullMode]

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }
    }
}
