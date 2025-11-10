//! CharacterData interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-characterdata

const std = @import("std");
const webidl = @import("webidl");
const Node = @import("node").Node;

const Allocator = std.mem.Allocator;

pub const CharacterData = webidl.interface(struct {
    allocator: Allocator,
    node: Node,
    data: []const u8,

    pub fn init(allocator: Allocator) !CharacterData {
        return .{
            .allocator = allocator,
            .node = try Node.init(allocator, Node.TEXT_NODE, "#text"),
            .data = "",
        };
    }

    pub fn deinit(self: *CharacterData) void {
        self.node.deinit();
    }

    pub fn get_data(self: *const CharacterData) []const u8 {
        return self.data;
    }

    pub fn get_length(self: *const CharacterData) usize {
        return self.data.len;
    }
});
