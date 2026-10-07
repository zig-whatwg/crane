//! Making nodes the way HTML's tree construction does, where no IDL member
//! fits.
//!
//! The HTML parser's "create an element for the token" runs DOM's "create an
//! element", which sets the new element's namespace and local name - with
//! none of the validation createElementNS applies to script's input, since a
//! name the tokenizer produced is one an element may hold. Its DOCTYPE token
//! appends "a DocumentType node ... with its name set to the name given in
//! the DOCTYPE token, or the empty string if the name was missing; its public
//! ID set to the public identifier given in the DOCTYPE token, or the empty
//! string if the public identifier was missing; and its system ID set to the
//! system identifier" - fields no IDL member writes. And a node the parser's
//! DOM adapter created but never inserted is freed by it, the way the tree
//! teardown frees a child: that is an engine concern (the adapter's
//! ownership, not a spec step), Blink's and WebKit's reference counting.
//!
//! Each step is its owner's state: Element installs the names, DocumentType
//! the identifiers, Node the teardown, each from its installHooks, before any node
//! exists for a parser to make.
//!
//! Spec: https://dom.spec.whatwg.org/#concept-create-element
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#the-initial-insertion-mode
//!
//! lint-impls: hook for Node, Element, DocumentType
const process_start = @import("process_start.zig");

const runtime = @import("runtime");

pub const Error = error{ InvalidStateError, OutOfMemory };

/// What Element supplies.
pub const ElementSteps = struct {
    /// Set `element`'s namespace and local name.
    set_names: *const fn (element: *runtime.Instance, namespace: ?[]const u8, local_name: []const u8) Error!void,
    /// Borrow the is value assigned by "create an element", for serialization.
    is_value: ?*const fn (*runtime.Instance) ?[]const u8 = null,
};

/// What DocumentType supplies.
pub const DocumentTypeSteps = struct {
    /// Set `doctype`'s name, public ID and system ID; a null one stays "".
    set_ids: *const fn (doctype: *runtime.Instance, name: ?[]const u8, public_id: ?[]const u8, system_id: ?[]const u8) void,
};

/// What Node supplies.
pub const NodeSteps = struct {
    /// Free `node`, which was created and never inserted, and its subtree.
    destroy_uninserted: *const fn (node: *runtime.Instance) void,
    /// DOM clone-a-node, with an explicit document, parent and fallback registry.
    clone: ?*const fn (*runtime.Instance, ?*runtime.Instance, bool, ?*runtime.Instance, ?*runtime.Instance) anyerror!*runtime.Instance = null,
    set_type: ?*const fn (*runtime.Instance, u16) anyerror!void = null,
};

const Hooks = struct {
    element: ?ElementSteps = null,
    document_type: ?DocumentTypeSteps = null,
    node: ?NodeSteps = null,
};
// process-wide: immutable creation algorithms installed before any Browser, with no instance state
var node_steps: Hooks = .{};

/// Called by Element's installHooks, once, at process start (process_start.zig).
pub fn installElement(steps: ElementSteps) void {
    process_start.assertInstalling();
    node_steps.element = steps;
}

/// Called by DocumentType's installHooks, once, at process start (process_start.zig).
pub fn installDocumentType(steps: DocumentTypeSteps) void {
    process_start.assertInstalling();
    node_steps.document_type = steps;
}

/// Called by Node's installHooks, once, at process start (process_start.zig).
pub fn installNode(steps: NodeSteps) void {
    process_start.assertInstalling();
    node_steps.node = steps;
}

/// DOM "create an element": set `element`'s namespace and local name.
pub fn setElementNames(element: *runtime.Instance, namespace: ?[]const u8, local_name: []const u8) Error!void {
    const steps = node_steps.element orelse return error.InvalidStateError;
    return steps.set_names(element, namespace, local_name);
}

pub fn elementIsValue(element: *runtime.Instance) ?[]const u8 {
    const steps = node_steps.element orelse return null;
    const read = steps.is_value orelse return null;
    return read(element);
}

/// The parser's DOCTYPE token: set `doctype`'s name, public ID and system
/// ID, each "" where the token had none.
pub fn setDoctypeIds(doctype: *runtime.Instance, name: ?[]const u8, public_id: ?[]const u8, system_id: ?[]const u8) void {
    const steps = node_steps.document_type orelse return;
    steps.set_ids(doctype, name, public_id, system_id);
}

/// Free `node` - created, never inserted, unreachable from script - and its
/// subtree.
pub fn destroyUninserted(node: *runtime.Instance) void {
    const steps = node_steps.node orelse return;
    steps.destroy_uninserted(node);
}

/// DOM "clone a node": callers supply its document and parent.
pub fn clone(node: *runtime.Instance, document: ?*runtime.Instance, subtree: bool, parent: ?*runtime.Instance) !*runtime.Instance {
    return cloneWithRegistry(node, document, subtree, parent, null);
}

pub fn cloneWithRegistry(node: *runtime.Instance, document: ?*runtime.Instance, subtree: bool, parent: ?*runtime.Instance, fallback_registry: ?*runtime.Instance) !*runtime.Instance {
    const steps = node_steps.node orelse return error.InvalidStateError;
    const algorithm = steps.clone orelse return error.InvalidStateError;
    return algorithm(node, document, subtree, parent, fallback_registry);
}

/// Set the node kind during initialization, before publishing the node.
pub fn setType(node: *runtime.Instance, kind: u16) !void {
    const steps = node_steps.node orelse return error.InvalidStateError;
    const algorithm = steps.set_type orelse return error.InvalidStateError;
    return algorithm(node, kind);
}

test "without installed steps nothing is set or freed" {
    const std = @import("std");
    const saved_node = node_steps;
    defer node_steps = saved_node;
    node_steps = .{};
    // Never dereferenced: with no steps nothing reads it.
    var node: runtime.Instance = undefined;
    try std.testing.expectError(error.InvalidStateError, setElementNames(&node, null, "div"));
    setDoctypeIds(&node, "html", null, null);
    destroyUninserted(&node);
}
