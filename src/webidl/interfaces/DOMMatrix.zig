//! Generated from: geometry.idl
//! Generated at: 2025-11-23T19:57:36Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DOMMatrixImpl = @import("impls").DOMMatrix;
const DOMMatrixReadOnly = @import("interfaces").DOMMatrixReadOnly;
const DOMPoint = @import("interfaces").DOMPoint;
const DOMMatrixInit = @import("dictionaries").DOMMatrixInit;
const sequence = @import("interfaces").sequence;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const DOMString = @import("typedefs").DOMString;

pub const DOMMatrix = struct {
    pub const Meta = struct {
        pub const name = "DOMMatrix";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *DOMMatrixReadOnly;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "Serializable" },
            .{ .name = "LegacyWindowAlias", .value = .{ .identifier_list = &.{ "SVGMatrix", "WebKitCSSMatrix" } } },
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
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "fromMatrix", "call_fromMatrix", 0 },
            .{ "fromFloat32Array", "call_fromFloat32Array", 1 },
            .{ "fromFloat64Array", "call_fromFloat64Array", 1 },
            .{ "multiplySelf", "call_multiplySelf", 0 },
            .{ "preMultiplySelf", "call_preMultiplySelf", 0 },
            .{ "translateSelf", "call_translateSelf", 0 },
            .{ "scaleSelf", "call_scaleSelf", 0 },
            .{ "scale3dSelf", "call_scale3dSelf", 0 },
            .{ "rotateSelf", "call_rotateSelf", 0 },
            .{ "rotateFromVectorSelf", "call_rotateFromVectorSelf", 0 },
            .{ "rotateAxisAngleSelf", "call_rotateAxisAngleSelf", 0 },
            .{ "skewXSelf", "call_skewXSelf", 0 },
            .{ "skewYSelf", "call_skewYSelf", 0 },
            .{ "invertSelf", "call_invertSelf", 0 },
            .{ "setMatrixValue", "call_setMatrixValue", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "fromMatrix",
            "fromFloat32Array",
            "fromFloat64Array",
            "multiplySelf",
            "preMultiplySelf",
            "translateSelf",
            "scaleSelf",
            "scale3dSelf",
            "rotateSelf",
            "rotateFromVectorSelf",
            "rotateAxisAngleSelf",
            "skewXSelf",
            "skewYSelf",
            "invertSelf",
            "setMatrixValue",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
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
            _internal: ?*DOMMatrixImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_a = &get_a,
        .get_b = &get_b,
        .get_c = &get_c,
        .get_d = &get_d,
        .get_e = &get_e,
        .get_f = &get_f,
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

        .call_fromFloat32Array = &call_fromFloat32Array,
        .call_fromFloat64Array = &call_fromFloat64Array,
        .call_fromMatrix = &call_fromMatrix,
        .call_invertSelf = &call_invertSelf,
        .call_multiplySelf = &call_multiplySelf,
        .call_preMultiplySelf = &call_preMultiplySelf,
        .call_rotateAxisAngleSelf = &call_rotateAxisAngleSelf,
        .call_rotateFromVectorSelf = &call_rotateFromVectorSelf,
        .call_rotateSelf = &call_rotateSelf,
        .call_scale3dSelf = &call_scale3dSelf,
        .call_scaleSelf = &call_scaleSelf,
        .call_setMatrixValue = &call_setMatrixValue,
        .call_skewXSelf = &call_skewXSelf,
        .call_skewYSelf = &call_skewYSelf,
        .call_translateSelf = &call_translateSelf,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DOMMatrixImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DOMMatrixImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, init_data: *const anyopaque) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try DOMMatrixImpl.call_constructor(allocator, ctx, init_data);
    }

    pub fn get_a(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixImpl.get_a(instance);
    }

    pub fn get_b(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixImpl.get_b(instance);
    }

    pub fn get_c(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixImpl.get_c(instance);
    }

    pub fn get_d(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixImpl.get_d(instance);
    }

    pub fn get_e(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixImpl.get_e(instance);
    }

    pub fn get_f(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixImpl.get_f(instance);
    }

    pub fn get_m11(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixImpl.get_m11(instance);
    }

    pub fn get_m12(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixImpl.get_m12(instance);
    }

    pub fn get_m13(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixImpl.get_m13(instance);
    }

    pub fn get_m14(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixImpl.get_m14(instance);
    }

    pub fn get_m21(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixImpl.get_m21(instance);
    }

    pub fn get_m22(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixImpl.get_m22(instance);
    }

    pub fn get_m23(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixImpl.get_m23(instance);
    }

    pub fn get_m24(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixImpl.get_m24(instance);
    }

    pub fn get_m31(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixImpl.get_m31(instance);
    }

    pub fn get_m32(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixImpl.get_m32(instance);
    }

    pub fn get_m33(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixImpl.get_m33(instance);
    }

    pub fn get_m34(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixImpl.get_m34(instance);
    }

    pub fn get_m41(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixImpl.get_m41(instance);
    }

    pub fn get_m42(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixImpl.get_m42(instance);
    }

    pub fn get_m43(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixImpl.get_m43(instance);
    }

    pub fn get_m44(instance: *runtime.Instance) anyerror!f64 {
        return try DOMMatrixImpl.get_m44(instance);
    }

    pub fn call_scaleSelf(instance: *runtime.Instance, scaleX: f64, scaleY: f64, scaleZ: f64, originX: f64, originY: f64, originZ: f64) anyerror!*runtime.Instance {
        
        return try DOMMatrixImpl.call_scaleSelf(instance, scaleX, scaleY, scaleZ, originX, originY, originZ);
    }

    /// Extended attributes: [NewObject]
    pub fn call_fromFloat32Array(instance: *runtime.Instance, array32: *const anyopaque) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixImpl.call_fromFloat32Array(instance, array32);
    }

    pub fn call_rotateFromVectorSelf(instance: *runtime.Instance, x: f64, y: f64) anyerror!*runtime.Instance {
        
        return try DOMMatrixImpl.call_rotateFromVectorSelf(instance, x, y);
    }

    /// Extended attributes: [NewObject]
    pub fn call_fromFloat64Array(instance: *runtime.Instance, array64: *const anyopaque) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixImpl.call_fromFloat64Array(instance, array64);
    }

    /// Extended attributes: [NewObject]
    pub fn call_fromMatrix(instance: *runtime.Instance, other: DOMMatrixInit) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixImpl.call_fromMatrix(instance, other);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_setMatrixValue(instance: *runtime.Instance, transformList: DOMString) anyerror!*runtime.Instance {
        
        return try DOMMatrixImpl.call_setMatrixValue(instance, transformList);
    }

    pub fn call_rotateAxisAngleSelf(instance: *runtime.Instance, x: f64, y: f64, z: f64, angle: f64) anyerror!*runtime.Instance {
        
        return try DOMMatrixImpl.call_rotateAxisAngleSelf(instance, x, y, z, angle);
    }

    pub fn call_scale3dSelf(instance: *runtime.Instance, scale: f64, originX: f64, originY: f64, originZ: f64) anyerror!*runtime.Instance {
        
        return try DOMMatrixImpl.call_scale3dSelf(instance, scale, originX, originY, originZ);
    }

    pub fn call_rotateSelf(instance: *runtime.Instance, rotX: f64, rotY: f64, rotZ: f64) anyerror!*runtime.Instance {
        
        return try DOMMatrixImpl.call_rotateSelf(instance, rotX, rotY, rotZ);
    }

    pub fn call_translateSelf(instance: *runtime.Instance, tx: f64, ty: f64, tz: f64) anyerror!*runtime.Instance {
        
        return try DOMMatrixImpl.call_translateSelf(instance, tx, ty, tz);
    }

    pub fn call_multiplySelf(instance: *runtime.Instance, other: DOMMatrixInit) anyerror!*runtime.Instance {
        
        return try DOMMatrixImpl.call_multiplySelf(instance, other);
    }

    pub fn call_skewXSelf(instance: *runtime.Instance, sx: f64) anyerror!*runtime.Instance {
        
        return try DOMMatrixImpl.call_skewXSelf(instance, sx);
    }

    pub fn call_skewYSelf(instance: *runtime.Instance, sy: f64) anyerror!*runtime.Instance {
        
        return try DOMMatrixImpl.call_skewYSelf(instance, sy);
    }

    pub fn call_invertSelf(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try DOMMatrixImpl.call_invertSelf(instance);
    }

    pub fn call_preMultiplySelf(instance: *runtime.Instance, other: DOMMatrixInit) anyerror!*runtime.Instance {
        
        return try DOMMatrixImpl.call_preMultiplySelf(instance, other);
    }

};
