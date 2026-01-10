//! Generated from: webcodecs.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AudioDecoderImpl = @import("impls").AudioDecoder;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("EventTarget.zig").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const CodecState = @import("enums").CodecState;
const AudioDecoderConfig = @import("dictionaries").AudioDecoderConfig;
const Observable = @import("Observable.zig").Observable;
const Event = @import("Event.zig").Event;
const AudioDecoderInit = @import("dictionaries").AudioDecoderInit;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EncodedAudioChunk = @import("EncodedAudioChunk.zig").EncodedAudioChunk;
const EventListener = @import("EventListener.zig").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const AudioDecoderSupport = @import("dictionaries").AudioDecoderSupport;

pub const AudioDecoder = struct {
    pub const Meta = struct {
        pub const name = "AudioDecoder";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
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
            .{ "decodeQueueSize", "get_decodeQueueSize", null },
            .{ "ondequeue", "get_ondequeue", "set_ondequeue" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "configure", "call_configure", 1 },
            .{ "decode", "call_decode", 1 },
            .{ "flush", "call_flush", 0 },
            .{ "reset", "call_reset", 0 },
            .{ "close", "call_close", 0 },
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "isConfigSupported", "call_static_isConfigSupported", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "configure",
            "decode",
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
            .{ "decodeQueueSize", "get_decodeQueueSize", null },
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
            state: enums.CodecState = undefined,
            decodeQueueSize: u32 = undefined,
            ondequeue: typedefs.EventHandler = undefined,
            _internal: ?*AudioDecoderImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_decodeQueueSize = &get_decodeQueueSize,
        .get_ondequeue = &get_ondequeue,
        .get_state = &get_state,

        .set_ondequeue = &set_ondequeue,

        .call_close = &call_close,
        .call_configure = &call_configure,
        .call_decode = &call_decode,
        .call_flush = &call_flush,
        .call_reset = &call_reset,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return AudioDecoderImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return AudioDecoderImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AudioDecoderImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, init_data: AudioDecoderInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try AudioDecoderImpl.call_constructor(ctx, init_data);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!CodecState {
        return try AudioDecoderImpl.get_state(instance);
    }

    pub fn get_decodeQueueSize(instance: *runtime.Instance) anyerror!u32 {
        return try AudioDecoderImpl.get_decodeQueueSize(instance);
    }

    pub fn get_ondequeue(instance: *runtime.Instance) anyerror!EventHandler {
        return try AudioDecoderImpl.get_ondequeue(instance);
    }

    pub fn set_ondequeue(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try AudioDecoderImpl.set_ondequeue(instance, value);
    }

    pub fn call_reset(instance: *runtime.Instance) anyerror!void {
        return try AudioDecoderImpl.call_reset(instance);
    }

    pub fn call_configure(instance: *runtime.Instance, config: AudioDecoderConfig) anyerror!void {
        
        return try AudioDecoderImpl.call_configure(instance, config);
    }

    pub fn call_decode(instance: *runtime.Instance, chunk: *runtime.Instance) anyerror!void {
        
        return try AudioDecoderImpl.call_decode(instance, chunk);
    }

    pub fn call_flush(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try AudioDecoderImpl.call_flush(instance);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try AudioDecoderImpl.call_close(instance);
    }

    pub fn call_static_isConfigSupported(instance: *runtime.Instance, config: AudioDecoderConfig) anyerror!runtime.JSValue {
        
        return try AudioDecoderImpl.call_static_isConfigSupported(instance, config);
    }

};
