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
const fetch = @import("fetch");
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

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // A meta element's pragma runs when it is inserted into a document.
    dom_module.mutation.registerInsertionStepsCallback(&insertionSteps) catch {};
    // The "referrer" metadata name runs again when name or content changes.
    dom_module.attribute_change_steps.install("meta", &attributeChangeSteps);
}

/// Initialize instance (creates the instance)
/// Chains to parent class: HTMLElement -> Element -> Node -> EventTarget
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
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

/// "When a meta element is inserted into the document, if its http-equiv
/// attribute is present and represents one of the above states, then the
/// user agent must run the algorithm appropriate for that state."
///
/// Only the Refresh state is modelled; the other states (content language,
/// encoding declaration, default style, set-cookie, X-UA-Compatible,
/// Content-Security-Policy) do nothing here.
fn insertionSteps(node: *NodeBase) void {
    if (node.node_type != 1) return;
    // Brand-checked by the instance's state, not by `node.node_name`: an
    // element's NodeBase name is set only where its own init sets it (an
    // iframe's, a script's), and is empty for a meta element.
    const instance: *runtime.Instance = @ptrCast(@alignCast(instance_bridge.getInstance(node) orelse return));
    if (instance.stateAs(State) == null) return;
    // "Inserted into a document": the insertion steps ran for it and it is
    // now in a document tree - not a shadow tree
    // (attr-meta-http-equiv-refresh/not-in-shadow-tree).
    if (!inDocumentTree(node)) return;
    // The "referrer" metadata name runs for a meta element inserted into the
    // document.
    referrerMetadataName(instance);
    const ElementImpl = @import("Element.zig");
    const http_equiv = (ElementImpl.call_getAttribute(instance, runtime.DOMString.initInterned("http-equiv")) catch return) orelse return;
    // The attribute is an enumerated attribute: its keywords match ASCII
    // case-insensitively.
    if (std.ascii.eqlIgnoreCase(http_equiv.asSlice(), "refresh")) refreshState(instance);
}

/// The meta element's attribute change steps: HTML's "referrer" metadata
/// name runs when a meta element "has its name or content attributes
/// changed".
fn attributeChangeSteps(element: *runtime.Instance, local_name: []const u8, old_value: ?[]const u8, value: ?[]const u8, namespace: ?[]const u8) void {
    _ = old_value;
    _ = value;
    if (namespace != null) return;
    if (std.mem.eql(u8, local_name, "name") or std.mem.eql(u8, local_name, "content")) referrerMetadataName(element);
}

/// HTML 4.2.5.1, the "referrer" metadata name: "If any meta element element
/// is inserted into the document, or has its name or content attributes
/// changed, user agents must run the following algorithm." Removing one
/// changes nothing, and the last inserted or changed one wins - there is no
/// tree order.
fn referrerMetadataName(element: *runtime.Instance) void {
    const node = instance_bridge.getNodeBase(element) orelse return;
    // 1. "If element is not in a document tree, then return."
    if (!inDocumentTree(node)) return;
    // 2. "If element does not have a name attribute whose value is an ASCII
    // case-insensitive match for "referrer", then return."
    const name = (interfaces.Element.call_getAttribute(element, runtime.DOMString.initInterned("name")) catch return) orelse return;
    if (!std.ascii.eqlIgnoreCase(name.asSlice(), "referrer")) return;
    // 3. "If element does not have a content attribute, or that attribute's
    // value is the empty string, then return."
    const content = (interfaces.Element.call_getAttribute(element, runtime.DOMString.initInterned("content")) catch return) orelse return;
    // 4-5. The value, ASCII lowercased, with the legacy values mapped.
    const policy = fetch.internal.policy_container.referrerPolicyFromMeta(content.asSlice()) orelse return;
    // 6. "If value is a referrer policy, then set element's node document's
    // policy container's referrer policy to policy."
    const document = (interfaces.Node.get_ownerDocument(element) catch return) orelse return;
    const container = dom_module.policy_containers.of(document) orelse return;
    container.referrer_policy = policy;
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
