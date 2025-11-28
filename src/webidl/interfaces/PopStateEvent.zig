//! Generated from: html.idl
//! Generated at: 2025-11-28T18:02:25Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PopStateEventImpl = @import("impls").PopStateEvent;
const Event = @import("interfaces").Event;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const PopStateEventInit = @import("dictionaries").PopStateEventInit;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const PopStateEvent = struct {
    pub const Meta = struct {
        pub const name = "PopStateEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "state", "get_state", null },
            .{ "hasUAVisualTransition", "get_hasUAVisualTransition", null },
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
            .{ "state", "get_state", null },
            .{ "hasUAVisualTransition", "get_hasUAVisualTransition", null },
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
            state: *const anyopaque = undefined,
            hasUAVisualTransition: bool = undefined,
            _internal: ?*PopStateEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_hasUAVisualTransition = &get_hasUAVisualTransition,
        .get_state = &get_state,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PopStateEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PopStateEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: PopStateEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try PopStateEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PopStateEventImpl.get_state(instance);
    }

    pub fn get_hasUAVisualTransition(instance: *runtime.Instance) anyerror!bool {
        return try PopStateEventImpl.get_hasUAVisualTransition(instance);
    }

};
