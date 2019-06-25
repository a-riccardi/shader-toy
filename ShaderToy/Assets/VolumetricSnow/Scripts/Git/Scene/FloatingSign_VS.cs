using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class FloatingSign_VS : UpdateableObject_VS
{
    [SerializeField] float rotationSpeed;
    [SerializeField] float floatingSpeed;
    [SerializeField] float floatingHalfHeight;

    Vector3 maxFloatingPos;
    Vector3 minFloatingPos;

    Transform signT;

	void Awake ()
    {
        signT = this.transform;
        maxFloatingPos = signT.position + signT.up * floatingHalfHeight;
        minFloatingPos = signT.position - signT.up * floatingHalfHeight;

        Setup();
    }

    public override void UpdateObj()
    {
        if (!isActiveAndEnabled)
            return;

        signT.position = Vector3.Lerp(maxFloatingPos, minFloatingPos, Mathf.Sin(Time.time * floatingSpeed) * 0.5f + 0.5f);
        signT.Rotate(0.0f, Time.deltaTime * rotationSpeed, 0.0f);
    }
}
