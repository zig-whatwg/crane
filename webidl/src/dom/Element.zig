//! Element interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-element

const std = @import("std");
const webidl = @import("webidl");
const dom = @import("dom");
const infra = @import("infra");

const Node = @import("node").Node;
const ChildNode = @import("child_node").ChildNode;
const NonDocumentTypeChildNode = @import("non_document_type_child_node").NonDocumentTypeChildNode;
const ParentNode = @import("parent_node").ParentNode;
const Slottable = @import("slottable").Slottable;
const NodeList = @import("node_list").NodeList;
const dom_types = @import("dom_types");
const Allocator = std.mem.Allocator;
const Attr = @import("attr").Attr;
const ShadowRoot = @import("shadow_root").ShadowRoot;
const ShadowRootInit = @import("shadow_root_init").ShadowRootInit;
const Text = @import("text").Text;

/// Element WebIDL interface
/// DOM Spec: interface Element : Node
pub const Element = webidl.interface(struct {
    pub const extends = Node;
    pub const includes = .{ ChildNode, NonDocumentTypeChildNode, ParentNode, Slottable };

    allocator: Allocator,
    tag_name: []const u8,
    namespace_uri: ?[]const u8,
    attributes: infra.List(Attr),

    /// Shadow root attached to this element (null if not a shadow host)
    shadow_root: ?*ShadowRoot,

    pub fn init(allocator: Allocator, tag_name: []const u8) !Element {
        // NOTE: Parent Node fields will be flattened by codegen
        return .{
            .allocator = allocator,
            .tag_name = tag_name,
            .namespace_uri = null,
            .attributes = infra.List(Attr).init(allocator),
            .shadow_root = null,
        };
    }

    pub fn deinit(self: *Element) void {
        // NOTE: Parent Node cleanup is handled by codegen
        self.attributes.deinit();

        // Free namespace_uri if allocated
        if (self.namespace_uri) |ns| {
            self.allocator.free(ns);
        }
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
    ///
    /// Returns a DOMTokenList representing the class attribute.
    /// The DOMTokenList is [SameObject] - should return same instance on repeated calls.
    /// TODO: Implement [SameObject] caching
    pub fn get_classList(self: *const Element) !*DOMTokenList {
        const TokenList = @import("dom_token_list").DOMTokenList;

        // Create DOMTokenList associated with this element's "class" attribute
        const token_list = try self.allocator.create(TokenList);
        token_list.* = try TokenList.init(self.allocator, @constCast(self), "class");

        // Parse current class attribute value into tokens
        const class_value = self.call_getAttribute("class") orelse "";
        if (class_value.len > 0) {
            var iter = std.mem.tokenizeScalar(u8, class_value, ' ');
            while (iter.next()) |token| {
                // Skip empty tokens
                if (token.len == 0) continue;

                const token_copy = try self.allocator.dupe(u8, token);
                try token_list.tokens.append(token_copy);
            }
        }

        return token_list;
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
    ///
    /// Spec steps:
    /// 1. Let s be the result of parse a selector from selectors.
    /// 2. If s is failure, throw a "SyntaxError" DOMException.
    /// 3. If the result of match a selector against an element, using s, this,
    ///    and :scope element this, returns success, then return true; otherwise, return false.
    pub fn call_matches(self: *const Element, allocator: Allocator, selectors: []const u8) !bool {
        // Use scopeMatchSelectorsString to parse and match
        // This will throw SyntaxError if parsing fails
        var matches = try dom.selectors.scopeMatchSelectorsString(allocator, selectors, self);
        defer matches.deinit();

        // Check if self is in the matches list
        for (matches.items) |match| {
            if (match == self) {
                return true;
            }
        }

        return false;
    }

    /// DOM §4.10.4 - Element.closest(selectors)
    /// Returns the closest ancestor element (including this element) that matches the given CSS selectors.
    /// Returns null if no such element exists.
    ///
    /// Spec steps:
    /// 1. Let s be the result of parse a selector from selectors.
    /// 2. If s is failure, throw a "SyntaxError" DOMException.
    /// 3. Let elements be this's inclusive ancestors that are elements, in reverse tree order.
    /// 4. For each element in elements, if the result of match a selector against an element,
    ///    using s, element, and :scope element this, returns success, return element.
    /// 5. Return null.
    pub fn call_closest(self: *const Element, allocator: Allocator, selectors: []const u8) !?*Element {
        const NodeType = @import("node").Node;

        // Parse selectors (will throw SyntaxError if invalid)
        var matches = try dom.selectors.scopeMatchSelectorsString(allocator, selectors, self);
        defer matches.deinit();

        // Step 3: Walk up the tree from this element
        // Check this element and its ancestors
        const self_node: *const NodeType = @ptrCast(self);
        var current: ?*const NodeType = self_node;

        while (current) |node| {
            // Only check elements
            if (node.node_type == NodeType.ELEMENT_NODE) {
                const elem: *const Element = @ptrCast(node);

                // Check if this element is in the matches
                for (matches.items) |match| {
                    if (match == elem) {
                        // Cast away const - closest returns mutable pointer
                        return @constCast(elem);
                    }
                }
            }

            // Move to parent
            current = node.parent_node;
        }

        // Step 5: No match found
        return null;
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

    // ========================================================================
    // Shadow DOM Methods (DOM §4.10.2)
    // ========================================================================

    /// DOM §4.10.2 - Element.attachShadow(init)
    ///
    /// Creates a shadow root for this element and returns it.
    ///
    /// Spec: https://dom.spec.whatwg.org/#dom-element-attachshadow
    pub fn call_attachShadow(self: *Element, shadow_init: ShadowRootInit) !*ShadowRoot {
        // Step 1: Let registry be this's node document's custom element registry
        // TODO: Implement when CustomElementRegistry is available
        const registry = shadow_init.customElementRegistry;

        // Step 2: If init["customElementRegistry"] is non-null:
        if (shadow_init.customElementRegistry) |_| {
            // Step 2.1: Set registry to init["customElementRegistry"]
            // Step 2.2: If registry's is scoped is false and registry is not this's node document's custom element registry, then throw NotSupportedError
            // TODO: Implement when CustomElementRegistry is available
        }

        // Step 3: Run attach a shadow root with this, init["mode"], init["clonable"],
        // init["serializable"], init["delegatesFocus"], init["slotAssignment"], and registry
        const shadow_dom_algorithms = dom.shadow_dom_algorithms;
        try shadow_dom_algorithms.attachShadowRoot(
            self,
            shadow_init.mode,
            shadow_init.clonable,
            shadow_init.serializable,
            shadow_init.delegatesFocus,
            shadow_init.slotAssignment,
            registry,
        );

        // Step 4: Return this's shadow root
        return self.shadow_root.?;
    }

    /// DOM §4.10.2 - Element.shadowRoot getter
    ///
    /// Returns element's shadow root, if any, and if shadow root's mode is "open"; otherwise null.
    ///
    /// Spec: https://dom.spec.whatwg.org/#dom-element-shadowroot
    pub fn get_shadowRoot(self: *const Element) ?*ShadowRoot {
        // Step 1: Let shadow be this's shadow root
        const shadow = self.shadow_root orelse return null;

        // Step 2: If shadow's mode is "closed", then return null
        if (shadow.getMode() == .closed) {
            return null;
        }

        // Step 3: Return shadow
        return shadow;
    }

    // Forward declarations for not-yet-implemented types
    const DOMTokenList = @import("dom_token_list").DOMTokenList;
    const HTMLCollection = @import("html_collection").HTMLCollection;
}, .{
    .exposed = &.{.Window},
});
