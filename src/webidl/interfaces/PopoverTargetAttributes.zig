//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PopoverTargetAttributesImpl = @import("impls").PopoverTargetAttributes;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Element = @import("interfaces").Element;
const DOMString = @import("typedefs").DOMString;

pub const PopoverTargetAttributes = struct {
    pub const Meta = struct {
        pub const name = "PopoverTargetAttributes";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "popoverTargetElement", "get_popoverTargetElement", "set_popoverTargetElement" },
            .{ "popoverTargetAction", "get_popoverTargetAction", "set_popoverTargetAction" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "popoverTargetElement", "get_popoverTargetElement", "set_popoverTargetElement" },
            .{ "popoverTargetAction", "get_popoverTargetAction", "set_popoverTargetAction" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            popoverTargetElement: ?*runtime.Instance = null,
            popoverTargetAction: runtime.DOMString = undefined,
            _internal: ?*PopoverTargetAttributesImpl.InternalState = null,
        },
    );

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "PopoverTargetAttributes")) {
            if (comptime @hasDecl(impls.PopoverTargetAttributes, "installHooks")) impls.PopoverTargetAttributes.installHooks();
        }
    }

    /// Extended attributes: [CEReactions], [Reflect="popovertarget"]
    pub fn get_popoverTargetElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try PopoverTargetAttributesImpl.get_popoverTargetElement(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="popovertarget"]
    pub fn set_popoverTargetElement(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        try PopoverTargetAttributesImpl.set_popoverTargetElement(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_popoverTargetAction(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try PopoverTargetAttributesImpl.get_popoverTargetAction(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_popoverTargetAction(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        try PopoverTargetAttributesImpl.set_popoverTargetAction(instance, value);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "set_popoverTargetElement", 0, "Element" },
    };

    /// HTML [CEReactions]: the functions that run a custom element reactions
    /// bracket - the binding dispatches each in a catch scope, where
    /// engine.withPendingExceptionSetAside sets aside what the member leaves
    /// pending.
    pub const ce_reactions = .{
        "set_popoverTargetElement",
        "set_popoverTargetAction",
    };
};
