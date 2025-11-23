//! Generated from: html.idl
//! Generated at: 2025-11-23T19:57:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HashChangeEventImpl = @import("impls").HashChangeEvent;
const Event = @import("interfaces").Event;
const HashChangeEventInit = @import("dictionaries").HashChangeEventInit;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const HashChangeEvent = struct {
    pub const Meta = struct {
        pub const name = "HashChangeEvent";
        pub const is_mixin = false;
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
            .{ "oldURL", "get_oldURL", null },
            .{ "newURL", "get_newURL", null },
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
            .{ "oldURL", "get_oldURL", null },
            .{ "newURL", "get_newURL", null },
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
            oldURL: runtime.USVString = undefined,
            newURL: runtime.USVString = undefined,
            _internal: ?*HashChangeEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_newURL = &get_newURL,
        .get_oldURL = &get_oldURL,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HashChangeEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HashChangeEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: HashChangeEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HashChangeEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_oldURL(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HashChangeEventImpl.get_oldURL(instance);
    }

    pub fn get_newURL(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HashChangeEventImpl.get_newURL(instance);
    }

};
