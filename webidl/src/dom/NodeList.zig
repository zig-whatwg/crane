//! NodeList interface per WHATWG DOM Standard

const std = @import("std");
const webidl = @import("webidl");
const Node = @import("node").Node;

pub const NodeList = webidl.interface(struct {
    allocator: std.mem.Allocator,
    nodes: std.ArrayList(*Node),

    pub fn init(allocator: std.mem.Allocator) !NodeList {
        return .{
            .allocator = allocator,
            .nodes = std.ArrayList(*Node).init(allocator),
        };
    }

    pub fn deinit(self: *NodeList) void {
        self.nodes.deinit();
    }

    pub fn call_item(self: *const NodeList, index: u32) ?*Node {
        if (index < self.nodes.items.len) {
            return self.nodes.items[index];
        }
        return null;
    }

    pub fn get_length(self: *const NodeList) u32 {
        return @intCast(self.nodes.items.len);
    }
});
