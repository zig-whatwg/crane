//! Generated from: geometry.idl
//! Generated at: 2025-11-28T03:24:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DOMMatrixReadOnlyImpl = @import("impls").DOMMatrixReadOnly;
const DOMPoint = @import("interfaces").DOMPoint;
const DOMMatrixInit = @import("dictionaries").DOMMatrixInit;
const DOMMatrix = @import("interfaces").DOMMatrix;
const sequence = @import("interfaces").sequence;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const DOMString = @import("typedefs").DOMString;

pub const DOMMatrixReadOnly = struct {
    pub const Meta = struct {
        pub const name = "DOMMatrixReadOnly";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "Serializable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "a", "get_a", null },
            .{ "b", "get_b", null },
            .{ "c", "get_c", null },
            .{ "d", "get_d", null },
            .{ "e", "get_e", null },
            .{ "f", "get_f", null },
            .{ "m11", "get_m11", null },
            .{ "m12", "get_m12", null },
            .{ "m13", "get_m13", null },
            .{ "m14", "get_m14", null },
            .{ "m21", "get_m21", null },
            .{ "m22", "get_m22", null },
            .{ "m23", "get_m23", null },
            .{ "m24", "get_m24", null },
            .{ "m31", "get_m31", null },
            .{ "m32", "get_m32", null },
            .{ "m33", "get_m33", null },
            .{ "m34", "get_m34", null },
            .{ "m41", "get_m41", null },
            .{ "m42", "get_m42", null },
            .{ "m43", "get_m43", null },
            .{ "m44", "get_m44", null },
            .{ "is2D", "get_is2D", null },
            .{ "isIdentity", "get_isIdentity", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "translate", "call_translate", 0 },
            .{ "scale", "call_scale", 0 },
            .{ "scaleNonUniform", "call_scaleNonUniform", 0 },
            .{ "scale3d", "call_scale3d", 0 },
            .{ "rotate", "call_rotate", 0 },
            .{ "rotateFromVector", "call_rotateFromVector", 0 },
            .{ "rotateAxisAngle", "call_rotateAxisAngle", 0 },
            .{ "skewX", "call_skewX", 0 },
            .{ "skewY", "call_skewY", 0 },
            .{ "multiply", "call_multiply", 0 },
            .{ "flipX", "call_flipX", 0 },
            .{ "flipY", "call_flipY", 0 },
            .{ "inverse", "call_inverse", 0 },
            .{ "transformPoint", "call_transformPoint", 0 },
            .{ "toFloat32Array", "call_toFloat32Array", 0 },
            .{ "toFloat64Array", "call_toFloat64Array", 0 },
            .{ "toJSON", "call_toJSON", 0 },
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "fromMatrix", "call_fromMatrix", 0 },
            .{ "fromFloat32Array", "call_fromFloat32Array", 1 },
            .{ "fromFloat64Array", "call_fromFloat64Array", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "fromMatrix",
            "fromFloat32Array",
            "fromFloat64Array",
            "translate",
            "scale",
            "scaleNonUniform",
            "scale3d",
            "rotate",
            "rotateFromVector",
            "rotateAxisAngle",
            "skewX",
            "skewY",
            "multiply",
            "flipX",
            "flipY",
            "inverse",
            "transformPoint",
            "toFloat32Array",
            "toFloat64Array",
            "toJSON",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "a", "get_a", null },
            .{ "b", "get_b", null },
            .{ "c", "get_c", null },
            .{ "d", "get_d", null },
            .{ "e", "get_e", null },
            .{ "f", "get_f", null },
            .{ "m11", "get_m11", null },
            .{ "m12", "get_m12", null },
            .{ "m13", "get_m13", null },
            .{ "m14", "get_m14", null },
            .{ "m21", "get_m21", null },
            .{ "m22", "get_m22", null },
            .{ "m23", "get_m23", null },
            .{ "m24", "get_m24", null },
            .{ "m31", "get_m31", null },
            .{ "m32", "get_m32", null },
            .{ "m33", "get_m33", null },
            .{ "m34", "get_m34", null },
            .{ "m41", "get_m41", null },
            .{ "m42", "get_m42", null },
            .{ "m43", "get_m43", null },
            .{ "m44", "get_m44", null },
            .{ "is2D", "get_is2D", null },
            .{ "isIdentity", "get_isIdentity", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            a: f64 = undefined,
            b: f64 = undefined,
            c: f64 = undefined,
            d: f64 = undefined,
            e: f64 = undefined,
            f: f64 = undefined,
            m11: f64 = undefined,
            m12: f64 = undefined,
            m13: f64 = undefined,
            m14: f64 = undefined,
            m21: f64 = undefined,
            m22: f64 = undefined,
            m23: f64 = undefined,
            m24: f64 = undefined,
            m31: f64 = undefined,
            m32: f64 = undefined,
            m33: f64 = undefined,
            m34: f64 = undefined,
            m41: f64 = undefined,
            m42: f64 = undefined,
            m43: f64 = undefined,
            m44: f64 = undefined,
            is2D: bool = undefined,
            isIdentity: bool = undefined,
            _internal: ?*DOMMatrixReadOnlyImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_a = &get_a,
        .get_b = &get_b,
        .get_c = &get_c,
        .get_d = &get_d,
        .get_e = &get_e,
        .get_f = &get_f,
        .get_is2D = &get_is2D,
        .get_isIdentity = &get_isIdentity,
        .get_m11 = &get_m11,
        .get_m12 = &get_m12,
        .get_m13 = &get_m13,
        .get_m14 = &get_m14,
        .get_m21 = &get_m21,
        .get_m22 = &get_m22,
        .get_m23 = &get_m23,
        .get_m24 = &get_m24,
        .get_m31 = &get_m31,
        .get_m32 = &get_m32,
        .get_m33 = &get_m33,
        .get_m34 = &get_m34,
        .get_m41 = &get_m41,
        .get_m42 = &get_m42,
        .get_m43 = &get_m43,
        .get_m44 = &get_m44,

        .call_flipX = &call_flipX,
        .call_flipY = &call_flipY,
        .call_fromFloat32Array = &call_fromFloat32Array,
        .call_fromFloat64Array = &call_fromFloat64Array,
        .call_fromMatrix = &call_fromMatrix,
        .call_inverse = &call_inverse,
        .call_multiply = &call_multiply,
        .call_rotate = &call_rotate,
        .call_rotateAxisAngle = &call_rotateAxisAngle,
        .call_rotateFromVector = &call_rotateFromVector,
        .call_scale = &call_scale,
        .call_scale3d = &call_scale3d,
        .call_scaleNonUniform = &call_scaleNonUniform,
        .call_skewX = &call_skewX,
        .call_skewY = &call_skewY,
        .call_toFloat32Array = &call_toFloat32Array,
        .call_toFloat64Array = &call_toFloat64Array,
        .call_toJSON = &call_toJSON,
        .call_transformPoint = &call_transformPoint,
        .call_translate = &call_translate,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DOMMatrixReadOnlyImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DOMMatrixReadOnlyImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, init_data: *const anyopaque) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try DOMMatrixReadOnlyImpl.call_constructor(allocator, ctx, init_data);
    }

    pub fn get_a(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixReadOnlyImpl.get_a(instance);
    }

    pub fn get_b(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixReadOnlyImpl.get_b(instance);
    }

    pub fn get_c(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixReadOnlyImpl.get_c(instance);
    }

    pub fn get_d(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixReadOnlyImpl.get_d(instance);
    }

    pub fn get_e(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixReadOnlyImpl.get_e(instance);
    }

    pub fn get_f(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixReadOnlyImpl.get_f(instance);
    }

    pub fn get_m11(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixReadOnlyImpl.get_m11(instance);
    }

    pub fn get_m12(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixReadOnlyImpl.get_m12(instance);
    }

    pub fn get_m13(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixReadOnlyImpl.get_m13(instance);
    }

    pub fn get_m14(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixReadOnlyImpl.get_m14(instance);
    }

    pub fn get_m21(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixReadOnlyImpl.get_m21(instance);
    }

    pub fn get_m22(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixReadOnlyImpl.get_m22(instance);
    }

    pub fn get_m23(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixReadOnlyImpl.get_m23(instance);
    }

    pub fn get_m24(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixReadOnlyImpl.get_m24(instance);
    }

    pub fn get_m31(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixReadOnlyImpl.get_m31(instance);
    }

    pub fn get_m32(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixReadOnlyImpl.get_m32(instance);
    }

    pub fn get_m33(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixReadOnlyImpl.get_m33(instance);
    }

    pub fn get_m34(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixReadOnlyImpl.get_m34(instance);
    }

    pub fn get_m41(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixReadOnlyImpl.get_m41(instance);
    }

    pub fn get_m42(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixReadOnlyImpl.get_m42(instance);
    }

    pub fn get_m43(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixReadOnlyImpl.get_m43(instance);
    }

    pub fn get_m44(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixReadOnlyImpl.get_m44(instance);
    }

    pub fn get_is2D(instance: *runtime.Instance) anyerror!bool {
        return try DOMMatrixReadOnlyImpl.get_is2D(instance);
    }

    pub fn get_isIdentity(instance: *runtime.Instance) anyerror!bool {
        return try DOMMatrixReadOnlyImpl.get_isIdentity(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_fromFloat32Array(instance: *runtime.Instance, array32: *const anyopaque) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixReadOnlyImpl.call_fromFloat32Array(instance, array32);
    }

    /// Extended attributes: [NewObject]
    pub fn call_flipX(instance: *runtime.Instance) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        return try DOMMatrixReadOnlyImpl.call_flipX(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_scale3d(instance: *runtime.Instance, scale: f64, originX: f64, originY: f64, originZ: f64) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixReadOnlyImpl.call_scale3d(instance, scale, originX, originY, originZ);
    }

    /// Extended attributes: [NewObject]
    pub fn call_fromFloat64Array(instance: *runtime.Instance, array64: *const anyopaque) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixReadOnlyImpl.call_fromFloat64Array(instance, array64);
    }

    /// Extended attributes: [NewObject]
    pub fn call_fromMatrix(instance: *runtime.Instance, other: DOMMatrixInit) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixReadOnlyImpl.call_fromMatrix(instance, other);
    }

    /// Extended attributes: [NewObject]
    pub fn call_rotateAxisAngle(instance: *runtime.Instance, x: f64, y: f64, z: f64, angle: f64) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixReadOnlyImpl.call_rotateAxisAngle(instance, x, y, z, angle);
    }

    /// Extended attributes: [NewObject]
    pub fn call_skewY(instance: *runtime.Instance, sy: f64) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixReadOnlyImpl.call_skewY(instance, sy);
    }

    /// Extended attributes: [NewObject]
    pub fn call_rotate(instance: *runtime.Instance, rotX: f64, rotY: f64, rotZ: f64) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixReadOnlyImpl.call_rotate(instance, rotX, rotY, rotZ);
    }

    /// Extended attributes: [NewObject]
    pub fn call_inverse(instance: *runtime.Instance) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        return try DOMMatrixReadOnlyImpl.call_inverse(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_toFloat64Array(instance: *runtime.Instance) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        return try DOMMatrixReadOnlyImpl.call_toFloat64Array(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_scale(instance: *runtime.Instance, scaleX: f64, scaleY: f64, scaleZ: f64, originX: f64, originY: f64, originZ: f64) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixReadOnlyImpl.call_scale(instance, scaleX, scaleY, scaleZ, originX, originY, originZ);
    }

    /// Extended attributes: [NewObject]
    pub fn call_translate(instance: *runtime.Instance, tx: f64, ty: f64, tz: f64) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixReadOnlyImpl.call_translate(instance, tx, ty, tz);
    }

    /// Extended attributes: [NewObject]
    pub fn call_multiply(instance: *runtime.Instance, other: DOMMatrixInit) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixReadOnlyImpl.call_multiply(instance, other);
    }

    /// Extended attributes: [NewObject]
    pub fn call_transformPoint(instance: *runtime.Instance, point: DOMPointInit) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixReadOnlyImpl.call_transformPoint(instance, point);
    }

    /// Extended attributes: [NewObject]
    pub fn call_skewX(instance: *runtime.Instance, sx: f64) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixReadOnlyImpl.call_skewX(instance, sx);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try DOMMatrixReadOnlyImpl.call_toJSON(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_scaleNonUniform(instance: *runtime.Instance, scaleX: f64, scaleY: f64) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixReadOnlyImpl.call_scaleNonUniform(instance, scaleX, scaleY);
    }

    /// Extended attributes: [NewObject]
    pub fn call_flipY(instance: *runtime.Instance) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        return try DOMMatrixReadOnlyImpl.call_flipY(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_toFloat32Array(instance: *runtime.Instance) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        return try DOMMatrixReadOnlyImpl.call_toFloat32Array(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_rotateFromVector(instance: *runtime.Instance, x: f64, y: f64) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixReadOnlyImpl.call_rotateFromVector(instance, x, y);
    }

};
