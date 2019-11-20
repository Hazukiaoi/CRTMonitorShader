Shader "Unlit/CRT"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		[Toggle(_PIXEL_SAMPLE_ON)]_PixelSameler("像素化采样", int) = 1
		_Count ("Count", float) = 50
		_RoundScale("Round Scale", Range(0,1)) = 0.5
		_ScanSpeed("Scan Speed", float) = 10
		_ScanPow("Scan Pow", float) = 40
		_ScanLineImageJitter("Scan Line Image Jitter", Range(0,1)) = 0.012
		_ScanLineImageJitterRange("Scan Line Image Jitter Range", Range(0,1)) = 0.892
		[Toggle(_SCAN_LINE_ON)]_ScanLineOn("Scan Line On", int) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue" = "Transparent"}
		Blend SrcAlpha OneMinusSrcAlpha
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
			#pragma shader_feature __ _SCAN_LINE_ON
			#pragma shader_feature __ _PIXEL_SAMPLE_ON
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
			float _Count;
			float _RoundScale;
			float _ScanPow;
			float _ScanSpeed;
			float _ScanLineImageJitter;
			float _ScanLineImageJitterRange;

			float sdLine(in float2 p, in float2 a, in float2 b)
			{
				float2 pa = p - a, ba = b - a;
				float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
				return length(pa - ba * h);
			}


			float sdBox(in float2 p, in float2 b)
			{
				float2 d = abs(p) - b;
				return length(max(d, float2(0.0,0.0))) + min(max(d.x, d.y), 0.0);
			}

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

			fixed4 frag(v2f i) : SV_Target
			{
				// sample the texture
				//fixed4 col = tex2D(_MainTex, i.uv);
				float2 scaleDir = normalize(i.uv - float2(0.5, 0.5));
				float _scale = distance(i.uv, float2(0.5, 0.5));

				//计算弧面屏角拉伸
				float2 scaledUV = i.uv + scaleDir * pow(max(0, _scale),3) * _RoundScale;

				//获取单个Tile
				float2 uv = frac(scaledUV * (int)_Count);


				//扫描线影响
				#ifdef _SCAN_LINE_ON
					float scanLineB = pow(frac((1 - scaledUV.y * (int)_Count) / (int)_Count - _Time.z * _ScanSpeed), _ScanPow);
					float scanLineT = smoothstep(0.85, 1, scanLineB);
					float scanLine = min(1, max(scanLineB * 0.7, scanLineT));
					#ifdef _PIXEL_SAMPLE_ON
						float4 _mainTex = tex2D(_MainTex, round( (scaledUV + float2(smoothstep(1 - _ScanLineImageJitterRange, 1, scanLineB) * _ScanLineImageJitter, 0)) * (int)_Count) / (int)_Count);
					#else
						float4 _mainTex = tex2D(_MainTex, scaledUV + float2(smoothstep(1 - _ScanLineImageJitterRange, 1, scanLineB) * _ScanLineImageJitter, 0));
					#endif
					//计算实际的像素色素长度和边缘硬度
					float3 lineSize = saturate(_mainTex.rgb + scanLine) * 0.35;
					float3 smoothSizeOffset = (1 - saturate(_mainTex.rgb + scanLine)) * 0.1;
					float2 smoothSize = float2(0.1, 0.2);
				#else
					#ifdef _PIXEL_SAMPLE_ON
						float4 _mainTex = tex2D(_MainTex, round( scaledUV * (int)_Count) / (int)_Count);
					#else
						float4 _mainTex = tex2D(_MainTex, scaledUV);
					#endif
					//计算实际的像素色素长度和边缘硬度
					float3 lineSize = saturate(_mainTex.rgb) * 0.35;
					float3 smoothSizeOffset = (1 - saturate(_mainTex.rgb)) * 0.1;
					float2 smoothSize = float2(0.1, 0.2);
				#endif


				//绘制单个像素
				float dr = 1 - smoothstep(smoothSize.x - smoothSizeOffset.r, smoothSize.y + smoothSizeOffset.r, sdLine(uv, float2(0.2, 0.5 - lineSize.r), float2(0.2, 0.5 + lineSize.r)));
				float dg = 1 - smoothstep(smoothSize.x - smoothSizeOffset.g, smoothSize.y + smoothSizeOffset.g, sdLine(uv, float2(0.5, 0.5 - lineSize.g), float2(0.5, 0.5 + lineSize.g)));
				float db = 1 - smoothstep(smoothSize.x - smoothSizeOffset.b, smoothSize.y + smoothSizeOffset.b, sdLine(uv, float2(0.8, 0.5 - lineSize.b), float2(0.8, 0.5 + lineSize.b)));

				//蒙版
				float mask = (smoothstep(0.0, 0.01, scaledUV.x)) * (1 - smoothstep(0.99, 1.0, scaledUV.x)) *
					(smoothstep(0.0, 0.01, scaledUV.y)) * (1 - smoothstep(0.99, 1.0, scaledUV.y));

				//输出
				#ifdef _SCAN_LINE_ON
				float4 findColor = float4(dr, dg, db, 1) * saturate(_mainTex + scanLine);
				#else
				float4 findColor = float4(dr, dg, db, 1) * _mainTex;
				#endif

				findColor.a = mask;
                //return float4(dr,dg,db, mask) * _mainTex;
				return findColor;


            }
            ENDCG
        }
    }
}
