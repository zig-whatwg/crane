//! Typed OM §3: snapshot live numeric slots into the EXISTING CSS math IR.
//! No token stream or serialization is involved; the property's normal
//! grammar subsequently validates and simplifies this context-free tree.
const std = @import("std");
const math = @import("../math_values.zig");
const numeric = @import("numeric.zig");
const ops = @import("numeric_ops.zig");

/// Raw numeric-object operations have no property grammar or parser limits.
pub fn snapshot(allocator: std.mem.Allocator, root: usize, reader: anytype) !*math.NumericExpression {
    return snapshotImpl(allocator, root, reader, null);
}

/// CSS Values 4 §10.8: bound property input before its recursive simplifier
/// or compute-time copier sees the native tree. No declaration is changed.
pub fn snapshotForProperty(allocator: std.mem.Allocator, root: usize, reader: anytype) !*math.NumericExpression {
    return snapshotImpl(allocator, root, reader, .{
        .depth = math.calculation_max_depth,
        .nodes = math.calculation_max_nodes,
    });
}

const Limits = struct { depth: usize, nodes: usize };

fn nextDepth(limits: ?Limits, parent_depth: usize, expanded: *usize, view: ops.View) error{Invalid}!usize {
    const bound = limits orelse return 0;
    if (view.kind == .unit) return parent_depth;
    // Q85/Q89, CSS Values 4 §10.8: text counts parser calls; this path
    // counts operation depth and expanded operations. The shared ceilings
    // therefore accept some graphs around 64–128 levels whose serialization
    // exceeds the text parser's effective limit. §10.8 permits that gap;
    // the required 32-level range must still serialize and reparse.
    if (parent_depth >= bound.depth or expanded.* >= bound.nodes) return error.Invalid;
    expanded.* += 1; // Count occurrences, including repeated references in a DAG.
    return parent_depth + 1;
}

fn snapshotImpl(allocator: std.mem.Allocator, root: usize, reader: anytype, limits: ?Limits) !*math.NumericExpression {
    const expression = try allocator.create(math.NumericExpression);
    expression.* = .{ .allocator = allocator, .arena = std.heap.ArenaAllocator.init(allocator) };
    errdefer expression.deinit();
    const arena = expression.arena.allocator();
    const Frame = struct { id: usize, view: ops.View, next: usize = 0, base: usize, operation_depth: usize };
    var frames: std.ArrayList(Frame) = .empty;
    defer frames.deinit(allocator);
    var results: std.ArrayList(*math.Node) = .empty;
    defer results.deinit(allocator);
    var expanded: usize = 0;
    const root_view = try reader.view(root);
    const root_depth = try nextDepth(limits, 0, &expanded, root_view);
    try frames.append(allocator, .{ .id = root, .view = root_view, .base = 0, .operation_depth = root_depth });
    while (frames.items.len > 0) {
        const top = &frames.items[frames.items.len - 1];
        if (top.next < top.view.count) {
            const child = try reader.child(top.id, top.next);
            top.next += 1;
            const view = try reader.view(child);
            const depth = try nextDepth(limits, top.operation_depth, &expanded, view);
            try frames.append(allocator, .{ .id = child, .view = view, .base = results.items.len, .operation_depth = depth });
            continue;
        }
        const frame = frames.pop().?;
        const children = try arena.dupe(*math.Node, results.items[frame.base..]);
        const node = try arena.create(math.Node);
        var typ: math.Type = if (frame.view.kind == .unit) math.Type.one(frame.view.number.unit.base()) else blk: {
            if (children.len == 0) return error.Invalid;
            var result = children[0].typ;
            if (frame.view.kind == .invert) result = try numeric.invertType(result);
            for (children[1..]) |child| result = if (frame.view.kind == .product)
                try numeric.multiplyTypes(result, child.typ)
            else
                try numeric.addTypes(result, child.typ);
            break :blk result;
        };
        if (frame.view.kind == .unit and frame.view.number.unit == .percent) typ = math.Type.one(.percent);
        node.* = .{
            .tag = switch (frame.view.kind) {
                .unit => .numeric,
                .sum => .sum,
                .product => .product,
                .negate => .negate,
                .invert => .invert,
                .min => .min,
                .max => .max,
                .clamp => .clamp,
            },
            .typ = typ,
            .numeric = frame.view.number,
            .children = children,
        };
        results.shrinkRetainingCapacity(frame.base);
        try results.append(allocator, node);
    }
    expression.root = results.items[0];
    return expression;
}
