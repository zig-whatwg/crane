//! Generated from: encrypted-media.idl
//! Generated at: 2025-12-07T20:02:44Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const MediaKeyMessageEventImpl = @import("impls").MediaKeyMessageEvent;
const mixins = @import("mixins");
const Event = @import("interfaces").Event;
const EventTarget = @import("interfaces").EventTarget;
const MediaKeyMessageType = @import("enums").MediaKeyMessageType;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const MediaKeyMessageEventInit = @import("dictionaries").MediaKeyMessageEventInit;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const MediaKeyMessageEvent = struct {
    pub const Meta = struct {
        pub const name = "MediaKeyMessageEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Event.State;
        pub const ParentInterface = Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "messageType", "get_messageType", null },
            .{ "message", "get_message", null },
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
            .{ "messageType", "get_messageType", null },
            .{ "message", "get_message", null },
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
            messageType: MediaKeyMessageType = undefined,
            message: runtime.ArrayBuffer = undefined,
            _internal: ?*MediaKeyMessageEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_message = &get_message,
        .get_messageType = &get_messageType,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MediaKeyMessageEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaKeyMessageEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: MediaKeyMessageEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try MediaKeyMessageEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_messageType(instance: *runtime.Instance) anyerror!MediaKeyMessageType {
        return try MediaKeyMessageEventImpl.get_messageType(instance);
    }

    pub fn get_message(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try MediaKeyMessageEventImpl.get_message(instance);
    }

};
