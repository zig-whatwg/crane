//! Generated from: webgl1.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WebGLRenderingContextBaseImpl = @import("impls").WebGLRenderingContextBase;
const WebGLActiveInfo = @import("interfaces").WebGLActiveInfo;
const GLboolean = @import("typedefs").GLboolean;
const object = @import("interfaces").object;
const GLint = @import("typedefs").GLint;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const GLenum = @import("typedefs").GLenum;
const WebGLFramebuffer = @import("interfaces").WebGLFramebuffer;
const GLintptr = @import("typedefs").GLintptr;
const WebGLProgram = @import("interfaces").WebGLProgram;
const WebGLBuffer = @import("interfaces").WebGLBuffer;
const PredefinedColorSpace = @import("enums").PredefinedColorSpace;
const WebGLShaderPrecisionFormat = @import("interfaces").WebGLShaderPrecisionFormat;
const WebGLTexture = @import("interfaces").WebGLTexture;
const (HTMLCanvasElement or OffscreenCanvas) = @import("interfaces").(HTMLCanvasElement or OffscreenCanvas);
const GLfloat = @import("typedefs").GLfloat;
const WebGLRenderbuffer = @import("interfaces").WebGLRenderbuffer;
const WebGLContextAttributes = @import("dictionaries").WebGLContextAttributes;
const GLbitfield = @import("typedefs").GLbitfield;
const Float32List = @import("typedefs").Float32List;
const GLuint = @import("typedefs").GLuint;
const WebGLShader = @import("interfaces").WebGLShader;
const GLclampf = @import("typedefs").GLclampf;
const GLsizei = @import("typedefs").GLsizei;
const sequence = @import("interfaces").sequence;
const WebGLUniformLocation = @import("interfaces").WebGLUniformLocation;
const DOMString = @import("typedefs").DOMString;

pub const WebGLRenderingContextBase = struct {
    pub const Meta = struct {
        pub const name = "WebGLRenderingContextBase";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            canvas: (HTMLCanvasElement or OffscreenCanvas) = undefined,
            drawingBufferWidth: GLsizei = undefined,
            drawingBufferHeight: GLsizei = undefined,
            drawingBufferFormat: GLenum = undefined,
            drawingBufferColorSpace: PredefinedColorSpace = undefined,
            unpackColorSpace: PredefinedColorSpace = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const GLenum DEPTH_BUFFER_BIT = 256;
    pub fn get_DEPTH_BUFFER_BIT() GLenum {
        return 256;
    }

    /// WebIDL constant: const GLenum STENCIL_BUFFER_BIT = 1024;
    pub fn get_STENCIL_BUFFER_BIT() GLenum {
        return 1024;
    }

    /// WebIDL constant: const GLenum COLOR_BUFFER_BIT = 16384;
    pub fn get_COLOR_BUFFER_BIT() GLenum {
        return 16384;
    }

    /// WebIDL constant: const GLenum POINTS = 0;
    pub fn get_POINTS() GLenum {
        return 0;
    }

    /// WebIDL constant: const GLenum LINES = 1;
    pub fn get_LINES() GLenum {
        return 1;
    }

    /// WebIDL constant: const GLenum LINE_LOOP = 2;
    pub fn get_LINE_LOOP() GLenum {
        return 2;
    }

    /// WebIDL constant: const GLenum LINE_STRIP = 3;
    pub fn get_LINE_STRIP() GLenum {
        return 3;
    }

    /// WebIDL constant: const GLenum TRIANGLES = 4;
    pub fn get_TRIANGLES() GLenum {
        return 4;
    }

    /// WebIDL constant: const GLenum TRIANGLE_STRIP = 5;
    pub fn get_TRIANGLE_STRIP() GLenum {
        return 5;
    }

    /// WebIDL constant: const GLenum TRIANGLE_FAN = 6;
    pub fn get_TRIANGLE_FAN() GLenum {
        return 6;
    }

    /// WebIDL constant: const GLenum ZERO = 0;
    pub fn get_ZERO() GLenum {
        return 0;
    }

    /// WebIDL constant: const GLenum ONE = 1;
    pub fn get_ONE() GLenum {
        return 1;
    }

    /// WebIDL constant: const GLenum SRC_COLOR = 768;
    pub fn get_SRC_COLOR() GLenum {
        return 768;
    }

    /// WebIDL constant: const GLenum ONE_MINUS_SRC_COLOR = 769;
    pub fn get_ONE_MINUS_SRC_COLOR() GLenum {
        return 769;
    }

    /// WebIDL constant: const GLenum SRC_ALPHA = 770;
    pub fn get_SRC_ALPHA() GLenum {
        return 770;
    }

    /// WebIDL constant: const GLenum ONE_MINUS_SRC_ALPHA = 771;
    pub fn get_ONE_MINUS_SRC_ALPHA() GLenum {
        return 771;
    }

    /// WebIDL constant: const GLenum DST_ALPHA = 772;
    pub fn get_DST_ALPHA() GLenum {
        return 772;
    }

    /// WebIDL constant: const GLenum ONE_MINUS_DST_ALPHA = 773;
    pub fn get_ONE_MINUS_DST_ALPHA() GLenum {
        return 773;
    }

    /// WebIDL constant: const GLenum DST_COLOR = 774;
    pub fn get_DST_COLOR() GLenum {
        return 774;
    }

    /// WebIDL constant: const GLenum ONE_MINUS_DST_COLOR = 775;
    pub fn get_ONE_MINUS_DST_COLOR() GLenum {
        return 775;
    }

    /// WebIDL constant: const GLenum SRC_ALPHA_SATURATE = 776;
    pub fn get_SRC_ALPHA_SATURATE() GLenum {
        return 776;
    }

    /// WebIDL constant: const GLenum FUNC_ADD = 32774;
    pub fn get_FUNC_ADD() GLenum {
        return 32774;
    }

    /// WebIDL constant: const GLenum BLEND_EQUATION = 32777;
    pub fn get_BLEND_EQUATION() GLenum {
        return 32777;
    }

    /// WebIDL constant: const GLenum BLEND_EQUATION_RGB = 32777;
    pub fn get_BLEND_EQUATION_RGB() GLenum {
        return 32777;
    }

    /// WebIDL constant: const GLenum BLEND_EQUATION_ALPHA = 34877;
    pub fn get_BLEND_EQUATION_ALPHA() GLenum {
        return 34877;
    }

    /// WebIDL constant: const GLenum FUNC_SUBTRACT = 32778;
    pub fn get_FUNC_SUBTRACT() GLenum {
        return 32778;
    }

    /// WebIDL constant: const GLenum FUNC_REVERSE_SUBTRACT = 32779;
    pub fn get_FUNC_REVERSE_SUBTRACT() GLenum {
        return 32779;
    }

    /// WebIDL constant: const GLenum BLEND_DST_RGB = 32968;
    pub fn get_BLEND_DST_RGB() GLenum {
        return 32968;
    }

    /// WebIDL constant: const GLenum BLEND_SRC_RGB = 32969;
    pub fn get_BLEND_SRC_RGB() GLenum {
        return 32969;
    }

    /// WebIDL constant: const GLenum BLEND_DST_ALPHA = 32970;
    pub fn get_BLEND_DST_ALPHA() GLenum {
        return 32970;
    }

    /// WebIDL constant: const GLenum BLEND_SRC_ALPHA = 32971;
    pub fn get_BLEND_SRC_ALPHA() GLenum {
        return 32971;
    }

    /// WebIDL constant: const GLenum CONSTANT_COLOR = 32769;
    pub fn get_CONSTANT_COLOR() GLenum {
        return 32769;
    }

    /// WebIDL constant: const GLenum ONE_MINUS_CONSTANT_COLOR = 32770;
    pub fn get_ONE_MINUS_CONSTANT_COLOR() GLenum {
        return 32770;
    }

    /// WebIDL constant: const GLenum CONSTANT_ALPHA = 32771;
    pub fn get_CONSTANT_ALPHA() GLenum {
        return 32771;
    }

    /// WebIDL constant: const GLenum ONE_MINUS_CONSTANT_ALPHA = 32772;
    pub fn get_ONE_MINUS_CONSTANT_ALPHA() GLenum {
        return 32772;
    }

    /// WebIDL constant: const GLenum BLEND_COLOR = 32773;
    pub fn get_BLEND_COLOR() GLenum {
        return 32773;
    }

    /// WebIDL constant: const GLenum ARRAY_BUFFER = 34962;
    pub fn get_ARRAY_BUFFER() GLenum {
        return 34962;
    }

    /// WebIDL constant: const GLenum ELEMENT_ARRAY_BUFFER = 34963;
    pub fn get_ELEMENT_ARRAY_BUFFER() GLenum {
        return 34963;
    }

    /// WebIDL constant: const GLenum ARRAY_BUFFER_BINDING = 34964;
    pub fn get_ARRAY_BUFFER_BINDING() GLenum {
        return 34964;
    }

    /// WebIDL constant: const GLenum ELEMENT_ARRAY_BUFFER_BINDING = 34965;
    pub fn get_ELEMENT_ARRAY_BUFFER_BINDING() GLenum {
        return 34965;
    }

    /// WebIDL constant: const GLenum STREAM_DRAW = 35040;
    pub fn get_STREAM_DRAW() GLenum {
        return 35040;
    }

    /// WebIDL constant: const GLenum STATIC_DRAW = 35044;
    pub fn get_STATIC_DRAW() GLenum {
        return 35044;
    }

    /// WebIDL constant: const GLenum DYNAMIC_DRAW = 35048;
    pub fn get_DYNAMIC_DRAW() GLenum {
        return 35048;
    }

    /// WebIDL constant: const GLenum BUFFER_SIZE = 34660;
    pub fn get_BUFFER_SIZE() GLenum {
        return 34660;
    }

    /// WebIDL constant: const GLenum BUFFER_USAGE = 34661;
    pub fn get_BUFFER_USAGE() GLenum {
        return 34661;
    }

    /// WebIDL constant: const GLenum CURRENT_VERTEX_ATTRIB = 34342;
    pub fn get_CURRENT_VERTEX_ATTRIB() GLenum {
        return 34342;
    }

    /// WebIDL constant: const GLenum FRONT = 1028;
    pub fn get_FRONT() GLenum {
        return 1028;
    }

    /// WebIDL constant: const GLenum BACK = 1029;
    pub fn get_BACK() GLenum {
        return 1029;
    }

    /// WebIDL constant: const GLenum FRONT_AND_BACK = 1032;
    pub fn get_FRONT_AND_BACK() GLenum {
        return 1032;
    }

    /// WebIDL constant: const GLenum CULL_FACE = 2884;
    pub fn get_CULL_FACE() GLenum {
        return 2884;
    }

    /// WebIDL constant: const GLenum BLEND = 3042;
    pub fn get_BLEND() GLenum {
        return 3042;
    }

    /// WebIDL constant: const GLenum DITHER = 3024;
    pub fn get_DITHER() GLenum {
        return 3024;
    }

    /// WebIDL constant: const GLenum STENCIL_TEST = 2960;
    pub fn get_STENCIL_TEST() GLenum {
        return 2960;
    }

    /// WebIDL constant: const GLenum DEPTH_TEST = 2929;
    pub fn get_DEPTH_TEST() GLenum {
        return 2929;
    }

    /// WebIDL constant: const GLenum SCISSOR_TEST = 3089;
    pub fn get_SCISSOR_TEST() GLenum {
        return 3089;
    }

    /// WebIDL constant: const GLenum POLYGON_OFFSET_FILL = 32823;
    pub fn get_POLYGON_OFFSET_FILL() GLenum {
        return 32823;
    }

    /// WebIDL constant: const GLenum SAMPLE_ALPHA_TO_COVERAGE = 32926;
    pub fn get_SAMPLE_ALPHA_TO_COVERAGE() GLenum {
        return 32926;
    }

    /// WebIDL constant: const GLenum SAMPLE_COVERAGE = 32928;
    pub fn get_SAMPLE_COVERAGE() GLenum {
        return 32928;
    }

    /// WebIDL constant: const GLenum NO_ERROR = 0;
    pub fn get_NO_ERROR() GLenum {
        return 0;
    }

    /// WebIDL constant: const GLenum INVALID_ENUM = 1280;
    pub fn get_INVALID_ENUM() GLenum {
        return 1280;
    }

    /// WebIDL constant: const GLenum INVALID_VALUE = 1281;
    pub fn get_INVALID_VALUE() GLenum {
        return 1281;
    }

    /// WebIDL constant: const GLenum INVALID_OPERATION = 1282;
    pub fn get_INVALID_OPERATION() GLenum {
        return 1282;
    }

    /// WebIDL constant: const GLenum OUT_OF_MEMORY = 1285;
    pub fn get_OUT_OF_MEMORY() GLenum {
        return 1285;
    }

    /// WebIDL constant: const GLenum CW = 2304;
    pub fn get_CW() GLenum {
        return 2304;
    }

    /// WebIDL constant: const GLenum CCW = 2305;
    pub fn get_CCW() GLenum {
        return 2305;
    }

    /// WebIDL constant: const GLenum LINE_WIDTH = 2849;
    pub fn get_LINE_WIDTH() GLenum {
        return 2849;
    }

    /// WebIDL constant: const GLenum ALIASED_POINT_SIZE_RANGE = 33901;
    pub fn get_ALIASED_POINT_SIZE_RANGE() GLenum {
        return 33901;
    }

    /// WebIDL constant: const GLenum ALIASED_LINE_WIDTH_RANGE = 33902;
    pub fn get_ALIASED_LINE_WIDTH_RANGE() GLenum {
        return 33902;
    }

    /// WebIDL constant: const GLenum CULL_FACE_MODE = 2885;
    pub fn get_CULL_FACE_MODE() GLenum {
        return 2885;
    }

    /// WebIDL constant: const GLenum FRONT_FACE = 2886;
    pub fn get_FRONT_FACE() GLenum {
        return 2886;
    }

    /// WebIDL constant: const GLenum DEPTH_RANGE = 2928;
    pub fn get_DEPTH_RANGE() GLenum {
        return 2928;
    }

    /// WebIDL constant: const GLenum DEPTH_WRITEMASK = 2930;
    pub fn get_DEPTH_WRITEMASK() GLenum {
        return 2930;
    }

    /// WebIDL constant: const GLenum DEPTH_CLEAR_VALUE = 2931;
    pub fn get_DEPTH_CLEAR_VALUE() GLenum {
        return 2931;
    }

    /// WebIDL constant: const GLenum DEPTH_FUNC = 2932;
    pub fn get_DEPTH_FUNC() GLenum {
        return 2932;
    }

    /// WebIDL constant: const GLenum STENCIL_CLEAR_VALUE = 2961;
    pub fn get_STENCIL_CLEAR_VALUE() GLenum {
        return 2961;
    }

    /// WebIDL constant: const GLenum STENCIL_FUNC = 2962;
    pub fn get_STENCIL_FUNC() GLenum {
        return 2962;
    }

    /// WebIDL constant: const GLenum STENCIL_FAIL = 2964;
    pub fn get_STENCIL_FAIL() GLenum {
        return 2964;
    }

    /// WebIDL constant: const GLenum STENCIL_PASS_DEPTH_FAIL = 2965;
    pub fn get_STENCIL_PASS_DEPTH_FAIL() GLenum {
        return 2965;
    }

    /// WebIDL constant: const GLenum STENCIL_PASS_DEPTH_PASS = 2966;
    pub fn get_STENCIL_PASS_DEPTH_PASS() GLenum {
        return 2966;
    }

    /// WebIDL constant: const GLenum STENCIL_REF = 2967;
    pub fn get_STENCIL_REF() GLenum {
        return 2967;
    }

    /// WebIDL constant: const GLenum STENCIL_VALUE_MASK = 2963;
    pub fn get_STENCIL_VALUE_MASK() GLenum {
        return 2963;
    }

    /// WebIDL constant: const GLenum STENCIL_WRITEMASK = 2968;
    pub fn get_STENCIL_WRITEMASK() GLenum {
        return 2968;
    }

    /// WebIDL constant: const GLenum STENCIL_BACK_FUNC = 34816;
    pub fn get_STENCIL_BACK_FUNC() GLenum {
        return 34816;
    }

    /// WebIDL constant: const GLenum STENCIL_BACK_FAIL = 34817;
    pub fn get_STENCIL_BACK_FAIL() GLenum {
        return 34817;
    }

    /// WebIDL constant: const GLenum STENCIL_BACK_PASS_DEPTH_FAIL = 34818;
    pub fn get_STENCIL_BACK_PASS_DEPTH_FAIL() GLenum {
        return 34818;
    }

    /// WebIDL constant: const GLenum STENCIL_BACK_PASS_DEPTH_PASS = 34819;
    pub fn get_STENCIL_BACK_PASS_DEPTH_PASS() GLenum {
        return 34819;
    }

    /// WebIDL constant: const GLenum STENCIL_BACK_REF = 36003;
    pub fn get_STENCIL_BACK_REF() GLenum {
        return 36003;
    }

    /// WebIDL constant: const GLenum STENCIL_BACK_VALUE_MASK = 36004;
    pub fn get_STENCIL_BACK_VALUE_MASK() GLenum {
        return 36004;
    }

    /// WebIDL constant: const GLenum STENCIL_BACK_WRITEMASK = 36005;
    pub fn get_STENCIL_BACK_WRITEMASK() GLenum {
        return 36005;
    }

    /// WebIDL constant: const GLenum VIEWPORT = 2978;
    pub fn get_VIEWPORT() GLenum {
        return 2978;
    }

    /// WebIDL constant: const GLenum SCISSOR_BOX = 3088;
    pub fn get_SCISSOR_BOX() GLenum {
        return 3088;
    }

    /// WebIDL constant: const GLenum COLOR_CLEAR_VALUE = 3106;
    pub fn get_COLOR_CLEAR_VALUE() GLenum {
        return 3106;
    }

    /// WebIDL constant: const GLenum COLOR_WRITEMASK = 3107;
    pub fn get_COLOR_WRITEMASK() GLenum {
        return 3107;
    }

    /// WebIDL constant: const GLenum UNPACK_ALIGNMENT = 3317;
    pub fn get_UNPACK_ALIGNMENT() GLenum {
        return 3317;
    }

    /// WebIDL constant: const GLenum PACK_ALIGNMENT = 3333;
    pub fn get_PACK_ALIGNMENT() GLenum {
        return 3333;
    }

    /// WebIDL constant: const GLenum MAX_TEXTURE_SIZE = 3379;
    pub fn get_MAX_TEXTURE_SIZE() GLenum {
        return 3379;
    }

    /// WebIDL constant: const GLenum MAX_VIEWPORT_DIMS = 3386;
    pub fn get_MAX_VIEWPORT_DIMS() GLenum {
        return 3386;
    }

    /// WebIDL constant: const GLenum SUBPIXEL_BITS = 3408;
    pub fn get_SUBPIXEL_BITS() GLenum {
        return 3408;
    }

    /// WebIDL constant: const GLenum RED_BITS = 3410;
    pub fn get_RED_BITS() GLenum {
        return 3410;
    }

    /// WebIDL constant: const GLenum GREEN_BITS = 3411;
    pub fn get_GREEN_BITS() GLenum {
        return 3411;
    }

    /// WebIDL constant: const GLenum BLUE_BITS = 3412;
    pub fn get_BLUE_BITS() GLenum {
        return 3412;
    }

    /// WebIDL constant: const GLenum ALPHA_BITS = 3413;
    pub fn get_ALPHA_BITS() GLenum {
        return 3413;
    }

    /// WebIDL constant: const GLenum DEPTH_BITS = 3414;
    pub fn get_DEPTH_BITS() GLenum {
        return 3414;
    }

    /// WebIDL constant: const GLenum STENCIL_BITS = 3415;
    pub fn get_STENCIL_BITS() GLenum {
        return 3415;
    }

    /// WebIDL constant: const GLenum POLYGON_OFFSET_UNITS = 10752;
    pub fn get_POLYGON_OFFSET_UNITS() GLenum {
        return 10752;
    }

    /// WebIDL constant: const GLenum POLYGON_OFFSET_FACTOR = 32824;
    pub fn get_POLYGON_OFFSET_FACTOR() GLenum {
        return 32824;
    }

    /// WebIDL constant: const GLenum TEXTURE_BINDING_2D = 32873;
    pub fn get_TEXTURE_BINDING_2D() GLenum {
        return 32873;
    }

    /// WebIDL constant: const GLenum SAMPLE_BUFFERS = 32936;
    pub fn get_SAMPLE_BUFFERS() GLenum {
        return 32936;
    }

    /// WebIDL constant: const GLenum SAMPLES = 32937;
    pub fn get_SAMPLES() GLenum {
        return 32937;
    }

    /// WebIDL constant: const GLenum SAMPLE_COVERAGE_VALUE = 32938;
    pub fn get_SAMPLE_COVERAGE_VALUE() GLenum {
        return 32938;
    }

    /// WebIDL constant: const GLenum SAMPLE_COVERAGE_INVERT = 32939;
    pub fn get_SAMPLE_COVERAGE_INVERT() GLenum {
        return 32939;
    }

    /// WebIDL constant: const GLenum COMPRESSED_TEXTURE_FORMATS = 34467;
    pub fn get_COMPRESSED_TEXTURE_FORMATS() GLenum {
        return 34467;
    }

    /// WebIDL constant: const GLenum DONT_CARE = 4352;
    pub fn get_DONT_CARE() GLenum {
        return 4352;
    }

    /// WebIDL constant: const GLenum FASTEST = 4353;
    pub fn get_FASTEST() GLenum {
        return 4353;
    }

    /// WebIDL constant: const GLenum NICEST = 4354;
    pub fn get_NICEST() GLenum {
        return 4354;
    }

    /// WebIDL constant: const GLenum GENERATE_MIPMAP_HINT = 33170;
    pub fn get_GENERATE_MIPMAP_HINT() GLenum {
        return 33170;
    }

    /// WebIDL constant: const GLenum BYTE = 5120;
    pub fn get_BYTE() GLenum {
        return 5120;
    }

    /// WebIDL constant: const GLenum UNSIGNED_BYTE = 5121;
    pub fn get_UNSIGNED_BYTE() GLenum {
        return 5121;
    }

    /// WebIDL constant: const GLenum SHORT = 5122;
    pub fn get_SHORT() GLenum {
        return 5122;
    }

    /// WebIDL constant: const GLenum UNSIGNED_SHORT = 5123;
    pub fn get_UNSIGNED_SHORT() GLenum {
        return 5123;
    }

    /// WebIDL constant: const GLenum INT = 5124;
    pub fn get_INT() GLenum {
        return 5124;
    }

    /// WebIDL constant: const GLenum UNSIGNED_INT = 5125;
    pub fn get_UNSIGNED_INT() GLenum {
        return 5125;
    }

    /// WebIDL constant: const GLenum FLOAT = 5126;
    pub fn get_FLOAT() GLenum {
        return 5126;
    }

    /// WebIDL constant: const GLenum DEPTH_COMPONENT = 6402;
    pub fn get_DEPTH_COMPONENT() GLenum {
        return 6402;
    }

    /// WebIDL constant: const GLenum ALPHA = 6406;
    pub fn get_ALPHA() GLenum {
        return 6406;
    }

    /// WebIDL constant: const GLenum RGB = 6407;
    pub fn get_RGB() GLenum {
        return 6407;
    }

    /// WebIDL constant: const GLenum RGBA = 6408;
    pub fn get_RGBA() GLenum {
        return 6408;
    }

    /// WebIDL constant: const GLenum LUMINANCE = 6409;
    pub fn get_LUMINANCE() GLenum {
        return 6409;
    }

    /// WebIDL constant: const GLenum LUMINANCE_ALPHA = 6410;
    pub fn get_LUMINANCE_ALPHA() GLenum {
        return 6410;
    }

    /// WebIDL constant: const GLenum UNSIGNED_SHORT_4_4_4_4 = 32819;
    pub fn get_UNSIGNED_SHORT_4_4_4_4() GLenum {
        return 32819;
    }

    /// WebIDL constant: const GLenum UNSIGNED_SHORT_5_5_5_1 = 32820;
    pub fn get_UNSIGNED_SHORT_5_5_5_1() GLenum {
        return 32820;
    }

    /// WebIDL constant: const GLenum UNSIGNED_SHORT_5_6_5 = 33635;
    pub fn get_UNSIGNED_SHORT_5_6_5() GLenum {
        return 33635;
    }

    /// WebIDL constant: const GLenum FRAGMENT_SHADER = 35632;
    pub fn get_FRAGMENT_SHADER() GLenum {
        return 35632;
    }

    /// WebIDL constant: const GLenum VERTEX_SHADER = 35633;
    pub fn get_VERTEX_SHADER() GLenum {
        return 35633;
    }

    /// WebIDL constant: const GLenum MAX_VERTEX_ATTRIBS = 34921;
    pub fn get_MAX_VERTEX_ATTRIBS() GLenum {
        return 34921;
    }

    /// WebIDL constant: const GLenum MAX_VERTEX_UNIFORM_VECTORS = 36347;
    pub fn get_MAX_VERTEX_UNIFORM_VECTORS() GLenum {
        return 36347;
    }

    /// WebIDL constant: const GLenum MAX_VARYING_VECTORS = 36348;
    pub fn get_MAX_VARYING_VECTORS() GLenum {
        return 36348;
    }

    /// WebIDL constant: const GLenum MAX_COMBINED_TEXTURE_IMAGE_UNITS = 35661;
    pub fn get_MAX_COMBINED_TEXTURE_IMAGE_UNITS() GLenum {
        return 35661;
    }

    /// WebIDL constant: const GLenum MAX_VERTEX_TEXTURE_IMAGE_UNITS = 35660;
    pub fn get_MAX_VERTEX_TEXTURE_IMAGE_UNITS() GLenum {
        return 35660;
    }

    /// WebIDL constant: const GLenum MAX_TEXTURE_IMAGE_UNITS = 34930;
    pub fn get_MAX_TEXTURE_IMAGE_UNITS() GLenum {
        return 34930;
    }

    /// WebIDL constant: const GLenum MAX_FRAGMENT_UNIFORM_VECTORS = 36349;
    pub fn get_MAX_FRAGMENT_UNIFORM_VECTORS() GLenum {
        return 36349;
    }

    /// WebIDL constant: const GLenum SHADER_TYPE = 35663;
    pub fn get_SHADER_TYPE() GLenum {
        return 35663;
    }

    /// WebIDL constant: const GLenum DELETE_STATUS = 35712;
    pub fn get_DELETE_STATUS() GLenum {
        return 35712;
    }

    /// WebIDL constant: const GLenum LINK_STATUS = 35714;
    pub fn get_LINK_STATUS() GLenum {
        return 35714;
    }

    /// WebIDL constant: const GLenum VALIDATE_STATUS = 35715;
    pub fn get_VALIDATE_STATUS() GLenum {
        return 35715;
    }

    /// WebIDL constant: const GLenum ATTACHED_SHADERS = 35717;
    pub fn get_ATTACHED_SHADERS() GLenum {
        return 35717;
    }

    /// WebIDL constant: const GLenum ACTIVE_UNIFORMS = 35718;
    pub fn get_ACTIVE_UNIFORMS() GLenum {
        return 35718;
    }

    /// WebIDL constant: const GLenum ACTIVE_ATTRIBUTES = 35721;
    pub fn get_ACTIVE_ATTRIBUTES() GLenum {
        return 35721;
    }

    /// WebIDL constant: const GLenum SHADING_LANGUAGE_VERSION = 35724;
    pub fn get_SHADING_LANGUAGE_VERSION() GLenum {
        return 35724;
    }

    /// WebIDL constant: const GLenum CURRENT_PROGRAM = 35725;
    pub fn get_CURRENT_PROGRAM() GLenum {
        return 35725;
    }

    /// WebIDL constant: const GLenum NEVER = 512;
    pub fn get_NEVER() GLenum {
        return 512;
    }

    /// WebIDL constant: const GLenum LESS = 513;
    pub fn get_LESS() GLenum {
        return 513;
    }

    /// WebIDL constant: const GLenum EQUAL = 514;
    pub fn get_EQUAL() GLenum {
        return 514;
    }

    /// WebIDL constant: const GLenum LEQUAL = 515;
    pub fn get_LEQUAL() GLenum {
        return 515;
    }

    /// WebIDL constant: const GLenum GREATER = 516;
    pub fn get_GREATER() GLenum {
        return 516;
    }

    /// WebIDL constant: const GLenum NOTEQUAL = 517;
    pub fn get_NOTEQUAL() GLenum {
        return 517;
    }

    /// WebIDL constant: const GLenum GEQUAL = 518;
    pub fn get_GEQUAL() GLenum {
        return 518;
    }

    /// WebIDL constant: const GLenum ALWAYS = 519;
    pub fn get_ALWAYS() GLenum {
        return 519;
    }

    /// WebIDL constant: const GLenum KEEP = 7680;
    pub fn get_KEEP() GLenum {
        return 7680;
    }

    /// WebIDL constant: const GLenum REPLACE = 7681;
    pub fn get_REPLACE() GLenum {
        return 7681;
    }

    /// WebIDL constant: const GLenum INCR = 7682;
    pub fn get_INCR() GLenum {
        return 7682;
    }

    /// WebIDL constant: const GLenum DECR = 7683;
    pub fn get_DECR() GLenum {
        return 7683;
    }

    /// WebIDL constant: const GLenum INVERT = 5386;
    pub fn get_INVERT() GLenum {
        return 5386;
    }

    /// WebIDL constant: const GLenum INCR_WRAP = 34055;
    pub fn get_INCR_WRAP() GLenum {
        return 34055;
    }

    /// WebIDL constant: const GLenum DECR_WRAP = 34056;
    pub fn get_DECR_WRAP() GLenum {
        return 34056;
    }

    /// WebIDL constant: const GLenum VENDOR = 7936;
    pub fn get_VENDOR() GLenum {
        return 7936;
    }

    /// WebIDL constant: const GLenum RENDERER = 7937;
    pub fn get_RENDERER() GLenum {
        return 7937;
    }

    /// WebIDL constant: const GLenum VERSION = 7938;
    pub fn get_VERSION() GLenum {
        return 7938;
    }

    /// WebIDL constant: const GLenum NEAREST = 9728;
    pub fn get_NEAREST() GLenum {
        return 9728;
    }

    /// WebIDL constant: const GLenum LINEAR = 9729;
    pub fn get_LINEAR() GLenum {
        return 9729;
    }

    /// WebIDL constant: const GLenum NEAREST_MIPMAP_NEAREST = 9984;
    pub fn get_NEAREST_MIPMAP_NEAREST() GLenum {
        return 9984;
    }

    /// WebIDL constant: const GLenum LINEAR_MIPMAP_NEAREST = 9985;
    pub fn get_LINEAR_MIPMAP_NEAREST() GLenum {
        return 9985;
    }

    /// WebIDL constant: const GLenum NEAREST_MIPMAP_LINEAR = 9986;
    pub fn get_NEAREST_MIPMAP_LINEAR() GLenum {
        return 9986;
    }

    /// WebIDL constant: const GLenum LINEAR_MIPMAP_LINEAR = 9987;
    pub fn get_LINEAR_MIPMAP_LINEAR() GLenum {
        return 9987;
    }

    /// WebIDL constant: const GLenum TEXTURE_MAG_FILTER = 10240;
    pub fn get_TEXTURE_MAG_FILTER() GLenum {
        return 10240;
    }

    /// WebIDL constant: const GLenum TEXTURE_MIN_FILTER = 10241;
    pub fn get_TEXTURE_MIN_FILTER() GLenum {
        return 10241;
    }

    /// WebIDL constant: const GLenum TEXTURE_WRAP_S = 10242;
    pub fn get_TEXTURE_WRAP_S() GLenum {
        return 10242;
    }

    /// WebIDL constant: const GLenum TEXTURE_WRAP_T = 10243;
    pub fn get_TEXTURE_WRAP_T() GLenum {
        return 10243;
    }

    /// WebIDL constant: const GLenum TEXTURE_2D = 3553;
    pub fn get_TEXTURE_2D() GLenum {
        return 3553;
    }

    /// WebIDL constant: const GLenum TEXTURE = 5890;
    pub fn get_TEXTURE() GLenum {
        return 5890;
    }

    /// WebIDL constant: const GLenum TEXTURE_CUBE_MAP = 34067;
    pub fn get_TEXTURE_CUBE_MAP() GLenum {
        return 34067;
    }

    /// WebIDL constant: const GLenum TEXTURE_BINDING_CUBE_MAP = 34068;
    pub fn get_TEXTURE_BINDING_CUBE_MAP() GLenum {
        return 34068;
    }

    /// WebIDL constant: const GLenum TEXTURE_CUBE_MAP_POSITIVE_X = 34069;
    pub fn get_TEXTURE_CUBE_MAP_POSITIVE_X() GLenum {
        return 34069;
    }

    /// WebIDL constant: const GLenum TEXTURE_CUBE_MAP_NEGATIVE_X = 34070;
    pub fn get_TEXTURE_CUBE_MAP_NEGATIVE_X() GLenum {
        return 34070;
    }

    /// WebIDL constant: const GLenum TEXTURE_CUBE_MAP_POSITIVE_Y = 34071;
    pub fn get_TEXTURE_CUBE_MAP_POSITIVE_Y() GLenum {
        return 34071;
    }

    /// WebIDL constant: const GLenum TEXTURE_CUBE_MAP_NEGATIVE_Y = 34072;
    pub fn get_TEXTURE_CUBE_MAP_NEGATIVE_Y() GLenum {
        return 34072;
    }

    /// WebIDL constant: const GLenum TEXTURE_CUBE_MAP_POSITIVE_Z = 34073;
    pub fn get_TEXTURE_CUBE_MAP_POSITIVE_Z() GLenum {
        return 34073;
    }

    /// WebIDL constant: const GLenum TEXTURE_CUBE_MAP_NEGATIVE_Z = 34074;
    pub fn get_TEXTURE_CUBE_MAP_NEGATIVE_Z() GLenum {
        return 34074;
    }

    /// WebIDL constant: const GLenum MAX_CUBE_MAP_TEXTURE_SIZE = 34076;
    pub fn get_MAX_CUBE_MAP_TEXTURE_SIZE() GLenum {
        return 34076;
    }

    /// WebIDL constant: const GLenum TEXTURE0 = 33984;
    pub fn get_TEXTURE0() GLenum {
        return 33984;
    }

    /// WebIDL constant: const GLenum TEXTURE1 = 33985;
    pub fn get_TEXTURE1() GLenum {
        return 33985;
    }

    /// WebIDL constant: const GLenum TEXTURE2 = 33986;
    pub fn get_TEXTURE2() GLenum {
        return 33986;
    }

    /// WebIDL constant: const GLenum TEXTURE3 = 33987;
    pub fn get_TEXTURE3() GLenum {
        return 33987;
    }

    /// WebIDL constant: const GLenum TEXTURE4 = 33988;
    pub fn get_TEXTURE4() GLenum {
        return 33988;
    }

    /// WebIDL constant: const GLenum TEXTURE5 = 33989;
    pub fn get_TEXTURE5() GLenum {
        return 33989;
    }

    /// WebIDL constant: const GLenum TEXTURE6 = 33990;
    pub fn get_TEXTURE6() GLenum {
        return 33990;
    }

    /// WebIDL constant: const GLenum TEXTURE7 = 33991;
    pub fn get_TEXTURE7() GLenum {
        return 33991;
    }

    /// WebIDL constant: const GLenum TEXTURE8 = 33992;
    pub fn get_TEXTURE8() GLenum {
        return 33992;
    }

    /// WebIDL constant: const GLenum TEXTURE9 = 33993;
    pub fn get_TEXTURE9() GLenum {
        return 33993;
    }

    /// WebIDL constant: const GLenum TEXTURE10 = 33994;
    pub fn get_TEXTURE10() GLenum {
        return 33994;
    }

    /// WebIDL constant: const GLenum TEXTURE11 = 33995;
    pub fn get_TEXTURE11() GLenum {
        return 33995;
    }

    /// WebIDL constant: const GLenum TEXTURE12 = 33996;
    pub fn get_TEXTURE12() GLenum {
        return 33996;
    }

    /// WebIDL constant: const GLenum TEXTURE13 = 33997;
    pub fn get_TEXTURE13() GLenum {
        return 33997;
    }

    /// WebIDL constant: const GLenum TEXTURE14 = 33998;
    pub fn get_TEXTURE14() GLenum {
        return 33998;
    }

    /// WebIDL constant: const GLenum TEXTURE15 = 33999;
    pub fn get_TEXTURE15() GLenum {
        return 33999;
    }

    /// WebIDL constant: const GLenum TEXTURE16 = 34000;
    pub fn get_TEXTURE16() GLenum {
        return 34000;
    }

    /// WebIDL constant: const GLenum TEXTURE17 = 34001;
    pub fn get_TEXTURE17() GLenum {
        return 34001;
    }

    /// WebIDL constant: const GLenum TEXTURE18 = 34002;
    pub fn get_TEXTURE18() GLenum {
        return 34002;
    }

    /// WebIDL constant: const GLenum TEXTURE19 = 34003;
    pub fn get_TEXTURE19() GLenum {
        return 34003;
    }

    /// WebIDL constant: const GLenum TEXTURE20 = 34004;
    pub fn get_TEXTURE20() GLenum {
        return 34004;
    }

    /// WebIDL constant: const GLenum TEXTURE21 = 34005;
    pub fn get_TEXTURE21() GLenum {
        return 34005;
    }

    /// WebIDL constant: const GLenum TEXTURE22 = 34006;
    pub fn get_TEXTURE22() GLenum {
        return 34006;
    }

    /// WebIDL constant: const GLenum TEXTURE23 = 34007;
    pub fn get_TEXTURE23() GLenum {
        return 34007;
    }

    /// WebIDL constant: const GLenum TEXTURE24 = 34008;
    pub fn get_TEXTURE24() GLenum {
        return 34008;
    }

    /// WebIDL constant: const GLenum TEXTURE25 = 34009;
    pub fn get_TEXTURE25() GLenum {
        return 34009;
    }

    /// WebIDL constant: const GLenum TEXTURE26 = 34010;
    pub fn get_TEXTURE26() GLenum {
        return 34010;
    }

    /// WebIDL constant: const GLenum TEXTURE27 = 34011;
    pub fn get_TEXTURE27() GLenum {
        return 34011;
    }

    /// WebIDL constant: const GLenum TEXTURE28 = 34012;
    pub fn get_TEXTURE28() GLenum {
        return 34012;
    }

    /// WebIDL constant: const GLenum TEXTURE29 = 34013;
    pub fn get_TEXTURE29() GLenum {
        return 34013;
    }

    /// WebIDL constant: const GLenum TEXTURE30 = 34014;
    pub fn get_TEXTURE30() GLenum {
        return 34014;
    }

    /// WebIDL constant: const GLenum TEXTURE31 = 34015;
    pub fn get_TEXTURE31() GLenum {
        return 34015;
    }

    /// WebIDL constant: const GLenum ACTIVE_TEXTURE = 34016;
    pub fn get_ACTIVE_TEXTURE() GLenum {
        return 34016;
    }

    /// WebIDL constant: const GLenum REPEAT = 10497;
    pub fn get_REPEAT() GLenum {
        return 10497;
    }

    /// WebIDL constant: const GLenum CLAMP_TO_EDGE = 33071;
    pub fn get_CLAMP_TO_EDGE() GLenum {
        return 33071;
    }

    /// WebIDL constant: const GLenum MIRRORED_REPEAT = 33648;
    pub fn get_MIRRORED_REPEAT() GLenum {
        return 33648;
    }

    /// WebIDL constant: const GLenum FLOAT_VEC2 = 35664;
    pub fn get_FLOAT_VEC2() GLenum {
        return 35664;
    }

    /// WebIDL constant: const GLenum FLOAT_VEC3 = 35665;
    pub fn get_FLOAT_VEC3() GLenum {
        return 35665;
    }

    /// WebIDL constant: const GLenum FLOAT_VEC4 = 35666;
    pub fn get_FLOAT_VEC4() GLenum {
        return 35666;
    }

    /// WebIDL constant: const GLenum INT_VEC2 = 35667;
    pub fn get_INT_VEC2() GLenum {
        return 35667;
    }

    /// WebIDL constant: const GLenum INT_VEC3 = 35668;
    pub fn get_INT_VEC3() GLenum {
        return 35668;
    }

    /// WebIDL constant: const GLenum INT_VEC4 = 35669;
    pub fn get_INT_VEC4() GLenum {
        return 35669;
    }

    /// WebIDL constant: const GLenum BOOL = 35670;
    pub fn get_BOOL() GLenum {
        return 35670;
    }

    /// WebIDL constant: const GLenum BOOL_VEC2 = 35671;
    pub fn get_BOOL_VEC2() GLenum {
        return 35671;
    }

    /// WebIDL constant: const GLenum BOOL_VEC3 = 35672;
    pub fn get_BOOL_VEC3() GLenum {
        return 35672;
    }

    /// WebIDL constant: const GLenum BOOL_VEC4 = 35673;
    pub fn get_BOOL_VEC4() GLenum {
        return 35673;
    }

    /// WebIDL constant: const GLenum FLOAT_MAT2 = 35674;
    pub fn get_FLOAT_MAT2() GLenum {
        return 35674;
    }

    /// WebIDL constant: const GLenum FLOAT_MAT3 = 35675;
    pub fn get_FLOAT_MAT3() GLenum {
        return 35675;
    }

    /// WebIDL constant: const GLenum FLOAT_MAT4 = 35676;
    pub fn get_FLOAT_MAT4() GLenum {
        return 35676;
    }

    /// WebIDL constant: const GLenum SAMPLER_2D = 35678;
    pub fn get_SAMPLER_2D() GLenum {
        return 35678;
    }

    /// WebIDL constant: const GLenum SAMPLER_CUBE = 35680;
    pub fn get_SAMPLER_CUBE() GLenum {
        return 35680;
    }

    /// WebIDL constant: const GLenum VERTEX_ATTRIB_ARRAY_ENABLED = 34338;
    pub fn get_VERTEX_ATTRIB_ARRAY_ENABLED() GLenum {
        return 34338;
    }

    /// WebIDL constant: const GLenum VERTEX_ATTRIB_ARRAY_SIZE = 34339;
    pub fn get_VERTEX_ATTRIB_ARRAY_SIZE() GLenum {
        return 34339;
    }

    /// WebIDL constant: const GLenum VERTEX_ATTRIB_ARRAY_STRIDE = 34340;
    pub fn get_VERTEX_ATTRIB_ARRAY_STRIDE() GLenum {
        return 34340;
    }

    /// WebIDL constant: const GLenum VERTEX_ATTRIB_ARRAY_TYPE = 34341;
    pub fn get_VERTEX_ATTRIB_ARRAY_TYPE() GLenum {
        return 34341;
    }

    /// WebIDL constant: const GLenum VERTEX_ATTRIB_ARRAY_NORMALIZED = 34922;
    pub fn get_VERTEX_ATTRIB_ARRAY_NORMALIZED() GLenum {
        return 34922;
    }

    /// WebIDL constant: const GLenum VERTEX_ATTRIB_ARRAY_POINTER = 34373;
    pub fn get_VERTEX_ATTRIB_ARRAY_POINTER() GLenum {
        return 34373;
    }

    /// WebIDL constant: const GLenum VERTEX_ATTRIB_ARRAY_BUFFER_BINDING = 34975;
    pub fn get_VERTEX_ATTRIB_ARRAY_BUFFER_BINDING() GLenum {
        return 34975;
    }

    /// WebIDL constant: const GLenum IMPLEMENTATION_COLOR_READ_TYPE = 35738;
    pub fn get_IMPLEMENTATION_COLOR_READ_TYPE() GLenum {
        return 35738;
    }

    /// WebIDL constant: const GLenum IMPLEMENTATION_COLOR_READ_FORMAT = 35739;
    pub fn get_IMPLEMENTATION_COLOR_READ_FORMAT() GLenum {
        return 35739;
    }

    /// WebIDL constant: const GLenum COMPILE_STATUS = 35713;
    pub fn get_COMPILE_STATUS() GLenum {
        return 35713;
    }

    /// WebIDL constant: const GLenum LOW_FLOAT = 36336;
    pub fn get_LOW_FLOAT() GLenum {
        return 36336;
    }

    /// WebIDL constant: const GLenum MEDIUM_FLOAT = 36337;
    pub fn get_MEDIUM_FLOAT() GLenum {
        return 36337;
    }

    /// WebIDL constant: const GLenum HIGH_FLOAT = 36338;
    pub fn get_HIGH_FLOAT() GLenum {
        return 36338;
    }

    /// WebIDL constant: const GLenum LOW_INT = 36339;
    pub fn get_LOW_INT() GLenum {
        return 36339;
    }

    /// WebIDL constant: const GLenum MEDIUM_INT = 36340;
    pub fn get_MEDIUM_INT() GLenum {
        return 36340;
    }

    /// WebIDL constant: const GLenum HIGH_INT = 36341;
    pub fn get_HIGH_INT() GLenum {
        return 36341;
    }

    /// WebIDL constant: const GLenum FRAMEBUFFER = 36160;
    pub fn get_FRAMEBUFFER() GLenum {
        return 36160;
    }

    /// WebIDL constant: const GLenum RENDERBUFFER = 36161;
    pub fn get_RENDERBUFFER() GLenum {
        return 36161;
    }

    /// WebIDL constant: const GLenum RGBA4 = 32854;
    pub fn get_RGBA4() GLenum {
        return 32854;
    }

    /// WebIDL constant: const GLenum RGB5_A1 = 32855;
    pub fn get_RGB5_A1() GLenum {
        return 32855;
    }

    /// WebIDL constant: const GLenum RGBA8 = 32856;
    pub fn get_RGBA8() GLenum {
        return 32856;
    }

    /// WebIDL constant: const GLenum RGB565 = 36194;
    pub fn get_RGB565() GLenum {
        return 36194;
    }

    /// WebIDL constant: const GLenum DEPTH_COMPONENT16 = 33189;
    pub fn get_DEPTH_COMPONENT16() GLenum {
        return 33189;
    }

    /// WebIDL constant: const GLenum STENCIL_INDEX8 = 36168;
    pub fn get_STENCIL_INDEX8() GLenum {
        return 36168;
    }

    /// WebIDL constant: const GLenum DEPTH_STENCIL = 34041;
    pub fn get_DEPTH_STENCIL() GLenum {
        return 34041;
    }

    /// WebIDL constant: const GLenum RENDERBUFFER_WIDTH = 36162;
    pub fn get_RENDERBUFFER_WIDTH() GLenum {
        return 36162;
    }

    /// WebIDL constant: const GLenum RENDERBUFFER_HEIGHT = 36163;
    pub fn get_RENDERBUFFER_HEIGHT() GLenum {
        return 36163;
    }

    /// WebIDL constant: const GLenum RENDERBUFFER_INTERNAL_FORMAT = 36164;
    pub fn get_RENDERBUFFER_INTERNAL_FORMAT() GLenum {
        return 36164;
    }

    /// WebIDL constant: const GLenum RENDERBUFFER_RED_SIZE = 36176;
    pub fn get_RENDERBUFFER_RED_SIZE() GLenum {
        return 36176;
    }

    /// WebIDL constant: const GLenum RENDERBUFFER_GREEN_SIZE = 36177;
    pub fn get_RENDERBUFFER_GREEN_SIZE() GLenum {
        return 36177;
    }

    /// WebIDL constant: const GLenum RENDERBUFFER_BLUE_SIZE = 36178;
    pub fn get_RENDERBUFFER_BLUE_SIZE() GLenum {
        return 36178;
    }

    /// WebIDL constant: const GLenum RENDERBUFFER_ALPHA_SIZE = 36179;
    pub fn get_RENDERBUFFER_ALPHA_SIZE() GLenum {
        return 36179;
    }

    /// WebIDL constant: const GLenum RENDERBUFFER_DEPTH_SIZE = 36180;
    pub fn get_RENDERBUFFER_DEPTH_SIZE() GLenum {
        return 36180;
    }

    /// WebIDL constant: const GLenum RENDERBUFFER_STENCIL_SIZE = 36181;
    pub fn get_RENDERBUFFER_STENCIL_SIZE() GLenum {
        return 36181;
    }

    /// WebIDL constant: const GLenum FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE = 36048;
    pub fn get_FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE() GLenum {
        return 36048;
    }

    /// WebIDL constant: const GLenum FRAMEBUFFER_ATTACHMENT_OBJECT_NAME = 36049;
    pub fn get_FRAMEBUFFER_ATTACHMENT_OBJECT_NAME() GLenum {
        return 36049;
    }

    /// WebIDL constant: const GLenum FRAMEBUFFER_ATTACHMENT_TEXTURE_LEVEL = 36050;
    pub fn get_FRAMEBUFFER_ATTACHMENT_TEXTURE_LEVEL() GLenum {
        return 36050;
    }

    /// WebIDL constant: const GLenum FRAMEBUFFER_ATTACHMENT_TEXTURE_CUBE_MAP_FACE = 36051;
    pub fn get_FRAMEBUFFER_ATTACHMENT_TEXTURE_CUBE_MAP_FACE() GLenum {
        return 36051;
    }

    /// WebIDL constant: const GLenum COLOR_ATTACHMENT0 = 36064;
    pub fn get_COLOR_ATTACHMENT0() GLenum {
        return 36064;
    }

    /// WebIDL constant: const GLenum DEPTH_ATTACHMENT = 36096;
    pub fn get_DEPTH_ATTACHMENT() GLenum {
        return 36096;
    }

    /// WebIDL constant: const GLenum STENCIL_ATTACHMENT = 36128;
    pub fn get_STENCIL_ATTACHMENT() GLenum {
        return 36128;
    }

    /// WebIDL constant: const GLenum DEPTH_STENCIL_ATTACHMENT = 33306;
    pub fn get_DEPTH_STENCIL_ATTACHMENT() GLenum {
        return 33306;
    }

    /// WebIDL constant: const GLenum NONE = 0;
    pub fn get_NONE() GLenum {
        return 0;
    }

    /// WebIDL constant: const GLenum FRAMEBUFFER_COMPLETE = 36053;
    pub fn get_FRAMEBUFFER_COMPLETE() GLenum {
        return 36053;
    }

    /// WebIDL constant: const GLenum FRAMEBUFFER_INCOMPLETE_ATTACHMENT = 36054;
    pub fn get_FRAMEBUFFER_INCOMPLETE_ATTACHMENT() GLenum {
        return 36054;
    }

    /// WebIDL constant: const GLenum FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT = 36055;
    pub fn get_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT() GLenum {
        return 36055;
    }

    /// WebIDL constant: const GLenum FRAMEBUFFER_INCOMPLETE_DIMENSIONS = 36057;
    pub fn get_FRAMEBUFFER_INCOMPLETE_DIMENSIONS() GLenum {
        return 36057;
    }

    /// WebIDL constant: const GLenum FRAMEBUFFER_UNSUPPORTED = 36061;
    pub fn get_FRAMEBUFFER_UNSUPPORTED() GLenum {
        return 36061;
    }

    /// WebIDL constant: const GLenum FRAMEBUFFER_BINDING = 36006;
    pub fn get_FRAMEBUFFER_BINDING() GLenum {
        return 36006;
    }

    /// WebIDL constant: const GLenum RENDERBUFFER_BINDING = 36007;
    pub fn get_RENDERBUFFER_BINDING() GLenum {
        return 36007;
    }

    /// WebIDL constant: const GLenum MAX_RENDERBUFFER_SIZE = 34024;
    pub fn get_MAX_RENDERBUFFER_SIZE() GLenum {
        return 34024;
    }

    /// WebIDL constant: const GLenum INVALID_FRAMEBUFFER_OPERATION = 1286;
    pub fn get_INVALID_FRAMEBUFFER_OPERATION() GLenum {
        return 1286;
    }

    /// WebIDL constant: const GLenum UNPACK_FLIP_Y_WEBGL = 37440;
    pub fn get_UNPACK_FLIP_Y_WEBGL() GLenum {
        return 37440;
    }

    /// WebIDL constant: const GLenum UNPACK_PREMULTIPLY_ALPHA_WEBGL = 37441;
    pub fn get_UNPACK_PREMULTIPLY_ALPHA_WEBGL() GLenum {
        return 37441;
    }

    /// WebIDL constant: const GLenum CONTEXT_LOST_WEBGL = 37442;
    pub fn get_CONTEXT_LOST_WEBGL() GLenum {
        return 37442;
    }

    /// WebIDL constant: const GLenum UNPACK_COLORSPACE_CONVERSION_WEBGL = 37443;
    pub fn get_UNPACK_COLORSPACE_CONVERSION_WEBGL() GLenum {
        return 37443;
    }

    /// WebIDL constant: const GLenum BROWSER_DEFAULT_WEBGL = 37444;
    pub fn get_BROWSER_DEFAULT_WEBGL() GLenum {
        return 37444;
    }

    pub const vtable = runtime.buildVTable(WebGLRenderingContextBase, .{
        .deinit_fn = &deinit_wrapper,

        .get_ACTIVE_ATTRIBUTES = &get_ACTIVE_ATTRIBUTES,
        .get_ACTIVE_TEXTURE = &get_ACTIVE_TEXTURE,
        .get_ACTIVE_UNIFORMS = &get_ACTIVE_UNIFORMS,
        .get_ALIASED_LINE_WIDTH_RANGE = &get_ALIASED_LINE_WIDTH_RANGE,
        .get_ALIASED_POINT_SIZE_RANGE = &get_ALIASED_POINT_SIZE_RANGE,
        .get_ALPHA = &get_ALPHA,
        .get_ALPHA_BITS = &get_ALPHA_BITS,
        .get_ALWAYS = &get_ALWAYS,
        .get_ARRAY_BUFFER = &get_ARRAY_BUFFER,
        .get_ARRAY_BUFFER_BINDING = &get_ARRAY_BUFFER_BINDING,
        .get_ATTACHED_SHADERS = &get_ATTACHED_SHADERS,
        .get_BACK = &get_BACK,
        .get_BLEND = &get_BLEND,
        .get_BLEND_COLOR = &get_BLEND_COLOR,
        .get_BLEND_DST_ALPHA = &get_BLEND_DST_ALPHA,
        .get_BLEND_DST_RGB = &get_BLEND_DST_RGB,
        .get_BLEND_EQUATION = &get_BLEND_EQUATION,
        .get_BLEND_EQUATION_ALPHA = &get_BLEND_EQUATION_ALPHA,
        .get_BLEND_EQUATION_RGB = &get_BLEND_EQUATION_RGB,
        .get_BLEND_SRC_ALPHA = &get_BLEND_SRC_ALPHA,
        .get_BLEND_SRC_RGB = &get_BLEND_SRC_RGB,
        .get_BLUE_BITS = &get_BLUE_BITS,
        .get_BOOL = &get_BOOL,
        .get_BOOL_VEC2 = &get_BOOL_VEC2,
        .get_BOOL_VEC3 = &get_BOOL_VEC3,
        .get_BOOL_VEC4 = &get_BOOL_VEC4,
        .get_BROWSER_DEFAULT_WEBGL = &get_BROWSER_DEFAULT_WEBGL,
        .get_BUFFER_SIZE = &get_BUFFER_SIZE,
        .get_BUFFER_USAGE = &get_BUFFER_USAGE,
        .get_BYTE = &get_BYTE,
        .get_CCW = &get_CCW,
        .get_CLAMP_TO_EDGE = &get_CLAMP_TO_EDGE,
        .get_COLOR_ATTACHMENT0 = &get_COLOR_ATTACHMENT0,
        .get_COLOR_BUFFER_BIT = &get_COLOR_BUFFER_BIT,
        .get_COLOR_CLEAR_VALUE = &get_COLOR_CLEAR_VALUE,
        .get_COLOR_WRITEMASK = &get_COLOR_WRITEMASK,
        .get_COMPILE_STATUS = &get_COMPILE_STATUS,
        .get_COMPRESSED_TEXTURE_FORMATS = &get_COMPRESSED_TEXTURE_FORMATS,
        .get_CONSTANT_ALPHA = &get_CONSTANT_ALPHA,
        .get_CONSTANT_COLOR = &get_CONSTANT_COLOR,
        .get_CONTEXT_LOST_WEBGL = &get_CONTEXT_LOST_WEBGL,
        .get_CULL_FACE = &get_CULL_FACE,
        .get_CULL_FACE_MODE = &get_CULL_FACE_MODE,
        .get_CURRENT_PROGRAM = &get_CURRENT_PROGRAM,
        .get_CURRENT_VERTEX_ATTRIB = &get_CURRENT_VERTEX_ATTRIB,
        .get_CW = &get_CW,
        .get_DECR = &get_DECR,
        .get_DECR_WRAP = &get_DECR_WRAP,
        .get_DELETE_STATUS = &get_DELETE_STATUS,
        .get_DEPTH_ATTACHMENT = &get_DEPTH_ATTACHMENT,
        .get_DEPTH_BITS = &get_DEPTH_BITS,
        .get_DEPTH_BUFFER_BIT = &get_DEPTH_BUFFER_BIT,
        .get_DEPTH_CLEAR_VALUE = &get_DEPTH_CLEAR_VALUE,
        .get_DEPTH_COMPONENT = &get_DEPTH_COMPONENT,
        .get_DEPTH_COMPONENT16 = &get_DEPTH_COMPONENT16,
        .get_DEPTH_FUNC = &get_DEPTH_FUNC,
        .get_DEPTH_RANGE = &get_DEPTH_RANGE,
        .get_DEPTH_STENCIL = &get_DEPTH_STENCIL,
        .get_DEPTH_STENCIL_ATTACHMENT = &get_DEPTH_STENCIL_ATTACHMENT,
        .get_DEPTH_TEST = &get_DEPTH_TEST,
        .get_DEPTH_WRITEMASK = &get_DEPTH_WRITEMASK,
        .get_DITHER = &get_DITHER,
        .get_DONT_CARE = &get_DONT_CARE,
        .get_DST_ALPHA = &get_DST_ALPHA,
        .get_DST_COLOR = &get_DST_COLOR,
        .get_DYNAMIC_DRAW = &get_DYNAMIC_DRAW,
        .get_ELEMENT_ARRAY_BUFFER = &get_ELEMENT_ARRAY_BUFFER,
        .get_ELEMENT_ARRAY_BUFFER_BINDING = &get_ELEMENT_ARRAY_BUFFER_BINDING,
        .get_EQUAL = &get_EQUAL,
        .get_FASTEST = &get_FASTEST,
        .get_FLOAT = &get_FLOAT,
        .get_FLOAT_MAT2 = &get_FLOAT_MAT2,
        .get_FLOAT_MAT3 = &get_FLOAT_MAT3,
        .get_FLOAT_MAT4 = &get_FLOAT_MAT4,
        .get_FLOAT_VEC2 = &get_FLOAT_VEC2,
        .get_FLOAT_VEC3 = &get_FLOAT_VEC3,
        .get_FLOAT_VEC4 = &get_FLOAT_VEC4,
        .get_FRAGMENT_SHADER = &get_FRAGMENT_SHADER,
        .get_FRAMEBUFFER = &get_FRAMEBUFFER,
        .get_FRAMEBUFFER_ATTACHMENT_OBJECT_NAME = &get_FRAMEBUFFER_ATTACHMENT_OBJECT_NAME,
        .get_FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE = &get_FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE,
        .get_FRAMEBUFFER_ATTACHMENT_TEXTURE_CUBE_MAP_FACE = &get_FRAMEBUFFER_ATTACHMENT_TEXTURE_CUBE_MAP_FACE,
        .get_FRAMEBUFFER_ATTACHMENT_TEXTURE_LEVEL = &get_FRAMEBUFFER_ATTACHMENT_TEXTURE_LEVEL,
        .get_FRAMEBUFFER_BINDING = &get_FRAMEBUFFER_BINDING,
        .get_FRAMEBUFFER_COMPLETE = &get_FRAMEBUFFER_COMPLETE,
        .get_FRAMEBUFFER_INCOMPLETE_ATTACHMENT = &get_FRAMEBUFFER_INCOMPLETE_ATTACHMENT,
        .get_FRAMEBUFFER_INCOMPLETE_DIMENSIONS = &get_FRAMEBUFFER_INCOMPLETE_DIMENSIONS,
        .get_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT = &get_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT,
        .get_FRAMEBUFFER_UNSUPPORTED = &get_FRAMEBUFFER_UNSUPPORTED,
        .get_FRONT = &get_FRONT,
        .get_FRONT_AND_BACK = &get_FRONT_AND_BACK,
        .get_FRONT_FACE = &get_FRONT_FACE,
        .get_FUNC_ADD = &get_FUNC_ADD,
        .get_FUNC_REVERSE_SUBTRACT = &get_FUNC_REVERSE_SUBTRACT,
        .get_FUNC_SUBTRACT = &get_FUNC_SUBTRACT,
        .get_GENERATE_MIPMAP_HINT = &get_GENERATE_MIPMAP_HINT,
        .get_GEQUAL = &get_GEQUAL,
        .get_GREATER = &get_GREATER,
        .get_GREEN_BITS = &get_GREEN_BITS,
        .get_HIGH_FLOAT = &get_HIGH_FLOAT,
        .get_HIGH_INT = &get_HIGH_INT,
        .get_IMPLEMENTATION_COLOR_READ_FORMAT = &get_IMPLEMENTATION_COLOR_READ_FORMAT,
        .get_IMPLEMENTATION_COLOR_READ_TYPE = &get_IMPLEMENTATION_COLOR_READ_TYPE,
        .get_INCR = &get_INCR,
        .get_INCR_WRAP = &get_INCR_WRAP,
        .get_INT = &get_INT,
        .get_INT_VEC2 = &get_INT_VEC2,
        .get_INT_VEC3 = &get_INT_VEC3,
        .get_INT_VEC4 = &get_INT_VEC4,
        .get_INVALID_ENUM = &get_INVALID_ENUM,
        .get_INVALID_FRAMEBUFFER_OPERATION = &get_INVALID_FRAMEBUFFER_OPERATION,
        .get_INVALID_OPERATION = &get_INVALID_OPERATION,
        .get_INVALID_VALUE = &get_INVALID_VALUE,
        .get_INVERT = &get_INVERT,
        .get_KEEP = &get_KEEP,
        .get_LEQUAL = &get_LEQUAL,
        .get_LESS = &get_LESS,
        .get_LINEAR = &get_LINEAR,
        .get_LINEAR_MIPMAP_LINEAR = &get_LINEAR_MIPMAP_LINEAR,
        .get_LINEAR_MIPMAP_NEAREST = &get_LINEAR_MIPMAP_NEAREST,
        .get_LINES = &get_LINES,
        .get_LINE_LOOP = &get_LINE_LOOP,
        .get_LINE_STRIP = &get_LINE_STRIP,
        .get_LINE_WIDTH = &get_LINE_WIDTH,
        .get_LINK_STATUS = &get_LINK_STATUS,
        .get_LOW_FLOAT = &get_LOW_FLOAT,
        .get_LOW_INT = &get_LOW_INT,
        .get_LUMINANCE = &get_LUMINANCE,
        .get_LUMINANCE_ALPHA = &get_LUMINANCE_ALPHA,
        .get_MAX_COMBINED_TEXTURE_IMAGE_UNITS = &get_MAX_COMBINED_TEXTURE_IMAGE_UNITS,
        .get_MAX_CUBE_MAP_TEXTURE_SIZE = &get_MAX_CUBE_MAP_TEXTURE_SIZE,
        .get_MAX_FRAGMENT_UNIFORM_VECTORS = &get_MAX_FRAGMENT_UNIFORM_VECTORS,
        .get_MAX_RENDERBUFFER_SIZE = &get_MAX_RENDERBUFFER_SIZE,
        .get_MAX_TEXTURE_IMAGE_UNITS = &get_MAX_TEXTURE_IMAGE_UNITS,
        .get_MAX_TEXTURE_SIZE = &get_MAX_TEXTURE_SIZE,
        .get_MAX_VARYING_VECTORS = &get_MAX_VARYING_VECTORS,
        .get_MAX_VERTEX_ATTRIBS = &get_MAX_VERTEX_ATTRIBS,
        .get_MAX_VERTEX_TEXTURE_IMAGE_UNITS = &get_MAX_VERTEX_TEXTURE_IMAGE_UNITS,
        .get_MAX_VERTEX_UNIFORM_VECTORS = &get_MAX_VERTEX_UNIFORM_VECTORS,
        .get_MAX_VIEWPORT_DIMS = &get_MAX_VIEWPORT_DIMS,
        .get_MEDIUM_FLOAT = &get_MEDIUM_FLOAT,
        .get_MEDIUM_INT = &get_MEDIUM_INT,
        .get_MIRRORED_REPEAT = &get_MIRRORED_REPEAT,
        .get_NEAREST = &get_NEAREST,
        .get_NEAREST_MIPMAP_LINEAR = &get_NEAREST_MIPMAP_LINEAR,
        .get_NEAREST_MIPMAP_NEAREST = &get_NEAREST_MIPMAP_NEAREST,
        .get_NEVER = &get_NEVER,
        .get_NICEST = &get_NICEST,
        .get_NONE = &get_NONE,
        .get_NOTEQUAL = &get_NOTEQUAL,
        .get_NO_ERROR = &get_NO_ERROR,
        .get_ONE = &get_ONE,
        .get_ONE_MINUS_CONSTANT_ALPHA = &get_ONE_MINUS_CONSTANT_ALPHA,
        .get_ONE_MINUS_CONSTANT_COLOR = &get_ONE_MINUS_CONSTANT_COLOR,
        .get_ONE_MINUS_DST_ALPHA = &get_ONE_MINUS_DST_ALPHA,
        .get_ONE_MINUS_DST_COLOR = &get_ONE_MINUS_DST_COLOR,
        .get_ONE_MINUS_SRC_ALPHA = &get_ONE_MINUS_SRC_ALPHA,
        .get_ONE_MINUS_SRC_COLOR = &get_ONE_MINUS_SRC_COLOR,
        .get_OUT_OF_MEMORY = &get_OUT_OF_MEMORY,
        .get_PACK_ALIGNMENT = &get_PACK_ALIGNMENT,
        .get_POINTS = &get_POINTS,
        .get_POLYGON_OFFSET_FACTOR = &get_POLYGON_OFFSET_FACTOR,
        .get_POLYGON_OFFSET_FILL = &get_POLYGON_OFFSET_FILL,
        .get_POLYGON_OFFSET_UNITS = &get_POLYGON_OFFSET_UNITS,
        .get_RED_BITS = &get_RED_BITS,
        .get_RENDERBUFFER = &get_RENDERBUFFER,
        .get_RENDERBUFFER_ALPHA_SIZE = &get_RENDERBUFFER_ALPHA_SIZE,
        .get_RENDERBUFFER_BINDING = &get_RENDERBUFFER_BINDING,
        .get_RENDERBUFFER_BLUE_SIZE = &get_RENDERBUFFER_BLUE_SIZE,
        .get_RENDERBUFFER_DEPTH_SIZE = &get_RENDERBUFFER_DEPTH_SIZE,
        .get_RENDERBUFFER_GREEN_SIZE = &get_RENDERBUFFER_GREEN_SIZE,
        .get_RENDERBUFFER_HEIGHT = &get_RENDERBUFFER_HEIGHT,
        .get_RENDERBUFFER_INTERNAL_FORMAT = &get_RENDERBUFFER_INTERNAL_FORMAT,
        .get_RENDERBUFFER_RED_SIZE = &get_RENDERBUFFER_RED_SIZE,
        .get_RENDERBUFFER_STENCIL_SIZE = &get_RENDERBUFFER_STENCIL_SIZE,
        .get_RENDERBUFFER_WIDTH = &get_RENDERBUFFER_WIDTH,
        .get_RENDERER = &get_RENDERER,
        .get_REPEAT = &get_REPEAT,
        .get_REPLACE = &get_REPLACE,
        .get_RGB = &get_RGB,
        .get_RGB565 = &get_RGB565,
        .get_RGB5_A1 = &get_RGB5_A1,
        .get_RGBA = &get_RGBA,
        .get_RGBA4 = &get_RGBA4,
        .get_RGBA8 = &get_RGBA8,
        .get_SAMPLER_2D = &get_SAMPLER_2D,
        .get_SAMPLER_CUBE = &get_SAMPLER_CUBE,
        .get_SAMPLES = &get_SAMPLES,
        .get_SAMPLE_ALPHA_TO_COVERAGE = &get_SAMPLE_ALPHA_TO_COVERAGE,
        .get_SAMPLE_BUFFERS = &get_SAMPLE_BUFFERS,
        .get_SAMPLE_COVERAGE = &get_SAMPLE_COVERAGE,
        .get_SAMPLE_COVERAGE_INVERT = &get_SAMPLE_COVERAGE_INVERT,
        .get_SAMPLE_COVERAGE_VALUE = &get_SAMPLE_COVERAGE_VALUE,
        .get_SCISSOR_BOX = &get_SCISSOR_BOX,
        .get_SCISSOR_TEST = &get_SCISSOR_TEST,
        .get_SHADER_TYPE = &get_SHADER_TYPE,
        .get_SHADING_LANGUAGE_VERSION = &get_SHADING_LANGUAGE_VERSION,
        .get_SHORT = &get_SHORT,
        .get_SRC_ALPHA = &get_SRC_ALPHA,
        .get_SRC_ALPHA_SATURATE = &get_SRC_ALPHA_SATURATE,
        .get_SRC_COLOR = &get_SRC_COLOR,
        .get_STATIC_DRAW = &get_STATIC_DRAW,
        .get_STENCIL_ATTACHMENT = &get_STENCIL_ATTACHMENT,
        .get_STENCIL_BACK_FAIL = &get_STENCIL_BACK_FAIL,
        .get_STENCIL_BACK_FUNC = &get_STENCIL_BACK_FUNC,
        .get_STENCIL_BACK_PASS_DEPTH_FAIL = &get_STENCIL_BACK_PASS_DEPTH_FAIL,
        .get_STENCIL_BACK_PASS_DEPTH_PASS = &get_STENCIL_BACK_PASS_DEPTH_PASS,
        .get_STENCIL_BACK_REF = &get_STENCIL_BACK_REF,
        .get_STENCIL_BACK_VALUE_MASK = &get_STENCIL_BACK_VALUE_MASK,
        .get_STENCIL_BACK_WRITEMASK = &get_STENCIL_BACK_WRITEMASK,
        .get_STENCIL_BITS = &get_STENCIL_BITS,
        .get_STENCIL_BUFFER_BIT = &get_STENCIL_BUFFER_BIT,
        .get_STENCIL_CLEAR_VALUE = &get_STENCIL_CLEAR_VALUE,
        .get_STENCIL_FAIL = &get_STENCIL_FAIL,
        .get_STENCIL_FUNC = &get_STENCIL_FUNC,
        .get_STENCIL_INDEX8 = &get_STENCIL_INDEX8,
        .get_STENCIL_PASS_DEPTH_FAIL = &get_STENCIL_PASS_DEPTH_FAIL,
        .get_STENCIL_PASS_DEPTH_PASS = &get_STENCIL_PASS_DEPTH_PASS,
        .get_STENCIL_REF = &get_STENCIL_REF,
        .get_STENCIL_TEST = &get_STENCIL_TEST,
        .get_STENCIL_VALUE_MASK = &get_STENCIL_VALUE_MASK,
        .get_STENCIL_WRITEMASK = &get_STENCIL_WRITEMASK,
        .get_STREAM_DRAW = &get_STREAM_DRAW,
        .get_SUBPIXEL_BITS = &get_SUBPIXEL_BITS,
        .get_TEXTURE = &get_TEXTURE,
        .get_TEXTURE0 = &get_TEXTURE0,
        .get_TEXTURE1 = &get_TEXTURE1,
        .get_TEXTURE10 = &get_TEXTURE10,
        .get_TEXTURE11 = &get_TEXTURE11,
        .get_TEXTURE12 = &get_TEXTURE12,
        .get_TEXTURE13 = &get_TEXTURE13,
        .get_TEXTURE14 = &get_TEXTURE14,
        .get_TEXTURE15 = &get_TEXTURE15,
        .get_TEXTURE16 = &get_TEXTURE16,
        .get_TEXTURE17 = &get_TEXTURE17,
        .get_TEXTURE18 = &get_TEXTURE18,
        .get_TEXTURE19 = &get_TEXTURE19,
        .get_TEXTURE2 = &get_TEXTURE2,
        .get_TEXTURE20 = &get_TEXTURE20,
        .get_TEXTURE21 = &get_TEXTURE21,
        .get_TEXTURE22 = &get_TEXTURE22,
        .get_TEXTURE23 = &get_TEXTURE23,
        .get_TEXTURE24 = &get_TEXTURE24,
        .get_TEXTURE25 = &get_TEXTURE25,
        .get_TEXTURE26 = &get_TEXTURE26,
        .get_TEXTURE27 = &get_TEXTURE27,
        .get_TEXTURE28 = &get_TEXTURE28,
        .get_TEXTURE29 = &get_TEXTURE29,
        .get_TEXTURE3 = &get_TEXTURE3,
        .get_TEXTURE30 = &get_TEXTURE30,
        .get_TEXTURE31 = &get_TEXTURE31,
        .get_TEXTURE4 = &get_TEXTURE4,
        .get_TEXTURE5 = &get_TEXTURE5,
        .get_TEXTURE6 = &get_TEXTURE6,
        .get_TEXTURE7 = &get_TEXTURE7,
        .get_TEXTURE8 = &get_TEXTURE8,
        .get_TEXTURE9 = &get_TEXTURE9,
        .get_TEXTURE_2D = &get_TEXTURE_2D,
        .get_TEXTURE_BINDING_2D = &get_TEXTURE_BINDING_2D,
        .get_TEXTURE_BINDING_CUBE_MAP = &get_TEXTURE_BINDING_CUBE_MAP,
        .get_TEXTURE_CUBE_MAP = &get_TEXTURE_CUBE_MAP,
        .get_TEXTURE_CUBE_MAP_NEGATIVE_X = &get_TEXTURE_CUBE_MAP_NEGATIVE_X,
        .get_TEXTURE_CUBE_MAP_NEGATIVE_Y = &get_TEXTURE_CUBE_MAP_NEGATIVE_Y,
        .get_TEXTURE_CUBE_MAP_NEGATIVE_Z = &get_TEXTURE_CUBE_MAP_NEGATIVE_Z,
        .get_TEXTURE_CUBE_MAP_POSITIVE_X = &get_TEXTURE_CUBE_MAP_POSITIVE_X,
        .get_TEXTURE_CUBE_MAP_POSITIVE_Y = &get_TEXTURE_CUBE_MAP_POSITIVE_Y,
        .get_TEXTURE_CUBE_MAP_POSITIVE_Z = &get_TEXTURE_CUBE_MAP_POSITIVE_Z,
        .get_TEXTURE_MAG_FILTER = &get_TEXTURE_MAG_FILTER,
        .get_TEXTURE_MIN_FILTER = &get_TEXTURE_MIN_FILTER,
        .get_TEXTURE_WRAP_S = &get_TEXTURE_WRAP_S,
        .get_TEXTURE_WRAP_T = &get_TEXTURE_WRAP_T,
        .get_TRIANGLES = &get_TRIANGLES,
        .get_TRIANGLE_FAN = &get_TRIANGLE_FAN,
        .get_TRIANGLE_STRIP = &get_TRIANGLE_STRIP,
        .get_UNPACK_ALIGNMENT = &get_UNPACK_ALIGNMENT,
        .get_UNPACK_COLORSPACE_CONVERSION_WEBGL = &get_UNPACK_COLORSPACE_CONVERSION_WEBGL,
        .get_UNPACK_FLIP_Y_WEBGL = &get_UNPACK_FLIP_Y_WEBGL,
        .get_UNPACK_PREMULTIPLY_ALPHA_WEBGL = &get_UNPACK_PREMULTIPLY_ALPHA_WEBGL,
        .get_UNSIGNED_BYTE = &get_UNSIGNED_BYTE,
        .get_UNSIGNED_INT = &get_UNSIGNED_INT,
        .get_UNSIGNED_SHORT = &get_UNSIGNED_SHORT,
        .get_UNSIGNED_SHORT_4_4_4_4 = &get_UNSIGNED_SHORT_4_4_4_4,
        .get_UNSIGNED_SHORT_5_5_5_1 = &get_UNSIGNED_SHORT_5_5_5_1,
        .get_UNSIGNED_SHORT_5_6_5 = &get_UNSIGNED_SHORT_5_6_5,
        .get_VALIDATE_STATUS = &get_VALIDATE_STATUS,
        .get_VENDOR = &get_VENDOR,
        .get_VERSION = &get_VERSION,
        .get_VERTEX_ATTRIB_ARRAY_BUFFER_BINDING = &get_VERTEX_ATTRIB_ARRAY_BUFFER_BINDING,
        .get_VERTEX_ATTRIB_ARRAY_ENABLED = &get_VERTEX_ATTRIB_ARRAY_ENABLED,
        .get_VERTEX_ATTRIB_ARRAY_NORMALIZED = &get_VERTEX_ATTRIB_ARRAY_NORMALIZED,
        .get_VERTEX_ATTRIB_ARRAY_POINTER = &get_VERTEX_ATTRIB_ARRAY_POINTER,
        .get_VERTEX_ATTRIB_ARRAY_SIZE = &get_VERTEX_ATTRIB_ARRAY_SIZE,
        .get_VERTEX_ATTRIB_ARRAY_STRIDE = &get_VERTEX_ATTRIB_ARRAY_STRIDE,
        .get_VERTEX_ATTRIB_ARRAY_TYPE = &get_VERTEX_ATTRIB_ARRAY_TYPE,
        .get_VERTEX_SHADER = &get_VERTEX_SHADER,
        .get_VIEWPORT = &get_VIEWPORT,
        .get_ZERO = &get_ZERO,
        .get_canvas = &get_canvas,
        .get_drawingBufferColorSpace = &get_drawingBufferColorSpace,
        .get_drawingBufferFormat = &get_drawingBufferFormat,
        .get_drawingBufferHeight = &get_drawingBufferHeight,
        .get_drawingBufferWidth = &get_drawingBufferWidth,
        .get_unpackColorSpace = &get_unpackColorSpace,

        .set_drawingBufferColorSpace = &set_drawingBufferColorSpace,
        .set_unpackColorSpace = &set_unpackColorSpace,

        .call_activeTexture = &call_activeTexture,
        .call_attachShader = &call_attachShader,
        .call_bindAttribLocation = &call_bindAttribLocation,
        .call_bindBuffer = &call_bindBuffer,
        .call_bindFramebuffer = &call_bindFramebuffer,
        .call_bindRenderbuffer = &call_bindRenderbuffer,
        .call_bindTexture = &call_bindTexture,
        .call_blendColor = &call_blendColor,
        .call_blendEquation = &call_blendEquation,
        .call_blendEquationSeparate = &call_blendEquationSeparate,
        .call_blendFunc = &call_blendFunc,
        .call_blendFuncSeparate = &call_blendFuncSeparate,
        .call_checkFramebufferStatus = &call_checkFramebufferStatus,
        .call_clear = &call_clear,
        .call_clearColor = &call_clearColor,
        .call_clearDepth = &call_clearDepth,
        .call_clearStencil = &call_clearStencil,
        .call_colorMask = &call_colorMask,
        .call_compileShader = &call_compileShader,
        .call_copyTexImage2D = &call_copyTexImage2D,
        .call_copyTexSubImage2D = &call_copyTexSubImage2D,
        .call_createBuffer = &call_createBuffer,
        .call_createFramebuffer = &call_createFramebuffer,
        .call_createProgram = &call_createProgram,
        .call_createRenderbuffer = &call_createRenderbuffer,
        .call_createShader = &call_createShader,
        .call_createTexture = &call_createTexture,
        .call_cullFace = &call_cullFace,
        .call_deleteBuffer = &call_deleteBuffer,
        .call_deleteFramebuffer = &call_deleteFramebuffer,
        .call_deleteProgram = &call_deleteProgram,
        .call_deleteRenderbuffer = &call_deleteRenderbuffer,
        .call_deleteShader = &call_deleteShader,
        .call_deleteTexture = &call_deleteTexture,
        .call_depthFunc = &call_depthFunc,
        .call_depthMask = &call_depthMask,
        .call_depthRange = &call_depthRange,
        .call_detachShader = &call_detachShader,
        .call_disable = &call_disable,
        .call_disableVertexAttribArray = &call_disableVertexAttribArray,
        .call_drawArrays = &call_drawArrays,
        .call_drawElements = &call_drawElements,
        .call_drawingBufferStorage = &call_drawingBufferStorage,
        .call_enable = &call_enable,
        .call_enableVertexAttribArray = &call_enableVertexAttribArray,
        .call_finish = &call_finish,
        .call_flush = &call_flush,
        .call_framebufferRenderbuffer = &call_framebufferRenderbuffer,
        .call_framebufferTexture2D = &call_framebufferTexture2D,
        .call_frontFace = &call_frontFace,
        .call_generateMipmap = &call_generateMipmap,
        .call_getActiveAttrib = &call_getActiveAttrib,
        .call_getActiveUniform = &call_getActiveUniform,
        .call_getAttachedShaders = &call_getAttachedShaders,
        .call_getAttribLocation = &call_getAttribLocation,
        .call_getBufferParameter = &call_getBufferParameter,
        .call_getContextAttributes = &call_getContextAttributes,
        .call_getError = &call_getError,
        .call_getExtension = &call_getExtension,
        .call_getFramebufferAttachmentParameter = &call_getFramebufferAttachmentParameter,
        .call_getParameter = &call_getParameter,
        .call_getProgramInfoLog = &call_getProgramInfoLog,
        .call_getProgramParameter = &call_getProgramParameter,
        .call_getRenderbufferParameter = &call_getRenderbufferParameter,
        .call_getShaderInfoLog = &call_getShaderInfoLog,
        .call_getShaderParameter = &call_getShaderParameter,
        .call_getShaderPrecisionFormat = &call_getShaderPrecisionFormat,
        .call_getShaderSource = &call_getShaderSource,
        .call_getSupportedExtensions = &call_getSupportedExtensions,
        .call_getTexParameter = &call_getTexParameter,
        .call_getUniform = &call_getUniform,
        .call_getUniformLocation = &call_getUniformLocation,
        .call_getVertexAttrib = &call_getVertexAttrib,
        .call_getVertexAttribOffset = &call_getVertexAttribOffset,
        .call_hint = &call_hint,
        .call_isBuffer = &call_isBuffer,
        .call_isContextLost = &call_isContextLost,
        .call_isEnabled = &call_isEnabled,
        .call_isFramebuffer = &call_isFramebuffer,
        .call_isProgram = &call_isProgram,
        .call_isRenderbuffer = &call_isRenderbuffer,
        .call_isShader = &call_isShader,
        .call_isTexture = &call_isTexture,
        .call_lineWidth = &call_lineWidth,
        .call_linkProgram = &call_linkProgram,
        .call_makeXRCompatible = &call_makeXRCompatible,
        .call_pixelStorei = &call_pixelStorei,
        .call_polygonOffset = &call_polygonOffset,
        .call_renderbufferStorage = &call_renderbufferStorage,
        .call_sampleCoverage = &call_sampleCoverage,
        .call_scissor = &call_scissor,
        .call_shaderSource = &call_shaderSource,
        .call_stencilFunc = &call_stencilFunc,
        .call_stencilFuncSeparate = &call_stencilFuncSeparate,
        .call_stencilMask = &call_stencilMask,
        .call_stencilMaskSeparate = &call_stencilMaskSeparate,
        .call_stencilOp = &call_stencilOp,
        .call_stencilOpSeparate = &call_stencilOpSeparate,
        .call_texParameterf = &call_texParameterf,
        .call_texParameteri = &call_texParameteri,
        .call_uniform1f = &call_uniform1f,
        .call_uniform1i = &call_uniform1i,
        .call_uniform2f = &call_uniform2f,
        .call_uniform2i = &call_uniform2i,
        .call_uniform3f = &call_uniform3f,
        .call_uniform3i = &call_uniform3i,
        .call_uniform4f = &call_uniform4f,
        .call_uniform4i = &call_uniform4i,
        .call_useProgram = &call_useProgram,
        .call_validateProgram = &call_validateProgram,
        .call_vertexAttrib1f = &call_vertexAttrib1f,
        .call_vertexAttrib1fv = &call_vertexAttrib1fv,
        .call_vertexAttrib2f = &call_vertexAttrib2f,
        .call_vertexAttrib2fv = &call_vertexAttrib2fv,
        .call_vertexAttrib3f = &call_vertexAttrib3f,
        .call_vertexAttrib3fv = &call_vertexAttrib3fv,
        .call_vertexAttrib4f = &call_vertexAttrib4f,
        .call_vertexAttrib4fv = &call_vertexAttrib4fv,
        .call_vertexAttribPointer = &call_vertexAttribPointer,
        .call_viewport = &call_viewport,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        WebGLRenderingContextBaseImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WebGLRenderingContextBaseImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_canvas(instance: *runtime.Instance) anyerror!anyopaque {
        return try WebGLRenderingContextBaseImpl.get_canvas(instance);
    }

    pub fn get_drawingBufferWidth(instance: *runtime.Instance) anyerror!GLsizei {
        return try WebGLRenderingContextBaseImpl.get_drawingBufferWidth(instance);
    }

    pub fn get_drawingBufferHeight(instance: *runtime.Instance) anyerror!GLsizei {
        return try WebGLRenderingContextBaseImpl.get_drawingBufferHeight(instance);
    }

    pub fn get_drawingBufferFormat(instance: *runtime.Instance) anyerror!GLenum {
        return try WebGLRenderingContextBaseImpl.get_drawingBufferFormat(instance);
    }

    pub fn get_drawingBufferColorSpace(instance: *runtime.Instance) anyerror!PredefinedColorSpace {
        return try WebGLRenderingContextBaseImpl.get_drawingBufferColorSpace(instance);
    }

    pub fn set_drawingBufferColorSpace(instance: *runtime.Instance, value: PredefinedColorSpace) anyerror!void {
        try WebGLRenderingContextBaseImpl.set_drawingBufferColorSpace(instance, value);
    }

    pub fn get_unpackColorSpace(instance: *runtime.Instance) anyerror!PredefinedColorSpace {
        return try WebGLRenderingContextBaseImpl.get_unpackColorSpace(instance);
    }

    pub fn set_unpackColorSpace(instance: *runtime.Instance, value: PredefinedColorSpace) anyerror!void {
        try WebGLRenderingContextBaseImpl.set_unpackColorSpace(instance, value);
    }

    pub fn call_createRenderbuffer(instance: *runtime.Instance) anyerror!WebGLRenderbuffer {
        return try WebGLRenderingContextBaseImpl.call_createRenderbuffer(instance);
    }

    pub fn call_createFramebuffer(instance: *runtime.Instance) anyerror!WebGLFramebuffer {
        return try WebGLRenderingContextBaseImpl.call_createFramebuffer(instance);
    }

    pub fn call_createTexture(instance: *runtime.Instance) anyerror!WebGLTexture {
        return try WebGLRenderingContextBaseImpl.call_createTexture(instance);
    }

    pub fn call_vertexAttrib4f(instance: *runtime.Instance, index: GLuint, x: GLfloat, y: GLfloat, z: GLfloat, w: GLfloat) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_vertexAttrib4f(instance, index, x, y, z, w);
    }

    pub fn call_vertexAttribPointer(instance: *runtime.Instance, index: GLuint, size: GLint, type_: GLenum, normalized: GLboolean, stride: GLsizei, offset: GLintptr) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_vertexAttribPointer(instance, index, size, type_, normalized, stride, offset);
    }

    pub fn call_uniform4f(instance: *runtime.Instance, location: anyopaque, x: GLfloat, y: GLfloat, z: GLfloat, w: GLfloat) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_uniform4f(instance, location, x, y, z, w);
    }

    pub fn call_stencilOpSeparate(instance: *runtime.Instance, face: GLenum, fail: GLenum, zfail: GLenum, zpass: GLenum) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_stencilOpSeparate(instance, face, fail, zfail, zpass);
    }

    pub fn call_generateMipmap(instance: *runtime.Instance, target: GLenum) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_generateMipmap(instance, target);
    }

    pub fn call_getActiveAttrib(instance: *runtime.Instance, program: WebGLProgram, index: GLuint) anyerror!anyopaque {
        
        return try WebGLRenderingContextBaseImpl.call_getActiveAttrib(instance, program, index);
    }

    pub fn call_blendFunc(instance: *runtime.Instance, sfactor: GLenum, dfactor: GLenum) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_blendFunc(instance, sfactor, dfactor);
    }

    pub fn call_getFramebufferAttachmentParameter(instance: *runtime.Instance, target: GLenum, attachment: GLenum, pname: GLenum) anyerror!anyopaque {
        
        return try WebGLRenderingContextBaseImpl.call_getFramebufferAttachmentParameter(instance, target, attachment, pname);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_isEnabled(instance: *runtime.Instance, cap: GLenum) anyerror!GLboolean {
        
        return try WebGLRenderingContextBaseImpl.call_isEnabled(instance, cap);
    }

    pub fn call_copyTexSubImage2D(instance: *runtime.Instance, target: GLenum, level: GLint, xoffset: GLint, yoffset: GLint, x: GLint, y: GLint, width: GLsizei, height: GLsizei) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_copyTexSubImage2D(instance, target, level, xoffset, yoffset, x, y, width, height);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_getContextAttributes(instance: *runtime.Instance) anyerror!anyopaque {
        return try WebGLRenderingContextBaseImpl.call_getContextAttributes(instance);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_isRenderbuffer(instance: *runtime.Instance, renderbuffer: anyopaque) anyerror!GLboolean {
        
        return try WebGLRenderingContextBaseImpl.call_isRenderbuffer(instance, renderbuffer);
    }

    pub fn call_vertexAttrib2f(instance: *runtime.Instance, index: GLuint, x: GLfloat, y: GLfloat) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_vertexAttrib2f(instance, index, x, y);
    }

    pub fn call_clear(instance: *runtime.Instance, mask: GLbitfield) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_clear(instance, mask);
    }

    pub fn call_deleteTexture(instance: *runtime.Instance, texture: anyopaque) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_deleteTexture(instance, texture);
    }

    pub fn call_getShaderSource(instance: *runtime.Instance, shader: WebGLShader) anyerror!anyopaque {
        
        return try WebGLRenderingContextBaseImpl.call_getShaderSource(instance, shader);
    }

    pub fn call_disable(instance: *runtime.Instance, cap: GLenum) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_disable(instance, cap);
    }

    pub fn call_compileShader(instance: *runtime.Instance, shader: WebGLShader) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_compileShader(instance, shader);
    }

    pub fn call_blendEquationSeparate(instance: *runtime.Instance, modeRGB: GLenum, modeAlpha: GLenum) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_blendEquationSeparate(instance, modeRGB, modeAlpha);
    }

    pub fn call_depthMask(instance: *runtime.Instance, flag: GLboolean) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_depthMask(instance, flag);
    }

    pub fn call_depthRange(instance: *runtime.Instance, zNear: GLclampf, zFar: GLclampf) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_depthRange(instance, zNear, zFar);
    }

    pub fn call_polygonOffset(instance: *runtime.Instance, factor: GLfloat, units: GLfloat) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_polygonOffset(instance, factor, units);
    }

    pub fn call_drawElements(instance: *runtime.Instance, mode: GLenum, count: GLsizei, type_: GLenum, offset: GLintptr) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_drawElements(instance, mode, count, type_, offset);
    }

    pub fn call_bindBuffer(instance: *runtime.Instance, target: GLenum, buffer: anyopaque) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_bindBuffer(instance, target, buffer);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_isShader(instance: *runtime.Instance, shader: anyopaque) anyerror!GLboolean {
        
        return try WebGLRenderingContextBaseImpl.call_isShader(instance, shader);
    }

    pub fn call_getParameter(instance: *runtime.Instance, pname: GLenum) anyerror!anyopaque {
        
        return try WebGLRenderingContextBaseImpl.call_getParameter(instance, pname);
    }

    /// Extended attributes: [NewObject]
    pub fn call_makeXRCompatible(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try WebGLRenderingContextBaseImpl.call_makeXRCompatible(instance);
    }

    pub fn call_getSupportedExtensions(instance: *runtime.Instance) anyerror!anyopaque {
        return try WebGLRenderingContextBaseImpl.call_getSupportedExtensions(instance);
    }

    pub fn call_clearStencil(instance: *runtime.Instance, s: GLint) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_clearStencil(instance, s);
    }

    pub fn call_drawingBufferStorage(instance: *runtime.Instance, sizedFormat: GLenum, width: u32, height: u32) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_drawingBufferStorage(instance, sizedFormat, width, height);
    }

    pub fn call_enable(instance: *runtime.Instance, cap: GLenum) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_enable(instance, cap);
    }

    pub fn call_renderbufferStorage(instance: *runtime.Instance, target: GLenum, internalformat: GLenum, width: GLsizei, height: GLsizei) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_renderbufferStorage(instance, target, internalformat, width, height);
    }

    pub fn call_getVertexAttrib(instance: *runtime.Instance, index: GLuint, pname: GLenum) anyerror!anyopaque {
        
        return try WebGLRenderingContextBaseImpl.call_getVertexAttrib(instance, index, pname);
    }

    pub fn call_clearDepth(instance: *runtime.Instance, depth: GLclampf) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_clearDepth(instance, depth);
    }

    pub fn call_shaderSource(instance: *runtime.Instance, shader: WebGLShader, source: DOMString) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_shaderSource(instance, shader, source);
    }

    pub fn call_blendFuncSeparate(instance: *runtime.Instance, srcRGB: GLenum, dstRGB: GLenum, srcAlpha: GLenum, dstAlpha: GLenum) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_blendFuncSeparate(instance, srcRGB, dstRGB, srcAlpha, dstAlpha);
    }

    pub fn call_detachShader(instance: *runtime.Instance, program: WebGLProgram, shader: WebGLShader) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_detachShader(instance, program, shader);
    }

    pub fn call_clearColor(instance: *runtime.Instance, red: GLclampf, green: GLclampf, blue: GLclampf, alpha: GLclampf) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_clearColor(instance, red, green, blue, alpha);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_getError(instance: *runtime.Instance) anyerror!GLenum {
        return try WebGLRenderingContextBaseImpl.call_getError(instance);
    }

    pub fn call_deleteRenderbuffer(instance: *runtime.Instance, renderbuffer: anyopaque) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_deleteRenderbuffer(instance, renderbuffer);
    }

    pub fn call_vertexAttrib3fv(instance: *runtime.Instance, index: GLuint, values: Float32List) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_vertexAttrib3fv(instance, index, values);
    }

    pub fn call_activeTexture(instance: *runtime.Instance, texture: GLenum) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_activeTexture(instance, texture);
    }

    pub fn call_stencilFunc(instance: *runtime.Instance, func: GLenum, ref: GLint, mask: GLuint) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_stencilFunc(instance, func, ref, mask);
    }

    pub fn call_framebufferTexture2D(instance: *runtime.Instance, target: GLenum, attachment: GLenum, textarget: GLenum, texture: anyopaque, level: GLint) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_framebufferTexture2D(instance, target, attachment, textarget, texture, level);
    }

    pub fn call_createProgram(instance: *runtime.Instance) anyerror!WebGLProgram {
        return try WebGLRenderingContextBaseImpl.call_createProgram(instance);
    }

    pub fn call_getProgramInfoLog(instance: *runtime.Instance, program: WebGLProgram) anyerror!anyopaque {
        
        return try WebGLRenderingContextBaseImpl.call_getProgramInfoLog(instance, program);
    }

    pub fn call_createShader(instance: *runtime.Instance, type_: GLenum) anyerror!anyopaque {
        
        return try WebGLRenderingContextBaseImpl.call_createShader(instance, type_);
    }

    pub fn call_deleteProgram(instance: *runtime.Instance, program: anyopaque) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_deleteProgram(instance, program);
    }

    pub fn call_useProgram(instance: *runtime.Instance, program: anyopaque) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_useProgram(instance, program);
    }

    pub fn call_getTexParameter(instance: *runtime.Instance, target: GLenum, pname: GLenum) anyerror!anyopaque {
        
        return try WebGLRenderingContextBaseImpl.call_getTexParameter(instance, target, pname);
    }

    pub fn call_blendColor(instance: *runtime.Instance, red: GLclampf, green: GLclampf, blue: GLclampf, alpha: GLclampf) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_blendColor(instance, red, green, blue, alpha);
    }

    pub fn call_frontFace(instance: *runtime.Instance, mode: GLenum) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_frontFace(instance, mode);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_isBuffer(instance: *runtime.Instance, buffer: anyopaque) anyerror!GLboolean {
        
        return try WebGLRenderingContextBaseImpl.call_isBuffer(instance, buffer);
    }

    pub fn call_bindTexture(instance: *runtime.Instance, target: GLenum, texture: anyopaque) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_bindTexture(instance, target, texture);
    }

    pub fn call_uniform3f(instance: *runtime.Instance, location: anyopaque, x: GLfloat, y: GLfloat, z: GLfloat) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_uniform3f(instance, location, x, y, z);
    }

    pub fn call_blendEquation(instance: *runtime.Instance, mode: GLenum) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_blendEquation(instance, mode);
    }

    pub fn call_enableVertexAttribArray(instance: *runtime.Instance, index: GLuint) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_enableVertexAttribArray(instance, index);
    }

    pub fn call_bindFramebuffer(instance: *runtime.Instance, target: GLenum, framebuffer: anyopaque) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_bindFramebuffer(instance, target, framebuffer);
    }

    pub fn call_stencilFuncSeparate(instance: *runtime.Instance, face: GLenum, func: GLenum, ref: GLint, mask: GLuint) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_stencilFuncSeparate(instance, face, func, ref, mask);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_isFramebuffer(instance: *runtime.Instance, framebuffer: anyopaque) anyerror!GLboolean {
        
        return try WebGLRenderingContextBaseImpl.call_isFramebuffer(instance, framebuffer);
    }

    pub fn call_finish(instance: *runtime.Instance) anyerror!void {
        return try WebGLRenderingContextBaseImpl.call_finish(instance);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_checkFramebufferStatus(instance: *runtime.Instance, target: GLenum) anyerror!GLenum {
        
        return try WebGLRenderingContextBaseImpl.call_checkFramebufferStatus(instance, target);
    }

    pub fn call_getRenderbufferParameter(instance: *runtime.Instance, target: GLenum, pname: GLenum) anyerror!anyopaque {
        
        return try WebGLRenderingContextBaseImpl.call_getRenderbufferParameter(instance, target, pname);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_isTexture(instance: *runtime.Instance, texture: anyopaque) anyerror!GLboolean {
        
        return try WebGLRenderingContextBaseImpl.call_isTexture(instance, texture);
    }

    pub fn call_linkProgram(instance: *runtime.Instance, program: WebGLProgram) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_linkProgram(instance, program);
    }

    pub fn call_pixelStorei(instance: *runtime.Instance, pname: GLenum, param: GLint) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_pixelStorei(instance, pname, param);
    }

    pub fn call_framebufferRenderbuffer(instance: *runtime.Instance, target: GLenum, attachment: GLenum, renderbuffertarget: GLenum, renderbuffer: anyopaque) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_framebufferRenderbuffer(instance, target, attachment, renderbuffertarget, renderbuffer);
    }

    pub fn call_getActiveUniform(instance: *runtime.Instance, program: WebGLProgram, index: GLuint) anyerror!anyopaque {
        
        return try WebGLRenderingContextBaseImpl.call_getActiveUniform(instance, program, index);
    }

    pub fn call_stencilOp(instance: *runtime.Instance, fail: GLenum, zfail: GLenum, zpass: GLenum) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_stencilOp(instance, fail, zfail, zpass);
    }

    pub fn call_texParameteri(instance: *runtime.Instance, target: GLenum, pname: GLenum, param: GLint) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_texParameteri(instance, target, pname, param);
    }

    pub fn call_vertexAttrib1f(instance: *runtime.Instance, index: GLuint, x: GLfloat) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_vertexAttrib1f(instance, index, x);
    }

    pub fn call_getShaderInfoLog(instance: *runtime.Instance, shader: WebGLShader) anyerror!anyopaque {
        
        return try WebGLRenderingContextBaseImpl.call_getShaderInfoLog(instance, shader);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_isContextLost(instance: *runtime.Instance) anyerror!bool {
        return try WebGLRenderingContextBaseImpl.call_isContextLost(instance);
    }

    pub fn call_deleteFramebuffer(instance: *runtime.Instance, framebuffer: anyopaque) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_deleteFramebuffer(instance, framebuffer);
    }

    pub fn call_vertexAttrib3f(instance: *runtime.Instance, index: GLuint, x: GLfloat, y: GLfloat, z: GLfloat) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_vertexAttrib3f(instance, index, x, y, z);
    }

    pub fn call_viewport(instance: *runtime.Instance, x: GLint, y: GLint, width: GLsizei, height: GLsizei) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_viewport(instance, x, y, width, height);
    }

    pub fn call_bindRenderbuffer(instance: *runtime.Instance, target: GLenum, renderbuffer: anyopaque) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_bindRenderbuffer(instance, target, renderbuffer);
    }

    pub fn call_depthFunc(instance: *runtime.Instance, func: GLenum) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_depthFunc(instance, func);
    }

    pub fn call_bindAttribLocation(instance: *runtime.Instance, program: WebGLProgram, index: GLuint, name: DOMString) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_bindAttribLocation(instance, program, index, name);
    }

    pub fn call_hint(instance: *runtime.Instance, target: GLenum, mode: GLenum) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_hint(instance, target, mode);
    }

    pub fn call_getUniformLocation(instance: *runtime.Instance, program: WebGLProgram, name: DOMString) anyerror!anyopaque {
        
        return try WebGLRenderingContextBaseImpl.call_getUniformLocation(instance, program, name);
    }

    pub fn call_uniform1f(instance: *runtime.Instance, location: anyopaque, x: GLfloat) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_uniform1f(instance, location, x);
    }

    pub fn call_getExtension(instance: *runtime.Instance, name: DOMString) anyerror!anyopaque {
        
        return try WebGLRenderingContextBaseImpl.call_getExtension(instance, name);
    }

    pub fn call_colorMask(instance: *runtime.Instance, red: GLboolean, green: GLboolean, blue: GLboolean, alpha: GLboolean) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_colorMask(instance, red, green, blue, alpha);
    }

    pub fn call_cullFace(instance: *runtime.Instance, mode: GLenum) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_cullFace(instance, mode);
    }

    pub fn call_deleteShader(instance: *runtime.Instance, shader: anyopaque) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_deleteShader(instance, shader);
    }

    pub fn call_vertexAttrib4fv(instance: *runtime.Instance, index: GLuint, values: Float32List) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_vertexAttrib4fv(instance, index, values);
    }

    pub fn call_disableVertexAttribArray(instance: *runtime.Instance, index: GLuint) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_disableVertexAttribArray(instance, index);
    }

    pub fn call_flush(instance: *runtime.Instance) anyerror!void {
        return try WebGLRenderingContextBaseImpl.call_flush(instance);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_getAttribLocation(instance: *runtime.Instance, program: WebGLProgram, name: DOMString) anyerror!GLint {
        
        return try WebGLRenderingContextBaseImpl.call_getAttribLocation(instance, program, name);
    }

    pub fn call_getProgramParameter(instance: *runtime.Instance, program: WebGLProgram, pname: GLenum) anyerror!anyopaque {
        
        return try WebGLRenderingContextBaseImpl.call_getProgramParameter(instance, program, pname);
    }

    pub fn call_vertexAttrib2fv(instance: *runtime.Instance, index: GLuint, values: Float32List) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_vertexAttrib2fv(instance, index, values);
    }

    pub fn call_uniform3i(instance: *runtime.Instance, location: anyopaque, x: GLint, y: GLint, z: GLint) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_uniform3i(instance, location, x, y, z);
    }

    pub fn call_uniform2f(instance: *runtime.Instance, location: anyopaque, x: GLfloat, y: GLfloat) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_uniform2f(instance, location, x, y);
    }

    pub fn call_drawArrays(instance: *runtime.Instance, mode: GLenum, first: GLint, count: GLsizei) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_drawArrays(instance, mode, first, count);
    }

    pub fn call_validateProgram(instance: *runtime.Instance, program: WebGLProgram) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_validateProgram(instance, program);
    }

    pub fn call_uniform2i(instance: *runtime.Instance, location: anyopaque, x: GLint, y: GLint) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_uniform2i(instance, location, x, y);
    }

    pub fn call_vertexAttrib1fv(instance: *runtime.Instance, index: GLuint, values: Float32List) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_vertexAttrib1fv(instance, index, values);
    }

    pub fn call_createBuffer(instance: *runtime.Instance) anyerror!WebGLBuffer {
        return try WebGLRenderingContextBaseImpl.call_createBuffer(instance);
    }

    pub fn call_scissor(instance: *runtime.Instance, x: GLint, y: GLint, width: GLsizei, height: GLsizei) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_scissor(instance, x, y, width, height);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_getVertexAttribOffset(instance: *runtime.Instance, index: GLuint, pname: GLenum) anyerror!GLintptr {
        
        return try WebGLRenderingContextBaseImpl.call_getVertexAttribOffset(instance, index, pname);
    }

    pub fn call_getShaderParameter(instance: *runtime.Instance, shader: WebGLShader, pname: GLenum) anyerror!anyopaque {
        
        return try WebGLRenderingContextBaseImpl.call_getShaderParameter(instance, shader, pname);
    }

    pub fn call_uniform4i(instance: *runtime.Instance, location: anyopaque, x: GLint, y: GLint, z: GLint, w: GLint) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_uniform4i(instance, location, x, y, z, w);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_isProgram(instance: *runtime.Instance, program: anyopaque) anyerror!GLboolean {
        
        return try WebGLRenderingContextBaseImpl.call_isProgram(instance, program);
    }

    pub fn call_deleteBuffer(instance: *runtime.Instance, buffer: anyopaque) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_deleteBuffer(instance, buffer);
    }

    pub fn call_lineWidth(instance: *runtime.Instance, width: GLfloat) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_lineWidth(instance, width);
    }

    pub fn call_stencilMask(instance: *runtime.Instance, mask: GLuint) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_stencilMask(instance, mask);
    }

    pub fn call_uniform1i(instance: *runtime.Instance, location: anyopaque, x: GLint) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_uniform1i(instance, location, x);
    }

    pub fn call_getShaderPrecisionFormat(instance: *runtime.Instance, shadertype: GLenum, precisiontype: GLenum) anyerror!anyopaque {
        
        return try WebGLRenderingContextBaseImpl.call_getShaderPrecisionFormat(instance, shadertype, precisiontype);
    }

    pub fn call_getBufferParameter(instance: *runtime.Instance, target: GLenum, pname: GLenum) anyerror!anyopaque {
        
        return try WebGLRenderingContextBaseImpl.call_getBufferParameter(instance, target, pname);
    }

    pub fn call_texParameterf(instance: *runtime.Instance, target: GLenum, pname: GLenum, param: GLfloat) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_texParameterf(instance, target, pname, param);
    }

    pub fn call_stencilMaskSeparate(instance: *runtime.Instance, face: GLenum, mask: GLuint) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_stencilMaskSeparate(instance, face, mask);
    }

    pub fn call_copyTexImage2D(instance: *runtime.Instance, target: GLenum, level: GLint, internalformat: GLenum, x: GLint, y: GLint, width: GLsizei, height: GLsizei, border: GLint) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_copyTexImage2D(instance, target, level, internalformat, x, y, width, height, border);
    }

    pub fn call_sampleCoverage(instance: *runtime.Instance, value: GLclampf, invert: GLboolean) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_sampleCoverage(instance, value, invert);
    }

    pub fn call_attachShader(instance: *runtime.Instance, program: WebGLProgram, shader: WebGLShader) anyerror!void {
        
        return try WebGLRenderingContextBaseImpl.call_attachShader(instance, program, shader);
    }

    pub fn call_getUniform(instance: *runtime.Instance, program: WebGLProgram, location: WebGLUniformLocation) anyerror!anyopaque {
        
        return try WebGLRenderingContextBaseImpl.call_getUniform(instance, program, location);
    }

    pub fn call_getAttachedShaders(instance: *runtime.Instance, program: WebGLProgram) anyerror!anyopaque {
        
        return try WebGLRenderingContextBaseImpl.call_getAttachedShaders(instance, program);
    }

};
