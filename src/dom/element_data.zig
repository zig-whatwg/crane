//! DOM § 4.9 an element's attribute list, with its ID, its classes and its
//! qualified name: the part of an element the rest of the tree reads.
//!
//! The selector matcher (type, class, ID and attribute selectors, the
//! of-type pseudo-classes), getElementById, a Window's named properties, the
//! HTML elements' content-attribute reflection and the CSSOM read these on
//! every element they visit. None of them may reach into Element's impl
//! (AGENTS.md "The impls boundary"), and one hook per field would be a
//! second copy of Element's API. So the TYPE lives here and Element keeps
//! the state: Element's InternalState embeds one `ElementData` by value -
//! one block, one lifetime - and installs `of` from its installHooks
//! (lesson architecture-move-the-states-type-out-of-the-impl-not-the-state).
//!
//! The attribute list (lane nd2 batch 2, A1; tmp/redesign/
//! node-memory-plan-v2.md I7): ONE out-of-line block, null for an element
//! with no attributes - an 8-byte header, then 8-byte entries, each a u32
//! NAME ID (dom.attribute_names: static for the known names, else a counted
//! reference to its Browser's interned record; A2) and a u32 VALUE ID
//! (dom.attribute_values: a counted reference to its Browser's interned
//! record of that value; the integrator's decision of 2026-11-10 after
//! value bytes in the block were shown to dangle every view on a growth).
//! No pointer in an entry (a comptime check). A one-attribute element pays
//! one 16-byte block where it paid a 32-byte list and a value malloc (and a
//! 72-byte name record for a name outside the static table). Blink's
//! `Attribute` is a QualifiedName and an AtomicString - two pointers to
//! shared records, 16 B (core/dom/attribute.h) - and WebKit's the same
//! (Source/WebCore/dom/Attribute.h); here the two records are ids.
//!
//! Growth (oss review R16): exact on parse and clone - the parser sets a
//! token's attributes at once (`dom.element_attributes.setParsed`) and a
//! clone shares its source's list - and 1 -> 4 -> x2 for script's appends,
//! so a `setAttribute` loop is not quadratic. Servo pre-sizes the same way
//! (f28a39571849), and so do Gecko and Ladybird.
//!
//! Sharing (lane nd2 batch 4, plan-v2 A3): elements with equal attribute
//! sets share one immutable block - a parser's document's `SharingCache`
//! (dom.attribute_block_cache, batch 5) hands out one per distinct set, and
//! a clone shares its source's - and every writer copies first
//! (`ElementData.writable`). See `AttributeList`.
//!
//! Reads are DOM's own read algorithms, plain functions over a `View` of
//! the data: the data and its element's Browser's tables, which decode the
//! ids. ElementData has no route to its Browser (review C2), so the view is
//! made where the element is known: `of(element)` finds the tables through
//! `runtime.BrowserScope.ofInstance(element)`. Every read hands out an
//! `AttributeEntry` BY VALUE whose slices are the name record's and the
//! value record's bytes - never a pointer into the block, which a growth
//! MOVES. A growth moves ids, never bytes, so a view is unaffected by
//! changes to the other attributes and stays valid until its own attribute
//! next changes or goes (when its records may be released). A reader that
//! only reads within its own step borrows; a holder across a point where
//! script can run takes a count on the records for that span
//! (attribute_values.Hold, attribute_names.retain) - Element's "handle
//! attribute changes" does, for the change steps. Writes - "change",
//! "append", "remove" and "replace" an attribute - stay Element's, where
//! "handle attribute changes" queues the mutation record, enqueues the
//! custom element reaction and runs the attribute change steps: callers
//! write through `dom.element_attributes` (`set`, `remove`, `append`,
//! `change`), never through this data, which `of` hands out read-only. The
//! ID and classes are read from the list through two indices its header
//! keeps (`idValue`, `classValue`; lane nd2 N3), which the list's own append
//! and remove re-derive - no step can forget them.
//!
//! The element's qualified name is ONE pointer to a shared record
//! (`name`, dom.element_name; lane nd2 N2), a counted reference to an
//! interned one (batch 1-fix): `rename` and `deinit` keep the count.
//!
//! Spec: https://dom.spec.whatwg.org/#concept-element-attribute
//!
//! lint-impls: hook for Element
const std = @import("std");
const builtin = @import("builtin");

const infra = @import("infra");
const runtime = @import("runtime");
const Hook = @import("hook.zig").Hook;
const element_name = @import("element_name.zig");
const attribute_names = @import("attribute_names.zig");
const attribute_values = @import("attribute_values.zig");

const debug_checks = builtin.mode == .debug;

/// The Attr node made for an attribute, once script asked for one, with the
/// slab generation that tells it from a later object at its address.
pub const AttrNodeLink = struct {
    instance: *runtime.Instance,
    generation: u64,

    pub fn to(instance: *runtime.Instance) AttrNodeLink {
        return .{ .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance) };
    }

    /// Is `instance` still the Attr node this link was taken on?
    pub fn isLive(self: AttrNodeLink) bool {
        return runtime.SlabAllocator.generationOf(self.instance) == self.generation;
    }
};

/// The namespace string every element and attribute in one of the six named
/// namespaces (Infra 8) shares, or null for any other (dom.element_name's).
pub const internNamespace = element_name.internNamespace;

/// An element's qualified name record (lane nd2 N2): `ElementData.name`.
pub const ElementName = element_name.ElementName;

/// An attribute's qualified name record (dom.attribute_names).
pub const QualifiedName = attribute_names.QualifiedName;
pub const NameId = attribute_names.NameId;
pub const ValueId = attribute_values.ValueId;

/// One attribute as the list stores it: its name id and its value id, each
/// a reference the list holds (counted, unless static or empty). 8 bytes,
/// no pointer: under the planned cage (node-memory-plan-v2.md D5(b), H5)
/// the entries are page-influenced bytes beside nothing a stale reader
/// could take for an address.
pub const Entry = extern struct {
    name: NameId,
    value: ValueId,

    comptime {
        std.debug.assert(@sizeOf(Entry) == 8);
        if (holdsPointer(Entry)) @compileError("an attribute entry holds no pointer");
    }
};

/// Whether a value of `T` can hold an address: what an attribute entry
/// must never (architecture 3.2: "a block whose bytes the page controls
/// holds no raw pointer").
pub fn holdsPointer(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .int, .float, .bool, .void, .@"enum" => false,
        .pointer => true,
        .optional => |info| holdsPointer(info.child),
        .array => |info| holdsPointer(info.child),
        .@"struct" => |info| {
            inline for (info.field_names) |name| {
                if (holdsPointer(@FieldType(T, name))) return true;
            }
            return false;
        },
        else => true,
    };
}

/// The tables an attribute's ids decode with: its element's Browser's.
/// Static names and the empty value need none.
pub const Tables = struct {
    names: ?*const attribute_names.Table = null,
    values: ?*const attribute_values.Table = null,

    /// `scope`'s tables, as made so far.
    pub fn of(scope: *runtime.BrowserScope) Tables {
        return .{ .names = attribute_names.tableOf(scope), .values = attribute_values.tableOf(scope) };
    }

    /// The record `id` names.
    pub inline fn name(self: Tables, id: NameId) *const QualifiedName {
        return attribute_names.record(self.names, id);
    }

    /// The bytes `id` names.
    pub inline fn value(self: Tables, id: ValueId) []const u8 {
        return attribute_values.bytesIn(self.values, id);
    }

    /// The view a reader gets of `entry`.
    pub fn view(self: Tables, entry: Entry) AttributeEntry {
        const record = self.name(entry.name);
        return .{
            .namespace_uri = record.namespace_uri,
            .prefix = record.prefix,
            .local_name = record.local_name,
            .value = self.value(entry.value),
        };
    }
};

/// One attribute of the list as a reader sees it: its namespace, namespace
/// prefix, local name and value (DOM 4.9.2), BORROWED from its name and
/// value records - valid until that attribute next changes or goes, and
/// unaffected by changes to the others. A value, never a pointer into the
/// list (see the file's comment).
pub const AttributeEntry = struct {
    namespace_uri: ?[]const u8,
    prefix: ?[]const u8,
    local_name: []const u8,
    value: []const u8,

    /// Whether this attribute's namespace is `namespace_uri` and its local
    /// name is `local_name` (null matches only null).
    pub fn isNamed(self: *const AttributeEntry, namespace_uri: ?[]const u8, local_name: []const u8) bool {
        return attribute_names.optionalEql(self.namespace_uri, namespace_uri) and std.mem.eql(u8, local_name, self.local_name);
    }

    /// Spec: https://dom.spec.whatwg.org/#concept-attribute-qualified-name
    pub fn qualifiedNameIs(self: *const AttributeEntry, qualified_name: []const u8) bool {
        return attribute_names.qualifiedNameMatches(self.prefix, self.local_name, qualified_name);
    }
};

/// The static ids of the two names the header indexes.
const id_name = attribute_names.comptimeLocalId("id");
const class_name = attribute_names.comptimeLocalId("class");

/// Whether `id` names the attribute `local_name` (one of the static names)
/// in no namespace: the static id, or - never made by a DOM API, but a list
/// is compared by namespace and local name, not prefix - a dynamic record
/// with no namespace and that local name.
fn namesLocal(tables: Tables, id: NameId, comptime static: NameId) bool {
    if (id == static) return true;
    if (id.isStatic()) return false;
    return tables.name(id).isNamed(null, attribute_names.staticRecord(static).local_name);
}

/// The out-of-line list: this header, then `capacity()` entries, in ONE
/// block taken through the allocator's raw entry point (its header and
/// entries are written at once; std's `alloc` would fill it with 0xaa first
/// in ReleaseSafe: review zig/report.md Z5).
///
/// The header also keeps the element's ID and classes as the POSITIONS of
/// its id and class attributes in no namespace (lane nd2 N3; the integrator's
/// perf3 D1 condition: indices, never pointers - a pointer into a list that
/// moves would dangle). Blink and WebKit keep the ID and classes in their
/// out-of-line ElementData too, so an element with no attributes pays
/// nothing for them - but as a cached atomized ID and pre-split class
/// tokens (Blink core/dom/element_data.h `id_for_style_resolution_`,
/// `class_names_`, a SpaceSplitString; WebKit Source/WebCore/dom/
/// ElementData.h), not positions: here a class match still splits the
/// value (appendix-nd2.md F6, F12). One byte each: 0..253 is the attribute's
/// position, `no_index` none, and `saturated_index` "at a position past
/// 253: scan from there" - an element has no cap on its attributes, and its
/// length stays 32 bits. The list's own changes keep them (`append`,
/// `take`); a change of value or prefix ("change", "replace") moves no
/// attribute. 8 bytes, as before.
///
/// SHARED blocks (lane nd2 batch 4, plan-v2 A3): elements whose attribute
/// sets are equal - names and values, in order - share ONE block, made by
/// the parser through its document's `SharingCache` or by a clone from its source (Blink
/// core/dom/element_data_cache.cc ElementDataCache::
/// CachedShareableElementDataWithAttributes and Element::CloneAttributesFrom;
/// WebKit Source/WebCore/dom/DocumentSharedObjectPool.cpp and
/// Element::cloneAttributesFromElement). A shared block is immutable: its
/// `holders` byte counts the elements and the cache that hold it, and every
/// writer first makes the list its element's own (`ElementData.writable`:
/// copy on write, Blink's Element::CreateUniqueElementData). 0 holders is an
/// element's own, writable list. The count costs no byte: it is the
/// header's spare one, and a block at `max_holders` takes no more - the next
/// sharer gets a new block.
pub const AttributeList = struct {
    len: u32,
    /// The capacity: 1 to 128 is that many entries (exact, as parse and
    /// clone reserve), k > 128 is 128 << (k - 128).
    cap_class: u8,
    /// Where the id attribute in no namespace is (see above).
    id_index: u8 = no_index,
    /// Where the class attribute in no namespace is.
    class_index: u8 = no_index,
    /// 0: one element's own list. 1 to `max_holders`: a shared, immutable
    /// block with that many holders (elements, and a document's cache).
    holders: u8 = 0,

    /// No such attribute.
    pub const no_index: u8 = 0xFF;
    /// The attribute is at position `saturated_index` or later: found by a
    /// scan from there.
    pub const saturated_index: u8 = 0xFE;
    /// The most holders a shared block counts; it never wraps.
    pub const max_holders: u8 = std.math.maxInt(u8);

    const exact_classes = 128;

    comptime {
        std.debug.assert(@sizeOf(AttributeList) == 8);
        std.debug.assert(@sizeOf(AttributeList) % @alignOf(Entry) == 0);
    }

    fn capacityOf(class: u8) usize {
        return if (class <= exact_classes) class else @as(usize, exact_classes) << @intCast(class - exact_classes);
    }

    /// The smallest class holding `wanted` entries: exact up to 128, then
    /// the next power of two.
    fn classFor(wanted: usize) error{OutOfMemory}!u8 {
        if (wanted <= exact_classes) return @intCast(@max(wanted, 1));
        var class: usize = exact_classes + 1;
        while (capacityOf(@intCast(class)) < wanted) : (class += 1) {
            if (class == std.math.maxInt(u8) or capacityOf(@intCast(class)) >= std.math.maxInt(u32)) return error.OutOfMemory;
        }
        return @intCast(class);
    }

    /// The entries the list holds.
    pub fn capacity(self: *const AttributeList) usize {
        return capacityOf(self.cap_class);
    }

    fn bytesFor(cap: usize) usize {
        return @sizeOf(AttributeList) + cap * @sizeOf(Entry);
    }

    fn block(self: *AttributeList) []u8 {
        const base: [*]u8 = @ptrCast(self);
        return base[0..bytesFor(self.capacity())];
    }

    /// The entries, to write: a list with no holders only.
    fn slots(self: *AttributeList) [*]Entry {
        const base: [*]u8 = @ptrCast(self);
        return @ptrCast(@alignCast(base + @sizeOf(AttributeList)));
    }

    fn mutableItems(self: *AttributeList) []Entry {
        return self.slots()[0..self.len];
    }

    /// The entries, to read.
    fn items(self: *const AttributeList) []const Entry {
        const base: [*]const u8 = @ptrCast(self);
        const entries: [*]const Entry = @ptrCast(@alignCast(base + @sizeOf(AttributeList)));
        return entries[0..self.len];
    }

    /// Whether this is a shared block (see the type's comment).
    pub inline fn isShared(self: *const AttributeList) bool {
        return self.holders != 0;
    }

    /// A new SHARED block holding exactly `entries`, whose references it
    /// takes, with `holders` holders; its ID and class indices are computed
    /// here, once (lane nd2 N3).
    fn createShared(scope: *runtime.BrowserScope, entries: []const Entry, holders: u8) error{OutOfMemory}!*AttributeList {
        std.debug.assert(entries.len != 0 and holders != 0);
        if (entries.len > std.math.maxInt(u32)) return error.OutOfMemory;
        const list = try create(scope.allocator, try classFor(entries.len));
        @memcpy(list.slots()[0..entries.len], entries);
        list.len = @intCast(entries.len);
        const tables = Tables.of(scope);
        for (entries, 0..) |entry, position| list.appended(tables, position, entry.name);
        list.holders = holders;
        return list;
    }

    /// One holder more of shared block `list`, or false when it has
    /// `max_holders` (the count never wraps).
    fn hold(list: *const AttributeList) bool {
        std.debug.assert(list.isShared());
        if (list.holders == max_holders) return false;
        // The count is the one field of a shared block that changes, as
        // Blink's ElementData keeps mutable bits in an immutable block.
        @constCast(list).holders += 1;
        return true;
    }

    /// Let go of one holder's `list` - a shared block's holder, or an
    /// element's own list: the last holder releases the entries' references
    /// and frees the block.
    fn drop(list: *const AttributeList, scope: *runtime.BrowserScope) void {
        const mutable = @constCast(list);
        if (list.holders > 1) {
            mutable.holders -= 1;
            return;
        }
        for (list.items()) |entry| ElementData.releaseEntry(scope, entry);
        mutable.destroy(scope.allocator);
    }

    /// An empty list of class `class`, its header written.
    fn create(allocator: std.mem.Allocator, class: u8) error{OutOfMemory}!*AttributeList {
        const memory = allocator.rawAlloc(bytesFor(capacityOf(class)), .of(AttributeList), @returnAddress()) orelse return error.OutOfMemory;
        const list: *AttributeList = @ptrCast(@alignCast(memory));
        list.* = .{ .len = 0, .cap_class = class };
        return list;
    }

    fn destroy(self: *AttributeList, allocator: std.mem.Allocator) void {
        const memory = self.block();
        if (debug_checks) @memset(memory, 0xAA);
        allocator.rawFree(memory, .of(AttributeList), @returnAddress());
    }

    /// The list in a block of class `class`: header and entries copied,
    /// this one freed (MOVED - nothing holds a pointer into it across this;
    /// a view's bytes are its records', which do not move).
    fn moved(self: *AttributeList, allocator: std.mem.Allocator, class: u8) error{OutOfMemory}!*AttributeList {
        std.debug.assert(!self.isShared());
        const list = try create(allocator, class);
        const header = self.*;
        @memcpy(list.slots()[0..self.len], self.items());
        list.* = header;
        list.cap_class = class;
        self.destroy(allocator);
        return list;
    }

    /// The list with room for one more script append: itself, or a larger
    /// copy (1 -> 4 -> x2: oss R16).
    fn withRoom(self: *AttributeList, allocator: std.mem.Allocator) error{OutOfMemory}!*AttributeList {
        // The length is 32 bits; past it there is no room to make.
        if (self.len == std.math.maxInt(u32)) return error.OutOfMemory;
        if (self.len < self.capacity()) return self;
        const current = self.capacity();
        return self.moved(allocator, try classFor(if (current < 4) 4 else current * 2));
    }

    /// The index byte for an attribute at `position`.
    fn indexFor(position: usize) u8 {
        return if (position < saturated_index) @intCast(position) else saturated_index;
    }

    /// The position of the attribute `index` says where to find, named by
    /// `static` (or a record of its namespace and local name), or null.
    fn find(self: *const AttributeList, tables: Tables, index: u8, comptime static: NameId) ?usize {
        if (index == no_index) return null;
        if (index != saturated_index) return index;
        const from = @min(@as(usize, saturated_index), self.len);
        for (self.items()[from..], from..) |entry, position| {
            if (namesLocal(tables, entry.name, static)) return position;
        }
        return null;
    }

    /// The value of the attribute `index` finds, decoded with `view`'s
    /// tables, or "": the values' table alone, the names' too only past a
    /// saturated index.
    fn valueAt(self: *const AttributeList, view: View, values: ?*const attribute_values.Table, index: u8, comptime static: NameId) []const u8 {
        return attribute_values.bytesIn(values, self.valueIdAt(view, index, static));
    }

    /// The value id of the attribute `index` finds, or .empty: no table read
    /// at all, the names' only past a saturated index.
    inline fn valueIdAt(self: *const AttributeList, view: View, index: u8, comptime static: NameId) ValueId {
        if (index == no_index) return .empty;
        if (index != saturated_index) return self.items()[index].value;
        const position = self.find(view.tables(), index, static) orelse return .empty;
        return self.items()[position].value;
    }

    /// The attribute just appended at `position` is the id or class
    /// attribute: its index follows it. There is at most one of each (an
    /// attribute is appended only when absent).
    fn appended(self: *AttributeList, tables: Tables, position: usize, name: NameId) void {
        if (self.id_index == no_index and namesLocal(tables, name, id_name)) self.id_index = indexFor(position);
        if (self.class_index == no_index and namesLocal(tables, name, class_name)) self.class_index = indexFor(position);
    }

    /// The attribute at `position`, named `name`, was just taken out: the
    /// indices after it move down one, its own goes, and a saturated one is
    /// found again (it may be exact now).
    fn taken(self: *AttributeList, tables: Tables, position: usize, name: NameId) void {
        self.id_index = self.indexAfterTake(tables, self.id_index, position, name, id_name);
        self.class_index = self.indexAfterTake(tables, self.class_index, position, name, class_name);
    }

    fn indexAfterTake(self: *AttributeList, tables: Tables, index: u8, position: usize, name: NameId, comptime static: NameId) u8 {
        if (index == no_index) return no_index;
        if (namesLocal(tables, name, static)) return no_index;
        if (index == saturated_index) {
            // It was at 254 or later, so it is at 253 or later now.
            const from = @min(@as(usize, saturated_index - 1), self.len);
            for (self.items()[from..], from..) |entry, at| {
                if (namesLocal(tables, entry.name, static)) return indexFor(at);
            }
            return no_index;
        }
        return if (position < index) index - 1 else index;
    }
};

/// The Attr nodes made for an element's attributes, each by its attribute's
/// name record (an attribute's identity: one per namespace and local name;
/// the record is static or counted by the attribute's entry, so its address
/// is stable while the attribute lives), made when script asks for the first
/// one. Blink keeps an element's Attr nodes apart from its attributes too
/// (its rare data's kAttrNodeList, looked up by QualifiedName); Crane keeps
/// this list in the element's ElementRareData (dom.element_rare_data, lane
/// perf3 D2).
pub const AttrNodeList = struct {
    entries: std.ArrayList(Item) = .empty,

    pub const Item = struct {
        name: *const QualifiedName,
        node: AttrNodeLink,
    };

    fn indexOf(self: *const AttrNodeList, name: *const QualifiedName) ?usize {
        for (self.entries.items, 0..) |item, i| {
            if (item.name == name) return i;
        }
        return null;
    }

    /// The Attr node kept for the attribute named by `name`, if any.
    pub fn get(self: *const AttrNodeList, name: *const QualifiedName) ?AttrNodeLink {
        const index = self.indexOf(name) orelse return null;
        return self.entries.items[index].node;
    }

    /// Keep `node` as the Attr node of the attribute named by `name`, and
    /// return the one kept before, if any.
    pub fn put(self: *AttrNodeList, allocator: std.mem.Allocator, name: *const QualifiedName, node: AttrNodeLink) !?AttrNodeLink {
        if (self.indexOf(name)) |index| {
            const old = self.entries.items[index].node;
            self.entries.items[index].node = node;
            return old;
        }
        try self.entries.append(allocator, .{ .name = name, .node = node });
        return null;
    }

    /// Stop keeping the Attr node of the attribute named by `name` and hand
    /// it back; the list's storage goes with its last node.
    pub fn take(self: *AttrNodeList, allocator: std.mem.Allocator, name: *const QualifiedName) ?AttrNodeLink {
        const index = self.indexOf(name) orelse return null;
        const node = self.entries.swapRemove(index).node;
        // std.ArrayList.deinit leaves the list `undefined`: empty it again.
        if (self.entries.items.len == 0) self.deinit(allocator);
        return node;
    }

    /// The attribute named by `old` is now named by `new` (the same
    /// namespace and local name: "replace" gave it another prefix); an Attr
    /// node kept for it follows.
    pub fn rename(self: *AttrNodeList, old: *const QualifiedName, new: *const QualifiedName) void {
        const index = self.indexOf(old) orelse return;
        self.entries.items[index].name = new;
    }

    /// Free the list's storage, leaving it empty; the nodes are their
    /// owner's to let go first.
    pub fn deinit(self: *AttrNodeList, allocator: std.mem.Allocator) void {
        self.entries.deinit(allocator);
        self.entries = .empty;
    }
};

/// An element's attribute list, ID, classes and qualified name. The Attr
/// nodes made for its attributes are rare data (dom.element_rare_data, lane
/// perf3 D2): no element of the perf pages had one.
pub const ElementData = struct {
    /// The element's namespace, namespace prefix and local name (DOM 4.9),
    /// fixed by "create an element": ONE pointer to a record every element
    /// of the name shares - static for the HTML, SVG and MathML names
    /// html_core's tag table knows, else its Browser's interned one
    /// (dom.element_name; lane nd2 N2: Blink's `Element::tag_name_`). An
    /// interned record is a COUNTED reference this data holds (batch
    /// 1-fix): written only by Element, through `rename`, and let go by
    /// `deinit`.
    name: *const ElementName = &element_name.unnamed,

    /// The attributes in list order, with the positions of the id and class
    /// attributes in its header; null while there are none. CONST: the
    /// block may be shared (AttributeList's comment), so a write goes
    /// through `writable` - the compiler holds every writer to it.
    attrs: ?*const AttributeList = null,

    pub fn init() ElementData {
        return .{};
    }

    /// Name the element `name`, a reference the caller hands over (counted,
    /// for an interned record: dom.element_name.intern), and let the old
    /// name's go - after, so renaming to the same record keeps it.
    pub fn rename(self: *ElementData, scope: *runtime.BrowserScope, name: *const ElementName) void {
        const old = self.name;
        self.name = name;
        element_name.release(scope, old);
    }

    /// Let the name record go and every attribute's references, and free
    /// the list. `scope` is the element's Browser's: its allocator made the
    /// list, its tables count the names and values. An attribute's Attr
    /// node is its owner's to let go first (AttrNodeList.take).
    pub fn deinit(self: *ElementData, scope: *runtime.BrowserScope) void {
        self.rename(scope, &element_name.unnamed);
        if (self.attrs) |list| {
            self.attrs = null;
            list.drop(scope);
        }
    }

    /// Take a reference on each of an entry's records: its name's and its
    /// value's.
    pub fn retainEntry(scope: *runtime.BrowserScope, entry: Entry) void {
        attribute_names.retain(scope, entry.name);
        attribute_values.retain(scope, entry.value);
    }

    /// Drop the references an entry held: its name's and its value's.
    pub fn releaseEntry(scope: *runtime.BrowserScope, entry: Entry) void {
        attribute_names.release(scope, entry.name);
        attribute_values.release(scope, entry.value);
    }

    /// A reader's view of this data, decoding with `scope`'s tables (the
    /// element's Browser's).
    pub fn view(self: *const ElementData, scope: *runtime.BrowserScope) View {
        return .{ .data = self, .name = self.name, .scope = scope };
    }

    /// The number of attributes in the list.
    pub fn getAttributeCount(self: *const ElementData) usize {
        return if (self.attrs) |list| list.len else 0;
    }

    /// The stored entries, for this file's loops. Read afresh after
    /// anything that can change the list.
    fn stored(self: *const ElementData) []const Entry {
        const list = self.attrs orelse return &.{};
        return list.items();
    }

    // ------------------------------------------------------------------
    // Element's writes. Each takes the index (or name) afresh: no caller
    // holds a pointer into the list across one.
    // ------------------------------------------------------------------

    /// The attribute at `index` as stored (its ids), or null past the end -
    /// Element's, for its writes.
    pub fn storedAt(self: *const ElementData, index: usize) ?Entry {
        const items = self.stored();
        if (index >= items.len) return null;
        return items[index];
    }

    /// Room for `more` attributes appended next, exactly: "create an
    /// element for a token" and "clone a single node" know how many they
    /// append (oss R16: exact on parse and clone). The list may MOVE.
    pub fn reserve(self: *ElementData, scope: *runtime.BrowserScope, more: usize) error{OutOfMemory}!void {
        if (more == 0) return;
        const len = self.getAttributeCount();
        const wanted = std.math.add(usize, len, more) catch return error.OutOfMemory;
        if (self.attrs != null) {
            const list = try self.writable(scope, more);
            if (wanted <= list.capacity()) return;
            self.attrs = try list.moved(scope.allocator, try AttributeList.classFor(wanted));
        } else {
            self.attrs = try AttributeList.create(scope.allocator, try AttributeList.classFor(wanted));
        }
    }

    /// The list, made this element's own for a write (copy on write: Blink's
    /// Element::CreateUniqueElementData, WebKit's Element::
    /// ensureUniqueElementData): itself when it has no holders; a shared
    /// block's last holder takes the block over; otherwise a copy, with room
    /// for `room` more entries, taking a reference on each entry's records,
    /// and the shared block loses this holder. The list may MOVE.
    fn writable(self: *ElementData, scope: *runtime.BrowserScope, room: usize) error{OutOfMemory}!*AttributeList {
        const list = self.attrs.?;
        const mutable = @constCast(list);
        if (!list.isShared()) return mutable;
        return self.unshare(scope, list, room);
    }

    noinline fn unshare(self: *ElementData, scope: *runtime.BrowserScope, list: *const AttributeList, room: usize) error{OutOfMemory}!*AttributeList {
        const mutable = @constCast(list);
        if (list.holders == 1) {
            mutable.holders = 0;
            return mutable;
        }
        const wanted = std.math.add(usize, list.len, room) catch return error.OutOfMemory;
        const copy = try AttributeList.create(scope.allocator, try AttributeList.classFor(wanted));
        const entries = list.items();
        @memcpy(copy.slots()[0..entries.len], entries);
        copy.len = list.len;
        copy.id_index = list.id_index;
        copy.class_index = list.class_index;
        for (entries) |entry| retainEntry(scope, entry);
        mutable.holders -= 1;
        self.attrs = copy;
        return copy;
    }

    /// The list of an element that has none yet: `entries`, whose references
    /// it takes on success - from `cache`, its parser's document's (shared
    /// with every element whose set is equal), or with no cache a block of
    /// its own. "Create an element for a token" (HTML 13.2.6.1: "Append each
    /// attribute in the given token to element") through Element: Blink's
    /// Element::ParserSetAttributes, WebKit's Element::parserSetAttributes.
    pub fn adoptEntries(self: *ElementData, scope: *runtime.BrowserScope, entries: []const Entry, cache: ?*SharingCache) error{OutOfMemory}!void {
        std.debug.assert(self.attrs == null);
        if (entries.len == 0) return;
        if (cache) |c| {
            self.attrs = try c.share(scope, entries);
            return;
        }
        if (entries.len > std.math.maxInt(u32)) return error.OutOfMemory;
        const list = try AttributeList.create(scope.allocator, try AttributeList.classFor(entries.len));
        @memcpy(list.slots()[0..entries.len], entries);
        list.len = @intCast(entries.len);
        const tables = Tables.of(scope);
        for (entries, 0..) |entry, position| list.appended(tables, position, entry.name);
        self.attrs = list;
    }

    /// DOM "clone a single node" step 3's attributes, for an element that has
    /// none yet: `source`'s list, SHARED - a shared block takes one holder
    /// more, and an element's own list becomes a shared block in place
    /// (Blink's Element::CloneAttributesFrom makes the source's
    /// UniqueElementData shareable; WebKit's Element::
    /// cloneAttributesFromElement). Across documents too: both elements are
    /// one Browser's, whose tables the ids are. A block at `max_holders`
    /// gives the clone a copy of its own.
    pub fn shareFrom(self: *ElementData, scope: *runtime.BrowserScope, source: *ElementData) error{OutOfMemory}!void {
        std.debug.assert(self.attrs == null);
        const list = source.attrs orelse return;
        if (!list.isShared()) {
            @constCast(list).holders = 2;
            self.attrs = list;
            return;
        }
        if (list.hold()) {
            self.attrs = list;
            return;
        }
        const copy = try AttributeList.create(scope.allocator, try AttributeList.classFor(list.len));
        const entries = list.items();
        @memcpy(copy.slots()[0..entries.len], entries);
        copy.len = list.len;
        copy.id_index = list.id_index;
        copy.class_index = list.class_index;
        for (entries) |entry| retainEntry(scope, entry);
        self.attrs = copy;
    }

    /// Append an attribute to the list, which takes the entry's references
    /// - on success only. Element's "append an attribute" step 1. The list
    /// may MOVE (script's appends grow it 1 -> 4 -> x2).
    pub fn appendAttribute(self: *ElementData, scope: *runtime.BrowserScope, entry: Entry) error{OutOfMemory}!void {
        const list = if (self.attrs != null) try (try self.writable(scope, 1)).withRoom(scope.allocator) else try AttributeList.create(scope.allocator, 1);
        self.attrs = list;
        const position = list.len;
        list.slots()[position] = entry;
        list.len += 1;
        list.appended(Tables.of(scope), position, entry.name);
    }

    /// Remove the attribute at `index` and hand its entry - its references
    /// - to the caller (`releaseEntry`). The list keeps its order (attribute
    /// order is observable through `attributes` and `getAttributeNames()`),
    /// and goes with its last attribute. A shared block whose last attribute
    /// goes is let go, no copy made.
    pub fn takeAttributeAt(self: *ElementData, scope: *runtime.BrowserScope, index: usize) error{OutOfMemory}!Entry {
        const current = self.attrs.?;
        if (current.isShared() and current.len == 1) {
            const entry = current.items()[0];
            retainEntry(scope, entry);
            self.attrs = null;
            current.drop(scope);
            return entry;
        }
        const list = try self.writable(scope, 0);
        const items = list.mutableItems();
        const entry = items[index];
        std.mem.copyForwards(Entry, items[index .. items.len - 1], items[index + 1 ..]);
        list.len -= 1;
        if (list.len == 0) {
            list.destroy(scope.allocator);
            self.attrs = null;
            return entry;
        }
        list.taken(Tables.of(scope), index, entry.name);
        return entry;
    }

    /// Set the value of the attribute at `index` to `value`, a reference
    /// the list takes, and hand back the old one for the caller to release
    /// once nothing reads it.
    pub fn setValueAt(self: *ElementData, scope: *runtime.BrowserScope, index: usize, value: ValueId) error{OutOfMemory}!ValueId {
        const slot = &(try self.writable(scope, 0)).mutableItems()[index];
        const old = slot.value;
        slot.value = value;
        return old;
    }

    /// Set the name of the attribute at `index` (the same namespace and
    /// local name; "replace" gives it another prefix) to `name`, a reference
    /// the list takes, and hand back the old one for the caller to release -
    /// after moving an Attr node kept for it to the new record
    /// (AttrNodeList.rename).
    pub fn setNameAt(self: *ElementData, scope: *runtime.BrowserScope, index: usize, name: NameId) error{OutOfMemory}!NameId {
        const slot = &(try self.writable(scope, 0)).mutableItems()[index];
        const old = slot.name;
        slot.name = name;
        return old;
    }
};

/// Shared attribute blocks by content: one per distinct attribute set -
/// names and values, in order - that its parsers have made (plan-v2 A3). A
/// parser hands an element's entries to `share` and gets the block every
/// element with an equal set got from this table.
///
/// The key is the CONTENT, compared in full: the entries' bytes, which are
/// the name and value ids - one id per distinct name and value in a Browser,
/// so equal sets are equal bytes (WebKit DocumentSharedObjectPool compares
/// the atomized attribute spans the same way; Blink compares the attribute
/// vectors). The hash only picks the slot.
///
/// LIFETIME: its owner's. A Document owns the one its parsers share
/// through, from its first parser run with an attribute until 10 s after
/// its parse (dom.attribute_block_cache, lane nd2 batch 5: Blink's
/// Document::element_data_cache_ and its element_data_cache_clear_timer_,
/// WebKit's Document::m_sharedObjectPool). Batch 4 gave every parser run a
/// table of its own, freed with the run; measured over the node-memory
/// walker's 17 pages, that lost 3,136 B (load-news) and 4,128 B (grid)
/// against the Document's - their innerHTML calls after the parse - and
/// cost every run the table's init and deinit. The table holds one holder
/// on each block, so a block lives while an element OR the table holds it;
/// `grow` lets go of the blocks only the table holds.
pub const SharingCache = struct {
    /// The Browser whose tables the blocks' ids are, set by the first share.
    scope: ?*runtime.BrowserScope = null,
    /// How many blocks the table holds.
    count: usize = 0,
    /// The table past `inline_len * 3 / 4` distinct sets: open addressing,
    /// linear probing, a power of two long. Empty while the table is the
    /// inline one.
    heap_slots: []?*const AttributeList = &.{},
    heap_hashes: []u32 = &.{},
    /// The table every cache starts with, in the cache itself: a document
    /// with a dozen distinct sets or fewer (DOMParser on a snippet, a small
    /// frame) allocates no table. (Batch 4's cache per parser run needed it
    /// for every fragment: a table from the allocator cost
    /// `el.innerHTML = '<b class=x>..</b>'` two allocations and two frees,
    /// 1.8% of its instructions.)
    inline_slots: [inline_len]?*const AttributeList = @splat(null),
    inline_hashes: [inline_len]u32 = @splat(0),

    const inline_len = 16;

    inline fn slots(self: *SharingCache) []?*const AttributeList {
        return if (self.heap_slots.len != 0) self.heap_slots else &self.inline_slots;
    }

    inline fn hashes(self: *SharingCache) []u32 {
        return if (self.heap_slots.len != 0) self.heap_hashes else &self.inline_hashes;
    }

    /// Let go of the cache's holder on every block (a block no element holds
    /// any more is freed) and free the table.
    pub fn deinit(self: *SharingCache) void {
        const scope = self.scope orelse return;
        for (self.slots()) |slot| if (slot) |list| list.drop(scope);
        scope.allocator.free(self.heap_slots);
        scope.allocator.free(self.heap_hashes);
        self.* = .{};
    }

    /// The slot hash of `entries`: their ids mixed as integers (an entry is
    /// a name id and a value id, 8 bytes). The hash only picks the slot -
    /// equality is the content - so it need not be a byte hash's quality:
    /// a multiply and a fold per entry.
    fn hashOf(entries: []const Entry) u32 {
        var hash: u64 = entries.len;
        for (entries) |entry| {
            const bits: u64 = @bitCast(std.mem.asBytes(&entry).*);
            hash = (hash ^ bits) *% 0x9E3779B97F4A7C15;
            hash ^= hash >> 32;
        }
        return @truncate(hash);
    }

    fn sameEntries(list: *const AttributeList, entries: []const Entry) bool {
        return std.mem.eql(u8, std.mem.sliceAsBytes(list.items()), std.mem.sliceAsBytes(entries));
    }

    /// The shared block holding exactly `entries`, with one holder taken for
    /// the caller. The entries' references are handed over on success: a
    /// block found already holds its own, so they are released; a new block
    /// takes them. A block found with `max_holders` is replaced in the cache
    /// by a new one, and the cache lets go of its holder on the old.
    pub fn share(self: *SharingCache, scope: *runtime.BrowserScope, entries: []const Entry) error{OutOfMemory}!*const AttributeList {
        std.debug.assert(entries.len != 0);
        std.debug.assert(self.scope == null or self.scope == scope);
        self.scope = scope;
        if ((self.count + 1) * 4 > self.slots().len * 3) try self.grow(scope);
        const table = self.slots();
        const table_hashes = self.hashes();
        const hash = hashOf(entries);
        const mask = table.len - 1;
        var at: usize = hash & mask;
        while (table[at]) |list| : (at = (at + 1) & mask) {
            if (table_hashes[at] != hash or !sameEntries(list, entries)) continue;
            if (list.hold()) {
                for (entries) |entry| ElementData.releaseEntry(scope, entry);
                return list;
            }
            const fresh = try AttributeList.createShared(scope, entries, 2);
            table[at] = fresh;
            list.drop(scope);
            return fresh;
        }
        const fresh = try AttributeList.createShared(scope, entries, 2);
        table[at] = fresh;
        table_hashes[at] = hash;
        self.count += 1;
        return fresh;
    }

    /// Room for one more block. FIRST the blocks no element holds any more
    /// go (one holder: the cache alone): they serve nothing, and a cache
    /// that outlives its parser run - a Document's (dom.
    /// attribute_block_cache) - would otherwise keep every set a page
    /// parsed and dropped for as long as it lives, the "huge caches" Blink
    /// and WebKit name as the reason their document cache's timer is never
    /// restarted (Document::FinishedParsing, Document::finishedParsing).
    /// THEN the table the blocks still held need: at most half full, so a
    /// table that lost nothing is four times as long (16 -> 64 -> 256 ->
    /// 1,024: a run with many distinct sets grows it few times) and one that
    /// lost most of its blocks gets shorter, back to the inline one.
    noinline fn grow(self: *SharingCache, scope: *runtime.BrowserScope) error{OutOfMemory}!void {
        const old_slots = self.slots();
        const old_hashes = self.hashes();
        var held: usize = 0;
        for (old_slots) |slot| {
            const list = slot orelse continue;
            if (list.holders > 1) held += 1;
        }
        var len: usize = inline_len;
        while ((held + 1) * 2 > len) len *= 4;

        if (len == inline_len) {
            // Into the inline table - from itself (a copy first) or from
            // the heap's, which goes.
            var slots_copy: [inline_len]?*const AttributeList = undefined;
            var hashes_copy: [inline_len]u32 = undefined;
            const from_inline = self.heap_slots.len == 0;
            if (from_inline) {
                slots_copy = self.inline_slots;
                hashes_copy = self.inline_hashes;
            }
            const from_slots: []const ?*const AttributeList = if (from_inline) &slots_copy else old_slots;
            const from_hashes: []const u32 = if (from_inline) &hashes_copy else old_hashes;
            self.inline_slots = @splat(null);
            rehash(scope, from_slots, from_hashes, &self.inline_slots, &self.inline_hashes);
            if (!from_inline) {
                scope.allocator.free(self.heap_slots);
                scope.allocator.free(self.heap_hashes);
                self.heap_slots = &.{};
                self.heap_hashes = &.{};
            }
        } else {
            const new_slots = try scope.allocator.alloc(?*const AttributeList, len);
            errdefer scope.allocator.free(new_slots);
            const new_hashes = try scope.allocator.alloc(u32, len);
            @memset(new_slots, null);
            rehash(scope, old_slots, old_hashes, new_slots, new_hashes);
            scope.allocator.free(self.heap_slots);
            scope.allocator.free(self.heap_hashes);
            self.heap_slots = new_slots;
            self.heap_hashes = new_hashes;
        }
        self.count = held;
    }

    /// Move the blocks an element still holds from one table into another,
    /// empty one (a power of two long, with room for them), and let go of
    /// the rest.
    fn rehash(scope: *runtime.BrowserScope, from_slots: []const ?*const AttributeList, from_hashes: []const u32, to_slots: []?*const AttributeList, to_hashes: []u32) void {
        const mask = to_slots.len - 1;
        for (from_slots, from_hashes) |slot, hash| {
            const list = slot orelse continue;
            if (list.holders == 1) {
                list.drop(scope);
                continue;
            }
            var at: usize = hash & mask;
            while (to_slots[at] != null) at = (at + 1) & mask;
            to_slots[at] = list;
            to_hashes[at] = hash;
        }
    }
};

/// The references a holder takes on an attribute's name and value for a
/// span in which script can run - "handle attribute changes" through the
/// change steps, an event dispatch: `const held = Hold.take(scope, entry);
/// defer held.end();`. The bytes of both records stay valid until `end`,
/// whatever the script does to the attribute (changes it, removes it, or
/// grows the list). Blink and WebKit get the same from an AtomString the
/// caller keeps (a refcount on its StringImpl).
pub const Hold = struct {
    scope: *runtime.BrowserScope,
    entry: Entry,

    pub fn take(scope: *runtime.BrowserScope, entry: Entry) Hold {
        attribute_names.retain(scope, entry.name);
        attribute_values.retain(scope, entry.value);
        return .{ .scope = scope, .entry = entry };
    }

    pub fn end(self: Hold) void {
        attribute_names.release(self.scope, self.entry.name);
        attribute_values.release(self.scope, self.entry.value);
    }

    /// The held value's bytes: valid until `end`.
    pub fn value(self: Hold) []const u8 {
        return attribute_values.bytesIn(attribute_values.tableOf(self.scope), self.entry.value);
    }
};

/// A reader's view of an element's data: the data, its element's qualified
/// name (`name`, as `ElementData.name`), and its element's Browser, whose
/// tables its attributes' ids decode with. Made by `of(element)` (or
/// `ElementData.view(scope)`), BY VALUE: it holds no pointer into the
/// attribute list, only to the data, and reads the list - and the tables,
/// which the first attribute's interning may make after the view was taken
/// - afresh on every call.
pub const View = struct {
    data: *const ElementData,
    /// The element's qualified name record (`ElementData.name`).
    name: *const ElementName,
    scope: *runtime.BrowserScope,

    /// The tables, as they are now.
    pub inline fn tables(self: View) Tables {
        return Tables.of(self.scope);
    }

    inline fn namesTable(self: View) ?*const attribute_names.Table {
        return attribute_names.tableOf(self.scope);
    }

    inline fn valuesTable(self: View) ?*const attribute_values.Table {
        return attribute_values.tableOf(self.scope);
    }

    /// The element's namespace, borrowed; null for none.
    pub fn namespaceSlice(self: View) ?[]const u8 {
        return self.name.namespace_uri;
    }

    /// The element's local name, borrowed.
    pub fn localName(self: View) []const u8 {
        return self.name.local_name;
    }

    /// The element's ID (DOM 4.9 "set / unset element's ID": its id
    /// attribute's value in no namespace; empty is no ID), or "". Read from
    /// the list through the header's index (lane nd2 N3), BORROWED: the
    /// value record's bytes - valid until that attribute next changes.
    /// Blink's Element::GetIdAttribute reads the attribute the same way.
    pub fn idValue(self: View) []const u8 {
        const list = self.data.attrs orelse return "";
        return list.valueAt(self, self.valuesTable(), list.id_index, id_name);
    }

    /// `idValue`, with the values table a reader of many elements of this
    /// Browser found once (the selector matcher): no table load a visit.
    pub fn idValueIn(self: View, values: ?*const attribute_values.Table) []const u8 {
        const list = self.data.attrs orelse return "";
        return list.valueAt(self, values orelse self.valuesTable(), list.id_index, id_name);
    }

    /// The class attribute's value in no namespace, or "": what the class
    /// selector, classList and getElementsByClassName read. Borrowed, like
    /// `idValue`.
    pub fn classValue(self: View) []const u8 {
        const list = self.data.attrs orelse return "";
        return list.valueAt(self, self.valuesTable(), list.class_index, class_name);
    }

    /// `classValue`, with the values table found once (`idValueIn`).
    pub fn classValueIn(self: View, values: ?*const attribute_values.Table) []const u8 {
        const list = self.data.attrs orelse return "";
        return list.valueAt(self, values orelse self.valuesTable(), list.class_index, class_name);
    }

    /// The class attribute's value in no namespace as its record's id, or
    /// .empty: what a class read takes the value's token list from
    /// (attribute_values.Table.hasToken / classNames; lane nd2 batch 3). No
    /// table load - the id itself says whether the value is one token.
    pub inline fn classId(self: View) ValueId {
        const list = self.data.attrs orelse return .empty;
        return list.valueIdAt(self, list.class_index, class_name);
    }

    /// The value of the attribute whose namespace is `namespace_uri` and
    /// local name is `local_name` as its record's id - .empty for the empty
    /// value - or null when there is no such attribute: a DOMTokenList's
    /// read of its attribute.
    pub fn findValueId(self: View, namespace_uri: ?[]const u8, local_name: []const u8) ?ValueId {
        const index = self.indexOfAttribute(namespace_uri, local_name) orelse return null;
        return self.data.stored()[index].value;
    }

    /// The number of attributes in the list.
    pub fn getAttributeCount(self: View) usize {
        return self.data.getAttributeCount();
    }

    /// The attributes in list order, each a view by value. The iterator
    /// keeps an index and reads the list afresh at each step.
    pub const AttributeIterator = struct {
        view: View,
        index: usize = 0,

        pub fn next(self: *AttributeIterator) ?AttributeEntry {
            const items = self.view.data.stored();
            if (self.index >= items.len) return null;
            const item = items[self.index];
            self.index += 1;
            return self.view.tables().view(item);
        }
    };

    pub fn attributeIterator(self: View) AttributeIterator {
        return .{ .view = self };
    }

    /// The attribute whose namespace is `namespace_uri` and local name is
    /// `local_name`; there is at most one.
    pub fn findAttribute(self: View, namespace_uri: ?[]const u8, local_name: []const u8) ?AttributeEntry {
        const index = self.indexOfAttribute(namespace_uri, local_name) orelse return null;
        return self.tables().view(self.data.stored()[index]);
    }

    /// The attribute at `index` in list order, or null past the end.
    pub fn attributeAt(self: View, index: usize) ?AttributeEntry {
        const entry = self.data.storedAt(index) orelse return null;
        return self.tables().view(entry);
    }

    /// The VALUE of the attribute at `index`, or null past the end: one
    /// table read, no name decoded (getAttribute's step 3).
    pub fn valueAt(self: View, index: usize) ?[]const u8 {
        const entry = self.data.storedAt(index) orelse return null;
        return attribute_values.bytesIn(self.valuesTable(), entry.value);
    }

    /// The value of the attribute whose namespace is `namespace_uri` and
    /// local name is `local_name`, or null: `findAttribute`'s value alone.
    pub fn findValue(self: View, namespace_uri: ?[]const u8, local_name: []const u8) ?[]const u8 {
        const index = self.indexOfAttribute(namespace_uri, local_name) orelse return null;
        return attribute_values.bytesIn(self.valuesTable(), self.data.stored()[index].value);
    }

    /// A count on the records of the attribute whose namespace is
    /// `namespace_uri` and local name is `local_name` - for a holder whose
    /// span crosses a point where script can run (`Hold`) - or null when
    /// there is none.
    pub fn holdAttribute(self: View, namespace_uri: ?[]const u8, local_name: []const u8) ?Hold {
        const index = self.indexOfAttribute(namespace_uri, local_name) orelse return null;
        return Hold.take(self.scope, self.data.stored()[index]);
    }

    /// The name record of the attribute at `index`, or null past the end:
    /// static, or counted by the attribute's entry - stable while it lives.
    pub fn nameAt(self: View, index: usize) ?*const QualifiedName {
        const entry = self.data.storedAt(index) orelse return null;
        return self.tables().name(entry.name);
    }

    /// Index of the attribute whose namespace is `namespace_uri` and local
    /// name is `local_name`. There is at most one.
    pub fn indexOfAttribute(self: View, namespace_uri: ?[]const u8, local_name: []const u8) ?usize {
        const entries = self.data.stored();
        if (entries.len == 0) return null;
        const names = self.namesTable();
        for (entries, 0..) |entry, index| {
            if (attribute_names.record(names, entry.name).isNamed(namespace_uri, local_name)) return index;
        }
        return null;
    }

    /// Index of the FIRST attribute whose qualified name is `qualified_name`.
    /// Two attributes in different namespaces can share one.
    pub fn indexOfQualifiedName(self: View, qualified_name: []const u8) ?usize {
        const entries = self.data.stored();
        if (entries.len == 0) return null;
        const names = self.namesTable();
        for (entries, 0..) |entry, index| {
            if (attribute_names.record(names, entry.name).qualifiedNameIs(qualified_name)) return index;
        }
        return null;
    }
};

/// DOM "get an attribute by namespace and local name": the attribute in the
/// element's attribute list whose namespace is `namespace` and local name is
/// `local_name`, or null. Borrowed.
///
/// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-get-by-namespace
pub fn getAttributeByNamespaceAndLocalName(data: View, namespace: ?[]const u8, local_name: []const u8) ?AttributeEntry {
    // Step 1: "If namespace is the empty string, then set it to null."
    const ns: ?[]const u8 = if (namespace) |n| (if (n.len == 0) null else n) else null;
    // Step 2: "Return the attribute in element's attribute list whose
    // namespace is namespace and local name is localName, if any; otherwise
    // null."
    return data.findAttribute(ns, local_name);
}

/// DOM "get an attribute value": the value of the attribute with this local
/// name and namespace (null for none), or the empty string. Borrowed - valid
/// until the attribute next changes.
///
/// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-get-value
pub fn getAttributeValue(data: View, local_name: []const u8, namespace: ?[]const u8) []const u8 {
    // Step 1: "Let attr be the result of getting an attribute given
    // namespace, localName, and element."
    // (getAttributeByNamespaceAndLocalName's steps, its value alone read.)
    const ns: ?[]const u8 = if (namespace) |n| (if (n.len == 0) null else n) else null;
    const value = data.findValue(ns, local_name) orelse {
        // Step 2: "If attr is null, then return the empty string."
        return "";
    };
    // Step 3: "Return attr's value."
    return value;
}

/// Whether the element has an attribute in no namespace with this local name
/// - a boolean content attribute's state (HTML 2.3.2).
pub fn hasAttribute(data: View, local_name: []const u8) bool {
    return data.indexOfAttribute(null, local_name) != null;
}

/// The classes getElementsByClassName looks for - DOM 4.2.6 "the list of
/// elements with class names classNames": classNames run through the
/// ordered set parser - as ids of one Browser's attribute values, read once
/// per refill of its collection, then compared with each element's class
/// tokens by id (lane nd2 batch 3; Blink's ClassCollection keeps its names
/// as a SpaceSplitString and asks ClassNames().ContainsAll()). In quirks
/// mode both sides are the ASCII lowercase (Blink's ClassCollection
/// constructor folds the names; "the comparisons for the classes must be
/// done in an ASCII case-insensitive manner"). A name kept as bytes (one too
/// long for an id), more names than `inline_count`, or no memory for a token
/// list: the byte compare, for the whole set.
pub const ClassSet = struct {
    const inline_count = 8;

    table: ?*attribute_values.Table = null,
    /// The table's `operand_frees` when the ids were read: they stay
    /// valid while it has not moved.
    frees: u64 = 0,
    ids: [inline_count]ValueId = undefined,
    len: usize = 0,
    /// Compare bytes: `text`'s tokens against each element's class value.
    bytes: bool = false,
    text: []const u8,
    quirks: bool,

    /// The set for `class_names` (borrowed for the set's life) in the
    /// Browser `scope`, for a document in quirks mode or not. The caller
    /// handles the empty set (DOM: an empty collection).
    pub fn init(scope: *runtime.BrowserScope, class_names: []const u8, quirks: bool) ClassSet {
        var set: ClassSet = .{ .text = class_names, .quirks = quirks };
        // No values table: no element of this Browser has a class.
        const table = attribute_values.classTable(scope) orelse return set;
        set.table = table;
        // A later name's release can free an earlier name's record (a ring
        // eviction that cascades through freed token lists), which moves
        // `operand_frees`: ids read across that are not trusted, and the
        // names are read again - their records parked now, so a second
        // pass frees nothing - or compared as bytes.
        for (0..2) |_| {
            const before = table.operand_frees;
            set.len = 0;
            var it = std.mem.tokenizeAny(u8, class_names, ascii_whitespace);
            while (it.next()) |name| {
                if (set.len == inline_count) return set.byBytes();
                const id = (table.operandOf(name, quirks) catch return set.byBytes()) orelse return set.byBytes();
                set.ids[set.len] = id;
                set.len += 1;
            }
            if (table.operand_frees == before) {
                set.frees = before;
                return set;
            }
        }
        return set.byBytes();
    }

    fn byBytes(self: ClassSet) ClassSet {
        var set = self;
        set.bytes = true;
        return set;
    }

    /// Whether every class of the set is one of `data`'s classes.
    pub fn matches(self: *ClassSet, data: View) bool {
        if (self.bytes) return self.matchesBytes(data);
        const id = data.classId();
        if (id == .empty) return false;
        const table = self.table orelse return false;
        if (table.operand_frees != self.frees) {
            self.bytes = true;
            return self.matchesBytes(data);
        }
        for (self.ids[0..self.len]) |wanted| {
            const found = (if (self.quirks) table.hasFoldedToken(id, wanted) else table.hasToken(id, wanted)) catch return self.matchesBytes(data);
            if (!found) return false;
        }
        return true;
    }

    fn matchesBytes(self: *const ClassSet, data: View) bool {
        const classes = data.classValue();
        if (classes.len == 0) return false;
        var names = std.mem.tokenizeAny(u8, self.text, ascii_whitespace);
        while (names.next()) |name| {
            var tokens = std.mem.tokenizeAny(u8, classes, ascii_whitespace);
            const found = while (tokens.next()) |token| {
                if (if (self.quirks) std.ascii.eqlIgnoreCase(token, name) else std.mem.eql(u8, token, name)) break true;
            } else false;
            if (!found) return false;
        }
        return true;
    }
};

/// Infra's ASCII whitespace: TAB, LF, FF, CR, SPACE (not VT).
const ascii_whitespace = "\t\n\x0C\r ";

/// `element`'s view made from its data, with its Browser (`ofInstance`: the
/// slab header its Instance sits in - ElementData itself has no route to it,
/// review C2).
fn viewOfElement(data: *const ElementData, element: *runtime.Instance) View {
    return .{ .data = data, .name = data.name, .scope = runtime.BrowserScope.ofInstance(element) };
}

/// `of`, for a reader that visits many elements of ONE Browser in one step
/// (the selector matcher, lane nd2 batch 2): `scope` is that Browser's,
/// found once, so a visit costs no address lookup.
pub fn ofIn(element: *runtime.Instance, scope: *runtime.BrowserScope) ?View {
    const impl = implementation.get() orelse return null;
    const data = impl.of(element) orelse return null;
    return .{ .data = data, .name = data.name, .scope = scope };
}

/// An element's rare data (dom.element_rare_data), which Element keeps and
/// reaches through this slot too: one hook per owner, not one per field.
const element_rare_data = @import("element_rare_data.zig");

/// What Element supplies.
pub const Implementation = struct {
    /// `element`'s data, or null when `element` has no Element part.
    of: *const fn (element: *runtime.Instance) ?*ElementData,
    /// `element`'s rare data access - the addresses of its holder and of
    /// click()'s flag, good for the element's life - or null when it is no
    /// element. The block moves when it grows, so a writer passes the
    /// holder itself (lane rare1; Blink's RareDataUpdate refreshes
    /// Node::data_).
    rare_holder: *const fn (element: *runtime.Instance) ?element_rare_data.Access,
};

// process-wide: an immutable function pointer Element installs once at process start (crane.Process); it reads only the element it is given, so one serves every Browser and thread
var implementation: Hook(?Implementation) = .init(null);

/// Called by Element's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    implementation.install(impl);
}

/// `element`'s data, read-only, as a reader's View (its Browser's tables
/// decode the attributes' ids): write through `dom.element_attributes`.
/// Null when `element` is no element (or Element installed nothing).
pub fn of(element: *runtime.Instance) ?View {
    const impl = implementation.get() orelse return null;
    return viewOfElement(impl.of(element) orelse return null, element);
}

/// `element`'s rare data access, or null when it is no element:
/// dom.element_rare_data.access.
pub fn rareHolderOf(element: *runtime.Instance) ?element_rare_data.Access {
    const impl = implementation.get() orelse return null;
    return impl.rare_holder(element);
}

// ============================================================================
// Tests
// ============================================================================

/// Append (`namespace`, `prefix`, `local_name`) = `value` the way Element
/// does: the ids interned in `scope`, the list taking both references.
fn testAppend(scope: *runtime.BrowserScope, data: *ElementData, namespace: ?[]const u8, prefix: ?[]const u8, local_name: []const u8, value: []const u8) !void {
    const name = try attribute_names.intern(scope, namespace, prefix, local_name);
    errdefer attribute_names.release(scope, name);
    const id = try attribute_values.intern(scope, value);
    errdefer attribute_values.release(scope, id);
    try data.appendAttribute(scope, .{ .name = name, .value = id });
}

fn testRemoveAt(scope: *runtime.BrowserScope, data: *ElementData, index: usize) void {
    ElementData.releaseEntry(scope, data.takeAttributeAt(scope, index) catch unreachable);
}

/// `names[i]` = `values[i]` interned in `scope`: entries whose references
/// the caller owns.
fn testEntries(scope: *runtime.BrowserScope, buffer: []Entry, names: []const []const u8, values: []const []const u8) ![]Entry {
    for (names, values, 0..) |name, value, i| {
        buffer[i] = .{ .name = try attribute_names.intern(scope, null, null, name), .value = try attribute_values.intern(scope, value) };
    }
    return buffer[0..names.len];
}

/// A parsed element's data: `names` = `values` through `cache`.
fn testParsed(scope: *runtime.BrowserScope, cache: ?*SharingCache, names: []const []const u8, values: []const []const u8) !ElementData {
    var buffer: [8]Entry = undefined;
    var data = ElementData.init();
    try data.adoptEntries(scope, try testEntries(scope, &buffer, names, values), cache);
    return data;
}

test "A3: two parsed elements with equal sets hold ONE block, a different set its own; the last holder frees it" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    var cache: SharingCache = .{};
    var a = try testParsed(&scope, &cache, &.{ "class", "id" }, &.{ "x y", "one" });
    var b = try testParsed(&scope, &cache, &.{ "class", "id" }, &.{ "x y", "one" });
    var c = try testParsed(&scope, &cache, &.{ "class", "id" }, &.{ "x y", "two" });
    // Same names, other order: another set.
    var d = try testParsed(&scope, &cache, &.{ "id", "class" }, &.{ "one", "x y" });
    try std.testing.expect(a.attrs.? == b.attrs.?);
    try std.testing.expect(a.attrs.? != c.attrs.? and a.attrs.? != d.attrs.?);
    try std.testing.expectEqual(@as(u8, 3), a.attrs.?.holders); // a, b and the cache
    try std.testing.expectEqual(@as(usize, 3), cache.count);
    // The ID and class indices are the block's, computed once.
    try std.testing.expectEqualStrings("one", b.view(&scope).idValue());
    try std.testing.expectEqualStrings("x y", b.view(&scope).classValue());
    try std.testing.expectEqualStrings("one", d.view(&scope).idValue());
    try std.testing.expectEqualStrings("x y", d.view(&scope).classValue());
    // The cache goes first; the blocks live while an element holds them.
    cache.deinit();
    try std.testing.expectEqual(@as(u8, 2), a.attrs.?.holders);
    a.deinit(&scope);
    try std.testing.expectEqual(@as(u8, 1), b.attrs.?.holders);
    try std.testing.expectEqualStrings("one", b.view(&scope).idValue());
    b.deinit(&scope);
    c.deinit(&scope);
    d.deinit(&scope);
    // std.testing.allocator: every block, record and table freed.
}

test "A3: a block counts at most 255 holders: 300 equal elements are two blocks, counts exact, all freed" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    var cache: SharingCache = .{};
    var elements: [300]ElementData = undefined;
    for (&elements) |*data| data.* = try testParsed(&scope, &cache, &.{ "class", "href" }, &.{ "row", "#" });
    const first = elements[0].attrs.?;
    const second = elements[299].attrs.?;
    try std.testing.expect(first != second);
    // The first block: 255 holders when it filled - 254 elements and the
    // cache - then the cache let go of it for the second.
    try std.testing.expectEqual(@as(u8, 254), first.holders);
    for (elements[0..254]) |data| try std.testing.expect(data.attrs.? == first);
    for (elements[254..]) |data| try std.testing.expect(data.attrs.? == second);
    try std.testing.expectEqual(@as(u8, 300 - 254 + 1), second.holders);
    // A clone of an element of the full block... the first is not full now;
    // fill it again through clones, then one more clone gets a copy.
    var clones: [2]ElementData = .{ ElementData.init(), ElementData.init() };
    try clones[0].shareFrom(&scope, &elements[0]);
    try std.testing.expectEqual(@as(u8, 255), first.holders);
    try clones[1].shareFrom(&scope, &elements[0]);
    try std.testing.expect(clones[1].attrs.? != first and !clones[1].attrs.?.isShared());
    try std.testing.expectEqual(@as(u8, 255), first.holders);
    for (&clones) |*data| data.deinit(&scope);
    cache.deinit();
    for (&elements) |*data| data.deinit(&scope);
}

test "A3: every writer copies a shared block and leaves the other holder untouched" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    const Writer = enum { append, take, take_last, set_value, set_name, reserve };
    for (std.enums.values(Writer)) |writer| {
        var cache: SharingCache = .{};
        defer cache.deinit();
        const one = writer == .take_last;
        const names: []const []const u8 = if (one) &.{"id"} else &.{ "id", "class" };
        const values: []const []const u8 = if (one) &.{"a"} else &.{ "a", "b c" };
        var mine = try testParsed(&scope, &cache, names, values);
        defer mine.deinit(&scope);
        var other = try testParsed(&scope, &cache, names, values);
        defer other.deinit(&scope);
        const shared = other.attrs.?;
        try std.testing.expect(mine.attrs.? == shared);
        switch (writer) {
            .append => try testAppend(&scope, &mine, null, null, "title", "t"),
            .take => testRemoveAt(&scope, &mine, 0),
            .take_last => testRemoveAt(&scope, &mine, 0),
            .set_value => attribute_values.release(&scope, try mine.setValueAt(&scope, 0, try attribute_values.intern(&scope, "z"))),
            .set_name => attribute_names.release(&scope, try mine.setNameAt(&scope, 0, try attribute_names.intern(&scope, null, "p", "id"))),
            .reserve => try mine.reserve(&scope, 3),
        }
        // The other holder still reads its set, from the same block.
        try std.testing.expect(other.attrs.? == shared);
        try std.testing.expectEqualStrings("a", other.view(&scope).idValue());
        try std.testing.expectEqual(names.len, other.getAttributeCount());
        // The writer's list is its own now (or gone).
        if (mine.attrs) |list| {
            try std.testing.expect(list != shared and !list.isShared());
        } else try std.testing.expect(writer == .take_last);
        try std.testing.expectEqual(@as(u8, 2), shared.holders); // other + cache
        switch (writer) {
            .append => try std.testing.expectEqualStrings("t", mine.view(&scope).findValue(null, "title").?),
            .take => try std.testing.expectEqualStrings("", mine.view(&scope).idValue()),
            .set_value => try std.testing.expectEqualStrings("z", mine.view(&scope).idValue()),
            .set_name => try std.testing.expectEqualStrings("p", mine.view(&scope).attributeAt(0).?.prefix.?),
            .reserve => try std.testing.expect(mine.attrs.?.capacity() >= 5),
            .take_last => {},
        }
        try std.testing.expectEqualStrings("b c", if (one) "b c" else mine.view(&scope).classValue());
    }
}

test "A3: the last holder of a shared block takes it over for a write - no copy" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    var cache: SharingCache = .{};
    var data = try testParsed(&scope, &cache, &.{"id"}, &.{"a"});
    defer data.deinit(&scope);
    cache.deinit();
    const block = data.attrs.?;
    try std.testing.expectEqual(@as(u8, 1), block.holders);
    attribute_values.release(&scope, try data.setValueAt(&scope, 0, try attribute_values.intern(&scope, "b")));
    try std.testing.expect(data.attrs.? == block and !block.isShared());
    try std.testing.expectEqualStrings("b", data.view(&scope).idValue());
}

test "A3: a clone shares its source's block - an element's own list becomes shared in place - and writes copy" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    var source = ElementData.init();
    defer source.deinit(&scope);
    try testAppend(&scope, &source, null, null, "id", "s");
    try testAppend(&scope, &source, null, null, "class", "k");
    const own = source.attrs.?;
    var copy = ElementData.init();
    defer copy.deinit(&scope);
    try copy.shareFrom(&scope, &source);
    try std.testing.expect(copy.attrs.? == own and own.holders == 2);
    // A source with no attributes: nothing to share.
    var empty = ElementData.init();
    var copy_of_empty = ElementData.init();
    try copy_of_empty.shareFrom(&scope, &empty);
    try std.testing.expect(copy_of_empty.attrs == null);
    // The source writes: it copies, the clone keeps the block.
    try testAppend(&scope, &source, null, null, "title", "t");
    try std.testing.expect(source.attrs.? != own and copy.attrs.? == own and own.holders == 1);
    try std.testing.expectEqualStrings("s", copy.view(&scope).idValue());
    try std.testing.expectEqual(@as(usize, 2), copy.getAttributeCount());
}

/// A parser run and what follows it, on an allocator that fails: 258 parsed
/// elements with one set (the block fills, and the cache replaces it), 50
/// with sets of their own (the cache's table leaves the cache for the
/// allocator at its 13th set and grows again at its 49th), then a clone, a
/// clone of the full block, and two writers' copies. Whatever fails, every
/// reference, block and table is let go.
fn testRunUnderFailure(allocator: std.mem.Allocator) !void {
    var scope = runtime.BrowserScope.init(allocator);
    defer scope.deinit();
    var cache: SharingCache = .{};
    defer cache.deinit();
    var elements: [258 + 50]ElementData = undefined;
    var made: usize = 0;
    defer for (elements[0..made]) |*data| data.deinit(&scope);
    for (&elements, 0..) |*data, i| {
        data.* = ElementData.init();
        made += 1;
        // As Element's setParsedAttributesHook: the entries' references are
        // the caller's until the list takes them.
        var entries: [2]Entry = undefined;
        var interned: usize = 0;
        errdefer for (entries[0..interned]) |entry| ElementData.releaseEntry(&scope, entry);
        var href: [8]u8 = undefined;
        const own = i >= 258;
        for ([_][]const u8{ "class", "href" }, [_][]const u8{ "row", if (own) try std.fmt.bufPrint(&href, "#{d}", .{i}) else "#" }) |name, value| {
            const name_id = try attribute_names.intern(&scope, null, null, name);
            const value_id = attribute_values.intern(&scope, value) catch |err| {
                attribute_names.release(&scope, name_id);
                return err;
            };
            entries[interned] = .{ .name = name_id, .value = value_id };
            interned += 1;
        }
        try data.adoptEntries(&scope, &entries, &cache);
        interned = 0;
    }
    // The first block is full (254 elements; the cache moved on): a clone of
    // one of its holders takes the 255th place, the next gets a copy.
    var clones: [2]ElementData = .{ ElementData.init(), ElementData.init() };
    defer for (&clones) |*data| data.deinit(&scope);
    for (&clones) |*data| try data.shareFrom(&scope, &elements[0]);
    // A writer's copy of a shared block, with the append's own growth.
    try testAppend(&scope, &elements[1], null, null, "title", "t");
    try elements[2].reserve(&scope, 3);
}

test "A3: a run of up to twelve distinct sets allocates no table; the thirteenth moves it to the allocator, and every block is still found" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    var cache: SharingCache = .{};
    defer cache.deinit();
    var elements: [40]ElementData = undefined;
    var made: usize = 0;
    defer for (elements[0..made]) |*data| data.deinit(&scope);
    var value: [8]u8 = undefined;
    for (elements[0..12], 0..) |*data, i| {
        data.* = try testParsed(&scope, &cache, &.{"href"}, &.{try std.fmt.bufPrint(&value, "#{d}", .{i})});
        made += 1;
    }
    // Twelve blocks, in the cache's own table.
    try std.testing.expectEqual(@as(usize, 12), cache.count);
    try std.testing.expectEqual(@as(usize, 0), cache.heap_slots.len);
    for (elements[12..20], 12..) |*data, i| {
        data.* = try testParsed(&scope, &cache, &.{"href"}, &.{try std.fmt.bufPrint(&value, "#{d}", .{i})});
        made += 1;
    }
    try std.testing.expectEqual(@as(usize, 64), cache.heap_slots.len);
    try std.testing.expectEqual(@as(usize, 20), cache.count);
    // Every set made before and after the move is found again: one block each.
    for (elements[20..40], 0..) |*data, i| {
        data.* = try testParsed(&scope, &cache, &.{"href"}, &.{try std.fmt.bufPrint(&value, "#{d}", .{i})});
        made += 1;
        try std.testing.expect(data.attrs.? == elements[i].attrs.?);
        try std.testing.expectEqual(@as(u8, 3), data.attrs.?.holders);
    }
    try std.testing.expectEqual(@as(usize, 20), cache.count);
}

/// How many references `scope`'s value table counts on `bytes`: 0 when no
/// entry of any block names it.
fn testValueReferences(scope: *runtime.BrowserScope, bytes: []const u8) u32 {
    const table = attribute_values.tableOf(scope) orelse return 0;
    const id = table.find(bytes) orelse return 0;
    return table.get(id).references;
}

test "A5: a table that would grow first lets go of the blocks no element holds" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    var cache: SharingCache = .{};
    defer cache.deinit();
    var elements: [12]ElementData = undefined;
    var value: [8]u8 = undefined;
    for (&elements, 0..) |*data, i| data.* = try testParsed(&scope, &cache, &.{"href"}, &.{try std.fmt.bufPrint(&value, "#{d}", .{i})});
    defer for (elements[0..2]) |*data| data.deinit(&scope);
    // Ten of the twelve elements go: their blocks are the table's alone.
    for (elements[2..]) |*data| data.deinit(&scope);
    try std.testing.expectEqual(@as(usize, 12), cache.count);
    try std.testing.expectEqual(@as(u32, 1), testValueReferences(&scope, "#5"));
    // The thirteenth set would grow the table (it is three quarters full):
    // the ten unheld blocks go instead, and it stays the inline one.
    var next = try testParsed(&scope, &cache, &.{"href"}, &.{"#12"});
    defer next.deinit(&scope);
    try std.testing.expectEqual(@as(usize, 3), cache.count);
    try std.testing.expectEqual(@as(usize, 0), cache.heap_slots.len);
    try std.testing.expectEqual(@as(u32, 0), testValueReferences(&scope, "#5"));
    // The held blocks are still found...
    for (elements[0..2], 0..) |*data, i| {
        var again = try testParsed(&scope, &cache, &.{"href"}, &.{try std.fmt.bufPrint(&value, "#{d}", .{i})});
        defer again.deinit(&scope);
        try std.testing.expect(again.attrs.? == data.attrs.?);
    }
    // ...and a set that went is made again.
    var remade = try testParsed(&scope, &cache, &.{"href"}, &.{"#5"});
    defer remade.deinit(&scope);
    try std.testing.expectEqual(@as(u8, 2), remade.attrs.?.holders);
    try std.testing.expectEqual(@as(usize, 4), cache.count);
}

test "A5: a table that lost most of its blocks gets shorter - back to the inline one - and a churn of unheld sets never grows it" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    var cache: SharingCache = .{};
    defer cache.deinit();
    var elements: [49]ElementData = undefined;
    var value: [12]u8 = undefined;
    for (&elements, 0..) |*data, i| data.* = try testParsed(&scope, &cache, &.{"href"}, &.{try std.fmt.bufPrint(&value, "#{d}", .{i})});
    defer for (elements[0..4]) |*data| data.deinit(&scope);
    try std.testing.expectEqual(@as(usize, 256), cache.heap_slots.len);
    for (elements[4..]) |*data| data.deinit(&scope);
    // 5,000 sets, each dropped at once (a page setting innerHTML on a
    // timer): every growth point finds only unheld blocks beside the four
    // held ones, so the table never passes its first heap size, and what it
    // keeps at any moment is under one table's worth.
    var longest: usize = 0;
    for (0..5000) |i| {
        var data = try testParsed(&scope, &cache, &.{"href"}, &.{try std.fmt.bufPrint(&value, "x{d}", .{i})});
        data.deinit(&scope);
        longest = @max(longest, cache.heap_slots.len);
        try std.testing.expect(cache.count <= 192);
    }
    try std.testing.expectEqual(@as(usize, 256), longest);
    // After the first growth point the four held blocks fit the inline
    // table, which the churn then fills and empties.
    try std.testing.expectEqual(@as(usize, 0), cache.heap_slots.len);
    try std.testing.expect(cache.count <= 12);
    for (elements[0..4], 0..) |*data, i| {
        var again = try testParsed(&scope, &cache, &.{"href"}, &.{try std.fmt.bufPrint(&value, "#{d}", .{i})});
        defer again.deinit(&scope);
        try std.testing.expect(again.attrs.? == data.attrs.?);
    }
}

test "A3: an allocation failure in a share, the cache's growth, a copy on write or a clone leaves nothing behind" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, testRunUnderFailure, .{});
}

test "an entry is 8 bytes with no pointer, and a one-attribute element pays one 16-byte block" {
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(Entry));
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(AttributeList));
    try std.testing.expect(!holdsPointer(Entry));
    // The predicate sees a pointer wherever one hides.
    try std.testing.expect(holdsPointer(struct { a: u32, b: ?*u8 }));
    try std.testing.expect(holdsPointer(struct { a: [2][]const u8 }));
    try std.testing.expect(!holdsPointer(struct { a: u32, b: enum(u32) { x, _ } }));

    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    var data = ElementData.init();
    defer data.deinit(&scope);
    try testAppend(&scope, &data, null, null, "title", "x");
    try std.testing.expectEqual(@as(usize, 1), data.attrs.?.capacity());
    try std.testing.expectEqual(@as(usize, 16), AttributeList.bytesFor(data.attrs.?.capacity()));
}

test "script's appends grow the list 1, 4, 8; a reservation is exact; order holds as it shrinks to nothing" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    var data = ElementData.init();
    defer data.deinit(&scope);

    try std.testing.expect(data.attrs == null);
    const names = [_][]const u8{ "a", "b", "c", "d", "e", "f" };
    const capacities = [_]usize{ 1, 4, 4, 4, 8, 8 };
    for (names, capacities) |name, cap| {
        try testAppend(&scope, &data, null, null, name, name);
        try std.testing.expectEqual(cap, data.attrs.?.capacity());
    }
    const view = data.view(&scope);
    try std.testing.expectEqual(@as(usize, 6), view.getAttributeCount());
    for (names, 0..) |name, i| try std.testing.expectEqualStrings(name, view.attributeAt(i).?.local_name);
    try std.testing.expect(view.attributeAt(6) == null);

    // Taking one keeps the others' order.
    testRemoveAt(&scope, &data, 1);
    const rest = [_][]const u8{ "a", "c", "d", "e", "f" };
    var it = data.view(&scope).attributeIterator();
    for (rest) |name| try std.testing.expectEqualStrings(name, it.next().?.value);
    try std.testing.expect(it.next() == null);
    try std.testing.expectEqual(@as(usize, 3), data.view(&scope).indexOfAttribute(null, "e").?);

    // The list goes with its last attribute, and so do the values.
    while (data.getAttributeCount() > 0) testRemoveAt(&scope, &data, 0);
    try std.testing.expect(data.attrs == null);
    try std.testing.expectEqual(@as(usize, 0), attribute_values.tableOf(&scope).?.liveCount());

    // Parse and clone reserve exactly: five attributes, five entries; then
    // a script append doubles.
    try data.reserve(&scope, 5);
    for (names[0..5]) |name| try testAppend(&scope, &data, null, null, name, "v");
    try std.testing.expectEqual(@as(usize, 5), data.attrs.?.capacity());
    try testAppend(&scope, &data, null, null, "f", "v");
    try std.testing.expectEqual(@as(usize, 10), data.attrs.?.capacity());
    // Past 128 entries a class is a power of two.
    try std.testing.expectEqual(@as(usize, 256), AttributeList.capacityOf(try AttributeList.classFor(200)));
    try std.testing.expectEqual(@as(usize, 128), AttributeList.capacityOf(try AttributeList.classFor(128)));
    // One value record serves all six attributes.
    try std.testing.expectEqual(@as(usize, 1), attribute_values.tableOf(&scope).?.liveCount());
}

test "attributes are named by namespace and local name, and found by qualified name" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    var data = ElementData.init();
    defer data.deinit(&scope);

    try testAppend(&scope, &data, "urn:x", "x", "title", "namespaced");
    try testAppend(&scope, &data, null, null, "title", "plain");
    const view = data.view(&scope);

    // By namespace and local name: one each; "" is null for the algorithm.
    try std.testing.expectEqualStrings("plain", getAttributeValue(view, "title", null));
    try std.testing.expectEqualStrings("plain", getAttributeValue(view, "title", ""));
    try std.testing.expectEqualStrings("namespaced", getAttributeValue(view, "title", "urn:x"));
    try std.testing.expectEqualStrings("", getAttributeValue(view, "title", "urn:y"));
    try std.testing.expect(hasAttribute(view, "title"));
    try std.testing.expect(!hasAttribute(view, "lang"));

    // By qualified name: "x:title" is the namespaced one, and "title" the
    // first whose qualified name it is - the plain one, the namespaced one
    // having a prefix.
    try std.testing.expectEqual(@as(usize, 0), view.indexOfQualifiedName("x:title").?);
    try std.testing.expectEqual(@as(usize, 1), view.indexOfQualifiedName("title").?);
    try std.testing.expect(view.indexOfQualifiedName("y:title") == null);
    // The namespaced name is the Browser's record; the plain one static.
    try std.testing.expect(!data.storedAt(0).?.name.isStatic());
    try std.testing.expect(data.storedAt(1).?.name.isStatic());
}

test "views survive the block's growth: a growth moves ids, never bytes" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    var data = ElementData.init();
    defer data.deinit(&scope);

    try testAppend(&scope, &data, null, null, "id", "main");
    try testAppend(&scope, &data, null, null, "data-first", "first value");
    const first = data.view(&scope).attributeAt(1).?;
    const block_before = @intFromPtr(data.attrs.?);
    var i: usize = 0;
    while (i < 20) : (i += 1) {
        var buffer: [16]u8 = undefined;
        const name = try std.fmt.bufPrint(&buffer, "a{d}", .{i});
        try testAppend(&scope, &data, null, null, name, name);
    }
    // The block moved (and was poisoned in Debug); the view taken before it
    // reads its records, which did not.
    try std.testing.expect(@intFromPtr(data.attrs.?) != block_before);
    try std.testing.expectEqualStrings("first value", first.value);
    try std.testing.expectEqualStrings("data-first", first.local_name);
    try std.testing.expectEqualStrings("main", data.view(&scope).idValue());
}

test "the header's indices follow appends and removals, saturate past 253 and stay exact below it" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    var data = ElementData.init();
    defer data.deinit(&scope);

    try std.testing.expectEqualStrings("", data.view(&scope).idValue());
    // A namespaced id is not the element's.
    try testAppend(&scope, &data, "urn:x", "p", "id", "ns");
    try std.testing.expectEqual(AttributeList.no_index, data.attrs.?.id_index);
    var i: usize = 0;
    while (i < 252) : (i += 1) {
        var buffer: [16]u8 = undefined;
        const name = try std.fmt.bufPrint(&buffer, "a{d}", .{i});
        try testAppend(&scope, &data, null, null, name, "");
    }
    // Position 253: the last exact index. Position 254: saturated.
    try testAppend(&scope, &data, null, null, "id", "i");
    try testAppend(&scope, &data, null, null, "class", "c");
    try std.testing.expectEqual(@as(u8, 253), data.attrs.?.id_index);
    try std.testing.expectEqual(AttributeList.saturated_index, data.attrs.?.class_index);
    try std.testing.expectEqualStrings("i", data.view(&scope).idValue());
    try std.testing.expectEqualStrings("c", data.view(&scope).classValue());
    // A removal before both: the class comes down to an exact 253.
    testRemoveAt(&scope, &data, 0);
    try std.testing.expectEqual(@as(u8, 252), data.attrs.?.id_index);
    try std.testing.expectEqual(@as(u8, 253), data.attrs.?.class_index);
    try std.testing.expectEqualStrings("c", data.view(&scope).classValue());
    // The id goes; the class moves down.
    testRemoveAt(&scope, &data, 252);
    try std.testing.expectEqual(AttributeList.no_index, data.attrs.?.id_index);
    try std.testing.expectEqual(@as(u8, 252), data.attrs.?.class_index);
    try std.testing.expectEqualStrings("", data.view(&scope).idValue());
    // Script's growth: 1, 4, 8, ... 256.
    try std.testing.expectEqual(@as(usize, 256), data.attrs.?.capacity());
}

test "without an installed implementation no node has element data or rare data" {
    const override = implementation.overrideForTest(null);
    defer override.restore();
    // Never dereferenced: with no implementation the calls do not reach it.
    var element: runtime.Instance = undefined;
    try std.testing.expect(of(&element) == null);
    try std.testing.expect(rareHolderOf(&element) == null);
    try std.testing.expect(element_rare_data.access(&element) == null);
    try std.testing.expect(element_rare_data.of(&element).block == null);
}
