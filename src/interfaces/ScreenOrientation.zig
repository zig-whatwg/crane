//! Generated from: screen-orientation.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ScreenOrientationImpl = @import("../impls/ScreenOrientation.zig");
const EventTarget = @import("EventTarget.zig");

pub const ScreenOrientation = struct {
    pub const Meta = struct {
        pub const name = "ScreenOrientation";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            type: OrientationType = undefined,
            angle: u16 = undefined,
            onchange: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ScreenOrientation, .{
        .deinit_fn = &deinit_wrapper,

        .get_angle = &get_angle,
        .get_onchange = &get_onchange,
        .get_type = &get_type,

        .set_onchange = &set_onchange,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_lock = &call_lock,
        .call_removeEventListener = &call_removeEventListener,
        .call_unlock = &call_unlock,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        ScreenOrientationImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ScreenOrientationImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ScreenOrientationImpl.get_type(state);
    }

    pub fn get_angle(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return ScreenOrientationImpl.get_angle(state);
    }

    pub fn get_onchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ScreenOrientationImpl.get_onchange(state);
    }

    pub fn set_onchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ScreenOrientationImpl.set_onchange(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return ScreenOrientationImpl.call_dispatchEvent(state, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ScreenOrientationImpl.call_when(state, type_, options);
    }

    pub fn call_lock(instance: *runtime.Instance, orientation: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ScreenOrientationImpl.call_lock(state, orientation);
    }

    pub fn call_unlock(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ScreenOrientationImpl.call_unlock(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ScreenOrientationImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ScreenOrientationImpl.call_removeEventListener(state, type_, callback, options);
    }

};
