// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

#ifndef CALMWATER_DX11_INCLUDED
#define CALMWATER_DX11_INCLUDED

#include "WaterHelper.cginc"
//Uncomment to enable enviro support
//#include "../../Enviro - Dynamic Enviroment/Resources/Shaders/Core/EnviroFogCore.cginc"

#ifndef LIGHTCOLOR
#define LIGHTCOLOR
uniform fixed4 _LightColor0;
#endif

// ===========================================================================================

struct appdata {
    float4 vertex 	: POSITION;
    float3 normal 	: NORMAL;
    float4 tangent 	: TANGENT;
    float2 texcoord : TEXCOORD0;
    float2 texcoord1 : TEXCOORD1;
	float4 color 	: COLOR;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};


// V2F
struct v2f {
    float4 pos 			: SV_POSITION;
    fixed4 ambient  	: COLOR;

    half4 tspace0 : TEXCOORD0; // tangent.x, bitangent.x, normal.x
    half4 tspace1 : TEXCOORD1; // tangent.y, bitangent.y, normal.y
    half4 tspace2 : TEXCOORD2; // tangent.z, bitangent.z, normal.z

    float3 worldPos : TEXCOORD3; // w = distance
    float4 GrabUV 	: TEXCOORD4;
    float4 DepthUV	: TEXCOORD5;

	#if _BUMPMODE_SINGLE ||_BUMPMODE_DUAL
    float4 AnimUV	: TEXCOORD6;
	#endif
	#if _BUMPMODE_DUAL
	float2 AnimUV2 	: TEXCOORD7;
	#endif
	#if _BUMPMODE_FLOWMAP
	float2 BumpUV		: TEXCOORD6;
	float2 FlowMapUV	: TEXCOORD7;
	#endif

    //#ifdef UNITY_PASS_FORWARDADD
    UNITY_SHADOW_COORDS(8)
    //#endif

    #ifdef UNITY_PASS_FORWARDBASE
    UNITY_FOG_COORDS(9)
    #endif

    #ifndef SHADER_API_D3D9
    #if _FOAM_ON || _WHITECAPS_ON
    float4 FoamUV	: TEXCOORD10;
    #endif
    #endif



	UNITY_VERTEX_OUTPUT_STEREO
};

void displacement (inout appdata v)
{

	half4 worldSpaceVertex 	= mul(unity_ObjectToWorld,(v.vertex));
	half3 offsets;
	half3 nrml;

	#if _DISPLACEMENTMODE_WAVE
		Wave (
			offsets, nrml, v.vertex.xyz,worldSpaceVertex,
			_Amplitude,
			_Frequency,
			_Speed
		);
		v.vertex.y 		+= offsets.y;
		v.normal 		= nrml;
		v.color.a		= offsets.y;

	#endif

	#if _DISPLACEMENTMODE_GERSTNER
		half3 vtxForAni 		= (worldSpaceVertex.xyz).xzz; // REMOVE VARIABLE
		Gerstner (
			offsets, nrml, v.vertex.xyz, vtxForAni,				// offsets, nrml will be written
			_Amplitude * 0.01,									// amplitude
			_Frequency,											// frequency
			_Steepness,											// steepness
			_WSpeed,											// speed
			_WDirectionAB,										// direction # 1, 2
			_WDirectionCD										// direction # 3, 4									
		);

		v.vertex.xyz += offsets;
		v.normal 	= nrml;
		v.color.a	= offsets.y;

	#endif

#if _DISPLACEMENTMODE_TEXTURE
	
	//offs, nrml, vtx, intensity, vectorLength
	TextureDisplacement(offsets, nrml, v.vertex, _Amplitude * 0.02, 1);

	v.vertex.y += offsets.y;
	v.normal = nrml;
	v.color.a = offsets.y;

#endif

}

// Vertex
v2f vert (appdata v) {
    //v2f o = (v2f)0;

    v2f o;
	UNITY_SETUP_INSTANCE_ID(v);
	UNITY_INITIALIZE_OUTPUT(v2f, o);
	UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

	#if !_DISPLACEMENTMODE_OFF
		displacement(v);
	#endif

    o.pos 			= UnityObjectToClipPos(v.vertex);
    o.GrabUV 		= ComputeGrabScreenPos(o.pos);
    o.DepthUV 		= ComputeScreenPos(o.pos);
	COMPUTE_EYEDEPTH(o.DepthUV.z);

	//Normals
	float4 worldPos 	= mul(unity_ObjectToWorld, v.vertex);
	float3 worldNormal 	= UnityObjectToWorldNormal(v.normal);
	float3 worldTangent	= UnityObjectToWorldNormal(v.tangent.xyz);
	float3 worldBinormal = cross(worldTangent,worldNormal);

	o.tspace0 	= float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
	o.tspace1 	= float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
	o.tspace2 	= float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);
	o.worldPos 	= worldPos;

	o.ambient.rgb 	= ShadeSH9(half4(worldNormal,1));
	o.ambient.a		= v.color.a;

	//UV Animation
	#if _BUMPMODE_SINGLE || _BUMPMODE_DUAL
		#if _WORLDSPACE_ON
		o.AnimUV = 	AnimateBump(worldPos.xz);
		#else
		o.AnimUV = 	AnimateBump(v.texcoord);
		#endif
	#endif

	#if _BUMPMODE_DUAL
		#if _WORLDSPACE_ON
		o.AnimUV2 =  AnimateLargeBump(_BumpMapLarge_ST, worldPos.xz, _SpeedsLarge.xy );
		#else
		o.AnimUV2 =  AnimateLargeBump(_BumpMapLarge_ST, v.texcoord, _SpeedsLarge.xy );
		#endif
	#endif
	#if _BUMPMODE_FLOWMAP
		#if _WORLDSPACE_ON
			o.BumpUV = TRANSFORM_TEX(worldPos.xz, _BumpMap);
			o.FlowMapUV = TRANSFORM_TEX(worldPos.xz, _FlowMap);
		#else
			o.BumpUV = TRANSFORM_TEX(v.texcoord, _BumpMap);
			o.FlowMapUV = TRANSFORM_TEX(v.texcoord, _FlowMap);
		#endif
	#endif

	//Foam
	#ifndef SHADER_API_D3D9
		#if _FOAM_ON || _WHITECAPS_ON

			o.FoamUV = float4(0,0,0,0);
			// Shore Foam
			#if _WORLDSPACE_ON
			o.FoamUV.xy =	TRANSFORM_TEX(worldPos.xz,_FoamTex);
			#else
			o.FoamUV.xy =	TRANSFORM_TEX(v.texcoord,_FoamTex);
			#endif

			// White Caps
			#if _WHITECAPS_ON

			#if _WORLDSPACE_ON
			o.FoamUV.zw =	TRANSFORM_TEX(worldPos.xz, _CapsMask);
			#else
			o.FoamUV.zw =	TRANSFORM_TEX(v.texcoord, _CapsMask);
			#endif
			// Animate Caps
			o.FoamUV.zw += frac(_CapsSpeed * _Time.x).xx;

			#endif
		#endif
	#endif

	#ifdef UNITY_PASS_FORWARDBASE
	UNITY_TRANSFER_FOG(o,o.pos);
	#endif

	UNITY_TRANSFER_SHADOW(o,v.texcoord1.xy); // pass shadow coordinates to pixel shader

    return o;
}

// ============================================
// Frag
// ============================================
fixed4 frag( v2f i ) : SV_Target
{
	// =========================================
	// Directions
	// =========================================

	// World ViewDir
	float3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.worldPos.xyz));
	
	#ifdef CULL_FRONT
		worldViewDir = -worldViewDir;
	#endif

	// World LightDir
	#ifndef USING_DIRECTIONAL_LIGHT
		float3 lightDir = normalize(UnityWorldSpaceLightDir(i.worldPos.xyz));
	#else
		float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
	#endif

	// NormalMaps
	half3 finalBump = half3(0, 0, 1);

	#if _BUMPMODE_SINGLE || _BUMPMODE_DUAL
	half4 n1	= tex2D(_BumpMap, i.AnimUV.xy);
	half4 n2 	= tex2D(_BumpMap, i.AnimUV.zw);

	#if _BUMPMODE_DUAL
	half4 n3 	= tex2D(_BumpMapLarge, i.AnimUV2);
	finalBump 	= UnpackNormalBlend(n1,n2,n3, _BumpStrength,_BumpLargeStrength);
	#else
	finalBump 	= UnpackNormalBlend(n1,n2, _BumpStrength);
	#endif
	#endif

	#if _BUMPMODE_FLOWMAP
	half4 bump	= SampleFlowMap(_BumpMap, i.BumpUV, _FlowMap, i.FlowMapUV, _FlowSpeed, _FlowIntensity);
	finalBump	= UnpackNormalScale(bump, _BumpStrength);
	#endif

	// World Normal
	half3 worldN = WorldNormal(i.tspace0.xyz, i.tspace1.xyz, i.tspace2.xyz, finalBump);
	// Vertex Normals
	//half3 vertexNormals = half3(i.tspace0.z, i.tspace1.z, i.tspace2.z);

	// Atten
	#ifdef UNITY_PASS_FORWARDADD
		UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos.xyz)
	#endif


	// ========================================
	// Textures
	// ========================================

	float2 offset = worldN.xz * _GrabTexture_TexelSize.xy * _Distortion;

	// Depth Distortion ===================================================
	float4 DepthUV 	= OffsetDepth(i.DepthUV,offset);
	// GrabPass Distortion ================================================
	float4 GrabUV 	= OffsetUV(i.GrabUV,offset);
	
	// Refraction ============================================================
	// RGB 	= Color
	// A 	= Depth
	// =======================================================================
	half4 refraction 		= tex2Dproj( _GrabTexture, UNITY_PROJ_COORD(GrabUV));
	half4 cleanRefraction  	= tex2Dproj(_GrabTexture, UNITY_PROJ_COORD(i.GrabUV));
	
	//Depth Texture Clean
	float sceneZ 	= texDepth(_CameraDepthTexture,i.DepthUV);
	//Depth Texture Distorted
	float DistZ 	= texDepth(_CameraDepthTexture,DepthUV);

	//Depth	
	refraction.a		= DistanceFade(DistZ, DepthUV.z, _DepthStart, _DepthEnd);
	//Clean Depth
	cleanRefraction.a	= DistanceFade(sceneZ, i.DepthUV.z, _DepthStart, _DepthEnd);


	//TODO: Remove keyword in cull front pass and remove check CULL_FRONT here
	#ifndef CULL_FRONT
		#if _DISTORTIONQUALITY_HIGH 
		//Hide refraction from objects over the surface		
		refraction = DepthUV.z > DistZ ? cleanRefraction : refraction;        
		#endif
	#endif
	
	//Final color with depth and refraction
	#ifndef CULL_FRONT
		#if _DEPTHFOG_ON
			fixed3 finalColor = lerp(_Color.rgb * refraction.rgb, _DepthColor.rgb * _LightColor0.rgb , 1.0 - refraction.a);
		#else
			fixed3 finalColor = lerp(_Color.rgb,_DepthColor.rgb, 1.0 - refraction.a) * refraction.rgb;
		#endif
	#else
		fixed3 finalColor = lerp(_Color.rgb,_DepthColor.rgb, 0.5) * refraction.rgb;
	#endif


	#ifdef UNITY_PASS_FORWARDBASE
		// ===========================================================================
		// Caustics
		// ===========================================================================
		#ifndef CULL_FRONT
			#if _CAUSTICS_ON
			float2 causticsUV = ProjectedWorldPos(i.worldPos.xyz, DistZ, DepthUV.z).xz / _CausticsTex_ST.xy + _CausticsTex_ST.zw;
			causticsUV += worldN.xy * 0.15;
			causticsUV += frac(_Time.x * _CausticsSpeed);

			float causticsDepth = DistanceFade(DistZ, DepthUV.z, _CausticsStart, _CausticsEnd);

			finalColor += tex2D(_CausticsTex, causticsUV) * causticsDepth * finalColor * _CausticsIntensity * _LightColor0.rgb;
			#endif
		#endif
		
		// ===========================================================================
		// Light Scatter
		// ===========================================================================

		#if _SCATTER_ON
			half sunScatter		= max(0.0, dot(lightDir, -worldViewDir)) * _ScatterParams.x;
			half waveTips		= smootherstep(i.ambient.a * _ScatterParams.y) ;
			float scatterMask	= pow(saturate(sunScatter) + saturate(waveTips), _ScatterParams.z);

			finalColor += _ScatterColor * saturate(scatterMask) * _LightColor0.rgb;
		#endif

	#endif

	// =====================================================================
	// Reflections 
	// No Reflection on backface
	// =====================================================================
	#ifndef CULL_FRONT

		//Reverse cubeMap Y to look like reflection
		#if _REFLECTIONTYPE_MIXED || _REFLECTIONTYPE_CUBEMAP
		half3 worldRefl 	= reflect(-worldViewDir, half3(worldN.x * _CubeDist,1,worldN.z * _CubeDist));
		half3 cubeMap 		= texCUBE(_Cube, worldRefl).rgb * _CubeColor.rgb;
		#endif

		#if _REFLECTIONTYPE_MIXED || _REFLECTIONTYPE_REALTIME
		//Real Time reflections

		//TODO: Upgrade to GrabUV when unity fixes its bug
		fixed3 rtReflections = tex2Dproj(_ReflectionTex, UNITY_PROJ_COORD(DepthUV)) * _Reflection;
		#endif

		#if _REFLECTIONTYPE_MIXED
		fixed3 finalReflection = lerp(cubeMap,rtReflections, 0.5);
		#endif

		#if _REFLECTIONTYPE_REALTIME
		fixed3 finalReflection = rtReflections;
		#endif

		#if _REFLECTIONTYPE_CUBEMAP
		fixed3 finalReflection = cubeMap;
		#endif
	//end CULL_FRONT
	#endif 

	// ===========================================================================
	// Apply Reflections
	// ===========================================================================
	#ifndef CULL_FRONT
	float NdotV = NdotVTerm(worldN, worldViewDir);

	#if _REFLECTIONTYPE_MIXED || _REFLECTIONTYPE_REALTIME || _REFLECTIONTYPE_CUBEMAP
			
			// TEST: Use vertex normal for reflection fresnel
			//float NdotVertex = NdotVTerm(vertexNormals, worldViewDir);

			half fresnel = smoothstep( 1- saturate(NdotV), 0, _RimPower);
			finalColor = lerp(finalColor, finalReflection, fresnel * _Reflection);
	#endif
	#endif

	#if _FOAM_ON || _WHITECAPS_ON

		#ifndef SHADER_API_D3D9
		float2 foamUV = i.FoamUV.xy;
		#else
		float2 foamUV = i.worldPos.xz;
		#endif

		fixed foamMask = 0;
		//Foam Texture with animation
		fixed3 foamTex = tex2D(_FoamTex,foamUV + (finalBump.xy * 0.05)).r;

		// ===========================================================================
		// FOAM
		// ===========================================================================
		#if _FOAM_ON
			//Border Foam Mask 
			foamMask = 1.0 - saturate(_FoamSize * (sceneZ-DepthUV.z));
		#endif

		// ===========================================================================
		// WHITE CAPS
		// ===========================================================================
		#if _WHITECAPS_ON
			#ifndef SHADER_API_D3D9
			float2 maskUV = i.FoamUV.zw;
			#else
			float2 maskUV = i.worldPos.xz;
			#endif

			fixed capsMask = tex2D(_CapsMask,maskUV);

			#if _DISPLACEMENTMODE_WAVE || _DISPLACEMENTMODE_GERSTNER || _DISPLACEMENTMODE_TEXTURE
			capsMask *= i.ambient.a;
			#endif

			capsMask = smoothstep(0,_CapsSize,capsMask);
			foamMask = max(_CapsIntensity * capsMask, foamMask);
		#endif

		foamTex 	*= foamMask.xxx * _FoamColor.rgb * max(_LightColor0.rgb ,i.ambient.rgb);
		finalColor	+= min(1.0, 2.0 * foamTex);

	#endif
	// ===========================================================================
	// Specular
	// ===========================================================================

#ifndef CULL_FRONT
	float waveFresnel = FresnelSpecular(saturate(NdotV), _specFresnel);
	finalColor += waveFresnel *_LightColor0.rgb * _SpecColor.rgb * UNITY_LIGHTMODEL_AMBIENT * _specIntensity;
#endif


	fixed3 specColor 	= SpecularColor (_Smoothness,lightDir,worldViewDir,worldN);

	//Albedo
	fixed3 diff = finalColor.rgb;// *(DiffuseTerm(worldN, lightDir) * 0.5 + 0.5 + i.ambient.rgb);

	#ifdef UNITY_PASS_FORWARDADD
	diff *= _LightColor0.rgb;
	#endif

	diff += specColor;

	//Alpha
	fixed alpha			= _EdgeFade * (sceneZ-DepthUV.z) * _Color.a;

	fixed4 c;

	#ifndef UNITY_PASS_FORWARDADD
		//Uncomment to enable enviro support
		//half2 screenUV = (i.pos.xy / i.pos.w) * _ProjectionParams.x * 0.5 + 0.5;
		//diff = TransparentFog(float4(diff, 0), i.worldPos, screenUV, i.DepthUV.z).rgb;

		c.rgb 	= lerp(cleanRefraction.rgb,diff, saturate(alpha) );
		UNITY_APPLY_FOG(i.fogCoord, c);
	#else
    	c.rgb 	= diff * saturate(alpha) * atten;
	#endif
	
	c.a 	= 1;


	return c;
}

#ifdef DX11
#ifdef UNITY_CAN_COMPILE_TESSELLATION
	struct TessVertex {
		float4 vertex 	: INTERNALTESSPOS;
		float3 normal 	: NORMAL;
		float4 tangent 	: TANGENT;
		float2 texcoord : TEXCOORD0;
		#ifdef UNITY_PASS_FORWARDADD
		float2 texcoord1 : TEXCOORD1;
		#endif
		//float4 color 	: COLOR;
	};

	struct OutputPatchConstant {
		float edge[3]         : SV_TessFactor;
		float inside          : SV_InsideTessFactor;
	};
	TessVertex tessvert (appdata v) {
		TessVertex o;
		o.vertex 	= v.vertex;
		o.normal 	= v.normal;
		o.tangent 	= v.tangent;
		o.texcoord 	= v.texcoord;
		#ifdef UNITY_PASS_FORWARDADD
		o.texcoord1	= v.texcoord1;
		#endif
		//o.color 	= v.color;
		return o;
	}

    float4 Tessellation(TessVertex v, TessVertex v1, TessVertex v2){
        return UnityEdgeLengthBasedTess(v.vertex, v1.vertex, v2.vertex, 32 - _Tess);
    }

    OutputPatchConstant hullconst (InputPatch<TessVertex,3> v) {
        OutputPatchConstant o;
        float4 ts = Tessellation( v[0], v[1], v[2] );
        o.edge[0] = ts.x;
        o.edge[1] = ts.y;
        o.edge[2] = ts.z;
        o.inside = ts.w;
        return o;
    }

    [domain("tri")]
    [partitioning("fractional_odd")]
    [outputtopology("triangle_cw")]
    [patchconstantfunc("hullconst")]
    [outputcontrolpoints(3)]
    TessVertex hs_surf (InputPatch<TessVertex,3> v, uint id : SV_OutputControlPointID) {
        return v[id];
    }

    [domain("tri")]
    v2f ds_surf (OutputPatchConstant tessFactors, const OutputPatch<TessVertex,3> vi, float3 bary : SV_DomainLocation) {
        appdata v = (appdata)0;

        v.vertex 	= vi[0].vertex*bary.x 	+ vi[1].vertex*bary.y 	+ vi[2].vertex*bary.z;
        v.texcoord 	= vi[0].texcoord*bary.x + vi[1].texcoord*bary.y + vi[2].texcoord*bary.z;
        #ifdef UNITY_PASS_FORWARDADD
        v.texcoord1 = vi[0].texcoord1*bary.x + vi[1].texcoord1*bary.y + vi[2].texcoord1*bary.z;
        #endif
        //v.color 	= vi[0].color*bary.x 	+ vi[1].color*bary.y 	+ vi[2].color*bary.z;
        v.tangent 	= vi[0].tangent*bary.x 	+ vi[1].tangent*bary.y 	+ vi[2].tangent*bary.z;
        v.normal 	= vi[0].normal*bary.x 	+ vi[1].normal*bary.y  	+ vi[2].normal*bary.z;

        v2f o = vert(v);

        return o;
    }

#endif
#endif
#endif