//! Generated from: webrtc.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const RTCDataChannelEventImpl = @import("impls").RTCDataChannelEvent;
const mixins = @import("mixins");
const Event = @import("interfaces").Event;
const RTCDataChannel = @import("interfaces").RTCDataChannel;
const EventTarget = @import("interfaces").EventTarget;
const RTCDataChannelEventInit = @import("dictionaries").RTCDataChannelEventInit;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const RTCDataChannelEvent = struct {
    pub const Meta = struct {
        pub const name = "RTCDataChannelEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Event.State;
        pub const ParentInterface = Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "channel", "get_channel", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "channel", "get_channel", null },
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
            channel: *runtime.Instance = undefined,
            _internal: ?*RTCDataChannelEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_channel = &get_channel,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RTCDataChannelEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCDataChannelEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: RTCDataChannelEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try RTCDataChannelEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_channel(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try RTCDataChannelEventImpl.get_channel(instance);
    }

};
