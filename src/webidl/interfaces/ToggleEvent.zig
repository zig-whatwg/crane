//! Generated from: html.idl
//! Generated at: 2025-11-29T05:01:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ToggleEventImpl = @import("impls").ToggleEvent;
const mixins = @import("mixins");
const Event = @import("interfaces").Event;
const ToggleEventInit = @import("dictionaries").ToggleEventInit;
const Element = @import("interfaces").Element;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const ToggleEvent = struct {
    pub const Meta = struct {
        pub const name = "ToggleEvent";
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
            .{ "oldState", "get_oldState", null },
            .{ "newState", "get_newState", null },
            .{ "source", "get_source", null },
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
            .{ "oldState", "get_oldState", null },
            .{ "newState", "get_newState", null },
            .{ "source", "get_source", null },
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
            oldState: runtime.DOMString = undefined,
            newState: runtime.DOMString = undefined,
            source: ?*runtime.Instance = null,
            _internal: ?*ToggleEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_newState = &get_newState,
        .get_oldState = &get_oldState,
        .get_source = &get_source,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ToggleEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ToggleEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: webidl.Opt(ToggleEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try ToggleEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_oldState(instance: *runtime.Instance) anyerror!DOMString {
        return try ToggleEventImpl.get_oldState(instance);
    }

    pub fn get_newState(instance: *runtime.Instance) anyerror!DOMString {
        return try ToggleEventImpl.get_newState(instance);
    }

    pub fn get_source(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ToggleEventImpl.get_source(instance);
    }

};
