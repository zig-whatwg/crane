//! Generated from: geometry.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DOMMatrixReadOnlyImpl = @import("impls").DOMMatrixReadOnly;
const DOMPoint = @import("interfaces").DOMPoint;
const DOMMatrixInit = @import("dictionaries").DOMMatrixInit;
const Float32Array = @import("interfaces").Float32Array;
const (DOMString or sequence) = @import("interfaces").(DOMString or sequence);
const DOMMatrix = @import("interfaces").DOMMatrix;
const Float64Array = @import("interfaces").Float64Array;
const DOMPointInit = @import("dictionaries").DOMPointInit;

pub const DOMMatrixReadOnly = struct {
    pub const Meta = struct {
        pub const name = "DOMMatrixReadOnly";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "Serializable" },
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
            is2D: bool = undefined,
            isIdentity: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(DOMMatrixReadOnly, .{
        .deinit_fn = &deinit_wrapper,

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
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        DOMMatrixReadOnlyImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DOMMatrixReadOnlyImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, init: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try DOMMatrixReadOnlyImpl.constructor(instance, init);
        
        return instance;
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
    pub fn call_fromFloat32Array(instance: *runtime.Instance, array32: anyopaque) anyerror!DOMMatrixReadOnly {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixReadOnlyImpl.call_fromFloat32Array(instance, array32);
    }

    /// Extended attributes: [NewObject]
    pub fn call_flipX(instance: *runtime.Instance) anyerror!DOMMatrix {
        // [NewObject] - Caller owns the returned object
        return try DOMMatrixReadOnlyImpl.call_flipX(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_scale3d(instance: *runtime.Instance, scale: f64, originX: f64, originY: f64, originZ: f64) anyerror!DOMMatrix {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixReadOnlyImpl.call_scale3d(instance, scale, originX, originY, originZ);
    }

    /// Extended attributes: [NewObject]
    pub fn call_fromFloat64Array(instance: *runtime.Instance, array64: anyopaque) anyerror!DOMMatrixReadOnly {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixReadOnlyImpl.call_fromFloat64Array(instance, array64);
    }

    /// Extended attributes: [NewObject]
    pub fn call_fromMatrix(instance: *runtime.Instance, other: DOMMatrixInit) anyerror!DOMMatrixReadOnly {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixReadOnlyImpl.call_fromMatrix(instance, other);
    }

    /// Extended attributes: [NewObject]
    pub fn call_rotateAxisAngle(instance: *runtime.Instance, x: f64, y: f64, z: f64, angle: f64) anyerror!DOMMatrix {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixReadOnlyImpl.call_rotateAxisAngle(instance, x, y, z, angle);
    }

    /// Extended attributes: [NewObject]
    pub fn call_skewY(instance: *runtime.Instance, sy: f64) anyerror!DOMMatrix {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixReadOnlyImpl.call_skewY(instance, sy);
    }

    /// Extended attributes: [NewObject]
    pub fn call_rotate(instance: *runtime.Instance, rotX: f64, rotY: f64, rotZ: f64) anyerror!DOMMatrix {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixReadOnlyImpl.call_rotate(instance, rotX, rotY, rotZ);
    }

    /// Extended attributes: [NewObject]
    pub fn call_inverse(instance: *runtime.Instance) anyerror!DOMMatrix {
        // [NewObject] - Caller owns the returned object
        return try DOMMatrixReadOnlyImpl.call_inverse(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_toFloat64Array(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try DOMMatrixReadOnlyImpl.call_toFloat64Array(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_scale(instance: *runtime.Instance, scaleX: f64, scaleY: f64, scaleZ: f64, originX: f64, originY: f64, originZ: f64) anyerror!DOMMatrix {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixReadOnlyImpl.call_scale(instance, scaleX, scaleY, scaleZ, originX, originY, originZ);
    }

    /// Extended attributes: [NewObject]
    pub fn call_translate(instance: *runtime.Instance, tx: f64, ty: f64, tz: f64) anyerror!DOMMatrix {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixReadOnlyImpl.call_translate(instance, tx, ty, tz);
    }

    /// Extended attributes: [NewObject]
    pub fn call_multiply(instance: *runtime.Instance, other: DOMMatrixInit) anyerror!DOMMatrix {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixReadOnlyImpl.call_multiply(instance, other);
    }

    /// Extended attributes: [NewObject]
    pub fn call_transformPoint(instance: *runtime.Instance, point: DOMPointInit) anyerror!DOMPoint {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixReadOnlyImpl.call_transformPoint(instance, point);
    }

    /// Extended attributes: [NewObject]
    pub fn call_skewX(instance: *runtime.Instance, sx: f64) anyerror!DOMMatrix {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixReadOnlyImpl.call_skewX(instance, sx);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!anyopaque {
        return try DOMMatrixReadOnlyImpl.call_toJSON(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_scaleNonUniform(instance: *runtime.Instance, scaleX: f64, scaleY: f64) anyerror!DOMMatrix {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixReadOnlyImpl.call_scaleNonUniform(instance, scaleX, scaleY);
    }

    /// Extended attributes: [NewObject]
    pub fn call_flipY(instance: *runtime.Instance) anyerror!DOMMatrix {
        // [NewObject] - Caller owns the returned object
        return try DOMMatrixReadOnlyImpl.call_flipY(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_toFloat32Array(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try DOMMatrixReadOnlyImpl.call_toFloat32Array(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_rotateFromVector(instance: *runtime.Instance, x: f64, y: f64) anyerror!DOMMatrix {
        // [NewObject] - Caller owns the returned object
        
        return try DOMMatrixReadOnlyImpl.call_rotateFromVector(instance, x, y);
    }

};
