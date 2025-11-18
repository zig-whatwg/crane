//! Generated from: geometry.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DOMPointReadOnlyImpl = @import("impls").DOMPointReadOnly;
const DOMPoint = @import("interfaces").DOMPoint;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const DOMMatrixInit = @import("dictionaries").DOMMatrixInit;

pub const DOMPointReadOnly = struct {
    pub const Meta = struct {
        pub const name = "DOMPointReadOnly";
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
            x: f64 = undefined,
            y: f64 = undefined,
            z: f64 = undefined,
            w: f64 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(DOMPointReadOnly, .{
        .deinit_fn = &deinit_wrapper,

        .get_w = &get_w,
        .get_x = &get_x,
        .get_y = &get_y,
        .get_z = &get_z,

        .call_fromPoint = &call_fromPoint,
        .call_matrixTransform = &call_matrixTransform,
        .call_toJSON = &call_toJSON,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        DOMPointReadOnlyImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DOMPointReadOnlyImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, x: f64, y: f64, z: f64, w: f64) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try DOMPointReadOnlyImpl.constructor(instance, x, y, z, w);
        
        return instance;
    }

    pub fn get_x(instance: *runtime.Instance) anyerror!f64 {
        return try DOMPointReadOnlyImpl.get_x(instance);
    }

    pub fn get_y(instance: *runtime.Instance) anyerror!f64 {
        return try DOMPointReadOnlyImpl.get_y(instance);
    }

    pub fn get_z(instance: *runtime.Instance) anyerror!f64 {
        return try DOMPointReadOnlyImpl.get_z(instance);
    }

    pub fn get_w(instance: *runtime.Instance) anyerror!f64 {
        return try DOMPointReadOnlyImpl.get_w(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!anyopaque {
        return try DOMPointReadOnlyImpl.call_toJSON(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_matrixTransform(instance: *runtime.Instance, matrix: DOMMatrixInit) anyerror!DOMPoint {
        // [NewObject] - Caller owns the returned object
        
        return try DOMPointReadOnlyImpl.call_matrixTransform(instance, matrix);
    }

    /// Extended attributes: [NewObject]
    pub fn call_fromPoint(instance: *runtime.Instance, other: DOMPointInit) anyerror!DOMPointReadOnly {
        // [NewObject] - Caller owns the returned object
        
        return try DOMPointReadOnlyImpl.call_fromPoint(instance, other);
    }

};
