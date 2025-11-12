//! XPath 1.0 Expression Evaluator
//!
//! This module evaluates XPath AST nodes to produce values.

const std = @import("std");
const ast = @import("ast.zig");
const Value = @import("value.zig").Value;
const NodeSet = @import("value.zig").NodeSet;
const Context = @import("context.zig").Context;
const Node = @import("node").Node;
const NodeBase = @import("../node_base.zig").NodeBase;
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
        .filter_with_path => |fwp| {
            // First evaluate the filter expression to get a node-set
            const filter_result = try evalFilterExpr(allocator, fwp.filter, ctx);
            const filter_ns = switch (filter_result) {
                .node_set => |ns| ns,
                else => return error.InvalidArgumentType,
            };

            // Then apply the location path to each node in the result
            var result = NodeSet.init(allocator);
            for (0..filter_ns.size()) |i| {
                if (filter_ns.get(i)) |node| {
                    // Create context with this node
                    var new_ctx = ctx.*;
                    new_ctx.context_node = node;

                    // Evaluate location path from this node
                    const path_result = try evalLocationPath(allocator, fwp.path, &new_ctx);
                    defer {
                        var val = path_result;
                        val.deinit(allocator);
                    }
                    const path_ns = switch (path_result) {
                        .node_set => |ns| ns,
                        else => return error.InvalidArgumentType,
                    };

                    // Union the results
                    try result.unionWith(&path_ns);
                }
            }

            return Value{ .node_set = result };
        },
    };
}

fn evalFilterExpr(allocator: std.mem.Allocator, filt: *const ast.FilterExpr, ctx: *const Context) !Value {
    var result = try evalPrimaryExpr(allocator, filt.primary, ctx);

    // Apply predicates to the result (must be a node-set)
    for (filt.predicates) |predicate| {
        const result_ns = switch (result) {
            .node_set => |ns| ns,
            else => return error.InvalidArgumentType,
        };

        const filtered = try applyPredicate(allocator, predicate, result_ns, ctx);
        result = Value{ .node_set = filtered };
    }

    return result;
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

fn applyPredicate(allocator: std.mem.Allocator, predicate: *const Expr, input: NodeSet, ctx: *const Context) !NodeSet {
    var result = NodeSet.init(allocator);

    const size = input.size();
    for (0..size) |i| {
        if (input.get(i)) |node| {
            // Create temporary context with position and size
            var pred_ctx = ctx.*;
            pred_ctx.context_node = node;
            pred_ctx.context_position = @intCast(i + 1); // 1-based
            pred_ctx.context_size = @intCast(size);

            // Evaluate predicate
            const pred_value = try evaluate(allocator, predicate, &pred_ctx);
            defer {
                var val = pred_value;
                val.deinit(allocator);
            }

            // XPath spec: if result is a number, check if position() = number
            // Otherwise, convert to boolean
            const matches = switch (pred_value) {
                .number => |n| @as(f64, @floatFromInt(pred_ctx.context_position)) == n,
                else => pred_value.toBoolean(),
            };

            if (matches) {
                try result.add(node);
            }
        }
    }

    return result;
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
    for (step.predicates) |predicate| {
        result = try applyPredicate(allocator, predicate, result, ctx);
    }

    return result;
}

fn applyAxis(allocator: std.mem.Allocator, axis: Axis, node: *NodeBase) !NodeSet {
    var result = NodeSet.init(allocator);

    switch (axis) {
        // Forward axes
        .child => {
            // Direct children
            for (0..node.child_nodes.size()) |i| {
                if (node.child_nodes.get(i)) |child| {
                    try result.add(child);
                }
            }
        },
        .descendant => {
            // All descendants (not including self)
            try addDescendants(allocator, node, &result);
        },
        .descendant_or_self => {
            // Self + all descendants
            try result.add(node);
            try addDescendants(allocator, node, &result);
        },
        .following_sibling => {
            // All siblings after this node
            if (node.parent_node) |parent| {
                var found_self = false;
                for (0..parent.child_nodes.size()) |i| {
                    if (parent.child_nodes.get(i)) |sibling| {
                        if (found_self) {
                            try result.add(sibling);
                        } else if (sibling == node) {
                            found_self = true;
                        }
                    }
                }
            }
        },
        .following => {
            // All nodes after this node in document order (not descendants)
            // This is complex - for now, simplified implementation
            if (node.parent_node) |parent| {
                var found_self = false;
                for (0..parent.child_nodes.size()) |i| {
                    if (parent.child_nodes.get(i)) |sibling| {
                        if (found_self) {
                            try result.add(sibling);
                            try addDescendants(allocator, sibling, &result);
                        } else if (sibling == node) {
                            found_self = true;
                        }
                    }
                }
                // Recursively apply to ancestors
                var current = parent;
                while (current.parent_node) |ancestor| {
                    var found_current = false;
                    for (0..ancestor.child_nodes.size()) |j| {
                        if (ancestor.child_nodes.get(j)) |uncle| {
                            if (found_current) {
                                try result.add(uncle);
                                try addDescendants(allocator, uncle, &result);
                            } else if (uncle == current) {
                                found_current = true;
                            }
                        }
                    }
                    current = ancestor;
                }
            }
        },
        .attribute => {
            // Attributes of the node
            // Only element nodes have attributes (XPath 1.0 §2.3)
            if (NodeBase.asElement(node)) |element| {
                // Access attributes from Element using NodeBase downcasting
                for (0..element.attributes.size()) |i| {
                    if (element.attributes.get(i)) |attr| {
                        // TODO: Create attribute nodes and add to result
                        // For now, we'll create pseudo attribute nodes
                        // This is simplified until we have proper Attr with NodeBase
                        _ = attr;
                        // try result.add(&attr_as_node);
                    }
                }
            }
        },
        .namespace => {
            // Namespace nodes
            // TODO: Implement when namespace support is added
        },
        .self => {
            // Just the node itself
            try result.add(node);
        },

        // Reverse axes
        .parent => {
            // Direct parent
            if (node.parent_node) |parent| {
                try result.add(parent);
            }
        },
        .ancestor => {
            // All ancestors (not including self)
            var current = node.parent_node;
            while (current) |ancestor| {
                try result.add(ancestor);
                current = ancestor.parent_node;
            }
        },
        .ancestor_or_self => {
            // Self + all ancestors
            try result.add(node);
            var current = node.parent_node;
            while (current) |ancestor| {
                try result.add(ancestor);
                current = ancestor.parent_node;
            }
        },
        .preceding_sibling => {
            // All siblings before this node (in reverse document order)
            if (node.parent_node) |parent| {
                for (0..parent.child_nodes.size()) |i| {
                    if (parent.child_nodes.get(i)) |sibling| {
                        if (sibling == node) break;
                        try result.add(sibling);
                    }
                }
            }
        },
        .preceding => {
            // All nodes before this node in document order (not ancestors)
            // This is complex - for now, simplified implementation
            if (node.parent_node) |parent| {
                for (0..parent.child_nodes.size()) |i| {
                    if (parent.child_nodes.get(i)) |sibling| {
                        if (sibling == node) break;
                        try result.add(sibling);
                        try addDescendants(allocator, sibling, &result);
                    }
                }
                // Recursively apply to ancestors
                var current = parent;
                while (current.parent_node) |ancestor| {
                    for (0..ancestor.child_nodes.size()) |j| {
                        if (ancestor.child_nodes.get(j)) |uncle| {
                            if (uncle == current) break;
                            try result.add(uncle);
                            try addDescendants(allocator, uncle, &result);
                        }
                    }
                    current = ancestor;
                }
            }
        },
    }

    return result;
}

/// Helper to add all descendants of a node to a NodeSet
fn addDescendants(allocator: std.mem.Allocator, node: *NodeBase, result: *NodeSet) !void {
    for (0..node.child_nodes.size()) |i| {
        if (node.child_nodes.get(i)) |child| {
            try result.add(child);
            try addDescendants(allocator, child, result);
        }
    }
}

fn matchesNodeTest(_: std.mem.Allocator, node_test: *const ast.NodeTest, node: *Node, _: *const Context) !bool {
    return switch (node_test.*) {
        .name_test => |name_test| matchesNameTest(&name_test, node),
        .node_type => |node_type| matchesNodeType(&node_type, node),
    };
}

fn matchesNameTest(name_test: *const ast.NodeTest.NameTest, node: *Node) bool {
    return switch (name_test.*) {
        .wildcard => {
            // * matches any element node
            return node.node_type == Node.ELEMENT_NODE;
        },
        .qname => |qname| {
            // Match element nodes with specific name
            if (node.node_type != Node.ELEMENT_NODE) return false;

            // For now, ignore namespace prefix and just match local name
            // TODO: Implement proper namespace matching when namespace support is added
            return std.mem.eql(u8, node.node_name, qname.local);
        },
        .namespace_wildcard => |prefix| {
            // prefix:* matches any element in that namespace
            // For now, just match element nodes
            // TODO: Implement proper namespace matching
            _ = prefix;
            return node.node_type == Node.ELEMENT_NODE;
        },
    };
}

fn matchesNodeType(node_type: *const ast.NodeTest.NodeType, node: *Node) bool {
    return switch (node_type.*) {
        .comment => node.node_type == Node.COMMENT_NODE,
        .text => node.node_type == Node.TEXT_NODE or node.node_type == Node.CDATA_SECTION_NODE,
        .processing_instruction => |target| {
            if (node.node_type != Node.PROCESSING_INSTRUCTION_NODE) return false;
            if (target) |t| {
                // Match specific processing instruction target
                return std.mem.eql(u8, node.node_name, t);
            }
            // Match any processing instruction
            return true;
        },
        .node => {
            // node() matches any node
            return true;
        },
    };
}

fn compareValues(allocator: std.mem.Allocator, left: Value, right: Value, _: bool) !bool {
    // Simplified comparison - convert to strings and compare
    const left_str = try left.toString(allocator);
    defer allocator.free(left_str);
    const right_str = try right.toString(allocator);
    defer allocator.free(right_str);
    return std.mem.eql(u8, left_str, right_str);
}
