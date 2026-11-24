//! Implementation for HTMLTitleElement interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const HTMLTitleElement = interfaces.HTMLTitleElement;

pub const State = HTMLTitleElement.State;

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
/// a title element inserted, removed, or with its children changed may change the
/// document's title, which the DevTools remote end reports to its targets
/// (dom.inspector_probes.titleMayHaveChanged; Blink's HTMLTitleElement::ChildrenChanged / InsertedInto / RemovedFrom ->
/// Document::UpdateTitle), and a title the parser has finished, once
/// (dom.finish_parsing_children). Each step costs one gate read while no
/// Browser is adopted by the remote end.
pub fn installHooks() void {
    dom_module.mutation.registerInsertionStepsCallback(&insertionSteps) catch {};
    dom_module.mutation.registerRemovingStepsCallback(&removingSteps) catch {};
    dom_module.mutation.registerChildrenChangedCallback(&childrenChangedSteps) catch {};
    dom_module.finish_parsing_children.install("title", .{ .finished = &finishedParsingChildren });
}

/// `node` as this element, when it is one.
fn titleOf(node: *NodeBase) ?*runtime.Instance {
    if (node.node_type != 1) return null;
    const ptr = instance_bridge.getInstance(node) orelse return null;
    const instance: *runtime.Instance = @ptrCast(@alignCast(ptr));
    _ = instance.stateAs(State) orelse return null;
    return instance;
}

/// Whether `title` can be "the title element" (HTML: the first title
/// element in the document): any connected one - which is first is the
/// title getter's to say, and an extra probe is harmless (the remote end
/// reports a title only when it changed).
fn countsForTitle(title: *NodeBase) bool {
    _ = title;
    return true;
}

/// The probe, unless the parser is still inside the element: a parsed
/// title reports its text once, not per character it appends, when the
/// parser pops it (`finishedParsingChildren`).
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
    if (false) return;
    probe(title);
}

/// The parser popped the element off its stack of open elements: its text
/// is parsed (Blink's HTMLTitleElement::ChildrenChanged and
/// Element::FinishParsingChildren -> Document::UpdateTitle), and a parsed
/// title reaches the remote end now, not at DOMContentLoaded - Chrome 157
/// lists a streamed page's title in Target.getTargets from its commit, while
/// its body is still coming (tests/devtools/mcp1_title_timing_test.zig).
fn finishedParsingChildren(title: *runtime.Instance) void {
    if (!inspector_probes.titlesObserved()) return;
    const owner = interfaces.Node.get_ownerDocument(title) catch return;
    const document = owner orelse return;
    inspector_probes.titleMayHaveChanged(document);
}

fn childrenChangedSteps(parent: *NodeBase, _: dom_module.mutation.ChildrenChange) void {
    if (!inspector_probes.titlesObserved()) return;
    if (!parent.is_connected) return;
    const title = titleOf(parent) orelse return;
    if (!countsForTitle(parent)) return;
    probe(title);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try HTMLTitleElement.init(ctx.allocator, ctx);
    errdefer HTMLTitleElement.deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for text
pub fn get_text(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // HTML 4.2.2: child text content (Text children only, not descendants).
    return runtime.DOMString.initOwned(try @import("dom").script_elements.childTextContent(instance.ctx.allocator, instance));
}

/// Setter for text
pub fn set_text(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    // HTML 4.2.2: string replace all. Node's Element branch runs steps
    // 1-3, including removal reactions inside this accessor's CEReactions.
    try interfaces.Node.set_textContent(instance, value);
}
