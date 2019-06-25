using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(ParticleSystem))]
public class ParticlesPreWarmer_VS : MonoBehaviour
{
    [SerializeField] float simulationTime;
	void Awake ()
    {
        ParticleSystem ps = GetComponent<ParticleSystem>();
        ps.Simulate(simulationTime);
        ps.Play();
    }
}
