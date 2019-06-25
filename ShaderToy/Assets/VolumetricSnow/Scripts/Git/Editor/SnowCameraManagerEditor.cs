using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(SnowCameraManager))]
[CanEditMultipleObjects]
public class SnowCameraManagerEditor : Editor
{
    SerializedProperty whitePatch;
    SerializedProperty bufferSize;
    SerializedProperty kernelSize;
    SerializedProperty depthProcessorMaterial;
    SerializedProperty persistence;

    void OnEnable()
    {
        whitePatch = serializedObject.FindProperty("whitePatch");
        bufferSize = serializedObject.FindProperty("bufferSize");
        kernelSize = serializedObject.FindProperty("kernelSize");
        depthProcessorMaterial = serializedObject.FindProperty("depthProcessorMaterial");
        persistence = serializedObject.FindProperty("persistence");
    }

    public override void OnInspectorGUI()
    {
        serializedObject.Update();

        whitePatch.objectReferenceValue = (Texture2D) EditorGUILayout.ObjectField("White Patch", whitePatch.objectReferenceValue, typeof(Texture2D), false);
        depthProcessorMaterial.objectReferenceValue = (Material)EditorGUILayout.ObjectField("Dephth Processor Material", depthProcessorMaterial.objectReferenceValue, typeof(Material), false);

        EditorGUI.BeginChangeCheck();
        bufferSize.intValue = (int)(BufferSize)EditorGUILayout.EnumPopup("Buffer Size:", (BufferSize)bufferSize.intValue);     
        kernelSize.intValue = (int)(KernelSize)EditorGUILayout.EnumPopup("Kernel Size:", (KernelSize)kernelSize.intValue);
        persistence.floatValue = EditorGUILayout.Slider("Persistance: ", persistence.floatValue, 0.0f, 10000.0f);

        serializedObject.ApplyModifiedProperties();

        if (EditorGUI.EndChangeCheck())
            (serializedObject.targetObject as SnowCameraManager).Editor_UpdateValues();
    }
}
