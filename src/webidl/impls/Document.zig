//! Implementation for Document interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-document
//! WHATWG DOM Standard §4.6
//!
//! Document represents the entire HTML or XML document. Conceptually, it is
//! the root of the document tree, and provides the primary access to the
//! document's data.
//!
//! Migrated from: webidl/src/dom/Document.zig

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const Document = interfaces.Document;

// Import related impls for factory methods
const NodeImpl = @import("Node.zig");
const TextImpl = @import("Text.zig");
const CommentImpl = @import("Comment.zig");
const DocumentFragmentImpl = @import("DocumentFragment.zig");
const ProcessingInstructionImpl = @import("ProcessingInstruction.zig");
const CDATASectionImpl = @import("CDATASection.zig");
const EventImpl = @import("Event.zig");
const AttrImpl = @import("Attr.zig");
const DocumentTypeImpl = @import("DocumentType.zig");
const RangeImpl = @import("Range.zig");
const NodeIteratorImpl = @import("NodeIterator.zig");
const TreeWalkerImpl = @import("TreeWalker.zig");

// Import ParentNode mixin for shared ParentNode interface methods
const mixins = @import("mixins");
const ParentNode = mixins.ParentNode;

// Content Security Policy
const csp = @import("csp");

pub const State = Document.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    NotSupportedError,
    HierarchyRequestError,
    NotFoundError,
    OutOfMemory,
};

/// Document format type enumeration
pub const DocType = enum {
    html,
    xml,
};

/// Speculation rule eagerness levels
/// Spec: https://html.spec.whatwg.org/multipage/speculative-loading.html#speculation-rule-eagerness
pub const SpeculationEagerness = enum {
    immediate,
    eager,
    moderate,
    conservative,
};

/// Internal state for Document implementation
/// Spec: https://dom.spec.whatwg.org/#concept-document
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// Cached DOMImplementation instance ([SameObject])
    implementation: ?*runtime.Instance,

    /// String interning pool for tag names, attribute names, etc.
    /// Provides memory savings and O(1) string comparison via pointer equality
    string_pool: std.StringHashMap(void),

    /// Document base URL (fallback: empty string for about:blank)
    /// Stored as owned slice
    base_uri: []const u8,

    /// Document content type (e.g., "text/html", "application/xml")
    /// Stored as DOMString for proper memory management
    content_type: runtime.DOMString,

    /// Document type: html or xml
    doc_type: DocType,

    /// Document URL
    /// Stored as owned slice
    url: []const u8,

    /// Document origin (opaque for now)
    origin: ?*anyopaque,

    /// Document encoding (default: UTF-8)
    /// Stored as DOMString for proper memory management
    encoding: runtime.DOMString,

    /// Document ready state
    ready_state: enums.DocumentReadyState,

    /// The document element (root element, usually <html>)
    document_element: ?*runtime.Instance,

    /// The doctype node (if any)
    doctype: ?*runtime.Instance,

    /// Live ranges associated with this document
    /// Spec: https://dom.spec.whatwg.org/#concept-live-range
    ranges: std.ArrayList(*runtime.Instance),

    /// Node iterators associated with this document
    node_iterators: std.ArrayList(*runtime.Instance),

    // === HTML Document Properties ===

    /// Document title (from <title> element or empty)
    title: runtime.DOMString,

    /// Document dir (text direction: "ltr", "rtl", or "")
    dir: runtime.DOMString,

    /// Document domain (for same-origin policy)
    domain: []const u8,

    /// Document referrer (the URI of the page that linked to this page)
    referrer: []const u8,

    /// Design mode ("on" or "off")
    design_mode: runtime.DOMString,

    /// Visibility state
    visibility_state: enums.DocumentVisibilityState,

    /// Whether document is hidden
    hidden: bool,

    // === Legacy color properties (deprecated but still supported) ===
    fg_color: runtime.DOMString,
    link_color: runtime.DOMString,
    vlink_color: runtime.DOMString,
    alink_color: runtime.DOMString,
    bg_color: runtime.DOMString,

    // === Fullscreen state ===
    fullscreen_enabled: bool,
    fullscreen_element: ?*runtime.Instance,

    // === Pointer lock state ===
    pointer_lock_element: ?*runtime.Instance,

    // === Picture-in-picture state ===
    picture_in_picture_element: ?*runtime.Instance,

    // === Active element (focus) ===
    active_element: ?*runtime.Instance,

    // === StyleSheetList (DocumentOrShadowRoot mixin) ===
    style_sheets: ?*runtime.Instance,

    // === Event handlers storage (using string keys for handler names) ===
    event_handlers: std.StringHashMap(typedefs.EventHandler),

    // === Script execution state (HTML Standard §4.12.1.1) ===

    /// Pending parsing-blocking script
    /// Spec: https://html.spec.whatwg.org/multipage/scripting.html#pending-parsing-blocking-script
    pending_parsing_blocking_script: ?*runtime.Instance,

    /// Set of scripts that will execute as soon as possible
    /// Spec: https://html.spec.whatwg.org/multipage/scripting.html#set-of-scripts-that-will-execute-as-soon-as-possible
    scripts_to_execute_asap: std.ArrayList(*runtime.Instance),

    /// List of scripts that will execute in order as soon as possible
    /// Spec: https://html.spec.whatwg.org/multipage/scripting.html#list-of-scripts-that-will-execute-in-order-as-soon-as-possible
    scripts_to_execute_in_order_asap: std.ArrayList(*runtime.Instance),

    /// List of scripts that will execute when document has finished parsing
    /// Spec: https://html.spec.whatwg.org/multipage/scripting.html#list-of-scripts-that-will-execute-when-the-document-has-finished-parsing
    scripts_to_execute_when_parsing_finished: std.ArrayList(*runtime.Instance),

    /// The currently executing script element (for document.currentScript)
    /// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-currentscript
    current_script: ?*runtime.Instance,

    /// Ignore-destructive-writes counter
    /// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#ignore-destructive-writes-counter
    ignore_destructive_writes_counter: u32,

    /// Whether scripting is enabled for this document
    /// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#concept-n-noscript
    scripting_enabled: bool,

    // === Module Map (HTML Standard §8.1.3.10) ===

    /// Module map for caching compiled ES modules
    /// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#module-map
    /// Key: module specifier (resolved URL), Value: V8 Module handle
    module_map: std.StringHashMap(*anyopaque),

    /// Import map for the document (type="importmap")
    /// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#import-map
    /// Key: bare specifier, Value: resolved URL
    import_map_imports: std.StringHashMap([]const u8),

    /// Import map scopes
    /// Key: scope prefix URL, Value: map of specifier -> resolved URL
    import_map_scopes: std.StringHashMap(std.StringHashMap([]const u8)),

    /// Whether an import map has been acquired for this document
    import_map_acquired: bool,

    // === Content Security Policy (CSP Level 3) ===

    /// CSP list for this document
    /// Spec: https://www.w3.org/TR/CSP3/ §2.2
    /// Contains all policies applied to this document via headers or meta tags.
    csp_list: ?*csp.CSPList,

    /// Document origin for CSP 'self' matching
    csp_self_origin: ?csp.Origin,

    /// Speculation rules: Prefetch URL hints
    /// Spec: https://html.spec.whatwg.org/multipage/speculative-loading.html
    prefetch_hints: std.StringHashMap(SpeculationEagerness),

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .implementation = null,
            .string_pool = std.StringHashMap(void).init(allocator),
            .base_uri = "",
            .content_type = runtime.DOMString.initEmpty(),
            .doc_type = .xml,
            .url = "",
            .origin = null,
            .encoding = runtime.DOMString.initEmpty(),
            .ready_state = ._loading_,
            .document_element = null,
            .doctype = null,
            .ranges = .{},
            .node_iterators = .{},
            // HTML properties
            .title = runtime.DOMString.initEmpty(),
            .dir = runtime.DOMString.initEmpty(),
            .domain = "",
            .referrer = "",
            .design_mode = runtime.DOMString.initInterned("off"),
            .visibility_state = ._visible_,
            .hidden = false,
            // Legacy colors (empty = not set)
            .fg_color = runtime.DOMString.initEmpty(),
            .link_color = runtime.DOMString.initEmpty(),
            .vlink_color = runtime.DOMString.initEmpty(),
            .alink_color = runtime.DOMString.initEmpty(),
            .bg_color = runtime.DOMString.initEmpty(),
            // Fullscreen
            .fullscreen_enabled = true,
            .fullscreen_element = null,
            // Pointer lock
            .pointer_lock_element = null,
            // Picture-in-picture
            .picture_in_picture_element = null,
            // Active element (focus)
            .active_element = null,
            // StyleSheetList
            .style_sheets = null,
            // Event handlers
            .event_handlers = std.StringHashMap(typedefs.EventHandler).init(allocator),
            // Script execution state
            .pending_parsing_blocking_script = null,
            .scripts_to_execute_asap = .{},
            .scripts_to_execute_in_order_asap = .{},
            .scripts_to_execute_when_parsing_finished = .{},
            .current_script = null,
            .ignore_destructive_writes_counter = 0,
            .scripting_enabled = true, // Default to true for browser environments
            // Module map and import map
            .module_map = std.StringHashMap(*anyopaque).init(allocator),
            .import_map_imports = std.StringHashMap([]const u8).init(allocator),
            .import_map_scopes = std.StringHashMap(std.StringHashMap([]const u8)).init(allocator),
            .import_map_acquired = false,
            // CSP
            .csp_list = null,
            .csp_self_origin = null,
            // Speculation rules
            .prefetch_hints = std.StringHashMap(SpeculationEagerness).init(allocator),
        };
    }

    pub fn deinit(self: *InternalState) void {
        // Free all interned strings from pool
        var it = self.string_pool.keyIterator();
        while (it.next()) |key_ptr| {
            self.allocator.free(key_ptr.*);
        }
        self.string_pool.deinit();

        // Clean up lists (don't own the items, just the list storage)
        self.ranges.deinit(self.allocator);
        self.node_iterators.deinit(self.allocator);

        // Free owned strings
        if (self.base_uri.len > 0) {
            self.allocator.free(self.base_uri);
        }
        if (self.url.len > 0) {
            self.allocator.free(self.url);
        }
        if (self.domain.len > 0) {
            self.allocator.free(self.domain);
        }
        if (self.referrer.len > 0) {
            self.allocator.free(self.referrer);
        }

        // Free DOMString storage
        self.content_type.deinit(self.allocator);
        self.encoding.deinit(self.allocator);
        self.title.deinit(self.allocator);
        self.dir.deinit(self.allocator);
        self.design_mode.deinit(self.allocator);
        self.fg_color.deinit(self.allocator);
        self.link_color.deinit(self.allocator);
        self.vlink_color.deinit(self.allocator);
        self.alink_color.deinit(self.allocator);
        self.bg_color.deinit(self.allocator);

        // Event handlers
        self.event_handlers.deinit();

        // Script execution lists (don't own the script elements, just the list storage)
        self.scripts_to_execute_asap.deinit(self.allocator);
        self.scripts_to_execute_in_order_asap.deinit(self.allocator);
        self.scripts_to_execute_when_parsing_finished.deinit(self.allocator);

        // Module map - dispose V8 module handles and free keys
        {
            const v8 = @import("v8");
            var mod_it = self.module_map.iterator();
            while (mod_it.next()) |entry| {
                // Dispose V8 module handle
                const module: *v8.ffi.Module = @ptrCast(@alignCast(entry.value_ptr.*));
                v8.ffi.v8_Module_Dispose(module);
                // Free the key (URL string)
                self.allocator.free(entry.key_ptr.*);
            }
            self.module_map.deinit();
        }

        // Import map - free keys and values
        {
            var imp_it = self.import_map_imports.iterator();
            while (imp_it.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                self.allocator.free(entry.value_ptr.*);
            }
            self.import_map_imports.deinit();
        }

        // Import map scopes
        {
            var scope_it = self.import_map_scopes.iterator();
            while (scope_it.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                // Free nested map
                var nested_it = entry.value_ptr.iterator();
                while (nested_it.next()) |nested_entry| {
                    self.allocator.free(nested_entry.key_ptr.*);
                    self.allocator.free(nested_entry.value_ptr.*);
                }
                entry.value_ptr.deinit();
            }
            self.import_map_scopes.deinit();
        }

        // CSP list and origin
        if (self.csp_list) |csp_list| {
            csp_list.deinit();
            self.allocator.destroy(csp_list);
        }
        if (self.csp_self_origin) |*origin| {
            origin.deinit();
        }

        // Prefetch hints
        {
            var hint_it = self.prefetch_hints.keyIterator();
            while (hint_it.next()) |key_ptr| {
                self.allocator.free(key_ptr.*);
            }
            self.prefetch_hints.deinit();
        }
    }
};

/// Get the internal state from an instance
/// Made public for use by HTMLParser, DOMParser, and other modules that need
/// access to document internals for DOM construction.
pub fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return getInternalFromRegistry(instance);
}

/// Get the Node internal state from a Document instance
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

    // Set node type to DOCUMENT_NODE
    try NodeImpl.setNodeType(instance, NodeImpl.NodeType.DOCUMENT_NODE);

    // Initialize Document's own internal state in registry
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.init(allocator);
    try setInternalInRegistry(instance, internal);

    return instance;
}

/// Global registry for Document internal state
var doc_registry: std.AutoHashMap(usize, *InternalState) = undefined;
var doc_registry_initialized: bool = false;

fn ensureDocRegistry() void {
    if (!doc_registry_initialized) {
        doc_registry = std.AutoHashMap(usize, *InternalState).init(std.heap.page_allocator);
        doc_registry_initialized = true;
    }
}

fn setInternalInRegistry(instance: *runtime.Instance, internal: *InternalState) !void {
    ensureDocRegistry();
    try doc_registry.put(@intFromPtr(instance), internal);
}

fn getInternalFromRegistry(instance: *runtime.Instance) ?*InternalState {
    ensureDocRegistry();
    return doc_registry.get(@intFromPtr(instance));
}

/// Get Document's internal state from the registry
pub fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    return getInternalFromRegistry(instance);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Clean up from registry
    ensureDocRegistry();
    if (doc_registry.get(@intFromPtr(instance))) |internal| {
        internal.deinit();
    }
    _ = doc_registry.remove(@intFromPtr(instance));
    // Node cleanup happens via inheritance chain
    NodeImpl.deinit(instance);
}

/// Constructor implementation
/// DOM §4.6 - new Document()
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
    const instance = try init(allocator, State, &Document.vtable, ctx);
    errdefer deinit(instance);

    // Set default values
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.content_type = try runtime.DOMString.initDupe(allocator, "application/xml");
    internal.url = try allocator.dupe(u8, "about:blank");
    internal.encoding = try runtime.DOMString.initDupe(allocator, "UTF-8");

    return instance;
}

// =============================================================================
// String Interning
// =============================================================================

/// Intern a string in the document's string pool
/// Returns a pointer to the interned string which can be compared via pointer equality
/// If the string is already interned, returns the existing copy
/// Caller does NOT own the returned slice - it's managed by the Document
pub fn internString(instance: *runtime.Instance, str: []const u8) ![]const u8 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Check if string is already interned
    if (internal.string_pool.getKey(str)) |existing| {
        return existing;
    }

    // Not interned yet - allocate and store
    const owned = try internal.allocator.dupe(u8, str);
    errdefer internal.allocator.free(owned);

    try internal.string_pool.put(owned, {});
    return owned;
}

// =============================================================================
// Range and NodeIterator Registration
// =============================================================================

/// Register a live range with this document
/// Spec: https://dom.spec.whatwg.org/#concept-live-range
pub fn registerRange(instance: *runtime.Instance, range: *runtime.Instance) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try internal.ranges.append(internal.allocator, range);
}

/// Unregister a live range from this document
pub fn unregisterRange(instance: *runtime.Instance, range: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;

    for (internal.ranges.items, 0..) |r, i| {
        if (r == range) {
            _ = internal.ranges.orderedRemove(i);
            return;
        }
    }
}

/// Register a node iterator with this document
pub fn registerNodeIterator(instance: *runtime.Instance, iterator: *runtime.Instance) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try internal.node_iterators.append(internal.allocator, iterator);
}

/// Unregister a node iterator from this document
pub fn unregisterNodeIterator(instance: *runtime.Instance, iterator: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;

    for (internal.node_iterators.items, 0..) |iter, i| {
        if (iter == iterator) {
            _ = internal.node_iterators.orderedRemove(i);
            return;
        }
    }
}

/// Getter for implementation
/// DOM §4.6 - Returns document's DOMImplementation object
/// [SameObject] - Always returns the same instance
pub fn get_implementation(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Return cached implementation if it exists
    if (internal.implementation) |impl| {
        return impl;
    }

    // Create and cache DOMImplementation
    const DOMImplementationImpl = @import("DOMImplementation.zig");
    const impl = DOMImplementationImpl.init(
        internal.allocator,
        interfaces.DOMImplementation.State,
        &interfaces.DOMImplementation.vtable,
        instance.ctx,
    ) catch return error.OutOfMemory;

    // Set the associated document
    DOMImplementationImpl.setDocument(impl, instance);

    // Cache and return
    internal.implementation = impl;
    return impl;
}

/// Getter for URL
/// DOM §4.6 - Returns document's URL
pub fn get_URL(instance: *runtime.Instance) anyerror!runtime.USVString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // USVString is just []const u8
    return internal.url;
}

/// Getter for documentURI
/// DOM §4.6 - Returns document's URL (alias for URL)
pub fn get_documentURI(instance: *runtime.Instance) anyerror!runtime.USVString {
    return get_URL(instance);
}

/// Getter for compatMode
/// DOM §4.6 - Returns "BackCompat" if quirks mode, "CSS1Compat" otherwise
/// For now, always return "CSS1Compat" (standards mode)
pub fn get_compatMode(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    // TODO: Track quirks mode flag in InternalState
    // Return interned string - no allocation needed
    return runtime.DOMString.initInterned("CSS1Compat");
}

/// Getter for characterSet
/// DOM §4.6 - Returns document's encoding
pub fn get_characterSet(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.encoding;
}

/// Getter for charset
/// DOM §4.6 - Historical alias for characterSet
pub fn get_charset(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return get_characterSet(instance);
}

/// Getter for inputEncoding
/// DOM §4.6 - Historical alias for characterSet
pub fn get_inputEncoding(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return get_characterSet(instance);
}

/// Getter for contentType
/// DOM §4.6 - Returns document's content type
pub fn get_contentType(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.content_type;
}

/// Getter for doctype
/// DOM §4.6 - Returns the DocumentType node or null
pub fn get_doctype(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.doctype; // Returns null if no doctype
}

/// Getter for documentElement
/// DOM §4.6 - Returns the document element (root element, e.g., <html>)
pub fn get_documentElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.document_element; // Returns null if no document element
}

/// Getter for fragmentDirective
pub fn get_fragmentDirective(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for prerendering
/// Returns whether this document is currently in prerendering mode.
/// In a server-side/headless context, this is always false.
pub fn get_prerendering(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return false;
}

/// Getter for onprerenderingchange
/// Returns the event handler for prerenderingchange events.
pub fn get_onprerenderingchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "prerenderingchange");
}

/// Getter for fullscreenEnabled
/// Fullscreen API - Returns whether fullscreen is enabled
/// Spec: https://fullscreen.spec.whatwg.org/#dom-document-fullscreenenabled
pub fn get_fullscreenEnabled(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.fullscreen_enabled;
}

/// Getter for fullscreen
/// Fullscreen API (obsolete) - Returns true if fullscreen element exists
/// Spec: https://fullscreen.spec.whatwg.org/#dom-document-fullscreen
pub fn get_fullscreen(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.fullscreen_element != null;
}

/// Getter for onfullscreenchange
pub fn get_onfullscreenchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "fullscreenchange");
}

/// Getter for onfullscreenerror
pub fn get_onfullscreenerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "fullscreenerror");
}

/// Getter for timeline
pub fn get_timeline(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for pictureInPictureEnabled
/// Returns whether Picture-in-Picture mode is enabled for this document.
/// In a server-side/headless context, this is always false.
pub fn get_pictureInPictureEnabled(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return false;
}

/// Getter for onpointerlockchange
pub fn get_onpointerlockchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pointerlockchange");
}

/// Getter for onpointerlockerror
pub fn get_onpointerlockerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pointerlockerror");
}

/// Getter for onfreeze
pub fn get_onfreeze(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "freeze");
}

/// Getter for onresume
pub fn get_onresume(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "resume");
}

/// Getter for wasDiscarded
/// Returns whether this document was discarded.
/// In a server-side/headless context, this is always false.
pub fn get_wasDiscarded(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return false;
}

/// Getter for namedFlows
pub fn get_namedFlows(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for rootElement
/// SVG §5.1.2 - Returns the root svg element for SVG documents, null otherwise
pub fn get_rootElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // For SVG documents, this would return the root <svg> element
    // For non-SVG documents, return null
    // TODO: Check if document is SVG and return root svg element
    _ = internal;
    return null;
}

/// Getter for activeViewTransition
/// View Transitions API - Returns the active ViewTransition or null
/// Spec: https://drafts.csswg.org/css-view-transitions/#dom-document-activeviewtransition
pub fn get_activeViewTransition(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    // View transitions not yet implemented - return null
    return null;
}

/// Getter for location
/// HTML §7.7.2 - Returns the Location object for the document
/// Spec: https://html.spec.whatwg.org/multipage/history.html#dom-document-location
/// Returns null if the document is not associated with a browsing context
pub fn get_location(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    // Location object not yet implemented - return null (no browsing context)
    return null;
}

/// Getter for domain
/// HTML §7.5.2 - Returns the document's domain
/// Spec: https://html.spec.whatwg.org/multipage/browsers.html#dom-document-domain
pub fn get_domain(instance: *runtime.Instance) anyerror!runtime.USVString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.domain;
}

/// Getter for referrer
/// HTML §7.5.2 - Returns the document's referrer
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-referrer
pub fn get_referrer(instance: *runtime.Instance) anyerror!runtime.USVString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.referrer;
}

/// Getter for cookie
/// HTML - Returns document's cookies as a string
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-cookie
///
/// Note: In non-browser context, we return an empty string (no cookie jar)
pub fn get_cookie(instance: *runtime.Instance) anyerror!runtime.USVString {
    _ = instance;
    // In non-browser environment, return empty string (no cookie storage)
    return "";
}

/// Getter for lastModified
/// HTML - Returns the date and time the document was last modified
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-lastmodified
///
/// Format: "MM/DD/YYYY hh:mm:ss" (local time)
/// Note: Returns current time as default when actual modification time is unavailable
pub fn get_lastModified(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    // In non-browser environment, return a sensible default
    // Per spec, return "01/01/1970 00:00:00" if the real date is not available
    return runtime.DOMString.initInterned("01/01/1970 00:00:00");
}

/// Getter for readyState
/// DOM §4.6 - Returns the document's ready state
pub fn get_readyState(instance: *runtime.Instance) anyerror!enums.DocumentReadyState {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.ready_state;
}

/// Getter for title
/// HTML §3.1.3 - Returns the document's title
pub fn get_title(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.title;
}

/// Getter for dir
/// HTML §3.2.6 - Returns the document's text direction
pub fn get_dir(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.dir;
}

/// Getter for body
/// HTML §3.1.3 - Returns the body element (the first body or frameset child of html element)
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-body
pub fn get_body(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Get document element (should be <html>)
    const doc_element = internal.document_element orelse return null;

    // Find first body or frameset child of the document element
    const ElementImpl = @import("Element.zig");
    var child = NodeImpl.getFirstChild(doc_element);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            if (ElementImpl.getInternal(c)) |elem_internal| {
                const tag_name = elem_internal.local_name.asSlice();
                // Check for body or frameset (case-insensitive for HTML)
                if (internal.doc_type == .html) {
                    if (std.ascii.eqlIgnoreCase(tag_name, "body") or
                        std.ascii.eqlIgnoreCase(tag_name, "frameset"))
                    {
                        return c;
                    }
                } else {
                    if (std.mem.eql(u8, tag_name, "body") or
                        std.mem.eql(u8, tag_name, "frameset"))
                    {
                        return c;
                    }
                }
            }
        }
        child = NodeImpl.getNextSibling(c);
    }

    return null; // No body or frameset found
}

/// Getter for head
/// HTML §3.1.3 - Returns the head element (the first head child of html element)
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-head
pub fn get_head(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Get document element (should be <html>)
    const doc_element = internal.document_element orelse return null;

    // Find first head child of the document element
    const ElementImpl = @import("Element.zig");
    var child = NodeImpl.getFirstChild(doc_element);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            if (ElementImpl.getInternal(c)) |elem_internal| {
                const tag_name = elem_internal.local_name.asSlice();
                // Check for head (case-insensitive for HTML)
                if (internal.doc_type == .html) {
                    if (std.ascii.eqlIgnoreCase(tag_name, "head")) {
                        return c;
                    }
                } else {
                    if (std.mem.eql(u8, tag_name, "head")) {
                        return c;
                    }
                }
            }
        }
        child = NodeImpl.getNextSibling(c);
    }

    return null; // No head element found
}

/// Helper: Create an HTMLCollection containing elements matching a single tag name
fn createCollectionByTagName(instance: *runtime.Instance, tag_name: []const u8) ImplError!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    const HTMLCollectionImpl = @import("HTMLCollection.zig");
    const collection = try HTMLCollectionImpl.init(
        internal.allocator,
        interfaces.HTMLCollection.State,
        &interfaces.HTMLCollection.vtable,
        instance.ctx,
    );
    errdefer HTMLCollectionImpl.deinit(collection);

    // Traverse tree and collect matching elements
    try collectElementsByTagName(instance, tag_name, internal.doc_type == .html, collection);

    return collection;
}

/// Helper: Create an HTMLCollection containing elements matching multiple tag names
fn createCollectionByTagNames(instance: *runtime.Instance, tag_names: []const []const u8) ImplError!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    const HTMLCollectionImpl = @import("HTMLCollection.zig");
    const collection = try HTMLCollectionImpl.init(
        internal.allocator,
        interfaces.HTMLCollection.State,
        &interfaces.HTMLCollection.vtable,
        instance.ctx,
    );
    errdefer HTMLCollectionImpl.deinit(collection);

    // Traverse tree and collect matching elements
    try collectElementsByTagNames(instance, tag_names, internal.doc_type == .html, collection);

    return collection;
}

/// Helper: Recursively collect elements by multiple tag names
fn collectElementsByTagNames(
    node: *runtime.Instance,
    target_names: []const []const u8,
    is_html: bool,
    collection: *runtime.Instance,
) ImplError!void {
    const HTMLCollectionImpl = @import("HTMLCollection.zig");
    const ElementImpl = @import("Element.zig");

    var child = NodeImpl.getFirstChild(node);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            // Get element's tag name and compare with each target
            if (ElementImpl.getInternal(c)) |elem_internal| {
                const elem_name = elem_internal.local_name.asSlice();
                var matches = false;

                for (target_names) |target_name| {
                    if (is_html) {
                        if (std.ascii.eqlIgnoreCase(elem_name, target_name)) {
                            matches = true;
                            break;
                        }
                    } else {
                        if (std.mem.eql(u8, elem_name, target_name)) {
                            matches = true;
                            break;
                        }
                    }
                }

                if (matches) {
                    HTMLCollectionImpl.addElement(collection, c) catch return error.OutOfMemory;
                }
            }
        }

        // Recursively search descendants
        try collectElementsByTagNames(c, target_names, is_html, collection);

        child = NodeImpl.getNextSibling(c);
    }
}

/// Getter for images
/// HTML §4.8.4 - Returns an HTMLCollection of all img elements
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-images
pub fn get_images(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return createCollectionByTagName(instance, "img");
}

/// Getter for embeds
/// HTML §4.8.6 - Returns an HTMLCollection of all embed elements
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-embeds
pub fn get_embeds(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return createCollectionByTagName(instance, "embed");
}

/// Getter for plugins
/// HTML §4.8.6 - Returns the same as embeds (alias)
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-plugins
pub fn get_plugins(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return get_embeds(instance);
}

/// Getter for links
/// HTML §4.8.2 - Returns an HTMLCollection of all a and area elements with href attribute
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-links
/// Note: This is a simplified implementation - full spec requires filtering by href presence
pub fn get_links(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const tag_names = &[_][]const u8{ "a", "area" };
    return createCollectionByTagNames(instance, tag_names);
}

/// Getter for forms
/// HTML §4.10.3 - Returns an HTMLCollection of all form elements
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-forms
pub fn get_forms(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return createCollectionByTagName(instance, "form");
}

/// Getter for scripts
/// HTML §4.12.1 - Returns an HTMLCollection of all script elements
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-scripts
pub fn get_scripts(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return createCollectionByTagName(instance, "script");
}

/// Getter for currentScript
/// HTML §4.12.1 - Returns the script element currently executing, or null
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-currentscript
///
/// Note: In non-browser context, there's no script currently executing
pub fn get_currentScript(instance: *runtime.Instance) anyerror!?typedefs.HTMLOrSVGScriptElement {
    _ = instance;
    // No script currently executing in server-side/headless context
    return null;
}

/// Getter for defaultView
/// HTML §7.3.1 - Returns the Window object associated with the document, or null
/// Spec: https://html.spec.whatwg.org/multipage/window-object.html#dom-document-defaultview
///
/// Note: In non-browser context, there's no associated window
pub fn get_defaultView(instance: *runtime.Instance) anyerror!?typedefs.WindowProxy {
    _ = instance;
    // No browsing context in server-side/headless context
    return null;
}

/// Getter for designMode
/// HTML §6.5.1 - Returns "on" or "off" depending on design mode state
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-document-designmode
pub fn get_designMode(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.design_mode;
}

/// Getter for hidden
/// Page Visibility - Returns true if document is hidden
/// Spec: https://www.w3.org/TR/page-visibility/#dom-document-hidden
pub fn get_hidden(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.hidden;
}

/// Getter for visibilityState
/// Page Visibility - Returns current visibility state
/// Spec: https://www.w3.org/TR/page-visibility/#dom-document-visibilitystate
pub fn get_visibilityState(instance: *runtime.Instance) anyerror!enums.DocumentVisibilityState {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.visibility_state;
}

/// Getter for onreadystatechange
pub fn get_onreadystatechange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "readystatechange");
}

/// Getter for onvisibilitychange
pub fn get_onvisibilitychange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "visibilitychange");
}

/// Getter for fgColor
/// HTML §14.3.11 (obsolete) - Returns document's text color
pub fn get_fgColor(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.fg_color;
}

/// Getter for linkColor
/// HTML §14.3.11 (obsolete) - Returns document's link color
pub fn get_linkColor(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.link_color;
}

/// Getter for vlinkColor
/// HTML §14.3.11 (obsolete) - Returns document's visited link color
pub fn get_vlinkColor(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.vlink_color;
}

/// Getter for alinkColor
/// HTML §14.3.11 (obsolete) - Returns document's active link color
pub fn get_alinkColor(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.alink_color;
}

/// Getter for bgColor
/// HTML §14.3.11 (obsolete) - Returns document's background color
pub fn get_bgColor(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.bg_color;
}

/// Getter for anchors
/// HTML (obsolete) - Returns an HTMLCollection of all a elements with name attribute
/// Spec: https://html.spec.whatwg.org/multipage/obsolete.html#dom-document-anchors
/// Note: Simplified - returns all 'a' elements (full spec requires name attribute)
pub fn get_anchors(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return createCollectionByTagName(instance, "a");
}

/// Getter for applets
/// HTML (obsolete) - Returns an empty HTMLCollection (applet element is obsolete)
/// Spec: https://html.spec.whatwg.org/multipage/obsolete.html#dom-document-applets
pub fn get_applets(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Return empty collection since applet is obsolete
    const HTMLCollectionImpl = @import("HTMLCollection.zig");
    return try HTMLCollectionImpl.init(
        internal.allocator,
        interfaces.HTMLCollection.State,
        &interfaces.HTMLCollection.vtable,
        instance.ctx,
    );
}

/// Getter for all
pub fn get_all(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for scrollingElement
/// Returns the element that scrolls the document, or null.
/// Without a layout engine, this returns null.
pub fn get_scrollingElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    // Without a layout engine, we cannot determine the scrolling element
    return null;
}

/// Getter for permissionsPolicy
pub fn get_permissionsPolicy(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for fonts
pub fn get_fonts(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for customElementRegistry
/// Returns the custom element registry associated with this document, or null.
pub fn get_customElementRegistry(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    // Custom elements not yet implemented
    return null;
}

/// Getter for fullscreenElement
/// Fullscreen API - Returns the current fullscreen element
/// Spec: https://fullscreen.spec.whatwg.org/#dom-document-fullscreenelement
/// Returns the element in this document that is currently in fullscreen mode, or null.
pub fn get_fullscreenElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.fullscreen_element;
}

/// Getter for pictureInPictureElement
/// Returns the element in this document that is currently in picture-in-picture mode, or null.
pub fn get_pictureInPictureElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.picture_in_picture_element;
}

/// Getter for pointerLockElement
/// Pointer Lock API - Returns the element that has pointer lock, or null.
/// Spec: https://w3c.github.io/pointerlock/#dom-documentorshadowroot-pointerlockelement
pub fn get_pointerLockElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.pointer_lock_element;
}

/// Getter for styleSheets
/// Returns the StyleSheetList of stylesheets associated with this document.
/// Lazily creates an empty StyleSheetList on first access.
pub fn get_styleSheets(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.style_sheets) |sheets| {
        return sheets;
    }
    // Lazily create an empty StyleSheetList
    const StyleSheetList = interfaces.StyleSheetList;
    const sheets = StyleSheetList.init(internal.allocator, instance.ctx) catch return error.OutOfMemory;
    internal.style_sheets = sheets;
    return sheets;
}

/// Getter for adoptedStyleSheets
/// Returns the adopted stylesheets for this document.
/// Returns an empty array sentinel for now.
pub fn get_adoptedStyleSheets(instance: *runtime.Instance) anyerror!*const anyopaque {
    _ = instance;
    // Return empty array sentinel
    const empty: []const *runtime.Instance = &[_]*runtime.Instance{};
    return @ptrCast(empty.ptr);
}

/// Getter for activeElement
/// Returns the deepest element in the document which has focus, or null.
pub fn get_activeElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.active_element;
}

/// Getter for children
/// ParentNode mixin - Returns an HTMLCollection of child elements
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-children
pub fn get_children(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Create an HTMLCollection to hold direct child elements
    const HTMLCollectionImpl = @import("HTMLCollection.zig");
    const collection = try HTMLCollectionImpl.init(
        internal.allocator,
        interfaces.HTMLCollection.State,
        &interfaces.HTMLCollection.vtable,
        instance.ctx,
    );
    errdefer HTMLCollectionImpl.deinit(collection);

    // Iterate direct children and add elements
    var child = NodeImpl.getFirstChild(instance);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            HTMLCollectionImpl.addElement(collection, c) catch return error.OutOfMemory;
        }
        child = NodeImpl.getNextSibling(c);
    }

    return collection;
}

/// Getter for firstElementChild
/// ParentNode mixin - Returns the first child that is an element
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-firstelementchild
pub fn get_firstElementChild(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    var child = NodeImpl.getFirstChild(instance);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            return c;
        }
        child = NodeImpl.getNextSibling(c);
    }
    // No element child found - return null per spec
    return null;
}

/// Getter for lastElementChild
/// ParentNode mixin - Returns the last child that is an element
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-lastelementchild
pub fn get_lastElementChild(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    var last_element: ?*runtime.Instance = null;

    var child = NodeImpl.getFirstChild(instance);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            last_element = c;
        }
        child = NodeImpl.getNextSibling(c);
    }

    // Return null if no element child found per spec
    return last_element;
}

/// Getter for childElementCount
/// ParentNode mixin - Returns the number of child elements
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-childelementcount
pub fn get_childElementCount(instance: *runtime.Instance) anyerror!u32 {
    var count: u32 = 0;

    var child = NodeImpl.getFirstChild(instance);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            count += 1;
        }
        child = NodeImpl.getNextSibling(c);
    }

    return count;
}

// =============================================================================
// Event Handler Helpers
// =============================================================================

/// Helper: Get an event handler by name
/// Returns null (as EventHandler) if not set - EventHandler is already nullable
fn getEventHandler(instance: *runtime.Instance, name: []const u8) typedefs.EventHandler {
    const internal = getInternal(instance) orelse return null;
    // If not in map, return null; if in map, return the stored value (which may itself be null)
    return internal.event_handlers.get(name) orelse null;
}

/// Helper: Set an event handler by name
fn setEventHandler(instance: *runtime.Instance, name: []const u8, handler: typedefs.EventHandler) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.event_handlers.put(name, handler) catch return error.OutOfMemory;
}

// =============================================================================
// Event Handler Getters
// =============================================================================

/// Getter for onabort
pub fn get_onabort(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "abort");
}

/// Getter for onauxclick
pub fn get_onauxclick(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "auxclick");
}

/// Getter for onbeforeinput
pub fn get_onbeforeinput(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "beforeinput");
}

/// Getter for onbeforematch
pub fn get_onbeforematch(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "beforematch");
}

/// Getter for onbeforetoggle
pub fn get_onbeforetoggle(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "beforetoggle");
}

/// Getter for onblur
pub fn get_onblur(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "blur");
}

/// Getter for oncancel
pub fn get_oncancel(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "cancel");
}

/// Getter for oncanplay
pub fn get_oncanplay(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "canplay");
}

/// Getter for oncanplaythrough
pub fn get_oncanplaythrough(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "canplaythrough");
}

/// Getter for onchange
pub fn get_onchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "change");
}

/// Getter for onclick
pub fn get_onclick(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "click");
}

/// Getter for onclose
pub fn get_onclose(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "close");
}

/// Getter for oncommand
pub fn get_oncommand(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "command");
}

/// Getter for oncontextlost
pub fn get_oncontextlost(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "contextlost");
}

/// Getter for oncontextmenu
pub fn get_oncontextmenu(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "contextmenu");
}

/// Getter for oncontextrestored
pub fn get_oncontextrestored(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "contextrestored");
}

/// Getter for oncopy
pub fn get_oncopy(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "copy");
}

/// Getter for oncuechange
pub fn get_oncuechange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "cuechange");
}

/// Getter for oncut
pub fn get_oncut(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "cut");
}

/// Getter for ondblclick
pub fn get_ondblclick(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "dblclick");
}

/// Getter for ondrag
pub fn get_ondrag(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "drag");
}

/// Getter for ondragend
pub fn get_ondragend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "dragend");
}

/// Getter for ondragenter
pub fn get_ondragenter(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "dragenter");
}

/// Getter for ondragleave
pub fn get_ondragleave(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "dragleave");
}

/// Getter for ondragover
pub fn get_ondragover(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "dragover");
}

/// Getter for ondragstart
pub fn get_ondragstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "dragstart");
}

/// Getter for ondrop
pub fn get_ondrop(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "drop");
}

/// Getter for ondurationchange
pub fn get_ondurationchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "durationchange");
}

/// Getter for onemptied
pub fn get_onemptied(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "emptied");
}

/// Getter for onended
pub fn get_onended(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "ended");
}

/// Getter for onerror
/// Returns the error event handler, or null if not set.
pub fn get_onerror(instance: *runtime.Instance) anyerror!typedefs.OnErrorEventHandler {
    _ = instance;
    // OnErrorEventHandler is nullable - return null for not set
    return null;
}

/// Getter for onfocus
pub fn get_onfocus(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "focus");
}

/// Getter for onformdata
pub fn get_onformdata(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "formdata");
}

/// Getter for oninput
pub fn get_oninput(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "input");
}

/// Getter for oninvalid
pub fn get_oninvalid(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "invalid");
}

/// Getter for onkeydown
pub fn get_onkeydown(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "keydown");
}

/// Getter for onkeypress
pub fn get_onkeypress(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "keypress");
}

/// Getter for onkeyup
pub fn get_onkeyup(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "keyup");
}

/// Getter for onload
pub fn get_onload(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "load");
}

/// Getter for onloadeddata
pub fn get_onloadeddata(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "loadeddata");
}

/// Getter for onloadedmetadata
pub fn get_onloadedmetadata(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "loadedmetadata");
}

/// Getter for onloadstart
pub fn get_onloadstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "loadstart");
}

/// Getter for onmousedown
pub fn get_onmousedown(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "mousedown");
}

/// Getter for onmouseenter
pub fn get_onmouseenter(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "mouseenter");
}

/// Getter for onmouseleave
pub fn get_onmouseleave(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "mouseleave");
}

/// Getter for onmousemove
pub fn get_onmousemove(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "mousemove");
}

/// Getter for onmouseout
pub fn get_onmouseout(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "mouseout");
}

/// Getter for onmouseover
pub fn get_onmouseover(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "mouseover");
}

/// Getter for onmouseup
pub fn get_onmouseup(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "mouseup");
}

/// Getter for onpaste
pub fn get_onpaste(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "paste");
}

/// Getter for onpause
pub fn get_onpause(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pause");
}

/// Getter for onplay
pub fn get_onplay(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "play");
}

/// Getter for onplaying
pub fn get_onplaying(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "playing");
}

/// Getter for onprogress
pub fn get_onprogress(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "progress");
}

/// Getter for onratechange
pub fn get_onratechange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "ratechange");
}

/// Getter for onreset
pub fn get_onreset(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "reset");
}

/// Getter for onresize
pub fn get_onresize(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "resize");
}

/// Getter for onscroll
pub fn get_onscroll(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "scroll");
}

/// Getter for onscrollend
pub fn get_onscrollend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "scrollend");
}

/// Getter for onsecuritypolicyviolation
pub fn get_onsecuritypolicyviolation(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "securitypolicyviolation");
}

/// Getter for onseeked
pub fn get_onseeked(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "seeked");
}

/// Getter for onseeking
pub fn get_onseeking(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "seeking");
}

/// Getter for onselect
pub fn get_onselect(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "select");
}

/// Getter for onslotchange
pub fn get_onslotchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "slotchange");
}

/// Getter for onstalled
pub fn get_onstalled(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "stalled");
}

/// Getter for onsubmit
pub fn get_onsubmit(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "submit");
}

/// Getter for onsuspend
pub fn get_onsuspend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "suspend");
}

/// Getter for ontimeupdate
pub fn get_ontimeupdate(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "timeupdate");
}

/// Getter for ontoggle
pub fn get_ontoggle(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "toggle");
}

/// Getter for onvolumechange
pub fn get_onvolumechange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "volumechange");
}

/// Getter for onwaiting
pub fn get_onwaiting(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "waiting");
}

/// Getter for onwebkitanimationend
pub fn get_onwebkitanimationend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "webkitanimationend");
}

/// Getter for onwebkitanimationiteration
pub fn get_onwebkitanimationiteration(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "webkitanimationiteration");
}

/// Getter for onwebkitanimationstart
pub fn get_onwebkitanimationstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "webkitanimationstart");
}

/// Getter for onwebkittransitionend
pub fn get_onwebkittransitionend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "webkittransitionend");
}

/// Getter for onwheel
pub fn get_onwheel(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "wheel");
}

/// Getter for onselectstart
pub fn get_onselectstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "selectstart");
}

/// Getter for onselectionchange
pub fn get_onselectionchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "selectionchange");
}

/// Getter for onanimationstart
pub fn get_onanimationstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "animationstart");
}

/// Getter for onanimationiteration
pub fn get_onanimationiteration(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "animationiteration");
}

/// Getter for onanimationend
pub fn get_onanimationend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "animationend");
}

/// Getter for onanimationcancel
pub fn get_onanimationcancel(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "animationcancel");
}

/// Getter for ontransitionrun
pub fn get_ontransitionrun(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "transitionrun");
}

/// Getter for ontransitionstart
pub fn get_ontransitionstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "transitionstart");
}

/// Getter for ontransitionend
pub fn get_ontransitionend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "transitionend");
}

/// Getter for ontransitioncancel
pub fn get_ontransitioncancel(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "transitioncancel");
}

/// Getter for onbeforexrselect
pub fn get_onbeforexrselect(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "beforexrselect");
}

/// Getter for onpointerover
pub fn get_onpointerover(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pointerover");
}

/// Getter for onpointerenter
pub fn get_onpointerenter(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pointerenter");
}

/// Getter for onpointerdown
pub fn get_onpointerdown(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pointerdown");
}

/// Getter for onpointermove
pub fn get_onpointermove(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pointermove");
}

/// Getter for onpointerrawupdate
pub fn get_onpointerrawupdate(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pointerrawupdate");
}

/// Getter for onpointerup
pub fn get_onpointerup(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pointerup");
}

/// Getter for onpointercancel
pub fn get_onpointercancel(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pointercancel");
}

/// Getter for onpointerout
pub fn get_onpointerout(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pointerout");
}

/// Getter for onpointerleave
pub fn get_onpointerleave(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "pointerleave");
}

/// Getter for ongotpointercapture
pub fn get_ongotpointercapture(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "gotpointercapture");
}

/// Getter for onlostpointercapture
pub fn get_onlostpointercapture(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "lostpointercapture");
}

/// Getter for ontouchstart
pub fn get_ontouchstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "touchstart");
}

/// Getter for ontouchend
pub fn get_ontouchend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "touchend");
}

/// Getter for ontouchmove
pub fn get_ontouchmove(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "touchmove");
}

/// Getter for ontouchcancel
pub fn get_ontouchcancel(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "touchcancel");
}

/// Getter for onfencedtreeclick
pub fn get_onfencedtreeclick(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "fencedtreeclick");
}

/// Getter for onsnapchanged
pub fn get_onsnapchanged(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "snapchanged");
}

/// Getter for onsnapchanging
pub fn get_onsnapchanging(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return getEventHandler(instance, "snapchanging");
}

// =============================================================================
// Event Handler Setters
// =============================================================================

/// Setter for onprerenderingchange
pub fn set_onprerenderingchange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "prerenderingchange", value);
}

/// Setter for onfullscreenchange
pub fn set_onfullscreenchange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "fullscreenchange", value);
}

/// Setter for onfullscreenerror
pub fn set_onfullscreenerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "fullscreenerror", value);
}

/// Setter for onpointerlockchange
pub fn set_onpointerlockchange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "pointerlockchange", value);
}

/// Setter for onpointerlockerror
pub fn set_onpointerlockerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "pointerlockerror", value);
}

/// Setter for onfreeze
pub fn set_onfreeze(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "freeze", value);
}

/// Setter for onresume
pub fn set_onresume(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "resume", value);
}

/// Setter for domain
/// HTML §7.5.2 - Sets the document's domain (for same-origin policy relaxation)
/// Spec: https://html.spec.whatwg.org/multipage/browsers.html#dom-document-domain
/// Note: This is deprecated and has security implications
pub fn set_domain(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Free old domain if it was allocated
    if (internal.domain.len > 0) {
        internal.allocator.free(internal.domain);
    }

    // Clone the new domain value
    internal.domain = internal.allocator.dupe(u8, value) catch return error.OutOfMemory;
}

/// Setter for cookie
/// HTML - Sets a cookie
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-cookie
///
/// Note: In non-browser context, this is a no-op (no cookie jar)
pub fn set_cookie(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    // In non-browser environment, ignore cookie sets (no cookie storage)
}

/// Setter for title
/// HTML §3.1.3 - Sets the document's title
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#document.title
pub fn set_title(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.title.deinit(internal.allocator);
    internal.title = value.clone(internal.allocator) catch return error.OutOfMemory;
    // TODO: Update the <title> element in the DOM if it exists
}

/// Setter for dir
/// HTML §3.2.6 - Sets the document's text direction ("ltr", "rtl", or "")
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-dir
pub fn set_dir(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.dir.deinit(internal.allocator);
    internal.dir = value.clone(internal.allocator) catch return error.OutOfMemory;
    // TODO: Update the dir attribute on the html element if it exists
}

/// Setter for body
/// HTML §3.1.3 - Sets the body element
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-body
///
/// Steps:
/// 1. If the new value is not a body or frameset element, throw HierarchyRequestError
/// 2. If the new value is the same as the old value, return
/// 3. If the old body element exists, replace it with the new value
/// 4. Otherwise, append the new value to the html element
pub fn set_body(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const ElementImpl = @import("Element.zig");

    // Step 1: Validate new value is body or frameset
    const value_node_type = NodeImpl.getNodeType(value) orelse 0;
    if (value_node_type != NodeImpl.NodeType.ELEMENT_NODE) {
        return error.HierarchyRequestError;
    }

    const value_internal = ElementImpl.getInternal(value) orelse return error.HierarchyRequestError;
    const tag_name = value_internal.local_name.asSlice();

    const is_body = if (internal.doc_type == .html)
        std.ascii.eqlIgnoreCase(tag_name, "body")
    else
        std.mem.eql(u8, tag_name, "body");

    const is_frameset = if (internal.doc_type == .html)
        std.ascii.eqlIgnoreCase(tag_name, "frameset")
    else
        std.mem.eql(u8, tag_name, "frameset");

    if (!is_body and !is_frameset) {
        return error.HierarchyRequestError;
    }

    // Step 2: If new value is same as old value, return
    const old_body = get_body(instance) catch null;
    if (old_body) |ob| {
        if (ob == value) return;
    }

    // Get document element (html)
    const doc_element = internal.document_element orelse return error.HierarchyRequestError;

    // Step 3: If old body exists, replace it
    if (old_body) |ob| {
        // Remove old body and insert new in its place
        _ = try NodeImpl.call_replaceChild(doc_element, value, ob);
    } else {
        // Step 4: Append to html element
        _ = try NodeImpl.appendChild(doc_element, value);
    }

    // Set owner document
    try NodeImpl.setOwnerDocument(value, instance);
}

/// Setter for designMode
/// HTML §6.5.1 - Sets design mode ("on" or "off")
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-document-designmode
pub fn set_designMode(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const val_slice = value.asSlice();

    // Only "on" and "off" are valid values (case-insensitive)
    if (std.ascii.eqlIgnoreCase(val_slice, "on")) {
        internal.design_mode.deinit(internal.allocator);
        internal.design_mode = runtime.DOMString.initInterned("on");
    } else if (std.ascii.eqlIgnoreCase(val_slice, "off")) {
        internal.design_mode.deinit(internal.allocator);
        internal.design_mode = runtime.DOMString.initInterned("off");
    }
    // Invalid values are ignored per spec
}

/// Setter for onreadystatechange
pub fn set_onreadystatechange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "readystatechange", value);
}

/// Setter for onvisibilitychange
pub fn set_onvisibilitychange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "visibilitychange", value);
}

/// Setter for fgColor
/// HTML §14.3.11 (obsolete) - Sets document's text color
pub fn set_fgColor(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.fg_color.deinit(internal.allocator);
    internal.fg_color = value.clone(internal.allocator) catch return error.OutOfMemory;
}

/// Setter for linkColor
/// HTML §14.3.11 (obsolete) - Sets document's link color
pub fn set_linkColor(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.link_color.deinit(internal.allocator);
    internal.link_color = value.clone(internal.allocator) catch return error.OutOfMemory;
}

/// Setter for vlinkColor
/// HTML §14.3.11 (obsolete) - Sets document's visited link color
pub fn set_vlinkColor(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.vlink_color.deinit(internal.allocator);
    internal.vlink_color = value.clone(internal.allocator) catch return error.OutOfMemory;
}

/// Setter for alinkColor
/// HTML §14.3.11 (obsolete) - Sets document's active link color
pub fn set_alinkColor(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.alink_color.deinit(internal.allocator);
    internal.alink_color = value.clone(internal.allocator) catch return error.OutOfMemory;
}

/// Setter for bgColor
/// HTML §14.3.11 (obsolete) - Sets document's background color
pub fn set_bgColor(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.bg_color.deinit(internal.allocator);
    internal.bg_color = value.clone(internal.allocator) catch return error.OutOfMemory;
}

/// Setter for adoptedStyleSheets
/// Sets the adopted stylesheets for this document.
/// Currently a no-op as CSSOM is not fully implemented.
pub fn set_adoptedStyleSheets(instance: *runtime.Instance, value: *const anyopaque) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - CSSOM not fully implemented
}

/// Setter for onabort
pub fn set_onabort(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "abort", value);
}

/// Setter for onauxclick
pub fn set_onauxclick(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "auxclick", value);
}

/// Setter for onbeforeinput
pub fn set_onbeforeinput(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "beforeinput", value);
}

/// Setter for onbeforematch
pub fn set_onbeforematch(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "beforematch", value);
}

/// Setter for onbeforetoggle
pub fn set_onbeforetoggle(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "beforetoggle", value);
}

/// Setter for onblur
pub fn set_onblur(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "blur", value);
}

/// Setter for oncancel
pub fn set_oncancel(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "cancel", value);
}

/// Setter for oncanplay
pub fn set_oncanplay(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "canplay", value);
}

/// Setter for oncanplaythrough
pub fn set_oncanplaythrough(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "canplaythrough", value);
}

/// Setter for onchange
pub fn set_onchange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "change", value);
}

/// Setter for onclick
pub fn set_onclick(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "click", value);
}

/// Setter for onclose
pub fn set_onclose(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "close", value);
}

/// Setter for oncommand
pub fn set_oncommand(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "command", value);
}

/// Setter for oncontextlost
pub fn set_oncontextlost(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "contextlost", value);
}

/// Setter for oncontextmenu
pub fn set_oncontextmenu(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "contextmenu", value);
}

/// Setter for oncontextrestored
pub fn set_oncontextrestored(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "contextrestored", value);
}

/// Setter for oncopy
pub fn set_oncopy(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "copy", value);
}

/// Setter for oncuechange
pub fn set_oncuechange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "cuechange", value);
}

/// Setter for oncut
pub fn set_oncut(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "cut", value);
}

/// Setter for ondblclick
pub fn set_ondblclick(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "dblclick", value);
}

/// Setter for ondrag
pub fn set_ondrag(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "drag", value);
}

/// Setter for ondragend
pub fn set_ondragend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "dragend", value);
}

/// Setter for ondragenter
pub fn set_ondragenter(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "dragenter", value);
}

/// Setter for ondragleave
pub fn set_ondragleave(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "dragleave", value);
}

/// Setter for ondragover
pub fn set_ondragover(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "dragover", value);
}

/// Setter for ondragstart
pub fn set_ondragstart(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "dragstart", value);
}

/// Setter for ondrop
pub fn set_ondrop(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "drop", value);
}

/// Setter for ondurationchange
pub fn set_ondurationchange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "durationchange", value);
}

/// Setter for onemptied
pub fn set_onemptied(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "emptied", value);
}

/// Setter for onended
pub fn set_onended(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "ended", value);
}

/// Setter for onerror
/// Sets the error event handler.
/// Currently a no-op as error events are not fully implemented.
pub fn set_onerror(instance: *runtime.Instance, value: typedefs.OnErrorEventHandler) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - error events not fully implemented
}

/// Setter for onfocus
pub fn set_onfocus(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "focus", value);
}

/// Setter for onformdata
pub fn set_onformdata(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "formdata", value);
}

/// Setter for oninput
pub fn set_oninput(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "input", value);
}

/// Setter for oninvalid
pub fn set_oninvalid(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "invalid", value);
}

/// Setter for onkeydown
pub fn set_onkeydown(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "keydown", value);
}

/// Setter for onkeypress
pub fn set_onkeypress(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "keypress", value);
}

/// Setter for onkeyup
pub fn set_onkeyup(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "keyup", value);
}

/// Setter for onload
pub fn set_onload(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "load", value);
}

/// Setter for onloadeddata
pub fn set_onloadeddata(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "loadeddata", value);
}

/// Setter for onloadedmetadata
pub fn set_onloadedmetadata(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "loadedmetadata", value);
}

/// Setter for onloadstart
pub fn set_onloadstart(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "loadstart", value);
}

/// Setter for onmousedown
pub fn set_onmousedown(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "mousedown", value);
}

/// Setter for onmouseenter
pub fn set_onmouseenter(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "mouseenter", value);
}

/// Setter for onmouseleave
pub fn set_onmouseleave(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "mouseleave", value);
}

/// Setter for onmousemove
pub fn set_onmousemove(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "mousemove", value);
}

/// Setter for onmouseout
pub fn set_onmouseout(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "mouseout", value);
}

/// Setter for onmouseover
pub fn set_onmouseover(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "mouseover", value);
}

/// Setter for onmouseup
pub fn set_onmouseup(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "mouseup", value);
}

/// Setter for onpaste
pub fn set_onpaste(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "paste", value);
}

/// Setter for onpause
pub fn set_onpause(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "pause", value);
}

/// Setter for onplay
pub fn set_onplay(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "play", value);
}

/// Setter for onplaying
pub fn set_onplaying(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "playing", value);
}

/// Setter for onprogress
pub fn set_onprogress(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "progress", value);
}

/// Setter for onratechange
pub fn set_onratechange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "ratechange", value);
}

/// Setter for onreset
pub fn set_onreset(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "reset", value);
}

/// Setter for onresize
pub fn set_onresize(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "resize", value);
}

/// Setter for onscroll
pub fn set_onscroll(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "scroll", value);
}

/// Setter for onscrollend
pub fn set_onscrollend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "scrollend", value);
}

/// Setter for onsecuritypolicyviolation
pub fn set_onsecuritypolicyviolation(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "securitypolicyviolation", value);
}

/// Setter for onseeked
pub fn set_onseeked(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "seeked", value);
}

/// Setter for onseeking
pub fn set_onseeking(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "seeking", value);
}

/// Setter for onselect
pub fn set_onselect(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "select", value);
}

/// Setter for onslotchange
pub fn set_onslotchange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "slotchange", value);
}

/// Setter for onstalled
pub fn set_onstalled(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "stalled", value);
}

/// Setter for onsubmit
pub fn set_onsubmit(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "submit", value);
}

/// Setter for onsuspend
pub fn set_onsuspend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "suspend", value);
}

/// Setter for ontimeupdate
pub fn set_ontimeupdate(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "timeupdate", value);
}

/// Setter for ontoggle
pub fn set_ontoggle(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "toggle", value);
}

/// Setter for onvolumechange
pub fn set_onvolumechange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "volumechange", value);
}

/// Setter for onwaiting
pub fn set_onwaiting(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "waiting", value);
}

/// Setter for onwebkitanimationend
pub fn set_onwebkitanimationend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "webkitanimationend", value);
}

/// Setter for onwebkitanimationiteration
pub fn set_onwebkitanimationiteration(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "webkitanimationiteration", value);
}

/// Setter for onwebkitanimationstart
pub fn set_onwebkitanimationstart(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "webkitanimationstart", value);
}

/// Setter for onwebkittransitionend
pub fn set_onwebkittransitionend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "webkittransitionend", value);
}

/// Setter for onwheel
pub fn set_onwheel(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "wheel", value);
}

/// Setter for onselectstart
pub fn set_onselectstart(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "selectstart", value);
}

/// Setter for onselectionchange
pub fn set_onselectionchange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "selectionchange", value);
}

/// Setter for onanimationstart
pub fn set_onanimationstart(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "animationstart", value);
}

/// Setter for onanimationiteration
pub fn set_onanimationiteration(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "animationiteration", value);
}

/// Setter for onanimationend
pub fn set_onanimationend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "animationend", value);
}

/// Setter for onanimationcancel
pub fn set_onanimationcancel(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "animationcancel", value);
}

/// Setter for ontransitionrun
pub fn set_ontransitionrun(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "transitionrun", value);
}

/// Setter for ontransitionstart
pub fn set_ontransitionstart(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "transitionstart", value);
}

/// Setter for ontransitionend
pub fn set_ontransitionend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "transitionend", value);
}

/// Setter for ontransitioncancel
pub fn set_ontransitioncancel(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "transitioncancel", value);
}

/// Setter for onbeforexrselect
pub fn set_onbeforexrselect(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "beforexrselect", value);
}

/// Setter for onpointerover
pub fn set_onpointerover(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "pointerover", value);
}

/// Setter for onpointerenter
pub fn set_onpointerenter(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "pointerenter", value);
}

/// Setter for onpointerdown
pub fn set_onpointerdown(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "pointerdown", value);
}

/// Setter for onpointermove
pub fn set_onpointermove(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "pointermove", value);
}

/// Setter for onpointerrawupdate
pub fn set_onpointerrawupdate(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "pointerrawupdate", value);
}

/// Setter for onpointerup
pub fn set_onpointerup(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "pointerup", value);
}

/// Setter for onpointercancel
pub fn set_onpointercancel(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "pointercancel", value);
}

/// Setter for onpointerout
pub fn set_onpointerout(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "pointerout", value);
}

/// Setter for onpointerleave
pub fn set_onpointerleave(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "pointerleave", value);
}

/// Setter for ongotpointercapture
pub fn set_ongotpointercapture(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "gotpointercapture", value);
}

/// Setter for onlostpointercapture
pub fn set_onlostpointercapture(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "lostpointercapture", value);
}

/// Setter for ontouchstart
pub fn set_ontouchstart(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "touchstart", value);
}

/// Setter for ontouchend
pub fn set_ontouchend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "touchend", value);
}

/// Setter for ontouchmove
pub fn set_ontouchmove(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "touchmove", value);
}

/// Setter for ontouchcancel
pub fn set_ontouchcancel(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "touchcancel", value);
}

/// Setter for onfencedtreeclick
pub fn set_onfencedtreeclick(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "fencedtreeclick", value);
}

/// Setter for onsnapchanged
pub fn set_onsnapchanged(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "snapchanged", value);
}

/// Setter for onsnapchanging
pub fn set_onsnapchanging(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    return setEventHandler(instance, "snapchanging", value);
}

/// Operation: exitPointerLock
/// Exits pointer lock mode. No-op without pointer lock support.
pub fn call_exitPointerLock(instance: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Clear pointer lock element if set
    internal.pointer_lock_element = null;
}

/// Operation: queryCommandState
/// Returns the state of an editing command. Without editing support, returns false.
pub fn call_queryCommandState(instance: *runtime.Instance, commandId: runtime.DOMString) anyerror!bool {
    _ = instance;
    _ = commandId;
    // Without editing support, all command states are false
    return false;
}

/// Operation: parseHTMLUnsafe
pub fn call_parseHTMLUnsafe(instance: *runtime.Instance, html: runtime.DOMString) anyerror!*runtime.Instance {
    _ = instance;
    _ = html;
    return error.NotImplemented;
}

/// Operation: exitPictureInPicture
pub fn call_exitPictureInPicture(instance: *runtime.Instance) anyerror!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: createExpression
pub fn call_createExpression(instance: *runtime.Instance, expression: runtime.DOMString, resolver: webidl.Opt(??*runtime.CallbackWrapper)) anyerror!*runtime.Instance {
    _ = instance;
    _ = expression;
    _ = resolver;
    return error.NotImplemented;
}

/// Operation: elementFromPoint
/// Returns the element at the specified coordinates, or null.
/// Without a layout engine, this always returns null.
pub fn call_elementFromPoint(instance: *runtime.Instance, x: f64, y: f64) anyerror!?*runtime.Instance {
    _ = instance;
    _ = x;
    _ = y;
    // Without a layout engine, we cannot determine element positions
    return null;
}

/// Operation: createElement
/// DOM §4.6 - Creates an element with the given local name
/// Spec: https://dom.spec.whatwg.org/#dom-document-createelement
pub fn call_createElement(instance: *runtime.Instance, localName: runtime.DOMString, options: webidl.Opt(*const anyopaque)) anyerror!*runtime.Instance {
    _ = options; // TODO: Handle ElementCreationOptions (custom elements)
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    const local_name_slice = localName.asSlice();

    // Create element via Element impl
    const ElementImpl = @import("Element.zig");
    const element = try ElementImpl.init(
        internal.allocator,
        interfaces.Element.State,
        &interfaces.Element.vtable,
        instance.ctx,
    );
    errdefer ElementImpl.deinit(element);

    // Set node type to ELEMENT_NODE via Node impl
    try NodeImpl.setNodeType(element, NodeImpl.NodeType.ELEMENT_NODE);

    // Set the local name
    try ElementImpl.setLocalName(element, local_name_slice);

    // Set owner document
    try NodeImpl.setOwnerDocument(element, instance);

    return element;
}

/// Operation: releaseEvents
/// Legacy no-op method for event capture.
pub fn call_releaseEvents(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    // No-op - legacy method
}

/// Operation: prepend
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-prepend
/// Inserts nodes before the first child
/// TODO: Implement variadic parameter conversion from anyopaque to []NodeOrString
/// The ParentNode mixin has the implementation at ParentNode.prepend()
pub fn call_prepend(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
    _ = instance;
    _ = nodes;
    // When variadic support is added:
    // const node_slice = convertVariadicNodes(nodes);
    // ParentNode.prepend(allocator, instance, node_slice, ctx);
    return error.NotImplemented;
}

/// Operation: convertQuadFromNode
pub fn call_convertQuadFromNode(instance: *runtime.Instance, quad: dictionaries.DOMQuadInit, from: typedefs.GeometryNode, options: webidl.Opt(dictionaries.ConvertCoordinateOptions)) anyerror!*runtime.Instance {
    _ = instance;
    _ = quad;
    _ = from;
    _ = options;
    return error.NotImplemented;
}

/// Operation: queryCommandSupported
/// Returns whether an editing command is supported. Without editing support, returns false.
pub fn call_queryCommandSupported(instance: *runtime.Instance, commandId: runtime.DOMString) anyerror!bool {
    _ = instance;
    _ = commandId;
    // Without editing support, no commands are supported
    return false;
}

/// Operation: hasPrivateToken
pub fn call_hasPrivateToken(instance: *runtime.Instance, issuer: runtime.USVString) anyerror!*const anyopaque {
    _ = instance;
    _ = issuer;
    return error.NotImplemented;
}

/// Operation: requestStorageAccessFor
pub fn call_requestStorageAccessFor(instance: *runtime.Instance, requestedOrigin: runtime.USVString) anyerror!*const anyopaque {
    _ = instance;
    _ = requestedOrigin;
    return error.NotImplemented;
}

/// Operation: open
pub fn call_open(instance: *runtime.Instance, unused1: webidl.Opt(runtime.DOMString), unused2: webidl.Opt(runtime.DOMString)) anyerror!*runtime.Instance {
    _ = instance;
    _ = unused1;
    _ = unused2;
    return error.NotImplemented;
}

/// Operation: hasUnpartitionedCookieAccess
pub fn call_hasUnpartitionedCookieAccess(instance: *runtime.Instance) anyerror!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: hasRedemptionRecord
pub fn call_hasRedemptionRecord(instance: *runtime.Instance, issuer: runtime.USVString) anyerror!*const anyopaque {
    _ = instance;
    _ = issuer;
    return error.NotImplemented;
}

/// Operation: execCommand
/// Executes an editing command. Without editing support, returns false.
pub fn call_execCommand(instance: *runtime.Instance, commandId: runtime.DOMString, showUI: webidl.Opt(bool), value: webidl.Opt(runtime.DOMString)) anyerror!bool {
    _ = instance;
    _ = commandId;
    _ = showUI;
    _ = value;
    // Without editing support, commands fail
    return false;
}

/// Operation: measureElement
pub fn call_measureElement(instance: *runtime.Instance, element: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    _ = element;
    return error.NotImplemented;
}

/// Operation: write
/// HTML §8.4.3 - Writes text to the document
/// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-document-write
///
/// Algorithm (HTML §8.4.3.2 "document.write()"):
/// 1. If document is an XML document, throw InvalidStateError
/// 2. If document's throw-on-dynamic-markup-insertion counter > 0, throw InvalidStateError
/// 3. If document is not active, return
/// 4. If document's origin is opaque, return
/// 5. If ignore-destructive-writes counter > 0 and insert-only-flag is not set, return
/// 6. (Steps 6-13 handle document open/parser state - simplified here)
///
/// This implementation handles the ignore-destructive-writes counter check.
pub fn call_write(instance: *runtime.Instance, text: []const runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: If this is an XML document, throw InvalidStateError
    if (internal.doc_type == .xml) {
        return error.InvalidStateError;
    }

    // Step 5: If ignore-destructive-writes counter > 0, return
    // This prevents document.write() from being called during external script execution
    // or module script execution, which would be destructive to the document.
    // Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#ignore-destructive-writes-counter
    if (internal.ignore_destructive_writes_counter > 0) {
        // The call is silently ignored per spec - not an error
        return;
    }

    // Concatenate all text arguments
    var total_len: usize = 0;
    for (text) |t| {
        total_len += t.asSlice().len;
    }

    if (total_len == 0) return;

    // Allocate buffer for concatenated text
    const buffer = try internal.allocator.alloc(u8, total_len);
    defer internal.allocator.free(buffer);

    var offset: usize = 0;
    for (text) |t| {
        const slice = t.asSlice();
        @memcpy(buffer[offset..][0..slice.len], slice);
        offset += slice.len;
    }

    // Get document body to append to
    const body = try get_body(instance);
    if (body == null) {
        // No body element - can't write
        // Full implementation would create one or handle differently
        return;
    }

    // Parse and append the HTML to body
    const HTMLParser = @import("HTMLParser.zig");

    const fragment = HTMLParser.parseFragment(
        internal.allocator,
        instance.ctx,
        buffer,
        body,
    ) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return,
    };
    defer DocumentFragmentImpl.deinit(fragment);

    // Move children from fragment to body
    var child = NodeImpl.getFirstChild(fragment);
    while (child) |c| {
        const next = NodeImpl.getNextSibling(c);
        _ = NodeImpl.call_removeChild(fragment, c) catch break;
        _ = NodeImpl.appendChild(body.?, c) catch break;
        child = next;
    }
}

/// Operation: createAttribute
/// DOM §4.6 - Creates an Attr node with the given local name
/// Spec: https://dom.spec.whatwg.org/#dom-document-createattribute
///
/// Steps:
/// 1. If localName does not match the Name production, throw InvalidCharacterError
/// 2. If this is an HTML document, set localName to ASCII lowercase
/// 3. Return a new Attr with localName as local name
pub fn call_createAttribute(instance: *runtime.Instance, localName: runtime.DOMString) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const local_name_slice = localName.asSlice();

    // TODO: Step 1: Validate localName against Name production

    // Step 2: For HTML documents, convert to lowercase
    var name_buf: [256]u8 = undefined;
    var actual_name = local_name_slice;
    if (internal.doc_type == .html and local_name_slice.len <= name_buf.len) {
        for (local_name_slice, 0..) |c, i| {
            name_buf[i] = std.ascii.toLower(c);
        }
        actual_name = name_buf[0..local_name_slice.len];
    }

    // Step 3: Create a new Attr
    const attr = try AttrImpl.init(
        internal.allocator,
        interfaces.Attr.State,
        &interfaces.Attr.vtable,
        instance.ctx,
    );
    errdefer AttrImpl.deinit(attr);

    // Set node type to ATTRIBUTE_NODE
    try NodeImpl.setNodeType(attr, NodeImpl.NodeType.ATTRIBUTE_NODE);

    // Set the local name on the Attr
    const attr_internal = attr.getState(interfaces.Attr.State).own._internal orelse return error.InvalidStateError;
    attr_internal.local_name = try internal.allocator.dupe(u8, actual_name);

    return attr;
}

/// Operation: clear
/// Legacy method - does nothing.
pub fn call_clear(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    // No-op - legacy method
}

/// Operation: queryCommandIndeterm
/// Returns whether an editing command is in an indeterminate state.
/// Without editing support, returns false.
pub fn call_queryCommandIndeterm(instance: *runtime.Instance, commandId: runtime.DOMString) anyerror!bool {
    _ = instance;
    _ = commandId;
    // Without editing support, no commands are indeterminate
    return false;
}

/// Operation: getElementsByTagNameNS
pub fn call_getElementsByTagNameNS(instance: *runtime.Instance, namespace: ?runtime.DOMString, localName: runtime.DOMString) anyerror!*runtime.Instance {
    _ = instance;
    _ = namespace;
    _ = localName;
    return error.NotImplemented;
}

/// Operation: elementsFromPoint
/// Returns a sequence of elements at the specified coordinates.
/// Without a layout engine, returns an empty sequence.
pub fn call_elementsFromPoint(instance: *runtime.Instance, x: f64, y: f64) anyerror!*const anyopaque {
    _ = instance;
    _ = x;
    _ = y;
    // Without a layout engine, we cannot determine element positions
    // Return empty sequence sentinel
    const empty: []const *runtime.Instance = &[_]*runtime.Instance{};
    return @ptrCast(empty.ptr);
}

/// Operation: createProcessingInstruction
/// DOM §4.6 - Creates a ProcessingInstruction node
/// Spec: https://dom.spec.whatwg.org/#dom-document-createprocessinginstruction
pub fn call_createProcessingInstruction(instance: *runtime.Instance, target: runtime.DOMString, data: runtime.DOMString) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Create ProcessingInstruction node via impl
    const pi = try ProcessingInstructionImpl.init(
        internal.allocator,
        interfaces.ProcessingInstruction.State,
        &interfaces.ProcessingInstruction.vtable,
        instance.ctx,
    );
    errdefer ProcessingInstructionImpl.deinit(pi);

    // Set node type
    try NodeImpl.setNodeType(pi, NodeImpl.NodeType.PROCESSING_INSTRUCTION_NODE);

    // TODO: Set target and data fields on the ProcessingInstruction
    _ = target;
    _ = data;

    // Set owner document
    try NodeImpl.setOwnerDocument(pi, instance);

    return pi;
}

/// Operation: createEvent
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
pub fn call_createEvent(instance: *runtime.Instance, interface: runtime.DOMString) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const interface_slice = interface.asSlice();

    // Step 2: Check ASCII case-insensitive match against known event types
    // Convert to lowercase for comparison
    var lowercase_buf: [64]u8 = undefined;
    if (interface_slice.len > lowercase_buf.len) {
        return error.NotSupportedError;
    }

    for (interface_slice, 0..) |c, i| {
        lowercase_buf[i] = std.ascii.toLower(c);
    }
    const lowercase_interface = lowercase_buf[0..interface_slice.len];

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
    // Proper implementation would create specific event subtypes (UIEvent, MouseEvent, etc.)
    // Note: The created event is in an uninitialized state
    // The caller must call initEvent() to initialize it - this matches legacy behavior per spec

    // Create with empty type and default EventInit (not initialized)
    const event_init = dictionaries.EventInit{
        .bubbles = false,
        .cancelable = false,
        .composed = false,
    };
    const event = try EventImpl.call_constructor(internal.allocator, instance.ctx, runtime.DOMString.initEmpty(), webidl.Opt(dictionaries.EventInit).passed(event_init));

    return event;
}

/// Operation: replaceChildren
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-replacechildren
/// Replaces all children with nodes
/// TODO: Implement variadic parameter conversion from anyopaque to []NodeOrString
/// The ParentNode mixin has the implementation at ParentNode.replaceChildren()
pub fn call_replaceChildren(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
    _ = instance;
    _ = nodes;
    // When variadic support is added:
    // const node_slice = convertVariadicNodes(nodes);
    // ParentNode.replaceChildren(allocator, instance, node_slice, ctx);
    return error.NotImplemented;
}

/// Operation: getBoxQuads
/// Returns the CSS box quads for this document.
/// Without a layout engine, returns an empty sequence.
pub fn call_getBoxQuads(instance: *runtime.Instance, options: webidl.Opt(dictionaries.BoxQuadOptions)) anyerror!*const anyopaque {
    _ = instance;
    _ = options;
    // Without a layout engine, we cannot compute box quads
    // Return empty sequence sentinel
    const empty: []const *runtime.Instance = &[_]*runtime.Instance{};
    return @ptrCast(empty.ptr);
}

/// Operation: convertPointFromNode
pub fn call_convertPointFromNode(instance: *runtime.Instance, point: dictionaries.DOMPointInit, from: typedefs.GeometryNode, options: webidl.Opt(dictionaries.ConvertCoordinateOptions)) anyerror!*runtime.Instance {
    _ = instance;
    _ = point;
    _ = from;
    _ = options;
    return error.NotImplemented;
}

/// Operation: getAnimations
pub fn call_getAnimations(instance: *runtime.Instance) anyerror!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getElementsByClassName
/// DOM §4.4 - Returns a live HTMLCollection of elements with matching class names
/// Spec: https://dom.spec.whatwg.org/#dom-document-getelementsbyclassname
///
/// Steps:
/// 1. Return a collection of descendant elements that have all classes in classNames
///    (classNames is a space-separated string of class names)
pub fn call_getElementsByClassName(instance: *runtime.Instance, classNames: runtime.DOMString) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const class_names = classNames.asSlice();

    // Empty class string returns empty collection
    if (class_names.len == 0) {
        const HTMLCollectionImpl = @import("HTMLCollection.zig");
        return try HTMLCollectionImpl.init(
            internal.allocator,
            interfaces.HTMLCollection.State,
            &interfaces.HTMLCollection.vtable,
            instance.ctx,
        );
    }

    // Create an HTMLCollection to hold results
    const HTMLCollectionImpl = @import("HTMLCollection.zig");
    const collection = try HTMLCollectionImpl.init(
        internal.allocator,
        interfaces.HTMLCollection.State,
        &interfaces.HTMLCollection.vtable,
        instance.ctx,
    );
    errdefer HTMLCollectionImpl.deinit(collection);

    // Traverse tree and collect matching elements
    try collectElementsByClassName(instance, class_names, collection);

    return collection;
}

/// Helper: Recursively collect elements by class name
fn collectElementsByClassName(
    node: *runtime.Instance,
    target_classes: []const u8,
    collection: *runtime.Instance,
) ImplError!void {
    const HTMLCollectionImpl = @import("HTMLCollection.zig");
    const ElementImpl = @import("Element.zig");

    var child = NodeImpl.getFirstChild(node);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            // Check if element has all the target classes
            if (ElementImpl.getInternal(c)) |elem_internal| {
                const elem_classes = elem_internal.class_name.asSlice();
                if (hasAllClasses(elem_classes, target_classes)) {
                    HTMLCollectionImpl.addElement(collection, c) catch return error.OutOfMemory;
                }
            }
        }

        // Recursively search descendants
        try collectElementsByClassName(c, target_classes, collection);

        child = NodeImpl.getNextSibling(c);
    }
}

/// Helper: Check if element_classes contains all classes in target_classes
/// Both are space-separated strings
fn hasAllClasses(element_classes: []const u8, target_classes: []const u8) bool {
    // Split target classes by spaces
    var target_iter = std.mem.splitScalar(u8, target_classes, ' ');
    while (target_iter.next()) |target_class| {
        if (target_class.len == 0) continue; // Skip empty tokens

        // Check if element has this class
        var found = false;
        var elem_iter = std.mem.splitScalar(u8, element_classes, ' ');
        while (elem_iter.next()) |elem_class| {
            if (elem_class.len == 0) continue;
            if (std.mem.eql(u8, elem_class, target_class)) {
                found = true;
                break;
            }
        }

        if (!found) return false;
    }

    return true;
}

/// Operation: getElementsByTagName
/// DOM §4.4 - Returns a live HTMLCollection of elements with matching tag name
/// Spec: https://dom.spec.whatwg.org/#dom-document-getelementsbytagname
///
/// Steps:
/// 1. If qualifiedName is "*", return a collection of all descendant elements
/// 2. Otherwise, return a collection of descendant elements whose qualified name is
///    qualifiedName (case-insensitively for HTML documents)
pub fn call_getElementsByTagName(instance: *runtime.Instance, qualifiedName: runtime.DOMString) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const qname = qualifiedName.asSlice();

    // Create an HTMLCollection to hold results
    const HTMLCollectionImpl = @import("HTMLCollection.zig");
    const collection = try HTMLCollectionImpl.init(
        internal.allocator,
        interfaces.HTMLCollection.State,
        &interfaces.HTMLCollection.vtable,
        instance.ctx,
    );
    errdefer HTMLCollectionImpl.deinit(collection);

    // Traverse tree and collect matching elements
    try collectElementsByTagName(instance, qname, internal.doc_type == .html, collection);

    return collection;
}

/// Helper: Recursively collect elements by tag name
fn collectElementsByTagName(
    node: *runtime.Instance,
    target_name: []const u8,
    is_html: bool,
    collection: *runtime.Instance,
) ImplError!void {
    const HTMLCollectionImpl = @import("HTMLCollection.zig");
    const ElementImpl = @import("Element.zig");
    const wildcard = std.mem.eql(u8, target_name, "*");

    var child = NodeImpl.getFirstChild(node);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            var matches = wildcard;

            if (!wildcard) {
                // Get element's tag name and compare
                if (ElementImpl.getInternal(c)) |elem_internal| {
                    const elem_name = elem_internal.local_name.asSlice();
                    if (is_html) {
                        // Case-insensitive comparison for HTML
                        matches = std.ascii.eqlIgnoreCase(elem_name, target_name);
                    } else {
                        matches = std.mem.eql(u8, elem_name, target_name);
                    }
                }
            }

            if (matches) {
                HTMLCollectionImpl.addElement(collection, c) catch return error.OutOfMemory;
            }
        }

        // Recursively search descendants
        try collectElementsByTagName(c, target_name, is_html, collection);

        child = NodeImpl.getNextSibling(c);
    }
}

/// Operation: evaluate
pub fn call_evaluate(instance: *runtime.Instance, expression: runtime.DOMString, contextNode: *runtime.Instance, resolver: webidl.Opt(??*runtime.CallbackWrapper), @"type": webidl.Opt(u16), result: webidl.Opt(?*runtime.Instance)) anyerror!*runtime.Instance {
    _ = instance;
    _ = expression;
    _ = contextNode;
    _ = resolver;
    _ = @"type";
    _ = result;
    return error.NotImplemented;
}

/// Operation: querySelector
/// ParentNode mixin - Returns the first element matching the selector
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-queryselector
pub fn call_querySelector(instance: *runtime.Instance, selectors: runtime.DOMString) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const selectors_str = selectors.asSlice();

    // Delegate to ParentNode mixin
    const result = ParentNode.querySelector(internal.allocator, instance, selectors_str) catch |err| {
        return switch (err) {
            error.SyntaxError => error.InvalidStateError, // Map SyntaxError to our error set
            error.OutOfMemory => error.OutOfMemory,
            else => error.NotImplemented,
        };
    };

    return result;
}

/// Operation: hasStorageAccess
pub fn call_hasStorageAccess(instance: *runtime.Instance) anyerror!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: importNode
/// DOM §4.6 - Returns a copy of node imported into this document.
/// Spec: https://dom.spec.whatwg.org/#dom-document-importnode
///
/// Steps:
/// 1. If node is a document or shadow root, throw "NotSupportedError"
/// 2. Return clone a node with document=this, subtree=deep
pub fn call_importNode(instance: *runtime.Instance, node: *runtime.Instance, options: webidl.Opt(*const anyopaque)) anyerror!*runtime.Instance {
    _ = options; // TODO: Handle ImportNodeOptions (deep flag)

    // Step 1: Check node type
    const node_type = NodeImpl.getNodeType(node);

    // Document nodes cannot be imported
    if (node_type == NodeImpl.NodeType.DOCUMENT_NODE) {
        return error.NotSupportedError;
    }

    // TODO: Check for shadow root when shadow DOM is implemented

    // Step 2: Clone the node into this document
    // For now, do a shallow clone (deep=false by default)
    // TODO: Parse options to get deep flag
    return cloneNode(instance, node, false);
}

/// Clone a node for importNode/cloneNode
/// Spec: https://dom.spec.whatwg.org/#concept-node-clone
fn cloneNode(doc: *runtime.Instance, node: *runtime.Instance, deep: bool) ImplError!*runtime.Instance {
    const internal = getInternal(doc) orelse return error.InvalidStateError;
    const node_type = NodeImpl.getNodeType(node) orelse return error.InvalidStateError;

    // Clone based on node type
    const copy = switch (node_type) {
        NodeImpl.NodeType.ELEMENT_NODE => blk: {
            // Create new element
            const ElementImpl = @import("Element.zig");
            const elem = try ElementImpl.init(
                internal.allocator,
                interfaces.Element.State,
                &interfaces.Element.vtable,
                doc.ctx,
            );
            try NodeImpl.setNodeType(elem, NodeImpl.NodeType.ELEMENT_NODE);

            // Copy element properties from source
            if (ElementImpl.getInternal(node)) |src_internal| {
                const elem_internal = ElementImpl.getInternal(elem) orelse break :blk elem;

                // Copy namespace, prefix, local name
                if (src_internal.namespace_uri) |ns| {
                    elem_internal.namespace_uri = try ns.clone(internal.allocator);
                }
                if (src_internal.prefix) |p| {
                    elem_internal.prefix = try p.clone(internal.allocator);
                }
                elem_internal.local_name = try src_internal.local_name.clone(internal.allocator);
                elem_internal.id = try src_internal.id.clone(internal.allocator);
                elem_internal.class_name = try src_internal.class_name.clone(internal.allocator);
                elem_internal.slot = try src_internal.slot.clone(internal.allocator);

                // Copy all attributes
                for (src_internal.attributes.items) |attr| {
                    const new_attr = ElementImpl.InternalState.AttributeEntry{
                        .namespace_uri = if (attr.namespace_uri) |ns| try internal.allocator.dupe(u8, ns) else null,
                        .prefix = if (attr.prefix) |p| try internal.allocator.dupe(u8, p) else null,
                        .local_name = try internal.allocator.dupe(u8, attr.local_name),
                        .value = try internal.allocator.dupe(u8, attr.value),
                    };
                    try elem_internal.attributes.append(internal.allocator, new_attr);
                }
            }

            break :blk elem;
        },
        NodeImpl.NodeType.TEXT_NODE => blk: {
            // Clone text data
            const CharacterDataImpl = @import("CharacterData.zig");
            const src_data = CharacterDataImpl.getData(node) orelse "";
            const text = try TextImpl.call_constructor(internal.allocator, doc.ctx, webidl.Opt(runtime.DOMString).passed(runtime.DOMString.initInterned(src_data)));
            break :blk text;
        },
        NodeImpl.NodeType.COMMENT_NODE => blk: {
            // Clone comment data
            const CharacterDataImpl = @import("CharacterData.zig");
            const src_data = CharacterDataImpl.getData(node) orelse "";
            const comment = try CommentImpl.call_constructor(internal.allocator, doc.ctx, webidl.Opt(runtime.DOMString).passed(runtime.DOMString.initInterned(src_data)));
            break :blk comment;
        },
        NodeImpl.NodeType.DOCUMENT_FRAGMENT_NODE => blk: {
            const fragment = try DocumentFragmentImpl.init(
                internal.allocator,
                interfaces.DocumentFragment.State,
                &interfaces.DocumentFragment.vtable,
                doc.ctx,
            );
            try NodeImpl.setNodeType(fragment, NodeImpl.NodeType.DOCUMENT_FRAGMENT_NODE);
            break :blk fragment;
        },
        NodeImpl.NodeType.PROCESSING_INSTRUCTION_NODE => blk: {
            // Get source target and data
            const src_target = ProcessingInstructionImpl.getTarget(node) orelse "";
            const CharacterDataImpl = @import("CharacterData.zig");
            const src_data = CharacterDataImpl.getData(node) orelse "";

            // Create PI with target and data
            const pi = try ProcessingInstructionImpl.createProcessingInstruction(
                internal.allocator,
                doc.ctx,
                src_target,
                src_data,
            );
            break :blk pi;
        },
        NodeImpl.NodeType.CDATA_SECTION_NODE => blk: {
            // Get source data
            const CharacterDataImpl = @import("CharacterData.zig");
            const src_data = CharacterDataImpl.getData(node) orelse "";

            const cdata = try CDATASectionImpl.init(
                internal.allocator,
                interfaces.CDATASection.State,
                &interfaces.CDATASection.vtable,
                doc.ctx,
            );
            try NodeImpl.setNodeType(cdata, NodeImpl.NodeType.CDATA_SECTION_NODE);

            // Set the data via CharacterData
            try CharacterDataImpl.setData(cdata, src_data);

            break :blk cdata;
        },
        NodeImpl.NodeType.DOCUMENT_TYPE_NODE => {
            // DocumentType cannot be imported via importNode per spec
            return error.NotSupportedError;
        },
        else => return error.NotSupportedError,
    };
    errdefer {
        // Clean up on error - cast to generic deinit
        runtime.Instance.deinit(copy);
    }

    // Set owner document
    try NodeImpl.setOwnerDocument(copy, doc);

    // If deep clone, recursively clone children
    if (deep) {
        // Iterate node's children using first_child/next_sibling traversal
        var child = NodeImpl.getFirstChild(node);
        while (child) |c| {
            const child_copy = try cloneNode(doc, c, true);
            // TODO: Append child_copy to copy using proper appendChild
            // For now we just clone; tree structure maintenance needs mutation algorithms
            _ = child_copy;
            child = NodeImpl.getNextSibling(c);
        }
    }

    return copy;
}

/// Operation: createCDATASection
/// DOM §4.6 - Creates a CDATASection node
/// Spec: https://dom.spec.whatwg.org/#dom-document-createcdatasection
/// Note: Only valid for XML documents
pub fn call_createCDATASection(instance: *runtime.Instance, data: runtime.DOMString) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Per spec: If this is an HTML document, throw NotSupportedError
    if (internal.doc_type == .html) {
        return error.NotSupportedError;
    }

    // Create CDATASection node via impl
    const cdata = try CDATASectionImpl.init(
        internal.allocator,
        interfaces.CDATASection.State,
        &interfaces.CDATASection.vtable,
        instance.ctx,
    );
    errdefer CDATASectionImpl.deinit(cdata);

    // Set node type
    try NodeImpl.setNodeType(cdata, NodeImpl.NodeType.CDATA_SECTION_NODE);

    // TODO: Set data field via CharacterData
    _ = data;

    // Set owner document
    try NodeImpl.setOwnerDocument(cdata, instance);

    return cdata;
}

/// Operation: queryCommandEnabled
pub fn call_queryCommandEnabled(instance: *runtime.Instance, commandId: runtime.DOMString) anyerror!bool {
    _ = instance;
    _ = commandId;
    return error.NotImplemented;
}

/// Operation: createRange
/// DOM §5 - Creates a new live Range
/// Spec: https://dom.spec.whatwg.org/#dom-document-createrange
///
/// Steps:
/// 1. Let range be a new live range
/// 2. Set range's start and end to (this, 0)
/// 3. Return range
pub fn call_createRange(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: Create a new Range
    const range = try RangeImpl.init(
        internal.allocator,
        interfaces.Range.State,
        &interfaces.Range.vtable,
        instance.ctx,
    );
    errdefer RangeImpl.deinit(range);

    // Step 2: Set range's start and end to (this, 0)
    // Access Range's internal state to set boundary points
    const range_state = range.getState(interfaces.Range.State);
    if (range_state.own._internal) |range_internal_ptr| {
        const range_internal: *RangeImpl.InternalState = @ptrCast(@alignCast(range_internal_ptr));
        range_internal.start_container = instance;
        range_internal.start_offset = 0;
        range_internal.end_container = instance;
        range_internal.end_offset = 0;
        range_internal.owner_document = instance;
    }

    // Register this range with the document
    try registerRange(instance, range);

    // Step 3: Return range
    return range;
}

/// Operation: getElementById
/// DOM §4.3.1 (NonElementParentNode) - Returns the first element with matching ID
/// Spec: https://dom.spec.whatwg.org/#dom-nonelementparentnode-getelementbyid
///
/// Steps:
/// 1. Return the first element, in tree order, within this's descendants,
///    that has an ID equal to elementId; otherwise null
pub fn call_getElementById(instance: *runtime.Instance, elementId: runtime.DOMString) anyerror!?*runtime.Instance {
    const element_id = elementId.asSlice();

    // Empty ID never matches per spec
    if (element_id.len == 0) {
        return null;
    }

    // Traverse tree in tree order (preorder depth-first)
    return findElementById(instance, element_id);
}

/// Helper: Recursively search for element by ID
fn findElementById(node: *runtime.Instance, target_id: []const u8) ?*runtime.Instance {
    // First check children
    var child = NodeImpl.getFirstChild(node);
    while (child) |c| {
        // Check if this child is an element with matching ID
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            // Get element's id
            const ElementImpl = @import("Element.zig");
            if (ElementImpl.getInternal(c)) |elem_internal| {
                const elem_id = elem_internal.id.asSlice();
                if (std.mem.eql(u8, elem_id, target_id)) {
                    return c;
                }
            }
        }

        // Recursively search descendants
        if (findElementById(c, target_id)) |found| {
            return found;
        }

        child = NodeImpl.getNextSibling(c);
    }

    return null;
}

/// Operation: createAttributeNS
/// DOM §4.6 - Creates an Attr node in the given namespace
/// Spec: https://dom.spec.whatwg.org/#dom-document-createattributens
///
/// Steps:
/// 1. Let namespace, prefix, and localName be the result of passing namespace and qualifiedName
/// 2. Return a new Attr with namespace, prefix, localName, and empty value
pub fn call_createAttributeNS(instance: *runtime.Instance, namespace: ?runtime.DOMString, qualifiedName: runtime.DOMString) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const ns_slice = if (namespace) |ns| ns.asSlice() else "";
    const qname_slice = qualifiedName.asSlice();

    // Parse qualified name for prefix and local name
    var prefix: ?[]const u8 = null;
    var local_name: []const u8 = qname_slice;

    if (std.mem.indexOfScalar(u8, qname_slice, ':')) |colon_pos| {
        prefix = qname_slice[0..colon_pos];
        local_name = qname_slice[colon_pos + 1 ..];
    }

    // Create a new Attr
    const attr = try AttrImpl.init(
        internal.allocator,
        interfaces.Attr.State,
        &interfaces.Attr.vtable,
        instance.ctx,
    );
    errdefer AttrImpl.deinit(attr);

    // Set node type to ATTRIBUTE_NODE
    try NodeImpl.setNodeType(attr, NodeImpl.NodeType.ATTRIBUTE_NODE);

    // Set namespace, prefix, and local name on the Attr
    const attr_internal = attr.getState(interfaces.Attr.State).own._internal orelse return error.InvalidStateError;
    if (ns_slice.len > 0) {
        attr_internal.namespace_uri = try internal.allocator.dupe(u8, ns_slice);
    }
    if (prefix) |p| {
        attr_internal.prefix = try internal.allocator.dupe(u8, p);
    }
    attr_internal.local_name = try internal.allocator.dupe(u8, local_name);

    return attr;
}

/// Operation: hasFocus
/// HTML §6.4.4 - Returns true if document has focus
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-document-hasfocus
///
/// In a typical browser context, this checks if the document's browsing context
/// is focused. Since we're not in a browser, we return true as a sensible default.
pub fn call_hasFocus(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    // In non-browser environment, default to true (document is considered focused)
    // TODO: Integrate with browsing context/window focus state when available
    return true;
}

/// Operation: exitFullscreen
pub fn call_exitFullscreen(instance: *runtime.Instance) anyerror!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: adoptNode
/// DOM §4.6 - Moves node from another document to this document.
/// Spec: https://dom.spec.whatwg.org/#dom-document-adoptnode
///
/// Steps:
/// 1. If node is a document, throw "NotSupportedError"
/// 2. If node is a shadow root, throw "HierarchyRequestError"
/// 3. If node is a DocumentFragment whose host is non-null, return node
/// 4. Adopt node into this document
/// 5. Return node
pub fn call_adoptNode(instance: *runtime.Instance, node: *runtime.Instance) anyerror!*runtime.Instance {
    const node_type = NodeImpl.getNodeType(node);

    // Step 1: Document nodes cannot be adopted
    if (node_type == NodeImpl.NodeType.DOCUMENT_NODE) {
        return error.NotSupportedError;
    }

    // Step 2: Shadow roots cannot be adopted
    // TODO: Check for shadow root when shadow DOM is implemented

    // Step 3: DocumentFragment with host - just return
    if (node_type == NodeImpl.NodeType.DOCUMENT_FRAGMENT_NODE) {
        // TODO: Check DocumentFragment.host when shadow DOM is implemented
        // For now, DocumentFragment doesn't have host field
    }

    // Step 4: Adopt node into this document
    // This involves:
    // a) Remove node from its parent (if any)
    // b) Set node's node document to this
    // c) Recursively set node document for all descendants

    // Remove from parent if attached
    if (NodeImpl.getParent(node)) |parent| {
        _ = parent;
        // TODO: Call parent.removeChild(node) when mutation algorithms are available
    }

    // Set owner document (recursively for descendants)
    try adoptNodeRecursive(instance, node);

    // Step 5: Return node
    return node;
}

/// Recursively adopt a node and all its descendants
/// Spec: https://dom.spec.whatwg.org/#concept-node-adopt
fn adoptNodeRecursive(doc: *runtime.Instance, node: *runtime.Instance) ImplError!void {
    // Set this node's owner document
    try NodeImpl.setOwnerDocument(node, doc);

    // Iterate children and adopt recursively using first_child/next_sibling traversal
    var child = NodeImpl.getFirstChild(node);
    while (child) |c| {
        try adoptNodeRecursive(doc, c);
        child = NodeImpl.getNextSibling(c);
    }
}

/// Operation: createTextNode
/// DOM §4.6 - Creates a Text node with the given data
/// Spec: https://dom.spec.whatwg.org/#dom-document-createtextnode
pub fn call_createTextNode(instance: *runtime.Instance, data: runtime.DOMString) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Create Text node via Text impl constructor
    const text = try TextImpl.call_constructor(internal.allocator, instance.ctx, webidl.Opt(runtime.DOMString).passed(data));
    errdefer TextImpl.deinit(text);

    // Set owner document
    try NodeImpl.setOwnerDocument(text, instance);

    return text;
}

/// Operation: createTreeWalker
/// DOM §6.3 - Creates a TreeWalker object
/// Spec: https://dom.spec.whatwg.org/#dom-document-createtreewalker
///
/// Steps:
/// 1. Create a TreeWalker object
/// 2. Set walker's root to root
/// 3. Set walker's currentNode to root
/// 4. Set walker's whatToShow to whatToShow
/// 5. Set walker's filter to filter
/// 6. Return walker
pub fn call_createTreeWalker(instance: *runtime.Instance, root: *runtime.Instance, whatToShow: webidl.Opt(u32), filter: webidl.Opt(??*runtime.CallbackWrapper)) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    _ = filter; // TODO: Handle NodeFilter callback properly

    // Step 1: Create TreeWalker
    const walker = try TreeWalkerImpl.init(
        internal.allocator,
        interfaces.TreeWalker.State,
        &interfaces.TreeWalker.vtable,
        instance.ctx,
    );
    errdefer TreeWalkerImpl.deinit(walker);

    // Steps 2-5: Initialize walker state
    const walker_state = walker.getState(interfaces.TreeWalker.State);
    if (walker_state.own._internal) |walker_internal_ptr| {
        const walker_internal: *TreeWalkerImpl.InternalState = @ptrCast(@alignCast(walker_internal_ptr));
        walker_internal.root = root;
        walker_internal.current = root;
        walker_internal.what_to_show = if (whatToShow.was_passed) whatToShow.value else 0xFFFFFFFF;
        // walker_internal.filter = filter; // TODO: Handle filter properly
    }

    // Step 6: Return walker
    return walker;
}

/// Operation: getElementsByName
/// HTML §3.1.3 - Returns a NodeList of elements with matching name attribute
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-getelementsbyname
///
/// Note: Returns a live NodeList (but our implementation is static for now)
pub fn call_getElementsByName(instance: *runtime.Instance, elementName: runtime.DOMString) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const target_name = elementName.asSlice();

    // Create a NodeList to hold results
    // We use HTMLCollection since we don't have a separate NodeList impl yet
    const HTMLCollectionImpl = @import("HTMLCollection.zig");
    const collection = try HTMLCollectionImpl.init(
        internal.allocator,
        interfaces.HTMLCollection.State,
        &interfaces.HTMLCollection.vtable,
        instance.ctx,
    );
    errdefer HTMLCollectionImpl.deinit(collection);

    // Traverse tree and collect elements with matching name attribute
    try collectElementsByName(instance, target_name, collection);

    return collection;
}

/// Helper: Recursively collect elements by name attribute
fn collectElementsByName(
    node: *runtime.Instance,
    target_name: []const u8,
    collection: *runtime.Instance,
) ImplError!void {
    const HTMLCollectionImpl = @import("HTMLCollection.zig");
    const ElementImpl = @import("Element.zig");

    var child = NodeImpl.getFirstChild(node);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            // Check if element has matching "name" attribute
            if (ElementImpl.getInternal(c)) |elem_internal| {
                // Look for "name" attribute in element's attributes
                for (elem_internal.attributes.items) |attr| {
                    if (std.mem.eql(u8, attr.local_name, "name")) {
                        if (std.mem.eql(u8, attr.value, target_name)) {
                            HTMLCollectionImpl.addElement(collection, c) catch return error.OutOfMemory;
                        }
                        break;
                    }
                }
            }
        }

        // Recursively search descendants
        try collectElementsByName(c, target_name, collection);

        child = NodeImpl.getNextSibling(c);
    }
}

/// Operation: writeln
/// HTML §8.4.3 - Writes text to the document followed by a newline
/// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-document-writeln
///
/// Same as write() but appends a newline character.
/// Follows the same algorithm as write() with ignore-destructive-writes handling.
pub fn call_writeln(instance: *runtime.Instance, text: []const runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: If this is an XML document, throw InvalidStateError
    if (internal.doc_type == .xml) {
        return error.InvalidStateError;
    }

    // Step 5: If ignore-destructive-writes counter > 0, return
    if (internal.ignore_destructive_writes_counter > 0) {
        return;
    }

    // Calculate total length including newline
    var total_len: usize = 0;
    for (text) |t| {
        total_len += t.asSlice().len;
    }
    total_len += 1; // For newline

    // Allocate buffer for concatenated text plus newline
    const buffer = try internal.allocator.alloc(u8, total_len);
    defer internal.allocator.free(buffer);

    var offset: usize = 0;
    for (text) |t| {
        const slice = t.asSlice();
        @memcpy(buffer[offset..][0..slice.len], slice);
        offset += slice.len;
    }
    buffer[offset] = '\n';

    // Get document body to append to
    const body = try get_body(instance);
    if (body == null) {
        return;
    }

    // Parse and append the HTML to body
    const HTMLParser = @import("HTMLParser.zig");

    const fragment = HTMLParser.parseFragment(
        internal.allocator,
        instance.ctx,
        buffer,
        body,
    ) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return,
    };
    defer DocumentFragmentImpl.deinit(fragment);

    // Move children from fragment to body
    var child = NodeImpl.getFirstChild(fragment);
    while (child) |c| {
        const next = NodeImpl.getNextSibling(c);
        _ = NodeImpl.call_removeChild(fragment, c) catch break;
        _ = NodeImpl.appendChild(body.?, c) catch break;
        child = next;
    }
}

/// Operation: append
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-append
/// Inserts nodes after the last child
/// TODO: Implement variadic parameter conversion from anyopaque to []NodeOrString
/// The ParentNode mixin has the implementation at ParentNode.append()
pub fn call_append(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
    _ = instance;
    _ = nodes;
    // When variadic support is added:
    // const node_slice = convertVariadicNodes(nodes);
    // ParentNode.append(allocator, instance, node_slice, ctx);
    return error.NotImplemented;
}

/// Operation: moveBefore
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-movebefore
/// Moves node to before child, preserving state
/// NOTE: Signature should be `child: ?*runtime.Instance` per spec - codegen needs fixing
pub fn call_moveBefore(instance: *runtime.Instance, node: *runtime.Instance, child: ?*runtime.Instance) anyerror!void {
    // Delegate to ParentNode mixin
    // TODO: When codegen is fixed, change child parameter to optional
    ParentNode.moveBefore(instance, node, child) catch |err| {
        return switch (err) {
            error.HierarchyRequestError => error.HierarchyRequestError,
            error.NotFoundError => error.NotFoundError,
            else => error.NotImplemented,
        };
    };
}

/// Operation: convertRectFromNode
pub fn call_convertRectFromNode(instance: *runtime.Instance, rect: *runtime.Instance, from: typedefs.GeometryNode, options: webidl.Opt(dictionaries.ConvertCoordinateOptions)) anyerror!*runtime.Instance {
    _ = instance;
    _ = rect;
    _ = from;
    _ = options;
    return error.NotImplemented;
}

/// Operation: queryCommandValue
pub fn call_queryCommandValue(instance: *runtime.Instance, commandId: runtime.DOMString) anyerror!runtime.DOMString {
    _ = instance;
    _ = commandId;
    return error.NotImplemented;
}

/// Operation: caretPositionFromPoint
/// Returns the caret position at the specified coordinates, or null.
/// Without a layout engine, this always returns null.
pub fn call_caretPositionFromPoint(instance: *runtime.Instance, x: f64, y: f64, options: webidl.Opt(dictionaries.CaretPositionFromPointOptions)) anyerror!?*runtime.Instance {
    _ = instance;
    _ = x;
    _ = y;
    _ = options;
    // Without a layout engine, we cannot determine caret positions
    return null;
}

/// Operation: startViewTransition
pub fn call_startViewTransition(instance: *runtime.Instance, callbackOptions: webidl.Opt(*const anyopaque)) anyerror!*runtime.Instance {
    _ = instance;
    _ = callbackOptions;
    return error.NotImplemented;
}

/// Operation: createComment
/// DOM §4.6 - Creates a Comment node with the given data
/// Spec: https://dom.spec.whatwg.org/#dom-document-createcomment
pub fn call_createComment(instance: *runtime.Instance, data: runtime.DOMString) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Create Comment node via Comment impl constructor
    const comment = try CommentImpl.call_constructor(internal.allocator, instance.ctx, webidl.Opt(runtime.DOMString).passed(data));
    errdefer CommentImpl.deinit(comment);

    // Set owner document
    try NodeImpl.setOwnerDocument(comment, instance);

    return comment;
}

/// Operation: createDocumentFragment
/// DOM §4.6 - Creates a DocumentFragment node
/// Spec: https://dom.spec.whatwg.org/#dom-document-createdocumentfragment
pub fn call_createDocumentFragment(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Create DocumentFragment node via impl
    const fragment = try DocumentFragmentImpl.init(
        internal.allocator,
        interfaces.DocumentFragment.State,
        &interfaces.DocumentFragment.vtable,
        instance.ctx,
    );
    errdefer DocumentFragmentImpl.deinit(fragment);

    // Set node type
    try NodeImpl.setNodeType(fragment, NodeImpl.NodeType.DOCUMENT_FRAGMENT_NODE);

    // Set owner document
    try NodeImpl.setOwnerDocument(fragment, instance);

    return fragment;
}

/// Operation: getSelection
/// Returns the current text selection, or null if no selection.
/// Without user interaction, this returns null.
pub fn call_getSelection(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    // Without user interaction or a visual context, there's no selection
    return null;
}

/// Operation: close
/// Closes the output stream. No-op in server-side/headless context.
pub fn call_close(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    // No-op - document.write/writeln not fully supported
}

/// Operation: requestStorageAccess
pub fn call_requestStorageAccess(instance: *runtime.Instance) anyerror!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: createElementNS
/// DOM §4.6 - Creates an element in the given namespace
/// Spec: https://dom.spec.whatwg.org/#dom-document-createelementns
///
/// Steps:
/// 1. Validate and extract namespace and qualifiedName
/// 2. Parse qualifiedName for prefix:localName
/// 3. Create element with namespace, prefix, localName
pub fn call_createElementNS(instance: *runtime.Instance, namespace: ?runtime.DOMString, qualifiedName: runtime.DOMString, options: webidl.Opt(*const anyopaque)) anyerror!*runtime.Instance {
    _ = options; // TODO: Handle ElementCreationOptions (custom elements)
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    const ns_slice = if (namespace) |ns| ns.asSlice() else "";
    const qname_slice = qualifiedName.asSlice();

    // Parse qualified name for prefix and local name
    var prefix: ?[]const u8 = null;
    var local_name: []const u8 = qname_slice;

    if (std.mem.indexOfScalar(u8, qname_slice, ':')) |colon_pos| {
        prefix = qname_slice[0..colon_pos];
        local_name = qname_slice[colon_pos + 1 ..];
    }

    // Create element via Element impl
    const ElementImpl = @import("Element.zig");
    const element = try ElementImpl.init(
        internal.allocator,
        interfaces.Element.State,
        &interfaces.Element.vtable,
        instance.ctx,
    );
    errdefer ElementImpl.deinit(element);

    // Set node type to ELEMENT_NODE
    try NodeImpl.setNodeType(element, NodeImpl.NodeType.ELEMENT_NODE);

    // Set namespace, prefix, and local name
    if (ns_slice.len > 0) {
        try ElementImpl.setNamespaceURI(element, ns_slice);
    }
    if (prefix) |p| {
        try ElementImpl.setPrefix(element, p);
    }
    try ElementImpl.setLocalName(element, local_name);

    // Set owner document
    try NodeImpl.setOwnerDocument(element, instance);

    return element;
}

/// Operation: captureEvents
pub fn call_captureEvents(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: querySelectorAll
/// ParentNode mixin - Returns all elements matching the selector
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-queryselectorall
pub fn call_querySelectorAll(instance: *runtime.Instance, selectors: runtime.DOMString) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const selectors_str = selectors.asSlice();

    // Delegate to ParentNode mixin
    return ParentNode.querySelectorAll(internal.allocator, instance, selectors_str, instance.ctx) catch |err| {
        return switch (err) {
            error.SyntaxError => error.InvalidStateError, // Map SyntaxError to our error set
            error.OutOfMemory => error.OutOfMemory,
            else => error.NotImplemented,
        };
    };
}

/// Operation: browsingTopics
pub fn call_browsingTopics(instance: *runtime.Instance, options: webidl.Opt(dictionaries.BrowsingTopicsOptions)) anyerror!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: createNSResolver
pub fn call_createNSResolver(instance: *runtime.Instance, nodeResolver: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    _ = nodeResolver;
    return error.NotImplemented;
}

/// Operation: createNodeIterator
/// DOM §6.2 - Creates a NodeIterator object
/// Spec: https://dom.spec.whatwg.org/#dom-document-createnodeiterator
///
/// Steps:
/// 1. Create a NodeIterator object
/// 2. Set iterator's root to root
/// 3. Set iterator's reference to root
/// 4. Set iterator's pointer before reference to true
/// 5. Set iterator's whatToShow to whatToShow
/// 6. Set iterator's filter to filter
/// 7. Return iterator
pub fn call_createNodeIterator(instance: *runtime.Instance, root: *runtime.Instance, whatToShow: webidl.Opt(u32), filter: webidl.Opt(??*runtime.CallbackWrapper)) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    _ = filter; // TODO: Handle NodeFilter callback properly

    // Step 1: Create NodeIterator
    const iterator = try NodeIteratorImpl.init(
        internal.allocator,
        interfaces.NodeIterator.State,
        &interfaces.NodeIterator.vtable,
        instance.ctx,
    );
    errdefer NodeIteratorImpl.deinit(iterator);

    // Steps 2-6: Initialize iterator state
    const iter_state = iterator.getState(interfaces.NodeIterator.State);
    if (iter_state.own._internal) |iter_internal_ptr| {
        const iter_internal: *NodeIteratorImpl.InternalState = @ptrCast(@alignCast(iter_internal_ptr));
        iter_internal.root = root;
        iter_internal.reference = root;
        iter_internal.pointer_before_reference = true;
        iter_internal.what_to_show = if (whatToShow.was_passed) whatToShow.value else 0xFFFFFFFF;
        // iter_internal.filter = filter; // TODO: Handle filter properly
    }

    // Register this iterator with the document
    try registerNodeIterator(instance, iterator);

    // Step 7: Return iterator
    return iterator;
}

/// Operation: measureText
pub fn call_measureText(instance: *runtime.Instance, text: runtime.DOMString, styleMap: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    _ = text;
    _ = styleMap;
    return error.NotImplemented;
}

// =============================================================================
// Helper Functions for External Use (DOMImplementation, etc.)
// =============================================================================

/// Set the document type (html or xml)
pub fn setDocumentType(instance: *runtime.Instance, doc_type: DocType) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.doc_type = doc_type;
}

/// Set the content type (e.g., "text/html", "application/xml")
pub fn setContentType(instance: *runtime.Instance, content_type: []const u8) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Clean up existing content type
    internal.content_type.deinit(internal.allocator);
    // Set new content type (allocate owned string)
    internal.content_type = try runtime.DOMString.initDupe(internal.allocator, content_type);
}

/// Copy origin from another document
pub fn copyOrigin(instance: *runtime.Instance, source: *runtime.Instance) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const source_internal = getInternal(source) orelse return error.InvalidStateError;
    internal.origin = source_internal.origin;
}

// =============================================================================
// Script Execution Management (HTML Standard §4.12.1.1)
// =============================================================================

/// Get pending parsing-blocking script
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#pending-parsing-blocking-script
pub fn getPendingParsingBlockingScript(instance: *runtime.Instance) ?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    return internal.pending_parsing_blocking_script;
}

/// Set pending parsing-blocking script
pub fn setPendingParsingBlockingScript(instance: *runtime.Instance, script: ?*runtime.Instance) void {
    if (getInternal(instance)) |internal| {
        internal.pending_parsing_blocking_script = script;
    }
}

/// Add script to "execute as soon as possible" set
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#set-of-scripts-that-will-execute-as-soon-as-possible
pub fn addScriptToExecuteAsap(instance: *runtime.Instance, script: *runtime.Instance) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try internal.scripts_to_execute_asap.append(script);
}

/// Remove script from "execute as soon as possible" set
pub fn removeScriptFromExecuteAsap(instance: *runtime.Instance, script: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    for (internal.scripts_to_execute_asap.items, 0..) |s, i| {
        if (s == script) {
            _ = internal.scripts_to_execute_asap.orderedRemove(i);
            return;
        }
    }
}

/// Add script to "execute in order as soon as possible" list
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#list-of-scripts-that-will-execute-in-order-as-soon-as-possible
pub fn addScriptToExecuteInOrderAsap(instance: *runtime.Instance, script: *runtime.Instance) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try internal.scripts_to_execute_in_order_asap.append(script);
}

/// Get first script in "execute in order" list
pub fn getFirstScriptToExecuteInOrder(instance: *runtime.Instance) ?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    if (internal.scripts_to_execute_in_order_asap.items.len > 0) {
        return internal.scripts_to_execute_in_order_asap.items[0];
    }
    return null;
}

/// Remove first script from "execute in order" list
pub fn removeFirstScriptFromExecuteInOrder(instance: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    if (internal.scripts_to_execute_in_order_asap.items.len > 0) {
        _ = internal.scripts_to_execute_in_order_asap.orderedRemove(0);
    }
}

/// Add script to "execute when document has finished parsing" list
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#list-of-scripts-that-will-execute-when-the-document-has-finished-parsing
pub fn addScriptToExecuteWhenParsingFinished(instance: *runtime.Instance, script: *runtime.Instance) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try internal.scripts_to_execute_when_parsing_finished.append(script);
}

/// Get scripts to execute when parsing finished
pub fn getScriptsToExecuteWhenParsingFinished(instance: *runtime.Instance) []const *runtime.Instance {
    const internal = getInternal(instance) orelse return &.{};
    return internal.scripts_to_execute_when_parsing_finished.items;
}

/// Clear scripts to execute when parsing finished
pub fn clearScriptsToExecuteWhenParsingFinished(instance: *runtime.Instance) void {
    if (getInternal(instance)) |internal| {
        internal.scripts_to_execute_when_parsing_finished.clearRetainingCapacity();
    }
}

/// Get scripts from "execute as soon as possible" set
pub fn getScriptsToExecuteAsap(instance: *runtime.Instance) []*runtime.Instance {
    const internal = getInternal(instance) orelse return &[_]*runtime.Instance{};
    return internal.scripts_to_execute_asap.items;
}

/// Pop and return the first script from "execute in order" list
pub fn popFirstScriptToExecuteInOrderAsap(instance: *runtime.Instance) ?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    if (internal.scripts_to_execute_in_order_asap.items.len > 0) {
        return internal.scripts_to_execute_in_order_asap.orderedRemove(0);
    }
    return null;
}

/// Get currently executing script (for document.currentScript)
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-currentscript
pub fn getCurrentScript(instance: *runtime.Instance) ?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    return internal.current_script;
}

/// Set currently executing script
pub fn setCurrentScript(instance: *runtime.Instance, script: ?*runtime.Instance) void {
    if (getInternal(instance)) |internal| {
        internal.current_script = script;
    }
}

/// Increment ignore-destructive-writes counter
/// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#ignore-destructive-writes-counter
pub fn incrementIgnoreDestructiveWritesCounter(instance: *runtime.Instance) void {
    if (getInternal(instance)) |internal| {
        internal.ignore_destructive_writes_counter += 1;
    }
}

/// Decrement ignore-destructive-writes counter
pub fn decrementIgnoreDestructiveWritesCounter(instance: *runtime.Instance) void {
    if (getInternal(instance)) |internal| {
        if (internal.ignore_destructive_writes_counter > 0) {
            internal.ignore_destructive_writes_counter -= 1;
        }
    }
}

/// Check if destructive writes should be ignored
pub fn shouldIgnoreDestructiveWrites(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    return internal.ignore_destructive_writes_counter > 0;
}

/// Check if scripting is enabled
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#concept-n-noscript
pub fn isScriptingEnabled(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    return internal.scripting_enabled;
}

/// Set scripting enabled flag
pub fn setScriptingEnabled(instance: *runtime.Instance, enabled: bool) void {
    if (getInternal(instance)) |internal| {
        internal.scripting_enabled = enabled;
    }
}

// =============================================================================
// Module Map Management (HTML Standard §8.1.3.10)
// =============================================================================

/// Get a module from the module map by URL
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#module-map
///
/// Returns the cached V8 Module handle if found, null otherwise.
pub fn getModule(instance: *runtime.Instance, url: []const u8) ?*anyopaque {
    const internal = getInternal(instance) orelse return null;
    return internal.module_map.get(url);
}

/// Store a module in the module map
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#module-map
///
/// The module handle will be disposed when the document is destroyed.
pub fn setModule(instance: *runtime.Instance, url: []const u8, module: *anyopaque) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // If a module already exists for this URL, dispose the old one first
    if (internal.module_map.get(url)) |old_module| {
        const v8 = @import("v8");
        const mod: *v8.ffi.Module = @ptrCast(@alignCast(old_module));
        v8.ffi.v8_Module_Dispose(mod);
        // Remove old entry (key is already allocated)
        _ = internal.module_map.remove(url);
    }

    // Clone the URL for storage
    const owned_url = try internal.allocator.dupe(u8, url);
    errdefer internal.allocator.free(owned_url);

    try internal.module_map.put(owned_url, module);
}

/// Check if a module exists in the module map
pub fn hasModule(instance: *runtime.Instance, url: []const u8) bool {
    const internal = getInternal(instance) orelse return false;
    return internal.module_map.contains(url);
}

// =============================================================================
// Import Map Management (HTML Standard §8.1.6)
// =============================================================================

/// Check if import map has been acquired
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#import-map
///
/// Once an import map is acquired, subsequent import maps are ignored.
pub fn hasImportMapAcquired(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    return internal.import_map_acquired;
}

/// Mark import map as acquired
pub fn setImportMapAcquired(instance: *runtime.Instance) void {
    if (getInternal(instance)) |internal| {
        internal.import_map_acquired = true;
    }
}

/// Add an import mapping
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#import-map
///
/// Maps a bare specifier to a resolved URL.
pub fn addImportMapping(instance: *runtime.Instance, specifier: []const u8, resolved_url: []const u8) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Clone strings for storage
    const owned_specifier = try internal.allocator.dupe(u8, specifier);
    errdefer internal.allocator.free(owned_specifier);

    const owned_url = try internal.allocator.dupe(u8, resolved_url);
    errdefer internal.allocator.free(owned_url);

    // Remove old mapping if exists
    if (internal.import_map_imports.getKey(specifier)) |old_key| {
        if (internal.import_map_imports.get(old_key)) |old_value| {
            internal.allocator.free(old_value);
        }
        _ = internal.import_map_imports.remove(old_key);
        internal.allocator.free(old_key);
    }

    try internal.import_map_imports.put(owned_specifier, owned_url);
}

/// Resolve an import specifier using the import map
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#resolve-a-module-specifier
///
/// Returns the resolved URL if found in the import map, null otherwise.
pub fn resolveImportSpecifier(instance: *runtime.Instance, specifier: []const u8, referrer_url: []const u8) ?[]const u8 {
    const internal = getInternal(instance) orelse return null;

    // Step 1: Check scopes (more specific takes precedence)
    // Find the longest matching scope prefix
    var best_scope: ?[]const u8 = null;
    var best_scope_len: usize = 0;

    var scope_it = internal.import_map_scopes.keyIterator();
    while (scope_it.next()) |scope_key| {
        if (std.mem.startsWith(u8, referrer_url, scope_key.*)) {
            if (scope_key.len > best_scope_len) {
                best_scope = scope_key.*;
                best_scope_len = scope_key.len;
            }
        }
    }

    // Check the matching scope's mappings
    if (best_scope) |scope| {
        if (internal.import_map_scopes.get(scope)) |scope_map| {
            if (scope_map.get(specifier)) |resolved| {
                return resolved;
            }
        }
    }

    // Step 2: Check top-level imports
    return internal.import_map_imports.get(specifier);
}

/// Add a scoped import mapping
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#import-map
pub fn addScopedImportMapping(
    instance: *runtime.Instance,
    scope_prefix: []const u8,
    specifier: []const u8,
    resolved_url: []const u8,
) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Get or create the scope map
    const scope_map_ptr = internal.import_map_scopes.getPtr(scope_prefix) orelse blk: {
        const owned_scope = try internal.allocator.dupe(u8, scope_prefix);
        errdefer internal.allocator.free(owned_scope);

        const new_map = std.StringHashMap([]const u8).init(internal.allocator);
        try internal.import_map_scopes.put(owned_scope, new_map);
        break :blk internal.import_map_scopes.getPtr(scope_prefix).?;
    };

    // Clone strings for storage
    const owned_specifier = try internal.allocator.dupe(u8, specifier);
    errdefer internal.allocator.free(owned_specifier);

    const owned_url = try internal.allocator.dupe(u8, resolved_url);
    errdefer internal.allocator.free(owned_url);

    try scope_map_ptr.put(owned_specifier, owned_url);
}

// =============================================================================
// Content Security Policy Management (CSP Level 3)
// =============================================================================

/// Get the CSP list for this document
/// Spec: https://www.w3.org/TR/CSP3/ §2.2
pub fn getCSPList(instance: *runtime.Instance) ?*csp.CSPList {
    const internal = getInternal(instance) orelse return null;
    return internal.csp_list;
}

/// Set the CSP list for this document
/// Takes ownership of the CSP list.
pub fn setCSPList(instance: *runtime.Instance, csp_list: *csp.CSPList) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Clean up existing CSP list if any
    if (internal.csp_list) |old_list| {
        old_list.deinit();
        internal.allocator.destroy(old_list);
    }

    internal.csp_list = csp_list;
}

/// Add a policy to the document's CSP list
/// Spec: https://www.w3.org/TR/CSP3/ §2.2.1
pub fn addCSPPolicy(instance: *runtime.Instance, policy: csp.Policy) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Create CSP list if it doesn't exist
    if (internal.csp_list == null) {
        const new_list = try internal.allocator.create(csp.CSPList);
        new_list.* = csp.CSPList.init(internal.allocator);
        internal.csp_list = new_list;
    }

    try internal.csp_list.?.append(policy);
}

/// Get the document's CSP self-origin for 'self' matching
pub fn getCSPSelfOrigin(instance: *runtime.Instance) ?*const csp.Origin {
    const internal = getInternal(instance) orelse return null;
    if (internal.csp_self_origin) |*origin| {
        return origin;
    }
    return null;
}

/// Set the document's CSP self-origin
/// Used for 'self' keyword matching in CSP directives.
pub fn setCSPSelfOrigin(instance: *runtime.Instance, scheme: []const u8, host: []const u8, port: ?u16) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Clean up existing origin if any
    if (internal.csp_self_origin) |*origin| {
        origin.deinit();
    }

    internal.csp_self_origin = try csp.Origin.create(internal.allocator, scheme, host, port);
}

/// Check if an inline script is allowed by CSP
/// Spec: https://www.w3.org/TR/CSP3/ §6.7.3
///
/// Returns true if the script is allowed, false if blocked.
/// This checks script-src (or default-src fallback) for:
/// - 'unsafe-inline' keyword
/// - Nonce matching
/// - Hash matching
pub fn isInlineScriptAllowedByCSP(
    instance: *runtime.Instance,
    nonce: ?[]const u8,
    hash_algorithm: ?[]const u8,
    hash_value: ?[]const u8,
) bool {
    const internal = getInternal(instance) orelse return true; // No document = allow
    const csp_list = internal.csp_list orelse return true; // No CSP = allow

    // Check each policy
    for (csp_list.policies.items) |*policy| {
        // Only check enforcing policies for blocking
        if (policy.disposition != .enforce) continue;

        // Get effective script-src directive (with fallback to default-src)
        const directive = csp.fallback.getEffectiveScriptSrcElem(&policy.directive_set) orelse continue;

        // Check if 'strict-dynamic' is present
        // With strict-dynamic, inline scripts are blocked unless nonced
        const has_strict_dynamic = csp.matching.hasStrictDynamic(&directive.value);

        // Check nonce
        if (nonce) |n| {
            if (csp.matching.doesNonceMatch(n, &directive.value)) {
                continue; // Allowed by nonce
            }
        }

        // Check hash
        if (hash_algorithm) |algo| {
            if (hash_value) |hash| {
                if (csp.matching.doesHashMatch(algo, hash, &directive.value)) {
                    continue; // Allowed by hash
                }
            }
        }

        // Check 'unsafe-inline'
        // Note: 'unsafe-inline' is ignored if nonce or hash is present in the directive
        if (!has_strict_dynamic and csp.matching.allowsUnsafeInline(&directive.value)) {
            // Check if there are any nonces or hashes in the directive
            var has_nonce_or_hash = false;
            for (directive.value.expressions.items) |expr| {
                if (expr.type == .nonce or expr.type == .hash) {
                    has_nonce_or_hash = true;
                    break;
                }
            }

            if (!has_nonce_or_hash) {
                continue; // Allowed by 'unsafe-inline'
            }
        }

        // Script blocked by this policy
        return false;
    }

    return true;
}

/// Check if an external script URL is allowed by CSP
/// Spec: https://www.w3.org/TR/CSP3/ §6.7.2
///
/// Returns true if the URL is allowed, false if blocked.
pub fn isExternalScriptAllowedByCSP(
    instance: *runtime.Instance,
    url_scheme: []const u8,
    url_host: []const u8,
    url_port: ?u16,
    url_path: []const u8,
    nonce: ?[]const u8,
) bool {
    const internal = getInternal(instance) orelse return true; // No document = allow
    const csp_list = internal.csp_list orelse return true; // No CSP = allow

    // Get self origin for 'self' matching
    const self_origin = if (internal.csp_self_origin) |*o| o else null;

    // Check each policy
    for (csp_list.policies.items) |*policy| {
        // Only check enforcing policies for blocking
        if (policy.disposition != .enforce) continue;

        // Get effective script-src directive (with fallback to default-src)
        const directive = csp.fallback.getEffectiveScriptSrcElem(&policy.directive_set) orelse continue;

        // Check if 'strict-dynamic' is present
        const has_strict_dynamic = csp.matching.hasStrictDynamic(&directive.value);

        // With 'strict-dynamic', only nonced/hashed scripts can load other scripts
        if (has_strict_dynamic) {
            // If we have a nonce, check it
            if (nonce) |n| {
                if (csp.matching.doesNonceMatch(n, &directive.value)) {
                    continue; // Allowed by nonce with strict-dynamic
                }
            }
            // Without valid nonce, strict-dynamic blocks URL-based loads
            return false;
        }

        // Check nonce first (takes precedence)
        if (nonce) |n| {
            if (csp.matching.doesNonceMatch(n, &directive.value)) {
                continue; // Allowed by nonce
            }
        }

        // Check URL matching
        if (csp.matching.doesUrlMatchSourceList(
            url_scheme,
            url_host,
            url_port,
            url_path,
            &directive.value,
            self_origin,
            0, // redirect_count
        )) {
            continue; // Allowed by URL
        }

        // Script blocked by this policy
        return false;
    }

    return true;
}

/// Check if eval() is allowed by CSP
/// Spec: https://www.w3.org/TR/CSP3/ §6.7.4
pub fn isEvalAllowedByCSP(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return true;
    const csp_list = internal.csp_list orelse return true;

    for (csp_list.policies.items) |*policy| {
        if (policy.disposition != .enforce) continue;

        const directive = csp.fallback.getEffectiveScriptSrc(&policy.directive_set) orelse continue;

        // Check for 'unsafe-eval'
        if (!csp.matching.allowsUnsafeEval(&directive.value)) {
            return false;
        }
    }

    return true;
}

// =============================================================================
// Speculation Rules Support (HTML Standard §7.6)
// =============================================================================

/// Add a prefetch hint from speculation rules
/// Spec: https://html.spec.whatwg.org/multipage/speculative-loading.html#consider-speculative-loads
pub fn addPrefetchHint(
    instance: *runtime.Instance,
    url: []const u8,
    eagerness: SpeculationEagerness,
) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Check if URL already exists - keep the more eager one
    if (internal.prefetch_hints.get(url)) |existing_eagerness| {
        // More eager = earlier in enum order (immediate=0, conservative=3)
        if (@intFromEnum(eagerness) < @intFromEnum(existing_eagerness)) {
            // New eagerness is more eager, update
            internal.prefetch_hints.put(url, eagerness) catch return error.OutOfMemory;
        }
        // Otherwise keep existing
        return;
    }

    // Add new hint with owned key
    const owned_url = try internal.allocator.dupe(u8, url);
    errdefer internal.allocator.free(owned_url);

    try internal.prefetch_hints.put(owned_url, eagerness);
}

/// Get all prefetch hints for this document
/// Returns a slice of URL strings (borrowed from internal storage)
pub fn getPrefetchHints(instance: *runtime.Instance) []const []const u8 {
    const internal = getInternal(instance) orelse return &.{};

    // Note: This returns a view into the internal storage
    // Caller should not modify or free these strings
    return internal.prefetch_hints.keys();
}

/// Check if a URL is in the prefetch hints
pub fn hasPrefetchHint(instance: *runtime.Instance, url: []const u8) bool {
    const internal = getInternal(instance) orelse return false;
    return internal.prefetch_hints.contains(url);
}

/// Get the eagerness for a prefetch hint
pub fn getPrefetchHintEagerness(instance: *runtime.Instance, url: []const u8) ?SpeculationEagerness {
    const internal = getInternal(instance) orelse return null;
    return internal.prefetch_hints.get(url);
}
