//! CharacterData interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-characterdata

const std = @import("std");
const webidl = @import("webidl");
const Node = @import("node").Node;
const ChildNode = @import("ChildNode.zig").ChildNode;
const NonDocumentTypeChildNode = @import("NonDocumentTypeChildNode.zig").NonDocumentTypeChildNode;

const Allocator = std.mem.Allocator;

/// DOM Spec: interface CharacterData : Node
pub const CharacterData = webidl.interface(struct {
    pub const extends = Node;
    pub const includes = .{ ChildNode, NonDocumentTypeChildNode };

    allocator: Allocator,
    data: []const u8,

    pub fn init(allocator: Allocator) !CharacterData {
        // NOTE: Parent Node fields will be flattened by codegen
        return .{
            .allocator = allocator,
            .data = "",
            // TODO: Initialize Node parent fields (will be added by codegen)
        };
    }

    pub fn deinit(self: *CharacterData) void {
        _ = self;
        // NOTE: Parent Node cleanup will be handled by codegen
        // TODO: Call parent Node deinit (will be added by codegen)
    }

    pub fn get_data(self: *const CharacterData) []const u8 {
        return self.data;
    }

    pub fn get_length(self: *const CharacterData) usize {
        return self.data.len;
    }
}, .{
    .exposed = &.{.Window},
});
