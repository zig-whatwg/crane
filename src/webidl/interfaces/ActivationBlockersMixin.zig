//! Generated from: geolocation-element.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ActivationBlockersMixinImpl = @import("impls").ActivationBlockersMixin;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ActivationBlockersMixinBlockerReason = @import("enums").ActivationBlockersMixinBlockerReason;
const EventHandler = @import("typedefs").EventHandler;

pub const ActivationBlockersMixin = struct {
    pub const Meta = struct {
        pub const name = "ActivationBlockersMixin";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "isValid", "get_isValid", null },
            .{ "invalidReason", "get_invalidReason", null },
            .{ "onvalidationstatuschange", "get_onvalidationstatuschange", "set_onvalidationstatuschange" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "isValid", "get_isValid", null },
            .{ "invalidReason", "get_invalidReason", null },
            .{ "onvalidationstatuschange", "get_onvalidationstatuschange", "set_onvalidationstatuschange" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            isValid: bool = undefined,
            invalidReason: enums.ActivationBlockersMixinBlockerReason = undefined,
            onvalidationstatuschange: typedefs.EventHandler = undefined,
            _internal: ?*ActivationBlockersMixinImpl.InternalState = null,
        },
    );

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "ActivationBlockersMixin")) {
            if (comptime @hasDecl(impls.ActivationBlockersMixin, "installHooks")) impls.ActivationBlockersMixin.installHooks();
        }
    }

    pub fn get_isValid(instance: *runtime.Instance) anyerror!bool {
        return try ActivationBlockersMixinImpl.get_isValid(instance);
    }

    pub fn get_invalidReason(instance: *runtime.Instance) anyerror!ActivationBlockersMixinBlockerReason {
        return try ActivationBlockersMixinImpl.get_invalidReason(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onvalidationstatuschange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(ActivationBlockersMixinImpl, "get_onvalidationstatuschange")) return try ActivationBlockersMixinImpl.get_onvalidationstatuschange(instance);
        return event_handlers.value(EventHandler, instance, "onvalidationstatuschange");
    }

    pub fn set_onvalidationstatuschange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(ActivationBlockersMixinImpl, "set_onvalidationstatuschange")) return try ActivationBlockersMixinImpl.set_onvalidationstatuschange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onvalidationstatuschange", value);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{"set_onvalidationstatuschange"};
};
