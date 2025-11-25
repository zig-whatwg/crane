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

pub const State = Document.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    NotSupportedError,
    HierarchyRequestError,
    OutOfMemory,
};

/// Document format type enumeration
pub const DocType = enum {
    html,
    xml,
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

    // === Event handlers storage (using string keys for handler names) ===
    event_handlers: std.StringHashMap(typedefs.EventHandler),

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
            // Event handlers
            .event_handlers = std.StringHashMap(typedefs.EventHandler).init(allocator),
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
    }
};

/// Get the internal state from an instance
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return state.own._internal;
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Initialize Document internal state
    const state = instance.getState(StateType);
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.init(allocator);
    state.own._internal = internal;

    // Initialize as DOCUMENT_NODE
    try NodeImpl.setNodeType(instance, NodeImpl.NodeType.DOCUMENT_NODE);

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
    }
    runtime.Instance.deinit(instance);
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
    try internal.ranges.append(range);
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
    try internal.node_iterators.append(iterator);
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
/// TODO: Implement DOMImplementation interface first
pub fn get_implementation(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.implementation) |impl| {
        return impl;
    }
    // TODO: Create and cache DOMImplementation when that interface is migrated
    return error.NotImplemented;
}

/// Getter for URL
/// DOM §4.6 - Returns document's URL
pub fn get_URL(instance: *runtime.Instance) ImplError!runtime.USVString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // USVString is just []const u8
    return internal.url;
}

/// Getter for documentURI
/// DOM §4.6 - Returns document's URL (alias for URL)
pub fn get_documentURI(instance: *runtime.Instance) ImplError!runtime.USVString {
    return get_URL(instance);
}

/// Getter for compatMode
/// DOM §4.6 - Returns "BackCompat" if quirks mode, "CSS1Compat" otherwise
/// For now, always return "CSS1Compat" (standards mode)
pub fn get_compatMode(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Track quirks mode flag in InternalState
    // Return interned string - no allocation needed
    return runtime.DOMString.initInterned("CSS1Compat");
}

/// Getter for characterSet
/// DOM §4.6 - Returns document's encoding
pub fn get_characterSet(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.encoding;
}

/// Getter for charset
/// DOM §4.6 - Historical alias for characterSet
pub fn get_charset(instance: *runtime.Instance) ImplError!runtime.DOMString {
    return get_characterSet(instance);
}

/// Getter for inputEncoding
/// DOM §4.6 - Historical alias for characterSet
pub fn get_inputEncoding(instance: *runtime.Instance) ImplError!runtime.DOMString {
    return get_characterSet(instance);
}

/// Getter for contentType
/// DOM §4.6 - Returns document's content type
pub fn get_contentType(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.content_type;
}

/// Getter for doctype
/// DOM §4.6 - Returns the DocumentType node or null
pub fn get_doctype(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.doctype orelse return error.NotImplemented; // null case - need nullable return
}

/// Getter for documentElement
/// DOM §4.6 - Returns the document element (root element, e.g., <html>)
pub fn get_documentElement(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.document_element orelse return error.NotImplemented; // null case - need nullable return
}

/// Getter for fragmentDirective
pub fn get_fragmentDirective(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for prerendering
pub fn get_prerendering(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onprerenderingchange
pub fn get_onprerenderingchange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for fullscreenEnabled
/// Fullscreen API - Returns whether fullscreen is enabled
/// Spec: https://fullscreen.spec.whatwg.org/#dom-document-fullscreenenabled
pub fn get_fullscreenEnabled(instance: *runtime.Instance) ImplError!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.fullscreen_enabled;
}

/// Getter for fullscreen
/// Fullscreen API (obsolete) - Returns true if fullscreen element exists
/// Spec: https://fullscreen.spec.whatwg.org/#dom-document-fullscreen
pub fn get_fullscreen(instance: *runtime.Instance) ImplError!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.fullscreen_element != null;
}

/// Getter for onfullscreenchange
pub fn get_onfullscreenchange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onfullscreenerror
pub fn get_onfullscreenerror(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for timeline
pub fn get_timeline(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for pictureInPictureEnabled
pub fn get_pictureInPictureEnabled(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onpointerlockchange
pub fn get_onpointerlockchange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onpointerlockerror
pub fn get_onpointerlockerror(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onfreeze
pub fn get_onfreeze(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onresume
pub fn get_onresume(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for wasDiscarded
pub fn get_wasDiscarded(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for namedFlows
pub fn get_namedFlows(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for rootElement
pub fn get_rootElement(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for activeViewTransition
pub fn get_activeViewTransition(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for location
pub fn get_location(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for domain
/// HTML §7.5.2 - Returns the document's domain
/// Spec: https://html.spec.whatwg.org/multipage/browsers.html#dom-document-domain
pub fn get_domain(instance: *runtime.Instance) ImplError!runtime.USVString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.domain;
}

/// Getter for referrer
/// HTML §7.5.2 - Returns the document's referrer
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-referrer
pub fn get_referrer(instance: *runtime.Instance) ImplError!runtime.USVString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.referrer;
}

/// Getter for cookie
pub fn get_cookie(instance: *runtime.Instance) ImplError!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for lastModified
pub fn get_lastModified(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for readyState
/// DOM §4.6 - Returns the document's ready state
pub fn get_readyState(instance: *runtime.Instance) ImplError!enums.DocumentReadyState {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.ready_state;
}

/// Getter for title
/// HTML §3.1.3 - Returns the document's title
pub fn get_title(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.title;
}

/// Getter for dir
/// HTML §3.2.6 - Returns the document's text direction
pub fn get_dir(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.dir;
}

/// Getter for body
/// HTML §3.1.3 - Returns the body element (the first body or frameset child of html element)
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-body
pub fn get_body(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Get document element (should be <html>)
    const doc_element = internal.document_element orelse return error.NotImplemented;

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

    return error.NotImplemented; // null
}

/// Getter for head
/// HTML §3.1.3 - Returns the head element (the first head child of html element)
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-head
pub fn get_head(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Get document element (should be <html>)
    const doc_element = internal.document_element orelse return error.NotImplemented;

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

    return error.NotImplemented; // null
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
pub fn get_images(instance: *runtime.Instance) ImplError!*runtime.Instance {
    return createCollectionByTagName(instance, "img");
}

/// Getter for embeds
/// HTML §4.8.6 - Returns an HTMLCollection of all embed elements
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-embeds
pub fn get_embeds(instance: *runtime.Instance) ImplError!*runtime.Instance {
    return createCollectionByTagName(instance, "embed");
}

/// Getter for plugins
/// HTML §4.8.6 - Returns the same as embeds (alias)
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-plugins
pub fn get_plugins(instance: *runtime.Instance) ImplError!*runtime.Instance {
    return get_embeds(instance);
}

/// Getter for links
/// HTML §4.8.2 - Returns an HTMLCollection of all a and area elements with href attribute
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-links
/// Note: This is a simplified implementation - full spec requires filtering by href presence
pub fn get_links(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const tag_names = &[_][]const u8{ "a", "area" };
    return createCollectionByTagNames(instance, tag_names);
}

/// Getter for forms
/// HTML §4.10.3 - Returns an HTMLCollection of all form elements
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-forms
pub fn get_forms(instance: *runtime.Instance) ImplError!*runtime.Instance {
    return createCollectionByTagName(instance, "form");
}

/// Getter for scripts
/// HTML §4.12.1 - Returns an HTMLCollection of all script elements
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-scripts
pub fn get_scripts(instance: *runtime.Instance) ImplError!*runtime.Instance {
    return createCollectionByTagName(instance, "script");
}

/// Getter for currentScript
pub fn get_currentScript(instance: *runtime.Instance) ImplError!typedefs.HTMLOrSVGScriptElement {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for defaultView
pub fn get_defaultView(instance: *runtime.Instance) ImplError!typedefs.WindowProxy {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for designMode
/// HTML §6.5.1 - Returns "on" or "off" depending on design mode state
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-document-designmode
pub fn get_designMode(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.design_mode;
}

/// Getter for hidden
/// Page Visibility - Returns true if document is hidden
/// Spec: https://www.w3.org/TR/page-visibility/#dom-document-hidden
pub fn get_hidden(instance: *runtime.Instance) ImplError!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.hidden;
}

/// Getter for visibilityState
/// Page Visibility - Returns current visibility state
/// Spec: https://www.w3.org/TR/page-visibility/#dom-document-visibilitystate
pub fn get_visibilityState(instance: *runtime.Instance) ImplError!enums.DocumentVisibilityState {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.visibility_state;
}

/// Getter for onreadystatechange
pub fn get_onreadystatechange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onvisibilitychange
pub fn get_onvisibilitychange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for fgColor
/// HTML §14.3.11 (obsolete) - Returns document's text color
pub fn get_fgColor(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.fg_color;
}

/// Getter for linkColor
/// HTML §14.3.11 (obsolete) - Returns document's link color
pub fn get_linkColor(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.link_color;
}

/// Getter for vlinkColor
/// HTML §14.3.11 (obsolete) - Returns document's visited link color
pub fn get_vlinkColor(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.vlink_color;
}

/// Getter for alinkColor
/// HTML §14.3.11 (obsolete) - Returns document's active link color
pub fn get_alinkColor(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.alink_color;
}

/// Getter for bgColor
/// HTML §14.3.11 (obsolete) - Returns document's background color
pub fn get_bgColor(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.bg_color;
}

/// Getter for anchors
/// HTML (obsolete) - Returns an HTMLCollection of all a elements with name attribute
/// Spec: https://html.spec.whatwg.org/multipage/obsolete.html#dom-document-anchors
/// Note: Simplified - returns all 'a' elements (full spec requires name attribute)
pub fn get_anchors(instance: *runtime.Instance) ImplError!*runtime.Instance {
    return createCollectionByTagName(instance, "a");
}

/// Getter for applets
/// HTML (obsolete) - Returns an empty HTMLCollection (applet element is obsolete)
/// Spec: https://html.spec.whatwg.org/multipage/obsolete.html#dom-document-applets
pub fn get_applets(instance: *runtime.Instance) ImplError!*runtime.Instance {
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
pub fn get_all(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for scrollingElement
pub fn get_scrollingElement(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for permissionsPolicy
pub fn get_permissionsPolicy(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for fonts
pub fn get_fonts(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for customElementRegistry
pub fn get_customElementRegistry(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for fullscreenElement
/// Fullscreen API - Returns the current fullscreen element
/// Spec: https://fullscreen.spec.whatwg.org/#dom-document-fullscreenelement
pub fn get_fullscreenElement(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.fullscreen_element orelse error.NotImplemented; // null
}

/// Getter for pictureInPictureElement
pub fn get_pictureInPictureElement(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for pointerLockElement
/// Pointer Lock API - Returns the element that has pointer lock
/// Spec: https://w3c.github.io/pointerlock/#dom-documentorshadowroot-pointerlockelement
pub fn get_pointerLockElement(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.pointer_lock_element orelse error.NotImplemented; // null
}

/// Getter for styleSheets
pub fn get_styleSheets(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for adoptedStyleSheets
pub fn get_adoptedStyleSheets(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for activeElement
pub fn get_activeElement(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for children
/// ParentNode mixin - Returns an HTMLCollection of child elements
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-children
pub fn get_children(instance: *runtime.Instance) ImplError!*runtime.Instance {
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
pub fn get_firstElementChild(instance: *runtime.Instance) ImplError!*runtime.Instance {
    var child = NodeImpl.getFirstChild(instance);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            return c;
        }
        child = NodeImpl.getNextSibling(c);
    }
    // No element child found - return "null" via error (need nullable return)
    return error.NotImplemented;
}

/// Getter for lastElementChild
/// ParentNode mixin - Returns the last child that is an element
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-lastelementchild
pub fn get_lastElementChild(instance: *runtime.Instance) ImplError!*runtime.Instance {
    var last_element: ?*runtime.Instance = null;

    var child = NodeImpl.getFirstChild(instance);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            last_element = c;
        }
        child = NodeImpl.getNextSibling(c);
    }

    return last_element orelse error.NotImplemented;
}

/// Getter for childElementCount
/// ParentNode mixin - Returns the number of child elements
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-childelementcount
pub fn get_childElementCount(instance: *runtime.Instance) ImplError!u32 {
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

/// Getter for onabort
pub fn get_onabort(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onauxclick
pub fn get_onauxclick(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onbeforeinput
pub fn get_onbeforeinput(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onbeforematch
pub fn get_onbeforematch(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onbeforetoggle
pub fn get_onbeforetoggle(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onblur
pub fn get_onblur(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for oncancel
pub fn get_oncancel(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for oncanplay
pub fn get_oncanplay(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for oncanplaythrough
pub fn get_oncanplaythrough(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onchange
pub fn get_onchange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onclick
pub fn get_onclick(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onclose
pub fn get_onclose(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for oncommand
pub fn get_oncommand(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for oncontextlost
pub fn get_oncontextlost(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for oncontextmenu
pub fn get_oncontextmenu(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for oncontextrestored
pub fn get_oncontextrestored(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for oncopy
pub fn get_oncopy(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for oncuechange
pub fn get_oncuechange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for oncut
pub fn get_oncut(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ondblclick
pub fn get_ondblclick(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ondrag
pub fn get_ondrag(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ondragend
pub fn get_ondragend(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ondragenter
pub fn get_ondragenter(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ondragleave
pub fn get_ondragleave(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ondragover
pub fn get_ondragover(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ondragstart
pub fn get_ondragstart(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ondrop
pub fn get_ondrop(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ondurationchange
pub fn get_ondurationchange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onemptied
pub fn get_onemptied(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onended
pub fn get_onended(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onerror
pub fn get_onerror(instance: *runtime.Instance) ImplError!typedefs.OnErrorEventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onfocus
pub fn get_onfocus(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onformdata
pub fn get_onformdata(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for oninput
pub fn get_oninput(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for oninvalid
pub fn get_oninvalid(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onkeydown
pub fn get_onkeydown(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onkeypress
pub fn get_onkeypress(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onkeyup
pub fn get_onkeyup(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onload
pub fn get_onload(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onloadeddata
pub fn get_onloadeddata(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onloadedmetadata
pub fn get_onloadedmetadata(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onloadstart
pub fn get_onloadstart(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onmousedown
pub fn get_onmousedown(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onmouseenter
pub fn get_onmouseenter(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onmouseleave
pub fn get_onmouseleave(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onmousemove
pub fn get_onmousemove(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onmouseout
pub fn get_onmouseout(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onmouseover
pub fn get_onmouseover(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onmouseup
pub fn get_onmouseup(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onpaste
pub fn get_onpaste(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onpause
pub fn get_onpause(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onplay
pub fn get_onplay(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onplaying
pub fn get_onplaying(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onprogress
pub fn get_onprogress(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onratechange
pub fn get_onratechange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onreset
pub fn get_onreset(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onresize
pub fn get_onresize(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onscroll
pub fn get_onscroll(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onscrollend
pub fn get_onscrollend(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onsecuritypolicyviolation
pub fn get_onsecuritypolicyviolation(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onseeked
pub fn get_onseeked(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onseeking
pub fn get_onseeking(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onselect
pub fn get_onselect(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onslotchange
pub fn get_onslotchange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onstalled
pub fn get_onstalled(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onsubmit
pub fn get_onsubmit(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onsuspend
pub fn get_onsuspend(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ontimeupdate
pub fn get_ontimeupdate(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ontoggle
pub fn get_ontoggle(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onvolumechange
pub fn get_onvolumechange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onwaiting
pub fn get_onwaiting(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onwebkitanimationend
pub fn get_onwebkitanimationend(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onwebkitanimationiteration
pub fn get_onwebkitanimationiteration(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onwebkitanimationstart
pub fn get_onwebkitanimationstart(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onwebkittransitionend
pub fn get_onwebkittransitionend(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onwheel
pub fn get_onwheel(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onselectstart
pub fn get_onselectstart(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onselectionchange
pub fn get_onselectionchange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onanimationstart
pub fn get_onanimationstart(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onanimationiteration
pub fn get_onanimationiteration(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onanimationend
pub fn get_onanimationend(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onanimationcancel
pub fn get_onanimationcancel(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ontransitionrun
pub fn get_ontransitionrun(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ontransitionstart
pub fn get_ontransitionstart(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ontransitionend
pub fn get_ontransitionend(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ontransitioncancel
pub fn get_ontransitioncancel(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onbeforexrselect
pub fn get_onbeforexrselect(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onpointerover
pub fn get_onpointerover(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onpointerenter
pub fn get_onpointerenter(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onpointerdown
pub fn get_onpointerdown(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onpointermove
pub fn get_onpointermove(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onpointerrawupdate
pub fn get_onpointerrawupdate(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onpointerup
pub fn get_onpointerup(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onpointercancel
pub fn get_onpointercancel(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onpointerout
pub fn get_onpointerout(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onpointerleave
pub fn get_onpointerleave(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ongotpointercapture
pub fn get_ongotpointercapture(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onlostpointercapture
pub fn get_onlostpointercapture(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ontouchstart
pub fn get_ontouchstart(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ontouchend
pub fn get_ontouchend(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ontouchmove
pub fn get_ontouchmove(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ontouchcancel
pub fn get_ontouchcancel(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onfencedtreeclick
pub fn get_onfencedtreeclick(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onsnapchanged
pub fn get_onsnapchanged(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onsnapchanging
pub fn get_onsnapchanging(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for onprerenderingchange
pub fn set_onprerenderingchange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onfullscreenchange
pub fn set_onfullscreenchange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onfullscreenerror
pub fn set_onfullscreenerror(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onpointerlockchange
pub fn set_onpointerlockchange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onpointerlockerror
pub fn set_onpointerlockerror(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onfreeze
pub fn set_onfreeze(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onresume
pub fn set_onresume(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for domain
/// HTML §7.5.2 - Sets the document's domain (for same-origin policy relaxation)
/// Spec: https://html.spec.whatwg.org/multipage/browsers.html#dom-document-domain
/// Note: This is deprecated and has security implications
pub fn set_domain(instance: *runtime.Instance, value: runtime.USVString) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Free old domain if it was allocated
    if (internal.domain.len > 0) {
        internal.allocator.free(internal.domain);
    }

    // Clone the new domain value
    internal.domain = internal.allocator.dupe(u8, value) catch return error.OutOfMemory;
}

/// Setter for cookie
pub fn set_cookie(instance: *runtime.Instance, value: runtime.USVString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for title
/// HTML §3.1.3 - Sets the document's title
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#document.title
pub fn set_title(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.title.deinit(internal.allocator);
    internal.title = value.clone(internal.allocator) catch return error.OutOfMemory;
    // TODO: Update the <title> element in the DOM if it exists
}

/// Setter for dir
/// HTML §3.2.6 - Sets the document's text direction ("ltr", "rtl", or "")
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-dir
pub fn set_dir(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.dir.deinit(internal.allocator);
    internal.dir = value.clone(internal.allocator) catch return error.OutOfMemory;
    // TODO: Update the dir attribute on the html element if it exists
}

/// Setter for body
pub fn set_body(instance: *runtime.Instance, value: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for designMode
/// HTML §6.5.1 - Sets design mode ("on" or "off")
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-document-designmode
pub fn set_designMode(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
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
pub fn set_onreadystatechange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onvisibilitychange
pub fn set_onvisibilitychange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for fgColor
/// HTML §14.3.11 (obsolete) - Sets document's text color
pub fn set_fgColor(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.fg_color.deinit(internal.allocator);
    internal.fg_color = value.clone(internal.allocator) catch return error.OutOfMemory;
}

/// Setter for linkColor
/// HTML §14.3.11 (obsolete) - Sets document's link color
pub fn set_linkColor(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.link_color.deinit(internal.allocator);
    internal.link_color = value.clone(internal.allocator) catch return error.OutOfMemory;
}

/// Setter for vlinkColor
/// HTML §14.3.11 (obsolete) - Sets document's visited link color
pub fn set_vlinkColor(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.vlink_color.deinit(internal.allocator);
    internal.vlink_color = value.clone(internal.allocator) catch return error.OutOfMemory;
}

/// Setter for alinkColor
/// HTML §14.3.11 (obsolete) - Sets document's active link color
pub fn set_alinkColor(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.alink_color.deinit(internal.allocator);
    internal.alink_color = value.clone(internal.allocator) catch return error.OutOfMemory;
}

/// Setter for bgColor
/// HTML §14.3.11 (obsolete) - Sets document's background color
pub fn set_bgColor(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.bg_color.deinit(internal.allocator);
    internal.bg_color = value.clone(internal.allocator) catch return error.OutOfMemory;
}

/// Setter for adoptedStyleSheets
pub fn set_adoptedStyleSheets(instance: *runtime.Instance, value: *const anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onabort
pub fn set_onabort(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onauxclick
pub fn set_onauxclick(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onbeforeinput
pub fn set_onbeforeinput(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onbeforematch
pub fn set_onbeforematch(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onbeforetoggle
pub fn set_onbeforetoggle(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onblur
pub fn set_onblur(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for oncancel
pub fn set_oncancel(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for oncanplay
pub fn set_oncanplay(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for oncanplaythrough
pub fn set_oncanplaythrough(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onchange
pub fn set_onchange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onclick
pub fn set_onclick(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onclose
pub fn set_onclose(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for oncommand
pub fn set_oncommand(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for oncontextlost
pub fn set_oncontextlost(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for oncontextmenu
pub fn set_oncontextmenu(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for oncontextrestored
pub fn set_oncontextrestored(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for oncopy
pub fn set_oncopy(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for oncuechange
pub fn set_oncuechange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for oncut
pub fn set_oncut(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ondblclick
pub fn set_ondblclick(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ondrag
pub fn set_ondrag(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ondragend
pub fn set_ondragend(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ondragenter
pub fn set_ondragenter(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ondragleave
pub fn set_ondragleave(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ondragover
pub fn set_ondragover(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ondragstart
pub fn set_ondragstart(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ondrop
pub fn set_ondrop(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ondurationchange
pub fn set_ondurationchange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onemptied
pub fn set_onemptied(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onended
pub fn set_onended(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onerror
pub fn set_onerror(instance: *runtime.Instance, value: typedefs.OnErrorEventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onfocus
pub fn set_onfocus(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onformdata
pub fn set_onformdata(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for oninput
pub fn set_oninput(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for oninvalid
pub fn set_oninvalid(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onkeydown
pub fn set_onkeydown(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onkeypress
pub fn set_onkeypress(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onkeyup
pub fn set_onkeyup(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onload
pub fn set_onload(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onloadeddata
pub fn set_onloadeddata(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onloadedmetadata
pub fn set_onloadedmetadata(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onloadstart
pub fn set_onloadstart(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onmousedown
pub fn set_onmousedown(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onmouseenter
pub fn set_onmouseenter(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onmouseleave
pub fn set_onmouseleave(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onmousemove
pub fn set_onmousemove(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onmouseout
pub fn set_onmouseout(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onmouseover
pub fn set_onmouseover(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onmouseup
pub fn set_onmouseup(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onpaste
pub fn set_onpaste(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onpause
pub fn set_onpause(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onplay
pub fn set_onplay(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onplaying
pub fn set_onplaying(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onprogress
pub fn set_onprogress(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onratechange
pub fn set_onratechange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onreset
pub fn set_onreset(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onresize
pub fn set_onresize(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onscroll
pub fn set_onscroll(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onscrollend
pub fn set_onscrollend(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onsecuritypolicyviolation
pub fn set_onsecuritypolicyviolation(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onseeked
pub fn set_onseeked(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onseeking
pub fn set_onseeking(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onselect
pub fn set_onselect(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onslotchange
pub fn set_onslotchange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onstalled
pub fn set_onstalled(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onsubmit
pub fn set_onsubmit(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onsuspend
pub fn set_onsuspend(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ontimeupdate
pub fn set_ontimeupdate(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ontoggle
pub fn set_ontoggle(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onvolumechange
pub fn set_onvolumechange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onwaiting
pub fn set_onwaiting(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onwebkitanimationend
pub fn set_onwebkitanimationend(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onwebkitanimationiteration
pub fn set_onwebkitanimationiteration(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onwebkitanimationstart
pub fn set_onwebkitanimationstart(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onwebkittransitionend
pub fn set_onwebkittransitionend(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onwheel
pub fn set_onwheel(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onselectstart
pub fn set_onselectstart(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onselectionchange
pub fn set_onselectionchange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onanimationstart
pub fn set_onanimationstart(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onanimationiteration
pub fn set_onanimationiteration(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onanimationend
pub fn set_onanimationend(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onanimationcancel
pub fn set_onanimationcancel(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ontransitionrun
pub fn set_ontransitionrun(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ontransitionstart
pub fn set_ontransitionstart(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ontransitionend
pub fn set_ontransitionend(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ontransitioncancel
pub fn set_ontransitioncancel(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onbeforexrselect
pub fn set_onbeforexrselect(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onpointerover
pub fn set_onpointerover(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onpointerenter
pub fn set_onpointerenter(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onpointerdown
pub fn set_onpointerdown(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onpointermove
pub fn set_onpointermove(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onpointerrawupdate
pub fn set_onpointerrawupdate(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onpointerup
pub fn set_onpointerup(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onpointercancel
pub fn set_onpointercancel(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onpointerout
pub fn set_onpointerout(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onpointerleave
pub fn set_onpointerleave(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ongotpointercapture
pub fn set_ongotpointercapture(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onlostpointercapture
pub fn set_onlostpointercapture(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ontouchstart
pub fn set_ontouchstart(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ontouchend
pub fn set_ontouchend(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ontouchmove
pub fn set_ontouchmove(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ontouchcancel
pub fn set_ontouchcancel(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onfencedtreeclick
pub fn set_onfencedtreeclick(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onsnapchanged
pub fn set_onsnapchanged(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onsnapchanging
pub fn set_onsnapchanging(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: exitPointerLock
pub fn call_exitPointerLock(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: queryCommandState
pub fn call_queryCommandState(instance: *runtime.Instance, commandId: runtime.DOMString) ImplError!bool {
    _ = instance;
    _ = commandId;
    return error.NotImplemented;
}

/// Operation: parseHTMLUnsafe
pub fn call_parseHTMLUnsafe(instance: *runtime.Instance, html: *const anyopaque) ImplError!*runtime.Instance {
    _ = instance;
    _ = html;
    return error.NotImplemented;
}

/// Operation: exitPictureInPicture
pub fn call_exitPictureInPicture(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: createExpression
pub fn call_createExpression(instance: *runtime.Instance, expression: runtime.DOMString, resolver: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    _ = expression;
    _ = resolver;
    return error.NotImplemented;
}

/// Operation: elementFromPoint
pub fn call_elementFromPoint(instance: *runtime.Instance, x: f64, y: f64) ImplError!*runtime.Instance {
    _ = instance;
    _ = x;
    _ = y;
    return error.NotImplemented;
}

/// Operation: createElement
/// DOM §4.6 - Creates an element with the given local name
/// Spec: https://dom.spec.whatwg.org/#dom-document-createelement
pub fn call_createElement(instance: *runtime.Instance, localName: runtime.DOMString, options: *const anyopaque) ImplError!*runtime.Instance {
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
pub fn call_releaseEvents(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: prepend
pub fn call_prepend(instance: *runtime.Instance, nodes: *const anyopaque) ImplError!void {
    _ = instance;
    _ = nodes;
    return error.NotImplemented;
}

/// Operation: convertQuadFromNode
pub fn call_convertQuadFromNode(instance: *runtime.Instance, quad: dictionaries.DOMQuadInit, from: typedefs.GeometryNode, options: dictionaries.ConvertCoordinateOptions) ImplError!*runtime.Instance {
    _ = instance;
    _ = quad;
    _ = from;
    _ = options;
    return error.NotImplemented;
}

/// Operation: queryCommandSupported
pub fn call_queryCommandSupported(instance: *runtime.Instance, commandId: runtime.DOMString) ImplError!bool {
    _ = instance;
    _ = commandId;
    return error.NotImplemented;
}

/// Operation: hasPrivateToken
pub fn call_hasPrivateToken(instance: *runtime.Instance, issuer: runtime.USVString) ImplError!*const anyopaque {
    _ = instance;
    _ = issuer;
    return error.NotImplemented;
}

/// Operation: requestStorageAccessFor
pub fn call_requestStorageAccessFor(instance: *runtime.Instance, requestedOrigin: runtime.USVString) ImplError!*const anyopaque {
    _ = instance;
    _ = requestedOrigin;
    return error.NotImplemented;
}

/// Operation: open
pub fn call_open(instance: *runtime.Instance, unused1: runtime.DOMString, unused2: runtime.DOMString) ImplError!*runtime.Instance {
    _ = instance;
    _ = unused1;
    _ = unused2;
    return error.NotImplemented;
}

/// Operation: hasUnpartitionedCookieAccess
pub fn call_hasUnpartitionedCookieAccess(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: hasRedemptionRecord
pub fn call_hasRedemptionRecord(instance: *runtime.Instance, issuer: runtime.USVString) ImplError!*const anyopaque {
    _ = instance;
    _ = issuer;
    return error.NotImplemented;
}

/// Operation: execCommand
pub fn call_execCommand(instance: *runtime.Instance, commandId: runtime.DOMString, showUI: bool, value: runtime.DOMString) ImplError!bool {
    _ = instance;
    _ = commandId;
    _ = showUI;
    _ = value;
    return error.NotImplemented;
}

/// Operation: measureElement
pub fn call_measureElement(instance: *runtime.Instance, element: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    _ = element;
    return error.NotImplemented;
}

/// Operation: write
pub fn call_write(instance: *runtime.Instance, text: *const anyopaque) ImplError!void {
    _ = instance;
    _ = text;
    return error.NotImplemented;
}

/// Operation: createAttribute
/// DOM §4.6 - Creates an Attr node with the given local name
/// Spec: https://dom.spec.whatwg.org/#dom-document-createattribute
///
/// Steps:
/// 1. If localName does not match the Name production, throw InvalidCharacterError
/// 2. If this is an HTML document, set localName to ASCII lowercase
/// 3. Return a new Attr with localName as local name
pub fn call_createAttribute(instance: *runtime.Instance, localName: runtime.DOMString) ImplError!*runtime.Instance {
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
pub fn call_clear(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: queryCommandIndeterm
pub fn call_queryCommandIndeterm(instance: *runtime.Instance, commandId: runtime.DOMString) ImplError!bool {
    _ = instance;
    _ = commandId;
    return error.NotImplemented;
}

/// Operation: getElementsByTagNameNS
pub fn call_getElementsByTagNameNS(instance: *runtime.Instance, namespace: runtime.DOMString, localName: runtime.DOMString) ImplError!*runtime.Instance {
    _ = instance;
    _ = namespace;
    _ = localName;
    return error.NotImplemented;
}

/// Operation: elementsFromPoint
pub fn call_elementsFromPoint(instance: *runtime.Instance, x: f64, y: f64) ImplError!*const anyopaque {
    _ = instance;
    _ = x;
    _ = y;
    return error.NotImplemented;
}

/// Operation: createProcessingInstruction
/// DOM §4.6 - Creates a ProcessingInstruction node
/// Spec: https://dom.spec.whatwg.org/#dom-document-createprocessinginstruction
pub fn call_createProcessingInstruction(instance: *runtime.Instance, target: runtime.DOMString, data: runtime.DOMString) ImplError!*runtime.Instance {
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
pub fn call_createEvent(instance: *runtime.Instance, interface: runtime.DOMString) ImplError!*runtime.Instance {
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
    const event = try EventImpl.call_constructor(internal.allocator, instance.ctx, runtime.DOMString.initEmpty(), event_init);

    return event;
}

/// Operation: replaceChildren
pub fn call_replaceChildren(instance: *runtime.Instance, nodes: *const anyopaque) ImplError!void {
    _ = instance;
    _ = nodes;
    return error.NotImplemented;
}

/// Operation: getBoxQuads
pub fn call_getBoxQuads(instance: *runtime.Instance, options: dictionaries.BoxQuadOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: convertPointFromNode
pub fn call_convertPointFromNode(instance: *runtime.Instance, point: dictionaries.DOMPointInit, from: typedefs.GeometryNode, options: dictionaries.ConvertCoordinateOptions) ImplError!*runtime.Instance {
    _ = instance;
    _ = point;
    _ = from;
    _ = options;
    return error.NotImplemented;
}

/// Operation: getAnimations
pub fn call_getAnimations(instance: *runtime.Instance) ImplError!*const anyopaque {
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
pub fn call_getElementsByClassName(instance: *runtime.Instance, classNames: runtime.DOMString) ImplError!*runtime.Instance {
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
pub fn call_getElementsByTagName(instance: *runtime.Instance, qualifiedName: runtime.DOMString) ImplError!*runtime.Instance {
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
pub fn call_evaluate(instance: *runtime.Instance, expression: runtime.DOMString, contextNode: *runtime.Instance, resolver: *runtime.Instance, @"type": u16, result: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    _ = expression;
    _ = contextNode;
    _ = resolver;
    _ = @"type";
    _ = result;
    return error.NotImplemented;
}

/// Operation: querySelector
pub fn call_querySelector(instance: *runtime.Instance, selectors: runtime.DOMString) ImplError!*runtime.Instance {
    _ = instance;
    _ = selectors;
    return error.NotImplemented;
}

/// Operation: hasStorageAccess
pub fn call_hasStorageAccess(instance: *runtime.Instance) ImplError!*const anyopaque {
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
pub fn call_importNode(instance: *runtime.Instance, node: *runtime.Instance, options: *const anyopaque) ImplError!*runtime.Instance {
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
            const text = try TextImpl.call_constructor(internal.allocator, doc.ctx, runtime.DOMString.initInterned(src_data));
            break :blk text;
        },
        NodeImpl.NodeType.COMMENT_NODE => blk: {
            // Clone comment data
            const CharacterDataImpl = @import("CharacterData.zig");
            const src_data = CharacterDataImpl.getData(node) orelse "";
            const comment = try CommentImpl.call_constructor(internal.allocator, doc.ctx, runtime.DOMString.initInterned(src_data));
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
pub fn call_createCDATASection(instance: *runtime.Instance, data: runtime.DOMString) ImplError!*runtime.Instance {
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
pub fn call_queryCommandEnabled(instance: *runtime.Instance, commandId: runtime.DOMString) ImplError!bool {
    _ = instance;
    _ = commandId;
    return error.NotImplemented;
}

/// Operation: createRange
pub fn call_createRange(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getElementById
/// DOM §4.3.1 (NonElementParentNode) - Returns the first element with matching ID
/// Spec: https://dom.spec.whatwg.org/#dom-nonelementparentnode-getelementbyid
///
/// Steps:
/// 1. Return the first element, in tree order, within this's descendants,
///    that has an ID equal to elementId; otherwise null
pub fn call_getElementById(instance: *runtime.Instance, elementId: runtime.DOMString) ImplError!*runtime.Instance {
    const element_id = elementId.asSlice();

    // Empty ID never matches
    if (element_id.len == 0) {
        return error.NotImplemented; // null
    }

    // Traverse tree in tree order (preorder depth-first)
    return findElementById(instance, element_id) orelse error.NotImplemented;
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
pub fn call_createAttributeNS(instance: *runtime.Instance, namespace: runtime.DOMString, qualifiedName: runtime.DOMString) ImplError!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const ns_slice = namespace.asSlice();
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
pub fn call_hasFocus(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: exitFullscreen
pub fn call_exitFullscreen(instance: *runtime.Instance) ImplError!*const anyopaque {
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
pub fn call_adoptNode(instance: *runtime.Instance, node: *runtime.Instance) ImplError!*runtime.Instance {
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
pub fn call_createTextNode(instance: *runtime.Instance, data: runtime.DOMString) ImplError!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Create Text node via Text impl constructor
    const text = try TextImpl.call_constructor(internal.allocator, instance.ctx, data);
    errdefer TextImpl.deinit(text);

    // Set owner document
    try NodeImpl.setOwnerDocument(text, instance);

    return text;
}

/// Operation: createTreeWalker
pub fn call_createTreeWalker(instance: *runtime.Instance, root: *runtime.Instance, whatToShow: u32, filter: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    _ = root;
    _ = whatToShow;
    _ = filter;
    return error.NotImplemented;
}

/// Operation: getElementsByName
pub fn call_getElementsByName(instance: *runtime.Instance, elementName: runtime.DOMString) ImplError!*runtime.Instance {
    _ = instance;
    _ = elementName;
    return error.NotImplemented;
}

/// Operation: writeln
pub fn call_writeln(instance: *runtime.Instance, text: *const anyopaque) ImplError!void {
    _ = instance;
    _ = text;
    return error.NotImplemented;
}

/// Operation: append
pub fn call_append(instance: *runtime.Instance, nodes: *const anyopaque) ImplError!void {
    _ = instance;
    _ = nodes;
    return error.NotImplemented;
}

/// Operation: moveBefore
pub fn call_moveBefore(instance: *runtime.Instance, node: *runtime.Instance, child: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = node;
    _ = child;
    return error.NotImplemented;
}

/// Operation: convertRectFromNode
pub fn call_convertRectFromNode(instance: *runtime.Instance, rect: *runtime.Instance, from: typedefs.GeometryNode, options: dictionaries.ConvertCoordinateOptions) ImplError!*runtime.Instance {
    _ = instance;
    _ = rect;
    _ = from;
    _ = options;
    return error.NotImplemented;
}

/// Operation: queryCommandValue
pub fn call_queryCommandValue(instance: *runtime.Instance, commandId: runtime.DOMString) ImplError!runtime.DOMString {
    _ = instance;
    _ = commandId;
    return error.NotImplemented;
}

/// Operation: caretPositionFromPoint
pub fn call_caretPositionFromPoint(instance: *runtime.Instance, x: f64, y: f64, options: dictionaries.CaretPositionFromPointOptions) ImplError!*runtime.Instance {
    _ = instance;
    _ = x;
    _ = y;
    _ = options;
    return error.NotImplemented;
}

/// Operation: startViewTransition
pub fn call_startViewTransition(instance: *runtime.Instance, callbackOptions: *const anyopaque) ImplError!*runtime.Instance {
    _ = instance;
    _ = callbackOptions;
    return error.NotImplemented;
}

/// Operation: createComment
/// DOM §4.6 - Creates a Comment node with the given data
/// Spec: https://dom.spec.whatwg.org/#dom-document-createcomment
pub fn call_createComment(instance: *runtime.Instance, data: runtime.DOMString) ImplError!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Create Comment node via Comment impl constructor
    const comment = try CommentImpl.call_constructor(internal.allocator, instance.ctx, data);
    errdefer CommentImpl.deinit(comment);

    // Set owner document
    try NodeImpl.setOwnerDocument(comment, instance);

    return comment;
}

/// Operation: createDocumentFragment
/// DOM §4.6 - Creates a DocumentFragment node
/// Spec: https://dom.spec.whatwg.org/#dom-document-createdocumentfragment
pub fn call_createDocumentFragment(instance: *runtime.Instance) ImplError!*runtime.Instance {
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
pub fn call_getSelection(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: close
pub fn call_close(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: requestStorageAccess
pub fn call_requestStorageAccess(instance: *runtime.Instance) ImplError!*const anyopaque {
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
pub fn call_createElementNS(instance: *runtime.Instance, namespace: runtime.DOMString, qualifiedName: runtime.DOMString, options: *const anyopaque) ImplError!*runtime.Instance {
    _ = options; // TODO: Handle ElementCreationOptions (custom elements)
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    const ns_slice = namespace.asSlice();
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
pub fn call_captureEvents(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: querySelectorAll
pub fn call_querySelectorAll(instance: *runtime.Instance, selectors: runtime.DOMString) ImplError!*runtime.Instance {
    _ = instance;
    _ = selectors;
    return error.NotImplemented;
}

/// Operation: browsingTopics
pub fn call_browsingTopics(instance: *runtime.Instance, options: dictionaries.BrowsingTopicsOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: createNSResolver
pub fn call_createNSResolver(instance: *runtime.Instance, nodeResolver: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    _ = nodeResolver;
    return error.NotImplemented;
}

/// Operation: createNodeIterator
pub fn call_createNodeIterator(instance: *runtime.Instance, root: *runtime.Instance, whatToShow: u32, filter: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    _ = root;
    _ = whatToShow;
    _ = filter;
    return error.NotImplemented;
}

/// Operation: measureText
pub fn call_measureText(instance: *runtime.Instance, text: runtime.DOMString, styleMap: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    _ = text;
    _ = styleMap;
    return error.NotImplemented;
}
