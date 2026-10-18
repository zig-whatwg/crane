//! DOM 2.9 "dispatch", steps 4-6.11: build an event's path - the items
//! "append to an event path" makes, each with its shadow-adjusted target,
//! retargeted relatedTarget and touch targets and its three shadow-tree
//! booleans - and find the activation target and clearTargets on the way.
//! EventTarget's dispatch runs the rest (the invoke passes and steps 7-13).
//!
//! Spec: https://dom.spec.whatwg.org/#concept-event-dispatch
//!
//! THE WALK. The standard walks "get the parent" from the target and tests,
//! for every parent, whether "target's root is a shadow-including inclusive
//! ancestor of parent" (step 6.9.6). Blink and WebKit answer that from a
//! TreeScope pointer every node carries (EventPath::CalculatePath and
//! CalculateAdjustedTargets; EventPath::buildPath). A Crane node has none -
//! its root is a walk up its parent chain - so this walk recovers the tree
//! scopes from the moves it makes. "Get the parent" moves in one of three
//! ways:
//!
//!   (a) a node to its parent, in the same tree;
//!   (b) an assigned slottable to its assigned slot - a slot in the shadow
//!       tree of the slottable's parent, so one tree deeper;
//!   (c) a shadow root to its host - back to the tree the walk entered that
//!       shadow tree from.
//!
//! `depth` counts (b) moves less (c) moves since dispatch's `target` was last
//! set. Neither (a) nor (b) ever leaves the shadow-including inclusive
//! descendants of the scope the walk is in, and a (c) at depth > 0 returns to
//! a scope the walk was in before. So the walk is outside target's root's
//! shadow-including inclusive descendants exactly when it takes a (c) at
//! depth 0 - leaving target's own tree for its root's host - and step 6.9.6
//! is false exactly there (6.9.7 and 6.9.8 run only there). The Zig test
//! tests/dom/ev1_event_path_differential_test.zig pins this against a
//! literal implementation of the steps, one root walk per step, over
//! thousands of random trees.
//!
//! The same counting answers the item booleans without walking to roots:
//! an item appended at depth > 0 is in a shadow tree (the walk entered its
//! tree through a slot). The depth-0 tree's kind is known when the walk
//! reaches its root (it takes a (c) from it, or ends there), and if that
//! root is a shadow root, every item since that tree's first one is in a
//! shadow tree - in it, or deeper. And retargeting against a parent depends
//! only on the parent's root, so relatedTarget and the touch targets are
//! retargeted only when a move changes the tree: (b), (c) and the Window.
//! A path with no shadow root does one retarget for a null relatedTarget
//! and nothing else.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const infra = @import("infra");

const NodeBase = @import("node_base.zig").NodeBase;
const event_dispatch = @import("event_dispatch.zig");
const EventState = event_dispatch.EventState;
const PathItem = event_dispatch.PathItem;
const retarget = @import("retarget.zig");
const slot_helpers = @import("slot_helpers.zig");
const activation = @import("activation.zig");
const indexeddb = @import("indexeddb.zig");

/// Guard against a cycle in parent pointers turning dispatch into a hang.
/// No real tree is anywhere near this deep.
pub const max_event_path_length: usize = 8192;

/// What the path depends on besides the target and the event's state.
pub const Input = struct {
    /// The event's type: Document's get the parent returns null for "load".
    event_type: []const u8,
    /// The event's composed flag: a shadow root's get the parent returns
    /// null for an event without it at the root of its target.
    composed: bool,
    /// The event's bubbles attribute (step 6.9.6.1).
    bubbles: bool,
    /// Non-null exactly when the event is an activation event (step 6.4: a
    /// MouseEvent whose type is "click"): the activation behaviour an
    /// EventTarget has, or null - dom.activation.of.
    activation_of: ?*const fn (target: *runtime.Instance) ?activation.Behavior = null,
};

/// An activation target and its behaviour.
pub const ActivationTarget = struct {
    target: *runtime.Instance,
    behavior: activation.Behavior,
};

/// What steps 3-6.11 leave besides the path.
pub const Result = struct {
    /// activationTarget (steps 3, 6.5, 6.9.6.1, 6.9.8.2).
    activation_target: ?ActivationTarget = null,
    /// clearTargets (steps 5, 6.10-6.11).
    clear_targets: bool = false,
};

/// The three kinds of move "get the parent" makes (see THE WALK), and the
/// moves out of the node trees: to the Window, and between the non-node
/// targets IndexedDB chains.
const Move = enum { tree, slot, host, window, other };

const Parent = struct {
    instance: *runtime.Instance,
    node: ?*NodeBase,
    move: Move,
};

/// The walk's state between steps.
const Walk = struct {
    state: *EventState,
    input: Input,
    /// The relatedTarget the event had when dispatch began.
    event_related: ?*runtime.Instance,
    /// Dispatch's `relatedTarget`, retargeted against the current parent.
    related: ?*runtime.Instance,
    /// Dispatch's `touchTargets`, retargeted against the current parent.
    touch_targets: infra.List(*runtime.Instance),
    /// Dispatch's `target`.
    target: *runtime.Instance,
    /// (b) moves less (c) moves since `target` was last set.
    depth: usize = 0,
    /// Index of the first item of the depth-0 tree, whose kind is not yet
    /// known.
    scope_start: usize = 0,
    /// Whether 6.9.8 has run: until it has, the depth-0 tree is the target's
    /// own, whose root is the root of path[0]'s invocation target.
    left_target_tree: bool = false,
    /// Index of the last item with a non-null shadow-adjusted target.
    last_target_index: usize = 0,
    result: Result = .{},

    fn allocator(self: *const Walk) std.mem.Allocator {
        return self.state.allocator;
    }

    /// "Append to an event path" with event, invocationTarget,
    /// shadowAdjustedTarget, relatedTarget, touchTargets and
    /// slotInClosedTree. invocation-target-in-shadow-tree is known here for
    /// an item deeper than the depth-0 tree, and filled in for the depth-0
    /// tree's items once its root is reached (`resolveScope`).
    fn append(self: *Walk, invocation_target: *runtime.Instance, node: ?*NodeBase, shadow_adjusted: ?*runtime.Instance, slot_in_closed_tree: bool) !void {
        var touch = infra.List(*runtime.Instance).init(self.allocator());
        errdefer touch.deinit();
        if (self.touch_targets.len > 0) try touch.appendSlice(self.touch_targets.toSlice());
        // Steps 1-2: invocationTargetInShadowTree - "invocationTarget is a
        // node and its root is a shadow root".
        const in_shadow_tree = node != null and self.depth > 0;
        // Steps 3-4: rootOfClosedTree - "invocationTarget is a shadow root
        // whose mode is closed". Only a node with no parent can be one.
        const root_of_closed_tree = if (node) |n| n.parent_node == null and retarget.isShadowRoot(n) and retarget.isClosed(n) else false;
        // Step 5.
        try self.state.path.append(.{
            .invocation_target = invocation_target,
            .invocation_target_in_shadow_tree = in_shadow_tree,
            .shadow_adjusted_target = shadow_adjusted,
            .related_target = self.related,
            .touch_target_list = touch,
            .root_of_closed_tree = root_of_closed_tree,
            .slot_in_closed_tree = slot_in_closed_tree,
            .target = self.target,
        });
    }

    /// The depth-0 tree's root `root` has been reached: if it is a shadow
    /// root, every item since the tree's first is in a shadow tree.
    fn resolveScope(self: *Walk, root: *NodeBase) void {
        if (!retarget.isShadowRoot(root)) return;
        for (self.state.path.toSliceMut()[self.scope_start..]) |*item| item.invocation_target_in_shadow_tree = true;
    }

    /// Steps 6.9.3-6.9.5 when a move changes the tree: relatedTarget and the
    /// touch targets, retargeted against `parent`.
    fn retargetAgainst(self: *Walk, parent: *runtime.Instance) !void {
        self.related = retarget.retargetAgainst(self.event_related, parent);
        const touch = self.state.touch_target_list.toSlice();
        if (touch.len == 0) return;
        self.touch_targets.clear();
        for (touch) |touch_target| {
            try self.touch_targets.append(retarget.retargetAgainst(touch_target, parent).?);
        }
    }

    /// "Get the parent" for the last item's invocation target, `instance`
    /// (`node` its node, or null for an EventTarget that is not one).
    fn parentOf(self: *Walk, instance: *runtime.Instance, node: ?*NodeBase) ?Parent {
        const n = node orelse {
            // An EventTarget that is not a node: a Window's get the parent
            // returns null (the default), and IndexedDB's request ->
            // transaction -> connection chain is its own (IndexedDB 2.7-2.8).
            const parent = indexeddb.getTheParent(instance) orelse return null;
            return .{ .instance = parent, .node = null, .move = .other };
        };
        if (n.parent_node) |parent| {
            // A node's get the parent: "the node's assigned slot, if node is
            // assigned; otherwise node's parent". Only a child of a shadow
            // host can be assigned (find a slot looks in the parent's shadow
            // root), so a tree with no shadow host tests one bit per node.
            if (parent.is_shadow_host and slot_helpers.isSlottable(n)) {
                if (slot_helpers.slottable(n)) |slottable| {
                    if (slottable.state.assignedSlot()) |slot| {
                        const slot_instance = retarget.instanceOf(slot) orelse return null;
                        return .{ .instance = slot_instance, .node = slot, .move = .slot };
                    }
                }
            }
            const parent_instance = retarget.instanceOf(parent) orelse return null;
            return .{ .instance = parent_instance, .node = parent, .move = .tree };
        }
        // `n` is a root. At depth 0 it is the depth-0 tree's.
        if (self.depth == 0) self.resolveScope(n);
        if (retarget.isShadowRoot(n)) {
            // A shadow root's get the parent: null "if event's composed flag
            // is unset and shadow root is the root of event's path's first
            // event path item's invocation target; otherwise shadow root's
            // host". At depth 0 before 6.9.8 has run, the walk is in the
            // target's own tree, so `n` is that root.
            if (!self.input.composed and self.depth == 0 and !self.left_target_tree) return null;
            const host = retarget.hostOf(n) orelse return null;
            const host_instance = retarget.instanceOf(host) orelse return null;
            return .{ .instance = host_instance, .node = host, .move = .host };
        }
        if (n.node_type == NodeBase.DOCUMENT_NODE) {
            // HTML's Document get the parent: null if event's type is "load"
            // or the document has no browsing context; otherwise its relevant
            // global object. No browsing context means no defaultView.
            if (std.mem.eql(u8, self.input.event_type, "load")) return null;
            const window = (interfaces.Document.get_defaultView(instance) catch null) orelse return null;
            return .{ .instance = window, .node = null, .move = .window };
        }
        return null;
    }

    /// Step 6.9.6.1 / 6.9.8.2's activation test for `candidate`.
    fn activationOf(self: *const Walk, candidate: *runtime.Instance) ?ActivationTarget {
        const of = self.input.activation_of orelse return null;
        const behavior = of(candidate) orelse return null;
        return .{ .target = candidate, .behavior = behavior };
    }
};

/// Dispatch steps 4-6.11 for `target`: append `state`'s path (empty on
/// entry) and return activationTarget and clearTargets. On error the path
/// holds what was appended; dispatch's end empties it.
pub fn build(state: *EventState, target: *runtime.Instance, input: Input) error{OutOfMemory}!Result {
    std.debug.assert(state.path.len == 0);
    const target_node = retarget.nodeOf(target);

    var walk: Walk = .{
        .state = state,
        .input = input,
        .event_related = state.related_target,
        .related = null,
        .touch_targets = infra.List(*runtime.Instance).init(state.allocator),
        .target = target,
    };
    defer walk.touch_targets.deinit();

    // Step 4: "Let relatedTarget be the result of retargeting event's
    // relatedTarget against target" - and steps 6.1-6.2's touchTargets,
    // retargeted against target too (nothing observes their order).
    try walk.retargetAgainst(target);

    // Step 6: "If target is not relatedTarget or target is event's
    // relatedTarget". Otherwise the path stays empty: no listener runs.
    if (target == walk.related and target != walk.event_related) return .{};

    // Step 6.3: "Append to an event path with event, target, targetOverride,
    // relatedTarget, touchTargets, and false." targetOverride is target: the
    // legacy target override flag is HTML's, for a Window, and Crane's HTML
    // does not pass it.
    try walk.append(target, target_node, target, false);

    // Steps 6.4-6.5: isActivationEvent (activation_of non-null), and the
    // target itself as activationTarget.
    walk.result.activation_target = walk.activationOf(target);

    // Steps 6.6-6.7: slottable and slotInClosedTree are the (b) move: a
    // parent reached from an assigned slottable is its slot.
    // Step 6.8: "Let parent be the result of invoking target's get the
    // parent with event."
    var current: *runtime.Instance = target;
    var current_node: ?*NodeBase = target_node;

    // Step 6.9: "While parent is non-null".
    while (walk.parentOf(current, current_node)) |parent| {
        if (state.path.len >= max_event_path_length) break;
        var slot_in_closed_tree = false;
        switch (parent.move) {
            .tree => {},
            .slot => {
                // Step 6.9.1: the previous node was an assigned slottable and
                // parent is its slot: "If parent's root is a shadow root whose
                // mode is closed, then set slotInClosedTree to true."
                const slot_root = retarget.rootOf(parent.node.?);
                slot_in_closed_tree = retarget.isShadowRoot(slot_root) and retarget.isClosed(slot_root);
                // Steps 6.9.3-6.9.5 in the slot's tree.
                try walk.retargetAgainst(parent.instance);
            },
            .host, .window => try walk.retargetAgainst(parent.instance),
            // retarget against an object that is not a node depends on
            // nothing but that: the values the last move left hold.
            .other => {},
        }

        // Step 6.9.6: "If parent is a Window object, or parent is a node and
        // target's root is a shadow-including inclusive ancestor of parent"
        // - false exactly for a (c) move at depth 0 (THE WALK).
        //
        // An IndexedDB parent is neither, and read literally 6.9.8 would make
        // each one its own AT_TARGET target. Golden rule 2: the browsers
        // append it like a Window and keep the request as the target -
        // WebKit's EventPath(std::span<EventTarget* const>) gives every
        // context the first target (Source/WebCore/dom/EventPath.cpp), and
        // Blink's IDBEventDispatcher::Dispatch sets only the current target
        // as it walks request, transaction and database
        // (crane/ev1-idb-target-stays-request.html).
        const leaves_target_tree = parent.move == .host and walk.depth == 0;
        if (!leaves_target_tree) {
            if (parent.move == .slot) walk.depth += 1;
            if (parent.move == .host) walk.depth -= 1;
            // Step 6.9.6.1.
            if (input.bubbles and walk.result.activation_target == null) {
                walk.result.activation_target = walk.activationOf(parent.instance);
            }
            // Step 6.9.6.2: "Append to an event path with event, parent,
            // null, relatedTarget, touchTargets, and slotInClosedTree."
            try walk.append(parent.instance, parent.node, null, slot_in_closed_tree);
        } else if (parent.instance == walk.related) {
            // Step 6.9.7: "Otherwise, if parent is relatedTarget, then set
            // parent to null."
            break;
        } else {
            // Step 6.9.8.1: "Set target to parent." The host's tree is the
            // new depth-0 tree, its kind not known yet.
            walk.target = parent.instance;
            walk.left_target_tree = true;
            walk.scope_start = state.path.len;
            walk.last_target_index = state.path.len;
            // Step 6.9.8.2.
            if (walk.result.activation_target == null) {
                walk.result.activation_target = walk.activationOf(parent.instance);
            }
            // Step 6.9.8.3: "Append to an event path with event, parent,
            // target, relatedTarget, touchTargets, and slotInClosedTree."
            try walk.append(parent.instance, parent.node, parent.instance, slot_in_closed_tree);
        }

        // Step 6.9.9: "If parent is non-null, then set parent to the result
        // of invoking parent's get the parent with event." Step 6.9.10:
        // slotInClosedTree is per iteration.
        current = parent.instance;
        current_node = parent.node;
    }

    // Steps 6.10-6.11: clearTargets, if clearTargetsItem's shadow-adjusted
    // target, relatedTarget or a touch target is a node whose root is a
    // shadow root. The shadow-adjusted target of an item that has one is its
    // invocation target.
    const item = state.path.toSlice()[walk.last_target_index];
    walk.result.clear_targets = item.invocation_target_in_shadow_tree or
        inShadowTree(item.related_target) or
        for (item.touch_target_list.toSlice()) |touch_target| {
            if (inShadowTree(touch_target)) break true;
        } else false;

    return walk.result;
}

/// Whether `target` is a node whose root is a shadow root.
fn inShadowTree(target: ?*runtime.Instance) bool {
    const instance = target orelse return false;
    const node = retarget.nodeOf(instance) orelse return false;
    return retarget.isShadowRoot(retarget.rootOf(node));
}
