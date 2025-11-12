//! XPathExpression interface - DOM §6.4

const std = @import("std");
const Node = @import("node").Node;
const XPathResult = @import("xpath_result").XPathResult;
const Expr = @import("dom").xpath.ast.Expr;
const Context = @import("dom").xpath.context.Context;
const evaluator = @import("dom").xpath.evaluator;

pub const XPathExpression = struct {
    allocator: std.mem.Allocator,
    expr: *Expr,

    pub fn init(allocator: std.mem.Allocator, expr: *Expr) !*XPathExpression {
        const self = try allocator.create(XPathExpression);
        self.* = .{
            .allocator = allocator,
            .expr = expr,
        };
        return self;
    }

    pub fn deinit(self: *XPathExpression) void {
        // expr is owned by arena allocator from parser
        self.allocator.destroy(self);
    }

    pub fn evaluate(self: *XPathExpression, context_node: *Node, result_type: u16, _: ?*XPathResult) !*XPathResult {
        var ctx = try Context.init(self.allocator, context_node);
        defer ctx.deinit();

        const value = try evaluator.evaluate(self.allocator, self.expr, &ctx);

        return try XPathResult.init(self.allocator, result_type, value);
    }
};
