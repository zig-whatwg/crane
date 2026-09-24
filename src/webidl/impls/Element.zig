//! Implementation for Element interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-element
//! WHATWG DOM Standard §4.8
//!
//! Element is the most general base class from which all element objects
//! (i.e. objects that represent elements) in a Document inherit. It only
//! has methods and properties common to all kinds of elements.
//!
//! Migrated from: webidl/src/dom/element.zig

const std = @import("std");
const v8 = @import("v8");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const infra = @import("infra");
const dom = @import("dom");
const same_object = @import("same_object.zig");
const Element = interfaces.Element;

// Import related impls
const NodeImpl = @import("Node.zig");
const AttrImpl = @import("Attr.zig");
const DOMTokenListImpl = @import("DOMTokenList.zig");
const CharacterDataImpl = @import("CharacterData.zig");
const NamedNodeMapImpl = @import("NamedNodeMap.zig");
const ParentNodeImpl = @import("ParentNode.zig");
const HTMLElementImpl = @import("HTMLElement.zig");
const CSSStyleDeclarationImpl = @import("CSSStyleDeclaration.zig");

// Import mixins for shared interface methods
const mixins = @import("mixins");
const ParentNode = mixins.ParentNode;
const NonDocumentTypeChildNode = mixins.NonDocumentTypeChildNode;
const ChildNode = mixins.ChildNode;

// Import pointer_tag for V8 pointer untagging (via v8 module)
const pointer_tag = @import("v8").pointer_tag;

pub const State = Element.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    NotFoundError,
    SyntaxError,
    InvalidCharacterError,
    OutOfMemory,
};

/// Static sentinel for representing "undefined" return values.
/// Used instead of @ptrFromInt(1) to provide a valid pointer that represents
/// undefined/empty results from operations that return *const anyopaque.
var undefined_sentinel: u8 = 0;

/// Custom element state per HTML spec
/// Spec: https://html.spec.whatwg.org/#custom-element-state
pub const CustomElementState = enum {
    undefined,
    failed,
    uncustomized,
    precustomized,
    custom,
};

// ==========================================================================
// Inline Attribute Storage Optimization
// Most elements have 0-3 attributes. Store first 4 inline to avoid heap allocation.
// Only spill to heap when more than 4 attributes are needed.
// Expected impact: 30-40% reduction in Element memory usage, fewer allocations,
// better cache locality.
// ==========================================================================

/// Number of inline attribute slots (optimized for common case of 0-3 attributes)
pub const INLINE_ATTR_CAPACITY: usize = 4;

/// Attribute entry storing namespace, prefix, local name, and value
pub const AttributeEntry = struct {
    namespace_uri: ?[]const u8,
    prefix: ?[]const u8,
    local_name: []const u8,
    value: []const u8,

    /// The Attr node made for this attribute, once script asked for one
    /// (ensureAttrNode), and the hold on its wrapper that keeps it the same
    /// node - identity, expandos and all - while the attribute is on this
    /// element. Blink traces the same edge (Element's AttrNodeList).
    attr_node: ?same_object.Link = null,
    attr_pin: same_object.Pin = .{},
};

/// Internal state for Element implementation
/// Stores element-specific data: namespace, prefix, local name, attributes
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The namespace URI of this element (null for HTML elements in HTML documents)
    namespace_uri: ?runtime.DOMString = null,

    /// The namespace prefix (null if no prefix)
    prefix: ?runtime.DOMString = null,

    /// The local name of this element (the tag name without prefix)
    local_name: runtime.DOMString,

    /// The element's id attribute value (cached for fast lookup)
    id: runtime.DOMString,

    /// The element's class attribute value (cached for classList)
    class_name: runtime.DOMString,

    /// The element's slot attribute value
    slot: runtime.DOMString,

    /// Shadow root attached to this element (null if not a shadow host)
    shadow_root: ?*runtime.Instance = null,

    /// Custom element state per HTML spec
    custom_element_state: CustomElementState = .undefined,

    /// "is" value for customized built-in elements
    is_value: ?runtime.DOMString = null,

    /// Slottable mixin fields (DOM §4.3.7)
    /// The slot this element is assigned to (null if not in a shadow tree or unassigned)
    assigned_slot: ?*runtime.Instance = null,

    /// Manual slot assignment (for SlotAssignmentMode.manual)
    manual_slot_assignment: ?*runtime.Instance = null,

    /// Cached NamedNodeMap for the attributes getter
    /// Per WebIDL, the same object must be returned on subsequent accesses
    /// so that own properties added to the object persist.
    named_node_map: ?*runtime.Instance = null,
    /// Slab generation of `named_node_map` when it was taken. The wrapper
    /// cache's teardown sweep can free the map before it reaches the element;
    /// the flags below do not see that, the generation does.
    named_node_map_generation: u64 = 0,

    // ==========================================================================
    // Inline Attribute Storage Optimization
    // Most elements have 0-3 attributes. Store first 4 inline to avoid heap allocation.
    // Only spill to heap when more than 4 attributes are needed.
    // Expected impact: 30-40% reduction in Element memory usage, fewer allocations,
    // better cache locality.
    // ==========================================================================

    /// Inline storage for first 4 attributes (avoids heap allocation for most elements)
    inline_attrs: [INLINE_ATTR_CAPACITY]?AttributeEntry = .{null} ** INLINE_ATTR_CAPACITY,

    /// Count of attributes stored inline (0-4)
    inline_attr_count: u8 = 0,

    /// Heap storage for attributes beyond inline capacity (null until needed)
    heap_attrs: ?std.ArrayList(AttributeEntry) = null,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .namespace_uri = null,
            .prefix = null,
            .local_name = runtime.DOMString.initEmpty(),
            .id = runtime.DOMString.initEmpty(),
            .class_name = runtime.DOMString.initEmpty(),
            .slot = runtime.DOMString.initEmpty(),
            .shadow_root = null,
            .custom_element_state = .undefined,
            .is_value = null,
            .named_node_map = null,
            .inline_attrs = .{null} ** INLINE_ATTR_CAPACITY,
            .inline_attr_count = 0,
            .heap_attrs = null,
        };
    }

    pub fn deinit(self: *InternalState) void {
        if (self.namespace_uri) |*ns| {
            ns.deinit(self.allocator);
        }
        if (self.prefix) |*p| {
            p.deinit(self.allocator);
        }
        self.local_name.deinit(self.allocator);
        self.id.deinit(self.allocator);
        self.class_name.deinit(self.allocator);
        self.slot.deinit(self.allocator);
        if (self.is_value) |*v| {
            v.deinit(self.allocator);
        }

        // Clean up cached NamedNodeMap
        // CRITICAL: Mark the NamedNodeMap via lifecycle tracking BEFORE calling deinit.
        // We use lifecycle tracking (not wrapper_cache.markInstanceCleanedUp) because
        // during wrapper_cache.deinit, the HashMap is being iterated/destroyed and
        // cannot be safely accessed. The lifecycle tracking uses a SEPARATE data
        // structure that's safe to modify during teardown.
        //
        // wrapper_cache.deinit checks isCleanupStarted() before calling gc.onObjectFreed,
        // so marking here prevents double-free of the NamedNodeMap.
        if (self.named_node_map) |nnm| {
            // The protocol above covers Element freeing the map FIRST. The other
            // order happens too: if script ever touched `el.attributes`, the map
            // was wrapped, and the wrapper cache's weak callback frees it at
            // whatever GC finds it dead - long before this exit-time sweep. It
            // marks the Instance cleaned-up and the slab reclaims the memory,
            // so `NamedNodeMap.deinit` here reads `getState` off an unmapped
            // page: SEGV in `Instance.stateAs` under
            // `InstanceRegistry(Element.InternalState).deinitAllAndClear`, which
            // is how custom-elements/connected-callbacks.html died at exit.
            //
            // The lifecycle flags are keyed on the address and never dereference
            // it, so they are safe to consult on freed memory. If the slab has
            // since reissued the address to a live object, the stale flag makes
            // this skip a deinit it should have done - a leak, and the
            // conservative side of the same trade the rest of this tree makes.
            //
            // The flags miss one order: the wrapper cache's teardown sweep freed
            // the map through onObjectFreed - state block and slab slot, no
            // flag set - before it reached this element. `getState` on that
            // poisoned block sails past every null check (0xAA is not null) and
            // the attribute list is freed a second time. The generation recorded
            // when the map was taken is what tells a freed or reissued slot from
            // the map this element still owns.
            const already_gone = runtime.instance_lifecycle.isCleanedUp(nnm) or
                runtime.instance_lifecycle.isCleanupStarted(nnm) or
                runtime.SlabAllocator.generationOf(nnm) != self.named_node_map_generation;
            if (!already_gone) {
                _ = runtime.instance_lifecycle.markCleanupStarted(nnm);
                interfaces.NamedNodeMap.deinit(nnm);
            }
            self.named_node_map = null;
        }

        // Free inline attribute entries, letting their Attr nodes go first
        for (self.inline_attrs[0..self.inline_attr_count]) |*maybe_entry| {
            if (maybe_entry.*) |*entry| {
                detachAttrNode(entry);
                freeAttributeEntry(self.allocator, entry.*);
            }
        }

        // Free heap attribute entries if any
        if (self.heap_attrs) |*heap| {
            for (heap.items) |*entry| {
                detachAttrNode(entry);
                freeAttributeEntry(self.allocator, entry.*);
            }
            heap.deinit(self.allocator);
        }
    }

    /// Free an attribute entry's allocated strings
    fn freeAttributeEntry(allocator: std.mem.Allocator, entry: AttributeEntry) void {
        if (entry.namespace_uri) |ns| {
            allocator.free(ns);
        }
        if (entry.prefix) |p| {
            allocator.free(p);
        }
        allocator.free(entry.local_name);
        allocator.free(entry.value);
    }

    /// Get total attribute count (inline + heap)
    pub fn getAttributeCount(self: *const InternalState) usize {
        const heap_count: usize = if (self.heap_attrs) |heap| heap.items.len else 0;
        return self.inline_attr_count + heap_count;
    }

    /// Backward-compatible attribute list view
    /// Provides `.items` accessor for code that expects ArrayList-like interface
    /// Collects attributes into a temporary slice for iteration
    pub const AttributeListView = struct {
        state: *const InternalState,

        /// Returns a slice that can be iterated like the old ArrayList.items
        /// Note: This builds a temporary list, so prefer attributeIterator() for performance
        pub fn toSlice(self: AttributeListView, allocator: std.mem.Allocator) ![]AttributeEntry {
            const count = self.state.getAttributeCount();
            if (count == 0) return &[_]AttributeEntry{};

            const result = try allocator.alloc(AttributeEntry, count);
            var idx: usize = 0;

            // Copy inline attributes
            for (self.state.inline_attrs[0..self.state.inline_attr_count]) |maybe_entry| {
                if (maybe_entry) |entry| {
                    result[idx] = entry;
                    idx += 1;
                }
            }

            // Copy heap attributes
            if (self.state.heap_attrs) |heap| {
                for (heap.items) |entry| {
                    result[idx] = entry;
                    idx += 1;
                }
            }

            return result;
        }

        /// Get count for compatibility with .items.len
        pub fn len(self: AttributeListView) usize {
            return self.state.getAttributeCount();
        }
    };

    /// Provides backward-compatible access similar to the old .attributes field
    pub fn attributes(self: *const InternalState) AttributeListView {
        return .{ .state = self };
    }

    /// Iterator over all attributes (inline first, then heap)
    pub const AttributeIterator = struct {
        state: *const InternalState,
        inline_index: usize = 0,
        heap_index: usize = 0,

        pub fn next(self: *AttributeIterator) ?*const AttributeEntry {
            // First iterate through inline attributes
            while (self.inline_index < self.state.inline_attr_count) {
                const idx = self.inline_index;
                self.inline_index += 1;
                if (self.state.inline_attrs[idx]) |*entry| {
                    return entry;
                }
            }

            // Then iterate through heap attributes
            if (self.state.heap_attrs) |heap| {
                if (self.heap_index < heap.items.len) {
                    const idx = self.heap_index;
                    self.heap_index += 1;
                    return &heap.items[idx];
                }
            }

            return null;
        }
    };

    /// Get an iterator over all attributes
    pub fn attributeIterator(self: *const InternalState) AttributeIterator {
        return .{ .state = self };
    }

    /// Add a new attribute (inline if space, otherwise heap)
    pub fn addAttribute(self: *InternalState, entry: AttributeEntry) !void {
        // Try inline storage first
        if (self.inline_attr_count < INLINE_ATTR_CAPACITY) {
            self.inline_attrs[self.inline_attr_count] = entry;
            self.inline_attr_count += 1;
            return;
        }

        // Spill to heap
        if (self.heap_attrs == null) {
            self.heap_attrs = std.ArrayList(AttributeEntry).empty;
        }
        try self.heap_attrs.?.append(self.allocator, entry);
    }

    /// Find an attribute by namespace and local name, returns mutable pointer
    pub fn findAttributeMut(self: *InternalState, namespace_uri: ?[]const u8, local_name: []const u8) ?*AttributeEntry {
        // Search inline first
        for (self.inline_attrs[0..self.inline_attr_count]) |*maybe_entry| {
            if (maybe_entry.*) |*entry| {
                if (attributeMatches(entry, namespace_uri, local_name)) {
                    return entry;
                }
            }
        }

        // Search heap
        if (self.heap_attrs) |*heap| {
            for (heap.items) |*entry| {
                if (attributeMatches(entry, namespace_uri, local_name)) {
                    return entry;
                }
            }
        }

        return null;
    }

    /// Find an attribute by namespace and local name, returns const pointer
    pub fn findAttribute(self: *const InternalState, namespace_uri: ?[]const u8, local_name: []const u8) ?*const AttributeEntry {
        // Search inline first
        for (self.inline_attrs[0..self.inline_attr_count]) |*maybe_entry| {
            if (maybe_entry.*) |*entry| {
                if (attributeMatches(entry, namespace_uri, local_name)) {
                    return entry;
                }
            }
        }

        // Search heap
        if (self.heap_attrs) |heap| {
            for (heap.items) |*entry| {
                if (attributeMatches(entry, namespace_uri, local_name)) {
                    return entry;
                }
            }
        }

        return null;
    }

    /// Check if an attribute matches namespace and local name
    fn attributeMatches(entry: *const AttributeEntry, namespace_uri: ?[]const u8, local_name: []const u8) bool {
        const ns_match = (namespace_uri == null and entry.namespace_uri == null) or
            (namespace_uri != null and entry.namespace_uri != null and
                std.mem.eql(u8, namespace_uri.?, entry.namespace_uri.?));
        return ns_match and std.mem.eql(u8, local_name, entry.local_name);
    }

    /// Remove an attribute by namespace and local name
    pub fn removeAttribute(self: *InternalState, namespace_uri: ?[]const u8, local_name: []const u8) bool {
        const index = self.indexOfAttribute(namespace_uri, local_name) orelse return false;
        freeAttributeEntry(self.allocator, self.takeAttributeAt(index));
        return true;
    }

    /// The attribute at `index` in the attribute list, in list order.
    pub fn attributeAt(self: *InternalState, index: usize) ?*AttributeEntry {
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
    pub fn indexOfAttribute(self: *const InternalState, namespace_uri: ?[]const u8, local_name: []const u8) ?usize {
        var it = self.attributeIterator();
        var index: usize = 0;
        while (it.next()) |entry| : (index += 1) {
            if (attributeMatches(entry, namespace_uri, local_name)) return index;
        }
        return null;
    }

    /// Index of the FIRST attribute whose qualified name is `qualified_name`.
    /// Two attributes in different namespaces can share one.
    pub fn indexOfQualifiedName(self: *const InternalState, qualified_name: []const u8) ?usize {
        var it = self.attributeIterator();
        var index: usize = 0;
        while (it.next()) |entry| : (index += 1) {
            if (qualifiedNameIs(entry, qualified_name)) return index;
        }
        return null;
    }

    /// Remove the attribute at `index` and hand its entry, strings and all, to
    /// the caller. The list keeps its order: attribute order is observable
    /// through `attributes` and `getAttributeNames()`.
    pub fn takeAttributeAt(self: *InternalState, index: usize) AttributeEntry {
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

/// An attribute's qualified name is its local name if its namespace prefix is
/// null, and otherwise its prefix, ":", and its local name. Compared in place.
///
/// Spec: https://dom.spec.whatwg.org/#concept-attribute-qualified-name
fn qualifiedNameIs(entry: *const AttributeEntry, qualified_name: []const u8) bool {
    const prefix = entry.prefix orelse return std.mem.eql(u8, entry.local_name, qualified_name);
    return qualified_name.len == prefix.len + 1 + entry.local_name.len and
        std.mem.startsWith(u8, qualified_name, prefix) and
        qualified_name[prefix.len] == ':' and
        std.mem.endsWith(u8, qualified_name, entry.local_name);
}

// Use shared InstanceRegistry utility for internal state management
const utils = @import("webidl").utils;
const Registry = utils.InstanceRegistry(InternalState);

/// Get the internal state from an instance
/// Made public for use by Document's getElementById, getElementsByTagName, etc.
pub fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

/// Get the Node internal state from an Element instance
/// Uses the registry pattern for proper inheritance chain
pub fn getNodeInternal(instance: *runtime.Instance) ?*NodeImpl.InternalState {
    return NodeImpl.getInternalState(instance);
}

/// Initialize instance (creates the instance)
/// Chains to parent class initialization: Node -> EventTarget
///
/// IMPORTANT: Due to state hierarchy complexity, internal state is stored
/// in a global registry rather than in the State struct.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // Chain to parent class (Node) which chains to EventTarget
    const instance = try NodeImpl.init(allocator, StateType, vtable, ctx);
    errdefer NodeImpl.deinit(instance);

    // Set node type to ELEMENT_NODE
    try NodeImpl.setNodeType(instance, NodeImpl.NodeType.ELEMENT_NODE);

    // The attribute list's hook, for its ancestors' use (cloning). Installed
    // before any element can be cloned: this runs for every element.
    dom.element_attributes.install(.{
        .at = &attributeAtHook,
        .count = &attributeCountHook,
        .append = &appendAttributeHook,
        .change = &changeAttributeHook,
        .node_at = &attrNodeAtHook,
    });

    // Initialize Element's own internal state in registry
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    // The registry owns this block, so `Registry.remove` returns it to the
    // arena. With `set` it was dropped from the map and held to process
    // exit - 904 bytes per discarded element, measured.
    const internal = try Registry.createIn(instance, ArenaAllocator.get());
    internal.* = InternalState.init(allocator);

    return instance;
}

/// Get Element's internal state from the registry
pub fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Clean up from registry
    if (Registry.get(instance)) |internal| {
        internal.deinit();
    }
    Registry.remove(instance);
    // Node cleanup happens via inheritance chain
    NodeImpl.deinit(instance);
}

/// Clean up ALL remaining Element internal states.
/// This is called during final context cleanup to catch any leaked elements
/// that were removed from the DOM tree but not properly deinited.
/// This handles the case where DOM manipulation (e.g., removeChild) creates
/// orphaned elements that aren't cleaned up by the normal tree traversal.
pub fn cleanupAllRemainingInternal() void {
    Registry.deinitAllAndClear();
}

// =============================================================================
// Setters for internal state (used by Document factory methods)
// =============================================================================

/// Set the namespace URI of this element
/// Used by Document.createElementNS
pub fn setNamespaceURI(instance: *runtime.Instance, namespace: ?[]const u8) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Free existing namespace if any
    if (internal.namespace_uri) |*ns| {
        ns.deinit(internal.allocator);
        internal.namespace_uri = null;
    }

    // Set new namespace if provided
    if (namespace) |ns| {
        internal.namespace_uri = try runtime.DOMString.initDupe(internal.allocator, ns);
    }
}

/// Set the namespace prefix of this element
/// Used by Document.createElementNS
pub fn setPrefix(instance: *runtime.Instance, prefix: ?[]const u8) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Free existing prefix if any
    if (internal.prefix) |*p| {
        p.deinit(internal.allocator);
        internal.prefix = null;
    }

    // Set new prefix if provided
    if (prefix) |p| {
        internal.prefix = try runtime.DOMString.initDupe(internal.allocator, p);
    }
}

/// Set the local name of this element
/// Used by Document.createElement and Document.createElementNS
/// Uses tag name interning for common HTML elements to avoid allocation.
pub fn setLocalName(instance: *runtime.Instance, local_name: []const u8) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Free existing local name
    internal.local_name.deinit(internal.allocator);

    // Try to use interned tag name for common HTML elements - on an exact
    // match only: a local name is case-sensitive.
    const html_core = @import("html_core");
    if (html_core.internTagNameExact(local_name)) |interned| {
        // Use interned static string - no allocation needed
        internal.local_name = runtime.DOMString.initInterned(interned);
    } else {
        // Fall back to allocation for custom/unknown elements
        internal.local_name = try runtime.DOMString.initDupe(internal.allocator, local_name);
    }
}

/// Getter for namespaceURI
/// DOM §4.8 - Returns the namespace URI of this element
pub fn get_namespaceURI(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.namespace_uri) |ns| {
        // Clone to transfer ownership to caller (interface layer will free)
        return try ns.clone(instance.ctx.allocator);
    }
    // DOMString?: an element in no namespace answers null, not "".
    return null;
}

/// Getter for prefix
/// DOM §4.8 - Returns the namespace prefix of this element
pub fn get_prefix(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.prefix) |p| {
        // Clone to transfer ownership to caller (interface layer will free)
        return try p.clone(instance.ctx.allocator);
    }
    return runtime.DOMString.initEmpty();
}

/// Getter for localName
/// DOM §4.8 - Returns the local name of this element
pub fn get_localName(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Clone to transfer ownership to caller (interface layer will free)
    return try internal.local_name.clone(instance.ctx.allocator);
}

/// Getter for tagName
/// DOM §4.8 - Returns the qualified name of this element
/// For HTML elements in HTML documents, this is uppercase
/// Spec: https://dom.spec.whatwg.org/#dom-element-tagname
pub fn get_tagName(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Per DOM spec §4.8:
    // If the element's namespace is the HTML namespace and the element's node document
    // is an HTML document, return the qualified name in ASCII uppercase.
    // HTML elements typically have null namespace_uri (implicit HTML namespace) or
    // explicit "http://www.w3.org/1999/xhtml"
    const HTML_NAMESPACE = "http://www.w3.org/1999/xhtml";
    const is_html_element = internal.namespace_uri == null or
        (internal.namespace_uri != null and
            std.mem.eql(u8, internal.namespace_uri.?.asSlice(), HTML_NAMESPACE));

    // If there's a prefix, return "prefix:localName"
    if (internal.prefix) |p| {
        const prefix_slice = p.asSlice();
        const local_slice = internal.local_name.asSlice();

        // Allocate buffer for "prefix:localName"
        const total_len = prefix_slice.len + 1 + local_slice.len;
        var buffer = try instance.ctx.allocator.alloc(u8, total_len);
        @memcpy(buffer[0..prefix_slice.len], prefix_slice);
        buffer[prefix_slice.len] = ':';
        @memcpy(buffer[prefix_slice.len + 1 ..], local_slice);

        // Uppercase for HTML elements in HTML documents
        if (is_html_element) {
            for (buffer) |*c| {
                c.* = std.ascii.toUpper(c.*);
            }
        }

        return runtime.DOMString.initOwned(buffer);
    }

    // No prefix, return just local name
    // Uppercase for HTML elements in HTML documents
    if (is_html_element) {
        const local_slice = internal.local_name.asSlice();
        var buffer = try instance.ctx.allocator.alloc(u8, local_slice.len);
        for (local_slice, 0..) |c, i| {
            buffer[i] = std.ascii.toUpper(c);
        }
        return runtime.DOMString.initOwned(buffer);
    }

    // Non-HTML element: return as-is
    // Clone to transfer ownership to caller (interface layer will free)
    return try internal.local_name.clone(instance.ctx.allocator);
}

/// Getter for id
/// DOM §4.8 - Returns the value of the id attribute
pub fn get_id(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Clone to transfer ownership to caller (interface layer will free)
    return try internal.id.clone(instance.ctx.allocator);
}

/// Getter for className
/// DOM §4.8 - Returns the value of the class attribute
pub fn get_className(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Clone to transfer ownership to caller (interface layer will free)
    return try internal.class_name.clone(instance.ctx.allocator);
}

/// Getter for classList
/// DOM §4.8 - Returns a DOMTokenList for the class attribute
/// Spec: https://dom.spec.whatwg.org/#dom-element-classlist
///
/// The classList getter steps are to return a DOMTokenList object whose
/// associated element is this and whose associated attribute's local name is class.
pub fn get_classList(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Create a new DOMTokenList
    // Use interface instead of impl (per Golden Rule #13)
    const token_list = interfaces.DOMTokenList.init(internal.allocator, instance.ctx) catch return error.OutOfMemory;
    errdefer interfaces.DOMTokenList.deinit(token_list);

    // Initialize with current class attribute value
    interfaces.DOMTokenList.set_value(token_list, internal.class_name) catch return error.OutOfMemory;

    // Associate with this element and the "class" attribute
    DOMTokenListImpl.setElement(token_list, instance, runtime.DOMString.initInterned("class"));

    return token_list;
}

/// Getter for slot
/// DOM §4.8 - Returns the value of the slot attribute
pub fn get_slot(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Clone to transfer ownership to caller (interface layer will free)
    return try internal.slot.clone(instance.ctx.allocator);
}

/// Getter for attributes
/// DOM §4.8 - Returns a NamedNodeMap of the element's attributes
/// Spec: https://dom.spec.whatwg.org/#dom-element-attributes
///
/// The attributes getter steps are to return the associated NamedNodeMap.
/// Per WebIDL semantics, returns the same cached object on each access so that
/// own properties added to the attributes object persist across accesses.
pub fn get_attributes(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse {
        return error.InvalidStateError;
    };

    // Return cached NamedNodeMap if it exists
    if (internal.named_node_map) |cached| {
        return cached;
    }

    // Create a NamedNodeMap containing all attributes
    // Use interface instead of impl (per Golden Rule #13)
    const named_node_map = interfaces.NamedNodeMap.init(internal.allocator, instance.ctx) catch return error.OutOfMemory;
    errdefer interfaces.NamedNodeMap.deinit(named_node_map);

    // Set the owner element
    NamedNodeMapImpl.setOwnerElement(named_node_map, instance);

    // The map reads this element's list whenever it is asked - it is live -
    // so there is nothing to copy into it.

    // Cache the NamedNodeMap for future accesses, with the generation that
    // proves it is still this map at deinit.
    internal.named_node_map = named_node_map;
    internal.named_node_map_generation = runtime.SlabAllocator.generationOf(named_node_map);

    return named_node_map;
}

/// Getter for shadowRoot
/// DOM §4.8 - Returns the element's shadow root if attached and mode is "open"
/// Spec: https://dom.spec.whatwg.org/#dom-element-shadowroot
///
/// The shadowRoot getter steps are:
/// 1. Let shadow be this's shadow root.
/// 2. If shadow is null or its mode is "closed", then return null.
/// 3. Return shadow.
pub fn get_shadowRoot(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: Let shadow be this's shadow root
    const shadow = internal.shadow_root orelse return null;

    // Step 2: If shadow's mode is "closed", return null
    // Use interface instead of impl (per Golden Rule #13)
    const mode = interfaces.ShadowRoot.get_mode(shadow) catch return null;

    // Check if mode is closed
    if (mode == ._closed_) {
        return null;
    }

    // Step 3: Return shadow
    return shadow;
}

/// Getter for customElementRegistry
/// HTML §4.13.3 - Returns the element's associated custom element registry
/// Spec: https://html.spec.whatwg.org/#dom-element-customelementregistry
///
/// Note: Returns null until Custom Element Registry is implemented.
/// This is acceptable as custom elements are an optional feature.
pub fn get_customElementRegistry(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    // Custom Element Registry not implemented - return null
    return null;
}

/// Getter for onfullscreenchange
/// Fullscreen API - Event handler for fullscreen changes
/// Spec: https://fullscreen.spec.whatwg.org/#handler-document-onfullscreenchange
///
/// Note: Returns null - fullscreen API requires browser integration.
pub fn get_onfullscreenchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    // Return null event handler (no fullscreen support without browser)
    return null;
}

/// Getter for onfullscreenerror
/// Fullscreen API - Event handler for fullscreen errors
/// Spec: https://fullscreen.spec.whatwg.org/#handler-document-onfullscreenerror
///
/// Note: Returns null - fullscreen API requires browser integration.
pub fn get_onfullscreenerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    // Return null event handler (no fullscreen support without browser)
    return null;
}

/// Getter for elementTiming
/// Element Timing API - Returns the value of the elementtiming attribute
/// Spec: https://wicg.github.io/element-timing/#dom-element-elementtiming
///
/// The elementTiming getter returns the value of the elementtiming content attribute.
pub fn get_elementTiming(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Look for elementtiming attribute
    if (internal.findAttribute(null, "elementtiming")) |entry| {
        return runtime.DOMString.initInterned(entry.value);
    }

    return runtime.DOMString.initEmpty();
}

/// Getter for part
/// CSS Shadow Parts - Returns the DOMTokenList for the part attribute
/// Spec: https://drafts.csswg.org/css-shadow-parts/#dom-element-part
///
/// The part getter returns a DOMTokenList reflecting the part attribute.
pub fn get_part(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Create a DOMTokenList for the part attribute
    // Use interface instead of impl (per Golden Rule #13)
    const token_list = interfaces.DOMTokenList.init(internal.allocator, instance.ctx) catch return error.OutOfMemory;
    errdefer interfaces.DOMTokenList.deinit(token_list);

    // Find current part attribute value
    if (internal.findAttribute(null, "part")) |entry| {
        interfaces.DOMTokenList.set_value(token_list, runtime.DOMString.initInterned(entry.value)) catch return error.OutOfMemory;
    }

    // Associate with this element and the "part" attribute (internal method)
    DOMTokenListImpl.setElement(token_list, instance, runtime.DOMString.initInterned("part"));

    return token_list;
}

/// Getter for activeViewTransition
/// View Transitions API - Returns the active ViewTransition for this element
/// Spec: https://drafts.csswg.org/css-view-transitions-2/#dom-element-activeviewtransition
///
/// Note: Returns null - View Transitions API requires rendering engine.
pub fn get_activeViewTransition(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    // View Transitions require rendering engine - return null
    return null;
}

/// Getter for innerHTML
/// DOM Parsing §3 - Returns the HTML serialization of the element's descendants
/// Spec: https://w3c.github.io/DOM-Parsing/#dom-element-innerhtml
///
/// Note: Simplified implementation - returns basic HTML structure.
/// Full implementation requires complete HTML serialization algorithm.
pub fn get_innerHTML(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = getInternal(instance) orelse return error.InvalidStateError;

    // IMPORTANT: Use instance.ctx.allocator for returned DOMStrings
    // The V8 property getter callback will free returned strings using instance.ctx.allocator
    const allocator = instance.ctx.allocator;

    // Build basic HTML from child elements using infra.List
    var result = infra.List(u8).init(allocator);
    errdefer result.deinit();

    // Iterate through children and serialize
    var child = NodeImpl.getFirstChild(instance);
    while (child) |c| {
        serializeNode(c, &result, allocator) catch return error.OutOfMemory;
        child = NodeImpl.getNextSibling(c);
    }

    // Return as DOMString - toOwnedSlice uses the List's allocator (ctx.allocator)
    const owned = result.toOwnedSlice() catch return error.OutOfMemory;
    return runtime.DOMString.initOwned(owned);
}

/// Getter for outerHTML
/// DOM Parsing §3 - Returns the HTML serialization of the element including itself
/// Spec: https://w3c.github.io/DOM-Parsing/#dom-element-outerhtml
///
/// Note: Simplified implementation - returns basic HTML structure.
/// Full implementation requires complete HTML serialization algorithm.
pub fn get_outerHTML(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = getInternal(instance) orelse return error.InvalidStateError;

    // IMPORTANT: Use instance.ctx.allocator for returned DOMStrings
    // The V8 property getter callback will free returned strings using instance.ctx.allocator
    const allocator = instance.ctx.allocator;

    var result = infra.List(u8).init(allocator);
    errdefer result.deinit();

    // Serialize this element including itself
    serializeNode(instance, &result, allocator) catch return error.OutOfMemory;

    // Return as DOMString - toOwnedSlice uses the List's allocator (ctx.allocator)
    const owned = result.toOwnedSlice() catch return error.OutOfMemory;
    return runtime.DOMString.initOwned(owned);
}

/// Internal helper to serialize a node to HTML
fn serializeNode(node: *runtime.Instance, result: *infra.List(u8), allocator: std.mem.Allocator) !void {
    _ = allocator;
    const node_type = NodeImpl.getNodeType(node) orelse return;

    switch (node_type) {
        NodeImpl.NodeType.ELEMENT_NODE => {
            // Get tag name
            const elem_internal = getInternal(node);
            if (elem_internal) |internal| {
                const tag = internal.local_name.asSlice();

                // Opening tag
                try result.append('<');
                try result.appendSlice(tag);

                // Attributes
                var attr_iter = internal.attributeIterator();
                while (attr_iter.next()) |attr| {
                    try result.append(' ');
                    try result.appendSlice(attr.local_name);
                    try result.appendSlice("=\"");
                    // Escape attribute value
                    for (attr.value) |c| {
                        switch (c) {
                            '"' => try result.appendSlice("&quot;"),
                            '&' => try result.appendSlice("&amp;"),
                            else => try result.append(c),
                        }
                    }
                    try result.append('"');
                }

                try result.append('>');

                // Children
                var child = NodeImpl.getFirstChild(node);
                while (child) |c| {
                    try serializeNode(c, result, internal.allocator);
                    child = NodeImpl.getNextSibling(c);
                }

                // Closing tag (skip for void elements)
                const void_elements = [_][]const u8{ "area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr" };
                var is_void = false;
                for (void_elements) |ve| {
                    if (std.ascii.eqlIgnoreCase(tag, ve)) {
                        is_void = true;
                        break;
                    }
                }

                if (!is_void) {
                    try result.appendSlice("</");
                    try result.appendSlice(tag);
                    try result.append('>');
                }
            }
        },
        NodeImpl.NodeType.TEXT_NODE => {
            // Get text content
            const text = CharacterDataImpl.getData(node);
            if (text) |t| {
                // Escape text content
                for (t) |c| {
                    switch (c) {
                        '<' => try result.appendSlice("&lt;"),
                        '>' => try result.appendSlice("&gt;"),
                        '&' => try result.appendSlice("&amp;"),
                        else => try result.append(c),
                    }
                }
            }
        },
        NodeImpl.NodeType.COMMENT_NODE => {
            try result.appendSlice("<!--");
            const text = CharacterDataImpl.getData(node);
            if (text) |t| {
                try result.appendSlice(t);
            }
            try result.appendSlice("-->");
        },
        else => {},
    }
}

/// Getter for scrollTop
/// CSSOM View §3.1 - Returns scroll position from top
/// Returns 0 for non-rendered elements (no layout engine)
pub fn get_scrollTop(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return 0.0;
}

/// Getter for scrollLeft
/// CSSOM View §3.1 - Returns scroll position from left
/// Returns 0 for non-rendered elements (no layout engine)
pub fn get_scrollLeft(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return 0.0;
}

/// Getter for scrollWidth
/// CSSOM View §3.1 - Returns scroll width of element
/// Returns 0 for non-rendered elements (no layout engine)
pub fn get_scrollWidth(instance: *runtime.Instance) anyerror!i32 {
    _ = instance;
    return 0;
}

/// Getter for scrollHeight
/// CSSOM View §3.1 - Returns scroll height of element
/// Returns 0 for non-rendered elements (no layout engine)
pub fn get_scrollHeight(instance: *runtime.Instance) anyerror!i32 {
    _ = instance;
    return 0;
}

/// Getter for clientTop
/// CSSOM View §3.1 - Returns top border width
/// Returns 0 for non-rendered elements (no layout engine)
pub fn get_clientTop(instance: *runtime.Instance) anyerror!i32 {
    _ = instance;
    return 0;
}

/// Getter for clientLeft
/// CSSOM View §3.1 - Returns left border width
/// Returns 0 for non-rendered elements (no layout engine)
pub fn get_clientLeft(instance: *runtime.Instance) anyerror!i32 {
    _ = instance;
    return 0;
}

/// Getter for clientWidth
/// CSSOM View §3.1 - Returns inner width of element
/// Returns 0 for non-rendered elements (no layout engine)
pub fn get_clientWidth(instance: *runtime.Instance) anyerror!i32 {
    _ = instance;
    return 0;
}

/// Getter for clientHeight
/// CSSOM View §3.1 - Returns inner height of element
/// Returns 0 for non-rendered elements (no layout engine)
pub fn get_clientHeight(instance: *runtime.Instance) anyerror!i32 {
    _ = instance;
    return 0;
}

/// Getter for currentCSSZoom
/// CSSOM View - Returns current CSS zoom level
/// Returns 1.0 (no zoom) for non-rendered elements
pub fn get_currentCSSZoom(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return 1.0;
}

/// Getter for role
/// ARIAMixin - Reflects the role attribute
pub fn get_role(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "role");
}

/// Getter for ariaActiveDescendantElement
/// ARIAMixin - Element reference attribute
/// Spec: https://w3c.github.io/aria/#aria-activedescendant
///
/// Returns the element referenced by aria-activedescendant, or null if not set
pub fn get_ariaActiveDescendantElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return getAriaElementRef(instance, "aria-activedescendant");
}

/// Getter for ariaAtomic
/// ARIAMixin - Reflects the aria-atomic attribute
pub fn get_ariaAtomic(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-atomic");
}

/// Getter for ariaAutoComplete
/// ARIAMixin - Reflects the aria-autocomplete attribute
pub fn get_ariaAutoComplete(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-autocomplete");
}

/// Getter for ariaBrailleLabel
/// ARIAMixin - Reflects the aria-braillelabel attribute
pub fn get_ariaBrailleLabel(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-braillelabel");
}

/// Getter for ariaBrailleRoleDescription
/// ARIAMixin - Reflects the aria-brailleroledescription attribute
pub fn get_ariaBrailleRoleDescription(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-brailleroledescription");
}

/// Getter for ariaBusy
/// ARIAMixin - Reflects the aria-busy attribute
pub fn get_ariaBusy(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-busy");
}

/// Getter for ariaChecked
/// ARIAMixin - Reflects the aria-checked attribute
pub fn get_ariaChecked(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-checked");
}

/// Getter for ariaColCount
/// ARIAMixin - Reflects the aria-colcount attribute
pub fn get_ariaColCount(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-colcount");
}

/// Getter for ariaColIndex
/// ARIAMixin - Reflects the aria-colindex attribute
pub fn get_ariaColIndex(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-colindex");
}

/// Getter for ariaColIndexText
/// ARIAMixin - Reflects the aria-colindextext attribute
pub fn get_ariaColIndexText(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-colindextext");
}

/// Getter for ariaColSpan
/// ARIAMixin - Reflects the aria-colspan attribute
pub fn get_ariaColSpan(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-colspan");
}

/// Getter for ariaControlsElements
/// ARIAMixin - Element array reference
/// Spec: https://w3c.github.io/aria/#dom-ariamixin-ariacontrolselements
///
/// Returns a frozen array of elements referenced by space-separated IDs in aria-controls.
/// Note: Returns null - full implementation requires FrozenArray support and ID resolution.
pub fn get_ariaControlsElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    _ = instance;
    // Return null - full implementation requires resolving space-separated IDs
    return null;
}

/// Getter for ariaCurrent
/// ARIAMixin - Reflects the aria-current attribute
pub fn get_ariaCurrent(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-current");
}

/// Getter for ariaDescribedByElements
/// ARIAMixin - Element array reference
/// Spec: https://w3c.github.io/aria/#aria-describedby
///
/// Returns an array of elements referenced by space-separated IDs in aria-describedby
/// Note: Returns null - full implementation requires FrozenArray support
pub fn get_ariaDescribedByElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    _ = instance;
    // Return null - full implementation requires resolving space-separated IDs
    return null;
}

/// Getter for ariaDescription
/// ARIAMixin - Reflects the aria-description attribute
pub fn get_ariaDescription(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-description");
}

/// Getter for ariaDetailsElements
/// ARIAMixin - Element array reference
/// Spec: https://w3c.github.io/aria/#aria-details
///
/// Returns an array of elements referenced by space-separated IDs in aria-details
/// Note: Returns null - full implementation requires FrozenArray support
pub fn get_ariaDetailsElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    _ = instance;
    // Return null - full implementation requires resolving space-separated IDs
    return null;
}

/// Getter for ariaDisabled
/// ARIAMixin - Reflects the aria-disabled attribute
pub fn get_ariaDisabled(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-disabled");
}

/// Getter for ariaErrorMessageElements
/// ARIAMixin - Element array reference
/// Spec: https://w3c.github.io/aria/#aria-errormessage
///
/// Returns an array of elements referenced by space-separated IDs in aria-errormessage
/// Note: Returns null - full implementation requires FrozenArray support
pub fn get_ariaErrorMessageElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    _ = instance;
    // Return null - full implementation requires resolving space-separated IDs
    return null;
}

/// Getter for ariaExpanded
/// ARIAMixin - Reflects the aria-expanded attribute
pub fn get_ariaExpanded(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-expanded");
}

/// Getter for ariaFlowToElements
/// ARIAMixin - Element array reference
/// Spec: https://w3c.github.io/aria/#aria-flowto
///
/// Returns an array of elements referenced by space-separated IDs in aria-flowto.
/// Note: Returns null - full implementation requires FrozenArray support and ID resolution.
pub fn get_ariaFlowToElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    _ = instance;
    // Return null - full implementation requires resolving space-separated IDs
    return null;
}

/// Getter for ariaHasPopup
/// ARIAMixin - Reflects the aria-haspopup attribute
pub fn get_ariaHasPopup(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-haspopup");
}

/// Getter for ariaHidden
/// ARIAMixin - Reflects the aria-hidden attribute
pub fn get_ariaHidden(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-hidden");
}

/// Getter for ariaInvalid
/// ARIAMixin - Reflects the aria-invalid attribute
pub fn get_ariaInvalid(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-invalid");
}

/// Getter for ariaKeyShortcuts
/// ARIAMixin - Reflects the aria-keyshortcuts attribute
pub fn get_ariaKeyShortcuts(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-keyshortcuts");
}

/// Getter for ariaLabel
/// ARIAMixin - Reflects the aria-label attribute
pub fn get_ariaLabel(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-label");
}

/// Getter for ariaLabelledByElements
/// ARIAMixin - Element array reference
/// Spec: https://w3c.github.io/aria/#aria-labelledby
///
/// Returns an array of elements referenced by space-separated IDs in aria-labelledby.
/// Note: Returns null - full implementation requires FrozenArray support and ID resolution.
pub fn get_ariaLabelledByElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    _ = instance;
    // Return null - full implementation requires resolving space-separated IDs
    return null;
}

/// Getter for ariaLevel
/// ARIAMixin - Reflects the aria-level attribute
pub fn get_ariaLevel(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-level");
}

/// Getter for ariaLive
/// ARIAMixin - Reflects the aria-live attribute
pub fn get_ariaLive(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-live");
}

/// Getter for ariaModal
/// ARIAMixin - Reflects the aria-modal attribute
pub fn get_ariaModal(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-modal");
}

/// Getter for ariaMultiLine
/// ARIAMixin - Reflects the aria-multiline attribute
pub fn get_ariaMultiLine(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-multiline");
}

/// Getter for ariaMultiSelectable
/// ARIAMixin - Reflects the aria-multiselectable attribute
pub fn get_ariaMultiSelectable(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-multiselectable");
}

/// Getter for ariaOrientation
/// ARIAMixin - Reflects the aria-orientation attribute
pub fn get_ariaOrientation(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-orientation");
}

/// Getter for ariaOwnsElements
/// ARIAMixin - Element array reference
/// Spec: https://w3c.github.io/aria/#aria-owns
///
/// Returns an array of elements referenced by space-separated IDs in aria-owns.
/// Note: Returns null - full implementation requires FrozenArray support and ID resolution.
pub fn get_ariaOwnsElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    _ = instance;
    // Return null - full implementation requires resolving space-separated IDs
    return null;
}

/// Getter for ariaPlaceholder
/// ARIAMixin - Reflects the aria-placeholder attribute
pub fn get_ariaPlaceholder(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-placeholder");
}

/// Getter for ariaPosInSet
/// ARIAMixin - Reflects the aria-posinset attribute
pub fn get_ariaPosInSet(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-posinset");
}

/// Getter for ariaPressed
/// ARIAMixin - Reflects the aria-pressed attribute
pub fn get_ariaPressed(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-pressed");
}

/// Getter for ariaReadOnly
/// ARIAMixin - Reflects the aria-readonly attribute
pub fn get_ariaReadOnly(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-readonly");
}

/// Getter for ariaRelevant
/// ARIAMixin - Reflects the aria-relevant attribute
pub fn get_ariaRelevant(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-relevant");
}

/// Getter for ariaRequired
/// ARIAMixin - Reflects the aria-required attribute
pub fn get_ariaRequired(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-required");
}

/// Getter for ariaRoleDescription
/// ARIAMixin - Reflects the aria-roledescription attribute
pub fn get_ariaRoleDescription(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-roledescription");
}

/// Getter for ariaRowCount
/// ARIAMixin - Reflects the aria-rowcount attribute
pub fn get_ariaRowCount(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-rowcount");
}

/// Getter for ariaRowIndex
/// ARIAMixin - Reflects the aria-rowindex attribute
pub fn get_ariaRowIndex(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-rowindex");
}

/// Getter for ariaRowIndexText
/// ARIAMixin - Reflects the aria-rowindextext attribute
pub fn get_ariaRowIndexText(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-rowindextext");
}

/// Getter for ariaRowSpan
/// ARIAMixin - Reflects the aria-rowspan attribute
pub fn get_ariaRowSpan(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-rowspan");
}

/// Getter for ariaSelected
/// ARIAMixin - Reflects the aria-selected attribute
pub fn get_ariaSelected(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-selected");
}

/// Getter for ariaSetSize
/// ARIAMixin - Reflects the aria-setsize attribute
pub fn get_ariaSetSize(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-setsize");
}

/// Getter for ariaSort
/// ARIAMixin - Reflects the aria-sort attribute
pub fn get_ariaSort(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-sort");
}

/// Getter for ariaValueMax
/// ARIAMixin - Reflects the aria-valuemax attribute
pub fn get_ariaValueMax(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-valuemax");
}

/// Getter for ariaValueMin
/// ARIAMixin - Reflects the aria-valuemin attribute
pub fn get_ariaValueMin(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-valuemin");
}

/// Getter for ariaValueNow
/// ARIAMixin - Reflects the aria-valuenow attribute
pub fn get_ariaValueNow(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-valuenow");
}

/// Getter for ariaValueText
/// ARIAMixin - Reflects the aria-valuetext attribute
pub fn get_ariaValueText(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaAttribute(instance, "aria-valuetext");
}

/// Getter for regionOverset
/// CSS Regions §10.2 - Returns the region's overset state
/// Spec: https://drafts.csswg.org/css-regions-1/#dom-region-regionoverset
///
/// Note: CSS Regions is deprecated/removed from most browsers.
/// Returns empty string as no region flow is active.
pub fn get_regionOverset(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    _ = instance;
    // CSS Regions not supported - return empty string
    return .{ .empty = {} };
}

/// Getter for children
/// ParentNode mixin - Returns an HTMLCollection of child elements
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-children
pub fn get_children(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return ParentNode.get_children(instance);
}

/// Getter for firstElementChild
/// ParentNode mixin - Returns the first child that is an element
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-firstelementchild
pub fn get_firstElementChild(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return ParentNode.get_firstElementChild(instance);
}

/// Getter for lastElementChild
/// ParentNode mixin - Returns the last child that is an element
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-lastelementchild
pub fn get_lastElementChild(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return ParentNode.get_lastElementChild(instance);
}

/// Getter for childElementCount
/// ParentNode mixin - Returns the number of child elements
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-childelementcount
pub fn get_childElementCount(instance: *runtime.Instance) anyerror!u32 {
    return ParentNode.get_childElementCount(instance);
}

/// Getter for previousElementSibling
/// NonDocumentTypeChildNode mixin - Returns the previous sibling that is an element
/// Spec: https://dom.spec.whatwg.org/#dom-nondocumenttypechildnode-previouselementsibling
pub fn get_previousElementSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return NonDocumentTypeChildNode.get_previousElementSibling(instance);
}

/// Getter for nextElementSibling
/// NonDocumentTypeChildNode mixin - Returns the next sibling that is an element
/// Spec: https://dom.spec.whatwg.org/#dom-nondocumenttypechildnode-nextelementsibling
pub fn get_nextElementSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return NonDocumentTypeChildNode.get_nextElementSibling(instance);
}

/// Getter for assignedSlot
/// Slottable mixin - Returns the slot this element is assigned to
/// Spec: https://dom.spec.whatwg.org/#dom-slottable-assignedslot
///
/// The assignedSlot getter steps are to return the result of find a slot
/// given this and with the open flag set.
///
/// Returns null if:
/// - Element is not assigned to any slot
/// - Element is assigned to a slot in a closed shadow root
pub fn get_assignedSlot(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Get the assigned slot
    const slot = internal.assigned_slot orelse return null;

    // Check if the slot's shadow root is open (per spec, only return for open mode)
    // The slot is an HTMLSlotElement which is in a ShadowRoot
    // We need to check if that shadow root has mode = "open"

    // Get the slot's parent/root to check if it's in an open shadow root
    // For now, return the slot if it exists - full implementation would
    // walk up to find the shadow root and check its mode
    // TODO: Implement full "find a slot" algorithm with open flag check

    return slot;
}

/// Setter for id: `id` reflects "id".
/// Spec: https://dom.spec.whatwg.org/#dom-element-id
pub fn set_id(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setAttributeValue(instance, "id", value.asSlice(), null, null);
}

/// Setter for className: `className` reflects "class".
/// Spec: https://dom.spec.whatwg.org/#dom-element-classname
pub fn set_className(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setAttributeValue(instance, "class", value.asSlice(), null, null);
}

/// Setter for slot: `slot` reflects "slot".
/// Spec: https://dom.spec.whatwg.org/#dom-element-slot
pub fn set_slot(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setAttributeValue(instance, "slot", value.asSlice(), null, null);
}

// =============================================================================
// The attribute list - DOM §4.9
//
// Every change to an element's attributes goes through the four algorithms
// "change", "append", "remove" and "replace" below, and each of them ends in
// "handle attribute changes": the mutation record, the custom element
// reaction and the attribute change steps. The id, class and slot caches are
// kept in step by those change steps, and by nothing else.
//
// Subclasses (HTMLElement's reflection, the script element's attributes) use
// the public "get / set an attribute value" and "remove an attribute"
// entry points; nothing outside this file touches the list directly.
// =============================================================================

/// "element is in the HTML namespace and its node document is an HTML
/// document": when getAttribute, setAttribute, hasAttribute, removeAttribute
/// and toggleAttribute lowercase the name they are given.
fn isHtmlElementInHtmlDocument(instance: *runtime.Instance, internal: *const InternalState) bool {
    const ns = internal.namespace_uri orelse return false;
    if (!std.mem.eql(u8, ns.asSlice(), infra.namespaces.HTML_NAMESPACE)) return false;
    const document = NodeImpl.getOwnerDocument(instance) orelse return false;
    return dom.document_internals.getDocumentType(document) == .html;
}

/// A name as an attribute lookup should see it: `qualifiedName in ASCII
/// lowercase` when the element is an HTML element in an HTML document.
/// Short names are lowercased into the caller's buffer.
const LookupName = struct {
    slice: []const u8,
    owned: ?[]u8 = null,

    fn deinit(self: LookupName, allocator: std.mem.Allocator) void {
        if (self.owned) |owned| allocator.free(owned);
    }
};

fn lookupName(instance: *runtime.Instance, internal: *const InternalState, name: []const u8, buffer: []u8) !LookupName {
    // A name with no ASCII upper alpha is its own lowercase - the case for
    // every name the HTML parser produces - so skip the document check.
    const has_upper = for (name) |c| {
        if (std.ascii.isUpper(c)) break true;
    } else false;
    if (!has_upper or !isHtmlElementInHtmlDocument(instance, internal)) return .{ .slice = name };

    if (name.len <= buffer.len) return .{ .slice = std.ascii.lowerString(buffer[0..name.len], name) };
    const owned = try std.ascii.allocLowerString(internal.allocator, name);
    return .{ .slice = owned, .owned = owned };
}

/// DOM "handle attribute changes" for an attribute - identified by its
/// namespace and local name - with this element, oldValue and newValue.
///
/// Spec: https://dom.spec.whatwg.org/#handle-attribute-changes
fn handleAttributeChanges(
    instance: *runtime.Instance,
    namespace: ?[]const u8,
    local_name: []const u8,
    old_value: ?[]const u8,
    new_value: ?[]const u8,
) void {
    // Step 1: "Queue a mutation record of "attributes" for element with
    // attribute's local name, attribute's namespace, oldValue, « », « »,
    // null, and null." The record copies what it keeps. A failure to queue
    // one must not skip the change steps below - the attribute has already
    // changed, and its caches must follow.
    dom.mutation_observer_algorithms.queueAttributeMutationRecord(instance, local_name, namespace, old_value) catch |err| {
        std.log.scoped(.element).warn("attributes mutation record not queued: {}", .{err});
    };

    // Step 2: "If element is custom, then enqueue a custom element callback
    // reaction with element, callback name "attributeChangedCallback", and
    // « attribute's local name, oldValue, newValue, attribute's namespace »."
    // TODO(custom-elements): nothing moves an element's custom element state
    // past "undefined" yet, so no element is custom and there is no
    // definition to consult. Enqueue here once upgrades set the state.

    // Step 3: "Run the attribute change steps with element, attribute's local
    // name, oldValue, newValue, and attribute's namespace."
    attributeChangeSteps(instance, local_name, old_value, new_value, namespace);
}

/// The attribute change steps this engine defines, in one place.
///
/// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-change-ext
///
/// The image step can run script - it fetches and fires load or error
/// synchronously - so it goes last, after every step that reads the name and
/// value it was handed.
fn attributeChangeSteps(
    instance: *runtime.Instance,
    local_name: []const u8,
    old_value: ?[]const u8,
    value: ?[]const u8,
    namespace: ?[]const u8,
) void {
    _ = old_value;
    // Every step below concerns attributes in no namespace.
    if (namespace != null) return;
    const internal = getInternal(instance) orelse return;

    // DOM §4.9: "If localName is id, namespace is null, and value is null or
    // the empty string, then unset element's ID. Otherwise, if localName is
    // id, namespace is null, then set element's ID to value." The class and
    // slot caches follow their attributes the same way.
    if (std.mem.eql(u8, local_name, "id")) {
        replaceCachedValue(internal, &internal.id, value);
    } else if (std.mem.eql(u8, local_name, "class")) {
        replaceCachedValue(internal, &internal.class_name, value);
    } else if (std.mem.eql(u8, local_name, "slot")) {
        replaceCachedValue(internal, &internal.slot, value);
    }

    // HTML §8.1.8.1: event handler content attributes.
    eventHandlerAttributeChangeSteps(instance, local_name, value);

    // HTML "update the image data", for an img whose src is set.
    if (value) |v| {
        if (std.mem.eql(u8, local_name, "src") and std.mem.eql(u8, internal.local_name.asSlice(), "img")) {
            triggerImageSrcChange(instance, v);
        }
    }
}

fn replaceCachedValue(internal: *InternalState, cache: *runtime.DOMString, value: ?[]const u8) void {
    cache.deinit(internal.allocator);
    cache.* = runtime.DOMString.initEmpty();
    if (value) |v| {
        // A failed copy leaves the cache empty; the attribute itself is set.
        cache.* = runtime.DOMString.initDupe(internal.allocator, v) catch runtime.DOMString.initEmpty();
    }
}

/// DOM "change an attribute" - the one at `index` - to `value`.
///
/// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-change
fn changeAttribute(instance: *runtime.Instance, internal: *InternalState, index: usize, value: []const u8) !void {
    const entry = internal.attributeAt(index) orelse return error.InvalidStateError;
    const new_value = try internal.allocator.dupe(u8, value);

    // Step 1: "Let oldValue be attribute's value."
    const old_value = entry.value;
    defer internal.allocator.free(old_value);

    // Step 2: "Set attribute's value to value."
    entry.value = new_value;

    // Step 3: "Handle attribute changes for attribute with attribute's
    // element, oldValue, and value."
    handleAttributeChanges(instance, entry.namespace_uri, entry.local_name, old_value, new_value);
}

/// DOM "append an attribute" to this element.
///
/// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-append
fn appendAttribute(
    instance: *runtime.Instance,
    internal: *InternalState,
    namespace: ?[]const u8,
    prefix: ?[]const u8,
    local_name: []const u8,
    value: []const u8,
) !void {
    const allocator = internal.allocator;
    const namespace_copy: ?[]const u8 = if (namespace) |ns| try allocator.dupe(u8, ns) else null;
    errdefer if (namespace_copy) |ns| allocator.free(ns);
    const prefix_copy: ?[]const u8 = if (prefix) |p| try allocator.dupe(u8, p) else null;
    errdefer if (prefix_copy) |p| allocator.free(p);
    const local_name_copy = try allocator.dupe(u8, local_name);
    errdefer allocator.free(local_name_copy);
    const value_copy = try allocator.dupe(u8, value);
    errdefer allocator.free(value_copy);

    const entry = AttributeEntry{
        .namespace_uri = namespace_copy,
        .prefix = prefix_copy,
        .local_name = local_name_copy,
        .value = value_copy,
    };

    // Step 1: "Append attribute to element's attribute list."
    try internal.addAttribute(entry);

    // Steps 2 and 3 set the attribute's element and node document: this list
    // stores the attribute's data, and an Attr node made for it takes both
    // from the element when it is created.

    // Step 4: "Handle attribute changes for attribute with element, null, and
    // attribute's value."
    handleAttributeChanges(instance, entry.namespace_uri, entry.local_name, null, entry.value);
}

/// DOM "remove an attribute" - the one at `index`.
///
/// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-remove
fn removeAttributeAt(instance: *runtime.Instance, internal: *InternalState, index: usize) void {
    // Steps 1 and 2: "Let element be attribute's element. Remove attribute
    // from element's attribute list." The entry is ours until the changes
    // below have read its name and value.
    var entry = internal.takeAttributeAt(index);
    defer InternalState.freeAttributeEntry(internal.allocator, entry);

    // Step 3: "Set attribute's element to null." - its Attr node, if script
    // has one, keeps the value it had here.
    detachAttrNode(&entry);

    // Step 4: "Handle attribute changes for attribute with element,
    // attribute's value, and null."
    handleAttributeChanges(instance, entry.namespace_uri, entry.local_name, entry.value, null);
}

/// DOM "get an attribute value": the value of the attribute with this
/// namespace and local name, or the empty string. Borrowed - valid until the
/// attribute next changes.
///
/// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-get-value
pub fn getAttributeValue(instance: *runtime.Instance, local_name: []const u8, namespace: ?[]const u8) []const u8 {
    const internal = getInternal(instance) orelse return "";
    const entry = internal.findAttribute(namespace, local_name) orelse return "";
    return entry.value;
}

/// DOM "set an attribute value": the setter steps of every reflected string
/// attribute, and of the internal callers that set a content attribute.
///
/// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-set-value
pub fn setAttributeValue(
    instance: *runtime.Instance,
    local_name: []const u8,
    value: []const u8,
    prefix: ?[]const u8,
    namespace: ?[]const u8,
) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: "Let attribute be the result of getting an attribute given
    // namespace, localName, and element."
    const index = internal.indexOfAttribute(namespace, local_name) orelse {
        // Step 2: "If attribute is null, create an attribute whose namespace
        // is namespace, namespace prefix is prefix, local name is localName,
        // value is value, and node document is element's node document, then
        // append this attribute to element, and then return."
        return appendAttribute(instance, internal, namespace, prefix, local_name, value);
    };

    // Step 3: "Change attribute to value."
    return changeAttribute(instance, internal, index, value);
}

/// DOM "remove an attribute by namespace and local name".
///
/// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-remove-by-namespace
pub fn removeAttributeByNamespaceAndLocalName(instance: *runtime.Instance, namespace: ?[]const u8, local_name: []const u8) void {
    const internal = getInternal(instance) orelse return;
    // Step 1: "Let attr be the result of getting an attribute given
    // namespace, localName, and element." (Getting one maps "" to null.)
    const ns: ?[]const u8 = if (namespace) |n| (if (n.len == 0) null else n) else null;
    // Step 2: "If attr is non-null, then remove attr."
    const index = internal.indexOfAttribute(ns, local_name) orelse return;
    removeAttributeAt(instance, internal, index);
}

/// DOM "remove an attribute by name": the first attribute whose qualified
/// name is `qualified_name`, after lowercasing for an HTML element in an HTML
/// document.
///
/// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-remove-by-name
pub fn removeAttributeByName(instance: *runtime.Instance, qualified_name: []const u8) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    var buffer: [64]u8 = undefined;
    const name = try lookupName(instance, internal, qualified_name, &buffer);
    defer name.deinit(internal.allocator);
    // Step 1: "Let attr be the result of getting an attribute given
    // qualifiedName and element."
    // Step 2: "If attr is non-null, then remove attr."
    const index = internal.indexOfQualifiedName(name.slice) orelse return;
    removeAttributeAt(instance, internal, index);
}

/// `dom.element_attributes.at`: the list read in place.
fn attributeAtHook(element: *runtime.Instance, index: usize) ?dom.element_attributes.Attribute {
    const internal = getInternal(element) orelse return null;
    const entry = internal.attributeAt(index) orelse return null;
    return .{
        .namespace = entry.namespace_uri,
        .prefix = entry.prefix,
        .local_name = entry.local_name,
        .value = entry.value,
    };
}

/// `dom.element_attributes.count`.
fn attributeCountHook(element: *runtime.Instance) usize {
    const internal = getInternal(element) orelse return 0;
    return internal.getAttributeCount();
}

/// `dom.element_attributes.append`: "append an attribute" with exactly the
/// fields given.
fn appendAttributeHook(element: *runtime.Instance, attribute: dom.element_attributes.Attribute) dom.element_attributes.Error!void {
    const internal = getInternal(element) orelse return error.InvalidStateError;
    return appendAttribute(element, internal, attribute.namespace, attribute.prefix, attribute.local_name, attribute.value);
}

/// `dom.element_attributes.change`: an Attr node's "set an existing attribute
/// value" for an attribute that has an element.
fn changeAttributeHook(element: *runtime.Instance, namespace: ?[]const u8, local_name: []const u8, value: []const u8) dom.element_attributes.Error!void {
    const internal = getInternal(element) orelse return error.InvalidStateError;
    const index = internal.indexOfAttribute(namespace, local_name) orelse return error.InvalidStateError;
    changeAttribute(element, internal, index, value) catch |err| return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => error.InvalidStateError,
    };
}

/// `dom.element_attributes.nodeAt`: NamedNodeMap's item(index).
fn attrNodeAtHook(element: *runtime.Instance, index: usize) dom.element_attributes.Error!?*runtime.Instance {
    const internal = getInternal(element) orelse return null;
    if (index >= internal.getAttributeCount()) return null;
    return ensureAttrNode(element, internal, index) catch |err| switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => error.InvalidStateError,
    };
}

// Note: matches(), closest(), and webkitMatchesSelector() delegate to ParentNode mixin
// which has access to the selector module. Element.zig cannot access selector directly.

// =============================================================================
// Insert Adjacent Algorithm (DOM §4.10.7)
// =============================================================================

/// InsertAdjacent error type
const InsertAdjacentError = error{
    SyntaxError,
    InvalidStateError,
};

/// Insert adjacent algorithm - shared by insertAdjacentElement and insertAdjacentText
/// Spec: https://dom.spec.whatwg.org/#insert-adjacent
///
/// To insert adjacent, given an element element, string where, and a node node:
/// 1. If where is "beforebegin": If element's parent is null, return null.
///    Otherwise, return pre-insert node into element's parent before element.
/// 2. If where is "afterbegin": Return pre-insert node into element before element's first child.
/// 3. If where is "beforeend": Return pre-insert node into element before null.
/// 4. If where is "afterend": If element's parent is null, return null.
///    Otherwise, return pre-insert node into element's parent before element's next sibling.
/// 5. Otherwise: Throw a "SyntaxError" DOMException.
fn insertAdjacent(
    element: *runtime.Instance,
    where: []const u8,
    node: *runtime.Instance,
) InsertAdjacentError!?*runtime.Instance {
    // Case-insensitive comparison per spec
    if (std.ascii.eqlIgnoreCase(where, "beforebegin")) {
        // Insert before this element (requires parent)
        const parent = NodeImpl.getParent(element) orelse return null;

        // Insert node into parent before element
        _ = interfaces.Node.call_insertBefore(parent, node, element) catch {
            return error.InvalidStateError;
        };
        return node;
    } else if (std.ascii.eqlIgnoreCase(where, "afterbegin")) {
        // Insert as first child of this element
        const first_child = NodeImpl.getFirstChild(element);

        if (first_child) |fc| {
            _ = interfaces.Node.call_insertBefore(element, node, fc) catch {
                return error.InvalidStateError;
            };
        } else {
            _ = interfaces.Node.call_appendChild(element, node) catch {
                return error.InvalidStateError;
            };
        }
        return node;
    } else if (std.ascii.eqlIgnoreCase(where, "beforeend")) {
        // Insert as last child of this element
        _ = interfaces.Node.call_appendChild(element, node) catch {
            return error.InvalidStateError;
        };
        return node;
    } else if (std.ascii.eqlIgnoreCase(where, "afterend")) {
        // Insert after this element (requires parent)
        const parent = NodeImpl.getParent(element) orelse return null;
        const next_sibling = NodeImpl.getNextSibling(element);

        if (next_sibling) |ns| {
            _ = interfaces.Node.call_insertBefore(parent, node, ns) catch {
                return error.InvalidStateError;
            };
        } else {
            _ = interfaces.Node.call_appendChild(parent, node) catch {
                return error.InvalidStateError;
            };
        }
        return node;
    } else {
        // Invalid position - throw SyntaxError
        return error.SyntaxError;
    }
}

// =============================================================================
// ARIA Attribute Helpers
// =============================================================================

/// Get an ARIA attribute value. The ARIA attributes reflect as nullable
/// DOMStrings: "If attr is null, then return null."
/// Spec: https://html.spec.whatwg.org/multipage/common-dom-interfaces.html#reflecting-content-attributes-in-idl-attributes
fn getAriaAttribute(instance: *runtime.Instance, aria_name: []const u8) ?runtime.DOMString {
    const internal = getInternal(instance) orelse return null;
    const entry = internal.findAttribute(null, aria_name) orelse return null;
    return runtime.DOMString.initInterned(entry.value);
}

/// Set an ARIA attribute value: a null value removes the attribute, anything
/// else sets it - the setter steps of a reflected nullable DOMString.
fn setAriaAttribute(instance: *runtime.Instance, aria_name: []const u8, value: ?runtime.DOMString) ImplError!void {
    if (value) |v| {
        setAttributeValue(instance, aria_name, v.asSlice(), null, null) catch |err| return switch (err) {
            error.OutOfMemory => error.OutOfMemory,
            else => error.InvalidStateError,
        };
    } else {
        removeAttributeByNamespaceAndLocalName(instance, null, aria_name);
    }
}

/// Get an element by ID from the owner document (for ARIA element reference attributes)
/// Returns null if the element is not connected to a document or the ID is not found
fn getElementByIdFromDocument(instance: *runtime.Instance, id: []const u8) ?*runtime.Instance {
    if (id.len == 0) return null;

    // Get the owner document (nullable return type now)
    const owner_doc_opt = interfaces.Node.get_ownerDocument(instance) catch return null;
    const owner_doc = owner_doc_opt orelse return null;

    // Use document's getElementById
    // Use interface instead of impl (per Golden Rule #13)
    const result = interfaces.Document.call_getElementById(owner_doc, runtime.DOMString.initInterned(id)) catch return null;
    return result;
}

/// Get an ARIA element reference attribute (single element)
/// These attributes contain an ID reference that needs to be resolved to an element
fn getAriaElementRef(instance: *runtime.Instance, aria_attr: []const u8) ?*runtime.Instance {
    // Get the attribute value (contains an ID)
    const attr_value = getAriaAttribute(instance, aria_attr) orelse return null;
    const id = attr_value.asSlice();
    if (id.len == 0) return null;

    return getElementByIdFromDocument(instance, id);
}

/// Set an ARIA element reference attribute
/// Takes an element and stores its ID as the attribute value
fn setAriaElementRef(instance: *runtime.Instance, aria_attr: []const u8, element: ?*runtime.Instance) ImplError!void {
    if (element) |elem| {
        // Get the element's ID
        if (getInternal(elem)) |elem_internal| {
            const elem_id = elem_internal.id.asSlice();
            if (elem_id.len > 0) {
                // Set the ARIA attribute to the element's ID
                return setAriaAttribute(instance, aria_attr, runtime.DOMString.initInterned(elem_id));
            }
        }
    }
    // Element is null or has no ID - remove the attribute
    removeAttributeByNamespaceAndLocalName(instance, null, aria_attr);
}

// =============================================================================
// Tree Traversal Helpers for getElementsBy* methods
// =============================================================================

/// Collect descendants matching tag name (tree order traversal)
fn collectElementsByTagName(
    root: *runtime.Instance,
    qualified_name: []const u8,
    collection: *runtime.Instance,
) !void {
    const HTMLCollectionImpl = @import("HTMLCollection.zig");

    // Get first child
    var child = NodeImpl.getFirstChild(root);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            // Check if matches
            if (getInternal(c)) |child_internal| {
                const local_name = child_internal.local_name.asSlice();
                const matches = std.mem.eql(u8, qualified_name, "*") or
                    std.ascii.eqlIgnoreCase(local_name, qualified_name);

                if (matches) {
                    try HTMLCollectionImpl.addElement(collection, c);
                }
            }

            // Recurse into descendants
            try collectElementsByTagName(c, qualified_name, collection);
        }

        child = NodeImpl.getNextSibling(c);
    }
}

/// Collect descendants matching namespace and local name (tree order traversal)
fn collectElementsByTagNameNS(
    root: *runtime.Instance,
    namespace: []const u8,
    local_name: []const u8,
    collection: *runtime.Instance,
) !void {
    const HTMLCollectionImpl = @import("HTMLCollection.zig");

    var child = NodeImpl.getFirstChild(root);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            if (getInternal(c)) |child_internal| {
                // Check namespace match ("*" matches any)
                const ns_matches = std.mem.eql(u8, namespace, "*") or blk: {
                    if (child_internal.namespace_uri) |ns| {
                        break :blk std.mem.eql(u8, ns.asSlice(), namespace);
                    }
                    break :blk namespace.len == 0;
                };

                // Check local name match ("*" matches any)
                const name_matches = std.mem.eql(u8, local_name, "*") or
                    std.mem.eql(u8, child_internal.local_name.asSlice(), local_name);

                if (ns_matches and name_matches) {
                    try HTMLCollectionImpl.addElement(collection, c);
                }
            }

            // Recurse into descendants
            try collectElementsByTagNameNS(c, namespace, local_name, collection);
        }

        child = NodeImpl.getNextSibling(c);
    }
}

/// Collect descendants with all specified class names (tree order traversal)
fn collectElementsByClassName(
    root: *runtime.Instance,
    class_names: []const u8,
    collection: *runtime.Instance,
) !void {
    const HTMLCollectionImpl = @import("HTMLCollection.zig");

    var child = NodeImpl.getFirstChild(root);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            if (getInternal(c)) |child_internal| {
                const class_attr = child_internal.class_name.asSlice();

                // Check if element has ALL required classes
                var all_found = true;
                var required_iter = std.mem.tokenizeScalar(u8, class_names, ' ');
                while (required_iter.next()) |required_class| {
                    if (required_class.len == 0) continue;

                    var found = false;
                    var elem_iter = std.mem.tokenizeScalar(u8, class_attr, ' ');
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

                if (all_found and class_names.len > 0) {
                    try HTMLCollectionImpl.addElement(collection, c);
                }
            }

            // Recurse into descendants
            try collectElementsByClassName(c, class_names, collection);
        }

        child = NodeImpl.getNextSibling(c);
    }
}

/// Setter for onfullscreenchange
/// Fullscreen API - Sets the event handler for fullscreen changes
/// Spec: https://fullscreen.spec.whatwg.org/#handler-document-onfullscreenchange
///
/// Note: No-op without fullscreen API support
pub fn set_onfullscreenchange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - fullscreen API requires browser integration
}

/// Setter for onfullscreenerror
/// Fullscreen API - Sets the event handler for fullscreen errors
/// Spec: https://fullscreen.spec.whatwg.org/#handler-document-onfullscreenerror
///
/// Note: No-op without fullscreen API support
pub fn set_onfullscreenerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - fullscreen API requires browser integration
}

/// Setter for elementTiming
/// Element Timing API - Sets the elementtiming attribute value
/// Spec: https://wicg.github.io/element-timing/#sec-modifications-dom
///
/// Sets the element's timing identifier for performance monitoring
pub fn set_elementTiming(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setAttributeValue(instance, "elementtiming", value.asSlice(), null, null);
}

/// Setter for innerHTML
/// DOM Parsing §3.2 - Sets the element's inner HTML
/// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#the-innerhtml-property
///
/// Steps:
/// 1. Parse the string using the HTML fragment parsing algorithm
/// 2. Remove all children from this element
/// 3. Append parsed nodes to this element
///
/// HTML Standard - Sets the innerHTML of this element
/// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#the-innerhtml-property
///
/// Steps:
/// 1. Let context element be this (the element)
/// 2. Parse the string using the HTML fragment parsing algorithm with context
/// 3. Replace all children of context with the parsed nodes
pub fn set_innerHTML(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const html_string = value.asSlice();

    // Import HTMLParser for fragment parsing
    const HTMLParser = @import("HTMLParser.zig");
    const element_base = dom.instance_bridge.getNodeBase(@ptrCast(instance)) orelse return error.InvalidStateError;

    // The empty string parses to an empty fragment: replace all with nothing.
    if (html_string.len == 0) {
        try dom.mutation.replaceAll(@as(?*dom.NodeBase, null), element_base);
        return;
    }

    // Step 1: "Let fragment be the result of invoking the fragment parsing
    // algorithm steps with context and compliantString."
    const fragment = HTMLParser.parseFragment(
        internal.allocator,
        instance.ctx,
        html_string,
        instance,
    ) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.NotSupportedError,
    };

    // The fragment is empty once its children have moved.
    defer interfaces.DocumentFragment.deinit(fragment);
    const fragment_base = dom.instance_bridge.getNodeBase(@ptrCast(fragment)) orelse return error.InvalidStateError;

    // Step 2: "If context is a template element, then set context to the
    // template element's template contents."
    // TODO(template): the template contents fragment has no seam from here
    // yet; the children land on the template element itself, as before.

    // Step 3: "Replace all with fragment within context." One tree mutation
    // record for the whole change; removing each child and moving each
    // parsed node one at a time queued a record apiece.
    try dom.mutation.replaceAll(@as(?*dom.NodeBase, fragment_base), element_base);
}

/// Setter for outerHTML
/// DOM Parsing §3.2 - Replaces the element with parsed HTML
/// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#the-outerhtml-property
///
/// Steps:
/// 1. Let parent be this element's parent
/// 2. If parent is null, return
/// 3. If parent is a Document, throw a NoModificationAllowedError
/// 4. Parse the string using the HTML fragment parsing algorithm with parent as context
/// 5. Replace this element with the parsed nodes
pub fn set_outerHTML(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const html_string = value.asSlice();

    // Step 1-2: Get parent, return if null
    const parent = NodeImpl.getParent(instance) orelse return;

    // Step 3: Check if parent is a Document (not allowed)
    const parent_type = NodeImpl.getNodeType(parent) orelse return error.InvalidStateError;
    if (parent_type == NodeImpl.NodeType.DOCUMENT_NODE) {
        return error.HierarchyRequestError;
    }

    // Import HTMLParser for fragment parsing
    const HTMLParser = @import("HTMLParser.zig");

    // Step 4: Parse the HTML fragment using parent as context
    const fragment = HTMLParser.parseFragment(
        internal.allocator,
        instance.ctx,
        html_string,
        parent,
    ) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.NotSupportedError,
    };

    // Step 5: Replace this element with the parsed nodes
    // Insert all children from fragment before this element, then remove this element
    var fragment_child = NodeImpl.getFirstChild(fragment);
    while (fragment_child) |fc| {
        const next = NodeImpl.getNextSibling(fc);
        // Remove from fragment
        _ = interfaces.Node.call_removeChild(fragment, fc) catch break;
        // Insert before this element
        _ = interfaces.Node.call_insertBefore(parent, fc, instance) catch break;
        fragment_child = next;
    }

    // Remove this element from parent
    _ = interfaces.Node.call_removeChild(parent, instance) catch {};

    // Clean up the fragment
    interfaces.DocumentFragment.deinit(fragment);
}

/// Setter for scrollTop
/// CSSOM View §3.1 - Sets scroll position from top
/// No-op for non-rendered elements (no layout engine)
pub fn set_scrollTop(instance: *runtime.Instance, value: f64) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - would require layout engine to scroll
}

/// Setter for scrollLeft
/// CSSOM View §3.1 - Sets scroll position from left
/// No-op for non-rendered elements (no layout engine)
pub fn set_scrollLeft(instance: *runtime.Instance, value: f64) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - would require layout engine to scroll
}

/// Setter for role
/// ARIAMixin - Sets the role attribute
pub fn set_role(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "role", value);
}

/// Setter for ariaActiveDescendantElement
/// ARIAMixin - Element reference setter
/// Spec: https://w3c.github.io/aria/#dom-ariamixin-ariaactivedescendantelement
///
/// Sets the element that is the active descendant. This should set
/// aria-activedescendant to the target element's ID.
/// Note: No-op - full implementation requires getting target element's ID
/// and setting aria-activedescendant attribute.
pub fn set_ariaActiveDescendantElement(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - would need to get value's ID and set aria-activedescendant
    // Full implementation requires: get ID from value element, set attribute
}

/// Setter for ariaAtomic
/// ARIAMixin - Sets the aria-atomic attribute
pub fn set_ariaAtomic(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-atomic", value);
}

/// Setter for ariaAutoComplete
/// ARIAMixin - Sets the aria-autocomplete attribute
pub fn set_ariaAutoComplete(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-autocomplete", value);
}

/// Setter for ariaBrailleLabel
/// ARIAMixin - Sets the aria-braillelabel attribute
pub fn set_ariaBrailleLabel(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-braillelabel", value);
}

/// Setter for ariaBrailleRoleDescription
/// ARIAMixin - Sets the aria-brailleroledescription attribute
pub fn set_ariaBrailleRoleDescription(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-brailleroledescription", value);
}

/// Setter for ariaBusy
/// ARIAMixin - Sets the aria-busy attribute
pub fn set_ariaBusy(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-busy", value);
}

/// Setter for ariaChecked
/// ARIAMixin - Sets the aria-checked attribute
pub fn set_ariaChecked(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-checked", value);
}

/// Setter for ariaColCount
/// ARIAMixin - Sets the aria-colcount attribute
pub fn set_ariaColCount(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-colcount", value);
}

/// Setter for ariaColIndex
/// ARIAMixin - Sets the aria-colindex attribute
pub fn set_ariaColIndex(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-colindex", value);
}

/// Setter for ariaColIndexText
/// ARIAMixin - Sets the aria-colindextext attribute
pub fn set_ariaColIndexText(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-colindextext", value);
}

/// Setter for ariaColSpan
/// ARIAMixin - Sets the aria-colspan attribute
pub fn set_ariaColSpan(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-colspan", value);
}

/// Setter for ariaControlsElements
/// ARIAMixin - Element array reference setter
/// Spec: https://w3c.github.io/aria/#dom-ariamixin-ariacontrolselements
///
/// Sets the elements that this element controls. This should set
/// aria-controls to space-separated IDs of the target elements.
/// Note: No-op - full implementation requires FrozenArray handling and ID extraction.
pub fn set_ariaControlsElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - would need to extract IDs from elements and set aria-controls
}

/// Setter for ariaCurrent
/// ARIAMixin - Sets the aria-current attribute
pub fn set_ariaCurrent(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-current", value);
}

/// Setter for ariaDescribedByElements
/// ARIAMixin - Element array reference setter
/// Spec: https://w3c.github.io/aria/#dom-ariamixin-ariadescribedbyelements
///
/// Sets the elements that describe this element. This should set
/// aria-describedby to space-separated IDs of the target elements.
/// Note: No-op - full implementation requires FrozenArray handling and ID extraction.
pub fn set_ariaDescribedByElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - would need to extract IDs from elements and set aria-describedby
}

/// Setter for ariaDescription
/// ARIAMixin - Sets the aria-description attribute
pub fn set_ariaDescription(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-description", value);
}

/// Setter for ariaDetailsElements
/// ARIAMixin - Element array reference setter
/// Spec: https://w3c.github.io/aria/#dom-ariamixin-ariadetailselements
///
/// Sets the elements that provide details for this element. This should set
/// aria-details to space-separated IDs of the target elements.
/// Note: No-op - full implementation requires FrozenArray handling and ID extraction.
pub fn set_ariaDetailsElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - would need to extract IDs from elements and set aria-details
}

/// Setter for ariaDisabled
/// ARIAMixin - Sets the aria-disabled attribute
pub fn set_ariaDisabled(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-disabled", value);
}

/// Setter for ariaErrorMessageElements
/// ARIAMixin - Element array reference setter
/// Spec: https://w3c.github.io/aria/#dom-ariamixin-ariaerrormessageelements
///
/// Sets the elements that contain error messages for this element. This should set
/// aria-errormessage to space-separated IDs of the target elements.
/// Note: No-op - full implementation requires FrozenArray handling and ID extraction.
pub fn set_ariaErrorMessageElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - would need to extract IDs from elements and set aria-errormessage
}

/// Setter for ariaExpanded
/// ARIAMixin - Sets the aria-expanded attribute
pub fn set_ariaExpanded(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-expanded", value);
}

/// Setter for ariaFlowToElements
/// ARIAMixin - Element array reference setter
/// Spec: https://w3c.github.io/aria/#dom-ariamixin-ariaflowtoelements
///
/// Sets the elements that are the next in reading order. This should set
/// aria-flowto to space-separated IDs of the target elements.
/// Note: No-op - full implementation requires FrozenArray handling and ID extraction.
pub fn set_ariaFlowToElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - would need to extract IDs from elements and set aria-flowto
}

/// Setter for ariaHasPopup
/// ARIAMixin - Sets the aria-haspopup attribute
pub fn set_ariaHasPopup(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-haspopup", value);
}

/// Setter for ariaHidden
/// ARIAMixin - Sets the aria-hidden attribute
pub fn set_ariaHidden(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-hidden", value);
}

/// Setter for ariaInvalid
/// ARIAMixin - Sets the aria-invalid attribute
pub fn set_ariaInvalid(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-invalid", value);
}

/// Setter for ariaKeyShortcuts
/// ARIAMixin - Sets the aria-keyshortcuts attribute
pub fn set_ariaKeyShortcuts(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-keyshortcuts", value);
}

/// Setter for ariaLabel
/// ARIAMixin - Sets the aria-label attribute
pub fn set_ariaLabel(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-label", value);
}

/// Setter for ariaLabelledByElements
/// ARIAMixin - Element array reference setter
/// Spec: https://w3c.github.io/aria/#dom-ariamixin-arialabelledbyelements
///
/// Sets the elements that label this element. This should set
/// aria-labelledby to space-separated IDs of the target elements.
/// Note: No-op - full implementation requires FrozenArray handling and ID extraction.
pub fn set_ariaLabelledByElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - would need to extract IDs from elements and set aria-labelledby
}

/// Setter for ariaLevel
/// ARIAMixin - Sets the aria-level attribute
pub fn set_ariaLevel(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-level", value);
}

/// Setter for ariaLive
/// ARIAMixin - Sets the aria-live attribute
pub fn set_ariaLive(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-live", value);
}

/// Setter for ariaModal
/// ARIAMixin - Sets the aria-modal attribute
pub fn set_ariaModal(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-modal", value);
}

/// Setter for ariaMultiLine
/// ARIAMixin - Sets the aria-multiline attribute
pub fn set_ariaMultiLine(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-multiline", value);
}

/// Setter for ariaMultiSelectable
/// ARIAMixin - Sets the aria-multiselectable attribute
pub fn set_ariaMultiSelectable(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-multiselectable", value);
}

/// Setter for ariaOrientation
/// ARIAMixin - Sets the aria-orientation attribute
pub fn set_ariaOrientation(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-orientation", value);
}

/// Setter for ariaOwnsElements
/// ARIAMixin - Element array reference setter
/// Spec: https://w3c.github.io/aria/#dom-ariamixin-ariaownselements
///
/// Sets the elements that are owned by this element. This should set
/// aria-owns to space-separated IDs of the target elements.
/// Note: No-op - full implementation requires FrozenArray handling and ID extraction.
pub fn set_ariaOwnsElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - would need to extract IDs from elements and set aria-owns
}

/// Setter for ariaPlaceholder
/// ARIAMixin - Sets the aria-placeholder attribute
pub fn set_ariaPlaceholder(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-placeholder", value);
}

/// Setter for ariaPosInSet
/// ARIAMixin - Sets the aria-posinset attribute
pub fn set_ariaPosInSet(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-posinset", value);
}

/// Setter for ariaPressed
/// ARIAMixin - Sets the aria-pressed attribute
pub fn set_ariaPressed(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-pressed", value);
}

/// Setter for ariaReadOnly
/// ARIAMixin - Sets the aria-readonly attribute
pub fn set_ariaReadOnly(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-readonly", value);
}

/// Setter for ariaRelevant
/// ARIAMixin - Sets the aria-relevant attribute
pub fn set_ariaRelevant(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-relevant", value);
}

/// Setter for ariaRequired
/// ARIAMixin - Sets the aria-required attribute
pub fn set_ariaRequired(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-required", value);
}

/// Setter for ariaRoleDescription
/// ARIAMixin - Sets the aria-roledescription attribute
pub fn set_ariaRoleDescription(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-roledescription", value);
}

/// Setter for ariaRowCount
/// ARIAMixin - Sets the aria-rowcount attribute
pub fn set_ariaRowCount(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-rowcount", value);
}

/// Setter for ariaRowIndex
/// ARIAMixin - Sets the aria-rowindex attribute
pub fn set_ariaRowIndex(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-rowindex", value);
}

/// Setter for ariaRowIndexText
/// ARIAMixin - Sets the aria-rowindextext attribute
pub fn set_ariaRowIndexText(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-rowindextext", value);
}

/// Setter for ariaRowSpan
/// ARIAMixin - Sets the aria-rowspan attribute
pub fn set_ariaRowSpan(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-rowspan", value);
}

/// Setter for ariaSelected
/// ARIAMixin - Sets the aria-selected attribute
pub fn set_ariaSelected(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-selected", value);
}

/// Setter for ariaSetSize
/// ARIAMixin - Sets the aria-setsize attribute
pub fn set_ariaSetSize(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-setsize", value);
}

/// Setter for ariaSort
/// ARIAMixin - Sets the aria-sort attribute
pub fn set_ariaSort(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-sort", value);
}

/// Setter for ariaValueMax
/// ARIAMixin - Sets the aria-valuemax attribute
pub fn set_ariaValueMax(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-valuemax", value);
}

/// Setter for ariaValueMin
/// ARIAMixin - Sets the aria-valuemin attribute
pub fn set_ariaValueMin(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-valuemin", value);
}

/// Setter for ariaValueNow
/// ARIAMixin - Sets the aria-valuenow attribute
pub fn set_ariaValueNow(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-valuenow", value);
}

/// Setter for ariaValueText
/// ARIAMixin - Sets the aria-valuetext attribute
pub fn set_ariaValueText(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    return setAriaAttribute(instance, "aria-valuetext", value);
}

/// Operation: getAttributeNS
/// DOM §4.8 - Returns the value of the attribute with the given namespace and local name
/// Spec: https://dom.spec.whatwg.org/#dom-element-getattributens
pub fn call_getAttributeNS(instance: *runtime.Instance, namespace: ?runtime.DOMString, localName: runtime.DOMString) anyerror!?runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Step 1: "Let attr be the result of getting an attribute given
    // namespace, localName, and this." Getting one maps "" to null.
    const ns: ?[]const u8 = if (namespace) |n| (if (n.len() == 0) null else n.asSlice()) else null;
    // Step 2: "If attr is null, return null."
    const entry = internal.findAttribute(ns, localName.asSlice()) orelse return null;
    // Step 3: "Return attr's value."
    return runtime.DOMString.initInterned(entry.value);
}

/// Operation: getAttribute
/// Spec: https://dom.spec.whatwg.org/#dom-element-getattribute
pub fn call_getAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString) anyerror!?runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Step 1: "Let attr be the result of getting an attribute given
    // qualifiedName and this": the first attribute whose qualified name is
    // qualifiedName, lowercased for an HTML element in an HTML document.
    var buffer: [64]u8 = undefined;
    const name = try lookupName(instance, internal, qualifiedName.asSlice(), &buffer);
    defer name.deinit(internal.allocator);
    // Step 2: "If attr is null, return null."
    const index = internal.indexOfQualifiedName(name.slice) orelse return null;
    // Step 3: "Return attr's value."
    return runtime.DOMString.initInterned(internal.attributeAt(index).?.value);
}

/// Operation: hasAttribute
/// Spec: https://dom.spec.whatwg.org/#dom-element-hasattribute
pub fn call_hasAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Step 1: lowercase for an HTML element in an HTML document.
    var buffer: [64]u8 = undefined;
    const name = try lookupName(instance, internal, qualifiedName.asSlice(), &buffer);
    defer name.deinit(internal.allocator);
    // Step 2: "Return true if this has an attribute whose qualified name is
    // qualifiedName; otherwise false."
    return internal.indexOfQualifiedName(name.slice) != null;
}

/// Operation: matches
/// DOM §4.10.4 - Returns true if element matches the given selector
/// Spec: https://dom.spec.whatwg.org/#dom-element-matches
pub fn call_matches(instance: *runtime.Instance, selectors: runtime.DOMString) anyerror!bool {
    // matches() is an Element method (not ParentNode mixin method)
    // Use ParentNode impl's helper function for selector matching
    return ParentNodeImpl.matches(instance, selectors);
}

/// Operation: releasePointerCapture
/// Pointer Events §5.4.3 - Releases pointer capture
/// Spec: https://w3c.github.io/pointerevents/#dom-element-releasepointercapture
///
/// Without pointer event support, this is a no-op
pub fn call_releasePointerCapture(instance: *runtime.Instance, pointerId: i32) anyerror!void {
    _ = instance;
    _ = pointerId;
    // No-op without pointer event support
}

/// Operation: computedStyleMap
/// CSS Typed OM §5.3 - Returns the element's computed style as a StylePropertyMapReadOnly
/// Spec: https://drafts.css-houdini.org/css-typed-om-1/#dom-element-computedstylemap
///
/// Note: Returns null - requires CSSOM and layout engine
pub fn call_computedStyleMap(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    // Requires CSSOM and layout engine - return null
    return error.NotImplemented;
}

/// Operation: scroll
/// CSSOM View §5.1 - Scrolls the element to the given coordinates
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-scroll
///
/// Without a layout engine, this is a no-op (returns sentinel for undefined)
pub fn call_scroll(instance: *runtime.Instance, options: webidl.Opt(dictionaries.ScrollToOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = options;
    // No-op without layout engine - returns undefined
    // TODO: Should return a resolved Promise<undefined>
    return runtime.JSValue.jsUndefined;
}

/// Operation: getClientRects
/// CSSOM View §5.1 - Returns a DOMRectList of client rects for this element
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-getclientrects
///
/// Without a layout engine, returns an empty DOMRectList
pub fn call_getClientRects(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Return empty DOMRectList (no layout = no client rects)
    return interfaces.DOMRectList.init(internal.allocator, instance.ctx) catch return error.OutOfMemory;
}

/// Operation: scrollBy
/// CSSOM View §5.1 - Scrolls the element by the given amounts
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-scrollby
///
/// Without a layout engine, this is a no-op (returns sentinel for undefined)
pub fn call_scrollBy(instance: *runtime.Instance, options: webidl.Opt(dictionaries.ScrollToOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = options;
    // No-op without layout engine - returns undefined
    // TODO: Should return a resolved Promise<undefined>
    return runtime.JSValue.jsUndefined;
}

/// Operation: prepend
/// ParentNode mixin - Inserts nodes before the first child of this element
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-prepend
///
/// Note: This is a simplified implementation that handles the common single-node case.
pub fn call_prepend(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
    // For simplified implementation, treat nodes as a single Node pointer
    // Untag pointer from V8 before use
    const untagged = pointer_tag.untagPointer(@ptrCast(nodes.ptr));
    const node: *runtime.Instance = @ptrCast(@alignCast(untagged.ptr));

    // Get first child
    const first_child = NodeImpl.getFirstChild(instance);

    if (first_child) |fc| {
        // Insert before first child
        _ = interfaces.Node.call_insertBefore(instance, node, fc) catch {
            return error.InvalidStateError;
        };
    } else {
        // No children - append
        _ = interfaces.Node.call_appendChild(instance, node) catch {
            return error.InvalidStateError;
        };
    }
}

/// Operation: replaceWith
/// ChildNode mixin - Replaces this element with nodes
/// Spec: https://dom.spec.whatwg.org/#dom-childnode-replacewith
///
/// Note: This is a simplified implementation that handles the common single-node case.
pub fn call_replaceWith(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
    // Get parent - if null, return (per spec)
    const parent = NodeImpl.getParent(instance) orelse return;

    // For simplified implementation, treat nodes as a single Node pointer
    // Untag pointer from V8 before use
    const untagged = pointer_tag.untagPointer(@ptrCast(nodes.ptr));
    const node: *runtime.Instance = @ptrCast(@alignCast(untagged.ptr));

    // Replace this with node using Node.replaceChild
    _ = interfaces.Node.call_replaceChild(parent, node, instance) catch {
        return error.InvalidStateError;
    };
}

/// Operation: convertQuadFromNode
/// CSSOM View §6 - Converts a quad from another element's coordinate space
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-convertquadfromnode
///
/// Note: Returns null - requires layout engine for coordinate transformations
pub fn call_convertQuadFromNode(instance: *runtime.Instance, quad: dictionaries.DOMQuadInit, from: typedefs.GeometryNode, options: webidl.Opt(dictionaries.ConvertCoordinateOptions)) anyerror!*runtime.Instance {
    _ = instance;
    _ = quad;
    _ = from;
    _ = options;
    // Requires layout engine for coordinate transformations - return null
    return error.NotImplemented;
}

/// Operation: setAttributeNodeNS
/// DOM §4.8 - Adds or replaces the Attr node with the given namespace
/// Spec: https://dom.spec.whatwg.org/#dom-element-setattributenodens
///
/// The setAttributeNodeNS(attr) method steps are to return the result of
/// setting an attribute given attr and this.
///
/// Returns the old Attr node if replaced, or null if newly added.
pub fn call_setAttributeNodeNS(instance: *runtime.Instance, attr: *runtime.Instance) anyerror!?*runtime.Instance {
    // setAttributeNodeNS and setAttributeNode have identical behavior per spec
    // They both call the "set an attribute" algorithm
    return call_setAttributeNode(instance, attr);
}

/// Operation: getAttributeNodeNS
/// DOM §4.8 - Returns the Attr node with the given namespace and local name
/// Spec: https://dom.spec.whatwg.org/#dom-element-getattributenodens
pub fn call_getAttributeNodeNS(instance: *runtime.Instance, namespace: ?runtime.DOMString, localName: runtime.DOMString) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // "Getting an attribute given namespace, localName, and this": "" is null.
    const ns: ?[]const u8 = if (namespace) |n| (if (n.len() == 0) null else n.asSlice()) else null;
    const index = internal.indexOfAttribute(ns, localName.asSlice()) orelse return null;
    return try ensureAttrNode(instance, internal, index);
}

/// The Attr node for the attribute at `index`: the one made before, or a new
/// one made now. This list stores attribute data; a node is made only when
/// script asks for one, and the same node is handed out after that - the
/// design of Blink's Element::EnsureAttr and WebKit's Element::ensureAttr.
fn ensureAttrNode(instance: *runtime.Instance, internal: *InternalState, index: usize) !*runtime.Instance {
    const entry = internal.attributeAt(index) orelse return error.InvalidStateError;
    if (entry.attr_node) |link| {
        if (link.isLive()) return link.instance;
    }

    const attr = try interfaces.Attr.init(internal.allocator, instance.ctx);
    errdefer interfaces.Attr.deinit(attr);
    try dom.attr_nodes.name(attr, entry.namespace_uri, entry.prefix, entry.local_name);
    try dom.attr_nodes.attach(attr, instance);
    // `attach` can run nothing, so `entry` is still this attribute's.
    entry.attr_node = same_object.Link.to(attr);
    entry.attr_pin.release();
    entry.attr_pin.hold(attr);
    return attr;
}

/// The attribute `entry` stands for is leaving this element: its Attr node, if
/// one was made, keeps the value and loses its element, and this element stops
/// holding it.
fn detachAttrNode(entry: *AttributeEntry) void {
    const link = entry.attr_node orelse return;
    entry.attr_node = null;
    defer entry.attr_pin.release();
    // A teardown sweep may have freed the node first.
    if (!link.isLive()) return;
    dom.attr_nodes.detach(link.instance, entry.value) catch {};
}

/// `attr` is now the Attr node for the attribute at `index`.
fn adoptAttrNode(instance: *runtime.Instance, internal: *InternalState, index: usize, attr: *runtime.Instance) !void {
    const entry = internal.attributeAt(index) orelse return error.InvalidStateError;
    try dom.attr_nodes.attach(attr, instance);
    entry.attr_node = same_object.Link.to(attr);
    entry.attr_pin.release();
    entry.attr_pin.hold(attr);
}

/// Operation: setAttributeNS
/// DOM §4.8 - Sets the attribute with the given namespace and qualified name
/// Spec: https://dom.spec.whatwg.org/#dom-element-setattributens
pub fn call_setAttributeNS(instance: *runtime.Instance, namespace: ?runtime.DOMString, qualifiedName: runtime.DOMString, value: runtime.DOMString) anyerror!void {
    // Step 1: "Let (namespace, prefix, localName) be the result of validating
    // and extracting namespace and qualifiedName given "attribute"."
    const extracted = try dom.names.validateAndExtract(
        if (namespace) |ns| ns.asSlice() else null,
        qualifiedName.asSlice(),
        .attribute,
    );

    // Step 2: "Let verifiedValue be the result of calling get trusted type
    // compliant attribute value with localName, namespace, this, and value."
    // Deviation: Trusted Types enforcement is not wired into attribute
    // setting; the value is used as given.

    // Step 3: "Set an attribute value for this using localName,
    // verifiedValue, prefix, and namespace."
    try setAttributeValue(instance, extracted.local_name, value.asSlice(), extracted.prefix, extracted.namespace);
}

/// Operation: setAttributeNode
/// DOM §4.8 - Adds or replaces the Attr node
/// Spec: https://dom.spec.whatwg.org/#dom-element-setattributenode
///
/// The setAttributeNode(attr) method steps are to return the result of
/// setting an attribute given attr and this.
pub fn call_setAttributeNode(instance: *runtime.Instance, attr: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: "Let verifiedValue be the result of calling get trusted type
    // compliant attribute value with attr's local name, attr's namespace,
    // element, and attr's value." Deviation: see setAttributeNS.

    // Step 2: "If attr's element is neither null nor element, throw an
    // "InUseAttributeError" DOMException."
    const attr_element = interfaces.Attr.get_ownerElement(attr) catch null;
    if (attr_element) |element| {
        if (element != instance) return error.InUseAttributeError;
    }

    // The getters clone into the Attr's context allocator; this frame owns
    // the copies. An Attr with no namespace or prefix reports "".
    const attr_allocator = attr.ctx.allocator;
    var namespace_string = (interfaces.Attr.get_namespaceURI(attr) catch return error.InvalidStateError) orelse runtime.DOMString.initEmpty();
    defer namespace_string.deinit(attr_allocator);
    var prefix_string = (interfaces.Attr.get_prefix(attr) catch return error.InvalidStateError) orelse runtime.DOMString.initEmpty();
    defer prefix_string.deinit(attr_allocator);
    var local_name = interfaces.Attr.get_localName(attr) catch return error.InvalidStateError;
    defer local_name.deinit(attr_allocator);
    var value = interfaces.Attr.get_value(attr) catch return error.InvalidStateError;
    defer value.deinit(attr_allocator);
    const namespace: ?[]const u8 = if (namespace_string.len() == 0) null else namespace_string.asSlice();
    const prefix: ?[]const u8 = if (prefix_string.len() == 0) null else prefix_string.asSlice();

    // Step 3: "Let oldAttr be the result of getting an attribute given attr's
    // namespace, attr's local name, and element."
    const old_index = internal.indexOfAttribute(namespace, local_name.asSlice()) orelse {
        // Step 7: "Otherwise, append attr to element." attr becomes the node
        // for the new attribute before the attribute change steps run.
        try appendAttribute(instance, internal, namespace, prefix, local_name.asSlice(), value.asSlice());
        // Found again by name: the change steps can run script.
        const new_index = internal.indexOfAttribute(namespace, local_name.asSlice()) orelse return null;
        try adoptAttrNode(instance, internal, new_index, attr);
        // Step 8: "Return oldAttr." - null.
        return null;
    };

    // Step 4: "If oldAttr is attr, return attr."
    if (internal.attributeAt(old_index).?.attr_node) |link| {
        if (link.isLive() and link.instance == attr) return attr;
    }

    // Step 5: "Set attr's value to verifiedValue." It is unchanged.

    // Step 6: "If oldAttr is non-null, then replace oldAttr with attr."
    // "Set oldAttribute's element to null": oldAttr - the node script may
    // already hold, or one made now to hand back - keeps its last value.
    const old_attr = try ensureAttrNode(instance, internal, old_index);
    detachAttrNode(internal.attributeAt(old_index).?);
    try replaceAttributeAt(instance, internal, old_index, prefix, value.asSlice());
    // Found again by name: the change steps can run script.
    if (internal.indexOfAttribute(namespace, local_name.asSlice())) |index| {
        try adoptAttrNode(instance, internal, index, attr);
    }

    // Step 8: "Return oldAttr."
    return old_attr;
}

/// DOM "replace an attribute": the one at `index` by an attribute with the
/// same namespace and local name, and the given prefix and value.
///
/// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-replace
fn replaceAttributeAt(instance: *runtime.Instance, internal: *InternalState, index: usize, prefix: ?[]const u8, value: []const u8) !void {
    const allocator = internal.allocator;
    const entry = internal.attributeAt(index) orelse return error.InvalidStateError;
    const new_prefix: ?[]const u8 = if (prefix) |p| try allocator.dupe(u8, p) else null;
    errdefer if (new_prefix) |p| allocator.free(p);
    const new_value = try allocator.dupe(u8, value);

    // Step 2: "Replace oldAttribute by newAttribute in element's attribute
    // list." Steps 3 to 5 move the element from one Attr node to the other.
    const old_prefix = entry.prefix;
    const old_value = entry.value;
    defer {
        if (old_prefix) |p| allocator.free(p);
        allocator.free(old_value);
    }
    entry.prefix = new_prefix;
    entry.value = new_value;

    // Step 6: "Handle attribute changes for oldAttribute with element,
    // oldAttribute's value, and newAttribute's value."
    handleAttributeChanges(instance, entry.namespace_uri, entry.local_name, old_value, new_value);
}

/// Operation: scrollTo
/// CSSOM View §5.1 - Scrolls the element to the given coordinates (alias for scroll)
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-scrollto
///
/// Without a layout engine, this is a no-op (returns sentinel for undefined)
pub fn call_scrollTo(instance: *runtime.Instance, options: webidl.Opt(dictionaries.ScrollToOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = options;
    // No-op without layout engine - returns undefined
    // TODO: Should return a resolved Promise<undefined>
    return runtime.JSValue.jsUndefined;
}

/// Operation: getElementsByTagNameNS
/// DOM §4.10.5 - Returns HTMLCollection of descendants with matching namespace and local name
/// Spec: https://dom.spec.whatwg.org/#dom-element-getelementsbytagnamens
pub fn call_getElementsByTagNameNS(instance: *runtime.Instance, namespace: ?runtime.DOMString, localName: runtime.DOMString) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const ns_slice = if (namespace) |ns| ns.asSlice() else "";
    const name_slice = localName.asSlice();

    // Create HTMLCollection
    const collection = interfaces.HTMLCollection.init(
        internal.allocator,
        instance.ctx,
    ) catch return error.OutOfMemory;
    errdefer interfaces.HTMLCollection.deinit(collection);

    // Collect matching descendants
    collectElementsByTagNameNS(instance, ns_slice, name_slice, collection) catch return error.OutOfMemory;

    return collection;
}

/// Operation: replaceChildren
/// ParentNode mixin - Replaces all children of this element with nodes
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-replacechildren
///
/// Steps:
/// 1. Let node be the result of converting nodes into a node
/// 2. Ensure pre-insertion validity of node into this before null
/// 3. Replace all with node within this
///
/// Note: This is a simplified implementation that handles the common single-node case.
pub fn call_replaceChildren(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
    // First, remove all existing children
    var child = NodeImpl.getFirstChild(instance);
    while (child) |c| {
        const next = NodeImpl.getNextSibling(c);
        _ = interfaces.Node.call_removeChild(instance, c) catch {};
        child = next;
    }

    // Then append the new node(s)
    // For simplified implementation, treat nodes as a single Node pointer
    // Untag pointer from V8 before use
    // Note: nodes being "empty" variadic is represented as a special marker, not null pointer
    const untagged = pointer_tag.untagPointer(@ptrCast(nodes.ptr));
    const node: *runtime.Instance = @ptrCast(@alignCast(untagged.ptr));

    // Append the new node
    _ = interfaces.Node.call_appendChild(instance, node) catch {
        return error.InvalidStateError;
    };
}

/// Operation: getRegionFlowRanges
/// CSS Regions §10.3 - Returns ranges for content in this region
/// Spec: https://drafts.csswg.org/css-regions-1/#dom-region-getregionflowranges
///
/// Note: CSS Regions is deprecated - returns null
pub fn call_getRegionFlowRanges(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    _ = instance;
    // CSS Regions is deprecated - return null
    return null;
}

/// Operation: getBoxQuads
/// CSSOM View §6 - Returns the element's CSS boxes as DOMQuads
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-getboxquads
///
/// Note: Returns sentinel for empty array - requires layout engine
pub fn call_getBoxQuads(instance: *runtime.Instance, options: webidl.Opt(dictionaries.BoxQuadOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = options;
    // Requires layout engine - return undefined (empty array)
    return runtime.JSValue.jsUndefined;
}

/// Operation: focusableAreas
/// CSS Spatial Navigation §5 - Returns focusable areas in specified direction
/// Spec: https://drafts.csswg.org/css-nav-1/#dom-element-focusableareas
///
/// Note: Returns undefined (empty array) - spatial navigation not implemented
pub fn call_focusableAreas(instance: *runtime.Instance, option: webidl.Opt(dictionaries.FocusableAreasOption)) anyerror!runtime.JSValue {
    _ = instance;
    _ = option;
    // Spatial navigation not implemented - return undefined (empty array)
    return runtime.JSValue.jsUndefined;
}

/// Operation: convertPointFromNode
/// CSSOM View §6 - Converts a point from another element's coordinate space
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-convertpointfromnode
///
/// Note: Returns null - requires layout engine for coordinate transformations
pub fn call_convertPointFromNode(instance: *runtime.Instance, point: dictionaries.DOMPointInit, from: typedefs.GeometryNode, options: webidl.Opt(dictionaries.ConvertCoordinateOptions)) anyerror!*runtime.Instance {
    _ = instance;
    _ = point;
    _ = from;
    _ = options;
    // Requires layout engine - return null
    return error.NotImplemented;
}

/// Operation: getAnimations
/// Web Animations §4.4.4 - Returns animations targeting this element
/// Spec: https://drafts.csswg.org/web-animations-1/#dom-animatable-getanimations
///
/// Returns sentinel for empty array (no animations without rendering engine)
pub fn call_getAnimations(instance: *runtime.Instance, options: webidl.Opt(dictionaries.GetAnimationsOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = options;
    // Returns undefined (empty array) - no animations without rendering engine
    return runtime.JSValue.jsUndefined;
}

/// Operation: getElementsByClassName
/// DOM §4.10.5 - Returns HTMLCollection of descendants with all given class names
/// Spec: https://dom.spec.whatwg.org/#dom-element-getelementsbyclassname
pub fn call_getElementsByClassName(instance: *runtime.Instance, classNames: runtime.DOMString) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const names_slice = classNames.asSlice();

    // Create HTMLCollection
    const collection = interfaces.HTMLCollection.init(
        internal.allocator,
        instance.ctx,
    ) catch return error.OutOfMemory;
    errdefer interfaces.HTMLCollection.deinit(collection);

    // Collect matching descendants
    collectElementsByClassName(instance, names_slice, collection) catch return error.OutOfMemory;

    return collection;
}

/// Operation: insertAdjacentElement
/// DOM §4.10.7 - Insert element at specified position relative to this element
/// Spec: https://dom.spec.whatwg.org/#dom-element-insertadjacentelement
///
/// The insertAdjacentElement(where, element) method steps are to return the result of
/// running insert adjacent, given this, where, and element.
///
/// Position values (case-insensitive):
/// - "beforebegin": Before this element (as a sibling)
/// - "afterbegin": Inside this element, before first child
/// - "beforeend": Inside this element, after last child
/// - "afterend": After this element (as a sibling)
pub fn call_insertAdjacentElement(instance: *runtime.Instance, where: runtime.DOMString, element: *runtime.Instance) anyerror!?*runtime.Instance {
    const result = insertAdjacent(instance, where.asSlice(), element) catch |err| {
        return switch (err) {
            error.SyntaxError => error.SyntaxError,
            error.InvalidStateError => error.InvalidStateError,
        };
    };

    // insertAdjacent returns null if parent is null for beforebegin/afterend positions
    return result;
}

/// Operation: webkitMatchesSelector
/// Legacy alias for matches() - Returns true if element matches the given selector
/// Spec: https://dom.spec.whatwg.org/#dom-element-webkitmatchesselector
pub fn call_webkitMatchesSelector(instance: *runtime.Instance, selectors: runtime.DOMString) anyerror!bool {
    // webkitMatchesSelector is an alias for matches()
    return call_matches(instance, selectors);
}

/// Operation: spatialNavigationSearch
/// CSS Spatial Navigation §5 - Searches for next focusable element in direction
/// Spec: https://drafts.csswg.org/css-nav-1/#dom-element-spatialnavigationsearch
///
/// Note: Returns null - spatial navigation not implemented without layout engine
pub fn call_spatialNavigationSearch(instance: *runtime.Instance, dir: enums.SpatialNavigationDirection, options: webidl.Opt(dictionaries.SpatialNavigationSearchOptions)) anyerror!?*runtime.Instance {
    _ = instance;
    _ = dir;
    _ = options;
    // Spatial navigation not implemented without layout engine - return null
    return null;
}

/// Operation: getElementsByTagName
/// DOM §4.10.5 - Returns HTMLCollection of descendants with matching tag name
/// Spec: https://dom.spec.whatwg.org/#dom-element-getelementsbytagname
pub fn call_getElementsByTagName(instance: *runtime.Instance, qualifiedName: runtime.DOMString) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const name_slice = qualifiedName.asSlice();

    // Create HTMLCollection
    const collection = interfaces.HTMLCollection.init(
        internal.allocator,
        instance.ctx,
    ) catch return error.OutOfMemory;
    errdefer interfaces.HTMLCollection.deinit(collection);

    // Collect matching descendants
    collectElementsByTagName(instance, name_slice, collection) catch return error.OutOfMemory;

    return collection;
}

/// Operation: querySelector
/// ParentNode mixin - Returns the first element matching the selector
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-queryselector
pub fn call_querySelector(instance: *runtime.Instance, selectors: runtime.DOMString) anyerror!?*runtime.Instance {
    // Delegate to ParentNode mixin - pass DOMString directly
    return ParentNode.call_querySelector(instance, selectors);
}

/// Operation: closest
/// DOM §4.10.4 - Returns closest ancestor (or self) matching selector
/// Spec: https://dom.spec.whatwg.org/#dom-element-closest
pub fn call_closest(instance: *runtime.Instance, selectors: runtime.DOMString) anyerror!?*runtime.Instance {
    // closest() is an Element method (not ParentNode mixin method)
    // Use ParentNode impl's helper function for selector matching
    return ParentNodeImpl.closest(instance, selectors);
}

/// Operation: getSpatialNavigationContainer
/// CSS Spatial Navigation §5 - Returns spatial navigation container
/// Spec: https://drafts.csswg.org/css-nav-1/#dom-element-getspatialnavigationcontainer
///
/// Note: Returns null - spatial navigation not implemented
pub fn call_getSpatialNavigationContainer(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    // Spatial navigation not implemented - return null
    return error.NotImplemented;
}

/// Operation: remove
/// ChildNode mixin - Removes this element from its parent
/// Spec: https://dom.spec.whatwg.org/#dom-childnode-remove
pub fn call_remove(instance: *runtime.Instance) anyerror!void {
    ChildNode.call_remove(instance) catch |err| {
        return switch (err) {
            error.HierarchyRequestError => error.InvalidStateError,
            else => error.NotImplemented,
        };
    };
}

/// Operation: removeAttribute
/// DOM §4.8 - Removes the named attribute
pub fn call_removeAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString) anyerror!void {
    // "Remove an attribute given qualifiedName and this, and then return
    // undefined."
    try removeAttributeByName(instance, qualifiedName.asSlice());
}

/// Operation: convertRectFromNode
/// CSSOM View §6 - Converts a rect from another element's coordinate space
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-convertrectfromnode
///
/// Note: Returns null - requires layout engine for coordinate transformations
pub fn call_convertRectFromNode(instance: *runtime.Instance, rect: *runtime.Instance, from: typedefs.GeometryNode, options: webidl.Opt(dictionaries.ConvertCoordinateOptions)) anyerror!*runtime.Instance {
    _ = instance;
    _ = rect;
    _ = from;
    _ = options;
    // Requires layout engine - return null
    return error.NotImplemented;
}

/// Operation: removeAttributeNode
/// DOM §4.8 - Removes the given Attr node from this element
/// Spec: https://dom.spec.whatwg.org/#dom-element-removeattributenode
///
/// The removeAttributeNode(attr) method steps are:
/// 1. If this's attribute list does not contain attr, then throw a "NotFoundError" DOMException.
/// 2. Remove attr.
/// 3. Return attr.
pub fn call_removeAttributeNode(instance: *runtime.Instance, attr: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: "If this's attribute list does not contain attr, then throw a
    // "NotFoundError" DOMException." The list contains attr when attr is the
    // node made for one of its attributes.
    var iter = internal.attributeIterator();
    var index: usize = 0;
    const found = while (iter.next()) |entry| : (index += 1) {
        const link = entry.attr_node orelse continue;
        if (link.isLive() and link.instance == attr) break true;
    } else false;
    if (!found) return error.NotFoundError;

    // Step 2: "Remove attr." - which sets attr's element to null.
    removeAttributeAt(instance, internal, index);

    // Step 3: "Return attr."
    return attr;
}

/// Operation: removeAttributeNS
/// DOM §4.8 - Removes the attribute with the given namespace and local name
/// Spec: https://dom.spec.whatwg.org/#dom-element-removeattributens
pub fn call_removeAttributeNS(instance: *runtime.Instance, namespace: ?runtime.DOMString, localName: runtime.DOMString) anyerror!void {
    // "Remove an attribute given namespace, localName, and this, and then
    // return undefined."
    removeAttributeByNamespaceAndLocalName(instance, if (namespace) |ns| ns.asSlice() else null, localName.asSlice());
}

/// Operation: insertAdjacentText
/// DOM §4.10.7 - Creates a Text node and inserts it at specified position
/// Spec: https://dom.spec.whatwg.org/#dom-element-insertadjacenttext
///
/// The insertAdjacentText(where, data) method steps are:
/// 1. Let text be a new Text node whose data is data and node document is this's node document.
/// 2. Run the insert adjacent algorithm given this, where, and text.
pub fn call_insertAdjacentText(instance: *runtime.Instance, where: runtime.DOMString, data: runtime.DOMString) anyerror!void {
    _ = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: Create a new Text node with the given data
    // Use interface instead of impl (per Golden Rule #13)
    const text_node = interfaces.Text.call_constructor(instance.ctx, webidl.Opt(runtime.DOMString).passed(data)) catch return error.OutOfMemory;
    errdefer interfaces.Text.deinit(text_node);

    // Step 2: Run insert adjacent algorithm
    _ = insertAdjacent(instance, where.asSlice(), text_node) catch |err| {
        return switch (err) {
            error.SyntaxError => error.SyntaxError,
            error.InvalidStateError => error.InvalidStateError,
        };
    };
}

/// Operation: requestFullscreen
/// Fullscreen API §4.1 - Requests fullscreen mode for this element
/// Spec: https://fullscreen.spec.whatwg.org/#dom-element-requestfullscreen
///
/// Note: Returns sentinel - fullscreen requires browser integration
pub fn call_requestFullscreen(instance: *runtime.Instance, options: webidl.Opt(dictionaries.FullscreenOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = options;
    // Fullscreen requires browser integration - return undefined
    // TODO: Should return a rejected Promise with TypeError
    return runtime.JSValue.jsUndefined;
}

/// Operation: animate
/// Web Animations §4.4.3 - Creates and runs a new Animation
/// Spec: https://drafts.csswg.org/web-animations-1/#dom-animatable-animate
///
/// Note: Returns null - requires Web Animations API and rendering engine
pub fn call_animate(instance: *runtime.Instance, keyframes: ?runtime.JSValue, options: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
    _ = instance;
    _ = keyframes;
    _ = options;
    // Animation requires rendering engine - return null
    return error.NotImplemented;
}

/// Operation: append
/// ParentNode mixin - Appends nodes after the last child of this element
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-append
///
/// Delegates to ParentNode mixin implementation.
pub fn call_append(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
    // Delegate to ParentNode impl (which handles NodeOrString properly)
    return ParentNodeImpl.call_append(instance, nodes);
}

/// Operation: moveBefore
/// DOM §4.10.6 - Moves a node before a child without triggering removal callbacks
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-movebefore
///
/// This is a newer DOM method for moving nodes atomically
pub fn call_moveBefore(instance: *runtime.Instance, node: *runtime.Instance, child: ?*runtime.Instance) anyerror!void {
    // Use insertBefore as a fallback (doesn't suppress callbacks but same tree result)
    _ = interfaces.Node.call_insertBefore(instance, node, child) catch |err| {
        return switch (err) {
            error.HierarchyRequestError => error.InvalidStateError,
            error.NotFoundError => error.NotFoundError,
            else => error.InvalidStateError,
        };
    };
}

/// Operation: getHTML
/// HTML Sanitizer API - Returns sanitized HTML serialization
/// Spec: https://wicg.github.io/sanitizer-api/#dom-element-gethtml
///
/// Returns the innerHTML with optional shadow roots serialized
pub fn call_getHTML(instance: *runtime.Instance, options: webidl.Opt(dictionaries.GetHTMLOptions)) anyerror!runtime.DOMString {
    _ = options;
    // get_innerHTML returns *const anyopaque which is a DOMString union
    // We need to call the serialization directly here
    _ = getInternal(instance) orelse return error.InvalidStateError;

    // IMPORTANT: Use instance.ctx.allocator for returned DOMStrings
    // The V8 property getter callback will free returned strings using instance.ctx.allocator
    const allocator = instance.ctx.allocator;

    // Serialize all child nodes
    var buffer = infra.List(u8).init(allocator);
    defer buffer.deinit();

    var child = NodeImpl.getFirstChild(instance);
    while (child) |c| {
        serializeNode(c, &buffer, allocator) catch return error.OutOfMemory;
        child = NodeImpl.getNextSibling(c);
    }

    // Return the serialized HTML
    const slice = buffer.items();
    if (slice.len == 0) {
        return runtime.DOMString.initEmpty();
    }
    return runtime.DOMString.initDupe(allocator, slice) catch return error.OutOfMemory;
}

/// Operation: getAttributeNode
/// DOM §4.8 - Returns the Attr node with the given qualified name
/// Spec: https://dom.spec.whatwg.org/#dom-element-getattributenode
///
/// The getAttributeNode(qualifiedName) method steps are to return the result of
/// getting an attribute given qualifiedName and this.
pub fn call_getAttributeNode(instance: *runtime.Instance, qualifiedName: runtime.DOMString) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // "Return the result of getting an attribute given qualifiedName and
    // this."
    var buffer: [64]u8 = undefined;
    const name = try lookupName(instance, internal, qualifiedName.asSlice(), &buffer);
    defer name.deinit(internal.allocator);
    const index = internal.indexOfQualifiedName(name.slice) orelse return null;
    return try ensureAttrNode(instance, internal, index);
}

/// Operation: startViewTransition
/// View Transitions API - Starts a view transition
/// Spec: https://drafts.csswg.org/css-view-transitions-1/#dom-document-startviewtransition
///
/// Note: Returns null - View Transitions require rendering engine
pub fn call_startViewTransition(instance: *runtime.Instance, callbackOptions: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
    _ = instance;
    _ = callbackOptions;
    // View Transitions require rendering engine - return null
    return error.NotImplemented;
}

/// Operation: setHTMLUnsafe
/// HTML Sanitizer API - Sets HTML without sanitization
/// Spec: https://wicg.github.io/sanitizer-api/#dom-element-sethtmlunsafe
///
/// Note: Requires HTML fragment parsing algorithm (not implemented)
pub fn call_setHTMLUnsafe(instance: *runtime.Instance, html: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = html;
    // TODO: Requires HTML fragment parsing algorithm
    return error.NotImplemented;
}

/// Operation: scrollIntoView
/// CSSOM View §5.1 - Scrolls this element into view
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-scrollintoview
///
/// Without a layout engine, this is a no-op (returns sentinel for undefined)
pub fn call_scrollIntoView(instance: *runtime.Instance, arg: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
    _ = instance;
    _ = arg;
    // No-op without layout engine - returns undefined
    // TODO: Should return a resolved Promise<undefined>
    return runtime.JSValue.jsUndefined;
}

/// Operation: hasAttributes
/// DOM §4.8 - Returns true if the element has any attributes
/// Spec: https://dom.spec.whatwg.org/#dom-element-hasattributes
pub fn call_hasAttributes(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.getAttributeCount() > 0;
}

/// Operation: hasPointerCapture
/// Pointer Events §5.4.4 - Checks if element has pointer capture
/// Spec: https://w3c.github.io/pointerevents/#dom-element-haspointercapture
///
/// Without pointer event support, always returns false
pub fn call_hasPointerCapture(instance: *runtime.Instance, pointerId: i32) anyerror!bool {
    _ = instance;
    _ = pointerId;
    // No pointer capture without pointer event support
    return false;
}

/// Operation: toggleAttribute
/// DOM §4.8 - Toggles the named attribute: removes it if present, adds it if not
/// Spec: https://dom.spec.whatwg.org/#dom-element-toggleattribute
///
/// Steps:
/// 1. If qualifiedName is invalid, throw InvalidCharacterError
/// 2. If HTML element in HTML document, lowercase qualifiedName
/// 3. If attribute exists and force is not true, remove it and return false
/// 4. If attribute doesn't exist and force is not false, add it with empty value and return true
/// 5. Return whether attribute now exists
pub fn call_toggleAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString, force: webidl.Opt(bool)) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: "If qualifiedName is not a valid attribute local name, then
    // throw an "InvalidCharacterError" DOMException."
    if (!dom.names.isValidAttributeLocalName(qualifiedName.asSlice())) return error.InvalidCharacterError;

    // Step 2: lowercase for an HTML element in an HTML document.
    var buffer: [64]u8 = undefined;
    const name = try lookupName(instance, internal, qualifiedName.asSlice(), &buffer);
    defer name.deinit(internal.allocator);

    // Step 3: "Let attribute be the first attribute in this's attribute list
    // whose qualified name is qualifiedName, and null otherwise."
    const index = internal.indexOfQualifiedName(name.slice) orelse {
        // Step 4.1: "If force is not given or is true, create an attribute
        // whose local name is qualifiedName, value is the empty string, and
        // node document is this's node document, then append this attribute
        // to this, and then return true."
        if (!force.was_passed or force.value) {
            try appendAttribute(instance, internal, null, null, name.slice, "");
            return true;
        }
        // Step 4.2: "Return false."
        return false;
    };

    // Step 5: "Otherwise, if force is not given or is false, remove an
    // attribute given qualifiedName and this, and then return false." The
    // attribute that removes is the one step 3 found.
    if (!force.was_passed or !force.value) {
        removeAttributeAt(instance, internal, index);
        return false;
    }

    // Step 6: "Return true."
    return true;
}

/// Operation: pseudo
/// CSSOM §6.1 - Returns a CSSPseudoElement for the given pseudo-element type
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-pseudo
///
/// Note: Returns null - requires CSSOM and pseudo-element support
pub fn call_pseudo(instance: *runtime.Instance, @"type": typedefs.CSSOMString) anyerror!?*runtime.Instance {
    _ = instance;
    _ = @"type";
    // Requires CSSOM and pseudo-element support - return null
    return error.NotImplemented;
}

/// Operation: before
/// ChildNode mixin - Inserts nodes just before this element
/// Spec: https://dom.spec.whatwg.org/#dom-childnode-before
///
/// Note: This is a simplified implementation that handles the common single-node case.
/// Full implementation would need to handle variadic Node or DOMString arguments.
pub fn call_before(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
    // Get parent - if null, return (per spec)
    const parent = NodeImpl.getParent(instance) orelse return;

    // For simplified implementation, treat nodes as a single Node pointer
    // Untag pointer from V8 before use
    // TODO: Handle variadic (Node or DOMString)... properly
    const untagged = pointer_tag.untagPointer(@ptrCast(nodes.ptr));
    const node: *runtime.Instance = @ptrCast(@alignCast(untagged.ptr));

    // Insert node before this element
    _ = interfaces.Node.call_insertBefore(parent, node, instance) catch {
        return error.InvalidStateError;
    };
}

/// Operation: after
/// ChildNode mixin - Inserts nodes just after this element
/// Spec: https://dom.spec.whatwg.org/#dom-childnode-after
///
/// Note: This is a simplified implementation that handles the common single-node case.
pub fn call_after(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
    // Get parent - if null, return (per spec)
    const parent = NodeImpl.getParent(instance) orelse return;

    // For simplified implementation, treat nodes as a single Node pointer
    // Untag pointer from V8 before use
    const untagged = pointer_tag.untagPointer(@ptrCast(nodes.ptr));
    const node: *runtime.Instance = @ptrCast(@alignCast(untagged.ptr));

    // Get next sibling
    const next_sibling = NodeImpl.getNextSibling(instance);

    if (next_sibling) |ns| {
        // Insert before next sibling
        _ = interfaces.Node.call_insertBefore(parent, node, ns) catch {
            return error.InvalidStateError;
        };
    } else {
        // Append to parent (no next sibling)
        _ = interfaces.Node.call_appendChild(parent, node) catch {
            return error.InvalidStateError;
        };
    }
}

/// Operation: setAttribute
/// Spec: https://dom.spec.whatwg.org/#dom-element-setattribute
pub fn call_setAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: "If qualifiedName is not a valid attribute local name, then
    // throw an "InvalidCharacterError" DOMException." It is only used as a
    // qualified name to find an attribute that already has it; a new one
    // takes it as its local name.
    if (!dom.names.isValidAttributeLocalName(qualifiedName.asSlice())) return error.InvalidCharacterError;

    // Step 2: lowercase for an HTML element in an HTML document.
    var buffer: [64]u8 = undefined;
    const name = try lookupName(instance, internal, qualifiedName.asSlice(), &buffer);
    defer name.deinit(internal.allocator);

    // Step 3: "Let verifiedValue be the result of calling get trusted type
    // compliant attribute value with qualifiedName, null, this, and value."
    // Deviation: see setAttributeNS.

    // Step 4: "Let attribute be the first attribute in this's attribute list
    // whose qualified name is qualifiedName, and null otherwise."
    // Step 5: "If attribute is non-null, then change attribute to
    // verifiedValue and return."
    if (internal.indexOfQualifiedName(name.slice)) |index| {
        return changeAttribute(instance, internal, index, value.asSlice());
    }

    // Steps 6 and 7: "Set attribute to a new attribute whose local name is
    // qualifiedName, value is verifiedValue, and node document is this's node
    // document. Append attribute to this."
    try appendAttribute(instance, internal, null, null, name.slice, value.asSlice());
}

// =============================================================================
// Event handler content attributes (HTML §8.1.8.1)
// =============================================================================

/// The event handlers a body or frameset element's content attributes set on
/// the WINDOW rather than on the element: the WindowEventHandlers members and
/// the "Window-reflecting body element event handler set".
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#determining-the-target-of-an-event-handler
const window_reflecting_body_handlers = [_][]const u8{
    // Window-reflecting body element event handler set
    "onblur",         "onerror",              "onfocus",
    "onload",         "onresize",             "onscroll",
    // WindowEventHandlers
    "onafterprint",   "onbeforeprint",        "onbeforeunload",
    "onhashchange",   "onlanguagechange",     "onmessage",
    "onmessageerror", "onoffline",            "ononline",
    "onpagehide",     "onpagereveal",         "onpageshow",
    "onpageswap",     "onpopstate",           "onrejectionhandled",
    "onstorage",      "onunhandledrejection", "onunload",
};

/// The attribute change steps that synchronize event handler content
/// attributes with event handlers.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-attributes
/// "1. If namespace is not null, or localName is not the name of an event
///  handler content attribute on element, then return.
///  2. Let eventTarget be the result of determining the target of an event
///  handler given element and localName.
///  3. If value is null, then deactivate an event handler given eventTarget and
///  localName.
///  4. Otherwise: ... set eventHandler's value to the internal raw uncompiled
///  handler value/location."
///
/// Nothing did this before, so `<body onload="...">` - and every `onload=`,
/// `onerror=`, `onclick=` attribute on any element - never ran. Pages that
/// start their tests from `<body onload>` (all of encoding/legacy-mb-*) waited
/// out the harness timeout on every variant.
///
/// Deviation, stated: the spec keeps the value as an internal raw uncompiled
/// handler and compiles it the first time the handler's current value is
/// needed. This compiles it here, at attribute-change time. Crane's handler
/// maps hold a compiled function under a pointer tag, and all four tag values
/// are taken, so an uncompiled value has nowhere to live yet. What that
/// changes: a syntax error surfaces when the attribute is set rather than when
/// the event first fires, and the scope chain captures the element's document
/// at set time. The function is otherwise the spec's: same name, same
/// parameters, same object environments, and it is assigned through the event
/// handler IDL attribute, so getters, dispatch and removal all see one handler.
fn eventHandlerAttributeChangeSteps(instance: *runtime.Instance, local_name: []const u8, value: ?[]const u8) void {
    // Step 1: only unnamespaced "on..." attributes of HTML elements. Whether
    // the name really is an event handler of the target is checked below,
    // against the target's own IDL attributes.
    if (!std.mem.startsWith(u8, local_name, "on") or local_name.len <= 2) return;
    const internal = getInternal(instance) orelse return;
    const ns = if (internal.namespace_uri) |n| n.asSlice() else return;
    if (!std.mem.eql(u8, ns, "http://www.w3.org/1999/xhtml")) return;

    // Step 2: determining the target of an event handler.
    const document = (interfaces.Node.get_ownerDocument(instance) catch null) orelse return;
    const element_name = internal.local_name.asSlice();
    const forwards_to_window = (std.mem.eql(u8, element_name, "body") or std.mem.eql(u8, element_name, "frameset")) and
        for (window_reflecting_body_handlers) |h| {
            if (std.mem.eql(u8, h, local_name)) break true;
        } else false;

    // A document with no browsing context has no active global to run in,
    // and "getting the current value" would never compile the handler there
    // (scripting is disabled for it) - so there is nothing to do.
    const window = (interfaces.Document.get_defaultView(document) catch null) orelse return;
    const target: *runtime.Instance = if (forwards_to_window) window else instance;

    const engine_ctx = instance.ctx.getEngineContext() orelse return;
    const context: *v8.ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const isolate = v8.ffi.v8_Isolate_GetCurrent() orelse return;
    const scope = v8.ffi.v8_HandleScope_New(isolate) orelse return;
    defer v8.ffi.v8_HandleScope_Dispose(scope);

    const template_registry = v8.template_registry;
    const target_obj = template_registry.wrapInstanceAsV8Object(
        target,
        template_registry.getInstanceInterfaceName(target),
        isolate,
        context,
    ) catch return;

    // "localName is the name of an event handler content attribute on
    // element": the target exposes an event handler IDL attribute of that name.
    var name_buf: [64]u8 = undefined;
    if (local_name.len >= name_buf.len) return;
    @memcpy(name_buf[0..local_name.len], local_name);
    name_buf[local_name.len] = 0;
    const name_z: [*:0]const u8 = @ptrCast(&name_buf);
    if (!v8.ffi.v8_Object_Has(context, target_obj, name_z)) return;

    const key = v8.ffi.v8_String_NewFromUtf8(isolate, local_name.ptr, @intCast(local_name.len)) orelse return;
    defer v8.ffi.v8_String_Dispose(key);

    // Step 3: deactivate. The IDL attribute set to null clears the handler.
    const body = value orelse {
        const null_value = v8.ffi.v8_Null(isolate) orelse return;
        defer v8.ffi.v8_Global_Dispose(null_value);
        _ = v8.ffi.v8_Object_Set(target_obj, context, @ptrCast(key), null_value);
        return;
    };

    // Getting the current value of the event handler, step 3.9: the scope is
    // the global environment, then - for an element's handler - the document
    // and the element itself. A Window's handler (a body's onload) gets none.
    // TODO: the form owner's object environment between the two.
    var scopes: [2]?*v8.ffi.Object = .{ null, null };
    var scope_count: c_int = 0;
    if (!forwards_to_window) {
        scopes[0] = template_registry.wrapInstanceAsV8Object(
            document,
            template_registry.getInstanceInterfaceName(document),
            isolate,
            context,
        ) catch return;
        scopes[1] = target_obj;
        scope_count = 2;
    }

    var error_info: ?*v8.ffi.V8ErrorInfo = null;
    const function = v8.ffi.v8_CompileEventHandler(
        context,
        local_name.ptr,
        @intCast(local_name.len),
        body.ptr,
        @intCast(body.len),
        forwards_to_window and std.mem.eql(u8, local_name, "onerror"),
        &scopes,
        scope_count,
        &error_info,
    ) orelse {
        // Step 3.7: a body that does not parse leaves the handler null.
        // TODO: report the SyntaxError to the global once "report an
        // exception" dispatches ErrorEvents.
        v8.ffi.v8_FreeErrorInfo(error_info);
        const null_value = v8.ffi.v8_Null(isolate) orelse return;
        defer v8.ffi.v8_Global_Dispose(null_value);
        _ = v8.ffi.v8_Object_Set(target_obj, context, @ptrCast(key), null_value);
        return;
    };
    defer v8.ffi.v8_Global_Dispose(function);

    // Step 3.12: the handler's value is the function - through the IDL
    // attribute, which stores it exactly as `element.onload = fn` would.
    _ = v8.ffi.v8_Object_Set(target_obj, context, @ptrCast(key), function);
}

/// Trigger image loading when src attribute changes on an img element
/// This is called from setAttribute when the src attribute is set on an img element.
fn triggerImageSrcChange(instance: *runtime.Instance, src_value: []const u8) void {
    // Skip empty URLs
    if (src_value.len == 0) {
        return;
    }

    // Import fetch module for HTTP requests
    const fetch_mod = @import("fetch");

    // Initiate the fetch for the image
    const allocator = instance.ctx.allocator;
    var fetch_result = fetch_mod.webidl.globalFetch(allocator, .{ .url = src_value }, .{});
    defer fetch_result.deinit();

    // Create and dispatch the appropriate event based on the result
    switch (fetch_result) {
        .response => |response| {
            // Check if the response indicates success (HTTP 200-299)
            if (response.ok()) {
                // Fire 'load' event
                fireImageEvent(instance, "load") catch {};
            } else {
                // HTTP error status - fire 'error' event
                fireImageEvent(instance, "error") catch {};
            }
        },
        .err => {
            // Network error - fire 'error' event
            fireImageEvent(instance, "error") catch {};
        },
    }
}

/// Helper function to fire load/error events on an image element
fn fireImageEvent(instance: *runtime.Instance, event_type: []const u8) !void {
    const allocator = instance.ctx.allocator;
    const ctx = instance.ctx;

    // Create the event
    const event = try interfaces.Event.init(allocator, ctx);
    errdefer interfaces.Event.deinit(event);

    // Initialize the event with the given type
    // Per spec: bubbles = false for load/error events on elements, cancelable = false
    const event_type_str = runtime.DOMString.initInterned(event_type);
    const bubbles = webidl.Opt(bool).passed(false);
    const cancelable = webidl.Opt(bool).passed(false);
    try interfaces.Event.call_initEvent(event, event_type_str, bubbles, cancelable);

    // Dispatch the event on the element
    _ = try interfaces.EventTarget.call_dispatchEvent(instance, event);
}

/// Operation: insertAdjacentHTML
/// DOM Parsing §3.4 - Parses HTML and inserts it at the specified position
/// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-element-insertadjacenthtml
///
/// Position values:
/// - "beforebegin": Before the element itself
/// - "afterbegin": Just inside the element, before its first child
/// - "beforeend": Just inside the element, after its last child
/// - "afterend": After the element itself
///
/// Note: Requires HTML fragment parsing algorithm (not implemented)
pub fn call_insertAdjacentHTML(instance: *runtime.Instance, position: runtime.DOMString, string: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = position;
    _ = string;
    // TODO: Requires HTML fragment parsing algorithm
    return error.NotImplemented;
}

/// Operation: checkVisibility
/// CSSOM View §3.1 - Checks if the element would be visible
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-checkvisibility
///
/// Returns true if the element is potentially visible (connected, rendered, not hidden).
/// Without a layout engine, we assume elements are visible if they exist.
pub fn call_checkVisibility(instance: *runtime.Instance, options: webidl.Opt(dictionaries.CheckVisibilityOptions)) anyerror!bool {
    _ = instance;
    _ = options; // Layout-related options can't be checked without a layout engine

    // Without a layout engine, we assume all elements are visible
    // A proper implementation would check:
    // - computed display != none
    // - computed visibility != hidden (if checkVisibilityCSS)
    // - opacity > 0 (if checkOpacity)
    // - not a content-visibility: hidden element (if contentVisibilityAuto)
    return true;
}

/// Operation: getAttributeNames
/// DOM §4.8 - Returns the qualified names of all attributes in order
/// Spec: https://dom.spec.whatwg.org/#dom-element-getattributenames
///
/// Returns a sequence of DOMStrings (the qualified names of attributes).
/// Note: These are not guaranteed to be unique.
pub fn call_getAttributeNames(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // "Return the qualified names of the attributes in this's attribute list,
    // in order; otherwise a new list." A sequence<DOMString> is a real array:
    // an impl's return value is the JavaScript value, as in
    // URLSearchParams.getAll.
    const isolate = v8.ffi.v8_Isolate_GetCurrent() orelse return error.InvalidStateError;
    const scope = v8.ffi.v8_HandleScope_New(isolate) orelse return error.OutOfMemory;
    defer v8.ffi.v8_HandleScope_Dispose(scope);
    const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return error.InvalidStateError;
    defer v8.ffi.v8_Context_Dispose(context);

    // A Global<Array> the caller owns; the JSValue carries it to the binding.
    const array = v8.ffi.v8_Array_New(isolate, @intCast(internal.getAttributeCount()));
    errdefer v8.ffi.v8_Value_Dispose(@ptrCast(array));

    var iter = internal.attributeIterator();
    var index: u32 = 0;
    while (iter.next()) |entry| : (index += 1) {
        // The qualified name: "prefix:localName", or the local name alone.
        const qualified_name = if (entry.prefix) |prefix|
            try std.fmt.allocPrint(internal.allocator, "{s}:{s}", .{ prefix, entry.local_name })
        else
            entry.local_name;
        defer if (entry.prefix != null) internal.allocator.free(qualified_name);

        // A Global the caller owns; `Set` takes its own reference.
        const name = v8.ffi.v8_String_NewFromUtf8(isolate, qualified_name.ptr, @intCast(qualified_name.len)) orelse return error.OutOfMemory;
        defer v8.ffi.v8_Value_Dispose(@ptrCast(name));
        _ = v8.ffi.v8_Array_Set(array, context, index, @ptrCast(name));
    }

    return runtime.JSValue{ .handle = .{ .ptr = @ptrCast(array) } };
}

/// Operation: attachShadow
/// DOM §4.10.2 - Attaches a shadow root to this element
/// Spec: https://dom.spec.whatwg.org/#dom-element-attachshadow
///
/// Creates a shadow root for this element and returns it.
/// Throws NotSupportedError if:
/// - Element already has a shadow root
/// - Element is not a valid shadow host (must be custom element or certain HTML elements)
pub fn call_attachShadow(instance: *runtime.Instance, init_data: dictionaries.ShadowRootInit) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Check if element already has a shadow root
    if (internal.shadow_root != null) {
        // Per spec: throw NotSupportedError if element already has a shadow root
        return error.InvalidStateError;
    }

    // TODO: Validate that this element can be a shadow host
    // Valid elements are: article, aside, blockquote, body, div, footer, h1-h6,
    // header, main, nav, p, section, span, or any custom element
    // For now, we allow any element

    // Use the mode directly from the dictionary (it's already an enum type)
    const mode = init_data.mode;

    // Use slotAssignment directly from the dictionary (it's already an enum type)
    const slot_assignment = init_data.slotAssignment orelse enums.SlotAssignmentMode._named_;

    // Create the ShadowRoot using the factory function which properly initializes all state
    const ShadowRootImpl = @import("ShadowRoot.zig");
    const shadow_root = ShadowRootImpl.create(
        internal.allocator,
        instance.ctx,
        instance, // host element
        mode,
        init_data.delegatesFocus orelse false,
        slot_assignment,
        init_data.clonable orelse false,
        init_data.serializable orelse false,
    ) catch return error.OutOfMemory;

    // Store reference in element's internal state
    internal.shadow_root = shadow_root;

    return shadow_root;
}

/// Parse ShadowRootMode from V8 value
fn parseShadowRootMode(ptr: *const anyopaque) enums.ShadowRootMode {
    // The V8 conversion layer passes enum values as strings via anyopaque pointer
    // For now, try to extract the string and match

    // Check if this is a V8 string value
    const v8_value: *v8.ffi.Value = @ptrCast(@constCast(ptr));
    if (v8.ffi.v8_Value_IsString(v8_value)) {
        // Get string length and content
        const str_len = v8.ffi.v8_Value_StringLength_Raw(ptr);
        if (str_len > 0 and str_len <= 10) {
            var buf: [10]u8 = undefined;
            const written = v8.ffi.v8_Value_StringWriteUtf8_Raw(ptr, &buf, @intCast(str_len));
            if (written > 0) {
                const mode_str = buf[0..@intCast(written)];
                if (std.mem.eql(u8, mode_str, "closed")) {
                    return ._closed_;
                }
            }
        }
    }
    // Default to open
    return ._open_;
}

/// Parse SlotAssignmentMode from V8 value
fn parseSlotAssignmentMode(ptr: *const anyopaque) enums.SlotAssignmentMode {
    const v8_value: *v8.ffi.Value = @ptrCast(@constCast(ptr));
    if (v8.ffi.v8_Value_IsString(v8_value)) {
        const str_len = v8.ffi.v8_Value_StringLength_Raw(ptr);
        if (str_len > 0 and str_len <= 10) {
            var buf: [10]u8 = undefined;
            const written = v8.ffi.v8_Value_StringWriteUtf8_Raw(ptr, &buf, @intCast(str_len));
            if (written > 0) {
                const mode_str = buf[0..@intCast(written)];
                if (std.mem.eql(u8, mode_str, "manual")) {
                    return ._manual_;
                }
            }
        }
    }
    // Default to named
    return ._named_;
}

/// Operation: requestPointerLock
/// Pointer Lock API §4.1 - Requests pointer lock on this element
/// Spec: https://w3c.github.io/pointerlock/#dom-element-requestpointerlock
///
/// Note: Returns sentinel - pointer lock requires browser integration
pub fn call_requestPointerLock(instance: *runtime.Instance, options: webidl.Opt(dictionaries.PointerLockOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = options;
    // Pointer lock requires browser integration - return undefined
    // TODO: Should return a rejected Promise with SecurityError
    return runtime.JSValue.jsUndefined;
}

/// Operation: hasAttributeNS
/// DOM §4.8 - Returns true if the element has an attribute with the given namespace and local name
/// Spec: https://dom.spec.whatwg.org/#dom-element-hasattributens
pub fn call_hasAttributeNS(instance: *runtime.Instance, namespace: ?runtime.DOMString, localName: runtime.DOMString) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Step 1: "If namespace is the empty string, then set it to null."
    const ns: ?[]const u8 = if (namespace) |n| (if (n.len() == 0) null else n.asSlice()) else null;
    // Step 2: "Return true if this has an attribute whose namespace is
    // namespace and local name is localName; otherwise false."
    return internal.findAttribute(ns, localName.asSlice()) != null;
}

/// Parse a CSS length value string and return pixels.
/// Supports: px, cm, mm, in, pt, pc (absolute units).
/// Returns null for unsupported units or invalid values.
/// Spec: https://drafts.csswg.org/css-values-4/#lengths
fn parseCssLengthToPixels(value: []const u8) ?f64 {
    const trimmed = std.mem.trim(u8, value, " \t\n\r");
    if (trimmed.len == 0) return null;

    // Find where the numeric part ends
    var numeric_end: usize = 0;
    var has_dot = false;

    for (trimmed, 0..) |c, i| {
        if (c == '-' and i == 0) {
            numeric_end = 1;
        } else if (c == '.' and !has_dot) {
            has_dot = true;
            numeric_end = i + 1;
        } else if (c >= '0' and c <= '9') {
            numeric_end = i + 1;
        } else {
            break;
        }
    }

    if (numeric_end == 0) return null;

    const numeric_str = trimmed[0..numeric_end];
    const unit_str = std.mem.trim(u8, trimmed[numeric_end..], " \t");

    const numeric_value = std.fmt.parseFloat(f64, numeric_str) catch return null;

    // Handle different units - convert to pixels
    // Spec: https://drafts.csswg.org/css-values-4/#absolute-lengths
    if (unit_str.len == 0) {
        // Unitless - in quirks mode this might be treated as px, but strictly it's invalid
        // For pragmatic compatibility, treat as px
        return numeric_value;
    } else if (std.ascii.eqlIgnoreCase(unit_str, "px")) {
        return numeric_value;
    } else if (std.ascii.eqlIgnoreCase(unit_str, "cm")) {
        return numeric_value * 37.7953; // 1cm = 37.7953px
    } else if (std.ascii.eqlIgnoreCase(unit_str, "mm")) {
        return numeric_value * 3.77953; // 1mm = 3.77953px
    } else if (std.ascii.eqlIgnoreCase(unit_str, "in")) {
        return numeric_value * 96.0; // 1in = 96px
    } else if (std.ascii.eqlIgnoreCase(unit_str, "pt")) {
        return numeric_value * (96.0 / 72.0); // 1pt = 96/72px
    } else if (std.ascii.eqlIgnoreCase(unit_str, "pc")) {
        return numeric_value * 16.0; // 1pc = 16px
    } else if (std.ascii.eqlIgnoreCase(unit_str, "q")) {
        return numeric_value * 0.944882; // 1Q = 0.944882px
    }

    // Relative units (em, rem, %, vw, vh, etc.) require layout context
    // Return null to indicate we can't compute the value
    return null;
}

/// Operation: getBoundingClientRect
/// CSSOM View §3.1 - Returns a DOMRect with the element's bounding box
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-getboundingclientrect
///
/// Returns a DOMRect representing the smallest rectangle containing the entire element.
/// For elements with inline CSS dimensions (width/height in pixels), returns those dimensions.
/// For elements without explicit dimensions or with relative units, returns zero dimensions.
pub fn call_getBoundingClientRect(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = getInternal(instance) orelse return error.InvalidStateError;

    var width: f64 = 0;
    var height: f64 = 0;

    // Try to get CSS dimensions from the element's inline style
    // Inline style properties are stored directly in HTMLElement's InternalState
    // (not in CSSStyleDeclaration) so they survive V8 GC of the style wrapper
    if (HTMLElementImpl.getInternalState(instance)) |html_internal| {
        // Get width and height directly from HTMLElement's inline style properties
        if (html_internal.getInlineStyleProperty("width")) |width_value| {
            if (parseCssLengthToPixels(width_value)) |w| {
                width = w;
            }
        }
        if (html_internal.getInlineStyleProperty("height")) |height_value| {
            if (parseCssLengthToPixels(height_value)) |h| {
                height = h;
            }
        }
    }

    // Return DOMRect with computed dimensions
    // x and y are 0 since we don't have layout position information
    return interfaces.DOMRect.call_constructor(
        instance.ctx,
        webidl.Opt(f64).passed(0), // x
        webidl.Opt(f64).passed(0), // y
        webidl.Opt(f64).passed(width), // width
        webidl.Opt(f64).passed(height), // height
    ) catch return error.OutOfMemory;
}

/// Operation: querySelectorAll
/// ParentNode mixin - Returns all elements matching the selector
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-queryselectorall
pub fn call_querySelectorAll(instance: *runtime.Instance, selectors: runtime.DOMString) anyerror!*runtime.Instance {
    // Delegate to ParentNode mixin - pass DOMString directly
    return ParentNode.call_querySelectorAll(instance, selectors);
}

/// Operation: setPointerCapture
/// Pointer Events §5.4.2 - Sets pointer capture
/// Spec: https://w3c.github.io/pointerevents/#dom-element-setpointercapture
///
/// Without pointer event support, this is a no-op
pub fn call_setPointerCapture(instance: *runtime.Instance, pointerId: i32) anyerror!void {
    _ = instance;
    _ = pointerId;
    // No-op without pointer event support
}
