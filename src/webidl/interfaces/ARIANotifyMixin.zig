//! Generated from: wai-aria.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ARIANotifyMixinImpl = @import("impls").ARIANotifyMixin;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const AriaNotificationOptions = @import("dictionaries").AriaNotificationOptions;
const DOMString = @import("typedefs").DOMString;

pub const ARIANotifyMixin = struct {
    pub const Meta = struct {
        pub const name = "ARIANotifyMixin";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "ariaNotify", "call_ariaNotify", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "ariaNotify",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*ARIANotifyMixinImpl.InternalState = null,
        },
    );

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "ARIANotifyMixin")) {
            if (comptime @hasDecl(impls.ARIANotifyMixin, "installHooks")) impls.ARIANotifyMixin.installHooks();
        }
    }

    pub fn call_ariaNotify(instance: *runtime.Instance, announcement: runtime.DOMString, options: webidl.Opt(AriaNotificationOptions)) anyerror!void {
        return try ARIANotifyMixinImpl.call_ariaNotify(instance, announcement, options);
    }
};
