//! Generated from: dom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XPathEvaluatorBaseImpl = @import("impls").XPathEvaluatorBase;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const XPathNSResolver = @import("interfaces").XPathNSResolver;
const XPathExpression = @import("interfaces").XPathExpression;
const Node = @import("interfaces").Node;
const XPathResult = @import("interfaces").XPathResult;
const DOMString = @import("typedefs").DOMString;

pub const XPathEvaluatorBase = struct {
    pub const Meta = struct {
        pub const name = "XPathEvaluatorBase";
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
            .{ "createExpression", "call_createExpression", 1 },
            .{ "createNSResolver", "call_createNSResolver", 1 },
            .{ "evaluate", "call_evaluate", 2 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "createExpression",
            "createNSResolver",
            "evaluate",
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
            _internal: ?*XPathEvaluatorBaseImpl.InternalState = null,
        },
    );

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "XPathEvaluatorBase")) {
            if (comptime @hasDecl(impls.XPathEvaluatorBase, "installHooks")) impls.XPathEvaluatorBase.installHooks();
        }
    }

    pub fn call_createNSResolver(instance: *runtime.Instance, nodeResolver: *runtime.Instance) anyerror!*runtime.Instance {
        return try XPathEvaluatorBaseImpl.call_createNSResolver(instance, nodeResolver);
    }

    pub fn call_evaluate(instance: *runtime.Instance, expression: DOMString, contextNode: *runtime.Instance, resolver: webidl.Opt(??*runtime.CallbackWrapper), @"type": webidl.Opt(u16), result: webidl.Opt(?*runtime.Instance)) anyerror!*runtime.Instance {
        return try XPathEvaluatorBaseImpl.call_evaluate(instance, expression, contextNode, resolver, @"type", result);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createExpression(instance: *runtime.Instance, expression: DOMString, resolver: webidl.Opt(??*runtime.CallbackWrapper)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try XPathEvaluatorBaseImpl.call_createExpression(instance, expression, resolver);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_createNSResolver", 0, "Node" },
        .{ "call_evaluate", 1, "Node" },
        .{ "call_evaluate", 4, "XPathResult" },
    };
};
