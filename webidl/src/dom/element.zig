//! Element interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-element

const std = @import("std");
const webidl = @import("webidl");
const infra = @import("infra");
const dom = @import("dom");

const Allocator = std.mem.Allocator;
const Node = @import("node").Node;
const ChildNode = @import("child_node").ChildNode;
const NonDocumentTypeChildNode = @import("non_document_type_child_node").NonDocumentTypeChildNode;
const ParentNode = @import("parent_node").ParentNode;
const NodeList = @import("node_list").NodeList;
const dom_types = @import("dom_types");

/// Element WebIDL interface
/// DOM Spec: interface Element : Node
pub const Element = webidl.interface(struct {
    pub const extends = Node;
    pub const includes = .{ ChildNode, NonDocumentTypeChildNode, ParentNode };

    allocator: Allocator,
    tag_name: []const u8,
    namespace_uri: ?[]const u8,
    attributes: infra.List(Attr),

    const Attr = @import("attr").Attr;

    pub fn init(allocator: Allocator, tag_name: []const u8) !Element {
        // NOTE: Parent Node fields will be flattened by codegen
        return .{
            .allocator = allocator,
            .tag_name = tag_name,
            .namespace_uri = null,
            .attributes = infra.List(Attr).init(allocator),
            // TODO: Initialize Node parent fields (will be added by codegen)
        };
    }

    pub fn deinit(self: *Element) void {
        // NOTE: Parent Node cleanup will be handled by codegen
        self.attributes.deinit();
        // TODO: Call parent Node deinit (will be added by codegen)
    }

    /// getAttribute(qualifiedName)
    /// Spec: https://dom.spec.whatwg.org/#dom-element-getattribute
    pub fn call_getAttribute(self: *const Element, qualified_name: []const u8) ?[]const u8 {
        for (self.attributes.items) |attr| {
            if (std.mem.eql(u8, attr.name, qualified_name)) {
                return attr.value;
            }
        }
        return null;
    }

    /// setAttribute(qualifiedName, value)
    /// Spec: https://dom.spec.whatwg.org/#dom-element-setattribute
    pub fn call_setAttribute(self: *Element, qualified_name: []const u8, value: []const u8) !void {
        for (self.attributes.items) |*attr| {
            if (std.mem.eql(u8, attr.name, qualified_name)) {
                attr.value = value;
                return;
            }
        }
        try self.attributes.append(Attr{
            .name = qualified_name,
            .value = value,
        });
    }

    /// removeAttribute(qualifiedName)
    /// Spec: https://dom.spec.whatwg.org/#dom-element-removeattribute
    pub fn call_removeAttribute(self: *Element, qualified_name: []const u8) void {
        for (self.attributes.items, 0..) |attr, i| {
            if (std.mem.eql(u8, attr.name, qualified_name)) {
                _ = self.attributes.orderedRemove(i);
                return;
            }
        }
    }

    /// hasAttribute(qualifiedName)
    /// Spec: https://dom.spec.whatwg.org/#dom-element-hasattribute
    pub fn call_hasAttribute(self: *const Element, qualified_name: []const u8) bool {
        for (self.attributes.items) |attr| {
            if (std.mem.eql(u8, attr.name, qualified_name)) {
                return true;
            }
        }
        return false;
    }

    /// DOM §4.10.1 - Element.id
    /// The id getter steps are to return the value of this's id content attribute.
    /// The id setter steps are to set the value of this's id content attribute to the given value.
    pub fn get_id(self: *const Element) []const u8 {
        return self.call_getAttribute("id") orelse "";
    }

    pub fn set_id(self: *Element, value: []const u8) !void {
        try self.call_setAttribute("id", value);
    }

    /// DOM §4.10.1 - Element.className
    /// The className getter steps are to return the value of this's class content attribute.
    /// The className setter steps are to set the value of this's class content attribute to the given value.
    pub fn get_className(self: *const Element) []const u8 {
        return self.call_getAttribute("class") orelse "";
    }

    pub fn set_className(self: *Element, value: []const u8) !void {
        try self.call_setAttribute("class", value);
    }

    /// DOM §4.10.1 - Element.classList
    /// The classList getter steps are to return a DOMTokenList object whose associated element
    /// is this and whose associated attribute's local name is class.
    /// TODO: Implement DOMTokenList
    /// For now, return error as DOMTokenList is not implemented
    pub fn get_classList(self: *const Element) !*DOMTokenList {
        _ = self;
        return error.NotImplemented;
    }

    /// DOM §4.10.1 - Element.slot
    /// The slot getter steps are to return the value of this's slot content attribute.
    /// The slot setter steps are to set the value of this's slot content attribute to the given value.
    pub fn get_slot(self: *const Element) []const u8 {
        return self.call_getAttribute("slot") orelse "";
    }

    pub fn set_slot(self: *Element, value: []const u8) !void {
        try self.call_setAttribute("slot", value);
    }

    /// Getters
    pub fn get_tagName(self: *const Element) []const u8 {
        return self.tag_name;
    }

    pub fn get_namespaceURI(self: *const Element) ?[]const u8 {
        return self.namespace_uri;
    }

    /// DOM §4.10.5 - Element.getElementsByTagName(qualifiedName)
    /// Returns an HTMLCollection of all descendant elements whose qualified name is qualifiedName.
    /// If qualifiedName is "*", returns all descendant elements.
    /// TODO: Implement when HTMLCollection is available
    pub fn call_getElementsByTagName(self: *const Element, qualified_name: []const u8) !*HTMLCollection {
        _ = self;
        _ = qualified_name;
        return error.NotImplemented;
    }

    /// DOM §4.10.5 - Element.getElementsByTagNameNS(namespace, localName)
    /// Returns an HTMLCollection of all descendant elements matching the namespace and local name.
    /// If namespace is "*", matches any namespace.
    /// If localName is "*", matches any local name.
    /// If both are "*", returns all descendant elements.
    /// TODO: Implement when HTMLCollection is available
    pub fn call_getElementsByTagNameNS(
        self: *const Element,
        namespace: ?[]const u8,
        local_name: []const u8,
    ) !*HTMLCollection {
        _ = self;
        _ = namespace;
        _ = local_name;
        return error.NotImplemented;
    }

    /// DOM §4.10.5 - Element.getElementsByClassName(classNames)
    /// Returns an HTMLCollection of all descendant elements that have all the given class names.
    /// classNames is a space-separated list of class names.
    /// TODO: Implement when HTMLCollection is available
    pub fn call_getElementsByClassName(self: *const Element, class_names: []const u8) !*HTMLCollection {
        _ = self;
        _ = class_names;
        return error.NotImplemented;
    }

    /// DOM §4.10.4 - Element.matches(selectors)
    /// Returns true if this element would be selected by the given CSS selectors; otherwise false.
    /// TODO: Implement using Selectors API (requires CSS selector parser)
    pub fn call_matches(self: *const Element, selectors: []const u8) !bool {
        _ = self;
        _ = selectors;
        return error.NotImplemented;
    }

    /// DOM §4.10.4 - Element.closest(selectors)
    /// Returns the closest ancestor element (including this element) that matches the given CSS selectors.
    /// Returns null if no such element exists.
    /// TODO: Implement using Selectors API (requires CSS selector parser)
    pub fn call_closest(self: *const Element, selectors: []const u8) !?*Element {
        _ = self;
        _ = selectors;
        return error.NotImplemented;
    }

    /// DOM §4.10.7 - insert adjacent algorithm
    /// To insert adjacent, given an element element, string where, and a node node, run the steps
    /// associated with the first ASCII case-insensitive match for where
    fn insertAdjacent(element: *Element, where: []const u8, node: *Node) !?*Node {
        const mutation = dom.mutation;

        // ASCII case-insensitive comparison helper
        const eqlIgnoreCase = std.ascii.eqlIgnoreCase;

        if (eqlIgnoreCase(where, "beforebegin")) {
            // If element's parent is null, return null
            const parent = element.parent_node orelse return null;

            // Return the result of pre-inserting node into element's parent before element
            return try mutation.preInsert(node, parent, element);
        } else if (eqlIgnoreCase(where, "afterbegin")) {
            // Return the result of pre-inserting node into element before element's first child
            const first_child = if (element.child_nodes.items.len > 0)
                element.child_nodes.items[0]
            else
                null;
            return try mutation.preInsert(node, @ptrCast(element), first_child);
        } else if (eqlIgnoreCase(where, "beforeend")) {
            // Return the result of pre-inserting node into element before null
            return try mutation.preInsert(node, @ptrCast(element), null);
        } else if (eqlIgnoreCase(where, "afterend")) {
            // If element's parent is null, return null
            const parent = element.parent_node orelse return null;

            // Return the result of pre-inserting node into element's parent before element's next sibling
            const next_sibling = dom.tree_helpers.getNextSibling(element);
            return try mutation.preInsert(node, parent, next_sibling);
        } else {
            // Otherwise: Throw a "SyntaxError" DOMException
            return error.SyntaxError;
        }
    }

    /// DOM §4.10.7 - Element.insertAdjacentElement(where, element)
    /// The insertAdjacentElement(where, element) method steps are to return the result of
    /// running insert adjacent, given this, where, and element.
    pub fn call_insertAdjacentElement(self: *Element, where: []const u8, element: *Element) !?*Element {
        const result = try insertAdjacent(self, where, @ptrCast(element));
        return if (result) |node| @ptrCast(@alignCast(node)) else null;
    }

    /// DOM §4.10.7 - Element.insertAdjacentText(where, data)
    /// The insertAdjacentText(where, data) method steps are:
    /// 1. Let text be a new Text node whose data is data and node document is this's node document.
    /// 2. Run insert adjacent, given this, where, and text.
    /// This method returns nothing because it existed before we had a chance to design it.
    pub fn call_insertAdjacentText(self: *Element, where: []const u8, data: []const u8) !void {
        // Step 1: Let text be a new Text node whose data is data and node document is this's node document
        const text = try self.allocator.create(Text);
        errdefer self.allocator.destroy(text);
        text.* = try Text.init(self.allocator);
        // TODO: Set text.data = data when CharacterData has data field accessible
        _ = data;

        // Step 2: Run insert adjacent, given this, where, and text
        _ = try insertAdjacent(self, where, @ptrCast(text));
    }

    // Forward declarations for not-yet-implemented types
    const DOMTokenList = @import("dom_token_list").DOMTokenList;
    const HTMLCollection = @import("html_collection").HTMLCollection;
    const Text = @import("text").Text;
}, .{
    .exposed = &.{.Window},
});
