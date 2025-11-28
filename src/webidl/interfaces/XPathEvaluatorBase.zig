//! Generated from: dom.idl
//! Generated at: 2025-11-28T19:51:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XPathEvaluatorBaseImpl = @import("impls").XPathEvaluatorBase;
const mixins = @import("mixins");
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
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
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
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*XPathEvaluatorBaseImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_createExpression = &call_createExpression,
        .call_createNSResolver = &call_createNSResolver,
        .call_evaluate = &call_evaluate,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XPathEvaluatorBaseImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XPathEvaluatorBaseImpl.deinit(instance);
    }

    pub fn call_createNSResolver(instance: *runtime.Instance, nodeResolver: *runtime.Instance) anyerror!*runtime.Instance {
        
        return try XPathEvaluatorBaseImpl.call_createNSResolver(instance, nodeResolver);
    }

    pub fn call_evaluate(instance: *runtime.Instance, expression: DOMString, contextNode: *runtime.Instance, resolver: webidl.Opt(??*runtime.CallbackWrapper), @"type": webidl.Opt(u16), result: webidl.Opt(?*runtime.Instance)) anyerror!*runtime.Instance {
        
        return try XPathEvaluatorBaseImpl.call_evaluate(instance, expression, contextNode, resolver.value, @"type".value, result.value);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createExpression(instance: *runtime.Instance, expression: DOMString, resolver: webidl.Opt(??*runtime.CallbackWrapper)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try XPathEvaluatorBaseImpl.call_createExpression(instance, expression, resolver.value);
    }

};
