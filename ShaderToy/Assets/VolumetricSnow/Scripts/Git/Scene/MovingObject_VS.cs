using System.Collections;
using UnityEngine;

public class MovingObject_VS : UpdateableObject_VS
{
    [SerializeField] ObjectIDHolder_VS obj;
    [SerializeField] float trainSpeed;
    [SerializeField] Vector2 minMaxWaitTime;
    [SerializeField] ObjectID objectID;

    Transform objT;
    Vector3 startPos;

    float x;

	void Awake ()
    {
        objT = obj.transform;
        startPos = objT.position;

        Setup();
	}

    void OnTriggerExit(Collider other)
    {
        ObjectIDHolder_VS idHolder = other.GetComponent<ObjectIDHolder_VS>();

        if (idHolder == null)
            return;

        if (idHolder.ID == objectID)
        {
            objT.position = startPos;
            x = Random.Range(minMaxWaitTime.x, minMaxWaitTime.y);
        }
    }

    public override void UpdateObj()
    {
        if (!isActiveAndEnabled)
            return;

        if (x >= 0)
            x -= Time.deltaTime;
        else
            objT.position += objT.forward * Time.deltaTime * trainSpeed;
    }
}
