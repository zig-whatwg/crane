//! Generated from: webaudio.idl
//! Generated at: 2025-12-05T20:30:47Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AudioScheduledSourceNodeImpl = @import("impls").AudioScheduledSourceNode;
const mixins = @import("mixins");
const AudioNode = @import("interfaces").AudioNode;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const BaseAudioContext = @import("interfaces").BaseAudioContext;
const ChannelCountMode = @import("enums").ChannelCountMode;
const Event = @import("interfaces").Event;
const Observable = @import("interfaces").Observable;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const AudioParam = @import("interfaces").AudioParam;
const ChannelInterpretation = @import("enums").ChannelInterpretation;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const AudioScheduledSourceNode = struct {
    pub const Meta = struct {
        pub const name = "AudioScheduledSourceNode";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = AudioNode.State;
        pub const ParentInterface = AudioNode;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "onended", "get_onended", "set_onended" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "start", "call_start", 0 },
            .{ "stop", "call_stop", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "start",
            "stop",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
            "connect",
            "connect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "onended", "get_onended", "set_onended" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            onended: EventHandler = undefined,
            _internal: ?*AudioScheduledSourceNodeImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_onended = &get_onended,

        .set_onended = &set_onended,

        .call_start = &call_start,
        .call_stop = &call_stop,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return AudioScheduledSourceNodeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AudioScheduledSourceNodeImpl.deinit(instance);
    }

    pub fn get_onended(instance: *runtime.Instance) anyerror!EventHandler {
        return try AudioScheduledSourceNodeImpl.get_onended(instance);
    }

    pub fn set_onended(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try AudioScheduledSourceNodeImpl.set_onended(instance, value);
    }

    pub fn call_stop(instance: *runtime.Instance, when: webidl.Opt(f64)) anyerror!void {
        return try AudioScheduledSourceNodeImpl.call_stop(instance, when);
    }

    pub fn call_start(instance: *runtime.Instance, when: webidl.Opt(f64)) anyerror!void {
        return try AudioScheduledSourceNodeImpl.call_start(instance, when);
    }
};
