using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[System.Serializable]
public struct LightInfo_VS
{
    public Transform lightT;
    public float delay;
    public float scale;
}

public class PatrollingSpaceship_VS : UpdateableObject_VS
{
    [SerializeField] ObjectID objectID;

    [SerializeField] float shipSpeed;
    [SerializeField] float floatSpeed;
    [SerializeField] AreaLight[] lights;
    [SerializeField] CapsuleCollider shipCollider;

    [SerializeField] LightInfo_VS[] lightsI;

    Transform shipT;
    Vector3 shipStartPos;
    Quaternion shipStartRot;

	void Awake ()
    {
        shipT = GetComponent<Transform>();
        shipStartRot = shipT.rotation;
        shipStartPos = shipT.position; // - shipT.forward * shipCollider.height;
        
        //lightsI = new LightInfo_VS[lights.Length];
        for (int i = 0; i < lights.Length; i++)
        {
            lightsI[i].lightT = lights[i].GetComponent<Transform>();
            /*
            lightsI[i] = new LightInfo_VS
            {
                lightT = lights[i].GetComponent<Transform>(),
                delay = Random.Range(-100.0f, 100.0f),
                scale = Random.Range(0.05f, 0.3f)
            };
            */
        }

        Setup();
    }

    void OnTriggerExit(Collider other)
    {
        ObjectIDHolder_VS idHolder = other.GetComponent<ObjectIDHolder_VS>();

        if (idHolder == null)
            return;

        if (idHolder.ID == objectID)
            shipT.position = shipStartPos;            
    }

    public override void UpdateObj()
    {
        for (int i = 0; i < lightsI.Length; i++)
        {
            lightsI[i].lightT.localRotation = Quaternion.Lerp(Quaternion.Euler(0, 60, 0), Quaternion.Euler(0, -15, 0), Mathf.Sin(Time.time * lightsI[i].scale + lightsI[i].delay) * 0.5f + 0.5f) *
                Quaternion.Lerp(Quaternion.Euler(0, 0, 0), Quaternion.Euler(120, 0, 0), Mathf.Cos(Time.time * lightsI[i].scale + lightsI[i].delay) * 0.5f + 0.5f);
        }

        //shipT.position += Vector3.Lerp(shipT.up, -shipT.up, Mathf.Sin(Time.time * 0.3f)*0.5f + 0.5f) * Time.deltaTime * floatSpeed;
        shipT.position += shipT.forward * Time.deltaTime * shipSpeed;
        shipT.rotation = Quaternion.Lerp(Quaternion.Euler(10.0f, 15.0f, -25.0f), Quaternion.Euler(-10.0f, -15.0f, 25.0f), Mathf.Sin(Time.time * 0.1f) * 0.5f + 0.5f) * shipStartRot;
    }
}
