//! XPath 1.0 Expression Evaluator
//!
//! This module evaluates XPath AST nodes to produce values.

const std = @import("std");
const ast = @import("ast.zig");
const Value = @import("value.zig").Value;
const NodeSet = @import("value.zig").NodeSet;
const Context = @import("context.zig").Context;
const Node = @import("node").Node;
const Expr = ast.Expr;
const PrimaryExpr = ast.PrimaryExpr;
const LocationPath = ast.LocationPath;
const Step = ast.Step;
const Axis = ast.Axis;

/// Evaluate an XPath expression
pub fn evaluate(allocator: std.mem.Allocator, expr: *const Expr, ctx: *const Context) !Value {
    return switch (expr.*) {
        .or_expr => |bin| try evalOrExpr(allocator, &bin, ctx),
        .and_expr => |bin| try evalAndExpr(allocator, &bin, ctx),
        .equality_expr => |bin| try evalEqualityExpr(allocator, &bin, ctx),
        .relational_expr => |bin| try evalRelationalExpr(allocator, &bin, ctx),
        .additive_expr => |bin| try evalAdditiveExpr(allocator, &bin, ctx),
        .multiplicative_expr => |bin| try evalMultiplicativeExpr(allocator, &bin, ctx),
        .unary_expr => |un| try evalUnaryExpr(allocator, &un, ctx),
        .union_expr => |bin| try evalUnionExpr(allocator, &bin, ctx),
        .path_expr => |path| try evalPathExpr(allocator, &path, ctx),
        .filter_expr => |filt| try evalFilterExpr(allocator, filt, ctx),
        .primary_expr => |prim| try evalPrimaryExpr(allocator, &prim, ctx),
        .location_path => |path| try evalLocationPath(allocator, &path, ctx),
    };
}

fn evalOrExpr(allocator: std.mem.Allocator, bin: *const Expr.BinaryExpr, ctx: *const Context) !Value {
    const left = try evaluate(allocator, bin.left, ctx);
    defer {
        var l = left;
        l.deinit(allocator);
    }
    if (left.toBoolean()) {
        return Value{ .boolean = true };
    }
    const right = try evaluate(allocator, bin.right, ctx);
    defer {
        var r = right;
        r.deinit(allocator);
    }
    return Value{ .boolean = right.toBoolean() };
}

fn evalAndExpr(allocator: std.mem.Allocator, bin: *const Expr.BinaryExpr, ctx: *const Context) !Value {
    const left = try evaluate(allocator, bin.left, ctx);
    defer {
        var l = left;
        l.deinit(allocator);
    }
    if (!left.toBoolean()) {
        return Value{ .boolean = false };
    }
    const right = try evaluate(allocator, bin.right, ctx);
    defer {
        var r = right;
        r.deinit(allocator);
    }
    return Value{ .boolean = right.toBoolean() };
}

fn evalEqualityExpr(allocator: std.mem.Allocator, bin: *const Expr.BinaryExpr, ctx: *const Context) !Value {
    const left = try evaluate(allocator, bin.left, ctx);
    defer {
        var l = left;
        l.deinit(allocator);
    }
    const right = try evaluate(allocator, bin.right, ctx);
    defer {
        var r = right;
        r.deinit(allocator);
    }
    
    const result = switch (bin.operator) {
        .equals => try compareValues(allocator, left, right, true),
        .not_equals => !try compareValues(allocator, left, right, true),
        else => unreachable,
    };
    return Value{ .boolean = result };
}

fn evalRelationalExpr(allocator: std.mem.Allocator, bin: *const Expr.BinaryExpr, ctx: *const Context) !Value {
    const left = try evaluate(allocator, bin.left, ctx);
    defer {
        var l = left;
        l.deinit(allocator);
    }
    const right = try evaluate(allocator, bin.right, ctx);
    defer {
        var r = right;
        r.deinit(allocator);
    }
    
    const left_num = try left.toNumber(allocator);
    const right_num = try right.toNumber(allocator);
    
    const result = switch (bin.operator) {
        .less_than => left_num < right_num,
        .less_than_or_equal => left_num <= right_num,
        .greater_than => left_num > right_num,
        .greater_than_or_equal => left_num >= right_num,
        else => unreachable,
    };
    return Value{ .boolean = result };
}

fn evalAdditiveExpr(allocator: std.mem.Allocator, bin: *const Expr.BinaryExpr, ctx: *const Context) !Value {
    const left = try evaluate(allocator, bin.left, ctx);
    defer {
        var l = left;
        l.deinit(allocator);
    }
    const right = try evaluate(allocator, bin.right, ctx);
    defer {
        var r = right;
        r.deinit(allocator);
    }
    
    const left_num = try left.toNumber(allocator);
    const right_num = try right.toNumber(allocator);
    
    const result = switch (bin.operator) {
        .plus => left_num + right_num,
        .minus => left_num - right_num,
        else => unreachable,
    };
    return Value{ .number = result };
}

fn evalMultiplicativeExpr(allocator: std.mem.Allocator, bin: *const Expr.BinaryExpr, ctx: *const Context) !Value {
    const left = try evaluate(allocator, bin.left, ctx);
    defer {
        var l = left;
        l.deinit(allocator);
    }
    const right = try evaluate(allocator, bin.right, ctx);
    defer {
        var r = right;
        r.deinit(allocator);
    }
    
    const left_num = try left.toNumber(allocator);
    const right_num = try right.toNumber(allocator);
    
    const result = switch (bin.operator) {
        .multiply => left_num * right_num,
        .div => left_num / right_num,
        .mod => @mod(left_num, right_num),
        else => unreachable,
    };
    return Value{ .number = result };
}

fn evalUnaryExpr(allocator: std.mem.Allocator, un: *const Expr.UnaryExpr, ctx: *const Context) !Value {
    const operand = try evaluate(allocator, un.operand, ctx);
    defer {
        var op = operand;
        op.deinit(allocator);
    }
    
    const num = try operand.toNumber(allocator);
    return Value{ .number = -num };
}

fn evalUnionExpr(allocator: std.mem.Allocator, bin: *const Expr.BinaryExpr, ctx: *const Context) !Value {
    const left = try evaluate(allocator, bin.left, ctx);
    var left_ns = switch (left) {
        .node_set => |ns| ns,
        else => return error.InvalidArgumentType,
    };
    
    const right = try evaluate(allocator, bin.right, ctx);
    defer {
        var r = right;
        r.deinit(allocator);
    }
    const right_ns = switch (right) {
        .node_set => |ns| ns,
        else => return error.InvalidArgumentType,
    };
    
    try left_ns.unionWith(&right_ns);
    return Value{ .node_set = left_ns };
}

fn evalPathExpr(allocator: std.mem.Allocator, path: *const ast.PathExpr, ctx: *const Context) !Value {
    return switch (path.*) {
        .location_path => |loc_path| try evalLocationPath(allocator, loc_path, ctx),
        .filter => |filt| try evalFilterExpr(allocator, filt, ctx),
        .filter_with_path => return error.FilterWithPathNotImplemented, // TODO
    };
}

fn evalFilterExpr(allocator: std.mem.Allocator, filt: *const ast.FilterExpr, ctx: *const Context) !Value {
    const primary = try evalPrimaryExpr(allocator, filt.primary, ctx);
    // TODO: Apply predicates
    _ = filt.predicates;
    return primary;
}

fn evalPrimaryExpr(allocator: std.mem.Allocator, prim: *const PrimaryExpr, ctx: *const Context) !Value {
    return switch (prim.*) {
        .variable_reference => |name| blk: {
            if (ctx.getVariable(name)) |val| {
                break :blk val;
            }
            return error.UndefinedVariable;
        },
        .literal => |s| Value{ .string = try allocator.dupe(u8, s) },
        .number => |n| Value{ .number = n },
        .function_call => |fc| try evalFunctionCall(allocator, &fc, ctx),
        .grouped => |expr| try evaluate(allocator, expr, ctx),
    };
}

fn evalFunctionCall(allocator: std.mem.Allocator, fc: *const PrimaryExpr.FunctionCall, ctx: *const Context) !Value {
    const func = ctx.functions.lookup(fc.name) orelse return error.UnknownFunction;
    
    // Evaluate arguments
    var args = try allocator.alloc(Value, fc.arguments.len);
    defer {
        for (args) |*arg| {
            arg.deinit(allocator);
        }
        allocator.free(args);
    }
    
    for (fc.arguments, 0..) |arg_expr, i| {
        args[i] = try evaluate(allocator, arg_expr, ctx);
    }
    
    return try func(allocator, ctx, args);
}

fn evalLocationPath(allocator: std.mem.Allocator, path: *const LocationPath, ctx: *const Context) !Value {
    var result = NodeSet.init(allocator);
    
    if (path.isAbsolute()) {
        // Start from document root
        // TODO: Get actual document root
        try result.add(ctx.context_node);
        
        // Apply steps
        for (path.absolute.steps) |step| {
            result = try evalStep(allocator, &step, result, ctx);
        }
    } else {
        // Start from context node
        try result.add(ctx.context_node);
        
        // Apply steps
        for (path.relative.steps) |step| {
            result = try evalStep(allocator, &step, result, ctx);
        }
    }
    
    return Value{ .node_set = result };
}

fn evalStep(allocator: std.mem.Allocator, step: *const Step, input: NodeSet, ctx: *const Context) !NodeSet {
    var result = NodeSet.init(allocator);
    
    // For each node in input, apply axis and node test
    for (0..input.size()) |i| {
        if (input.get(i)) |node| {
            const nodes = try applyAxis(allocator, step.axis, node);
            defer nodes.deinit();
            
            // Filter by node test
            for (0..nodes.size()) |j| {
                if (nodes.get(j)) |candidate| {
                    if (try matchesNodeTest(allocator, &step.node_test, candidate, ctx)) {
                        try result.add(candidate);
                    }
                }
            }
        }
    }
    
    // Apply predicates
    for (step.predicates) |_| {
        // TODO: Implement predicate filtering
    }
    
    return result;
}

fn applyAxis(_: std.mem.Allocator, axis: Axis, _: *Node) !NodeSet {
    // TODO: Implement axis traversal
    // For now, return empty node set
    _ = axis;
    return NodeSet.init(std.heap.page_allocator);
}

fn matchesNodeTest(_: std.mem.Allocator, _: *const ast.NodeTest, _: *Node, _: *const Context) !bool {
    // TODO: Implement node test matching
    return true;
}

fn compareValues(allocator: std.mem.Allocator, left: Value, right: Value, _: bool) !bool {
    // Simplified comparison - convert to strings and compare
    const left_str = try left.toString(allocator);
    defer allocator.free(left_str);
    const right_str = try right.toString(allocator);
    defer allocator.free(right_str);
    return std.mem.eql(u8, left_str, right_str);
}
