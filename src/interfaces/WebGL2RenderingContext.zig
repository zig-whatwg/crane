//! Generated from: webgl2.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WebGL2RenderingContextImpl = @import("../impls/WebGL2RenderingContext.zig");
const WebGLRenderingContextBase = @import("WebGLRenderingContextBase.zig");
const WebGL2RenderingContextBase = @import("WebGL2RenderingContextBase.zig");
const WebGL2RenderingContextOverloads = @import("WebGL2RenderingContextOverloads.zig");

pub const WebGL2RenderingContext = struct {
    pub const Meta = struct {
        pub const name = "WebGL2RenderingContext";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{
            WebGLRenderingContextBase,
            WebGL2RenderingContextBase,
            WebGL2RenderingContextOverloads,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
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

    pub const vtable = runtime.buildVTable(WebGL2RenderingContext, .{
        .deinit_fn = &deinit_wrapper,

        .get_ACTIVE_ATTRIBUTES = &get_ACTIVE_ATTRIBUTES,
        .get_ACTIVE_TEXTURE = &get_ACTIVE_TEXTURE,
        .get_ACTIVE_UNIFORMS = &get_ACTIVE_UNIFORMS,
        .get_ACTIVE_UNIFORM_BLOCKS = &get_ACTIVE_UNIFORM_BLOCKS,
        .get_ALIASED_LINE_WIDTH_RANGE = &get_ALIASED_LINE_WIDTH_RANGE,
        .get_ALIASED_POINT_SIZE_RANGE = &get_ALIASED_POINT_SIZE_RANGE,
        .get_ALPHA = &get_ALPHA,
        .get_ALPHA_BITS = &get_ALPHA_BITS,
        .get_ALREADY_SIGNALED = &get_ALREADY_SIGNALED,
        .get_ALWAYS = &get_ALWAYS,
        .get_ANY_SAMPLES_PASSED = &get_ANY_SAMPLES_PASSED,
        .get_ANY_SAMPLES_PASSED_CONSERVATIVE = &get_ANY_SAMPLES_PASSED_CONSERVATIVE,
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
        .get_COLOR = &get_COLOR,
        .get_COLOR_ATTACHMENT0 = &get_COLOR_ATTACHMENT0,
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
        .get_COLOR_BUFFER_BIT = &get_COLOR_BUFFER_BIT,
        .get_COLOR_CLEAR_VALUE = &get_COLOR_CLEAR_VALUE,
        .get_COLOR_WRITEMASK = &get_COLOR_WRITEMASK,
        .get_COMPARE_REF_TO_TEXTURE = &get_COMPARE_REF_TO_TEXTURE,
        .get_COMPILE_STATUS = &get_COMPILE_STATUS,
        .get_COMPRESSED_TEXTURE_FORMATS = &get_COMPRESSED_TEXTURE_FORMATS,
        .get_CONDITION_SATISFIED = &get_CONDITION_SATISFIED,
        .get_CONSTANT_ALPHA = &get_CONSTANT_ALPHA,
        .get_CONSTANT_COLOR = &get_CONSTANT_COLOR,
        .get_CONTEXT_LOST_WEBGL = &get_CONTEXT_LOST_WEBGL,
        .get_COPY_READ_BUFFER = &get_COPY_READ_BUFFER,
        .get_COPY_READ_BUFFER_BINDING = &get_COPY_READ_BUFFER_BINDING,
        .get_COPY_WRITE_BUFFER = &get_COPY_WRITE_BUFFER,
        .get_COPY_WRITE_BUFFER_BINDING = &get_COPY_WRITE_BUFFER_BINDING,
        .get_CULL_FACE = &get_CULL_FACE,
        .get_CULL_FACE_MODE = &get_CULL_FACE_MODE,
        .get_CURRENT_PROGRAM = &get_CURRENT_PROGRAM,
        .get_CURRENT_QUERY = &get_CURRENT_QUERY,
        .get_CURRENT_VERTEX_ATTRIB = &get_CURRENT_VERTEX_ATTRIB,
        .get_CW = &get_CW,
        .get_DECR = &get_DECR,
        .get_DECR_WRAP = &get_DECR_WRAP,
        .get_DELETE_STATUS = &get_DELETE_STATUS,
        .get_DEPTH = &get_DEPTH,
        .get_DEPTH24_STENCIL8 = &get_DEPTH24_STENCIL8,
        .get_DEPTH32F_STENCIL8 = &get_DEPTH32F_STENCIL8,
        .get_DEPTH_ATTACHMENT = &get_DEPTH_ATTACHMENT,
        .get_DEPTH_BITS = &get_DEPTH_BITS,
        .get_DEPTH_BUFFER_BIT = &get_DEPTH_BUFFER_BIT,
        .get_DEPTH_CLEAR_VALUE = &get_DEPTH_CLEAR_VALUE,
        .get_DEPTH_COMPONENT = &get_DEPTH_COMPONENT,
        .get_DEPTH_COMPONENT16 = &get_DEPTH_COMPONENT16,
        .get_DEPTH_COMPONENT24 = &get_DEPTH_COMPONENT24,
        .get_DEPTH_COMPONENT32F = &get_DEPTH_COMPONENT32F,
        .get_DEPTH_FUNC = &get_DEPTH_FUNC,
        .get_DEPTH_RANGE = &get_DEPTH_RANGE,
        .get_DEPTH_STENCIL = &get_DEPTH_STENCIL,
        .get_DEPTH_STENCIL_ATTACHMENT = &get_DEPTH_STENCIL_ATTACHMENT,
        .get_DEPTH_TEST = &get_DEPTH_TEST,
        .get_DEPTH_WRITEMASK = &get_DEPTH_WRITEMASK,
        .get_DITHER = &get_DITHER,
        .get_DONT_CARE = &get_DONT_CARE,
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
        .get_DST_ALPHA = &get_DST_ALPHA,
        .get_DST_COLOR = &get_DST_COLOR,
        .get_DYNAMIC_COPY = &get_DYNAMIC_COPY,
        .get_DYNAMIC_DRAW = &get_DYNAMIC_DRAW,
        .get_DYNAMIC_READ = &get_DYNAMIC_READ,
        .get_ELEMENT_ARRAY_BUFFER = &get_ELEMENT_ARRAY_BUFFER,
        .get_ELEMENT_ARRAY_BUFFER_BINDING = &get_ELEMENT_ARRAY_BUFFER_BINDING,
        .get_EQUAL = &get_EQUAL,
        .get_FASTEST = &get_FASTEST,
        .get_FLOAT = &get_FLOAT,
        .get_FLOAT_32_UNSIGNED_INT_24_8_REV = &get_FLOAT_32_UNSIGNED_INT_24_8_REV,
        .get_FLOAT_MAT2 = &get_FLOAT_MAT2,
        .get_FLOAT_MAT2x3 = &get_FLOAT_MAT2x3,
        .get_FLOAT_MAT2x4 = &get_FLOAT_MAT2x4,
        .get_FLOAT_MAT3 = &get_FLOAT_MAT3,
        .get_FLOAT_MAT3x2 = &get_FLOAT_MAT3x2,
        .get_FLOAT_MAT3x4 = &get_FLOAT_MAT3x4,
        .get_FLOAT_MAT4 = &get_FLOAT_MAT4,
        .get_FLOAT_MAT4x2 = &get_FLOAT_MAT4x2,
        .get_FLOAT_MAT4x3 = &get_FLOAT_MAT4x3,
        .get_FLOAT_VEC2 = &get_FLOAT_VEC2,
        .get_FLOAT_VEC3 = &get_FLOAT_VEC3,
        .get_FLOAT_VEC4 = &get_FLOAT_VEC4,
        .get_FRAGMENT_SHADER = &get_FRAGMENT_SHADER,
        .get_FRAGMENT_SHADER_DERIVATIVE_HINT = &get_FRAGMENT_SHADER_DERIVATIVE_HINT,
        .get_FRAMEBUFFER = &get_FRAMEBUFFER,
        .get_FRAMEBUFFER_ATTACHMENT_ALPHA_SIZE = &get_FRAMEBUFFER_ATTACHMENT_ALPHA_SIZE,
        .get_FRAMEBUFFER_ATTACHMENT_BLUE_SIZE = &get_FRAMEBUFFER_ATTACHMENT_BLUE_SIZE,
        .get_FRAMEBUFFER_ATTACHMENT_COLOR_ENCODING = &get_FRAMEBUFFER_ATTACHMENT_COLOR_ENCODING,
        .get_FRAMEBUFFER_ATTACHMENT_COMPONENT_TYPE = &get_FRAMEBUFFER_ATTACHMENT_COMPONENT_TYPE,
        .get_FRAMEBUFFER_ATTACHMENT_DEPTH_SIZE = &get_FRAMEBUFFER_ATTACHMENT_DEPTH_SIZE,
        .get_FRAMEBUFFER_ATTACHMENT_GREEN_SIZE = &get_FRAMEBUFFER_ATTACHMENT_GREEN_SIZE,
        .get_FRAMEBUFFER_ATTACHMENT_OBJECT_NAME = &get_FRAMEBUFFER_ATTACHMENT_OBJECT_NAME,
        .get_FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE = &get_FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE,
        .get_FRAMEBUFFER_ATTACHMENT_RED_SIZE = &get_FRAMEBUFFER_ATTACHMENT_RED_SIZE,
        .get_FRAMEBUFFER_ATTACHMENT_STENCIL_SIZE = &get_FRAMEBUFFER_ATTACHMENT_STENCIL_SIZE,
        .get_FRAMEBUFFER_ATTACHMENT_TEXTURE_CUBE_MAP_FACE = &get_FRAMEBUFFER_ATTACHMENT_TEXTURE_CUBE_MAP_FACE,
        .get_FRAMEBUFFER_ATTACHMENT_TEXTURE_LAYER = &get_FRAMEBUFFER_ATTACHMENT_TEXTURE_LAYER,
        .get_FRAMEBUFFER_ATTACHMENT_TEXTURE_LEVEL = &get_FRAMEBUFFER_ATTACHMENT_TEXTURE_LEVEL,
        .get_FRAMEBUFFER_BINDING = &get_FRAMEBUFFER_BINDING,
        .get_FRAMEBUFFER_COMPLETE = &get_FRAMEBUFFER_COMPLETE,
        .get_FRAMEBUFFER_DEFAULT = &get_FRAMEBUFFER_DEFAULT,
        .get_FRAMEBUFFER_INCOMPLETE_ATTACHMENT = &get_FRAMEBUFFER_INCOMPLETE_ATTACHMENT,
        .get_FRAMEBUFFER_INCOMPLETE_DIMENSIONS = &get_FRAMEBUFFER_INCOMPLETE_DIMENSIONS,
        .get_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT = &get_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT,
        .get_FRAMEBUFFER_INCOMPLETE_MULTISAMPLE = &get_FRAMEBUFFER_INCOMPLETE_MULTISAMPLE,
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
        .get_HALF_FLOAT = &get_HALF_FLOAT,
        .get_HIGH_FLOAT = &get_HIGH_FLOAT,
        .get_HIGH_INT = &get_HIGH_INT,
        .get_IMPLEMENTATION_COLOR_READ_FORMAT = &get_IMPLEMENTATION_COLOR_READ_FORMAT,
        .get_IMPLEMENTATION_COLOR_READ_TYPE = &get_IMPLEMENTATION_COLOR_READ_TYPE,
        .get_INCR = &get_INCR,
        .get_INCR_WRAP = &get_INCR_WRAP,
        .get_INT = &get_INT,
        .get_INTERLEAVED_ATTRIBS = &get_INTERLEAVED_ATTRIBS,
        .get_INT_2_10_10_10_REV = &get_INT_2_10_10_10_REV,
        .get_INT_SAMPLER_2D = &get_INT_SAMPLER_2D,
        .get_INT_SAMPLER_2D_ARRAY = &get_INT_SAMPLER_2D_ARRAY,
        .get_INT_SAMPLER_3D = &get_INT_SAMPLER_3D,
        .get_INT_SAMPLER_CUBE = &get_INT_SAMPLER_CUBE,
        .get_INT_VEC2 = &get_INT_VEC2,
        .get_INT_VEC3 = &get_INT_VEC3,
        .get_INT_VEC4 = &get_INT_VEC4,
        .get_INVALID_ENUM = &get_INVALID_ENUM,
        .get_INVALID_FRAMEBUFFER_OPERATION = &get_INVALID_FRAMEBUFFER_OPERATION,
        .get_INVALID_INDEX = &get_INVALID_INDEX,
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
        .get_MAX = &get_MAX,
        .get_MAX_3D_TEXTURE_SIZE = &get_MAX_3D_TEXTURE_SIZE,
        .get_MAX_ARRAY_TEXTURE_LAYERS = &get_MAX_ARRAY_TEXTURE_LAYERS,
        .get_MAX_CLIENT_WAIT_TIMEOUT_WEBGL = &get_MAX_CLIENT_WAIT_TIMEOUT_WEBGL,
        .get_MAX_COLOR_ATTACHMENTS = &get_MAX_COLOR_ATTACHMENTS,
        .get_MAX_COMBINED_FRAGMENT_UNIFORM_COMPONENTS = &get_MAX_COMBINED_FRAGMENT_UNIFORM_COMPONENTS,
        .get_MAX_COMBINED_TEXTURE_IMAGE_UNITS = &get_MAX_COMBINED_TEXTURE_IMAGE_UNITS,
        .get_MAX_COMBINED_UNIFORM_BLOCKS = &get_MAX_COMBINED_UNIFORM_BLOCKS,
        .get_MAX_COMBINED_VERTEX_UNIFORM_COMPONENTS = &get_MAX_COMBINED_VERTEX_UNIFORM_COMPONENTS,
        .get_MAX_CUBE_MAP_TEXTURE_SIZE = &get_MAX_CUBE_MAP_TEXTURE_SIZE,
        .get_MAX_DRAW_BUFFERS = &get_MAX_DRAW_BUFFERS,
        .get_MAX_ELEMENTS_INDICES = &get_MAX_ELEMENTS_INDICES,
        .get_MAX_ELEMENTS_VERTICES = &get_MAX_ELEMENTS_VERTICES,
        .get_MAX_ELEMENT_INDEX = &get_MAX_ELEMENT_INDEX,
        .get_MAX_FRAGMENT_INPUT_COMPONENTS = &get_MAX_FRAGMENT_INPUT_COMPONENTS,
        .get_MAX_FRAGMENT_UNIFORM_BLOCKS = &get_MAX_FRAGMENT_UNIFORM_BLOCKS,
        .get_MAX_FRAGMENT_UNIFORM_COMPONENTS = &get_MAX_FRAGMENT_UNIFORM_COMPONENTS,
        .get_MAX_FRAGMENT_UNIFORM_VECTORS = &get_MAX_FRAGMENT_UNIFORM_VECTORS,
        .get_MAX_PROGRAM_TEXEL_OFFSET = &get_MAX_PROGRAM_TEXEL_OFFSET,
        .get_MAX_RENDERBUFFER_SIZE = &get_MAX_RENDERBUFFER_SIZE,
        .get_MAX_SAMPLES = &get_MAX_SAMPLES,
        .get_MAX_SERVER_WAIT_TIMEOUT = &get_MAX_SERVER_WAIT_TIMEOUT,
        .get_MAX_TEXTURE_IMAGE_UNITS = &get_MAX_TEXTURE_IMAGE_UNITS,
        .get_MAX_TEXTURE_LOD_BIAS = &get_MAX_TEXTURE_LOD_BIAS,
        .get_MAX_TEXTURE_SIZE = &get_MAX_TEXTURE_SIZE,
        .get_MAX_TRANSFORM_FEEDBACK_INTERLEAVED_COMPONENTS = &get_MAX_TRANSFORM_FEEDBACK_INTERLEAVED_COMPONENTS,
        .get_MAX_TRANSFORM_FEEDBACK_SEPARATE_ATTRIBS = &get_MAX_TRANSFORM_FEEDBACK_SEPARATE_ATTRIBS,
        .get_MAX_TRANSFORM_FEEDBACK_SEPARATE_COMPONENTS = &get_MAX_TRANSFORM_FEEDBACK_SEPARATE_COMPONENTS,
        .get_MAX_UNIFORM_BLOCK_SIZE = &get_MAX_UNIFORM_BLOCK_SIZE,
        .get_MAX_UNIFORM_BUFFER_BINDINGS = &get_MAX_UNIFORM_BUFFER_BINDINGS,
        .get_MAX_VARYING_COMPONENTS = &get_MAX_VARYING_COMPONENTS,
        .get_MAX_VARYING_VECTORS = &get_MAX_VARYING_VECTORS,
        .get_MAX_VERTEX_ATTRIBS = &get_MAX_VERTEX_ATTRIBS,
        .get_MAX_VERTEX_OUTPUT_COMPONENTS = &get_MAX_VERTEX_OUTPUT_COMPONENTS,
        .get_MAX_VERTEX_TEXTURE_IMAGE_UNITS = &get_MAX_VERTEX_TEXTURE_IMAGE_UNITS,
        .get_MAX_VERTEX_UNIFORM_BLOCKS = &get_MAX_VERTEX_UNIFORM_BLOCKS,
        .get_MAX_VERTEX_UNIFORM_COMPONENTS = &get_MAX_VERTEX_UNIFORM_COMPONENTS,
        .get_MAX_VERTEX_UNIFORM_VECTORS = &get_MAX_VERTEX_UNIFORM_VECTORS,
        .get_MAX_VIEWPORT_DIMS = &get_MAX_VIEWPORT_DIMS,
        .get_MEDIUM_FLOAT = &get_MEDIUM_FLOAT,
        .get_MEDIUM_INT = &get_MEDIUM_INT,
        .get_MIN = &get_MIN,
        .get_MIN_PROGRAM_TEXEL_OFFSET = &get_MIN_PROGRAM_TEXEL_OFFSET,
        .get_MIRRORED_REPEAT = &get_MIRRORED_REPEAT,
        .get_NEAREST = &get_NEAREST,
        .get_NEAREST_MIPMAP_LINEAR = &get_NEAREST_MIPMAP_LINEAR,
        .get_NEAREST_MIPMAP_NEAREST = &get_NEAREST_MIPMAP_NEAREST,
        .get_NEVER = &get_NEVER,
        .get_NICEST = &get_NICEST,
        .get_NONE = &get_NONE,
        .get_NOTEQUAL = &get_NOTEQUAL,
        .get_NO_ERROR = &get_NO_ERROR,
        .get_OBJECT_TYPE = &get_OBJECT_TYPE,
        .get_ONE = &get_ONE,
        .get_ONE_MINUS_CONSTANT_ALPHA = &get_ONE_MINUS_CONSTANT_ALPHA,
        .get_ONE_MINUS_CONSTANT_COLOR = &get_ONE_MINUS_CONSTANT_COLOR,
        .get_ONE_MINUS_DST_ALPHA = &get_ONE_MINUS_DST_ALPHA,
        .get_ONE_MINUS_DST_COLOR = &get_ONE_MINUS_DST_COLOR,
        .get_ONE_MINUS_SRC_ALPHA = &get_ONE_MINUS_SRC_ALPHA,
        .get_ONE_MINUS_SRC_COLOR = &get_ONE_MINUS_SRC_COLOR,
        .get_OUT_OF_MEMORY = &get_OUT_OF_MEMORY,
        .get_PACK_ALIGNMENT = &get_PACK_ALIGNMENT,
        .get_PACK_ROW_LENGTH = &get_PACK_ROW_LENGTH,
        .get_PACK_SKIP_PIXELS = &get_PACK_SKIP_PIXELS,
        .get_PACK_SKIP_ROWS = &get_PACK_SKIP_ROWS,
        .get_PIXEL_PACK_BUFFER = &get_PIXEL_PACK_BUFFER,
        .get_PIXEL_PACK_BUFFER_BINDING = &get_PIXEL_PACK_BUFFER_BINDING,
        .get_PIXEL_UNPACK_BUFFER = &get_PIXEL_UNPACK_BUFFER,
        .get_PIXEL_UNPACK_BUFFER_BINDING = &get_PIXEL_UNPACK_BUFFER_BINDING,
        .get_POINTS = &get_POINTS,
        .get_POLYGON_OFFSET_FACTOR = &get_POLYGON_OFFSET_FACTOR,
        .get_POLYGON_OFFSET_FILL = &get_POLYGON_OFFSET_FILL,
        .get_POLYGON_OFFSET_UNITS = &get_POLYGON_OFFSET_UNITS,
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
        .get_RED_BITS = &get_RED_BITS,
        .get_RED_INTEGER = &get_RED_INTEGER,
        .get_RENDERBUFFER = &get_RENDERBUFFER,
        .get_RENDERBUFFER_ALPHA_SIZE = &get_RENDERBUFFER_ALPHA_SIZE,
        .get_RENDERBUFFER_BINDING = &get_RENDERBUFFER_BINDING,
        .get_RENDERBUFFER_BLUE_SIZE = &get_RENDERBUFFER_BLUE_SIZE,
        .get_RENDERBUFFER_DEPTH_SIZE = &get_RENDERBUFFER_DEPTH_SIZE,
        .get_RENDERBUFFER_GREEN_SIZE = &get_RENDERBUFFER_GREEN_SIZE,
        .get_RENDERBUFFER_HEIGHT = &get_RENDERBUFFER_HEIGHT,
        .get_RENDERBUFFER_INTERNAL_FORMAT = &get_RENDERBUFFER_INTERNAL_FORMAT,
        .get_RENDERBUFFER_RED_SIZE = &get_RENDERBUFFER_RED_SIZE,
        .get_RENDERBUFFER_SAMPLES = &get_RENDERBUFFER_SAMPLES,
        .get_RENDERBUFFER_STENCIL_SIZE = &get_RENDERBUFFER_STENCIL_SIZE,
        .get_RENDERBUFFER_WIDTH = &get_RENDERBUFFER_WIDTH,
        .get_RENDERER = &get_RENDERER,
        .get_REPEAT = &get_REPEAT,
        .get_REPLACE = &get_REPLACE,
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
        .get_RGB = &get_RGB,
        .get_RGB10_A2 = &get_RGB10_A2,
        .get_RGB10_A2UI = &get_RGB10_A2UI,
        .get_RGB16F = &get_RGB16F,
        .get_RGB16I = &get_RGB16I,
        .get_RGB16UI = &get_RGB16UI,
        .get_RGB32F = &get_RGB32F,
        .get_RGB32I = &get_RGB32I,
        .get_RGB32UI = &get_RGB32UI,
        .get_RGB565 = &get_RGB565,
        .get_RGB5_A1 = &get_RGB5_A1,
        .get_RGB8 = &get_RGB8,
        .get_RGB8I = &get_RGB8I,
        .get_RGB8UI = &get_RGB8UI,
        .get_RGB8_SNORM = &get_RGB8_SNORM,
        .get_RGB9_E5 = &get_RGB9_E5,
        .get_RGBA = &get_RGBA,
        .get_RGBA16F = &get_RGBA16F,
        .get_RGBA16I = &get_RGBA16I,
        .get_RGBA16UI = &get_RGBA16UI,
        .get_RGBA32F = &get_RGBA32F,
        .get_RGBA32I = &get_RGBA32I,
        .get_RGBA32UI = &get_RGBA32UI,
        .get_RGBA4 = &get_RGBA4,
        .get_RGBA8 = &get_RGBA8,
        .get_RGBA8I = &get_RGBA8I,
        .get_RGBA8UI = &get_RGBA8UI,
        .get_RGBA8_SNORM = &get_RGBA8_SNORM,
        .get_RGBA_INTEGER = &get_RGBA_INTEGER,
        .get_RGB_INTEGER = &get_RGB_INTEGER,
        .get_RG_INTEGER = &get_RG_INTEGER,
        .get_SAMPLER_2D = &get_SAMPLER_2D,
        .get_SAMPLER_2D_ARRAY = &get_SAMPLER_2D_ARRAY,
        .get_SAMPLER_2D_ARRAY_SHADOW = &get_SAMPLER_2D_ARRAY_SHADOW,
        .get_SAMPLER_2D_SHADOW = &get_SAMPLER_2D_SHADOW,
        .get_SAMPLER_3D = &get_SAMPLER_3D,
        .get_SAMPLER_BINDING = &get_SAMPLER_BINDING,
        .get_SAMPLER_CUBE = &get_SAMPLER_CUBE,
        .get_SAMPLER_CUBE_SHADOW = &get_SAMPLER_CUBE_SHADOW,
        .get_SAMPLES = &get_SAMPLES,
        .get_SAMPLE_ALPHA_TO_COVERAGE = &get_SAMPLE_ALPHA_TO_COVERAGE,
        .get_SAMPLE_BUFFERS = &get_SAMPLE_BUFFERS,
        .get_SAMPLE_COVERAGE = &get_SAMPLE_COVERAGE,
        .get_SAMPLE_COVERAGE_INVERT = &get_SAMPLE_COVERAGE_INVERT,
        .get_SAMPLE_COVERAGE_VALUE = &get_SAMPLE_COVERAGE_VALUE,
        .get_SCISSOR_BOX = &get_SCISSOR_BOX,
        .get_SCISSOR_TEST = &get_SCISSOR_TEST,
        .get_SEPARATE_ATTRIBS = &get_SEPARATE_ATTRIBS,
        .get_SHADER_TYPE = &get_SHADER_TYPE,
        .get_SHADING_LANGUAGE_VERSION = &get_SHADING_LANGUAGE_VERSION,
        .get_SHORT = &get_SHORT,
        .get_SIGNALED = &get_SIGNALED,
        .get_SIGNED_NORMALIZED = &get_SIGNED_NORMALIZED,
        .get_SRC_ALPHA = &get_SRC_ALPHA,
        .get_SRC_ALPHA_SATURATE = &get_SRC_ALPHA_SATURATE,
        .get_SRC_COLOR = &get_SRC_COLOR,
        .get_SRGB = &get_SRGB,
        .get_SRGB8 = &get_SRGB8,
        .get_SRGB8_ALPHA8 = &get_SRGB8_ALPHA8,
        .get_STATIC_COPY = &get_STATIC_COPY,
        .get_STATIC_DRAW = &get_STATIC_DRAW,
        .get_STATIC_READ = &get_STATIC_READ,
        .get_STENCIL = &get_STENCIL,
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
        .get_STREAM_COPY = &get_STREAM_COPY,
        .get_STREAM_DRAW = &get_STREAM_DRAW,
        .get_STREAM_READ = &get_STREAM_READ,
        .get_SUBPIXEL_BITS = &get_SUBPIXEL_BITS,
        .get_SYNC_CONDITION = &get_SYNC_CONDITION,
        .get_SYNC_FENCE = &get_SYNC_FENCE,
        .get_SYNC_FLAGS = &get_SYNC_FLAGS,
        .get_SYNC_FLUSH_COMMANDS_BIT = &get_SYNC_FLUSH_COMMANDS_BIT,
        .get_SYNC_GPU_COMMANDS_COMPLETE = &get_SYNC_GPU_COMMANDS_COMPLETE,
        .get_SYNC_STATUS = &get_SYNC_STATUS,
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
        .get_TEXTURE_2D_ARRAY = &get_TEXTURE_2D_ARRAY,
        .get_TEXTURE_3D = &get_TEXTURE_3D,
        .get_TEXTURE_BASE_LEVEL = &get_TEXTURE_BASE_LEVEL,
        .get_TEXTURE_BINDING_2D = &get_TEXTURE_BINDING_2D,
        .get_TEXTURE_BINDING_2D_ARRAY = &get_TEXTURE_BINDING_2D_ARRAY,
        .get_TEXTURE_BINDING_3D = &get_TEXTURE_BINDING_3D,
        .get_TEXTURE_BINDING_CUBE_MAP = &get_TEXTURE_BINDING_CUBE_MAP,
        .get_TEXTURE_COMPARE_FUNC = &get_TEXTURE_COMPARE_FUNC,
        .get_TEXTURE_COMPARE_MODE = &get_TEXTURE_COMPARE_MODE,
        .get_TEXTURE_CUBE_MAP = &get_TEXTURE_CUBE_MAP,
        .get_TEXTURE_CUBE_MAP_NEGATIVE_X = &get_TEXTURE_CUBE_MAP_NEGATIVE_X,
        .get_TEXTURE_CUBE_MAP_NEGATIVE_Y = &get_TEXTURE_CUBE_MAP_NEGATIVE_Y,
        .get_TEXTURE_CUBE_MAP_NEGATIVE_Z = &get_TEXTURE_CUBE_MAP_NEGATIVE_Z,
        .get_TEXTURE_CUBE_MAP_POSITIVE_X = &get_TEXTURE_CUBE_MAP_POSITIVE_X,
        .get_TEXTURE_CUBE_MAP_POSITIVE_Y = &get_TEXTURE_CUBE_MAP_POSITIVE_Y,
        .get_TEXTURE_CUBE_MAP_POSITIVE_Z = &get_TEXTURE_CUBE_MAP_POSITIVE_Z,
        .get_TEXTURE_IMMUTABLE_FORMAT = &get_TEXTURE_IMMUTABLE_FORMAT,
        .get_TEXTURE_IMMUTABLE_LEVELS = &get_TEXTURE_IMMUTABLE_LEVELS,
        .get_TEXTURE_MAG_FILTER = &get_TEXTURE_MAG_FILTER,
        .get_TEXTURE_MAX_LEVEL = &get_TEXTURE_MAX_LEVEL,
        .get_TEXTURE_MAX_LOD = &get_TEXTURE_MAX_LOD,
        .get_TEXTURE_MIN_FILTER = &get_TEXTURE_MIN_FILTER,
        .get_TEXTURE_MIN_LOD = &get_TEXTURE_MIN_LOD,
        .get_TEXTURE_WRAP_R = &get_TEXTURE_WRAP_R,
        .get_TEXTURE_WRAP_S = &get_TEXTURE_WRAP_S,
        .get_TEXTURE_WRAP_T = &get_TEXTURE_WRAP_T,
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
        .get_TRIANGLES = &get_TRIANGLES,
        .get_TRIANGLE_FAN = &get_TRIANGLE_FAN,
        .get_TRIANGLE_STRIP = &get_TRIANGLE_STRIP,
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
        .get_UNPACK_ALIGNMENT = &get_UNPACK_ALIGNMENT,
        .get_UNPACK_COLORSPACE_CONVERSION_WEBGL = &get_UNPACK_COLORSPACE_CONVERSION_WEBGL,
        .get_UNPACK_FLIP_Y_WEBGL = &get_UNPACK_FLIP_Y_WEBGL,
        .get_UNPACK_IMAGE_HEIGHT = &get_UNPACK_IMAGE_HEIGHT,
        .get_UNPACK_PREMULTIPLY_ALPHA_WEBGL = &get_UNPACK_PREMULTIPLY_ALPHA_WEBGL,
        .get_UNPACK_ROW_LENGTH = &get_UNPACK_ROW_LENGTH,
        .get_UNPACK_SKIP_IMAGES = &get_UNPACK_SKIP_IMAGES,
        .get_UNPACK_SKIP_PIXELS = &get_UNPACK_SKIP_PIXELS,
        .get_UNPACK_SKIP_ROWS = &get_UNPACK_SKIP_ROWS,
        .get_UNSIGNALED = &get_UNSIGNALED,
        .get_UNSIGNED_BYTE = &get_UNSIGNED_BYTE,
        .get_UNSIGNED_INT = &get_UNSIGNED_INT,
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
        .get_UNSIGNED_SHORT = &get_UNSIGNED_SHORT,
        .get_UNSIGNED_SHORT_4_4_4_4 = &get_UNSIGNED_SHORT_4_4_4_4,
        .get_UNSIGNED_SHORT_5_5_5_1 = &get_UNSIGNED_SHORT_5_5_5_1,
        .get_UNSIGNED_SHORT_5_6_5 = &get_UNSIGNED_SHORT_5_6_5,
        .get_VALIDATE_STATUS = &get_VALIDATE_STATUS,
        .get_VENDOR = &get_VENDOR,
        .get_VERSION = &get_VERSION,
        .get_VERTEX_ARRAY_BINDING = &get_VERTEX_ARRAY_BINDING,
        .get_VERTEX_ATTRIB_ARRAY_BUFFER_BINDING = &get_VERTEX_ATTRIB_ARRAY_BUFFER_BINDING,
        .get_VERTEX_ATTRIB_ARRAY_DIVISOR = &get_VERTEX_ATTRIB_ARRAY_DIVISOR,
        .get_VERTEX_ATTRIB_ARRAY_ENABLED = &get_VERTEX_ATTRIB_ARRAY_ENABLED,
        .get_VERTEX_ATTRIB_ARRAY_INTEGER = &get_VERTEX_ATTRIB_ARRAY_INTEGER,
        .get_VERTEX_ATTRIB_ARRAY_NORMALIZED = &get_VERTEX_ATTRIB_ARRAY_NORMALIZED,
        .get_VERTEX_ATTRIB_ARRAY_POINTER = &get_VERTEX_ATTRIB_ARRAY_POINTER,
        .get_VERTEX_ATTRIB_ARRAY_SIZE = &get_VERTEX_ATTRIB_ARRAY_SIZE,
        .get_VERTEX_ATTRIB_ARRAY_STRIDE = &get_VERTEX_ATTRIB_ARRAY_STRIDE,
        .get_VERTEX_ATTRIB_ARRAY_TYPE = &get_VERTEX_ATTRIB_ARRAY_TYPE,
        .get_VERTEX_SHADER = &get_VERTEX_SHADER,
        .get_VIEWPORT = &get_VIEWPORT,
        .get_WAIT_FAILED = &get_WAIT_FAILED,
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
        .call_beginQuery = &call_beginQuery,
        .call_beginTransformFeedback = &call_beginTransformFeedback,
        .call_bindAttribLocation = &call_bindAttribLocation,
        .call_bindBuffer = &call_bindBuffer,
        .call_bindBufferBase = &call_bindBufferBase,
        .call_bindBufferRange = &call_bindBufferRange,
        .call_bindFramebuffer = &call_bindFramebuffer,
        .call_bindRenderbuffer = &call_bindRenderbuffer,
        .call_bindSampler = &call_bindSampler,
        .call_bindTexture = &call_bindTexture,
        .call_bindTransformFeedback = &call_bindTransformFeedback,
        .call_bindVertexArray = &call_bindVertexArray,
        .call_blendColor = &call_blendColor,
        .call_blendEquation = &call_blendEquation,
        .call_blendEquationSeparate = &call_blendEquationSeparate,
        .call_blendFunc = &call_blendFunc,
        .call_blendFuncSeparate = &call_blendFuncSeparate,
        .call_blitFramebuffer = &call_blitFramebuffer,
        .call_bufferData = &call_bufferData,
        .call_bufferData = &call_bufferData,
        .call_bufferData = &call_bufferData,
        .call_bufferSubData = &call_bufferSubData,
        .call_bufferSubData = &call_bufferSubData,
        .call_checkFramebufferStatus = &call_checkFramebufferStatus,
        .call_clear = &call_clear,
        .call_clearBufferfi = &call_clearBufferfi,
        .call_clearBufferfv = &call_clearBufferfv,
        .call_clearBufferiv = &call_clearBufferiv,
        .call_clearBufferuiv = &call_clearBufferuiv,
        .call_clearColor = &call_clearColor,
        .call_clearDepth = &call_clearDepth,
        .call_clearStencil = &call_clearStencil,
        .call_clientWaitSync = &call_clientWaitSync,
        .call_colorMask = &call_colorMask,
        .call_compileShader = &call_compileShader,
        .call_compressedTexImage2D = &call_compressedTexImage2D,
        .call_compressedTexImage2D = &call_compressedTexImage2D,
        .call_compressedTexImage3D = &call_compressedTexImage3D,
        .call_compressedTexImage3D = &call_compressedTexImage3D,
        .call_compressedTexSubImage2D = &call_compressedTexSubImage2D,
        .call_compressedTexSubImage2D = &call_compressedTexSubImage2D,
        .call_compressedTexSubImage3D = &call_compressedTexSubImage3D,
        .call_compressedTexSubImage3D = &call_compressedTexSubImage3D,
        .call_copyBufferSubData = &call_copyBufferSubData,
        .call_copyTexImage2D = &call_copyTexImage2D,
        .call_copyTexSubImage2D = &call_copyTexSubImage2D,
        .call_copyTexSubImage3D = &call_copyTexSubImage3D,
        .call_createBuffer = &call_createBuffer,
        .call_createFramebuffer = &call_createFramebuffer,
        .call_createProgram = &call_createProgram,
        .call_createQuery = &call_createQuery,
        .call_createRenderbuffer = &call_createRenderbuffer,
        .call_createSampler = &call_createSampler,
        .call_createShader = &call_createShader,
        .call_createTexture = &call_createTexture,
        .call_createTransformFeedback = &call_createTransformFeedback,
        .call_createVertexArray = &call_createVertexArray,
        .call_cullFace = &call_cullFace,
        .call_deleteBuffer = &call_deleteBuffer,
        .call_deleteFramebuffer = &call_deleteFramebuffer,
        .call_deleteProgram = &call_deleteProgram,
        .call_deleteQuery = &call_deleteQuery,
        .call_deleteRenderbuffer = &call_deleteRenderbuffer,
        .call_deleteSampler = &call_deleteSampler,
        .call_deleteShader = &call_deleteShader,
        .call_deleteSync = &call_deleteSync,
        .call_deleteTexture = &call_deleteTexture,
        .call_deleteTransformFeedback = &call_deleteTransformFeedback,
        .call_deleteVertexArray = &call_deleteVertexArray,
        .call_depthFunc = &call_depthFunc,
        .call_depthMask = &call_depthMask,
        .call_depthRange = &call_depthRange,
        .call_detachShader = &call_detachShader,
        .call_disable = &call_disable,
        .call_disableVertexAttribArray = &call_disableVertexAttribArray,
        .call_drawArrays = &call_drawArrays,
        .call_drawArraysInstanced = &call_drawArraysInstanced,
        .call_drawBuffers = &call_drawBuffers,
        .call_drawElements = &call_drawElements,
        .call_drawElementsInstanced = &call_drawElementsInstanced,
        .call_drawRangeElements = &call_drawRangeElements,
        .call_drawingBufferStorage = &call_drawingBufferStorage,
        .call_enable = &call_enable,
        .call_enableVertexAttribArray = &call_enableVertexAttribArray,
        .call_endQuery = &call_endQuery,
        .call_endTransformFeedback = &call_endTransformFeedback,
        .call_fenceSync = &call_fenceSync,
        .call_finish = &call_finish,
        .call_flush = &call_flush,
        .call_framebufferRenderbuffer = &call_framebufferRenderbuffer,
        .call_framebufferTexture2D = &call_framebufferTexture2D,
        .call_framebufferTextureLayer = &call_framebufferTextureLayer,
        .call_frontFace = &call_frontFace,
        .call_generateMipmap = &call_generateMipmap,
        .call_getActiveAttrib = &call_getActiveAttrib,
        .call_getActiveUniform = &call_getActiveUniform,
        .call_getActiveUniformBlockName = &call_getActiveUniformBlockName,
        .call_getActiveUniformBlockParameter = &call_getActiveUniformBlockParameter,
        .call_getActiveUniforms = &call_getActiveUniforms,
        .call_getAttachedShaders = &call_getAttachedShaders,
        .call_getAttribLocation = &call_getAttribLocation,
        .call_getBufferParameter = &call_getBufferParameter,
        .call_getBufferSubData = &call_getBufferSubData,
        .call_getContextAttributes = &call_getContextAttributes,
        .call_getError = &call_getError,
        .call_getExtension = &call_getExtension,
        .call_getFragDataLocation = &call_getFragDataLocation,
        .call_getFramebufferAttachmentParameter = &call_getFramebufferAttachmentParameter,
        .call_getIndexedParameter = &call_getIndexedParameter,
        .call_getInternalformatParameter = &call_getInternalformatParameter,
        .call_getParameter = &call_getParameter,
        .call_getProgramInfoLog = &call_getProgramInfoLog,
        .call_getProgramParameter = &call_getProgramParameter,
        .call_getQuery = &call_getQuery,
        .call_getQueryParameter = &call_getQueryParameter,
        .call_getRenderbufferParameter = &call_getRenderbufferParameter,
        .call_getSamplerParameter = &call_getSamplerParameter,
        .call_getShaderInfoLog = &call_getShaderInfoLog,
        .call_getShaderParameter = &call_getShaderParameter,
        .call_getShaderPrecisionFormat = &call_getShaderPrecisionFormat,
        .call_getShaderSource = &call_getShaderSource,
        .call_getSupportedExtensions = &call_getSupportedExtensions,
        .call_getSyncParameter = &call_getSyncParameter,
        .call_getTexParameter = &call_getTexParameter,
        .call_getTransformFeedbackVarying = &call_getTransformFeedbackVarying,
        .call_getUniform = &call_getUniform,
        .call_getUniformBlockIndex = &call_getUniformBlockIndex,
        .call_getUniformIndices = &call_getUniformIndices,
        .call_getUniformLocation = &call_getUniformLocation,
        .call_getVertexAttrib = &call_getVertexAttrib,
        .call_getVertexAttribOffset = &call_getVertexAttribOffset,
        .call_hint = &call_hint,
        .call_invalidateFramebuffer = &call_invalidateFramebuffer,
        .call_invalidateSubFramebuffer = &call_invalidateSubFramebuffer,
        .call_isBuffer = &call_isBuffer,
        .call_isContextLost = &call_isContextLost,
        .call_isEnabled = &call_isEnabled,
        .call_isFramebuffer = &call_isFramebuffer,
        .call_isProgram = &call_isProgram,
        .call_isQuery = &call_isQuery,
        .call_isRenderbuffer = &call_isRenderbuffer,
        .call_isSampler = &call_isSampler,
        .call_isShader = &call_isShader,
        .call_isSync = &call_isSync,
        .call_isTexture = &call_isTexture,
        .call_isTransformFeedback = &call_isTransformFeedback,
        .call_isVertexArray = &call_isVertexArray,
        .call_lineWidth = &call_lineWidth,
        .call_linkProgram = &call_linkProgram,
        .call_makeXRCompatible = &call_makeXRCompatible,
        .call_pauseTransformFeedback = &call_pauseTransformFeedback,
        .call_pixelStorei = &call_pixelStorei,
        .call_polygonOffset = &call_polygonOffset,
        .call_readBuffer = &call_readBuffer,
        .call_readPixels = &call_readPixels,
        .call_readPixels = &call_readPixels,
        .call_readPixels = &call_readPixels,
        .call_renderbufferStorage = &call_renderbufferStorage,
        .call_renderbufferStorageMultisample = &call_renderbufferStorageMultisample,
        .call_resumeTransformFeedback = &call_resumeTransformFeedback,
        .call_sampleCoverage = &call_sampleCoverage,
        .call_samplerParameterf = &call_samplerParameterf,
        .call_samplerParameteri = &call_samplerParameteri,
        .call_scissor = &call_scissor,
        .call_shaderSource = &call_shaderSource,
        .call_stencilFunc = &call_stencilFunc,
        .call_stencilFuncSeparate = &call_stencilFuncSeparate,
        .call_stencilMask = &call_stencilMask,
        .call_stencilMaskSeparate = &call_stencilMaskSeparate,
        .call_stencilOp = &call_stencilOp,
        .call_stencilOpSeparate = &call_stencilOpSeparate,
        .call_texImage2D = &call_texImage2D,
        .call_texImage2D = &call_texImage2D,
        .call_texImage2D = &call_texImage2D,
        .call_texImage2D = &call_texImage2D,
        .call_texImage2D = &call_texImage2D,
        .call_texImage3D = &call_texImage3D,
        .call_texImage3D = &call_texImage3D,
        .call_texImage3D = &call_texImage3D,
        .call_texImage3D = &call_texImage3D,
        .call_texParameterf = &call_texParameterf,
        .call_texParameteri = &call_texParameteri,
        .call_texStorage2D = &call_texStorage2D,
        .call_texStorage3D = &call_texStorage3D,
        .call_texSubImage2D = &call_texSubImage2D,
        .call_texSubImage2D = &call_texSubImage2D,
        .call_texSubImage2D = &call_texSubImage2D,
        .call_texSubImage2D = &call_texSubImage2D,
        .call_texSubImage2D = &call_texSubImage2D,
        .call_texSubImage3D = &call_texSubImage3D,
        .call_texSubImage3D = &call_texSubImage3D,
        .call_texSubImage3D = &call_texSubImage3D,
        .call_transformFeedbackVaryings = &call_transformFeedbackVaryings,
        .call_uniform1f = &call_uniform1f,
        .call_uniform1fv = &call_uniform1fv,
        .call_uniform1i = &call_uniform1i,
        .call_uniform1iv = &call_uniform1iv,
        .call_uniform1ui = &call_uniform1ui,
        .call_uniform1uiv = &call_uniform1uiv,
        .call_uniform2f = &call_uniform2f,
        .call_uniform2fv = &call_uniform2fv,
        .call_uniform2i = &call_uniform2i,
        .call_uniform2iv = &call_uniform2iv,
        .call_uniform2ui = &call_uniform2ui,
        .call_uniform2uiv = &call_uniform2uiv,
        .call_uniform3f = &call_uniform3f,
        .call_uniform3fv = &call_uniform3fv,
        .call_uniform3i = &call_uniform3i,
        .call_uniform3iv = &call_uniform3iv,
        .call_uniform3ui = &call_uniform3ui,
        .call_uniform3uiv = &call_uniform3uiv,
        .call_uniform4f = &call_uniform4f,
        .call_uniform4fv = &call_uniform4fv,
        .call_uniform4i = &call_uniform4i,
        .call_uniform4iv = &call_uniform4iv,
        .call_uniform4ui = &call_uniform4ui,
        .call_uniform4uiv = &call_uniform4uiv,
        .call_uniformBlockBinding = &call_uniformBlockBinding,
        .call_uniformMatrix2fv = &call_uniformMatrix2fv,
        .call_uniformMatrix2x3fv = &call_uniformMatrix2x3fv,
        .call_uniformMatrix2x4fv = &call_uniformMatrix2x4fv,
        .call_uniformMatrix3fv = &call_uniformMatrix3fv,
        .call_uniformMatrix3x2fv = &call_uniformMatrix3x2fv,
        .call_uniformMatrix3x4fv = &call_uniformMatrix3x4fv,
        .call_uniformMatrix4fv = &call_uniformMatrix4fv,
        .call_uniformMatrix4x2fv = &call_uniformMatrix4x2fv,
        .call_uniformMatrix4x3fv = &call_uniformMatrix4x3fv,
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
        .call_vertexAttribDivisor = &call_vertexAttribDivisor,
        .call_vertexAttribI4i = &call_vertexAttribI4i,
        .call_vertexAttribI4iv = &call_vertexAttribI4iv,
        .call_vertexAttribI4ui = &call_vertexAttribI4ui,
        .call_vertexAttribI4uiv = &call_vertexAttribI4uiv,
        .call_vertexAttribIPointer = &call_vertexAttribIPointer,
        .call_vertexAttribPointer = &call_vertexAttribPointer,
        .call_viewport = &call_viewport,
        .call_waitSync = &call_waitSync,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        WebGL2RenderingContextImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        WebGL2RenderingContextImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_canvas(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebGL2RenderingContextImpl.get_canvas(state);
    }

    pub fn get_drawingBufferWidth(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebGL2RenderingContextImpl.get_drawingBufferWidth(state);
    }

    pub fn get_drawingBufferHeight(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebGL2RenderingContextImpl.get_drawingBufferHeight(state);
    }

    pub fn get_drawingBufferFormat(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebGL2RenderingContextImpl.get_drawingBufferFormat(state);
    }

    pub fn get_drawingBufferColorSpace(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebGL2RenderingContextImpl.get_drawingBufferColorSpace(state);
    }

    pub fn set_drawingBufferColorSpace(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WebGL2RenderingContextImpl.set_drawingBufferColorSpace(state, value);
    }

    pub fn get_unpackColorSpace(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebGL2RenderingContextImpl.get_unpackColorSpace(state);
    }

    pub fn set_unpackColorSpace(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WebGL2RenderingContextImpl.set_unpackColorSpace(state, value);
    }

    pub fn call_createRenderbuffer(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebGL2RenderingContextImpl.call_createRenderbuffer(state);
    }

    pub fn call_uniform4ui(instance: *runtime.Instance, location: anyopaque, v0: anyopaque, v1: anyopaque, v2: anyopaque, v3: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniform4ui(state, location, v0, v1, v2, v3);
    }

    pub fn call_resumeTransformFeedback(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebGL2RenderingContextImpl.call_resumeTransformFeedback(state);
    }

    pub fn call_vertexAttribDivisor(instance: *runtime.Instance, index: anyopaque, divisor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_vertexAttribDivisor(state, index, divisor);
    }

    pub fn call_uniformBlockBinding(instance: *runtime.Instance, program: anyopaque, uniformBlockIndex: anyopaque, uniformBlockBinding: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniformBlockBinding(state, program, uniformBlockIndex, uniformBlockBinding);
    }

    pub fn call_vertexAttribPointer(instance: *runtime.Instance, index: anyopaque, size: anyopaque, type_: anyopaque, normalized: anyopaque, stride: anyopaque, offset: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_vertexAttribPointer(state, index, size, type_, normalized, stride, offset);
    }

    /// Arguments for readPixels (WebIDL overloading)
    pub const ReadPixelsArgs = union(enum) {
        /// readPixels(x, y, width, height, format, type, dstData)
        GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView?: struct {
            x: anyopaque,
            y: anyopaque,
            width: anyopaque,
            height: anyopaque,
            format: anyopaque,
            type_: anyopaque,
            dstData: anyopaque,
        },
        /// readPixels(x, y, width, height, format, type, offset)
        GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_GLintptr: struct {
            x: anyopaque,
            y: anyopaque,
            width: anyopaque,
            height: anyopaque,
            format: anyopaque,
            type_: anyopaque,
            offset: anyopaque,
        },
        /// readPixels(x, y, width, height, format, type, dstData, dstOffset)
        GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView_long long: struct {
            x: anyopaque,
            y: anyopaque,
            width: anyopaque,
            height: anyopaque,
            format: anyopaque,
            type_: anyopaque,
            dstData: anyopaque,
            dstOffset: u64,
        },
    };

    pub fn call_readPixels(instance: *runtime.Instance, args: ReadPixelsArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView? => |a| return WebGL2RenderingContextImpl.GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView?(state, a.x, a.y, a.width, a.height, a.format, a.type_, a.dstData),
            .GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_GLintptr => |a| return WebGL2RenderingContextImpl.GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_GLintptr(state, a.x, a.y, a.width, a.height, a.format, a.type_, a.offset),
            .GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView_long long => |a| return WebGL2RenderingContextImpl.GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView_long long(state, a.x, a.y, a.width, a.height, a.format, a.type_, a.dstData, a.dstOffset),
        }
    }

    pub fn call_createVertexArray(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebGL2RenderingContextImpl.call_createVertexArray(state);
    }

    pub fn call_getActiveAttrib(instance: *runtime.Instance, program: anyopaque, index: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getActiveAttrib(state, program, index);
    }

    /// Arguments for texImage2D (WebIDL overloading)
    pub const TexImage2DArgs = union(enum) {
        /// texImage2D(target, level, internalformat, width, height, border, format, type, pixels)
        GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView?: struct {
            target: anyopaque,
            level: anyopaque,
            internalformat: anyopaque,
            width: anyopaque,
            height: anyopaque,
            border: anyopaque,
            format: anyopaque,
            type_: anyopaque,
            pixels: anyopaque,
        },
        /// texImage2D(target, level, internalformat, format, type, source)
        GLenum_GLint_GLint_GLenum_GLenum_TexImageSource: struct {
            target: anyopaque,
            level: anyopaque,
            internalformat: anyopaque,
            format: anyopaque,
            type_: anyopaque,
            source: anyopaque,
        },
        /// texImage2D(target, level, internalformat, width, height, border, format, type, pboOffset)
        GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_GLintptr: struct {
            target: anyopaque,
            level: anyopaque,
            internalformat: anyopaque,
            width: anyopaque,
            height: anyopaque,
            border: anyopaque,
            format: anyopaque,
            type_: anyopaque,
            pboOffset: anyopaque,
        },
        /// texImage2D(target, level, internalformat, width, height, border, format, type, source)
        GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_TexImageSource: struct {
            target: anyopaque,
            level: anyopaque,
            internalformat: anyopaque,
            width: anyopaque,
            height: anyopaque,
            border: anyopaque,
            format: anyopaque,
            type_: anyopaque,
            source: anyopaque,
        },
        /// texImage2D(target, level, internalformat, width, height, border, format, type, srcData, srcOffset)
        GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView_long long: struct {
            target: anyopaque,
            level: anyopaque,
            internalformat: anyopaque,
            width: anyopaque,
            height: anyopaque,
            border: anyopaque,
            format: anyopaque,
            type_: anyopaque,
            srcData: anyopaque,
            srcOffset: u64,
        },
    };

    pub fn call_texImage2D(instance: *runtime.Instance, args: TexImage2DArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView? => |a| return WebGL2RenderingContextImpl.GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView?(state, a.target, a.level, a.internalformat, a.width, a.height, a.border, a.format, a.type_, a.pixels),
            .GLenum_GLint_GLint_GLenum_GLenum_TexImageSource => |a| return WebGL2RenderingContextImpl.GLenum_GLint_GLint_GLenum_GLenum_TexImageSource(state, a.target, a.level, a.internalformat, a.format, a.type_, a.source),
            .GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_GLintptr => |a| return WebGL2RenderingContextImpl.GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_GLintptr(state, a.target, a.level, a.internalformat, a.width, a.height, a.border, a.format, a.type_, a.pboOffset),
            .GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_TexImageSource => |a| return WebGL2RenderingContextImpl.GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_TexImageSource(state, a.target, a.level, a.internalformat, a.width, a.height, a.border, a.format, a.type_, a.source),
            .GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView_long long => |a| return WebGL2RenderingContextImpl.GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView_long long(state, a.target, a.level, a.internalformat, a.width, a.height, a.border, a.format, a.type_, a.srcData, a.srcOffset),
        }
    }

    pub fn call_blendFunc(instance: *runtime.Instance, sfactor: anyopaque, dfactor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_blendFunc(state, sfactor, dfactor);
    }

    /// Arguments for texImage3D (WebIDL overloading)
    pub const TexImage3DArgs = union(enum) {
        /// texImage3D(target, level, internalformat, width, height, depth, border, format, type, pboOffset)
        GLenum_GLint_GLint_GLsizei_GLsizei_GLsizei_GLint_GLenum_GLenum_GLintptr: struct {
            target: anyopaque,
            level: anyopaque,
            internalformat: anyopaque,
            width: anyopaque,
            height: anyopaque,
            depth: anyopaque,
            border: anyopaque,
            format: anyopaque,
            type_: anyopaque,
            pboOffset: anyopaque,
        },
        /// texImage3D(target, level, internalformat, width, height, depth, border, format, type, source)
        GLenum_GLint_GLint_GLsizei_GLsizei_GLsizei_GLint_GLenum_GLenum_TexImageSource: struct {
            target: anyopaque,
            level: anyopaque,
            internalformat: anyopaque,
            width: anyopaque,
            height: anyopaque,
            depth: anyopaque,
            border: anyopaque,
            format: anyopaque,
            type_: anyopaque,
            source: anyopaque,
        },
        /// texImage3D(target, level, internalformat, width, height, depth, border, format, type, srcData)
        GLenum_GLint_GLint_GLsizei_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView?: struct {
            target: anyopaque,
            level: anyopaque,
            internalformat: anyopaque,
            width: anyopaque,
            height: anyopaque,
            depth: anyopaque,
            border: anyopaque,
            format: anyopaque,
            type_: anyopaque,
            srcData: anyopaque,
        },
        /// texImage3D(target, level, internalformat, width, height, depth, border, format, type, srcData, srcOffset)
        GLenum_GLint_GLint_GLsizei_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView_long long: struct {
            target: anyopaque,
            level: anyopaque,
            internalformat: anyopaque,
            width: anyopaque,
            height: anyopaque,
            depth: anyopaque,
            border: anyopaque,
            format: anyopaque,
            type_: anyopaque,
            srcData: anyopaque,
            srcOffset: u64,
        },
    };

    pub fn call_texImage3D(instance: *runtime.Instance, args: TexImage3DArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .GLenum_GLint_GLint_GLsizei_GLsizei_GLsizei_GLint_GLenum_GLenum_GLintptr => |a| return WebGL2RenderingContextImpl.GLenum_GLint_GLint_GLsizei_GLsizei_GLsizei_GLint_GLenum_GLenum_GLintptr(state, a.target, a.level, a.internalformat, a.width, a.height, a.depth, a.border, a.format, a.type_, a.pboOffset),
            .GLenum_GLint_GLint_GLsizei_GLsizei_GLsizei_GLint_GLenum_GLenum_TexImageSource => |a| return WebGL2RenderingContextImpl.GLenum_GLint_GLint_GLsizei_GLsizei_GLsizei_GLint_GLenum_GLenum_TexImageSource(state, a.target, a.level, a.internalformat, a.width, a.height, a.depth, a.border, a.format, a.type_, a.source),
            .GLenum_GLint_GLint_GLsizei_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView? => |a| return WebGL2RenderingContextImpl.GLenum_GLint_GLint_GLsizei_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView?(state, a.target, a.level, a.internalformat, a.width, a.height, a.depth, a.border, a.format, a.type_, a.srcData),
            .GLenum_GLint_GLint_GLsizei_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView_long long => |a| return WebGL2RenderingContextImpl.GLenum_GLint_GLint_GLsizei_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView_long long(state, a.target, a.level, a.internalformat, a.width, a.height, a.depth, a.border, a.format, a.type_, a.srcData, a.srcOffset),
        }
    }

    pub fn call_texStorage2D(instance: *runtime.Instance, target: anyopaque, levels: anyopaque, internalformat: anyopaque, width: anyopaque, height: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_texStorage2D(state, target, levels, internalformat, width, height);
    }

    pub fn call_clientWaitSync(instance: *runtime.Instance, sync: anyopaque, flags: anyopaque, timeout: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_clientWaitSync(state, sync, flags, timeout);
    }

    pub fn call_uniform3fv(instance: *runtime.Instance, location: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniform3fv(state, location, data, srcOffset, srcLength);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_getContextAttributes(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebGL2RenderingContextImpl.call_getContextAttributes(state);
    }

    pub fn call_uniformMatrix2x3fv(instance: *runtime.Instance, location: anyopaque, transpose: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniformMatrix2x3fv(state, location, transpose, data, srcOffset, srcLength);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_isRenderbuffer(instance: *runtime.Instance, renderbuffer: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_isRenderbuffer(state, renderbuffer);
    }

    pub fn call_uniformMatrix2fv(instance: *runtime.Instance, location: anyopaque, transpose: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniformMatrix2fv(state, location, transpose, data, srcOffset, srcLength);
    }

    pub fn call_uniform4fv(instance: *runtime.Instance, location: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniform4fv(state, location, data, srcOffset, srcLength);
    }

    pub fn call_deleteTexture(instance: *runtime.Instance, texture: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_deleteTexture(state, texture);
    }

    pub fn call_getShaderSource(instance: *runtime.Instance, shader: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getShaderSource(state, shader);
    }

    pub fn call_clearBufferiv(instance: *runtime.Instance, buffer: anyopaque, drawbuffer: anyopaque, values: anyopaque, srcOffset: u64) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_clearBufferiv(state, buffer, drawbuffer, values, srcOffset);
    }

    pub fn call_vertexAttribI4i(instance: *runtime.Instance, index: anyopaque, x: anyopaque, y: anyopaque, z: anyopaque, w: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_vertexAttribI4i(state, index, x, y, z, w);
    }

    pub fn call_bindSampler(instance: *runtime.Instance, unit: anyopaque, sampler: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_bindSampler(state, unit, sampler);
    }

    pub fn call_vertexAttribI4uiv(instance: *runtime.Instance, index: anyopaque, values: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_vertexAttribI4uiv(state, index, values);
    }

    pub fn call_depthMask(instance: *runtime.Instance, flag: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_depthMask(state, flag);
    }

    pub fn call_drawElements(instance: *runtime.Instance, mode: anyopaque, count: anyopaque, type_: anyopaque, offset: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_drawElements(state, mode, count, type_, offset);
    }

    pub fn call_drawBuffers(instance: *runtime.Instance, buffers: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_drawBuffers(state, buffers);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_isShader(instance: *runtime.Instance, shader: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_isShader(state, shader);
    }

    pub fn call_getParameter(instance: *runtime.Instance, pname: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getParameter(state, pname);
    }

    pub fn call_getBufferSubData(instance: *runtime.Instance, target: anyopaque, srcByteOffset: anyopaque, dstBuffer: anyopaque, dstOffset: u64, length: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getBufferSubData(state, target, srcByteOffset, dstBuffer, dstOffset, length);
    }

    pub fn call_drawingBufferStorage(instance: *runtime.Instance, sizedFormat: anyopaque, width: u32, height: u32) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_drawingBufferStorage(state, sizedFormat, width, height);
    }

    pub fn call_uniform3iv(instance: *runtime.Instance, location: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniform3iv(state, location, data, srcOffset, srcLength);
    }

    pub fn call_renderbufferStorage(instance: *runtime.Instance, target: anyopaque, internalformat: anyopaque, width: anyopaque, height: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_renderbufferStorage(state, target, internalformat, width, height);
    }

    pub fn call_bindTransformFeedback(instance: *runtime.Instance, target: anyopaque, tf: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_bindTransformFeedback(state, target, tf);
    }

    pub fn call_getVertexAttrib(instance: *runtime.Instance, index: anyopaque, pname: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getVertexAttrib(state, index, pname);
    }

    pub fn call_blendFuncSeparate(instance: *runtime.Instance, srcRGB: anyopaque, dstRGB: anyopaque, srcAlpha: anyopaque, dstAlpha: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_blendFuncSeparate(state, srcRGB, dstRGB, srcAlpha, dstAlpha);
    }

    /// Arguments for texSubImage2D (WebIDL overloading)
    pub const TexSubImage2DArgs = union(enum) {
        /// texSubImage2D(target, level, xoffset, yoffset, width, height, format, type, pixels)
        GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView?: struct {
            target: anyopaque,
            level: anyopaque,
            xoffset: anyopaque,
            yoffset: anyopaque,
            width: anyopaque,
            height: anyopaque,
            format: anyopaque,
            type_: anyopaque,
            pixels: anyopaque,
        },
        /// texSubImage2D(target, level, xoffset, yoffset, format, type, source)
        GLenum_GLint_GLint_GLint_GLenum_GLenum_TexImageSource: struct {
            target: anyopaque,
            level: anyopaque,
            xoffset: anyopaque,
            yoffset: anyopaque,
            format: anyopaque,
            type_: anyopaque,
            source: anyopaque,
        },
        /// texSubImage2D(target, level, xoffset, yoffset, width, height, format, type, pboOffset)
        GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_GLintptr: struct {
            target: anyopaque,
            level: anyopaque,
            xoffset: anyopaque,
            yoffset: anyopaque,
            width: anyopaque,
            height: anyopaque,
            format: anyopaque,
            type_: anyopaque,
            pboOffset: anyopaque,
        },
        /// texSubImage2D(target, level, xoffset, yoffset, width, height, format, type, source)
        GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_TexImageSource: struct {
            target: anyopaque,
            level: anyopaque,
            xoffset: anyopaque,
            yoffset: anyopaque,
            width: anyopaque,
            height: anyopaque,
            format: anyopaque,
            type_: anyopaque,
            source: anyopaque,
        },
        /// texSubImage2D(target, level, xoffset, yoffset, width, height, format, type, srcData, srcOffset)
        GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView_long long: struct {
            target: anyopaque,
            level: anyopaque,
            xoffset: anyopaque,
            yoffset: anyopaque,
            width: anyopaque,
            height: anyopaque,
            format: anyopaque,
            type_: anyopaque,
            srcData: anyopaque,
            srcOffset: u64,
        },
    };

    pub fn call_texSubImage2D(instance: *runtime.Instance, args: TexSubImage2DArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView? => |a| return WebGL2RenderingContextImpl.GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView?(state, a.target, a.level, a.xoffset, a.yoffset, a.width, a.height, a.format, a.type_, a.pixels),
            .GLenum_GLint_GLint_GLint_GLenum_GLenum_TexImageSource => |a| return WebGL2RenderingContextImpl.GLenum_GLint_GLint_GLint_GLenum_GLenum_TexImageSource(state, a.target, a.level, a.xoffset, a.yoffset, a.format, a.type_, a.source),
            .GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_GLintptr => |a| return WebGL2RenderingContextImpl.GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_GLintptr(state, a.target, a.level, a.xoffset, a.yoffset, a.width, a.height, a.format, a.type_, a.pboOffset),
            .GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_TexImageSource => |a| return WebGL2RenderingContextImpl.GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_TexImageSource(state, a.target, a.level, a.xoffset, a.yoffset, a.width, a.height, a.format, a.type_, a.source),
            .GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView_long long => |a| return WebGL2RenderingContextImpl.GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView_long long(state, a.target, a.level, a.xoffset, a.yoffset, a.width, a.height, a.format, a.type_, a.srcData, a.srcOffset),
        }
    }

    pub fn call_getTransformFeedbackVarying(instance: *runtime.Instance, program: anyopaque, index: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getTransformFeedbackVarying(state, program, index);
    }

    pub fn call_clearColor(instance: *runtime.Instance, red: anyopaque, green: anyopaque, blue: anyopaque, alpha: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_clearColor(state, red, green, blue, alpha);
    }

    pub fn call_deleteRenderbuffer(instance: *runtime.Instance, renderbuffer: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_deleteRenderbuffer(state, renderbuffer);
    }

    pub fn call_activeTexture(instance: *runtime.Instance, texture: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_activeTexture(state, texture);
    }

    /// Arguments for compressedTexImage3D (WebIDL overloading)
    pub const CompressedTexImage3DArgs = union(enum) {
        /// compressedTexImage3D(target, level, internalformat, width, height, depth, border, imageSize, offset)
        GLenum_GLint_GLenum_GLsizei_GLsizei_GLsizei_GLint_GLsizei_GLintptr: struct {
            target: anyopaque,
            level: anyopaque,
            internalformat: anyopaque,
            width: anyopaque,
            height: anyopaque,
            depth: anyopaque,
            border: anyopaque,
            imageSize: anyopaque,
            offset: anyopaque,
        },
        /// compressedTexImage3D(target, level, internalformat, width, height, depth, border, srcData, srcOffset, srcLengthOverride)
        GLenum_GLint_GLenum_GLsizei_GLsizei_GLsizei_GLint_ArrayBufferView_long long_GLuint: struct {
            target: anyopaque,
            level: anyopaque,
            internalformat: anyopaque,
            width: anyopaque,
            height: anyopaque,
            depth: anyopaque,
            border: anyopaque,
            srcData: anyopaque,
            srcOffset: u64,
            srcLengthOverride: anyopaque,
        },
    };

    pub fn call_compressedTexImage3D(instance: *runtime.Instance, args: CompressedTexImage3DArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .GLenum_GLint_GLenum_GLsizei_GLsizei_GLsizei_GLint_GLsizei_GLintptr => |a| return WebGL2RenderingContextImpl.GLenum_GLint_GLenum_GLsizei_GLsizei_GLsizei_GLint_GLsizei_GLintptr(state, a.target, a.level, a.internalformat, a.width, a.height, a.depth, a.border, a.imageSize, a.offset),
            .GLenum_GLint_GLenum_GLsizei_GLsizei_GLsizei_GLint_ArrayBufferView_long long_GLuint => |a| return WebGL2RenderingContextImpl.GLenum_GLint_GLenum_GLsizei_GLsizei_GLsizei_GLint_ArrayBufferView_long long_GLuint(state, a.target, a.level, a.internalformat, a.width, a.height, a.depth, a.border, a.srcData, a.srcOffset, a.srcLengthOverride),
        }
    }

    pub fn call_createProgram(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebGL2RenderingContextImpl.call_createProgram(state);
    }

    pub fn call_uniform2uiv(instance: *runtime.Instance, location: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniform2uiv(state, location, data, srcOffset, srcLength);
    }

    pub fn call_getProgramInfoLog(instance: *runtime.Instance, program: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getProgramInfoLog(state, program);
    }

    pub fn call_uniform1fv(instance: *runtime.Instance, location: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniform1fv(state, location, data, srcOffset, srcLength);
    }

    pub fn call_deleteProgram(instance: *runtime.Instance, program: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_deleteProgram(state, program);
    }

    pub fn call_uniform1uiv(instance: *runtime.Instance, location: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniform1uiv(state, location, data, srcOffset, srcLength);
    }

    pub fn call_bindBufferRange(instance: *runtime.Instance, target: anyopaque, index: anyopaque, buffer: anyopaque, offset: anyopaque, size: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_bindBufferRange(state, target, index, buffer, offset, size);
    }

    pub fn call_texStorage3D(instance: *runtime.Instance, target: anyopaque, levels: anyopaque, internalformat: anyopaque, width: anyopaque, height: anyopaque, depth: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_texStorage3D(state, target, levels, internalformat, width, height, depth);
    }

    pub fn call_frontFace(instance: *runtime.Instance, mode: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_frontFace(state, mode);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_isBuffer(instance: *runtime.Instance, buffer: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_isBuffer(state, buffer);
    }

    pub fn call_bindTexture(instance: *runtime.Instance, target: anyopaque, texture: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_bindTexture(state, target, texture);
    }

    pub fn call_uniform3f(instance: *runtime.Instance, location: anyopaque, x: anyopaque, y: anyopaque, z: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniform3f(state, location, x, y, z);
    }

    pub fn call_blendEquation(instance: *runtime.Instance, mode: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_blendEquation(state, mode);
    }

    pub fn call_enableVertexAttribArray(instance: *runtime.Instance, index: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_enableVertexAttribArray(state, index);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_isFramebuffer(instance: *runtime.Instance, framebuffer: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_isFramebuffer(state, framebuffer);
    }

    pub fn call_finish(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebGL2RenderingContextImpl.call_finish(state);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_checkFramebufferStatus(instance: *runtime.Instance, target: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_checkFramebufferStatus(state, target);
    }

    pub fn call_getRenderbufferParameter(instance: *runtime.Instance, target: anyopaque, pname: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getRenderbufferParameter(state, target, pname);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_isTexture(instance: *runtime.Instance, texture: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_isTexture(state, texture);
    }

    pub fn call_linkProgram(instance: *runtime.Instance, program: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_linkProgram(state, program);
    }

    pub fn call_framebufferRenderbuffer(instance: *runtime.Instance, target: anyopaque, attachment: anyopaque, renderbuffertarget: anyopaque, renderbuffer: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_framebufferRenderbuffer(state, target, attachment, renderbuffertarget, renderbuffer);
    }

    pub fn call_getActiveUniform(instance: *runtime.Instance, program: anyopaque, index: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getActiveUniform(state, program, index);
    }

    pub fn call_vertexAttrib1f(instance: *runtime.Instance, index: anyopaque, x: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_vertexAttrib1f(state, index, x);
    }

    pub fn call_getShaderInfoLog(instance: *runtime.Instance, shader: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getShaderInfoLog(state, shader);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_isContextLost(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return WebGL2RenderingContextImpl.call_isContextLost(state);
    }

    pub fn call_deleteFramebuffer(instance: *runtime.Instance, framebuffer: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_deleteFramebuffer(state, framebuffer);
    }

    pub fn call_uniform2ui(instance: *runtime.Instance, location: anyopaque, v0: anyopaque, v1: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniform2ui(state, location, v0, v1);
    }

    pub fn call_uniformMatrix4x3fv(instance: *runtime.Instance, location: anyopaque, transpose: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniformMatrix4x3fv(state, location, transpose, data, srcOffset, srcLength);
    }

    pub fn call_getUniformBlockIndex(instance: *runtime.Instance, program: anyopaque, uniformBlockName: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getUniformBlockIndex(state, program, uniformBlockName);
    }

    /// Arguments for compressedTexSubImage2D (WebIDL overloading)
    pub const CompressedTexSubImage2DArgs = union(enum) {
        /// compressedTexSubImage2D(target, level, xoffset, yoffset, width, height, format, imageSize, offset)
        GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLsizei_GLintptr: struct {
            target: anyopaque,
            level: anyopaque,
            xoffset: anyopaque,
            yoffset: anyopaque,
            width: anyopaque,
            height: anyopaque,
            format: anyopaque,
            imageSize: anyopaque,
            offset: anyopaque,
        },
        /// compressedTexSubImage2D(target, level, xoffset, yoffset, width, height, format, srcData, srcOffset, srcLengthOverride)
        GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_ArrayBufferView_long long_GLuint: struct {
            target: anyopaque,
            level: anyopaque,
            xoffset: anyopaque,
            yoffset: anyopaque,
            width: anyopaque,
            height: anyopaque,
            format: anyopaque,
            srcData: anyopaque,
            srcOffset: u64,
            srcLengthOverride: anyopaque,
        },
    };

    pub fn call_compressedTexSubImage2D(instance: *runtime.Instance, args: CompressedTexSubImage2DArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLsizei_GLintptr => |a| return WebGL2RenderingContextImpl.GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLsizei_GLintptr(state, a.target, a.level, a.xoffset, a.yoffset, a.width, a.height, a.format, a.imageSize, a.offset),
            .GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_ArrayBufferView_long long_GLuint => |a| return WebGL2RenderingContextImpl.GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_ArrayBufferView_long long_GLuint(state, a.target, a.level, a.xoffset, a.yoffset, a.width, a.height, a.format, a.srcData, a.srcOffset, a.srcLengthOverride),
        }
    }

    pub fn call_bindAttribLocation(instance: *runtime.Instance, program: anyopaque, index: anyopaque, name: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_bindAttribLocation(state, program, index, name);
    }

    pub fn call_getUniformLocation(instance: *runtime.Instance, program: anyopaque, name: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getUniformLocation(state, program, name);
    }

    pub fn call_uniform4iv(instance: *runtime.Instance, location: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniform4iv(state, location, data, srcOffset, srcLength);
    }

    pub fn call_bindBufferBase(instance: *runtime.Instance, target: anyopaque, index: anyopaque, buffer: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_bindBufferBase(state, target, index, buffer);
    }

    pub fn call_getExtension(instance: *runtime.Instance, name: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getExtension(state, name);
    }

    pub fn call_colorMask(instance: *runtime.Instance, red: anyopaque, green: anyopaque, blue: anyopaque, alpha: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_colorMask(state, red, green, blue, alpha);
    }

    pub fn call_cullFace(instance: *runtime.Instance, mode: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_cullFace(state, mode);
    }

    pub fn call_deleteShader(instance: *runtime.Instance, shader: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_deleteShader(state, shader);
    }

    pub fn call_vertexAttrib4fv(instance: *runtime.Instance, index: anyopaque, values: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_vertexAttrib4fv(state, index, values);
    }

    pub fn call_disableVertexAttribArray(instance: *runtime.Instance, index: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_disableVertexAttribArray(state, index);
    }

    pub fn call_uniformMatrix4x2fv(instance: *runtime.Instance, location: anyopaque, transpose: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniformMatrix4x2fv(state, location, transpose, data, srcOffset, srcLength);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_getAttribLocation(instance: *runtime.Instance, program: anyopaque, name: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getAttribLocation(state, program, name);
    }

    pub fn call_drawArraysInstanced(instance: *runtime.Instance, mode: anyopaque, first: anyopaque, count: anyopaque, instanceCount: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_drawArraysInstanced(state, mode, first, count, instanceCount);
    }

    pub fn call_uniform3i(instance: *runtime.Instance, location: anyopaque, x: anyopaque, y: anyopaque, z: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniform3i(state, location, x, y, z);
    }

    pub fn call_uniform2i(instance: *runtime.Instance, location: anyopaque, x: anyopaque, y: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniform2i(state, location, x, y);
    }

    pub fn call_vertexAttrib1fv(instance: *runtime.Instance, index: anyopaque, values: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_vertexAttrib1fv(state, index, values);
    }

    /// Arguments for bufferSubData (WebIDL overloading)
    pub const BufferSubDataArgs = union(enum) {
        /// bufferSubData(target, dstByteOffset, srcData)
        GLenum_GLintptr_AllowSharedBufferSource: struct {
            target: anyopaque,
            dstByteOffset: anyopaque,
            srcData: anyopaque,
        },
        /// bufferSubData(target, dstByteOffset, srcData, srcOffset, length)
        GLenum_GLintptr_ArrayBufferView_long long_GLuint: struct {
            target: anyopaque,
            dstByteOffset: anyopaque,
            srcData: anyopaque,
            srcOffset: u64,
            length: anyopaque,
        },
    };

    pub fn call_bufferSubData(instance: *runtime.Instance, args: BufferSubDataArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .GLenum_GLintptr_AllowSharedBufferSource => |a| return WebGL2RenderingContextImpl.GLenum_GLintptr_AllowSharedBufferSource(state, a.target, a.dstByteOffset, a.srcData),
            .GLenum_GLintptr_ArrayBufferView_long long_GLuint => |a| return WebGL2RenderingContextImpl.GLenum_GLintptr_ArrayBufferView_long long_GLuint(state, a.target, a.dstByteOffset, a.srcData, a.srcOffset, a.length),
        }
    }

    pub fn call_scissor(instance: *runtime.Instance, x: anyopaque, y: anyopaque, width: anyopaque, height: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_scissor(state, x, y, width, height);
    }

    pub fn call_vertexAttribI4iv(instance: *runtime.Instance, index: anyopaque, values: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_vertexAttribI4iv(state, index, values);
    }

    pub fn call_getShaderParameter(instance: *runtime.Instance, shader: anyopaque, pname: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getShaderParameter(state, shader, pname);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_isProgram(instance: *runtime.Instance, program: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_isProgram(state, program);
    }

    pub fn call_uniformMatrix3x4fv(instance: *runtime.Instance, location: anyopaque, transpose: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniformMatrix3x4fv(state, location, transpose, data, srcOffset, srcLength);
    }

    pub fn call_lineWidth(instance: *runtime.Instance, width: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_lineWidth(state, width);
    }

    pub fn call_uniform1ui(instance: *runtime.Instance, location: anyopaque, v0: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniform1ui(state, location, v0);
    }

    pub fn call_uniform1i(instance: *runtime.Instance, location: anyopaque, x: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniform1i(state, location, x);
    }

    pub fn call_getShaderPrecisionFormat(instance: *runtime.Instance, shadertype: anyopaque, precisiontype: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getShaderPrecisionFormat(state, shadertype, precisiontype);
    }

    pub fn call_samplerParameterf(instance: *runtime.Instance, sampler: anyopaque, pname: anyopaque, param: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_samplerParameterf(state, sampler, pname, param);
    }

    pub fn call_texParameterf(instance: *runtime.Instance, target: anyopaque, pname: anyopaque, param: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_texParameterf(state, target, pname, param);
    }

    pub fn call_copyBufferSubData(instance: *runtime.Instance, readTarget: anyopaque, writeTarget: anyopaque, readOffset: anyopaque, writeOffset: anyopaque, size: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_copyBufferSubData(state, readTarget, writeTarget, readOffset, writeOffset, size);
    }

    pub fn call_sampleCoverage(instance: *runtime.Instance, value: anyopaque, invert: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_sampleCoverage(state, value, invert);
    }

    pub fn call_uniform1iv(instance: *runtime.Instance, location: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniform1iv(state, location, data, srcOffset, srcLength);
    }

    pub fn call_uniformMatrix4fv(instance: *runtime.Instance, location: anyopaque, transpose: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniformMatrix4fv(state, location, transpose, data, srcOffset, srcLength);
    }

    pub fn call_getAttachedShaders(instance: *runtime.Instance, program: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getAttachedShaders(state, program);
    }

    pub fn call_createFramebuffer(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebGL2RenderingContextImpl.call_createFramebuffer(state);
    }

    pub fn call_createTexture(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebGL2RenderingContextImpl.call_createTexture(state);
    }

    pub fn call_vertexAttrib4f(instance: *runtime.Instance, index: anyopaque, x: anyopaque, y: anyopaque, z: anyopaque, w: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_vertexAttrib4f(state, index, x, y, z, w);
    }

    pub fn call_uniform4f(instance: *runtime.Instance, location: anyopaque, x: anyopaque, y: anyopaque, z: anyopaque, w: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniform4f(state, location, x, y, z, w);
    }

    pub fn call_createTransformFeedback(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebGL2RenderingContextImpl.call_createTransformFeedback(state);
    }

    pub fn call_getQuery(instance: *runtime.Instance, target: anyopaque, pname: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getQuery(state, target, pname);
    }

    pub fn call_stencilOpSeparate(instance: *runtime.Instance, face: anyopaque, fail: anyopaque, zfail: anyopaque, zpass: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_stencilOpSeparate(state, face, fail, zfail, zpass);
    }

    pub fn call_endTransformFeedback(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebGL2RenderingContextImpl.call_endTransformFeedback(state);
    }

    pub fn call_generateMipmap(instance: *runtime.Instance, target: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_generateMipmap(state, target);
    }

    pub fn call_getUniformIndices(instance: *runtime.Instance, program: anyopaque, uniformNames: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getUniformIndices(state, program, uniformNames);
    }

    pub fn call_clearBufferfi(instance: *runtime.Instance, buffer: anyopaque, drawbuffer: anyopaque, depth: anyopaque, stencil: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_clearBufferfi(state, buffer, drawbuffer, depth, stencil);
    }

    pub fn call_getFramebufferAttachmentParameter(instance: *runtime.Instance, target: anyopaque, attachment: anyopaque, pname: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getFramebufferAttachmentParameter(state, target, attachment, pname);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_isEnabled(instance: *runtime.Instance, cap: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_isEnabled(state, cap);
    }

    pub fn call_copyTexSubImage2D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, xoffset: anyopaque, yoffset: anyopaque, x: anyopaque, y: anyopaque, width: anyopaque, height: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_copyTexSubImage2D(state, target, level, xoffset, yoffset, x, y, width, height);
    }

    pub fn call_fenceSync(instance: *runtime.Instance, condition: anyopaque, flags: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_fenceSync(state, condition, flags);
    }

    pub fn call_vertexAttrib2f(instance: *runtime.Instance, index: anyopaque, x: anyopaque, y: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_vertexAttrib2f(state, index, x, y);
    }

    pub fn call_clear(instance: *runtime.Instance, mask: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_clear(state, mask);
    }

    pub fn call_copyTexSubImage3D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, xoffset: anyopaque, yoffset: anyopaque, zoffset: anyopaque, x: anyopaque, y: anyopaque, width: anyopaque, height: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_copyTexSubImage3D(state, target, level, xoffset, yoffset, zoffset, x, y, width, height);
    }

    /// Arguments for texSubImage3D (WebIDL overloading)
    pub const TexSubImage3DArgs = union(enum) {
        /// texSubImage3D(target, level, xoffset, yoffset, zoffset, width, height, depth, format, type, pboOffset)
        GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_GLenum_GLintptr: struct {
            target: anyopaque,
            level: anyopaque,
            xoffset: anyopaque,
            yoffset: anyopaque,
            zoffset: anyopaque,
            width: anyopaque,
            height: anyopaque,
            depth: anyopaque,
            format: anyopaque,
            type_: anyopaque,
            pboOffset: anyopaque,
        },
        /// texSubImage3D(target, level, xoffset, yoffset, zoffset, width, height, depth, format, type, source)
        GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_GLenum_TexImageSource: struct {
            target: anyopaque,
            level: anyopaque,
            xoffset: anyopaque,
            yoffset: anyopaque,
            zoffset: anyopaque,
            width: anyopaque,
            height: anyopaque,
            depth: anyopaque,
            format: anyopaque,
            type_: anyopaque,
            source: anyopaque,
        },
        /// texSubImage3D(target, level, xoffset, yoffset, zoffset, width, height, depth, format, type, srcData, srcOffset)
        GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView?_long long: struct {
            target: anyopaque,
            level: anyopaque,
            xoffset: anyopaque,
            yoffset: anyopaque,
            zoffset: anyopaque,
            width: anyopaque,
            height: anyopaque,
            depth: anyopaque,
            format: anyopaque,
            type_: anyopaque,
            srcData: anyopaque,
            srcOffset: u64,
        },
    };

    pub fn call_texSubImage3D(instance: *runtime.Instance, args: TexSubImage3DArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_GLenum_GLintptr => |a| return WebGL2RenderingContextImpl.GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_GLenum_GLintptr(state, a.target, a.level, a.xoffset, a.yoffset, a.zoffset, a.width, a.height, a.depth, a.format, a.type_, a.pboOffset),
            .GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_GLenum_TexImageSource => |a| return WebGL2RenderingContextImpl.GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_GLenum_TexImageSource(state, a.target, a.level, a.xoffset, a.yoffset, a.zoffset, a.width, a.height, a.depth, a.format, a.type_, a.source),
            .GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView?_long long => |a| return WebGL2RenderingContextImpl.GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView?_long long(state, a.target, a.level, a.xoffset, a.yoffset, a.zoffset, a.width, a.height, a.depth, a.format, a.type_, a.srcData, a.srcOffset),
        }
    }

    pub fn call_uniform2fv(instance: *runtime.Instance, location: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniform2fv(state, location, data, srcOffset, srcLength);
    }

    pub fn call_disable(instance: *runtime.Instance, cap: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_disable(state, cap);
    }

    pub fn call_framebufferTextureLayer(instance: *runtime.Instance, target: anyopaque, attachment: anyopaque, texture: anyopaque, level: anyopaque, layer: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_framebufferTextureLayer(state, target, attachment, texture, level, layer);
    }

    pub fn call_endQuery(instance: *runtime.Instance, target: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_endQuery(state, target);
    }

    pub fn call_compileShader(instance: *runtime.Instance, shader: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_compileShader(state, shader);
    }

    pub fn call_drawElementsInstanced(instance: *runtime.Instance, mode: anyopaque, count: anyopaque, type_: anyopaque, offset: anyopaque, instanceCount: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_drawElementsInstanced(state, mode, count, type_, offset, instanceCount);
    }

    pub fn call_blendEquationSeparate(instance: *runtime.Instance, modeRGB: anyopaque, modeAlpha: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_blendEquationSeparate(state, modeRGB, modeAlpha);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_isSampler(instance: *runtime.Instance, sampler: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_isSampler(state, sampler);
    }

    pub fn call_getSamplerParameter(instance: *runtime.Instance, sampler: anyopaque, pname: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getSamplerParameter(state, sampler, pname);
    }

    pub fn call_depthRange(instance: *runtime.Instance, zNear: anyopaque, zFar: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_depthRange(state, zNear, zFar);
    }

    pub fn call_getActiveUniformBlockName(instance: *runtime.Instance, program: anyopaque, uniformBlockIndex: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getActiveUniformBlockName(state, program, uniformBlockIndex);
    }

    pub fn call_polygonOffset(instance: *runtime.Instance, factor: anyopaque, units: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_polygonOffset(state, factor, units);
    }

    pub fn call_vertexAttribI4ui(instance: *runtime.Instance, index: anyopaque, x: anyopaque, y: anyopaque, z: anyopaque, w: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_vertexAttribI4ui(state, index, x, y, z, w);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_isVertexArray(instance: *runtime.Instance, vertexArray: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_isVertexArray(state, vertexArray);
    }

    pub fn call_bindBuffer(instance: *runtime.Instance, target: anyopaque, buffer: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_bindBuffer(state, target, buffer);
    }

    /// Extended attributes: [NewObject]
    pub fn call_makeXRCompatible(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return WebGL2RenderingContextImpl.call_makeXRCompatible(state);
    }

    pub fn call_getQueryParameter(instance: *runtime.Instance, query: anyopaque, pname: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getQueryParameter(state, query, pname);
    }

    pub fn call_uniformMatrix3x2fv(instance: *runtime.Instance, location: anyopaque, transpose: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniformMatrix3x2fv(state, location, transpose, data, srcOffset, srcLength);
    }

    pub fn call_deleteQuery(instance: *runtime.Instance, query: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_deleteQuery(state, query);
    }

    pub fn call_getSupportedExtensions(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebGL2RenderingContextImpl.call_getSupportedExtensions(state);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_isSync(instance: *runtime.Instance, sync: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_isSync(state, sync);
    }

    /// Arguments for compressedTexImage2D (WebIDL overloading)
    pub const CompressedTexImage2DArgs = union(enum) {
        /// compressedTexImage2D(target, level, internalformat, width, height, border, imageSize, offset)
        GLenum_GLint_GLenum_GLsizei_GLsizei_GLint_GLsizei_GLintptr: struct {
            target: anyopaque,
            level: anyopaque,
            internalformat: anyopaque,
            width: anyopaque,
            height: anyopaque,
            border: anyopaque,
            imageSize: anyopaque,
            offset: anyopaque,
        },
        /// compressedTexImage2D(target, level, internalformat, width, height, border, srcData, srcOffset, srcLengthOverride)
        GLenum_GLint_GLenum_GLsizei_GLsizei_GLint_ArrayBufferView_long long_GLuint: struct {
            target: anyopaque,
            level: anyopaque,
            internalformat: anyopaque,
            width: anyopaque,
            height: anyopaque,
            border: anyopaque,
            srcData: anyopaque,
            srcOffset: u64,
            srcLengthOverride: anyopaque,
        },
    };

    pub fn call_compressedTexImage2D(instance: *runtime.Instance, args: CompressedTexImage2DArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .GLenum_GLint_GLenum_GLsizei_GLsizei_GLint_GLsizei_GLintptr => |a| return WebGL2RenderingContextImpl.GLenum_GLint_GLenum_GLsizei_GLsizei_GLint_GLsizei_GLintptr(state, a.target, a.level, a.internalformat, a.width, a.height, a.border, a.imageSize, a.offset),
            .GLenum_GLint_GLenum_GLsizei_GLsizei_GLint_ArrayBufferView_long long_GLuint => |a| return WebGL2RenderingContextImpl.GLenum_GLint_GLenum_GLsizei_GLsizei_GLint_ArrayBufferView_long long_GLuint(state, a.target, a.level, a.internalformat, a.width, a.height, a.border, a.srcData, a.srcOffset, a.srcLengthOverride),
        }
    }

    pub fn call_clearStencil(instance: *runtime.Instance, s: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_clearStencil(state, s);
    }

    pub fn call_enable(instance: *runtime.Instance, cap: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_enable(state, cap);
    }

    pub fn call_shaderSource(instance: *runtime.Instance, shader: anyopaque, source: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_shaderSource(state, shader, source);
    }

    pub fn call_clearDepth(instance: *runtime.Instance, depth: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_clearDepth(state, depth);
    }

    pub fn call_detachShader(instance: *runtime.Instance, program: anyopaque, shader: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_detachShader(state, program, shader);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_getError(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebGL2RenderingContextImpl.call_getError(state);
    }

    pub fn call_vertexAttrib3fv(instance: *runtime.Instance, index: anyopaque, values: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_vertexAttrib3fv(state, index, values);
    }

    pub fn call_stencilFunc(instance: *runtime.Instance, func: anyopaque, ref: anyopaque, mask: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_stencilFunc(state, func, ref, mask);
    }

    pub fn call_getActiveUniformBlockParameter(instance: *runtime.Instance, program: anyopaque, uniformBlockIndex: anyopaque, pname: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getActiveUniformBlockParameter(state, program, uniformBlockIndex, pname);
    }

    pub fn call_framebufferTexture2D(instance: *runtime.Instance, target: anyopaque, attachment: anyopaque, textarget: anyopaque, texture: anyopaque, level: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_framebufferTexture2D(state, target, attachment, textarget, texture, level);
    }

    pub fn call_invalidateFramebuffer(instance: *runtime.Instance, target: anyopaque, attachments: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_invalidateFramebuffer(state, target, attachments);
    }

    pub fn call_getIndexedParameter(instance: *runtime.Instance, target: anyopaque, index: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getIndexedParameter(state, target, index);
    }

    pub fn call_deleteVertexArray(instance: *runtime.Instance, vertexArray: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_deleteVertexArray(state, vertexArray);
    }

    pub fn call_createShader(instance: *runtime.Instance, type_: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_createShader(state, type_);
    }

    pub fn call_useProgram(instance: *runtime.Instance, program: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_useProgram(state, program);
    }

    pub fn call_uniform3ui(instance: *runtime.Instance, location: anyopaque, v0: anyopaque, v1: anyopaque, v2: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniform3ui(state, location, v0, v1, v2);
    }

    pub fn call_waitSync(instance: *runtime.Instance, sync: anyopaque, flags: anyopaque, timeout: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_waitSync(state, sync, flags, timeout);
    }

    /// Arguments for bufferData (WebIDL overloading)
    pub const BufferDataArgs = union(enum) {
        /// bufferData(target, size, usage)
        GLenum_GLsizeiptr_GLenum: struct {
            target: anyopaque,
            size: anyopaque,
            usage: anyopaque,
        },
        /// bufferData(target, srcData, usage)
        GLenum_AllowSharedBufferSource?_GLenum: struct {
            target: anyopaque,
            srcData: anyopaque,
            usage: anyopaque,
        },
        /// bufferData(target, srcData, usage, srcOffset, length)
        GLenum_ArrayBufferView_GLenum_long long_GLuint: struct {
            target: anyopaque,
            srcData: anyopaque,
            usage: anyopaque,
            srcOffset: u64,
            length: anyopaque,
        },
    };

    pub fn call_bufferData(instance: *runtime.Instance, args: BufferDataArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .GLenum_GLsizeiptr_GLenum => |a| return WebGL2RenderingContextImpl.GLenum_GLsizeiptr_GLenum(state, a.target, a.size, a.usage),
            .GLenum_AllowSharedBufferSource?_GLenum => |a| return WebGL2RenderingContextImpl.GLenum_AllowSharedBufferSource?_GLenum(state, a.target, a.srcData, a.usage),
            .GLenum_ArrayBufferView_GLenum_long long_GLuint => |a| return WebGL2RenderingContextImpl.GLenum_ArrayBufferView_GLenum_long long_GLuint(state, a.target, a.srcData, a.usage, a.srcOffset, a.length),
        }
    }

    pub fn call_getTexParameter(instance: *runtime.Instance, target: anyopaque, pname: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getTexParameter(state, target, pname);
    }

    pub fn call_blendColor(instance: *runtime.Instance, red: anyopaque, green: anyopaque, blue: anyopaque, alpha: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_blendColor(state, red, green, blue, alpha);
    }

    pub fn call_readBuffer(instance: *runtime.Instance, src: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_readBuffer(state, src);
    }

    pub fn call_clearBufferuiv(instance: *runtime.Instance, buffer: anyopaque, drawbuffer: anyopaque, values: anyopaque, srcOffset: u64) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_clearBufferuiv(state, buffer, drawbuffer, values, srcOffset);
    }

    pub fn call_renderbufferStorageMultisample(instance: *runtime.Instance, target: anyopaque, samples: anyopaque, internalformat: anyopaque, width: anyopaque, height: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_renderbufferStorageMultisample(state, target, samples, internalformat, width, height);
    }

    pub fn call_bindFramebuffer(instance: *runtime.Instance, target: anyopaque, framebuffer: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_bindFramebuffer(state, target, framebuffer);
    }

    pub fn call_stencilFuncSeparate(instance: *runtime.Instance, face: anyopaque, func: anyopaque, ref: anyopaque, mask: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_stencilFuncSeparate(state, face, func, ref, mask);
    }

    pub fn call_clearBufferfv(instance: *runtime.Instance, buffer: anyopaque, drawbuffer: anyopaque, values: anyopaque, srcOffset: u64) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_clearBufferfv(state, buffer, drawbuffer, values, srcOffset);
    }

    pub fn call_vertexAttrib3f(instance: *runtime.Instance, index: anyopaque, x: anyopaque, y: anyopaque, z: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_vertexAttrib3f(state, index, x, y, z);
    }

    pub fn call_transformFeedbackVaryings(instance: *runtime.Instance, program: anyopaque, varyings: anyopaque, bufferMode: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_transformFeedbackVaryings(state, program, varyings, bufferMode);
    }

    pub fn call_texParameteri(instance: *runtime.Instance, target: anyopaque, pname: anyopaque, param: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_texParameteri(state, target, pname, param);
    }

    pub fn call_pixelStorei(instance: *runtime.Instance, pname: anyopaque, param: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_pixelStorei(state, pname, param);
    }

    pub fn call_viewport(instance: *runtime.Instance, x: anyopaque, y: anyopaque, width: anyopaque, height: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_viewport(state, x, y, width, height);
    }

    pub fn call_invalidateSubFramebuffer(instance: *runtime.Instance, target: anyopaque, attachments: anyopaque, x: anyopaque, y: anyopaque, width: anyopaque, height: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_invalidateSubFramebuffer(state, target, attachments, x, y, width, height);
    }

    pub fn call_stencilOp(instance: *runtime.Instance, fail: anyopaque, zfail: anyopaque, zpass: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_stencilOp(state, fail, zfail, zpass);
    }

    pub fn call_deleteSampler(instance: *runtime.Instance, sampler: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_deleteSampler(state, sampler);
    }

    pub fn call_getSyncParameter(instance: *runtime.Instance, sync: anyopaque, pname: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getSyncParameter(state, sync, pname);
    }

    pub fn call_bindRenderbuffer(instance: *runtime.Instance, target: anyopaque, renderbuffer: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_bindRenderbuffer(state, target, renderbuffer);
    }

    pub fn call_depthFunc(instance: *runtime.Instance, func: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_depthFunc(state, func);
    }

    pub fn call_hint(instance: *runtime.Instance, target: anyopaque, mode: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_hint(state, target, mode);
    }

    pub fn call_blitFramebuffer(instance: *runtime.Instance, srcX0: anyopaque, srcY0: anyopaque, srcX1: anyopaque, srcY1: anyopaque, dstX0: anyopaque, dstY0: anyopaque, dstX1: anyopaque, dstY1: anyopaque, mask: anyopaque, filter: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_blitFramebuffer(state, srcX0, srcY0, srcX1, srcY1, dstX0, dstY0, dstX1, dstY1, mask, filter);
    }

    pub fn call_drawRangeElements(instance: *runtime.Instance, mode: anyopaque, start: anyopaque, end: anyopaque, count: anyopaque, type_: anyopaque, offset: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_drawRangeElements(state, mode, start, end, count, type_, offset);
    }

    pub fn call_uniform1f(instance: *runtime.Instance, location: anyopaque, x: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniform1f(state, location, x);
    }

    pub fn call_beginTransformFeedback(instance: *runtime.Instance, primitiveMode: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_beginTransformFeedback(state, primitiveMode);
    }

    pub fn call_bindVertexArray(instance: *runtime.Instance, array: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_bindVertexArray(state, array);
    }

    pub fn call_uniformMatrix3fv(instance: *runtime.Instance, location: anyopaque, transpose: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniformMatrix3fv(state, location, transpose, data, srcOffset, srcLength);
    }

    pub fn call_pauseTransformFeedback(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebGL2RenderingContextImpl.call_pauseTransformFeedback(state);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_isQuery(instance: *runtime.Instance, query: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_isQuery(state, query);
    }

    pub fn call_uniform3uiv(instance: *runtime.Instance, location: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniform3uiv(state, location, data, srcOffset, srcLength);
    }

    pub fn call_getProgramParameter(instance: *runtime.Instance, program: anyopaque, pname: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getProgramParameter(state, program, pname);
    }

    pub fn call_flush(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebGL2RenderingContextImpl.call_flush(state);
    }

    pub fn call_vertexAttrib2fv(instance: *runtime.Instance, index: anyopaque, values: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_vertexAttrib2fv(state, index, values);
    }

    pub fn call_getInternalformatParameter(instance: *runtime.Instance, target: anyopaque, internalformat: anyopaque, pname: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getInternalformatParameter(state, target, internalformat, pname);
    }

    pub fn call_uniform4uiv(instance: *runtime.Instance, location: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniform4uiv(state, location, data, srcOffset, srcLength);
    }

    pub fn call_createQuery(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebGL2RenderingContextImpl.call_createQuery(state);
    }

    pub fn call_uniform2f(instance: *runtime.Instance, location: anyopaque, x: anyopaque, y: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniform2f(state, location, x, y);
    }

    pub fn call_drawArrays(instance: *runtime.Instance, mode: anyopaque, first: anyopaque, count: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_drawArrays(state, mode, first, count);
    }

    pub fn call_validateProgram(instance: *runtime.Instance, program: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_validateProgram(state, program);
    }

    pub fn call_deleteSync(instance: *runtime.Instance, sync: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_deleteSync(state, sync);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_getFragDataLocation(instance: *runtime.Instance, program: anyopaque, name: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getFragDataLocation(state, program, name);
    }

    pub fn call_createBuffer(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebGL2RenderingContextImpl.call_createBuffer(state);
    }

    pub fn call_getActiveUniforms(instance: *runtime.Instance, program: anyopaque, uniformIndices: anyopaque, pname: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getActiveUniforms(state, program, uniformIndices, pname);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_getVertexAttribOffset(instance: *runtime.Instance, index: anyopaque, pname: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getVertexAttribOffset(state, index, pname);
    }

    /// Arguments for compressedTexSubImage3D (WebIDL overloading)
    pub const CompressedTexSubImage3DArgs = union(enum) {
        /// compressedTexSubImage3D(target, level, xoffset, yoffset, zoffset, width, height, depth, format, imageSize, offset)
        GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_GLsizei_GLintptr: struct {
            target: anyopaque,
            level: anyopaque,
            xoffset: anyopaque,
            yoffset: anyopaque,
            zoffset: anyopaque,
            width: anyopaque,
            height: anyopaque,
            depth: anyopaque,
            format: anyopaque,
            imageSize: anyopaque,
            offset: anyopaque,
        },
        /// compressedTexSubImage3D(target, level, xoffset, yoffset, zoffset, width, height, depth, format, srcData, srcOffset, srcLengthOverride)
        GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_ArrayBufferView_long long_GLuint: struct {
            target: anyopaque,
            level: anyopaque,
            xoffset: anyopaque,
            yoffset: anyopaque,
            zoffset: anyopaque,
            width: anyopaque,
            height: anyopaque,
            depth: anyopaque,
            format: anyopaque,
            srcData: anyopaque,
            srcOffset: u64,
            srcLengthOverride: anyopaque,
        },
    };

    pub fn call_compressedTexSubImage3D(instance: *runtime.Instance, args: CompressedTexSubImage3DArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_GLsizei_GLintptr => |a| return WebGL2RenderingContextImpl.GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_GLsizei_GLintptr(state, a.target, a.level, a.xoffset, a.yoffset, a.zoffset, a.width, a.height, a.depth, a.format, a.imageSize, a.offset),
            .GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_ArrayBufferView_long long_GLuint => |a| return WebGL2RenderingContextImpl.GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_ArrayBufferView_long long_GLuint(state, a.target, a.level, a.xoffset, a.yoffset, a.zoffset, a.width, a.height, a.depth, a.format, a.srcData, a.srcOffset, a.srcLengthOverride),
        }
    }

    pub fn call_uniform4i(instance: *runtime.Instance, location: anyopaque, x: anyopaque, y: anyopaque, z: anyopaque, w: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniform4i(state, location, x, y, z, w);
    }

    pub fn call_deleteBuffer(instance: *runtime.Instance, buffer: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_deleteBuffer(state, buffer);
    }

    pub fn call_stencilMask(instance: *runtime.Instance, mask: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_stencilMask(state, mask);
    }

    pub fn call_vertexAttribIPointer(instance: *runtime.Instance, index: anyopaque, size: anyopaque, type_: anyopaque, stride: anyopaque, offset: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_vertexAttribIPointer(state, index, size, type_, stride, offset);
    }

    pub fn call_samplerParameteri(instance: *runtime.Instance, sampler: anyopaque, pname: anyopaque, param: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_samplerParameteri(state, sampler, pname, param);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_isTransformFeedback(instance: *runtime.Instance, tf: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_isTransformFeedback(state, tf);
    }

    pub fn call_beginQuery(instance: *runtime.Instance, target: anyopaque, query: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_beginQuery(state, target, query);
    }

    pub fn call_createSampler(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebGL2RenderingContextImpl.call_createSampler(state);
    }

    pub fn call_deleteTransformFeedback(instance: *runtime.Instance, tf: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_deleteTransformFeedback(state, tf);
    }

    pub fn call_getBufferParameter(instance: *runtime.Instance, target: anyopaque, pname: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getBufferParameter(state, target, pname);
    }

    pub fn call_stencilMaskSeparate(instance: *runtime.Instance, face: anyopaque, mask: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_stencilMaskSeparate(state, face, mask);
    }

    pub fn call_uniformMatrix2x4fv(instance: *runtime.Instance, location: anyopaque, transpose: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniformMatrix2x4fv(state, location, transpose, data, srcOffset, srcLength);
    }

    pub fn call_copyTexImage2D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, internalformat: anyopaque, x: anyopaque, y: anyopaque, width: anyopaque, height: anyopaque, border: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_copyTexImage2D(state, target, level, internalformat, x, y, width, height, border);
    }

    pub fn call_uniform2iv(instance: *runtime.Instance, location: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_uniform2iv(state, location, data, srcOffset, srcLength);
    }

    pub fn call_attachShader(instance: *runtime.Instance, program: anyopaque, shader: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_attachShader(state, program, shader);
    }

    pub fn call_getUniform(instance: *runtime.Instance, program: anyopaque, location: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextImpl.call_getUniform(state, program, location);
    }

};
