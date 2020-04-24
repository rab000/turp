using UnityEngine;
using UnityEngine.Rendering;

[CreateAssetMenu(menuName = "Rendering/TPipeline")]
public class TPipelineAssets : RenderPipelineAsset
{
    protected override RenderPipeline CreatePipeline()
    {
        return new TBaseSrpPipeline();
    }
}
