//! dom.wrapper_tracing: which node wrappers a reachable one keeps, computed
//! while the engine's collector marks (the wrapper redesign's P5,
//! tmp/redesign/wrapper-redesign-design.md 3.2 and 4.4).
//!
//! The rule is the browsers'. A wrapper of a node is kept through a major
//! collection while any wrapper of a node of its host-including tree is
//! (parent, shadow host, template host), or of a node whose node document's
//! tree it is, or while a node of the tree is kept (pending activity):
//! - Blink traces the whole tree through its nodes' Member edges and each
//!   node's wrapper from the node (Chromium 131.0.6778.0, the release on V8
//!   13.1, read on chromium.googlesource.com, and 145.0.7608.0 locally - the
//!   same in both): `Node::Trace` (core/dom/node.cc) visits
//!   `parent_or_shadow_host_node_`, `tree_scope_` (whose Trace visits the
//!   tree's `document_` and root), `previous_`, `next_` and `data_`;
//!   `ContainerNode::Trace` visits `first_child_` and `last_child_`;
//!   `HTMLTemplateElement::Trace` visits `content_`, whose
//!   `TemplateContentDocumentFragment::Trace` visits its `host_`; the shadow
//!   root is in the host's rare data fields (ElementRareDataVector::Trace);
//!   and `EventTarget::Trace` reaches `ScriptWrappable::Trace`
//!   (platform/bindings/script_wrappable.cc), which visits the inline
//!   `wrapper_`. The heap-snapshot graph that V8EmbedderGraphBuilder once
//!   built is V8's own CppGraphBuilder since the unified heap, and Blink
//!   only answers detachedness there, from the same host-including root
//!   (bindings/core/v8/v8_gc_controller.cc `OpaqueRootForGC`:
//!   `ParentOrShadowHostOrTemplateHostNode` up to the root, a connected node's
//!   root being its document).
//! - WebKit keeps a node's wrapper while its opaque root - the same root - is
//!   reachable (JSNodeOwner::isReachableFromOpaqueRoots).
//!
//! Crane's nodes are reference-counted Zig memory, not collector objects, so
//! nothing traces them edge by edge: the engine reaches this walk from the
//! wrapper it is marking (runtime.lifetime's `traceTree` hook; V8's
//! NodeAnchor::Trace and the agent's keeps), and the walk visits the tree from
//! its root, naming each wrapper to the engine (engine.traceNodeWrapper). It
//! visits only the held part of the tree: a wrapped node is held - its
//! wrapper owns a counted reference - so every subtree holding a wrapper has
//! `subtree_holds > 0` at its own root, and the walk tests each child's OWN
//! total, never its parent's. A tree is walked once per collection however
//! many of its wrappers the collector reaches (engine.traceVisitOnce on its
//! root). Blink traces every node of every live tree, so this is never more
//! work than Blink's.
//!
//! The walk runs inside the collector's atomic pause, with the mutator
//! stopped (V8: C++ marking is atomic, CppHeapCreateParams.marking_support =
//! kAtomic - v8_wrapper.cpp NodeAnchor::Trace says why and fails loudly
//! otherwise). So it is READ-ONLY, allocates nothing and calls no engine
//! operation but the two tracing ones; recursion-free (a tree's depth costs no
//! stack). Every read below is a field or a hook that reads fields:
//! `refcount.root` / `hostIncludingParent` (a hosted root's host:
//! template_contents.host - ShadowRoot's `host` or the template's), and
//! `refcount.hostedRoots` (dom.shadow_hosts.rootForHost - the Element's rare
//! data - and template_contents.contentOf - the template's content field,
//! generation-checked), `refcount.liveNodeDocument` (Node's generation-checked
//! node document). A collection can start only at an allocation, and a tree
//! mutation's link writes and count updates allocate nothing between them
//! (NodeBase.linkChildBefore, refcount.linkChild / moveChild / unlinkChild),
//! so the walk sees consistent links and counts.
//!
//! The Debug oracle (-Dv8-wrapper-trace-check, the V8 adapter's node_wrappers.zig)
//! walks the same trees unpruned (`forEachWrapped`) after each major GC.
//!
//! HOLDERS (the redesign's P6, design 3.2 rule (d) and 4.4 "Holders"): a
//! holder whose wrapper is kept keeps the nodes it holds for script and
//! their trees - a static NodeList's nodes, a MutationRecord's, a live
//! collection's root. The holder's type names them from its VTable's
//! `trace_held_nodes` (runtime.lifetime.heldNodesOf: a `traceHeldNodes` on
//! its InternalState), reached from the holder's wrapper (V8: its
//! HolderAnchor's Trace) or, for a node that holds nodes - a Document's
//! active parser and top layer, a dialog's saved focus - from this walk
//! where it visits the node (`NodeBase.traces_held`); each held node goes
//! through `traceHeld`: its own wrapper, and every wrapper of its trees.
//! Blink traces a holder's `Member<Node>`s (StaticNodeTypeList::Trace,
//! ChildListRecord::Trace, HTMLConstructionSite::Trace; Chromium
//! 131.0.6778.0). Nothing here makes a wrapper: a held node with none costs
//! nothing (docs/lessons/architecture-tracing-a-holders-nodes-makes-a-
//! wrapper-per-node.md). A node holder the pruned walk does not visit - not
//! held itself, and nothing held below it - is not asked: Blink would trace
//! it with its whole tree. The trees its members are in are then kept by
//! their own wrappers only; a holder script reaches is wrapped, so held, so
//! visited.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const NodeBase = @import("node_base.zig").NodeBase;
const refcount = @import("refcount.zig");

/// runtime.lifetime's `traceTree` hook (installed by dom.refcount at process
/// start): `target` - a counted node, as the wrapper's acquire answered it -
/// has a wrapper the collector reached, or is kept. Every wrapper of its
/// host-including tree is kept, and every wrapper of its node document's
/// tree (refcount decision D6: a node keeps its document's tree; Blink's
/// `Node::Trace` visits `tree_scope_`, whose `document_` it traces).
/// `target`'s own wrapper is the engine's to keep (a reached wrapper's, or a
/// kept one's rooted anchor): a lone `target` names nothing again.
pub fn traceTree(target: *anyopaque, tracer: *engine.Tracer) void {
    const node: *NodeBase = @ptrCast(@alignCast(target));
    const roots = treeRoots(node);
    walkTree(roots[0], node, node, tracer);
    if (roots[1]) |document| walkTree(document, node, null, tracer);
}

/// A node a holder holds for script (design 3.2 (d)): its own wrapper, and
/// every wrapper of its host-including tree and of its node document's tree
/// - what `traceTree` keeps for a reached wrapper, the node's own included.
/// Called from a holder's `trace_held_nodes`, in the collection's atomic
/// pause; reads only.
pub fn traceHeld(node: *NodeBase, tracer: *engine.Tracer) void {
    if (connectedDocument(node)) |document| return walkTree(document, null, node, tracer);
    const roots = treeRoots(node);
    walkTree(roots[0], null, node, tracer);
    if (roots[1]) |document| walkTree(document, null, null, tracer);
}

/// The Document a connected `node` is in - its host-including root and its
/// node document at once (connected: its shadow-including root is a
/// document; template contents are never connected) - or null for a node
/// that is not connected. No climb: a holder of thousands of connected nodes
/// (an observer's records during a parse) costs a field test each, and the
/// document's tree is walked once per collection whoever asks.
pub fn connectedDocument(node: *NodeBase) ?*NodeBase {
    if (node.node_type == NodeBase.DOCUMENT_NODE) return node;
    if (!node.is_connected) return null;
    return node.documentBase();
}

/// `node` holds nodes for script itself (`NodeBase.traces_held`): its
/// type's `trace_held_nodes` names them.
fn traceHolderNode(node: *NodeBase, tracer: *engine.Tracer) void {
    const instance: *runtime.Instance = @ptrCast(@alignCast(node.ownerInstance() orelse return));
    // A node whose teardown began holds nothing any more.
    if (runtime.instance_lifecycle.isCleanupStarted(instance)) return;
    const trace = instance.vtable.trace_held_nodes orelse return;
    trace(instance, tracer);
}

/// The roots of the trees `node` keeps: its host-including tree's, and its
/// node document's when that is another tree (null otherwise).
pub fn treeRoots(node: *NodeBase) [2]?*NodeBase {
    const tree_root = refcount.root(null, node);
    const document = refcount.liveNodeDocument(node);
    return .{ tree_root, if (document != null and document.? != tree_root) document else null };
}

/// The held part of `tree_root`'s tree, once per collection: each wrapper in
/// it named to the engine (`target`'s own excepted when it is a lone root),
/// and each node holder in it asked for what it holds. `path_to` - a node of
/// the tree whose wrapper or hold brought the walk here, or null - lets the
/// walk enter the children on its path without scanning for them.
fn walkTree(maybe_root: ?*NodeBase, target: ?*NodeBase, path_to: ?*NodeBase, tracer: *engine.Tracer) void {
    const tree_root = maybe_root orelse return;
    // A garbage tree holds nothing (its total is 0, so no node of it is
    // wrapped), and its teardown may be under way: never walked (design R2).
    if (tree_root.rc_flags.garbage) return;
    // No held node below the root (its own hold, if any, is the whole
    // total): the root's wrapper is all there is - no visited-set entry for
    // the common lone node, and nothing at all when it is `target` itself,
    // whose wrapper the engine keeps (the per-anchor cost, design R4c).
    if (isLone(tree_root)) {
        if (tree_root != target) engine.traceNodeWrapper(tracer, &tree_root.wrapper);
        // A lone node holder (a Document whose only held node is itself): asked
        // once per collection.
        if (tree_root.traces_held and engine.traceVisitOnce(tracer, tree_root)) traceHolderNode(tree_root, tracer);
        return;
    }
    if (!engine.traceVisitOnce(tracer, tree_root)) return;
    var path: Path = .{};
    if (path_to) |node| path.climb(node, tree_root);
    _ = walkHeld(tree_root, &path, Pruned{ .tracer = tracer });
}

// ---- The pruned walk (decision 7's remedy, at the wrapper redesign's P7) -----
//
// The walk runs in the collector's atomic pause, so its cost is pause time
// (design 4.4 "Cost per major GC", risk R4c). P5's walk tested EVERY child of
// each node on a held path - a flat body of 50,000 children with one held
// cost 50,000 tests a major collection (gc_bench `wide`: p95 1.79x P2's at
// P6, against decision 7's 1.5x). Two exact cuts remove only tests that
// cannot find a wrapper:
// - a node's children are tested only until the ones found hold all of the
//   node's remaining holds: `subtree_holds` is the node's own hold plus its
//   hosted roots' and its children's totals (refcount's invariant, checked
//   by refcount.verifyTree; a collection starts only at an allocation, and
//   no tree mutation allocates between its link writes and its count
//   updates - this module's header). A total that does not add up (found
//   more than the parent says) turns the cut off for that node: the scan
//   then runs to the end, as before;
// - the path from the tree's root to the node whose wrapper (or hold)
//   brought the walk to the tree is known from that node's own climb to its
//   root, so the walk enters each node's child on it directly - Blink's
//   marking reaches a parent's last child as directly as its first
//   (ContainerNode::Trace visits first_child_ and last_child_, Chromium
//   131.0.6778.0, core/dom/container_node.cc) - and counts its holds as
//   found before scanning for the others.
// With both, `wide`'s held last child costs no test at all. The frames live
// on a bounded stack in this function's frame (allocation-free, as the walk
// must be); a subtree deeper than the stack is walked by the stackless walk
// below, which tests every child - exact, only slower.

/// The deepest path the walk remembers (`Path`): deeper nodes are found by
/// the scan.
const max_path = 64;
/// The walk's frames (`walkHeld`): a deeper subtree goes to `walkDown`.
const max_frames = 64;

/// The path from a tree's root down to the node whose wrapper (or hold)
/// brought the walk to the tree: nodes[0] is that node, nodes[len - 1] the
/// root. Empty when the node is deeper than `max_path` below the root.
const Path = struct {
    nodes: [max_path]*NodeBase = undefined,
    len: usize = 0,

    /// Climb from `node` to `tree_root`, as refcount.root does.
    fn climb(self: *Path, node: *NodeBase, tree_root: *NodeBase) void {
        var at = node;
        while (true) {
            if (self.len == max_path) return self.forget();
            self.nodes[self.len] = at;
            self.len += 1;
            if (at == tree_root) return;
            at = refcount.hostIncludingParent(at) orelse return self.forget();
        }
    }

    fn forget(self: *Path) void {
        self.len = 0;
    }

    /// The index of `node` in the path if it is the next node down from
    /// the node at `above` (an index), else `none`.
    fn below(self: *const Path, above: usize, node: *NodeBase) usize {
        if (above == none or above == 0) return none;
        return if (self.nodes[above - 1] == node) above - 1 else none;
    }

    const none = std.math.maxInt(usize);
};

/// One node of the walk, and where its search for held children stands.
const Frame = struct {
    node: *NodeBase,
    /// Its shadow root and template contents, tested before its children.
    hosted: [2]?*NodeBase,
    hosted_next: u8 = 0,
    /// Its child on the path, entered before the scan and skipped by it.
    path_child: ?*NodeBase = null,
    skip: ?*NodeBase = null,
    /// Its index in the path, or Path.none.
    path_index: usize,
    /// The next child the scan tests.
    cursor: ?*NodeBase,
    /// Holds of its children not found yet; `unknown` runs the scan to the
    /// end.
    remaining: u64,

    const unknown = std.math.maxInt(u64);

    fn enter(node: *NodeBase, path: *const Path, path_index: usize) Frame {
        var frame: Frame = .{ .node = node, .hosted = .{ null, null }, .path_index = path_index, .cursor = node.first_child, .remaining = undefined };
        var left: i64 = @as(i64, node.subtree_holds) - @intFromBool(refcount.isHeld(node));
        if (node.node_type == NodeBase.ELEMENT_NODE) {
            var hosted: [2]?*NodeBase = undefined;
            const roots = refcount.hostedRoots(node, &hosted);
            if (roots.len == 2) {
                frame.hosted = .{ roots[0], roots[1] };
                for (frame.hosted) |maybe| if (maybe) |root| {
                    left -= root.subtree_holds;
                };
            }
        }
        if (path_index != Path.none and path_index > 0) {
            const on_path = path.nodes[path_index - 1];
            if (on_path.parent_node == node and on_path.subtree_holds != 0) {
                frame.path_child = on_path;
                frame.skip = on_path;
                left -= on_path.subtree_holds;
            }
        }
        frame.remaining = if (left < 0) unknown else @intCast(left);
        return frame;
    }

    /// Its next host-including child holding a held node, or null.
    fn next(self: *Frame, stats: ?*WalkStats) ?*NodeBase {
        while (self.hosted_next < 2) {
            const hosted = self.hosted[self.hosted_next];
            self.hosted_next += 1;
            if (hosted) |root| {
                if (stats) |s| s.tested += 1;
                if (root.subtree_holds != 0) return root;
            }
        }
        if (self.path_child) |child| {
            self.path_child = null;
            return child;
        }
        while (self.remaining != 0) {
            const child = self.cursor orelse return null;
            self.cursor = child.next_sibling;
            if (child == self.skip) continue;
            if (stats) |s| s.tested += 1;
            const holds = child.subtree_holds;
            if (holds == 0) continue;
            if (self.remaining != unknown) self.remaining = if (holds > self.remaining) unknown else self.remaining - holds;
            return child;
        }
        return null;
    }
};

/// The held part of `top`'s host-including subtree, each node `walker.visit`ed
/// - depth first on a bounded stack of frames, the path entered directly and
/// each child scan cut once its node's holds are found (see above). What it
/// tested, when `stats` counts.
fn walkHeld(top: *NodeBase, path: *const Path, walker: anytype) void {
    walkHeldCounting(top, path, walker, null);
}

fn walkHeldCounting(top: *NodeBase, path: *const Path, walker: anytype, stats: ?*WalkStats) void {
    var frames: [max_frames]Frame = undefined;
    const top_index = if (path.len > 0 and path.nodes[path.len - 1] == top) path.len - 1 else Path.none;
    walker.visit(top);
    frames[0] = Frame.enter(top, path, top_index);
    var depth: usize = 1;
    while (depth > 0) {
        const frame = &frames[depth - 1];
        const child = frame.next(stats) orelse {
            depth -= 1;
            continue;
        };
        if (depth == max_frames) {
            // Deeper than the frames go: the stackless walk, every child
            // tested (exact).
            walkDown(child, walker);
            continue;
        }
        walker.visit(child);
        frames[depth] = Frame.enter(child, path, path.below(frame.path_index, child));
        depth += 1;
    }
}

/// Whether no node below `tree_root` is held: its own hold, if any, is its
/// whole total.
pub fn isLone(tree_root: *const NodeBase) bool {
    return tree_root.subtree_holds == @intFromBool(refcount.isHeld(tree_root));
}

/// The walk's visitor: held subtrees only, each wrapper named to the engine.
const Pruned = struct {
    tracer: *engine.Tracer,

    fn enters(_: Pruned, child: *NodeBase) bool {
        return child.subtree_holds != 0;
    }

    fn visit(self: Pruned, node: *NodeBase) void {
        if (!node.wrapper.isEmpty()) engine.traceNodeWrapper(self.tracer, &node.wrapper);
        if (node.traces_held) traceHolderNode(node, self.tracer);
    }
};

/// Whether a node of `top`'s host-including subtree - `top` included - has
/// a wrapper: a creator that frees a subtree it made (dom.node_creation
/// .destroyUninserted) must not free one script reaches. A wrapped node is
/// held (its wrapper's reference), so only held subtrees are entered, and the
/// walk stops at the first wrapper. Since the wrapper redesign's P7 a wrap
/// reaches no ancestor, so `top`'s own slot does not answer for its tree.
/// Read-only and allocation-free, as the walk.
pub fn holdsWrapper(top: *NodeBase) bool {
    if (!top.wrapper.isEmpty()) return true;
    if (top.subtree_holds == 0 or isLone(top)) return false;
    const Find = struct {
        found: *bool,

        fn enters(self: @This(), child: *NodeBase) bool {
            return !self.found.* and child.subtree_holds != 0;
        }

        fn visit(self: @This(), node: *NodeBase) void {
            if (!node.wrapper.isEmpty()) self.found.* = true;
        }
    };
    var found = false;
    walkDown(top, Find{ .found = &found });
    return found;
}

/// What one walk of a tree costs (`measureWalk`).
pub const WalkStats = struct {
    /// Nodes the walk visits (named to the engine when wrapped).
    visited: usize = 0,
    /// Of them, the held ones.
    held: usize = 0,
    /// Children it tests for a held subtree (`subtree_holds != 0`).
    tested: usize = 0,
};

/// The walk of `tree_root`'s held part as the collector's pause runs it -
/// arriving from `path_to`, a node of the tree whose wrapper (or hold)
/// brought it there, or from none - with a counter in place of the engine:
/// what it visits and how many children it tests. Read-only, no engine call
/// (tests/dom/wr7_walk_early_exit_test.zig; decision 7's remedy).
pub fn measureWalk(tree_root: *NodeBase, path_to: ?*NodeBase) WalkStats {
    var stats: WalkStats = .{};
    const Count = struct {
        stats: *WalkStats,

        fn enters(self: @This(), child: *NodeBase) bool {
            self.stats.tested += 1;
            return child.subtree_holds != 0;
        }

        fn visit(self: @This(), node: *NodeBase) void {
            self.stats.visited += 1;
            if (refcount.isHeld(node)) self.stats.held += 1;
        }
    };
    var path: Path = .{};
    if (path_to) |node| path.climb(node, tree_root);
    walkHeldCounting(tree_root, &path, Count{ .stats = &stats }, &stats);
    return stats;
}

/// The oracle's walk: EVERY node of `tree_root`'s host-including tree,
/// unpruned, `check(context, slot)` for each wrapped one. Read-only and
/// allocation-free like the walk; null and garbage roots visit nothing.
pub fn forEachWrapped(maybe_root: ?*NodeBase, context: anytype, comptime check: fn (@TypeOf(context), *engine.NodeWrapperSlot) void) void {
    const tree_root = maybe_root orelse return;
    if (tree_root.rc_flags.garbage) return;
    const Unpruned = struct {
        context: @TypeOf(context),

        fn enters(_: @This(), _: *NodeBase) bool {
            return true;
        }

        fn visit(self: @This(), node: *NodeBase) void {
            if (!node.wrapper.isEmpty()) check(self.context, &node.wrapper);
        }
    };
    walkDown(tree_root, Unpruned{ .context = context });
}

/// Pre-order over `top`'s host-including subtree - each node, then its
/// shadow root, its template contents and its children, in that order - with
/// no stack: a node's way back up is its parent, or a hosted root's host.
/// `walker.enters(child)` says whether to descend into a child's subtree.
fn walkDown(top: *NodeBase, walker: anytype) void {
    var node = top;
    descend: while (true) {
        walker.visit(node);
        if (firstEntered(node, .shadow_root, walker)) |child| {
            node = child;
            continue :descend;
        }
        // Climb until an ancestor has a next host-including child.
        while (node != top) {
            const up = refcount.hostIncludingParent(node) orelse return;
            if (nextEntered(up, node, walker)) |next| {
                node = next;
                continue :descend;
            }
            node = up;
        }
        return;
    }
}

/// Where among a node's host-including children a search starts.
const From = enum { shadow_root, template_contents, children };

/// `node`'s first host-including child the walker enters, starting at
/// `from`: its shadow root, its template contents, then its children.
fn firstEntered(node: *NodeBase, from: From, walker: anytype) ?*NodeBase {
    if (from != .children and node.node_type == NodeBase.ELEMENT_NODE) {
        var hosted: [2]?*NodeBase = undefined;
        const roots = refcount.hostedRoots(node, &hosted);
        if (roots.len == 2) {
            if (from == .shadow_root) if (roots[0]) |shadow_root| if (walker.enters(shadow_root)) return shadow_root;
            if (roots[1]) |contents| if (walker.enters(contents)) return contents;
        }
    }
    var child = node.first_child;
    while (child) |c| : (child = c.next_sibling) {
        if (walker.enters(c)) return c;
    }
    return null;
}

/// The host-including child of `up` the walker enters after `node` (one of
/// its host-including children).
fn nextEntered(up: *NodeBase, node: *NodeBase, walker: anytype) ?*NodeBase {
    if (node.parent_node == null) {
        // A hosted root: `up`'s shadow root or its template contents.
        var hosted: [2]?*NodeBase = undefined;
        const roots = refcount.hostedRoots(up, &hosted);
        const after_shadow = roots.len == 2 and roots[0] == node;
        return firstEntered(up, if (after_shadow) .template_contents else .children, walker);
    }
    var sibling = node.next_sibling;
    while (sibling) |s| : (sibling = s.next_sibling) {
        if (walker.enters(s)) return s;
    }
    return null;
}
