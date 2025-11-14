//! DocumentFragment interface per WHATWG DOM Standard

const std = @import("std");
const webidl = @import("webidl");
const dom = @import("dom");
const Node = @import("node").Node;
const ParentNode = @import("parent_node").ParentNode;
const NonElementParentNode = @import("non_element_parent_node").NonElementParentNode;
const HTMLCollection = @import("html_collection").HTMLCollection;
const dom_types = @import("dom_types");

// Forward declaration for Element to avoid circular dependency
const Element = @import("element").Element;

/// DOM Spec: interface DocumentFragment : Node
pub const DocumentFragment = webidl.interface(struct {
    pub const extends = Node;
    pub const includes = .{ ParentNode, NonElementParentNode };

    allocator: std.mem.Allocator,

    /// Host element for shadow roots (null for regular document fragments)
    /// Per DOM spec: A shadow root's host is always non-null
    /// This field allows distinguishing ShadowRoot from plain DocumentFragment
    host: ?*Element = null,

    pub fn init(allocator: std.mem.Allocator) !DocumentFragment {
        // NOTE: Parent Node fields will be flattened by codegen
        return .{
            .allocator = allocator,
            .host = null,
            // NOTE: Parent Node initialization is handled by codegen
        };
    }

    pub fn deinit(self: *DocumentFragment) void {
        _ = self;
        // NOTE: Parent Node cleanup is handled by codegen
    }
}, .{
    .exposed = &.{.Window},
});
