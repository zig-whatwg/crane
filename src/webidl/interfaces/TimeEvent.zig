//! Generated from: svg-animations.idl
//! Generated at: 2025-11-28T19:11:19Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TimeEventImpl = @import("impls").TimeEvent;
const mixins = @import("mixins");
const Event = @import("interfaces").Event;
const Window = @import("interfaces").Window;
const EventTarget = @import("interfaces").EventTarget;
const WindowProxy = @import("typedefs").WindowProxy;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const TimeEvent = struct {
    pub const Meta = struct {
        pub const name = "TimeEvent";
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
            .{ "view", "get_view", null },
            .{ "detail", "get_detail", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "initTimeEvent", "call_initTimeEvent", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "initTimeEvent",
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
            .{ "view", "get_view", null },
            .{ "detail", "get_detail", null },
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
            view: ?WindowProxy = null,
            detail: i32 = undefined,
            _internal: ?*TimeEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_detail = &get_detail,
        .get_view = &get_view,

        .call_initTimeEvent = &call_initTimeEvent,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return TimeEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TimeEventImpl.deinit(instance);
    }

    pub fn get_view(instance: *runtime.Instance) anyerror!?WindowProxy {
        return try TimeEventImpl.get_view(instance);
    }

    pub fn get_detail(instance: *runtime.Instance) anyerror!i32 {
        return try TimeEventImpl.get_detail(instance);
    }

    pub fn call_initTimeEvent(instance: *runtime.Instance, typeArg: DOMString, viewArg: webidl.Opt(?*runtime.Instance), detailArg: webidl.Opt(i32)) anyerror!void {
        
        return try TimeEventImpl.call_initTimeEvent(instance, typeArg, viewArg, detailArg);
    }

};
