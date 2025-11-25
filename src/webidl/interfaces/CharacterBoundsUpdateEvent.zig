//! Generated from: edit-context.idl
//! Generated at: 2025-11-25T20:02:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CharacterBoundsUpdateEventImpl = @import("impls").CharacterBoundsUpdateEvent;
const Event = @import("interfaces").Event;
const EventTarget = @import("interfaces").EventTarget;
const CharacterBoundsUpdateEventInit = @import("dictionaries").CharacterBoundsUpdateEventInit;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const CharacterBoundsUpdateEvent = struct {
    pub const Meta = struct {
        pub const name = "CharacterBoundsUpdateEvent";
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
            .{ "rangeStart", "get_rangeStart", null },
            .{ "rangeEnd", "get_rangeEnd", null },
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
            .{ "rangeStart", "get_rangeStart", null },
            .{ "rangeEnd", "get_rangeEnd", null },
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
            rangeStart: u32 = undefined,
            rangeEnd: u32 = undefined,
            _internal: ?*CharacterBoundsUpdateEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_rangeEnd = &get_rangeEnd,
        .get_rangeStart = &get_rangeStart,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CharacterBoundsUpdateEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CharacterBoundsUpdateEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, options: CharacterBoundsUpdateEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CharacterBoundsUpdateEventImpl.call_constructor(allocator, ctx, @"type", options);
    }

    pub fn get_rangeStart(instance: *runtime.Instance) anyerror!u32 {
        return try CharacterBoundsUpdateEventImpl.get_rangeStart(instance);
    }

    pub fn get_rangeEnd(instance: *runtime.Instance) anyerror!u32 {
        return try CharacterBoundsUpdateEventImpl.get_rangeEnd(instance);
    }

};
