using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Light))]
public class LightFlicker_VS : UpdateableObject_VS
{
    [SerializeField] AnimationCurve flicker;
    [SerializeField] float speed;
    [SerializeField] float intensityScaler;

    Light light;
    float x;
    float maxIntensity;
    float minIntensity;

    void Awake ()
    {
        light = GetComponent<Light>();
        maxIntensity = light.intensity;
        minIntensity = maxIntensity * intensityScaler;

        Setup();
	}

    public override void UpdateObj()
    {
        x += Time.deltaTime * speed;
        light.intensity = Mathf.LerpUnclamped(minIntensity, maxIntensity, flicker.Evaluate(x));
    }
}
