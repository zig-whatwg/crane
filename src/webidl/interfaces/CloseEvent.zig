//! Generated from: websockets.idl
//! Generated at: 2025-11-23T01:22:15Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CloseEventImpl = @import("impls").CloseEvent;
const Event = @import("interfaces").Event;
const DOMString = @import("typedefs").DOMString;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const USVString = @import("interfaces").USVString;
const CloseEventInit = @import("dictionaries").CloseEventInit;

pub const CloseEvent = struct {
    pub const Meta = struct {
        pub const name = "CloseEvent";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "wasClean", "get_wasClean", null },
            .{ "code", "get_code", null },
            .{ "reason", "get_reason", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
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
            .{ "wasClean", "get_wasClean", null },
            .{ "code", "get_code", null },
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
            wasClean: bool = undefined,
            code: u16 = undefined,
            reason: runtime.USVString = undefined,
        },
    );

    const delegates = .{

        .get_code = &get_code,
        .get_reason = &get_reason,
        .get_wasClean = &get_wasClean,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CloseEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CloseEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: CloseEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CloseEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_wasClean(instance: *runtime.Instance) anyerror!bool {
        return try CloseEventImpl.get_wasClean(instance);
    }

    pub fn get_code(instance: *runtime.Instance) anyerror!u16 {
        return try CloseEventImpl.get_code(instance);
    }

    pub fn get_reason(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try CloseEventImpl.get_reason(instance);
    }

};
