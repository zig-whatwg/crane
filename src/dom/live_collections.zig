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
const Hook = @import("hook.zig").Hook;

const runtime = @import("runtime");
const NodeBase = @import("node_base.zig").NodeBase;

/// A document version covers tree, attribute and character data mutations,
/// adoption included, and the form association changes that are not
/// mutations (refcount.formAssociationChanged), and nothing else (a free is
/// not a mutation). The
/// refcount owner updates it at those mutation boundaries. Null means no live
/// document version is available - none, or a document whose teardown has
/// begun: always recompute.
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

    /// The instance while its slot holds it and its teardown has not
    /// finished. The generation and the cleanup bit are both in the slot's
    /// stamp (runtime.SlabAllocator, runtime.instance_lifecycle): no
    /// registry read. Every read of a cached entry or cursor makes this
    /// check, because the tree version does not move on frees
    /// (refcount.nodeFreed).
    pub fn get(self: Link) ?*runtime.Instance {
        if (runtime.SlabAllocator.generationOf(self.instance) != self.generation or
            runtime.instance_lifecycle.isCleanedUp(self.instance)) return null;
        return self.instance;
    }

    /// `get` for a registry's weak link that hands its node out (refcount
    /// step 5i: a form's named-element cache and past names never count):
    /// once weak references see garbage, a node of a garbage tree reads as
    /// gone too (dom.refcount.weakLinkLive).
    pub fn getWeak(self: Link) ?*runtime.Instance {
        const instance = self.get() orelse return null;
        if (!@import("refcount.zig").weakLinkLive(instance, self.generation)) return null;
        return instance;
    }
};

/// What a node's tree node names as its node document - a document names
/// itself - as a key `IndexCache.fresh` compares (NodeBase.documentKey).
fn documentKey(root_base: *const NodeBase) usize {
    if (root_base.node_type == NodeBase.DOCUMENT_NODE) return root_base.keyAsDocument();
    return root_base.documentKey();
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
    /// and its tree version has not moved. One registry read (the document's
    /// counts) against `begin`'s six; false sends the caller to `begin`.
    ///
    /// Every mutation and adoption of a node of the document moves the
    /// version, so a true answer says the walk the cache remembers is still
    /// the tree's: no node entered or left the root's subtree. Frees do not
    /// move it (refcount.nodeFreed), and need not: a node the cache
    /// remembers is in the root's subtree, and the collection being read
    /// keeps its root (node_holds.MemberHold: an edge from its wrapper), so
    /// the root's tree is not garbage and no teardown of it has begun. A node
    /// leaves a tree that is not garbage only by removal, which moves the
    /// version before the node can be freed. A document's own teardown
    /// takes its counts first (Document's deinitOwn runs before Node's
    /// deinit tears its tree down), so its version reads null from then
    /// on. Each cached entry is still read through `Link.get`, which sees
    /// a teardown that has finished.
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
                node = link.get();
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
    /// Make `collection` the named-property collection of `document` for
    /// `name` (domindex1): a Document's named elements, or the elements
    /// among its Window's named objects, read from the document's maps
    /// (dom.tree_ordered_map). Null while HTMLCollection installs none.
    named_items: ?*const fn (collection: *runtime.Instance, document: *runtime.Instance, kind: NamedKind, name: []const u8) error{OutOfMemory}!void = null,
};

/// Which named-property collection (dom.tree_ordered_map.NamedKind).
pub const NamedKind = @import("tree_ordered_map.zig").NamedKind;

/// Process-wide, written once at start-up (process_start.zig).
var implementation: Hook(?Implementation) = .init(null);

/// Called by HTMLCollection's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    implementation.install(impl);
}

/// Make `collection` - just created, empty - the live collection of `root`'s
/// element children.
pub fn elementChildren(collection: *runtime.Instance, root: *runtime.Instance) !void {
    const impl = implementation.get() orelse return error.NotSupported;
    impl.element_children(collection, root);
}

/// Make `collection` - just created, empty - DOM's "list of elements with
/// class names `class_names`" for `root`: live, over `root`'s descendant
/// elements that have every class in the set `class_names` names.
///
/// Spec: https://dom.spec.whatwg.org/#concept-getelementsbyclassname
pub fn elementsWithClassNames(collection: *runtime.Instance, root: *runtime.Instance, class_names: []const u8) !void {
    const impl = implementation.get() orelse return error.NotSupported;
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
    const impl = implementation.get() orelse return error.NotSupported;
    try impl.qualified_name(collection, root, qualified_name);
}

/// Make `collection` - just created, empty - DOM's "list of elements with
/// namespace `namespace` and local name `local_name`" for `root` (live; "*"
/// in either matches any; an empty namespace is null).
///
/// Spec: https://dom.spec.whatwg.org/#concept-getelementsbytagnamens
pub fn elementsWithNamespaceAndLocalName(collection: *runtime.Instance, root: *runtime.Instance, namespace: ?[]const u8, local_name: []const u8) !void {
    const impl = implementation.get() orelse return error.NotSupported;
    try impl.namespace_local_name(collection, root, namespace, local_name);
}

/// The live document collection for HTML's corresponding tree accessor.
pub fn documentElements(collection: *runtime.Instance, document: *runtime.Instance, filter: DocumentFilter) !void {
    (implementation.get() orelse return error.NotSupported).document_elements(collection, document, filter);
}

pub fn formControls(collection: *runtime.Instance, root: *runtime.Instance, fieldset: bool) !void {
    (implementation.get() orelse return error.NotSupported).form_controls(collection, root, fieldset);
}

/// HTML 4.10.7: the select's live options, optionally only selected options.
pub fn selectOptions(collection: *runtime.Instance, select: *runtime.Instance, selected_only: bool) !void {
    (implementation.get() orelse return error.NotSupported).select_options(collection, select, selected_only);
}

pub fn table(collection: *runtime.Instance, root: *runtime.Instance, filter: TableFilter) !void {
    (implementation.get() orelse return error.NotSupported).table(collection, root, filter);
}

/// HTML 3.1.7 named getter step 4 ("an HTMLCollection rooted at the
/// Document node, whose filter matches only named elements with the name
/// name") and 7.2.2.3 step 4 (the same, for a Window's named objects):
/// make `collection` - just created, empty - that live collection.
pub fn namedItems(collection: *runtime.Instance, document: *runtime.Instance, kind: NamedKind, name: []const u8) !void {
    const step = (implementation.get() orelse return error.NotSupported).named_items orelse return error.NotSupported;
    try step(collection, document, kind, name);
}

/// The owner-checked live root, or null after its native lifetime ends.
pub fn rootOf(collection: *runtime.Instance) ?*runtime.Instance {
    return (implementation.get() orelse return null).root(collection);
}

/// One of DOM's element lists by argument (4.2.6): what getElementsByClassName,
/// getElementsByTagName and getElementsByTagNameNS return for a root.
pub const Query = union(enum) {
    /// "the list of elements with class names `classNames`" (a non-empty
    /// set of classes: the empty set's list is no live list).
    class_names: []const u8,
    /// "the list of elements with qualified name `qualifiedName`".
    qualified_name: []const u8,
    /// "the list of elements with namespace `namespace` and local name
    /// `localName`" (step 1, "" as null, is the list's own).
    namespace_local_name: struct { namespace: ?[]const u8, local_name: []const u8 },
};

/// What getElementsByClassName, getElementsByTagName and
/// getElementsByTagNameNS return for `root` (lane perf2): the live
/// collection made for this root and argument before, while it lives, else
/// a new one, kept. DOM 4.2.6: "When invoked with the same argument[s], the
/// same HTMLCollection object may be returned as returned by an earlier
/// call" (for the qualified-name list, "as long as root's node document's
/// type has not changed": the list is kept under the root's CURRENT node
/// document, so an adopted root gets one of its new document's). All three
/// browsers do: Blink and WebKit keep each list in the root's
/// NodeListsNodeData (EnsureCachedCollection<ClassCollection /
/// TagCollection / TagCollectionNS>, keyed by type and name, weakly), Gecko
/// in nsContentList's hashtables (NS_GetContentList,
/// GetFuncStringContentList). The cache is weak (dom.tree_ordered_map
/// `cachedList`): the wrapper owns the collection, as for a new one.
///
/// So the caller hands it to script and NEVER frees it: another caller may
/// hold the same object. A native step that reads a list and lets it go
/// makes its own with `newCollection`.
pub fn collectionFor(root: *runtime.Instance, query: Query) !*runtime.Instance {
    const tree_ordered_map = @import("tree_ordered_map.zig");
    const document = nodeDocument(root) orelse return newCollection(root, query);
    const key: tree_ordered_map.ListKey = switch (query) {
        .class_names => |names| .{ .kind = .class_names, .root = root, .root_generation = runtime.SlabAllocator.generationOf(root), .name = names },
        .qualified_name => |name| .{ .kind = .qualified_name, .root = root, .root_generation = runtime.SlabAllocator.generationOf(root), .name = name },
        .namespace_local_name => |q| blk: {
            // Step 1, "If namespace is the empty string, then set it to
            // null", before the key: ("", x) and (null, x) are one list, as
            // in Blink's getElementsByTagNameNS.
            const namespace: ?[]const u8 = if (q.namespace) |ns| (if (ns.len == 0) null else ns) else null;
            break :blk .{ .kind = .namespace_local_name, .root = root, .root_generation = runtime.SlabAllocator.generationOf(root), .has_namespace = namespace != null, .namespace = namespace orelse "", .name = q.local_name };
        },
    };
    if (tree_ordered_map.cachedList(document, key)) |kept| return kept;
    const collection = try newCollection(root, query);
    tree_ordered_map.rememberList(document, key, collection);
    return collection;
}

/// A NEW live collection for `query` over `root`, the caller's own: no one
/// else is handed it, and the caller frees it (a native step that reads a
/// list and lets it go, or a [SameObject] attribute whose collection HTML
/// defines with a filter of its own - Blink's HTMLDataListOptionsCollection,
/// its kMapAreas collection). Script's getElementsBy* calls get the kept one
/// instead (`collectionFor`).
pub fn newCollection(root: *runtime.Instance, query: Query) !*runtime.Instance {
    const interfaces = @import("interfaces");
    const collection = try interfaces.HTMLCollection.init(root.ctx.getAllocator(), root.ctx);
    errdefer interfaces.HTMLCollection.deinit(collection);
    switch (query) {
        .class_names => |names| try elementsWithClassNames(collection, root, names),
        .qualified_name => |name| try elementsWithQualifiedName(collection, root, name),
        .namespace_local_name => |q| try elementsWithNamespaceAndLocalName(collection, root, q.namespace, q.local_name),
    }
    return collection;
}

test "elementChildren without an installed implementation reports NotSupported" {
    const std = @import("std");
    const override = implementation.overrideForTest(null);
    defer override.restore();
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
