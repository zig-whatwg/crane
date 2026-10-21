//! Generated from: geolocation-element.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PowerfulFeatureObserverImpl = @import("impls").PowerfulFeatureObserver;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const PermissionState = @import("enums").PermissionState;
const EventHandler = @import("typedefs").EventHandler;

pub const PowerfulFeatureObserver = struct {
    pub const Meta = struct {
        pub const name = "PowerfulFeatureObserver";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "initialPermissionStatus", "get_initialPermissionStatus", null },
            .{ "permissionStatus", "get_permissionStatus", null },
            .{ "onpromptaction", "get_onpromptaction", "set_onpromptaction" },
            .{ "onpromptdismiss", "get_onpromptdismiss", "set_onpromptdismiss" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "initialPermissionStatus", "get_initialPermissionStatus", null },
            .{ "permissionStatus", "get_permissionStatus", null },
            .{ "onpromptaction", "get_onpromptaction", "set_onpromptaction" },
            .{ "onpromptdismiss", "get_onpromptdismiss", "set_onpromptdismiss" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            initialPermissionStatus: enums.PermissionState = undefined,
            permissionStatus: enums.PermissionState = undefined,
            onpromptaction: typedefs.EventHandler = undefined,
            onpromptdismiss: typedefs.EventHandler = undefined,
            _internal: ?*PowerfulFeatureObserverImpl.InternalState = null,
        },
    );

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "PowerfulFeatureObserver")) {
            if (comptime @hasDecl(impls.PowerfulFeatureObserver, "installHooks")) impls.PowerfulFeatureObserver.installHooks();
        }
    }

    pub fn get_initialPermissionStatus(instance: *runtime.Instance) anyerror!PermissionState {
        return try PowerfulFeatureObserverImpl.get_initialPermissionStatus(instance);
    }

    pub fn get_permissionStatus(instance: *runtime.Instance) anyerror!PermissionState {
        return try PowerfulFeatureObserverImpl.get_permissionStatus(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onpromptaction(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(PowerfulFeatureObserverImpl, "get_onpromptaction")) return try PowerfulFeatureObserverImpl.get_onpromptaction(instance);
        return event_handlers.value(EventHandler, instance, "onpromptaction");
    }

    pub fn set_onpromptaction(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(PowerfulFeatureObserverImpl, "set_onpromptaction")) return try PowerfulFeatureObserverImpl.set_onpromptaction(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onpromptaction", value);
    }

    pub fn get_onpromptdismiss(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(PowerfulFeatureObserverImpl, "get_onpromptdismiss")) return try PowerfulFeatureObserverImpl.get_onpromptdismiss(instance);
        return event_handlers.value(EventHandler, instance, "onpromptdismiss");
    }

    pub fn set_onpromptdismiss(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(PowerfulFeatureObserverImpl, "set_onpromptdismiss")) return try PowerfulFeatureObserverImpl.set_onpromptdismiss(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onpromptdismiss", value);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{ "set_onpromptaction", "set_onpromptdismiss" };
};
