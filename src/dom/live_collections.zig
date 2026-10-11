//! HTMLCollection's live filters, as the seam other impls create them through.
//!
//! `children` is ParentNode's attribute, but what it returns - "an
//! HTMLCollection collection rooted at this matching only element children" -
//! is a collection HTMLCollection maintains: it re-reads the tree whenever the
//! tree has changed since its last read. ParentNode may not reach into
//! HTMLCollection's impl to set that up, so HTMLCollection installs its filters
//! here when it creates a collection - necessarily before anyone holds one to
//! make live - and ParentNode asks for the one it needs. The same shape as
//! `abort_algorithms.zig`.
//!
//! lint-impls: hook for HTMLCollection
const process_start = @import("process_start.zig");

const runtime = @import("runtime");
const NodeBase = @import("node_base.zig").NodeBase;

/// A document version covers tree and attribute mutations, including adoption
/// and teardown. The refcount owner updates it at those mutation boundaries.
/// Null means no live document version is available: always recompute.
pub fn treeVersion(document: *runtime.Instance) ?u64 {
    return @import("refcount.zig").treeVersion(document);
}

/// The traced slot a live collection's wrapper keeps its root's opaque root
/// in (dom.node_holds.MemberHold; refcount design 5h). One slot for every kind
/// of collection, HTMLCollection's and NodeList's.
pub const root_slot: @import("engine").TracedSlot = .{ .name = "live-collection:root" };

/// A teardown check, not a hold: a cached entry, or a root a collection
/// reads. A mutation invalidates the cache before a removed node can be
/// reused. The collection's hold on its root is a node_holds.MemberHold.
pub const Link = struct {
    instance: *runtime.Instance,
    generation: u64,

    pub fn to(instance: *runtime.Instance) Link {
        return .{ .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance) };
    }

    pub fn get(self: Link) ?*runtime.Instance {
        if (runtime.SlabAllocator.generationOf(self.instance) != self.generation or
            runtime.instance_lifecycle.isCleanedUp(self.instance)) return null;
        return self.instance;
    }

    /// `get` by the slab generation alone, for an entry of a cache whose
    /// document's tree version has not moved since the entry was cached:
    /// every free of a node of that document moves it (refcount.nodeFreed),
    /// so the entry's teardown cannot have begun. The generation stays the
    /// net.
    pub fn getUnchanged(self: Link) ?*runtime.Instance {
        if (runtime.SlabAllocator.generationOf(self.instance) != self.generation) return null;
        return self.instance;
    }
};

/// What a node's tree node names as its node document - the document's own
/// tree node; a document names itself - as a key `IndexCache.fresh` compares.
fn documentKey(root_base: *const NodeBase) usize {
    if (root_base.node_type == NodeBase.DOCUMENT_NODE) return @intFromPtr(root_base);
    return @intFromPtr(root_base.owner_document);
}

/// The root's CURRENT node document, so adoption cannot reuse the old
/// document's version even if both documents happen to have the same number.
pub fn nodeDocument(root: *runtime.Instance) ?*runtime.Instance {
    const interfaces = @import("interfaces");
    if ((interfaces.Node.get_nodeType(root) catch 0) == interfaces.Node.get_DOCUMENT_NODE()) return root;
    return interfaces.Node.get_ownerDocument(root) catch null;
}

/// DOM's live view, amortized across unchanged reads. As in Blink's
/// core/dom/collection_index_cache.h (NodeCount/NodeAt), remember a cursor
/// and the length independently. The walk supplies first() and next(node).
/// No engine, allocation, mutation observer, or process-global cache state.
pub const IndexCache = struct {
    version: ?u64 = null,
    document: ?Link = null,
    /// `documentKey` of the root when `document` was read (`keyDocument`);
    /// 0 until then. The cheap half of `fresh`.
    document_key: usize = 0,
    length: ?u32 = null,
    last: ?Link = null,
    last_index: u32 = 0,

    /// Call before EACH read, with the producer's saved root generation.
    /// Returns true only when all cached information is still usable.
    pub fn begin(self: *IndexCache, root: Link, document: ?*runtime.Instance, version: ?u64) bool {
        const root_live = root.get() != null;
        // Drop invalidated state before inspecting old links. In particular,
        // adoption must not dereference the previous document just to discard it.
        if (root_live and version != null and version == self.version and document != null) {
            if (self.document) |link| {
                if (link.instance == document.? and link.get() != null) {
                    const last_live = if (self.last) |last| last.get() != null else true;
                    if (last_live) return true;
                }
            }
        }
        self.* = .{};
        if (root_live and document != null and version != null) {
            self.document = Link.to(document.?);
            self.version = version;
        }
        return false;
    }

    /// Whether everything cached is still usable, checked cheaply enough for
    /// every indexed read: the root - alive, its collection holds it
    /// (node_holds.MemberHold), and `root_base` is its tree node - still
    /// names the document `begin` read, that document is the same slab slot,
    /// and its tree version has not moved. Every mutation, adoption and free
    /// of a node of the document moves the version, so a true answer also
    /// says every node the cache remembers is alive. One registry read (the
    /// document's counts) against `begin`'s six; false sends the caller to
    /// `begin`.
    pub fn fresh(self: *const IndexCache, root_base: *const NodeBase) bool {
        const version = self.version orelse return false;
        const document = self.document orelse return false;
        if (self.document_key == 0 or documentKey(root_base) != self.document_key) return false;
        if (runtime.SlabAllocator.generationOf(document.instance) != document.generation) return false;
        return treeVersion(document.instance) == version;
    }

    /// After `begin`: remember the document key of the root whose document
    /// `begin` read, for `fresh`.
    pub fn keyDocument(self: *IndexCache, root_base: *const NodeBase) void {
        self.document_key = if (self.document != null) documentKey(root_base) else 0;
    }

    pub fn remember(self: *IndexCache, index: u32, node: *runtime.Instance) void {
        self.last = Link.to(node);
        self.last_index = index;
    }

    pub fn item(self: *IndexCache, walk: anytype, index: u32) ?*runtime.Instance {
        if (self.length) |length| if (index >= length) return null;
        var offset: u32 = 0;
        var node: ?*runtime.Instance = null;
        if (self.last) |link| {
            if (index >= self.last_index) {
                // `begin` or `fresh` validated the cache against an unmoved
                // tree version for this read, or it would hold no cursor.
                node = link.getUnchanged();
                if (node != null) offset = self.last_index;
            }
        }
        if (node == null) node = walk.first();
        var previous: ?*runtime.Instance = null;
        while (node) |current| : (offset += 1) {
            if (offset == index) {
                self.remember(offset, current);
                return current;
            }
            previous = current;
            node = walk.next(current);
        }
        if (previous) |last| self.remember(offset - 1, last);
        self.length = offset;
        return null;
    }

    pub fn count(self: *IndexCache, walk: anytype) u32 {
        if (self.length) |length| return length;
        _ = self.item(walk, @import("std").math.maxInt(u32));
        return self.length.?;
    }
};

/// HTML document collections, restricted to HTML-namespace descendants.
pub const DocumentFilter = enum { images, embeds, links, forms, scripts, anchors };

/// HTML 4.9 table collections, each rooted in its owning table/section/row.
pub const TableFilter = enum { bodies, table_rows, section_rows, row_cells };

/// What the HTMLCollection impl supplies.
pub const Implementation = struct {
    /// Make `collection` live over `root`'s element children, in tree order.
    element_children: *const fn (collection: *runtime.Instance, root: *runtime.Instance) void,
    /// Make `collection` DOM's "list of elements with class names
    /// `class_names`" for `root` (a non-empty set of classes).
    class_names: *const fn (collection: *runtime.Instance, root: *runtime.Instance, class_names: []const u8) error{OutOfMemory}!void,
    /// Make `collection` DOM's "list of elements with qualified name
    /// `qualified_name`" for `root`.
    qualified_name: *const fn (collection: *runtime.Instance, root: *runtime.Instance, qualified_name: []const u8) error{OutOfMemory}!void,
    /// Make `collection` DOM's "list of elements with namespace `namespace`
    /// and local name `local_name`" for `root`.
    namespace_local_name: *const fn (collection: *runtime.Instance, root: *runtime.Instance, namespace: ?[]const u8, local_name: []const u8) error{OutOfMemory}!void,
    document_elements: *const fn (collection: *runtime.Instance, document: *runtime.Instance, filter: DocumentFilter) void,
    form_controls: *const fn (*runtime.Instance, *runtime.Instance, bool) void,
    select_options: *const fn (*runtime.Instance, *runtime.Instance, bool) void,
    table: *const fn (*runtime.Instance, *runtime.Instance, TableFilter) void,
    root: *const fn (*runtime.Instance) ?*runtime.Instance,
};

/// Process-wide, written once at start-up (process_start.zig).
var implementation: ?Implementation = null;

/// Called by HTMLCollection's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// Make `collection` - just created, empty - the live collection of `root`'s
/// element children.
pub fn elementChildren(collection: *runtime.Instance, root: *runtime.Instance) !void {
    const impl = implementation orelse return error.NotSupported;
    impl.element_children(collection, root);
}

/// Make `collection` - just created, empty - DOM's "list of elements with
/// class names `class_names`" for `root`: live, over `root`'s descendant
/// elements that have every class in the set `class_names` names.
///
/// Spec: https://dom.spec.whatwg.org/#concept-getelementsbyclassname
pub fn elementsWithClassNames(collection: *runtime.Instance, root: *runtime.Instance, class_names: []const u8) !void {
    const impl = implementation orelse return error.NotSupported;
    try impl.class_names(collection, root, class_names);
}

/// Make `collection` - just created, empty - DOM's "list of elements with
/// qualified name `qualified_name`" for `root`: live, over `root`'s
/// descendant elements; in an HTML document an HTML element's qualified name
/// is compared with `qualified_name` in ASCII lowercase. Whether the document
/// is an HTML document is read now, once, as the spec's steps do.
///
/// Spec: https://dom.spec.whatwg.org/#concept-getelementsbytagname
pub fn elementsWithQualifiedName(collection: *runtime.Instance, root: *runtime.Instance, qualified_name: []const u8) !void {
    const impl = implementation orelse return error.NotSupported;
    try impl.qualified_name(collection, root, qualified_name);
}

/// Make `collection` - just created, empty - DOM's "list of elements with
/// namespace `namespace` and local name `local_name`" for `root` (live; "*"
/// in either matches any; an empty namespace is null).
///
/// Spec: https://dom.spec.whatwg.org/#concept-getelementsbytagnamens
pub fn elementsWithNamespaceAndLocalName(collection: *runtime.Instance, root: *runtime.Instance, namespace: ?[]const u8, local_name: []const u8) !void {
    const impl = implementation orelse return error.NotSupported;
    try impl.namespace_local_name(collection, root, namespace, local_name);
}

/// The live document collection for HTML's corresponding tree accessor.
pub fn documentElements(collection: *runtime.Instance, document: *runtime.Instance, filter: DocumentFilter) !void {
    (implementation orelse return error.NotSupported).document_elements(collection, document, filter);
}

pub fn formControls(collection: *runtime.Instance, root: *runtime.Instance, fieldset: bool) !void {
    (implementation orelse return error.NotSupported).form_controls(collection, root, fieldset);
}

/// HTML 4.10.7: the select's live options, optionally only selected options.
pub fn selectOptions(collection: *runtime.Instance, select: *runtime.Instance, selected_only: bool) !void {
    (implementation orelse return error.NotSupported).select_options(collection, select, selected_only);
}

pub fn table(collection: *runtime.Instance, root: *runtime.Instance, filter: TableFilter) !void {
    (implementation orelse return error.NotSupported).table(collection, root, filter);
}

/// The owner-checked live root, or null after its native lifetime ends.
pub fn rootOf(collection: *runtime.Instance) ?*runtime.Instance {
    return (implementation orelse return null).root(collection);
}

test "elementChildren without an installed implementation reports NotSupported" {
    const std = @import("std");
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with no implementation the call does not reach it.
    var object: runtime.Instance = undefined;
    try std.testing.expectError(error.NotSupported, elementChildren(&object, &object));
    try std.testing.expectError(error.NotSupported, elementsWithClassNames(&object, &object, "a"));
    try std.testing.expectError(error.NotSupported, elementsWithQualifiedName(&object, &object, "a"));
    try std.testing.expectError(error.NotSupported, elementsWithNamespaceAndLocalName(&object, &object, null, "a"));
    try std.testing.expectError(error.NotSupported, documentElements(&object, &object, .images));
    try std.testing.expectError(error.NotSupported, selectOptions(&object, &object, false));
    try std.testing.expectEqual(null, rootOf(&object));
}
