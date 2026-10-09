//! DOM 4.2.2.3-4.2.2.5: finding slots and slottables, assigning them, and
//! signaling a slot change - and the steps of insert, remove, move and the
//! attribute change steps that run them.
//!
//! Spec: https://dom.spec.whatwg.org/#finding-slots-and-slotables
//!
//! Eager, as the standard writes it: every mutation that can change a slot's
//! assigned nodes recomputes them at once, so a slotchange is signaled at the
//! step the standard names. Blink and WebKit recompute lazily
//! (SlotAssignment::RecalcAssignment, NamedSlotAssignment::assignSlots) and
//! keep separate bookkeeping to signal slotchange at the same points; eager
//! needs none, and its cost is confined to trees with shadow roots:
//!
//! - A tree with no shadow root pays, per insertion or removal, a test of
//!   the parent's shadow host bit (NodeBase.is_shadow_host), a vtable
//!   comparison (is the parent a slot) and a walk to the parent's root
//!   (whose node type is a Document's, or no fragment that is a shadow root).
//! - "Assign slottables for a tree" (insert step 7.6, remove step 10) runs
//!   only when the tree is a shadow tree and the inserted or removed subtree
//!   holds a slot: a slot's assigned nodes depend only on the slots of its
//!   shadow tree and the children of its host, and a slot outside a shadow
//!   tree always has none (the remove steps empty it when it leaves). So in
//!   any other case every slot of the tree already has the assigned nodes it
//!   would get, and the run would change and signal nothing.
//!
//! Every reference between nodes is a weak `slot_helpers.NodeRef`; see that
//! file for why none of them can be read once its target is gone.
//!
//! The KEEP note this file used to carry (duck-typed `*anyopaque` helpers)
//! went with the code it described: the algorithms work on NodeBase and
//! reach slot state through the slot_helpers hook.

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const enums = @import("enums");

const NodeBase = @import("node_base.zig").NodeBase;
const slot_helpers = @import("slot_helpers.zig");
const NodeRef = slot_helpers.NodeRef;
const tree_helpers = @import("tree_helpers.zig");
const instance_bridge = @import("instance_bridge.zig");
const mutation_observer_algorithms = @import("mutation_observer_algorithms.zig");

const ELEMENT_NODE = NodeBase.ELEMENT_NODE;
const TEXT_NODE = NodeBase.TEXT_NODE;
const DOCUMENT_FRAGMENT_NODE = NodeBase.DOCUMENT_FRAGMENT_NODE;

pub const Error = error{OutOfMemory};

// ============================================================================
// Tree helpers
// ============================================================================

fn instanceOf(node: *NodeBase) ?*runtime.Instance {
    const opaque_instance = node.owner_instance orelse return null;
    return @ptrCast(@alignCast(opaque_instance));
}

fn nodeOf(instance: *runtime.Instance) ?*NodeBase {
    return instance_bridge.getNodeBase(instance);
}

/// DOM: a node's root - the topmost inclusive ancestor.
fn rootOf(node: *NodeBase) *NodeBase {
    var current = node;
    while (current.parent_node) |parent| current = parent;
    return current;
}

/// Whether `node` is a shadow root.
fn isShadowRoot(node: *NodeBase) bool {
    if (node.node_type != DOCUMENT_FRAGMENT_NODE) return false;
    const instance = instanceOf(node) orelse return false;
    return instance.vtable == &interfaces.ShadowRoot.vtable;
}

/// A shadow root's host, as a node; null when the host is gone (a host
/// freed before its shadow root, dom.shadow_hosts).
fn hostOf(shadow: *NodeBase) ?*NodeBase {
    const instance = instanceOf(shadow) orelse return null;
    const host = interfaces.ShadowRoot.get_host(instance) catch return null;
    return nodeOf(host);
}

fn isOpen(shadow: *NodeBase) bool {
    const instance = instanceOf(shadow) orelse return false;
    const mode = interfaces.ShadowRoot.get_mode(instance) catch return false;
    return mode == ._open_;
}

fn isManual(shadow: *NodeBase) bool {
    const instance = instanceOf(shadow) orelse return false;
    const assignment = interfaces.ShadowRoot.get_slotAssignment(instance) catch return false;
    return assignment == ._manual_;
}

/// The next node after `node` in tree order, staying inside `root`'s
/// inclusive descendants (never crossing into a shadow tree).
fn nextInTree(node: *NodeBase, root: *NodeBase) ?*NodeBase {
    if (node.first_child) |child| return child;
    var current = node;
    while (current != root) {
        if (current.next_sibling) |sibling| return sibling;
        current = current.parent_node orelse return null;
    }
    return null;
}

/// Whether `node` has an inclusive descendant that is a slot.
fn hasInclusiveDescendantSlot(node: *NodeBase) bool {
    var current: ?*NodeBase = node;
    while (current) |n| : (current = nextInTree(n, node)) {
        if (slot_helpers.isSlot(n)) return true;
    }
    return false;
}

/// The first slot in tree order among `shadow`'s descendants whose name is
/// `name`.
fn firstSlotNamed(shadow: *NodeBase, name: []const u8) ?*NodeBase {
    var current = nextInTree(shadow, shadow);
    while (current) |n| : (current = nextInTree(n, shadow)) {
        const state = slot_helpers.slotState(n) orelse continue;
        if (std.mem.eql(u8, state.name, name)) return n;
    }
    return null;
}

// ============================================================================
// 4.2.2.3 Finding slots and slottables
// ============================================================================

/// DOM "find a slot" for `slottable`, with `open`.
///
/// Spec: https://dom.spec.whatwg.org/#find-a-slot
pub fn findSlot(slottable: *NodeBase, open: bool) ?*NodeBase {
    // Step 1: "If slottable's parent is null, then return null."
    const parent = slottable.parent_node orelse return null;
    // Step 2: "Let shadow be slottable's parent's shadow root."
    // Step 3: "If shadow is null, then return null."
    const shadow = tree_helpers.shadowRootForHost(parent) orelse return null;
    // Step 4: "If open is true and shadow's mode is not "open", then return
    // null."
    if (open and !isOpen(shadow)) return null;
    const own = slot_helpers.slottable(slottable) orelse return null;
    // Step 5: "If shadow's slot assignment is "manual", then return the slot
    // in shadow's descendants whose manually assigned nodes contains
    // slottable, if any; otherwise null." A slottable is in the manually
    // assigned nodes of exactly the slot its manual slot assignment names
    // (HTML assign() keeps the two together), so that is the slot to test.
    if (isManual(shadow)) {
        const slot = own.state.manualSlotAssignment() orelse return null;
        if (rootOf(slot) != shadow) return null;
        const state = slot_helpers.slotState(slot) orelse return null;
        for (state.manually_assigned_nodes.items) |ref| {
            if (ref.is(slottable)) return slot;
        }
        return null;
    }
    // Step 6: "Return the first slot in tree order in shadow's descendants
    // whose name is slottable's name, if any; otherwise null."
    return firstSlotNamed(shadow, own.name);
}

/// DOM "find slottables" for `slot`, appended to `result`.
///
/// Spec: https://dom.spec.whatwg.org/#find-slotables
pub fn findSlottables(allocator: Allocator, slot: *NodeBase, result: *std.ArrayListUnmanaged(NodeRef)) Error!void {
    // Step 1: "Let result be « »." (The caller's list.)
    // Step 2: "Let root be slot's root."
    const root = rootOf(slot);
    // Step 3: "If root is not a shadow root, then return result."
    if (!isShadowRoot(root)) return;
    // Step 4: "Let host be root's host."
    const host = hostOf(root) orelse return;
    const state = slot_helpers.slotState(slot) orelse return;
    // Step 5: "If root's slot assignment is "manual"": "for each slottable
    // slottable of slot's manually assigned nodes, if slottable's parent is
    // host, append slottable to result."
    if (isManual(root)) {
        for (state.manually_assigned_nodes.items) |ref| {
            const node = ref.get() orelse continue;
            if (node.parent_node == host) try result.append(allocator, ref);
        }
        return;
    }
    // Step 6: "Otherwise, for each slottable child slottable of host, in tree
    // order": "let foundSlot be the result of finding a slot given
    // slottable" and "if foundSlot is slot, then append slottable to result".
    //
    // For a child of host, finding a slot (open false, named assignment)
    // returns the first slot in root named as the child is - so it returns
    // slot exactly when slot is the first slot with its own name and the
    // child's name is that name. Testing slot once, then each child's name,
    // is the same result without a tree walk per child.
    if (firstSlotNamed(root, state.name) != slot) return;
    var child = host.first_child;
    while (child) |c| : (child = c.next_sibling) {
        if (!slot_helpers.isSlottable(c)) continue;
        const slottable = slot_helpers.slottable(c) orelse continue;
        if (!std.mem.eql(u8, slottable.name, state.name)) continue;
        const ref = NodeRef.to(c) orelse continue;
        try result.append(allocator, ref);
    }
    // Step 7: "Return result."
}

/// DOM "find flattened slottables" for `slot`, appended to `result`.
///
/// Spec: https://dom.spec.whatwg.org/#find-flattened-slotables
pub fn findFlattenedSlottables(allocator: Allocator, slot: *NodeBase, result: *std.ArrayListUnmanaged(NodeRef)) Error!void {
    // Step 1: "Let result be « »." (The caller's list.)
    // Step 2: "If slot's root is not a shadow root, then return result."
    if (!isShadowRoot(rootOf(slot))) return;
    // Step 3: "Let slottables be the result of finding slottables given
    // slot."
    var slottables: std.ArrayListUnmanaged(NodeRef) = .empty;
    defer slottables.deinit(allocator);
    try findSlottables(allocator, slot, &slottables);
    // Step 4: "If slottables is the empty list, then append each slottable
    // child of slot, in tree order, to slottables."
    if (slottables.items.len == 0) {
        var child = slot.first_child;
        while (child) |c| : (child = c.next_sibling) {
            if (!slot_helpers.isSlottable(c)) continue;
            const ref = NodeRef.to(c) orelse continue;
            try slottables.append(allocator, ref);
        }
    }
    // Step 5: "For each node of slottables":
    for (slottables.items) |ref| {
        const node = ref.get() orelse continue;
        // Step 5.1: "If node is a slot whose root is a shadow root": append
        // each slottable of "the result of finding flattened slottables
        // given node", in order, to result.
        if (slot_helpers.isSlot(node) and isShadowRoot(rootOf(node))) {
            try findFlattenedSlottables(allocator, node, result);
            continue;
        }
        // Step 5.2: "Otherwise, append node to result."
        try result.append(allocator, ref);
    }
    // Step 6: "Return result."
}

// ============================================================================
// 4.2.2.4 Assigning slottables and slots
// ============================================================================

fn identical(a: []const NodeRef, b: []const NodeRef) bool {
    if (a.len != b.len) return false;
    for (a, b) |x, y| {
        if (!x.eql(y)) return false;
    }
    return true;
}

/// DOM "assign slottables" for `slot`.
///
/// Spec: https://dom.spec.whatwg.org/#assign-slotables
pub fn assignSlottables(allocator: Allocator, slot: *NodeBase) Error!void {
    const state = slot_helpers.slotState(slot) orelse return;
    // Step 1: "Let slottables be the result of finding slottables for slot."
    // A scratch list: most slots hold a handful of nodes.
    var scratch = std.heap.stackFallback(16 * @sizeOf(NodeRef), allocator);
    const scratch_allocator = scratch.get();
    var slottables: std.ArrayListUnmanaged(NodeRef) = .empty;
    defer slottables.deinit(scratch_allocator);
    try findSlottables(scratch_allocator, slot, &slottables);

    // Step 2: "If slottables and slot's assigned nodes are not identical,
    // then run signal a slot change for slot." Identical lists leave steps 3
    // and 4 nothing to change: each of those slottables already names slot.
    if (identical(slottables.items, state.assigned_nodes.items)) return;
    signalSlotChange(slot);

    // A slottable slot no longer finds stops being assigned to it. The
    // standard never resets an assigned slot - a removed node, or one whose
    // slot left its tree, keeps naming it, and "get the parent" would still
    // route its events through that slot - while every engine clears it:
    // Blink's RecalcAssignment clears the flat tree data of each host child
    // it does not slot (ClearFlatTreeNodeData), Gecko's
    // HTMLSlotElement::RemoveAssignedNode and WebKit's assignSlots reset it.
    // Clear the old ones that still name slot; step 4 sets the new ones, so a
    // slottable in both lists ends up assigned to slot again.
    const slot_ref = NodeRef.to(slot) orelse return;
    for (state.assigned_nodes.items) |ref| {
        const node = ref.get() orelse continue;
        const old = slot_helpers.slottable(node) orelse continue;
        const assigned = old.state.assigned_slot orelse continue;
        if (assigned.eql(slot_ref)) old.state.assigned_slot = null;
    }

    // Step 3: "Set slot's assigned nodes to slottables."
    try state.setAssignedNodes(slottables.items);

    // Step 4: "For each slottable of slottables: set slottable's assigned
    // slot to slot."
    for (state.assigned_nodes.items) |ref| {
        const node = ref.get() orelse continue;
        const slottable = slot_helpers.slottable(node) orelse continue;
        slottable.state.assigned_slot = slot_ref;
    }
}

/// DOM "assign slottables for a tree", given `root`: "run assign slottables
/// for each slot of root's inclusive descendants, in tree order".
///
/// Spec: https://dom.spec.whatwg.org/#assign-slotables-for-a-tree
pub fn assignSlottablesForTree(allocator: Allocator, root: *NodeBase) Error!void {
    var current: ?*NodeBase = root;
    while (current) |node| : (current = nextInTree(node, root)) {
        if (slot_helpers.isSlot(node)) try assignSlottables(allocator, node);
    }
}

/// "Assign slottables for a tree" with `root`, where only a shadow tree can
/// change anything: a slot outside one has no assigned nodes and finds no
/// slottables (see the file comment).
fn assignSlottablesForShadowTree(allocator: Allocator, root: *NodeBase) Error!void {
    if (!isShadowRoot(root)) return;
    try assignSlottablesForTree(allocator, root);
}

/// DOM "assign a slot", given `slottable`.
///
/// Spec: https://dom.spec.whatwg.org/#assign-a-slot
pub fn assignSlot(allocator: Allocator, slottable: *NodeBase) Error!void {
    // Step 1: "Let slot be the result of finding a slot with slottable."
    const slot = findSlot(slottable, false) orelse return;
    // Step 2: "If slot is non-null, then run assign slottables for slot."
    try assignSlottables(allocator, slot);
}

// ============================================================================
// 4.2.2.5 Signaling slot change
// ============================================================================

/// DOM "signal a slot change", for `slot`.
///
/// Spec: https://dom.spec.whatwg.org/#signal-a-slot-change
pub fn signalSlotChange(slot: *NodeBase) void {
    const instance = instanceOf(slot) orelse return;
    // Steps 1-2: the surrounding agent's signal slots and its mutation
    // observer microtask, which mutation_observer_algorithms owns.
    mutation_observer_algorithms.signalSlotChange(instance);
}

// ============================================================================
// The steps that run the algorithms
// ============================================================================

/// DOM insert steps 7.4-7.6 (and move steps 21-23, which are the same) for
/// `node`, just inserted into `parent`.
///
/// Spec: https://dom.spec.whatwg.org/#concept-node-insert
pub fn runInsertionSlotSteps(allocator: Allocator, node: *NodeBase, parent: *NodeBase) Error!void {
    // Step 7.4: "If parent is a shadow host whose shadow root's slot
    // assignment is "named" and node is a slottable, then assign a slot for
    // node."
    //
    // Stated deviation (golden rule 2): for a "manual" shadow root too. All
    // three engines re-assign a manually assigned node appended to its host:
    // Blink's SlotAssignment::RecalcAssignment slots each manually assigned
    // node whose parent is the host, on every host child change; Gecko's
    // ShadowRoot::MaybeSlotHostChild asks SlotInsertionPointFor, whose manual
    // branch returns the child's manual slot assignment when it is in this
    // shadow root; WebKit's ManualSlotAssignment::hostChildElementDidChange
    // invalidates effectiveAssignedNodes (the manually assigned nodes whose
    // parent is the host). wpt.fyi stable, 2026-10-06 aligned runs
    // (chrome 6218298311311360, firefox 4877098740350976, safari
    // 5164107446878208): shadow-dom/imperative-slot-api.html 16/16 in each,
    // whose "Moving c4 into place should reveal the assignment" appends a
    // manually assigned node to its host and reads the slot's assigned
    // nodes. "Find a slot" already answers a manual shadow root.
    if (parent.is_shadow_host and slot_helpers.isSlottable(node)) {
        if (tree_helpers.shadowRootForHost(parent) != null) try assignSlot(allocator, node);
    }

    // Steps 7.5 and 7.6 concern parent's root, which is node's root now, only
    // when it is a shadow root.
    const parent_is_slot = slot_helpers.isSlot(parent);
    const root = rootOf(parent);
    if (!isShadowRoot(root)) return;

    // Step 7.5: "If parent's root is a shadow root, and parent is a slot
    // whose assigned nodes is the empty list, then run signal a slot change
    // for parent."
    if (parent_is_slot) {
        if (slot_helpers.slotState(parent)) |state| {
            if (!state.hasAssignedNodes()) signalSlotChange(parent);
        }
    }

    // Step 7.6: "Run assign slottables for a tree with node's root." Only a
    // slot node brings can change an assignment here (file comment).
    if (hasInclusiveDescendantSlot(node)) try assignSlottablesForTree(allocator, root);
}

/// DOM remove steps 8-10 (and move steps 14-16, which are the same) for
/// `node`, just removed from `parent`.
///
/// Spec: https://dom.spec.whatwg.org/#concept-node-remove
pub fn runRemovingSlotSteps(allocator: Allocator, node: *NodeBase, parent: *NodeBase) Error!void {
    // Step 8: "If node is assigned, then run assign slottables for node's
    // assigned slot." A node is assigned only while it is a child of its
    // slot's shadow host (assign slottables unassigns it otherwise), so a
    // parent that is no host means a node that is not assigned.
    if (parent.is_shadow_host and slot_helpers.isSlottable(node)) {
        if (slot_helpers.slottable(node)) |slottable| {
            if (slottable.state.assignedSlot()) |slot| try assignSlottables(allocator, slot);
        }
    }

    // Steps 9 and 10 change nothing unless parent's root is a shadow root:
    // a slot outside a shadow tree, removed or left behind, has no assigned
    // nodes before or after (file comment).
    const parent_is_slot = slot_helpers.isSlot(parent);
    const root = rootOf(parent);
    if (!isShadowRoot(root)) return;

    // Step 9: "If parent's root is a shadow root, and parent is a slot whose
    // assigned nodes is the empty list, then run signal a slot change for
    // parent."
    if (parent_is_slot) {
        if (slot_helpers.slotState(parent)) |state| {
            if (!state.hasAssignedNodes()) signalSlotChange(parent);
        }
    }

    // Step 10: "If node has an inclusive descendant that is a slot":
    if (hasInclusiveDescendantSlot(node)) {
        // Step 10.1: "Run assign slottables for a tree with parent's root."
        try assignSlottablesForTree(allocator, root);
        // Step 10.2: "Run assign slottables for a tree with node."
        try assignSlottablesForTree(allocator, node);
    }
}

fn sameValue(old_value: ?[]const u8, value: ?[]const u8) bool {
    // "If value is oldValue, then return."
    if (old_value == null and value == null) return true;
    if (old_value != null and value != null and std.mem.eql(u8, old_value.?, value.?)) return true;
    // "If value is null and oldValue is the empty string, then return."
    if (value == null and old_value != null and old_value.?.len == 0) return true;
    // "If value is the empty string and oldValue is null, then return."
    if (value != null and value.?.len == 0 and old_value == null) return true;
    return false;
}

/// DOM 4.2.2.2, the attribute change steps that update a slottable's name:
/// `element`'s `slot` attribute (no namespace) changed from `old_value` to
/// `value`. Its name - Element's cache of the attribute - is already set
/// (steps 1.4-1.5).
///
/// Spec: https://dom.spec.whatwg.org/#slotable-name
pub fn slottableNameChanged(element: *runtime.Instance, old_value: ?[]const u8, value: ?[]const u8) void {
    // Steps 1.1-1.3: an unchanged name changes nothing.
    if (sameValue(old_value, value)) return;
    const node = nodeOf(element) orelse return;
    const allocator = element.ctx.allocator;
    if (slot_helpers.slottable(node)) |slottable| {
        // Step 1.6: "If element is assigned, then run assign slottables for
        // element's assigned slot."
        if (slottable.state.assignedSlot()) |slot| assignSlottables(allocator, slot) catch {};
    }
    // Step 1.7: "Run assign a slot for element."
    assignSlot(allocator, node) catch {};
}

/// DOM 4.2.2.1, the attribute change steps that update a slot's name:
/// `slot`'s `name` attribute (no namespace) changed from `old_value` to
/// `value`.
///
/// Spec: https://dom.spec.whatwg.org/#slot-name
pub fn slotNameChanged(slot: *runtime.Instance, old_value: ?[]const u8, value: ?[]const u8) void {
    // Steps 1.1-1.3: an unchanged name changes nothing.
    if (sameValue(old_value, value)) return;
    const node = nodeOf(slot) orelse return;
    const state = slot_helpers.slotState(node) orelse return;
    const allocator = slot.ctx.allocator;
    // Steps 1.4-1.5: "If value is null or the empty string, then set
    // element's name to the empty string. Otherwise, set element's name to
    // value." A failed copy leaves the name as it was.
    state.setName(value orelse "") catch return;
    // Step 1.6: "Run assign slottables for a tree with element's root."
    assignSlottablesForShadowTree(allocator, rootOf(node)) catch {};
}

// ============================================================================
// What the IDL members read
// ============================================================================

/// Slottable's `assignedSlot` getter: "return the result of find a slot
/// given this and true."
///
/// Spec: https://dom.spec.whatwg.org/#dom-slotable-assignedslot
pub fn assignedSlotForScript(slottable: *runtime.Instance) ?*runtime.Instance {
    const node = nodeOf(slottable) orelse return null;
    const slot = findSlot(node, true) orelse return null;
    return instanceOf(slot);
}

/// A node's assigned slot - internal, a closed shadow root's included - for
/// the event path's "get the parent".
///
/// Spec: https://dom.spec.whatwg.org/#get-the-parent
pub fn assignedSlotOf(node_instance: *runtime.Instance) ?*runtime.Instance {
    const node = nodeOf(node_instance) orelse return null;
    if (!slot_helpers.isSlottable(node)) return null;
    const slottable = slot_helpers.slottable(node) orelse return null;
    const slot = slottable.state.assignedSlot() orelse return null;
    return instanceOf(slot);
}

/// HTML `assignedNodes(options)` and `assignedElements(options)`: `slot`'s
/// assigned nodes, or its flattened slottables when `flatten`, limited to
/// elements when `elements_only`. The caller owns the returned slice.
///
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#dom-slot-assignednodes
pub fn assignedNodes(allocator: Allocator, slot: *runtime.Instance, flatten: bool, elements_only: bool) Error![]*runtime.Instance {
    var result: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    errdefer result.deinit(allocator);
    const node = nodeOf(slot) orelse return result.toOwnedSlice(allocator);
    var refs: std.ArrayListUnmanaged(NodeRef) = .empty;
    defer refs.deinit(allocator);
    if (flatten) {
        // Step 2: "Return the result of finding flattened slottables with
        // this."
        try findFlattenedSlottables(allocator, node, &refs);
    } else {
        // Step 1: "If options["flatten"] is false, then return this's
        // assigned nodes."
        const state = slot_helpers.slotState(node) orelse return result.toOwnedSlice(allocator);
        try refs.appendSlice(allocator, state.assigned_nodes.items);
    }
    for (refs.items) |ref| {
        const target = ref.get() orelse continue;
        // assignedElements: "filtered to contain only Element nodes".
        if (elements_only and target.node_type != ELEMENT_NODE) continue;
        try result.append(allocator, ref.instance);
    }
    return result.toOwnedSlice(allocator);
}

/// HTML `assign(...nodes)` for `slot`; `nodes` are Element or Text nodes
/// (the binding's conversion has checked).
///
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#dom-slot-assign
pub fn assign(allocator: Allocator, slot: *runtime.Instance, nodes: []const *runtime.Instance) Error!void {
    const slot_node = nodeOf(slot) orelse return;
    const state = slot_helpers.slotState(slot_node) orelse return;
    const slot_ref = NodeRef.to(slot_node) orelse return;

    // The slots whose manually assigned nodes step 3.1 changes, other than
    // this one: their shadow trees are reassigned too (below).
    var previous_slots: std.ArrayListUnmanaged(NodeRef) = .empty;
    defer previous_slots.deinit(allocator);

    // Step 2: "Let nodesSet be a new ordered set." Built before anything
    // changes, so that running out of memory changes nothing.
    var nodes_set: std.ArrayListUnmanaged(NodeRef) = .empty;
    defer nodes_set.deinit(allocator);
    for (nodes) |instance| {
        const node = nodeOf(instance) orelse continue;
        const ref = NodeRef.to(node) orelse continue;
        // Step 3.3: "Append node to nodesSet" - a set: the first one wins.
        const present = for (nodes_set.items) |existing| {
            if (existing.eql(ref)) break true;
        } else false;
        if (!present) try nodes_set.append(allocator, ref);
    }
    try previous_slots.ensureTotalCapacity(allocator, nodes_set.items.len);
    try state.manually_assigned_nodes.ensureTotalCapacity(state.allocator, nodes_set.items.len);

    const old_manual = try allocator.dupe(NodeRef, state.manually_assigned_nodes.items);
    defer allocator.free(old_manual);

    // Step 1: "For each node of this's manually assigned nodes, set node's
    // manual slot assignment to null."
    for (state.manually_assigned_nodes.items) |ref| {
        const node = ref.get() orelse continue;
        const slottable = slot_helpers.slottable(node) orelse continue;
        slottable.state.manual_slot_assignment = null;
    }

    // Step 3: "For each node of nodes":
    for (nodes_set.items) |ref| {
        const node = ref.get() orelse continue;
        const slottable = slot_helpers.slottable(node) orelse continue;
        // Step 3.1: "If node's manual slot assignment refers to a slot, then
        // remove node from that slot's manually assigned nodes."
        if (slottable.state.manualSlotAssignment()) |previous| {
            if (slot_helpers.slotState(previous)) |previous_state| {
                var i: usize = 0;
                while (i < previous_state.manually_assigned_nodes.items.len) {
                    if (previous_state.manually_assigned_nodes.items[i].eql(ref)) {
                        _ = previous_state.manually_assigned_nodes.orderedRemove(i);
                    } else i += 1;
                }
                if (NodeRef.to(previous)) |previous_ref| previous_slots.appendAssumeCapacity(previous_ref);
            }
        }
        // Step 3.2: "Set node's manual slot assignment to this."
        slottable.state.manual_slot_assignment = slot_ref;
    }

    // Step 4: "Set this's manually assigned nodes to nodesSet." (Its memory
    // was reserved before step 1.)
    state.manually_assigned_nodes.clearRetainingCapacity();
    state.manually_assigned_nodes.appendSliceAssumeCapacity(nodes_set.items);

    // Step 5: "Run assign slottables for a tree for this's root."
    const root = rootOf(slot_node);
    try assignSlottablesForShadowTree(allocator, root);

    // Stated deviations (golden rule 2), both from the cross-root case, which
    // shadow-dom/imperative-slot-api-cross-shadow-root.html checks - wpt.fyi
    // stable 2026-10-06 aligned runs: chrome 2/2 (6218298311311360),
    // firefox 2/2 (4877098740350976), safari 1/2 (5164107446878208):
    //
    // - A previous slot in another tree lost a node in step 3.1, and the
    //   standard reassigns only this's tree, leaving that slot's assigned
    //   nodes naming a node it no longer has. Blink's HTMLSlotElement::Assign
    //   signals each such previous slot (changed_slots) and recalculates its
    //   tree; Gecko's HTMLSlotElement::Assign signals it when the node was
    //   assigned to it (wasAssigned). Reassigning that tree does both: it
    //   signals exactly when the slot's assigned nodes change.
    for (previous_slots.items) |previous_ref| {
        const previous = previous_ref.get() orelse continue;
        const previous_root = rootOf(previous);
        if (previous_root == root) continue;
        try assignSlottablesForShadowTree(allocator, previous_root);
    }

    // - This slot is signaled whenever its manually assigned nodes changed
    //   while it is in a shadow tree, even if its assigned nodes did not (a
    //   node assigned while it is not a child of the host): Blink's Assign
    //   signals `this` when `updated` and it has a containing shadow root;
    //   Gecko's signals it for each node whose manual slot assignment becomes
    //   this. Signal slots is a set, so a slot step 5 signaled stays where it
    //   was.
    if (isShadowRoot(root) and !identical(old_manual, state.manually_assigned_nodes.items)) {
        signalSlotChange(slot_node);
    }
}
