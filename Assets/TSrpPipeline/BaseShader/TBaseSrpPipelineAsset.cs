
using UnityEngine;
using UnityEngine.Rendering;

[CreateAssetMenu(menuName = "Rendering/TBasePipeline")]
public class TBaseSrpPipelineAsset : RenderPipelineAsset
{
    
    protected override RenderPipeline CreatePipeline()
    {       
        return new TBaseSrpPipeline();
    }
}
