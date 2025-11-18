//! Generated from: geometry.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DOMMatrixImpl = @import("impls").DOMMatrix;
const DOMMatrixReadOnly = @import("interfaces").DOMMatrixReadOnly;
const DOMMatrixInit = @import("dictionaries").DOMMatrixInit;
const Float32Array = @import("interfaces").Float32Array;
const (DOMString or sequence) = @import("interfaces").(DOMString or sequence);
const Float64Array = @import("interfaces").Float64Array;

pub const DOMMatrix = struct {
    pub const Meta = struct {
        pub const name = "DOMMatrix";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *DOMMatrixReadOnly;
        pub const MixinTypes = .{};
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
    };

    pub const State = runtime.FlattenedState(
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
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(DOMMatrix, .{
        .deinit_fn = &deinit_wrapper,

        .get_a = &get_a,
        .get_a = &get_a,
        .get_b = &get_b,
        .get_b = &get_b,
        .get_c = &get_c,
        .get_c = &get_c,
        .get_d = &get_d,
        .get_d = &get_d,
        .get_e = &get_e,
        .get_e = &get_e,
        .get_f = &get_f,
        .get_f = &get_f,
        .get_is2D = &get_is2D,
        .get_isIdentity = &get_isIdentity,
        .get_m11 = &get_m11,
        .get_m11 = &get_m11,
        .get_m12 = &get_m12,
        .get_m12 = &get_m12,
        .get_m13 = &get_m13,
        .get_m13 = &get_m13,
        .get_m14 = &get_m14,
        .get_m14 = &get_m14,
        .get_m21 = &get_m21,
        .get_m21 = &get_m21,
        .get_m22 = &get_m22,
        .get_m22 = &get_m22,
        .get_m23 = &get_m23,
        .get_m23 = &get_m23,
        .get_m24 = &get_m24,
        .get_m24 = &get_m24,
        .get_m31 = &get_m31,
        .get_m31 = &get_m31,
        .get_m32 = &get_m32,
        .get_m32 = &get_m32,
        .get_m33 = &get_m33,
        .get_m33 = &get_m33,
        .get_m34 = &get_m34,
        .get_m34 = &get_m34,
        .get_m41 = &get_m41,
        .get_m41 = &get_m41,
        .get_m42 = &get_m42,
        .get_m42 = &get_m42,
        .get_m43 = &get_m43,
        .get_m43 = &get_m43,
        .get_m44 = &get_m44,
        .get_m44 = &get_m44,

        .call_flipX = &call_flipX,
        .call_flipY = &call_flipY,
        .call_fromFloat32Array = &call_fromFloat32Array,
        .call_fromFloat64Array = &call_fromFloat64Array,
        .call_fromMatrix = &call_fromMatrix,
        .call_inverse = &call_inverse,
        .call_invertSelf = &call_invertSelf,
        .call_multiply = &call_multiply,
        .call_multiplySelf = &call_multiplySelf,
        .call_preMultiplySelf = &call_preMultiplySelf,
        .call_rotate = &call_rotate,
        .call_rotateAxisAngle = &call_rotateAxisAngle,
        .call_rotateAxisAngleSelf = &call_rotateAxisAngleSelf,
        .call_rotateFromVector = &call_rotateFromVector,
        .call_rotateFromVectorSelf = &call_rotateFromVectorSelf,
        .call_rotateSelf = &call_rotateSelf,
        .call_scale = &call_scale,
        .call_scale3d = &call_scale3d,
        .call_scale3dSelf = &call_scale3dSelf,
        .call_scaleNonUniform = &call_scaleNonUniform,
        .call_scaleSelf = &call_scaleSelf,
        .call_setMatrixValue = &call_setMatrixValue,
        .call_skewX = &call_skewX,
        .call_skewXSelf = &call_skewXSelf,
        .call_skewY = &call_skewY,
        .call_skewYSelf = &call_skewYSelf,
        .call_toFloat32Array = &call_toFloat32Array,
        .call_toFloat64Array = &call_toFloat64Array,
        .call_toJSON = &call_toJSON,
        .call_transformPoint = &call_transformPoint,
        .call_translate = &call_translate,
        .call_translateSelf = &call_translateSelf,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        DOMMatrixImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DOMMatrixImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, init: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try DOMMatrixImpl.constructor(instance, init);
        
        return instance;
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

    pub fn get_is2D(instance: *runtime.Instance) anyerror!bool {
        return try DOMMatrixImpl.get_is2D(instance);
    }

    pub fn get_isIdentity(instance: *runtime.Instance) anyerror!bool {
        return try DOMMatrixImpl.get_isIdentity(instance);
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

    /// Arguments for fromFloat32Array (WebIDL overloading)
    pub const FromFloat32ArrayArgs = union(enum) {
        /// fromFloat32Array(array32)
        Float32Array: anyopaque,
        /// fromFloat32Array(array32)
        Float32Array: anyopaque,
    };

    pub fn call_fromFloat32Array(instance: *runtime.Instance, args: FromFloat32ArrayArgs) anyerror!DOMMatrixReadOnly {
        switch (args) {
            .Float32Array => |arg| return try DOMMatrixImpl.Float32Array(instance, arg),
            .Float32Array => |arg| return try DOMMatrixImpl.Float32Array(instance, arg),
        }
    }

    /// Extended attributes: [NewObject]
    pub fn call_scale3d(instance: *runtime.Instance, scale: f64, originX: f64, originY: f64, originZ: f64) anyerror!DOMMatrix {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixImpl.call_scale3d(instance, scale, originX, originY, originZ);
    }

    /// Arguments for fromFloat64Array (WebIDL overloading)
    pub const FromFloat64ArrayArgs = union(enum) {
        /// fromFloat64Array(array64)
        Float64Array: anyopaque,
        /// fromFloat64Array(array64)
        Float64Array: anyopaque,
    };

    pub fn call_fromFloat64Array(instance: *runtime.Instance, args: FromFloat64ArrayArgs) anyerror!DOMMatrixReadOnly {
        switch (args) {
            .Float64Array => |arg| return try DOMMatrixImpl.Float64Array(instance, arg),
            .Float64Array => |arg| return try DOMMatrixImpl.Float64Array(instance, arg),
        }
    }

    /// Arguments for fromMatrix (WebIDL overloading)
    pub const FromMatrixArgs = union(enum) {
        /// fromMatrix(other)
        DOMMatrixInit: DOMMatrixInit,
        /// fromMatrix(other)
        DOMMatrixInit: DOMMatrixInit,
    };

    pub fn call_fromMatrix(instance: *runtime.Instance, args: FromMatrixArgs) anyerror!DOMMatrixReadOnly {
        switch (args) {
            .DOMMatrixInit => |arg| return try DOMMatrixImpl.DOMMatrixInit(instance, arg),
            .DOMMatrixInit => |arg| return try DOMMatrixImpl.DOMMatrixInit(instance, arg),
        }
    }

    /// Extended attributes: [NewObject]
    pub fn call_skewY(instance: *runtime.Instance, sy: f64) anyerror!DOMMatrix {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixImpl.call_skewY(instance, sy);
    }

    /// Extended attributes: [NewObject]
    pub fn call_inverse(instance: *runtime.Instance) anyerror!DOMMatrix {
        // [NewObject] - Caller owns the returned object
        return try DOMMatrixImpl.call_inverse(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!anyopaque {
        return try DOMMatrixImpl.call_toJSON(instance);
    }

    pub fn call_rotateAxisAngleSelf(instance: *runtime.Instance, x: f64, y: f64, z: f64, angle: f64) anyerror!DOMMatrix {
        
        return try DOMMatrixImpl.call_rotateAxisAngleSelf(instance, x, y, z, angle);
    }

    /// Extended attributes: [NewObject]
    pub fn call_transformPoint(instance: *runtime.Instance, point: DOMPointInit) anyerror!DOMPoint {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixImpl.call_transformPoint(instance, point);
    }

    /// Extended attributes: [NewObject]
    pub fn call_multiply(instance: *runtime.Instance, other: DOMMatrixInit) anyerror!DOMMatrix {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixImpl.call_multiply(instance, other);
    }

    /// Extended attributes: [NewObject]
    pub fn call_skewX(instance: *runtime.Instance, sx: f64) anyerror!DOMMatrix {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixImpl.call_skewX(instance, sx);
    }

    pub fn call_scale3dSelf(instance: *runtime.Instance, scale: f64, originX: f64, originY: f64, originZ: f64) anyerror!DOMMatrix {
        
        return try DOMMatrixImpl.call_scale3dSelf(instance, scale, originX, originY, originZ);
    }

    pub fn call_translateSelf(instance: *runtime.Instance, tx: f64, ty: f64, tz: f64) anyerror!DOMMatrix {
        
        return try DOMMatrixImpl.call_translateSelf(instance, tx, ty, tz);
    }

    pub fn call_multiplySelf(instance: *runtime.Instance, other: DOMMatrixInit) anyerror!DOMMatrix {
        
        return try DOMMatrixImpl.call_multiplySelf(instance, other);
    }

    pub fn call_rotateSelf(instance: *runtime.Instance, rotX: f64, rotY: f64, rotZ: f64) anyerror!DOMMatrix {
        
        return try DOMMatrixImpl.call_rotateSelf(instance, rotX, rotY, rotZ);
    }

    pub fn call_skewYSelf(instance: *runtime.Instance, sy: f64) anyerror!DOMMatrix {
        
        return try DOMMatrixImpl.call_skewYSelf(instance, sy);
    }

    pub fn call_scaleSelf(instance: *runtime.Instance, scaleX: f64, scaleY: f64, scaleZ: f64, originX: f64, originY: f64, originZ: f64) anyerror!DOMMatrix {
        
        return try DOMMatrixImpl.call_scaleSelf(instance, scaleX, scaleY, scaleZ, originX, originY, originZ);
    }

    pub fn call_rotateFromVectorSelf(instance: *runtime.Instance, x: f64, y: f64) anyerror!DOMMatrix {
        
        return try DOMMatrixImpl.call_rotateFromVectorSelf(instance, x, y);
    }

    /// Extended attributes: [NewObject]
    pub fn call_flipX(instance: *runtime.Instance) anyerror!DOMMatrix {
        // [NewObject] - Caller owns the returned object
        return try DOMMatrixImpl.call_flipX(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_rotateAxisAngle(instance: *runtime.Instance, x: f64, y: f64, z: f64, angle: f64) anyerror!DOMMatrix {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixImpl.call_rotateAxisAngle(instance, x, y, z, angle);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_setMatrixValue(instance: *runtime.Instance, transformList: DOMString) anyerror!DOMMatrix {
        
        return try DOMMatrixImpl.call_setMatrixValue(instance, transformList);
    }

    /// Extended attributes: [NewObject]
    pub fn call_rotate(instance: *runtime.Instance, rotX: f64, rotY: f64, rotZ: f64) anyerror!DOMMatrix {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixImpl.call_rotate(instance, rotX, rotY, rotZ);
    }

    /// Extended attributes: [NewObject]
    pub fn call_toFloat64Array(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try DOMMatrixImpl.call_toFloat64Array(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_scale(instance: *runtime.Instance, scaleX: f64, scaleY: f64, scaleZ: f64, originX: f64, originY: f64, originZ: f64) anyerror!DOMMatrix {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixImpl.call_scale(instance, scaleX, scaleY, scaleZ, originX, originY, originZ);
    }

    /// Extended attributes: [NewObject]
    pub fn call_translate(instance: *runtime.Instance, tx: f64, ty: f64, tz: f64) anyerror!DOMMatrix {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixImpl.call_translate(instance, tx, ty, tz);
    }

    pub fn call_invertSelf(instance: *runtime.Instance) anyerror!DOMMatrix {
        return try DOMMatrixImpl.call_invertSelf(instance);
    }

    pub fn call_skewXSelf(instance: *runtime.Instance, sx: f64) anyerror!DOMMatrix {
        
        return try DOMMatrixImpl.call_skewXSelf(instance, sx);
    }

    /// Extended attributes: [NewObject]
    pub fn call_scaleNonUniform(instance: *runtime.Instance, scaleX: f64, scaleY: f64) anyerror!DOMMatrix {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixImpl.call_scaleNonUniform(instance, scaleX, scaleY);
    }

    /// Extended attributes: [NewObject]
    pub fn call_flipY(instance: *runtime.Instance) anyerror!DOMMatrix {
        // [NewObject] - Caller owns the returned object
        return try DOMMatrixImpl.call_flipY(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_toFloat32Array(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try DOMMatrixImpl.call_toFloat32Array(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_rotateFromVector(instance: *runtime.Instance, x: f64, y: f64) anyerror!DOMMatrix {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixImpl.call_rotateFromVector(instance, x, y);
    }

    pub fn call_preMultiplySelf(instance: *runtime.Instance, other: DOMMatrixInit) anyerror!DOMMatrix {
        
        return try DOMMatrixImpl.call_preMultiplySelf(instance, other);
    }

};
