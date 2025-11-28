//! Generated from: html.idl
//! Generated at: 2025-11-28T19:51:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CommandEventImpl = @import("impls").CommandEvent;
const mixins = @import("mixins");
const Event = @import("interfaces").Event;
const Element = @import("interfaces").Element;
const EventTarget = @import("interfaces").EventTarget;
const CommandEventInit = @import("dictionaries").CommandEventInit;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const CommandEvent = struct {
    pub const Meta = struct {
        pub const name = "CommandEvent";
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
            .{ "source", "get_source", null },
            .{ "command", "get_command", null },
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
            .{ "source", "get_source", null },
            .{ "command", "get_command", null },
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
            source: ?*runtime.Instance = null,
            command: runtime.DOMString = undefined,
            _internal: ?*CommandEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_command = &get_command,
        .get_source = &get_source,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CommandEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CommandEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: webidl.Opt(CommandEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CommandEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict.value);
    }

    pub fn get_source(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try CommandEventImpl.get_source(instance);
    }

    pub fn get_command(instance: *runtime.Instance) anyerror!DOMString {
        return try CommandEventImpl.get_command(instance);
    }

};
