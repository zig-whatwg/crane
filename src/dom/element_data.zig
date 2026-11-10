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
//! The attribute list is the engines' layout (lane perf3 D1,
//! tmp/plans/perf3b2-element-data-design.md): OUT OF LINE and exact-size,
//! null for an element with no attributes - 43% of the 3.04 M elements of
//! the perf pages had none and 85% had at most one, where Crane kept a
//! 384-byte array of four inline slots in every element. Blink's
//! ElementData (core/dom/element_data.h) is NULL until an element has an
//! attribute; its UniqueElementData keeps an AttributeVector and its
//! ShareableElementData a trailing `Attribute attribute_array_[0]`, each
//! Attribute a `QualifiedName name_; AtomicString value_;` (16 B, a
//! static_assert). WebKit's ElementData / UniqueElementData /
//! ShareableElementData (Source/WebCore/dom/ElementData.h, Attribute.h) are
//! the same. Here an `Attribute` is a pointer to its qualified name - a
//! static record every element shares for a known name, else one record of
//! its own - and its owned value: 24 B.
//!
//! Reads are DOM's own read algorithms, plain functions over the data: "get
//! an attribute by namespace and local name" and "get an attribute value".
//! Every read hands out an `AttributeEntry` BY VALUE - a view of the
//! attribute's names and value - never a pointer into the list: the list
//! reallocates when an attribute is appended or removed, and a pointer into
//! it held across that (or across any step that can run script and so
//! change attributes: the attribute change steps, custom element reactions,
//! mutation records, an Attr node's value setter) would dangle. Blink hit
//! exactly that (rare data reallocated during a set; the DOM report's
//! reference [7]). So the safety rule is structural: the view's slices
//! point into the name record (static, or freed only with its attribute)
//! and the value's own buffer (freed only when the attribute's value
//! changes or the attribute goes), neither of which moves with the list. A
//! name or value is therefore valid until that attribute next changes or
//! the element is freed; copy what you keep. Writes - "change", "append",
//! "remove" and "replace" an attribute - stay Element's, where "handle
//! attribute changes" queues the mutation record, enqueues the custom
//! element reaction and runs the attribute change steps: callers write
//! through `dom.element_attributes` (`set`, `remove`, `append`, `change`),
//! never through this data, which `of` hands out read-only. The ID and
//! classes are read from the list through two indices its header keeps
//! (`idValue`, `classValue`; lane nd2 N3), which the list's own append and
//! remove re-derive - no step can forget them.
//!
//! The element's qualified name is ONE pointer to a shared record
//! (`name`, dom.element_name; lane nd2 N2), a counted reference to an
//! interned one (batch 1-fix): `rename` and `deinit` keep the count.
//!
//! Spec: https://dom.spec.whatwg.org/#concept-element-attribute
//!
//! lint-impls: hook for Element
const std = @import("std");

const infra = @import("infra");
const runtime = @import("runtime");
const Hook = @import("hook.zig").Hook;
const element_name = @import("element_name.zig");

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

/// An attribute's qualified name: its namespace, namespace prefix and local
/// name (DOM 4.9.2), which an attribute keeps for its whole life ("replace"
/// gives the list a new attribute). A known name is one static record every
/// element points to (html_core's attribute name table, beside its tag
/// names: Blink's and WebKit's static QualifiedNames for the HTML, SVG,
/// MathML, XLink and XML attribute names); any other - data-*, a custom
/// name, a namespaced or prefixed one - is a record of its own attribute's,
/// made by `create` and freed with the attribute.
pub const QualifiedName = struct {
    namespace_uri: ?[]const u8 = null,
    prefix: ?[]const u8 = null,
    local_name: []const u8,
    /// 0 for a static record; for one of an attribute's own, the bytes of
    /// its allocation (the record and its strings), which `destroy` frees.
    owned_bytes: u32 = 0,

    /// Whether this is an attribute's own record (freed with it) rather than
    /// a static one every element shares.
    pub fn isOwned(self: *const QualifiedName) bool {
        return self.owned_bytes != 0;
    }

    /// Whether this name's namespace is `namespace_uri` and its local name
    /// is `local_name` (null matches only null): an attribute's identity in
    /// its element's list.
    pub fn isNamed(self: *const QualifiedName, namespace_uri: ?[]const u8, local_name: []const u8) bool {
        return namespaceIs(self.namespace_uri, namespace_uri) and std.mem.eql(u8, local_name, self.local_name);
    }

    /// Whether this name is exactly `namespace_uri`, `prefix` and
    /// `local_name`.
    pub fn eql(self: *const QualifiedName, namespace_uri: ?[]const u8, prefix: ?[]const u8, local_name: []const u8) bool {
        return self.isNamed(namespace_uri, local_name) and namespaceIs(self.prefix, prefix);
    }

    /// An attribute's qualified name is its local name if its namespace
    /// prefix is null, and otherwise its prefix, ":", and its local name.
    /// Compared in place.
    ///
    /// Spec: https://dom.spec.whatwg.org/#concept-attribute-qualified-name
    pub fn qualifiedNameIs(self: *const QualifiedName, qualified_name: []const u8) bool {
        return qualifiedNameMatches(self.prefix, self.local_name, qualified_name);
    }

    /// A record of an attribute's own for a name no static table holds: ONE
    /// allocation, the record followed by the bytes of its local name, its
    /// prefix and - unless it is one of the six named ones, which stay
    /// static - its namespace.
    pub fn create(allocator: std.mem.Allocator, namespace_uri: ?[]const u8, prefix: ?[]const u8, local_name: []const u8) !*const QualifiedName {
        const static_namespace: ?[]const u8 = if (namespace_uri) |ns| internNamespace(ns) else null;
        const namespace_bytes: usize = if (namespace_uri) |ns| (if (static_namespace == null) ns.len else 0) else 0;
        const prefix_bytes: usize = if (prefix) |p| p.len else 0;
        const total = @sizeOf(QualifiedName) + local_name.len + prefix_bytes + namespace_bytes;
        if (total > std.math.maxInt(u32)) return error.OutOfMemory;
        const memory = try allocator.alignedAlloc(u8, .of(QualifiedName), total);
        var tail: []u8 = memory[@sizeOf(QualifiedName)..];
        const local = copyInto(&tail, local_name);
        const own_prefix: ?[]const u8 = if (prefix) |p| copyInto(&tail, p) else null;
        const own_namespace: ?[]const u8 = if (namespace_uri) |ns| (static_namespace orelse copyInto(&tail, ns)) else null;
        std.debug.assert(tail.len == 0);
        const record: *QualifiedName = @ptrCast(memory.ptr);
        record.* = .{
            .namespace_uri = own_namespace,
            .prefix = own_prefix,
            .local_name = local,
            .owned_bytes = @intCast(total),
        };
        return record;
    }

    /// Free a record `create` made.
    pub fn destroy(self: *const QualifiedName, allocator: std.mem.Allocator) void {
        std.debug.assert(self.isOwned());
        const base: [*]align(@alignOf(QualifiedName)) u8 = @ptrCast(@constCast(self));
        allocator.free(base[0..self.owned_bytes]);
    }

    fn copyInto(tail: *[]u8, bytes: []const u8) []const u8 {
        const out = tail.*[0..bytes.len];
        @memcpy(out, bytes);
        tail.* = tail.*[bytes.len..];
        return out;
    }
};

fn namespaceIs(own: ?[]const u8, wanted: ?[]const u8) bool {
    const w = wanted orelse return own == null;
    const o = own orelse return false;
    return std.mem.eql(u8, o, w);
}

fn qualifiedNameMatches(prefix_or_null: ?[]const u8, local_name: []const u8, qualified_name: []const u8) bool {
    const prefix = prefix_or_null orelse return std.mem.eql(u8, local_name, qualified_name);
    return qualified_name.len == prefix.len + 1 + local_name.len and
        std.mem.startsWith(u8, qualified_name, prefix) and
        qualified_name[prefix.len] == ':' and
        std.mem.endsWith(u8, qualified_name, local_name);
}

/// One attribute as the list stores it: its qualified name and its value,
/// owned by the list (the value always; the name when `name.isOwned()`).
pub const Attribute = struct {
    name: *const QualifiedName,
    value: []const u8,

    /// The view a reader gets.
    pub fn entry(self: Attribute) AttributeEntry {
        return .{
            .namespace_uri = self.name.namespace_uri,
            .prefix = self.name.prefix,
            .local_name = self.name.local_name,
            .value = self.value,
        };
    }
};

/// One attribute of the list as a reader sees it: its namespace, namespace
/// prefix, local name and value (DOM 4.9.2), BORROWED - valid until that
/// attribute next changes or goes, and unaffected by changes to the others.
/// A value, never a pointer into the list (see the file's comment).
pub const AttributeEntry = struct {
    namespace_uri: ?[]const u8,
    prefix: ?[]const u8,
    local_name: []const u8,
    value: []const u8,

    /// Whether this attribute's namespace is `namespace_uri` and its local
    /// name is `local_name` (null matches only null).
    pub fn isNamed(self: *const AttributeEntry, namespace_uri: ?[]const u8, local_name: []const u8) bool {
        return namespaceIs(self.namespace_uri, namespace_uri) and std.mem.eql(u8, local_name, self.local_name);
    }

    /// Spec: https://dom.spec.whatwg.org/#concept-attribute-qualified-name
    pub fn qualifiedNameIs(self: *const AttributeEntry, qualified_name: []const u8) bool {
        return qualifiedNameMatches(self.prefix, self.local_name, qualified_name);
    }
};

/// The out-of-line list: this header, then `cap` Attributes, in ONE
/// allocation. It grows by one slot up to four (85% of elements have at
/// most one attribute and none on the perf pages more than four) and then
/// doubles; the element frees it when its last attribute goes.
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
/// attribute. 8 bytes, as before: the capacity is a one-byte growth class.
pub const AttributeList = struct {
    len: u32,
    /// The capacity's growth class: 1 to 4 is that many slots, k > 4 is
    /// 4 << (k - 4) - exactly the growth policy above (`capacity`).
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

    comptime {
        std.debug.assert(@sizeOf(AttributeList) == 8);
        std.debug.assert(@sizeOf(AttributeList) % @alignOf(Attribute) == 0);
    }

    const Memory = []align(@alignOf(Attribute)) u8;

    fn capacityOf(class: u8) usize {
        return if (class <= 4) class else @as(usize, 4) << @intCast(class - 4);
    }

    /// The slots the list holds.
    pub fn capacity(self: *const AttributeList) usize {
        return capacityOf(self.cap_class);
    }

    fn bytesFor(cap: usize) usize {
        return @sizeOf(AttributeList) + cap * @sizeOf(Attribute);
    }

    fn memory(self: *AttributeList) Memory {
        const base: [*]align(@alignOf(Attribute)) u8 = @ptrCast(@alignCast(self));
        return base[0..bytesFor(self.capacity())];
    }

    fn slots(self: *AttributeList) [*]Attribute {
        const base: [*]align(@alignOf(Attribute)) u8 = @ptrCast(@alignCast(self));
        return @ptrCast(@alignCast(base + @sizeOf(AttributeList)));
    }

    fn items(self: *AttributeList) []Attribute {
        return self.slots()[0..self.len];
    }

    fn create(allocator: std.mem.Allocator) !*AttributeList {
        const bytes = try allocator.alignedAlloc(u8, .of(Attribute), bytesFor(capacityOf(1)));
        const list: *AttributeList = @ptrCast(bytes.ptr);
        list.* = .{ .len = 0, .cap_class = 1 };
        return list;
    }

    fn destroy(self: *AttributeList, allocator: std.mem.Allocator) void {
        allocator.free(self.memory());
    }

    /// The list with room for one more: itself, or a larger copy that
    /// replaces it (MOVED - nothing may hold a pointer into it across this).
    fn withRoom(self: *AttributeList, allocator: std.mem.Allocator) !*AttributeList {
        // The length is 32 bits; past it there is no room to make.
        if (self.len == std.math.maxInt(u32)) return error.OutOfMemory;
        if (self.len < self.capacity()) return self;
        const class = self.cap_class + 1;
        const bytes = try allocator.realloc(self.memory(), bytesFor(capacityOf(class)));
        const list: *AttributeList = @ptrCast(bytes.ptr);
        list.cap_class = class;
        return list;
    }

    /// The index byte for an attribute at `position`.
    fn indexFor(position: usize) u8 {
        return if (position < saturated_index) @intCast(position) else saturated_index;
    }

    /// The position of the attribute in no namespace named `local_name`
    /// that `index` says where to find, or null.
    fn find(self: *AttributeList, index: u8, local_name: []const u8) ?usize {
        if (index == no_index) return null;
        if (index != saturated_index) return index;
        const from = @min(@as(usize, saturated_index), self.len);
        for (self.items()[from..], from..) |attribute, position| {
            if (attribute.name.isNamed(null, local_name)) return position;
        }
        return null;
    }

    /// The value of the attribute `index` finds, or "".
    fn valueAt(self: *AttributeList, index: u8, local_name: []const u8) []const u8 {
        const position = self.find(index, local_name) orelse return "";
        return self.items()[position].value;
    }

    /// The attribute just appended at `position` is the id or class
    /// attribute: its index follows it. There is at most one of each (an
    /// attribute is appended only when absent).
    fn appended(self: *AttributeList, position: usize, name: *const QualifiedName) void {
        if (name.namespace_uri != null) return;
        if (self.id_index == no_index and std.mem.eql(u8, name.local_name, "id")) self.id_index = indexFor(position);
        if (self.class_index == no_index and std.mem.eql(u8, name.local_name, "class")) self.class_index = indexFor(position);
    }

    /// The attribute at `position`, named `name`, was just taken out: the
    /// indices after it move down one, its own goes, and a saturated one is
    /// found again (it may be exact now).
    fn taken(self: *AttributeList, position: usize, name: *const QualifiedName) void {
        self.id_index = self.indexAfterTake(self.id_index, position, name, "id");
        self.class_index = self.indexAfterTake(self.class_index, position, name, "class");
    }

    fn indexAfterTake(self: *AttributeList, index: u8, position: usize, name: *const QualifiedName, local_name: []const u8) u8 {
        if (index == no_index) return no_index;
        if (name.isNamed(null, local_name)) return no_index;
        if (index == saturated_index) {
            // It was at 254 or later, so it is at 253 or later now.
            const from = @min(@as(usize, saturated_index - 1), self.len);
            for (self.items()[from..], from..) |attribute, at| {
                if (attribute.name.isNamed(null, local_name)) return indexFor(at);
            }
            return no_index;
        }
        return if (position < index) index - 1 else index;
    }
};

/// The Attr nodes made for an element's attributes, each by its attribute's
/// name record (an attribute's identity: one per namespace and local name),
/// made when script asks for the first one. Blink keeps an element's Attr
/// nodes apart from its attributes too (its rare data's kAttrNodeList,
/// looked up by QualifiedName); Crane keeps this list in the element's
/// ElementRareData (dom.element_rare_data, lane perf3 D2).
pub const AttrNodeList = struct {
    entries: std.ArrayList(Entry) = .empty,

    pub const Entry = struct {
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
    /// (dom.element_name; lane nd2 N2: Blink's `Element::tag_name_`). It
    /// was a 32-byte namespace and a 24-byte local name here and a 32-byte
    /// prefix in rare data. An interned record is a COUNTED reference this
    /// data holds (batch 1-fix): written only by Element, through `rename`,
    /// and let go by `deinit`.
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

    /// Let the name record go and free every attribute. `scope` is the
    /// element's Browser's: its allocator made the list, its table counts
    /// the name. An attribute's Attr node is its owner's to let go first
    /// (AttrNodeList.take): this frees the list only.
    pub fn deinit(self: *ElementData, scope: *runtime.BrowserScope) void {
        const allocator = scope.allocator;
        self.rename(scope, &element_name.unnamed);
        if (self.attrs) |list| {
            for (list.items()) |attribute| freeAttribute(allocator, attribute);
            list.destroy(allocator);
            self.attrs = null;
        }
    }

    /// Free what an attribute owns: its value, and its name if it is its own.
    pub fn freeAttribute(allocator: std.mem.Allocator, attribute: Attribute) void {
        if (attribute.name.isOwned()) attribute.name.destroy(allocator);
        allocator.free(attribute.value);
    }

    /// The element's namespace, borrowed; null for none.
    pub fn namespaceSlice(self: *const ElementData) ?[]const u8 {
        return self.name.namespace_uri;
    }

    /// The element's local name, borrowed.
    pub fn localName(self: *const ElementData) []const u8 {
        return self.name.local_name;
    }

    /// The element's ID (DOM 4.9 "set / unset element's ID": its id
    /// attribute's value in no namespace; empty is no ID), or "". Read from
    /// the list through the header's index (lane nd2 N3; a 24-byte view on
    /// every element before), BORROWED: the value's own buffer, which does
    /// not move with the list - valid until that attribute next changes.
    /// Blink's Element::GetIdAttribute reads the attribute the same way.
    pub fn idValue(self: *const ElementData) []const u8 {
        const list = self.attrs orelse return "";
        return list.valueAt(list.id_index, "id");
    }

    /// The class attribute's value in no namespace, or "": what the class
    /// selector, classList and getElementsByClassName read. Borrowed, like
    /// `idValue`.
    pub fn classValue(self: *const ElementData) []const u8 {
        const list = self.attrs orelse return "";
        return list.valueAt(list.class_index, "class");
    }

    /// The number of attributes in the list.
    pub fn getAttributeCount(self: *const ElementData) usize {
        return if (self.attrs) |list| list.len else 0;
    }

    /// The stored attributes, for this file's loops. Read afresh after
    /// anything that can change the list.
    fn stored(self: *const ElementData) []const Attribute {
        const list = self.attrs orelse return &.{};
        return list.items();
    }

    /// The attributes in list order, each a view by value. The iterator
    /// keeps an index and reads the list afresh at each step.
    pub const AttributeIterator = struct {
        data: *const ElementData,
        index: usize = 0,

        pub fn next(self: *AttributeIterator) ?AttributeEntry {
            const items = self.data.stored();
            if (self.index >= items.len) return null;
            const item = items[self.index];
            self.index += 1;
            return item.entry();
        }
    };

    pub fn attributeIterator(self: *const ElementData) AttributeIterator {
        return .{ .data = self };
    }

    /// The attribute whose namespace is `namespace_uri` and local name is
    /// `local_name`; there is at most one.
    pub fn findAttribute(self: *const ElementData, namespace_uri: ?[]const u8, local_name: []const u8) ?AttributeEntry {
        const index = self.indexOfAttribute(namespace_uri, local_name) orelse return null;
        return self.stored()[index].entry();
    }

    /// The attribute at `index` in list order, or null past the end.
    pub fn attributeAt(self: *const ElementData, index: usize) ?AttributeEntry {
        const items = self.stored();
        if (index >= items.len) return null;
        return items[index].entry();
    }

    /// Index of the attribute whose namespace is `namespace_uri` and local
    /// name is `local_name`. There is at most one.
    pub fn indexOfAttribute(self: *const ElementData, namespace_uri: ?[]const u8, local_name: []const u8) ?usize {
        for (self.stored(), 0..) |attribute, index| {
            if (attribute.name.isNamed(namespace_uri, local_name)) return index;
        }
        return null;
    }

    /// Index of the FIRST attribute whose qualified name is `qualified_name`.
    /// Two attributes in different namespaces can share one.
    pub fn indexOfQualifiedName(self: *const ElementData, qualified_name: []const u8) ?usize {
        for (self.stored(), 0..) |attribute, index| {
            if (attribute.name.qualifiedNameIs(qualified_name)) return index;
        }
        return null;
    }

    // ------------------------------------------------------------------
    // Element's writes. Each takes the index (or name) afresh: no caller
    // holds a pointer into the list across one.
    // ------------------------------------------------------------------

    /// The attribute at `index` as stored (its name record and value), or
    /// null past the end - Element's, for its writes.
    pub fn storedAt(self: *const ElementData, index: usize) ?Attribute {
        const items = self.stored();
        if (index >= items.len) return null;
        return items[index];
    }

    /// Append an attribute to the list; the list takes its value and, if it
    /// is its own, its name - on success only. Element's "append an
    /// attribute" step 1. The list may MOVE.
    pub fn appendAttribute(self: *ElementData, allocator: std.mem.Allocator, attribute: Attribute) !void {
        const list = if (self.attrs) |list| try list.withRoom(allocator) else try AttributeList.create(allocator);
        self.attrs = list;
        const position = list.len;
        list.slots()[position] = attribute;
        list.len += 1;
        list.appended(position, attribute.name);
    }

    /// Remove the attribute at `index` and hand it - value and name - to the
    /// caller (`freeAttribute`). The list keeps its order (attribute order is
    /// observable through `attributes` and `getAttributeNames()`), and goes
    /// with its last attribute.
    pub fn takeAttributeAt(self: *ElementData, allocator: std.mem.Allocator, index: usize) Attribute {
        const list = self.attrs.?;
        const items = list.items();
        const attribute = items[index];
        std.mem.copyForwards(Attribute, items[index .. items.len - 1], items[index + 1 ..]);
        list.len -= 1;
        if (list.len == 0) {
            list.destroy(allocator);
            self.attrs = null;
            return attribute;
        }
        list.taken(index, attribute.name);
        return attribute;
    }

    /// Set the value of the attribute at `index`, which takes `value`, and
    /// return its old one for the caller to free once nothing reads it.
    pub fn setValueAt(self: *ElementData, index: usize, value: []const u8) []const u8 {
        const slot = &self.attrs.?.items()[index];
        const old = slot.value;
        slot.value = value;
        return old;
    }

    /// Set the name record of the attribute at `index` (the same namespace
    /// and local name; "replace" gives it another prefix), and return its old
    /// one for the caller to free (`QualifiedName.destroy`, if owned) - after
    /// moving an Attr node kept for it to the new record (AttrNodeList.rename).
    pub fn setNameAt(self: *ElementData, index: usize, name: *const QualifiedName) *const QualifiedName {
        const slot = &self.attrs.?.items()[index];
        const old = slot.name;
        std.debug.assert(name.isNamed(old.namespace_uri, old.local_name));
        slot.name = name;
        return old;
    }
};

/// DOM "get an attribute by namespace and local name": the attribute in the
/// element's attribute list whose namespace is `namespace` and local name is
/// `local_name`, or null. Borrowed.
///
/// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-get-by-namespace
pub fn getAttributeByNamespaceAndLocalName(data: *const ElementData, namespace: ?[]const u8, local_name: []const u8) ?AttributeEntry {
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
pub fn getAttributeValue(data: *const ElementData, local_name: []const u8, namespace: ?[]const u8) []const u8 {
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
pub fn hasAttribute(data: *const ElementData, local_name: []const u8) bool {
    return data.indexOfAttribute(null, local_name) != null;
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

/// `element`'s data, read-only: write through `dom.element_attributes`. Null
/// when `element` is no element (or Element installed nothing).
pub fn of(element: *runtime.Instance) ?*const ElementData {
    const impl = implementation.get() orelse return null;
    return impl.of(element);
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

fn testAttribute(allocator: std.mem.Allocator, namespace: ?[]const u8, prefix: ?[]const u8, local_name: []const u8, value: []const u8) !Attribute {
    const name = try QualifiedName.create(allocator, namespace, prefix, local_name);
    errdefer name.destroy(allocator);
    return .{ .name = name, .value = try allocator.dupe(u8, value) };
}

test "the list keeps its order as it grows past four and shrinks to nothing" {
    const allocator = std.testing.allocator;
    var scope = runtime.BrowserScope.init(allocator);
    defer scope.deinit();
    var data = ElementData.init();
    defer data.deinit(&scope);

    try std.testing.expect(data.attrs == null);
    const names = [_][]const u8{ "a", "b", "c", "d", "e", "f" };
    for (names) |name| try data.appendAttribute(allocator, try testAttribute(allocator, null, null, name, name));
    try std.testing.expectEqual(@as(usize, 6), data.getAttributeCount());
    try std.testing.expectEqual(@as(usize, 8), data.attrs.?.capacity());
    for (names, 0..) |name, i| try std.testing.expectEqualStrings(name, data.attributeAt(i).?.local_name);
    try std.testing.expect(data.attributeAt(6) == null);

    // Taking one keeps the others' order.
    ElementData.freeAttribute(allocator, data.takeAttributeAt(allocator, 1));
    const rest = [_][]const u8{ "a", "c", "d", "e", "f" };
    var it = data.attributeIterator();
    for (rest) |name| try std.testing.expectEqualStrings(name, it.next().?.local_name);
    try std.testing.expect(it.next() == null);
    try std.testing.expectEqual(@as(usize, 3), data.indexOfAttribute(null, "e").?);

    // The list goes with its last attribute.
    while (data.getAttributeCount() > 0) ElementData.freeAttribute(allocator, data.takeAttributeAt(allocator, 0));
    try std.testing.expect(data.attrs == null);
}

test "attributes are named by namespace and local name, and found by qualified name" {
    const allocator = std.testing.allocator;
    var scope = runtime.BrowserScope.init(allocator);
    defer scope.deinit();
    var data = ElementData.init();
    defer data.deinit(&scope);

    try data.appendAttribute(allocator, try testAttribute(allocator, "urn:x", "x", "title", "namespaced"));
    const plain_name: QualifiedName = .{ .local_name = "title" };
    try data.appendAttribute(allocator, .{ .name = &plain_name, .value = try allocator.dupe(u8, "plain") });

    // By namespace and local name: one each; "" is null for the algorithm.
    try std.testing.expectEqualStrings("plain", getAttributeValue(&data, "title", null));
    try std.testing.expectEqualStrings("plain", getAttributeValue(&data, "title", ""));
    try std.testing.expectEqualStrings("namespaced", getAttributeValue(&data, "title", "urn:x"));
    try std.testing.expectEqualStrings("", getAttributeValue(&data, "title", "urn:y"));
    try std.testing.expect(hasAttribute(&data, "title"));
    try std.testing.expect(!hasAttribute(&data, "lang"));

    // By qualified name: "x:title" is the namespaced one, and "title" the
    // first whose qualified name it is - the plain one, the namespaced one
    // having a prefix.
    try std.testing.expectEqual(@as(usize, 0), data.indexOfQualifiedName("x:title").?);
    try std.testing.expectEqual(@as(usize, 1), data.indexOfQualifiedName("title").?);
    try std.testing.expect(data.indexOfQualifiedName("y:title") == null);
}

test "an attribute's own name is one allocation; a named namespace stays static" {
    const allocator = std.testing.allocator;
    const xlink = try QualifiedName.create(allocator, infra.namespaces.XLINK_NAMESPACE, "xlink", "href");
    defer xlink.destroy(allocator);
    try std.testing.expect(xlink.isOwned());
    try std.testing.expect(xlink.namespace_uri.?.ptr == infra.namespaces.XLINK_NAMESPACE.ptr);
    try std.testing.expect(xlink.eql(infra.namespaces.XLINK_NAMESPACE, "xlink", "href"));
    try std.testing.expect(xlink.qualifiedNameIs("xlink:href"));
    try std.testing.expectEqual(@as(u32, @sizeOf(QualifiedName) + "href".len + "xlink".len), xlink.owned_bytes);

    const other = try QualifiedName.create(allocator, "urn:other", null, "data-x");
    defer other.destroy(allocator);
    try std.testing.expectEqualStrings("urn:other", other.namespace_uri.?);
    try std.testing.expect(other.prefix == null);
    try std.testing.expectEqual(@as(u32, @sizeOf(QualifiedName) + "data-x".len + "urn:other".len), other.owned_bytes);
}

test "views survive the list's reallocation; Attr node links follow a renamed attribute" {
    const allocator = std.testing.allocator;
    var scope = runtime.BrowserScope.init(allocator);
    defer scope.deinit();
    var data = ElementData.init();
    defer data.deinit(&scope);

    try data.appendAttribute(allocator, try testAttribute(allocator, null, null, "id", "main"));
    const first = data.attributeAt(0).?;
    var i: usize = 0;
    while (i < 20) : (i += 1) {
        var buffer: [16]u8 = undefined;
        const name = try std.fmt.bufPrint(&buffer, "a{d}", .{i});
        try data.appendAttribute(allocator, try testAttribute(allocator, null, null, name, name));
    }
    // The view taken before and the ID read the value's own buffer.
    try std.testing.expectEqualStrings("main", first.value);
    try std.testing.expectEqualStrings("main", data.idValue());

    // An Attr node link is keyed by the name record and follows "replace".
    var nodes: AttrNodeList = .{};
    defer nodes.deinit(allocator);
    const name0 = data.storedAt(0).?.name;
    var fake: runtime.Instance = undefined;
    const link: AttrNodeLink = .{ .instance = &fake, .generation = 7 };
    try std.testing.expect((try nodes.put(allocator, name0, link)) == null);
    const renamed = try QualifiedName.create(allocator, null, null, "id");
    const old = data.setNameAt(0, renamed);
    nodes.rename(old, renamed);
    old.destroy(allocator);
    try std.testing.expect(nodes.get(renamed).?.generation == 7);
    try std.testing.expect(nodes.get(old) == null);
    try std.testing.expect(nodes.take(allocator, renamed) != null);
    try std.testing.expectEqual(@as(usize, 0), nodes.entries.capacity);
}

test "the header's indices follow appends and removals, saturate past 253 and stay exact below it" {
    const allocator = std.testing.allocator;
    var scope = runtime.BrowserScope.init(allocator);
    defer scope.deinit();
    var data = ElementData.init();
    defer data.deinit(&scope);

    try std.testing.expectEqualStrings("", data.idValue());
    // A namespaced id is not the element's.
    try data.appendAttribute(allocator, try testAttribute(allocator, "urn:x", "p", "id", "ns"));
    try std.testing.expectEqual(AttributeList.no_index, data.attrs.?.id_index);
    var i: usize = 0;
    while (i < 252) : (i += 1) {
        var buffer: [16]u8 = undefined;
        const name = try std.fmt.bufPrint(&buffer, "a{d}", .{i});
        try data.appendAttribute(allocator, try testAttribute(allocator, null, null, name, ""));
    }
    // Position 253: the last exact index. Position 254: saturated.
    try data.appendAttribute(allocator, try testAttribute(allocator, null, null, "id", "i"));
    try data.appendAttribute(allocator, try testAttribute(allocator, null, null, "class", "c"));
    try std.testing.expectEqual(@as(u8, 253), data.attrs.?.id_index);
    try std.testing.expectEqual(AttributeList.saturated_index, data.attrs.?.class_index);
    try std.testing.expectEqualStrings("i", data.idValue());
    try std.testing.expectEqualStrings("c", data.classValue());
    // A removal before both: the class comes down to an exact 253.
    ElementData.freeAttribute(allocator, data.takeAttributeAt(allocator, 0));
    try std.testing.expectEqual(@as(u8, 252), data.attrs.?.id_index);
    try std.testing.expectEqual(@as(u8, 253), data.attrs.?.class_index);
    try std.testing.expectEqualStrings("c", data.classValue());
    // The id goes; the class moves down.
    ElementData.freeAttribute(allocator, data.takeAttributeAt(allocator, 252));
    try std.testing.expectEqual(AttributeList.no_index, data.attrs.?.id_index);
    try std.testing.expectEqual(@as(u8, 252), data.attrs.?.class_index);
    try std.testing.expectEqualStrings("", data.idValue());
    // The capacity class grew as the old policy did: 1, 2, 3, 4, 8, ...
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
