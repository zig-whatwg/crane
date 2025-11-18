//! Generated from: audio-session.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AudioSessionImpl = @import("../impls/AudioSession.zig");
const EventTarget = @import("EventTarget.zig");

pub const AudioSession = struct {
    pub const Meta = struct {
        pub const name = "AudioSession";
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
            type: AudioSessionType = undefined,
            state: AudioSessionState = undefined,
            onstatechange: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(AudioSession, .{
        .deinit_fn = &deinit_wrapper,

        .get_onstatechange = &get_onstatechange,
        .get_state = &get_state,
        .get_type = &get_type,

        .set_onstatechange = &set_onstatechange,
        .set_type = &set_type,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
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
        AudioSessionImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        AudioSessionImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AudioSessionImpl.get_type(state);
    }

    pub fn set_type(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        AudioSessionImpl.set_type(state, value);
    }

    pub fn get_state(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AudioSessionImpl.get_state(state);
    }

    pub fn get_onstatechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AudioSessionImpl.get_onstatechange(state);
    }

    pub fn set_onstatechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        AudioSessionImpl.set_onstatechange(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return AudioSessionImpl.call_dispatchEvent(state, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AudioSessionImpl.call_when(state, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AudioSessionImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AudioSessionImpl.call_removeEventListener(state, type_, callback, options);
    }

};
