//! Generated from: media-source.idl
//! Generated at: 2025-11-29T05:01:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ManagedSourceBufferImpl = @import("impls").ManagedSourceBuffer;
const mixins = @import("mixins");
const SourceBuffer = @import("interfaces").SourceBuffer;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const AppendMode = @import("enums").AppendMode;
const AudioTrackList = @import("interfaces").AudioTrackList;
const TextTrackList = @import("interfaces").TextTrackList;
const Observable = @import("interfaces").Observable;
const TimeRanges = @import("interfaces").TimeRanges;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const BufferSource = @import("typedefs").BufferSource;
const EventListener = @import("interfaces").EventListener;
const VideoTrackList = @import("interfaces").VideoTrackList;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const ManagedSourceBuffer = struct {
    pub const Meta = struct {
        pub const name = "ManagedSourceBuffer";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = SourceBuffer.State;
        pub const ParentInterface = SourceBuffer;
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
            .{ "onbufferedchange", "get_onbufferedchange", "set_onbufferedchange" },
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
            "appendBuffer",
            "abort",
            "changeType",
            "remove",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "onbufferedchange", "get_onbufferedchange", "set_onbufferedchange" },
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
            onbufferedchange: EventHandler = undefined,
            _internal: ?*ManagedSourceBufferImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_onbufferedchange = &get_onbufferedchange,

        .set_onbufferedchange = &set_onbufferedchange,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ManagedSourceBufferImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ManagedSourceBufferImpl.deinit(instance);
    }

    pub fn get_onbufferedchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try ManagedSourceBufferImpl.get_onbufferedchange(instance);
    }

    pub fn set_onbufferedchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ManagedSourceBufferImpl.set_onbufferedchange(instance, value);
    }

};
