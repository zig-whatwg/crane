//! Generated from: SVG.idl
//! Generated at: 2025-12-05T20:30:46Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SVGTransformImpl = @import("impls").SVGTransform;
const mixins = @import("mixins");
const DOMMatrix2DInit = @import("dictionaries").DOMMatrix2DInit;
const DOMMatrix = @import("interfaces").DOMMatrix;

pub const SVGTransform = struct {
    pub const Meta = struct {
        pub const name = "SVGTransform";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "type", "get_type", null },
            .{ "matrix", "get_matrix", null },
            .{ "angle", "get_angle", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "setMatrix", "call_setMatrix", 0 },
            .{ "setTranslate", "call_setTranslate", 2 },
            .{ "setScale", "call_setScale", 2 },
            .{ "setRotate", "call_setRotate", 3 },
            .{ "setSkewX", "call_setSkewX", 1 },
            .{ "setSkewY", "call_setSkewY", 1 },
        };

        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "SVG_TRANSFORM_UNKNOWN", "get_SVG_TRANSFORM_UNKNOWN" },
            .{ "SVG_TRANSFORM_MATRIX", "get_SVG_TRANSFORM_MATRIX" },
            .{ "SVG_TRANSFORM_TRANSLATE", "get_SVG_TRANSFORM_TRANSLATE" },
            .{ "SVG_TRANSFORM_SCALE", "get_SVG_TRANSFORM_SCALE" },
            .{ "SVG_TRANSFORM_ROTATE", "get_SVG_TRANSFORM_ROTATE" },
            .{ "SVG_TRANSFORM_SKEWX", "get_SVG_TRANSFORM_SKEWX" },
            .{ "SVG_TRANSFORM_SKEWY", "get_SVG_TRANSFORM_SKEWY" },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "setMatrix",
            "setTranslate",
            "setScale",
            "setRotate",
            "setSkewX",
            "setSkewY",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "type", "get_type", null },
            .{ "matrix", "get_matrix", null },
            .{ "angle", "get_angle", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            type: u16 = undefined,
            matrix: *runtime.Instance = undefined,
            angle: f32 = undefined,
            cached_matrix: ?*runtime.Instance = null,
            _internal: ?*SVGTransformImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short SVG_TRANSFORM_UNKNOWN = 0;
    pub fn get_SVG_TRANSFORM_UNKNOWN() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short SVG_TRANSFORM_MATRIX = 1;
    pub fn get_SVG_TRANSFORM_MATRIX() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short SVG_TRANSFORM_TRANSLATE = 2;
    pub fn get_SVG_TRANSFORM_TRANSLATE() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short SVG_TRANSFORM_SCALE = 3;
    pub fn get_SVG_TRANSFORM_SCALE() u16 {
        return 3;
    }

    /// WebIDL constant: const unsigned short SVG_TRANSFORM_ROTATE = 4;
    pub fn get_SVG_TRANSFORM_ROTATE() u16 {
        return 4;
    }

    /// WebIDL constant: const unsigned short SVG_TRANSFORM_SKEWX = 5;
    pub fn get_SVG_TRANSFORM_SKEWX() u16 {
        return 5;
    }

    /// WebIDL constant: const unsigned short SVG_TRANSFORM_SKEWY = 6;
    pub fn get_SVG_TRANSFORM_SKEWY() u16 {
        return 6;
    }

    const delegates = .{
        .get_SVG_TRANSFORM_MATRIX = &get_SVG_TRANSFORM_MATRIX,
        .get_SVG_TRANSFORM_ROTATE = &get_SVG_TRANSFORM_ROTATE,
        .get_SVG_TRANSFORM_SCALE = &get_SVG_TRANSFORM_SCALE,
        .get_SVG_TRANSFORM_SKEWX = &get_SVG_TRANSFORM_SKEWX,
        .get_SVG_TRANSFORM_SKEWY = &get_SVG_TRANSFORM_SKEWY,
        .get_SVG_TRANSFORM_TRANSLATE = &get_SVG_TRANSFORM_TRANSLATE,
        .get_SVG_TRANSFORM_UNKNOWN = &get_SVG_TRANSFORM_UNKNOWN,
        .get_angle = &get_angle,
        .get_matrix = &get_matrix,
        .get_type = &get_type,

        .call_setMatrix = &call_setMatrix,
        .call_setRotate = &call_setRotate,
        .call_setScale = &call_setScale,
        .call_setSkewX = &call_setSkewX,
        .call_setSkewY = &call_setSkewY,
        .call_setTranslate = &call_setTranslate,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SVGTransformImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGTransformImpl.deinit(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!u16 {
        return try SVGTransformImpl.get_type(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_matrix(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_matrix) |cached| {
            return cached;
        }
        const value = try SVGTransformImpl.get_matrix(instance);
        state.own.cached_matrix = value;
        return value;
    }

    pub fn get_angle(instance: *runtime.Instance) anyerror!f32 {
        return try SVGTransformImpl.get_angle(instance);
    }

    pub fn call_setSkewX(instance: *runtime.Instance, angle: f32) anyerror!void {
        return try SVGTransformImpl.call_setSkewX(instance, angle);
    }

    pub fn call_setMatrix(instance: *runtime.Instance, matrix: webidl.Opt(DOMMatrix2DInit)) anyerror!void {
        return try SVGTransformImpl.call_setMatrix(instance, matrix);
    }

    pub fn call_setRotate(instance: *runtime.Instance, angle: f32, cx: f32, cy: f32) anyerror!void {
        return try SVGTransformImpl.call_setRotate(instance, angle, cx, cy);
    }

    pub fn call_setSkewY(instance: *runtime.Instance, angle: f32) anyerror!void {
        return try SVGTransformImpl.call_setSkewY(instance, angle);
    }

    pub fn call_setTranslate(instance: *runtime.Instance, tx: f32, ty: f32) anyerror!void {
        return try SVGTransformImpl.call_setTranslate(instance, tx, ty);
    }

    pub fn call_setScale(instance: *runtime.Instance, sx: f32, sy: f32) anyerror!void {
        return try SVGTransformImpl.call_setScale(instance, sx, sy);
    }
};
