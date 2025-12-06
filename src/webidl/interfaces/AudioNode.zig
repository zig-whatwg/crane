//! Generated from: webaudio.idl
//! Generated at: 2025-12-05T20:30:46Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AudioNodeImpl = @import("impls").AudioNode;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const BaseAudioContext = @import("interfaces").BaseAudioContext;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const ChannelCountMode = @import("enums").ChannelCountMode;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const AudioParam = @import("interfaces").AudioParam;
const ChannelInterpretation = @import("enums").ChannelInterpretation;
const EventListener = @import("interfaces").EventListener;
const DOMString = @import("typedefs").DOMString;

pub const AudioNode = struct {
    pub const Meta = struct {
        pub const name = "AudioNode";
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
            .{ "context", "get_context", null },
            .{ "numberOfInputs", "get_numberOfInputs", null },
            .{ "numberOfOutputs", "get_numberOfOutputs", null },
            .{ "channelCount", "get_channelCount", "set_channelCount" },
            .{ "channelCountMode", "get_channelCountMode", "set_channelCountMode" },
            .{ "channelInterpretation", "get_channelInterpretation", "set_channelInterpretation" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "connect", "call_connect", 1 },
            .{ "connect", "call_connect", 1 },
            .{ "disconnect", "call_disconnect", 0 },
            .{ "disconnect", "call_disconnect", 1 },
            .{ "disconnect", "call_disconnect", 1 },
            .{ "disconnect", "call_disconnect", 2 },
            .{ "disconnect", "call_disconnect", 3 },
            .{ "disconnect", "call_disconnect", 1 },
            .{ "disconnect", "call_disconnect", 2 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
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

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "context", "get_context", null },
            .{ "numberOfInputs", "get_numberOfInputs", null },
            .{ "numberOfOutputs", "get_numberOfOutputs", null },
            .{ "channelCount", "get_channelCount", "set_channelCount" },
            .{ "channelCountMode", "get_channelCountMode", "set_channelCountMode" },
            .{ "channelInterpretation", "get_channelInterpretation", "set_channelInterpretation" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            context: *runtime.Instance = undefined,
            numberOfInputs: u32 = undefined,
            numberOfOutputs: u32 = undefined,
            channelCount: u32 = undefined,
            channelCountMode: ChannelCountMode = undefined,
            channelInterpretation: ChannelInterpretation = undefined,
            _internal: ?*AudioNodeImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_channelCount = &get_channelCount,
        .get_channelCountMode = &get_channelCountMode,
        .get_channelInterpretation = &get_channelInterpretation,
        .get_context = &get_context,
        .get_numberOfInputs = &get_numberOfInputs,
        .get_numberOfOutputs = &get_numberOfOutputs,

        .set_channelCount = &set_channelCount,
        .set_channelCountMode = &set_channelCountMode,
        .set_channelInterpretation = &set_channelInterpretation,

        .call_connect = &call_connect,
        .call_disconnect = &call_disconnect,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return AudioNodeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AudioNodeImpl.deinit(instance);
    }

    pub fn get_context(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AudioNodeImpl.get_context(instance);
    }

    pub fn get_numberOfInputs(instance: *runtime.Instance) anyerror!u32 {
        return try AudioNodeImpl.get_numberOfInputs(instance);
    }

    pub fn get_numberOfOutputs(instance: *runtime.Instance) anyerror!u32 {
        return try AudioNodeImpl.get_numberOfOutputs(instance);
    }

    pub fn get_channelCount(instance: *runtime.Instance) anyerror!u32 {
        return try AudioNodeImpl.get_channelCount(instance);
    }

    pub fn set_channelCount(instance: *runtime.Instance, value: u32) anyerror!void {
        try AudioNodeImpl.set_channelCount(instance, value);
    }

    pub fn get_channelCountMode(instance: *runtime.Instance) anyerror!ChannelCountMode {
        return try AudioNodeImpl.get_channelCountMode(instance);
    }

    pub fn set_channelCountMode(instance: *runtime.Instance, value: ChannelCountMode) anyerror!void {
        try AudioNodeImpl.set_channelCountMode(instance, value);
    }

    pub fn get_channelInterpretation(instance: *runtime.Instance) anyerror!ChannelInterpretation {
        return try AudioNodeImpl.get_channelInterpretation(instance);
    }

    pub fn set_channelInterpretation(instance: *runtime.Instance, value: ChannelInterpretation) anyerror!void {
        try AudioNodeImpl.set_channelInterpretation(instance, value);
    }

    pub fn call_disconnect(instance: *runtime.Instance) anyerror!void {
        return try AudioNodeImpl.call_disconnect(instance);
    }

    pub fn call_connect(instance: *runtime.Instance, destinationNode: *runtime.Instance, output: webidl.Opt(u32), input: webidl.Opt(u32)) anyerror!*runtime.Instance {
        return try AudioNodeImpl.call_connect(instance, destinationNode, output, input);
    }
};
