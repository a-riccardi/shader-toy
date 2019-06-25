using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SnowRoof : MonoBehaviour
{
    [SerializeField] Texture2D roofTexture;
    [SerializeField] GameObject snowPlane;
    [SerializeField] SnowCameraManager snowCamera;
    [SerializeField] Collider roofCollider;

    Renderer snowRenderer;
    public Guid ID { get { return id; } }
    Guid id;

    void Awake()
    {
        snowRenderer = snowPlane.GetComponent<Renderer>();

        if (snowRenderer == null)
            Debug.LogError("snowPlane has no renderer attached! check the prefab");
    }

    void Start()
    {
        float roofCameraYsize = roofCollider.GetComponent<Transform>().localScale.z * transform.localScale.z * 0.5f;
        float roofAspectRatio = transform.localScale.x / transform.localScale.z;

        snowCamera.SetCameraAspect(roofCameraYsize, roofAspectRatio);
        SwitchToActiveState();
    }

    public void SwitchToActiveState()
    {
        snowCamera.SetSnowCameraActive(true);

        snowCamera.SetSnowMaterialDepthTexture(snowRenderer.material);
        snowRenderer.material.SetTexture("_RoofTex", roofTexture);
    }

    public void SwitchToInactiveState()
    {
        snowRenderer.material = SnowRoofManager.SimpleSnowMaterial;
        //TODO save height texture?
        snowCamera.SetSnowCameraActive(false);
    }

}
/*
#if UNITY_EDITOR

    Vector3 previousLocalScale = Vector3.zero;
    /*
    void Update()
    {
        if (snowPlane.transform.localScale != previousLocalScale)
        {
            Vector3 localScale = snowPlane.transform.localScale;
            localScale.z = 0.1f / snowPlane.transform.lossyScale.z;
            snowPlane.transform.localScale = localScale;

            previousLocalScale = localScale;
        }

        if (id == null)
            id = Guid.NewGuid();

        SnowRoofManager.AddRoofToMap(this);
    }
    */
    /*
#endif

}
*/