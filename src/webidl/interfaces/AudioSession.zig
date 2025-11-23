//! Generated from: audio-session.idl
//! Generated at: 2025-11-23T16:59:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AudioSessionImpl = @import("impls").AudioSession;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const EventHandler = @import("typedefs").EventHandler;
const AudioSessionState = @import("enums").AudioSessionState;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const Event = @import("interfaces").Event;
const EventListener = @import("interfaces").EventListener;
const AudioSessionType = @import("enums").AudioSessionType;
const Observable = @import("interfaces").Observable;

pub const AudioSession = struct {
    pub const Meta = struct {
        pub const name = "AudioSession";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "type", "get_type", "set_type" },
            .{ "state", "get_state", null },
            .{ "onstatechange", "get_onstatechange", "set_onstatechange" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
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
            .{ "type", "get_type", "set_type" },
            .{ "state", "get_state", null },
            .{ "onstatechange", "get_onstatechange", "set_onstatechange" },
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
            @"type": AudioSessionType = undefined,
            state: AudioSessionState = undefined,
            onstatechange: EventHandler = undefined,
            _internal: ?*AudioSessionImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_onstatechange = &get_onstatechange,
        .get_state = &get_state,
        .get_type = &get_type,

        .set_onstatechange = &set_onstatechange,
        .set_type = &set_type,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return AudioSessionImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AudioSessionImpl.deinit(instance);
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

};
