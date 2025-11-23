//! Generated from: gamepad.idl
//! Generated at: 2025-11-23T01:22:14Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GamepadEventImpl = @import("impls").GamepadEvent;
const Event = @import("interfaces").Event;
const GamepadEventInit = @import("dictionaries").GamepadEventInit;
const Gamepad = @import("interfaces").Gamepad;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const GamepadEvent = struct {
    pub const Meta = struct {
        pub const name = "GamepadEvent";
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
            .{ "gamepad", "get_gamepad", null },
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
            .{ "gamepad", "get_gamepad", null },
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
            gamepad: Gamepad = undefined,
            cached_gamepad: ?Gamepad = null,
        },
    );

    const delegates = .{

        .get_gamepad = &get_gamepad,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GamepadEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GamepadEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: GamepadEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try GamepadEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    /// Extended attributes: [SameObject]
    pub fn get_gamepad(instance: *runtime.Instance) anyerror!Gamepad {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_gamepad) |cached| {
            return cached;
        }
        const value = try GamepadEventImpl.get_gamepad(instance);
        state.own.cached_gamepad = value;
        return value;
    }

};
