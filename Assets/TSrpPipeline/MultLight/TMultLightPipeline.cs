
using UnityEngine;
using UnityEngine.Rendering;

public class TMultLightPipeline : RenderPipeline
{
    //定义CommandBuffer用来传参
    private CommandBuffer myCommandBuffer;

    //定义好最大平行光数量
    const int maxDirectionalLights = 4;
    Vector4[] DLightColors = new Vector4[maxDirectionalLights];
    Vector4[] DLightDirections = new Vector4[maxDirectionalLights];

    //定义最大点光数量
    const int maxPointLights = 4;
    Vector4[] PLightColors = new Vector4[maxPointLights];
    Vector4[] PLightPos = new Vector4[maxPointLights];

    //定义好最大聚光灯数量
    const int maxSpotLights = 4;
    Vector4[] SLightColors = new Vector4[maxPointLights];
    Vector4[] SLightPos = new Vector4[maxPointLights];
    Vector4[] SLightDir = new Vector4[maxPointLights];


    protected override void Render(ScriptableRenderContext renderContext, Camera[] cameras)
    {
        
        //渲染开始后，创建CommandBuffer;
        if (myCommandBuffer == null) myCommandBuffer = new CommandBuffer() { name = "T SRP CB" };


        //将shader中需要的属性参数映射为ID，加速传参
     
        var _DLightDir = Shader.PropertyToID("_DLightDir");
        var _DLightColor = Shader.PropertyToID("_DLightColor");

        var _PLightPos = Shader.PropertyToID("_PLightPos");
        var _PLightColor = Shader.PropertyToID("_PLightColor");

        var _SLightPos = Shader.PropertyToID("_SLightPos");
        var _SLightColor = Shader.PropertyToID("_SLightColor");
        var _SLightDir = Shader.PropertyToID("_SLightDir");

        var _CameraPos = Shader.PropertyToID("_CameraPos");


        //全部相机逐次渲染
        foreach (var camera in cameras)
        {
            //清理myCommandBuffer，设置渲染目标的颜色为灰色。
            myCommandBuffer.ClearRenderTarget(true, true, Color.black);

            //设置渲染相关相机参数,包含相机的各个矩阵和剪裁平面等
            renderContext.SetupCameraProperties(camera);
            //绘制天空球
            renderContext.DrawSkybox(camera);

            //剪裁，这边应该是相机的视锥剪裁相关。
            //自定义一个剪裁参数，cullParam类里有很多可以设置的东西。我们先简单采用相机的默认剪裁参数。
            ScriptableCullingParameters cullParam = new ScriptableCullingParameters();
            //直接使用相机默认剪裁参数
            camera.TryGetCullingParameters(out cullParam);
            //非正交相机
            cullParam.isOrthographic = false;
            //获取剪裁之后的全部结果(其中不仅有渲染物体，还有相关的其他渲染要素)
            CullingResults cullResults = renderContext.Cull(ref cullParam);


            //传入相机参数。注意是世界空间位置。
            Vector4 cameraPos = camera.transform.position;
            myCommandBuffer.SetGlobalVector(_CameraPos, cameraPos);


            //在剪裁结果中获取灯光并进行参数获取
            var lights = cullResults.visibleLights;
            myCommandBuffer.name = "Render Lights";

            int indexDirectionalLight = 0;
            int indexPointLight = 0;
            int indexSpotLight = 0;

            foreach (var light in lights)
            {
                //判断灯光类型
                if (light.lightType == LightType.Directional)
                {
                    if (indexDirectionalLight < maxDirectionalLights)
                    {
                        //获取灯光参数,平行光朝向即为灯光Z轴方向。矩阵第一到三列分别为xyz轴项，第四列为位置。
                        Vector4 lightpos = light.localToWorldMatrix.GetColumn(2);
                        DLightColors[indexDirectionalLight] = light.finalColor;
                        DLightDirections[indexDirectionalLight] = -lightpos;
                        DLightDirections[indexDirectionalLight].w = 0;
                        //if (i == 2) Debug.Log("color:"+ DLightColors[i]);
                        indexDirectionalLight++;
                    }
                }
                else if (light.lightType == LightType.Point)
                {
                    if (indexPointLight < maxPointLights)
                    {
                        PLightColors[indexPointLight] = light.finalColor;
                        //将点光源的距离设置塞到颜色的A通道
                        PLightColors[indexPointLight].w = light.range;
                        //矩阵第4列为位置
                        PLightPos[indexPointLight] = light.localToWorldMatrix.GetColumn(3);
                        indexPointLight++;
                    }
                }
                else if (light.lightType == LightType.Spot) 
                {
                    if (indexSpotLight < maxSpotLights)
                    {
                        SLightColors[indexSpotLight] = light.finalColor;
                        //将聚光灯的距离设置塞到颜色的A通道
                        SLightColors[indexSpotLight].w = light.range;
                        //矩阵第三列为朝向，第四列为位置
                        Vector4 lightpos = light.localToWorldMatrix.GetColumn(2);
                        SLightDir[indexSpotLight] = -lightpos;

                        //外角弧度-unity中设置的角度为外角全角，我们之取半角进行计算
                        float outerRad = Mathf.Deg2Rad * 0.5f * light.spotAngle;
                        //外角弧度cos值和tan值
                        float outerCos = Mathf.Cos(outerRad);
                        float outerTan = Mathf.Tan(outerRad);
                        //内角弧度计算-设定内角tan值为外角tan值的46/64
                        float innerRad = Mathf.Atan(((46f / 64f) * outerTan));
                        //内角弧度cos值
                        float innerCos = Mathf.Cos(innerRad);
                        SLightPos[indexSpotLight] = light.localToWorldMatrix.GetColumn(3);
                        //角度计算用的cos(ro)与cos(ri) - cos(ro)分别存入方向与位置的w分量
                        SLightDir[indexSpotLight].w = outerCos;
                        SLightPos[indexSpotLight].w = innerCos - outerCos;

                        indexSpotLight++;
                    }
                }
                else
                {
                    continue;
                }
                
                
            }

            //将灯光参数组传入Shader           
            myCommandBuffer.SetGlobalVectorArray(_DLightColor, DLightColors);
            myCommandBuffer.SetGlobalVectorArray(_DLightDir, DLightDirections);

            myCommandBuffer.SetGlobalVectorArray(_PLightColor, PLightColors);
            myCommandBuffer.SetGlobalVectorArray(_PLightPos, PLightPos);

            myCommandBuffer.SetGlobalVectorArray(_SLightColor, SLightColors);
            myCommandBuffer.SetGlobalVectorArray(_SLightPos, SLightPos);
            myCommandBuffer.SetGlobalVectorArray(_SLightDir, SLightDir);

            //执行CommandBuffer中的指令
            renderContext.ExecuteCommandBuffer(myCommandBuffer);
            myCommandBuffer.Clear();


            //渲染时，会牵扯到渲染排序，所以先要进行一个相机的排序设置，这里Unity内置了一些默认的排序可以调用
            SortingSettings sortSet = new SortingSettings(camera) { criteria = SortingCriteria.CommonOpaque };
            //这边进行渲染的相关设置，需要指定渲染的shader的光照模式(就是这里，如果shader中没有标注LightMode的
            //话，使用该shader的物体就没法进行渲染了)和上面的排序设置两个参数
            DrawingSettings drawSet = new DrawingSettings(new ShaderTagId("Always"), sortSet);


            //这边是指定渲染的种类(对应shader中的Rendertype)和相关Layer的设置(-1表示全部layer)
            FilteringSettings filtSet = new FilteringSettings(RenderQueueRange.opaque, -1);

            //绘制物体
            renderContext.DrawRenderers(cullResults, ref drawSet, ref filtSet);

            //绘制天空球
            //renderContext.DrawSkybox(camera);

            //开始执行上下文
            renderContext.Submit();

        }
    }
}
