//! Generated from: html.idl
//! Generated at: 2025-12-07T20:02:42Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const BeforeUnloadEventImpl = @import("impls").BeforeUnloadEvent;
const mixins = @import("mixins");
const Event = @import("interfaces").Event;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const EventTarget = @import("interfaces").EventTarget;
const DOMString = @import("typedefs").DOMString;

pub const BeforeUnloadEvent = struct {
    pub const Meta = struct {
        pub const name = "BeforeUnloadEvent";
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
            .{ "returnValue", "get_returnValue", "set_returnValue" },
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
            .{ "returnValue", "get_returnValue", "set_returnValue" },
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
            returnValue: runtime.DOMString = undefined,
            _internal: ?*BeforeUnloadEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_returnValue = &get_returnValue,

        .set_returnValue = &set_returnValue,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BeforeUnloadEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BeforeUnloadEventImpl.deinit(instance);
    }

    pub fn get_returnValue(instance: *runtime.Instance) anyerror!DOMString {
        return try BeforeUnloadEventImpl.get_returnValue(instance);
    }

    pub fn set_returnValue(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try BeforeUnloadEventImpl.set_returnValue(instance, value);
    }

};
