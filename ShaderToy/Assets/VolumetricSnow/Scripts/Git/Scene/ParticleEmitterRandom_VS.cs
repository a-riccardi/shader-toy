using System.Collections;
using System.Collections.Generic;
using UnityEngine;
[RequireComponent(typeof(ParticleSystem))]
public class ParticleEmitterRandom_VS : UpdateableObject_VS
{
    [SerializeField] Vector2 minMaxWaitTime;
    [SerializeField] Vector2 minMaxDuration;

    ParticleSystem system;
    ParticleSystem.MainModule mainModule;
    float x;

    void Awake ()
    {
        Setup();

        system = GetComponent<ParticleSystem>();
        mainModule = system.main;
	}

    public override void UpdateObj()
    {
        if (x <= 0.0f && !system.isPlaying)
        {
            x = Random.Range(minMaxWaitTime.x, minMaxWaitTime.y);
            system.randomSeed = (uint)Random.Range(0, int.MaxValue);
            mainModule.duration = Random.Range(minMaxDuration.x, minMaxDuration.y);
            system.Play();
        }
        else
            x -= Time.deltaTime;
    }
}
