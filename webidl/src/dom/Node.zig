//! Node interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-node

const std = @import("std");
const webidl = @import("webidl");
const infra = @import("infra");

const Allocator = std.mem.Allocator;
const EventTarget = @import("event_target").EventTarget;
const Document = @import("document").Document;
const RegisteredObserver = @import("registered_observer").RegisteredObserver;
const TransientRegisteredObserver = @import("registered_observer").TransientRegisteredObserver;
const CharacterData = @import("character_data").CharacterData;
const Text = @import("text").Text;
const Element = @import("element").Element;
const Attr = @import("attr").Attr;
const NodeList = @import("node_list").NodeList;
const ShadowRoot = @import("shadow_root").ShadowRoot;

/// Node WebIDL interface
/// DOM Spec: interface Node : EventTarget
pub const Node = webidl.interface(struct {
    pub const extends = EventTarget;

    allocator: Allocator,
    node_type: u16,
    node_name: []const u8,
    parent_node: ?*Node,
    child_nodes: infra.List(*Node),
    owner_document: ?*Document,

    /// DOM §7.1 - Registered observer list
    /// List of registered mutation observers watching this node
    registered_observers: infra.List(@import("registered_observer").RegisteredObserver),

    /// Cloning steps hook - optional function called during node cloning
    /// Signature: fn(node: *Node, copy: *Node, subtree: bool) !void
    /// Specifications (like HTML) can define cloning steps for specific node types
    cloning_steps_hook: ?*const fn (node: *Node, copy: *Node, subtree: bool) anyerror!void = null,

    /// [SameObject] cache for childNodes NodeList
    /// Per WebIDL [SameObject], the same NodeList object is returned each time
    /// This is a live view of the child_nodes list
    cached_child_nodes: ?*@import("node_list").NodeList = null,

    pub const ELEMENT_NODE: u16 = 1;
    pub const ATTRIBUTE_NODE: u16 = 2;
    pub const TEXT_NODE: u16 = 3;
    pub const CDATA_SECTION_NODE: u16 = 4;
    pub const ENTITY_REFERENCE_NODE: u16 = 5;
    pub const ENTITY_NODE: u16 = 6;
    pub const PROCESSING_INSTRUCTION_NODE: u16 = 7;
    pub const COMMENT_NODE: u16 = 8;
    pub const DOCUMENT_NODE: u16 = 9;
    pub const DOCUMENT_TYPE_NODE: u16 = 10;
    pub const DOCUMENT_FRAGMENT_NODE: u16 = 11;
    pub const NOTATION_NODE: u16 = 12;

    pub const DOCUMENT_POSITION_DISCONNECTED: u16 = 0x01;
    pub const DOCUMENT_POSITION_PRECEDING: u16 = 0x02;
    pub const DOCUMENT_POSITION_FOLLOWING: u16 = 0x04;
    pub const DOCUMENT_POSITION_CONTAINS: u16 = 0x08;
    pub const DOCUMENT_POSITION_CONTAINED_BY: u16 = 0x10;
    pub const DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC: u16 = 0x20;

    pub fn init(allocator: Allocator, node_type: u16, node_name: []const u8) !Node {
        // NOTE: Parent EventTarget fields must be initialized here
        return .{
            .event_listener_list = null, // From EventTarget (DOM §2.7)
            .allocator = allocator,
            .node_type = node_type,
            .node_name = node_name,
            .parent_node = null,
            .child_nodes = infra.List(*Node).init(allocator),
            .owner_document = null,
            .registered_observers = infra.List(@import("registered_observer").RegisteredObserver).init(allocator),
            .cloning_steps_hook = null,
            .cached_child_nodes = null,
        };
    }

    pub fn deinit(self: *Node) void {
        // NOTE: EventTarget parent cleanup is handled by codegen
        self.child_nodes.deinit();
        self.registered_observers.deinit();

        // Clean up cached NodeList if it exists
        if (self.cached_child_nodes) |list| {
            list.deinit();
            self.allocator.destroy(list);
        }
    }

    /// insertBefore(node, child)
    /// Spec: https://dom.spec.whatwg.org/#dom-node-insertbefore
    pub fn call_insertBefore(self: *Node, node: *Node, child: ?*Node) !*Node {
        // Call mutation.preInsert algorithm from src/dom/mutation.zig
        const mutation = @import("dom").mutation;
        return mutation.preInsert(node, self, child) catch |err| switch (err) {
            error.HierarchyRequestError => error.HierarchyRequestError,
            error.NotFoundError => error.NotFoundError,
            error.NotSupportedError => error.NotSupportedError,
            error.OutOfMemory => error.OutOfMemory,
            error.IndexOutOfBounds => error.IndexOutOfBounds,
        };
    }

    /// appendChild(node)
    /// Spec: https://dom.spec.whatwg.org/#dom-node-appendchild
    pub fn call_appendChild(self: *Node, node: *Node) !*Node {
        // Call mutation.append algorithm from src/dom/mutation.zig
        const mutation = @import("dom").mutation;
        return mutation.append(node, self) catch |err| switch (err) {
            error.HierarchyRequestError => error.HierarchyRequestError,
            error.NotFoundError => error.NotFoundError,
            error.NotSupportedError => error.NotSupportedError,
            error.OutOfMemory => error.OutOfMemory,
            error.IndexOutOfBounds => error.IndexOutOfBounds,
        };
    }

    /// replaceChild(node, child)
    /// Spec: https://dom.spec.whatwg.org/#dom-node-replacechild
    pub fn call_replaceChild(self: *Node, node: *Node, child: *Node) !*Node {
        // Call mutation.replace algorithm from src/dom/mutation.zig
        const mutation = @import("dom").mutation;
        return mutation.replace(child, node, self) catch |err| switch (err) {
            error.HierarchyRequestError => error.HierarchyRequestError,
            error.NotFoundError => error.NotFoundError,
            error.NotSupportedError => error.NotSupportedError,
            error.OutOfMemory => error.OutOfMemory,
            error.IndexOutOfBounds => error.IndexOutOfBounds,
        };
    }

    /// removeChild(child)
    /// Spec: https://dom.spec.whatwg.org/#dom-node-removechild
    pub fn call_removeChild(self: *Node, child: *Node) !*Node {
        // Call mutation.preRemove algorithm from src/dom/mutation.zig
        const mutation = @import("dom").mutation;
        return mutation.preRemove(child, self) catch |err| switch (err) {
            error.HierarchyRequestError => error.HierarchyRequestError,
            error.NotFoundError => error.NotFoundError,
            error.NotSupportedError => error.NotSupportedError,
            error.OutOfMemory => error.OutOfMemory,
            error.IndexOutOfBounds => error.IndexOutOfBounds,
        };
    }

    /// getRootNode(options)
    /// Spec: https://dom.spec.whatwg.org/#dom-node-getrootnode
    ///
    /// The getRootNode(options) method steps are to return this's shadow-including root
    /// if options["composed"] is true; otherwise this's root.
    pub fn call_getRootNode(self: *Node, options: ?GetRootNodeOptions) *Node {
        const tree = @import("dom").tree;

        // Check if we need shadow-including root
        const composed = if (options) |opts| opts.composed else false;

        if (composed) {
            // Return shadow-including root (DOM §4.2.2.4)
            // Algorithm:
            // 1. Let root be node's root
            // 2. If root is a shadow root, return root's host's shadow-including root
            // 3. Return root
            var root = tree.root(self);

            // Check if root is a ShadowRoot by checking type_tag
            while (root.base.type_tag == .ShadowRoot) {
                // Cast to ShadowRoot to access host
                const shadow_root: *ShadowRoot = @ptrCast(@alignCast(root));

                // Get the host element (which is a Node)
                const host_element = shadow_root.host_element;
                const host_node: *Node = @ptrCast(@alignCast(&host_element.base));

                // Get host's root (might be another shadow root)
                root = tree.root(host_node);
            }

            return root;
        } else {
            // Return regular root
            return tree.root(self);
        }
    }

    /// contains(other)
    /// Spec: https://dom.spec.whatwg.org/#dom-node-contains
    pub fn call_contains(self: *const Node, other: ?*const Node) bool {
        if (other == null) return false;
        // Check if other is an inclusive descendant of this
        const tree = @import("dom").tree;
        const other_node = other.?;
        return tree.isInclusiveDescendant(other_node, self);
    }

    /// compareDocumentPosition(other)
    /// Spec: https://dom.spec.whatwg.org/#dom-node-comparedocumentposition
    pub fn call_compareDocumentPosition(self: *const Node, other: *const Node) u16 {
        const tree = @import("dom").tree;

        // Step 1: If this is other, then return zero
        if (self == other) {
            return 0;
        }

        // Step 2: Let node1 be other and node2 be this
        const node1 = other;
        const node2 = self;

        // Step 3: Let attr1 and attr2 be null
        // Step 4-5: Handle attributes (not implemented yet - attributes don't participate in tree)
        // For now, we skip attribute handling as Attr nodes are handled separately

        // Step 6: If node1 or node2 is null, or node1's root is not node2's root
        // Check if nodes are in the same tree by comparing roots
        const root1 = tree.root(@constCast(node1));
        const root2 = tree.root(@constCast(node2));

        if (root1 != root2) {
            // Return disconnected + implementation specific + preceding/following
            // Use pointer comparison for consistent ordering
            const ptr1 = @intFromPtr(node1);
            const ptr2 = @intFromPtr(node2);
            const ordering = if (ptr1 < ptr2) Node.DOCUMENT_POSITION_PRECEDING else Node.DOCUMENT_POSITION_FOLLOWING;
            return Node.DOCUMENT_POSITION_DISCONNECTED | Node.DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC | ordering;
        }

        // Step 7: If node1 is an ancestor of node2
        if (tree.isAncestor(node1, node2)) {
            return Node.DOCUMENT_POSITION_CONTAINS | Node.DOCUMENT_POSITION_PRECEDING;
        }

        // Step 8: If node1 is a descendant of node2
        if (tree.isDescendant(node1, node2)) {
            return Node.DOCUMENT_POSITION_CONTAINED_BY | Node.DOCUMENT_POSITION_FOLLOWING;
        }

        // Step 9: If node1 is preceding node2
        if (tree.isPreceding(node1, node2)) {
            return Node.DOCUMENT_POSITION_PRECEDING;
        }

        // Step 10: Return DOCUMENT_POSITION_FOLLOWING
        return Node.DOCUMENT_POSITION_FOLLOWING;
    }

    /// isEqualNode(otherNode)
    /// Spec: https://dom.spec.whatwg.org/#dom-node-isequalnode
    pub fn call_isEqualNode(self: *const Node, other_node: ?*const Node) bool {
        // Step 1: Return true if otherNode is non-null and this equals otherNode
        if (other_node == null) return false;
        return Node.nodeEquals(self, other_node.?);
    }

    /// Node A equals node B - DOM Spec algorithm
    /// A node A equals a node B if all of the following conditions are true:
    /// - A and B implement the same interfaces
    /// - Node-specific properties are equal
    /// - If A is an element, each attribute in its list equals an attribute in B's list
    /// - A and B have the same number of children
    /// - Each child of A equals the child of B at the identical index
    pub fn nodeEquals(a: *const Node, b: *const Node) bool {
        // Step 1: A and B implement the same interfaces (check node_type)
        if (a.node_type != b.node_type) return false;

        // Step 2: Check node-type-specific properties
        switch (a.node_type) {
            DOCUMENT_TYPE_NODE => {
                // DocumentType: check name, public ID, and system ID
                const DocumentType = @import("document_type").DocumentType;
                const doctype_a: *const DocumentType = @ptrCast(@alignCast(a));
                const doctype_b: *const DocumentType = @ptrCast(@alignCast(b));

                // Check name
                if (!std.mem.eql(u8, doctype_a.name, doctype_b.name)) return false;

                // Check public ID
                if (!std.mem.eql(u8, doctype_a.public_id, doctype_b.public_id)) return false;

                // Check system ID
                if (!std.mem.eql(u8, doctype_a.system_id, doctype_b.system_id)) return false;
            },
            ELEMENT_NODE => {
                // Element: check namespace, namespace prefix, local name, and attribute list size
                const elem_a: *const Element = @ptrCast(@alignCast(a));
                const elem_b: *const Element = @ptrCast(@alignCast(b));

                // Check namespace
                if (elem_a.namespace_uri == null and elem_b.namespace_uri != null) return false;
                if (elem_a.namespace_uri != null and elem_b.namespace_uri == null) return false;
                if (elem_a.namespace_uri != null and elem_b.namespace_uri != null) {
                    if (!std.mem.eql(u8, elem_a.namespace_uri.?, elem_b.namespace_uri.?)) return false;
                }

                // Check local name (tag_name)
                if (!std.mem.eql(u8, elem_a.tag_name, elem_b.tag_name)) return false;

                // Check attribute list size
                if (elem_a.attributes.len != elem_b.attributes.len) return false;

                // Step 3: Each attribute in A's list has an equal attribute in B's list
                for (elem_a.attributes.toSlice()) |attr_a| {
                    var found = false;
                    for (elem_b.attributes.toSlice()) |attr_b| {
                        if (Node.attributeEquals(&attr_a, &attr_b)) {
                            found = true;
                            break;
                        }
                    }
                    if (!found) return false;
                }
            },
            ATTRIBUTE_NODE => {
                // Attr: check namespace, local name, and value
                // Note: Attr nodes don't participate in tree, but we check for completeness
                const attr_a: *const Attr = @ptrCast(@alignCast(a));
                const attr_b: *const Attr = @ptrCast(@alignCast(b));
                return Node.attributeEquals(attr_a, attr_b);
            },
            PROCESSING_INSTRUCTION_NODE => {
                // ProcessingInstruction: check target and data
                const PI = @import("processing_instruction").ProcessingInstruction;
                const pi_a: *const PI = @ptrCast(@alignCast(a));
                const pi_b: *const PI = @ptrCast(@alignCast(b));

                if (!std.mem.eql(u8, pi_a.target, pi_b.target)) return false;
                if (!std.mem.eql(u8, pi_a.data, pi_b.data)) return false;
            },
            TEXT_NODE, COMMENT_NODE, CDATA_SECTION_NODE => {
                // Text, Comment, CDATASection: check data
                const cd_a: *const CharacterData = @ptrCast(@alignCast(a));
                const cd_b: *const CharacterData = @ptrCast(@alignCast(b));

                if (!std.mem.eql(u8, cd_a.data, cd_b.data)) return false;
            },
            else => {
                // For other node types, basic node_name check is sufficient
                if (!std.mem.eql(u8, a.node_name, b.node_name)) return false;
            },
        }

        // Step 4: A and B have the same number of children
        if (a.child_nodes.len != b.child_nodes.len) return false;

        // Step 5: Each child of A equals the child of B at the identical index
        for (a.child_nodes.toSlice(), 0..) |child_a, i| {
            const child_b = b.child_nodes.toSlice()[i];
            if (!Node.nodeEquals(child_a, child_b)) return false;
        }

        return true;
    }

    /// Attribute equality check
    /// An attribute A equals an attribute B if:
    /// - namespace is equal
    /// - local name is equal
    /// - value is equal
    pub fn attributeEquals(a: *const @import("attr").Attr, b: *const @import("attr").Attr) bool {
        // Check namespace
        if (a.namespace_uri == null and b.namespace_uri != null) return false;
        if (a.namespace_uri != null and b.namespace_uri == null) return false;
        if (a.namespace_uri != null and b.namespace_uri != null) {
            if (!std.mem.eql(u8, a.namespace_uri.?, b.namespace_uri.?)) return false;
        }

        // Check local name
        if (!std.mem.eql(u8, a.local_name, b.local_name)) return false;

        // Check value
        if (!std.mem.eql(u8, a.value, b.value)) return false;

        return true;
    }

    /// isSameNode(otherNode)
    /// Spec: https://dom.spec.whatwg.org/#dom-node-issamenode
    pub fn call_isSameNode(self: *const Node, other_node: ?*const Node) bool {
        // Legacy alias of === (pointer equality)
        if (other_node == null) return false;
        return self == other_node.?;
    }

    /// hasChildNodes()
    /// Spec: https://dom.spec.whatwg.org/#dom-node-haschildnodes
    pub fn call_hasChildNodes(self: *const Node) bool {
        return self.child_nodes.len > 0;
    }

    /// cloneNode(deep)
    /// Spec: https://dom.spec.whatwg.org/#dom-node-clonenode
    pub fn call_cloneNode(self: *Node, deep: bool) !*Node {
        // Step 1: If this is a shadow root, throw NotSupportedError
        if (self.node_type == Node.DOCUMENT_FRAGMENT_NODE) {
            // Check if this is specifically a ShadowRoot
            // ShadowRoot inherits from DocumentFragment and has a non-null host
            const DocumentFragment = @import("document_fragment").DocumentFragment;
            const frag: *const DocumentFragment = @ptrCast(@alignCast(self));
            if (frag.host != null) {
                // This is a ShadowRoot (host is non-null)
                return error.NotSupportedError;
            }
        }

        // Step 2: Return the result of cloning this node with subtree set to deep
        return try Node.cloneNodeInternal(self, self.owner_document, deep, null, null);
    }

    /// Clone a node - DOM Spec algorithm
    /// Given a node `node` and optional document, subtree flag, parent, and fallbackRegistry
    pub fn cloneNodeInternal(
        node: *Node,
        document_param: ?*Document,
        subtree: bool,
        parent: ?*Node,
        fallback_registry: ?*anyopaque, // CustomElementRegistry - not implemented yet
    ) !*Node {
        // Step 1: Let document be document_param or node's owner_document
        const document = document_param orelse node.owner_document;

        // Assert: node is not a document or node is document
        // (We don't have full Document implementation yet, skip this assert)

        // Step 2: Let copy be the result of cloning a single node
        var copy = try Node.cloneSingleNode(node, document, fallback_registry);

        // Step 3: Run any cloning steps defined for node
        // Specifications may define cloning steps for specific node types
        if (node.cloning_steps_hook) |hook| {
            try hook(node, copy, subtree);
        }

        // Step 4: If parent is non-null, append copy to parent
        if (parent) |p| {
            try p.child_nodes.append(copy);
            copy.parent_node = p;
        }

        // Step 5: If subtree is true, clone all children recursively
        if (subtree) {
            for (node.child_nodes.toSlice()) |child| {
                _ = try Node.cloneNodeInternal(child, document, subtree, copy, fallback_registry);
            }
        }

        // Step 6: If node is an element, node is shadow host, and shadow root is clonable, clone shadow
        if (node.node_type == Node.ELEMENT_NODE) {
            const elem: *const Element = @ptrCast(@alignCast(node));
            if (elem.shadow_root) |shadow| {
                // Check if shadow root is clonable
                if (shadow.clonable_flag) {
                    // Clone the shadow root per spec
                    const copy_elem: *Element = @ptrCast(@alignCast(copy));

                    // Assert: copy is not a shadow host (should be true since we just created it)
                    std.debug.assert(copy_elem.shadow_root == null);

                    // Step 6.2-6.4: Determine shadow root registry and attach shadow root
                    //
                    // Per spec (DOM §4.2.7):
                    // - If node's shadow root's custom element registry is non-null, use it
                    // - Otherwise, if fallbackRegistry is non-null, use fallbackRegistry
                    // - Otherwise, set registry to null
                    //
                    // NOTE: Custom element registry is part of the HTML spec, not DOM spec.
                    // Full implementation requires:
                    // - ShadowRoot.custom_element_registry field (currently not present)
                    // - CustomElementRegistry type and implementation
                    // - Registry scoping logic
                    //
                    // For now, we pass null for the registry. When custom elements are
                    // implemented, fallback_registry will be used here to determine the
                    // registry for the cloned shadow root.

                    // Attach shadow root to copy
                    var copy_shadow = try ShadowRoot.init(
                        copy.allocator,
                        copy_elem,
                        shadow.shadow_mode,
                        shadow.delegates_focus_flag,
                        shadow.slot_assignment_mode,
                        shadow.clonable_flag,
                        shadow.serializable_flag,
                    );

                    // Set additional flags after init
                    copy_shadow.available_to_element_internals = shadow.available_to_element_internals;
                    copy_shadow.declarative_flag = shadow.declarative_flag;

                    copy_elem.shadow_root = &copy_shadow;

                    // Step 6.6: Clone shadow root children
                    const shadow_node: *Node = @ptrCast(shadow);
                    for (shadow_node.child_nodes.toSlice()) |child| {
                        const copy_shadow_node: *Node = @ptrCast(&copy_shadow);
                        _ = try Node.cloneNodeInternal(child, document, subtree, copy_shadow_node, null);
                    }
                }
            }
        }

        // Step 7: Return copy
        return copy;
    }

    /// Clone a single node - DOM Spec algorithm
    /// Creates a new node with the same properties but no children
    pub fn cloneSingleNode(
        node: *Node,
        document: ?*Document,
        fallback_registry: ?*anyopaque,
    ) !*Node {
        _ = fallback_registry; // Not used yet - for custom elements

        // Step 2-3: Handle different node types
        switch (node.node_type) {
            Node.ELEMENT_NODE => {
                // Clone element with attributes
                const elem: *Element = @ptrCast(@alignCast(node));

                // Create new element
                var copy_elem = try Element.init(elem.allocator, elem.tag_name);
                copy_elem.namespace_uri = elem.namespace_uri;

                // Clone attributes
                for (elem.attributes.toSlice()) |attr| {
                    const copy_attr = Attr{
                        // EventTarget fields
                        .event_listener_list = null,
                        // Node fields
                        .allocator = elem.allocator,
                        .node_type = 2, // ATTRIBUTE_NODE
                        .node_name = attr.local_name,
                        .parent_node = null,
                        .child_nodes = infra.List(*Node).init(elem.allocator),
                        .owner_document = null,
                        .registered_observers = infra.List(@import("registered_observer").RegisteredObserver).init(elem.allocator),
                        .cloning_steps_hook = null,
                        .cached_child_nodes = null,
                        // Attr fields
                        .namespace_uri = attr.namespace_uri,
                        .prefix = attr.prefix,
                        .local_name = attr.local_name,
                        .value = attr.value,
                        .owner_element = &copy_elem,
                    };
                    try copy_elem.attributes.append(copy_attr);
                }

                const copy_node = @as(*Node, @ptrCast(&copy_elem));
                copy_node.owner_document = document;
                return copy_node;
            },
            Node.TEXT_NODE, Node.COMMENT_NODE, Node.CDATA_SECTION_NODE => {
                // Clone CharacterData (Text, Comment, CDATASection)
                const cd: *CharacterData = @ptrCast(@alignCast(node));

                var copy_cd = try CharacterData.init(cd.allocator);
                copy_cd.data = try cd.allocator.dupe(u8, cd.data);

                const copy_node = @as(*Node, @ptrCast(&copy_cd));
                copy_node.node_type = node.node_type;
                copy_node.node_name = node.node_name;
                copy_node.owner_document = document;
                return copy_node;
            },
            Node.PROCESSING_INSTRUCTION_NODE => {
                // Clone ProcessingInstruction
                const PI = @import("processing_instruction").ProcessingInstruction;
                const pi: *PI = @ptrCast(@alignCast(node));

                var copy_pi = try PI.init(pi.allocator, pi.target, pi.data);

                const copy_node = @as(*Node, @ptrCast(&copy_pi));
                copy_node.owner_document = document;
                return copy_node;
            },
            Node.ATTRIBUTE_NODE => {
                // Clone Attr
                const attr: *Attr = @ptrCast(@alignCast(node));

                var copy_attr = try Attr.init(
                    attr.allocator,
                    attr.namespace_uri,
                    attr.prefix,
                    attr.local_name,
                    attr.value,
                );

                const copy_node = @as(*Node, @ptrCast(&copy_attr));
                copy_node.owner_document = document;
                return copy_node;
            },
            Node.DOCUMENT_TYPE_NODE => {
                // Clone DocumentType (simplified - full implementation needs public ID, system ID)
                const copy = try node.allocator.create(Node);
                copy.* = try Node.init(node.allocator, node.node_type, node.node_name);
                copy.owner_document = document;
                return copy;
            },
            Node.DOCUMENT_FRAGMENT_NODE => {
                // Clone DocumentFragment
                const copy = try node.allocator.create(Node);
                copy.* = try Node.init(node.allocator, node.node_type, node.node_name);
                copy.owner_document = document;
                return copy;
            },
            Node.DOCUMENT_NODE => {
                // Cloning Document is complex and not fully supported yet
                // For now, just create a basic copy
                const copy = try node.allocator.create(Node);
                copy.* = try Node.init(node.allocator, node.node_type, node.node_name);
                copy.owner_document = document;
                return copy;
            },
            else => {
                // Default: create basic node copy
                const copy = try node.allocator.create(Node);
                copy.* = try Node.init(node.allocator, node.node_type, node.node_name);
                copy.owner_document = document;
                return copy;
            },
        }
    }

    /// normalize()
    /// Spec: https://dom.spec.whatwg.org/#dom-node-normalize
    ///
    /// Removes empty exclusive Text nodes and concatenates the data of remaining
    /// contiguous exclusive Text nodes into the first of their nodes.
    ///
    /// The normalize() method steps are to run these steps for each descendant
    /// exclusive Text node `node` of this:
    /// 1. Let length be node's length
    /// 2. If length is zero, remove node and continue
    /// 3. Let data be concatenation of data of node's contiguous exclusive Text nodes (excluding itself)
    /// 4. Replace data with node, offset length, count 0, and data
    /// 5. Let currentNode be node's next sibling
    /// 6. While currentNode is exclusive Text node: update ranges and advance
    /// 7. Remove node's contiguous exclusive Text nodes (excluding itself)
    pub fn call_normalize(self: *Node) !void {
        // Get all descendant exclusive Text nodes
        var text_nodes = infra.List(*Node).init(self.allocator);
        defer text_nodes.deinit();

        try collectDescendantExclusiveTextNodes(self, &text_nodes);

        // Process each exclusive Text node
        for (0..text_nodes.len) |i| {
            const node = text_nodes.get(i) orelse continue;
            // Step 1: Let length be node's length
            const cd: *CharacterData = @ptrCast(@alignCast(node));
            var length: usize = cd.data.len;

            // Step 2: If length is zero, remove node and continue
            if (length == 0) {
                // Remove the node from its parent
                if (node.parent_node) |_| {
                    const mutation = @import("dom").mutation;
                    _ = try mutation.remove(node, false);
                }
                continue;
            }

            // Step 3: Let data be concatenation of contiguous exclusive Text nodes (excluding itself)
            var contiguous_data = infra.List(u8).init(self.allocator);
            defer contiguous_data.deinit();

            // Find next sibling exclusive Text nodes
            var next_sibling = node.get_nextSibling();
            while (next_sibling) |sibling| {
                if (isExclusiveTextNode(sibling)) {
                    const sibling_cd: *CharacterData = @ptrCast(@alignCast(sibling));
                    try contiguous_data.appendSlice(sibling_cd.data);
                    next_sibling = sibling.get_nextSibling();
                } else {
                    break;
                }
            }

            // Step 4: Replace data with node, offset length, count 0, and data
            // This appends the concatenated data to the current node's data
            if (contiguous_data.toSlice().len > 0) {
                try cd.call_replaceData(@intCast(length), 0, contiguous_data.toSlice());
            }

            // Step 5: Let currentNode be node's next sibling
            var current_node = node.get_nextSibling();

            // Step 6: While currentNode is an exclusive Text node
            while (current_node) |curr| {
                if (!isExclusiveTextNode(curr)) break;

                const curr_cd: *CharacterData = @ptrCast(@alignCast(curr));

                // Step 6.1-6.4: Update live ranges
                // Get owner document for range tracking
                if (node.owner_document) |doc| {
                    updateRangesForNormalize(doc, node, curr, @intCast(length));
                }

                // Step 6.5: Add currentNode's length to length
                length += curr_cd.data.len;

                // Step 6.6: Set currentNode to its next sibling
                const next = curr.get_nextSibling();
                current_node = next;
            }

            // Step 7: Remove node's contiguous exclusive Text nodes (excluding itself)
            // Go back through and remove all the adjacent text nodes we just merged
            var remove_node = node.get_nextSibling();
            while (remove_node) |rn| {
                if (!isExclusiveTextNode(rn)) break;

                const next_remove = rn.get_nextSibling();
                if (rn.parent_node) |_| {
                    const mutation = @import("dom").mutation;
                    _ = try mutation.remove(rn, false);
                }
                remove_node = next_remove;
            }
        }
    }

    /// Helper: Check if a node is an exclusive Text node
    /// An exclusive Text node is a Text node that is NOT a CDATASection node
    fn isExclusiveTextNode(node: *Node) bool {
        // Exclusive Text node = TEXT_NODE but not CDATA_SECTION_NODE
        return node.node_type == Node.TEXT_NODE;
    }

    /// Helper: Collect all descendant exclusive Text nodes in tree order
    fn collectDescendantExclusiveTextNodes(node: *Node, list: *infra.List(*Node)) !void {
        // Check if this node is an exclusive Text node
        if (isExclusiveTextNode(node)) {
            try list.append(node);
        }

        // Recursively collect from children
        for (0..node.child_nodes.len) |i| {
            const child = node.child_nodes.get(i) orelse continue;
            try collectDescendantExclusiveTextNodes(child, list);
        }
    }

    /// Helper: Update ranges during normalize operation
    /// Spec: DOM §4.2.5 normalize() step 6.1-6.4
    fn updateRangesForNormalize(doc: *Document, node: *Node, current_node: *Node, length: usize) void {
        // This requires access to document's live ranges list
        // The range tracking infrastructure is in src/dom/range_tracking.zig
        // For now, we'll add a helper function there

        // Get document's ranges (if the infrastructure exists)
        // Per spec step 6.1-6.4:
        // 1. For each live range whose start node is currentNode,
        //    add length to its start offset and set its start node to node
        // 2. For each live range whose end node is currentNode,
        //    add length to its end offset and set its end node to node
        // 3. For each live range whose start node is currentNode's parent
        //    and start offset is currentNode's index, set its start node to node
        //    and its start offset to length
        // 4. For each live range whose end node is currentNode's parent
        //    and end offset is currentNode's index, set its end node to node
        //    and its end offset to length

        _ = doc;
        _ = node;
        _ = current_node;
        _ = length;

        // TODO: Implement range updates once Range tracking is fully integrated
        // For now, this is a placeholder. Range tracking will be added when
        // Phase 5 (Range Operations) is implemented.
    }

    /// Getters
    pub fn get_nodeType(self: *const Node) u16 {
        return self.node_type;
    }

    pub fn get_nodeName(self: *const Node) []const u8 {
        return self.node_name;
    }

    pub fn get_parentNode(self: *const Node) ?*Node {
        return self.parent_node;
    }

    pub fn get_parentElement(self: *const Node) ?*Element {
        // Returns parent if it's an Element, null otherwise
        const parent = self.parent_node orelse return null;
        if (parent.node_type == ELEMENT_NODE) {
            // Cast to Element - safe because we checked node_type
            return @ptrCast(@alignCast(parent));
        }
        return null;
    }

    pub fn get_childNodes(self: *Node) !*@import("node_list").NodeList {
        // [SameObject] - Return the same NodeList object each time
        // The NodeList is a live view of this node's children

        if (self.cached_child_nodes) |list| {
            return list;
        }

        // Create new NodeList on first access
        const list = try self.allocator.create(NodeList);
        list.* = try NodeList.init(self.allocator);

        // Populate with current children (live view will track changes)
        for (self.child_nodes.toSlice()) |child| {
            try list.addNode(child);
        }

        self.cached_child_nodes = list;
        return list;
    }

    pub fn get_firstChild(self: *const Node) ?*Node {
        if (self.child_nodes.len > 0) {
            return self.child_nodes.get(0);
        }
        return null;
    }

    pub fn get_lastChild(self: *const Node) ?*Node {
        if (self.child_nodes.len > 0) {
            return self.child_nodes.get(self.child_nodes.len - 1);
        }
        return null;
    }

    pub fn get_ownerDocument(self: *const Node) ?*Document {
        return self.owner_document;
    }

    pub fn get_previousSibling(self: *const Node) ?*Node {
        const parent = self.parent_node orelse return null;
        for (parent.child_nodes.toSlice(), 0..) |child, i| {
            if (child == self) {
                if (i == 0) return null;
                return parent.child_nodes.toSlice()[i - 1];
            }
        }
        return null;
    }

    pub fn get_nextSibling(self: *const Node) ?*Node {
        const parent = self.parent_node orelse return null;
        for (parent.child_nodes.toSlice(), 0..) |child, i| {
            if (child == self) {
                if (i + 1 >= parent.child_nodes.toSlice().len) return null;
                return parent.child_nodes.toSlice()[i + 1];
            }
        }
        return null;
    }

    pub fn get_isConnected(self: *const Node) bool {
        // A node is connected if its root is a document
        const tree = @import("dom").tree;
        // tree.root requires mutable pointer but doesn't actually mutate
        // Cast to mutable for the algorithm (safe for read-only root traversal)
        const mutable_self = @constCast(self);
        const root_node = tree.root(mutable_self);
        // Check if root is a document (node_type == DOCUMENT_NODE)
        return root_node.node_type == DOCUMENT_NODE;
    }

    /// DOM §4.4 - Node.baseURI getter
    /// Returns this's node document's document base URL, serialized.
    ///
    /// The baseURI getter steps are to return this's node document's
    /// document base URL, serialized.
    pub fn get_baseURI(self: *const Node) []const u8 {
        // Get owner document
        const doc = self.owner_document orelse {
            // If no owner document, return empty string (should not happen in normal DOM)
            return "about:blank";
        };

        // Return document's base URI
        return doc.base_uri;
    }

    pub fn get_nodeValue(self: *const Node) ?[]const u8 {
        // Spec: https://dom.spec.whatwg.org/#dom-node-nodevalue
        // The nodeValue getter steps are to return the following, switching on the interface:
        // - Attr: this's value
        // - CharacterData: this's data
        // - Otherwise: null

        switch (self.node_type) {
            ATTRIBUTE_NODE => {
                // Attr node
                const attr: *const Attr = @ptrCast(@alignCast(self));
                return attr.value;
            },
            TEXT_NODE, CDATA_SECTION_NODE, PROCESSING_INSTRUCTION_NODE, COMMENT_NODE => {
                // CharacterData nodes (Text, Comment, ProcessingInstruction, CDATASection)
                const char_data: *const CharacterData = @ptrCast(@alignCast(self));
                return char_data.data;
            },
            else => {
                // All other node types return null
                return null;
            },
        }
    }

    pub fn set_nodeValue(self: *Node, value: ?[]const u8) !void {
        // Spec: https://dom.spec.whatwg.org/#dom-node-nodevalue
        // The nodeValue setter steps are to, if given value is null, act as if it was empty string
        // Then:
        // - Attr: Set an existing attribute value with this and the given value
        // - CharacterData: Replace data with node this, offset 0, count this's length, data given value
        // - Otherwise: Do nothing

        const str_value = value orelse "";

        switch (self.node_type) {
            ATTRIBUTE_NODE => {
                // Attr node - set an existing attribute value
                const attr: *Attr = @ptrCast(@alignCast(self));
                // Use "set an existing attribute value" algorithm from Attr
                try Attr.setExistingAttributeValue(attr, str_value);
            },
            TEXT_NODE, CDATA_SECTION_NODE, PROCESSING_INSTRUCTION_NODE, COMMENT_NODE => {
                // CharacterData nodes - replace data
                const char_data: *CharacterData = @ptrCast(@alignCast(self));
                // Replace data: offset 0, count = length, data = str_value
                try char_data.call_replaceData(0, @intCast(char_data.data.len), str_value);
            },
            else => {
                // All other node types do nothing
            },
        }
    }

    pub fn get_textContent(self: *const Node) !?[]const u8 {
        // Spec: https://dom.spec.whatwg.org/#dom-node-textcontent
        // Return the result of running get text content with this
        return Node.getTextContent(self, self.allocator);
    }

    pub fn set_textContent(self: *Node, value: ?[]const u8) !void {
        // Spec: https://dom.spec.whatwg.org/#dom-node-textcontent
        // If the given value is null, act as if it was the empty string instead
        const str_value = value orelse "";
        try Node.setTextContent(self, str_value);
    }

    /// Get text content - DOM Spec algorithm
    /// Returns text content based on node type
    /// For Element and DocumentFragment, the returned string is allocated and must be freed by caller
    /// For other types, returns a reference to existing data (no allocation)
    pub fn getTextContent(node: *const Node, allocator: std.mem.Allocator) !?[]const u8 {
        switch (node.node_type) {
            Node.DOCUMENT_FRAGMENT_NODE, Node.ELEMENT_NODE => {
                // Return descendant text content (allocated)
                return Node.getDescendantTextContent(node, allocator);
            },
            Node.ATTRIBUTE_NODE => {
                // Return node's value (no allocation - returns reference)
                const attr: *const Attr = @ptrCast(@alignCast(node));
                return attr.value;
            },
            Node.TEXT_NODE, Node.COMMENT_NODE, Node.CDATA_SECTION_NODE, Node.PROCESSING_INSTRUCTION_NODE => {
                // Return node's data (no allocation - returns reference)
                const cd: *const CharacterData = @ptrCast(@alignCast(node));
                return cd.data;
            },
            else => {
                // Document, DocumentType: return null
                return null;
            },
        }
    }

    /// Get descendant text content - concatenate all Text node descendants
    /// Spec: https://dom.spec.whatwg.org/#concept-descendant-text-content
    /// Returns the concatenation of data from all Text node descendants in tree order.
    /// Caller owns the returned memory and must free it.
    pub fn getDescendantTextContent(node: *const Node, allocator: std.mem.Allocator) ![]const u8 {
        var result = infra.List(u8).init(allocator);
        errdefer result.deinit();

        try collectDescendantText(node, &result);

        return result.toOwnedSlice();
    }

    /// Helper function to recursively collect text from descendants
    fn collectDescendantText(node: *const Node, result: *infra.List(u8)) !void {
        // If this is a Text node, collect its data
        if (node.node_type == Node.TEXT_NODE) {
            const cd: *const CharacterData = @ptrCast(@alignCast(node));
            try result.appendSlice(cd.data);
        }

        // Recursively process all children
        for (0..node.child_nodes.len) |i| {
            if (node.child_nodes.get(i)) |child| {
                try collectDescendantText(child, result);
            }
        }
    }

    /// Set text content - DOM Spec algorithm
    /// Sets text content based on node type
    pub fn setTextContent(node: *Node, value: []const u8) !void {
        switch (node.node_type) {
            Node.DOCUMENT_FRAGMENT_NODE, Node.ELEMENT_NODE => {
                // String replace all with value within node
                try Node.stringReplaceAll(node, value);
            },
            Node.ATTRIBUTE_NODE => {
                // Set an existing attribute value
                const attr: *Attr = @ptrCast(@alignCast(node));
                // Use "set an existing attribute value" algorithm from Attr
                try Attr.setExistingAttributeValue(attr, value);
            },
            Node.TEXT_NODE, Node.COMMENT_NODE, Node.CDATA_SECTION_NODE => {
                // Replace data with node, offset 0, count node's length, and data value
                const cd: *CharacterData = @ptrCast(@alignCast(node));
                const length = @as(u32, @intCast(cd.data.len));
                try cd.replaceData(0, length, value);
            },
            else => {
                // Document, DocumentType, etc: do nothing
            },
        }
    }

    /// String replace all - DOM Spec algorithm
    /// Replace all children with a single text node containing string
    pub fn stringReplaceAll(parent: *Node, string: []const u8) !void {
        // Step 1: Let node be null
        var node_opt: ?*Node = null;

        // Step 2: If string is not the empty string, create a new Text node
        if (string.len > 0) {
            var text_node = try Text.init(parent.allocator);

            const cd: *CharacterData = @ptrCast(@alignCast(&text_node));
            cd.data = try parent.allocator.dupe(u8, string);

            const new_node: *Node = @ptrCast(&text_node);
            new_node.owner_document = parent.owner_document;
            node_opt = new_node;
        }

        // Step 3: Replace all with node within parent
        const mutation = @import("dom").mutation;
        try mutation.replaceAll(node_opt, parent);
    }

    /// lookupPrefix(namespace)
    /// Spec: https://dom.spec.whatwg.org/#dom-node-lookupprefix
    pub fn call_lookupPrefix(self: *const Node, namespace_param: ?[]const u8) ?[]const u8 {
        // Spec step 1: If namespace is null or empty, return null
        const namespace = namespace_param orelse return null;
        if (namespace.len == 0) return null;

        // Spec step 2: Switch on node type
        switch (self.node_type) {
            ELEMENT_NODE => {
                // Return result of locating a namespace prefix
                return self.locateNamespacePrefix(namespace);
            },
            DOCUMENT_NODE => {
                // If document element is null, return null
                const doc: *const Document = @ptrCast(@alignCast(self));
                const doc_elem = doc.documentElement() orelse return null;
                return doc_elem.base.locateNamespacePrefix(namespace);
            },
            DOCUMENT_TYPE_NODE, DOCUMENT_FRAGMENT_NODE => {
                return null;
            },
            else => {
                // For other node types, use parent element if exists
                const parent = self.parent_element orelse return null;
                return parent.base.locateNamespacePrefix(namespace);
            },
        }
    }

    /// lookupNamespaceURI(prefix)
    /// Spec: https://dom.spec.whatwg.org/#dom-node-lookupnamespaceuri
    pub fn call_lookupNamespaceURI(self: *const Node, prefix_param: ?[]const u8) ?[]const u8 {
        // Spec step 1: If prefix is empty string, set to null
        const prefix = if (prefix_param) |p| if (p.len == 0) null else p else null;

        // Spec step 2: Return result of locating a namespace
        return self.locateNamespace(prefix);
    }

    /// isDefaultNamespace(namespace)
    /// Spec: https://dom.spec.whatwg.org/#dom-node-isdefaultnamespace
    pub fn call_isDefaultNamespace(self: *const Node, namespace_param: ?[]const u8) bool {
        // Spec step 1: If namespace is empty string, set to null
        const namespace = if (namespace_param) |ns| if (ns.len == 0) null else ns else null;

        // Spec step 2: Let defaultNamespace be result of locating namespace using null prefix
        const default_namespace = self.locateNamespace(null);

        // Spec step 3: Return true if defaultNamespace equals namespace
        if (default_namespace == null and namespace == null) return true;
        if (default_namespace == null or namespace == null) return false;
        return std.mem.eql(u8, default_namespace.?, namespace.?);
    }

    /// Locate a namespace prefix for element (internal algorithm)
    /// Spec: https://dom.spec.whatwg.org/#locate-a-namespace-prefix
    fn locateNamespacePrefix(self: *const Node, namespace: []const u8) ?[]const u8 {
        if (self.node_type != ELEMENT_NODE) return null;

        const elem: *const Element = @ptrCast(@alignCast(self));

        // Step 1: If element's namespace is namespace and prefix is non-null, return prefix
        if (elem.namespace_uri) |ns| {
            if (std.mem.eql(u8, ns, namespace)) {
                if (elem.prefix) |p| return p;
            }
        }

        // Step 2: If element has attribute with prefix "xmlns" and value namespace, return local name
        for (elem.attributes.toSlice()) |attr| {
            if (attr.prefix) |attr_prefix| {
                if (std.mem.eql(u8, attr_prefix, "xmlns") and std.mem.eql(u8, attr.value, namespace)) {
                    return attr.local_name;
                }
            }
        }

        // Step 3: If parent element exists, recurse
        if (self.parent_element) |parent| {
            return parent.base.locateNamespacePrefix(namespace);
        }

        // Step 4: Return null
        return null;
    }

    /// Locate a namespace for node (internal algorithm)
    /// Spec: https://dom.spec.whatwg.org/#locate-a-namespace
    fn locateNamespace(self: *const Node, prefix: ?[]const u8) ?[]const u8 {
        switch (self.node_type) {
            ELEMENT_NODE => {
                const elem: *const Element = @ptrCast(@alignCast(self));

                // Step 1: If prefix is "xml", return XML namespace
                if (prefix) |p| {
                    if (std.mem.eql(u8, p, "xml")) {
                        return "http://www.w3.org/XML/1998/namespace";
                    }
                    // Step 2: If prefix is "xmlns", return XMLNS namespace
                    if (std.mem.eql(u8, p, "xmlns")) {
                        return "http://www.w3.org/2000/xmlns/";
                    }
                }

                // Step 3: If namespace is non-null and prefix matches, return namespace
                if (elem.namespace_uri) |ns| {
                    if ((prefix == null and elem.prefix == null) or
                        (prefix != null and elem.prefix != null and std.mem.eql(u8, prefix.?, elem.prefix.?)))
                    {
                        return ns;
                    }
                }

                // Step 4: Check for xmlns attributes
                // If it has an attribute whose namespace is XMLNS namespace, prefix is "xmlns",
                // and local name is prefix, return its value if not empty string, else null.
                // Or if prefix is null and it has an attribute whose namespace is XMLNS namespace,
                // prefix is null, and local name is "xmlns", return its value if not empty, else null.
                for (elem.attributes.toSlice()) |attr| {
                    const xmlns_ns = "http://www.w3.org/2000/xmlns/";

                    if (attr.namespace_uri) |attr_ns| {
                        if (std.mem.eql(u8, attr_ns, xmlns_ns)) {
                            // Check if this matches our prefix
                            if (prefix) |p| {
                                // Looking for xmlns:prefix attribute
                                if (attr.prefix) |attr_prefix| {
                                    if (std.mem.eql(u8, attr_prefix, "xmlns") and std.mem.eql(u8, attr.local_name, p)) {
                                        return if (attr.value.len > 0) attr.value else null;
                                    }
                                }
                            } else {
                                // Looking for xmlns attribute (default namespace)
                                if (attr.prefix == null and std.mem.eql(u8, attr.local_name, "xmlns")) {
                                    return if (attr.value.len > 0) attr.value else null;
                                }
                            }
                        }
                    }
                }

                // Step 5: If parent element is null, return null
                const parent = self.parent_element orelse return null;

                // Step 6: Return result of locating namespace on parent
                return parent.base.locateNamespace(prefix);
            },
            DOCUMENT_NODE => {
                // Step 1: If document element is null, return null
                const doc: *const Document = @ptrCast(@alignCast(self));
                const doc_elem = doc.documentElement() orelse return null;

                // Step 2: Return result of locating namespace on document element
                return doc_elem.base.locateNamespace(prefix);
            },
            DOCUMENT_TYPE_NODE, DOCUMENT_FRAGMENT_NODE => {
                return null;
            },
            ATTRIBUTE_NODE => {
                // Step 1: If element is null, return null
                const AttributeType = @import("attr").Attr;
                const attr: *const AttributeType = @ptrCast(@alignCast(self));
                const element = attr.owner_element orelse return null;

                // Step 2: Return result of locating namespace on element
                return element.base.locateNamespace(prefix);
            },
            else => {
                // Step 1: If parent element is null, return null
                const parent = self.parent_element orelse return null;

                // Step 2: Return result of locating namespace on parent
                return parent.base.locateNamespace(prefix);
            },
        }
    }

    // ========================================================================
    // Mutation Observer Support (DOM §7.1)
    // ========================================================================

    /// Get the list of registered observers for this node
    pub fn getRegisteredObservers(self: *Node) *infra.List(RegisteredObserver) {
        return &self.registered_observers;
    }

    /// Add a registered observer to this node's list
    pub fn addRegisteredObserver(self: *Node, registered: RegisteredObserver) !void {
        try self.registered_observers.append(registered);
    }

    /// Remove all registered observers for a specific MutationObserver
    pub fn removeRegisteredObserver(self: *Node, observer: *const @import("mutation_observer").MutationObserver) void {
        var i: usize = 0;
        while (i < self.registered_observers.toSlice().len) {
            if (self.registered_observers.toSlice()[i].observer == observer) {
                _ = self.registered_observers.orderedRemove(i);
                // Don't increment i, we just shifted everything down
            } else {
                i += 1;
            }
        }
    }

    /// Remove all transient registered observers whose source matches the given registered observer
    ///
    /// Spec: Used during MutationObserver.observe() to clean up old transient observers
    /// when re-observing a node with updated options.
    pub fn removeTransientObservers(self: *Node, source: *const RegisteredObserver) void {
        // Note: In our current implementation, we don't have a way to distinguish
        // transient observers from regular ones in the registered_observers list.
        // This would require either:
        // 1. A separate transient_observers list, OR
        // 2. Wrapping RegisteredObserver in a tagged union
        //
        // For now, this is a no-op. Transient observers are not yet fully implemented.
        // When they are, they should be stored separately or tagged so we can identify
        // and remove them here.
        _ = self;
        _ = source;
    }
}, .{
    .exposed = &.{.Window},
});

/// GetRootNodeOptions dictionary
/// Spec: https://dom.spec.whatwg.org/#dictdef-getrootnodeoptions
pub const GetRootNodeOptions = struct {
    composed: bool = false,
};
