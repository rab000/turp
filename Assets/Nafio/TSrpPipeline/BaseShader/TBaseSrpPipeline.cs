
using UnityEngine;
using UnityEngine.Rendering;
public class TBaseSrpPipeline : RenderPipeline
{
    //定义CommandBuffer用来传参
    private CommandBuffer myCommandBuffer;

    protected override void Render(ScriptableRenderContext renderContext, Camera[] cameras)
    {
        //渲染开始后，创建CommandBuffer;
        if (myCommandBuffer == null) myCommandBuffer = new CommandBuffer() { name = "T SRP CB" };


        //将shader中需要的属性参数映射为ID，加速传参
        var _LightDir0 = Shader.PropertyToID("_DLightDir");
        var _LightColor0 = Shader.PropertyToID("_DLightColor");
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
            foreach (var light in lights)
            {
                //判断灯光类型
                if (light.lightType != LightType.Directional) continue;
                //获取灯光参数,平行光朝向即为灯光Z轴方向。矩阵第一到三列分别为xyz轴项，第四列为位置。
                Vector4 lightpos = light.localToWorldMatrix.GetColumn(2);
                //灯光方向反向。默认管线中，unity提供的平行光方向也是灯光反向。光照计算决定
                Vector4 lightDir = -lightpos;
                //方向的第四个值(W值)为0，点为1.
                lightDir.w = 0;
                //这边获取的灯光的finalColor是灯光颜色乘上强度之后的值，也正好是shader需要的值
                Color lightColor = light.finalColor;
                //利用CommandBuffer进行参数传递。
                myCommandBuffer.SetGlobalVector(_LightDir0, lightDir);
                myCommandBuffer.SetGlobalColor(_LightColor0, lightColor);
                
                break;
            }

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
