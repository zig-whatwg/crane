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
//! The Debug oracle (-Dwrapper-trace-check, the V8 adapter's node_wrappers.zig)
//! walks the same trees unpruned (`forEachWrapped`) after each major GC.

const std = @import("std");
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
    walkTree(roots[0], node, tracer);
    if (roots[1]) |document| walkTree(document, node, tracer);
}

/// The roots of the trees `node` keeps: its host-including tree's, and its
/// node document's when that is another tree (null otherwise).
pub fn treeRoots(node: *NodeBase) [2]?*NodeBase {
    const tree_root = refcount.root(null, node);
    const document = refcount.liveNodeDocument(node);
    return .{ tree_root, if (document != null and document.? != tree_root) document else null };
}

/// The held part of `tree_root`'s tree, once per collection: each wrapper in
/// it named to the engine (`target`'s own excepted when it is a lone root).
fn walkTree(maybe_root: ?*NodeBase, target: *NodeBase, tracer: *engine.Tracer) void {
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
        return;
    }
    if (!engine.traceVisitOnce(tracer, tree_root)) return;
    walkDown(tree_root, Pruned{ .tracer = tracer });
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
    }
};

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
