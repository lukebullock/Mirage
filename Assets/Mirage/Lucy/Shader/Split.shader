﻿Shader "Hidden/Mirage/Lucy/SplitMesh"
{
    Properties
    {
        _Color1("", Color) = (1, 1, 1, 1)
        _Color2("", Color) = (0.4, 0.2, 0.1, 1)
        _ColorMap("", 2D) = "black"{}

        _Glossiness("", Range(0, 1)) = 0
        [Gamma] _Metallic("", Range(0, 1)) = 0

        _BumpMap("", 2D) = "bump"{}
        _BumpScale("", Float) = 1

        _OcclusionMap("", 2D) = "white"{}
        _OcclusionStrength("", Range(0, 1)) = 1
        _OcclusionContrast("", Range(0, 5)) = 1

        _BackColor("", Color) = (0, 0, 0)
    }

    CGINCLUDE

    fixed4 _Color1;
    fixed4 _Color2;
    sampler2D _ColorMap;

    half _Glossiness;
    half _Metallic;

    sampler2D _BumpMap;
    half _BumpScale;

    sampler2D _OcclusionMap;
    half _OcclusionStrength;
    half _OcclusionContrast;

    half4 _BackColor;

    float4 _Effect;

    struct Input
    {
        float2 uv_ColorMap;
    };

    // PRNG function
    float nrand(float2 uv)
    {
        return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
    }

    // Quaternion multiplication
    // http://mathworld.wolfram.com/Quaternion.html
    float4 qmul(float4 q1, float4 q2)
    {
        return float4(
            q2.xyz * q1.w + q1.xyz * q2.w + cross(q1.xyz, q2.xyz),
            q1.w * q2.w - dot(q1.xyz, q2.xyz)
        );
    }

    // Uniformaly distributed points on a unit sphere
    // http://mathworld.wolfram.com/SpherePointPicking.html
    float3 random_point_on_sphere(float2 uv)
    {
        float u = nrand(uv) * 2 - 1;
        float theta = nrand(uv + 0.333) * UNITY_PI * 2;
        float u2 = sqrt(1 - u * u);
        return float3(u2 * cos(theta), u2 * sin(theta), u);
    }

    // Vector rotation with a quaternion
    // http://mathworld.wolfram.com/Quaternion.html
    float3 rotate_vector(float3 v, float4 r)
    {
        float4 r_c = r * float4(-1, -1, -1, 1);
        return qmul(r, qmul(float4(v, 0), r_c)).xyz;
    }

    // A given angle of rotation about a given aixs
    float4 rotation_angle_axis(float angle, float3 axis)
    {
        float sn, cs;
        sincos(angle * 0.5, sn, cs);
        return float4(axis * sn, cs);
    }

    float3 displace(float3 v, float3 n)
    {
        float phi = (v.z + 1.9) * _Effect.x;
        float sn, cs;
        sincos(phi, sn, cs);
        float3x3 mtx = {
            cs, -sn, 0,
            sn, cs, 0,
            0, 0, 1
        };

        float d = nrand(v.xz + v.zy + _Effect.w) < _Effect.z;
        v += n * d * _Effect.y;

        return mul(v, mtx);
    }

    ENDCG

    SubShader
    {
        Tags { "RenderType"="Opaque" }

        CGPROGRAM

        #pragma surface surf Standard vertex:vert nolightmap addshadow
        #pragma target 3.0

        void vert(inout appdata_full v)
        {
            float3 v1 = v.vertex.xyz;
            float3 v2 = v.texcoord1.xyz;
            float3 v3 = v.texcoord2.xyz;
            float3 n = v.normal;

            v1 = displace(v1, n);
            v2 = displace(v2, n);
            v3 = displace(v3, n);

            v.vertex.xyz = v1;
            v.normal = normalize(cross(v2 - v1, v3 - v1));
        }

        void surf(Input IN, inout SurfaceOutputStandard o)
        {
            float2 uv = IN.uv_ColorMap;

            fixed4 cm = tex2D(_ColorMap, uv);
            o.Albedo = lerp(_Color1, _Color2, cm);

            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;

            fixed4 nrm = tex2D(_BumpMap, uv);
            o.Normal = UnpackScaleNormal(nrm, _BumpScale) * float3(1, -1, 1);

            fixed occ = tex2D(_OcclusionMap, uv).g;
            occ = pow(1 - occ, _OcclusionContrast);
            o.Occlusion = 1 - _OcclusionStrength * occ;
        }

        ENDCG
    }
    FallBack "Diffuse"
}
