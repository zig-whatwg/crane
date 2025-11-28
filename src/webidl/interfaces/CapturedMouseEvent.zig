//! Generated from: captured-mouse-events.idl
//! Generated at: 2025-11-28T19:51:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CapturedMouseEventImpl = @import("impls").CapturedMouseEvent;
const mixins = @import("mixins");
const Event = @import("interfaces").Event;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const CapturedMouseEventInit = @import("dictionaries").CapturedMouseEventInit;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const CapturedMouseEvent = struct {
    pub const Meta = struct {
        pub const name = "CapturedMouseEvent";
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
            .{ "surfaceX", "get_surfaceX", null },
            .{ "surfaceY", "get_surfaceY", null },
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
            .{ "surfaceX", "get_surfaceX", null },
            .{ "surfaceY", "get_surfaceY", null },
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
            surfaceX: i32 = undefined,
            surfaceY: i32 = undefined,
            _internal: ?*CapturedMouseEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_surfaceX = &get_surfaceX,
        .get_surfaceY = &get_surfaceY,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CapturedMouseEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CapturedMouseEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: webidl.Opt(CapturedMouseEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CapturedMouseEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict.value);
    }

    pub fn get_surfaceX(instance: *runtime.Instance) anyerror!i32 {
        return try CapturedMouseEventImpl.get_surfaceX(instance);
    }

    pub fn get_surfaceY(instance: *runtime.Instance) anyerror!i32 {
        return try CapturedMouseEventImpl.get_surfaceY(instance);
    }

};
