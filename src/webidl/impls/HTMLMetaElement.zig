//! Implementation for HTMLMetaElement interface
//!
//! HTMLMetaElement represents a <meta> element in the DOM.
//! All attributes are reflected content attributes per HTML spec.
//! Spec: https://html.spec.whatwg.org/multipage/semantics.html#the-meta-element

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const HTMLMetaElement = interfaces.HTMLMetaElement;
const Element = interfaces.Element;
const dom_module = @import("dom");
const instance_bridge = dom_module.instance_bridge;
const NodeBase = dom_module.NodeBase;

pub const State = HTMLMetaElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
/// Chains to parent class: HTMLElement -> Element -> Node -> EventTarget
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // A meta element's pragma runs when it is inserted into a document:
    // installed before any meta element exists.
    ensureInsertionStepsRegistered();
    // Chain to parent class (HTMLElement)
    const HTMLElementImpl = @import("HTMLElement.zig");
    const instance = try HTMLElementImpl.init(allocator, StateType, vtable, ctx);
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // HTMLMetaElement has no additional cleanup
    // Chain to parent class
    const HTMLElementImpl = @import("HTMLElement.zig");
    HTMLElementImpl.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &HTMLMetaElement.vtable, ctx);
    errdefer deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

// =============================================================================
// Reflected Content Attributes
// =============================================================================
// All HTMLMetaElement attributes are reflected content attributes.
// Spec: https://html.spec.whatwg.org/multipage/semantics.html#the-meta-element

// =============================================================================
// Pragma directives (HTML §4.2.5.3)
// =============================================================================

var insertion_steps_registered: bool = false;

fn ensureInsertionStepsRegistered() void {
    if (insertion_steps_registered) return;
    dom_module.mutation.registerInsertionStepsCallback(&insertionSteps) catch return;
    insertion_steps_registered = true;
}

/// "When a meta element is inserted into the document, if its http-equiv
/// attribute is present and represents one of the above states, then the
/// user agent must run the algorithm appropriate for that state."
///
/// Only the Refresh state is modelled; the other states (content language,
/// encoding declaration, default style, set-cookie, X-UA-Compatible,
/// Content-Security-Policy) do nothing here.
fn insertionSteps(node: *NodeBase) void {
    if (node.node_type != 1) return;
    if (!std.ascii.eqlIgnoreCase(node.node_name, "meta")) return;
    const instance: *runtime.Instance = @ptrCast(@alignCast(instance_bridge.getInstance(node) orelse return));
    if (instance.stateAs(State) == null) return;
    // "Inserted into a document": the insertion steps ran for it and it is
    // now in a document tree - not a shadow tree
    // (attr-meta-http-equiv-refresh/not-in-shadow-tree).
    if (!inDocumentTree(node)) return;
    const ElementImpl = @import("Element.zig");
    const http_equiv = (ElementImpl.call_getAttribute(instance, runtime.DOMString.initInterned("http-equiv")) catch return) orelse return;
    // The attribute is an enumerated attribute: its keywords match ASCII
    // case-insensitively.
    if (std.ascii.eqlIgnoreCase(http_equiv.asSlice(), "refresh")) refreshState(instance);
}

/// Whether `node`'s root is a document: it is in a document tree.
fn inDocumentTree(node: *NodeBase) bool {
    var root = node;
    var depth: usize = 0;
    while (root.parent_node) |parent| : (depth += 1) {
        if (depth > 4096) return false;
        root = parent;
    }
    return root.node_type == 9;
}

/// The Refresh state (`http-equiv="refresh"`): a timed redirect.
fn refreshState(meta: *runtime.Instance) void {
    const ElementImpl = @import("Element.zig");
    // Step 1: "If the meta element has no content attribute, or if that
    // attribute's value is the empty string, then return."
    const content = (ElementImpl.call_getAttribute(meta, runtime.DOMString.initInterned("content")) catch return) orelse return;
    // Step 2: "Let input be the value of the element's content attribute."
    const input = content.asSlice();
    if (input.len == 0) return;
    // Step 3: "Run the shared declarative refresh steps with the meta
    // element's node document, input, and the meta element."
    const NodeImpl = @import("Node.zig");
    const document = NodeImpl.getOwnerDocument(meta) orelse return;
    dom_module.document_lifecycle.declarativeRefresh(document, input, meta);
}
