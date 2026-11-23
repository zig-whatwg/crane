//! DOM 2.9 dispatch steps 4-6.11 across shadow trees: dom.event_path's walk
//! against a literal implementation of the steps, written here, over random
//! trees.
//!
//! dom.event_path never walks to a root to answer step 6.9.6 ("target's root
//! is a shadow-including inclusive ancestor of parent") or an item's
//! invocation-target-in-shadow-tree: it counts the moves "get the parent"
//! makes (THE WALK, src/dom/event_path.zig) and retargets only when a move
//! changes the tree. That is an argument. This test is the proof the
//! integrator asked for: for every random tree - nested shadow roots, open
//! and closed, named and manual slot assignment, slotted and unslotted
//! elements and text, a detached tree - and every random dispatch - target,
//! relatedTarget (or none), up to two touch targets, composed, bubbles,
//! "load" or not, activation event or not - the walk's path must equal the
//! literal one item by item: invocation target, shadow-adjusted target,
//! relatedTarget, touch target list, the three booleans and invoke's target,
//! and the activation target and clearTargets too. The path is built into a
//! dispatch's own `DispatchPath`, as EventTarget's dispatch builds it (lane
//! ev1's second batch: the path is the dispatch's, and an item's touch
//! targets are a run of the path's). The literal implementation takes one root walk per question, through
//! the IDL getters, as the standard reads.
//!
//! A failure prints the seed; `ev1_seed_only` reruns one.

const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

/// The test's allocator: a churn test's (tests/test_runner/poisoning.zig,
/// `ChurnAllocator`), not std.testing.allocator - 2,500 random trees and
/// 30,000 dispatches make and free millions of blocks, and the per-allocation
/// stack capture std.testing.allocator does made this test 164 s on chat2
/// against 5.0 s on server1 (lane flk4 item 8, 2026-11-23). Its deinit, at
/// the test's end, is the leak check std.testing.allocator's was.
var churn: @import("root").poisoning.ChurnAllocator = .{ .name = "ev1_event_path_differential_test" };

fn allocator() std.mem.Allocator {
    return churn.allocator();
}
const Instance = runtime.Instance;

/// Trees to build; each gets `dispatches_per_tree` dispatches.
const tree_count: u64 = 2500;
const dispatches_per_tree: usize = 12;
/// Set to a seed to rerun only that tree.
const ev1_seed_only: ?u64 = null;

// ============================================================================
// The literal implementation: DOM 2.9 steps 4-6.11, one root walk per step
// ============================================================================

fn isNode(target: *Instance) bool {
    return target.stateAs(interfaces.Node.State) != null;
}

fn isShadowRoot(target: *Instance) bool {
    return target.stateAs(interfaces.ShadowRoot.State) != null;
}

fn isDocument(target: *Instance) bool {
    return target.stateAs(interfaces.Document.State) != null;
}

fn rootOf(node: *Instance) *Instance {
    return interfaces.Node.call_getRootNode(node, .{ .was_passed = false, .value = undefined }) catch unreachable;
}

fn hostOf(shadow: *Instance) *Instance {
    return interfaces.ShadowRoot.get_host(shadow) catch unreachable;
}

fn isClosedShadowRoot(target: *Instance) bool {
    if (!isShadowRoot(target)) return false;
    const mode = interfaces.ShadowRoot.get_mode(target) catch unreachable;
    return mode == ._closed_;
}

/// "Element and Text nodes are slottables."
fn isSlottable(target: *Instance) bool {
    const node = dom.instance_bridge.getNodeBase(target) orelse return false;
    return node.node_type == dom.NodeBase.ELEMENT_NODE or node.node_type == dom.NodeBase.TEXT_NODE;
}

/// "A slottable is assigned if its assigned slot is non-null."
fn assignedSlot(target: *Instance) ?*Instance {
    if (!isSlottable(target)) return null;
    return dom.shadow_dom_algorithms.assignedSlotOf(target);
}

/// "An object A is a shadow-including inclusive ancestor of an object B" -
/// B is A, a descendant of A, or in a shadow tree whose host is a
/// shadow-including inclusive descendant of A.
fn isShadowIncludingInclusiveAncestor(a: *Instance, b: *Instance) bool {
    if (interfaces.Node.call_contains(a, b) catch unreachable) return true;
    const root = rootOf(b);
    if (!isShadowRoot(root)) return false;
    return isShadowIncludingInclusiveAncestor(a, hostOf(root));
}

/// "Retarget A against B".
fn retargetLiteral(a_given: ?*Instance, b: *Instance) ?*Instance {
    var a = a_given orelse return null;
    while (true) {
        if (!isNode(a)) return a;
        const root = rootOf(a);
        if (!isShadowRoot(root)) return a;
        if (isNode(b) and isShadowIncludingInclusiveAncestor(root, b)) return a;
        a = hostOf(root);
    }
}

const Item = struct {
    invocation_target: *Instance,
    in_shadow_tree: bool,
    shadow_adjusted_target: ?*Instance,
    related_target: ?*Instance,
    /// The item's touch target list: one per touch target of the event.
    touch: [max_touch]*Instance = undefined,
    root_of_closed_tree: bool,
    slot_in_closed_tree: bool,
};

/// The most touch targets a random dispatch gives its event.
const max_touch = 2;

const Literal = struct {
    path: std.ArrayListUnmanaged(Item) = .empty,
    activation_target: ?*Instance = null,
    clear_targets: bool = false,

    fn deinit(self: *Literal) void {
        self.path.deinit(allocator());
    }
};

const Dispatch = struct {
    target: *Instance,
    related: ?*Instance,
    /// The event's touch target list when dispatch begins.
    touch: []const *Instance = &.{},
    composed: bool,
    bubbles: bool,
    load: bool,
    activation_event: bool,
};

fn hasActivationBehavior(target: *Instance) bool {
    const node = dom.instance_bridge.getNodeBase(target) orelse return false;
    return node.node_type == dom.NodeBase.ELEMENT_NODE and std.ascii.eqlIgnoreCase(node.nodeName(), "x-act");
}

/// "Append to an event path".
fn appendLiteral(path: *std.ArrayListUnmanaged(Item), invocation_target: *Instance, shadow_adjusted: ?*Instance, related: ?*Instance, touch: [max_touch]*Instance, slot_in_closed_tree: bool) !void {
    try path.append(allocator(), .{
        .invocation_target = invocation_target,
        .in_shadow_tree = isNode(invocation_target) and isShadowRoot(rootOf(invocation_target)),
        .shadow_adjusted_target = shadow_adjusted,
        .related_target = related,
        .touch = touch,
        .root_of_closed_tree = isClosedShadowRoot(invocation_target),
        .slot_in_closed_tree = slot_in_closed_tree,
    });
}

/// Steps 6.1-6.2 and 6.9.4-6.9.5: "for each touchTarget of event's touch
/// target list, append the result of retargeting touchTarget against"
/// `against`.
fn retargetTouchLiteral(d: Dispatch, against: *Instance) [max_touch]*Instance {
    var touch: [max_touch]*Instance = undefined;
    for (d.touch, 0..) |touch_target, i| touch[i] = retargetLiteral(touch_target, against).?;
    return touch;
}

/// A node's, a shadow root's and a document's "get the parent".
fn getTheParentLiteral(target: *Instance, path: []const Item, d: Dispatch) ?*Instance {
    if (isShadowRoot(target)) {
        if (!d.composed and target == rootOf(path[0].invocation_target)) return null;
        return hostOf(target);
    }
    if (isDocument(target)) {
        if (d.load) return null;
        return interfaces.Document.get_defaultView(target) catch null;
    }
    if (isNode(target)) {
        if (assignedSlot(target)) |slot| return slot;
        return interfaces.Node.get_parentNode(target) catch unreachable;
    }
    return null;
}

/// DOM 2.9 dispatch steps 3-6.11, as written.
fn literal(d: Dispatch) !Literal {
    var result: Literal = .{};
    errdefer result.deinit();
    var target = d.target;
    // Step 4.
    var related = retargetLiteral(d.related, target);
    // Step 6.
    if (target != related or target == d.related) {
        // Steps 6.1-6.2.
        var touch = retargetTouchLiteral(d, target);
        // Step 6.3.
        try appendLiteral(&result.path, target, target, related, touch, false);
        // Steps 6.4-6.5.
        const is_activation_event = d.activation_event;
        if (is_activation_event and hasActivationBehavior(target)) result.activation_target = target;
        // Steps 6.6-6.8.
        var slottable: ?*Instance = if (assignedSlot(target) != null) target else null;
        var slot_in_closed_tree = false;
        var parent = getTheParentLiteral(target, result.path.items, d);
        // Step 6.9.
        while (parent) |p| {
            // Step 6.9.1.
            if (slottable != null) {
                try std.testing.expect(dom.slot_helpers.isSlot(dom.instance_bridge.getNodeBase(p).?));
                slottable = null;
                if (isClosedShadowRoot(rootOf(p))) slot_in_closed_tree = true;
            }
            // Step 6.9.2.
            if (assignedSlot(p) != null) slottable = p;
            // Steps 6.9.3-6.9.5.
            related = retargetLiteral(d.related, p);
            touch = retargetTouchLiteral(d, p);
            var next: ?*Instance = p;
            // Step 6.9.6.
            if (!isNode(p) or isShadowIncludingInclusiveAncestor(rootOf(target), p)) {
                if (is_activation_event and d.bubbles and result.activation_target == null and hasActivationBehavior(p)) result.activation_target = p;
                try appendLiteral(&result.path, p, null, related, touch, slot_in_closed_tree);
            } else if (p == related) {
                // Step 6.9.7.
                next = null;
            } else {
                // Step 6.9.8.
                target = p;
                if (is_activation_event and result.activation_target == null and hasActivationBehavior(target)) result.activation_target = target;
                try appendLiteral(&result.path, p, target, related, touch, slot_in_closed_tree);
            }
            // Steps 6.9.9-6.9.10.
            parent = if (next) |n| getTheParentLiteral(n, result.path.items, d) else null;
            slot_in_closed_tree = false;
        }
        // Steps 6.10-6.11.
        var clear_item: Item = undefined;
        for (result.path.items) |item| {
            if (item.shadow_adjusted_target != null) clear_item = item;
        }
        const in_shadow = struct {
            fn check(t: ?*Instance) bool {
                const x = t orelse return false;
                return isNode(x) and isShadowRoot(rootOf(x));
            }
        }.check;
        result.clear_targets = in_shadow(clear_item.shadow_adjusted_target) or in_shadow(clear_item.related_target);
        for (clear_item.touch[0..d.touch.len]) |touch_target| {
            if (in_shadow(touch_target)) result.clear_targets = true;
        }
    }
    return result;
}

// ============================================================================
// Random trees
// ============================================================================

const Tree = struct {
    ctx: runtime.ContextData,
    document: *Instance,
    /// Every node a dispatch may target or name as its relatedTarget.
    nodes: std.ArrayListUnmanaged(*Instance) = .empty,
    /// Nodes that can take children.
    containers: std.ArrayListUnmanaged(*Instance) = .empty,
    /// Shadow roots in the order they were attached (outer before inner).
    shadows: std.ArrayListUnmanaged(*Instance) = .empty,
    /// The root of the detached tree.
    detached: *Instance,

    fn element(self: *Tree, name: []const u8) !*Instance {
        return interfaces.Document.call_createElement(self.document, runtime.DOMString.initInterned(name), .{ .was_passed = false, .value = undefined });
    }

    fn setAttribute(target: *Instance, name: []const u8, value: []const u8) !void {
        try interfaces.Element.call_setAttribute(target, runtime.DOMString.initInterned(name), .{ .domstring = runtime.DOMString.initInterned(value) });
    }

    fn init(self: *Tree, random: std.Random) !void {
        self.* = .{ .ctx = try runtime.ContextData.init(allocator(), .{}), .document = undefined, .detached = undefined };
        self.document = try interfaces.Document.init(allocator(), &self.ctx);
        try dom.document_internals.setContentType(self.document, "text/html");
        try dom.document_internals.setDocumentType(self.document, .html);
        const html = try self.element("html");
        _ = try interfaces.Node.call_appendChild(self.document, html);
        const body = try self.element("body");
        _ = try interfaces.Node.call_appendChild(html, body);
        self.detached = try self.element("div");
        try self.nodes.appendSlice(allocator(), &.{ self.document, html, body, self.detached });
        try self.containers.appendSlice(allocator(), &.{ body, self.detached });

        const names = [_][]const u8{ "a", "b", "c" };
        const count = 6 + random.uintLessThan(usize, 26);
        for (0..count) |_| {
            const parent = self.containers.items[random.uintLessThan(usize, self.containers.items.len)];
            const roll = random.uintLessThan(u8, 100);
            if (roll < 15) {
                const text = try interfaces.Document.call_createTextNode(self.document, runtime.DOMString.initInterned("t"));
                _ = try interfaces.Node.call_appendChild(parent, text);
                try self.nodes.append(allocator(), text);
                continue;
            }
            const name: []const u8 = if (roll < 32) "slot" else if (roll < 42) "x-act" else if (roll < 71) "div" else "span";
            const el = try self.element(name);
            if (std.mem.eql(u8, name, "slot")) {
                if (random.boolean()) try setAttribute(el, "name", names[random.uintLessThan(usize, names.len)]);
            } else if (random.uintLessThan(u8, 100) < 45) {
                try setAttribute(el, "slot", names[random.uintLessThan(usize, names.len)]);
            }
            _ = try interfaces.Node.call_appendChild(parent, el);
            try self.nodes.append(allocator(), el);
            try self.containers.append(allocator(), el);
            if ((std.mem.eql(u8, name, "div") or std.mem.eql(u8, name, "span")) and random.uintLessThan(u8, 100) < 40) {
                const shadow = try interfaces.Element.call_attachShadow(el, .{
                    .mode = if (random.boolean()) ._open_ else ._closed_,
                    .slotAssignment = if (random.uintLessThan(u8, 100) < 25) ._manual_ else ._named_,
                });
                try dom.node_document.set(shadow, self.document);
                try self.shadows.append(allocator(), shadow);
                try self.nodes.append(allocator(), shadow);
                try self.containers.append(allocator(), shadow);
            }
        }
        try self.assignManually(random);
    }

    /// For each slot in a shadow root with manual slot assignment, assign()
    /// a random subset of its host's children.
    fn assignManually(self: *Tree, random: std.Random) !void {
        for (self.shadows.items) |shadow| {
            const assignment = try interfaces.ShadowRoot.get_slotAssignment(shadow);
            if (assignment != ._manual_) continue;
            const host = hostOf(shadow);
            var children: std.ArrayListUnmanaged(*Instance) = .empty;
            defer children.deinit(allocator());
            var child = interfaces.Node.get_firstChild(host) catch null;
            while (child) |c| : (child = interfaces.Node.get_nextSibling(c) catch null) {
                if (isSlottable(c)) try children.append(allocator(), c);
            }
            for (self.nodes.items) |candidate| {
                if (!isNode(candidate) or isShadowRoot(candidate)) continue;
                if (!dom.slot_helpers.isSlot(dom.instance_bridge.getNodeBase(candidate).?)) continue;
                if (rootOf(candidate) != shadow) continue;
                var chosen: std.ArrayListUnmanaged(*Instance) = .empty;
                defer chosen.deinit(allocator());
                for (children.items) |c| {
                    if (random.boolean()) try chosen.append(allocator(), c);
                }
                try dom.shadow_dom_algorithms.assign(allocator(), candidate, chosen.items);
            }
        }
    }

    fn deinit(self: *Tree) void {
        // Hosts first, each telling its shadow root it is gone; then each
        // shadow root frees its own tree, outer before inner.
        interfaces.Document.deinit(self.document);
        interfaces.HTMLDivElement.deinit(self.detached);
        for (self.shadows.items) |shadow| interfaces.ShadowRoot.deinit(shadow);
        self.nodes.deinit(allocator());
        self.containers.deinit(allocator());
        self.shadows.deinit(allocator());
        self.ctx.deinit();
    }
};

// ============================================================================
// The comparison
// ============================================================================

const TestActivation = struct {
    fn has(target: *Instance) bool {
        return hasActivationBehavior(target);
    }
    fn run(_: *Instance, _: *Instance) void {}
    fn of(target: *Instance) ?dom.activation.Behavior {
        if (!hasActivationBehavior(target)) return null;
        return .{ .has = &has, .run = &run };
    }
};

fn describe(tree: *const Tree, target: ?*Instance) usize {
    const t = target orelse return std.math.maxInt(usize);
    for (tree.nodes.items, 0..) |n, i| {
        if (n == t) return i;
    }
    return std.math.maxInt(usize) - 1;
}

fn check(seed: u64, tree: *Tree, d: Dispatch) !void {
    var expected = try literal(d);
    defer expected.deinit();

    const event = try interfaces.Event.call_constructor(&tree.ctx, runtime.DOMString.initInterned(if (d.load) "load" else "ev1"), .{ .was_passed = false, .value = undefined });
    defer interfaces.Event.deinit(event);
    const state = dom.event_dispatch.of(event).?;
    // Raw, as dispatch reads it: the edge is not what is under test.
    state.related_target = d.related;
    defer state.related_target = null;
    for (d.touch) |touch_target| try state.touch_target_list.append(runtime.allocatorOf(event), touch_target);

    // The dispatch's path, as EventTarget's dispatch declares it.
    var dispatch_path: dom.event_dispatch.DispatchPath = undefined;
    dispatch_path.init(allocator());
    defer dispatch_path.deinit();
    const result = try dom.event_path.build(state, &dispatch_path, d.target, .{
        .event_type = if (d.load) "load" else "ev1",
        .composed = d.composed,
        .bubbles = d.bubbles,
        .activation_of = if (d.activation_event) &TestActivation.of else null,
    });
    defer state.clearPath();
    const path = state.pathItems();
    // The event points at the dispatch's path, and nowhere else.
    try std.testing.expect(state.path == &dispatch_path or path.len == 0);

    errdefer std.debug.print(
        "\nev1 differential: seed {d}, target #{d}, related #{d}, composed {}, bubbles {}, load {}, activation {}: expected {d} items, got {d}\n",
        .{ seed, describe(tree, d.target), describe(tree, d.related), d.composed, d.bubbles, d.load, d.activation_event, expected.path.items.len, path.len },
    );

    try std.testing.expectEqual(expected.path.items.len, path.len);
    var invoke_target: ?*Instance = null;
    for (expected.path.items, path, 0..) |want, *got_item, i| {
        const got = got_item.*;
        errdefer std.debug.print("ev1 differential: item {d} (#{d}) differs\n", .{ i, describe(tree, want.invocation_target) });
        try std.testing.expectEqual(want.invocation_target, got.invocation_target);
        try std.testing.expectEqual(want.shadow_adjusted_target, got.shadowAdjustedTarget());
        try std.testing.expectEqual(want.related_target, got.related_target);
        try std.testing.expectEqual(want.in_shadow_tree, got.invocation_target_in_shadow_tree);
        try std.testing.expectEqual(want.root_of_closed_tree, got.root_of_closed_tree);
        try std.testing.expectEqual(want.slot_in_closed_tree, got.slot_in_closed_tree);
        // Invoke steps 1-3: the last shadow-adjusted target at or before.
        if (want.shadow_adjusted_target) |t| invoke_target = t;
        try std.testing.expectEqual(invoke_target.?, got.target);
        try std.testing.expectEqualSlices(*Instance, want.touch[0..d.touch.len], dispatch_path.touchTargetsOf(got_item));
    }
    const got_activation: ?*Instance = if (result.activation_target) |at| at.target else null;
    try std.testing.expectEqual(expected.activation_target, got_activation);
    try std.testing.expectEqual(expected.clear_targets, result.clear_targets);
}

test "the event path across shadow trees matches DOM 2.9 steps 4-6.11, read literally, on random trees" {
    try differential();
    // The leak check: everything the trees, the dispatches and the runtime
    // made is freed (the runtime's own end ran in `differential`).
    try churn.deinit();
}

fn differential() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator());
    defer runtime.deinitializeRuntime();

    var cases: usize = 0;
    var shadow_paths: usize = 0;
    var touch_cases: usize = 0;
    var seed: u64 = 0;
    while (seed < tree_count) : (seed += 1) {
        if (ev1_seed_only) |only| {
            if (seed != only) continue;
        }
        var prng = std.Random.DefaultPrng.init(seed *% 0x9E3779B97F4A7C15 +% 1);
        const random = prng.random();
        var tree: Tree = undefined;
        try tree.init(random);
        defer tree.deinit();
        for (0..dispatches_per_tree) |_| {
            const nodes = tree.nodes.items;
            // One dispatch in three is a touch event's: one or two touch
            // targets, anywhere in the trees.
            var touch: [max_touch]*Instance = undefined;
            const touch_count: usize = if (random.uintLessThan(u8, 3) == 0) 1 + random.uintLessThan(usize, max_touch) else 0;
            for (touch[0..touch_count]) |*touch_target| touch_target.* = nodes[random.uintLessThan(usize, nodes.len)];
            if (touch_count > 0) touch_cases += 1;
            const d: Dispatch = .{
                .target = nodes[random.uintLessThan(usize, nodes.len)],
                .related = if (random.uintLessThan(u8, 100) < 30) null else nodes[random.uintLessThan(usize, nodes.len)],
                .touch = touch[0..touch_count],
                .composed = random.boolean(),
                .bubbles = random.boolean(),
                .load = random.uintLessThan(u8, 100) < 10,
                .activation_event = random.boolean(),
            };
            try check(seed, &tree, d);
            cases += 1;
            if (isShadowRoot(rootOf(d.target))) shadow_paths += 1;
        }
    }
    // The trees must actually exercise shadow trees: a run whose targets are
    // all in light trees would pass vacuously.
    if (ev1_seed_only == null) {
        try std.testing.expect(cases == tree_count * dispatches_per_tree);
        try std.testing.expect(shadow_paths * 5 > cases);
        try std.testing.expect(touch_cases * 5 > cases);
    }
}
