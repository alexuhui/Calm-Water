using System;
using System.Collections;
using System.Collections.Generic;
using System.Reflection;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using Object = UnityEngine.Object;

public class CommonShaderGUI : ShaderGUI
{
    MaterialEditor editor;
    Object[] materials;
    MaterialProperty[] properties;

    private GUIStyle _PRDisabledLabel;
    private GUIStyle PRDisabledLabel
    {
        get { if (_PRDisabledLabel == null) _PRDisabledLabel = new GUIStyle("PR DisabledLabel");
            return _PRDisabledLabel;
        }
    }


    bool showRenderingMode = true;
    bool showKeywords = false;
    bool showLocalKeywords = false;
    bool showGlobalKeywords = false;
    int renderQueueOffset = 0;
    bool unsafeMode = false;
    bool hasInit = false;

    HashSet<string> unsafePro = new HashSet<string> {
        "_SrcBlend",
        "_DstBlend",
        "_ZWriteMode",
        "_CullMode",
        "_ZTestMode",
        "_ColorMask",
    };

    HashSet<string> hiddenPro = new HashSet<string>
    {
        "_ALPHATEST_ON",
    };

    Dictionary<string, Func<string, bool>> conditionalPro = new Dictionary<string, Func<string, bool>>();
    private void InitConditionalPro()
    {
        conditionalPro.Add("_CutOff", CheckKeyworld);
    }



    bool CullOut
    {
        set => SetPropertyAndKeyworld("_ALPHATEST_ON", "_ALPHATEST_ON", value, false);
    }

    BlendMode SrcBlend
    {
        set => SetProperty("_SrcBlend", (float)value);
    }

    BlendMode DstBlend
    {
        set => SetProperty("_DstBlend", (float)value);
    }

    bool ZWrite
    {
        set => SetProperty("_ZWriteMode", value ? 1f : 0f);
    }
    RenderQueue RenderQueue
    {
        set
        {
            foreach (Material m in materials)
            {
                m.renderQueue = (int)value;
            }
        }
        get {
            return materials.Length > 0 ? (RenderQueue)(materials[0] as Material).renderQueue : RenderQueue.Geometry;
        }
    }

    bool HasProperty(string name) => FindProperty(name, properties, false) != null;
    bool HasCutOff => HasProperty("_CutOff");


    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        editor = materialEditor;
        materials = materialEditor.targets;
        this.properties = properties;
        if (!hasInit)
        {
            hasInit = true;
            Init();
        }

        for (int i = 0; i < properties.Length; i++)
        {
            var pro = properties[i];
            if (hiddenPro.Contains(pro.name)) continue;
            if (unsafePro.Contains(pro.name)) continue;

            conditionalPro.TryGetValue(pro.name, out Func<string, bool> condition);
            if (condition != null && !condition.Invoke(pro.name)) continue;

            materialEditor.ShaderProperty(pro, pro.displayName);
        }
        EditorGUILayout.Space(10);


        showRenderingMode = EditorGUILayout.Foldout(showRenderingMode, "Rendering Mode", true);
        if (!showRenderingMode) return;
        OpaquePreset();
        ClipPreset();
        TransparentPreset();

        int tempOffset = EditorGUILayout.IntSlider("Render Queue Offset", renderQueueOffset, 0, 200);
        if(renderQueueOffset != tempOffset)
        {
            int add = tempOffset - renderQueueOffset;
            RenderQueue += add;
            renderQueueOffset = tempOffset;
        }

        EditorGUILayout.Space(10);
        GUILayout.Label("正常情况下，请勿直接修改以下参数！");
        unsafeMode = EditorGUILayout.Toggle("非安全模式 (慎用)", unsafeMode);
        EditorGUI.BeginDisabledGroup(!unsafeMode);
        for (int i = 0; i < properties.Length; i++)
        {
            var pro = properties[i];
            if (!unsafePro.Contains(pro.name)) continue;
            materialEditor.ShaderProperty(pro, pro.displayName);
        }
        materialEditor.RenderQueueField();
        EditorGUI.EndDisabledGroup();

        GUILayout.Space(5);
        DrawKeyworlds();
       // GUIDebug(materialEditor, properties);
    }

    private void DrawKeyworlds()
    {
        showKeywords = EditorGUILayout.Foldout(showKeywords, "Keywords", true);
        if (showKeywords)
        {
            if (materials.Length > 0)
            {
                var mat = materials[0] as Material;

                EditorGUI.indentLevel++;
                {

                    showLocalKeywords = EditorGUILayout.Foldout(showLocalKeywords, "Local", true);
                    if (showLocalKeywords)
                    {
                        EditorGUI.indentLevel++;
                        {
                            var localKws = mat.shaderKeywords;
                            for (int i = 0; i < localKws.Length; i++)
                            {
                                EditorGUILayout.LabelField(localKws[i]);
                            }
                        }
                        EditorGUI.indentLevel--;
                    }

                    showGlobalKeywords = EditorGUILayout.Foldout(showGlobalKeywords, "Global", true);
                    if (showGlobalKeywords)
                    {
                        EditorGUI.indentLevel++;
                        {
                            var globalKws = GetGlobalKeywords(mat.shader);
                            for (int i = 0; i < globalKws.Length; i++)
                            {
                                if (Shader.IsKeywordEnabled(globalKws[i]))
                                    EditorGUILayout.LabelField(globalKws[i]);
                                else
                                    EditorGUILayout.LabelField(globalKws[i], PRDisabledLabel);
                            }
                        }
                        EditorGUI.indentLevel--;
                    }
                }
                EditorGUI.indentLevel--;
            }
        }
    }

    private string[] GetGlobalKeywords(Shader shader)
    {
        var getKeywordsMethod = typeof(ShaderUtil).GetMethod("GetShaderGlobalKeywords", BindingFlags.Static | BindingFlags.NonPublic);
        string[] keywords = (string[])getKeywordsMethod.Invoke(null, new object[] { shader });
        return keywords;
    }

    private void GUIDebug(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        if (GUILayout.Button("properties"))
        {
            foreach (var pro in properties)
            {
                Debug.LogFormat("name : {0}   displayName : {1}", pro.name, pro.displayName);
            }
        }
    }

    private void Init()
    {
        hasInit = true;
        SupportedRenderingFeatures.active.editableMaterialRenderQueue = false;
        InitConditionalPro();

        int[] rq = (int[])Enum.GetValues(typeof(RenderQueue));
        for(int i = rq.Length-1; i >= 0; i --)
        {
            renderQueueOffset = (int)RenderQueue - rq[i];
            if (renderQueueOffset >= 0) break;
        }
    }

    bool PresetButton(string name)
    {
        if (GUILayout.Button(name))
        {
            editor.RegisterPropertyChangeUndo(name);
            return true;
        }
        return false;
    }

    void OpaquePreset()
    {
        if (PresetButton("Opaque"))
        {
            CullOut = false;
            SrcBlend = BlendMode.One;
            DstBlend = BlendMode.Zero;
            ZWrite = true;
            RenderQueue = RenderQueue.Geometry + renderQueueOffset;
            SetOverrideTag("RenderType", "Opaque");
        }
    }
    void ClipPreset()
    {
        if (HasCutOff && PresetButton("CullOut"))
        {
            CullOut = true;
            SrcBlend = BlendMode.One;
            DstBlend = BlendMode.Zero;
            ZWrite = true;
            RenderQueue = RenderQueue.AlphaTest + renderQueueOffset;
            SetOverrideTag("RenderType", "TransparentCutout");
        }
    }

    void TransparentPreset()
    {
        if (PresetButton("Transparent"))
        {
            CullOut = false;
            SrcBlend = BlendMode.SrcAlpha;
            DstBlend = BlendMode.OneMinusSrcAlpha;
            ZWrite = false;
            RenderQueue = RenderQueue.Transparent + renderQueueOffset;
            SetOverrideTag("RenderType", "Transparent");
            SetOverrideTag("IgnoreProjector", "True");
        }
    }

    void SetPropertyAndKeyworld(string name, string keyword, bool value, bool checkPro = true)
    {
        if(SetProperty(name, value ? 1f : 0f))
        {
            SetKeyword(keyword, value);
        }
    }

    bool SetProperty(string name, float value)
    {
        MaterialProperty property = FindProperty(name, properties, false);
        if(property != null)
        {
            property.floatValue = value;
            return true;
        }
        return false;
    }

    void SetKeyword(string keyword, bool enabled)
    {
        if (enabled)
        {
            foreach (Material m in materials)
            {
                m.EnableKeyword(keyword);
            }
        }
        else
        {
            foreach (Material m in materials)
            {
                m.DisableKeyword(keyword);
            }
        }
    }

    private bool CheckKeyworld(string keyworld)
    {
        return materials.Length > 0 ? (materials[0] as Material).IsKeywordEnabled("_ALPHATEST_ON") : false;
    }

    void SetOverrideTag(string tag, string value)
    {
        foreach (Material m in materials)
        {
            m.SetOverrideTag(tag, value);
        }
    }
}
