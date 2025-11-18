//! Generated from: touch-events.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TouchImpl = @import("../impls/Touch.zig");

pub const Touch = struct {
    pub const Meta = struct {
        pub const name = "Touch";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            identifier: i32 = undefined,
            target: EventTarget = undefined,
            screenX: f64 = undefined,
            screenY: f64 = undefined,
            clientX: f64 = undefined,
            clientY: f64 = undefined,
            pageX: f64 = undefined,
            pageY: f64 = undefined,
            radiusX: f32 = undefined,
            radiusY: f32 = undefined,
            rotationAngle: f32 = undefined,
            force: f32 = undefined,
            altitudeAngle: f32 = undefined,
            azimuthAngle: f32 = undefined,
            touchType: TouchType = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Touch, .{
        .deinit_fn = &deinit_wrapper,

        .get_altitudeAngle = &get_altitudeAngle,
        .get_azimuthAngle = &get_azimuthAngle,
        .get_clientX = &get_clientX,
        .get_clientY = &get_clientY,
        .get_force = &get_force,
        .get_identifier = &get_identifier,
        .get_pageX = &get_pageX,
        .get_pageY = &get_pageY,
        .get_radiusX = &get_radiusX,
        .get_radiusY = &get_radiusY,
        .get_rotationAngle = &get_rotationAngle,
        .get_screenX = &get_screenX,
        .get_screenY = &get_screenY,
        .get_target = &get_target,
        .get_touchType = &get_touchType,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        TouchImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        TouchImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, touchInitDict: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try TouchImpl.constructor(state, touchInitDict);
        
        return instance;
    }

    pub fn get_identifier(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return TouchImpl.get_identifier(state);
    }

    pub fn get_target(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TouchImpl.get_target(state);
    }

    pub fn get_screenX(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return TouchImpl.get_screenX(state);
    }

    pub fn get_screenY(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return TouchImpl.get_screenY(state);
    }

    pub fn get_clientX(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return TouchImpl.get_clientX(state);
    }

    pub fn get_clientY(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return TouchImpl.get_clientY(state);
    }

    pub fn get_pageX(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return TouchImpl.get_pageX(state);
    }

    pub fn get_pageY(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return TouchImpl.get_pageY(state);
    }

    pub fn get_radiusX(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return TouchImpl.get_radiusX(state);
    }

    pub fn get_radiusY(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return TouchImpl.get_radiusY(state);
    }

    pub fn get_rotationAngle(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return TouchImpl.get_rotationAngle(state);
    }

    pub fn get_force(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return TouchImpl.get_force(state);
    }

    pub fn get_altitudeAngle(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return TouchImpl.get_altitudeAngle(state);
    }

    pub fn get_azimuthAngle(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return TouchImpl.get_azimuthAngle(state);
    }

    pub fn get_touchType(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TouchImpl.get_touchType(state);
    }

};
