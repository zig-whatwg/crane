//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLOrSVGOrMathMLElementImpl = @import("impls").HTMLOrSVGOrMathMLElement;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMStringMap = @import("interfaces").DOMStringMap;
const DOMString = @import("typedefs").DOMString;
const FocusOptions = @import("dictionaries").FocusOptions;

pub const HTMLOrSVGOrMathMLElement = struct {
    pub const Meta = struct {
        pub const name = "HTMLOrSVGOrMathMLElement";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "dataset", "get_dataset", null },
            .{ "nonce", "get_nonce", "set_nonce" },
            .{ "autofocus", "get_autofocus", "set_autofocus" },
            .{ "tabIndex", "get_tabIndex", "set_tabIndex" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "focus", "call_focus", 0 },
            .{ "blur", "call_blur", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "focus",
            "blur",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "dataset", "get_dataset", null },
            .{ "nonce", "get_nonce", "set_nonce" },
            .{ "autofocus", "get_autofocus", "set_autofocus" },
            .{ "tabIndex", "get_tabIndex", "set_tabIndex" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            dataset: *runtime.Instance = undefined,
            nonce: runtime.DOMString = undefined,
            autofocus: bool = undefined,
            tabIndex: i32 = undefined,
            cached_dataset: ?*runtime.Instance = null,
            _internal: ?*HTMLOrSVGOrMathMLElementImpl.InternalState = null,
        },
    );

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "HTMLOrSVGOrMathMLElement")) {
            if (comptime @hasDecl(impls.HTMLOrSVGOrMathMLElement, "installHooks")) impls.HTMLOrSVGOrMathMLElement.installHooks();
        }
    }

    /// Extended attributes: [SameObject]
    pub fn get_dataset(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_dataset) |cached| {
            return cached;
        }
        const value = try HTMLOrSVGOrMathMLElementImpl.get_dataset(instance);
        state.own.cached_dataset = value;
        @import("dom").same_object_cache.made(instance, value, "dataset");
        return value;
    }

    pub fn get_nonce(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try HTMLOrSVGOrMathMLElementImpl.get_nonce(instance);
    }

    pub fn set_nonce(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        try HTMLOrSVGOrMathMLElementImpl.set_nonce(instance, value);
    }

    const reflection = @import("dom").reflection;

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_autofocus(instance: *runtime.Instance) anyerror!bool {
        if (comptime @hasDecl(HTMLOrSVGOrMathMLElementImpl, "get_autofocus")) return try HTMLOrSVGOrMathMLElementImpl.get_autofocus(instance);
        return try reflection.get(bool, instance, .{ .name = "autofocus" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_autofocus(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLOrSVGOrMathMLElementImpl, "set_autofocus")) return try HTMLOrSVGOrMathMLElementImpl.set_autofocus(instance, value);
        try reflection.set(bool, instance, .{ .name = "autofocus" }, value);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn get_tabIndex(instance: *runtime.Instance) anyerror!i32 {
        return try HTMLOrSVGOrMathMLElementImpl.get_tabIndex(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn set_tabIndex(instance: *runtime.Instance, value: i32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLOrSVGOrMathMLElementImpl, "set_tabIndex")) return try HTMLOrSVGOrMathMLElementImpl.set_tabIndex(instance, value);
        try reflection.set(i32, instance, .{ .name = "tabindex" }, value);
    }

    pub fn call_focus(instance: *runtime.Instance, options: webidl.Opt(FocusOptions)) anyerror!void {
        return try HTMLOrSVGOrMathMLElementImpl.call_focus(instance, options);
    }

    pub fn call_blur(instance: *runtime.Instance) anyerror!void {
        return try HTMLOrSVGOrMathMLElementImpl.call_blur(instance);
    }

    /// HTML [CEReactions]: the functions that run a custom element reactions
    /// bracket - the binding dispatches each in a catch scope, where
    /// engine.withPendingExceptionSetAside sets aside what the member leaves
    /// pending.
    pub const ce_reactions = .{
        "set_autofocus",
        "set_tabIndex",
    };
};
