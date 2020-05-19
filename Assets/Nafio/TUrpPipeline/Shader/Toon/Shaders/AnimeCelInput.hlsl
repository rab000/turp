#ifndef STAR_ANIMECEL_INPUT_INCLUDED
#define STAR_ANIMECEL_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"

CBUFFER_START(UnityPerMaterial)
	float4 _MainTex_ST;
	float4 _ShadowTex_ST;

	float4 _ShadowMaskTex_ST;

	half4 _BaseColor;
	half4 _ShadowColor;

	float _BaseShadowThreshold;
	float _BaseShadowRadius;
	float _SysShadowValue;

	half4 _RimLightColor;
	float _RimLightPower;
	float _RimLightThreshold;
	float _RimLightRadius;

	float _RimLightXLightColor;

	float _UnityGIIntensity;

	float _ShadowMaskTexBlueAsBrightOffset;
	float _SMTBlueBrightOffsetScale;
	float _ShadowMaskTexAlphaAsShadowSoftness;
	float _AlphaShadowSoftnessScale;

	// blinn-phong specular
	half4 _SpecularColor;
	float _SpecularPower;
	float _SpecularThreshold;
	float _SpecularRadius;

	// Todo : Anisotropic or PBR specular

	float _Mode; // blend mode

	float _MultiLightsIntensity;
	float _BaseLightRimLightIntensity;
	float _RimBlendMode;

	float _OverBlendAffectedByLight;
	float4 _OverBlendTex_ST;
	float _OverBlendIntensity;
CBUFFER_END

TEXTURE2D(_MainTex);		SAMPLER(sampler_MainTex);
TEXTURE2D(_ShadowTex);		SAMPLER(sampler_ShadowTex);
TEXTURE2D(_ShadowMaskTex);	SAMPLER(sampler_ShadowMaskTex);
TEXTURE2D(_OverBlendTex);	SAMPLER(sampler_OverBlendTex);

#endif // STAR_ANIMECEL_INPUT_INCLUDED