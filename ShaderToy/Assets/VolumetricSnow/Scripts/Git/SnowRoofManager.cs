using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SnowRoofManager : MonoBehaviour
{
    public static SnowRoofManager singleton;

    public static Material SimpleSnowMaterial { get { return singleton.simpleSnowMaterial; } }
    [SerializeField] Material simpleSnowMaterial;
    public static Material DeformableSnowMaterial { get { return singleton.deformableSnowMaterial; } }
    [SerializeField] Material deformableSnowMaterial;

    [SerializeField] Dictionary<Guid, SnowRoof> roofMap;

    void Awake()
    {
        if (singleton != null)
        {
            enabled = false;
            Destroy(this);
            return;
        }
        else
        {
            singleton = this;
            DontDestroyOnLoad(this);

            //Debug.Log("roofMap size: " + singleton.roofMap.Count.ToString());
        }
    }

#if UNITY_EDITOR

    public static void AddRoofToMap(SnowRoof newRoof)
    {
        if (singleton == null)
            return;

        if (singleton.roofMap == null)
            singleton.roofMap = new Dictionary<Guid, SnowRoof>();

        if (!singleton.roofMap.ContainsKey(newRoof.ID))
        {
            singleton.roofMap.Add(newRoof.ID, newRoof);
            Debug.Log("roofMap size: " + singleton.roofMap.Count.ToString());
        }
    }

#endif
}
