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
        const infra = @import("infra");
        const RegisteredObserver = @import("registered_observer").RegisteredObserver;

        return .{
            // EventTarget fields
            .event_listener_list = null,
            // Node fields
            .allocator = allocator,
            .node_type = 11, // DOCUMENT_FRAGMENT_NODE
            .node_name = "#document-fragment",
            .parent_node = null,
            .child_nodes = infra.List(*Node).init(allocator),
            .owner_document = null,
            .registered_observers = infra.List(RegisteredObserver).init(allocator),
            .cloning_steps_hook = null,
            .cached_child_nodes = null,
            // DocumentFragment fields
            .host = null,
        };
    }

    pub fn deinit(self: *DocumentFragment) void {
        _ = self;
        // NOTE: Parent Node cleanup is handled by codegen
    }
}, .{
    .exposed = &.{.Window},
});
