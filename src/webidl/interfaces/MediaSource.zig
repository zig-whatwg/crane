//! Generated from: media-source.idl
//! Generated at: 2025-11-25T20:02:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaSourceImpl = @import("impls").MediaSource;
const EventTarget = @import("interfaces").EventTarget;
const EndOfStreamError = @import("enums").EndOfStreamError;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const MediaSourceHandle = @import("interfaces").MediaSourceHandle;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const SourceBufferList = @import("interfaces").SourceBufferList;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const SourceBuffer = @import("interfaces").SourceBuffer;
const EventListener = @import("interfaces").EventListener;
const ReadyState = @import("enums").ReadyState;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const MediaSource = struct {
    pub const Meta = struct {
        pub const name = "MediaSource";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "handle", "get_handle", null },
            .{ "sourceBuffers", "get_sourceBuffers", null },
            .{ "activeSourceBuffers", "get_activeSourceBuffers", null },
            .{ "readyState", "get_readyState", null },
            .{ "duration", "get_duration", "set_duration" },
            .{ "onsourceopen", "get_onsourceopen", "set_onsourceopen" },
            .{ "onsourceended", "get_onsourceended", "set_onsourceended" },
            .{ "onsourceclose", "get_onsourceclose", "set_onsourceclose" },
            .{ "canConstructInDedicatedWorker", "get_canConstructInDedicatedWorker", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "addSourceBuffer", "call_addSourceBuffer", 1 },
            .{ "removeSourceBuffer", "call_removeSourceBuffer", 1 },
            .{ "endOfStream", "call_endOfStream", 0 },
            .{ "setLiveSeekableRange", "call_setLiveSeekableRange", 2 },
            .{ "clearLiveSeekableRange", "call_clearLiveSeekableRange", 0 },
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "isTypeSupported", "call_isTypeSupported", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "addSourceBuffer",
            "removeSourceBuffer",
            "endOfStream",
            "setLiveSeekableRange",
            "clearLiveSeekableRange",
            "isTypeSupported",
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
            .{ "handle", "get_handle", null },
            .{ "sourceBuffers", "get_sourceBuffers", null },
            .{ "activeSourceBuffers", "get_activeSourceBuffers", null },
            .{ "readyState", "get_readyState", null },
            .{ "duration", "get_duration", "set_duration" },
            .{ "onsourceopen", "get_onsourceopen", "set_onsourceopen" },
            .{ "onsourceended", "get_onsourceended", "set_onsourceended" },
            .{ "onsourceclose", "get_onsourceclose", "set_onsourceclose" },
            .{ "canConstructInDedicatedWorker", "get_canConstructInDedicatedWorker", null },
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
            handle: *runtime.Instance = undefined,
            sourceBuffers: *runtime.Instance = undefined,
            activeSourceBuffers: *runtime.Instance = undefined,
            readyState: ReadyState = undefined,
            duration: f64 = undefined,
            onsourceopen: EventHandler = undefined,
            onsourceended: EventHandler = undefined,
            onsourceclose: EventHandler = undefined,
            cached_handle: ?*runtime.Instance = null,
            _internal: ?*MediaSourceImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_activeSourceBuffers = &get_activeSourceBuffers,
        .get_canConstructInDedicatedWorker = &get_canConstructInDedicatedWorker,
        .get_duration = &get_duration,
        .get_handle = &get_handle,
        .get_onsourceclose = &get_onsourceclose,
        .get_onsourceended = &get_onsourceended,
        .get_onsourceopen = &get_onsourceopen,
        .get_readyState = &get_readyState,
        .get_sourceBuffers = &get_sourceBuffers,

        .set_duration = &set_duration,
        .set_onsourceclose = &set_onsourceclose,
        .set_onsourceended = &set_onsourceended,
        .set_onsourceopen = &set_onsourceopen,

        .call_addSourceBuffer = &call_addSourceBuffer,
        .call_clearLiveSeekableRange = &call_clearLiveSeekableRange,
        .call_endOfStream = &call_endOfStream,
        .call_isTypeSupported = &call_isTypeSupported,
        .call_removeSourceBuffer = &call_removeSourceBuffer,
        .call_setLiveSeekableRange = &call_setLiveSeekableRange,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MediaSourceImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaSourceImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try MediaSourceImpl.call_constructor(allocator, ctx);
    }

    /// Extended attributes: [SameObject], [Exposed=DedicatedWorker]
    pub fn get_handle(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_handle) |cached| {
            return cached;
        }
        const value = try MediaSourceImpl.get_handle(instance);
        state.own.cached_handle = value;
        return value;
    }

    pub fn get_sourceBuffers(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try MediaSourceImpl.get_sourceBuffers(instance);
    }

    pub fn get_activeSourceBuffers(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try MediaSourceImpl.get_activeSourceBuffers(instance);
    }

    pub fn get_readyState(instance: *runtime.Instance) anyerror!ReadyState {
        return try MediaSourceImpl.get_readyState(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!f64 {
        return try MediaSourceImpl.get_duration(instance);
    }

    pub fn set_duration(instance: *runtime.Instance, value: f64) anyerror!void {
        try MediaSourceImpl.set_duration(instance, value);
    }

    pub fn get_onsourceopen(instance: *runtime.Instance) anyerror!EventHandler {
        return try MediaSourceImpl.get_onsourceopen(instance);
    }

    pub fn set_onsourceopen(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MediaSourceImpl.set_onsourceopen(instance, value);
    }

    pub fn get_onsourceended(instance: *runtime.Instance) anyerror!EventHandler {
        return try MediaSourceImpl.get_onsourceended(instance);
    }

    pub fn set_onsourceended(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MediaSourceImpl.set_onsourceended(instance, value);
    }

    pub fn get_onsourceclose(instance: *runtime.Instance) anyerror!EventHandler {
        return try MediaSourceImpl.get_onsourceclose(instance);
    }

    pub fn set_onsourceclose(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MediaSourceImpl.set_onsourceclose(instance, value);
    }

    pub fn get_canConstructInDedicatedWorker(instance: *runtime.Instance) anyerror!bool {
        return try MediaSourceImpl.get_canConstructInDedicatedWorker(instance);
    }

    pub fn call_endOfStream(instance: *runtime.Instance, @"error": EndOfStreamError) anyerror!void {
        
        return try MediaSourceImpl.call_endOfStream(instance, @"error");
    }

    pub fn call_setLiveSeekableRange(instance: *runtime.Instance, start: f64, end: f64) anyerror!void {
        
        return try MediaSourceImpl.call_setLiveSeekableRange(instance, start, end);
    }

    pub fn call_clearLiveSeekableRange(instance: *runtime.Instance) anyerror!void {
        return try MediaSourceImpl.call_clearLiveSeekableRange(instance);
    }

    pub fn call_addSourceBuffer(instance: *runtime.Instance, @"type": DOMString) anyerror!*runtime.Instance {
        
        return try MediaSourceImpl.call_addSourceBuffer(instance, @"type");
    }

    pub fn call_removeSourceBuffer(instance: *runtime.Instance, sourceBuffer: *runtime.Instance) anyerror!void {
        
        return try MediaSourceImpl.call_removeSourceBuffer(instance, sourceBuffer);
    }

    pub fn call_isTypeSupported(instance: *runtime.Instance, @"type": DOMString) anyerror!bool {
        
        return try MediaSourceImpl.call_isTypeSupported(instance, @"type");
    }

};
