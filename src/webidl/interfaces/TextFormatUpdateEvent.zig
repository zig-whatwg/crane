//! Generated from: edit-context.idl
//! Generated at: 2025-11-25T20:02:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TextFormatUpdateEventImpl = @import("impls").TextFormatUpdateEvent;
const Event = @import("interfaces").Event;
const TextFormat = @import("interfaces").TextFormat;
const TextFormatUpdateEventInit = @import("dictionaries").TextFormatUpdateEventInit;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const TextFormatUpdateEvent = struct {
    pub const Meta = struct {
        pub const name = "TextFormatUpdateEvent";
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
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getTextFormats", "call_getTextFormats", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getTextFormats",
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
            _internal: ?*TextFormatUpdateEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_getTextFormats = &call_getTextFormats,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return TextFormatUpdateEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TextFormatUpdateEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, options: TextFormatUpdateEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try TextFormatUpdateEventImpl.call_constructor(allocator, ctx, @"type", options);
    }

    pub fn call_getTextFormats(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try TextFormatUpdateEventImpl.call_getTextFormats(instance);
    }

};
