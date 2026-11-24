//! Implementation for SVGTitleElement interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const SVGTitleElement = interfaces.SVGTitleElement;

pub const State = SVGTitleElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

const dom_module = @import("dom");
const NodeBase = dom_module.NodeBase;
const instance_bridge = dom_module.instance_bridge;
const inspector_probes = dom_module.inspector_probes;

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md):
/// an SVG document element's title child inserted, removed, or with its children changed may change the
/// document's title, which the DevTools remote end reports to its targets
/// (dom.inspector_probes.titleMayHaveChanged; Blink's SVGTitleElement::ChildrenChanged / InsertedInto / RemovedFrom ->
/// Document::UpdateTitle). Each step costs one gate read while no Browser
/// is adopted by the remote end.
pub fn installHooks() void {
    dom_module.mutation.registerInsertionStepsCallback(&insertionSteps) catch {};
    dom_module.mutation.registerRemovingStepsCallback(&removingSteps) catch {};
    dom_module.mutation.registerChildrenChangedCallback(&childrenChangedSteps) catch {};
}

/// `node` as this element, when it is one.
fn titleOf(node: *NodeBase) ?*runtime.Instance {
    if (node.node_type != 1) return null;
    const ptr = instance_bridge.getInstance(node) orelse return null;
    const instance: *runtime.Instance = @ptrCast(@alignCast(ptr));
    _ = instance.stateAs(State) orelse return null;
    return instance;
}

/// Whether `title` is "the title element" of an SVG document: a child of
/// the document element (HTML document.title's step 1 reads the first SVG
/// title child of an SVG document element; extra probes are harmless - the
/// remote end reports a title only when it changed).
fn countsForTitle(title: *NodeBase) bool {
    const parent = title.parent_node orelse return false;
    const grandparent = parent.parent_node orelse return false;
    return grandparent.node_type == 9;
}

/// The probe, unless the parser is still inside the element: a parsed
/// title reports its text once, not per character it appends (Blink's
/// parser inserts a title's text in one change; the document's
/// DOMContentLoaded report carries a parsed title - BrowserSide).
fn probe(title: *runtime.Instance) void {
    const owner = interfaces.Node.get_ownerDocument(title) catch return;
    const document = owner orelse return;
    if (dom_module.document_rendering.onParserStack(document, title)) return;
    inspector_probes.titleMayHaveChanged(document);
}

fn insertionSteps(node: *NodeBase) void {
    if (!inspector_probes.titlesObserved()) return;
    if (!node.is_connected) return;
    const title = titleOf(node) orelse return;
    if (!countsForTitle(node)) return;
    probe(title);
}

fn removingSteps(node: *NodeBase, old_parent: ?*NodeBase) void {
    if (!inspector_probes.titlesObserved()) return;
    const parent = old_parent orelse return;
    if (!parent.is_connected) return;
    const title = titleOf(node) orelse return;
    // Removed from the document element (SVG): its old parent's parent was
    // the document.
    if ((parent.parent_node orelse return).node_type != 9) return;
    probe(title);
}

fn childrenChangedSteps(parent: *NodeBase, _: dom_module.mutation.ChildrenChange) void {
    if (!inspector_probes.titlesObserved()) return;
    if (!parent.is_connected) return;
    const title = titleOf(parent) orelse return;
    if (!countsForTitle(parent)) return;
    probe(title);
}
