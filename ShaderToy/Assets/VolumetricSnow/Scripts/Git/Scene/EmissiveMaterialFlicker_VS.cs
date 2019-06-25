using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class EmissiveMaterialFlicker_VS : MonoBehaviour
{
    [SerializeField] AnimationCurve anim;
    [SerializeField] float speed;
    [SerializeField] string emissivePropertyName;

    Color startColor;
    int matID;
    float x;
    Material m;
    Renderer r;
	void Awake ()
    {
        r = GetComponent<Renderer>();
        m = r.material;
        matID = Shader.PropertyToID(emissivePropertyName);
        startColor = m.GetColor(matID);
	}
	
	void Update ()
    {
        x += Time.deltaTime * speed;

        //DynamicGI.SetEmissive(r, startColor * anim.Evaluate(x));
        m.SetColor(matID, startColor * anim.Evaluate(x));
	}
}
