using UnityEngine;
using UnityEngine.Rendering;
using System.Collections;

public class DepthCameraManager : MonoBehaviour
{
	Camera depthCamera;

	[SerializeField] RenderTexture depthBuffer;
	[SerializeField] Material depthAccumulator;
	[SerializeField] RenderTexture supportDepthBuffer;
	[SerializeField] Texture2D whitePatch;

    [SerializeField] Material depthMaskComposer;

	CommandBuffer cb;
	int dBufferID;
	int dSBufferID;

    int bDBufferID;
    int bufferDim = 32;
    float bufferDimScaled;

	//void Awake ()
	//{
	//	depthCamera = GetComponent<Camera>();
	//	depthCamera.depthTextureMode = DepthTextureMode.Depth;

	//	ClearBuffers();
    //  GetPropertyIDs();
    //  InitializeShaderGlobals();
	//	SetupCommandBuffer();
	//}

	void ClearBuffers()
	{
		Graphics.Blit(whitePatch, depthBuffer);
		Graphics.Blit(whitePatch, supportDepthBuffer);
    }

    void GetPropertyIDs()
    {
        dBufferID = Shader.PropertyToID("_HeightTex");
        dSBufferID = Shader.PropertyToID("_DBuffer");
        bDBufferID = Shader.PropertyToID("_BlurredDepth");
    }

    void InitializeShaderGlobals()
    {
        //this parameters are setted without the ID retrieving because they will never be changed again
        bufferDimScaled = 1.0f / (float)bufferDim;
        Shader.SetGlobalVector("texel_size", new Vector4(bufferDimScaled, bufferDimScaled));
        Shader.SetGlobalFloat("tessellation_min", 3.0f);
        Shader.SetGlobalFloat("tessellation_max", 100.0f);
    }

	void SetupCommandBuffer()
	{
        RenderTexture blitHalfRes = RenderTexture.GetTemporary(bufferDim, bufferDim);
        RenderTexture blitHalfResBuffer = RenderTexture.GetTemporary(bufferDim, bufferDim);
        RenderTexture dstSupportBuffer = RenderTexture.GetTemporary(depthBuffer.width, depthBuffer.height);

        RenderTargetIdentifier dst = new RenderTargetIdentifier(depthBuffer);
		RenderTargetIdentifier supportDst = new RenderTargetIdentifier(supportDepthBuffer);
        RenderTargetIdentifier blitHalfResID = new RenderTargetIdentifier(blitHalfRes);
        RenderTargetIdentifier blitHalfResBufferID = new RenderTargetIdentifier(blitHalfResBuffer);
        RenderTargetIdentifier dstSupportBufferID = new RenderTargetIdentifier(dstSupportBuffer);

        cb = new CommandBuffer();
		cb.name = "depth accumulation";
        //copy the current state of the depth buffer on the support buffer to be used in the next frame
		cb.Blit(dst, supportDst);
        //set the support buffer as a texture which will be used in the next step
		cb.SetGlobalTexture(dSBufferID, supportDst);
        //blit the current camera target on the depth buffer, using the depthAccumulator material
		cb.Blit(BuiltinRenderTextureType.CameraTarget, dst, depthAccumulator);
        //copy the depth buffer on the low res buffer
        cb.Blit(dst, blitHalfResID);
        //expand the low res buffer
        cb.Blit(blitHalfResID, blitHalfResBufferID, depthMaskComposer, 0);
        //set the low res buffer as a global texture which will be used in the next step
        cb.SetGlobalTexture(bDBufferID, blitHalfResBufferID);
        //compose the depth buffer and the low res buffer on a support buffer, using the depthMaskComposer material
        cb.Blit(dst, dstSupportBufferID, depthMaskComposer, 1);
        //TODO: investigate if problem is relatet to dst being a render texture and not just a temporary buffer
        //cb.SetGlobalTexture(dBufferID, dstSupportBufferID);
        //
        cb.Blit(dstSupportBufferID, dst);
        cb.SetGlobalTexture(dBufferID, dst);

		depthCamera.AddCommandBuffer(CameraEvent.BeforeForwardOpaque, cb);
	}
}
