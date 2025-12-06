//! Generated from: notifications.idl
//! Generated at: 2025-12-05T20:30:45Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NotificationEventImpl = @import("impls").NotificationEvent;
const mixins = @import("mixins");
const ExtendableEvent = @import("interfaces").ExtendableEvent;
const NotificationEventInit = @import("dictionaries").NotificationEventInit;
const ExtendableEventInit = @import("dictionaries").ExtendableEventInit;
const EventTarget = @import("interfaces").EventTarget;
const Notification = @import("interfaces").Notification;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const NotificationEvent = struct {
    pub const Meta = struct {
        pub const name = "NotificationEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ExtendableEvent.State;
        pub const ParentInterface = ExtendableEvent;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "ServiceWorker" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .ServiceWorker = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "notification", "get_notification", null },
            .{ "action", "get_action", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
            "waitUntil",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "notification", "get_notification", null },
            .{ "action", "get_action", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            notification: *runtime.Instance = undefined,
            action: runtime.DOMString = undefined,
            _internal: ?*NotificationEventImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_action = &get_action,
        .get_notification = &get_notification,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NotificationEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NotificationEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: NotificationEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try NotificationEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_notification(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try NotificationEventImpl.get_notification(instance);
    }

    pub fn get_action(instance: *runtime.Instance) anyerror!DOMString {
        return try NotificationEventImpl.get_action(instance);
    }
};
