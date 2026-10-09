//! HTML 4.10.18.3 "reset the form owner" and 4.10.19.5's disabled state for
//! form-associated custom elements, run only where a mutation can change
//! them (CE2-S1, tmp/analysis/fix-list.md).
//!
//! A form-associated custom element keeps its form owner and disabled state
//! (ElementInternals' refreshForm), because a change of either enqueues
//! formAssociatedCallback or formDisabledCallback. Before, once any
//! formAssociated definition existed, every children change, every removal
//! and every id, form or disabled attribute change walked - and allocated -
//! the whole tree to recompute both for every element in it: every parser
//! append was a walk of the document parsed so far. What can change an
//! element's owner or disabled state, and what is reset here:
//!
//! - its ancestor chain or its connectedness: the inserted, removed or
//!   moved node's shadow-including inclusive descendants (the HTML element
//!   insertion, removing and moving steps reset the form owner);
//! - the ID its `form` attribute names entering, leaving or changing in its
//!   tree ("When a listed form-associated element has a form attribute and
//!   the ID of any of the elements in the tree changes ... or an element with
//!   an ID is inserted into or removed from the Document, or its HTML element
//!   moving steps are run, then the user agent must reset the form owner"):
//!   the elements observing that ID (form_observers.zig, Blink's
//!   FormAttributeTargetObserver) - this also resets an element whose owner
//!   was a removed form it named;
//! - its own form or disabled attribute: that element;
//! - a fieldset's disabled attribute: that fieldset's descendants
//!   (Blink's HTMLFieldSetElement::DisabledAttributeChanged);
//! - which legend is a disabled fieldset's first legend child: a legend
//!   inserted into, removed from or moved out of a disabled fieldset resets
//!   that fieldset's descendants (Blink's HTMLFieldSetElement::ChildrenChanged).
//!
//! The owner is derived from the tree on every reset (form_associated.zig
//! formOwner), as built-in listed elements derive theirs on every read, so
//! the two agree after every mutation; the parser's form-element-pointer
//! association is the stated deviation of form_associated.zig for both.
//! No reset runs script: callbacks are enqueued, so no tree changes under a
//! walk.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const ce = dom.custom_elements;
const form_associated = @import("../form_associated.zig");
const driver = @import("driver.zig");

const Instance = runtime.Instance;
const NodeBase = dom.NodeBase;
const ELEMENT_NODE = NodeBase.ELEMENT_NODE;
const Observers = @FieldType(ce.AgentState, "form_id_observers");

/// The agent's state while any formAssociated definition exists: with none,
/// no element is form-associated and there is nothing to reset.
fn activeState(realm: runtime.Context) ?*ce.AgentState {
    const state = driver.stateForRealm(realm) orelse return null;
    if (state.form_definition_count == 0) return null;
    return state;
}

fn instanceOf(node: *NodeBase) ?*Instance {
    const object = dom.instance_bridge.getInstance(node) orelse return null;
    return @ptrCast(@alignCast(object));
}

/// `node` was inserted (`old_parent` null), removed (`new_parent` null) or
/// moved. The tree is already in its new shape.
pub fn subtreeMoved(node: *Instance, old_parent: ?*Instance, new_parent: ?*Instance) void {
    const state = activeState(node.ctx) orelse return;
    const base = dom.instance_bridge.getNodeBase(node) orelse return;
    resetShadowIncludingSubtree(base);
    if (state.form_id_observers.count() != 0) resetObserversOfIdsIn(state, base);
    if (base.node_type != ELEMENT_NODE) return;
    if (old_parent) |parent| resetIfLegendOfDisabledFieldset(node, parent);
    if (new_parent) |parent| if (parent != old_parent) resetIfLegendOfDisabledFieldset(node, parent);
}

/// An attribute in no namespace changed on `element`.
pub fn attributeChanged(element: *Instance, local_name: []const u8, old_value: ?[]const u8, new_value: ?[]const u8) void {
    const state = activeState(element.ctx) orelse return;
    if (std.mem.eql(u8, local_name, "id")) {
        if (state.form_id_observers.count() == 0) return;
        if (old_value) |value| resetObserversOf(state, value);
        if (new_value) |value| if (old_value == null or !std.mem.eql(u8, value, old_value.?)) resetObserversOf(state, value);
    } else if (std.mem.eql(u8, local_name, "form")) {
        ce.refreshForm(element);
    } else if (std.mem.eql(u8, local_name, "disabled")) {
        ce.refreshForm(element);
        if (form_associated.isElementNamed(element, "fieldset")) {
            const base = dom.instance_bridge.getNodeBase(element) orelse return;
            resetDescendants(base);
        }
    }
}

/// ElementInternals' refreshForm, after it reset `element`: observe the ID
/// its form attribute names, or stop observing.
pub fn observe(element: *Instance) void {
    const state = driver.stateForRealm(element.ctx) orelse return;
    const allocator = state.allocator;
    const value = form_associated.attributeValue(allocator, element, "form") catch null orelse {
        state.form_id_observers.remove(allocator, element);
        return;
    };
    defer allocator.free(value);
    // Its teardown must reach AgentState.cancelElement (Element.deinit
    // calls it for an element ever enqueued), which takes the entry out.
    ce.markEnqueued(element);
    state.form_id_observers.put(allocator, element, .{
        .realm = element.ctx,
        .generation = runtime.SlabAllocator.generationOf(element),
        .id_hash = Observers.hashId(value),
    }) catch {};
}

/// Reset every form-associated custom element among `root`'s
/// shadow-including inclusive descendants, in shadow-including tree order.
fn resetShadowIncludingSubtree(root: *NodeBase) void {
    var current: ?*NodeBase = root;
    while (current) |node| : (current = nextInSubtree(node, root)) {
        if (node.node_type != ELEMENT_NODE) continue;
        const element = instanceOf(node) orelse continue;
        ce.refreshForm(element);
        // The shadow root's tree before the host's children.
        const shadow = ce.shadowRootOf(element) orelse continue;
        const shadow_base = dom.instance_bridge.getNodeBase(shadow) orelse continue;
        var child = shadow_base.first_child;
        while (child) |c| : (child = c.next_sibling) resetShadowIncludingSubtree(c);
    }
}

/// Reset every form-associated custom element among `root`'s descendants:
/// a fieldset's, whose disabled state reaches into no shadow tree
/// (form_associated.isDisabled walks parents only).
fn resetDescendants(root: *NodeBase) void {
    var current = root.first_child;
    while (current) |node| : (current = nextInSubtree(node, root)) {
        if (node.node_type != ELEMENT_NODE) continue;
        ce.refreshForm(instanceOf(node) orelse continue);
    }
}

/// `node`, a child `parent` gained or lost, may be or have been its first
/// legend child: if `parent` is a disabled fieldset, that decides which of
/// its descendants are disabled. Cheapest test first: the attribute.
fn resetIfLegendOfDisabledFieldset(node: *Instance, parent: *Instance) void {
    if (!form_associated.isElement(parent)) return;
    if (!form_associated.hasAttribute(parent, "disabled")) return;
    if (!form_associated.isElementNamed(parent, "fieldset")) return;
    if (!form_associated.isElementNamed(node, "legend")) return;
    resetDescendants(dom.instance_bridge.getNodeBase(parent) orelse return);
}

/// Every element with an ID in `root`'s tree-order inclusive descendants
/// (not into shadow trees: an ID there is in another tree, whose observers
/// are in that tree and among the descendants already reset).
fn resetObserversOfIdsIn(state: *ce.AgentState, root: *NodeBase) void {
    var current: ?*NodeBase = root;
    while (current) |node| : (current = nextInSubtree(node, root)) {
        if (node.node_type != ELEMENT_NODE) continue;
        const element = instanceOf(node) orelse continue;
        var id = interfaces.Element.get_id(element) catch continue;
        defer id.deinit(element.ctx.allocator);
        if (id.asSlice().len == 0) continue;
        resetObserversOf(state, id.asSlice());
        if (state.form_id_observers.count() == 0) return;
    }
}

/// Reset the elements whose form attribute names `id` (or collides with it).
fn resetObserversOf(state: *ce.AgentState, id: []const u8) void {
    const found = state.form_id_observers.matching(Observers.hashId(id));
    if (found.len == 0) return;
    // A reset re-registers its element: work from a copy.
    var buffer: [16]*Instance = undefined;
    var heap: ?[]*Instance = null;
    defer if (heap) |list| state.allocator.free(list);
    const elements: []*Instance = if (found.len <= buffer.len) buffer[0..found.len] else blk: {
        heap = state.allocator.dupe(*Instance, found) catch return;
        break :blk heap.?;
    };
    if (heap == null) @memcpy(elements, found);
    for (elements) |element| {
        const entry = state.form_id_observers.get(element) orelse continue;
        // A dead element at a kept address, or a realm that ended: never
        // followed - dropped.
        if (runtime.SlabAllocator.generationOf(element) != entry.generation or
            runtime.instance_lifecycle.isCleanedUp(element) or
            (!entry.realm.hasEngine() and entry.realm.agent != null))
        {
            state.form_id_observers.remove(state.allocator, element);
            continue;
        }
        ce.refreshForm(element);
    }
}

/// The node after `node` in tree order within `root`'s subtree.
fn nextInSubtree(node: *NodeBase, root: *NodeBase) ?*NodeBase {
    if (node.first_child) |child| return child;
    var current = node;
    while (current != root) {
        if (current.next_sibling) |sibling| return sibling;
        current = current.parent_node orelse return null;
    }
    return null;
}
