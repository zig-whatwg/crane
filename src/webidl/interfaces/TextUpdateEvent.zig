//! Generated from: edit-context.idl
//! Generated at: 2025-11-28T03:24:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TextUpdateEventImpl = @import("impls").TextUpdateEvent;
const Event = @import("interfaces").Event;
const EventTarget = @import("interfaces").EventTarget;
const TextUpdateEventInit = @import("dictionaries").TextUpdateEventInit;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const TextUpdateEvent = struct {
    pub const Meta = struct {
        pub const name = "TextUpdateEvent";
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
            .{ "updateRangeStart", "get_updateRangeStart", null },
            .{ "updateRangeEnd", "get_updateRangeEnd", null },
            .{ "text", "get_text", null },
            .{ "selectionStart", "get_selectionStart", null },
            .{ "selectionEnd", "get_selectionEnd", null },
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
            .{ "updateRangeStart", "get_updateRangeStart", null },
            .{ "updateRangeEnd", "get_updateRangeEnd", null },
            .{ "text", "get_text", null },
            .{ "selectionStart", "get_selectionStart", null },
            .{ "selectionEnd", "get_selectionEnd", null },
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
            updateRangeStart: u32 = undefined,
            updateRangeEnd: u32 = undefined,
            text: runtime.DOMString = undefined,
            selectionStart: u32 = undefined,
            selectionEnd: u32 = undefined,
            _internal: ?*TextUpdateEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_selectionEnd = &get_selectionEnd,
        .get_selectionStart = &get_selectionStart,
        .get_text = &get_text,
        .get_updateRangeEnd = &get_updateRangeEnd,
        .get_updateRangeStart = &get_updateRangeStart,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return TextUpdateEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TextUpdateEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, options: TextUpdateEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try TextUpdateEventImpl.call_constructor(allocator, ctx, @"type", options);
    }

    pub fn get_updateRangeStart(instance: *runtime.Instance) anyerror!u32 {
        return try TextUpdateEventImpl.get_updateRangeStart(instance);
    }

    pub fn get_updateRangeEnd(instance: *runtime.Instance) anyerror!u32 {
        return try TextUpdateEventImpl.get_updateRangeEnd(instance);
    }

    pub fn get_text(instance: *runtime.Instance) anyerror!DOMString {
        return try TextUpdateEventImpl.get_text(instance);
    }

    pub fn get_selectionStart(instance: *runtime.Instance) anyerror!u32 {
        return try TextUpdateEventImpl.get_selectionStart(instance);
    }

    pub fn get_selectionEnd(instance: *runtime.Instance) anyerror!u32 {
        return try TextUpdateEventImpl.get_selectionEnd(instance);
    }

};
