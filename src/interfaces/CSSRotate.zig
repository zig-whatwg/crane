//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSRotateImpl = @import("../impls/CSSRotate.zig");
const CSSTransformComponent = @import("CSSTransformComponent.zig");

pub const CSSRotate = struct {
    pub const Meta = struct {
        pub const name = "CSSRotate";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSTransformComponent;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker", "PaintWorklet", "LayoutWorklet" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
            .PaintWorklet = true,
            .LayoutWorklet = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            x: CSSNumberish = undefined,
            y: CSSNumberish = undefined,
            z: CSSNumberish = undefined,
            angle: CSSNumericValue = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSRotate, .{
        .deinit_fn = &deinit_wrapper,

        .get_angle = &get_angle,
        .get_is2D = &get_is2D,
        .get_x = &get_x,
        .get_y = &get_y,
        .get_z = &get_z,

        .set_angle = &set_angle,
        .set_is2D = &set_is2D,
        .set_x = &set_x,
        .set_y = &set_y,
        .set_z = &set_z,

        .call_toMatrix = &call_toMatrix,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        CSSRotateImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CSSRotateImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, angle: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try CSSRotateImpl.constructor(state, angle);
        
        return instance;
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, x: anyopaque, y: anyopaque, z: anyopaque, angle: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try CSSRotateImpl.constructor(state, x, y, z, angle);
        
        return instance;
    }

    pub fn get_is2D(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return CSSRotateImpl.get_is2D(state);
    }

    pub fn set_is2D(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        CSSRotateImpl.set_is2D(state, value);
    }

    pub fn get_x(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSRotateImpl.get_x(state);
    }

    pub fn set_x(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSRotateImpl.set_x(state, value);
    }

    pub fn get_y(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSRotateImpl.get_y(state);
    }

    pub fn set_y(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSRotateImpl.set_y(state, value);
    }

    pub fn get_z(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSRotateImpl.get_z(state);
    }

    pub fn set_z(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSRotateImpl.set_z(state, value);
    }

    pub fn get_angle(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSRotateImpl.get_angle(state);
    }

    pub fn set_angle(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSRotateImpl.set_angle(state, value);
    }

    pub fn call_toMatrix(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSRotateImpl.call_toMatrix(state);
    }

};
