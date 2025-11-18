//! Generated from: geometry.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DOMPointReadOnlyImpl = @import("../impls/DOMPointReadOnly.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        DOMPointReadOnlyImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        DOMPointReadOnlyImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, x: f64, y: f64, z: f64, w: f64) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try DOMPointReadOnlyImpl.constructor(state, x, y, z, w);
        
        return instance;
    }

    pub fn get_x(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return DOMPointReadOnlyImpl.get_x(state);
    }

    pub fn get_y(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return DOMPointReadOnlyImpl.get_y(state);
    }

    pub fn get_z(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return DOMPointReadOnlyImpl.get_z(state);
    }

    pub fn get_w(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return DOMPointReadOnlyImpl.get_w(state);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DOMPointReadOnlyImpl.call_toJSON(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_matrixTransform(instance: *runtime.Instance, matrix: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return DOMPointReadOnlyImpl.call_matrixTransform(state, matrix);
    }

    /// Extended attributes: [NewObject]
    pub fn call_fromPoint(instance: *runtime.Instance, other: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return DOMPointReadOnlyImpl.call_fromPoint(state, other);
    }

};
