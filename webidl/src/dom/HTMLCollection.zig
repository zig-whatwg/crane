//! HTMLCollection interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-htmlcollection

const std = @import("std");
const webidl = @import("webidl");
const infra = @import("infra");

const Allocator = std.mem.Allocator;
const Element = @import("element").Element;
const Node = @import("node").Node;

pub const FilterFn = *const fn (*Element, *const anyopaque) bool;

/// HTMLCollection is a collection of elements.
///
/// This is a live collection - it automatically updates when the DOM changes.
/// WebIDL Definition:
/// ```
/// interface HTMLCollection {
///   readonly attribute unsigned long length;
///   getter Element? item(unsigned long index);
///   getter Element? namedItem(DOMString name);
/// };
/// ```
pub const HTMLCollection = webidl.interface(struct {
    allocator: Allocator,

    /// The elements in this collection (cached)
    elements: infra.List(*Element),

    /// Root node for live traversal
    root: ?*Node = null,

    /// Filter function for live collection
    filter_fn: ?FilterFn = null,
    filter_context: ?*const anyopaque = null,

    pub fn init(allocator: Allocator) !HTMLCollection {
        return .{
            .allocator = allocator,
            .elements = infra.List(*Element).init(allocator),
            .root = null,
            .filter_fn = null,
            .filter_context = null,
        };
    }

    pub fn initWithFilter(allocator: Allocator, root: *Node, filter_fn: FilterFn, filter_context: *const anyopaque) !HTMLCollection {
        var coll = HTMLCollection{
            .allocator = allocator,
            .elements = infra.List(*Element).init(allocator),
            .root = root,
            .filter_fn = filter_fn,
            .filter_context = filter_context,
        };
        try coll.rebuild();
        return coll;
    }

    fn rebuild(self: *HTMLCollection) !void {
        if (self.root == null or self.filter_fn == null) return;
        self.elements.clearRetainingCapacity();
        try self.collectElements(self.root.?);
    }

    fn collectElements(self: *HTMLCollection, node: *Node) !void {
        for (node.child_nodes.toSlice()) |child| {
            if (child.node_type == Node.ELEMENT_NODE) {
                const element: *Element = @ptrCast(child);
                if (self.filter_fn.?(element, self.filter_context.?)) {
                    try self.elements.append(element);
                }
                try self.collectElements(child);
            }
        }
    }

    pub fn deinit(self: *HTMLCollection) void {
        self.elements.deinit();
    }

    /// DOM §4.3.5 - HTMLCollection.length
    /// Returns the number of elements in the collection.
    pub fn get_length(self: *const HTMLCollection) u32 {
        return @intCast(self.elements.toSlice().len);
    }

    /// DOM §4.3.5 - HTMLCollection.item(index)
    /// Returns the element at the given index, or null if out of bounds.
    /// The elements are sorted in tree order.
    pub fn call_item(self: *const HTMLCollection, index: u32) ?*Element {
        if (index >= self.elements.toSlice().len) {
            return null;
        }
        return self.elements.toSlice()[index];
    }

    /// DOM §4.3.5 - HTMLCollection.namedItem(name)
    /// Returns the first element with ID or name attribute matching the given name.
    /// Returns null if no such element exists.
    pub fn call_namedItem(self: *const HTMLCollection, name: []const u8) ?*Element {
        for (self.elements.toSlice()) |element| {
            // Check if element's id matches
            const id = element.get_id();
            if (std.mem.eql(u8, id, name)) {
                return element;
            }

            // Check if element's name attribute matches
            if (element.call_getAttribute("name")) |attr_name| {
                if (std.mem.eql(u8, attr_name, name)) {
                    return element;
                }
            }
        }
        return null;
    }

    /// Helper method to add an element to the collection
    /// NOTE: This is internal API, not part of WebIDL spec
    pub fn addElement(self: *HTMLCollection, element: *Element) !void {
        try self.elements.append(element);
    }

    /// Helper method to clear the collection
    /// NOTE: This is internal API, not part of WebIDL spec
    pub fn clear(self: *HTMLCollection) void {
        self.elements.clearRetainingCapacity();
    }

    // =========================================================================
    // Factory methods for DOM Standard collection types
    // =========================================================================

    /// Initialize collection for getElementsByTagName
    /// DOM §4.5.1 - Returns elements whose qualified name matches
    pub fn initByTagName(allocator: Allocator, root: *Node, qualified_name: []const u8, is_html_document: bool) !HTMLCollection {
        var coll = HTMLCollection{
            .allocator = allocator,
            .elements = infra.List(*Element).init(allocator),
            .root = root,
            .filter_fn = null,
            .filter_context = null,
        };

        // Collect matching elements
        try coll.collectElementsByTagName(root, qualified_name, is_html_document);
        return coll;
    }

    fn collectElementsByTagName(self: *HTMLCollection, node: *Node, qualified_name: []const u8, is_html_document: bool) !void {
        // "*" matches all elements
        const match_all = std.mem.eql(u8, qualified_name, "*");

        for (node.child_nodes.toSlice()) |child| {
            if (child.node_type == Node.ELEMENT_NODE) {
                const element: *Element = @ptrCast(child);

                if (match_all) {
                    try self.elements.append(element);
                } else {
                    // Per spec: In HTML documents, elements in HTML namespace match case-insensitively
                    const tag = element.get_tagName();
                    const is_html_namespace = element.namespace_uri == null or
                        std.mem.eql(u8, element.namespace_uri.?, "http://www.w3.org/1999/xhtml");

                    if (is_html_document and is_html_namespace) {
                        // Case-insensitive match for HTML elements in HTML documents
                        if (std.ascii.eqlIgnoreCase(tag, qualified_name)) {
                            try self.elements.append(element);
                        }
                    } else {
                        // Case-sensitive match for non-HTML
                        if (std.mem.eql(u8, tag, qualified_name)) {
                            try self.elements.append(element);
                        }
                    }
                }
                try self.collectElementsByTagName(child, qualified_name, is_html_document);
            }
        }
    }

    /// Initialize collection for getElementsByTagNameNS
    /// DOM §4.5.2 - Returns elements whose namespace and local name match
    pub fn initByTagNameNS(allocator: Allocator, root: *Node, namespace: ?[]const u8, local_name: []const u8) !HTMLCollection {
        var coll = HTMLCollection{
            .allocator = allocator,
            .elements = infra.List(*Element).init(allocator),
            .root = root,
            .filter_fn = null,
            .filter_context = null,
        };

        try coll.collectElementsByTagNameNS(root, namespace, local_name);
        return coll;
    }

    fn collectElementsByTagNameNS(self: *HTMLCollection, node: *Node, namespace: ?[]const u8, local_name: []const u8) !void {
        const match_all_ns = namespace != null and std.mem.eql(u8, namespace.?, "*");
        const match_all_name = std.mem.eql(u8, local_name, "*");

        for (node.child_nodes.toSlice()) |child| {
            if (child.node_type == Node.ELEMENT_NODE) {
                const element: *Element = @ptrCast(child);

                var ns_matches = false;
                var name_matches = false;

                // Check namespace match
                if (match_all_ns) {
                    ns_matches = true;
                } else if (namespace == null) {
                    ns_matches = element.namespace_uri == null;
                } else if (element.namespace_uri) |elem_ns| {
                    ns_matches = std.mem.eql(u8, elem_ns, namespace.?);
                }

                // Check local name match
                if (match_all_name) {
                    name_matches = true;
                } else {
                    name_matches = std.mem.eql(u8, element.local_name, local_name);
                }

                if (ns_matches and name_matches) {
                    try self.elements.append(element);
                }

                try self.collectElementsByTagNameNS(child, namespace, local_name);
            }
        }
    }

    /// Initialize collection for getElementsByClassName
    /// DOM §4.5.3 - Returns elements with all specified class names
    pub fn initByClassName(allocator: Allocator, root: *Node, class_names: []const u8, quirks_mode: bool) !HTMLCollection {
        var coll = HTMLCollection{
            .allocator = allocator,
            .elements = infra.List(*Element).init(allocator),
            .root = root,
            .filter_fn = null,
            .filter_context = null,
        };

        // Parse class names (space-separated)
        var classes = std.ArrayList([]const u8).init(allocator);
        defer classes.deinit();

        var iter = std.mem.splitScalar(u8, class_names, ' ');
        while (iter.next()) |class| {
            if (class.len > 0) {
                try classes.append(class);
            }
        }

        if (classes.items.len == 0) {
            // Empty class list - return empty collection
            return coll;
        }

        try coll.collectElementsByClassName(root, classes.items, quirks_mode);
        return coll;
    }

    fn collectElementsByClassName(self: *HTMLCollection, node: *Node, classes: []const []const u8, quirks_mode: bool) !void {
        for (node.child_nodes.toSlice()) |child| {
            if (child.node_type == Node.ELEMENT_NODE) {
                const element: *Element = @ptrCast(child);

                // Check if element has all required classes
                const class_attr = element.call_getAttribute("class") orelse "";
                if (hasAllClasses(class_attr, classes, quirks_mode)) {
                    try self.elements.append(element);
                }

                try self.collectElementsByClassName(child, classes, quirks_mode);
            }
        }
    }

    fn hasAllClasses(element_classes: []const u8, required_classes: []const []const u8, quirks_mode: bool) bool {
        for (required_classes) |required| {
            var found = false;
            var iter = std.mem.splitScalar(u8, element_classes, ' ');
            while (iter.next()) |element_class| {
                if (element_class.len == 0) continue;

                if (quirks_mode) {
                    // Quirks mode: case-insensitive comparison
                    if (std.ascii.eqlIgnoreCase(element_class, required)) {
                        found = true;
                        break;
                    }
                } else {
                    // Standards mode: case-sensitive comparison
                    if (std.mem.eql(u8, element_class, required)) {
                        found = true;
                        break;
                    }
                }
            }
            if (!found) return false;
        }
        return true;
    }
}, .{
    .exposed = &.{.Window},
});
