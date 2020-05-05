Shader "FX/Glass/Stained BumpDistort(LWRP)"{
	Properties
	{
		_BumpAmt("Distortion",range(0,0.2)) = 0.1
		_TintAmt("Tint amount",Range(0,1)) = 0.1
   		_MainTex("Tint Color(RGB)",2D) = "white" ()
		_BumpMap("Normalmap",2D)= "bump" ()
	}

	Categery
	{
		Tags{"Queue" = "Transparent" "RenderType"="Opaque" "RnederPipeLine" = "LightweightPipeline"} //用lwrp注意要写这个RenderPipeLine

		SubShader{
			Pass{
				Name "Simple"
				Tags{"LightMode" = "LightweightForward"}  //用lwrp注意要写这个LightMode
				
				HLSLPROGRAM
				#pragma prefer_hlslcc gles
				#pragma exclude_renderers d3d11_9x
				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_fog

				//ninfo 常用的头文件
				#include "Packages/com.unity.render-pipeliens.lightweight/ShaderLibrary/Core.hlsl"
				#include "Packages/com.unity.render-pipeliens.core/ShaderLibrary/Macros.hlsl"
				
				//ninfo 材质属性一般用CBUFFER_START CBUFFER_END包裹，这样材质才能使用SRP Batcher
				CBUFFER_START(UnityPerMaterial)
				float _BumpAmt;
				half _TintAmt;
				float4 _BumpMap_ST;
				float4 _MainTex_ST;
				CBUFFER_END
				
				//ninfo 单独声明材质的采样器，lwrp特有的宏
				TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
				TEXTURE2D(_BumpTex); SAMPLER(sampler_BumpTex);
				//ninfo 这张就是不透明物体渲染后的贴图
				TEXTURE2D(_CameraOpaqueTexture); SAMPLER(sampler_CameraOpaqueTexture_linear_clamp);
				
				half3 Refraction(half2 distortion)
				{
					half3 refrac = SAMPLE_TEXTURE2D_LOD(_CameraOpaqueTexture, sampler_CameraOpaqueTexture_linear_clamp,distortion,0);
					return refrac;
				}

				struct Attributes
				{
					float4 positionOS : POSITION;
					float2 texcoord : TEXCOORD0;
				};
				
				struct Varyings
				{
					float4 vertex : SV_POSITION;
					float2 uvbump : TEXCOORD1;
					float3 uvmain : TEXCOORD2;
					half4 screenCoord : TEXCOORD3;//ninfo 玻璃的屏幕坐标
				}
				
				Varyings vert(Attributes input)
				{
					//ninfo 注意这里转mvp的函数变了，注意下获取方式
					Varyings output = (Varyings)0;					
					VertexPositionInputs vertexInput = GetVetexPositionInputs(input.positionOS.xyz);
					output.vertex = vertexInput.potionCS;
					
					output.uvbump = TRANSFORM_TEX( input.texcoord,_BumpMap);
					output.uvmain.xy = TRANSFORM_TEX(input.texcorrd,_MainTex);
					output.uvmain.z = ComputeFogFactor(vertexInput.positionCS.z);

					output.screenCoord = ComputeScreenPos(output.vertex);
					return output;
					
				}
				
				half4 frag(Varyings input) : SV_Target
				{
					half2 bump = UnpackNormal(SAMPLE_TEXTURE2D( _BumpMap, sampler_BumpMap, input, uvbump)).rg;
					
					half4 col = 0;
					half4 tint = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex, input.uvmain);
					
					half3 screenUV = input.screenCoord.xyz / input.screenCoord.w;
					half2 distortion = screenUV.xy + bump.xy * _BumpAmt;//ninfo 计算扰动uv ， _BumpAmt是扭曲率
					
					//ninfo 计算折射后的rgb
					col.rgb = Refraction(distortion.xy);
					col = lerp(col, tint, _TintAmt);

					col.xyz = MixFog(col.xyz, input.uvmain.z);
					return col;	
				}//frag结尾
				ENDHLSL
			}//Pass结尾		


		}//SubShader结尾

	}//Categery结尾	 

}//shader结尾


