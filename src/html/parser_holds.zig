//! The live HTML parsers of a Browser, and the DOM removing steps that let a
//! parser rescue a tree script detaches from under it.
//!
//! A parser holds natively the nodes its own structures name: the stack of
//! open elements and the head and form element pointers (HTML 13.2.4.2-4).
//! No wrapper is made for them. Blink traces exactly those structures
//! (HTMLConstructionSite::Trace visits open_elements_, head_ and form_, and
//! HTMLStackItem holds a Member<ContainerNode>); WebKit's HTMLElementStack
//! records own their nodes with a RefPtr. Crane has no tracing of native
//! objects, and the collector frees a node only as the root of its tree (or
//! inside a freed root's subtree), so a held node is safe for as long as its
//! tree's root is either the parser's Document or a node whose wrapper the
//! parser has rooted.
//!
//! The only ways a held node leaves its Document's tree are a removal and a
//! failed parser insertion. This module hears every removal, through a DOM
//! removing-steps callback installed once at process start, and acts on the
//! removal ROOT only - the node left parentless by it (DOM 4.2.3 "remove",
//! step 11; the descendants of step 14 still have their parents). It asks each
//! live parser of the Browser whether that root is a host-including inclusive
//! ancestor of a node it holds, and a parser that says yes rescues the root:
//! it roots that ONE wrapper from a fixed, collectible member of its Document
//! until it is released (`DocumentParser.rescue`).
//!
//! Design: tmp/plans/parser-holds-design.md (5.1-5.3); lesson
//! docs/lessons/architecture-parser-holds-are-its-structures-and-detached-trees-are-rescued.md.

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const NodeBase = dom.NodeBase;
const DocumentParser = @import("scripted_parser.zig").DocumentParser;

/// A Browser's live document parsers: a supplement of its scope
/// (runtime.BrowserScope, docs/instances.md rule 2), reached through the
/// realm of the node a removal detaches.
///
/// A parser registers when it is created in a realm that has an engine, and
/// unregisters when its last reference goes (`DocumentParser.release`) - an
/// old parser that `document.open` replaced while it is still on the native
/// stack stays registered, and still rescues, until then (HTML's
/// "abort a parser" leaves the unwinding frames to finish).
///
/// The DOM and its parsers live on the Browser's window agent thread: every
/// registration, every walk and every rescue happens there. The mutex guards
/// the list as a supplement must, and is never held across a rescue, which
/// makes wrappers and may let the collector finalize objects.
pub const ParserRegistry = struct {
    allocator: Allocator,
    mutex: std.Io.Mutex = .init,
    parsers: std.ArrayListUnmanaged(*DocumentParser) = .empty,

    pub fn init(allocator: Allocator) ParserRegistry {
        return .{ .allocator = allocator };
    }

    /// The scope's end. A parser still registered outlives the Browser's
    /// scope only by leaking; it no longer names this registry.
    pub fn deinit(self: *ParserRegistry) void {
        for (self.parsers.items) |parser| parser.registry = null;
        self.parsers.deinit(self.allocator);
    }

    /// The registry of the Browser `realm` belongs to, made on first use; null
    /// for a realm with no Browser scope (a test realm).
    pub fn of(realm: runtime.Context) ?*ParserRegistry {
        const scope = realm.browser_scope orelse return null;
        return scope.of(ParserRegistry) catch null;
    }

    /// The registry of the Browser `realm` belongs to, if one was made.
    pub fn existingOf(realm: runtime.Context) ?*ParserRegistry {
        const scope = realm.browser_scope orelse return null;
        return scope.existing(ParserRegistry);
    }

    pub fn register(self: *ParserRegistry, parser: *DocumentParser) Allocator.Error!void {
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        try self.parsers.append(self.allocator, parser);
    }

    pub fn unregister(self: *ParserRegistry, parser: *DocumentParser) void {
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        for (self.parsers.items, 0..) |registered, i| {
            if (registered != parser) continue;
            _ = self.parsers.orderedRemove(i);
            return;
        }
    }

    /// Reserve the next index of `parser`'s Document's kept-roots container.
    /// Every parser of one Document writes into that one array (an old parser
    /// still unwinding, and the parser `document.open` installed after it), so
    /// the index is one past the highest any registered parser of the same
    /// Document reserved. A parser clears its slots before it unregisters, so
    /// no live parser's slot is ever reused. Reserved before any engine
    /// allocation: a rescue that reenters cannot take the same index.
    pub fn reserveSlot(self: *ParserRegistry, parser: *DocumentParser) usize {
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        var next = parser.kept_slot_end;
        for (self.parsers.items) |other| {
            if (other.document != parser.document or other.document_generation != parser.document_generation) continue;
            next = @max(next, other.kept_slot_end);
        }
        parser.kept_slot_end = next + 1;
        return next;
    }

    /// The removing steps' question to every live parser: does `root` - left
    /// parentless by a removal - contain a node you hold? Each parser that
    /// does rescues `root`. The walks only read parser structures; rescues run
    /// after the lock is released, with each parser retained across its own.
    fn rescueTreesContaining(self: *ParserRegistry, root: *runtime.Instance, root_base: *NodeBase) void {
        var start: usize = 0;
        while (true) {
            var batch: [8]*DocumentParser = undefined;
            var count: usize = 0;
            var done = true;
            {
                std.Io.Threaded.mutexLock(&self.mutex);
                defer std.Io.Threaded.mutexUnlock(&self.mutex);
                var i = start;
                while (i < self.parsers.items.len) : (i += 1) {
                    if (count == batch.len) {
                        done = false;
                        break;
                    }
                    const parser = self.parsers.items[i];
                    if (!parser.holdsNodeUnder(root_base)) continue;
                    parser.retain();
                    batch[count] = parser;
                    count += 1;
                }
                start = i;
            }
            for (batch[0..count]) |parser| {
                parser.rescue(root);
                parser.release();
            }
            if (done) return;
        }
    }
};

/// Installed once, at process start (crane.Process; docs/instances.md
/// "Hooks"). The callback list it joins is dom.mutation's own; this module
/// adds no state of its own.
pub fn installHooks() void {
    dom.mutation.registerRemovingStepsCallback(onRemovingSteps) catch {};
}

/// DOM "removing steps" for every node: act only on the removal root. A
/// descendant is visited with its parent still set; a shadow root, the other
/// parentless node step 14 visits, is inside the removed tree through its host.
fn onRemovingSteps(node: *NodeBase, old_parent: ?*NodeBase) void {
    _ = old_parent;
    if (node.parent_node != null) return;
    const opaque_instance = dom.instance_bridge.getInstance(node) orelse return;
    const instance: *runtime.Instance = @ptrCast(@alignCast(opaque_instance));
    if (node.node_type == NodeBase.DOCUMENT_FRAGMENT_NODE and instance.stateAs(interfaces.ShadowRoot.State) != null) return;
    const registry = ParserRegistry.existingOf(instance.ctx) orelse return;
    if (registry.parsers.items.len == 0) return;
    registry.rescueTreesContaining(instance, node);
}

/// Whether `root` - a parentless node - is a host-including inclusive
/// ancestor of `node` (DOM: "either A is an inclusive ancestor of B, or B's
/// root has a non-null host and A is a host-including inclusive ancestor of
/// B's root's host"). The walk stops early at `known_outside`, a node already
/// known not to be under `root`, and at a Document.
pub fn isUnderRoot(node: *NodeBase, root: *NodeBase, known_outside: ?*NodeBase) bool {
    var current = node;
    while (true) {
        if (current == root) return true;
        if (known_outside) |outside| if (current == outside) return false;
        if (current.parent_node) |parent| {
            current = parent;
            continue;
        }
        current = hostOfRoot(current) orelse return false;
    }
}

/// The root of `node`'s host-including tree: the root of its tree, or - when
/// that root is a fragment with a host (a template's contents, a shadow
/// root) - the host-including root of the host.
pub fn hostIncludingRoot(node: *NodeBase) *NodeBase {
    var current = node;
    while (true) {
        if (current.parent_node) |parent| {
            current = parent;
            continue;
        }
        current = hostOfRoot(current) orelse return current;
    }
}

/// The host of a parentless fragment, or null.
fn hostOfRoot(root: *NodeBase) ?*NodeBase {
    if (root.node_type != NodeBase.DOCUMENT_FRAGMENT_NODE) return null;
    const opaque_instance = dom.instance_bridge.getInstance(root) orelse return null;
    const instance: *runtime.Instance = @ptrCast(@alignCast(opaque_instance));
    const host = dom.template_contents.host(instance) orelse return null;
    return dom.instance_bridge.getNodeBase(host);
}
