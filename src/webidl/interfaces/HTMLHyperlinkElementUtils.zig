//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLHyperlinkElementUtilsImpl = @import("impls").HTMLHyperlinkElementUtils;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;

pub const HTMLHyperlinkElementUtils = struct {
    pub const Meta = struct {
        pub const name = "HTMLHyperlinkElementUtils";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "href", "get_href", "set_href" },
            .{ "target", "get_target", "set_target" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "toString", "get_href", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "toString",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "href", "get_href", "set_href" },
            .{ "target", "get_target", "set_target" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            href: runtime.USVString = undefined,
            target: runtime.DOMString = undefined,
            _internal: ?*HTMLHyperlinkElementUtilsImpl.InternalState = null,
        },
    );

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "HTMLHyperlinkElementUtils")) {
            if (comptime @hasDecl(impls.HTMLHyperlinkElementUtils, "installHooks")) impls.HTMLHyperlinkElementUtils.installHooks();
        }
    }

    const reflection = @import("dom").reflection;

    /// Extended attributes: [CEReactions], [ReflectSetter], [Stringifier]
    pub fn get_href(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLHyperlinkElementUtilsImpl.get_href(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter], [Stringifier]
    pub fn set_href(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLHyperlinkElementUtilsImpl, "set_href")) return try HTMLHyperlinkElementUtilsImpl.set_href(instance, value);
        try reflection.set(runtime.USVString, instance, .{ .name = "href" }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_target(instance: *runtime.Instance) anyerror!runtime.DOMString {
        if (comptime @hasDecl(HTMLHyperlinkElementUtilsImpl, "get_target")) return try HTMLHyperlinkElementUtilsImpl.get_target(instance);
        return try reflection.get(runtime.DOMString, instance, .{ .name = "target" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_target(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLHyperlinkElementUtilsImpl, "set_target")) return try HTMLHyperlinkElementUtilsImpl.set_target(instance, value);
        try reflection.set(runtime.DOMString, instance, .{ .name = "target" }, value);
    }

    /// HTML [CEReactions]: the functions that run a custom element reactions
    /// bracket - the binding dispatches each in a catch scope, where
    /// engine.withPendingExceptionSetAside sets aside what the member leaves
    /// pending.
    pub const ce_reactions = .{
        "set_href",
        "set_target",
    };
};
