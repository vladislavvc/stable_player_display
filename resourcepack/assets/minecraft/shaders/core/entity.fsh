#version 330

#moj_import <minecraft:fog.glsl>
#moj_import <minecraft:dynamictransforms.glsl>

#if defined(ALPHA_CUTOUT) && !defined(EMISSIVE) && !defined(NO_OVERLAY) && !defined(APPLY_TEXTURE_MATRIX) && !defined(DISSOLVE)
#define MAYBE_PLAYERDISP 1
#endif

uniform sampler2D Sampler0;

#ifdef DISSOLVE
uniform sampler2D DissolveMaskSampler;
#endif

in float sphericalVertexDistance;
in float cylindricalVertexDistance;
#ifdef PER_FACE_LIGHTING
in vec4 vertexPerFaceColorBack;
in vec4 vertexPerFaceColorFront;
#else
in vec4 vertexColor;
#endif

#ifndef EMISSIVE
in vec4 lightMapColor;
#endif

#ifndef NO_OVERLAY
in vec4 overlayColor;
#endif

in vec2 texCoord0;

#ifdef MAYBE_PLAYERDISP
flat in int playerDispPart;
flat in int playerDispSlim;

#define SPLITMODEL 0
#define SKINRES 64.0
#define FADERANGE 12.0
#define FADEBIAS 8.0
#define MINALPHA 0.25

const vec4[] subuvs = vec4[](
    vec4(4.0,  0.0,  8.0,  4.0),
    vec4(8.0,  0.0, 12.0,  4.0),
    vec4(0.0,  4.0,  4.0, 16.0),
    vec4(4.0,  4.0,  8.0, 16.0),
    vec4(8.0,  4.0, 12.0, 16.0),
    vec4(12.0, 4.0, 16.0, 16.0),
    vec4(4.0,  0.0,  7.0,  4.0),
    vec4(7.0,  0.0, 10.0,  4.0),
    vec4(0.0,  4.0,  4.0, 16.0),
    vec4(4.0,  4.0,  7.0, 16.0),
    vec4(7.0,  4.0, 11.0, 16.0),
    vec4(11.0, 4.0, 14.0, 16.0),
    vec4(4.0,  0.0, 12.0,  4.0),
    vec4(12.0, 0.0, 20.0,  4.0),
    vec4(0.0,  4.0,  4.0, 16.0),
    vec4(4.0,  4.0, 12.0, 16.0),
    vec4(12.0, 4.0, 16.0, 16.0),
    vec4(16.0, 4.0, 24.0, 16.0)
);

const vec2[] origins = vec2[](
    vec2(40.0, 16.0),
    vec2(40.0, 32.0),
    vec2(32.0, 48.0),
    vec2(48.0, 48.0),
    vec2(16.0, 16.0),
    vec2(16.0, 32.0),
    vec2(0.0,  16.0),
    vec2(0.0,  32.0),
    vec2(16.0, 48.0),
    vec2(0.0,  48.0)
);

const mat4 bayer4 = mat4(
    0.0 / 16.0,  8.0 / 16.0,  2.0 / 16.0, 10.0 / 16.0,
   12.0 / 16.0,  4.0 / 16.0, 14.0 / 16.0,  6.0 / 16.0,
    3.0 / 16.0, 11.0 / 16.0,  1.0 / 16.0,  9.0 / 16.0,
   15.0 / 16.0,  7.0 / 16.0, 13.0 / 16.0,  5.0 / 16.0
);

void remapPlayerDispUV(vec2 sourceUV, int partIndex, bool slim, out vec2 mappedUV, out vec2 underUV) {
    vec2 sourcePixel = sourceUV * SKINRES;
    int outerLayer = sourcePixel.x >= 32.0 ? 1 : 0;

    if (outerLayer == 1) {
        sourcePixel.x -= 32.0;
    }

    int faceId;
    vec2 sourceOrigin;

    if (sourcePixel.y < 8.0) {
        if (sourcePixel.x < 16.0) {
            faceId = 0;
            sourceOrigin = vec2(8.0, 0.0);
        } else {
            faceId = 1;
            sourceOrigin = vec2(16.0, 0.0);
        }
    } else {
        int sideFace = int(clamp(floor(sourcePixel.x / 8.0), 0.0, 3.0));
        faceId = sideFace + 2;
        sourceOrigin = vec2(float(sideFace) * 8.0, 8.0);
    }

    vec2 faceUV = clamp((sourcePixel - sourceOrigin) / 8.0, 0.0, 1.0);
    int partIdMod = partIndex % 5;
    int subuvIndex = faceId;

    if (slim && (partIdMod == 0 || partIdMod == 1)) {
        subuvIndex += 6;
    } else if (partIdMod == 2) {
        subuvIndex += 12;
    }

    vec4 subuv = subuvs[subuvIndex];

#if SPLITMODEL == 1
    if (faceId >= 2) {
        subuv.w -= 6.0;
        if (partIndex >= 5) {
            subuv.yw += 6.0;
        }
    }
#endif

    vec2 offset = mix(subuv.xy, subuv.zw, faceUV);
    mappedUV = (origins[2 * partIdMod + outerLayer] + offset) / SKINRES;
    underUV = (origins[2 * partIdMod] + offset) / SKINRES;
}
#endif

out vec4 fragColor;

void main() {
    vec2 sampleUV = texCoord0;
#ifdef MAYBE_PLAYERDISP
    vec2 underUV = texCoord0;
    if (playerDispPart > 0) {
        remapPlayerDispUV(texCoord0, playerDispPart - 1, playerDispSlim != 0, sampleUV, underUV);
    }
#endif

    vec4 color = texture(Sampler0, sampleUV);
#ifdef ALPHA_CUTOUT
    if (color.a < ALPHA_CUTOUT) {
        discard;
    }
#endif

#ifdef PER_FACE_LIGHTING
    vec4 faceVertexColor = gl_FrontFacing ? vertexPerFaceColorFront : vertexPerFaceColorBack;
#else
    vec4 faceVertexColor = vertexColor;
#endif

#ifdef DISSOLVE
    if (faceVertexColor.a < texture(DissolveMaskSampler, sampleUV).a) {
        discard;
    }
    faceVertexColor.a = 1.0;
#endif

    color *= faceVertexColor * ColorModulator;
#ifndef NO_OVERLAY
    color.rgb = mix(overlayColor.rgb, color.rgb, overlayColor.a);
#endif
#ifndef EMISSIVE
    color *= lightMapColor;
#endif

    fragColor = apply_fog(
        color,
        sphericalVertexDistance,
        cylindricalVertexDistance,
        FogEnvironmentalStart,
        FogEnvironmentalEnd,
        FogRenderDistanceStart,
        FogRenderDistanceEnd,
        FogColor
    );

#ifdef MAYBE_PLAYERDISP
    if (playerDispPart > 0 && fragColor.a < 1.0) {
        fragColor.a = max(fragColor.a, MINALPHA);

        vec3 underCol = texture(Sampler0, underUV).rgb;
        vec3 trueMix = mix(underCol, fragColor.rgb, fragColor.a);
        float fade = mix(
            fragColor.a,
            1.0,
            clamp((cylindricalVertexDistance - FADEBIAS) / (FADERANGE - FADEBIAS), 0.0, 1.0)
        );

        fragColor = vec4((trueMix - (1.0 - fade) * underCol) / fade, fade);
        if (fragColor.a < bayer4[int(gl_FragCoord.x) % 4][int(gl_FragCoord.y) % 4] + (0.5 / 16.0)) {
            discard;
        } else {
            fragColor.a = 1.0;
        }
    }
#endif
}
