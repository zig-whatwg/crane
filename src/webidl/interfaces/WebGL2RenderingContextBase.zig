//! Generated from: webgl2.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WebGL2RenderingContextBaseImpl = @import("impls").WebGL2RenderingContextBase;
const WebGLActiveInfo = @import("interfaces").WebGLActiveInfo;
const GLboolean = @import("typedefs").GLboolean;
const WebGLSampler = @import("interfaces").WebGLSampler;
const WebGLVertexArrayObject = @import("interfaces").WebGLVertexArrayObject;
const GLint = @import("typedefs").GLint;
const ArrayBufferView = @import("typedefs").ArrayBufferView;
const WebGLTransformFeedback = @import("interfaces").WebGLTransformFeedback;
const WebGLSync = @import("interfaces").WebGLSync;
const GLenum = @import("typedefs").GLenum;
const GLsizeiptr = @import("typedefs").GLsizeiptr;
const GLintptr = @import("typedefs").GLintptr;
const WebGLProgram = @import("interfaces").WebGLProgram;
const WebGLBuffer = @import("interfaces").WebGLBuffer;
const WebGLTexture = @import("interfaces").WebGLTexture;
const Int32List = @import("typedefs").Int32List;
const GLfloat = @import("typedefs").GLfloat;
const GLuint64 = @import("typedefs").GLuint64;
const GLint64 = @import("typedefs").GLint64;
const GLbitfield = @import("typedefs").GLbitfield;
const Float32List = @import("typedefs").Float32List;
const TexImageSource = @import("typedefs").TexImageSource;
const GLuint = @import("typedefs").GLuint;
const GLsizei = @import("typedefs").GLsizei;
const sequence = @import("interfaces").sequence;
const WebGLUniformLocation = @import("interfaces").WebGLUniformLocation;
const Uint32List = @import("typedefs").Uint32List;
const WebGLQuery = @import("interfaces").WebGLQuery;
const DOMString = @import("typedefs").DOMString;

pub const WebGL2RenderingContextBase = struct {
    pub const Meta = struct {
        pub const name = "WebGL2RenderingContextBase";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const GLenum READ_BUFFER = 3074;
    pub fn get_READ_BUFFER() GLenum {
        return 3074;
    }

    /// WebIDL constant: const GLenum UNPACK_ROW_LENGTH = 3314;
    pub fn get_UNPACK_ROW_LENGTH() GLenum {
        return 3314;
    }

    /// WebIDL constant: const GLenum UNPACK_SKIP_ROWS = 3315;
    pub fn get_UNPACK_SKIP_ROWS() GLenum {
        return 3315;
    }

    /// WebIDL constant: const GLenum UNPACK_SKIP_PIXELS = 3316;
    pub fn get_UNPACK_SKIP_PIXELS() GLenum {
        return 3316;
    }

    /// WebIDL constant: const GLenum PACK_ROW_LENGTH = 3330;
    pub fn get_PACK_ROW_LENGTH() GLenum {
        return 3330;
    }

    /// WebIDL constant: const GLenum PACK_SKIP_ROWS = 3331;
    pub fn get_PACK_SKIP_ROWS() GLenum {
        return 3331;
    }

    /// WebIDL constant: const GLenum PACK_SKIP_PIXELS = 3332;
    pub fn get_PACK_SKIP_PIXELS() GLenum {
        return 3332;
    }

    /// WebIDL constant: const GLenum COLOR = 6144;
    pub fn get_COLOR() GLenum {
        return 6144;
    }

    /// WebIDL constant: const GLenum DEPTH = 6145;
    pub fn get_DEPTH() GLenum {
        return 6145;
    }

    /// WebIDL constant: const GLenum STENCIL = 6146;
    pub fn get_STENCIL() GLenum {
        return 6146;
    }

    /// WebIDL constant: const GLenum RED = 6403;
    pub fn get_RED() GLenum {
        return 6403;
    }

    /// WebIDL constant: const GLenum RGB8 = 32849;
    pub fn get_RGB8() GLenum {
        return 32849;
    }

    /// WebIDL constant: const GLenum RGB10_A2 = 32857;
    pub fn get_RGB10_A2() GLenum {
        return 32857;
    }

    /// WebIDL constant: const GLenum TEXTURE_BINDING_3D = 32874;
    pub fn get_TEXTURE_BINDING_3D() GLenum {
        return 32874;
    }

    /// WebIDL constant: const GLenum UNPACK_SKIP_IMAGES = 32877;
    pub fn get_UNPACK_SKIP_IMAGES() GLenum {
        return 32877;
    }

    /// WebIDL constant: const GLenum UNPACK_IMAGE_HEIGHT = 32878;
    pub fn get_UNPACK_IMAGE_HEIGHT() GLenum {
        return 32878;
    }

    /// WebIDL constant: const GLenum TEXTURE_3D = 32879;
    pub fn get_TEXTURE_3D() GLenum {
        return 32879;
    }

    /// WebIDL constant: const GLenum TEXTURE_WRAP_R = 32882;
    pub fn get_TEXTURE_WRAP_R() GLenum {
        return 32882;
    }

    /// WebIDL constant: const GLenum MAX_3D_TEXTURE_SIZE = 32883;
    pub fn get_MAX_3D_TEXTURE_SIZE() GLenum {
        return 32883;
    }

    /// WebIDL constant: const GLenum UNSIGNED_INT_2_10_10_10_REV = 33640;
    pub fn get_UNSIGNED_INT_2_10_10_10_REV() GLenum {
        return 33640;
    }

    /// WebIDL constant: const GLenum MAX_ELEMENTS_VERTICES = 33000;
    pub fn get_MAX_ELEMENTS_VERTICES() GLenum {
        return 33000;
    }

    /// WebIDL constant: const GLenum MAX_ELEMENTS_INDICES = 33001;
    pub fn get_MAX_ELEMENTS_INDICES() GLenum {
        return 33001;
    }

    /// WebIDL constant: const GLenum TEXTURE_MIN_LOD = 33082;
    pub fn get_TEXTURE_MIN_LOD() GLenum {
        return 33082;
    }

    /// WebIDL constant: const GLenum TEXTURE_MAX_LOD = 33083;
    pub fn get_TEXTURE_MAX_LOD() GLenum {
        return 33083;
    }

    /// WebIDL constant: const GLenum TEXTURE_BASE_LEVEL = 33084;
    pub fn get_TEXTURE_BASE_LEVEL() GLenum {
        return 33084;
    }

    /// WebIDL constant: const GLenum TEXTURE_MAX_LEVEL = 33085;
    pub fn get_TEXTURE_MAX_LEVEL() GLenum {
        return 33085;
    }

    /// WebIDL constant: const GLenum MIN = 32775;
    pub fn get_MIN() GLenum {
        return 32775;
    }

    /// WebIDL constant: const GLenum MAX = 32776;
    pub fn get_MAX() GLenum {
        return 32776;
    }

    /// WebIDL constant: const GLenum DEPTH_COMPONENT24 = 33190;
    pub fn get_DEPTH_COMPONENT24() GLenum {
        return 33190;
    }

    /// WebIDL constant: const GLenum MAX_TEXTURE_LOD_BIAS = 34045;
    pub fn get_MAX_TEXTURE_LOD_BIAS() GLenum {
        return 34045;
    }

    /// WebIDL constant: const GLenum TEXTURE_COMPARE_MODE = 34892;
    pub fn get_TEXTURE_COMPARE_MODE() GLenum {
        return 34892;
    }

    /// WebIDL constant: const GLenum TEXTURE_COMPARE_FUNC = 34893;
    pub fn get_TEXTURE_COMPARE_FUNC() GLenum {
        return 34893;
    }

    /// WebIDL constant: const GLenum CURRENT_QUERY = 34917;
    pub fn get_CURRENT_QUERY() GLenum {
        return 34917;
    }

    /// WebIDL constant: const GLenum QUERY_RESULT = 34918;
    pub fn get_QUERY_RESULT() GLenum {
        return 34918;
    }

    /// WebIDL constant: const GLenum QUERY_RESULT_AVAILABLE = 34919;
    pub fn get_QUERY_RESULT_AVAILABLE() GLenum {
        return 34919;
    }

    /// WebIDL constant: const GLenum STREAM_READ = 35041;
    pub fn get_STREAM_READ() GLenum {
        return 35041;
    }

    /// WebIDL constant: const GLenum STREAM_COPY = 35042;
    pub fn get_STREAM_COPY() GLenum {
        return 35042;
    }

    /// WebIDL constant: const GLenum STATIC_READ = 35045;
    pub fn get_STATIC_READ() GLenum {
        return 35045;
    }

    /// WebIDL constant: const GLenum STATIC_COPY = 35046;
    pub fn get_STATIC_COPY() GLenum {
        return 35046;
    }

    /// WebIDL constant: const GLenum DYNAMIC_READ = 35049;
    pub fn get_DYNAMIC_READ() GLenum {
        return 35049;
    }

    /// WebIDL constant: const GLenum DYNAMIC_COPY = 35050;
    pub fn get_DYNAMIC_COPY() GLenum {
        return 35050;
    }

    /// WebIDL constant: const GLenum MAX_DRAW_BUFFERS = 34852;
    pub fn get_MAX_DRAW_BUFFERS() GLenum {
        return 34852;
    }

    /// WebIDL constant: const GLenum DRAW_BUFFER0 = 34853;
    pub fn get_DRAW_BUFFER0() GLenum {
        return 34853;
    }

    /// WebIDL constant: const GLenum DRAW_BUFFER1 = 34854;
    pub fn get_DRAW_BUFFER1() GLenum {
        return 34854;
    }

    /// WebIDL constant: const GLenum DRAW_BUFFER2 = 34855;
    pub fn get_DRAW_BUFFER2() GLenum {
        return 34855;
    }

    /// WebIDL constant: const GLenum DRAW_BUFFER3 = 34856;
    pub fn get_DRAW_BUFFER3() GLenum {
        return 34856;
    }

    /// WebIDL constant: const GLenum DRAW_BUFFER4 = 34857;
    pub fn get_DRAW_BUFFER4() GLenum {
        return 34857;
    }

    /// WebIDL constant: const GLenum DRAW_BUFFER5 = 34858;
    pub fn get_DRAW_BUFFER5() GLenum {
        return 34858;
    }

    /// WebIDL constant: const GLenum DRAW_BUFFER6 = 34859;
    pub fn get_DRAW_BUFFER6() GLenum {
        return 34859;
    }

    /// WebIDL constant: const GLenum DRAW_BUFFER7 = 34860;
    pub fn get_DRAW_BUFFER7() GLenum {
        return 34860;
    }

    /// WebIDL constant: const GLenum DRAW_BUFFER8 = 34861;
    pub fn get_DRAW_BUFFER8() GLenum {
        return 34861;
    }

    /// WebIDL constant: const GLenum DRAW_BUFFER9 = 34862;
    pub fn get_DRAW_BUFFER9() GLenum {
        return 34862;
    }

    /// WebIDL constant: const GLenum DRAW_BUFFER10 = 34863;
    pub fn get_DRAW_BUFFER10() GLenum {
        return 34863;
    }

    /// WebIDL constant: const GLenum DRAW_BUFFER11 = 34864;
    pub fn get_DRAW_BUFFER11() GLenum {
        return 34864;
    }

    /// WebIDL constant: const GLenum DRAW_BUFFER12 = 34865;
    pub fn get_DRAW_BUFFER12() GLenum {
        return 34865;
    }

    /// WebIDL constant: const GLenum DRAW_BUFFER13 = 34866;
    pub fn get_DRAW_BUFFER13() GLenum {
        return 34866;
    }

    /// WebIDL constant: const GLenum DRAW_BUFFER14 = 34867;
    pub fn get_DRAW_BUFFER14() GLenum {
        return 34867;
    }

    /// WebIDL constant: const GLenum DRAW_BUFFER15 = 34868;
    pub fn get_DRAW_BUFFER15() GLenum {
        return 34868;
    }

    /// WebIDL constant: const GLenum MAX_FRAGMENT_UNIFORM_COMPONENTS = 35657;
    pub fn get_MAX_FRAGMENT_UNIFORM_COMPONENTS() GLenum {
        return 35657;
    }

    /// WebIDL constant: const GLenum MAX_VERTEX_UNIFORM_COMPONENTS = 35658;
    pub fn get_MAX_VERTEX_UNIFORM_COMPONENTS() GLenum {
        return 35658;
    }

    /// WebIDL constant: const GLenum SAMPLER_3D = 35679;
    pub fn get_SAMPLER_3D() GLenum {
        return 35679;
    }

    /// WebIDL constant: const GLenum SAMPLER_2D_SHADOW = 35682;
    pub fn get_SAMPLER_2D_SHADOW() GLenum {
        return 35682;
    }

    /// WebIDL constant: const GLenum FRAGMENT_SHADER_DERIVATIVE_HINT = 35723;
    pub fn get_FRAGMENT_SHADER_DERIVATIVE_HINT() GLenum {
        return 35723;
    }

    /// WebIDL constant: const GLenum PIXEL_PACK_BUFFER = 35051;
    pub fn get_PIXEL_PACK_BUFFER() GLenum {
        return 35051;
    }

    /// WebIDL constant: const GLenum PIXEL_UNPACK_BUFFER = 35052;
    pub fn get_PIXEL_UNPACK_BUFFER() GLenum {
        return 35052;
    }

    /// WebIDL constant: const GLenum PIXEL_PACK_BUFFER_BINDING = 35053;
    pub fn get_PIXEL_PACK_BUFFER_BINDING() GLenum {
        return 35053;
    }

    /// WebIDL constant: const GLenum PIXEL_UNPACK_BUFFER_BINDING = 35055;
    pub fn get_PIXEL_UNPACK_BUFFER_BINDING() GLenum {
        return 35055;
    }

    /// WebIDL constant: const GLenum FLOAT_MAT2x3 = 35685;
    pub fn get_FLOAT_MAT2x3() GLenum {
        return 35685;
    }

    /// WebIDL constant: const GLenum FLOAT_MAT2x4 = 35686;
    pub fn get_FLOAT_MAT2x4() GLenum {
        return 35686;
    }

    /// WebIDL constant: const GLenum FLOAT_MAT3x2 = 35687;
    pub fn get_FLOAT_MAT3x2() GLenum {
        return 35687;
    }

    /// WebIDL constant: const GLenum FLOAT_MAT3x4 = 35688;
    pub fn get_FLOAT_MAT3x4() GLenum {
        return 35688;
    }

    /// WebIDL constant: const GLenum FLOAT_MAT4x2 = 35689;
    pub fn get_FLOAT_MAT4x2() GLenum {
        return 35689;
    }

    /// WebIDL constant: const GLenum FLOAT_MAT4x3 = 35690;
    pub fn get_FLOAT_MAT4x3() GLenum {
        return 35690;
    }

    /// WebIDL constant: const GLenum SRGB = 35904;
    pub fn get_SRGB() GLenum {
        return 35904;
    }

    /// WebIDL constant: const GLenum SRGB8 = 35905;
    pub fn get_SRGB8() GLenum {
        return 35905;
    }

    /// WebIDL constant: const GLenum SRGB8_ALPHA8 = 35907;
    pub fn get_SRGB8_ALPHA8() GLenum {
        return 35907;
    }

    /// WebIDL constant: const GLenum COMPARE_REF_TO_TEXTURE = 34894;
    pub fn get_COMPARE_REF_TO_TEXTURE() GLenum {
        return 34894;
    }

    /// WebIDL constant: const GLenum RGBA32F = 34836;
    pub fn get_RGBA32F() GLenum {
        return 34836;
    }

    /// WebIDL constant: const GLenum RGB32F = 34837;
    pub fn get_RGB32F() GLenum {
        return 34837;
    }

    /// WebIDL constant: const GLenum RGBA16F = 34842;
    pub fn get_RGBA16F() GLenum {
        return 34842;
    }

    /// WebIDL constant: const GLenum RGB16F = 34843;
    pub fn get_RGB16F() GLenum {
        return 34843;
    }

    /// WebIDL constant: const GLenum VERTEX_ATTRIB_ARRAY_INTEGER = 35069;
    pub fn get_VERTEX_ATTRIB_ARRAY_INTEGER() GLenum {
        return 35069;
    }

    /// WebIDL constant: const GLenum MAX_ARRAY_TEXTURE_LAYERS = 35071;
    pub fn get_MAX_ARRAY_TEXTURE_LAYERS() GLenum {
        return 35071;
    }

    /// WebIDL constant: const GLenum MIN_PROGRAM_TEXEL_OFFSET = 35076;
    pub fn get_MIN_PROGRAM_TEXEL_OFFSET() GLenum {
        return 35076;
    }

    /// WebIDL constant: const GLenum MAX_PROGRAM_TEXEL_OFFSET = 35077;
    pub fn get_MAX_PROGRAM_TEXEL_OFFSET() GLenum {
        return 35077;
    }

    /// WebIDL constant: const GLenum MAX_VARYING_COMPONENTS = 35659;
    pub fn get_MAX_VARYING_COMPONENTS() GLenum {
        return 35659;
    }

    /// WebIDL constant: const GLenum TEXTURE_2D_ARRAY = 35866;
    pub fn get_TEXTURE_2D_ARRAY() GLenum {
        return 35866;
    }

    /// WebIDL constant: const GLenum TEXTURE_BINDING_2D_ARRAY = 35869;
    pub fn get_TEXTURE_BINDING_2D_ARRAY() GLenum {
        return 35869;
    }

    /// WebIDL constant: const GLenum R11F_G11F_B10F = 35898;
    pub fn get_R11F_G11F_B10F() GLenum {
        return 35898;
    }

    /// WebIDL constant: const GLenum UNSIGNED_INT_10F_11F_11F_REV = 35899;
    pub fn get_UNSIGNED_INT_10F_11F_11F_REV() GLenum {
        return 35899;
    }

    /// WebIDL constant: const GLenum RGB9_E5 = 35901;
    pub fn get_RGB9_E5() GLenum {
        return 35901;
    }

    /// WebIDL constant: const GLenum UNSIGNED_INT_5_9_9_9_REV = 35902;
    pub fn get_UNSIGNED_INT_5_9_9_9_REV() GLenum {
        return 35902;
    }

    /// WebIDL constant: const GLenum TRANSFORM_FEEDBACK_BUFFER_MODE = 35967;
    pub fn get_TRANSFORM_FEEDBACK_BUFFER_MODE() GLenum {
        return 35967;
    }

    /// WebIDL constant: const GLenum MAX_TRANSFORM_FEEDBACK_SEPARATE_COMPONENTS = 35968;
    pub fn get_MAX_TRANSFORM_FEEDBACK_SEPARATE_COMPONENTS() GLenum {
        return 35968;
    }

    /// WebIDL constant: const GLenum TRANSFORM_FEEDBACK_VARYINGS = 35971;
    pub fn get_TRANSFORM_FEEDBACK_VARYINGS() GLenum {
        return 35971;
    }

    /// WebIDL constant: const GLenum TRANSFORM_FEEDBACK_BUFFER_START = 35972;
    pub fn get_TRANSFORM_FEEDBACK_BUFFER_START() GLenum {
        return 35972;
    }

    /// WebIDL constant: const GLenum TRANSFORM_FEEDBACK_BUFFER_SIZE = 35973;
    pub fn get_TRANSFORM_FEEDBACK_BUFFER_SIZE() GLenum {
        return 35973;
    }

    /// WebIDL constant: const GLenum TRANSFORM_FEEDBACK_PRIMITIVES_WRITTEN = 35976;
    pub fn get_TRANSFORM_FEEDBACK_PRIMITIVES_WRITTEN() GLenum {
        return 35976;
    }

    /// WebIDL constant: const GLenum RASTERIZER_DISCARD = 35977;
    pub fn get_RASTERIZER_DISCARD() GLenum {
        return 35977;
    }

    /// WebIDL constant: const GLenum MAX_TRANSFORM_FEEDBACK_INTERLEAVED_COMPONENTS = 35978;
    pub fn get_MAX_TRANSFORM_FEEDBACK_INTERLEAVED_COMPONENTS() GLenum {
        return 35978;
    }

    /// WebIDL constant: const GLenum MAX_TRANSFORM_FEEDBACK_SEPARATE_ATTRIBS = 35979;
    pub fn get_MAX_TRANSFORM_FEEDBACK_SEPARATE_ATTRIBS() GLenum {
        return 35979;
    }

    /// WebIDL constant: const GLenum INTERLEAVED_ATTRIBS = 35980;
    pub fn get_INTERLEAVED_ATTRIBS() GLenum {
        return 35980;
    }

    /// WebIDL constant: const GLenum SEPARATE_ATTRIBS = 35981;
    pub fn get_SEPARATE_ATTRIBS() GLenum {
        return 35981;
    }

    /// WebIDL constant: const GLenum TRANSFORM_FEEDBACK_BUFFER = 35982;
    pub fn get_TRANSFORM_FEEDBACK_BUFFER() GLenum {
        return 35982;
    }

    /// WebIDL constant: const GLenum TRANSFORM_FEEDBACK_BUFFER_BINDING = 35983;
    pub fn get_TRANSFORM_FEEDBACK_BUFFER_BINDING() GLenum {
        return 35983;
    }

    /// WebIDL constant: const GLenum RGBA32UI = 36208;
    pub fn get_RGBA32UI() GLenum {
        return 36208;
    }

    /// WebIDL constant: const GLenum RGB32UI = 36209;
    pub fn get_RGB32UI() GLenum {
        return 36209;
    }

    /// WebIDL constant: const GLenum RGBA16UI = 36214;
    pub fn get_RGBA16UI() GLenum {
        return 36214;
    }

    /// WebIDL constant: const GLenum RGB16UI = 36215;
    pub fn get_RGB16UI() GLenum {
        return 36215;
    }

    /// WebIDL constant: const GLenum RGBA8UI = 36220;
    pub fn get_RGBA8UI() GLenum {
        return 36220;
    }

    /// WebIDL constant: const GLenum RGB8UI = 36221;
    pub fn get_RGB8UI() GLenum {
        return 36221;
    }

    /// WebIDL constant: const GLenum RGBA32I = 36226;
    pub fn get_RGBA32I() GLenum {
        return 36226;
    }

    /// WebIDL constant: const GLenum RGB32I = 36227;
    pub fn get_RGB32I() GLenum {
        return 36227;
    }

    /// WebIDL constant: const GLenum RGBA16I = 36232;
    pub fn get_RGBA16I() GLenum {
        return 36232;
    }

    /// WebIDL constant: const GLenum RGB16I = 36233;
    pub fn get_RGB16I() GLenum {
        return 36233;
    }

    /// WebIDL constant: const GLenum RGBA8I = 36238;
    pub fn get_RGBA8I() GLenum {
        return 36238;
    }

    /// WebIDL constant: const GLenum RGB8I = 36239;
    pub fn get_RGB8I() GLenum {
        return 36239;
    }

    /// WebIDL constant: const GLenum RED_INTEGER = 36244;
    pub fn get_RED_INTEGER() GLenum {
        return 36244;
    }

    /// WebIDL constant: const GLenum RGB_INTEGER = 36248;
    pub fn get_RGB_INTEGER() GLenum {
        return 36248;
    }

    /// WebIDL constant: const GLenum RGBA_INTEGER = 36249;
    pub fn get_RGBA_INTEGER() GLenum {
        return 36249;
    }

    /// WebIDL constant: const GLenum SAMPLER_2D_ARRAY = 36289;
    pub fn get_SAMPLER_2D_ARRAY() GLenum {
        return 36289;
    }

    /// WebIDL constant: const GLenum SAMPLER_2D_ARRAY_SHADOW = 36292;
    pub fn get_SAMPLER_2D_ARRAY_SHADOW() GLenum {
        return 36292;
    }

    /// WebIDL constant: const GLenum SAMPLER_CUBE_SHADOW = 36293;
    pub fn get_SAMPLER_CUBE_SHADOW() GLenum {
        return 36293;
    }

    /// WebIDL constant: const GLenum UNSIGNED_INT_VEC2 = 36294;
    pub fn get_UNSIGNED_INT_VEC2() GLenum {
        return 36294;
    }

    /// WebIDL constant: const GLenum UNSIGNED_INT_VEC3 = 36295;
    pub fn get_UNSIGNED_INT_VEC3() GLenum {
        return 36295;
    }

    /// WebIDL constant: const GLenum UNSIGNED_INT_VEC4 = 36296;
    pub fn get_UNSIGNED_INT_VEC4() GLenum {
        return 36296;
    }

    /// WebIDL constant: const GLenum INT_SAMPLER_2D = 36298;
    pub fn get_INT_SAMPLER_2D() GLenum {
        return 36298;
    }

    /// WebIDL constant: const GLenum INT_SAMPLER_3D = 36299;
    pub fn get_INT_SAMPLER_3D() GLenum {
        return 36299;
    }

    /// WebIDL constant: const GLenum INT_SAMPLER_CUBE = 36300;
    pub fn get_INT_SAMPLER_CUBE() GLenum {
        return 36300;
    }

    /// WebIDL constant: const GLenum INT_SAMPLER_2D_ARRAY = 36303;
    pub fn get_INT_SAMPLER_2D_ARRAY() GLenum {
        return 36303;
    }

    /// WebIDL constant: const GLenum UNSIGNED_INT_SAMPLER_2D = 36306;
    pub fn get_UNSIGNED_INT_SAMPLER_2D() GLenum {
        return 36306;
    }

    /// WebIDL constant: const GLenum UNSIGNED_INT_SAMPLER_3D = 36307;
    pub fn get_UNSIGNED_INT_SAMPLER_3D() GLenum {
        return 36307;
    }

    /// WebIDL constant: const GLenum UNSIGNED_INT_SAMPLER_CUBE = 36308;
    pub fn get_UNSIGNED_INT_SAMPLER_CUBE() GLenum {
        return 36308;
    }

    /// WebIDL constant: const GLenum UNSIGNED_INT_SAMPLER_2D_ARRAY = 36311;
    pub fn get_UNSIGNED_INT_SAMPLER_2D_ARRAY() GLenum {
        return 36311;
    }

    /// WebIDL constant: const GLenum DEPTH_COMPONENT32F = 36012;
    pub fn get_DEPTH_COMPONENT32F() GLenum {
        return 36012;
    }

    /// WebIDL constant: const GLenum DEPTH32F_STENCIL8 = 36013;
    pub fn get_DEPTH32F_STENCIL8() GLenum {
        return 36013;
    }

    /// WebIDL constant: const GLenum FLOAT_32_UNSIGNED_INT_24_8_REV = 36269;
    pub fn get_FLOAT_32_UNSIGNED_INT_24_8_REV() GLenum {
        return 36269;
    }

    /// WebIDL constant: const GLenum FRAMEBUFFER_ATTACHMENT_COLOR_ENCODING = 33296;
    pub fn get_FRAMEBUFFER_ATTACHMENT_COLOR_ENCODING() GLenum {
        return 33296;
    }

    /// WebIDL constant: const GLenum FRAMEBUFFER_ATTACHMENT_COMPONENT_TYPE = 33297;
    pub fn get_FRAMEBUFFER_ATTACHMENT_COMPONENT_TYPE() GLenum {
        return 33297;
    }

    /// WebIDL constant: const GLenum FRAMEBUFFER_ATTACHMENT_RED_SIZE = 33298;
    pub fn get_FRAMEBUFFER_ATTACHMENT_RED_SIZE() GLenum {
        return 33298;
    }

    /// WebIDL constant: const GLenum FRAMEBUFFER_ATTACHMENT_GREEN_SIZE = 33299;
    pub fn get_FRAMEBUFFER_ATTACHMENT_GREEN_SIZE() GLenum {
        return 33299;
    }

    /// WebIDL constant: const GLenum FRAMEBUFFER_ATTACHMENT_BLUE_SIZE = 33300;
    pub fn get_FRAMEBUFFER_ATTACHMENT_BLUE_SIZE() GLenum {
        return 33300;
    }

    /// WebIDL constant: const GLenum FRAMEBUFFER_ATTACHMENT_ALPHA_SIZE = 33301;
    pub fn get_FRAMEBUFFER_ATTACHMENT_ALPHA_SIZE() GLenum {
        return 33301;
    }

    /// WebIDL constant: const GLenum FRAMEBUFFER_ATTACHMENT_DEPTH_SIZE = 33302;
    pub fn get_FRAMEBUFFER_ATTACHMENT_DEPTH_SIZE() GLenum {
        return 33302;
    }

    /// WebIDL constant: const GLenum FRAMEBUFFER_ATTACHMENT_STENCIL_SIZE = 33303;
    pub fn get_FRAMEBUFFER_ATTACHMENT_STENCIL_SIZE() GLenum {
        return 33303;
    }

    /// WebIDL constant: const GLenum FRAMEBUFFER_DEFAULT = 33304;
    pub fn get_FRAMEBUFFER_DEFAULT() GLenum {
        return 33304;
    }

    /// WebIDL constant: const GLenum UNSIGNED_INT_24_8 = 34042;
    pub fn get_UNSIGNED_INT_24_8() GLenum {
        return 34042;
    }

    /// WebIDL constant: const GLenum DEPTH24_STENCIL8 = 35056;
    pub fn get_DEPTH24_STENCIL8() GLenum {
        return 35056;
    }

    /// WebIDL constant: const GLenum UNSIGNED_NORMALIZED = 35863;
    pub fn get_UNSIGNED_NORMALIZED() GLenum {
        return 35863;
    }

    /// WebIDL constant: const GLenum DRAW_FRAMEBUFFER_BINDING = 36006;
    pub fn get_DRAW_FRAMEBUFFER_BINDING() GLenum {
        return 36006;
    }

    /// WebIDL constant: const GLenum READ_FRAMEBUFFER = 36008;
    pub fn get_READ_FRAMEBUFFER() GLenum {
        return 36008;
    }

    /// WebIDL constant: const GLenum DRAW_FRAMEBUFFER = 36009;
    pub fn get_DRAW_FRAMEBUFFER() GLenum {
        return 36009;
    }

    /// WebIDL constant: const GLenum READ_FRAMEBUFFER_BINDING = 36010;
    pub fn get_READ_FRAMEBUFFER_BINDING() GLenum {
        return 36010;
    }

    /// WebIDL constant: const GLenum RENDERBUFFER_SAMPLES = 36011;
    pub fn get_RENDERBUFFER_SAMPLES() GLenum {
        return 36011;
    }

    /// WebIDL constant: const GLenum FRAMEBUFFER_ATTACHMENT_TEXTURE_LAYER = 36052;
    pub fn get_FRAMEBUFFER_ATTACHMENT_TEXTURE_LAYER() GLenum {
        return 36052;
    }

    /// WebIDL constant: const GLenum MAX_COLOR_ATTACHMENTS = 36063;
    pub fn get_MAX_COLOR_ATTACHMENTS() GLenum {
        return 36063;
    }

    /// WebIDL constant: const GLenum COLOR_ATTACHMENT1 = 36065;
    pub fn get_COLOR_ATTACHMENT1() GLenum {
        return 36065;
    }

    /// WebIDL constant: const GLenum COLOR_ATTACHMENT2 = 36066;
    pub fn get_COLOR_ATTACHMENT2() GLenum {
        return 36066;
    }

    /// WebIDL constant: const GLenum COLOR_ATTACHMENT3 = 36067;
    pub fn get_COLOR_ATTACHMENT3() GLenum {
        return 36067;
    }

    /// WebIDL constant: const GLenum COLOR_ATTACHMENT4 = 36068;
    pub fn get_COLOR_ATTACHMENT4() GLenum {
        return 36068;
    }

    /// WebIDL constant: const GLenum COLOR_ATTACHMENT5 = 36069;
    pub fn get_COLOR_ATTACHMENT5() GLenum {
        return 36069;
    }

    /// WebIDL constant: const GLenum COLOR_ATTACHMENT6 = 36070;
    pub fn get_COLOR_ATTACHMENT6() GLenum {
        return 36070;
    }

    /// WebIDL constant: const GLenum COLOR_ATTACHMENT7 = 36071;
    pub fn get_COLOR_ATTACHMENT7() GLenum {
        return 36071;
    }

    /// WebIDL constant: const GLenum COLOR_ATTACHMENT8 = 36072;
    pub fn get_COLOR_ATTACHMENT8() GLenum {
        return 36072;
    }

    /// WebIDL constant: const GLenum COLOR_ATTACHMENT9 = 36073;
    pub fn get_COLOR_ATTACHMENT9() GLenum {
        return 36073;
    }

    /// WebIDL constant: const GLenum COLOR_ATTACHMENT10 = 36074;
    pub fn get_COLOR_ATTACHMENT10() GLenum {
        return 36074;
    }

    /// WebIDL constant: const GLenum COLOR_ATTACHMENT11 = 36075;
    pub fn get_COLOR_ATTACHMENT11() GLenum {
        return 36075;
    }

    /// WebIDL constant: const GLenum COLOR_ATTACHMENT12 = 36076;
    pub fn get_COLOR_ATTACHMENT12() GLenum {
        return 36076;
    }

    /// WebIDL constant: const GLenum COLOR_ATTACHMENT13 = 36077;
    pub fn get_COLOR_ATTACHMENT13() GLenum {
        return 36077;
    }

    /// WebIDL constant: const GLenum COLOR_ATTACHMENT14 = 36078;
    pub fn get_COLOR_ATTACHMENT14() GLenum {
        return 36078;
    }

    /// WebIDL constant: const GLenum COLOR_ATTACHMENT15 = 36079;
    pub fn get_COLOR_ATTACHMENT15() GLenum {
        return 36079;
    }

    /// WebIDL constant: const GLenum FRAMEBUFFER_INCOMPLETE_MULTISAMPLE = 36182;
    pub fn get_FRAMEBUFFER_INCOMPLETE_MULTISAMPLE() GLenum {
        return 36182;
    }

    /// WebIDL constant: const GLenum MAX_SAMPLES = 36183;
    pub fn get_MAX_SAMPLES() GLenum {
        return 36183;
    }

    /// WebIDL constant: const GLenum HALF_FLOAT = 5131;
    pub fn get_HALF_FLOAT() GLenum {
        return 5131;
    }

    /// WebIDL constant: const GLenum RG = 33319;
    pub fn get_RG() GLenum {
        return 33319;
    }

    /// WebIDL constant: const GLenum RG_INTEGER = 33320;
    pub fn get_RG_INTEGER() GLenum {
        return 33320;
    }

    /// WebIDL constant: const GLenum R8 = 33321;
    pub fn get_R8() GLenum {
        return 33321;
    }

    /// WebIDL constant: const GLenum RG8 = 33323;
    pub fn get_RG8() GLenum {
        return 33323;
    }

    /// WebIDL constant: const GLenum R16F = 33325;
    pub fn get_R16F() GLenum {
        return 33325;
    }

    /// WebIDL constant: const GLenum R32F = 33326;
    pub fn get_R32F() GLenum {
        return 33326;
    }

    /// WebIDL constant: const GLenum RG16F = 33327;
    pub fn get_RG16F() GLenum {
        return 33327;
    }

    /// WebIDL constant: const GLenum RG32F = 33328;
    pub fn get_RG32F() GLenum {
        return 33328;
    }

    /// WebIDL constant: const GLenum R8I = 33329;
    pub fn get_R8I() GLenum {
        return 33329;
    }

    /// WebIDL constant: const GLenum R8UI = 33330;
    pub fn get_R8UI() GLenum {
        return 33330;
    }

    /// WebIDL constant: const GLenum R16I = 33331;
    pub fn get_R16I() GLenum {
        return 33331;
    }

    /// WebIDL constant: const GLenum R16UI = 33332;
    pub fn get_R16UI() GLenum {
        return 33332;
    }

    /// WebIDL constant: const GLenum R32I = 33333;
    pub fn get_R32I() GLenum {
        return 33333;
    }

    /// WebIDL constant: const GLenum R32UI = 33334;
    pub fn get_R32UI() GLenum {
        return 33334;
    }

    /// WebIDL constant: const GLenum RG8I = 33335;
    pub fn get_RG8I() GLenum {
        return 33335;
    }

    /// WebIDL constant: const GLenum RG8UI = 33336;
    pub fn get_RG8UI() GLenum {
        return 33336;
    }

    /// WebIDL constant: const GLenum RG16I = 33337;
    pub fn get_RG16I() GLenum {
        return 33337;
    }

    /// WebIDL constant: const GLenum RG16UI = 33338;
    pub fn get_RG16UI() GLenum {
        return 33338;
    }

    /// WebIDL constant: const GLenum RG32I = 33339;
    pub fn get_RG32I() GLenum {
        return 33339;
    }

    /// WebIDL constant: const GLenum RG32UI = 33340;
    pub fn get_RG32UI() GLenum {
        return 33340;
    }

    /// WebIDL constant: const GLenum VERTEX_ARRAY_BINDING = 34229;
    pub fn get_VERTEX_ARRAY_BINDING() GLenum {
        return 34229;
    }

    /// WebIDL constant: const GLenum R8_SNORM = 36756;
    pub fn get_R8_SNORM() GLenum {
        return 36756;
    }

    /// WebIDL constant: const GLenum RG8_SNORM = 36757;
    pub fn get_RG8_SNORM() GLenum {
        return 36757;
    }

    /// WebIDL constant: const GLenum RGB8_SNORM = 36758;
    pub fn get_RGB8_SNORM() GLenum {
        return 36758;
    }

    /// WebIDL constant: const GLenum RGBA8_SNORM = 36759;
    pub fn get_RGBA8_SNORM() GLenum {
        return 36759;
    }

    /// WebIDL constant: const GLenum SIGNED_NORMALIZED = 36764;
    pub fn get_SIGNED_NORMALIZED() GLenum {
        return 36764;
    }

    /// WebIDL constant: const GLenum COPY_READ_BUFFER = 36662;
    pub fn get_COPY_READ_BUFFER() GLenum {
        return 36662;
    }

    /// WebIDL constant: const GLenum COPY_WRITE_BUFFER = 36663;
    pub fn get_COPY_WRITE_BUFFER() GLenum {
        return 36663;
    }

    /// WebIDL constant: const GLenum COPY_READ_BUFFER_BINDING = 36662;
    pub fn get_COPY_READ_BUFFER_BINDING() GLenum {
        return 36662;
    }

    /// WebIDL constant: const GLenum COPY_WRITE_BUFFER_BINDING = 36663;
    pub fn get_COPY_WRITE_BUFFER_BINDING() GLenum {
        return 36663;
    }

    /// WebIDL constant: const GLenum UNIFORM_BUFFER = 35345;
    pub fn get_UNIFORM_BUFFER() GLenum {
        return 35345;
    }

    /// WebIDL constant: const GLenum UNIFORM_BUFFER_BINDING = 35368;
    pub fn get_UNIFORM_BUFFER_BINDING() GLenum {
        return 35368;
    }

    /// WebIDL constant: const GLenum UNIFORM_BUFFER_START = 35369;
    pub fn get_UNIFORM_BUFFER_START() GLenum {
        return 35369;
    }

    /// WebIDL constant: const GLenum UNIFORM_BUFFER_SIZE = 35370;
    pub fn get_UNIFORM_BUFFER_SIZE() GLenum {
        return 35370;
    }

    /// WebIDL constant: const GLenum MAX_VERTEX_UNIFORM_BLOCKS = 35371;
    pub fn get_MAX_VERTEX_UNIFORM_BLOCKS() GLenum {
        return 35371;
    }

    /// WebIDL constant: const GLenum MAX_FRAGMENT_UNIFORM_BLOCKS = 35373;
    pub fn get_MAX_FRAGMENT_UNIFORM_BLOCKS() GLenum {
        return 35373;
    }

    /// WebIDL constant: const GLenum MAX_COMBINED_UNIFORM_BLOCKS = 35374;
    pub fn get_MAX_COMBINED_UNIFORM_BLOCKS() GLenum {
        return 35374;
    }

    /// WebIDL constant: const GLenum MAX_UNIFORM_BUFFER_BINDINGS = 35375;
    pub fn get_MAX_UNIFORM_BUFFER_BINDINGS() GLenum {
        return 35375;
    }

    /// WebIDL constant: const GLenum MAX_UNIFORM_BLOCK_SIZE = 35376;
    pub fn get_MAX_UNIFORM_BLOCK_SIZE() GLenum {
        return 35376;
    }

    /// WebIDL constant: const GLenum MAX_COMBINED_VERTEX_UNIFORM_COMPONENTS = 35377;
    pub fn get_MAX_COMBINED_VERTEX_UNIFORM_COMPONENTS() GLenum {
        return 35377;
    }

    /// WebIDL constant: const GLenum MAX_COMBINED_FRAGMENT_UNIFORM_COMPONENTS = 35379;
    pub fn get_MAX_COMBINED_FRAGMENT_UNIFORM_COMPONENTS() GLenum {
        return 35379;
    }

    /// WebIDL constant: const GLenum UNIFORM_BUFFER_OFFSET_ALIGNMENT = 35380;
    pub fn get_UNIFORM_BUFFER_OFFSET_ALIGNMENT() GLenum {
        return 35380;
    }

    /// WebIDL constant: const GLenum ACTIVE_UNIFORM_BLOCKS = 35382;
    pub fn get_ACTIVE_UNIFORM_BLOCKS() GLenum {
        return 35382;
    }

    /// WebIDL constant: const GLenum UNIFORM_TYPE = 35383;
    pub fn get_UNIFORM_TYPE() GLenum {
        return 35383;
    }

    /// WebIDL constant: const GLenum UNIFORM_SIZE = 35384;
    pub fn get_UNIFORM_SIZE() GLenum {
        return 35384;
    }

    /// WebIDL constant: const GLenum UNIFORM_BLOCK_INDEX = 35386;
    pub fn get_UNIFORM_BLOCK_INDEX() GLenum {
        return 35386;
    }

    /// WebIDL constant: const GLenum UNIFORM_OFFSET = 35387;
    pub fn get_UNIFORM_OFFSET() GLenum {
        return 35387;
    }

    /// WebIDL constant: const GLenum UNIFORM_ARRAY_STRIDE = 35388;
    pub fn get_UNIFORM_ARRAY_STRIDE() GLenum {
        return 35388;
    }

    /// WebIDL constant: const GLenum UNIFORM_MATRIX_STRIDE = 35389;
    pub fn get_UNIFORM_MATRIX_STRIDE() GLenum {
        return 35389;
    }

    /// WebIDL constant: const GLenum UNIFORM_IS_ROW_MAJOR = 35390;
    pub fn get_UNIFORM_IS_ROW_MAJOR() GLenum {
        return 35390;
    }

    /// WebIDL constant: const GLenum UNIFORM_BLOCK_BINDING = 35391;
    pub fn get_UNIFORM_BLOCK_BINDING() GLenum {
        return 35391;
    }

    /// WebIDL constant: const GLenum UNIFORM_BLOCK_DATA_SIZE = 35392;
    pub fn get_UNIFORM_BLOCK_DATA_SIZE() GLenum {
        return 35392;
    }

    /// WebIDL constant: const GLenum UNIFORM_BLOCK_ACTIVE_UNIFORMS = 35394;
    pub fn get_UNIFORM_BLOCK_ACTIVE_UNIFORMS() GLenum {
        return 35394;
    }

    /// WebIDL constant: const GLenum UNIFORM_BLOCK_ACTIVE_UNIFORM_INDICES = 35395;
    pub fn get_UNIFORM_BLOCK_ACTIVE_UNIFORM_INDICES() GLenum {
        return 35395;
    }

    /// WebIDL constant: const GLenum UNIFORM_BLOCK_REFERENCED_BY_VERTEX_SHADER = 35396;
    pub fn get_UNIFORM_BLOCK_REFERENCED_BY_VERTEX_SHADER() GLenum {
        return 35396;
    }

    /// WebIDL constant: const GLenum UNIFORM_BLOCK_REFERENCED_BY_FRAGMENT_SHADER = 35398;
    pub fn get_UNIFORM_BLOCK_REFERENCED_BY_FRAGMENT_SHADER() GLenum {
        return 35398;
    }

    /// WebIDL constant: const GLenum INVALID_INDEX = 4294967295;
    pub fn get_INVALID_INDEX() GLenum {
        return 4294967295;
    }

    /// WebIDL constant: const GLenum MAX_VERTEX_OUTPUT_COMPONENTS = 37154;
    pub fn get_MAX_VERTEX_OUTPUT_COMPONENTS() GLenum {
        return 37154;
    }

    /// WebIDL constant: const GLenum MAX_FRAGMENT_INPUT_COMPONENTS = 37157;
    pub fn get_MAX_FRAGMENT_INPUT_COMPONENTS() GLenum {
        return 37157;
    }

    /// WebIDL constant: const GLenum MAX_SERVER_WAIT_TIMEOUT = 37137;
    pub fn get_MAX_SERVER_WAIT_TIMEOUT() GLenum {
        return 37137;
    }

    /// WebIDL constant: const GLenum OBJECT_TYPE = 37138;
    pub fn get_OBJECT_TYPE() GLenum {
        return 37138;
    }

    /// WebIDL constant: const GLenum SYNC_CONDITION = 37139;
    pub fn get_SYNC_CONDITION() GLenum {
        return 37139;
    }

    /// WebIDL constant: const GLenum SYNC_STATUS = 37140;
    pub fn get_SYNC_STATUS() GLenum {
        return 37140;
    }

    /// WebIDL constant: const GLenum SYNC_FLAGS = 37141;
    pub fn get_SYNC_FLAGS() GLenum {
        return 37141;
    }

    /// WebIDL constant: const GLenum SYNC_FENCE = 37142;
    pub fn get_SYNC_FENCE() GLenum {
        return 37142;
    }

    /// WebIDL constant: const GLenum SYNC_GPU_COMMANDS_COMPLETE = 37143;
    pub fn get_SYNC_GPU_COMMANDS_COMPLETE() GLenum {
        return 37143;
    }

    /// WebIDL constant: const GLenum UNSIGNALED = 37144;
    pub fn get_UNSIGNALED() GLenum {
        return 37144;
    }

    /// WebIDL constant: const GLenum SIGNALED = 37145;
    pub fn get_SIGNALED() GLenum {
        return 37145;
    }

    /// WebIDL constant: const GLenum ALREADY_SIGNALED = 37146;
    pub fn get_ALREADY_SIGNALED() GLenum {
        return 37146;
    }

    /// WebIDL constant: const GLenum TIMEOUT_EXPIRED = 37147;
    pub fn get_TIMEOUT_EXPIRED() GLenum {
        return 37147;
    }

    /// WebIDL constant: const GLenum CONDITION_SATISFIED = 37148;
    pub fn get_CONDITION_SATISFIED() GLenum {
        return 37148;
    }

    /// WebIDL constant: const GLenum WAIT_FAILED = 37149;
    pub fn get_WAIT_FAILED() GLenum {
        return 37149;
    }

    /// WebIDL constant: const GLenum SYNC_FLUSH_COMMANDS_BIT = 1;
    pub fn get_SYNC_FLUSH_COMMANDS_BIT() GLenum {
        return 1;
    }

    /// WebIDL constant: const GLenum VERTEX_ATTRIB_ARRAY_DIVISOR = 35070;
    pub fn get_VERTEX_ATTRIB_ARRAY_DIVISOR() GLenum {
        return 35070;
    }

    /// WebIDL constant: const GLenum ANY_SAMPLES_PASSED = 35887;
    pub fn get_ANY_SAMPLES_PASSED() GLenum {
        return 35887;
    }

    /// WebIDL constant: const GLenum ANY_SAMPLES_PASSED_CONSERVATIVE = 36202;
    pub fn get_ANY_SAMPLES_PASSED_CONSERVATIVE() GLenum {
        return 36202;
    }

    /// WebIDL constant: const GLenum SAMPLER_BINDING = 35097;
    pub fn get_SAMPLER_BINDING() GLenum {
        return 35097;
    }

    /// WebIDL constant: const GLenum RGB10_A2UI = 36975;
    pub fn get_RGB10_A2UI() GLenum {
        return 36975;
    }

    /// WebIDL constant: const GLenum INT_2_10_10_10_REV = 36255;
    pub fn get_INT_2_10_10_10_REV() GLenum {
        return 36255;
    }

    /// WebIDL constant: const GLenum TRANSFORM_FEEDBACK = 36386;
    pub fn get_TRANSFORM_FEEDBACK() GLenum {
        return 36386;
    }

    /// WebIDL constant: const GLenum TRANSFORM_FEEDBACK_PAUSED = 36387;
    pub fn get_TRANSFORM_FEEDBACK_PAUSED() GLenum {
        return 36387;
    }

    /// WebIDL constant: const GLenum TRANSFORM_FEEDBACK_ACTIVE = 36388;
    pub fn get_TRANSFORM_FEEDBACK_ACTIVE() GLenum {
        return 36388;
    }

    /// WebIDL constant: const GLenum TRANSFORM_FEEDBACK_BINDING = 36389;
    pub fn get_TRANSFORM_FEEDBACK_BINDING() GLenum {
        return 36389;
    }

    /// WebIDL constant: const GLenum TEXTURE_IMMUTABLE_FORMAT = 37167;
    pub fn get_TEXTURE_IMMUTABLE_FORMAT() GLenum {
        return 37167;
    }

    /// WebIDL constant: const GLenum MAX_ELEMENT_INDEX = 36203;
    pub fn get_MAX_ELEMENT_INDEX() GLenum {
        return 36203;
    }

    /// WebIDL constant: const GLenum TEXTURE_IMMUTABLE_LEVELS = 33503;
    pub fn get_TEXTURE_IMMUTABLE_LEVELS() GLenum {
        return 33503;
    }

    /// WebIDL constant: const GLint64 TIMEOUT_IGNORED = -1;
    pub fn get_TIMEOUT_IGNORED() GLint64 {
        return -1;
    }

    /// WebIDL constant: const GLenum MAX_CLIENT_WAIT_TIMEOUT_WEBGL = 37447;
    pub fn get_MAX_CLIENT_WAIT_TIMEOUT_WEBGL() GLenum {
        return 37447;
    }

    pub const vtable = runtime.buildVTable(WebGL2RenderingContextBase, .{
        .deinit_fn = &deinit_wrapper,

        .get_ACTIVE_UNIFORM_BLOCKS = &get_ACTIVE_UNIFORM_BLOCKS,
        .get_ALREADY_SIGNALED = &get_ALREADY_SIGNALED,
        .get_ANY_SAMPLES_PASSED = &get_ANY_SAMPLES_PASSED,
        .get_ANY_SAMPLES_PASSED_CONSERVATIVE = &get_ANY_SAMPLES_PASSED_CONSERVATIVE,
        .get_COLOR = &get_COLOR,
        .get_COLOR_ATTACHMENT1 = &get_COLOR_ATTACHMENT1,
        .get_COLOR_ATTACHMENT10 = &get_COLOR_ATTACHMENT10,
        .get_COLOR_ATTACHMENT11 = &get_COLOR_ATTACHMENT11,
        .get_COLOR_ATTACHMENT12 = &get_COLOR_ATTACHMENT12,
        .get_COLOR_ATTACHMENT13 = &get_COLOR_ATTACHMENT13,
        .get_COLOR_ATTACHMENT14 = &get_COLOR_ATTACHMENT14,
        .get_COLOR_ATTACHMENT15 = &get_COLOR_ATTACHMENT15,
        .get_COLOR_ATTACHMENT2 = &get_COLOR_ATTACHMENT2,
        .get_COLOR_ATTACHMENT3 = &get_COLOR_ATTACHMENT3,
        .get_COLOR_ATTACHMENT4 = &get_COLOR_ATTACHMENT4,
        .get_COLOR_ATTACHMENT5 = &get_COLOR_ATTACHMENT5,
        .get_COLOR_ATTACHMENT6 = &get_COLOR_ATTACHMENT6,
        .get_COLOR_ATTACHMENT7 = &get_COLOR_ATTACHMENT7,
        .get_COLOR_ATTACHMENT8 = &get_COLOR_ATTACHMENT8,
        .get_COLOR_ATTACHMENT9 = &get_COLOR_ATTACHMENT9,
        .get_COMPARE_REF_TO_TEXTURE = &get_COMPARE_REF_TO_TEXTURE,
        .get_CONDITION_SATISFIED = &get_CONDITION_SATISFIED,
        .get_COPY_READ_BUFFER = &get_COPY_READ_BUFFER,
        .get_COPY_READ_BUFFER_BINDING = &get_COPY_READ_BUFFER_BINDING,
        .get_COPY_WRITE_BUFFER = &get_COPY_WRITE_BUFFER,
        .get_COPY_WRITE_BUFFER_BINDING = &get_COPY_WRITE_BUFFER_BINDING,
        .get_CURRENT_QUERY = &get_CURRENT_QUERY,
        .get_DEPTH = &get_DEPTH,
        .get_DEPTH24_STENCIL8 = &get_DEPTH24_STENCIL8,
        .get_DEPTH32F_STENCIL8 = &get_DEPTH32F_STENCIL8,
        .get_DEPTH_COMPONENT24 = &get_DEPTH_COMPONENT24,
        .get_DEPTH_COMPONENT32F = &get_DEPTH_COMPONENT32F,
        .get_DRAW_BUFFER0 = &get_DRAW_BUFFER0,
        .get_DRAW_BUFFER1 = &get_DRAW_BUFFER1,
        .get_DRAW_BUFFER10 = &get_DRAW_BUFFER10,
        .get_DRAW_BUFFER11 = &get_DRAW_BUFFER11,
        .get_DRAW_BUFFER12 = &get_DRAW_BUFFER12,
        .get_DRAW_BUFFER13 = &get_DRAW_BUFFER13,
        .get_DRAW_BUFFER14 = &get_DRAW_BUFFER14,
        .get_DRAW_BUFFER15 = &get_DRAW_BUFFER15,
        .get_DRAW_BUFFER2 = &get_DRAW_BUFFER2,
        .get_DRAW_BUFFER3 = &get_DRAW_BUFFER3,
        .get_DRAW_BUFFER4 = &get_DRAW_BUFFER4,
        .get_DRAW_BUFFER5 = &get_DRAW_BUFFER5,
        .get_DRAW_BUFFER6 = &get_DRAW_BUFFER6,
        .get_DRAW_BUFFER7 = &get_DRAW_BUFFER7,
        .get_DRAW_BUFFER8 = &get_DRAW_BUFFER8,
        .get_DRAW_BUFFER9 = &get_DRAW_BUFFER9,
        .get_DRAW_FRAMEBUFFER = &get_DRAW_FRAMEBUFFER,
        .get_DRAW_FRAMEBUFFER_BINDING = &get_DRAW_FRAMEBUFFER_BINDING,
        .get_DYNAMIC_COPY = &get_DYNAMIC_COPY,
        .get_DYNAMIC_READ = &get_DYNAMIC_READ,
        .get_FLOAT_32_UNSIGNED_INT_24_8_REV = &get_FLOAT_32_UNSIGNED_INT_24_8_REV,
        .get_FLOAT_MAT2x3 = &get_FLOAT_MAT2x3,
        .get_FLOAT_MAT2x4 = &get_FLOAT_MAT2x4,
        .get_FLOAT_MAT3x2 = &get_FLOAT_MAT3x2,
        .get_FLOAT_MAT3x4 = &get_FLOAT_MAT3x4,
        .get_FLOAT_MAT4x2 = &get_FLOAT_MAT4x2,
        .get_FLOAT_MAT4x3 = &get_FLOAT_MAT4x3,
        .get_FRAGMENT_SHADER_DERIVATIVE_HINT = &get_FRAGMENT_SHADER_DERIVATIVE_HINT,
        .get_FRAMEBUFFER_ATTACHMENT_ALPHA_SIZE = &get_FRAMEBUFFER_ATTACHMENT_ALPHA_SIZE,
        .get_FRAMEBUFFER_ATTACHMENT_BLUE_SIZE = &get_FRAMEBUFFER_ATTACHMENT_BLUE_SIZE,
        .get_FRAMEBUFFER_ATTACHMENT_COLOR_ENCODING = &get_FRAMEBUFFER_ATTACHMENT_COLOR_ENCODING,
        .get_FRAMEBUFFER_ATTACHMENT_COMPONENT_TYPE = &get_FRAMEBUFFER_ATTACHMENT_COMPONENT_TYPE,
        .get_FRAMEBUFFER_ATTACHMENT_DEPTH_SIZE = &get_FRAMEBUFFER_ATTACHMENT_DEPTH_SIZE,
        .get_FRAMEBUFFER_ATTACHMENT_GREEN_SIZE = &get_FRAMEBUFFER_ATTACHMENT_GREEN_SIZE,
        .get_FRAMEBUFFER_ATTACHMENT_RED_SIZE = &get_FRAMEBUFFER_ATTACHMENT_RED_SIZE,
        .get_FRAMEBUFFER_ATTACHMENT_STENCIL_SIZE = &get_FRAMEBUFFER_ATTACHMENT_STENCIL_SIZE,
        .get_FRAMEBUFFER_ATTACHMENT_TEXTURE_LAYER = &get_FRAMEBUFFER_ATTACHMENT_TEXTURE_LAYER,
        .get_FRAMEBUFFER_DEFAULT = &get_FRAMEBUFFER_DEFAULT,
        .get_FRAMEBUFFER_INCOMPLETE_MULTISAMPLE = &get_FRAMEBUFFER_INCOMPLETE_MULTISAMPLE,
        .get_HALF_FLOAT = &get_HALF_FLOAT,
        .get_INTERLEAVED_ATTRIBS = &get_INTERLEAVED_ATTRIBS,
        .get_INT_2_10_10_10_REV = &get_INT_2_10_10_10_REV,
        .get_INT_SAMPLER_2D = &get_INT_SAMPLER_2D,
        .get_INT_SAMPLER_2D_ARRAY = &get_INT_SAMPLER_2D_ARRAY,
        .get_INT_SAMPLER_3D = &get_INT_SAMPLER_3D,
        .get_INT_SAMPLER_CUBE = &get_INT_SAMPLER_CUBE,
        .get_INVALID_INDEX = &get_INVALID_INDEX,
        .get_MAX = &get_MAX,
        .get_MAX_3D_TEXTURE_SIZE = &get_MAX_3D_TEXTURE_SIZE,
        .get_MAX_ARRAY_TEXTURE_LAYERS = &get_MAX_ARRAY_TEXTURE_LAYERS,
        .get_MAX_CLIENT_WAIT_TIMEOUT_WEBGL = &get_MAX_CLIENT_WAIT_TIMEOUT_WEBGL,
        .get_MAX_COLOR_ATTACHMENTS = &get_MAX_COLOR_ATTACHMENTS,
        .get_MAX_COMBINED_FRAGMENT_UNIFORM_COMPONENTS = &get_MAX_COMBINED_FRAGMENT_UNIFORM_COMPONENTS,
        .get_MAX_COMBINED_UNIFORM_BLOCKS = &get_MAX_COMBINED_UNIFORM_BLOCKS,
        .get_MAX_COMBINED_VERTEX_UNIFORM_COMPONENTS = &get_MAX_COMBINED_VERTEX_UNIFORM_COMPONENTS,
        .get_MAX_DRAW_BUFFERS = &get_MAX_DRAW_BUFFERS,
        .get_MAX_ELEMENTS_INDICES = &get_MAX_ELEMENTS_INDICES,
        .get_MAX_ELEMENTS_VERTICES = &get_MAX_ELEMENTS_VERTICES,
        .get_MAX_ELEMENT_INDEX = &get_MAX_ELEMENT_INDEX,
        .get_MAX_FRAGMENT_INPUT_COMPONENTS = &get_MAX_FRAGMENT_INPUT_COMPONENTS,
        .get_MAX_FRAGMENT_UNIFORM_BLOCKS = &get_MAX_FRAGMENT_UNIFORM_BLOCKS,
        .get_MAX_FRAGMENT_UNIFORM_COMPONENTS = &get_MAX_FRAGMENT_UNIFORM_COMPONENTS,
        .get_MAX_PROGRAM_TEXEL_OFFSET = &get_MAX_PROGRAM_TEXEL_OFFSET,
        .get_MAX_SAMPLES = &get_MAX_SAMPLES,
        .get_MAX_SERVER_WAIT_TIMEOUT = &get_MAX_SERVER_WAIT_TIMEOUT,
        .get_MAX_TEXTURE_LOD_BIAS = &get_MAX_TEXTURE_LOD_BIAS,
        .get_MAX_TRANSFORM_FEEDBACK_INTERLEAVED_COMPONENTS = &get_MAX_TRANSFORM_FEEDBACK_INTERLEAVED_COMPONENTS,
        .get_MAX_TRANSFORM_FEEDBACK_SEPARATE_ATTRIBS = &get_MAX_TRANSFORM_FEEDBACK_SEPARATE_ATTRIBS,
        .get_MAX_TRANSFORM_FEEDBACK_SEPARATE_COMPONENTS = &get_MAX_TRANSFORM_FEEDBACK_SEPARATE_COMPONENTS,
        .get_MAX_UNIFORM_BLOCK_SIZE = &get_MAX_UNIFORM_BLOCK_SIZE,
        .get_MAX_UNIFORM_BUFFER_BINDINGS = &get_MAX_UNIFORM_BUFFER_BINDINGS,
        .get_MAX_VARYING_COMPONENTS = &get_MAX_VARYING_COMPONENTS,
        .get_MAX_VERTEX_OUTPUT_COMPONENTS = &get_MAX_VERTEX_OUTPUT_COMPONENTS,
        .get_MAX_VERTEX_UNIFORM_BLOCKS = &get_MAX_VERTEX_UNIFORM_BLOCKS,
        .get_MAX_VERTEX_UNIFORM_COMPONENTS = &get_MAX_VERTEX_UNIFORM_COMPONENTS,
        .get_MIN = &get_MIN,
        .get_MIN_PROGRAM_TEXEL_OFFSET = &get_MIN_PROGRAM_TEXEL_OFFSET,
        .get_OBJECT_TYPE = &get_OBJECT_TYPE,
        .get_PACK_ROW_LENGTH = &get_PACK_ROW_LENGTH,
        .get_PACK_SKIP_PIXELS = &get_PACK_SKIP_PIXELS,
        .get_PACK_SKIP_ROWS = &get_PACK_SKIP_ROWS,
        .get_PIXEL_PACK_BUFFER = &get_PIXEL_PACK_BUFFER,
        .get_PIXEL_PACK_BUFFER_BINDING = &get_PIXEL_PACK_BUFFER_BINDING,
        .get_PIXEL_UNPACK_BUFFER = &get_PIXEL_UNPACK_BUFFER,
        .get_PIXEL_UNPACK_BUFFER_BINDING = &get_PIXEL_UNPACK_BUFFER_BINDING,
        .get_QUERY_RESULT = &get_QUERY_RESULT,
        .get_QUERY_RESULT_AVAILABLE = &get_QUERY_RESULT_AVAILABLE,
        .get_R11F_G11F_B10F = &get_R11F_G11F_B10F,
        .get_R16F = &get_R16F,
        .get_R16I = &get_R16I,
        .get_R16UI = &get_R16UI,
        .get_R32F = &get_R32F,
        .get_R32I = &get_R32I,
        .get_R32UI = &get_R32UI,
        .get_R8 = &get_R8,
        .get_R8I = &get_R8I,
        .get_R8UI = &get_R8UI,
        .get_R8_SNORM = &get_R8_SNORM,
        .get_RASTERIZER_DISCARD = &get_RASTERIZER_DISCARD,
        .get_READ_BUFFER = &get_READ_BUFFER,
        .get_READ_FRAMEBUFFER = &get_READ_FRAMEBUFFER,
        .get_READ_FRAMEBUFFER_BINDING = &get_READ_FRAMEBUFFER_BINDING,
        .get_RED = &get_RED,
        .get_RED_INTEGER = &get_RED_INTEGER,
        .get_RENDERBUFFER_SAMPLES = &get_RENDERBUFFER_SAMPLES,
        .get_RG = &get_RG,
        .get_RG16F = &get_RG16F,
        .get_RG16I = &get_RG16I,
        .get_RG16UI = &get_RG16UI,
        .get_RG32F = &get_RG32F,
        .get_RG32I = &get_RG32I,
        .get_RG32UI = &get_RG32UI,
        .get_RG8 = &get_RG8,
        .get_RG8I = &get_RG8I,
        .get_RG8UI = &get_RG8UI,
        .get_RG8_SNORM = &get_RG8_SNORM,
        .get_RGB10_A2 = &get_RGB10_A2,
        .get_RGB10_A2UI = &get_RGB10_A2UI,
        .get_RGB16F = &get_RGB16F,
        .get_RGB16I = &get_RGB16I,
        .get_RGB16UI = &get_RGB16UI,
        .get_RGB32F = &get_RGB32F,
        .get_RGB32I = &get_RGB32I,
        .get_RGB32UI = &get_RGB32UI,
        .get_RGB8 = &get_RGB8,
        .get_RGB8I = &get_RGB8I,
        .get_RGB8UI = &get_RGB8UI,
        .get_RGB8_SNORM = &get_RGB8_SNORM,
        .get_RGB9_E5 = &get_RGB9_E5,
        .get_RGBA16F = &get_RGBA16F,
        .get_RGBA16I = &get_RGBA16I,
        .get_RGBA16UI = &get_RGBA16UI,
        .get_RGBA32F = &get_RGBA32F,
        .get_RGBA32I = &get_RGBA32I,
        .get_RGBA32UI = &get_RGBA32UI,
        .get_RGBA8I = &get_RGBA8I,
        .get_RGBA8UI = &get_RGBA8UI,
        .get_RGBA8_SNORM = &get_RGBA8_SNORM,
        .get_RGBA_INTEGER = &get_RGBA_INTEGER,
        .get_RGB_INTEGER = &get_RGB_INTEGER,
        .get_RG_INTEGER = &get_RG_INTEGER,
        .get_SAMPLER_2D_ARRAY = &get_SAMPLER_2D_ARRAY,
        .get_SAMPLER_2D_ARRAY_SHADOW = &get_SAMPLER_2D_ARRAY_SHADOW,
        .get_SAMPLER_2D_SHADOW = &get_SAMPLER_2D_SHADOW,
        .get_SAMPLER_3D = &get_SAMPLER_3D,
        .get_SAMPLER_BINDING = &get_SAMPLER_BINDING,
        .get_SAMPLER_CUBE_SHADOW = &get_SAMPLER_CUBE_SHADOW,
        .get_SEPARATE_ATTRIBS = &get_SEPARATE_ATTRIBS,
        .get_SIGNALED = &get_SIGNALED,
        .get_SIGNED_NORMALIZED = &get_SIGNED_NORMALIZED,
        .get_SRGB = &get_SRGB,
        .get_SRGB8 = &get_SRGB8,
        .get_SRGB8_ALPHA8 = &get_SRGB8_ALPHA8,
        .get_STATIC_COPY = &get_STATIC_COPY,
        .get_STATIC_READ = &get_STATIC_READ,
        .get_STENCIL = &get_STENCIL,
        .get_STREAM_COPY = &get_STREAM_COPY,
        .get_STREAM_READ = &get_STREAM_READ,
        .get_SYNC_CONDITION = &get_SYNC_CONDITION,
        .get_SYNC_FENCE = &get_SYNC_FENCE,
        .get_SYNC_FLAGS = &get_SYNC_FLAGS,
        .get_SYNC_FLUSH_COMMANDS_BIT = &get_SYNC_FLUSH_COMMANDS_BIT,
        .get_SYNC_GPU_COMMANDS_COMPLETE = &get_SYNC_GPU_COMMANDS_COMPLETE,
        .get_SYNC_STATUS = &get_SYNC_STATUS,
        .get_TEXTURE_2D_ARRAY = &get_TEXTURE_2D_ARRAY,
        .get_TEXTURE_3D = &get_TEXTURE_3D,
        .get_TEXTURE_BASE_LEVEL = &get_TEXTURE_BASE_LEVEL,
        .get_TEXTURE_BINDING_2D_ARRAY = &get_TEXTURE_BINDING_2D_ARRAY,
        .get_TEXTURE_BINDING_3D = &get_TEXTURE_BINDING_3D,
        .get_TEXTURE_COMPARE_FUNC = &get_TEXTURE_COMPARE_FUNC,
        .get_TEXTURE_COMPARE_MODE = &get_TEXTURE_COMPARE_MODE,
        .get_TEXTURE_IMMUTABLE_FORMAT = &get_TEXTURE_IMMUTABLE_FORMAT,
        .get_TEXTURE_IMMUTABLE_LEVELS = &get_TEXTURE_IMMUTABLE_LEVELS,
        .get_TEXTURE_MAX_LEVEL = &get_TEXTURE_MAX_LEVEL,
        .get_TEXTURE_MAX_LOD = &get_TEXTURE_MAX_LOD,
        .get_TEXTURE_MIN_LOD = &get_TEXTURE_MIN_LOD,
        .get_TEXTURE_WRAP_R = &get_TEXTURE_WRAP_R,
        .get_TIMEOUT_EXPIRED = &get_TIMEOUT_EXPIRED,
        .get_TIMEOUT_IGNORED = &get_TIMEOUT_IGNORED,
        .get_TRANSFORM_FEEDBACK = &get_TRANSFORM_FEEDBACK,
        .get_TRANSFORM_FEEDBACK_ACTIVE = &get_TRANSFORM_FEEDBACK_ACTIVE,
        .get_TRANSFORM_FEEDBACK_BINDING = &get_TRANSFORM_FEEDBACK_BINDING,
        .get_TRANSFORM_FEEDBACK_BUFFER = &get_TRANSFORM_FEEDBACK_BUFFER,
        .get_TRANSFORM_FEEDBACK_BUFFER_BINDING = &get_TRANSFORM_FEEDBACK_BUFFER_BINDING,
        .get_TRANSFORM_FEEDBACK_BUFFER_MODE = &get_TRANSFORM_FEEDBACK_BUFFER_MODE,
        .get_TRANSFORM_FEEDBACK_BUFFER_SIZE = &get_TRANSFORM_FEEDBACK_BUFFER_SIZE,
        .get_TRANSFORM_FEEDBACK_BUFFER_START = &get_TRANSFORM_FEEDBACK_BUFFER_START,
        .get_TRANSFORM_FEEDBACK_PAUSED = &get_TRANSFORM_FEEDBACK_PAUSED,
        .get_TRANSFORM_FEEDBACK_PRIMITIVES_WRITTEN = &get_TRANSFORM_FEEDBACK_PRIMITIVES_WRITTEN,
        .get_TRANSFORM_FEEDBACK_VARYINGS = &get_TRANSFORM_FEEDBACK_VARYINGS,
        .get_UNIFORM_ARRAY_STRIDE = &get_UNIFORM_ARRAY_STRIDE,
        .get_UNIFORM_BLOCK_ACTIVE_UNIFORMS = &get_UNIFORM_BLOCK_ACTIVE_UNIFORMS,
        .get_UNIFORM_BLOCK_ACTIVE_UNIFORM_INDICES = &get_UNIFORM_BLOCK_ACTIVE_UNIFORM_INDICES,
        .get_UNIFORM_BLOCK_BINDING = &get_UNIFORM_BLOCK_BINDING,
        .get_UNIFORM_BLOCK_DATA_SIZE = &get_UNIFORM_BLOCK_DATA_SIZE,
        .get_UNIFORM_BLOCK_INDEX = &get_UNIFORM_BLOCK_INDEX,
        .get_UNIFORM_BLOCK_REFERENCED_BY_FRAGMENT_SHADER = &get_UNIFORM_BLOCK_REFERENCED_BY_FRAGMENT_SHADER,
        .get_UNIFORM_BLOCK_REFERENCED_BY_VERTEX_SHADER = &get_UNIFORM_BLOCK_REFERENCED_BY_VERTEX_SHADER,
        .get_UNIFORM_BUFFER = &get_UNIFORM_BUFFER,
        .get_UNIFORM_BUFFER_BINDING = &get_UNIFORM_BUFFER_BINDING,
        .get_UNIFORM_BUFFER_OFFSET_ALIGNMENT = &get_UNIFORM_BUFFER_OFFSET_ALIGNMENT,
        .get_UNIFORM_BUFFER_SIZE = &get_UNIFORM_BUFFER_SIZE,
        .get_UNIFORM_BUFFER_START = &get_UNIFORM_BUFFER_START,
        .get_UNIFORM_IS_ROW_MAJOR = &get_UNIFORM_IS_ROW_MAJOR,
        .get_UNIFORM_MATRIX_STRIDE = &get_UNIFORM_MATRIX_STRIDE,
        .get_UNIFORM_OFFSET = &get_UNIFORM_OFFSET,
        .get_UNIFORM_SIZE = &get_UNIFORM_SIZE,
        .get_UNIFORM_TYPE = &get_UNIFORM_TYPE,
        .get_UNPACK_IMAGE_HEIGHT = &get_UNPACK_IMAGE_HEIGHT,
        .get_UNPACK_ROW_LENGTH = &get_UNPACK_ROW_LENGTH,
        .get_UNPACK_SKIP_IMAGES = &get_UNPACK_SKIP_IMAGES,
        .get_UNPACK_SKIP_PIXELS = &get_UNPACK_SKIP_PIXELS,
        .get_UNPACK_SKIP_ROWS = &get_UNPACK_SKIP_ROWS,
        .get_UNSIGNALED = &get_UNSIGNALED,
        .get_UNSIGNED_INT_10F_11F_11F_REV = &get_UNSIGNED_INT_10F_11F_11F_REV,
        .get_UNSIGNED_INT_24_8 = &get_UNSIGNED_INT_24_8,
        .get_UNSIGNED_INT_2_10_10_10_REV = &get_UNSIGNED_INT_2_10_10_10_REV,
        .get_UNSIGNED_INT_5_9_9_9_REV = &get_UNSIGNED_INT_5_9_9_9_REV,
        .get_UNSIGNED_INT_SAMPLER_2D = &get_UNSIGNED_INT_SAMPLER_2D,
        .get_UNSIGNED_INT_SAMPLER_2D_ARRAY = &get_UNSIGNED_INT_SAMPLER_2D_ARRAY,
        .get_UNSIGNED_INT_SAMPLER_3D = &get_UNSIGNED_INT_SAMPLER_3D,
        .get_UNSIGNED_INT_SAMPLER_CUBE = &get_UNSIGNED_INT_SAMPLER_CUBE,
        .get_UNSIGNED_INT_VEC2 = &get_UNSIGNED_INT_VEC2,
        .get_UNSIGNED_INT_VEC3 = &get_UNSIGNED_INT_VEC3,
        .get_UNSIGNED_INT_VEC4 = &get_UNSIGNED_INT_VEC4,
        .get_UNSIGNED_NORMALIZED = &get_UNSIGNED_NORMALIZED,
        .get_VERTEX_ARRAY_BINDING = &get_VERTEX_ARRAY_BINDING,
        .get_VERTEX_ATTRIB_ARRAY_DIVISOR = &get_VERTEX_ATTRIB_ARRAY_DIVISOR,
        .get_VERTEX_ATTRIB_ARRAY_INTEGER = &get_VERTEX_ATTRIB_ARRAY_INTEGER,
        .get_WAIT_FAILED = &get_WAIT_FAILED,

        .call_beginQuery = &call_beginQuery,
        .call_beginTransformFeedback = &call_beginTransformFeedback,
        .call_bindBufferBase = &call_bindBufferBase,
        .call_bindBufferRange = &call_bindBufferRange,
        .call_bindSampler = &call_bindSampler,
        .call_bindTransformFeedback = &call_bindTransformFeedback,
        .call_bindVertexArray = &call_bindVertexArray,
        .call_blitFramebuffer = &call_blitFramebuffer,
        .call_clearBufferfi = &call_clearBufferfi,
        .call_clearBufferfv = &call_clearBufferfv,
        .call_clearBufferiv = &call_clearBufferiv,
        .call_clearBufferuiv = &call_clearBufferuiv,
        .call_clientWaitSync = &call_clientWaitSync,
        .call_compressedTexImage3D = &call_compressedTexImage3D,
        .call_compressedTexSubImage3D = &call_compressedTexSubImage3D,
        .call_copyBufferSubData = &call_copyBufferSubData,
        .call_copyTexSubImage3D = &call_copyTexSubImage3D,
        .call_createQuery = &call_createQuery,
        .call_createSampler = &call_createSampler,
        .call_createTransformFeedback = &call_createTransformFeedback,
        .call_createVertexArray = &call_createVertexArray,
        .call_deleteQuery = &call_deleteQuery,
        .call_deleteSampler = &call_deleteSampler,
        .call_deleteSync = &call_deleteSync,
        .call_deleteTransformFeedback = &call_deleteTransformFeedback,
        .call_deleteVertexArray = &call_deleteVertexArray,
        .call_drawArraysInstanced = &call_drawArraysInstanced,
        .call_drawBuffers = &call_drawBuffers,
        .call_drawElementsInstanced = &call_drawElementsInstanced,
        .call_drawRangeElements = &call_drawRangeElements,
        .call_endQuery = &call_endQuery,
        .call_endTransformFeedback = &call_endTransformFeedback,
        .call_fenceSync = &call_fenceSync,
        .call_framebufferTextureLayer = &call_framebufferTextureLayer,
        .call_getActiveUniformBlockName = &call_getActiveUniformBlockName,
        .call_getActiveUniformBlockParameter = &call_getActiveUniformBlockParameter,
        .call_getActiveUniforms = &call_getActiveUniforms,
        .call_getBufferSubData = &call_getBufferSubData,
        .call_getFragDataLocation = &call_getFragDataLocation,
        .call_getIndexedParameter = &call_getIndexedParameter,
        .call_getInternalformatParameter = &call_getInternalformatParameter,
        .call_getQuery = &call_getQuery,
        .call_getQueryParameter = &call_getQueryParameter,
        .call_getSamplerParameter = &call_getSamplerParameter,
        .call_getSyncParameter = &call_getSyncParameter,
        .call_getTransformFeedbackVarying = &call_getTransformFeedbackVarying,
        .call_getUniformBlockIndex = &call_getUniformBlockIndex,
        .call_getUniformIndices = &call_getUniformIndices,
        .call_invalidateFramebuffer = &call_invalidateFramebuffer,
        .call_invalidateSubFramebuffer = &call_invalidateSubFramebuffer,
        .call_isQuery = &call_isQuery,
        .call_isSampler = &call_isSampler,
        .call_isSync = &call_isSync,
        .call_isTransformFeedback = &call_isTransformFeedback,
        .call_isVertexArray = &call_isVertexArray,
        .call_pauseTransformFeedback = &call_pauseTransformFeedback,
        .call_readBuffer = &call_readBuffer,
        .call_renderbufferStorageMultisample = &call_renderbufferStorageMultisample,
        .call_resumeTransformFeedback = &call_resumeTransformFeedback,
        .call_samplerParameterf = &call_samplerParameterf,
        .call_samplerParameteri = &call_samplerParameteri,
        .call_texImage3D = &call_texImage3D,
        .call_texStorage2D = &call_texStorage2D,
        .call_texStorage3D = &call_texStorage3D,
        .call_texSubImage3D = &call_texSubImage3D,
        .call_transformFeedbackVaryings = &call_transformFeedbackVaryings,
        .call_uniform1ui = &call_uniform1ui,
        .call_uniform1uiv = &call_uniform1uiv,
        .call_uniform2ui = &call_uniform2ui,
        .call_uniform2uiv = &call_uniform2uiv,
        .call_uniform3ui = &call_uniform3ui,
        .call_uniform3uiv = &call_uniform3uiv,
        .call_uniform4ui = &call_uniform4ui,
        .call_uniform4uiv = &call_uniform4uiv,
        .call_uniformBlockBinding = &call_uniformBlockBinding,
        .call_uniformMatrix2x3fv = &call_uniformMatrix2x3fv,
        .call_uniformMatrix2x4fv = &call_uniformMatrix2x4fv,
        .call_uniformMatrix3x2fv = &call_uniformMatrix3x2fv,
        .call_uniformMatrix3x4fv = &call_uniformMatrix3x4fv,
        .call_uniformMatrix4x2fv = &call_uniformMatrix4x2fv,
        .call_uniformMatrix4x3fv = &call_uniformMatrix4x3fv,
        .call_vertexAttribDivisor = &call_vertexAttribDivisor,
        .call_vertexAttribI4i = &call_vertexAttribI4i,
        .call_vertexAttribI4iv = &call_vertexAttribI4iv,
        .call_vertexAttribI4ui = &call_vertexAttribI4ui,
        .call_vertexAttribI4uiv = &call_vertexAttribI4uiv,
        .call_vertexAttribIPointer = &call_vertexAttribIPointer,
        .call_waitSync = &call_waitSync,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        WebGL2RenderingContextBaseImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WebGL2RenderingContextBaseImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_resumeTransformFeedback(instance: *runtime.Instance) anyerror!void {
        return try WebGL2RenderingContextBaseImpl.call_resumeTransformFeedback(instance);
    }

    pub fn call_uniform4ui(instance: *runtime.Instance, location: anyopaque, v0: GLuint, v1: GLuint, v2: GLuint, v3: GLuint) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_uniform4ui(instance, location, v0, v1, v2, v3);
    }

    pub fn call_texStorage3D(instance: *runtime.Instance, target: GLenum, levels: GLsizei, internalformat: GLenum, width: GLsizei, height: GLsizei, depth: GLsizei) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_texStorage3D(instance, target, levels, internalformat, width, height, depth);
    }

    pub fn call_vertexAttribDivisor(instance: *runtime.Instance, index: GLuint, divisor: GLuint) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_vertexAttribDivisor(instance, index, divisor);
    }

    pub fn call_uniformBlockBinding(instance: *runtime.Instance, program: WebGLProgram, uniformBlockIndex: GLuint, uniformBlockBinding: GLuint) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_uniformBlockBinding(instance, program, uniformBlockIndex, uniformBlockBinding);
    }

    pub fn call_createTransformFeedback(instance: *runtime.Instance) anyerror!WebGLTransformFeedback {
        return try WebGL2RenderingContextBaseImpl.call_createTransformFeedback(instance);
    }

    pub fn call_getQuery(instance: *runtime.Instance, target: GLenum, pname: GLenum) anyerror!anyopaque {
        
        return try WebGL2RenderingContextBaseImpl.call_getQuery(instance, target, pname);
    }

    pub fn call_createVertexArray(instance: *runtime.Instance) anyerror!WebGLVertexArrayObject {
        return try WebGL2RenderingContextBaseImpl.call_createVertexArray(instance);
    }

    pub fn call_readBuffer(instance: *runtime.Instance, src: GLenum) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_readBuffer(instance, src);
    }

    pub fn call_endTransformFeedback(instance: *runtime.Instance) anyerror!void {
        return try WebGL2RenderingContextBaseImpl.call_endTransformFeedback(instance);
    }

    pub fn call_clearBufferuiv(instance: *runtime.Instance, buffer: GLenum, drawbuffer: GLint, values: Uint32List, srcOffset: u64) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_clearBufferuiv(instance, buffer, drawbuffer, values, srcOffset);
    }

    pub fn call_getUniformIndices(instance: *runtime.Instance, program: WebGLProgram, uniformNames: anyopaque) anyerror!anyopaque {
        
        return try WebGL2RenderingContextBaseImpl.call_getUniformIndices(instance, program, uniformNames);
    }

    pub fn call_renderbufferStorageMultisample(instance: *runtime.Instance, target: GLenum, samples: GLsizei, internalformat: GLenum, width: GLsizei, height: GLsizei) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_renderbufferStorageMultisample(instance, target, samples, internalformat, width, height);
    }

    pub fn call_clearBufferfv(instance: *runtime.Instance, buffer: GLenum, drawbuffer: GLint, values: Float32List, srcOffset: u64) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_clearBufferfv(instance, buffer, drawbuffer, values, srcOffset);
    }

    pub fn call_clearBufferfi(instance: *runtime.Instance, buffer: GLenum, drawbuffer: GLint, depth: GLfloat, stencil: GLint) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_clearBufferfi(instance, buffer, drawbuffer, depth, stencil);
    }

    /// Arguments for texImage3D (WebIDL overloading)
    pub const TexImage3DArgs = union(enum) {
        /// texImage3D(target, level, internalformat, width, height, depth, border, format, type, pboOffset)
        GLenum_GLint_GLint_GLsizei_GLsizei_GLsizei_GLint_GLenum_GLenum_GLintptr: struct {
            target: GLenum,
            level: GLint,
            internalformat: GLint,
            width: GLsizei,
            height: GLsizei,
            depth: GLsizei,
            border: GLint,
            format: GLenum,
            type_: GLenum,
            pboOffset: GLintptr,
        },
        /// texImage3D(target, level, internalformat, width, height, depth, border, format, type, source)
        GLenum_GLint_GLint_GLsizei_GLsizei_GLsizei_GLint_GLenum_GLenum_TexImageSource: struct {
            target: GLenum,
            level: GLint,
            internalformat: GLint,
            width: GLsizei,
            height: GLsizei,
            depth: GLsizei,
            border: GLint,
            format: GLenum,
            type_: GLenum,
            source: TexImageSource,
        },
        /// texImage3D(target, level, internalformat, width, height, depth, border, format, type, srcData)
        GLenum_GLint_GLint_GLsizei_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView?: struct {
            target: GLenum,
            level: GLint,
            internalformat: GLint,
            width: GLsizei,
            height: GLsizei,
            depth: GLsizei,
            border: GLint,
            format: GLenum,
            type_: GLenum,
            srcData: anyopaque,
        },
        /// texImage3D(target, level, internalformat, width, height, depth, border, format, type, srcData, srcOffset)
        GLenum_GLint_GLint_GLsizei_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView_long long: struct {
            target: GLenum,
            level: GLint,
            internalformat: GLint,
            width: GLsizei,
            height: GLsizei,
            depth: GLsizei,
            border: GLint,
            format: GLenum,
            type_: GLenum,
            srcData: ArrayBufferView,
            srcOffset: u64,
        },
    };

    pub fn call_texImage3D(instance: *runtime.Instance, args: TexImage3DArgs) anyerror!void {
        switch (args) {
            .GLenum_GLint_GLint_GLsizei_GLsizei_GLsizei_GLint_GLenum_GLenum_GLintptr => |a| return try WebGL2RenderingContextBaseImpl.GLenum_GLint_GLint_GLsizei_GLsizei_GLsizei_GLint_GLenum_GLenum_GLintptr(instance, a.target, a.level, a.internalformat, a.width, a.height, a.depth, a.border, a.format, a.type_, a.pboOffset),
            .GLenum_GLint_GLint_GLsizei_GLsizei_GLsizei_GLint_GLenum_GLenum_TexImageSource => |a| return try WebGL2RenderingContextBaseImpl.GLenum_GLint_GLint_GLsizei_GLsizei_GLsizei_GLint_GLenum_GLenum_TexImageSource(instance, a.target, a.level, a.internalformat, a.width, a.height, a.depth, a.border, a.format, a.type_, a.source),
            .GLenum_GLint_GLint_GLsizei_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView? => |a| return try WebGL2RenderingContextBaseImpl.GLenum_GLint_GLint_GLsizei_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView?(instance, a.target, a.level, a.internalformat, a.width, a.height, a.depth, a.border, a.format, a.type_, a.srcData),
            .GLenum_GLint_GLint_GLsizei_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView_long long => |a| return try WebGL2RenderingContextBaseImpl.GLenum_GLint_GLint_GLsizei_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView_long long(instance, a.target, a.level, a.internalformat, a.width, a.height, a.depth, a.border, a.format, a.type_, a.srcData, a.srcOffset),
        }
    }

    pub fn call_texStorage2D(instance: *runtime.Instance, target: GLenum, levels: GLsizei, internalformat: GLenum, width: GLsizei, height: GLsizei) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_texStorage2D(instance, target, levels, internalformat, width, height);
    }

    pub fn call_clientWaitSync(instance: *runtime.Instance, sync: WebGLSync, flags: GLbitfield, timeout: GLuint64) anyerror!GLenum {
        
        return try WebGL2RenderingContextBaseImpl.call_clientWaitSync(instance, sync, flags, timeout);
    }

    pub fn call_transformFeedbackVaryings(instance: *runtime.Instance, program: WebGLProgram, varyings: anyopaque, bufferMode: GLenum) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_transformFeedbackVaryings(instance, program, varyings, bufferMode);
    }

    pub fn call_invalidateSubFramebuffer(instance: *runtime.Instance, target: GLenum, attachments: anyopaque, x: GLint, y: GLint, width: GLsizei, height: GLsizei) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_invalidateSubFramebuffer(instance, target, attachments, x, y, width, height);
    }

    pub fn call_fenceSync(instance: *runtime.Instance, condition: GLenum, flags: GLbitfield) anyerror!anyopaque {
        
        return try WebGL2RenderingContextBaseImpl.call_fenceSync(instance, condition, flags);
    }

    pub fn call_deleteSampler(instance: *runtime.Instance, sampler: anyopaque) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_deleteSampler(instance, sampler);
    }

    pub fn call_uniformMatrix2x3fv(instance: *runtime.Instance, location: anyopaque, transpose: GLboolean, data: Float32List, srcOffset: u64, srcLength: GLuint) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_uniformMatrix2x3fv(instance, location, transpose, data, srcOffset, srcLength);
    }

    pub fn call_uniformMatrix4x3fv(instance: *runtime.Instance, location: anyopaque, transpose: GLboolean, data: Float32List, srcOffset: u64, srcLength: GLuint) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_uniformMatrix4x3fv(instance, location, transpose, data, srcOffset, srcLength);
    }

    pub fn call_uniform2ui(instance: *runtime.Instance, location: anyopaque, v0: GLuint, v1: GLuint) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_uniform2ui(instance, location, v0, v1);
    }

    pub fn call_getSyncParameter(instance: *runtime.Instance, sync: WebGLSync, pname: GLenum) anyerror!anyopaque {
        
        return try WebGL2RenderingContextBaseImpl.call_getSyncParameter(instance, sync, pname);
    }

    pub fn call_getUniformBlockIndex(instance: *runtime.Instance, program: WebGLProgram, uniformBlockName: DOMString) anyerror!GLuint {
        
        return try WebGL2RenderingContextBaseImpl.call_getUniformBlockIndex(instance, program, uniformBlockName);
    }

    pub fn call_copyTexSubImage3D(instance: *runtime.Instance, target: GLenum, level: GLint, xoffset: GLint, yoffset: GLint, zoffset: GLint, x: GLint, y: GLint, width: GLsizei, height: GLsizei) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_copyTexSubImage3D(instance, target, level, xoffset, yoffset, zoffset, x, y, width, height);
    }

    /// Arguments for texSubImage3D (WebIDL overloading)
    pub const TexSubImage3DArgs = union(enum) {
        /// texSubImage3D(target, level, xoffset, yoffset, zoffset, width, height, depth, format, type, pboOffset)
        GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_GLenum_GLintptr: struct {
            target: GLenum,
            level: GLint,
            xoffset: GLint,
            yoffset: GLint,
            zoffset: GLint,
            width: GLsizei,
            height: GLsizei,
            depth: GLsizei,
            format: GLenum,
            type_: GLenum,
            pboOffset: GLintptr,
        },
        /// texSubImage3D(target, level, xoffset, yoffset, zoffset, width, height, depth, format, type, source)
        GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_GLenum_TexImageSource: struct {
            target: GLenum,
            level: GLint,
            xoffset: GLint,
            yoffset: GLint,
            zoffset: GLint,
            width: GLsizei,
            height: GLsizei,
            depth: GLsizei,
            format: GLenum,
            type_: GLenum,
            source: TexImageSource,
        },
        /// texSubImage3D(target, level, xoffset, yoffset, zoffset, width, height, depth, format, type, srcData, srcOffset)
        GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView?_long long: struct {
            target: GLenum,
            level: GLint,
            xoffset: GLint,
            yoffset: GLint,
            zoffset: GLint,
            width: GLsizei,
            height: GLsizei,
            depth: GLsizei,
            format: GLenum,
            type_: GLenum,
            srcData: anyopaque,
            srcOffset: u64,
        },
    };

    pub fn call_texSubImage3D(instance: *runtime.Instance, args: TexSubImage3DArgs) anyerror!void {
        switch (args) {
            .GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_GLenum_GLintptr => |a| return try WebGL2RenderingContextBaseImpl.GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_GLenum_GLintptr(instance, a.target, a.level, a.xoffset, a.yoffset, a.zoffset, a.width, a.height, a.depth, a.format, a.type_, a.pboOffset),
            .GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_GLenum_TexImageSource => |a| return try WebGL2RenderingContextBaseImpl.GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_GLenum_TexImageSource(instance, a.target, a.level, a.xoffset, a.yoffset, a.zoffset, a.width, a.height, a.depth, a.format, a.type_, a.source),
            .GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView?_long long => |a| return try WebGL2RenderingContextBaseImpl.GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView?_long long(instance, a.target, a.level, a.xoffset, a.yoffset, a.zoffset, a.width, a.height, a.depth, a.format, a.type_, a.srcData, a.srcOffset),
        }
    }

    pub fn call_clearBufferiv(instance: *runtime.Instance, buffer: GLenum, drawbuffer: GLint, values: Int32List, srcOffset: u64) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_clearBufferiv(instance, buffer, drawbuffer, values, srcOffset);
    }

    pub fn call_drawRangeElements(instance: *runtime.Instance, mode: GLenum, start: GLuint, end: GLuint, count: GLsizei, type_: GLenum, offset: GLintptr) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_drawRangeElements(instance, mode, start, end, count, type_, offset);
    }

    pub fn call_endQuery(instance: *runtime.Instance, target: GLenum) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_endQuery(instance, target);
    }

    pub fn call_framebufferTextureLayer(instance: *runtime.Instance, target: GLenum, attachment: GLenum, texture: anyopaque, level: GLint, layer: GLint) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_framebufferTextureLayer(instance, target, attachment, texture, level, layer);
    }

    pub fn call_blitFramebuffer(instance: *runtime.Instance, srcX0: GLint, srcY0: GLint, srcX1: GLint, srcY1: GLint, dstX0: GLint, dstY0: GLint, dstX1: GLint, dstY1: GLint, mask: GLbitfield, filter: GLenum) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_blitFramebuffer(instance, srcX0, srcY0, srcX1, srcY1, dstX0, dstY0, dstX1, dstY1, mask, filter);
    }

    pub fn call_vertexAttribI4i(instance: *runtime.Instance, index: GLuint, x: GLint, y: GLint, z: GLint, w: GLint) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_vertexAttribI4i(instance, index, x, y, z, w);
    }

    pub fn call_drawElementsInstanced(instance: *runtime.Instance, mode: GLenum, count: GLsizei, type_: GLenum, offset: GLintptr, instanceCount: GLsizei) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_drawElementsInstanced(instance, mode, count, type_, offset, instanceCount);
    }

    pub fn call_vertexAttribI4uiv(instance: *runtime.Instance, index: GLuint, values: Uint32List) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_vertexAttribI4uiv(instance, index, values);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_isSampler(instance: *runtime.Instance, sampler: anyopaque) anyerror!GLboolean {
        
        return try WebGL2RenderingContextBaseImpl.call_isSampler(instance, sampler);
    }

    pub fn call_bindSampler(instance: *runtime.Instance, unit: GLuint, sampler: anyopaque) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_bindSampler(instance, unit, sampler);
    }

    pub fn call_getSamplerParameter(instance: *runtime.Instance, sampler: WebGLSampler, pname: GLenum) anyerror!anyopaque {
        
        return try WebGL2RenderingContextBaseImpl.call_getSamplerParameter(instance, sampler, pname);
    }

    pub fn call_beginTransformFeedback(instance: *runtime.Instance, primitiveMode: GLenum) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_beginTransformFeedback(instance, primitiveMode);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_isQuery(instance: *runtime.Instance, query: anyopaque) anyerror!GLboolean {
        
        return try WebGL2RenderingContextBaseImpl.call_isQuery(instance, query);
    }

    pub fn call_pauseTransformFeedback(instance: *runtime.Instance) anyerror!void {
        return try WebGL2RenderingContextBaseImpl.call_pauseTransformFeedback(instance);
    }

    pub fn call_bindBufferBase(instance: *runtime.Instance, target: GLenum, index: GLuint, buffer: anyopaque) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_bindBufferBase(instance, target, index, buffer);
    }

    pub fn call_uniform3uiv(instance: *runtime.Instance, location: anyopaque, data: Uint32List, srcOffset: u64, srcLength: GLuint) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_uniform3uiv(instance, location, data, srcOffset, srcLength);
    }

    pub fn call_uniformMatrix4x2fv(instance: *runtime.Instance, location: anyopaque, transpose: GLboolean, data: Float32List, srcOffset: u64, srcLength: GLuint) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_uniformMatrix4x2fv(instance, location, transpose, data, srcOffset, srcLength);
    }

    pub fn call_getInternalformatParameter(instance: *runtime.Instance, target: GLenum, internalformat: GLenum, pname: GLenum) anyerror!anyopaque {
        
        return try WebGL2RenderingContextBaseImpl.call_getInternalformatParameter(instance, target, internalformat, pname);
    }

    pub fn call_uniform4uiv(instance: *runtime.Instance, location: anyopaque, data: Uint32List, srcOffset: u64, srcLength: GLuint) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_uniform4uiv(instance, location, data, srcOffset, srcLength);
    }

    pub fn call_drawArraysInstanced(instance: *runtime.Instance, mode: GLenum, first: GLint, count: GLsizei, instanceCount: GLsizei) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_drawArraysInstanced(instance, mode, first, count, instanceCount);
    }

    pub fn call_vertexAttribI4ui(instance: *runtime.Instance, index: GLuint, x: GLuint, y: GLuint, z: GLuint, w: GLuint) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_vertexAttribI4ui(instance, index, x, y, z, w);
    }

    pub fn call_createQuery(instance: *runtime.Instance) anyerror!WebGLQuery {
        return try WebGL2RenderingContextBaseImpl.call_createQuery(instance);
    }

    pub fn call_getActiveUniformBlockName(instance: *runtime.Instance, program: WebGLProgram, uniformBlockIndex: GLuint) anyerror!anyopaque {
        
        return try WebGL2RenderingContextBaseImpl.call_getActiveUniformBlockName(instance, program, uniformBlockIndex);
    }

    pub fn call_drawBuffers(instance: *runtime.Instance, buffers: anyopaque) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_drawBuffers(instance, buffers);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_isVertexArray(instance: *runtime.Instance, vertexArray: anyopaque) anyerror!GLboolean {
        
        return try WebGL2RenderingContextBaseImpl.call_isVertexArray(instance, vertexArray);
    }

    pub fn call_bindVertexArray(instance: *runtime.Instance, array: anyopaque) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_bindVertexArray(instance, array);
    }

    pub fn call_deleteSync(instance: *runtime.Instance, sync: anyopaque) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_deleteSync(instance, sync);
    }

    pub fn call_getBufferSubData(instance: *runtime.Instance, target: GLenum, srcByteOffset: GLintptr, dstBuffer: ArrayBufferView, dstOffset: u64, length: GLuint) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_getBufferSubData(instance, target, srcByteOffset, dstBuffer, dstOffset, length);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_getFragDataLocation(instance: *runtime.Instance, program: WebGLProgram, name: DOMString) anyerror!GLint {
        
        return try WebGL2RenderingContextBaseImpl.call_getFragDataLocation(instance, program, name);
    }

    pub fn call_getQueryParameter(instance: *runtime.Instance, query: WebGLQuery, pname: GLenum) anyerror!anyopaque {
        
        return try WebGL2RenderingContextBaseImpl.call_getQueryParameter(instance, query, pname);
    }

    pub fn call_uniformMatrix3x2fv(instance: *runtime.Instance, location: anyopaque, transpose: GLboolean, data: Float32List, srcOffset: u64, srcLength: GLuint) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_uniformMatrix3x2fv(instance, location, transpose, data, srcOffset, srcLength);
    }

    pub fn call_vertexAttribI4iv(instance: *runtime.Instance, index: GLuint, values: Int32List) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_vertexAttribI4iv(instance, index, values);
    }

    pub fn call_deleteQuery(instance: *runtime.Instance, query: anyopaque) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_deleteQuery(instance, query);
    }

    /// Arguments for compressedTexSubImage3D (WebIDL overloading)
    pub const CompressedTexSubImage3DArgs = union(enum) {
        /// compressedTexSubImage3D(target, level, xoffset, yoffset, zoffset, width, height, depth, format, imageSize, offset)
        GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_GLsizei_GLintptr: struct {
            target: GLenum,
            level: GLint,
            xoffset: GLint,
            yoffset: GLint,
            zoffset: GLint,
            width: GLsizei,
            height: GLsizei,
            depth: GLsizei,
            format: GLenum,
            imageSize: GLsizei,
            offset: GLintptr,
        },
        /// compressedTexSubImage3D(target, level, xoffset, yoffset, zoffset, width, height, depth, format, srcData, srcOffset, srcLengthOverride)
        GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_ArrayBufferView_long long_GLuint: struct {
            target: GLenum,
            level: GLint,
            xoffset: GLint,
            yoffset: GLint,
            zoffset: GLint,
            width: GLsizei,
            height: GLsizei,
            depth: GLsizei,
            format: GLenum,
            srcData: ArrayBufferView,
            srcOffset: u64,
            srcLengthOverride: GLuint,
        },
    };

    pub fn call_compressedTexSubImage3D(instance: *runtime.Instance, args: CompressedTexSubImage3DArgs) anyerror!void {
        switch (args) {
            .GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_GLsizei_GLintptr => |a| return try WebGL2RenderingContextBaseImpl.GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_GLsizei_GLintptr(instance, a.target, a.level, a.xoffset, a.yoffset, a.zoffset, a.width, a.height, a.depth, a.format, a.imageSize, a.offset),
            .GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_ArrayBufferView_long long_GLuint => |a| return try WebGL2RenderingContextBaseImpl.GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_ArrayBufferView_long long_GLuint(instance, a.target, a.level, a.xoffset, a.yoffset, a.zoffset, a.width, a.height, a.depth, a.format, a.srcData, a.srcOffset, a.srcLengthOverride),
        }
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_isSync(instance: *runtime.Instance, sync: anyopaque) anyerror!GLboolean {
        
        return try WebGL2RenderingContextBaseImpl.call_isSync(instance, sync);
    }

    pub fn call_getActiveUniforms(instance: *runtime.Instance, program: WebGLProgram, uniformIndices: anyopaque, pname: GLenum) anyerror!anyopaque {
        
        return try WebGL2RenderingContextBaseImpl.call_getActiveUniforms(instance, program, uniformIndices, pname);
    }

    pub fn call_bindTransformFeedback(instance: *runtime.Instance, target: GLenum, tf: anyopaque) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_bindTransformFeedback(instance, target, tf);
    }

    pub fn call_uniformMatrix3x4fv(instance: *runtime.Instance, location: anyopaque, transpose: GLboolean, data: Float32List, srcOffset: u64, srcLength: GLuint) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_uniformMatrix3x4fv(instance, location, transpose, data, srcOffset, srcLength);
    }

    pub fn call_vertexAttribIPointer(instance: *runtime.Instance, index: GLuint, size: GLint, type_: GLenum, stride: GLsizei, offset: GLintptr) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_vertexAttribIPointer(instance, index, size, type_, stride, offset);
    }

    pub fn call_getTransformFeedbackVarying(instance: *runtime.Instance, program: WebGLProgram, index: GLuint) anyerror!anyopaque {
        
        return try WebGL2RenderingContextBaseImpl.call_getTransformFeedbackVarying(instance, program, index);
    }

    pub fn call_samplerParameteri(instance: *runtime.Instance, sampler: WebGLSampler, pname: GLenum, param: GLint) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_samplerParameteri(instance, sampler, pname, param);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_isTransformFeedback(instance: *runtime.Instance, tf: anyopaque) anyerror!GLboolean {
        
        return try WebGL2RenderingContextBaseImpl.call_isTransformFeedback(instance, tf);
    }

    pub fn call_beginQuery(instance: *runtime.Instance, target: GLenum, query: WebGLQuery) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_beginQuery(instance, target, query);
    }

    pub fn call_createSampler(instance: *runtime.Instance) anyerror!WebGLSampler {
        return try WebGL2RenderingContextBaseImpl.call_createSampler(instance);
    }

    pub fn call_deleteTransformFeedback(instance: *runtime.Instance, tf: anyopaque) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_deleteTransformFeedback(instance, tf);
    }

    pub fn call_uniform1ui(instance: *runtime.Instance, location: anyopaque, v0: GLuint) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_uniform1ui(instance, location, v0);
    }

    pub fn call_getActiveUniformBlockParameter(instance: *runtime.Instance, program: WebGLProgram, uniformBlockIndex: GLuint, pname: GLenum) anyerror!anyopaque {
        
        return try WebGL2RenderingContextBaseImpl.call_getActiveUniformBlockParameter(instance, program, uniformBlockIndex, pname);
    }

    pub fn call_invalidateFramebuffer(instance: *runtime.Instance, target: GLenum, attachments: anyopaque) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_invalidateFramebuffer(instance, target, attachments);
    }

    pub fn call_getIndexedParameter(instance: *runtime.Instance, target: GLenum, index: GLuint) anyerror!anyopaque {
        
        return try WebGL2RenderingContextBaseImpl.call_getIndexedParameter(instance, target, index);
    }

    /// Arguments for compressedTexImage3D (WebIDL overloading)
    pub const CompressedTexImage3DArgs = union(enum) {
        /// compressedTexImage3D(target, level, internalformat, width, height, depth, border, imageSize, offset)
        GLenum_GLint_GLenum_GLsizei_GLsizei_GLsizei_GLint_GLsizei_GLintptr: struct {
            target: GLenum,
            level: GLint,
            internalformat: GLenum,
            width: GLsizei,
            height: GLsizei,
            depth: GLsizei,
            border: GLint,
            imageSize: GLsizei,
            offset: GLintptr,
        },
        /// compressedTexImage3D(target, level, internalformat, width, height, depth, border, srcData, srcOffset, srcLengthOverride)
        GLenum_GLint_GLenum_GLsizei_GLsizei_GLsizei_GLint_ArrayBufferView_long long_GLuint: struct {
            target: GLenum,
            level: GLint,
            internalformat: GLenum,
            width: GLsizei,
            height: GLsizei,
            depth: GLsizei,
            border: GLint,
            srcData: ArrayBufferView,
            srcOffset: u64,
            srcLengthOverride: GLuint,
        },
    };

    pub fn call_compressedTexImage3D(instance: *runtime.Instance, args: CompressedTexImage3DArgs) anyerror!void {
        switch (args) {
            .GLenum_GLint_GLenum_GLsizei_GLsizei_GLsizei_GLint_GLsizei_GLintptr => |a| return try WebGL2RenderingContextBaseImpl.GLenum_GLint_GLenum_GLsizei_GLsizei_GLsizei_GLint_GLsizei_GLintptr(instance, a.target, a.level, a.internalformat, a.width, a.height, a.depth, a.border, a.imageSize, a.offset),
            .GLenum_GLint_GLenum_GLsizei_GLsizei_GLsizei_GLint_ArrayBufferView_long long_GLuint => |a| return try WebGL2RenderingContextBaseImpl.GLenum_GLint_GLenum_GLsizei_GLsizei_GLsizei_GLint_ArrayBufferView_long long_GLuint(instance, a.target, a.level, a.internalformat, a.width, a.height, a.depth, a.border, a.srcData, a.srcOffset, a.srcLengthOverride),
        }
    }

    pub fn call_copyBufferSubData(instance: *runtime.Instance, readTarget: GLenum, writeTarget: GLenum, readOffset: GLintptr, writeOffset: GLintptr, size: GLsizeiptr) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_copyBufferSubData(instance, readTarget, writeTarget, readOffset, writeOffset, size);
    }

    pub fn call_uniform2uiv(instance: *runtime.Instance, location: anyopaque, data: Uint32List, srcOffset: u64, srcLength: GLuint) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_uniform2uiv(instance, location, data, srcOffset, srcLength);
    }

    pub fn call_uniformMatrix2x4fv(instance: *runtime.Instance, location: anyopaque, transpose: GLboolean, data: Float32List, srcOffset: u64, srcLength: GLuint) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_uniformMatrix2x4fv(instance, location, transpose, data, srcOffset, srcLength);
    }

    pub fn call_samplerParameterf(instance: *runtime.Instance, sampler: WebGLSampler, pname: GLenum, param: GLfloat) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_samplerParameterf(instance, sampler, pname, param);
    }

    pub fn call_deleteVertexArray(instance: *runtime.Instance, vertexArray: anyopaque) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_deleteVertexArray(instance, vertexArray);
    }

    pub fn call_uniform3ui(instance: *runtime.Instance, location: anyopaque, v0: GLuint, v1: GLuint, v2: GLuint) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_uniform3ui(instance, location, v0, v1, v2);
    }

    pub fn call_waitSync(instance: *runtime.Instance, sync: WebGLSync, flags: GLbitfield, timeout: GLint64) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_waitSync(instance, sync, flags, timeout);
    }

    pub fn call_uniform1uiv(instance: *runtime.Instance, location: anyopaque, data: Uint32List, srcOffset: u64, srcLength: GLuint) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_uniform1uiv(instance, location, data, srcOffset, srcLength);
    }

    pub fn call_bindBufferRange(instance: *runtime.Instance, target: GLenum, index: GLuint, buffer: anyopaque, offset: GLintptr, size: GLsizeiptr) anyerror!void {
        
        return try WebGL2RenderingContextBaseImpl.call_bindBufferRange(instance, target, index, buffer, offset, size);
    }

};
