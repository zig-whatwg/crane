//! DocumentFragment interface per WHATWG DOM Standard

const std = @import("std");
const webidl = @import("webidl");
const dom = @import("dom");
const ParentNode = @import("parent_node").ParentNode;
const NonElementParentNode = @import("non_element_parent_node").NonElementParentNode;
const NodeList = @import("node_list").NodeList;
const HTMLCollection = @import("html_collection").HTMLCollection;
const dom_types = @import("dom_types");

/// DOM Spec: interface DocumentFragment : Node
pub const DocumentFragment = webidl.interface(struct {
    pub const extends = Node;
    pub const includes = .{ ParentNode, NonElementParentNode };

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !DocumentFragment {
        // NOTE: Parent Node fields will be flattened by codegen
        return .{
            .allocator = allocator,
            // TODO: Initialize Node parent fields (will be added by codegen)
        };
    }

    pub fn deinit(self: *DocumentFragment) void {
        _ = self;
        // NOTE: Parent Node cleanup will be handled by codegen
        // TODO: Call parent Node deinit (will be added by codegen)
    }
}, .{
    .exposed = &.{.Window},
});
