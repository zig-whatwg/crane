//! Generated from: remote-playback.idl
//! Generated at: 2025-12-07T19:32:58Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const RemotePlaybackImpl = @import("impls").RemotePlayback;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const RemotePlaybackState = @import("enums").RemotePlaybackState;
const RemotePlaybackAvailabilityCallback = @import("callbacks").RemotePlaybackAvailabilityCallback;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const RemotePlayback = struct {
    pub const Meta = struct {
        pub const name = "RemotePlayback";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "state", "get_state", null },
            .{ "onconnecting", "get_onconnecting", "set_onconnecting" },
            .{ "onconnect", "get_onconnect", "set_onconnect" },
            .{ "ondisconnect", "get_ondisconnect", "set_ondisconnect" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "watchAvailability", "call_watchAvailability", 1 },
            .{ "cancelWatchAvailability", "call_cancelWatchAvailability", 0 },
            .{ "prompt", "call_prompt", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "watchAvailability",
            "cancelWatchAvailability",
            "prompt",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "state", "get_state", null },
            .{ "onconnecting", "get_onconnecting", "set_onconnecting" },
            .{ "onconnect", "get_onconnect", "set_onconnect" },
            .{ "ondisconnect", "get_ondisconnect", "set_ondisconnect" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            state: RemotePlaybackState = undefined,
            onconnecting: EventHandler = undefined,
            onconnect: EventHandler = undefined,
            ondisconnect: EventHandler = undefined,
            _internal: ?*RemotePlaybackImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_onconnect = &get_onconnect,
        .get_onconnecting = &get_onconnecting,
        .get_ondisconnect = &get_ondisconnect,
        .get_state = &get_state,

        .set_onconnect = &set_onconnect,
        .set_onconnecting = &set_onconnecting,
        .set_ondisconnect = &set_ondisconnect,

        .call_cancelWatchAvailability = &call_cancelWatchAvailability,
        .call_prompt = &call_prompt,
        .call_watchAvailability = &call_watchAvailability,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RemotePlaybackImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RemotePlaybackImpl.deinit(instance);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!RemotePlaybackState {
        return try RemotePlaybackImpl.get_state(instance);
    }

    pub fn get_onconnecting(instance: *runtime.Instance) anyerror!EventHandler {
        return try RemotePlaybackImpl.get_onconnecting(instance);
    }

    pub fn set_onconnecting(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RemotePlaybackImpl.set_onconnecting(instance, value);
    }

    pub fn get_onconnect(instance: *runtime.Instance) anyerror!EventHandler {
        return try RemotePlaybackImpl.get_onconnect(instance);
    }

    pub fn set_onconnect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RemotePlaybackImpl.set_onconnect(instance, value);
    }

    pub fn get_ondisconnect(instance: *runtime.Instance) anyerror!EventHandler {
        return try RemotePlaybackImpl.get_ondisconnect(instance);
    }

    pub fn set_ondisconnect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RemotePlaybackImpl.set_ondisconnect(instance, value);
    }

    pub fn call_watchAvailability(instance: *runtime.Instance, callback: RemotePlaybackAvailabilityCallback) anyerror!*const anyopaque {
        
        return try RemotePlaybackImpl.call_watchAvailability(instance, callback);
    }

    pub fn call_cancelWatchAvailability(instance: *runtime.Instance, id: webidl.Opt(i32)) anyerror!*const anyopaque {
        
        return try RemotePlaybackImpl.call_cancelWatchAvailability(instance, id);
    }

    pub fn call_prompt(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try RemotePlaybackImpl.call_prompt(instance);
    }

};
