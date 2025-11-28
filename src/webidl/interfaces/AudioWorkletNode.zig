//! Generated from: webaudio.idl
//! Generated at: 2025-11-28T22:33:20Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AudioWorkletNodeImpl = @import("impls").AudioWorkletNode;
const mixins = @import("mixins");
const AudioNode = @import("interfaces").AudioNode;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const BaseAudioContext = @import("interfaces").BaseAudioContext;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const ChannelCountMode = @import("enums").ChannelCountMode;
const AudioParamMap = @import("interfaces").AudioParamMap;
const AudioWorkletNodeOptions = @import("dictionaries").AudioWorkletNodeOptions;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const AudioParam = @import("interfaces").AudioParam;
const ChannelInterpretation = @import("enums").ChannelInterpretation;
const MessagePort = @import("interfaces").MessagePort;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const AudioWorkletNode = struct {
    pub const Meta = struct {
        pub const name = "AudioWorkletNode";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *AudioNode;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "parameters", "get_parameters", null },
            .{ "port", "get_port", null },
            .{ "onprocessorerror", "get_onprocessorerror", "set_onprocessorerror" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
            .{ "parameters", "get_parameters", null },
            .{ "port", "get_port", null },
            .{ "onprocessorerror", "get_onprocessorerror", "set_onprocessorerror" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            parameters: *runtime.Instance = undefined,
            port: *runtime.Instance = undefined,
            onprocessorerror: EventHandler = undefined,
            _internal: ?*AudioWorkletNodeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_onprocessorerror = &get_onprocessorerror,
        .get_parameters = &get_parameters,
        .get_port = &get_port,

        .set_onprocessorerror = &set_onprocessorerror,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return AudioWorkletNodeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AudioWorkletNodeImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, context: *runtime.Instance, name: DOMString, options: webidl.Opt(AudioWorkletNodeOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try AudioWorkletNodeImpl.call_constructor(allocator, ctx, context, name, options);
    }

    pub fn get_parameters(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AudioWorkletNodeImpl.get_parameters(instance);
    }

    pub fn get_port(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AudioWorkletNodeImpl.get_port(instance);
    }

    pub fn get_onprocessorerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try AudioWorkletNodeImpl.get_onprocessorerror(instance);
    }

    pub fn set_onprocessorerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try AudioWorkletNodeImpl.set_onprocessorerror(instance, value);
    }

};
