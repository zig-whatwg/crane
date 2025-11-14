//! Document interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-document

const std = @import("std");
const webidl = @import("webidl");
const infra = @import("infra");
const dom = @import("dom");
const Node = @import("node").Node;
const ParentNode = @import("parent_node").ParentNode;
const NonElementParentNode = @import("non_element_parent_node").NonElementParentNode;
const DocumentOrShadowRoot = @import("document_or_shadow_root").DocumentOrShadowRoot;
const HTMLCollection = @import("html_collection").HTMLCollection;
const dom_types = @import("dom_types");
const ProcessingInstruction = @import("processing_instruction").ProcessingInstruction;
const CDATASection = @import("cdata_section").CDATASection;
const DocumentType = @import("document_type").DocumentType;
const DOMImplementation = @import("dom_implementation").DOMImplementation;
const Allocator = std.mem.Allocator;
const Element = @import("element").Element;
const Text = @import("text").Text;
const Comment = @import("comment").Comment;
const DocumentFragment = @import("document_fragment").DocumentFragment;
const Range = @import("range").Range;
const NodeIterator = @import("node_iterator").NodeIterator;
const Event = @import("event").Event;
const Attr = @import("attr").Attr;

/// Document format type enumeration
pub const DocType = enum {
    html,
    xml,
};

/// DOM Spec: interface Document : Node
pub const Document = webidl.interface(struct {
    pub const extends = Node;
    pub const includes = .{ ParentNode, NonElementParentNode, DocumentOrShadowRoot };

    allocator: Allocator,
    /// Cached DOMImplementation instance ([SameObject])
    _implementation: ?DOMImplementation,
    /// String interning pool for tag names, attribute names, etc.
    /// Provides memory savings (20-30%) and O(1) string comparison via pointer equality
    _string_pool: std.StringHashMap(void),
    /// Document base URL (fallback: empty string for about:blank)
    base_uri: []const u8,
    /// Document content type (e.g., "text/html", "application/xml")
    content_type: []const u8,
    /// Document type: html or xml
    doc_type: DocType,
    /// Document origin (opaque for now)
    origin: ?*anyopaque,
    /// Live ranges associated with this document
    /// Spec: https://dom.spec.whatwg.org/#concept-live-range
    ranges: infra.List(*Range),
    ranges_mutex: std.Thread.Mutex,

    /// Node iterators associated with this document
    /// Spec: DOM §7.1.2 - NodeIterator pre-removing steps require tracking all iterators
    /// Per spec: "For each NodeIterator object iterator whose root's node document is node's node document"
    node_iterators: infra.List(*NodeIterator),
    node_iterators_mutex: std.Thread.Mutex,

    pub fn init(allocator: Allocator) !Document {
        return .{
            .event_listener_list = null, // From EventTarget
            .allocator = allocator,
            ._implementation = null,
            ._string_pool = std.StringHashMap(void).init(allocator),
            .content_type = "application/xml",
            .doc_type = .xml,
            .origin = null,
            .base_uri = "about:blank",
            .ranges = infra.List(*Range).init(allocator),
            .ranges_mutex = std.Thread.Mutex{},
            .node_iterators = infra.List(*NodeIterator).init(allocator),
            .node_iterators_mutex = std.Thread.Mutex{},
        };
    }

    pub fn deinit(self: *Document) void {
        // Free all interned strings from pool
        var it = self._string_pool.keyIterator();
        while (it.next()) |key_ptr| {
            self.allocator.free(key_ptr.*);
        }
        self._string_pool.deinit();

        // Clean up cached implementation if it exists
        if (self._implementation) |*impl| {
            impl.deinit();
        }

        // Clean up ranges list (ranges themselves are owned by their creators)
        self.ranges.deinit();

        // Clean up node iterators list (iterators themselves are owned by their creators)
        self.node_iterators.deinit();

        // NOTE: Parent Node cleanup is handled by codegen
    }

    /// Intern a string in the document's string pool
    /// Returns a pointer to the interned string which can be compared via pointer equality
    /// If the string is already interned, returns the existing copy
    /// Caller does NOT own the returned slice - it's managed by the Document
    pub fn internString(self: *Document, str: []const u8) ![]const u8 {
        // Check if string is already interned
        if (self._string_pool.getKey(str)) |existing| {
            return existing;
        }

        // Not interned yet - allocate and store
        const owned = try self.allocator.dupe(u8, str);
        errdefer self.allocator.free(owned);

        try self._string_pool.put(owned, {});
        return owned;
    }

    /// Register a live range with this document
    /// Spec: https://dom.spec.whatwg.org/#concept-live-range
    pub fn registerRange(self: *Document, range: *Range) !void {
        self.ranges_mutex.lock();
        defer self.ranges_mutex.unlock();

        try self.ranges.append(range);
    }

    /// Unregister a live range from this document
    pub fn unregisterRange(self: *Document, range: *Range) void {
        self.ranges_mutex.lock();
        defer self.ranges_mutex.unlock();

        var i: usize = 0;
        while (i < self.ranges.len) {
            if (self.ranges.get(i)) |r| {
                if (r == range) {
                    _ = self.ranges.remove(i) catch unreachable;
                    return;
                }
            }
            i += 1;
        }
    }

    /// Register a node iterator with this document
    /// Per DOM spec: Document tracks all NodeIterators whose root's node document is this document
    /// This enables NodeIterator pre-removing steps during mutation operations
    pub fn registerNodeIterator(self: *Document, iterator: *NodeIterator) !void {
        self.node_iterators_mutex.lock();
        defer self.node_iterators_mutex.unlock();

        try self.node_iterators.append(iterator);
    }

    /// Unregister a node iterator from this document
    pub fn unregisterNodeIterator(self: *Document, iterator: *NodeIterator) void {
        self.node_iterators_mutex.lock();
        defer self.node_iterators_mutex.unlock();

        var i: usize = 0;
        while (i < self.node_iterators.len) {
            if (self.node_iterators.get(i)) |iter| {
                if (iter == iterator) {
                    _ = self.node_iterators.remove(i) catch unreachable;
                    return;
                }
            }
            i += 1;
        }
    }

    /// implementation getter
    /// DOM §4.6 - Returns document's DOMImplementation object
    /// [SameObject] - Always returns the same instance
    pub fn get_implementation(self: *Document) !DOMImplementation {
        if (self._implementation) |impl| {
            return impl;
        }
        // Create and cache the implementation
        const impl = try DOMImplementation.init(self.allocator, self);
        self._implementation = impl;
        return impl;
    }

    /// createElement(localName)
    /// Spec: https://dom.spec.whatwg.org/#dom-document-createelement
    pub fn call_createElement(self: *Document, local_name: []const u8) !*Element {
        // Intern the tag name for memory savings and fast comparison
        const interned_name = try self.internString(local_name);

        const element = try self.allocator.create(Element);
        element.* = try Element.init(self.allocator, interned_name);
        return element;
    }

    /// createTextNode(data)
    /// Spec: https://dom.spec.whatwg.org/#dom-document-createtextnode
    pub fn call_createTextNode(self: *Document, data: []const u8) !*Text {
        const text = try self.allocator.create(Text);
        text.* = try Text.init(self.allocator);

        // Set data field (Text extends CharacterData which has data field)
        const cd: *@import("character_data").CharacterData = @ptrCast(text);
        cd.data = try self.allocator.dupe(u8, data);

        return text;
    }

    /// createComment(data)
    /// DOM §4.6.1 - The createComment(data) method steps are to return
    /// a new Comment node whose data is data and node document is this.
    pub fn call_createComment(self: *Document, data: []const u8) !*Comment {
        const comment = try self.allocator.create(Comment);
        comment.* = try Comment.init(self.allocator);

        // Set data field (Comment extends CharacterData which has data field)
        const cd: *@import("character_data").CharacterData = @ptrCast(comment);
        cd.data = try self.allocator.dupe(u8, data);

        return comment;
    }

    /// createProcessingInstruction(target, data)
    /// DOM §4.6.1 - Creates a ProcessingInstruction node
    /// Returns a new ProcessingInstruction node whose target is target, data is data,
    /// and node document is this.
    pub fn call_createProcessingInstruction(
        self: *Document,
        target: []const u8,
        data: []const u8,
    ) !*ProcessingInstruction {
        const pi = try self.allocator.create(ProcessingInstruction);
        pi.* = try ProcessingInstruction.init(self.allocator, target, data);
        return pi;
    }

    /// createCDATASection(data)
    /// DOM §4.6.1 - Creates a CDATASection node
    /// Returns a new CDATASection node whose data is data and node document is this.
    pub fn call_createCDATASection(self: *Document, data: []const u8) !*CDATASection {
        const cdata = try self.allocator.create(CDATASection);
        cdata.* = try CDATASection.init(self.allocator, data);
        return cdata;
    }

    /// createDocumentType(qualifiedName, publicId, systemId)
    /// DOM §4.6.1 - Creates a DocumentType node
    /// Returns a new DocumentType node whose name is qualifiedName, public ID is publicId,
    /// system ID is systemId, and node document is this.
    pub fn call_createDocumentType(
        self: *Document,
        qualified_name: []const u8,
        public_id: []const u8,
        system_id: []const u8,
    ) !*DocumentType {
        const doctype = try self.allocator.create(DocumentType);
        doctype.* = try DocumentType.init(self.allocator, qualified_name, public_id, system_id);
        return doctype;
    }

    /// createDocumentFragment()
    /// DOM §4.6.1 - The createDocumentFragment() method steps are to return
    /// a new DocumentFragment node whose node document is this.
    pub fn call_createDocumentFragment(self: *Document) !*DocumentFragment {
        const fragment = try self.allocator.create(DocumentFragment);
        fragment.* = try DocumentFragment.init(self.allocator);
        return fragment;
    }

    /// createElementNS(namespace, qualifiedName)
    /// DOM §4.6.1 - Creates an element in the given namespace
    ///
    /// Spec: Internal createElementNS steps:
    /// 1. Validate and extract namespace and qualifiedName
    /// 2. Flatten element creation options (for custom elements)
    /// 3. Create an element with namespace, prefix, localName
    ///
    /// Simplified implementation:
    /// - Sets namespace_uri field on element
    /// - Parses qualified name for prefix:localName
    /// - Skips custom element handling
    pub fn call_createElementNS(
        self: *Document,
        namespace: ?[]const u8,
        qualified_name: []const u8,
    ) !*Element {
        // Parse qualified name for prefix and local name
        var prefix: ?[]const u8 = null;
        var local_name: []const u8 = qualified_name;

        if (std.mem.indexOfScalar(u8, qualified_name, ':')) |colon_pos| {
            prefix = qualified_name[0..colon_pos];
            local_name = qualified_name[colon_pos + 1 ..];
        }

        // Create element with qualified name
        const element = try self.allocator.create(Element);
        element.* = try Element.init(self.allocator, qualified_name);

        // Set namespace, prefix, and local name
        if (namespace) |ns| {
            element.namespace_uri = try self.allocator.dupe(u8, ns);
        }
        if (prefix) |p| {
            element.prefix = try self.allocator.dupe(u8, p);
        }
        element.local_name = try self.allocator.dupe(u8, local_name);

        return element;
    }

    /// createAttribute(localName)
    /// DOM §4.6.1 - Creates an Attr node with the given local name
    pub fn call_createAttribute(self: *Document, local_name: []const u8) !*Attr {
        _ = self;
        _ = local_name;
        return error.NotImplemented;
    }

    /// createAttributeNS(namespace, qualifiedName)
    /// DOM §4.6.1 - Creates an Attr node in the given namespace
    pub fn call_createAttributeNS(
        self: *Document,
        namespace: ?[]const u8,
        qualified_name: []const u8,
    ) !*Attr {
        _ = self;
        _ = namespace;
        _ = qualified_name;
        return error.NotImplemented;
    }

    /// importNode(node, deep)
    /// DOM §4.6.1 - Returns a copy of node imported into this document.
    /// If deep is true, the copy also includes the node's descendants.
    ///
    /// Spec: https://dom.spec.whatwg.org/#dom-document-importnode
    ///
    /// Implementation notes:
    /// - Handles common node types: Element, Text, Comment, ProcessingInstruction, DocumentFragment
    /// - Does not yet support: Custom Elements, Shadow DOM, CDATA sections
    /// - DocumentType nodes are rejected per spec
    ///
    /// Spec steps:
    /// 1. If node is a document or shadow root, throw "NotSupportedError"
    /// 2. Return clone a node with document=this, subtree=deep
    pub fn call_importNode(self: *Document, node: *Node, deep: bool) !*Node {
        // Step 1: If node is a document or shadow root, throw "NotSupportedError"
        if (node.node_type == Node.DOCUMENT_NODE) {
            return error.NotSupportedError;
        }
        // TODO: Check for shadow root when shadow DOM is implemented

        // Step 2: Clone the node
        return self.cloneNode(node, deep, null);
    }

    /// Clone a node algorithm
    /// Spec: https://dom.spec.whatwg.org/#concept-node-clone
    ///
    /// Simplified implementation for common node types.
    /// Does not yet support: Custom Elements, Shadow DOM cloning
    fn cloneNode(self: *Document, node: *Node, subtree: bool, parent: ?*Node) !*Node {
        // Clone the single node first
        const copy = try self.cloneSingleNode(node);
        errdefer self.destroyNode(copy);

        // If parent is provided, append copy to parent
        if (parent) |p| {
            // Append to parent's children
            try p.child_nodes.append(copy);
            copy.parent_node = p;
        }

        // If subtree is true, clone all children recursively
        if (subtree) {
            for (0..node.child_nodes.size()) |i| {
                if (node.child_nodes.get(i)) |child| {
                    _ = try self.cloneNode(child, true, copy);
                }
            }
        }

        return copy;
    }

    /// Clone a single node (without children)
    /// Spec: https://dom.spec.whatwg.org/#concept-node-clone-single
    fn cloneSingleNode(self: *Document, node: *Node) !*Node {
        switch (node.node_type) {
            Node.ELEMENT_NODE => {
                const elem: *Element = @ptrCast(node);

                // Create new element with same tag name
                const copy_elem = try self.call_createElement(elem.tag_name);

                // Clone all attributes
                for (elem.attributes.items) |attr| {
                    const copy_attr = try self.allocator.create(Attr);
                    errdefer self.allocator.destroy(copy_attr);

                    copy_attr.* = try Attr.init(
                        self.allocator,
                        attr.name,
                        attr.value,
                        attr.namespace_uri,
                        attr.prefix,
                    );

                    try copy_elem.attributes.append(copy_attr);
                }

                return @ptrCast(copy_elem);
            },

            Node.TEXT_NODE => {
                const text: *Text = @ptrCast(node);
                const copy_text = try self.call_createTextNode(text.data);
                return @ptrCast(copy_text);
            },

            Node.COMMENT_NODE => {
                const comment: *Comment = @ptrCast(node);
                const copy_comment = try self.call_createComment(comment.data);
                return @ptrCast(copy_comment);
            },

            Node.PROCESSING_INSTRUCTION_NODE => {
                const pi: *ProcessingInstruction = @ptrCast(node);
                const copy_pi = try self.call_createProcessingInstruction(pi.target, pi.data);
                return @ptrCast(copy_pi);
            },

            Node.DOCUMENT_FRAGMENT_NODE => {
                const copy_fragment = try self.call_createDocumentFragment();
                return @ptrCast(copy_fragment);
            },

            Node.DOCUMENT_TYPE_NODE => {
                // Per spec: DocumentType cannot be cloned via importNode
                return error.NotSupportedError;
            },

            Node.CDATA_SECTION_NODE => {
                // TODO: Implement when CDATASection is fully supported
                return error.NotImplemented;
            },

            else => {
                return error.NotSupportedError;
            },
        }
    }

    /// Helper to destroy a node (for error cleanup)
    fn destroyNode(self: *Document, node: *Node) void {
        switch (node.node_type) {
            Node.ELEMENT_NODE => {
                const elem: *Element = @ptrCast(node);
                elem.deinit();
                self.allocator.destroy(elem);
            },
            Node.TEXT_NODE => {
                const text: *Text = @ptrCast(node);
                text.deinit();
                self.allocator.destroy(text);
            },
            Node.COMMENT_NODE => {
                const comment: *Comment = @ptrCast(node);
                comment.deinit();
                self.allocator.destroy(comment);
            },
            Node.PROCESSING_INSTRUCTION_NODE => {
                const pi: *ProcessingInstruction = @ptrCast(node);
                pi.deinit();
                self.allocator.destroy(pi);
            },
            Node.DOCUMENT_FRAGMENT_NODE => {
                const fragment: *DocumentFragment = @ptrCast(node);
                fragment.deinit();
                self.allocator.destroy(fragment);
            },
            else => {},
        }
    }

    /// adoptNode(node)
    /// DOM §4.6.1 - Moves node from another document to this document.
    ///
    /// Spec steps:
    /// 1. If node is a document, throw "NotSupportedError".
    /// 2. If node is a shadow root, throw "HierarchyRequestError".
    /// 3. If node is a DocumentFragment whose host is non-null, return.
    /// 4. Adopt node into this.
    /// 5. Return node.
    pub fn call_adoptNode(self: *Document, node: *Node) !*Node {
        const mutation = @import("dom").mutation;

        // Step 1: If node is a document, throw "NotSupportedError"
        if (node.node_type == Node.DOCUMENT_NODE) {
            return error.NotSupportedError;
        }

        // Step 2: If node is a shadow root, throw "HierarchyRequestError"
        // TODO: Check for shadow root when shadow DOM is implemented
        // For now, we don't have shadow roots, so skip this check

        // Step 3: If node is a DocumentFragment whose host is non-null, return
        if (node.node_type == Node.DOCUMENT_FRAGMENT_NODE) {
            // TODO: Check DocumentFragment.host when shadow DOM is implemented
            // For now, DocumentFragment doesn't have host field, so skip
        }

        // Step 4: Adopt node into this
        try mutation.adopt(node, self);

        // Step 5: Return node
        return node;
    }

    /// createEvent(interface)
    /// DOM §4.6.1 - Creates a legacy event object
    /// Spec: https://dom.spec.whatwg.org/#dom-document-createevent
    ///
    /// This is a legacy API for creating events. New code should use event constructors instead.
    ///
    /// Spec steps:
    /// 1. Let constructor be null
    /// 2. If interface is ASCII case-insensitive match for strings in table, set constructor
    /// 3. If constructor is null, throw "NotSupportedError"
    /// 4. If interface not exposed on relevant global object, throw "NotSupportedError"
    /// 5. Return result of creating an event given constructor
    pub fn call_createEvent(self: *Document, interface: []const u8) !*@import("event").Event {

        // Step 2: Check ASCII case-insensitive match against known event types
        // Convert to lowercase for comparison
        var lowercase_buf: [64]u8 = undefined;
        if (interface.len > lowercase_buf.len) {
            return error.NotSupportedError;
        }

        for (interface, 0..) |c, i| {
            lowercase_buf[i] = std.ascii.toLower(c);
        }
        const lowercase_interface = lowercase_buf[0..interface.len];

        // Step 2: Match against known event type strings
        // For now, we only support basic Event type
        // Full spec requires: BeforeUnloadEvent, CompositionEvent, CustomEvent,
        // DeviceMotionEvent, DeviceOrientationEvent, DragEvent, Event, FocusEvent,
        // HashChangeEvent, KeyboardEvent, MessageEvent, MouseEvent, StorageEvent,
        // TextEvent, TouchEvent, UIEvent

        const is_event = std.mem.eql(u8, lowercase_interface, "event") or
            std.mem.eql(u8, lowercase_interface, "events") or
            std.mem.eql(u8, lowercase_interface, "htmlevents") or
            std.mem.eql(u8, lowercase_interface, "svgevents");

        const is_uievent = std.mem.eql(u8, lowercase_interface, "uievent") or
            std.mem.eql(u8, lowercase_interface, "uievents");

        const is_mouseevent = std.mem.eql(u8, lowercase_interface, "mouseevent") or
            std.mem.eql(u8, lowercase_interface, "mouseevents");

        const is_customevent = std.mem.eql(u8, lowercase_interface, "customevent");

        // TODO: Add support for other event types when they're implemented:
        // - KeyboardEvent, FocusEvent, TouchEvent, etc.

        // Step 3: If constructor is null, throw "NotSupportedError"
        if (!is_event and !is_uievent and !is_mouseevent and !is_customevent) {
            return error.NotSupportedError;
        }

        // Step 4: Interface exposure check (skipped for now - all Event types are exposed)

        // Step 5: Create an event
        // For now, we create a basic Event for all types
        // Proper implementation would create specific event subtypes
        // Note: Event is inherited from EventTarget (via Node)
        const event = try self.allocator.create(Event);
        errdefer self.allocator.destroy(event);

        event.* = try Event.init(self.allocator);

        // Note: The created event will be in uninitialized state
        // The caller must call initEvent() or similar to initialize it
        // This matches legacy behavior per spec

        return event;
    }
}, .{
    .exposed = &.{.Window},
});

// ============================================================================
// Tests for string interning
// ============================================================================
