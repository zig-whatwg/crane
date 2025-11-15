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
const dom_types = @import("dom_types");
const Allocator = std.mem.Allocator;
const Attr = @import("attr").Attr;
const ShadowRoot = @import("shadow_root").ShadowRoot;
const ShadowRootInit = @import("shadow_root_init").ShadowRootInit;
const Text = @import("text").Text;

/// Custom element state per HTML spec
/// Spec: https://html.spec.whatwg.org/#custom-element-state
pub const CustomElementState = enum {
    undefined,
    failed,
    uncustomized,
    precustomized,
    custom,
};

/// Element WebIDL interface
/// DOM Spec: interface Element : Node
pub const Element = webidl.interface(struct {
    pub const extends = Node;
    pub const includes = .{ ChildNode, NonDocumentTypeChildNode, ParentNode, Slottable };

    allocator: Allocator,
    tag_name: []const u8,
    namespace_uri: ?[]const u8,
    prefix: ?[]const u8 = null,
    local_name: []const u8,
    attributes: infra.List(Attr),

    /// Shadow root attached to this element (null if not a shadow host)
    shadow_root: ?*ShadowRoot,

    /// Custom element state per HTML spec
    /// Spec: https://html.spec.whatwg.org/#custom-element-state
    custom_element_state: CustomElementState = .undefined,

    /// "is" value for customized built-in elements
    /// Spec: https://html.spec.whatwg.org/#concept-element-is-value
    is_value: ?[]const u8 = null,

    /// Cached DOMTokenList for classList ([SameObject])
    cached_class_list: ?*@import("dom_token_list").DOMTokenList = null,

    /// Cached NamedNodeMap for attributes ([SameObject])
    /// Spec: https://dom.spec.whatwg.org/#ref-for-dom-element-attributes
    cached_attributes: ?*@import("named_node_map").NamedNodeMap = null,

    pub fn init(allocator: Allocator, tag_name: []const u8) !Element {
        // NOTE: Parent Node fields will be flattened by codegen
        // NOTE: Mixin fields (Slottable) are also flattened by codegen
        return .{
            // Inherited from EventTarget (via Node)
            .event_listener_list = null,
            // Inherited from Node
            .node_type = 1, // ELEMENT_NODE
            .node_name = tag_name,
            .parent_node = null,
            .child_nodes = infra.List(*Node).init(allocator),
            .owner_document = null,
            .registered_observers = infra.List(@import("registered_observer").RegisteredObserver).init(allocator),
            .cloning_steps_hook = null,
            .cached_child_nodes = null,
            // Slottable mixin fields
            .slottable_name = "",
            .assigned_slot = null,
            .manual_slot_assignment = null,
            // Element own fields
            .allocator = allocator,
            .tag_name = tag_name,
            .namespace_uri = null,
            .prefix = null,
            .local_name = tag_name,
            .attributes = infra.List(Attr).init(allocator),
            .shadow_root = null,
            .custom_element_state = .undefined,
            .is_value = null,
            .cached_class_list = null,
            .cached_attributes = null,
        };
    }

    pub fn deinit(self: *Element) void {
        // Clean up Node fields (inherited)
        self.child_nodes.deinit();
        self.registered_observers.deinit();
        if (self.cached_child_nodes) |list| {
            list.deinit();
            self.allocator.destroy(list);
        }

        // Clean up Element fields
        self.attributes.deinit();

        // Free namespace_uri if allocated
        if (self.namespace_uri) |ns| {
            self.allocator.free(ns);
        }

        // Free prefix if allocated
        if (self.prefix) |p| {
            self.allocator.free(p);
        }

        // Free cached classList
        if (self.cached_class_list) |list| {
            list.deinit();
            self.allocator.destroy(list);
        }

        // Free cached attributes NamedNodeMap
        if (self.cached_attributes) |attrs| {
            attrs.deinit();
            self.allocator.destroy(attrs);
        }
    }

    // ========================================================================
    // DOM §4.10.3-4.10.4 - Attribute Helper Algorithms
    // ========================================================================

    /// Append an attribute - DOM §4.10.3
    /// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-append
    ///
    /// To append an attribute to element:
    /// 1. Append attribute to element's attribute list
    /// 2. Set attribute's element to element
    /// 3. Set attribute's node document to element's node document
    /// 4. Handle attribute changes for attribute with element, null, and attribute's value
    fn appendAttribute(self: *Element, attribute: Attr) !void {
        // Step 1: Append to attribute list
        try self.attributes.append(attribute);

        // Get pointer to the appended attribute
        const appended_attr = &self.attributes.toSliceMut()[self.attributes.len - 1];

        // Step 2: Set attribute's element
        appended_attr.owner_element = self;

        // Step 3: Set attribute's node document
        // TODO: Set node_document when Attr has that field

        // Step 4: Handle attribute changes
        try Attr.handleAttributeChanges(appended_attr, self, null, appended_attr.value);
    }

    /// Remove an attribute - DOM §4.10.3
    /// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-remove
    ///
    /// To remove an attribute:
    /// 1. Let element be attribute's element
    /// 2. Remove attribute from element's attribute list
    /// 3. Set attribute's element to null
    /// 4. Handle attribute changes for attribute with element, attribute's value, and null
    fn removeAttributeInternal(self: *Element, attr_to_remove: *Attr) !void {
        // Step 1: element is self
        const old_value = attr_to_remove.value;

        // Step 2: Remove from attribute list
        for (self.attributes.toSlice(), 0..) |*attr, i| {
            if (attr == attr_to_remove) {
                _ = try self.attributes.remove(i);
                break;
            }
        }

        // Step 3: Set attribute's element to null
        attr_to_remove.owner_element = null;

        // Step 4: Handle attribute changes
        // Note: Pass empty string for new_value since attribute is being removed
        try Attr.handleAttributeChanges(attr_to_remove, self, old_value, "");
    }

    /// Set an attribute value - DOM §4.10.4
    /// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-set-value
    ///
    /// To set an attribute value given element, localName, value, and optionally prefix and namespace:
    /// 1. Let attribute be result of getting attribute given namespace, localName, and element
    /// 2. If attribute is null, create attribute and append to element, then return
    /// 3. Change attribute to value
    fn setAttributeValue(
        self: *Element,
        local_name: []const u8,
        value: []const u8,
        prefix: ?[]const u8,
        namespace: ?[]const u8,
    ) !void {
        // Step 1: Get existing attribute
        const existing = self.getAttributeByNamespaceAndLocalName(namespace, local_name);

        if (existing) |attr| {
            // Step 3: Change attribute to value
            try Attr.changeAttribute(attr, value);
        } else {
            // Step 2: Create new attribute and append
            const new_attr = try Attr.init(
                self.allocator,
                namespace,
                prefix,
                local_name,
                value,
            );
            try self.appendAttribute(new_attr);
        }
    }

    /// Remove an attribute by name - DOM §4.10.4
    /// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-remove-by-name
    ///
    /// To remove an attribute by name given qualifiedName and element:
    /// 1. Let attr be result of getting attribute given qualifiedName and element
    /// 2. If attr is non-null, then remove attr
    /// 3. Return attr
    fn removeAttributeByName(self: *Element, qualified_name: []const u8) !void {
        if (self.getAttributeByName(qualified_name)) |attr| {
            try self.removeAttributeInternal(attr);
        }
    }

    /// Remove an attribute by namespace and local name - DOM §4.10.4
    /// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-remove-by-namespace
    ///
    /// To remove an attribute by namespace and local name given namespace, localName, and element:
    /// 1. Let attr be result of getting attribute given namespace, localName, and element
    /// 2. If attr is non-null, then remove attr
    /// 3. Return attr
    fn removeAttributeByNamespaceAndLocalName(
        self: *Element,
        namespace: ?[]const u8,
        local_name: []const u8,
    ) !void {
        if (self.getAttributeByNamespaceAndLocalName(namespace, local_name)) |attr| {
            try self.removeAttributeInternal(attr);
        }
    }

    /// Get an attribute by name - DOM §4.10.4
    /// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-get-by-name
    ///
    /// To get an attribute by name given a string qualifiedName and element:
    /// 1. If element is in HTML namespace and its node document is HTML document,
    ///    then set qualifiedName to qualifiedName in ASCII lowercase
    /// 2. Return first attribute in element's attribute list whose qualified name
    ///    is qualifiedName; otherwise null
    fn getAttributeByName(self: *const Element, qualified_name: []const u8) ?*Attr {
        // Step 1: ASCII lowercase if HTML element in HTML document
        var lowercased_buf: [256]u8 = undefined;
        const search_name = if (self.isHTMLElementInHTMLDocument()) blk: {
            // ASCII lowercase the qualified name
            if (qualified_name.len > lowercased_buf.len) {
                // Name too long for stack buffer, use heap
                // For now, just use original (this is edge case)
                break :blk qualified_name;
            }
            for (qualified_name, 0..) |c, i| {
                lowercased_buf[i] = std.ascii.toLower(c);
            }
            break :blk lowercased_buf[0..qualified_name.len];
        } else qualified_name;

        // Step 2: Find first attribute with matching qualified name
        for (@constCast(self).attributes.toSliceMut()) |*attr| {
            const attr_qualified_name = attr.get_name() catch continue;
            defer if (attr.prefix != null) self.allocator.free(attr_qualified_name); // Free if allocated

            if (std.mem.eql(u8, attr_qualified_name, search_name)) {
                return attr;
            }
        }
        return null;
    }

    /// Get an attribute by namespace and local name - DOM §4.10.4
    /// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-get-by-namespace
    ///
    /// To get an attribute by namespace and local name given null or string namespace,
    /// string localName, and element:
    /// 1. If namespace is empty string, set it to null
    /// 2. Return attribute in element's attribute list whose namespace is namespace
    ///    and local name is localName, if any; otherwise null
    fn getAttributeByNamespaceAndLocalName(
        self: *const Element,
        namespace: ?[]const u8,
        local_name: []const u8,
    ) ?*Attr {
        // Step 1: Empty string namespace becomes null
        const ns = if (namespace) |n| if (n.len == 0) null else n else null;

        // Step 2: Find attribute with matching namespace and local name
        for (@constCast(self).attributes.toSliceMut()) |*attr| {
            // Check namespace match
            const ns_match = if (ns == null and attr.namespace_uri == null)
                true
            else if (ns != null and attr.namespace_uri != null)
                std.mem.eql(u8, ns.?, attr.namespace_uri.?)
            else
                false;

            // Check local name match
            const name_match = std.mem.eql(u8, attr.local_name, local_name);

            if (ns_match and name_match) {
                return attr;
            }
        }
        return null;
    }

    /// Check if this element is an HTML element in an HTML document
    /// Used for ASCII lowercasing of attribute names
    fn isHTMLElementInHTMLDocument(self: *const Element) bool {
        // Check if element is in HTML namespace
        const html_ns = "http://www.w3.org/1999/xhtml";
        const in_html_namespace = if (self.namespace_uri) |ns|
            std.mem.eql(u8, ns, html_ns)
        else
            false;

        if (!in_html_namespace) return false;

        // Check if node document is an HTML document
        // For now, we'll assume documents are HTML unless explicitly XML
        // Full implementation would check document.type
        // TODO: Check owner_document.type when Document is fully implemented
        return true;
    }

    // ========================================================================
    // DOM §4.10.4 - Attribute Public Methods
    // ========================================================================

    /// getAttribute(qualifiedName)
    /// Spec: https://dom.spec.whatwg.org/#dom-element-getattribute
    ///
    /// The getAttribute(qualifiedName) method steps are:
    /// 1. Let attr be result of getting an attribute given qualifiedName and this
    /// 2. If attr is null, return null
    /// 3. Return attr's value
    pub fn call_getAttribute(self: *const Element, qualified_name: []const u8) ?[]const u8 {
        // Step 1: Get attribute by name
        const attr = self.getAttributeByName(qualified_name) orelse return null;

        // Step 3: Return attr's value
        return attr.value;
    }

    /// getAttributeNS(namespace, localName)
    /// Spec: https://dom.spec.whatwg.org/#dom-element-getattributens
    ///
    /// The getAttributeNS(namespace, localName) method steps are:
    /// 1. Let attr be result of getting an attribute given namespace, localName, and this
    /// 2. If attr is null, return null
    /// 3. Return attr's value
    pub fn call_getAttributeNS(
        self: *const Element,
        namespace: ?[]const u8,
        local_name: []const u8,
    ) ?[]const u8 {
        // Step 1: Get attribute by namespace and local name
        const attr = self.getAttributeByNamespaceAndLocalName(namespace, local_name) orelse return null;

        // Step 3: Return attr's value
        return attr.value;
    }

    /// setAttribute(qualifiedName, value)
    /// Spec: https://dom.spec.whatwg.org/#dom-element-setattribute
    ///
    /// The setAttribute(qualifiedName, value) method steps are:
    /// 1. If qualifiedName is not valid attribute local name, throw InvalidCharacterError
    /// 2. If this is in HTML namespace and node document is HTML document,
    ///    set qualifiedName to qualifiedName in ASCII lowercase
    /// 3. Let attribute be first attribute in this's attribute list whose qualified name
    ///    is qualifiedName, and null otherwise
    /// 4. If attribute is null, create attribute and append to this, then return
    /// 5. Change attribute to value
    pub fn call_setAttribute(self: *Element, qualified_name: []const u8, value: []const u8) !void {
        // Step 1: Validate qualified name (simplified - check not empty and valid chars)
        if (qualified_name.len == 0) {
            return error.InvalidCharacterError;
        }

        // Step 2: ASCII lowercase if HTML element in HTML document
        var lowercased_buf: [256]u8 = undefined;
        const normalized_name = if (self.isHTMLElementInHTMLDocument()) blk: {
            if (qualified_name.len > lowercased_buf.len) {
                break :blk qualified_name; // Edge case: name too long
            }
            for (qualified_name, 0..) |c, i| {
                lowercased_buf[i] = std.ascii.toLower(c);
            }
            break :blk lowercased_buf[0..qualified_name.len];
        } else qualified_name;

        // Step 3: Find existing attribute
        const existing = self.getAttributeByName(normalized_name);

        if (existing) |attr| {
            // Step 5: Change attribute to value
            try Attr.changeAttribute(attr, value);
        } else {
            // Step 4: Create new attribute and append
            // For setAttribute, we create with null namespace and prefix
            const new_attr = try Attr.init(
                self.allocator,
                null, // namespace
                null, // prefix
                normalized_name,
                value,
            );
            try self.appendAttribute(new_attr);
        }
    }

    /// setAttributeNS(namespace, qualifiedName, value)
    /// Spec: https://dom.spec.whatwg.org/#dom-element-setattributens
    ///
    /// The setAttributeNS(namespace, qualifiedName, value) method steps are:
    /// 1. Let (namespace, prefix, localName) = result of validating and extracting
    ///    namespace and qualifiedName given "element"
    /// 2. Set an attribute value for this using localName, value, and also prefix and namespace
    pub fn call_setAttributeNS(
        self: *Element,
        namespace: ?[]const u8,
        qualified_name: []const u8,
        value: []const u8,
    ) !void {
        // Step 1: Validate and extract namespace/qualifiedName
        // For now, simplified: split on ':' if present
        var prefix: ?[]const u8 = null;
        var local_name: []const u8 = qualified_name;

        if (std.mem.indexOfScalar(u8, qualified_name, ':')) |colon_idx| {
            prefix = qualified_name[0..colon_idx];
            local_name = qualified_name[colon_idx + 1 ..];
        }

        // Step 2: Set attribute value
        try self.setAttributeValue(local_name, value, prefix, namespace);
    }

    /// removeAttribute(qualifiedName)
    /// Spec: https://dom.spec.whatwg.org/#dom-element-removeattribute
    ///
    /// The removeAttribute(qualifiedName) method steps are to remove an attribute
    /// given qualifiedName and this, and then return undefined.
    pub fn call_removeAttribute(self: *Element, qualified_name: []const u8) !void {
        try self.removeAttributeByName(qualified_name);
    }

    /// removeAttributeNS(namespace, localName)
    /// Spec: https://dom.spec.whatwg.org/#dom-element-removeattributens
    ///
    /// The removeAttributeNS(namespace, localName) method steps are to remove an attribute
    /// given namespace, localName, and this, and then return undefined.
    pub fn call_removeAttributeNS(
        self: *Element,
        namespace: ?[]const u8,
        local_name: []const u8,
    ) !void {
        try self.removeAttributeByNamespaceAndLocalName(namespace, local_name);
    }

    /// toggleAttribute(qualifiedName, force?)
    /// Spec: https://dom.spec.whatwg.org/#dom-element-toggleattribute
    ///
    /// The toggleAttribute(qualifiedName, force) method steps are:
    /// 1. If qualifiedName is not valid attribute local name, throw InvalidCharacterError
    /// 2. If this is in HTML namespace and node document is HTML, set qualifiedName to ASCII lowercase
    /// 3. Let attribute be first attribute whose qualified name is qualifiedName, else null
    /// 4. If attribute is null:
    ///    a. If force not given or is true, create attribute with empty value, append, return true
    ///    b. Return false
    /// 5. Otherwise, if force not given or is false, remove attribute, return false
    /// 6. Return true
    pub fn call_toggleAttribute(
        self: *Element,
        qualified_name: []const u8,
        force: ?bool,
    ) !bool {
        // Step 1: Validate qualified name
        if (qualified_name.len == 0) {
            return error.InvalidCharacterError;
        }

        // Step 2: ASCII lowercase if HTML element in HTML document
        var lowercased_buf: [256]u8 = undefined;
        const normalized_name = if (self.isHTMLElementInHTMLDocument()) blk: {
            if (qualified_name.len > lowercased_buf.len) {
                break :blk qualified_name; // Edge case: name too long
            }
            for (qualified_name, 0..) |c, i| {
                lowercased_buf[i] = std.ascii.toLower(c);
            }
            break :blk lowercased_buf[0..qualified_name.len];
        } else qualified_name;

        // Step 3: Find existing attribute
        const existing = self.getAttributeByName(normalized_name);

        // Step 4: If attribute is null
        if (existing == null) {
            // Step 4a: If force not given or is true, create and append
            if (force == null or force.? == true) {
                const new_attr = try Attr.init(
                    self.allocator,
                    null, // namespace
                    null, // prefix
                    normalized_name,
                    "", // empty value
                );
                try self.appendAttribute(new_attr);
                return true;
            }
            // Step 4b: Return false
            return false;
        }

        // Step 5: Otherwise, if force not given or is false, remove attribute
        if (force == null or force.? == false) {
            try self.removeAttributeByName(normalized_name);
            return false;
        }

        // Step 6: Return true (attribute exists and force is true)
        return true;
    }

    /// hasAttribute(qualifiedName)
    /// Spec: https://dom.spec.whatwg.org/#dom-element-hasattribute
    ///
    /// The hasAttribute(qualifiedName) method steps are:
    /// 1. If this is in HTML namespace and its node document is HTML document,
    ///    then set qualifiedName to qualifiedName in ASCII lowercase
    /// 2. Return true if this has attribute whose qualified name is qualifiedName;
    ///    otherwise false
    pub fn call_hasAttribute(self: *const Element, qualified_name: []const u8) bool {
        return self.getAttributeByName(qualified_name) != null;
    }

    /// hasAttributeNS(namespace, localName)
    /// Spec: https://dom.spec.whatwg.org/#dom-element-hasattributens
    ///
    /// The hasAttributeNS(namespace, localName) method steps are:
    /// 1. If namespace is empty string, set it to null
    /// 2. Return true if this has attribute whose namespace is namespace and
    ///    local name is localName; otherwise false
    pub fn call_hasAttributeNS(
        self: *const Element,
        namespace: ?[]const u8,
        local_name: []const u8,
    ) bool {
        return self.getAttributeByNamespaceAndLocalName(namespace, local_name) != null;
    }

    /// getAttributeNames()
    /// Spec: https://dom.spec.whatwg.org/#dom-element-getattributenames
    ///
    /// The getAttributeNames() method steps are to return the qualified names
    /// of the attributes in this's attribute list, in order; otherwise a new list.
    ///
    /// These are not guaranteed to be unique.
    ///
    /// Note: Caller owns returned memory and must free each string and the List
    pub fn call_getAttributeNames(self: *const Element) !infra.List([]const u8) {
        var names = infra.List([]const u8).init(self.allocator);
        errdefer {
            var i: usize = 0;
            while (i < names.len) : (i += 1) {
                // Only free if prefix exists (qualified name was allocated)
                // If no prefix, it's just local_name which is owned by Attr
            }
            names.deinit();
        }

        var i: usize = 0;
        while (i < self.attributes.len) : (i += 1) {
            const attr = self.attributes.getMut(i).?;
            const qualified_name = try attr.get_name();
            // Note: get_name() returns allocated string if prefix exists,
            // otherwise returns local_name directly
            // The caller is responsible for freeing if needed
            try names.append(qualified_name);
        }

        return names;
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
    /// The DOMTokenList is [SameObject] - returns same instance on repeated calls.
    pub fn get_classList(self: *Element) !*DOMTokenList {
        // Return cached instance if available
        if (self.cached_class_list) |list| {
            return list;
        }

        const TokenList = @import("dom_token_list").DOMTokenList;

        // Create DOMTokenList associated with this element's "class" attribute
        const token_list = try self.allocator.create(TokenList);
        token_list.* = try TokenList.init(self.allocator, self, "class");

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

        // Cache the instance for [SameObject] semantics
        self.cached_class_list = token_list;

        return token_list;
    }

    /// DOM §4.9 - Element.attributes
    /// Returns the element's attribute list as a NamedNodeMap.
    /// The NamedNodeMap is [SameObject] - returns same instance on repeated calls.
    /// Spec: https://dom.spec.whatwg.org/#ref-for-dom-element-attributes
    pub fn get_attributes(self: *Element) !*@import("named_node_map").NamedNodeMap {
        // Return cached instance if available
        if (self.cached_attributes) |attrs| {
            return attrs;
        }

        const NamedNodeMap = @import("named_node_map").NamedNodeMap;

        // Create NamedNodeMap associated with this element
        const named_node_map = try self.allocator.create(NamedNodeMap);
        named_node_map.* = NamedNodeMap.init(self);

        // Cache the instance for [SameObject] semantics
        self.cached_attributes = named_node_map;

        return named_node_map;
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
    pub fn get_namespaceURI(self: *const Element) ?[]const u8 {
        return self.namespace_uri;
    }

    pub fn get_prefix(self: *const Element) ?[]const u8 {
        return self.prefix;
    }

    pub fn get_localName(self: *const Element) []const u8 {
        return self.local_name;
    }

    pub fn get_tagName(self: *const Element) []const u8 {
        return self.tag_name;
    }

    /// DOM §4.10.5 - Element.getElementsByTagName(qualifiedName)
    /// Returns an HTMLCollection of all descendant elements whose qualified name is qualifiedName.
    /// If qualifiedName is "*", returns all descendant elements.
    pub fn call_getElementsByTagName(self: *Element, qualified_name: []const u8) !*HTMLCollection {
        const collection = try self.allocator.create(HTMLCollection);
        collection.* = try HTMLCollection.init(self.allocator);

        // Collect matching descendants
        try self.collectByTagName(&self.base, qualified_name, collection);

        return collection;
    }

    fn collectByTagName(self: *const Element, node: *Node, qualified_name: []const u8, collection: *HTMLCollection) !void {
        for (node.child_nodes.toSlice()()) |child| {
            if (child.node_type == Node.ELEMENT_NODE) {
                const elem: *Element = @ptrCast(child);

                // Check if matches
                const matches = if (std.mem.eql(u8, qualified_name, "*"))
                    true
                else
                    std.mem.eql(u8, elem.node_name, qualified_name);

                if (matches) {
                    try collection.addElement(elem);
                }

                // Recurse
                try self.collectByTagName(child, qualified_name, collection);
            }
        }
    }

    /// DOM §4.10.5 - Element.getElementsByTagNameNS(namespace, localName)
    /// Returns an HTMLCollection of all descendant elements matching the namespace and local name.
    /// If namespace is "*", matches any namespace.
    /// If localName is "*", matches any local name.
    /// If both are "*", returns all descendant elements.
    pub fn call_getElementsByTagNameNS(
        self: *Element,
        namespace: ?[]const u8,
        local_name: []const u8,
    ) !*HTMLCollection {
        const collection = try self.allocator.create(HTMLCollection);
        collection.* = try HTMLCollection.init(self.allocator);

        try self.collectByTagNameNS(&self.base, namespace, local_name, collection);

        return collection;
    }

    fn collectByTagNameNS(self: *const Element, node: *Node, namespace: ?[]const u8, local_name: []const u8, collection: *HTMLCollection) !void {
        for (node.child_nodes.toSlice()()) |child| {
            if (child.node_type == Node.ELEMENT_NODE) {
                const elem: *Element = @ptrCast(child);

                // Check namespace match
                const ns_matches = if (namespace) |ns|
                    std.mem.eql(u8, ns, "*") or (elem.namespace_uri != null and std.mem.eql(u8, elem.namespace_uri.?, ns))
                else
                    elem.namespace_uri == null;

                // Check local name match
                const name_matches = std.mem.eql(u8, local_name, "*") or std.mem.eql(u8, elem.local_name, local_name);

                if (ns_matches and name_matches) {
                    try collection.addElement(elem);
                }

                try self.collectByTagNameNS(child, namespace, local_name, collection);
            }
        }
    }

    /// DOM §4.10.5 - Element.getElementsByClassName(classNames)
    /// Returns an HTMLCollection of all descendant elements that have all the given class names.
    /// classNames is a space-separated list of class names.
    pub fn call_getElementsByClassName(self: *Element, class_names: []const u8) !*HTMLCollection {
        const collection = try self.allocator.create(HTMLCollection);
        collection.* = try HTMLCollection.init(self.allocator);

        try self.collectByClassName(&self.base, class_names, collection);

        return collection;
    }

    fn collectByClassName(self: *const Element, node: *Node, class_names: []const u8, collection: *HTMLCollection) !void {
        for (node.child_nodes.toSlice()()) |child| {
            if (child.node_type == Node.ELEMENT_NODE) {
                const elem: *Element = @ptrCast(child);

                // Check if element has all required classes
                const attributes = elem.get_attributes();
                if (attributes.call_getNamedItem("class")) |class_attr| {
                    var all_found = true;
                    var required_iter = std.mem.tokenizeScalar(u8, class_names, ' ');
                    while (required_iter.next()) |required_class| {
                        var found = false;
                        var elem_iter = std.mem.tokenizeScalar(u8, class_attr.value, ' ');
                        while (elem_iter.next()) |elem_class| {
                            if (std.mem.eql(u8, elem_class, required_class)) {
                                found = true;
                                break;
                            }
                        }
                        if (!found) {
                            all_found = false;
                            break;
                        }
                    }

                    if (all_found) {
                        try collection.addElement(elem);
                    }
                }

                try self.collectByClassName(child, class_names, collection);
            }
        }
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
        for (matches.toSlice()) |match| {
            const match_elem: *const Element = @ptrCast(match);
            if (match_elem == self) {
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
                for (matches.toSlice()) |match| {
                    const match_elem: *const Element = @ptrCast(match);
                    if (match_elem == elem) {
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
            return try mutation.preInsert(node, parent, @ptrCast(element));
        } else if (eqlIgnoreCase(where, "afterbegin")) {
            // Return the result of pre-inserting node into element before element's first child
            const first_child = if (element.child_nodes.toSlice().len > 0)
                element.child_nodes.toSlice()[0]
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
            const next_sibling = dom.tree_helpers.getNextSibling(@ptrCast(element));
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
        // Set the text node's data
        self.allocator.free(text.data);
        text.data = try self.allocator.dupe(u8, data);

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
        const registry = shadow_init.customElementRegistry;

        // Step 2: If init["customElementRegistry"] is non-null:
        if (shadow_init.customElementRegistry) |_| {
            // Step 2.1: Set registry to init["customElementRegistry"]
            // Step 2.2: If registry's is scoped is false and registry is not this's node document's custom element registry, then throw NotSupportedError
            // Note: Full validation requires CustomElementRegistry implementation with is_scoped property
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
