//! Generated from: audio-session.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AudioSessionImpl = @import("impls").AudioSession;
const EventTarget = @import("interfaces").EventTarget;
const AudioSessionState = @import("enums").AudioSessionState;
const AudioSessionType = @import("enums").AudioSessionType;
const EventHandler = @import("typedefs").EventHandler;

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
        
        // Initialize the instance (Impl receives full instance)
        AudioSessionImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AudioSessionImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!AudioSessionType {
        return try AudioSessionImpl.get_type(instance);
    }

    pub fn set_type(instance: *runtime.Instance, value: AudioSessionType) anyerror!void {
        try AudioSessionImpl.set_type(instance, value);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!AudioSessionState {
        return try AudioSessionImpl.get_state(instance);
    }

    pub fn get_onstatechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try AudioSessionImpl.get_onstatechange(instance);
    }

    pub fn set_onstatechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try AudioSessionImpl.set_onstatechange(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try AudioSessionImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try AudioSessionImpl.call_when(instance, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try AudioSessionImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try AudioSessionImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
