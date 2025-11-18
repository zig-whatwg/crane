//! Generated from: screen-wake-lock.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WakeLockSentinelImpl = @import("../impls/WakeLockSentinel.zig");
const EventTarget = @import("EventTarget.zig");

pub const WakeLockSentinel = struct {
    pub const Meta = struct {
        pub const name = "WakeLockSentinel";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            released: bool = undefined,
            type: WakeLockType = undefined,
            onrelease: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(WakeLockSentinel, .{
        .deinit_fn = &deinit_wrapper,

        .get_onrelease = &get_onrelease,
        .get_released = &get_released,
        .get_type = &get_type,

        .set_onrelease = &set_onrelease,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_release = &call_release,
        .call_removeEventListener = &call_removeEventListener,
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
        WakeLockSentinelImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        WakeLockSentinelImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_released(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return WakeLockSentinelImpl.get_released(state);
    }

    pub fn get_type(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WakeLockSentinelImpl.get_type(state);
    }

    pub fn get_onrelease(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WakeLockSentinelImpl.get_onrelease(state);
    }

    pub fn set_onrelease(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WakeLockSentinelImpl.set_onrelease(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return WakeLockSentinelImpl.call_dispatchEvent(state, event);
    }

    pub fn call_release(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WakeLockSentinelImpl.call_release(state);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WakeLockSentinelImpl.call_when(state, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WakeLockSentinelImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WakeLockSentinelImpl.call_removeEventListener(state, type_, callback, options);
    }

};
