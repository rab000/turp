//基础带2高光shader
Shader "TSrp/TMultLightShader"
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

		//定义最多4盏平行光
		#define MAX_DIRECTIONAL_LIGHTS 4
		fixed4 _DLightDir[MAX_DIRECTIONAL_LIGHTS];
		fixed4 _DLightColor[MAX_DIRECTIONAL_LIGHTS];
		//定义平行光照参数
		half3 dLight = 0;

		//定义最多4盏点光
		#define MAX_POINT_LIGHTS 4
		half4 _PLightPos[MAX_POINT_LIGHTS];
		fixed4 _PLightColor[MAX_POINT_LIGHTS];
		//像素管线中计算点光源光照
		half3 pLight = 0;


		//定义最多4盏聚光
		#define MAX_SPOT_LIGHTS 4
		//定义参数数组
		half4 _SLightColor[MAX_SPOT_LIGHTS];
		half4 _SLightPos[MAX_SPOT_LIGHTS];
		half4 _SLightDir[MAX_SPOT_LIGHTS];
		half3 sLight = 0;

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

			half3 viewDir = normalize(_CameraPos - v.worldPos);
			
			//half3 tt= _DLightColor[2].rgb;

			for (int n = 0; n < MAX_DIRECTIONAL_LIGHTS; n++)
			{				
				fixed specular = 0;
				//判断，仅第一盏光产生高光
				if (n == 0)
				{
					half3 halfDir = normalize(viewDir + _DLightDir[n].xyz);
					specular = pow(saturate(dot(v.normal, halfDir)), _SpecularPow);
				}
				//diffuce+specular
				dLight += (1 + specular) * saturate(dot(v.normal, _DLightDir[n])) * _DLightColor[n].rgb;				
				
			}

			half3 tt= _PLightColor[0].rgb;

			for (int n = 0; n < MAX_POINT_LIGHTS; n++)
			{
				fixed specular = 0;
				half3 pLightVector = _PLightPos[n].xyz - v.worldPos;
				half3 pLightDir = normalize(pLightVector);
				//距离平方，用于计算点光衰减
				half distanceSqr = max(dot(pLightVector, pLightVector), 0.00001);
				//点光衰减公式pow(max(1 - pow((distance*distance/range*range),2),0),2)
				half pLightAttenuation = pow(max(1 - pow((distanceSqr / (_PLightColor[n].a * _PLightColor[n].a)), 2), 0), 2);
				half3 halfDir = normalize(viewDir + pLightDir);
				specular = pow(saturate(dot(v.normal, halfDir)), _SpecularPow);
				pLight += (1 + specular) * saturate(dot(v.normal, pLightDir)) * _PLightColor[n].rgb * pLightAttenuation;

			}

			for (int n = 0; n < MAX_SPOT_LIGHTS; n++)
			{
				fixed specular = 0;
				//灯光到受光物体矢量，类似点光方向
				half3 sLightVector = _SLightPos[n].xyz - v.worldPos;
				//聚光灯朝向
				half3 sLightDir = normalize(_SLightDir[n].xyz);
				//距离平方，与点光的距离衰减计算一样
				half distanceSqr = max(dot(sLightVector, sLightVector), 0.00001);
				//距离衰减公式同点光pow(max(1 - pow((distance*distance/range*range),2),0),2)
				half rangeAttenuation = pow(max(1 - pow((distanceSqr / (_SLightColor[n].a * _SLightColor[n].a)), 2), 0), 2);
				//灯光物体矢量与照射矢量点积
				float spotCos = saturate(dot(normalize(sLightVector), sLightDir));
				//角度衰减公式
				float spotAttenuation = saturate((spotCos - _SLightDir[n].w) / _SLightPos[n].w);

				half3 halfDir = normalize(viewDir + sLightDir);
				specular = pow(saturate(dot(v.normal, halfDir)), _SpecularPow);
				sLight += (1 + specular) * saturate(dot(v.normal, sLightDir)) * _SLightColor[n].rgb * rangeAttenuation * spotAttenuation * spotAttenuation;
			}


			half3 c = dLight.rgb + pLight.rgb+ sLight.rgb;

			return float4(c.rgb,1);

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