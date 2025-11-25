//! Generated from: webcodecs.idl
//! Generated at: 2025-11-25T14:21:38Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AudioEncoderImpl = @import("impls").AudioEncoder;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const AudioEncoderSupport = @import("dictionaries").AudioEncoderSupport;
const CodecState = @import("enums").CodecState;
const Event = @import("interfaces").Event;
const AudioEncoderInit = @import("dictionaries").AudioEncoderInit;
const Observable = @import("interfaces").Observable;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const AudioData = @import("interfaces").AudioData;
const AudioEncoderConfig = @import("dictionaries").AudioEncoderConfig;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const AudioEncoder = struct {
    pub const Meta = struct {
        pub const name = "AudioEncoder";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "state", "get_state", null },
            .{ "encodeQueueSize", "get_encodeQueueSize", null },
            .{ "ondequeue", "get_ondequeue", "set_ondequeue" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "configure", "call_configure", 1 },
            .{ "encode", "call_encode", 1 },
            .{ "flush", "call_flush", 0 },
            .{ "reset", "call_reset", 0 },
            .{ "close", "call_close", 0 },
            .{ "isConfigSupported", "call_isConfigSupported", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "configure",
            "encode",
            "flush",
            "reset",
            "close",
            "isConfigSupported",
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
            .{ "encodeQueueSize", "get_encodeQueueSize", null },
            .{ "ondequeue", "get_ondequeue", "set_ondequeue" },
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
            state: CodecState = undefined,
            encodeQueueSize: u32 = undefined,
            ondequeue: EventHandler = undefined,
            _internal: ?*AudioEncoderImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_encodeQueueSize = &get_encodeQueueSize,
        .get_ondequeue = &get_ondequeue,
        .get_state = &get_state,

        .set_ondequeue = &set_ondequeue,

        .call_close = &call_close,
        .call_configure = &call_configure,
        .call_encode = &call_encode,
        .call_flush = &call_flush,
        .call_isConfigSupported = &call_isConfigSupported,
        .call_reset = &call_reset,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return AudioEncoderImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AudioEncoderImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, init_data: AudioEncoderInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try AudioEncoderImpl.call_constructor(allocator, ctx, init_data);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!CodecState {
        return try AudioEncoderImpl.get_state(instance);
    }

    pub fn get_encodeQueueSize(instance: *runtime.Instance) anyerror!u32 {
        return try AudioEncoderImpl.get_encodeQueueSize(instance);
    }

    pub fn get_ondequeue(instance: *runtime.Instance) anyerror!EventHandler {
        return try AudioEncoderImpl.get_ondequeue(instance);
    }

    pub fn set_ondequeue(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try AudioEncoderImpl.set_ondequeue(instance, value);
    }

    pub fn call_isConfigSupported(instance: *runtime.Instance, config: AudioEncoderConfig) anyerror!*const anyopaque {
        
        return try AudioEncoderImpl.call_isConfigSupported(instance, config);
    }

    pub fn call_encode(instance: *runtime.Instance, data: *runtime.Instance) anyerror!void {
        
        return try AudioEncoderImpl.call_encode(instance, data);
    }

    pub fn call_reset(instance: *runtime.Instance) anyerror!void {
        return try AudioEncoderImpl.call_reset(instance);
    }

    pub fn call_configure(instance: *runtime.Instance, config: AudioEncoderConfig) anyerror!void {
        
        return try AudioEncoderImpl.call_configure(instance, config);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try AudioEncoderImpl.call_close(instance);
    }

    pub fn call_flush(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try AudioEncoderImpl.call_flush(instance);
    }

};
