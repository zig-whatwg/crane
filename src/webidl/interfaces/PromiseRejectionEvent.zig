//! Generated from: html.idl
//! Generated at: 2025-11-29T11:15:57Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PromiseRejectionEventImpl = @import("impls").PromiseRejectionEvent;
const mixins = @import("mixins");
const Event = @import("interfaces").Event;
const PromiseRejectionEventInit = @import("dictionaries").PromiseRejectionEventInit;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const PromiseRejectionEvent = struct {
    pub const Meta = struct {
        pub const name = "PromiseRejectionEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Event.State;
        pub const ParentInterface = Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "promise", "get_promise", null },
            .{ "reason", "get_reason", null },
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
            .{ "promise", "get_promise", null },
            .{ "reason", "get_reason", null },
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
            promise: *const anyopaque = undefined,
            reason: *const anyopaque = undefined,
            _internal: ?*PromiseRejectionEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_promise = &get_promise,
        .get_reason = &get_reason,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PromiseRejectionEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PromiseRejectionEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: PromiseRejectionEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try PromiseRejectionEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_promise(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PromiseRejectionEventImpl.get_promise(instance);
    }

    pub fn get_reason(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PromiseRejectionEventImpl.get_reason(instance);
    }

};
