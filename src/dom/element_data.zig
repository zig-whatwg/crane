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
//! WebKit makes the same split: Source/WebCore/dom/ElementData.h holds the
//! attribute storage (`findAttributeByName`, `attributeAt`), the ID for
//! style resolution and the class names, owned by its Element.
//!
//! Reads are DOM's own read algorithms, plain functions over the data:
//! "get an attribute by namespace and local name" and "get an attribute
//! value". They BORROW: a name or value is valid until the attribute next
//! changes or the element is freed; copy what you keep. Writes - "change",
//! "append", "remove" and "replace" an attribute - stay Element's, where
//! "handle attribute changes" queues the mutation record, enqueues the
//! custom element reaction and runs the attribute change steps that keep
//! `id` and `class_name` in step: callers write through
//! `dom.element_attributes` (`set`, `remove`, `append`, `change`), never
//! through this data, which `of` hands out read-only.
//!
//! Spec: https://dom.spec.whatwg.org/#concept-element-attribute
//!
//! lint-impls: hook for Element
const std = @import("std");
const process_start = @import("process_start.zig");

const runtime = @import("runtime");

/// Attributes kept in the element's own block before the list spills to the
/// heap: most elements have 0-3.
pub const INLINE_ATTR_CAPACITY: usize = 4;

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

/// One attribute of the list: its namespace, namespace prefix, local name and
/// value (DOM 4.9.2), each owned by the list's allocator.
pub const AttributeEntry = struct {
    namespace_uri: ?[]const u8,
    prefix: ?[]const u8,
    local_name: []const u8,
    value: []const u8,

    /// The Attr node made for this attribute, once script asked for one.
    /// Element keeps it (its wrapper traces the node: an edge, not a root),
    /// so it stays the same node - identity, expandos and all - while the
    /// attribute is on the element. Blink traces the same edge (Element's
    /// AttrNodeList).
    attr_node: ?AttrNodeLink = null,

    /// Whether this attribute's namespace is `namespace_uri` and its local
    /// name is `local_name` (null matches only null).
    pub fn isNamed(self: *const AttributeEntry, namespace_uri: ?[]const u8, local_name: []const u8) bool {
        const ns_match = if (namespace_uri) |ns|
            (if (self.namespace_uri) |own| std.mem.eql(u8, ns, own) else false)
        else
            self.namespace_uri == null;
        return ns_match and std.mem.eql(u8, local_name, self.local_name);
    }

    /// An attribute's qualified name is its local name if its namespace
    /// prefix is null, and otherwise its prefix, ":", and its local name.
    /// Compared in place.
    ///
    /// Spec: https://dom.spec.whatwg.org/#concept-attribute-qualified-name
    pub fn qualifiedNameIs(self: *const AttributeEntry, qualified_name: []const u8) bool {
        const prefix = self.prefix orelse return std.mem.eql(u8, self.local_name, qualified_name);
        return qualified_name.len == prefix.len + 1 + self.local_name.len and
            std.mem.startsWith(u8, qualified_name, prefix) and
            qualified_name[prefix.len] == ':' and
            std.mem.endsWith(u8, qualified_name, self.local_name);
    }
};

/// An element's attribute list, ID, classes and qualified name.
pub const ElementData = struct {
    allocator: std.mem.Allocator,

    /// The element's namespace (DOM 4.9); null for none.
    namespace_uri: ?runtime.DOMString = null,
    /// The element's namespace prefix; null for none.
    prefix: ?runtime.DOMString = null,
    /// The element's local name, fixed by "create an element".
    local_name: runtime.DOMString,

    /// The element's ID: its id attribute's value, or empty when it has none
    /// ("set / unset element's ID", DOM 4.9's attribute change steps).
    id: runtime.DOMString,
    /// The class attribute's value, or empty when it has none: what the
    /// class selector, classList and getElementsByClassName read.
    class_name: runtime.DOMString,

    /// The first INLINE_ATTR_CAPACITY attributes, in list order.
    inline_attrs: [INLINE_ATTR_CAPACITY]?AttributeEntry = .{null} ** INLINE_ATTR_CAPACITY,
    /// How many of `inline_attrs` are in use (0-4).
    inline_attr_count: u8 = 0,
    /// The attributes after the inline ones, in list order; null until needed.
    heap_attrs: ?std.ArrayList(AttributeEntry) = null,

    pub fn init(allocator: std.mem.Allocator) ElementData {
        return .{
            .allocator = allocator,
            .local_name = runtime.DOMString.initEmpty(),
            .id = runtime.DOMString.initEmpty(),
            .class_name = runtime.DOMString.initEmpty(),
        };
    }

    /// Free the names, the caches and every attribute. An attribute's Attr
    /// node is its owner's to let go first: this frees the strings only.
    pub fn deinit(self: *ElementData) void {
        if (self.namespace_uri) |*ns| ns.deinit(self.allocator);
        if (self.prefix) |*p| p.deinit(self.allocator);
        self.local_name.deinit(self.allocator);
        self.id.deinit(self.allocator);
        self.class_name.deinit(self.allocator);
        for (self.inline_attrs[0..self.inline_attr_count]) |maybe_entry| {
            if (maybe_entry) |entry| freeAttributeEntry(self.allocator, entry);
        }
        if (self.heap_attrs) |*heap| {
            for (heap.items) |entry| freeAttributeEntry(self.allocator, entry);
            heap.deinit(self.allocator);
        }
        self.inline_attr_count = 0;
        self.heap_attrs = null;
    }

    /// Free an attribute entry's strings.
    pub fn freeAttributeEntry(allocator: std.mem.Allocator, entry: AttributeEntry) void {
        if (entry.namespace_uri) |ns| allocator.free(ns);
        if (entry.prefix) |p| allocator.free(p);
        allocator.free(entry.local_name);
        allocator.free(entry.value);
    }

    /// The element's namespace, borrowed; null for none.
    pub fn namespaceSlice(self: *const ElementData) ?[]const u8 {
        return if (self.namespace_uri) |ns| ns.asSlice() else null;
    }

    /// The number of attributes in the list.
    pub fn getAttributeCount(self: *const ElementData) usize {
        const heap_count: usize = if (self.heap_attrs) |heap| heap.items.len else 0;
        return self.inline_attr_count + heap_count;
    }

    /// The attributes in list order: inline first, then the heap's.
    pub const AttributeIterator = struct {
        data: *const ElementData,
        inline_index: usize = 0,
        heap_index: usize = 0,

        pub fn next(self: *AttributeIterator) ?*const AttributeEntry {
            while (self.inline_index < self.data.inline_attr_count) {
                const idx = self.inline_index;
                self.inline_index += 1;
                if (self.data.inline_attrs[idx]) |*entry| return entry;
            }
            if (self.data.heap_attrs) |heap| {
                if (self.heap_index < heap.items.len) {
                    const idx = self.heap_index;
                    self.heap_index += 1;
                    return &heap.items[idx];
                }
            }
            return null;
        }
    };

    pub fn attributeIterator(self: *const ElementData) AttributeIterator {
        return .{ .data = self };
    }

    /// Append an attribute to the list (inline while there is room). The
    /// list takes the entry's strings. Element's "append an attribute" step 1.
    pub fn addAttribute(self: *ElementData, entry: AttributeEntry) !void {
        if (self.inline_attr_count < INLINE_ATTR_CAPACITY) {
            self.inline_attrs[self.inline_attr_count] = entry;
            self.inline_attr_count += 1;
            return;
        }
        if (self.heap_attrs == null) self.heap_attrs = std.ArrayList(AttributeEntry).empty;
        try self.heap_attrs.?.append(self.allocator, entry);
    }

    /// The attribute whose namespace is `namespace_uri` and local name is
    /// `local_name`; there is at most one.
    pub fn findAttribute(self: *const ElementData, namespace_uri: ?[]const u8, local_name: []const u8) ?*const AttributeEntry {
        for (self.inline_attrs[0..self.inline_attr_count]) |*maybe_entry| {
            if (maybe_entry.*) |*entry| {
                if (entry.isNamed(namespace_uri, local_name)) return entry;
            }
        }
        if (self.heap_attrs) |heap| {
            for (heap.items) |*entry| {
                if (entry.isNamed(namespace_uri, local_name)) return entry;
            }
        }
        return null;
    }

    /// `findAttribute`, for Element's writes.
    pub fn findAttributeMut(self: *ElementData, namespace_uri: ?[]const u8, local_name: []const u8) ?*AttributeEntry {
        for (self.inline_attrs[0..self.inline_attr_count]) |*maybe_entry| {
            if (maybe_entry.*) |*entry| {
                if (entry.isNamed(namespace_uri, local_name)) return entry;
            }
        }
        if (self.heap_attrs) |*heap| {
            for (heap.items) |*entry| {
                if (entry.isNamed(namespace_uri, local_name)) return entry;
            }
        }
        return null;
    }

    /// The attribute at `index` in list order, or null past the end.
    pub fn attributeAt(self: *const ElementData, index: usize) ?*const AttributeEntry {
        if (index < self.inline_attr_count) {
            if (self.inline_attrs[index]) |*entry| return entry;
            return null;
        }
        const heap = if (self.heap_attrs) |*h| h else return null;
        const heap_index = index - self.inline_attr_count;
        if (heap_index >= heap.items.len) return null;
        return &heap.items[heap_index];
    }

    /// `attributeAt`, for Element's writes.
    pub fn attributeAtMut(self: *ElementData, index: usize) ?*AttributeEntry {
        if (index < self.inline_attr_count) {
            if (self.inline_attrs[index]) |*entry| return entry;
            return null;
        }
        const heap = if (self.heap_attrs) |*h| h else return null;
        const heap_index = index - self.inline_attr_count;
        if (heap_index >= heap.items.len) return null;
        return &heap.items[heap_index];
    }

    /// Index of the attribute whose namespace is `namespace_uri` and local
    /// name is `local_name`. There is at most one.
    pub fn indexOfAttribute(self: *const ElementData, namespace_uri: ?[]const u8, local_name: []const u8) ?usize {
        var it = self.attributeIterator();
        var index: usize = 0;
        while (it.next()) |entry| : (index += 1) {
            if (entry.isNamed(namespace_uri, local_name)) return index;
        }
        return null;
    }

    /// Index of the FIRST attribute whose qualified name is `qualified_name`.
    /// Two attributes in different namespaces can share one.
    pub fn indexOfQualifiedName(self: *const ElementData, qualified_name: []const u8) ?usize {
        var it = self.attributeIterator();
        var index: usize = 0;
        while (it.next()) |entry| : (index += 1) {
            if (entry.qualifiedNameIs(qualified_name)) return index;
        }
        return null;
    }

    /// Remove the attribute at `index` and hand its entry, strings and all,
    /// to the caller. The list keeps its order: attribute order is observable
    /// through `attributes` and `getAttributeNames()`.
    pub fn takeAttributeAt(self: *ElementData, index: usize) AttributeEntry {
        if (index < self.inline_attr_count) {
            const entry = self.inline_attrs[index].?;
            var j = index;
            while (j + 1 < self.inline_attr_count) : (j += 1) {
                self.inline_attrs[j] = self.inline_attrs[j + 1];
            }
            self.inline_attr_count -= 1;
            self.inline_attrs[self.inline_attr_count] = null;

            // The first heap attribute follows the last inline one, so it is
            // the one that moves into the freed inline slot.
            if (self.heap_attrs) |*heap| {
                if (heap.items.len > 0) {
                    self.inline_attrs[self.inline_attr_count] = heap.orderedRemove(0);
                    self.inline_attr_count += 1;
                }
            }
            return entry;
        }
        return self.heap_attrs.?.orderedRemove(index - self.inline_attr_count);
    }
};

/// DOM "get an attribute by namespace and local name": the attribute in the
/// element's attribute list whose namespace is `namespace` and local name is
/// `local_name`, or null. Borrowed.
///
/// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-get-by-namespace
pub fn getAttributeByNamespaceAndLocalName(data: *const ElementData, namespace: ?[]const u8, local_name: []const u8) ?*const AttributeEntry {
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
    return data.findAttribute(null, local_name) != null;
}

/// What Element supplies.
pub const Implementation = struct {
    /// `element`'s data, or null when `element` has no Element part.
    of: *const fn (element: *runtime.Instance) ?*ElementData,
};

// process-wide: an immutable function pointer Element installs once at process start (crane.Process); it reads only the element it is given, so one serves every Browser and thread
var implementation: ?Implementation = null;

/// Called by Element's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// `element`'s data, read-only: write through `dom.element_attributes`. Null
/// when `element` is no element (or Element installed nothing).
pub fn of(element: *runtime.Instance) ?*const ElementData {
    const impl = implementation orelse return null;
    return impl.of(element);
}

// ============================================================================
// Tests
// ============================================================================

fn testEntry(allocator: std.mem.Allocator, namespace: ?[]const u8, prefix: ?[]const u8, local_name: []const u8, value: []const u8) !AttributeEntry {
    const ns = if (namespace) |n| try allocator.dupe(u8, n) else null;
    errdefer if (ns) |n| allocator.free(n);
    const p = if (prefix) |text| try allocator.dupe(u8, text) else null;
    errdefer if (p) |text| allocator.free(text);
    const name = try allocator.dupe(u8, local_name);
    errdefer allocator.free(name);
    return .{ .namespace_uri = ns, .prefix = p, .local_name = name, .value = try allocator.dupe(u8, value) };
}

test "the list keeps its order across the inline slots and the heap" {
    const allocator = std.testing.allocator;
    var data = ElementData.init(allocator);
    defer data.deinit();

    const names = [_][]const u8{ "a", "b", "c", "d", "e", "f" };
    for (names) |name| try data.addAttribute(try testEntry(allocator, null, null, name, name));
    try std.testing.expectEqual(@as(usize, 6), data.getAttributeCount());
    try std.testing.expectEqual(@as(u8, INLINE_ATTR_CAPACITY), data.inline_attr_count);
    for (names, 0..) |name, i| try std.testing.expectEqualStrings(name, data.attributeAt(i).?.local_name);
    try std.testing.expect(data.attributeAt(6) == null);

    // Taking an inline attribute moves the first heap one into the inline
    // slots: the order is unchanged.
    ElementData.freeAttributeEntry(allocator, data.takeAttributeAt(1));
    const rest = [_][]const u8{ "a", "c", "d", "e", "f" };
    var it = data.attributeIterator();
    for (rest) |name| try std.testing.expectEqualStrings(name, it.next().?.local_name);
    try std.testing.expect(it.next() == null);
    try std.testing.expectEqual(@as(usize, 3), data.indexOfAttribute(null, "e").?);
}

test "attributes are named by namespace and local name, and found by qualified name" {
    const allocator = std.testing.allocator;
    var data = ElementData.init(allocator);
    defer data.deinit();

    try data.addAttribute(try testEntry(allocator, "urn:x", "x", "title", "namespaced"));
    try data.addAttribute(try testEntry(allocator, null, null, "title", "plain"));

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

test "without an installed implementation no node has element data" {
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with no implementation the call does not reach it.
    var element: runtime.Instance = undefined;
    try std.testing.expect(of(&element) == null);
}
