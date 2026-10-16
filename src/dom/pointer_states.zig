//! HTML 4.16.3: the elements a Document's :hover and :active rest on.
//!
//! - `hovered`: the element the user designates with a pointing device
//!   ("designated by a pointing device", :hover);
//! - `pointed`: the element being actively pointed at - indicated while the
//!   pointing device is down (:active);
//! - `activated`: the element in a formal activation state - a button held
//!   by the keyboard's Space key until its keyup (:active).
//!
//! Each is the Document's state: Document keeps a weak link per state (an
//! element can be removed and freed while it is designated) and installs
//! the implementation once, at process start (its installHooks). Input
//! (src/html/user_input.zig) sets them; the :hover and :active pseudo-classes
//! (src/html/pseudo_classes.zig) read them. A reader gets an element only
//! while it is still in that document.
//!
//! An element that leaves the document hands its designations to the node
//! it was removed from, as Blink (Document::HoveredElementDetached,
//! Document::ActiveChainNodeDetached) and Gecko (EventStateManager::
//! ContentRemoved) move hover and active state to the removed element's
//! parent: `removingSteps`, which Document registers as removing steps.
//!
//! Spec: https://html.spec.whatwg.org/multipage/semantics-other.html#selector-hover
//!
//! lint-impls: hook for Document
const std = @import("std");
const process_start = @import("process_start.zig");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const NodeBase = @import("node_base.zig").NodeBase;
const instance_bridge = @import("instance_bridge.zig");

pub const State = enum {
    /// Designated by a pointing device (:hover).
    hovered,
    /// Being actively pointed at (:active).
    pointed,
    /// In a formal activation state (:active).
    activated,
};

/// What Document supplies.
pub const Implementation = struct {
    /// `document`'s element for `state`, or null - also once the element it
    /// names has been freed.
    get: *const fn (document: *runtime.Instance, state: State) ?*runtime.Instance,
    /// Designate `element` (null: nothing) for `state` in `document`.
    set: *const fn (document: *runtime.Instance, state: State, element: ?*runtime.Instance) void,
};

// process-wide: immutable function pointers Document installs once at process start (crane.Process); they read only the document they are given, so one serves every Browser and thread
var implementation: ?Implementation = null;

/// Called by Document's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// `document`'s element for `state`, while it is still in `document`
/// (connected, with `document` its node document).
pub fn get(document: *runtime.Instance, state: State) ?*runtime.Instance {
    const impl = implementation orelse return null;
    const element = impl.get(document, state) orelse return null;
    const node = instance_bridge.getNodeBase(element) orelse return null;
    if (!node.is_connected) return null;
    const owner = interfaces.Node.get_ownerDocument(element) catch return null;
    return if (owner == document) element else null;
}

/// Designate `element` (null: nothing) for `state` in `document`.
pub fn set(document: *runtime.Instance, state: State, element: ?*runtime.Instance) void {
    const impl = implementation orelse return;
    impl.set(document, state, element);
}

/// Removing steps (DOM 4.2.5), which Document registers: when the root of a
/// removed subtree leaves a document, each state designating an element in
/// that subtree passes to the parent it was removed from - its host, when
/// that parent is a shadow root; nothing, when it is the document.
pub fn removingSteps(node: *NodeBase, old_parent: ?*NodeBase) void {
    // The removal's root alone: its descendants still have their parents,
    // and a node removed from a tree no document holds changes nothing.
    if (node.parent_node != null or node.node_type != NodeBase.ELEMENT_NODE) return;
    const parent = old_parent orelse return;
    if (!parent.is_connected and parent.node_type != NodeBase.DOCUMENT_NODE) return;
    const impl = implementation orelse return;
    const parent_instance: *runtime.Instance = @ptrCast(@alignCast(parent.owner_instance orelse return));
    const document = if (parent.node_type == NodeBase.DOCUMENT_NODE)
        parent_instance
    else
        (interfaces.Node.get_ownerDocument(parent_instance) catch return) orelse return;
    for ([_]State{ .hovered, .pointed, .activated }) |state| {
        const element = impl.get(document, state) orelse continue;
        const designated = instance_bridge.getNodeBase(element) orelse continue;
        if (!isShadowIncludingInclusiveDescendant(designated, node)) continue;
        impl.set(document, state, successor(parent));
    }
}

/// The element a designation passes to when its element is removed from
/// `parent`: the parent element, or a shadow root's host.
fn successor(parent: *NodeBase) ?*runtime.Instance {
    const instance: *runtime.Instance = @ptrCast(@alignCast(parent.owner_instance orelse return null));
    if (parent.node_type == NodeBase.ELEMENT_NODE) return instance;
    if (instance.vtable == &interfaces.ShadowRoot.vtable) return interfaces.ShadowRoot.get_host(instance) catch null;
    return null;
}

/// Whether `node` is `ancestor` or below it, through shadow roots' hosts.
fn isShadowIncludingInclusiveDescendant(node: *NodeBase, ancestor: *NodeBase) bool {
    var current: ?*NodeBase = node;
    while (current) |n| {
        if (n == ancestor) return true;
        if (n.parent_node) |parent| {
            current = parent;
            continue;
        }
        // A shadow root: on to its host.
        const instance: *runtime.Instance = @ptrCast(@alignCast(n.owner_instance orelse return false));
        if (instance.vtable != &interfaces.ShadowRoot.vtable) return false;
        const host = interfaces.ShadowRoot.get_host(instance) catch return false;
        current = instance_bridge.getNodeBase(host);
    }
    return false;
}

test "without an installed implementation nothing is hovered or active" {
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with no implementation nothing reads the document.
    var document: runtime.Instance = undefined;
    try std.testing.expect(get(&document, .hovered) == null);
    try std.testing.expect(get(&document, .pointed) == null);
    set(&document, .activated, null);
    try std.testing.expect(get(&document, .activated) == null);
}

test "set forwards to the installed implementation" {
    const saved = implementation;
    defer implementation = saved;
    const Record = struct {
        var last_state: ?State = null;
        var last_element: ?*runtime.Instance = null;
        fn get(_: *runtime.Instance, _: State) ?*runtime.Instance {
            return null;
        }
        fn set(_: *runtime.Instance, state: State, element: ?*runtime.Instance) void {
            last_state = state;
            last_element = element;
        }
    };
    implementation = .{ .get = &Record.get, .set = &Record.set };
    var document: runtime.Instance = undefined;
    set(&document, .pointed, null);
    try std.testing.expect(Record.last_state.? == .pointed);
    try std.testing.expect(Record.last_element == null);
    // A designation the Document has lost (a freed element) reads as none.
    try std.testing.expect(get(&document, .pointed) == null);
}
