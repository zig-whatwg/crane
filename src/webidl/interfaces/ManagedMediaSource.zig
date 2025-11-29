//! Generated from: media-source.idl
//! Generated at: 2025-11-29T02:15:45Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ManagedMediaSourceImpl = @import("impls").ManagedMediaSource;
const mixins = @import("mixins");
const MediaSource = @import("interfaces").MediaSource;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const EndOfStreamError = @import("enums").EndOfStreamError;
const MediaSourceHandle = @import("interfaces").MediaSourceHandle;
const DOMString = @import("typedefs").DOMString;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const SourceBufferList = @import("interfaces").SourceBufferList;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const SourceBuffer = @import("interfaces").SourceBuffer;
const EventListener = @import("interfaces").EventListener;
const ReadyState = @import("enums").ReadyState;
const EventHandler = @import("typedefs").EventHandler;

pub const ManagedMediaSource = struct {
    pub const Meta = struct {
        pub const name = "ManagedMediaSource";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *MediaSource;
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
            .{ "streaming", "get_streaming", null },
            .{ "onstartstreaming", "get_onstartstreaming", "set_onstartstreaming" },
            .{ "onendstreaming", "get_onendstreaming", "set_onendstreaming" },
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
            "addSourceBuffer",
            "removeSourceBuffer",
            "endOfStream",
            "setLiveSeekableRange",
            "clearLiveSeekableRange",
            "isTypeSupported",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "streaming", "get_streaming", null },
            .{ "onstartstreaming", "get_onstartstreaming", "set_onstartstreaming" },
            .{ "onendstreaming", "get_onendstreaming", "set_onendstreaming" },
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
            streaming: bool = undefined,
            onstartstreaming: EventHandler = undefined,
            onendstreaming: EventHandler = undefined,
            _internal: ?*ManagedMediaSourceImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_onendstreaming = &get_onendstreaming,
        .get_onstartstreaming = &get_onstartstreaming,
        .get_streaming = &get_streaming,

        .set_onendstreaming = &set_onendstreaming,
        .set_onstartstreaming = &set_onstartstreaming,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ManagedMediaSourceImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ManagedMediaSourceImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try ManagedMediaSourceImpl.call_constructor(allocator, ctx);
    }

    pub fn get_streaming(instance: *runtime.Instance) anyerror!bool {
        return try ManagedMediaSourceImpl.get_streaming(instance);
    }

    pub fn get_onstartstreaming(instance: *runtime.Instance) anyerror!EventHandler {
        return try ManagedMediaSourceImpl.get_onstartstreaming(instance);
    }

    pub fn set_onstartstreaming(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ManagedMediaSourceImpl.set_onstartstreaming(instance, value);
    }

    pub fn get_onendstreaming(instance: *runtime.Instance) anyerror!EventHandler {
        return try ManagedMediaSourceImpl.get_onendstreaming(instance);
    }

    pub fn set_onendstreaming(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ManagedMediaSourceImpl.set_onendstreaming(instance, value);
    }

};
