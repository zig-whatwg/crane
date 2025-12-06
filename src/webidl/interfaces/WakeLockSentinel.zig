//! Generated from: screen-wake-lock.idl
//! Generated at: 2025-12-05T20:30:47Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WakeLockSentinelImpl = @import("impls").WakeLockSentinel;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const WakeLockType = @import("enums").WakeLockType;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const WakeLockSentinel = struct {
    pub const Meta = struct {
        pub const name = "WakeLockSentinel";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{"Window"} } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "released", "get_released", null },
            .{ "type", "get_type", null },
            .{ "onrelease", "get_onrelease", "set_onrelease" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "release", "call_release", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "release",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "released", "get_released", null },
            .{ "type", "get_type", null },
            .{ "onrelease", "get_onrelease", "set_onrelease" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            released: bool = undefined,
            type: WakeLockType = undefined,
            onrelease: EventHandler = undefined,
            _internal: ?*WakeLockSentinelImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_onrelease = &get_onrelease,
        .get_released = &get_released,
        .get_type = &get_type,

        .set_onrelease = &set_onrelease,

        .call_release = &call_release,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WakeLockSentinelImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WakeLockSentinelImpl.deinit(instance);
    }

    pub fn get_released(instance: *runtime.Instance) anyerror!bool {
        return try WakeLockSentinelImpl.get_released(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!WakeLockType {
        return try WakeLockSentinelImpl.get_type(instance);
    }

    pub fn get_onrelease(instance: *runtime.Instance) anyerror!EventHandler {
        return try WakeLockSentinelImpl.get_onrelease(instance);
    }

    pub fn set_onrelease(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WakeLockSentinelImpl.set_onrelease(instance, value);
    }

    pub fn call_release(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try WakeLockSentinelImpl.call_release(instance);
    }
};
