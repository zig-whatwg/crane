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
}, .{
    .exposed = &.{.Window},
});
