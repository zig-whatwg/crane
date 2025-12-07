//! Generated from: presentation-api.idl
//! Generated at: 2025-12-07T19:32:59Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const PresentationConnectionCloseEventImpl = @import("impls").PresentationConnectionCloseEvent;
const mixins = @import("mixins");
const Event = @import("interfaces").Event;
const PresentationConnectionCloseReason = @import("enums").PresentationConnectionCloseReason;
const EventTarget = @import("interfaces").EventTarget;
const PresentationConnectionCloseEventInit = @import("dictionaries").PresentationConnectionCloseEventInit;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const PresentationConnectionCloseEvent = struct {
    pub const Meta = struct {
        pub const name = "PresentationConnectionCloseEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Event.State;
        pub const ParentInterface = Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "reason", "get_reason", null },
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
            .{ "reason", "get_reason", null },
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
            reason: PresentationConnectionCloseReason = undefined,
            message: runtime.DOMString = undefined,
            _internal: ?*PresentationConnectionCloseEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_message = &get_message,
        .get_reason = &get_reason,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PresentationConnectionCloseEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PresentationConnectionCloseEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: PresentationConnectionCloseEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try PresentationConnectionCloseEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_reason(instance: *runtime.Instance) anyerror!PresentationConnectionCloseReason {
        return try PresentationConnectionCloseEventImpl.get_reason(instance);
    }

    pub fn get_message(instance: *runtime.Instance) anyerror!DOMString {
        return try PresentationConnectionCloseEventImpl.get_message(instance);
    }

};
