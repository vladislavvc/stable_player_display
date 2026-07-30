#version 330

#if defined(PER_FACE_LIGHTING) || !defined(NO_CARDINAL_LIGHTING)
#moj_import <minecraft:light.glsl>
#endif
#moj_import <minecraft:fog.glsl>
#moj_import <minecraft:dynamictransforms.glsl>
#moj_import <minecraft:projection.glsl>
#moj_import <minecraft:sample_lightmap.glsl>

#if defined(ALPHA_CUTOUT) && !defined(EMISSIVE) && !defined(NO_OVERLAY) && !defined(APPLY_TEXTURE_MATRIX) && !defined(DISSOLVE)
#define MAYBE_PLAYERDISP 1
#endif

in vec3 Position;
in vec4 Color;
in vec2 UV0;
in ivec2 UV1;
in ivec2 UV2;
in vec3 Normal;

#ifdef MAYBE_PLAYERDISP
uniform sampler2D Sampler0;
#endif
#ifndef NO_OVERLAY
uniform sampler2D Sampler1;
#endif
#ifndef EMISSIVE
uniform sampler2D Sampler2;
#endif

out float sphericalVertexDistance;
out float cylindricalVertexDistance;

#ifdef PER_FACE_LIGHTING
out vec4 vertexPerFaceColorBack;
out vec4 vertexPerFaceColorFront;
#else
out vec4 vertexColor;
#endif

#ifndef EMISSIVE
out vec4 lightMapColor;
#endif

#ifndef NO_OVERLAY
out vec4 overlayColor;
#endif

out vec2 texCoord0;

#ifdef MAYBE_PLAYERDISP
flat out int playerDispPart;
flat out int playerDispSlim;

#define SPACING 1024.0
#define MAXRANGE (0.5 * SPACING)
#define SKINRES 64

#define SLIMCHECK0 vec2(54.0 / float(SKINRES), 20.0 / float(SKINRES))
#define SLIMCHECK1 vec2(55.0 / float(SKINRES), 20.0 / float(SKINRES))
#endif

void main() {
#ifdef PER_FACE_LIGHTING
    vec2 light = minecraft_compute_light(Light0_Direction, Light1_Direction, Normal);
    vertexPerFaceColorBack = minecraft_mix_light_separate(-light, Color);
    vertexPerFaceColorFront = minecraft_mix_light_separate(light, Color);
#elif defined(NO_CARDINAL_LIGHTING)
    vertexColor = Color;
#else
    vertexColor = minecraft_mix_light(Light0_Direction, Light1_Direction, Normal, Color);
#endif

#ifndef EMISSIVE
    lightMapColor = sample_lightmap(Sampler2, UV2);
#endif
#ifndef NO_OVERLAY
    overlayColor = texelFetch(Sampler1, UV1, 0);
#endif

    texCoord0 = UV0;
#ifdef APPLY_TEXTURE_MATRIX
    texCoord0 = (TextureMat * vec4(UV0, 0.0, 1.0)).xy;
#endif

#ifdef MAYBE_PLAYERDISP
    playerDispPart = 0;
    playerDispSlim = 0;

    ivec2 dim = textureSize(Sampler0, 0);
    if (abs(ProjMat[2][3]) > 1e-5 && dim.x == SKINRES && dim.y == SKINRES && FogRenderDistanceEnd > FogRenderDistanceStart) {
        int partId = -int((Position.y - MAXRANGE) / SPACING);

        if (partId != 0) {
            vec4 samp1 = texture(Sampler0, SLIMCHECK0);
            vec4 samp2 = texture(Sampler0, SLIMCHECK1);
            bool slim = samp1.a == 0.0 || (((samp1.r + samp1.g + samp1.b) == 0.0) && ((samp2.r + samp2.g + samp2.b) == 0.0) && samp1.a == 1.0 && samp2.a == 1.0);

            playerDispPart = partId;
            playerDispSlim = slim ? 1 : 0;

            vec3 wpos = Position;
            wpos.y += SPACING * partId;
            gl_Position = ProjMat * ModelViewMat * vec4(wpos, 1.0);

            sphericalVertexDistance = fog_spherical_distance(wpos);
            cylindricalVertexDistance = fog_cylindrical_distance(wpos);
            return;
        }
    }
#endif

    gl_Position = ProjMat * ModelViewMat * vec4(Position, 1.0);
    sphericalVertexDistance = fog_spherical_distance(Position);
    cylindricalVertexDistance = fog_cylindrical_distance(Position);
}
