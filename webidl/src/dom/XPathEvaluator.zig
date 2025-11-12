//! XPathEvaluator interface - DOM §6.4

const std = @import("std");
const Node = @import("Node.zig").Node;
const XPathResult = @import("XPathResult.zig").XPathResult;
const XPathExpression = @import("XPathExpression.zig").XPathExpression;
const Parser = @import("dom").xpath.parser.Parser;
const Context = @import("dom").xpath.context.Context;
const evaluator = @import("dom").xpath.evaluator;

pub const XPathEvaluator = struct {
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) !*XPathEvaluator {
        const self = try allocator.create(XPathEvaluator);
        self.* = .{
            .allocator = allocator,
        };
        return self;
    }
    
    pub fn deinit(self: *XPathEvaluator) void {
        self.allocator.destroy(self);
    }
    
    pub fn createExpression(self: *XPathEvaluator, expression: []const u8, _: ?*anyopaque) !*XPathExpression {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        // Arena will be kept alive for expression lifetime
        
        var parser = try Parser.init(arena.allocator(), expression);
        const expr = try parser.parse();
        
        return try XPathExpression.init(self.allocator, expr);
    }
    
    pub fn evaluate(self: *XPathEvaluator, expression: []const u8, context_node: *Node, _: ?*anyopaque, result_type: u16, _: ?*XPathResult) !*XPathResult {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        
        var parser = try Parser.init(arena.allocator(), expression);
        const expr = try parser.parse();
        
        var ctx = try Context.init(self.allocator, context_node);
        defer ctx.deinit();
        
        const value = try evaluator.evaluate(self.allocator, expr, &ctx);
        
        return try XPathResult.init(self.allocator, result_type, value);
    }
};
