//! DocumentFragment interface per WHATWG DOM Standard

const std = @import("std");
const webidl = @import("webidl");
const Node = @import("node").Node;

pub const DocumentFragment = webidl.interface(struct {
    allocator: std.mem.Allocator,
    node: Node,

    pub fn init(allocator: std.mem.Allocator) !DocumentFragment {
        return .{
            .allocator = allocator,
            .node = try Node.init(allocator, Node.DOCUMENT_FRAGMENT_NODE, "#document-fragment"),
        };
    }

    pub fn deinit(self: *DocumentFragment) void {
        self.node.deinit();
    }
});
