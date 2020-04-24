//基础带2高光shader
Shader "TSrp/TBaseShader"
{
	Properties
	{
		_Color("Color Tint", Color) = (0.5,0.5,0.5)
		_MainTex("MainTex",2D) = "white"{}
		_SpecularPow("SpecularPow",range(5,50)) = 20
	}

	HLSLINCLUDE
	#include "UnityCG.cginc"
	uniform float4 _Color;
	sampler2D _MainTex;
	half4 _CameraPos;
	fixed _SpecularPow;
	float4 _DLightColor;
	float4 _DLightDir;

	struct a2v
	{
		float4 position : POSITION;
		float3 normal : NORMAL;
		float2 uv : TEXCOORD0;
		
	};

	struct v2f
	{
		float4 position : SV_POSITION;
		float2 uv : TEXCOORD0;
		float3 worldPos : TEXCOORD1;
		float3 normal : NORMAL;
	};

	v2f vert(a2v v)
	{
		v2f o;
		UNITY_INITIALIZE_OUTPUT(v2f, o);
		o.position = UnityObjectToClipPos(v.position);
		o.worldPos = mul(unity_ObjectToWorld, v.position).xyz;
		o.normal = UnityObjectToWorldNormal(v.normal);
		o.uv = v.uv;
		return o;
	}

	half4 frag(v2f v) : SV_Target
	{
		half4 fragColor = half4(_Color.rgb,1.0) * tex2D(_MainTex, v.uv);

		//获得光照参数，进行兰伯特光照计算
		half diffuse = saturate(dot(normalize(v.normal), _DLightDir));

				
		half3 viewDir = normalize(_CameraPos - v.worldPos);
		half3 halfDir = normalize(viewDir + _DLightDir.xyz);
		half specular = pow(saturate(dot(v.normal, halfDir)), _SpecularPow);

		half4 color = fragColor * (diffuse + specular) * _DLightColor;

		return float4(color.rgb,1);

	}

	ENDHLSL

	SubShader
	{
		Tags{ "Queue" = "Geometry" }
		LOD 100
		Pass
		{
			//注意这里,默认是没写光照类型的,自定义管线要求必须写,渲染脚本中会调用,否则无法渲染
			//这也是为啥新建一个默认unlitshader,无法被渲染的原因
			Tags{ "LightMode" = "Always" }
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			ENDHLSL
		}
	}
}