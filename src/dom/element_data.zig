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
//! Growth (oss review R16): exact on parse and clone - the parser and
//! "clone a single node" reserve room for their attributes first
//! (`dom.element_attributes.reserve`) - and 1 -> 4 -> x2 for script's
//! appends, so a `setAttribute` loop is not quadratic. Servo pre-sizes the
//! same way (f28a39571849), and so do Gecko and Ladybird.
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
pub const AttributeList = struct {
    len: u32,
    /// The capacity: 1 to 128 is that many entries (exact, as parse and
    /// clone reserve), k > 128 is 128 << (k - 128).
    cap_class: u8,
    /// Where the id attribute in no namespace is (see above).
    id_index: u8 = no_index,
    /// Where the class attribute in no namespace is.
    class_index: u8 = no_index,
    _reserved: u8 = 0,

    /// No such attribute.
    pub const no_index: u8 = 0xFF;
    /// The attribute is at position `saturated_index` or later: found by a
    /// scan from there.
    pub const saturated_index: u8 = 0xFE;

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

    fn slots(self: *AttributeList) [*]Entry {
        const base: [*]u8 = @ptrCast(self);
        return @ptrCast(@alignCast(base + @sizeOf(AttributeList)));
    }

    fn items(self: *AttributeList) []Entry {
        return self.slots()[0..self.len];
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
    fn find(self: *AttributeList, tables: Tables, index: u8, comptime static: NameId) ?usize {
        if (index == no_index) return null;
        if (index != saturated_index) return index;
        const from = @min(@as(usize, saturated_index), self.len);
        for (self.items()[from..], from..) |entry, position| {
            if (namesLocal(tables, entry.name, static)) return position;
        }
        return null;
    }

    /// The value of the attribute `index` finds, or "".
    fn valueAt(self: *AttributeList, tables: Tables, index: u8, comptime static: NameId) []const u8 {
        const position = self.find(tables, index, static) orelse return "";
        return tables.value(self.items()[position].value);
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
    /// attributes in its header; null while there are none.
    attrs: ?*AttributeList = null,

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
            for (list.items()) |entry| releaseEntry(scope, entry);
            list.destroy(scope.allocator);
            self.attrs = null;
        }
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
    pub fn reserve(self: *ElementData, allocator: std.mem.Allocator, more: usize) error{OutOfMemory}!void {
        if (more == 0) return;
        const len = self.getAttributeCount();
        const wanted = std.math.add(usize, len, more) catch return error.OutOfMemory;
        if (self.attrs) |list| {
            if (wanted <= list.capacity()) return;
            self.attrs = try list.moved(allocator, try AttributeList.classFor(wanted));
        } else {
            self.attrs = try AttributeList.create(allocator, try AttributeList.classFor(wanted));
        }
    }

    /// Append an attribute to the list, which takes the entry's references
    /// - on success only. Element's "append an attribute" step 1. The list
    /// may MOVE (script's appends grow it 1 -> 4 -> x2).
    pub fn appendAttribute(self: *ElementData, scope: *runtime.BrowserScope, entry: Entry) error{OutOfMemory}!void {
        const list = if (self.attrs) |list| try list.withRoom(scope.allocator) else try AttributeList.create(scope.allocator, 1);
        self.attrs = list;
        const position = list.len;
        list.slots()[position] = entry;
        list.len += 1;
        list.appended(Tables.of(scope), position, entry.name);
    }

    /// Remove the attribute at `index` and hand its entry - its references
    /// - to the caller (`releaseEntry`). The list keeps its order (attribute
    /// order is observable through `attributes` and `getAttributeNames()`),
    /// and goes with its last attribute.
    pub fn takeAttributeAt(self: *ElementData, scope: *runtime.BrowserScope, index: usize) Entry {
        const list = self.attrs.?;
        const items = list.items();
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
    pub fn setValueAt(self: *ElementData, index: usize, value: ValueId) ValueId {
        const slot = &self.attrs.?.items()[index];
        const old = slot.value;
        slot.value = value;
        return old;
    }

    /// Set the name of the attribute at `index` (the same namespace and
    /// local name; "replace" gives it another prefix) to `name`, a reference
    /// the list takes, and hand back the old one for the caller to release -
    /// after moving an Attr node kept for it to the new record
    /// (AttrNodeList.rename).
    pub fn setNameAt(self: *ElementData, index: usize, name: NameId) NameId {
        const slot = &self.attrs.?.items()[index];
        const old = slot.name;
        slot.name = name;
        return old;
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
        return list.valueAt(self.tables(), list.id_index, id_name);
    }

    /// The class attribute's value in no namespace, or "": what the class
    /// selector, classList and getElementsByClassName read. Borrowed, like
    /// `idValue`.
    pub fn classValue(self: View) []const u8 {
        const list = self.data.attrs orelse return "";
        return list.valueAt(self.tables(), list.class_index, class_name);
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
        const names = attribute_names.tableOf(self.scope);
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
        const names = attribute_names.tableOf(self.scope);
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
    const attr = getAttributeByNamespaceAndLocalName(data, namespace, local_name) orelse {
        // Step 2: "If attr is null, then return the empty string."
        return "";
    };
    // Step 3: "Return attr's value."
    return attr.value;
}

/// Whether the element has an attribute in no namespace with this local name
/// - a boolean content attribute's state (HTML 2.3.2).
pub fn hasAttribute(data: View, local_name: []const u8) bool {
    return data.indexOfAttribute(null, local_name) != null;
}

/// `element`'s view made from its data, with its Browser (`ofInstance`: the
/// slab header its Instance sits in - ElementData itself has no route to it,
/// review C2).
fn viewOfElement(data: *const ElementData, element: *runtime.Instance) View {
    return .{ .data = data, .name = data.name, .scope = runtime.BrowserScope.ofInstance(element) };
}

/// An element's rare data (dom.element_rare_data), which Element keeps and
/// reaches through this slot too: one hook per owner, not one per field.
const element_rare_data = @import("element_rare_data.zig");

/// What Element supplies.
pub const Implementation = struct {
    /// `element`'s data, or null when `element` has no Element part.
    of: *const fn (element: *runtime.Instance) ?*ElementData,
    /// `element`'s rare data, or null when it has none (or is no element).
    /// Never makes one.
    rare_of: *const fn (element: *runtime.Instance) ?*element_rare_data.ElementRareData,
    /// `element`'s rare data, made now if it has none. InvalidStateError
    /// for an instance that is no element.
    ensure_rare: *const fn (element: *runtime.Instance) element_rare_data.Error!*element_rare_data.ElementRareData,
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

/// `element`'s rare data, or null when it has none: dom.element_rare_data.of.
pub fn rareDataOf(element: *runtime.Instance) ?*element_rare_data.ElementRareData {
    const impl = implementation.get() orelse return null;
    return impl.rare_of(element);
}

/// `element`'s rare data, made on first use: dom.element_rare_data.ensure.
pub fn ensureRareData(element: *runtime.Instance) element_rare_data.Error!*element_rare_data.ElementRareData {
    const impl = implementation.get() orelse return error.InvalidStateError;
    return impl.ensure_rare(element);
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
    ElementData.releaseEntry(scope, data.takeAttributeAt(scope, index));
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
    try std.testing.expectEqual(@as(usize, 0), attribute_values.tableOf(&scope).?.count());

    // Parse and clone reserve exactly: five attributes, five entries; then
    // a script append doubles.
    try data.reserve(scope.allocator, 5);
    for (names[0..5]) |name| try testAppend(&scope, &data, null, null, name, "v");
    try std.testing.expectEqual(@as(usize, 5), data.attrs.?.capacity());
    try testAppend(&scope, &data, null, null, "f", "v");
    try std.testing.expectEqual(@as(usize, 10), data.attrs.?.capacity());
    // Past 128 entries a class is a power of two.
    try std.testing.expectEqual(@as(usize, 256), AttributeList.capacityOf(try AttributeList.classFor(200)));
    try std.testing.expectEqual(@as(usize, 128), AttributeList.capacityOf(try AttributeList.classFor(128)));
    // One value record serves all six attributes.
    try std.testing.expectEqual(@as(usize, 1), attribute_values.tableOf(&scope).?.count());
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
    try std.testing.expect(rareDataOf(&element) == null);
    try std.testing.expectError(error.InvalidStateError, ensureRareData(&element));
    try std.testing.expect(element_rare_data.of(&element) == null);
}
