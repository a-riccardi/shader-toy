using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Video;

public enum AdvertisementID { COCA_COLA_HORIZONTAL, COCA_COLA_VERTICAL, BAJITOUHU, ATARI, BEAUTY_1, BEAUTY_2, ZAIBATZU, GEISHA_HORIZONTA, GEISHA_VERTICAL }

[System.Serializable]
public struct AdLight
{
    public Color ALcolor;
    public Color otherColor;
}

[System.Serializable]
public struct Ad
{
    public AdvertisementID ID;
    public VideoClip video;
    public AdLight[] lightInfo;
}

public class AdManager_VS : MonoBehaviour
{
    static AdManager_VS singleton;

    [SerializeField] List<Ad> advertisements;

    Dictionary<AdvertisementID, Ad> advertisementInfo;

	void Awake ()
    {
        if (singleton != null)
        {
            Destroy(this);
            enabled = false;
            return;
        }

        singleton = this;

        Setup();
	}

    void Setup()
    {
        advertisementInfo = new Dictionary<AdvertisementID, Ad>();

        foreach (Ad ad in advertisements)
        {
            if (!advertisementInfo.ContainsKey(ad.ID))
                advertisementInfo.Add(ad.ID, ad);
            else
                Debug.LogError("Two ads with the same ID [" + ad.ID.ToString() + "] were found! pleas check the correct ID is attributed.");
        }

        advertisements.Clear();
    }

    public static Ad GetAdInfo(AdvertisementID id)
    {
        if (singleton == null)
        {
            Debug.LogError("AdManager_VS.GetAdInfo(" + id.ToString() + ") was called but singleton was null! Aborting.");
            return new Ad();
        }

        return singleton._GetAdInfo(id);
    }

    Ad _GetAdInfo(AdvertisementID id)
    {
        return advertisementInfo[id];
    }
}
