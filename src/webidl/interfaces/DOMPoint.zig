//! Generated from: geometry.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DOMPointImpl = @import("impls").DOMPoint;
const DOMPointReadOnly = @import("interfaces").DOMPointReadOnly;
const DOMPointInit = @import("dictionaries").DOMPointInit;

pub const DOMPoint = struct {
    pub const Meta = struct {
        pub const name = "DOMPoint";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *DOMPointReadOnly;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "Serializable" },
            .{ .name = "LegacyWindowAlias", .value = .{ .identifier = "SVGPoint" } },
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

    pub const vtable = runtime.buildVTable(DOMPoint, .{
        .deinit_fn = &deinit_wrapper,

        .get_w = &get_w,
        .get_w = &get_w,
        .get_x = &get_x,
        .get_x = &get_x,
        .get_y = &get_y,
        .get_y = &get_y,
        .get_z = &get_z,
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
        DOMPointImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DOMPointImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, x: f64, y: f64, z: f64, w: f64) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try DOMPointImpl.constructor(instance, x, y, z, w);
        
        return instance;
    }

    pub fn get_x(instance: *runtime.Instance) anyerror!f64 {
        return try DOMPointImpl.get_x(instance);
    }

    pub fn get_y(instance: *runtime.Instance) anyerror!f64 {
        return try DOMPointImpl.get_y(instance);
    }

    pub fn get_z(instance: *runtime.Instance) anyerror!f64 {
        return try DOMPointImpl.get_z(instance);
    }

    pub fn get_w(instance: *runtime.Instance) anyerror!f64 {
        return try DOMPointImpl.get_w(instance);
    }

    pub fn get_x(instance: *runtime.Instance) anyerror!f64 {
        return try DOMPointImpl.get_x(instance);
    }

    pub fn get_y(instance: *runtime.Instance) anyerror!f64 {
        return try DOMPointImpl.get_y(instance);
    }

    pub fn get_z(instance: *runtime.Instance) anyerror!f64 {
        return try DOMPointImpl.get_z(instance);
    }

    pub fn get_w(instance: *runtime.Instance) anyerror!f64 {
        return try DOMPointImpl.get_w(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!anyopaque {
        return try DOMPointImpl.call_toJSON(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_matrixTransform(instance: *runtime.Instance, matrix: DOMMatrixInit) anyerror!DOMPoint {
        // [NewObject] - Caller owns the returned object
        
        return try DOMPointImpl.call_matrixTransform(instance, matrix);
    }

    /// Arguments for fromPoint (WebIDL overloading)
    pub const FromPointArgs = union(enum) {
        /// fromPoint(other)
        DOMPointInit: DOMPointInit,
        /// fromPoint(other)
        DOMPointInit: DOMPointInit,
    };

    pub fn call_fromPoint(instance: *runtime.Instance, args: FromPointArgs) anyerror!DOMPointReadOnly {
        switch (args) {
            .DOMPointInit => |arg| return try DOMPointImpl.DOMPointInit(instance, arg),
            .DOMPointInit => |arg| return try DOMPointImpl.DOMPointInit(instance, arg),
        }
    }

};
