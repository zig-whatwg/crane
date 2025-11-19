//! Generated from: dom.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XPathEvaluatorImpl = @import("impls").XPathEvaluator;
const XPathEvaluatorBase = @import("interfaces").XPathEvaluatorBase;
const XPathExpression = @import("interfaces").XPathExpression;
const XPathResult = @import("interfaces").XPathResult;
const XPathNSResolver = @import("interfaces").XPathNSResolver;
const Node = @import("interfaces").Node;
const DOMString = @import("typedefs").DOMString;

pub const XPathEvaluator = struct {
    pub const Meta = struct {
        pub const name = "XPathEvaluator";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{
            XPathEvaluatorBase,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XPathEvaluator, .{
        .deinit_fn = &deinit_wrapper,

        .call_createExpression = &call_createExpression,
        .call_createNSResolver = &call_createNSResolver,
        .call_evaluate = &call_evaluate,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return XPathEvaluatorImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XPathEvaluatorImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try XPathEvaluatorImpl.constructor(instance);
        
        return instance;
    }

    pub fn call_createNSResolver(instance: *runtime.Instance, nodeResolver: Node) anyerror!Node {
        
        return try XPathEvaluatorImpl.call_createNSResolver(instance, nodeResolver);
    }

    pub fn call_evaluate(instance: *runtime.Instance, expression: DOMString, contextNode: Node, resolver: XPathNSResolver, @"type": u16, result: XPathResult) anyerror!XPathResult {
        
        return try XPathEvaluatorImpl.call_evaluate(instance, expression, contextNode, resolver, @"type", result);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createExpression(instance: *runtime.Instance, expression: DOMString, resolver: XPathNSResolver) anyerror!XPathExpression {
        // [NewObject] - Caller owns the returned object
        
        return try XPathEvaluatorImpl.call_createExpression(instance, expression, resolver);
    }

};
