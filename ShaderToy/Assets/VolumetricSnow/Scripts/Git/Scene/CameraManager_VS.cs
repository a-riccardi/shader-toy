using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[System.Serializable]
public struct SceneCamera_VS
{
    public SceneID sceneID;
    public Transform camT;
}

public class CameraManager_VS : UpdateableObject_VS
{
    [SerializeField] Camera mainCamera;
    [SerializeField] SceneCamera_VS [] scenes;

    int sceneIndex;

    void Start()
    {
        Setup2To1ScreenRatio();

        sceneIndex = 1;
        SceneManager_VS.AddCameraManager(this);
        SceneManager_VS.SetupScene(scenes[sceneIndex].sceneID);
    }

    void Setup2To1ScreenRatio()
    {
        // determine the game window's current aspect ratio
        float windowaspect = (float)Screen.width / (float)Screen.height;
        // current viewport height should be scaled by this amount
        float scaleheight = windowaspect / 2.0f;
        // if scaled height is less than current height, add letterbox
        if (scaleheight < 1.0f)
        {  
            Rect rect = mainCamera.rect;
            rect.width = 1.0f;
            rect.height = scaleheight;
            rect.x = 0;
            rect.y = (1.0f - scaleheight) / 2.0f;
           mainCamera.rect = rect;
        }
        else if (scaleheight > 1.0f) // add pillarbox
        {
            float scalewidth = 1.0f / scaleheight;
            Rect rect = mainCamera.rect;
            rect.width = scalewidth;
            rect.height = 1.0f;
            rect.x = (1.0f - scalewidth) / 2.0f;
            rect.y = 0;
            mainCamera.rect = rect;
        }
    }

    void ChangeCamera(int indexDelta)
    {
        sceneIndex += indexDelta;

        if (sceneIndex >= scenes.Length)
            sceneIndex = 0;
        else if (sceneIndex < 0)
            sceneIndex = scenes.Length - 1;

        mainCamera.transform.position = scenes[sceneIndex].camT.position;
        mainCamera.transform.rotation = scenes[sceneIndex].camT.rotation;

        SceneManager_VS.SetupScene(scenes[sceneIndex].sceneID);
    }

    public override void UpdateObj()
    {
        if (!isActiveAndEnabled)
            return;

        if (Input.GetKeyDown(KeyCode.E))
            ChangeCamera(1);
        else if (Input.GetKeyDown(KeyCode.Q))
            ChangeCamera(-1);
    }
}
