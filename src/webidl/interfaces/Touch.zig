//! Generated from: touch-events.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TouchImpl = @import("impls").Touch;
const TouchInit = @import("dictionaries").TouchInit;
const EventTarget = @import("interfaces").EventTarget;
const TouchType = @import("enums").TouchType;

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
        
        // Initialize the instance (Impl receives full instance)
        TouchImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TouchImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, touchInitDict: TouchInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try TouchImpl.constructor(instance, touchInitDict);
        
        return instance;
    }

    pub fn get_identifier(instance: *runtime.Instance) anyerror!i32 {
        return try TouchImpl.get_identifier(instance);
    }

    pub fn get_target(instance: *runtime.Instance) anyerror!EventTarget {
        return try TouchImpl.get_target(instance);
    }

    pub fn get_screenX(instance: *runtime.Instance) anyerror!f64 {
        return try TouchImpl.get_screenX(instance);
    }

    pub fn get_screenY(instance: *runtime.Instance) anyerror!f64 {
        return try TouchImpl.get_screenY(instance);
    }

    pub fn get_clientX(instance: *runtime.Instance) anyerror!f64 {
        return try TouchImpl.get_clientX(instance);
    }

    pub fn get_clientY(instance: *runtime.Instance) anyerror!f64 {
        return try TouchImpl.get_clientY(instance);
    }

    pub fn get_pageX(instance: *runtime.Instance) anyerror!f64 {
        return try TouchImpl.get_pageX(instance);
    }

    pub fn get_pageY(instance: *runtime.Instance) anyerror!f64 {
        return try TouchImpl.get_pageY(instance);
    }

    pub fn get_radiusX(instance: *runtime.Instance) anyerror!f32 {
        return try TouchImpl.get_radiusX(instance);
    }

    pub fn get_radiusY(instance: *runtime.Instance) anyerror!f32 {
        return try TouchImpl.get_radiusY(instance);
    }

    pub fn get_rotationAngle(instance: *runtime.Instance) anyerror!f32 {
        return try TouchImpl.get_rotationAngle(instance);
    }

    pub fn get_force(instance: *runtime.Instance) anyerror!f32 {
        return try TouchImpl.get_force(instance);
    }

    pub fn get_altitudeAngle(instance: *runtime.Instance) anyerror!f32 {
        return try TouchImpl.get_altitudeAngle(instance);
    }

    pub fn get_azimuthAngle(instance: *runtime.Instance) anyerror!f32 {
        return try TouchImpl.get_azimuthAngle(instance);
    }

    pub fn get_touchType(instance: *runtime.Instance) anyerror!TouchType {
        return try TouchImpl.get_touchType(instance);
    }

};
