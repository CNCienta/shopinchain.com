#version GLSL_VERSION

/*==============================================================================
                                    VARS
==============================================================================*/
#var PRECISION highp

#var CAUSTICS 0
#var CALC_TBN_SPACE 0
#var MAIN_BEND_COL 0
#var DETAIL_BEND 0
#var CALC_TBN 0
#var USE_INSTANCED_PARTCLS 0
#var NODES 0
#var USE_TBN_SHADING 0
#var REFLECTION_TYPE REFL_NONE
#var SMAA_JITTER 0
#var MAC_OS_SHADOW_HACK 0
#var USE_POSITION_CLIP 0

#var RGBA_SHADOWS 0

#var REFRACTIVE 0

#var AU_QUALIFIER GLSL_IN
#var BEND_CENTER_ONLY 0
#var CSM_SECTION1 0
#var CSM_SECTION2 0
#var CSM_SECTION3 0
#var HAIR_BILLBOARD 0
#var FRAMES_BLENDING 0
#var SHADOW_TEX_RES 2048.0
#var VERTEX_ANIM 0
#var NUM_CAST_LAMPS 0
#var TEXTURE_COLOR 0
#var ALPHA 0

#var VERTEX_ANIM_MIX_NORMALS_FACTOR u_va_frame_factor
#var MAX_BONES 0

#var WIND_BEND 0
#var SHADOW_USAGE NO_SHADOWS
#var SKINNED 0
#var DYNAMIC_GRASS 0
#var BILLBOARD 0
#var STATIC_BATCH 0
#var BILLBOARD_JITTERED 0

/*==============================================================================
                                  INCLUDES
==============================================================================*/
#include <std.glsl>

#include <math.glslv>
#include <to_world.glslv>
#include <scale_texcoord.glslv>

/*==============================================================================
                                SHADER INTERFACE
==============================================================================*/
GLSL_IN vec3 a_position;

GLSL_IN vec4 a_tbn;

#if USE_INSTANCED_PARTCLS
GLSL_IN vec4 a_part_ts;
GLSL_IN vec4 a_part_r;
#endif

#if USE_TBN_SHADING
GLSL_IN vec3 a_shade_tangs;
#endif

#if SKINNED
GLSL_IN vec4 a_influence;
#endif

#if (WIND_BEND || DYNAMIC_GRASS || BILLBOARD) && !USE_INSTANCED_PARTCLS
AU_QUALIFIER vec3 au_center_pos;
#endif

#if WIND_BEND
# if MAIN_BEND_COL
GLSL_IN float a_bending_col_main;
#  if DETAIL_BEND
GLSL_IN vec3 a_bending_col_detail;
AU_QUALIFIER float au_detail_bending_amp;
AU_QUALIFIER float au_branch_bending_amp;
AU_QUALIFIER float au_detail_bending_freq;
#  endif  // DETAIL_BEND
# endif  // MAIN_BEND_COL
AU_QUALIFIER float au_wind_bending_amp;
AU_QUALIFIER float au_wind_bending_freq;
# if BEND_CENTER_ONLY
GLSL_IN vec3 a_emitter_center;
# endif
#endif  // WIND_BEND

#if VERTEX_ANIM
GLSL_IN vec3 a_position_next;
# if NODES && ALPHA
#  if USE_NODE_MATERIAL_BEGIN || USE_NODE_GEOMETRY_NO || USE_NODE_NORMAL_MAP \
        || CAUSTICS || CALC_TBN_SPACE
GLSL_IN vec4 a_tbn_next;
#  endif
# endif
#endif // VERTEX_ANIM

#if !(NODES && ALPHA) && TEXTURE_COLOR
GLSL_IN vec2 a_texcoord;
#endif
//------------------------------------------------------------------------------

#if NODES && ALPHA
GLSL_OUT vec3 v_pos_world;
GLSL_OUT vec3 v_normal;

# if CALC_TBN_SPACE
GLSL_OUT vec4 v_tangent;
# endif

#else
# if TEXTURE_COLOR
GLSL_OUT vec2 v_texcoord;
# endif
#endif

#if SHADOW_USAGE == SHADOW_MASK_GENERATION || NODES && ALPHA \
|| SHADOW_USAGE == SHADOW_CASTING && RGBA_SHADOWS
GLSL_OUT vec4 v_pos_view;
#endif

#if SHADOW_USAGE == SHADOW_MASK_GENERATION
GLSL_OUT vec4 v_shadow_coord0;

# if CSM_SECTION1 || NUM_CAST_LAMPS > 1
GLSL_OUT vec4 v_shadow_coord1;
# endif

# if CSM_SECTION2 || NUM_CAST_LAMPS > 2
GLSL_OUT vec4 v_shadow_coord2;
# endif

# if CSM_SECTION3 || NUM_CAST_LAMPS > 3
GLSL_OUT vec4 v_shadow_coord3;
# endif
#endif

#if REFLECTION_TYPE == REFL_PLANE || USE_POSITION_CLIP
GLSL_OUT vec3 v_tex_pos_clip;
#endif

#if NODES && ALPHA
# if USE_NODE_B4W_REFRACTION && REFRACTIVE
GLSL_OUT float v_view_depth;
# endif
#endif

#if USE_TBN_SHADING
GLSL_OUT vec3 v_shade_tang;
#endif

/*==============================================================================
                                   UNIFORMS
==============================================================================*/

#if STATIC_BATCH
// NOTE:  mat3(0.0, 0.0, 0.0, --- trans
//             1.0, 1.0, 1.0 --- scale
//             0.0, 0.0, 0.0 --- quat);
const mat3 u_model_tsr = mat3(0.0, 0.0, 0.0,
                              1.0, 1.0, 1.0,
                              0.0, 0.0, 0.0);
#else
uniform PRECISION mat3 u_model_tsr;
#endif

#if SMAA_JITTER
uniform vec2 u_subpixel_jitter;
#endif

uniform mat3 u_view_tsr;
uniform mat4 u_proj_matrix;
# if DYNAMIC_GRASS || BILLBOARD
uniform vec3 u_camera_eye;
# endif

#if BILLBOARD && SHADOW_USAGE == SHADOW_CASTING
uniform mat3 u_shadow_cast_billboard_view_tsr;
#endif

#if DYNAMIC_GRASS
uniform PRECISION sampler2D u_grass_map_depth;
uniform sampler2D u_grass_map_color;
uniform vec4 u_camera_quat;
uniform vec3 u_grass_map_dim;
uniform float u_grass_size;
uniform float u_scale_threshold;
#endif

#if SKINNED
    uniform vec4 u_quatsb[MAX_BONES];
    uniform vec4 u_transb[MAX_BONES];
    uniform vec4 u_arm_rel_trans;
    uniform vec4 u_arm_rel_quat;

    #if FRAMES_BLENDING
        uniform vec4 u_quatsa[MAX_BONES];
        uniform vec4 u_transa[MAX_BONES];

        // near 0 if before, near 1 if after
        uniform float u_frame_factor;
    #endif
#endif

#if WIND_BEND
#if BILLBOARD_JITTERED
uniform float u_jitter_amp;
uniform float u_jitter_freq;
#endif
uniform vec3 u_wind;
uniform PRECISION float u_time;
#endif

#if VERTEX_ANIM
uniform float u_va_frame_factor;
#endif

#if !(NODES && ALPHA) && TEXTURE_COLOR
uniform vec3 u_texture_scale;
#endif

#if SHADOW_USAGE == SHADOW_MASK_GENERATION
uniform float u_normal_offset;
# if MAC_OS_SHADOW_HACK
uniform mat3 u_v_light_tsr[NUM_CAST_LAMPS];
# else
uniform vec4 u_v_light_ts[NUM_CAST_LAMPS];
uniform vec4 u_v_light_r[NUM_CAST_LAMPS];
# endif

uniform mat4 u_p_light_matrix0;

# if CSM_SECTION1 || NUM_CAST_LAMPS > 1
uniform mat4 u_p_light_matrix1;
# endif

# if CSM_SECTION2 || NUM_CAST_LAMPS > 2
uniform mat4 u_p_light_matrix2;
# endif

# if CSM_SECTION3 || NUM_CAST_LAMPS > 3
uniform mat4 u_p_light_matrix3;
# endif
#endif

#if USE_NODE_B4W_REFRACTION
uniform PRECISION float u_view_max_depth;
#endif

/*==============================================================================
                                  INCLUDES
==============================================================================*/

#include <dynamic_grass.glslv>
#include <shadow.glslv>
#include <skin.glslv>
#include <wind_bending.glslv>

#if NODES && ALPHA
#include <nodes.glslv>
#endif
/*==============================================================================
                                    MAIN
==============================================================================*/

void main(void) {
    mat3 view_tsr = u_view_tsr;
    vec3 position = a_position;

#if SHADOW_USAGE == SHADOW_MASK_GENERATION || CALC_TBN_SPACE || USE_NODE_MATERIAL_BEGIN \
        || USE_NODE_GEOMETRY_NO || USE_NODE_NORMAL_MAP \
        || CAUSTICS || WIND_BEND && MAIN_BEND_COL && DETAIL_BEND \
        || USE_NODE_BSDF_BEGIN || USE_NODE_FRESNEL || USE_NODE_TEX_COORD_NO \
        || USE_NODE_TEX_COORD_RE || USE_NODE_LAYER_WEIGHT || USE_NODE_BUMP
    float correct_angle, handedness;
    vec4 tbn_quat = get_tbn_quat(a_tbn, correct_angle, handedness);
    vec3 norm_tbn = qrot(tbn_quat, vec3(0.0, 1.0, 0.0));
    vec3 normal = norm_tbn;
#else
    vec3 normal = vec3(0.0);
#endif

#if NODES && ALPHA && CALC_TBN_SPACE
    vec3 tangent = qrot(tbn_quat, vec3(1.0, 0.0, 0.0));
    // - cross(tangent, normal) --- blender space binormal
    vec3 binormal = handedness * cross(normal, tangent);

    vec4 tanget_rot_quat = qsetAxisAngle(binormal, handedness * correct_angle);
    tangent = qrot(tanget_rot_quat, normal);
#else
    vec3 tangent = vec3(0.0);
    vec3 binormal = vec3(0.0);
#endif

#if VERTEX_ANIM
    position = mix(position, a_position_next, u_va_frame_factor);
# if NODES && ALPHA
#  if USE_NODE_MATERIAL_BEGIN || USE_NODE_GEOMETRY_NO || USE_NODE_NORMAL_MAP || CAUSTICS || CALC_TBN_SPACE
    float correct_angle_next, handedness_next;
    vec4 tbn_quat_next = get_tbn_quat(a_tbn_next, correct_angle_next, handedness_next);
    vec3 normal_next = qrot(tbn_quat_next, vec3(0.0, 1.0, 0.0));
    normal = mix(normal, normal_next, VERTEX_ANIM_MIX_NORMALS_FACTOR);
#  endif
#  if CALC_TBN_SPACE
    vec3 tangent_next = qrot(tbn_quat_next, vec3(1.0, 0.0, 0.0));
    vec3 binormal_next = handedness_next * cross(normal_next, tangent_next);

    vec4 tangent_rot_quat_next = qsetAxisAngle(binormal_next, \
            handedness_next * correct_angle_next);
    tangent_next = qrot(tangent_rot_quat_next, normal_next);

    tangent = mix(tangent, tangent_next, u_va_frame_factor);
    binormal = mix(binormal, binormal_next, u_va_frame_factor);
#  endif
# endif // NODES && ALPHA
#endif // VERTEX_ANIM

#if SKINNED
    skin(position, tangent, binormal, normal);
#endif

#if USE_INSTANCED_PARTCLS
    mat3 model_tsr = tsr_set_trans(a_part_ts.xyz, tsr_identity());
    model_tsr = tsr_set_scale(vec3(a_part_ts.w), model_tsr);
    model_tsr = tsr_set_quat(a_part_r, model_tsr);
# if !STATIC_BATCH
    model_tsr = tsr_multiply(u_model_tsr, model_tsr);
# endif
#else
    mat3 model_tsr = u_model_tsr;
#endif

#if (WIND_BEND || DYNAMIC_GRASS || BILLBOARD) && !USE_INSTANCED_PARTCLS
    vec3 center = au_center_pos;
#elif DYNAMIC_GRASS && USE_INSTANCED_PARTCLS
    vec3 center = a_part_ts.xyz;
    position = tsr9_transform(model_tsr, position);
#else
    vec3 center = vec3(0.0);
#endif

#if USE_TBN_SHADING
# if CALC_TBN
    vec3 norm_world = normalize(tsr9_transform_dir(model_tsr, norm_tbn));
    vec3 shade_binormal = cross(vec3(0.0, 0.0, 1.0), norm_world);
    vec3 shade_tangent = cross(norm_world, shade_binormal);
# else
    vec3 shade_tangent = a_shade_tangs;
# endif
#else
    vec3 shade_tangent = vec3(0.0);
#endif

#if DYNAMIC_GRASS
    vertex world = grass_vertex(position, vec3(0.0), vec3(0.0), vec3(0.0), normal,
            center, u_grass_map_depth, u_grass_map_color, u_grass_map_dim,
            u_grass_size, u_camera_eye, u_camera_quat, view_tsr, model_tsr);
#else

# if BILLBOARD
    vec3 wcen = tsr9_transform(model_tsr, center);
// NOTE: only for non-particles geometry on SHADOW_CAST subscene
#  if !HAIR_BILLBOARD && SHADOW_USAGE == SHADOW_CASTING
    mat3 bill_view_tsr = u_shadow_cast_billboard_view_tsr;
#  else
    mat3 bill_view_tsr = view_tsr;
#  endif

    model_tsr = billboard_tsr(u_camera_eye, wcen, bill_view_tsr, model_tsr);

#  if WIND_BEND && BILLBOARD_JITTERED
    model_tsr = bend_jitter_rotate_tsr(u_wind, u_time,
            u_jitter_amp, u_jitter_freq, wcen, model_tsr);
#  endif
    vertex world = to_world(position - center, center, tangent, shade_tangent,
            binormal, normal, model_tsr);
    world.center = wcen;
# else
    vertex world = to_world(position, center, tangent, shade_tangent, binormal,
            normal, model_tsr);
# endif
#endif

#if WIND_BEND
# if MAIN_BEND_COL && DETAIL_BEND
    vec3 bend_normal = norm_tbn;
# else
    vec3 bend_normal = vec3(0.0);
# endif
    bend_vertex(world.position, world.center, bend_normal, mat4(0.0));
#endif

#if NODES && ALPHA
    v_pos_world = world.position;

# if USE_NODE_MATERIAL_BEGIN || USE_NODE_GEOMETRY_NO || USE_NODE_NORMAL_MAP \
        || CAUSTICS || CALC_TBN_SPACE || WIND_BEND && MAIN_BEND_COL && DETAIL_BEND \
        || USE_NODE_TEX_COORD_NO || USE_NODE_BSDF_BEGIN || USE_NODE_FRESNEL \
        || USE_NODE_TEX_COORD_RE || USE_NODE_LAYER_WEIGHT || USE_NODE_BUMP
    v_normal = world.normal;
# endif
# if CALC_TBN_SPACE
    // calculate handedness as described in Math for 3D GP and CG, page 185
    float m = (dot(cross(world.normal, world.tangent),
                   world.binormal) < 0.0) ? -1.0 : 1.0;

    v_tangent = vec4(world.tangent, m);
# endif
# if USE_TBN_SHADING
    v_shade_tang = world.shade_tang;
# endif

#endif // NODES && ALPHA
    vec4 pos_view = vec4(tsr9_transform(view_tsr, world.position), 1.0);
    vec4 pos_clip = u_proj_matrix * pos_view;

#if SMAA_JITTER
    pos_clip.xy += u_subpixel_jitter * pos_clip.w;
#endif

#if NODES && ALPHA
# if REFLECTION_TYPE == REFL_PLANE || USE_POSITION_CLIP
    v_tex_pos_clip = clip_to_tex(pos_clip);
# endif

// NOTE: this can never be, because refraction needs a blend material, which 
// doesn't receive shadows 
# if USE_NODE_B4W_REFRACTION && REFRACTIVE
    v_view_depth = -pos_view.z / u_view_max_depth;
# endif
    nodes_main();
#else
# if TEXTURE_COLOR
    v_texcoord = scale_texcoord(a_texcoord, u_texture_scale);
# endif
#endif // NODES && ALPHA

#if SHADOW_USAGE == SHADOW_MASK_GENERATION
    get_shadow_coords(world.position, world.normal);
#endif

#if SHADOW_USAGE == SHADOW_MASK_GENERATION || NODES && ALPHA \
|| SHADOW_USAGE == SHADOW_CASTING && RGBA_SHADOWS
    v_pos_view = pos_view;
#endif

#if SHADOW_USAGE == SHADOW_CASTING
    // NOTE: shift coords to remove shadow map panning

    // NOTE: tsr_get_trans(view_tsr) is world space origin translated into light space
    vec2 shift = (u_proj_matrix * vec4(tsr_get_trans(view_tsr), 1.0)).xy;
    float half_tex_res = SHADOW_TEX_RES / 2.0;
    shift = floor(shift * half_tex_res + 0.5) / half_tex_res - shift;
    pos_clip.xy += shift;
#endif

    gl_Position = pos_clip;
}
