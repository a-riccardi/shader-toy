using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public enum ObjectID { NONE = -1, TRAIN_NEAR_UP, TRAIN_NEAR_DOWN, TRAIN_FAR, SPACESHIP, CAR_DOWN, CAR_UP }

public enum SceneID { NONE = -1, SHOT, BILLBOARD, SIDE_STREET }

[System.Serializable]
public struct SceneObjects_VS
{
    public SceneID id;
    public GameObject[] obj;
}

public class SceneManager_VS : MonoBehaviour
{
    static SceneManager_VS singleton;

    List<UpdateableObject_VS> updateables;

    [SerializeField] List<SceneObjects_VS> sceneObjects;
    Dictionary<SceneID, SceneObjects_VS> sceneObj;
    SceneObjects_VS currentSceneObjects;

    CameraManager_VS cameraManager;

	void Awake ()
    {
        if (singleton != null)
        {
            Destroy(this);
            enabled = false;
            return;
        }

        singleton = this;

        updateables = new List<UpdateableObject_VS>();
        sceneObj = new Dictionary<SceneID, SceneObjects_VS>();

        foreach (SceneObjects_VS so in sceneObjects)
        {
            if (!sceneObj.ContainsKey(so.id))
                sceneObj.Add(so.id, so);
            else
                Debug.LogError("Multiple entries with the same ID[" + so.id.ToString() + "] found! Please check IDs");
        }

        sceneObjects.Clear();

        currentSceneObjects = new SceneObjects_VS { id = SceneID.NONE, obj = null };
	}
	
	void Update ()
    {
        cameraManager.UpdateObj();

        foreach (UpdateableObject_VS uo in updateables)
            uo.UpdateObj();

        if (Input.GetKeyDown(KeyCode.Escape))
            Application.Quit();
    }

    public static void AddUpdateableObject(UpdateableObject_VS updateable)
    {
        if (singleton == null)
        {
            Debug.LogError("SceneManager_VS.AddUpdateableObject(" + updateable.name + ") called, but singleton was NULL! Aborting.");
            return;
        }

        singleton._AddUpdateableObject(updateable);
    }

    void _AddUpdateableObject(UpdateableObject_VS updateable)
    {
        updateables.Add(updateable);
    }

    public static void AddCameraManager(CameraManager_VS updateable)
    {
        if (singleton == null)
        {
            Debug.LogError("SceneManager_VS.AddUpdateableObject(" + updateable.name + ") called, but singleton was NULL! Aborting.");
            return;
        }

        singleton._AddCameraManager(updateable);
    }

    void _AddCameraManager(CameraManager_VS updateable)
    {
        cameraManager = updateable;
    }

    public static void SetupScene(SceneID id)
    {
         if (singleton == null)
        {
            Debug.LogError("SceneManager_VS.SetupScene(" + id.ToString() + ") called, but singleton was NULL! Aborting.");
            return;
        }

        singleton._SetupScene(id);
    }

    void _SetupScene(SceneID id)
    {
        if (currentSceneObjects.id != SceneID.NONE)
        {
            foreach (GameObject go in currentSceneObjects.obj)
                go.SetActive(true);
        }

        currentSceneObjects = sceneObj[id];

        foreach (GameObject go in currentSceneObjects.obj)
            go.SetActive(false);
    }
}
