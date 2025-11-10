//! DocumentType interface per WHATWG DOM Standard

const std = @import("std");
const webidl = @import("webidl");
const Node = @import("node").Node;

pub const DocumentType = webidl.interface(struct {
    allocator: std.mem.Allocator,
    node: Node,
    name: []const u8,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !DocumentType {
        return .{
            .allocator = allocator,
            .node = try Node.init(allocator, Node.DOCUMENT_TYPE_NODE, name),
            .name = name,
        };
    }

    pub fn deinit(self: *DocumentType) void {
        self.node.deinit();
    }

    pub fn get_name(self: *const DocumentType) []const u8 {
        return self.name;
    }
}, .{
    .exposed = &.{.Window},
});
