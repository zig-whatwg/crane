//! A tree scope's maps from an element's ID - and a document's, from its
//! named properties' names - to the elements of that tree scope: what
//! getElementById, the Document's named getter and the Window's named
//! properties answer from, instead of walking the tree on every read.
//!
//! Blink's TreeOrderedMap (core/dom/tree_ordered_map.{h,cc}) and WebKit's
//! TreeScopeOrderedMap (Source/WebCore/dom/TreeScopeOrderedMap.cpp), whose
//! design this takes: an entry per key remembers how many elements of the
//! scope have that key and, once a reader asked, which of them is first in
//! tree order. Adding a second element forgets the first (it may precede the
//! old one); removing the first keeps the second when the entry's ordered
//! list is known; a reader that finds no first walks the scope's tree to the
//! first element with the key and remembers it (Blink TreeOrderedMap::Get).
//! The ordered list a collection reads is built the same way, on demand
//! (Blink GetAllElementsById). A key one element has - nearly every ID - is
//! answered without a walk.
//!
//! The kinds of key (`Kind`):
//! - `id` (DOM 4.2.4 getElementById: "the first element, in tree order,
//!   within this's descendants, whose ID is elementId"), for a Document's and
//!   a ShadowRoot's tree (Blink TreeScope::elements_by_id_);
//! - `document_named`, a Document's named elements (HTML 3.1.7, "Document
//!   named properties"; WebKit HTMLDocument::m_documentNamedItem,
//!   DocumentNameCollection::elementMatches);
//! - `window_named`, the elements among a Window's named objects (HTML
//!   7.2.2.3; WebKit m_windowNamedItem, WindowNameCollection::elementMatches).
//!   The document-tree child navigables named by their target name are the
//!   Window's to find, not this map's.
//!
//! The maps are EXACT, by construction: mutation.zig calls `inserted`,
//! `removed` and `moved` where it links and unlinks a node - before any
//! insertion, removing or moving step, form owner reset or slot assignment
//! can read them (Blink and WebKit update theirs in InsertedInto/RemovedFrom,
//! before IdTargetObserver notification) - and Element calls
//! `beginChange`/`endChange` around its id and name attribute change steps.
//! Each walks the moved node's LIGHT subtree: a shadow tree inside it keeps
//! its own tree scope. Adoption needs no step of its own (adopt step 2
//! removes the node, the insertion that follows adds it). An entry holds
//! links (instance and slab generation), never a bare pointer a reader would
//! trust: a link that no longer reads its element means the maps are not
//! exact.
//!
//! EXACT OR WALK. An allocation that fails while the maps change (a key's
//! copy, a hash insert) leaves them DEGRADED: emptied, no hook updates them,
//! and every reader first tries to rebuild them from a walk of the scope's
//! tree and, while that fails, walks the tree for its answer. A link that
//! no longer reads its element, or a walk that finds fewer elements than an
//! entry counts, degrades them too (and logs it: it is a bug).
//!
//! The TYPE lives here and the tree scope keeps the state (the element_data
//! pattern): Document's and ShadowRoot's InternalState embed one `Maps` by
//! value, and each installs its accessor from its installHooks.
//!
//! A Document also keeps here the HTMLCollections its and its Window's named
//! getters made for a name with several matches, by link: Blink's
//! EnsureCachedCollection (kDocumentNamedItems, kWindowNamedItems), a weak
//! cache, so `document.a === document.a` while the collection's wrapper
//! lives, and a new collection once it was collected. The wrapper cache owns
//! a collection; the cache holds no reference.
//!
//! lint-impls: hook for Document, ShadowRoot
const std = @import("std");
const tombstones = @import("infra").tombstones;
const runtime = @import("runtime");
const process_start = @import("process_start.zig");
const NodeBase = @import("node_base.zig").NodeBase;
const element_data = @import("element_data.zig");
const instance_bridge = @import("instance_bridge.zig");
const live_collections = @import("live_collections.zig");

const log = std.log.scoped(.tree_ordered_map);

const html_namespace = "http://www.w3.org/1999/xhtml";

/// What a key names, in a tree scope (the file's comment).
pub const Kind = enum { id, document_named, window_named };

/// The two named-property kinds, as the collections that read them name them.
pub const NamedKind = enum {
    /// A Document's named elements.
    document,
    /// The elements among a Window's named objects.
    window,

    fn kind(self: NamedKind) Kind {
        return switch (self) {
            .document => .document_named,
            .window => .window_named,
        };
    }
};

/// Which tree scope a `Maps` is: a ShadowRoot keeps IDs only.
pub const Scope = enum { document, shadow_root };

/// An element of the scope, by its instance and slab generation.
pub const Link = live_collections.Link;

/// An element's ID, its type for the named-element rules (an HTML element of
/// one of the five types, or `other`), and its name attribute's value when
/// that type reads it - read in place, borrowed for the call.
const Facts = struct {
    named_type: NamedType,
    id: []const u8,
    name: []const u8,

    fn hasKeys(self: Facts) bool {
        return self.id.len > 0 or self.name.len > 0;
    }
};

/// The HTML elements a name attribute can make a named element or object.
const NamedType = enum { other, embed, form, iframe, img, object };

fn namedTypeOf(data: *const element_data.ElementData) NamedType {
    const namespace = data.namespace_uri orelse return .other;
    if (!std.mem.eql(u8, namespace.asSlice(), html_namespace)) return .other;
    const local = data.local_name.asSlice();
    // Local names are case-sensitive: an HTML element made as "IMG" by
    // createElementNS is no img element.
    inline for (.{ "embed", "form", "iframe", "img", "object" }, .{ NamedType.embed, .form, .iframe, .img, .object }) |name, value| {
        if (std.mem.eql(u8, local, name)) return value;
    }
    return .other;
}

fn factsOfData(data: *const element_data.ElementData) Facts {
    const named_type = namedTypeOf(data);
    const name: []const u8 = if (named_type == .other) "" else if (element_data.getAttributeByNamespaceAndLocalName(data, null, "name")) |attribute| attribute.value else "";
    return .{ .named_type = named_type, .id = data.id.asSlice(), .name = name };
}

fn instanceOf(node: *NodeBase) ?*runtime.Instance {
    const raw = node.owner_instance orelse return null;
    return @ptrCast(@alignCast(raw));
}

fn factsOf(node: *NodeBase) ?Facts {
    if (node.node_type != NodeBase.ELEMENT_NODE) return null;
    const data = element_data.of(instanceOf(node) orelse return null) orelse return null;
    return factsOfData(data);
}

/// The keys an element with `facts` has as a `kind`, ID first (HTML's
/// supported property names list an element's ID before its name): at most
/// two, distinct, the empty string for none.
///
/// - document_named (HTML 3.1.7 "named element"): an embed, form, iframe,
///   img or object element by its name attribute; an object by its ID; an
///   img by its ID only while it has a non-empty name attribute too.
/// - window_named (HTML 7.2.2.3 "named objects"): an embed, form, img or
///   object element by its name attribute; any element by its ID.
fn keysOf(facts: Facts, kind: Kind) [2][]const u8 {
    var by_id: []const u8 = "";
    var by_name: []const u8 = "";
    switch (kind) {
        .id => by_id = facts.id,
        .document_named => {
            if (facts.named_type != .other) by_name = facts.name;
            if (facts.named_type == .object or (facts.named_type == .img and facts.name.len > 0)) by_id = facts.id;
        },
        .window_named => {
            if (facts.named_type != .other and facts.named_type != .iframe) by_name = facts.name;
            by_id = facts.id;
        },
    }
    if (std.mem.eql(u8, by_id, by_name)) by_name = "";
    return .{ by_id, by_name };
}

/// Whether an element with `facts` has `key` (non-empty) as a `kind`: the
/// filter the walks and the collections apply, the same rule as `keysOf`.
fn hasKey(facts: Facts, kind: Kind, key: []const u8) bool {
    const keys = keysOf(facts, kind);
    return std.mem.eql(u8, keys[0], key) or std.mem.eql(u8, keys[1], key);
}

fn kindsOf(scope: Scope) []const Kind {
    return switch (scope) {
        .document => &.{ .id, .document_named, .window_named },
        .shadow_root => &.{.id},
    };
}

/// One key's elements of one kind.
const Entry = struct {
    count: u32 = 0,
    /// The first of them in tree order, once a reader found it; null while
    /// unknown.
    first: ?Link = null,
    /// All of them in tree order, once a reader asked; null while unknown.
    ordered: ?[]Link = null,

    fn forgetOrder(self: *Entry, allocator: std.mem.Allocator) void {
        if (self.ordered) |list| allocator.free(list);
        self.ordered = null;
    }
};

const Slot = std.EnumArray(Kind, Entry);

/// The HTMLCollections a document's named getters made for one name.
const Collections = struct {
    document: ?Link = null,
    window: ?Link = null,

    fn of(self: *Collections, kind: NamedKind) *?Link {
        return switch (kind) {
            .document => &self.document,
            .window => &self.window,
        };
    }

    fn live(self: Collections) bool {
        if (self.document) |link| if (link.get() != null) return true;
        if (self.window) |link| if (link.get() != null) return true;
        return false;
    }
};

/// One tree scope's maps (the file's comment).
pub const Maps = struct {
    allocator: std.mem.Allocator,
    scope: Scope,
    /// Each key, owned, and its entries.
    map: std.StringHashMapUnmanaged(Slot) = .empty,
    /// Bounds `map`'s tombstones. Every new ID or name is a key the map
    /// never saw, and emptied keys leave in batches (`sweepEmptySlots`), so
    /// a document whose elements come and go never grew its map and never
    /// cleared them (a 1,069-file runner sample: starved in 44 of 4,082
    /// samples). An `*Entry` (`entryOf`) is read and written only between
    /// changes to the tree - no insert - and the map's walks (`clear`,
    /// `sweepEmptySlots`) insert nothing.
    map_guard: tombstones.TombstoneGuard = .{},
    /// How many registrations each kind holds: a kind with none answers
    /// every query without a lookup.
    totals: std.EnumArray(Kind, u32) = .initFill(0),
    /// The maps are not exact (the file's comment): no hook updates them,
    /// and every reader rebuilds them or walks.
    degraded: bool = false,
    /// The scope's teardown has begun: nothing is kept from here on.
    ended: bool = false,
    /// A document's named-property collections, by name (owned).
    // tombstones: a document's, written only when script reads a named property that makes a collection, and swept only past twice what stayed (`sweep_at`); empty at every insert of a 1,069-file runner sample
    collections: std.StringHashMapUnmanaged(Collections) = .empty,
    /// The size at which remembering a collection first sweeps out the names
    /// whose collections are all gone.
    sweep_at: u32 = 16,
    /// How many of `map`'s keys no element has any more (kept for reuse;
    /// `remove` says how long).
    empty_slots: u32 = 0,
    /// The most keys elements had at once since the last sweep of the
    /// emptied ones: what bounds how many emptied keys are kept.
    live_peak: u32 = 0,

    pub fn init(allocator: std.mem.Allocator, scope: Scope) Maps {
        return .{ .allocator = allocator, .scope = scope };
    }

    /// With the scope: frees everything, and keeps nothing after.
    pub fn deinit(self: *Maps) void {
        self.clear();
        self.map.deinit(self.allocator);
        var names = self.collections.keyIterator();
        while (names.next()) |name| self.allocator.free(name.*);
        self.collections.deinit(self.allocator);
        self.collections = .empty;
        self.map = .empty;
        self.ended = true;
        self.degraded = true;
    }

    /// Every key and entry goes; the maps are empty (and exact for an empty
    /// tree).
    fn clear(self: *Maps) void {
        var it = self.map.iterator();
        while (it.next()) |kv| {
            for (std.enums.values(Kind)) |kind| kv.value_ptr.getPtr(kind).forgetOrder(self.allocator);
            self.allocator.free(kv.key_ptr.*);
        }
        self.map.clearRetainingCapacity();
        self.map_guard.reset();
        self.totals = .initFill(0);
        self.empty_slots = 0;
        self.live_peak = 0;
    }

    /// An allocation failed, or the maps were found inexact: empty them and
    /// let every reader walk until a rebuild succeeds.
    fn degrade(self: *Maps) void {
        self.clear();
        self.degraded = true;
    }

    /// The kinds `key` is one of `facts`'s keys of, in this scope.
    fn kindsWithKey(self: *const Maps, facts: Facts, key: []const u8) std.EnumSet(Kind) {
        var kinds: std.EnumSet(Kind) = .initEmpty();
        for (kindsOf(self.scope)) |kind| {
            if (hasKey(facts, kind, key)) kinds.insert(kind);
        }
        return kinds;
    }

    /// Add `member` under `key` for each of `kinds`: one hash lookup.
    fn add(self: *Maps, kinds: std.EnumSet(Kind), key: []const u8, member: Link) error{OutOfMemory}!void {
        self.map_guard.beforeInsert(&self.map);
        const gop = try self.map.getOrPut(self.allocator, key);
        if (!gop.found_existing) {
            gop.key_ptr.* = self.allocator.dupe(u8, key) catch |err| {
                self.map.removeByPtr(gop.key_ptr);
                self.map_guard.noteRemoval(&self.map);
                return err;
            };
            gop.value_ptr.* = .initFill(.{});
            self.live_peak = @max(self.live_peak, self.map.count() - self.empty_slots);
        } else if (slotIsEmpty(gop.value_ptr)) {
            self.empty_slots -= 1;
        }
        var it = kinds.iterator();
        while (it.next()) |kind| {
            const entry = gop.value_ptr.getPtr(kind);
            // Blink TreeOrderedMap::Add: a second element may precede the
            // first.
            entry.first = if (entry.count == 0) member else null;
            entry.forgetOrder(self.allocator);
            entry.count += 1;
            self.totals.getPtr(kind).* += 1;
        }
    }

    /// Take `member` out from under `key` for each of `kinds`: one lookup,
    /// no allocation.
    fn remove(self: *Maps, kinds: std.EnumSet(Kind), key: []const u8, member: Link) void {
        const slot = self.map.getPtr(key) orelse return self.inexact("removed key not kept", key);
        var it = kinds.iterator();
        while (it.next()) |kind| {
            const entry = slot.getPtr(kind);
            if (entry.count == 0) return self.inexact("removed key not kept", key);
            if (entry.count == 1) {
                entry.forgetOrder(self.allocator);
                entry.* = .{};
            } else {
                // Blink TreeOrderedMap::Remove: the second of a known order
                // is the new first.
                if (entry.first) |first| if (sameLink(first, member)) {
                    entry.first = null;
                    if (entry.ordered) |list| if (list.len > 1 and sameLink(list[0], member)) {
                        entry.first = list[1];
                    };
                };
                entry.forgetOrder(self.allocator);
                entry.count -= 1;
            }
            self.totals.getPtr(kind).* -= 1;
        }
        if (!slotIsEmpty(slot)) return;
        // Its key stays for the next element that has it - a churn of the
        // same elements (all removed, then all put back) makes no key copy
        // and no hash insert - until the emptied keys outnumber the most the
        // scope had live at once since the last sweep (and 64), when they
        // all go: kept keys are bounded by twice the scope's peak, and each
        // sweep is paid for by at least as many removals as it visits.
        self.empty_slots += 1;
        if (self.empty_slots > @max(64, self.live_peak)) self.sweepEmptySlots();
    }

    fn sweepEmptySlots(self: *Maps) void {
        var it = self.map.iterator();
        while (it.next()) |kv| {
            if (!slotIsEmpty(kv.value_ptr)) continue;
            const owned = kv.key_ptr.*;
            self.map.removeByPtr(kv.key_ptr);
            self.map_guard.noteRemoval(&self.map);
            self.allocator.free(owned);
        }
        self.empty_slots = 0;
        self.live_peak = self.map.count();
    }

    fn inexact(self: *Maps, comptime what: []const u8, key: []const u8) void {
        log.err(what ++ ": the tree scope's maps are not exact (key \"{s}\"); readers walk the tree", .{key});
        self.degrade();
    }

    /// An element's distinct keys: its ID and its name (when its type reads
    /// it), each at most once.
    fn distinctKeys(facts: Facts) [2][]const u8 {
        return .{ facts.id, if (std.mem.eql(u8, facts.name, facts.id)) "" else facts.name };
    }

    /// Register an element with `facts` under each of its keys. A failed
    /// allocation degrades the maps: no half-registered element stays.
    fn register(self: *Maps, facts: Facts, member: Link) void {
        if (self.degraded) return;
        for (distinctKeys(facts)) |key| {
            if (key.len == 0) continue;
            const kinds = self.kindsWithKey(facts, key);
            if (kinds.count() == 0) continue;
            self.add(kinds, key, member) catch return self.degrade();
        }
    }

    fn unregister(self: *Maps, facts: Facts, member: Link) void {
        if (self.degraded) return;
        for (distinctKeys(facts)) |key| {
            if (key.len == 0) continue;
            const kinds = self.kindsWithKey(facts, key);
            if (kinds.count() == 0) continue;
            self.remove(kinds, key, member);
            if (self.degraded) return;
        }
    }

    /// Degraded maps rebuilt from a walk of `root`'s tree; false when that
    /// fails too (they stay degraded).
    fn rebuild(self: *Maps, root: *NodeBase) bool {
        if (!self.degraded) return true;
        if (self.ended) return false;
        self.degraded = false;
        var at = root.first_child;
        while (at) |node| : (at = nextInTree(node, root)) {
            const facts = factsOf(node) orelse continue;
            if (!facts.hasKeys()) continue;
            self.register(facts, Link.to(instanceOf(node).?));
            if (self.degraded) return false;
        }
        return true;
    }

    fn entryOf(self: *Maps, kind: Kind, key: []const u8) ?*Entry {
        if (self.totals.get(kind) == 0) return null;
        const slot = self.map.getPtr(key) orelse return null;
        const entry = slot.getPtr(kind);
        return if (entry.count == 0) null else entry;
    }
};

fn slotIsEmpty(slot: *const Slot) bool {
    for (std.enums.values(Kind)) |kind| if (slot.get(kind).count != 0) return false;
    return true;
}

fn sameLink(a: Link, b: Link) bool {
    return a.instance == b.instance and a.generation == b.generation;
}

// =============================================================================
// The owners' accessors
// =============================================================================

pub const Implementation = struct {
    document: ?*const fn (document: *runtime.Instance) ?*Maps = null,
    shadow_root: ?*const fn (shadow_root: *runtime.Instance) ?*Maps = null,
};

// process-wide: two immutable function pointers Document and ShadowRoot install once at process start (crane.Process); each reads only the object it is given, so one serves every Browser and thread
var implementation: Implementation = .{};

/// Called by Document's installHooks, once, at process start: `of` is the
/// document's maps, or null for an object that is no Document.
pub fn installDocument(of: *const fn (document: *runtime.Instance) ?*Maps) void {
    process_start.assertInstalling();
    implementation.document = of;
}

/// Called by ShadowRoot's installHooks, once, at process start: `of` is the
/// shadow root's maps, or null for a DocumentFragment that is no ShadowRoot.
pub fn installShadowRoot(of: *const fn (shadow_root: *runtime.Instance) ?*Maps) void {
    process_start.assertInstalling();
    implementation.shadow_root = of;
}

/// The maps of the tree scope whose root is `root`: a Document's or a
/// ShadowRoot's, else null (a tree rooted at an element or a plain
/// DocumentFragment is no tree scope's).
fn mapsOfRoot(root: *NodeBase) ?*Maps {
    const instance = instanceOf(root) orelse return null;
    const maps = switch (root.node_type) {
        NodeBase.DOCUMENT_NODE => (implementation.document orelse return null)(instance),
        NodeBase.DOCUMENT_FRAGMENT_NODE => (implementation.shadow_root orelse return null)(instance),
        else => return null,
    } orelse return null;
    return if (maps.ended) null else maps;
}

fn rootOf(node: *NodeBase) *NodeBase {
    var at = node;
    while (at.parent_node) |parent| at = parent;
    return at;
}

/// The node after `node` in `root`'s light tree, in tree order (preorder);
/// null past the end.
fn nextInTree(node: *NodeBase, root: *NodeBase) ?*NodeBase {
    if (node.first_child) |child| return child;
    var at = node;
    while (at != root) {
        if (at.next_sibling) |sibling| return sibling;
        at = at.parent_node orelse return null;
    }
    return null;
}

/// The scope of a subtree's new or old parent, found once, and only when the
/// subtree has an element with a key: most inserted nodes have none.
const LazyScope = struct {
    parent: *NodeBase,
    found: bool = false,
    maps: ?*Maps = null,

    fn get(self: *LazyScope) ?*Maps {
        if (!self.found) {
            self.found = true;
            self.maps = mapsOfRoot(rootOf(self.parent));
        }
        const maps = self.maps orelse return null;
        return if (maps.degraded) null else maps;
    }
};

// =============================================================================
// The mutation hooks (src/dom/mutation.zig)
// =============================================================================

/// DOM insert step 7, at the link: `node` was just linked under `parent`.
/// Its light subtree's elements join `parent`'s tree scope.
pub fn inserted(node: *NodeBase, parent: *NodeBase) void {
    var scope: LazyScope = .{ .parent = parent };
    var at: ?*NodeBase = node;
    while (at) |current| : (at = nextInTree(current, node)) {
        const facts = factsOf(current) orelse continue;
        if (!facts.hasKeys()) continue;
        const maps = scope.get() orelse return;
        maps.register(facts, Link.to(instanceOf(current).?));
    }
}

/// DOM remove step 7, at the unlink: `node` was just unlinked from
/// `old_parent`. Its light subtree's elements leave `old_parent`'s scope.
pub fn removed(node: *NodeBase, old_parent: *NodeBase) void {
    var scope: LazyScope = .{ .parent = old_parent };
    var at: ?*NodeBase = node;
    while (at) |current| : (at = nextInTree(current, node)) {
        const facts = factsOf(current) orelse continue;
        if (!facts.hasKeys()) continue;
        const maps = scope.get() orelse return;
        maps.unregister(facts, Link.to(instanceOf(current).?));
    }
}

/// DOM move steps 13-20, once `node` is linked under `new_parent`: its light
/// subtree's elements leave `old_parent`'s scope and join `new_parent`'s -
/// the same one, often, and the move still forgets their order. Not yet
/// reached: nothing calls mutation.move (moveBefore removes and inserts, so
/// it reaches `removed` and `inserted`), and mutation.move has never
/// compiled (docs/lessons/testing-a-hook-in-a-function-nothing-calls-has-never-compiled.md).
pub fn moved(node: *NodeBase, old_parent: *NodeBase, new_parent: *NodeBase) void {
    var old_scope: LazyScope = .{ .parent = old_parent };
    var new_scope: LazyScope = .{ .parent = new_parent };
    var at: ?*NodeBase = node;
    while (at) |current| : (at = nextInTree(current, node)) {
        const facts = factsOf(current) orelse continue;
        if (!facts.hasKeys()) continue;
        const member = Link.to(instanceOf(current).?);
        if (old_scope.get()) |maps| maps.unregister(facts, member);
        if (new_scope.get()) |maps| maps.register(facts, member);
    }
}

// =============================================================================
// The attribute change hooks (Element's attribute change steps)
// =============================================================================

/// An element's registration, between `beginChange` and `endChange`.
pub const Change = struct {
    maps: *Maps,
    member: Link,
};

/// What the element's name attribute was, for `beginChange`.
pub const OldName = union(enum) {
    /// Its name attribute stands (an ID change).
    current,
    /// It changed from this value ("" for none).
    was: []const u8,
};

/// Before `element`'s ID changes, or after its name attribute did: take it
/// out of its tree scope's maps as they hold it - its current ID, and
/// `old_name` or its current name. Null when it is in no tree scope. `data`
/// is the element's own (Element passes it: no lookup).
pub fn beginChange(element: *runtime.Instance, data: *const element_data.ElementData, old_name: OldName) ?Change {
    var facts = factsOfData(data);
    switch (old_name) {
        .current => {},
        // No kind reads the name of an element of no named type.
        .was => |value| {
            if (facts.named_type == .other) return null;
            facts.name = value;
        },
    }
    const node = instance_bridge.getNodeBase(element) orelse return null;
    // A parentless element is its own tree's root, no tree scope: the
    // parser's and createElement's attributes, set before insertion.
    if (node.parent_node == null) return null;
    const maps = mapsOfRoot(rootOf(node)) orelse return null;
    if (maps.degraded) return null;
    const member = Link.to(element);
    if (facts.hasKeys()) maps.unregister(facts, member);
    return .{ .maps = maps, .member = member };
}

/// After `element`'s ID or name changed: put it back as it is now.
pub fn endChange(data: *const element_data.ElementData, change: ?Change) void {
    const taken = change orelse return;
    if (taken.maps.degraded) return;
    const facts = factsOfData(data);
    if (facts.hasKeys()) taken.maps.register(facts, taken.member);
}

// =============================================================================
// The readers
// =============================================================================

/// The maps of `scope_root`'s tree scope - a Document's or a ShadowRoot's -
/// rebuilt first if they were degraded; null when it is no tree scope's root
/// or they are still degraded (the caller walks), with `root` its node.
fn readableMaps(scope_root: *runtime.Instance) ?struct { maps: *Maps, root: *NodeBase } {
    const root = instance_bridge.getNodeBase(scope_root) orelse return null;
    if (root.parent_node != null) return null;
    const maps = mapsOfRoot(root) orelse return null;
    if (!maps.rebuild(root)) return null;
    return .{ .maps = maps, .root = root };
}

/// The first element of `root`'s light tree, in tree order, with `key` as a
/// `kind`; with `after` set, the first one after `after` instead.
fn findFrom(root: *NodeBase, start: ?*NodeBase, kind: Kind, key: []const u8) ?*NodeBase {
    var at = if (start) |node| nextInTree(node, root) else root.first_child;
    while (at) |node| : (at = nextInTree(node, root)) {
        const facts = factsOf(node) orelse continue;
        if (hasKey(facts, kind, key)) return node;
    }
    return null;
}

/// What a reader is told about one key: how many elements have it (2 meaning
/// "two or more" when the maps could not be read and the tree was walked),
/// and the first of them in tree order - always for getElementById, and for
/// a named reader only when there is exactly one (several make a
/// collection, which finds its own order).
pub const Answer = struct {
    count: u32 = 0,
    first: ?*runtime.Instance = null,
};

/// The answer for (`kind`, `key`) in `root`'s maps: the remembered first, or
/// a walk to it (with `first_of_several` unset, none when there are several).
/// Null when the maps were found inexact (the caller walks).
fn answerFrom(maps: *Maps, root: *NodeBase, kind: Kind, key: []const u8, first_of_several: bool) ?Answer {
    const entry = maps.entryOf(kind, key) orelse return .{};
    if (entry.count > 1 and !first_of_several) return .{ .count = entry.count };
    if (entry.first) |link| {
        if (link.get()) |element| return .{ .count = entry.count, .first = element };
        maps.inexact("a remembered element is gone", key);
        return null;
    }
    const found = findFrom(root, null, kind, key) orelse {
        maps.inexact("no element has a kept key", key);
        return null;
    };
    const element = instanceOf(found).?;
    entry.first = Link.to(element);
    return .{ .count = entry.count, .first = element };
}

/// The answer from a walk of `root`'s tree, counting to two.
fn walkAnswer(root: *NodeBase, kind: Kind, key: []const u8) Answer {
    const first = findFrom(root, null, kind, key) orelse return .{};
    const second = findFrom(root, first, kind, key);
    return .{ .count = if (second == null) 1 else 2, .first = instanceOf(first) };
}

/// getElementById's answer for `scope_root`'s tree scope.
pub const ById = union(enum) {
    /// No maps answer for this root - a plain DocumentFragment, or maps that
    /// could not be rebuilt: walk the tree.
    unindexed,
    found: ?*runtime.Instance,
};

/// DOM 4.2.4 getElementById for a Document or a ShadowRoot: "the first
/// element, in tree order, within this's descendants, whose ID is
/// elementId". `id` is not empty.
pub fn elementById(scope_root: *runtime.Instance, id: []const u8) ById {
    const readable = readableMaps(scope_root) orelse return .unindexed;
    const answer = answerFrom(readable.maps, readable.root, .id, id, true) orelse return .{ .found = walkAnswer(readable.root, .id, id).first };
    return .{ .found = answer.first };
}

/// The named elements (`.document`) or named-object elements (`.window`) of
/// `document`'s tree named `name`: how many, and the element when there is
/// exactly one.
pub fn named(document: *runtime.Instance, kind: NamedKind, name: []const u8) Answer {
    if (name.len == 0) return .{};
    const root = instance_bridge.getNodeBase(document) orelse return .{};
    const readable = readableMaps(document) orelse return walkAnswer(root, kind.kind(), name);
    return answerFrom(readable.maps, readable.root, kind.kind(), name, false) orelse walkAnswer(readable.root, kind.kind(), name);
}

/// Whether `name` is one of `document`'s named elements' (or its Window's
/// named-object elements') names: WebIDL's "is P a supported property
/// name?", for one P.
pub fn isNamed(document: *runtime.Instance, kind: NamedKind, name: []const u8) bool {
    if (name.len == 0) return false;
    const root = instance_bridge.getNodeBase(document) orelse return false;
    const readable = readableMaps(document) orelse return findFrom(root, null, kind.kind(), name) != null;
    return readable.maps.entryOf(kind.kind(), name) != null;
}

/// Add each of `document`'s elements named `name` as a `kind`, in tree
/// order, with `add(context, element)`: a named-property collection's
/// contents. From the maps' ordered list, built once per change of the
/// name's elements; from a walk when the maps cannot be read.
pub fn collectNamed(
    document: *runtime.Instance,
    kind: NamedKind,
    name: []const u8,
    context: anytype,
    comptime add: anytype,
) !void {
    if (name.len == 0) return;
    const root = instance_bridge.getNodeBase(document) orelse return;
    if (readableMaps(document)) |readable| {
        if (orderedFrom(readable.maps, readable.root, kind.kind(), name)) |list| {
            for (list) |link| try add(context, link.get().?);
            return;
        }
    }
    var at = findFrom(root, null, kind.kind(), name);
    while (at) |node| : (at = findFrom(root, node, kind.kind(), name)) try add(context, instanceOf(node).?);
}

/// The entry's elements in tree order (Blink GetAllElementsById): kept,
/// built by a walk from its first, or null when it cannot be built (no
/// memory, or the maps were found inexact) and the caller walks. Borrowed
/// until the maps next change.
fn orderedFrom(maps: *Maps, root: *NodeBase, kind: Kind, key: []const u8) ?[]const Link {
    const entry = maps.entryOf(kind, key) orelse return &.{};
    if (entry.ordered) |list| {
        for (list) |link| if (link.get() == null) {
            maps.inexact("a remembered element is gone", key);
            return null;
        };
        return list;
    }
    const list = maps.allocator.alloc(Link, entry.count) catch return null;
    // From the first when it is known (Blink starts its walk there too):
    // nothing before it has the key.
    const known_first: ?*NodeBase = if (entry.first) |link| (if (link.get()) |element| instance_bridge.getNodeBase(element) else null) else null;
    var filled: usize = 0;
    var at = known_first orelse findFrom(root, null, kind, key);
    while (at) |node| : (at = findFrom(root, node, kind, key)) {
        if (filled == list.len) break;
        list[filled] = Link.to(instanceOf(node).?);
        filled += 1;
    }
    // Fewer elements than the count, or more (the loop stopped on one):
    // the maps are not exact.
    if (filled != list.len or at != null) {
        maps.allocator.free(list);
        maps.inexact("the tree's elements do not match a kept count", key);
        return null;
    }
    entry.ordered = list;
    entry.first = list[0];
    return list;
}

/// HTML 3.1.7 a Document's supported property names (`.document`), or the
/// element-contributed part of a Window's (`.window`): for each element of
/// `document`'s tree in tree order, its ID and then its name when they make
/// it a named element, later duplicates ignored. Owned by `allocator`. A
/// walk - only enumeration asks - and none when the maps hold no name.
pub fn supportedNames(document: *runtime.Instance, kind: NamedKind, allocator: std.mem.Allocator) ![]runtime.DOMString {
    const root = instance_bridge.getNodeBase(document) orelse return &.{};
    if (readableMaps(document)) |readable| {
        if (readable.maps.totals.get(kind.kind()) == 0) return &.{};
    }
    var names: std.ArrayList(runtime.DOMString) = .empty;
    errdefer {
        for (names.items) |*name| name.deinit(allocator);
        names.deinit(allocator);
    }
    var seen: std.StringHashMapUnmanaged(void) = .empty;
    defer seen.deinit(allocator);
    var at = root.first_child;
    while (at) |node| : (at = nextInTree(node, root)) {
        const facts = factsOf(node) orelse continue;
        for (keysOf(facts, kind.kind())) |key| {
            if (key.len == 0) continue;
            const gop = try seen.getOrPut(allocator, key);
            if (gop.found_existing) continue;
            // The set borrows the element's own string: nothing runs script
            // during the walk, so none changes before it ends.
            var copy = try runtime.DOMString.initDupe(allocator, key);
            errdefer copy.deinit(allocator);
            try names.append(allocator, copy);
        }
    }
    return names.toOwnedSlice(allocator);
}

// =============================================================================
// The named-property collections a document keeps (weakly)
// =============================================================================

fn documentMaps(document: *runtime.Instance) ?*Maps {
    const maps = (implementation.document orelse return null)(document) orelse return null;
    return if (maps.ended) null else maps;
}

/// The collection `document`'s `kind` named getter made for `name` before,
/// while its wrapper lives; null for none (a gone one's link is dropped).
pub fn cachedCollection(document: *runtime.Instance, kind: NamedKind, name: []const u8) ?*runtime.Instance {
    const maps = documentMaps(document) orelse return null;
    const collections = maps.collections.getPtr(name) orelse return null;
    const slot = collections.of(kind);
    if (slot.*) |link| {
        if (link.get()) |collection| return collection;
        slot.* = null;
    }
    if (!collections.live()) {
        const owned = maps.collections.getKey(name).?;
        _ = maps.collections.remove(name);
        maps.allocator.free(owned);
    }
    return null;
}

/// Remember `collection` as `document`'s `kind` named collection for `name`.
/// When the cache has grown to its sweep size, the names whose collections
/// are all gone go first, and the next sweep waits for twice what stays
/// (never under 16). Out of memory, it is not remembered: the next read
/// makes another.
pub fn rememberCollection(document: *runtime.Instance, kind: NamedKind, name: []const u8, collection: *runtime.Instance) void {
    const maps = documentMaps(document) orelse return;
    if (maps.collections.count() >= maps.sweep_at) sweepCollections(maps);
    const gop = maps.collections.getOrPut(maps.allocator, name) catch return;
    if (!gop.found_existing) {
        gop.key_ptr.* = maps.allocator.dupe(u8, name) catch {
            maps.collections.removeByPtr(gop.key_ptr);
            return;
        };
        gop.value_ptr.* = .{};
    }
    gop.value_ptr.of(kind).* = Link.to(collection);
}

fn sweepCollections(maps: *Maps) void {
    var gone: std.ArrayList([]const u8) = .empty;
    defer gone.deinit(maps.allocator);
    var it = maps.collections.iterator();
    while (it.next()) |kv| {
        if (!kv.value_ptr.live()) gone.append(maps.allocator, kv.key_ptr.*) catch break;
    }
    for (gone.items) |name| {
        _ = maps.collections.remove(name);
        maps.allocator.free(name);
    }
    maps.sweep_at = @max(16, 2 * maps.collections.count());
}

/// HTML 3.1.7 / 7.2.2.3 step 4: the live named-property collection of
/// `document` for `name` - the one made before, while its wrapper lives,
/// else a new one, remembered. The caller hands it to script, whose wrapper
/// then owns it (or, natively, frees it itself).
pub fn namedCollection(document: *runtime.Instance, kind: NamedKind, name: []const u8) !*runtime.Instance {
    if (cachedCollection(document, kind, name)) |collection| return collection;
    const interfaces = @import("interfaces");
    const allocator = if (documentMaps(document)) |maps| maps.allocator else document.ctx.allocator;
    const collection = try interfaces.HTMLCollection.init(allocator, document.ctx);
    errdefer interfaces.HTMLCollection.deinit(collection);
    try live_collections.namedItems(collection, document, kind, name);
    rememberCollection(document, kind, name, collection);
    return collection;
}

/// How many names `document`'s collection cache holds (tests).
pub fn cachedCollectionNames(document: *runtime.Instance) usize {
    const maps = documentMaps(document) orelse return 0;
    return maps.collections.count();
}

// =============================================================================
// What tests read
// =============================================================================

/// How `scope_root`'s maps stand, for tests: null when it is no tree scope's
/// root.
pub const Inspection = struct {
    degraded: bool,
    keys: usize,
    count: u32,
    first_known: bool,
};

pub fn inspect(scope_root: *runtime.Instance, kind: Kind, key: []const u8) ?Inspection {
    const root = instance_bridge.getNodeBase(scope_root) orelse return null;
    const maps = mapsOfRoot(root) orelse return null;
    const entry: ?*Entry = if (maps.degraded) null else maps.entryOf(kind, key);
    return .{
        .degraded = maps.degraded,
        .keys = maps.map.count() - maps.empty_slots,
        .count = if (entry) |e| e.count else 0,
        .first_known = if (entry) |e| e.first != null else false,
    };
}

/// How `scope_root`'s key map stands as a hash table, for tests: its slot
/// counts and the mean slots a miss walks (infra.tombstones); null when it
/// is no tree scope's root.
pub const TableInspection = struct {
    slots: tombstones.SlotCounts,
    mean_miss: usize,
};

pub fn inspectTable(scope_root: *runtime.Instance) ?TableInspection {
    const root = instance_bridge.getNodeBase(scope_root) orelse return null;
    const maps = mapsOfRoot(root) orelse return null;
    return .{ .slots = tombstones.slotCounts(&maps.map), .mean_miss = tombstones.meanMissProbe(&maps.map) };
}

/// Make `scope_root`'s maps - still empty - allocate from `allocator`, so a
/// test can fail their allocations alone.
pub fn useAllocatorForTest(scope_root: *runtime.Instance, allocator: std.mem.Allocator) void {
    const root = instance_bridge.getNodeBase(scope_root) orelse return;
    const maps = mapsOfRoot(root) orelse return;
    std.debug.assert(maps.map.count() == 0 and maps.collections.count() == 0);
    maps.map.deinit(maps.allocator);
    maps.map = .empty;
    maps.collections.deinit(maps.allocator);
    maps.collections = .empty;
    maps.allocator = allocator;
}

/// The elements `scope_root`'s tree scope has with `key` as a `kind`, in
/// tree order, as the maps answer (rebuilding or walking as readers do);
/// owned by `allocator`. For tests comparing the maps with a walk.
pub fn elementsFor(scope_root: *runtime.Instance, kind: Kind, key: []const u8, allocator: std.mem.Allocator) ![]*runtime.Instance {
    var list: std.ArrayList(*runtime.Instance) = .empty;
    errdefer list.deinit(allocator);
    const root = instance_bridge.getNodeBase(scope_root) orelse return list.toOwnedSlice(allocator);
    if (readableMaps(scope_root)) |readable| {
        if (orderedFrom(readable.maps, readable.root, kind, key)) |links| {
            for (links) |link| try list.append(allocator, link.get().?);
            return list.toOwnedSlice(allocator);
        }
    }
    var at = findFrom(root, null, kind, key);
    while (at) |node| : (at = findFrom(root, node, kind, key)) try list.append(allocator, instanceOf(node).?);
    return list.toOwnedSlice(allocator);
}

test "keysOf follows HTML's named element and named object rules" {
    const img: Facts = .{ .named_type = .img, .id = "i", .name = "n" };
    try std.testing.expectEqualStrings("i", keysOf(img, .document_named)[0]);
    try std.testing.expectEqualStrings("n", keysOf(img, .document_named)[1]);
    // An img's ID names it only while it has a non-empty name.
    const nameless_img: Facts = .{ .named_type = .img, .id = "i", .name = "" };
    try std.testing.expectEqualStrings("", keysOf(nameless_img, .document_named)[0]);
    try std.testing.expectEqualStrings("i", keysOf(nameless_img, .window_named)[0]);
    // An iframe is a named element by name, but a Window's named object only
    // by ID (its name is its navigable's target name's business).
    const iframe: Facts = .{ .named_type = .iframe, .id = "i", .name = "n" };
    try std.testing.expectEqualStrings("", keysOf(iframe, .document_named)[0]);
    try std.testing.expectEqualStrings("n", keysOf(iframe, .document_named)[1]);
    try std.testing.expectEqualStrings("i", keysOf(iframe, .window_named)[0]);
    try std.testing.expectEqualStrings("", keysOf(iframe, .window_named)[1]);
    // A div is named by nothing in a document, by its ID in a window.
    const div: Facts = .{ .named_type = .other, .id = "d", .name = "" };
    try std.testing.expectEqualStrings("", keysOf(div, .document_named)[0]);
    try std.testing.expectEqualStrings("d", keysOf(div, .window_named)[0]);
    // An ID equal to the name registers once.
    const object: Facts = .{ .named_type = .object, .id = "same", .name = "same" };
    try std.testing.expectEqualStrings("same", keysOf(object, .document_named)[0]);
    try std.testing.expectEqualStrings("", keysOf(object, .document_named)[1]);
}
