//! Generated from: web-bluetooth.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ServiceEventHandlersImpl = @import("impls").ServiceEventHandlers;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventHandler = @import("typedefs").EventHandler;

pub const ServiceEventHandlers = struct {
    pub const Meta = struct {
        pub const name = "ServiceEventHandlers";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "onserviceadded", "get_onserviceadded", "set_onserviceadded" },
            .{ "onservicechanged", "get_onservicechanged", "set_onservicechanged" },
            .{ "onserviceremoved", "get_onserviceremoved", "set_onserviceremoved" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "onserviceadded", "get_onserviceadded", "set_onserviceadded" },
            .{ "onservicechanged", "get_onservicechanged", "set_onservicechanged" },
            .{ "onserviceremoved", "get_onserviceremoved", "set_onserviceremoved" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            onserviceadded: typedefs.EventHandler = undefined,
            onservicechanged: typedefs.EventHandler = undefined,
            onserviceremoved: typedefs.EventHandler = undefined,
            _internal: ?*ServiceEventHandlersImpl.InternalState = null,
        },
    );

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "ServiceEventHandlers")) {
            if (comptime @hasDecl(impls.ServiceEventHandlers, "installHooks")) impls.ServiceEventHandlers.installHooks();
        }
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onserviceadded(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(ServiceEventHandlersImpl, "get_onserviceadded")) return try ServiceEventHandlersImpl.get_onserviceadded(instance);
        return event_handlers.value(EventHandler, instance, "onserviceadded");
    }

    pub fn set_onserviceadded(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(ServiceEventHandlersImpl, "set_onserviceadded")) return try ServiceEventHandlersImpl.set_onserviceadded(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onserviceadded", value);
    }

    pub fn get_onservicechanged(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(ServiceEventHandlersImpl, "get_onservicechanged")) return try ServiceEventHandlersImpl.get_onservicechanged(instance);
        return event_handlers.value(EventHandler, instance, "onservicechanged");
    }

    pub fn set_onservicechanged(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(ServiceEventHandlersImpl, "set_onservicechanged")) return try ServiceEventHandlersImpl.set_onservicechanged(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onservicechanged", value);
    }

    pub fn get_onserviceremoved(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(ServiceEventHandlersImpl, "get_onserviceremoved")) return try ServiceEventHandlersImpl.get_onserviceremoved(instance);
        return event_handlers.value(EventHandler, instance, "onserviceremoved");
    }

    pub fn set_onserviceremoved(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(ServiceEventHandlersImpl, "set_onserviceremoved")) return try ServiceEventHandlersImpl.set_onserviceremoved(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onserviceremoved", value);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{ "set_onserviceadded", "set_onservicechanged", "set_onserviceremoved" };
};
