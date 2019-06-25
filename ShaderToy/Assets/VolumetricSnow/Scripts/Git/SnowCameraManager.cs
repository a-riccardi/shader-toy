using UnityEngine;
using UnityEngine.Rendering;

public enum BufferSize { _32 = 32, _64 = 64, _128 = 128, _256 = 256, _512 = 512, _1024 = 1024, _2048 = 2048  }
public enum KernelSize { NONE = 0, SMALL = 1 } //, MEDIUM = 8, LARGE = 16 }

[RequireComponent(typeof(Camera))]
public class SnowCameraManager : MonoBehaviour
{
    [SerializeField] Texture2D whitePatch;
    [SerializeField] Material depthProcessorMaterial;

    [SerializeField] BufferSize bufferSize;
    public BufferSize BufferSize
    {
        get { return bufferSize; }

        set
        {
            bufferSize = value;

            int xBufferSize = (int)((float)bufferSize * snowCamera.aspect);
            
            RenderTexture old_depthBuffer = new RenderTexture(depthBuffer);
            RenderTexture old_depthBufferSupport = new RenderTexture(depthBufferSupport);
            RenderTexture old_depthBufferBlurred = new RenderTexture(depthBufferBlurred);

            old_depthBuffer.Create();
            old_depthBufferSupport.Create();
            old_depthBufferBlurred.Create();

            if (SystemInfo.copyTextureSupport == CopyTextureSupport.None)
            {
                Graphics.Blit(depthBuffer, old_depthBuffer);
                Graphics.Blit(depthBufferSupport, old_depthBufferSupport);
                Graphics.Blit(depthBufferBlurred, old_depthBufferBlurred);
            }
            else
            {
                Graphics.CopyTexture(depthBuffer, old_depthBuffer);
                Graphics.CopyTexture(depthBufferSupport, old_depthBufferSupport);
                Graphics.CopyTexture(depthBufferBlurred, old_depthBufferBlurred);
            }
                
            SetupVariables(false);

            Graphics.Blit(old_depthBuffer, depthBuffer);
            Graphics.Blit(old_depthBufferSupport, depthBufferSupport);
            Graphics.Blit(old_depthBufferBlurred, depthBufferBlurred);

            old_depthBuffer.Release();
            old_depthBufferSupport.Release();
            old_depthBufferBlurred.Release();

            snowCamera.RemoveCommandBuffer(CameraEvent.BeforeForwardOpaque, cb);
            cb.Dispose();

            SetupCommandBuffer(true);
        }
    }

    [SerializeField] KernelSize kernelSize;
    public KernelSize BlurKernelSize
    {
        get { return kernelSize; }

        set
        {
            kernelSize = value;

            snowCamera.RemoveCommandBuffer(CameraEvent.BeforeForwardOpaque, cb);
            cb.Dispose();
            SetupCommandBuffer(false);
            SetSnowMaterialDepthTexture(roofManager.SnowMaterial);
        }
    }

    [Range(0.0f, 10000.0f)]
    [SerializeField] float persistence;

    public float Persistence
    {
        get { return persistence; }

        set
        {
            persistence = value;
            if (depthProcessorMaterial != null)
                depthProcessorMaterial.SetFloat(persistenceID, persistence);
        }
    }

    Camera snowCamera;
    public SnowRoof RoofManager { get { return roofManager; } set { roofManager = value; } }
    SnowRoof roofManager;

    RenderTexture depthBuffer;
    RenderTexture depthBufferSupport;
    RenderTexture depthBufferBlurred;

    RenderTargetIdentifier dst;
    RenderTargetIdentifier dstSupport;
    RenderTargetIdentifier dstBlurred;

    CommandBuffer cb;
    int kernelSizeID;
    int heightTexID;
    int persistenceID;

    bool useRFloatTexture;

	void Awake ()
    {
        //cache components
        snowCamera = GetComponent<Camera>();
        snowCamera.depthTextureMode = DepthTextureMode.Depth;

        //Get variables and setup command buffer
        GetPropertyIDs();
    }

    void SetupVariables(bool generateDepthProcessor = true)
    {
        if (generateDepthProcessor)
        {
            //setup all the variables
            //create the material (optionally, expose it as a reference?)
            depthProcessorMaterial = new Material(depthProcessorMaterial);
            depthProcessorMaterial.SetFloat(persistenceID, persistence);
        }

        int xBufferSize = (int)((float)bufferSize * snowCamera.aspect);
        
        //perform check on RFloat format hardware capability
        if (SystemInfo.SupportsRenderTextureFormat(RenderTextureFormat.RFloat))
        {
            //use RFloat textures, disable fallback keyword
            Shader.DisableKeyword("FALLBACK_ARGB");
            depthBuffer = new RenderTexture(xBufferSize, (int)bufferSize, 0, RenderTextureFormat.RFloat, RenderTextureReadWrite.Linear);
            depthBufferSupport = new RenderTexture(xBufferSize, (int)bufferSize, 0, RenderTextureFormat.RFloat, RenderTextureReadWrite.Linear);
            depthBufferBlurred = new RenderTexture(xBufferSize, (int)bufferSize, 0, RenderTextureFormat.RFloat, RenderTextureReadWrite.Linear);
        }
        else
        {
            //print warning and default to ARGB32 textures
            Debug.LogWarning("RFloat texture format is not supported on this platform. Defaulting to ARGB texture format");
            //enable fallback keyword
            Shader.EnableKeyword("FALLBACK_ARGB");
            depthBuffer = new RenderTexture(xBufferSize, (int)bufferSize, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
            depthBufferSupport = new RenderTexture(xBufferSize, (int)bufferSize, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
            depthBufferBlurred = new RenderTexture(xBufferSize, (int)bufferSize, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
        }
    }

    void GetPropertyIDs()
    {
        //get IDs for the properties
        kernelSizeID = Shader.PropertyToID("_KernelSize");
        heightTexID = Shader.PropertyToID("_HeightTex");
        persistenceID = Shader.PropertyToID("_PersistenceF");
    }

    void ClearBuffer()
    {
        //clear all buffers white
        Graphics.Blit(whitePatch, depthBuffer);
        Graphics.Blit(whitePatch, depthBufferSupport);
        Graphics.Blit(whitePatch, depthBufferBlurred);
    }

    void SetupCommandBuffer(bool generateRTI = true)
    {
        cb = new CommandBuffer();
        cb.name = "Depth Processor Buffer" + (kernelSize == KernelSize.NONE ? "" : " - BLUR -");

        if (generateRTI)
        {
            dst = new RenderTargetIdentifier(depthBuffer);
            dstSupport = new RenderTargetIdentifier(depthBufferSupport);
            dstBlurred = new RenderTargetIdentifier(depthBufferBlurred);
        }
       
        //copy the dst buffer into the supportDst, which will be used in the next step
        //NOTE: CopyTexture is more efficient, but it's not supported on all platforms
        //perform check & add a Blit command if CopyTexture is unsupported
        if (SystemInfo.copyTextureSupport == CopyTextureSupport.None)
            cb.Blit(dst, dstSupport);
        else
            cb.CopyTexture(dst, dstSupport);

        //blit the rendered camera depth into the depthBuffer
        cb.Blit(dstSupport, dst, depthProcessorMaterial, 0);

        //if we want some kind of blur on the height texture, add blur instructions to the buffer
        if (kernelSize != KernelSize.NONE)
        {
            //NOTE: only choosing between blur/no blur for now, removing unused variables
            //set blur level
            //depthProcessorMaterial.SetFloat(kernelSizeID, (float)kernelSize);

            //actually blit into buffer with pass 1
            cb.Blit(dst, dstBlurred, depthProcessorMaterial, 1);

            //set the blurred buffer as the height texture
            //cb.SetGlobalTexture(heightTexID, dstBlurred);
        }
        //else
            //else, just set the depth buffer as the height texture
            //cb.SetGlobalTexture(heightTexID, dst);

        //add the command buffer before forward opaque rendering, in order to have the height texture available at render time
        snowCamera.AddCommandBuffer(CameraEvent.BeforeForwardOpaque, cb);
    }

    public void SetSnowMaterialDepthTexture(Material snowMaterial)
    { 
        if (kernelSize == KernelSize.NONE)
            snowMaterial.SetTexture(heightTexID, depthBuffer);
        else
            snowMaterial.SetTexture(heightTexID, depthBufferBlurred);
    }

    public void SetSnowCameraActive(bool isActive)
    {
        snowCamera.enabled = isActive;

        if (isActive)
        {
            SetupVariables();
            ClearBuffer();
            SetupCommandBuffer();
        }        
    }

    public void SetCameraAspect(float orthographicSize, float aspectRatio)
    {
        snowCamera.orthographicSize = orthographicSize;
        snowCamera.aspect = aspectRatio;
    }

#if UNITY_EDITOR
    public void Editor_UpdateValues()
    {
        if (!Application.isPlaying)
            return;

        Persistence = persistence;
        BufferSize = bufferSize;
        BlurKernelSize = kernelSize;
    }
#endif
}
