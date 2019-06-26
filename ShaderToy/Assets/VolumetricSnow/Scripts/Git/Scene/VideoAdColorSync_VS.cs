using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Video;

[RequireComponent(typeof(VideoPlayer))]
public class VideoAdColorSync_VS : MonoBehaviour
{
    VideoPlayer player;
    [SerializeField] AreaLight al;
    [SerializeField] Light[] additionalLights;

    [SerializeField] AdvertisementID[] adSequence;
    int sequenceIndex;
    Ad currentAd;

    float x;
    int adLightIndex;
    bool doUpdate;

    void Awake()
    {
        player = GetComponent<VideoPlayer>();
        doUpdate = false;

        player.skipOnDrop = true;
        player.prepareCompleted += OnFrameDropped;
        player.frameDropped += OnPrepareCompleted;
        player.loopPointReached += OnLoopPointReached;

        GetAdInfo(adSequence[sequenceIndex]);
        SetupLight();
    }

    void GetAdInfo(AdvertisementID id)
    {
        currentAd = AdManager_VS.GetAdInfo(id);
        player.clip = currentAd.video;
    }

    void OnFrameDropped(VideoPlayer source)
    {
        x -= Time.deltaTime;
    }

    void OnPrepareCompleted(VideoPlayer source)
    {
        doUpdate = true;
    }

    void OnLoopPointReached(VideoPlayer source)
    {
        player.Pause();
        player.time = 0.0f;

        sequenceIndex++;

        if (sequenceIndex >= adSequence.Length)
            sequenceIndex = 0;

        GetAdInfo(adSequence[sequenceIndex]);

        SetupLight();

        player.Play();
    }

    void SetupLight()
    {
        if(al != null)
            al.m_Color = currentAd.lightInfo[adLightIndex].ALcolor;

        foreach(Light l in additionalLights)
            l.color = currentAd.lightInfo[adLightIndex].otherColor;
    }
}
