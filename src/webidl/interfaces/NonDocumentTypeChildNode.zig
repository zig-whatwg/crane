//! Generated from: dom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NonDocumentTypeChildNodeImpl = @import("impls").NonDocumentTypeChildNode;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Element = @import("interfaces").Element;

pub const NonDocumentTypeChildNode = struct {
    pub const Meta = struct {
        pub const name = "NonDocumentTypeChildNode";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "previousElementSibling", "get_previousElementSibling", null },
            .{ "nextElementSibling", "get_nextElementSibling", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "previousElementSibling", "get_previousElementSibling", null },
            .{ "nextElementSibling", "get_nextElementSibling", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            previousElementSibling: ?*runtime.Instance = null,
            nextElementSibling: ?*runtime.Instance = null,
            _internal: ?*NonDocumentTypeChildNodeImpl.InternalState = null,
        },
    );

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "NonDocumentTypeChildNode")) {
            if (comptime @hasDecl(impls.NonDocumentTypeChildNode, "installHooks")) impls.NonDocumentTypeChildNode.installHooks();
        }
    }

    pub fn get_previousElementSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try NonDocumentTypeChildNodeImpl.get_previousElementSibling(instance);
    }

    pub fn get_nextElementSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try NonDocumentTypeChildNodeImpl.get_nextElementSibling(instance);
    }
};
