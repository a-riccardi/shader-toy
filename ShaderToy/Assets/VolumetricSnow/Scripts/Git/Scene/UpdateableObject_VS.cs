using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public abstract class UpdateableObject_VS : MonoBehaviour
{
    protected void Setup()
    {
        SceneManager_VS.AddUpdateableObject(this);
    }

    public abstract void UpdateObj();       
}
