//! NodeList interface per WHATWG DOM Standard

const std = @import("std");
const infra = @import("infra");
const webidl = @import("webidl");
const Node = @import("node").Node;

pub const NodeList = webidl.interface(struct {
    allocator: std.mem.Allocator,
    nodes: infra.List(*Node),

    pub fn init(allocator: std.mem.Allocator) !NodeList {
        return .{
            .allocator = allocator,
            .nodes = infra.List(*Node).init(allocator),
        };
    }

    pub fn deinit(self: *NodeList) void {
        self.nodes.deinit();
    }

    /// DOM §4.3.6 - NodeList.item(index)
    /// Returns the node at the given index, or null if out of bounds.
    /// The nodes are sorted in tree order.
    pub fn call_item(self: *const NodeList, index: u32) ?*Node {
        if (index >= self.nodes.items.len) {
            return null;
        }
        return self.nodes.items[index];
    }

    /// DOM §4.3.6 - NodeList.length
    /// Returns the number of nodes in the collection.
    pub fn get_length(self: *const NodeList) u32 {
        return @intCast(self.nodes.items.len);
    }

    /// Helper method to add a node to the list
    /// NOTE: This is internal API, not part of WebIDL spec
    pub fn addNode(self: *NodeList, node: *Node) !void {
        try self.nodes.append(node);
    }

    /// Helper method to clear the list
    /// NOTE: This is internal API, not part of WebIDL spec
    pub fn clear(self: *NodeList) void {
        self.nodes.clearRetainingCapacity();
    }
}, .{
    .exposed = &.{.Window},
});
