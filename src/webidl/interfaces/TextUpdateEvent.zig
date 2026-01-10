//! Generated from: edit-context.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TextUpdateEventImpl = @import("impls").TextUpdateEvent;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Event = @import("Event.zig").Event;
const EventTarget = @import("EventTarget.zig").EventTarget;
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
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            updateRangeStart: u32 = undefined,
            updateRangeEnd: u32 = undefined,
            text: typedefs.DOMString = undefined,
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

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return TextUpdateEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return TextUpdateEventImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TextUpdateEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, @"type": DOMString, options: webidl.Opt(TextUpdateEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try TextUpdateEventImpl.call_constructor(ctx, @"type", options);
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
