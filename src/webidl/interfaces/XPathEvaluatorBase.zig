//! Generated from: dom.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XPathEvaluatorBaseImpl = @import("impls").XPathEvaluatorBase;
const XPathNSResolver = @import("interfaces").XPathNSResolver;
const XPathExpression = @import("interfaces").XPathExpression;
const Node = @import("interfaces").Node;
const XPathResult = @import("interfaces").XPathResult;
const DOMString = @import("typedefs").DOMString;

pub const XPathEvaluatorBase = struct {
    pub const Meta = struct {
        pub const name = "XPathEvaluatorBase";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XPathEvaluatorBase, .{
        .deinit_fn = &deinit_wrapper,

        .call_createExpression = &call_createExpression,
        .call_createNSResolver = &call_createNSResolver,
        .call_evaluate = &call_evaluate,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return XPathEvaluatorBaseImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XPathEvaluatorBaseImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_createNSResolver(instance: *runtime.Instance, nodeResolver: Node) anyerror!Node {
        
        return try XPathEvaluatorBaseImpl.call_createNSResolver(instance, nodeResolver);
    }

    pub fn call_evaluate(instance: *runtime.Instance, expression: DOMString, contextNode: Node, resolver: XPathNSResolver, @"type": u16, result: XPathResult) anyerror!XPathResult {
        
        return try XPathEvaluatorBaseImpl.call_evaluate(instance, expression, contextNode, resolver, @"type", result);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createExpression(instance: *runtime.Instance, expression: DOMString, resolver: XPathNSResolver) anyerror!XPathExpression {
        // [NewObject] - Caller owns the returned object
        
        return try XPathEvaluatorBaseImpl.call_createExpression(instance, expression, resolver);
    }

};
