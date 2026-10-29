//! Typed OM §§5.3–5.4: walk the existing pending-substitution tree.
//! This module never tokenizes a property value or resolves a substitution.
const std = @import("std");
const substitution = @import("../substitution.zig");
const unparsed = @import("unparsed.zig");
const Allocator = std.mem.Allocator;
const Node = substitution.Node;

pub const Graph = struct {
    allocator: Allocator,
    arena: std.heap.ArenaAllocator,
    lists: []const []const unparsed.Segment = &.{},

    pub fn deinit(self: *Graph) void {
        const allocator = self.allocator;
        self.arena.deinit();
        allocator.destroy(self);
    }

    pub fn length(self: *const Graph, id: usize) !usize {
        return self.lists[id].len;
    }

    pub fn segment(self: *const Graph, id: usize, index: usize) !unparsed.Segment {
        return self.lists[id][index];
    }

    pub fn release(_: *const Graph, _: unparsed.Segment) void {}
};

const Bucket = struct {
    parts: std.ArrayList(unparsed.Segment) = .empty,
    text: std.ArrayList(u8) = .empty,

    fn flush(self: *Bucket, allocator: Allocator) Allocator.Error!void {
        if (self.text.items.len == 0) return;
        const string = try allocator.dupe(u8, self.text.items);
        try self.parts.append(allocator, .{ .string = string });
        self.text.clearRetainingCapacity();
    }
};

/// Q31 probe, Chrome 156 / Safari 27, 2026-10-27: only var() has a
/// reference object; env/attr/if remain maximal string segments. Names are
/// decoded in both shippers. Q34: the newer Variables grammar can compute
/// a var name; stable browsers lag it. Such an outer var stays string
/// fragments, with ordinary nested var references reified recursively.
/// Revisit when a browser ships a Typed OM representation for that grammar.
pub fn fromNodes(allocator: Allocator, nodes: []const Node) Allocator.Error!*Graph {
    const result = try allocator.create(Graph);
    result.* = .{ .allocator = allocator, .arena = std.heap.ArenaAllocator.init(allocator) };
    errdefer result.deinit();
    const arena = result.arena.allocator();
    const Frame = struct {
        nodes: []const Node,
        bucket: usize,
        index: usize = 0,
        close: ?u8 = null,
        close_raw: []const u8 = "",
        finish_list: bool = false,
    };
    var buckets: std.ArrayList(Bucket) = .empty;
    try buckets.append(arena, .{});
    var frames: std.ArrayList(Frame) = .empty;
    try frames.append(arena, .{ .nodes = nodes, .bucket = 0, .finish_list = true });
    while (frames.items.len != 0) {
        const top = &frames.items[frames.items.len - 1];
        const bucket = top.bucket;
        if (top.index == top.nodes.len) {
            if (top.close) |close| {
                if (top.close_raw.len != 0) {
                    try buckets.items[bucket].text.appendSlice(arena, top.close_raw);
                } else try buckets.items[bucket].text.append(arena, close);
            }
            if (top.finish_list) try buckets.items[bucket].flush(arena);
            _ = frames.pop();
            continue;
        }
        const node = top.nodes[top.index];
        top.index += 1;
        if (node.function == .@"var") {
            var comma: ?usize = null;
            for (node.children, 0..) |child, index| if (child.kind == .comma) {
                comma = index;
                break;
            };
            const name_nodes = node.children[0 .. comma orelse node.children.len];
            const rendered = try substitution.render(arena, name_nodes);
            if (try substitution.customPropertyName(arena, rendered.text)) |name| {
                // Node.raw includes any comment immediately before the
                // function token. That prefix belongs to the preceding run.
                const prefix = @intFromPtr(node.value.ptr) - @intFromPtr(node.raw.ptr);
                try buckets.items[bucket].text.appendSlice(arena, node.raw[0..prefix]);
                try buckets.items[bucket].flush(arena);
                const fallback: ?usize = if (comma != null) buckets.items.len else null;
                if (fallback != null) try buckets.append(arena, .{});
                try buckets.items[bucket].parts.append(arena, .{ .variable = .{ .name = name, .fallback = fallback } });
                if (fallback) |id| {
                    // Read the original node slice: the shared argument
                    // grammar's trimmed view would lose fallback whitespace.
                    try frames.append(arena, .{ .nodes = node.children[comma.? + 1 ..], .bucket = id, .finish_list = true });
                }
                continue;
            }
        }
        try buckets.items[bucket].text.appendSlice(arena, node.raw);
        if (node.close != null) try frames.append(arena, .{
            .nodes = node.children,
            .bucket = bucket,
            .close = node.close,
            .close_raw = node.close_raw,
        });
    }
    const lists = try arena.alloc([]const unparsed.Segment, buckets.items.len);
    for (lists, buckets.items) |*list, bucket| list.* = bucket.parts.items;
    result.lists = lists;
    return result;
}
