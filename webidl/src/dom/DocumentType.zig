//! DocumentType interface per WHATWG DOM Standard

const std = @import("std");
const webidl = @import("webidl");
const Node = @import("node").Node;
const ChildNode = @import("child_node").ChildNode;
const dom_types = @import("dom_types");

/// DOM Spec: interface DocumentType : Node
pub const DocumentType = webidl.interface(struct {
    pub const extends = Node;
    pub const includes = .{ChildNode};

    allocator: std.mem.Allocator,
    name: []const u8,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !DocumentType {
        // NOTE: Parent Node fields will be flattened by codegen
        return .{
            .allocator = allocator,
            .name = name,
            // TODO: Initialize Node parent fields (will be added by codegen)
        };
    }

    pub fn deinit(self: *DocumentType) void {
        _ = self;
        // NOTE: Parent Node cleanup will be handled by codegen
        // TODO: Call parent Node deinit (will be added by codegen)
    }

    pub fn get_name(self: *const DocumentType) []const u8 {
        return self.name;
    }
}, .{
    .exposed = &.{.Window},
});
