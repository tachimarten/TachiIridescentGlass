Shader "Tachi/Iridescent Glass" {
    // *INDENT-OFF*
    Properties {
        _Color("Color", Color) = (1, 1, 1, 1)
        _Specular("Specular", Color) = (0.3, 0.3, 0.3, 1)
        _MainTex("Dummy Texture", 2D) = "white" {}

        _Glossiness("Smoothness", Range(0, 1)) = 0.5

        _Wavelength("Diffraction Wavelength", Range(300, 10000)) = 1600
        _DiffractionLUT("Diffraction LUT", 2D) = "white" {}

        _IOR("Index of Refraction", Range(-3, 3)) = 1.45
        _RefractionDistance("Refraction Distance", Range(0.001, 0.03)) = 0.01

        _TessFactor("Tess. Factor", Range(50, 100)) = 75
        _MaxTessLevel("Max Tess. Level", Range(1, 6)) = 6
    }
    // *INDENT-ON*

    SubShader {
        Tags {
            "RenderType" = "Opaque"
        }

        GrabPass {}

        LOD 200

        CGPROGRAM

// Physically based Standard lighting model, and enable shadows on all light types.
//
// See the Unity documentation [2] for more things you can put here.
//
// You must include `tessellate:mainTessControl vertex:fakeVert` here for tessellation to work.
//
// [2]: https://docs.unity3d.com/Manual/SL-SurfaceShaders.html

// *INDENT-OFF*
#pragma surface mainSurface StandardIridescentGlass addshadow fullforwardshadows tessellate:mainTessControl vertex:fakeVert
// *INDENT-ON*

// Use shader model 4.6 target for tessellation.
#pragma target 4.6

        // This must go *before* `TachiTess.cginc` is included.
        void fakeVert(inout appdata_full unusedArg) {
            // Unused.
        }

#include "TachiTess.cginc"
#include "UnityPBSLighting.cginc"

#define DIFFRACTION_LUT_MIN_WAVELENGTH 0.0
#define DIFFRACTION_LUT_MAX_WAVELENGTH (780.0*8.0)

        sampler2D _MainTex;
        sampler2D _DiffractionLUT;
        sampler2D _GrabTexture;

        struct Input {
            float2 uv_MainTex;
            float3 worldPos;
            float3 worldNormal;
        };

        float _BumpScale;
        float _Glossiness;
        float _Metallic;
        float4 _Color;
        float4 _Specular;
        float _Wavelength;
        float _IOR;
        float _RefractionDistance;

        struct MySurfaceOutputStandardSpecular {
            fixed3 Albedo;      // diffuse color
            fixed3 Specular;    // specular color
            float3 Normal;      // tangent space normal, if written
            half3 Emission;
            half Smoothness;    // 0=rough, 1=smooth
            half Occlusion;     // occlusion (default 1)
            fixed Alpha;        // alpha for transparencies

            float2 uv;
            float3 background;
            float3 tangent;
            //float3 realNormal;
        };

        UNITY_INSTANCING_BUFFER_START(Props)
        // Per-instance properties go here.
        UNITY_INSTANCING_BUFFER_END(Props)

        // The basic surface shader.
        void mainSurface(Input input, inout MySurfaceOutputStandardSpecular inoutOutput) {
            float3 viewDir = normalize(input.worldPos - _WorldSpaceCameraPos);
            float3 normal = length(input.worldNormal) < 0.0001 ?
                float3(0.0, 0.0, 1.0) :
                normalize(input.worldNormal);
            float3 refractedDir = refract(viewDir, normal, _IOR);

            inoutOutput.uv = input.uv_MainTex;

            float4 grabUV = ComputeGrabScreenPos(mul(UNITY_MATRIX_VP,
                float4(input.worldPos + refractedDir * _RefractionDistance, 1.0)));

            float4 background = tex2Dproj(_GrabTexture, UNITY_PROJ_COORD(grabUV));
            inoutOutput.background = background.rgb;

            inoutOutput.Albedo = _Color.rgb;
            inoutOutput.Specular = _Specular.rgb;
            inoutOutput.Smoothness = _Glossiness;
            inoutOutput.Alpha = _Color.a;
        }

        SurfaceOutputStandardSpecular toSurfaceOutputStandardSpecular(MySurfaceOutputStandardSpecular output) {
            SurfaceOutputStandardSpecular specularOutput;
            specularOutput.Albedo = output.Albedo;
            specularOutput.Specular = output.Specular;
            specularOutput.Normal = output.Normal;
            specularOutput.Emission = output.Emission;
            specularOutput.Smoothness = output.Smoothness;
            specularOutput.Occlusion = output.Occlusion;
            specularOutput.Alpha = output.Alpha;
            return specularOutput;
        }

        inline float4 LightingStandardIridescentGlass(
                MySurfaceOutputStandardSpecular output,
                float3 viewDir,
                UnityGI globalIllumination) {
            float3 background = output.background;
            float2 uv = output.uv;

            SurfaceOutputStandardSpecular specularOutput = toSurfaceOutputStandardSpecular(output);
            float4 pbrColor = LightingStandardSpecular(specularOutput, viewDir, globalIllumination);

            float3 lightDir = normalize(globalIllumination.light.dir);
            viewDir = normalize(viewDir);
            float3 tangent = output.Normal;

            float diffraction = abs(dot(tangent, lightDir) - dot(tangent, viewDir));
            float lutU = (diffraction * _Wavelength - DIFFRACTION_LUT_MIN_WAVELENGTH) /
                (DIFFRACTION_LUT_MAX_WAVELENGTH - DIFFRACTION_LUT_MIN_WAVELENGTH);
            float4 diffractedColor = tex2D(_DiffractionLUT, float2(lutU, 0.5));

            return float4(lerp(background, pbrColor.rgb + diffractedColor.rgb, pbrColor.a), 1.0);
        }

        inline void LightingStandardIridescentGlass_GI(
                MySurfaceOutputStandardSpecular output,
                UnityGIInput input,
                inout UnityGI globalIllumination) {
            SurfaceOutputStandardSpecular specularOutput = toSurfaceOutputStandardSpecular(output);
            LightingStandardSpecular_GI(specularOutput, input, globalIllumination);
        }

        ENDCG
    }

    FallBack "Standard"
}

