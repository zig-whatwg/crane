//! Generated from: remote-playback.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RemotePlaybackImpl = @import("../impls/RemotePlayback.zig");
const EventTarget = @import("EventTarget.zig");

pub const RemotePlayback = struct {
    pub const Meta = struct {
        pub const name = "RemotePlayback";
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
            state: RemotePlaybackState = undefined,
            onconnecting: EventHandler = undefined,
            onconnect: EventHandler = undefined,
            ondisconnect: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(RemotePlayback, .{
        .deinit_fn = &deinit_wrapper,

        .get_onconnect = &get_onconnect,
        .get_onconnecting = &get_onconnecting,
        .get_ondisconnect = &get_ondisconnect,
        .get_state = &get_state,

        .set_onconnect = &set_onconnect,
        .set_onconnecting = &set_onconnecting,
        .set_ondisconnect = &set_ondisconnect,

        .call_addEventListener = &call_addEventListener,
        .call_cancelWatchAvailability = &call_cancelWatchAvailability,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_prompt = &call_prompt,
        .call_removeEventListener = &call_removeEventListener,
        .call_watchAvailability = &call_watchAvailability,
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
        RemotePlaybackImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        RemotePlaybackImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_state(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RemotePlaybackImpl.get_state(state);
    }

    pub fn get_onconnecting(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RemotePlaybackImpl.get_onconnecting(state);
    }

    pub fn set_onconnecting(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RemotePlaybackImpl.set_onconnecting(state, value);
    }

    pub fn get_onconnect(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RemotePlaybackImpl.get_onconnect(state);
    }

    pub fn set_onconnect(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RemotePlaybackImpl.set_onconnect(state, value);
    }

    pub fn get_ondisconnect(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RemotePlaybackImpl.get_ondisconnect(state);
    }

    pub fn set_ondisconnect(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RemotePlaybackImpl.set_ondisconnect(state, value);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RemotePlaybackImpl.call_removeEventListener(state, type_, callback, options);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RemotePlaybackImpl.call_when(state, type_, options);
    }

    pub fn call_watchAvailability(instance: *runtime.Instance, callback: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RemotePlaybackImpl.call_watchAvailability(state, callback);
    }

    pub fn call_prompt(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RemotePlaybackImpl.call_prompt(state);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return RemotePlaybackImpl.call_dispatchEvent(state, event);
    }

    pub fn call_cancelWatchAvailability(instance: *runtime.Instance, id: i32) anyopaque {
        const state = instance.getState(State);
        
        return RemotePlaybackImpl.call_cancelWatchAvailability(state, id);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RemotePlaybackImpl.call_addEventListener(state, type_, callback, options);
    }

};
