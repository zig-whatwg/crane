//! DOM Mutation Algorithms (WHATWG DOM Standard §4.2.5)
//!
//! Spec: https://dom.spec.whatwg.org/#mutation-algorithms
//!
//! This module implements the complete set of mutation algorithms for DOM node trees.
//! All algorithms follow the WHATWG DOM specification precisely.
//!
//! ARCHITECTURE: This module operates on NodeBase - the single source of truth for
//! DOM tree structure. WebIDL impls delegate all tree operations here.

const std = @import("std");
const hook = @import("hook.zig");
const infra = @import("infra");
const runtime = @import("runtime");

// NodeBase is THE source of truth for DOM tree structure
const node_base = @import("node_base.zig");
const NodeBase = node_base.NodeBase;

// Node type constants from NodeBase
const ELEMENT_NODE = NodeBase.ELEMENT_NODE;
const ATTRIBUTE_NODE = NodeBase.ATTRIBUTE_NODE;
const TEXT_NODE = NodeBase.TEXT_NODE;
const CDATA_SECTION_NODE = NodeBase.CDATA_SECTION_NODE;
const PROCESSING_INSTRUCTION_NODE = NodeBase.PROCESSING_INSTRUCTION_NODE;
const COMMENT_NODE = NodeBase.COMMENT_NODE;
const DOCUMENT_NODE = NodeBase.DOCUMENT_NODE;
const DOCUMENT_TYPE_NODE = NodeBase.DOCUMENT_TYPE_NODE;
const DOCUMENT_FRAGMENT_NODE = NodeBase.DOCUMENT_FRAGMENT_NODE;

// Local DOM modules
const tree_helpers = @import("tree_helpers.zig");
const shadow_dom_algorithms = @import("shadow_dom_algorithms.zig");
const mutation_observer = @import("mutation_observer_algorithms.zig");
const document_internals = @import("document_internals.zig");
const element_with_base = @import("element_with_base.zig");
const attr_with_base = @import("attr_with_base.zig");
const instance_bridge = @import("instance_bridge.zig");
const refcount = @import("refcount.zig");
const wrapper_tracing = @import("wrapper_tracing.zig");
const engine = @import("engine");
const node_document = @import("node_document.zig");
const element_attributes = @import("element_attributes.zig");
const range_boundaries = @import("range_boundaries.zig");
const custom_elements = @import("custom_elements.zig");
const tree_ordered_map = @import("tree_ordered_map.zig");

// Interface types needed for mutation observer integration
const interfaces = @import("interfaces");
const NodeList = interfaces.NodeList;
const Node = interfaces.Node;
const Document = interfaces.Document;

/// DOM Exception types as defined in WebIDL
pub const DOMException = error{
    HierarchyRequestError,
    NotFoundError,
    NotSupportedError,
    OutOfMemory,
    IndexOutOfBounds,
};

/// Children Changed Steps Callback
/// Spec: https://dom.spec.whatwg.org/#concept-node-children-changed-ext
///
/// Specifications (like HTML) may define children changed steps for all or some nodes.
/// The algorithm is passed the parent node and is called from insert, remove, and replace data.
///
/// Example usage (to be implemented by HTML spec):
///   - Slot assignment algorithm (Shadow DOM)
///   - Form-associated element connections
///   - Custom element reactions
///
/// This is an extension point for specifications to hook into DOM mutations.
/// `moved`: a child left (for the old parent) or joined (for the new one) by
/// DOM "move" - `move`'s doc comment says why these steps run for it.
pub const ChildrenChange = enum { inserted, removed, replaced_data, moved };
pub const ChildrenChangedCallback = *const fn (parent: *NodeBase, change: ChildrenChange) void;

/// Global registry for children changed steps callbacks
/// This allows specifications (like HTML) to register their hooks.
/// Process-wide, written once at start-up (hook.zig); the capacity bounds
/// what start-up installs, with room to spare.
var children_changed_callbacks: hook.Hook(hook.List(ChildrenChangedCallback, max_callbacks)) = .init(.empty);

/// Room per registry: the most-registered (removing steps) has 22 owners.
const max_callbacks = 48;

/// Register a callback to be invoked when children change
/// This should be called during initialization by specifications that need to hook into mutations
pub fn registerChildrenChangedCallback(callback: ChildrenChangedCallback) error{OutOfMemory}!void {
    const callbacks = children_changed_callbacks.installing();
    // Once per function: a repeated install (a test that installs again) adds nothing.
    if (callbacks.contains(callback)) return;
    callbacks.append(callback);
}

/// Run the children changed steps for a parent node
/// Spec: https://dom.spec.whatwg.org/#concept-node-children-changed-ext
///
/// Called from:
/// - insert (step 9)
/// - remove (step 17)
/// - replace data in CharacterData (step 12)
pub fn runChildrenChangedSteps(parent: anytype, change: ChildrenChange) void {
    // Cast to *NodeBase for callbacks (all DOM types have Node fields duplicated)
    const parent_node: *NodeBase = @ptrCast(parent);

    // Call all registered callbacks
    for (children_changed_callbacks.read().slice()) |callback| {
        callback(parent_node, change);
    }

    // Note: If no callbacks are registered, this is a no-op
    // This is expected until HTML or other specifications register their hooks
}

/// Insertion Steps Callback
/// Spec: Specifications may define insertion steps for all or some nodes.
/// The algorithm is passed the inserted node.
///
/// Examples:
///   - HTML: iframe loading, form-associated element connections
///   - Custom elements: connectedCallback
pub const InsertionStepsCallback = *const fn (node: *NodeBase) void;

/// Removing Steps Callback
/// Spec: Specifications may define removing steps for all or some nodes.
/// The algorithm is passed the removed node and optionally the old parent.
///
/// Examples:
///   - HTML: iframe unloading, form-associated element disconnections
///   - Custom elements: disconnectedCallback
pub const RemovingStepsCallback = *const fn (node: *NodeBase, old_parent: ?*NodeBase) void;

/// Post-connection Steps Callback
/// Spec: The post-connection steps are run after a batch of nodes is inserted.
/// This allows JavaScript to run after all mutations are complete.
///
/// Examples:
///   - HTML: iframe loading after all tree mutations
///   - Custom elements: batch reactions after insertion
pub const PostConnectionStepsCallback = *const fn (node: *NodeBase) void;

/// Moving Steps Callback
/// Spec: Specifications may define moving steps for all or some nodes.
/// The algorithm is passed the moved node and optionally the old parent.
///
/// Examples:
///   - Custom elements: connectedMoveCallback
///   - HTML: element relocation handling
pub const MovingStepsCallback = *const fn (node: *NodeBase, old_parent: ?*NodeBase) void;

/// Global registry for insertion steps callbacks.
/// Process-wide, written once at start-up (hook.zig).
var insertion_steps_callbacks: hook.Hook(hook.List(InsertionStepsCallback, max_callbacks)) = .init(.empty);

/// Global registry for removing steps callbacks.
/// Process-wide, written once at start-up (hook.zig).
var removing_steps_callbacks: hook.Hook(hook.List(RemovingStepsCallback, max_callbacks)) = .init(.empty);

/// Global registry for post-connection steps callbacks.
/// Process-wide, written once at start-up (hook.zig).
var post_connection_steps_callbacks: hook.Hook(hook.List(PostConnectionStepsCallback, max_callbacks)) = .init(.empty);

/// Global registry for moving steps callbacks.
/// Process-wide, written once at start-up (hook.zig).
var moving_steps_callbacks: hook.Hook(hook.List(MovingStepsCallback, max_callbacks)) = .init(.empty);

/// A test's own copies of the five registries, which the callbacks the test
/// registers go into, until `restore()` takes them away again - so a test's
/// callback never stays registered for the process's later tests.
pub const RegistriesOverride = struct {
    children_changed: @TypeOf(children_changed_callbacks).Override,
    insertion: @TypeOf(insertion_steps_callbacks).Override,
    removing: @TypeOf(removing_steps_callbacks).Override,
    post_connection: @TypeOf(post_connection_steps_callbacks).Override,
    moving: @TypeOf(moving_steps_callbacks).Override,

    pub fn restore(self: RegistriesOverride) void {
        self.moving.restore();
        self.post_connection.restore();
        self.removing.restore();
        self.insertion.restore();
        self.children_changed.restore();
    }
};

pub fn overrideRegistriesForTest() RegistriesOverride {
    return .{
        .children_changed = children_changed_callbacks.overrideForTest(children_changed_callbacks.get()),
        .insertion = insertion_steps_callbacks.overrideForTest(insertion_steps_callbacks.get()),
        .removing = removing_steps_callbacks.overrideForTest(removing_steps_callbacks.get()),
        .post_connection = post_connection_steps_callbacks.overrideForTest(post_connection_steps_callbacks.get()),
        .moving = moving_steps_callbacks.overrideForTest(moving_steps_callbacks.get()),
    };
}

/// Register a callback for insertion steps
pub fn registerInsertionStepsCallback(callback: InsertionStepsCallback) error{OutOfMemory}!void {
    const callbacks = insertion_steps_callbacks.installing();
    // Once per function: a repeated install (a test that installs again) adds nothing.
    if (callbacks.contains(callback)) return;
    callbacks.append(callback);
}

/// Register a callback for removing steps
pub fn registerRemovingStepsCallback(callback: RemovingStepsCallback) error{OutOfMemory}!void {
    const callbacks = removing_steps_callbacks.installing();
    // Once per function: a repeated install (a test that installs again) adds nothing.
    if (callbacks.contains(callback)) return;
    callbacks.append(callback);
}

/// Register a callback for post-connection steps
pub fn registerPostConnectionStepsCallback(callback: PostConnectionStepsCallback) error{OutOfMemory}!void {
    const callbacks = post_connection_steps_callbacks.installing();
    // Once per function: a repeated install (a test that installs again) adds nothing.
    if (callbacks.contains(callback)) return;
    callbacks.append(callback);
}

/// Register a callback for moving steps
pub fn registerMovingStepsCallback(callback: MovingStepsCallback) error{OutOfMemory}!void {
    const callbacks = moving_steps_callbacks.installing();
    // Once per function: a repeated install (a test that installs again) adds nothing.
    if (callbacks.contains(callback)) return;
    callbacks.append(callback);
}

/// Run the insertion steps for a node
/// Called during the insert algorithm for each shadow-including descendant
fn runInsertionSteps(node: anytype) void {
    // Fast path: if no callbacks are registered, skip entirely
    const callbacks = insertion_steps_callbacks.read().slice();
    if (callbacks.len == 0) return;

    const node_ptr: *NodeBase = @ptrCast(node);
    for (callbacks) |callback| {
        callback(node_ptr);
    }
}

/// Check if there are any insertion steps callbacks registered
/// Used to skip expensive descendant traversal when no callbacks exist
pub fn hasInsertionStepsCallbacks() bool {
    return insertion_steps_callbacks.read().len > 0;
}

/// Run the removing steps for a node
/// Called during the remove algorithm
fn runRemovingSteps(node: anytype, old_parent: anytype) void {
    const node_ptr: *NodeBase = @ptrCast(node);
    // Handle optional or non-optional old_parent
    const old_parent_ptr: ?*NodeBase = if (@TypeOf(old_parent) == @TypeOf(null))
        null
    else if (@typeInfo(@TypeOf(old_parent)) == .optional)
        if (old_parent) |p| @ptrCast(p) else null
    else
        @ptrCast(old_parent);

    for (removing_steps_callbacks.read().slice()) |callback| {
        callback(node_ptr, old_parent_ptr);
    }
}

/// Run the post-connection steps for a node
/// Called after a batch of insertions complete
fn runPostConnectionSteps(node: anytype) void {
    // Fast path: if no callbacks are registered, skip entirely
    const callbacks = post_connection_steps_callbacks.read().slice();
    if (callbacks.len == 0) return;

    const node_ptr: *NodeBase = @ptrCast(node);
    for (callbacks) |callback| {
        callback(node_ptr);
    }
}

/// Check if there are any post-connection steps callbacks registered
/// Used to skip expensive descendant traversal when no callbacks exist
pub fn hasPostConnectionStepsCallbacks() bool {
    return post_connection_steps_callbacks.read().len > 0;
}

/// Run insertion steps for a node and all its light descendants, in tree
/// order - the fallback when the shadow-including list cannot be allocated.
/// A loop over the links, no frame per level (lane crash1 batch 3).
fn runInsertionStepsRecursive(node: anytype) void {
    const root: *NodeBase = @ptrCast(node);
    var at: ?*NodeBase = root;
    while (at) |current| : (at = nextLightInTree(current, root)) runInsertionSteps(current);
}

/// The node after `node` in `root`'s light subtree, in tree order.
fn nextLightInTree(node: *NodeBase, root: *NodeBase) ?*NodeBase {
    if (node.first_child) |child| return child;
    var current = node;
    while (current != root) {
        if (current.next_sibling) |sibling| return sibling;
        current = current.parent_node orelse return null;
    }
    return null;
}

/// DOM insert steps 10–12: snapshot the whole batch before a step can run
/// script. A callback can remove nodes, retire a realm, and reuse slab slots.
fn runPostConnectionStepsForTrees(allocator: std.mem.Allocator, roots: []const *NodeBase) !void {
    // Step 11 runs a node's post-connection steps "if node is connected". The
    // batch's nodes were just inserted under one parent, so each is
    // connected exactly when its root is (the flag is exact), and none can
    // become connected before some step has run script. A batch whose roots
    // are not connected has nothing to run, and its subtrees are not
    // collected: a deep detached subtree moved between detached parents
    // (Range's subfragments) was walked here on every move, its steps all
    // skipped (lane crash1 batch 3).
    for (roots) |root| {
        if (root.is_connected) break;
    } else return;
    const Entry = struct {
        node: *NodeBase,
        instance: ?*runtime.Instance,
        generation: u64,
    };
    var entries = infra.List(Entry).init(allocator);
    defer entries.deinit();
    for (roots) |root| {
        var descendants = try tree_helpers.getShadowIncludingInclusiveDescendants(allocator, root);
        defer descendants.deinit();
        for (descendants.toSlice()) |node| {
            const instance: ?*runtime.Instance = if (instance_bridge.getInstance(node)) |object| @ptrCast(@alignCast(object)) else null;
            try entries.append(.{
                .node = node,
                .instance = instance,
                .generation = if (instance) |object| runtime.SlabAllocator.generationOf(object) else 0,
            });
        }
    }
    for (entries.toSlice()) |entry| {
        if (entry.instance) |object| {
            if (runtime.SlabAllocator.generationOf(object) != entry.generation) continue;
        }
        // Native parser nodes have no script-visible Instance to retire.
        // For registered nodes, validate the generation BEFORE reading NodeBase.
        if (entry.node.is_connected or entry.node.node_type == DOCUMENT_NODE) {
            runPostConnectionSteps(entry.node);
        }
    }
}

/// Allocation-free fallback for remove step 14, in the same shadow-including
/// tree order as the collected list. Every callback receives the original
/// ancestor that the subtree was removed from, including shadow descendants.
/// The walk is a loop (tree_helpers.ShadowIncludingWalk), no frame per level
/// (lane crash1 batch 3); its next node is read before a node's steps run,
/// as the recursion read a node's children after them - a fallback for when
/// no list can be allocated, whose steps run no script.
fn runRemovingStepsForDescendants(node: anytype, old_parent: anytype, parent_connected: bool) void {
    var walk = tree_helpers.ShadowIncludingWalk.init(@ptrCast(node));
    _ = walk.next(); // `node` itself: its own steps ran
    while (walk.next()) |descendant| {
        runRemovingSteps(descendant, old_parent);
        if (parent_connected) enqueueCustomElementCallback(descendant, .disconnected, .none);
    }
}

/// Set the is_connected flag of a node and all its shadow-including
/// descendants - connectedness follows the shadow-including root, so a host
/// changes its shadow trees too. Called during insert (connected=true) and
/// remove (connected=false). A loop over the links
/// (tree_helpers.ShadowIncludingWalk), no frame per level: a deep tree moved
/// into or out of a document overflowed the stack here (lane crash1 batch 3).
fn setConnectedRecursive(node: anytype, connected: bool) void {
    var walk = tree_helpers.ShadowIncludingWalk.init(@ptrCast(node));
    while (walk.next()) |descendant| descendant.is_connected = connected;
}

/// DOM "remove" step 15: "For each inclusive ancestor inclusiveAncestor of
/// parent, and then for each registered of inclusiveAncestor's registered
/// observer list, if
/// registered's options["subtree"] is true, then append a new transient
/// registered observer whose observer is registered's observer, options is
/// registered's options, and source is registered to node's registered
/// observer list."
///
/// Only `node` gets one: "queue a mutation record" walks the inclusive
/// ancestors of its target, so a transient observer on the removed subtree's
/// root sees every mutation inside it. The observer is told, so that notify
/// step 6.3 can take the transient observers off again.
/// Spec: https://dom.spec.whatwg.org/#concept-node-remove
fn createTransientObserversForRemovedNode(node: anytype, parent: anytype) !void {
    const removed: *NodeBase = @ptrCast(node);
    const removed_instance: ?*runtime.Instance = if (instance_bridge.getInstance(removed)) |opaque_ptr|
        @ptrCast(@alignCast(opaque_ptr))
    else
        null;
    var current_ancestor: ?*NodeBase = @ptrCast(parent);
    var visited: usize = 0;
    while (current_ancestor) |ancestor| : (current_ancestor = ancestor.parent_node) {
        // A deep parent: no observer made in the agent means none registered
        // on the rest of the ancestry (mutation_observer.anyObserverMade,
        // as hasInterestedObservers asks it; Blink's and WebKit's
        // hasMutationObserversOfType) - lane crash1 batch 3.
        visited += 1;
        if (visited == mutation_observer.walk_before_asking and !mutation_observer.anyObserverMade(removed)) return;
        // Appending below never touches this list: node is not an ancestor
        // of its old parent.
        var entries = ancestor.registeredObservers();
        while (entries.next()) |registered| {
            if (!registered.options.subtree) continue;
            _ = try removed.appendRegisteredObserver(.{
                .observer = registered.observer,
                .observer_generation = registered.observer_generation,
                .options = registered.options,
                .transient_source = ancestor,
            });
            const observer_opaque = @import("handles.zig").mutationObserverToAnyopaque(registered.observer) orelse continue;
            const observer: *runtime.Instance = @ptrCast(@alignCast(observer_opaque));
            if (removed_instance) |instance| {
                @import("observer_registrations.zig").transientAdded(observer, registered.observer_generation, instance);
            }
        }
    }
}

/// Helper to get node type from any node-like type
fn getNodeType(node: anytype) u16 {
    return node.node_type;
}

/// Helper to check if node is a Document
fn isDocument(node: anytype) bool {
    return getNodeType(node) == DOCUMENT_NODE;
}

/// Helper to check if node is a DocumentFragment
fn isDocumentFragment(node: anytype) bool {
    return getNodeType(node) == DOCUMENT_FRAGMENT_NODE;
}

/// Helper to check if node is an Element
fn isElement(node: anytype) bool {
    return getNodeType(node) == ELEMENT_NODE;
}

/// Helper to check if node is a DocumentType
fn isDocumentType(node: anytype) bool {
    return getNodeType(node) == DOCUMENT_TYPE_NODE;
}

/// Helper to check if node is a Text node
fn isText(node: anytype) bool {
    // DOM's "Text" interface includes CDATASection in all mutation checks.
    const kind = getNodeType(node);
    return kind == TEXT_NODE or kind == CDATA_SECTION_NODE;
}

/// Queue a tree mutation record for MutationObserver notifications
///
/// This function bridges the NodeBase-based mutation algorithms with the
/// WebIDL MutationObserver system: the target and siblings as platform
/// objects, and the added and removed nodes as they are - each record holds
/// them itself and makes its NodeLists only when script reads one
/// (MutationRecord.create; lane nodeholds). Two NodeLists used to be built
/// here per mutation, shared by every observer's record and never freed
/// unless script read them.
///
/// Spec: https://dom.spec.whatwg.org/#queue-a-tree-mutation-record
///
/// @param allocator - Allocator for the record's scratch
/// @param target - The parent node that was mutated (NodeBase)
/// @param added_nodes - Array of NodeBase pointers that were added
/// @param removed_nodes - Array of NodeBase pointers that were removed
/// @param previous_sibling - The sibling before the mutation (or null)
/// @param next_sibling - The sibling after the mutation (or null)
fn queueTreeMutationRecord(
    allocator: std.mem.Allocator,
    target: anytype,
    added_nodes: []const *NodeBase,
    removed_nodes: []const *NodeBase,
    previous_sibling: ?*NodeBase,
    next_sibling: ?*NodeBase,
) void {
    // Early return if both arrays are empty (spec step 1 assertion would fail)
    if (added_nodes.len == 0 and removed_nodes.len == 0) return;

    // Get the target as a runtime.Instance via the instance bridge
    const target_nodebase: *NodeBase = @ptrCast(target);

    // Nothing is built unless an observer wants the record.
    if (!mutation_observer.hasInterestedObservers(target_nodebase, .child_list, null, null)) return;
    const target_instance_ptr = instance_bridge.getInstance(target_nodebase) orelse {
        // Target is not a registered runtime.Instance - cannot queue mutation record
        // This can happen for nodes created purely through NodeBase (e.g., during parsing)
        return;
    };
    const target_instance: *runtime.Instance = @ptrCast(@alignCast(target_instance_ptr));

    // Convert previous_sibling and next_sibling to runtime.Instance
    const prev_instance: ?*runtime.Instance = if (previous_sibling) |prev| blk: {
        const prev_inst_ptr = instance_bridge.getInstance(prev) orelse break :blk null;
        break :blk @ptrCast(@alignCast(prev_inst_ptr));
    } else null;

    const next_instance: ?*runtime.Instance = if (next_sibling) |next| blk: {
        const next_inst_ptr = instance_bridge.getInstance(next) orelse break :blk null;
        break :blk @ptrCast(@alignCast(next_inst_ptr));
    } else null;

    // Call the mutation observer algorithm. A record that cannot be made is
    // skipped, as before.
    mutation_observer.queueTreeMutationRecord(
        allocator,
        target_instance,
        added_nodes,
        removed_nodes,
        prev_instance,
        next_instance,
    ) catch {};
}

/// Helper to check if node is a CharacterData node
fn isCharacterData(node: anytype) bool {
    const node_type = getNodeType(node);
    return node_type == TEXT_NODE or
        node_type == COMMENT_NODE or
        node_type == CDATA_SECTION_NODE or
        node_type == PROCESSING_INSTRUCTION_NODE;
}

/// DOM 4.2.1: the index of `child` in its parent - its number of preceding
/// siblings (a walk: NodeBase.index) - or null when it has no parent.
fn getChildIndex(child: anytype) ?usize {
    if (child.parent_node == null) return null;
    const child_node: *const NodeBase = @ptrCast(child);
    return child_node.index();
}

/// Whether `doc` has live ranges: an index is counted for them only
/// (DOM insert step 5, remove steps 4-7), as Blink does.
fn hasLiveRanges(doc: anytype) bool {
    const doc_instance: *runtime.Instance = @ptrCast(@alignCast(doc));
    const ranges = document_internals.liveRanges(doc_instance) orelse return false;
    return !ranges.isEmpty();
}

/// Check if a doctype is following a given child in parent
fn isDoctypeFollowing(parent: *NodeBase, child: ?*NodeBase) bool {
    const c = child orelse return false;
    if (c.parent_node != parent) return false;

    // Check all siblings after child
    var sibling = c.next_sibling;
    while (sibling) |s| : (sibling = s.next_sibling) {
        if (isDocumentType(s)) return true;
    }

    return false;
}

/// Check if an element is preceding a given child in parent
fn isElementPreceding(parent: *NodeBase, child: ?*NodeBase) bool {
    if (child == null) {
        // If child is null, check if parent has any element children
        var children = parent.children();
        while (children.next()) |node| {
            if (isElement(node)) return true;
        }
        return false;
    }

    if (child.?.parent_node != parent) return false;

    // Check all siblings before child
    var sibling = child.?.previousSibling();
    while (sibling) |s| : (sibling = s.previousSibling()) {
        if (isElement(s)) return true;
    }

    return false;
}

/// Count element children of a node
fn countElementChildren(node: anytype) usize {
    var count: usize = 0;
    var children = node.children();
    while (children.next()) |child| {
        if (isElement(child)) count += 1;
    }
    return count;
}

/// Check if node has a Text child
fn hasTextChild(node: anytype) bool {
    var children = node.children();
    while (children.next()) |child| {
        if (isText(child)) return true;
    }
    return false;
}

/// Check if parent has a doctype child
fn hasDoctypeChild(parent: anytype) bool {
    var children = parent.children();
    while (children.next()) |child| {
        if (isDocumentType(child)) return true;
    }
    return false;
}

/// Check if parent has an element child (optionally excluding one node)
fn hasElementChild(parent: *NodeBase, exclude: ?*NodeBase) bool {
    var children = parent.children();
    while (children.next()) |child| {
        if (exclude) |ex| {
            if (child == ex) continue;
        }
        if (isElement(child)) return true;
    }
    return false;
}

/// DOM §4.2.5 - Ensure pre-insertion validity
/// Spec: https://dom.spec.whatwg.org/#concept-node-ensure-pre-insertion-validity
///
/// Steps:
/// 1. If parent is not a Document, DocumentFragment, or Element node, throw HierarchyRequestError
/// 2. If node is a host-including inclusive ancestor of parent, throw HierarchyRequestError
/// 3. If child is non-null and its parent is not parent, throw NotFoundError
/// 4. If node is not a DocumentFragment, DocumentType, Element, or CharacterData node, throw HierarchyRequestError
/// 5. If either node is a Text node and parent is a document, or node is a doctype and parent is not a document, throw HierarchyRequestError
/// 6. If parent is a document, perform additional validation based on node type
pub fn ensurePreInsertValidity(
    node: anytype,
    parent: anytype,
    child: anytype,
) DOMException!void {
    return ensurePreInsertValidityExcluding(node, parent, child, .none);
}

/// replaceChildren step 2 excludes the children that step 3 will remove.
/// Rule 2: newer spec, browsers lagging (whatwg/dom ea2a74edc2 / #1487,
/// WPT #61154, with Gecko/WebKit implementer interest).
pub fn ensureReplaceChildrenValidity(node: anytype, parent: anytype) DOMException!void {
    return ensurePreInsertValidityExcluding(node, parent, @as(?*NodeBase, null), .parent_children);
}

const ExcludedChildren = enum { none, parent_children };

/// A comptime choice: ordinary pre-insert retains its existing checks and
/// pays no runtime cost for replaceChildren's excluded list.
fn ensurePreInsertValidityExcluding(node: anytype, parent: anytype, child: anytype, comptime excluded: ExcludedChildren) DOMException!void {
    // Step 1: Check parent is Document, DocumentFragment, or Element
    if (!isDocument(parent) and !isDocumentFragment(parent) and !isElement(parent)) {
        return error.HierarchyRequestError;
    }

    // Step 2: Check node is not host-including inclusive ancestor of parent
    if (isHostIncludingInclusiveAncestor(node, parent)) {
        return error.HierarchyRequestError;
    }

    // Step 3: If child is non-null, check child's parent is parent
    if (child) |c| {
        if (c.parent_node != parent) {
            return error.NotFoundError;
        }
    }

    // Step 4: Check node is valid type
    if (!isDocumentFragment(node) and !isDocumentType(node) and
        !isElement(node) and !isCharacterData(node))
    {
        return error.HierarchyRequestError;
    }

    // Steps 5-7: doctype only under Document; Text (including CDATA) never under it.
    if (isText(node) and isDocument(parent)) {
        return error.HierarchyRequestError;
    }
    if (isDocumentType(node) and !isDocument(parent)) {
        return error.HierarchyRequestError;
    }

    // Steps 8-11: Document-specific checks.
    if (isDocument(parent)) {
        if (isDocumentFragment(node)) {
            // Step 8: validate the fragment itself; its own children are not excluded.
            const element_count = countElementChildren(node);

            if (element_count > 1 or hasTextChild(node)) {
                return error.HierarchyRequestError;
            }

            if (element_count == 1) {
                if ((excluded == .none and hasElementChild(parent, null)) or
                    isDoctypeFollowing(parent, child) or
                    (excluded == .none and child != null and isDocumentType(child.?)))
                {
                    return error.HierarchyRequestError;
                }
            }
        } else if (isElement(node)) {
            // Step 9: no other element or following doctype.
            if ((excluded == .none and hasElementChild(parent, null)) or
                isDoctypeFollowing(parent, child) or
                (excluded == .none and child != null and isDocumentType(child.?)))
            {
                return error.HierarchyRequestError;
            }
        } else if (isDocumentType(node)) {
            // Steps 10-11: no other doctype or preceding element.
            if ((excluded == .none and hasDoctypeChild(parent)) or
                (excluded == .none and isElementPreceding(parent, child)) or
                (excluded == .none and child == null and hasElementChild(parent, null)))
            {
                return error.HierarchyRequestError;
            }
        }
    }
}

/// DOM §4.2.5 - Pre-insert
/// Spec: https://dom.spec.whatwg.org/#concept-node-pre-insert
///
/// Steps:
/// 1. Ensure pre-insertion validity of node into parent before child
/// 2. Let referenceChild be child
/// 3. If referenceChild is node, then set referenceChild to node's next sibling
/// 4. Insert node into parent before referenceChild
/// 5. Return node
pub fn preInsert(
    node: anytype,
    parent: anytype,
    child: anytype,
) DOMException!@TypeOf(node) {
    // Step 1: Ensure pre-insertion validity
    try ensurePreInsertValidity(node, parent, child);

    // Step 2: Let referenceChild be child
    // Step 3: If referenceChild is node, set to node's next sibling
    const referenceChild = if (child != null and child.? == node) node.next_sibling else child;

    // Step 4: Insert node into parent before referenceChild
    try insert(node, parent, referenceChild, false);

    // Step 5: Return node
    return node;
}

/// DOM §4.2.5 - Insert
/// Spec: https://dom.spec.whatwg.org/#concept-node-insert
///
/// This is the core insertion algorithm. It handles:
/// - DocumentFragment unwrapping
/// - Live range updates
/// - Node adoption
/// - Shadow DOM slot assignment
/// - Insertion steps callbacks
/// - Mutation observer notifications
///
/// This function declares step 1's stack buffer and nothing else. ReleaseSafe
/// writes 0xAA over an `undefined` buffer where it is declared: 2 KB on every
/// insert, 1.7% of dom.insert-remove and 2.0% of dom.inner-html-set (lane perf2,
/// batch 3, MEASURED). Runtime safety is off for this declaration only - the
/// user's approval, 2026-11-06 18:04 UTC ("ok to turn off ReleaseSafe's safety
/// around the buffer"): insertWith, which runs the algorithm on the buffer,
/// keeps every check (@setRuntimeSafety is lexically scoped, so a callee keeps
/// its own, inlined or not).
pub fn insert(
    node: anytype,
    parent: anytype,
    child: anytype,
    suppress_observers: bool,
) DOMException!void {
    @setRuntimeSafety(false);
    var nodes_buf: [256]*NodeBase = undefined;
    return insertWith(&nodes_buf, node, parent, child, suppress_observers);
}

fn insertWith(
    nodes_buf: *[256]*NodeBase,
    node: anytype,
    parent: anytype,
    child: anytype,
    suppress_observers: bool,
) DOMException!void {
    // Step 1: Let nodes be node's children if node is DocumentFragment, otherwise « node »
    //
    // A COPY, read off the fragment's links before step 4.1 takes its
    // children out (it was once a slice into a child list step 4.1 shrank:
    // `el.append("A","B","C","D","E")` read freed memory). The copy goes to
    // `nodes_buf` (insert's) or, past 256, to the heap.
    var nodes_heap: ?[]*NodeBase = null;
    defer if (nodes_heap) |heap| parent.allocator().free(heap);
    var nodes: []*NodeBase = undefined;
    var nodes_count: usize = 0;

    if (isDocumentFragment(node)) {
        nodes = copyChildren(parent.allocator(), node, nodes_buf) catch return error.OutOfMemory;
        nodes_count = nodes.len;
        if (nodes_count > nodes_buf.len) nodes_heap = nodes;
    } else {
        nodes_buf[0] = node;
        nodes = nodes_buf[0..1];
        nodes_count = 1;
    }

    // Step 2: Let count be nodes's size
    const count = nodes_count;

    // Step 3: If count is 0, then return
    if (count == 0) return;

    // Every node moved here is held from its removal to its link (refcount
    // step 7's prerequisite (b); WebKit's insertBefore holds the NodeVector
    // of Ref<Node> collectChildrenAndRemoveFromOldParent returned): each
    // removal below keeps its remover's hold, and the node's link in step
    // 7.3 ends it. A node an error leaves unlinked ends it here.
    var linked: usize = 0;
    errdefer for (nodes[linked..nodes_count]) |n| {
        // A fragment's child step 4.1 took out and no step 7.3 linked is out
        // of every tree now: recorded as a possible orphan here, while its
        // remover's hold still stands, as its removal would have recorded
        // it (a child step 4.1 never reached still has its parent, and is
        // not).
        if (isDocumentFragment(node)) orphanRemoved(n);
        refcount.endRemovalHold(n);
    };

    // Step 4: If node is a DocumentFragment node:
    if (isDocumentFragment(node)) {
        // Step 4.1: Remove its children with suppress observers flag set.
        // Moves, not removals: each child is linked into `parent` in step
        // 7.3, so none is recorded as a possible orphan (removeHeldMoving).
        // Nothing can reach one in between: the record is only ever made
        // for a node no wrapper reaches, the fragment no longer lists it,
        // and its remover's hold keeps it until its link or the errdefer
        // above.
        for (nodes[0..nodes_count]) |child_node| {
            try removeHeldMoving(child_node, true);
        }

        // Step 4.2: Queue a tree mutation record for node
        // addedNodes is empty, removedNodes is the children that were removed
        queueTreeMutationRecord(
            parent.allocator(),
            node,
            &[_]*NodeBase{},
            nodes[0..nodes_count],
            null,
            null,
        );
    }

    // Step 5: If child is non-null, update live ranges: for each live range
    // whose start/end node is parent and offset > child's index, increase
    // the offset by count. The index is counted only when there are any.
    if (child) |c| {
        if (nodeDocument(parent)) |doc| {
            if (hasLiveRanges(doc)) updateRangesForInsertionWithCount(doc, parent, getChildIndex(c) orelse 0, count);
        }
    }

    // Step 6: Let previousSibling be child's previous sibling or parent's last child if child is null
    const previousSibling: ?*NodeBase = if (child) |c| c.previousSibling() else parent.lastChild();

    // Step 7: For each node in nodes, in tree order:
    for (nodes[0..count]) |n| {
        // Step 7.1: "Adopt node into parent's node document." A document is
        // its own node document.
        //
        // Adopting is ALSO what takes node out of its old parent (adopt step
        // 2), so it can never be skipped. It used to be, whenever the
        // parent's NodeBase had no owner document - true of every node made
        // through the DOM API that had not yet been inside a document, a
        // DocumentFragment above all - and the node was then linked into its
        // new parent while its old parent still listed it: the old parent's
        // first child became the moved node and the rest of its children
        // fell off the list. Emptying an element into a fragment one child
        // at a time (jQuery's append) never terminated.
        const parent_base: *NodeBase = @ptrCast(parent);
        if (parent_base.getNodeDocument()) |doc| {
            try adoptHeld(n, doc);
        } else if (n.parent_node != null) {
            // No document to adopt into: still honour adopt's step 2.
            try removeHeld(n, false);
        }

        // Step 7.2-3: Insert node into parent's children: the links are the
        // children (NodeBase.children), so this cannot fail.

        // Before child, or after the last child.
        parent.linkChildBefore(n, child);

        // The parent write, and the holds it moves (refcount, step 3) - its
        // remover's hold ends here; a wrapped root joins its new tree's
        // opaque root (step 4).
        refcount.linkChild(n, @ptrCast(parent));
        linked += 1;
        joinedTree(n, @ptrCast(parent));
        // domindex1: the light subtree joins its new tree scope's ID and
        // named-property maps at the link, before any insertion step, slot
        // step or form owner reset can read them (Blink and WebKit update
        // theirs in InsertedInto).
        tree_ordered_map.inserted(n, @ptrCast(parent));

        // Update is_connected for the inserted node and all its descendants.
        // A node is connected if its shadow-including root is a Document:
        // the parent is a Document, or its flag says so - exact in shadow
        // trees too, which take their host's when attached
        // (dom.shadow_hosts.attached), so no walk to the root (Blink and
        // WebKit read their isConnected flag).
        const parent_is_connected = parent.is_connected or
            parent.node_type == DOCUMENT_NODE;
        if (parent_is_connected) {
            setConnectedRecursive(n, true);
        }

        // Steps 7.4-7.6: assign a slot for node if parent is a shadow host,
        // signal a slot change for an empty slot parent in a shadow tree,
        // and assign slottables for node's tree when it is a shadow tree
        // that node brings a slot into.
        insertionSlotSteps(parent.allocator(), n, @ptrCast(parent));

        // Step 7.7: For each shadow-including inclusive descendant of node,
        // in shadow-including tree order, run the insertion steps
        // Spec: DOM §4.2.5 step 7.7
        // Note: We process only the current node `n`, not all nodes (that would be O(n²))
        //
        // OPTIMIZATION: Skip expensive descendant traversal if no callbacks registered.
        // During HTML parsing, there are typically no insertion steps callbacks,
        // so this saves significant overhead for large documents.
        if (hasInsertionStepsCallbacks() or (parent_is_connected and hasCustomElementDefinitions(parent))) {
            // Get all shadow-including inclusive descendants in tree order
            var descendants = tree_helpers.getShadowIncludingInclusiveDescendants(
                parent.allocator(),
                n,
            ) catch {
                // If we can't allocate, fall back to non-shadow traversal
                runInsertionSteps(n);
                var descendants_left = n.children();
                while (descendants_left.next()) |descendant| {
                    runInsertionStepsRecursive(descendant);
                }
                continue;
            };
            defer descendants.deinit();

            // Run insertion steps for each shadow-including inclusive descendant
            for (descendants.toSlice()) |inclusive_descendant| {
                runInsertionSteps(inclusive_descendant);

                // Steps 7.7.2–7.7.4: only connected elements receive a
                // connected reaction or a try-to-upgrade reaction.
                runCustomElementInsertionSteps(inclusive_descendant);
            }
        }

        // TODO: Step 10-12 - Post-connection steps
        // Collect all nodes in staticNodeList before calling post-connection steps
    }

    // Step 8: If suppress observers flag is unset, queue a tree mutation record
    if (!suppress_observers) {
        queueTreeMutationRecord(
            parent.allocator(),
            parent,
            nodes[0..nodes_count],
            &[_]*NodeBase{},
            previousSibling,
            child,
        );
    }

    // HTML element insertion steps: reset the form owner of what the
    // inserted nodes carry in (CE2-S1: their subtrees, not the whole tree).
    for (nodes[0..nodes_count]) |n| formSubtreeMoved(n, null, @ptrCast(parent));

    // Step 9: Run the children changed steps for parent
    runChildrenChangedSteps(parent, .inserted);

    // Steps 10-12: Post-connection steps
    // Spec: The post-connection steps are run after a batch of nodes is inserted
    // This allows specifications to execute JavaScript or perform connection-related
    // operations after all tree mutations are complete
    //
    // OPTIMIZATION: Skip expensive descendant traversal if no callbacks registered.
    if (hasPostConnectionStepsCallbacks()) {
        try runPostConnectionStepsForTrees(parent.allocator(), nodes);
    }

    if (refcount.treeChecksOn()) {
        refcount.checkAround(@ptrCast(parent));
        if (isDocumentFragment(node)) refcount.checkAround(@ptrCast(node));
    }
}

/// DOM §4.2.5 - Append
/// Spec: https://dom.spec.whatwg.org/#concept-node-append
///
/// This is a convenience wrapper that pre-inserts before null
pub fn append(node: anytype, parent: anytype) DOMException!@TypeOf(node) {
    return preInsert(node, parent, null);
}

/// Batch Child Insertion API - Performance Optimization
///
/// Appends multiple children to a parent in a single operation.
/// This is more efficient than calling append() repeatedly because:
/// - Single mutation observer notification instead of N notifications
/// - Single children-changed callback instead of N callbacks
/// - Batch update of sibling pointers
/// - Uses appendSlice for O(1) amortized insertion vs O(n) repeated appends
///
/// Use this when parsing HTML fragments or building DOM trees where
/// multiple children are known upfront.
///
/// Example:
///   var children: [3]*NodeBase = .{ text1, text2, text3 };
///   try appendChildren(parent, &children);
///
pub fn appendChildren(
    parent: anytype,
    children: []const *NodeBase,
) DOMException!void {
    // Early exit if no children to insert
    if (children.len == 0) return;

    // Step 1: Validate parent is a valid container
    if (!isDocument(parent) and !isDocumentFragment(parent) and !isElement(parent)) {
        return error.HierarchyRequestError;
    }

    // A child moved out of another parent is held from that removal to its
    // link below, which ends the hold (refcount step 7's prerequisite (b));
    // an error leaves it unlinked, and ends it here.
    errdefer for (children) |child| refcount.endRemovalHold(child);

    // Step 2: Validate all children and adopt them
    for (children) |child| {
        // Check child is not an ancestor of parent
        if (isHostIncludingInclusiveAncestor(child, parent)) {
            return error.HierarchyRequestError;
        }

        // Check child is valid type
        if (!isDocumentFragment(child) and !isDocumentType(child) and
            !isElement(child) and !isCharacterData(child))
        {
            return error.HierarchyRequestError;
        }

        // Text nodes cannot be children of documents
        if (isText(child) and isDocument(parent)) {
            return error.HierarchyRequestError;
        }

        // Remove child from its current parent if any
        if (child.parent_node != null) {
            try removeHeld(child, true); // suppress observers for batch efficiency
        }

        // Adopt child into parent's document
        if (parent.documentBase()) |doc| {
            try adoptHeld(child, doc);
        }
    }

    // Step 3: Get previous sibling for mutation record (last child before insertion)
    const previousSibling: ?*NodeBase = parent.lastChild();

    // Steps 4-5: link every child after it - parent and sibling pointers
    // (the links are the children: NodeBase.children)
    for (children) |child| {
        refcount.linkChild(child, @ptrCast(parent));
        joinedTree(child, @ptrCast(parent));
        parent.linkChildBefore(child, null);
    }
    // domindex1: the tree scope's maps, once the batch is linked.
    for (children) |child| tree_ordered_map.inserted(child, @ptrCast(parent));

    // Step 6: Update live ranges if document is available (the first
    // appended child's index: counted only when there are live ranges)
    if (nodeDocument(parent)) |doc| {
        if (hasLiveRanges(doc) and children.len > 0) updateRangesForInsertionWithCount(doc, parent, children[0].index(), children.len);
    }

    // Step 7: Run insertion steps for all inserted nodes and their descendants
    // OPTIMIZATION: Skip expensive descendant traversal if no callbacks registered.
    if (hasInsertionStepsCallbacks() or (parent.is_connected and hasCustomElementDefinitions(parent))) {
        for (children) |child| {
            // Get all shadow-including inclusive descendants in tree order
            var descendants = tree_helpers.getShadowIncludingInclusiveDescendants(
                parent.allocator(),
                child,
            ) catch {
                // If we can't allocate, fall back to non-shadow traversal
                runInsertionSteps(child);
                var descendants_left = child.children();
                while (descendants_left.next()) |descendant| {
                    runInsertionStepsRecursive(descendant);
                }
                continue;
            };
            defer descendants.deinit();

            // Run insertion steps for each shadow-including inclusive descendant
            for (descendants.toSlice()) |inclusive_descendant| {
                runInsertionSteps(inclusive_descendant);
                runCustomElementInsertionSteps(inclusive_descendant);
            }
        }
    }

    // Step 8: Queue a single tree mutation record for all insertions
    // TODO: Phase 6 (whatwg-9wkz8) - MutationObserver integration
    queueTreeMutationRecord(
        parent.allocator(),
        parent,
        children,
        &[_]*NodeBase{},
        previousSibling,
        null, // nextSibling is null since we're appending at end
    );

    // HTML element insertion steps: reset the form owner of what the
    // inserted nodes carry in (CE2-S1).
    for (children) |inserted| formSubtreeMoved(inserted, null, @ptrCast(parent));

    // Step 9: Run children changed steps once for all insertions
    runChildrenChangedSteps(parent, .inserted);

    // Step 10: Run post-connection steps for all inserted nodes
    // OPTIMIZATION: Skip expensive descendant traversal if no callbacks registered.
    if (hasPostConnectionStepsCallbacks()) {
        try runPostConnectionStepsForTrees(parent.allocator(), children);
    }

    if (refcount.treeChecksOn()) refcount.checkAround(@ptrCast(parent));
}

/// Batch Insert Children Before - Performance Optimization
///
/// Inserts multiple children before a reference child in a single operation.
/// Similar to appendChildren but inserts at a specific position.
///
/// This is useful for fragment insertion where nodes need to be inserted
/// before an existing child rather than at the end.
pub fn insertChildrenBefore(
    parent: anytype,
    children: []const *NodeBase,
    reference_child: ?*NodeBase,
) DOMException!void {
    // If reference is null, this is equivalent to appendChildren
    if (reference_child == null) {
        return appendChildren(parent, children);
    }

    const ref_child = reference_child.?;

    // Early exit if no children to insert
    if (children.len == 0) return;

    // Validate reference child's parent
    if (ref_child.parent_node != @as(*NodeBase, @ptrCast(parent))) {
        return error.NotFoundError;
    }

    // Validate parent is a valid container
    if (!isDocument(parent) and !isDocumentFragment(parent) and !isElement(parent)) {
        return error.HierarchyRequestError;
    }

    // As appendChildren: a moved child is held from its removal to its link.
    errdefer for (children) |child| refcount.endRemovalHold(child);

    // Validate and adopt all children
    for (children) |child| {
        if (isHostIncludingInclusiveAncestor(child, parent)) {
            return error.HierarchyRequestError;
        }
        if (!isDocumentFragment(child) and !isDocumentType(child) and
            !isElement(child) and !isCharacterData(child))
        {
            return error.HierarchyRequestError;
        }
        if (isText(child) and isDocument(parent)) {
            return error.HierarchyRequestError;
        }
        if (child.parent_node != null) {
            try removeHeld(child, true);
        }
        if (parent.documentBase()) |doc| {
            try adoptHeld(child, doc);
        }
    }

    // Get previous sibling for mutation record
    const previousSibling: ?*NodeBase = ref_child.previousSibling();

    // The parent link of each child (the holds it moves), in reverse order as
    // before; the sibling links below are the children (NodeBase.children).
    var i: usize = children.len;
    while (i > 0) {
        i -= 1;
        refcount.linkChild(children[i], @ptrCast(parent));
        joinedTree(children[i], @ptrCast(parent));
    }

    // Link the inserted children, in order, before the reference child.
    for (children) |child| parent.linkChildBefore(child, ref_child);
    // domindex1: the tree scope's maps, once the batch is linked.
    for (children) |child| tree_ordered_map.inserted(child, @ptrCast(parent));

    // Update live ranges (the first inserted child's index: counted only
    // when there are live ranges)
    if (nodeDocument(parent)) |doc| {
        if (hasLiveRanges(doc) and children.len > 0) updateRangesForInsertionWithCount(doc, parent, children[0].index(), children.len);
    }

    // Run insertion steps for all inserted nodes
    // OPTIMIZATION: Skip expensive descendant traversal if no callbacks registered.
    if (hasInsertionStepsCallbacks() or (parent.is_connected and hasCustomElementDefinitions(parent))) {
        for (children) |child| {
            var descendants = tree_helpers.getShadowIncludingInclusiveDescendants(
                parent.allocator(),
                child,
            ) catch {
                runInsertionSteps(child);
                var descendants_left = child.children();
                while (descendants_left.next()) |descendant| {
                    runInsertionStepsRecursive(descendant);
                }
                continue;
            };
            defer descendants.deinit();

            for (descendants.toSlice()) |inclusive_descendant| {
                runInsertionSteps(inclusive_descendant);
                runCustomElementInsertionSteps(inclusive_descendant);
            }
        }
    }

    // Queue single mutation record
    // TODO: Phase 6 (whatwg-9wkz8) - MutationObserver integration
    queueTreeMutationRecord(
        parent.allocator(),
        parent,
        children,
        &[_]*NodeBase{},
        previousSibling,
        ref_child,
    );

    // HTML element insertion steps: reset the form owner of what the
    // inserted nodes carry in (CE2-S1).
    for (children) |inserted| formSubtreeMoved(inserted, null, @ptrCast(parent));

    // Run children changed steps once
    runChildrenChangedSteps(parent, .inserted);

    // Run post-connection steps
    // OPTIMIZATION: Skip expensive descendant traversal if no callbacks registered.
    if (hasPostConnectionStepsCallbacks()) {
        try runPostConnectionStepsForTrees(parent.allocator(), children);
    }

    if (refcount.treeChecksOn()) refcount.checkAround(@ptrCast(parent));
}

/// DOM §4.2.5 - Replace
/// Spec: https://dom.spec.whatwg.org/#concept-node-replace
///
/// Steps are similar to pre-insert but with additional validation
/// and removal of the old child
pub fn replace(
    child: anytype,
    node: anytype,
    parent: anytype,
) DOMException!@TypeOf(child) {
    // Step 1: If parent is not Document, DocumentFragment, or Element, throw HierarchyRequestError
    if (!isDocument(parent) and !isDocumentFragment(parent) and !isElement(parent)) {
        return error.HierarchyRequestError;
    }

    // Step 2: If node is host-including inclusive ancestor of parent, throw HierarchyRequestError
    if (isHostIncludingInclusiveAncestor(node, parent)) {
        return error.HierarchyRequestError;
    }

    // Step 3: If child's parent is not parent, throw NotFoundError
    if (child.parent_node != parent) {
        return error.NotFoundError;
    }

    // Step 4: Check node is valid type
    if (!isDocumentFragment(node) and !isDocumentType(node) and
        !isElement(node) and !isCharacterData(node))
    {
        return error.HierarchyRequestError;
    }

    // Step 5: Check Text/doctype constraints
    if (isText(node) and isDocument(parent)) {
        return error.HierarchyRequestError;
    }
    if (isDocumentType(node) and !isDocument(parent)) {
        return error.HierarchyRequestError;
    }

    // Step 6: If parent is document, check additional constraints
    if (isDocument(parent)) {
        if (isDocumentFragment(node)) {
            const element_count = countElementChildren(node);

            if (element_count > 1 or hasTextChild(node)) {
                return error.HierarchyRequestError;
            }

            if (element_count == 1) {
                if (hasElementChild(parent, child) or isDoctypeFollowing(parent, child)) {
                    return error.HierarchyRequestError;
                }
            }
        } else if (isElement(node)) {
            if (hasElementChild(parent, child) or isDoctypeFollowing(parent, child)) {
                return error.HierarchyRequestError;
            }
        } else if (isDocumentType(node)) {
            if (hasDoctypeChild(parent) or isElementPreceding(parent, child)) {
                return error.HierarchyRequestError;
            }
        }
    }

    // Step 7: Let referenceChild be child's next sibling
    var referenceChild: ?*NodeBase = child.next_sibling;

    // Step 8: If referenceChild is node, set referenceChild to node's next sibling
    if (referenceChild != null and referenceChild.? == node) {
        referenceChild = node.next_sibling;
    }

    // Step 9: Let previousSibling be child's previous sibling
    const previousSibling: ?*NodeBase = child.previousSibling();

    // Deviation, stated: the spec text now leaves node's adoption to step
    // 13's insert, which would remove node from its old parent only after
    // child is gone. Browsers - and WPT's MutationObserver-childList.html -
    // still take node out of its old parent HERE, before child is removed,
    // as the spec's step 10 used to read ("Adopt node into parent's node
    // document"), so that removal is its own record and its previous sibling
    // is still in place. Blink's ContainerNode::ReplaceChild does the same "to
    // make a separated MutationRecord".
    //
    // Moved, `node` is held from that removal to its link in step 13's
    // insert, which ends the hold (refcount step 7's prerequisite (b)).
    if (!isDocumentFragment(node) and node.parent_node != null) {
        try removeHeld(node, false);
    }
    errdefer refcount.endRemovalHold(@ptrCast(node));

    // Step 10-11: Remove child if its parent is non-null
    var removedNodes: [1]*NodeBase = undefined;
    var removed_count: usize = 0;

    // The removed child is held until step 14's record names it (WebKit's
    // replaceChild keeps `Ref protectedOldChild`; prerequisite (b2)).
    defer if (removed_count == 1) refcount.endRemovalHold(child);
    if (child.parent_node != null) {
        try removeHeld(child, true); // suppress observers
        removedNodes[0] = child;
        removed_count = 1;
    }

    // Step 12: Let nodes be node's children if DocumentFragment, otherwise
    // « node ». Copied: step 13 moves a fragment's children out of its list.
    var added_nodes_buf: [64]*NodeBase = undefined;
    const single = [1]*NodeBase{@ptrCast(node)};
    const added_nodes = (if (isDocumentFragment(node))
        copyChildren(parent.allocator(), node, &added_nodes_buf)
    else
        copyNodes(parent.allocator(), &single, &added_nodes_buf)) catch return error.OutOfMemory;
    defer if (added_nodes.len > added_nodes_buf.len) parent.allocator().free(added_nodes);
    const added_count = added_nodes.len;

    // Step 13: Insert node into parent before referenceChild with suppress observers
    try insert(node, parent, referenceChild, true);

    // Step 14: Queue a tree mutation record
    // TODO: Phase 6 (whatwg-9wkz8) - MutationObserver integration
    queueTreeMutationRecord(
        parent.allocator(),
        parent,
        added_nodes[0..added_count],
        removedNodes[0..removed_count],
        previousSibling,
        referenceChild,
    );

    // Step 15: Return child
    return child;
}

/// DOM §4.2.5 - Replace all
/// Spec: https://dom.spec.whatwg.org/#concept-node-replace-all
///
/// This algorithm removes all children and inserts node (if non-null)
pub fn replaceAll(
    node: anytype,
    parent: anytype,
) DOMException!void {
    const allocator = parent.allocator();

    // Step 1: "Let removedNodes be parent's children." Copied: step 5 empties
    // the list this would otherwise be a view of.
    var removed_buf: [64]*NodeBase = undefined;
    const removed_nodes = copyChildren(allocator, parent, &removed_buf) catch return error.OutOfMemory;
    defer if (removed_nodes.len > removed_buf.len) allocator.free(removed_nodes);

    // Steps 2-4: "Let addedNodes be the empty set. If node is a
    // DocumentFragment node, then set addedNodes to node's children.
    // Otherwise, if node is non-null, set addedNodes to « node »." Copied
    // too: step 6 moves a fragment's children out of it.
    var added_buf: [64]*NodeBase = undefined;
    var single: [1]*NodeBase = undefined;
    const added_nodes = (if (node) |n| blk: {
        if (isDocumentFragment(n)) break :blk copyChildren(allocator, n, &added_buf);
        single[0] = @ptrCast(n);
        break :blk copyNodes(allocator, &single, &added_buf);
    } else copyNodes(allocator, &.{}, &added_buf)) catch return error.OutOfMemory;
    defer if (added_nodes.len > added_buf.len) allocator.free(added_nodes);

    // Step 5: "Remove all parent's children, in tree order, with the
    // suppress observers flag set." Each is held until step 7's record names
    // it (prerequisite (b2)): the record takes its removed nodes on a tree
    // that never counted zero. The holds end at the end, error or not.
    defer for (removed_nodes) |removed| refcount.endRemovalHold(removed);
    while (parent.first_child) |child_to_remove| {
        try removeHeld(child_to_remove, true);
    }

    // Step 6: "If node is non-null, then insert node into parent before null
    // with the suppress observers flag set."
    if (node) |n| {
        try insert(n, parent, null, true);
    }

    // Step 7: "If either addedNodes or removedNodes is not empty, then queue
    // a tree mutation record for parent with addedNodes, removedNodes, null,
    // and null."
    if (added_nodes.len > 0 or removed_nodes.len > 0) {
        queueTreeMutationRecord(allocator, parent, added_nodes, removed_nodes, null, null);
    }
}

/// `nodes` copied into `buffer` when it fits, or into a new allocation.
fn copyNodes(allocator: std.mem.Allocator, nodes: []const *NodeBase, buffer: []*NodeBase) ![]*NodeBase {
    const copy = if (nodes.len <= buffer.len) buffer[0..nodes.len] else try allocator.alloc(*NodeBase, nodes.len);
    @memcpy(copy, nodes);
    return copy;
}

/// `parent`'s children in tree order, copied off its links into `buffer`, or
/// into a new allocation past its length (the caller frees a result longer
/// than `buffer`): a snapshot a step can keep while it moves them.
fn copyChildren(allocator: std.mem.Allocator, parent: anytype, buffer: []*NodeBase) ![]*NodeBase {
    const from: *const NodeBase = @ptrCast(parent);
    const count = from.childCount();
    const copy = if (count <= buffer.len) buffer[0..count] else try allocator.alloc(*NodeBase, count);
    var children = from.children();
    var i: usize = 0;
    while (children.next()) |child| : (i += 1) copy[i] = child;
    return copy;
}

/// DOM §4.2.5 - Pre-remove
/// Spec: https://dom.spec.whatwg.org/#concept-node-pre-remove
///
/// Steps:
/// 1. If child's parent is not parent, then throw NotFoundError
/// 2. Remove child
/// 3. Return child
pub fn preRemove(
    child: anytype,
    parent: anytype,
) (DOMException || error{OutOfMemory})!@TypeOf(child) {
    // Step 1: If child's parent is not parent, throw NotFoundError
    if (child.parent_node != parent) {
        return error.NotFoundError;
    }

    // Step 2: Remove child
    try remove(child, false);

    // Step 3: Return child
    return child;
}

/// DOM §4.2.5 - Remove
/// Spec: https://dom.spec.whatwg.org/#concept-node-remove
///
/// This handles all the complex removal logic including:
/// - Live range updates
/// - NodeIterator updates
/// - Slot assignment
/// - Removing steps callbacks
/// - Custom element disconnection
/// - Mutation observer notifications
///
/// The remover holds `node` across the steps that follow its unlink - the
/// removing steps, the transient observers, the mutation record - and lets
/// go at the end (WebKit's ContainerNode::removeChild `Ref
/// protectedOldChild`; refcount step 7's prerequisite (b2), lane
/// refcount8): a holder that takes the node on in those steps (a record, an
/// img's update) takes it on a tree that never counted zero.
pub fn remove(
    node: anytype,
    suppress_observers: bool,
) (DOMException || error{OutOfMemory})!void {
    try removeHeld(node, suppress_observers);
    refcount.endRemovalHold(@ptrCast(node));
}

/// `remove`, leaving the remover's hold on `node` (refcount.unlinkChildHeld)
/// for the caller: a move links it again (insert, whose link ends it), and
/// replace and replace all end it after their own mutation record names it
/// (refcount.endRemovalHold). On an error after the unlink the hold ends here.
fn removeHeld(
    node: anytype,
    suppress_observers: bool,
) (DOMException || error{OutOfMemory})!void {
    try removeHeldMoving(node, suppress_observers);
    orphanRemoved(@ptrCast(node));
}

/// `removeHeld` for a caller that removes `node` only to link it again in
/// the same algorithm - "insert"'s step 4.1, which takes a fragment's
/// children out to give them to the parent in step 7.3: a MOVE. It does not
/// record the node as a possible orphan (`orphanRemoved`): the record was
/// stale the moment the node was linked, and `host.innerHTML` of 100,000
/// spans left 100,000 of them, 2.2 MB, in the realm's list to its end (lane
/// nm1; MEASURED, malloc_history: one block under removeHeld <- insert <-
/// replaceAll). The caller records what it leaves unlinked on an error.
/// Blink and WebKit move a fragment's children with no bookkeeping beyond
/// the removal itself (ContainerNode::InsertBefore -> CollectChildrenAnd
/// RemoveFromOldParent, a NodeVector of the held children).
fn removeHeldMoving(
    node: anytype,
    suppress_observers: bool,
) (DOMException || error{OutOfMemory})!void {
    // Step 1: Let parent be node's parent
    const parent = node.parent_node orelse {
        // Step 2: Assert parent is non-null
        // If parent is null, this is an error in the algorithm usage
        return error.HierarchyRequestError;
    };

    // Step 3: Run the live range pre-remove steps
    runLiveRangePreRemoveSteps(node);

    // Step 4: For each NodeIterator, run pre-remove steps
    runNodeIteratorPreRemoveSteps(node);

    // Step 5: Let oldPreviousSibling be node's previous sibling
    const oldPreviousSibling: ?*NodeBase = node.previousSibling();

    // Step 6: Let oldNextSibling be node's next sibling
    const oldNextSibling: ?*NodeBase = node.next_sibling;

    // Step 7: Remove node from its parent's children: unlink it (the links
    // are the children, NodeBase.children)
    parent.unlinkChild(node);

    // The parent write, and the holds it moves (refcount, step 3), with the
    // remover's hold (removeHeld); a wrapped root leaves its old tree's
    // opaque root (step 4).
    refcount.unlinkChildHeld(@ptrCast(node));
    errdefer refcount.endRemovalHold(@ptrCast(node));
    leftTree(@ptrCast(node), @ptrCast(parent));

    // Update is_connected for the removed node and all its descendants. A
    // removed node is no longer connected to the document tree; one that was
    // not connected has no connected descendant (the flag is exact,
    // dom.shadow_hosts.attached), so its subtree is not walked - a deep
    // detached subtree moved between detached parents (Range's subfragments)
    // paid a walk of it on every move (lane crash1 batch 3).
    if (node.is_connected) setConnectedRecursive(node, false);
    // domindex1: the light subtree leaves its old tree scope's maps at the
    // unlink - before the form owner reset below, whose form-ID lookups
    // read them, and before any removing step (Blink and WebKit update
    // theirs in RemovedFrom).
    tree_ordered_map.removed(@ptrCast(node), @ptrCast(parent));
    // HTML element removing steps: reset the form owner of the removed
    // subtree, and of the elements whose form attribute named an ID that
    // left the tree (CE2-S1).
    formSubtreeMoved(@ptrCast(node), @ptrCast(parent), null);

    // Steps 8-10: re-assign node's assigned slot, signal a slot change for
    // an empty slot parent in a shadow tree, and re-assign both trees when
    // node takes a slot out of a shadow tree.
    removingSlotSteps(parent.allocator(), @ptrCast(node), @ptrCast(parent));

    // Step 11: Run the removing steps with node and parent
    // Spec: DOM §4.2.5 - Specifications may define removing steps
    runRemovingSteps(node, parent);

    // Steps 12–13: removing steps have run; read the parent's connectedness
    // now and enqueue disconnectedCallback for each custom descendant.
    const parent_connected = parent.is_connected or parent.node_type == DOCUMENT_NODE;
    if (parent_connected) enqueueCustomElementCallback(node, .disconnected, .none);

    // Step 14: For each shadow-including descendant of node,
    // in shadow-including tree order, run removing steps
    // Spec: DOM §4.2.5 step 14
    if (tree_helpers.getShadowIncludingDescendants(parent.allocator(), node)) |descendants| {
        var mut_descendants = descendants;
        defer mut_descendants.deinit();

        // Step 14.1: Run removing steps with the original removed ancestor.
        // Step 14.2: Custom element disconnectedCallback
        for (mut_descendants.items()) |descendant| {
            runRemovingSteps(descendant, parent);

            if (parent_connected) enqueueCustomElementCallback(descendant, .disconnected, .none);
        }
    } else |_| {
        // The node is already detached: allocation failure must not skip
        // shadow descendant cleanup or repeat the root's removing steps.
        runRemovingStepsForDescendants(node, parent, parent_connected);
    }

    // Step 15: transient registered observers on node, for every observer
    // of an inclusive ancestor of parent that observes its subtree.
    try createTransientObserversForRemovedNode(node, parent);

    // Step 16: If suppress observers flag is unset, queue a tree mutation record
    if (!suppress_observers) {
        var removed_nodes_buf: [1]*NodeBase = undefined;
        removed_nodes_buf[0] = node;
        // TODO: Phase 6 (whatwg-9wkz8) - MutationObserver integration
        queueTreeMutationRecord(
            parent.allocator(),
            parent,
            &[_]*NodeBase{},
            removed_nodes_buf[0..1],
            oldPreviousSibling,
            oldNextSibling,
        );
    }

    // Step 17: Run the children changed steps for parent
    runChildrenChangedSteps(parent, .removed);

    if (refcount.treeChecksOn()) {
        refcount.checkAround(@ptrCast(parent));
        refcount.checkAround(@ptrCast(node));
    }
}

/// `node` left its tree. A root no wrapper of any realm ever reached - nor
/// any node of its tree (dom.wrapper_tracing.holdsWrapper) - is an ORPHAN:
/// no tree teardown and no collector reaches it until reference counting
/// decides (refcount design step 7). Its realm frees it at its end unless a
/// tree or a wrapper takes it first (runtime.orphan_roots; lane unwrapped1).
/// Only where the engine marks every wrap ([wrap_tracking]): elsewhere the
/// missing mark proves nothing, and the orphan stays until its Browser ends,
/// as before. The root's own wrapper state no longer speaks for its subtree:
/// since the wrapper redesign's P7 a wrap reaches no ancestor, so a node
/// script read out of the tree - getElementById - can be wrapped and held
/// under a root no script ever saw (tests/wpt/crane/wr7-removed-unwrapped-
/// root-keeps-held-node.html); its wrapper's reference holds the tree, and
/// the counts decide that tree's free. Exactly that question - is a node of
/// the tree WRAPPED - and no broader one: a tree held only by holders'
/// counts is still recorded and freed at the realm's end, as before P7
/// (refusing every held tree left lone elements held at the agent's end in
/// the editing1/2/3 tests; that drain's own fate is refcount step 7b's).
fn orphanRemoved(node: *NodeBase) void {
    if (engine.capabilities.wrap_tracking == .unsupported) return;
    if (node.parent_node != null or !node.wrapper.isEmpty()) return;
    if (wrapper_tracing.holdsWrapper(node)) return;
    const instance: *runtime.Instance = @ptrCast(@alignCast(node.ownerInstance() orelse return));
    if (!runtime.instance_lifecycle.provablyUnwrapped(true, instance)) return;
    runtime.orphan_roots.record(instance.ctx, instance);
}

// ============================================================================
// The mutation algorithms on platform objects
// ============================================================================
//
// For another DOM algorithm whose steps run one of the algorithms above on
// nodes it was given as platform objects: ParentNode's prepend() and
// append(), ChildNode's before(), after(), replaceWith() and remove(), and
// "converting nodes into a node". They call these, never Node's IDL members:
// appendChild, insertBefore and replaceChild are [CEReactions], and their
// generated functions open a reaction scope, which would run the element
// queue in the middle of the outer algorithm (impls-boundary design 3.1, a4;
// Blink opens the scope only in its bindings, `CEReactionsScope` in the V8
// callback, and its C++ calls make none).
//
// Each reports an algorithm's exception as Node's own members have: a
// HierarchyRequestError and a NotFoundError as they are, anything else - an
// OutOfMemory among them - an InvalidStateError, and so does an object that
// is no node.

/// The exceptions of the mutation algorithms on platform objects.
pub const NodeError = error{ HierarchyRequestError, NotFoundError, InvalidStateError };

fn nodeError(err: (DOMException || error{OutOfMemory})) NodeError {
    return switch (err) {
        error.HierarchyRequestError => error.HierarchyRequestError,
        error.NotFoundError => error.NotFoundError,
        else => error.InvalidStateError,
    };
}

/// `instance`'s node, or an InvalidStateError for an object that is no node.
fn nodeOfInstance(instance: *runtime.Instance) NodeError!*NodeBase {
    return instance_bridge.getNodeBase(instance) orelse error.InvalidStateError;
}

/// "Pre-insert `node` into `parent` before `child`". A `child` that is no
/// node is null: the end of `parent`'s children.
pub fn preInsertNode(node: *runtime.Instance, parent: *runtime.Instance, child: ?*runtime.Instance) NodeError!void {
    const parent_ptr = try nodeOfInstance(parent);
    const node_ptr = try nodeOfInstance(node);
    const child_ptr: ?*NodeBase = if (child) |c| instance_bridge.getNodeBase(c) else null;
    _ = preInsert(node_ptr, parent_ptr, child_ptr) catch |err| return nodeError(err);
}

/// "Append `node` to `parent`".
pub fn appendNode(node: *runtime.Instance, parent: *runtime.Instance) NodeError!void {
    const parent_ptr = try nodeOfInstance(parent);
    const node_ptr = try nodeOfInstance(node);
    _ = append(node_ptr, parent_ptr) catch |err| return nodeError(err);
}

/// "Replace `child` with `node` within `parent`".
pub fn replaceNode(child: *runtime.Instance, node: *runtime.Instance, parent: *runtime.Instance) NodeError!void {
    const parent_ptr = try nodeOfInstance(parent);
    const child_ptr = try nodeOfInstance(child);
    const node_ptr = try nodeOfInstance(node);
    _ = replace(child_ptr, node_ptr, parent_ptr) catch |err| return nodeError(err);
}

/// "Remove `node`".
pub fn removeNode(node: *runtime.Instance) NodeError!void {
    const node_ptr = try nodeOfInstance(node);
    remove(node_ptr, false) catch |err| return nodeError(err);
}

/// "Move `node` into `parent` before `child`" (null: at the end) - DOM
/// "move", ParentNode.moveBefore()'s step 3. A `child` that is no node is
/// null.
pub fn moveNode(node: *runtime.Instance, parent: *runtime.Instance, child: ?*runtime.Instance) NodeError!void {
    const parent_ptr = try nodeOfInstance(parent);
    const node_ptr = try nodeOfInstance(node);
    const child_ptr: ?*NodeBase = if (child) |c| instance_bridge.getNodeBase(c) else null;
    move(node_ptr, parent_ptr, child_ptr) catch |err| return nodeError(err);
}

/// DOM "converting nodes into a node", given `nodes` (the ParentNode and
/// ChildNode mixins' `(Node or DOMString)...`: a slice of a union with a
/// `node` and a `string` arm) and `document`.
/// Spec: https://dom.spec.whatwg.org/#converting-nodes-into-a-node
pub fn convertNodesIntoNode(nodes: anytype, document: *runtime.Instance) !*runtime.Instance {
    // Steps 1-2: "Replace each string of nodes with a new Text node whose data
    // is the string and node document is document. If nodes contains one node,
    // then return nodes[0]."
    if (nodes.len == 1) return nodeOrText(nodes[0], document);

    // Step 3: "Let fragment be a new DocumentFragment node whose node document
    // is document."
    const fragment = try interfaces.Document.call_createDocumentFragment(document);

    // Step 4: "For each node of nodes: append node to fragment."
    for (nodes) |item| try appendNode(try nodeOrText(item, document), fragment);

    // Step 5: "Return fragment."
    return fragment;
}

/// The node "converting nodes into a node" returned, once its caller's
/// insertion of it is over (`count`: how many nodes were converted). A
/// fragment it made (more than one) was never exposed: its children moved
/// out, it is empty and parentless, and nothing but its creator ever named
/// it - so it goes now, its born reference with it (refcount step 7's
/// prerequisite (a), lane refcount8: 38 such fragments were freed only at
/// their realm's end, still holding their creator's reference). One an
/// error left children in keeps them: only its creator's reference ends.
/// One node is the caller's own, or a Text node its insertion took over.
pub fn dropConvertedNode(node: *runtime.Instance, count: usize) void {
    if (count == 1) return;
    const base = instance_bridge.getNodeBase(node) orelse return;
    if (base.first_child == null and base.parent_node == null) {
        @import("node_creation.zig").releaseIfUnwrapped(node, runtime.SlabAllocator.generationOf(node));
    } else refcount.releaseCreatorReference(base);
}

/// A node of a "converting nodes into a node" list: the node itself, or a new
/// Text node holding the string, whose node document is `document`.
fn nodeOrText(item: anytype, document: *runtime.Instance) !*runtime.Instance {
    return switch (item) {
        .node => |node| node,
        // createTextNode copies the data; the binding owns the slice.
        .string => |data| try interfaces.Document.call_createTextNode(document, runtime.DOMString.initInterned(data)),
    };
}

/// DOM "move" (https://dom.spec.whatwg.org/#move): move `node` into
/// `new_parent` before `child` (null: at the end). A primitive of its own,
/// not a removal and an insertion: it runs the moving steps and never the
/// removing, insertion or post-connection steps, so a moved node keeps its
/// state - its iframe's navigable, its running animations, its place in the
/// top layer, the focus, a fetched style sheet, a custom element's state.
/// ParentNode.moveBefore() is its caller (`moveNode`).
///
/// Children changed steps, a stated deviation (AGENTS.md golden rule 2; no
/// newer spec is involved): the DOM text runs none in move, but both browsers
/// that ship moveBefore notify both parents' children changes on a move.
/// Blink's Node::moveBefore (core/dom/node.cc) is ContainerNode::InsertBefore,
/// which removes the child and inserts it again under
/// Document::StatePreservingAtomicMoveInProgress, and each half calls
/// ContainerNode::ChildrenChanged; Gecko's nsINode::MoveBefore
/// (dom/base/nsINode.cpp) is RemoveChildNode + InsertChildBefore with
/// notifications (ContentWillBeRemoved, ContentInserted). Both skip only the
/// script's preparation for it: HTMLScriptElement/SVGScriptElement::
/// ChildrenChanged do not call the script loader during the move, and Gecko's
/// ScriptElement::ContentInserted/ContentAppended return when `aInfo.mOldParent`
/// is set ("moveBefore() must not run the script"); a style element updates its
/// sheet in both. So the steps run here with the `.moved` reason, which the
/// script elements' callbacks skip (dom/nodes/moveBefore/script-move-before.html:
/// Chrome 157 and Firefox 159 2/2).
///
/// Lifetime (lesson "a move is a removal and an insertion - hold what you
/// move"): the counts move once, from the old tree to the new one, at the
/// link (refcount.moveChild); the node is never a counted root of its own,
/// so its tree cannot become garbage between step 13 and step 20, and no
/// remover's hold is needed (step 13's comment).
pub fn move(node: *NodeBase, new_parent: *NodeBase, child: ?*NodeBase) DOMException!void {
    // 1. "If newParent's shadow-including root is not the same as node's
    // shadow-including root, then throw a HierarchyRequestError
    // DOMException." (So a move is only performed when newParent's
    // connected is node's connected.)
    if (shadowIncludingRoot(new_parent) != shadowIncludingRoot(node)) return error.HierarchyRequestError;
    // 2. "If node is a host-including inclusive ancestor of newParent, then
    // throw a HierarchyRequestError DOMException."
    if (isHostIncludingInclusiveAncestor(node, new_parent)) return error.HierarchyRequestError;
    // 3. "If child is non-null and its parent is not newParent, then throw a
    // NotFoundError DOMException."
    if (child) |c| if (c.parent_node != new_parent) return error.NotFoundError;
    // 4. "If node is not an Element or a CharacterData node, then throw a
    // HierarchyRequestError DOMException."
    if (!isElement(node) and !isCharacterData(node)) return error.HierarchyRequestError;
    // 5. "If node is a Text node and newParent is a document, then throw a
    // HierarchyRequestError DOMException."
    if (isText(node) and isDocument(new_parent)) return error.HierarchyRequestError;
    // 6. "If newParent is a document, node is an Element node, and either
    // newParent has an element child, child is a doctype, or child is
    // non-null and a doctype is following child then throw a
    // HierarchyRequestError DOMException."
    if (isDocument(new_parent) and isElement(node)) {
        if (hasElementChild(new_parent, null)) return error.HierarchyRequestError;
        if (child) |c| if (isDocumentType(c) or isDoctypeFollowing(new_parent, c)) return error.HierarchyRequestError;
    }
    // 7. "Let oldParent be node's parent." 8. "Assert: oldParent is
    // non-null." Step 1 holds it: a parentless node is its own
    // shadow-including root, which step 2 keeps from being newParent's.
    const old_parent = node.parent_node orelse return error.HierarchyRequestError;
    const allocator = new_parent.allocator();

    // 9. "Run the live range pre-remove steps, given node."
    runLiveRangePreRemoveSteps(node);
    // 10. "For each NodeIterator object iterator whose root's node document
    // is node's node document: run the NodeIterator pre-remove steps given
    // node and iterator."
    runNodeIteratorPreRemoveSteps(node);
    // 11. "Let oldPreviousSibling be node's previous sibling."
    const old_previous_sibling = node.previousSibling();
    // 12. "Let oldNextSibling be node's next sibling."
    const old_next_sibling = node.next_sibling;

    // 13. "Remove node from oldParent's children."
    //
    // Node's parent pointer stays oldParent until steps 20-21 write the new
    // one (refcount.moveChild): the counts then move from the old chain to
    // the new one in a single step, and the moved tree is never a counted
    // root of its own - with a parentless node a hold taken and dropped
    // between the two (a wrap, a node_holds hold) would end at node and call
    // its tree garbage. What the standard's parentless node changes in the
    // steps in between: steps 14-16 walk trees through child lists, which no
    // longer reach node, so oldParent's tree loses node's slots and node's
    // slots find no slottable through "find a slot" either way; only a
    // manually assigned slot in node's subtree still finds its manually
    // assigned nodes for one step (its root reads as oldParent's), and step
    // 24 assigns it again from node's new root. Every other step names its
    // parent explicitly.
    unlinkForMove(node, old_parent);

    // 14. "If node is assigned, then run assign slottables for node's
    // assigned slot." 15. "If oldParent's root is a shadow root, and
    // oldParent is a slot whose assigned nodes is empty, then run signal a
    // slot change for oldParent." 16. "If node has an inclusive descendant
    // that is a slot": assign slottables for a tree with oldParent's root,
    // then with node. (The remove steps 8-10.)
    removingSlotSteps(allocator, node, old_parent);

    // 17. "Add transient registered observers given node and oldParent."
    // An allocation failure leaves those observers out, not the move half
    // done.
    createTransientObserversForRemovedNode(node, old_parent) catch |err| {
        std.log.scoped(.mutation).warn("transient observers after a move failed: {}", .{err});
    };

    // The old parent's children changed - the stated deviation above.
    runChildrenChangedSteps(old_parent, .moved);

    // 18. "If child is non-null": "For each live range whose start node is
    // newParent and start offset is greater than child's index: increase its
    // start offset by 1", and the same for end nodes and end offsets.
    if (child) |c| {
        // The index is counted only when there are live ranges (insert's
        // step 5 does the same).
        if (nodeDocument(new_parent)) |doc| if (hasLiveRanges(doc)) updateRangesForInsertion(doc, new_parent, getChildIndex(c) orelse 0);
    }

    // 19. "Let newPreviousSibling be child's previous sibling if child is
    // non-null, and newParent's last child otherwise."
    const new_previous_sibling = if (child) |c| c.previousSibling() else new_parent.lastChild();

    // 20. "If child is null, then append node to newParent's children."
    // 21. "Otherwise, insert node into newParent's children before child's
    // index." The parent link, the counts and the wrapper edges with it.
    linkForMove(node, old_parent, new_parent, child);

    // domindex1: the light subtree leaves its old tree scope's maps and
    // joins its new one's - often the same scope, and the move still changes
    // the order its keys' elements are in - at the link, before the form
    // owner reset reads them.
    tree_ordered_map.moved(node, old_parent, new_parent);
    // HTML moving steps step 2: reset the form owner of what the move
    // reached, once, in the new position (CE2-S1).
    formSubtreeMoved(node, old_parent, new_parent);

    // 22. "If newParent is a shadow host whose shadow root's slot assignment
    // is "named" and node is a slottable, then assign a slot for node."
    // 23. "If newParent's root is a shadow root, and newParent is a slot
    // whose assigned nodes is empty, then run signal a slot change for
    // newParent." 24. "Run assign slottables for a tree with node's root."
    // (The insert steps 7.4-7.6.)
    insertionSlotSteps(allocator, node, new_parent);

    // The new parent's children changed - the stated deviation above.
    runChildrenChangedSteps(new_parent, .moved);

    // 25. For each shadow-including inclusive descendant of node, in
    // shadow-including tree order: the moving steps, and connectedMoveCallback
    // for a custom one when newParent is connected.
    const new_parent_connected = new_parent.is_connected or isDocument(new_parent);
    runMovingStepsForTree(node, old_parent, new_parent_connected);

    // 26. "Queue a tree mutation record for oldParent with « », « node »,
    // oldPreviousSibling, and oldNextSibling."
    const moved_nodes = [_]*NodeBase{node};
    queueTreeMutationRecord(allocator, old_parent, &[_]*NodeBase{}, &moved_nodes, old_previous_sibling, old_next_sibling);
    // 27. "Queue a tree mutation record for newParent with « node », « »,
    // newPreviousSibling, and child."
    queueTreeMutationRecord(allocator, new_parent, &moved_nodes, &[_]*NodeBase{}, new_previous_sibling, child);

    if (refcount.treeChecksOn()) {
        refcount.checkAround(old_parent);
        refcount.checkAround(new_parent);
    }
}

/// The slot steps of insert (7.4-7.6) and move (21-23). They cannot fail in
/// the standard; running out of memory here leaves an assignment stale
/// rather than abandoning an insertion halfway through its steps.
fn insertionSlotSteps(allocator: std.mem.Allocator, node: *NodeBase, parent: *NodeBase) void {
    shadow_dom_algorithms.runInsertionSlotSteps(allocator, node, parent) catch |err| {
        std.log.scoped(.mutation).warn("slot assignment after insertion failed: {}", .{err});
    };
}

/// The slot steps of remove (8-10) and move (14-16); see insertionSlotSteps.
fn removingSlotSteps(allocator: std.mem.Allocator, node: *NodeBase, parent: *NodeBase) void {
    shadow_dom_algorithms.runRemovingSlotSteps(allocator, node, parent) catch |err| {
        std.log.scoped(.mutation).warn("slot assignment after removal failed: {}", .{err});
    };
}

/// DOM "shadow-including root": "its root's host's shadow-including root, if
/// the object's root is a shadow root; otherwise its root." Through
/// ShadowRoot's host only: a template's contents is a
/// fragment with a host too, but not a shadow root, so it is a root here.
/// Gecko's MoveBefore step 1 compares GetRootNode({composed: true}).
fn shadowIncludingRoot(node: *NodeBase) *NodeBase {
    var current = node;
    // A chain of shadow roots is a handful deep; the bound only stops a
    // corrupt tree from looping.
    var depth: usize = 0;
    while (depth < 1024) : (depth += 1) {
        var root = current;
        while (root.parent_node) |parent| root = parent;
        if (root.node_type != DOCUMENT_FRAGMENT_NODE) return root;
        const root_instance = instanceOfNode(root) orelse return root;
        if (root_instance.stateAs(interfaces.ShadowRoot.State) == null) return root;
        const host = interfaces.ShadowRoot.get_host(root_instance) catch return root;
        current = instance_bridge.getNodeBase(host) orelse return root;
    }
    return current;
}

/// Helper: Check if node is a host-including inclusive ancestor of other
/// Spec: https://dom.spec.whatwg.org/#concept-tree-host-including-inclusive-ancestor
///
/// DOM: "An object A is a host-including inclusive ancestor of an object B,
/// if either A is an inclusive ancestor of B, or if B's root has a non-null
/// host and A is a host-including inclusive ancestor of B's root's host."
///
/// True when `node` is a host-including inclusive ancestor of `other` - the
/// question pre-insertion validity step 2 asks with (node, parent). This used
/// to ask it backwards (`tree_helpers.isInclusiveAncestor(node, other)` is
/// "`other` is an inclusive ancestor of `node`"), so moving a child within its
/// own parent threw HierarchyRequestError while inserting an ancestor into its
/// own descendant succeeded and made a cycle that hung every later tree walk.
fn isHostIncludingInclusiveAncestor(node: anytype, other: anytype) bool {
    const ancestor: *const NodeBase = @ptrCast(node);
    var current: *const NodeBase = @ptrCast(other);
    // A node with no children is an inclusive ancestor of itself alone, and
    // a host-including ancestor of anything more only as a host - of a
    // shadow root, or of template contents. So a new leaf, the node nearly
    // every insert brings, answers here, where the walk below climbs the
    // parent's whole ancestry and then its root's host chain: a tree built
    // one node at a time cost O(nodes x depth) (lane crash1 batch 3). WebKit's
    // Node::isDescendantOf returns false at `!other.hasChildNodes()`, Blink's
    // Node::IsShadowIncludingAncestorOf at `!has_children && !has_shadow`.
    if (ancestor.first_child == null and !ancestor.is_shadow_host and !hostsTemplateContents(ancestor)) return ancestor == current;
    // DOM host-including inclusive ancestor: follow every fragment host.
    // A fixed depth would permit a cycle through valid, deeply nested templates.
    while (true) {
        if (tree_helpers.isInclusiveAncestor(current, ancestor)) return true;
        // B's root, and whether it is a shadow root with a host.
        var root = current;
        while (root.parent_node) |parent| root = parent;
        if (root.node_type != DOCUMENT_FRAGMENT_NODE) return false;
        const root_opaque = instance_bridge.getInstance(@constCast(root)) orelse return false;
        const root_instance: *runtime.Instance = @ptrCast(@alignCast(root_opaque));
        const host = @import("template_contents.zig").host(root_instance) orelse return false;
        current = instance_bridge.getNodeBase(host) orelse return false;
    }
}

/// Whether `node` is a template whose contents exist: the host of a
/// DocumentFragment that host-including ancestry passes through.
fn hostsTemplateContents(node: *const NodeBase) bool {
    if (node.node_type != ELEMENT_NODE) return false;
    const instance = instanceOfNode(@constCast(node)) orelse return false;
    return @import("template_contents.zig").contentOf(instance) != null;
}

// Stub: Queue tree mutation record for NodeBase nodes
//
// TODO: MutationObserver integration is stubbed out during unified DOM tree refactoring.
// The mutation_observer_algorithms.queueTreeMutationRecord function expects:
//   - target: *Node (WebIDL interface)
//   - added_nodes: *NodeList (WebIDL interface)
//   - removed_nodes: *NodeList (WebIDL interface)

/// `node`'s node document, which the live-range and NodeIterator steps key
/// their lists on, read through the Node interface. A document is its own node
/// document.
fn nodeDocument(node: anytype) ?*runtime.Instance {
    const base: *NodeBase = @ptrCast(@constCast(node));
    const instance_opaque = instance_bridge.getInstance(base) orelse return null;
    const instance: *runtime.Instance = @ptrCast(@alignCast(instance_opaque));
    if (base.node_type == DOCUMENT_NODE) return instance;
    return interfaces.Node.get_ownerDocument(instance) catch null;
}

/// Hold the teardowns of `document`'s agent for a walk of its live ranges
/// or NodeIterators (engine.holdTeardowns): a step's engine call can start a
/// collection, and what it collects is torn down when the walk ends, not
/// under it - neither a range the walk has not reached nor the one it is
/// stepping. The cursor (dom.live_range_list) keeps the walk whole when an
/// entry leaves anyway, as a range that moves to another document does.
///
/// A hold must not span script, and these walks run none: their steps set
/// boundary points and offsets (Range's live-range steps, setStart/setEnd in
/// the replace-data and normalize steps), redraw traced edges, queue a
/// selectionchange task without running it (dom.selection.rangeMutated), and
/// move a NodeIterator's reference - its filter is not called by the
/// pre-removing steps. No event is dispatched and no microtask checkpoint is
/// performed inside one.
fn holdTeardownsFor(document: *runtime.Instance) engine.TeardownHold {
    return engine.holdTeardowns(document.ctx);
}

/// Helper: Run live range pre-remove steps
/// Spec: https://dom.spec.whatwg.org/#concept-node-remove steps 4-7
///
/// Each live range's boundary points are read once, through Range's
/// dom.range_boundaries steps, and kept current here as steps 4 and 5 move
/// them: Range's setters change nothing else, so steps 6 and 7 read what the
/// range now holds.
///
/// The ranges are walked through a cursor, never a slice: setting a
/// boundary redraws the range's edge to its node, an engine call that can
/// start a collection, and the collection's prologue tears down the ranges
/// collected before it - each leaving this list mid-walk
/// (live_range_list.zig; lane rangeuaf).
fn runLiveRangePreRemoveSteps(node: anytype) void {
    // Get the node's document to access the list of live ranges
    const doc_instance = nodeDocument(node) orelse return;

    // The document's live ranges
    const ranges = document_internals.liveRanges(doc_instance) orelse return;
    if (ranges.isEmpty()) return;

    // Get the parent and index for updating boundary points (a walk: only
    // when there are live ranges)
    const parent = node.parent_node orelse return;
    const index = getChildIndex(node) orelse return;
    const live = range_boundaries.liveRange() orelse return;
    const node_ptr: *const NodeBase = @ptrCast(node);

    // Iterate through all live ranges registered with this document
    const hold = holdTeardownsFor(doc_instance);
    defer hold.release();
    var walk: document_internals.LiveObjects.Walk = undefined;
    ranges.beginWalk(&walk);
    defer ranges.endWalk(&walk);
    while (walk.nextEntry()) |range| {
        var points = live.points(range) orelse continue;

        // Each boundary node is looked up once - the instance bridge is a
        // pure lookup, which nothing in these steps changes - and once for
        // both when the range starts and ends in one node (a collapsed range,
        // a selection's caret), which also asks step 5's question of step 4.
        const one_node = points.end_container != null and points.end_container == points.start_container;
        var start_base: ?*NodeBase = if (points.start_container) |start_node| instance_bridge.getNodeBase(start_node) else null;
        var end_base: ?*NodeBase = if (one_node) start_base else if (points.end_container) |end_node| instance_bridge.getNodeBase(end_node) else null;

        // Step 4: For each live range whose start node is an inclusive descendant of node,
        // set its start to (parent, index)
        const start_inside = if (start_base) |base| tree_helpers.isInclusiveDescendant(node_ptr, base) else false;
        if (start_inside) {
            // Cast parent to runtime.Instance
            if (instance_bridge.getInstance(parent)) |parent_instance| {
                const container: *runtime.Instance = @ptrCast(@alignCast(parent_instance));
                live.set_start(range, container, @intCast(index));
                points.start_container = container;
                points.start_offset = @intCast(index);
                start_base = instance_bridge.getNodeBase(container);
            }
        }

        // Step 5: For each live range whose end node is an inclusive descendant of node,
        // set its end to (parent, index)
        const end_inside = if (one_node) start_inside else if (end_base) |base| tree_helpers.isInclusiveDescendant(node_ptr, base) else false;
        if (end_inside) {
            // Cast parent to runtime.Instance
            if (instance_bridge.getInstance(parent)) |parent_instance| {
                const container: *runtime.Instance = @ptrCast(@alignCast(parent_instance));
                live.set_end(range, container, @intCast(index));
                points.end_container = container;
                points.end_offset = @intCast(index);
                end_base = instance_bridge.getNodeBase(container);
            }
        }

        // Step 6: For each live range whose start node is parent and start offset is greater than index,
        // decrease its start offset by 1
        if (start_base == parent and points.start_offset > index) {
            live.set_start_offset(range, @intCast(points.start_offset - 1));
        }

        // Step 7: For each live range whose end node is parent and end offset is greater than index,
        // decrease its end offset by 1
        if (end_base == parent and points.end_offset > index) {
            live.set_end_offset(range, @intCast(points.end_offset - 1));
        }
    }
}

/// Live range updates for "split a Text node", steps 7.2 through 7.5.
/// Spec: https://dom.spec.whatwg.org/#concept-text-split
///
/// Called by `Text.splitText` *after* `newNode` has been inserted into
/// `parent`. The insert algorithm's own step 5 has already shifted ranges whose
/// offset is strictly greater than newNode's index; these four steps are the
/// separate ones the split algorithm adds on top, and they do not overlap with
/// it: 7.4/7.5 match the single offset `index of node + 1` exactly.
///
/// Non-throwing. A node with no document, or a document with no registered
/// ranges, simply has nothing to update - the overwhelmingly common case.
///
/// `node` and `new_node` are `*runtime.Instance` for Text nodes, `parent` the
/// `*runtime.Instance` they now live under.
pub fn runLiveRangeSplitSteps(
    node: *runtime.Instance,
    new_node: *runtime.Instance,
    parent: *runtime.Instance,
    offset: u32,
) void {
    const doc = (interfaces.Node.get_ownerDocument(node) catch null) orelse return;
    const ranges = document_internals.liveRanges(doc) orelse return;
    if (ranges.isEmpty()) return;

    // Index of node in parent, for steps 7.4 and 7.5. Inserting newNode after
    // node does not move node, so this is the same index the spec means.
    const node_base_ptr = instance_bridge.getNodeBase(node) orelse return;
    const parent_base_ptr = instance_bridge.getNodeBase(parent) orelse return;
    const node_index_usize = tree_helpers.getChildIndex(parent_base_ptr, node_base_ptr) orelse return;
    const node_index: u32 = @intCast(node_index_usize);

    const live = range_boundaries.liveRange() orelse return;
    // Through a cursor: 7.2 and 7.3 redraw a range's edges, which can tear
    // collected ranges down mid-walk (runLiveRangePreRemoveSteps).
    const hold = holdTeardownsFor(doc);
    defer hold.release();
    var walk: document_internals.LiveObjects.Walk = undefined;
    ranges.beginWalk(&walk);
    defer ranges.endWalk(&walk);
    while (walk.nextEntry()) |range| {
        // Read once, and kept current as 7.2 and 7.3 move the points.
        var points = live.points(range) orelse continue;

        // Step 7.2: start node is node and start offset > offset ->
        // move the boundary to newNode, rebased.
        if (points.start_container == node) {
            if (points.start_offset > offset) {
                live.set_start(range, new_node, points.start_offset - offset);
                points.start_container = new_node;
                points.start_offset -= offset;
            }
        }

        // Step 7.3: same for the end boundary.
        if (points.end_container == node) {
            if (points.end_offset > offset) {
                live.set_end(range, new_node, points.end_offset - offset);
                points.end_container = new_node;
                points.end_offset -= offset;
            }
        }

        // Step 7.4: start node is parent and start offset == node's index + 1.
        // The container as 7.2 left it: a boundary it moved to newNode is not
        // on parent, so it cannot match here.
        if (points.start_container == parent) {
            if (points.start_offset == node_index + 1) {
                live.set_start_offset(range, points.start_offset + 1);
            }
        }

        // Step 7.5: same for the end boundary.
        if (points.end_container == parent) {
            if (points.end_offset == node_index + 1) {
                live.set_end_offset(range, points.end_offset + 1);
            }
        }
    }
}

/// Where "replace data" steps 8-11 move a boundary offset `bp_offset` in
/// the replaced node: into `offset` when it fell inside the replaced code
/// units, shifted by what was inserted less what was removed when it lay
/// after them, unchanged otherwise.
pub fn replaceDataBoundaryOffset(bp_offset: u32, offset: u32, count: u32, data_length: u32) u32 {
    // Steps 8 and 9: "greater than offset but less than or equal to offset
    // + count: set its offset to offset."
    if (bp_offset > offset and bp_offset <= offset + count) return offset;
    // Steps 10 and 11: "greater than offset + count: increase its offset by
    // data's length and decrease it by count."
    if (bp_offset > offset + count) return bp_offset + data_length - count;
    return bp_offset;
}

/// DOM "replace data" steps 8-11, for the live ranges of `node`'s node
/// document: each boundary point in `node` follows the replaced code units.
/// Run after steps 5-7 have changed the data, with `count` already clamped by
/// step 3, so every new offset is within the node's new length.
///
/// Spec: https://dom.spec.whatwg.org/#concept-cd-replace
///
/// The boundary points are read through `range_boundaries` and written
/// through Range's own setStart/setEnd. A start is written before its end;
/// the offsets keep their order (the map above never reverses two offsets),
/// so setStart's "bp is after the range's end" collapse, when an insertion
/// carries the start past the old end, is undone by the setEnd that follows.
pub fn runLiveRangeReplaceDataSteps(node: *runtime.Instance, offset: u32, count: u32, data_length: u32) void {
    const doc = (interfaces.Node.get_ownerDocument(node) catch null) orelse return;
    const ranges = document_internals.liveRanges(doc) orelse return;
    if (ranges.isEmpty()) return;
    // Through a cursor: a setter's engine calls can tear collected ranges
    // down mid-walk (runLiveRangePreRemoveSteps).
    const hold = holdTeardownsFor(doc);
    defer hold.release();
    var walk: document_internals.LiveObjects.Walk = undefined;
    ranges.beginWalk(&walk);
    defer ranges.endWalk(&walk);
    while (walk.nextEntry()) |range| {
        const bp = range_boundaries.of(range) orelse continue;
        if (bp.start_container == node) {
            const moved = replaceDataBoundaryOffset(bp.start_offset, offset, count, data_length);
            if (moved != bp.start_offset) interfaces.Range.call_setStart(range, node, moved) catch {};
        }
        if (bp.end_container == node) {
            const moved = replaceDataBoundaryOffset(bp.end_offset, offset, count, data_length);
            if (moved != bp.end_offset) interfaces.Range.call_setEnd(range, node, moved) catch {};
        }
    }
}

/// DOM normalize() steps 6.1-6.4, for `current`, one of `node`'s contiguous
/// exclusive Text nodes whose data node now ends with, starting at `length`:
/// every boundary point in current, or at current's place in its parent,
/// moves into node. Run before current is removed (step 7), so the live
/// range pre-remove steps then find nothing of these ranges left in it.
///
/// Spec: https://dom.spec.whatwg.org/#dom-node-normalize
///
/// A start moved into node is before any end still in current or at a later
/// point of the parent, so setStart never collapses the range here.
pub fn runLiveRangeNormalizeSteps(node: *runtime.Instance, current: *runtime.Instance, length: u32) void {
    const doc = (interfaces.Node.get_ownerDocument(node) catch null) orelse return;
    const ranges = document_internals.liveRanges(doc) orelse return;
    if (ranges.isEmpty()) return;

    // currentNode's parent and index, for steps 6.3 and 6.4.
    const parent = interfaces.Node.get_parentNode(current) catch null;
    const index: ?u32 = blk: {
        var i: u32 = 0;
        var sibling = interfaces.Node.get_previousSibling(current) catch null;
        while (sibling) |s| : (sibling = interfaces.Node.get_previousSibling(s) catch null) i += 1;
        break :blk i;
    };

    // Through a cursor: setStart and setEnd redraw a range's edges, which
    // can tear collected ranges down mid-walk (runLiveRangePreRemoveSteps).
    const hold = holdTeardownsFor(doc);
    defer hold.release();
    var walk: document_internals.LiveObjects.Walk = undefined;
    ranges.beginWalk(&walk);
    defer ranges.endWalk(&walk);
    while (walk.nextEntry()) |range| {
        const bp = range_boundaries.of(range) orelse continue;
        // Step 6.1: "For each live range whose start node is currentNode: add
        // length to its start offset and set its start node to node."
        if (bp.start_container == current) {
            interfaces.Range.call_setStart(range, node, bp.start_offset + length) catch {};
        }
        // Step 6.2: "For each live range whose end node is currentNode: add
        // length to its end offset and set its end node to node."
        if (bp.end_container == current) {
            interfaces.Range.call_setEnd(range, node, bp.end_offset + length) catch {};
        }
        // Step 6.3: "For each live range whose start node is currentNode's
        // parent and start offset is currentNode's index: set its start node
        // to node and its start offset to length."
        if (parent != null and bp.start_container == parent.? and bp.start_offset == index.?) {
            interfaces.Range.call_setStart(range, node, length) catch {};
        }
        // Step 6.4: "For each live range whose end node is currentNode's
        // parent and end offset is currentNode's index: set its end node to
        // node and its end offset to length."
        if (parent != null and bp.end_container == parent.? and bp.end_offset == index.?) {
            interfaces.Range.call_setEnd(range, node, length) catch {};
        }
    }
}

test "replace data moves a boundary inside the replaced units to offset, and one after them by the difference" {
    // "abcdef", replace 2 units at 1 with "XYZ" -> "aXYZdef".
    try std.testing.expectEqual(@as(u32, 0), replaceDataBoundaryOffset(0, 1, 2, 3));
    try std.testing.expectEqual(@as(u32, 1), replaceDataBoundaryOffset(1, 1, 2, 3));
    try std.testing.expectEqual(@as(u32, 1), replaceDataBoundaryOffset(2, 1, 2, 3));
    try std.testing.expectEqual(@as(u32, 1), replaceDataBoundaryOffset(3, 1, 2, 3));
    try std.testing.expectEqual(@as(u32, 5), replaceDataBoundaryOffset(4, 1, 2, 3));
    try std.testing.expectEqual(@as(u32, 7), replaceDataBoundaryOffset(6, 1, 2, 3));
    // Deleting everything ("data = ''" on "abc"): every offset goes to 0.
    try std.testing.expectEqual(@as(u32, 0), replaceDataBoundaryOffset(3, 0, 3, 0));
    // Appending (offset = length, count 0): nothing moves.
    try std.testing.expectEqual(@as(u32, 3), replaceDataBoundaryOffset(3, 3, 0, 5));
}

/// Helper: Run NodeIterator pre-remove steps for all iterators
/// Spec: https://dom.spec.whatwg.org/#nodeiterator-pre-removing-steps
fn runNodeIteratorPreRemoveSteps(node: anytype) void {
    // Get the node's document to access the list of NodeIterators
    const doc_instance = nodeDocument(node) orelse return;

    // The document's NodeIterators
    const iterators = document_internals.nodeIterators(doc_instance) orelse return;
    if (iterators.isEmpty()) return;

    // Get the node as a runtime.Instance for passing to NodeIterator.preRemoveSteps
    const node_base_ptr: *NodeBase = @ptrCast(node);
    const node_instance = instance_bridge.getInstance(node_base_ptr) orelse return;
    const node_runtime: *runtime.Instance = @ptrCast(@alignCast(node_instance));

    // For each NodeIterator object iterator whose root's node document is node's node document,
    // run the NodeIterator pre-removing steps given node and iterator.
    // Through a cursor: a new reference redraws the iterator's edge to it,
    // an engine call that can tear collected iterators down mid-walk, each
    // leaving this list (runLiveRangePreRemoveSteps).
    const hold = holdTeardownsFor(doc_instance);
    defer hold.release();
    var walk: document_internals.LiveObjects.Walk = undefined;
    iterators.beginWalk(&walk);
    defer iterators.endWalk(&walk);
    while (walk.nextEntry()) |iterator| {
        @import("traversal.zig").preRemoveNodeIterator(iterator, node_runtime);
    }
}

/// Helper: Update ranges when inserting before child
fn updateRangesForInsertion(doc: anytype, parent: anytype, child_index: usize) void {
    updateRangesForInsertionWithCount(doc, parent, child_index, 1);
}

/// Helper: Update ranges when inserting multiple nodes before child
/// Spec: https://dom.spec.whatwg.org/#concept-node-insert step 5
/// For each live range whose start/end node is parent and offset > child_index,
/// increase offset by count
fn updateRangesForInsertionWithCount(doc: anytype, parent: anytype, child_index: usize, count: usize) void {
    // Cast document to runtime.Instance
    const doc_instance: *runtime.Instance = @ptrCast(@alignCast(doc));

    // The document's live ranges
    const ranges = document_internals.liveRanges(doc_instance) orelse return;

    // Get parent as a pointer for comparison
    const parent_base: *const NodeBase = @ptrCast(parent);

    if (ranges.isEmpty()) return;
    const live = range_boundaries.liveRange() orelse return;

    // For each live range, update offsets if necessary - through a cursor,
    // like every walk of the list (runLiveRangePreRemoveSteps).
    const hold = holdTeardownsFor(doc_instance);
    defer hold.release();
    var walk: document_internals.LiveObjects.Walk = undefined;
    ranges.beginWalk(&walk);
    defer ranges.endWalk(&walk);
    while (walk.nextEntry()) |range| {
        // Get range boundary points (an offset change moves no container),
        // and their nodes - one lookup when the range starts and ends in one
        // node, as in the pre-remove steps.
        const points = live.points(range) orelse continue;
        const start_base: ?*NodeBase = if (points.start_container) |start_node| instance_bridge.getNodeBase(start_node) else null;
        const end_base: ?*NodeBase = if (points.end_container) |end_node|
            (if (points.start_container == end_node) start_base else instance_bridge.getNodeBase(end_node))
        else
            null;

        // For each live range whose start node is parent and start offset is greater than child's index,
        // increase its start offset by count.
        if (start_base == parent_base and points.start_offset > child_index) {
            live.set_start_offset(range, @intCast(points.start_offset + count));
        }

        // For each live range whose end node is parent and end offset is greater than child's index,
        // increase its end offset by count.
        if (end_base == parent_base and points.end_offset > child_index) {
            live.set_end_offset(range, @intCast(points.end_offset + count));
        }
    }
}

/// Move step 13: `node` leaves `old_parent`'s children - the sibling links
/// and both ends (the links are the children: NodeBase.children), as
/// removeHeld's step 7. Its parent link stays until linkForMove
/// (refcount.moveChild writes it there with the counts): see `move`.
fn unlinkForMove(node: *NodeBase, old_parent: *NodeBase) void {
    old_parent.unlinkChild(node);
}

/// Move steps 20-21: `node` joins `new_parent`'s children before `child`
/// (null: at the end) - the sibling links and both ends, as insertWith's
/// step 7.2-7.3 - with the parent write and the counts moved
/// from `old_parent`'s tree to `new_parent`'s in one step (refcount.moveChild:
/// the new chain gains first, so no total passes through zero), and a wrapped
/// node's opaque root and tree edges following it: it leaves its old
/// parent's and joins its new one's (refcount design section 7 step 4).
fn linkForMove(node: *NodeBase, old_parent: *NodeBase, new_parent: *NodeBase, child: ?*NodeBase) void {
    new_parent.linkChildBefore(node, child);
    refcount.moveChild(node, new_parent);
    if (old_parent != new_parent) {
        leftTree(node, old_parent);
        joinedTree(node, new_parent);
    }
}

/// Node tracing's opaque root follows the tree (refcount design 2.2, section 7
/// step 4): `node` - the root of a subtree just linked under `parent` - joins
/// `parent`'s opaque root, if it has a wrapper. Only for an engine that
/// emulates wrapper tracing with edges (engine.capabilities.wrapper_tracing
/// == .emulated): one that traces natively - V8 since the wrapper redesign's
/// P7 - finds a tree's wrappers from its nodes while it marks, so the call
/// compiles out there (tmp/redesign/wrapper-redesign-design.md 3.3). One
/// field test (the engine's wrapper slot on NodeBase, `wrapper.isEmpty()`),
/// so a parse or an innerHTML of unwrapped nodes never calls the engine;
/// only the subtree's root changes trees, so its descendants are not visited
/// (the adapter's insertion-steps hook visited and looked up each one).
fn joinedTree(node: *NodeBase, parent: *NodeBase) void {
    if (engine.capabilities.wrapper_tracing != .emulated) return;
    if (node.wrapper.isEmpty()) return;
    const member = instance_bridge.getInstance(node) orelse return;
    const owner = instance_bridge.getInstance(parent) orelse return;
    engine.joinOpaqueRoot(@ptrCast(@alignCast(member)), @ptrCast(@alignCast(owner)));
}

/// `node` - the root of a subtree just unlinked from `old_parent` - leaves
/// its old tree's opaque root and is a root of its own, if it has a wrapper
/// (an `.emulated` engine's only, as `joinedTree`).
fn leftTree(node: *NodeBase, old_parent: *NodeBase) void {
    if (engine.capabilities.wrapper_tracing != .emulated) return;
    if (node.wrapper.isEmpty()) return;
    const member = instance_bridge.getInstance(node) orelse return;
    const owner = instance_bridge.getInstance(old_parent) orelse return;
    engine.leaveOpaqueRoot(@ptrCast(@alignCast(member)), @ptrCast(@alignCast(owner)));
}

/// After a tree left `old_document`: every live range of `old_document`
/// moves to its start node's document if that is no longer this one. Moving
/// a range removes it from this list, which the walk's cursor allows for
/// (Blink's DidMoveTreeToNewDocument copies ranges_ for the same reason; a
/// copy here would also hold ranges a teardown frees mid-walk).
fn moveLiveRangesAfterAdoption(old_document: *runtime.Instance) void {
    const ranges = document_internals.liveRanges(old_document) orelse return;
    if (ranges.isEmpty()) return;
    const hold = holdTeardownsFor(old_document);
    defer hold.release();
    var walk: document_internals.LiveObjects.Walk = undefined;
    ranges.beginWalk(&walk);
    defer ranges.endWalk(&walk);
    while (walk.nextEntry()) |range| {
        range_boundaries.updateOwnerDocument(range) catch {};
    }
}

/// Move step 25: "For each shadow-including inclusive descendant
/// inclusiveDescendant of node, in shadow-including tree order: 1. Let
/// isSubtreeRoot be true if inclusiveDescendant is node; otherwise false.
/// 2. Run the moving steps with inclusiveDescendant, isSubtreeRoot, and
/// oldParent. 3. If inclusiveDescendant is custom and newParent is
/// connected, then enqueue a custom element callback reaction with
/// inclusiveDescendant, callback name "connectedMoveCallback", and « »."
///
/// The moving-steps callbacks receive oldParent for the subtree root and
/// null for every descendant: isSubtreeRoot and oldAncestor in one argument
/// (the HTML moving steps of option, selectedcontent, img and source read
/// oldAncestor only when isSubtreeRoot is true).
fn runMovingStepsForTree(node: *NodeBase, old_parent: *NodeBase, new_parent_connected: bool) void {
    var descendants = tree_helpers.getShadowIncludingInclusiveDescendants(node.allocator(), node) catch {
        // No room for the list: the same steps over the light tree, without
        // its shadow trees, rather than none.
        runMovingStepsOn(node, old_parent, new_parent_connected);
        var current = node.first_child;
        while (current) |descendant| {
            runMovingStepsOn(descendant, null, new_parent_connected);
            current = nextInSubtree(descendant, node);
        }
        return;
    };
    defer descendants.deinit();
    for (descendants.toSlice(), 0..) |descendant, i| {
        runMovingStepsOn(descendant, if (i == 0) old_parent else null, new_parent_connected);
    }
}

/// The node after `current` in `root`'s light subtree, in tree order.
fn nextInSubtree(current: *NodeBase, root: *NodeBase) ?*NodeBase {
    if (current.first_child) |first| return first;
    var at = current;
    while (at != root) {
        if (at.next_sibling) |next| return next;
        at = at.parent_node orelse return null;
    }
    return null;
}

/// Move steps 25.2-25.3 for one shadow-including inclusive descendant.
fn runMovingStepsOn(descendant: *NodeBase, old_parent: ?*NodeBase, new_parent_connected: bool) void {
    runMovingSteps(descendant, old_parent);
    if (new_parent_connected) enqueueCustomElementCallback(descendant, .connected_move, .none);
}

fn hasCustomElementDefinitions(node: anytype) bool {
    const object = instance_bridge.getInstance(@ptrCast(node)) orelse return false;
    const instance: *runtime.Instance = @ptrCast(@alignCast(object));
    return custom_elements.hasDefinitions(instance.ctx);
}

fn instanceOfNode(node: ?*NodeBase) ?*runtime.Instance {
    const object = instance_bridge.getInstance(node orelse return null) orelse return null;
    return @ptrCast(@alignCast(object));
}

/// HTML's element insertion, removing and moving steps reset the form owner
/// (4.10.18.3); for form-associated custom elements that reset is kept
/// (formAssociatedCallback), and runs only over what the mutation reached.
fn formSubtreeMoved(node: *NodeBase, old_parent: ?*NodeBase, new_parent: ?*NodeBase) void {
    custom_elements.formSubtreeMoved(instanceOfNode(node) orelse return, instanceOfNode(old_parent), instanceOfNode(new_parent));
}

fn runCustomElementInsertionSteps(node: *NodeBase) void {
    if (!node.is_connected) return;
    const object = instance_bridge.getInstance(node) orelse return;
    const instance: *runtime.Instance = @ptrCast(@alignCast(object));
    const registry = if (node.node_type == ELEMENT_NODE)
        interfaces.Element.get_customElementRegistry(instance) catch null
    else if (instance.stateAs(interfaces.ShadowRoot.State) != null)
        interfaces.ShadowRoot.get_customElementRegistry(instance) catch null
    else
        null;
    // DOM insert 7.7.3.1 / 7.7.4: a scoped registry remembers this document.
    if (registry) |value| {
        if (custom_elements.isScoped(value)) {
            if (interfaces.Node.get_ownerDocument(instance) catch null) |document| custom_elements.associateDocument(value, document) catch {};
        }
    }
    if (node.node_type != ELEMENT_NODE) return;
    const data = custom_elements.get(instance) orelse return;
    // DOM insert 7.7.3.2: a custom element gets connectedCallback.
    //
    // Deviation from the cached spec text, stated (CE2-S3; the user's
    // browsers-first rule, 2026-10-08): specs/whatwg/dom.md insert step
    // 7.7.3 enqueues it only when the element's custom element registry is
    // non-null, and an element adopted into a document with no registry
    // (new Document(), createHTMLDocument) has a null one. Chrome 157, Edge
    // 157 and Firefox 159 enqueue it whatever the registry
    // (custom-elements/connected-callbacks.html 40/40 and
    // adopted-callback.html 71/71 on wpt.fyi stable/experimental; Crane had
    // 15/40 and 16/71), and the question is open upstream - so a custom
    // element is connected whatever its registry. The scoped-document-set
    // append above and the try-to-upgrade below stay gated on a registry
    // (with none there is no definition to find).
    if (data.state == .custom) {
        custom_elements.enqueueCallback(instance, .connected, .none);
    } else if (registry != null) {
        custom_elements.tryUpgrade(instance);
    }
}

fn enqueueCustomElementCallback(node: anytype, kind: custom_elements.CallbackType, args: custom_elements.CallbackArgs) void {
    if (node.node_type != ELEMENT_NODE) return;
    const object = instance_bridge.getInstance(@ptrCast(node)) orelse return;
    custom_elements.enqueueCallback(@ptrCast(@alignCast(object)), kind, args);
}

/// Helper: Run moving steps hook for a node
/// Spec: Moving steps are defined by specifications
/// Called during the move algorithm for each shadow-including descendant
fn runMovingSteps(node: *NodeBase, old_parent: ?*NodeBase) void {
    for (moving_steps_callbacks.read().slice()) |callback| {
        callback(node, old_parent);
    }
}

/// DOM §4.2.5 - Adopt
/// Spec: https://dom.spec.whatwg.org/#concept-node-adopt
///
/// To adopt a node into a document:
/// 1. Let oldDocument be node's node document
/// 2. If node's parent is non-null, then remove node
/// 3. If document is not oldDocument:
///    a. For each shadow-including inclusive descendant:
///       - Set its node document to document
///       - If element, update attribute node documents
///    b. For each shadow-including inclusive descendant that is custom:
///       - Enqueue adoptedCallback reaction (future)
///    c. Run adopting steps for each descendant (future)
pub fn adopt(
    node: anytype,
    document: anytype,
) DOMException!void {
    try adoptHeld(node, document);
    refcount.endRemovalHold(@ptrCast(node));
}

/// `adopt`, leaving the hold of its step 2's removal on `node` for the
/// insertion that adopts it to end at its link (refcount.linkChild): the
/// adopting steps run in between (an img's update of the image data takes
/// the node on), and the moved tree must not count zero there.
fn adoptHeld(
    node: anytype,
    document_any: anytype,
) DOMException!void {
    // The document, as its own NodeBase: what NodeBase.getNodeDocument and
    // documentBase answer. A caller that names it as `*interfaces.Document`
    // names the same address.
    const document: *NodeBase = @ptrCast(@alignCast(document_any));
    // Step 1: Let oldDocument be node's node document (its own NodeBase;
    // null for none, and for one freed under the node - NodeBase.documentBase)
    const oldDocument: ?*NodeBase = node.documentBase();

    // Step 2: If node's parent is non-null, then remove node
    if (node.parent_node != null) {
        try removeHeld(node, false);
    }
    errdefer refcount.endRemovalHold(@ptrCast(node));

    // Step 3: If document is not oldDocument
    if (@as(?*NodeBase, document) != oldDocument) {
        // Step 3.1: Collect the shadow-including inclusive descendants in
        // tree order, including closed shadow roots and their descendants.
        var descendants = try tree_helpers.getShadowIncludingInclusiveDescendants(node.allocator(), node);
        defer descendants.deinit();

        // The node document is also held by each node's Node state, which
        // the ownerDocument getter and everything outside src/dom read; the
        // node_document hook keeps that copy - and through it this one - in
        // step.
        const document_instance: ?*runtime.Instance = if (instance_bridge.getInstance(document)) |opaque_instance|
            @ptrCast(@alignCast(opaque_instance))
        else
            null;

        // Step 3.1: For each shadow-including inclusive descendant in tree order
        for (0..descendants.len) |idx| {
            const desc = descendants.get(idx) orelse continue;

            // Step 3.1.1: Set node document to document. A platform node's
            // is set by the node_document hook below (the Node impl's setter,
            // which also moves the node between the documents' counts and
            // must see the OLD document still named: the word is one, since
            // lane nm1); an owner-less node's is written here.
            if (document_instance == null or instance_bridge.getInstance(desc) == null) desc.setDocumentBase(document);
            if (document_instance) |doc_instance| {
                if (instance_bridge.getInstance(desc)) |desc_opaque| {
                    const desc_instance: *runtime.Instance = @ptrCast(@alignCast(desc_opaque));
                    node_document.set(desc_instance, doc_instance) catch {};
                    // DOM adopt 3.2–3.3: scoped associations survive; global
                    // associations follow the new document's effective global.
                    const target_registry = interfaces.Document.get_customElementRegistry(doc_instance) catch null;
                    if (desc_instance.stateAs(interfaces.ShadowRoot.State) != null) {
                        const old_registry = interfaces.ShadowRoot.get_customElementRegistry(desc_instance) catch null;
                        const replace_registry = if (old_registry) |value| !custom_elements.isScoped(value) else !custom_elements.shadowKeepsRegistryNull(desc_instance);
                        if (replace_registry) custom_elements.setShadowRegistry(desc_instance, custom_elements.effectiveGlobal(target_registry)) catch {};
                    } else if (desc.node_type == ELEMENT_NODE) {
                        const old_registry = interfaces.Element.get_customElementRegistry(desc_instance) catch null;
                        if (old_registry == null or !custom_elements.isScoped(old_registry.?)) {
                            var registry = target_registry;
                            if (old_registry == null) {
                                if (desc.parent_node) |parent| {
                                    if (instance_bridge.getInstance(parent)) |parent_opaque| {
                                        const parent_instance: *runtime.Instance = @ptrCast(@alignCast(parent_opaque));
                                        if (parent.node_type == ELEMENT_NODE) registry = interfaces.Element.get_customElementRegistry(parent_instance) catch null else if (parent_instance.stateAs(interfaces.ShadowRoot.State) != null) registry = interfaces.ShadowRoot.get_customElementRegistry(parent_instance) catch null;
                                    }
                                }
                            }
                            custom_elements.setElementRegistry(desc_instance, custom_elements.effectiveGlobal(registry)) catch {};
                        } else custom_elements.associateDocument(old_registry.?, doc_instance) catch {};
                    }
                }
            }

            // Step 3.1.2: If element, update attribute node documents
            if (desc.node_type == ELEMENT_NODE) {
                // Access element attributes via ElementWithBase.
                //
                // @fieldParentPtr, NOT @ptrCast. ElementWithBase is a plain struct,
                // so Zig's auto layout does not guarantee `base` sits at offset 0 no
                // matter what the "MUST be the first field" comment on it says - it
                // orders by alignment. @fieldParentPtr computes the real offset.
                // The bare cast read element.attributes from the wrong address, whose
                // garbage length then drove List.get into out-of-bounds access
                // (caught by UBSan at infra/list.zig:197 via this exact path).
                // ONLY parser-created elements embed their NodeBase in an
                // ElementWithBase (element_with_base.zig: `.base = NodeBase{...}`).
                // WebIDL-created ones keep a STANDALONE NodeBase in Node's state
                // (impls/Node.zig: `InternalState.base`) and keep their
                // attributes elsewhere entirely, so there is no ElementWithBase to
                // recover - @fieldParentPtr is as wrong as @ptrCast was, it just
                // computes a different wrong address.
                //
                // node_type == ELEMENT_NODE does NOT distinguish them. ownerInstance()
                // does: instance_bridge.register is called only on the WebIDL path,
                // so a non-null owner means "standalone, not embedded". Reading
                // `attributes` off a standalone NodeBase yielded a garbage length,
                // which drove infra.List.get out of bounds (UBSan: list.zig:197).
                if (desc.ownerInstance() == null) {
                    const element: *element_with_base.ElementWithBase = @fieldParentPtr("base", desc);
                    for (0..element.attributes.size()) |attr_idx| {
                        if (element.attributes.get(attr_idx)) |attr| {
                            attr.base.setDocumentBase(document);
                        }
                    }
                } else if (document_instance) |doc_instance| {
                    // A platform element keeps its attributes in its own
                    // state and makes an Attr node only when script asks for
                    // one: each it made follows it (its document edge with
                    // it, so the old document is let go), and an attribute
                    // with none gets none - adopting a tree allocates nothing
                    // for attributes script never touched.
                    const element: *runtime.Instance = @ptrCast(@alignCast(desc.ownerInstance().?));
                    for (0..element_attributes.count(element)) |attr_idx| {
                        const attr = element_attributes.existingNodeAt(element, attr_idx) orelse continue;
                        node_document.set(attr, doc_instance) catch {};
                    }
                }
            }
        }

        // Blink's Document::DidMoveTreeToNewDocument: each of the old
        // document's live ranges re-checks which document it belongs to, so
        // a range whose boundary moved with the tree follows it.
        if (oldDocument) |old_document| {
            if (instance_bridge.getInstance(old_document)) |old_opaque| {
                moveLiveRangesAfterAdoption(@ptrCast(@alignCast(old_opaque)));
            }
        }

        // Step 3.2.3: adoptedCallback receives the old and new documents in
        // shadow-including tree order. Queued arguments retain both documents.
        if (oldDocument) |old_document| {
            if (instance_bridge.getInstance(old_document)) |old_opaque| {
                if (document_instance) |new_document| {
                    for (descendants.toSlice()) |descendant| enqueueCustomElementCallback(descendant, .adopted, .{
                        .adopted = .{ .old_document = @ptrCast(@alignCast(old_opaque)), .new_document = new_document },
                    });
                }
            }
        }

        // DOM adopt, step 3.4: template contents are a separate hosted tree,
        // so updating the ordinary descendants above does not reach them.
        for (descendants.toSlice()) |desc| {
            if (instance_bridge.getInstance(desc)) |opaque_instance| {
                @import("template_contents.zig").adopted(@ptrCast(@alignCast(opaque_instance))) catch |err| {
                    return if (err == error.OutOfMemory) error.OutOfMemory else error.NotSupportedError;
                };
            }
        }

        // DOM adopt, step 3.4: "Run the adopting steps with
        // inclusiveDescendant and oldDocument" - the other types' (an img's
        // is a relevant mutation that updates its image data), once every
        // node document has changed. They schedule work; none runs script.
        const old_document_instance: ?*runtime.Instance = if (oldDocument) |old_document|
            if (instance_bridge.getInstance(@ptrCast(@alignCast(old_document)))) |old_opaque| @ptrCast(@alignCast(old_opaque)) else null
        else
            null;
        for (descendants.toSlice()) |desc| {
            if (desc.node_type != ELEMENT_NODE) continue;
            if (instance_bridge.getInstance(desc)) |opaque_instance| {
                @import("adopting_steps.zig").run(@ptrCast(@alignCast(opaque_instance)), old_document_instance);
            }
        }
    }

    if (refcount.treeChecksOn()) refcount.checkAround(@ptrCast(node));
}

test "a callback registered twice runs once" {
    const Counter = struct {
        var calls: usize = 0;
        fn childrenChanged(_: *NodeBase, _: ChildrenChange) void {
            calls += 1;
        }
    };
    const override = children_changed_callbacks.overrideForTest(.empty);
    defer override.restore();

    try registerChildrenChangedCallback(&Counter.childrenChanged);
    try registerChildrenChangedCallback(&Counter.childrenChanged);
    var parent: NodeBase = .{
        .owner = NodeBase.ownerless(&std.testing.allocator),
        .node_type = NodeBase.DOCUMENT_FRAGMENT_NODE,
    };
    runChildrenChangedSteps(&parent, .inserted);
    try std.testing.expectEqual(@as(usize, 1), Counter.calls);
}
