using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ObjectIDHolder_VS : MonoBehaviour
{
    public ObjectID ID { get { return id; } }
    [SerializeField] ObjectID id;
}
