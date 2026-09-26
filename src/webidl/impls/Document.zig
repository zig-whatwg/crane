//! Implementation for Document interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-document
//! WHATWG DOM Standard §4.6
//!
//! Document represents the entire HTML or XML document. Conceptually, it is
//! the root of the tree, and provides the primary access to the
//! document's data.
//!
//! Migrated from: webidl/src/dom/Document.zig
//!
//! ## Architecture Note (Golden Rule #13)
//!
//! Per Golden Rule #13, impls should call interfaces, not other impls.
//! This file uses interfaces for factory method calls (call_constructor, etc.)
//! but may use impls for internal initialization (setNodeType, etc.).

const std = @import("std");
const log = std.log.scoped(.document_impl);
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const Document = interfaces.Document;

// Use shared InstanceRegistry utility for internal state management
const utils = webidl.utils;
const Registry = utils.InstanceRegistry(InternalState);

// Import impls ONLY for internal initialization methods not exposed via interfaces
const NodeImpl = @import("Node.zig");
const EventImpl = @import("Event.zig");
const ProcessingInstructionImpl = @import("ProcessingInstruction.zig");
const RangeImpl = @import("Range.zig");
const SelectionImpl = @import("Selection.zig");

// Import ParentNode mixin for shared ParentNode interface methods
const mixins = @import("mixins");

// Content Security Policy
const csp = @import("csp");

// HTML module for stylesheet blocking and editing
const html_core = @import("html_core");
const range_boundaries = @import("dom").range_boundaries;
const names = @import("dom").names;
const attr_nodes = @import("dom").attr_nodes;
const traversal = @import("dom").traversal;
const StylesheetBlockingTracker = html_core.StylesheetBlockingTracker;
const editing = html_core.editing;

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
    /// HTML "page showing": set when pageshow fires at the end of loading.
    page_showing: bool = false,
    /// HTML "completely loaded": "completely finish loading" has run.
    completely_loaded: bool = false,
    /// HTML "is initial about:blank": the document "create a new browsing
    /// context and document" made, until something replaces it.
    is_initial_about_blank: bool = false,
    /// HTML "salvageable"; set false by "unload" (Crane keeps no bfcache).
    salvageable: bool = true,
    /// "The end" is waiting at step 8 - something delays the load event -
    /// and has not queued step 9's task yet.
    load_waiting_on_delay: bool = false,

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

    // === Cookie storage (simplified in-memory storage for WPT tests) ===
    /// Simple cookie jar storing name -> value mappings
    /// In a real browser, this would be backed by a proper cookie store
    cookies: std.StringHashMap([]const u8),

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

    /// Throw-on-dynamic-markup-insertion counter
    /// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#throw-on-dynamic-markup-insertion-counter
    /// When > 0, document.open/write/close throw InvalidStateError
    throw_on_dynamic_markup_insertion_counter: u32,

    /// The unload counter
    /// Spec: https://html.spec.whatwg.org/multipage/browsing-the-web.html#unload-counter
    /// When > 0 (during beforeunload/unload), destructive writes are ignored
    unload_counter: u32,

    /// Parser insertion point
    /// Spec: https://html.spec.whatwg.org/multipage/parsing.html#insertion-point
    /// When non-null, indicates parsing is active and points to position in input stream.
    /// When null, parsing has finished or not started.
    insertion_point: ?usize,

    /// Whether this document's parser is script-created
    /// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#script-created-parser
    /// Set to true when document.open() creates a new parser
    is_script_created_parser: bool,

    /// Whether the active parser was aborted (e.g., by navigation)
    active_parser_was_aborted: bool,

    /// Buffered content from document.write() in after-parsing mode
    /// When insertion_point is null and document.write() is called, content
    /// is accumulated here until document.close() is called
    write_buffer: std.ArrayList(u8),

    /// The InputStreamManager for document.write() during parsing
    /// This is set when parsing starts and cleared when parsing finishes
    input_stream_manager: ?*html_core.parser.document_write.InputStreamManager,

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

    /// Optional module dispose function - set when engine is configured
    /// Used to dispose V8/JSC module handles without compile-time dependency
    dispose_module_fn: ?*const fn (*anyopaque) void,

    // === Stylesheet Blocking (HTML Standard §14.3.3) ===

    /// Stylesheet blocking tracker
    /// Spec: https://html.spec.whatwg.org/multipage/semantics.html#has-a-style-sheet-that-is-blocking-scripts
    /// Tracks pending stylesheets to block script execution until CSS loads.
    stylesheet_tracker: StylesheetBlockingTracker,

    // === Selection API (Selection API spec) ===

    /// The document's selection object (lazily created, [SameObject])
    /// Spec: https://w3c.github.io/selection-api/#dom-document-getselection
    selection: ?*runtime.Instance,

    // === Adopted Style Sheets (CSSOM) ===

    /// Adopted style sheets (ObservableArray exotic object)
    /// Spec: https://drafts.csswg.org/cssom/#dom-documentorshadowroot-adoptedstylesheets
    /// Stored as V8 handle pointer (Proxy object), not a runtime.Instance
    adopted_style_sheets: ?*anyopaque,

    /// Cached FontFaceSet instance ([SameObject])
    /// Spec: https://drafts.csswg.org/css-font-loading/#dom-fontfacesource-fonts
    fonts: ?*runtime.Instance,

    /// Cached HTMLAllCollection instance ([SameObject])
    /// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-all
    /// This collection has [[IsHTMLDDA]] internal slot (undetectable)
    all_collection: ?*runtime.Instance,

    /// The default view (window) associated with this document.
    /// This is the Window whose document is this Document.
    /// Set via setDefaultView() when the document is associated with a window.
    /// Spec: https://html.spec.whatwg.org/multipage/window-object.html#dom-document-defaultview
    default_view: ?*runtime.Instance = null,

    /// V8 wrapper for this Document, created in the Document's owning context.
    /// Used for cross-context access (e.g., iframe.contentDocument from parent).
    /// When a Document is accessed from a different context than where it was created,
    /// we return this pre-created wrapper instead of creating a new one in the
    /// accessing context, which avoids callback corruption issues.
    bound_v8_wrapper: ?*anyopaque = null,

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
            .ranges = .empty,
            .node_iterators = .empty,
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
            // Per Fullscreen spec, fullscreenEnabled returns true only if fullscreen is supported
            // and the document's fullscreen flag is set. For a new Document, default to false.
            .fullscreen_enabled = false,
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
            // Cookie storage
            .cookies = std.StringHashMap([]const u8).init(allocator),
            // Script execution state
            .pending_parsing_blocking_script = null,
            .scripts_to_execute_asap = .empty,
            .scripts_to_execute_in_order_asap = .empty,
            .scripts_to_execute_when_parsing_finished = .empty,
            .current_script = null,
            .ignore_destructive_writes_counter = 0,
            .throw_on_dynamic_markup_insertion_counter = 0,
            .unload_counter = 0,
            .insertion_point = null,
            .is_script_created_parser = false,
            .active_parser_was_aborted = false,
            .write_buffer = .empty,
            .input_stream_manager = null,
            .scripting_enabled = true, // Default to true for browser environments
            // Module map and import map
            .module_map = std.StringHashMap(*anyopaque).init(allocator),
            .import_map_imports = std.StringHashMap([]const u8).init(allocator),
            .import_map_scopes = std.StringHashMap(std.StringHashMap([]const u8)).init(allocator),
            .import_map_acquired = false,
            // Module disposal (set when engine is configured)
            .dispose_module_fn = null,
            // CSP
            .csp_list = null,
            .csp_self_origin = null,
            // Speculation rules
            .prefetch_hints = std.StringHashMap(SpeculationEagerness).init(allocator),
            // Stylesheet blocking tracker
            .stylesheet_tracker = StylesheetBlockingTracker.init(allocator),
            // Selection
            .selection = null,
            // Adopted style sheets (ObservableArray exotic object)
            .adopted_style_sheets = null,
            // FontFaceSet (CSS Font Loading)
            .fonts = null,
            // HTMLAllCollection (undetectable legacy object)
            .all_collection = null,
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

        // Cookies - free values
        {
            var cookie_it = self.cookies.iterator();
            while (cookie_it.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                self.allocator.free(entry.value_ptr.*);
            }
            self.cookies.deinit();
        }

        // Write buffer (for document.write() in after-parsing mode)
        self.write_buffer.deinit(self.allocator);

        // Note: input_stream_manager is NOT owned by Document - it's owned by HTMLParser
        // and is just a reference here for document.write() integration

        // Script execution lists (don't own the script elements, just the list storage)
        self.scripts_to_execute_asap.deinit(self.allocator);
        self.scripts_to_execute_in_order_asap.deinit(self.allocator);
        self.scripts_to_execute_when_parsing_finished.deinit(self.allocator);

        // Module map - dispose module handles and free keys
        {
            var mod_it = self.module_map.iterator();
            while (mod_it.next()) |entry| {
                // Dispose module handle using stored function pointer
                // (null if no JS engine configured, e.g., in stub test mode)
                if (self.dispose_module_fn) |dispose_fn| {
                    dispose_fn(entry.value_ptr.*);
                }
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

        // Stylesheet blocking tracker
        self.stylesheet_tracker.deinit();

        // Clean up cached [SameObject] instances
        // These instances are lazily created and cached, so we need to clean them up here.
        // The GC may not have cleaned them up yet if the context is being torn down.
        if (self.all_collection) |all| {
            interfaces.HTMLAllCollection.deinit(all);
        }
        if (self.fonts) |fonts_inst| {
            interfaces.FontFaceSet.deinit(fonts_inst);
        }
        if (self.selection) |sel| {
            interfaces.Selection.deinit(sel);
        }
        if (self.style_sheets) |ss| {
            interfaces.StyleSheetList.deinit(ss);
        }
    }
};

/// Get the internal state from an instance
/// Made public for use by HTMLParser, DOMParser, and other modules that need
/// access to document internals for DOM construction.
pub fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
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
    // The registry owns this block, so `Registry.remove` returns it to the
    // arena. With `set` it was dropped from the map and held to process
    // exit - 904 bytes per discarded element, measured.
    const internal = try Registry.createIn(instance, ArenaAllocator.get());
    internal.* = InternalState.init(allocator);

    @import("dom").document_lifecycle.install(.{
        .parsing_stopped = &lifecycleParsingStopped,
        .finish_loading = &lifecycleFinishLoading,
        .load_delay_may_have_ended = &lifecycleLoadDelayMayHaveEnded,
        .is_completely_loaded = &lifecycleIsCompletelyLoaded,
        .is_initial_about_blank = &lifecycleIsInitialAboutBlank,
        .mark_initial_about_blank = &lifecycleMarkInitialAboutBlank,
        .is_unloading = &lifecycleIsUnloading,
        .fire_beforeunload = &lifecycleFireBeforeUnload,
        .unload = &lifecycleUnload,
    });

    return instance;
}

/// Get Document's internal state from the registry
/// Alias for getInternal for backward compatibility
pub fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

/// Set the V8 wrapper for this Document (created in the Document's owning context).
/// This should be called immediately after creating the Document, before returning
/// it to any other context. The wrapper ensures cross-context access works correctly.
pub fn setBoundV8Wrapper(instance: *runtime.Instance, v8_wrapper: *anyopaque) void {
    if (getInternalState(instance)) |internal| {
        internal.bound_v8_wrapper = v8_wrapper;
    }
}

/// Get the V8 wrapper for this Document if one was pre-created.
/// Returns null if no wrapper was set (Document will be wrapped on demand).
pub fn getBoundV8Wrapper(instance: *runtime.Instance) ?*anyopaque {
    const internal = getInternalState(instance) orelse return null;
    return internal.bound_v8_wrapper;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Clean up internal state from registry
    if (Registry.get(instance)) |internal| {
        internal.deinit();
    }
    Registry.remove(instance);
    // Node cleanup happens via inheritance chain
    NodeImpl.deinit(instance);
}

/// Constructor implementation
/// DOM §4.6 - new Document()
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &Document.vtable, ctx);
    errdefer deinit(instance);

    // Set default values
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.content_type = try runtime.DOMString.initDupe(ctx.allocator, "application/xml");
    internal.url = try ctx.allocator.dupe(u8, "about:blank");
    internal.encoding = try runtime.DOMString.initDupe(ctx.allocator, "UTF-8");

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
    // Use interface instead of impl (per Golden Rule #13)
    const DOMImplementationImpl = @import("DOMImplementation.zig");
    const impl = interfaces.DOMImplementation.init(internal.allocator, instance.ctx) catch return error.OutOfMemory;

    // Set the associated document (internal method)
    DOMImplementationImpl.setDocument(impl, instance);

    // Cache and return
    internal.implementation = impl;
    return impl;
}

/// Getter for URL
/// DOM §4.6 - Returns document's URL
pub fn get_URL(instance: *runtime.Instance) anyerror!runtime.USVString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.url.len == 0 and internal.default_view != null) {
        // HTML "create and initialize a Document object": the document's URL
        // is the navigation's URL. The context records that URL when the
        // navigation commits (context_manager.setDocumentUrl) and the parser
        // never copies it here, so a navigated document read as "". Only a
        // window's document is navigated: one made by createHTMLDocument or
        // DOMParser has no default view and keeps its own URL. Read live, not
        // cached: an iframe's context records a new URL on every navigation.
        if (navigatedUrl(instance)) |url| {
            return try instance.ctx.allocator.dupe(u8, url);
        }
    }
    // DOM: a document's URL is "about:blank" unless stated otherwise - the
    // URL of every document createHTMLDocument, createDocument and
    // `new Document()` make. It read "" before, and so did their baseURI.
    if (internal.url.len == 0) return try instance.ctx.allocator.dupe(u8, "about:blank");
    // Clone to transfer ownership to caller (interface layer will free)
    return try instance.ctx.allocator.dupe(u8, internal.url);
}

/// The URL the context navigated to, if it has one. The instance's own
/// context, not the current one: a parent reading `iframe.contentDocument.URL`
/// must get the iframe's URL.
fn navigatedUrl(instance: *runtime.Instance) ?[]const u8 {
    const v8_engine = @import("v8");
    const v8_context = instance.ctx.getEngineContextAs(v8_engine.ffi.Context) orelse return null;
    const url = v8_engine.context_manager.getDocumentUrl(v8_context) orelse return null;
    return if (url.len == 0) null else url;
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
    // Clone to transfer ownership to caller (interface layer will free)
    return try internal.encoding.clone(instance.ctx.allocator);
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
    // Clone to transfer ownership to caller (interface layer will free)
    return try internal.content_type.clone(instance.ctx.allocator);
}

/// Getter for doctype
/// DOM §4.6 - Returns the DocumentType node or null
pub fn get_doctype(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // The doctype is the document's first DocumentType CHILD.
    // https://dom.spec.whatwg.org/#concept-document-doctype
    //
    // Computed for the same reason as documentElement above: `internal.doctype`
    // is a cache the parser paths fill in, so `createHTMLDocument` - which does
    // create and append a doctype - still reported null, and a doctype removed
    // from the tree would still have been reported.
    var child = NodeImpl.getFirstChild(instance);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.DOCUMENT_TYPE_NODE) return c;
        child = NodeImpl.getNextSibling(c);
    }
    return internal.doctype;
}

/// Getter for documentElement
/// DOM §4.6 - Returns the document element (root element, e.g., <html>)
/// The document element: the document's first ELEMENT child.
///
/// https://dom.spec.whatwg.org/#document-element
///
/// COMPUTED, not remembered. `internal.document_element` is a cache that only
/// the parser paths ever assigned - HTMLParser, dom_tree_adapter,
/// scripted_parser and context_manager - so a document built through the DOM
/// API had none. `createHTMLDocument` correctly created and appended
/// html/head/body and `documentElement` was still null, and `body` with it.
///
/// That was not niche: dom/common.js builds its fixtures inside `setup()` with
/// `foreignDoc.body.appendChild(...)`, and testharness rethrows out of
/// `setup()`, so this one null turned whole FILES into a harness ERROR with
/// zero subtests.
///
/// A cache also goes stale: removing or replacing the root left the old
/// pointer in place. Walking the children costs nothing here - a document has
/// a doctype and a root, not a list.
///
/// The cached field is still consulted as a FALLBACK, so any path that sets it
/// without linking the tree keeps working.
fn documentElementOf(instance: *runtime.Instance) ?*runtime.Instance {
    var child = NodeImpl.getFirstChild(instance);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) return c;
        child = NodeImpl.getNextSibling(c);
    }
    if (getInternal(instance)) |internal| return internal.document_element;
    return null;
}

pub fn get_documentElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = getInternal(instance) orelse return error.InvalidStateError;
    return documentElementOf(instance);
}

/// Setter for documentElement (internal use)
/// Used when creating initial document structure for about:blank
pub fn setDocumentElement(instance: *runtime.Instance, element: ?*runtime.Instance) void {
    if (getInternal(instance)) |internal| {
        internal.document_element = element;
    }
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
/// Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-document-location
/// "The Document object's location getter steps are to return this's relevant
/// global object's Location object, if this is fully active, and null
/// otherwise."
///
/// Fully active: the document its window still shows, in a browsing context
/// that has not been discarded - removing an iframe discards its context and
/// every one below it, which is what `closed` reports. A document with no
/// window (createHTMLDocument, DOMParser) is not fully active either.
pub fn get_location(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const window = (try get_defaultView(instance)) orelse return null;
    if (interfaces.Window.get_closed(window) catch true) return null;
    const shown = interfaces.Window.get_document(window) catch return null;
    if (shown != instance) return null;
    return interfaces.Window.get_location(window) catch null;
}

/// Getter for domain
/// HTML §7.5.2 - Returns the document's domain
/// Spec: https://html.spec.whatwg.org/multipage/browsers.html#dom-document-domain
pub fn get_domain(instance: *runtime.Instance) anyerror!runtime.USVString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Clone to transfer ownership to caller (interface layer will free)
    return try instance.ctx.allocator.dupe(u8, internal.domain);
}

/// Getter for referrer
/// HTML §7.5.2 - Returns the document's referrer
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-referrer
pub fn get_referrer(instance: *runtime.Instance) anyerror!runtime.USVString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Clone to transfer ownership to caller (interface layer will free)
    return try instance.ctx.allocator.dupe(u8, internal.referrer);
}

/// Getter for cookie
/// HTML - Returns document's cookies as a string
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-cookie
///
/// Returns document cookies as "name1=value1; name2=value2"
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-cookie
pub fn get_cookie(instance: *runtime.Instance) anyerror!runtime.USVString {
    const internal = getInternal(instance) orelse return "";

    // Count cookies to determine buffer size
    var count: usize = 0;
    var total_len: usize = 0;
    var cookie_it = internal.cookies.iterator();
    while (cookie_it.next()) |entry| {
        if (count > 0) total_len += 2; // "; "
        total_len += entry.key_ptr.len + 1 + entry.value_ptr.len; // "name=value"
        count += 1;
    }

    if (count == 0) return "";

    // Build the cookie string
    const result = internal.allocator.alloc(u8, total_len) catch return "";
    var pos: usize = 0;
    var first = true;
    var it2 = internal.cookies.iterator();
    while (it2.next()) |entry| {
        if (!first) {
            @memcpy(result[pos .. pos + 2], "; ");
            pos += 2;
        }
        @memcpy(result[pos .. pos + entry.key_ptr.len], entry.key_ptr.*);
        pos += entry.key_ptr.len;
        result[pos] = '=';
        pos += 1;
        @memcpy(result[pos .. pos + entry.value_ptr.len], entry.value_ptr.*);
        pos += entry.value_ptr.len;
        first = false;
    }

    return result;
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
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#document.title
///
/// For HTML documents: Returns the text content of the first <title> element
/// in the document (in document order), with whitespace stripped and collapsed.
/// Returns empty string if no <title> element exists.
pub fn get_title(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: If this is an HTML document, find the title element
    // The title element is the first <title> element in document tree order
    if (internal.doc_type == .html) {
        // Find the first <title> element in the document
        if (findTitleElement(instance)) |title_element| {
            // Get the text content of the title element
            if (try interfaces.Node.get_textContent(title_element)) |tc| {
                var text_content = tc;
                defer text_content.deinit(instance.ctx.allocator);
                // Strip and collapse whitespace per spec
                const stripped = stripAndCollapseWhitespace(instance.ctx.allocator, text_content.asSlice()) catch {
                    return runtime.DOMString.initEmpty();
                };
                return runtime.DOMString.initOwned(stripped);
            }
        }
        // No title element found - return empty string
        return runtime.DOMString.initEmpty();
    }

    // For non-HTML documents (XML, SVG), return the cached title
    // (SVG documents have different title element semantics)
    // Clone to transfer ownership to caller (interface layer will free)
    return try internal.title.clone(instance.ctx.allocator);
}

/// Find the first <title> element in the document tree
fn findTitleElement(document: *runtime.Instance) ?*runtime.Instance {
    const internal = getInternal(document) orelse return null;
    const ElementImpl = @import("Element.zig");

    // Start from document element (usually <html>)
    const doc_element = documentElementOf(document) orelse return null;

    // Recursively search for the first <title> element
    return findTitleElementInSubtree(doc_element, ElementImpl, internal.doc_type == .html);
}

/// Recursively search for <title> element in subtree
fn findTitleElementInSubtree(node: *runtime.Instance, comptime ElementImpl: type, is_html: bool) ?*runtime.Instance {
    var child = NodeImpl.getFirstChild(node);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            // Check if this is a <title> element
            if (ElementImpl.getInternal(c)) |elem_internal| {
                const tag_name = elem_internal.local_name.asSlice();
                const is_title = if (is_html)
                    std.ascii.eqlIgnoreCase(tag_name, "title")
                else
                    std.mem.eql(u8, tag_name, "title");

                if (is_title) {
                    return c;
                }
            }

            // Recursively search descendants
            if (findTitleElementInSubtree(c, ElementImpl, is_html)) |found| {
                return found;
            }
        }
        child = NodeImpl.getNextSibling(c);
    }
    return null;
}

/// Strip leading/trailing whitespace and collapse internal whitespace to single spaces
/// Per HTML spec: https://html.spec.whatwg.org/multipage/dom.html#document.title
fn stripAndCollapseWhitespace(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    if (input.len == 0) {
        return try allocator.dupe(u8, "");
    }

    var result = std.ArrayListUnmanaged(u8).empty;
    errdefer result.deinit(allocator);

    var in_whitespace = true; // Skip leading whitespace
    for (input) |c| {
        const is_ws = (c == ' ' or c == '\t' or c == '\n' or c == '\r' or c == '\x0C');
        if (is_ws) {
            if (!in_whitespace) {
                // First whitespace after non-whitespace: add single space
                try result.append(allocator, ' ');
                in_whitespace = true;
            }
            // Otherwise skip additional whitespace
        } else {
            try result.append(allocator, c);
            in_whitespace = false;
        }
    }

    // Remove trailing whitespace (if result ends with space)
    if (result.items.len > 0 and result.items[result.items.len - 1] == ' ') {
        _ = result.pop();
    }

    return result.toOwnedSlice(allocator);
}

/// Getter for dir
/// HTML §3.2.6 - Returns the document's text direction
pub fn get_dir(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Clone to transfer ownership to caller (interface layer will free)
    return try internal.dir.clone(instance.ctx.allocator);
}

/// Getter for body
/// HTML §3.1.3 - Returns the body element (the first body or frameset child of html element)
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-body
pub fn get_body(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Get document element (should be <html>)
    const doc_element = documentElementOf(instance) orelse return null;

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
    const doc_element = documentElementOf(instance) orelse return null;

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

    // Use interface instead of impl (per Golden Rule #13)
    const collection = try interfaces.HTMLCollection.init(internal.allocator, instance.ctx);
    errdefer interfaces.HTMLCollection.deinit(collection);

    // Traverse tree and collect matching elements
    try collectElementsByTagName(instance, tag_name, internal.doc_type == .html, collection);

    return collection;
}

/// Helper: Create an HTMLCollection containing elements matching multiple tag names
fn createCollectionByTagNames(instance: *runtime.Instance, tag_names: []const []const u8) ImplError!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Use interface instead of impl (per Golden Rule #13)
    const collection = try interfaces.HTMLCollection.init(internal.allocator, instance.ctx);
    errdefer interfaces.HTMLCollection.deinit(collection);

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
/// "The currentScript attribute, on getting, must return the value to which it
/// was most recently set." Execute the script element sets it around a classic
/// script's run (and leaves it null for a module script) through
/// `setCurrentScript`; this getter used to ignore that and return null always.
pub fn get_currentScript(instance: *runtime.Instance) anyerror!?typedefs.HTMLOrSVGScriptElement {
    const script = getCurrentScript(instance) orelse return null;
    return .{ .htmlscript_element = script };
}

/// Getter for defaultView
/// HTML §7.3.1 - Returns the Window object associated with the document, or null
/// Spec: https://html.spec.whatwg.org/multipage/window-object.html#dom-document-defaultview
///
/// Returns the Window whose document is this Document, or null if none.
pub fn get_defaultView(instance: *runtime.Instance) anyerror!?typedefs.WindowProxy {
    const internal = getInternal(instance) orelse return null;
    if (internal.default_view) |window| {
        return @ptrCast(window);
    }
    return null;
}

/// Set the default view (window) associated with this document.
/// Called when the document is associated with a window (e.g., during iframe setup).
/// This establishes the bidirectional Document <-> Window relationship.
pub fn setDefaultView(instance: *runtime.Instance, window: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    internal.default_view = window;
    // The window aliases this document's wrapper from here on, so the wrapper
    // cache holds it strongly (see wrapper_cache.holdStrong).
    @import("v8").wrapper_cache_mod.holdStrong(instance);
}

/// Getter for designMode
/// HTML §6.5.1 - Returns "on" or "off" depending on design mode state
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-document-designmode
pub fn get_designMode(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Clone to transfer ownership to caller (interface layer will free)
    return try internal.design_mode.clone(instance.ctx.allocator);
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
    // Clone to transfer ownership to caller (interface layer will free)
    return try internal.fg_color.clone(instance.ctx.allocator);
}

/// Getter for linkColor
/// HTML §14.3.11 (obsolete) - Returns document's link color
pub fn get_linkColor(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Clone to transfer ownership to caller (interface layer will free)
    return try internal.link_color.clone(instance.ctx.allocator);
}

/// Getter for vlinkColor
/// HTML §14.3.11 (obsolete) - Returns document's visited link color
pub fn get_vlinkColor(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Clone to transfer ownership to caller (interface layer will free)
    return try internal.vlink_color.clone(instance.ctx.allocator);
}

/// Getter for alinkColor
/// HTML §14.3.11 (obsolete) - Returns document's active link color
pub fn get_alinkColor(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Clone to transfer ownership to caller (interface layer will free)
    return try internal.alink_color.clone(instance.ctx.allocator);
}

/// Getter for bgColor
/// HTML §14.3.11 (obsolete) - Returns document's background color
pub fn get_bgColor(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Clone to transfer ownership to caller (interface layer will free)
    return try internal.bg_color.clone(instance.ctx.allocator);
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
    // Use interface instead of impl (per Golden Rule #13)
    return try interfaces.HTMLCollection.init(internal.allocator, instance.ctx);
}

/// Getter for all
/// Returns the document's HTMLAllCollection, which is a legacy "undetectable" object.
/// Per HTML spec, document.all has [[IsHTMLDDA]] internal slot making it:
/// - typeof returns "undefined"
/// - == null and == undefined return true
/// - ToBoolean returns false
/// This is essential for WPT test: webidl/ecmascript-binding/global-object-implicit-this-value.any.js
pub fn get_all(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Return cached HTMLAllCollection (lazily created, [SameObject])
    if (internal.all_collection) |all| {
        return all;
    }

    // Create a new HTMLAllCollection for this document
    // The HTMLAllCollection template is automatically marked as undetectable
    // by the V8Interface binding code (see interface.zig HTMLAllCollection handling)
    const HTMLAllCollection = interfaces.HTMLAllCollection;
    const all = try HTMLAllCollection.init(internal.allocator, instance.ctx);
    internal.all_collection = all;
    return all;
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
/// Returns the FontFaceSet associated with this document.
/// Spec: https://drafts.csswg.org/css-font-loading/#dom-fontfacesource-fonts
/// Lazily creates a FontFaceSet on first access ([SameObject] semantics).
pub fn get_fonts(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.fonts) |fonts| {
        return fonts;
    }
    // Lazily create FontFaceSet
    const FontFaceSet = interfaces.FontFaceSet;
    const fonts = FontFaceSet.init(internal.allocator, instance.ctx) catch return error.OutOfMemory;
    internal.fonts = fonts;
    return fonts;
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
/// Spec: https://drafts.csswg.org/cssom/#dom-documentorshadowroot-adoptedstylesheets
///
/// Returns an ObservableArray exotic object (Proxy-based) per WebIDL spec.
/// Uses [SameObject] semantics - returns the same array on each access.
pub fn get_adoptedStyleSheets(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Return cached instance if available ([SameObject] semantics)
    if (internal.adopted_style_sheets) |sheets| {
        // Return the cached V8 handle wrapped as JSValue
        return runtime.JSValue{
            .handle = .{
                .ptr = sheets,
                .needs_disposal = false, // Already tracked by ObservableArrayExotic
                .handle_scope = .global,
            },
        };
    }

    // Create new ObservableArray exotic object
    const observable_array = runtime.ObservableArrayExotic.create(instance.ctx) catch {
        // If we can't create the ObservableArray (e.g., no V8 context), return undefined
        // This gracefully degrades for testing scenarios without full V8 setup
        return runtime.JSValue.jsUndefined;
    };

    // Cache the raw V8 object pointer for future access
    // Extract the handle pointer from the JSValue union
    internal.adopted_style_sheets = switch (observable_array) {
        .handle => |h| h.ptr,
        else => null,
    };

    return observable_array;
}

/// Getter for activeElement
/// Returns the deepest element in the document which has focus, or null.
pub fn get_activeElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.active_element;
}

/// Set the active element (focused element) for this document.
/// Called by HTMLElement.focus() to update document.activeElement.
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#focus-processing-model
pub fn setActiveElement(instance: *runtime.Instance, element: ?*runtime.Instance) void {
    const internal = getInternalState(instance) orelse return;
    internal.active_element = element;
}

// =============================================================================
// Event Handler Helpers
// =============================================================================

/// Document's own event handler IDL attributes (onreadystatechange,
/// onvisibilitychange, ...): the document is their target, and they live in
/// its event handler map on EventTarget with every other handler. The
/// GlobalEventHandlers members are inherited (impls/GlobalEventHandlers.zig).
fn getEventHandler(instance: *runtime.Instance, name: []const u8) typedefs.EventHandler {
    return @import("EventTarget.zig").eventHandler(typedefs.EventHandler, instance, name);
}

fn setEventHandler(instance: *runtime.Instance, name: []const u8, handler: typedefs.EventHandler) ImplError!void {
    @import("EventTarget.zig").setEventHandler(typedefs.EventHandler, instance, name, handler) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidStateError,
    };
}

// =============================================================================
// Event Handler Getters
// =============================================================================

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
/// Sets a cookie from a "name=value; attr1; attr2=val" string
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-cookie
pub fn set_cookie(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    const internal = getInternal(instance) orelse return;
    const cookie_str = value;
    if (cookie_str.len == 0) return;

    // Parse "name=value" from the first part
    var parts_iter = std.mem.splitSequence(u8, cookie_str, ";");
    const name_value = parts_iter.first();

    // Find the '=' separator
    const eq_idx = std.mem.indexOf(u8, name_value, "=") orelse return;
    if (eq_idx == 0) return; // Empty name

    const name = std.mem.trim(u8, name_value[0..eq_idx], " ");
    const cookie_value = std.mem.trim(u8, name_value[eq_idx + 1 ..], " ");

    // Check for expires= attribute to detect deletion
    var is_delete = false;
    while (parts_iter.next()) |attr| {
        const trimmed = std.mem.trim(u8, attr, " ");
        const lower_attr = blk: {
            var lower: [256]u8 = undefined;
            const len = @min(trimmed.len, 256);
            for (0..len) |i| {
                lower[i] = std.ascii.toLower(trimmed[i]);
            }
            break :blk lower[0..len];
        };

        // Check for max-age=0 or max-age=-1 (deletion)
        if (std.mem.startsWith(u8, lower_attr, "max-age=")) {
            const max_age_str = trimmed[8..];
            const max_age = std.fmt.parseInt(i64, max_age_str, 10) catch 0;
            if (max_age <= 0) is_delete = true;
        }
        // Check for expires in the past (deletion)
        if (std.mem.startsWith(u8, lower_attr, "expires=")) {
            // Simple heuristic: if expires contains "1970" it's deletion
            if (std.mem.indexOf(u8, lower_attr, "1970") != null) is_delete = true;
        }
    }

    if (is_delete) {
        // Remove cookie
        if (internal.cookies.fetchRemove(name)) |entry| {
            internal.allocator.free(entry.key);
            internal.allocator.free(entry.value);
        }
        return;
    }

    // Remove old value if exists
    if (internal.cookies.fetchRemove(name)) |entry| {
        internal.allocator.free(entry.key);
        internal.allocator.free(entry.value);
    }

    // Store the new cookie
    const name_copy = internal.allocator.dupe(u8, name) catch return;
    errdefer internal.allocator.free(name_copy);
    const value_copy = internal.allocator.dupe(u8, cookie_value) catch {
        internal.allocator.free(name_copy);
        return;
    };
    internal.cookies.put(name_copy, value_copy) catch {
        internal.allocator.free(name_copy);
        internal.allocator.free(value_copy);
        return;
    };
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
///
/// Note: Per WebIDL spec, this attribute is HTMLElement? (nullable), so it accepts
/// null/undefined from JavaScript. However per HTML spec, null is not a valid body
/// element, so we throw HierarchyRequestError for null values.
pub fn set_body(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const ElementImpl = @import("Element.zig");

    // Step 1: Validate new value is body or frameset
    // Per WebIDL, undefined is converted to null for nullable types.
    // Per HTML spec, null is not a valid body element, so throw HierarchyRequestError.
    const actual_value = value orelse return error.HierarchyRequestError;
    const value_node_type = NodeImpl.getNodeType(actual_value) orelse 0;
    if (value_node_type != NodeImpl.NodeType.ELEMENT_NODE) {
        return error.HierarchyRequestError;
    }

    const value_internal = ElementImpl.getInternal(actual_value) orelse return error.HierarchyRequestError;
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
        if (ob == actual_value) return;
    }

    // Get document element (html)
    const doc_element = documentElementOf(instance) orelse return error.HierarchyRequestError;

    // Step 3: If old body exists, replace it
    if (old_body) |ob| {
        // Remove old body and insert new in its place
        // Use interface instead of impl (per Golden Rule #13)
        _ = try interfaces.Node.call_replaceChild(doc_element, actual_value, ob);
    } else {
        // Step 4: Append to html element
        // Use interface instead of impl (per Golden Rule #13)
        _ = try interfaces.Node.call_appendChild(doc_element, actual_value);
    }

    // Set owner document
    try NodeImpl.setOwnerDocument(actual_value, instance);
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
pub fn set_adoptedStyleSheets(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - CSSOM not fully implemented
}

/// Operation: exitPointerLock
/// Exits pointer lock mode. No-op without pointer lock support.
pub fn call_exitPointerLock(instance: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Clear pointer lock element if set
    internal.pointer_lock_element = null;
}

/// Operation: queryCommandState
/// Returns the state of a toggle command (e.g., bold, italic).
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-document-querycommandstate
pub fn call_queryCommandState(instance: *runtime.Instance, commandId: runtime.DOMString) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    const command_name = commandId.asSlice();

    return editing.queryCommandState(
        internal.allocator,
        @ptrCast(instance),
        command_name,
    ) catch false;
}

/// Operation: parseHTMLUnsafe
pub fn call_static_parseHTMLUnsafe(instance: *runtime.Instance, html: runtime.DOMString) anyerror!*runtime.Instance {
    _ = instance;
    _ = html;
    return error.NotImplemented;
}

/// Operation: exitPictureInPicture
pub fn call_exitPictureInPicture(instance: *runtime.Instance) anyerror!runtime.JSValue {
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
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#elements-in-the-dom
///
/// Creates an element with the correct interface based on tag name.
/// HTML tag names dispatch to their corresponding interfaces (e.g., "iframe" → HTMLIFrameElement).
/// Unknown tag names create HTMLUnknownElement.
pub fn call_createElement(instance: *runtime.Instance, localName: runtime.DOMString, options: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
    _ = options; // TODO: Handle ElementCreationOptions (custom elements)
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // DOM 4.5 createElement step 1: "If localName is not a valid element local
    // name, then throw an "InvalidCharacterError" DOMException."
    if (!names.isValidElementLocalName(localName.asSlice())) return error.InvalidCharacterError;

    // Step 2: "If this is an HTML document, then set localName to localName in
    // ASCII lowercase."
    const lowered: ?[]u8 = if (internal.doc_type == .html) try std.ascii.allocLowerString(internal.allocator, localName.asSlice()) else null;
    defer if (lowered) |l| internal.allocator.free(l);
    const local_name_slice: []const u8 = lowered orelse localName.asSlice();

    // Step 4: "Let namespace be the HTML namespace, if this is an HTML document
    // or this's content type is "application/xhtml+xml"; otherwise null."
    //
    // Leaving this null made a script-created <div> and a parser-created <div>
    // differ: the parser already puts elements in the HTML namespace, so
    // getElementsByTagNameNS, matches() and cloning disagreed depending on how
    // the element happened to be made.
    const in_html_namespace = internal.doc_type == .html or
        std.mem.eql(u8, internal.content_type.asSlice(), "application/xhtml+xml");

    // Step 5: create an element given this, localName, namespace.
    return createAnElement(instance, local_name_slice, if (in_html_namespace) html_namespace else null, null);
}

const html_namespace = "http://www.w3.org/1999/xhtml";

/// DOM "create an element", for a document, local name, namespace and prefix
/// - custom element definitions aside (TODO: steps 2-5 look one up).
///
/// Spec: https://dom.spec.whatwg.org/#concept-create-element step 6: "a new
/// element that implements interface" - the element interface for localName
/// and namespace - "with ... namespace set to namespace, namespace prefix set
/// to prefix, local name set to localName ... and node document set to
/// document".
///
/// Deviation: only the HTML namespace has element interfaces here - an SVG or
/// MathML element is a plain Element (TODO).
fn createAnElement(instance: *runtime.Instance, local_name: []const u8, namespace: ?[]const u8, prefix: ?[]const u8) !*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const ElementImpl = @import("Element.zig");
    const is_html = if (namespace) |ns| std.mem.eql(u8, ns, html_namespace) else false;

    const element = if (is_html)
        try createHTMLElement(internal.allocator, instance.ctx, local_name)
    else
        try interfaces.Element.init(internal.allocator, instance.ctx);
    errdefer runtime.Instance.deinit(element);

    // An HTML element's init chain sets its node type; a plain Element's
    // does not.
    if (!is_html) try NodeImpl.setNodeType(element, NodeImpl.NodeType.ELEMENT_NODE);
    try ElementImpl.setLocalName(element, local_name);
    if (namespace) |ns| try ElementImpl.setNamespaceURI(element, ns);
    if (prefix) |p| try ElementImpl.setPrefix(element, p);
    try NodeImpl.setOwnerDocument(element, instance);
    return element;
}

/// Create an element in the HTML namespace: it implements the interface HTML's
/// "element interface" algorithm names for `local_name`, matched exactly.
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#htmlelement
pub fn createHTMLElement(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    local_name: []const u8,
) !*runtime.Instance {
    return switch (html_core.element_interface.forLocalName(local_name)) {
        inline else => |which| @field(interfaces, @tagName(which)).init(allocator, ctx),
    };
}

/// Operation: releaseEvents
/// Legacy no-op method for event capture.
pub fn call_releaseEvents(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    // No-op - legacy method
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
/// Returns whether an editing command is supported by this implementation.
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-document-querycommandsupported
pub fn call_queryCommandSupported(instance: *runtime.Instance, commandId: runtime.DOMString) anyerror!bool {
    _ = instance;
    const command_name = commandId.asSlice();
    return editing.queryCommandSupported(command_name);
}

/// Operation: hasPrivateToken
pub fn call_hasPrivateToken(instance: *runtime.Instance, issuer: runtime.USVString) anyerror!runtime.JSValue {
    _ = instance;
    _ = issuer;
    return error.NotImplemented;
}

/// Operation: requestStorageAccessFor
pub fn call_requestStorageAccessFor(instance: *runtime.Instance, requestedOrigin: runtime.USVString) anyerror!runtime.JSValue {
    _ = instance;
    _ = requestedOrigin;
    return error.NotImplemented;
}

/// Operation: open
/// HTML §8.4.1 - Opens the document for writing
/// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-document-open
///
/// Algorithm (simplified):
/// 1. If document is an XML document, throw InvalidStateError
/// 2. If throw-on-dynamic-markup-insertion counter > 0, throw InvalidStateError
/// 3. Clear the document and create a script-created parser
/// 4. Return the document
pub fn call_open(instance: *runtime.Instance, unused1: webidl.Opt(runtime.DOMString), unused2: webidl.Opt(runtime.DOMString)) anyerror!*runtime.Instance {
    _ = unused1;
    _ = unused2;

    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: If this is an XML document, throw InvalidStateError
    if (internal.doc_type == .xml) {
        return error.InvalidStateError;
    }

    // Step 2: If throw-on-dynamic-markup-insertion counter > 0, throw InvalidStateError
    if (internal.throw_on_dynamic_markup_insertion_counter > 0) {
        return error.InvalidStateError;
    }

    // Step 5-6: Check unload counter
    if (internal.unload_counter > 0) {
        return instance; // Return document unchanged
    }

    // Step 7: Check if active parser was aborted
    if (internal.active_parser_was_aborted) {
        return instance; // Return document unchanged
    }

    // Step 8: "If document's node navigable is non-null and document's node
    // navigable's ongoing navigation is a navigation ID, then stop loading
    // document's node navigable."
    @import("dom").content_navigables.stopLoading(instance);

    // Steps 9-14: Remove all nodes from document
    var child = NodeImpl.getFirstChild(instance);
    while (child) |c| {
        const next = NodeImpl.getNextSibling(c);
        _ = interfaces.Node.call_removeChild(instance, c) catch {};
        child = next;
    }

    // Reset document element and doctype references
    internal.document_element = null;
    internal.doctype = null;

    // Step 13: "Set document's is initial about:blank to false."
    internal.is_initial_about_blank = false;

    // Step 16: Create new HTML parser (script-created)
    internal.is_script_created_parser = true;

    // Step 17: Set insertion point to 0 (beginning of stream)
    internal.insertion_point = 0;

    // Clear any previously buffered content
    internal.write_buffer.clearRetainingCapacity();

    // Step 18: "Update the current document readiness of document to
    // "loading"." Not implemented, stated: steps 9-10 (erase the listeners
    // and handlers of the document and its window) and 14 (mute the iframe
    // load event).
    updateReadiness(instance, ._loading_);

    // Return the document
    return instance;
}

/// Operation: hasUnpartitionedCookieAccess
pub fn call_hasUnpartitionedCookieAccess(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: hasRedemptionRecord
pub fn call_hasRedemptionRecord(instance: *runtime.Instance, issuer: runtime.USVString) anyerror!runtime.JSValue {
    _ = instance;
    _ = issuer;
    return error.NotImplemented;
}

/// Operation: execCommand
/// Executes an editing command.
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-document-execcommand
///
/// This implementation performs actual DOM manipulation for formatting commands.
/// The editing module (html_core) provides command parsing and validation,
/// but DOM manipulation happens here since impls has access to interfaces.
pub fn call_execCommand(instance: *runtime.Instance, commandId: runtime.DOMString, showUI: webidl.Opt(bool), value: webidl.Opt(runtime.DOMString)) anyerror!bool {
    const internal = getInternal(instance) orelse return false;

    // Get command name (case-insensitive per spec)
    const command_name = commandId.asSlice();
    _ = showUI; // Ignored by modern browsers

    // Get optional value for commands that need it
    const value_slice: ?[]const u8 = if (value.wasPassed())
        value.value.asSlice()
    else
        null;

    // Parse command and determine action
    // Formatting commands that wrap selection in elements
    if (std.ascii.eqlIgnoreCase(command_name, "bold")) {
        return applyInlineFormatting(instance, internal, "b");
    } else if (std.ascii.eqlIgnoreCase(command_name, "italic")) {
        return applyInlineFormatting(instance, internal, "i");
    } else if (std.ascii.eqlIgnoreCase(command_name, "underline")) {
        return applyInlineFormatting(instance, internal, "u");
    } else if (std.ascii.eqlIgnoreCase(command_name, "strikethrough") or
        std.ascii.eqlIgnoreCase(command_name, "strikeThrough"))
    {
        return applyInlineFormatting(instance, internal, "s");
    } else if (std.ascii.eqlIgnoreCase(command_name, "subscript")) {
        return applyInlineFormatting(instance, internal, "sub");
    } else if (std.ascii.eqlIgnoreCase(command_name, "superscript")) {
        return applyInlineFormatting(instance, internal, "sup");
    } else if (std.ascii.eqlIgnoreCase(command_name, "createLink")) {
        // createLink requires a URL value
        const url = value_slice orelse return false;
        return applyCreateLink(instance, internal, url);
    } else if (std.ascii.eqlIgnoreCase(command_name, "insertText")) {
        // insertText requires text value
        const text = value_slice orelse return false;
        return applyInsertText(instance, internal, text);
    }

    // For unsupported commands, delegate to the editing module for stub handling
    return editing.execCommand(
        internal.allocator,
        @ptrCast(instance),
        command_name,
        false,
        value_slice,
    ) catch |err| {
        if (@import("builtin").mode == .Debug) {
            log.err("execCommand error: {any}", .{err});
        }
        return false;
    };
}

/// Apply inline formatting by wrapping selection in an element
/// Used for bold, italic, underline, strikethrough, subscript, superscript
fn applyInlineFormatting(document: *runtime.Instance, internal: *InternalState, tag_name: []const u8) bool {
    // Step 1: Get selection
    const selection_opt = call_getSelection(document) catch return false;
    const selection = selection_opt orelse return false;

    // Step 2: Check if selection has content (not collapsed)
    const is_collapsed = SelectionImpl.get_isCollapsed(selection) catch return false;
    if (is_collapsed) {
        // No content selected - nothing to format
        // TODO: Toggle "future typing" state
        return true;
    }

    // Step 3: Get the range
    const range = SelectionImpl.call_getRangeAt(selection, 0) catch return false;

    // Step 4: Create the formatting element
    const element = call_createElement(document, runtime.DOMString.initInterned(tag_name), webidl.Opt(runtime.JSValue).notPassed()) catch return false;

    // Step 5: Surround the selection with the element
    RangeImpl.call_surroundContents(range, element) catch |err| {
        if (@import("builtin").mode == .Debug) {
            log.err("surroundContents failed: {any}", .{err});
        }
        // surroundContents can fail if range partially contains non-text nodes
        return false;
    };

    _ = internal; // Will be used for undo history
    return true;
}

/// Apply createLink by wrapping selection in an anchor element
fn applyCreateLink(document: *runtime.Instance, _: *InternalState, url: []const u8) bool {
    // Step 1: Get selection
    const selection_opt = call_getSelection(document) catch return false;
    const selection = selection_opt orelse return false;

    // Step 2: Check if selection has content
    const is_collapsed = SelectionImpl.get_isCollapsed(selection) catch return false;
    if (is_collapsed) {
        // No content selected - can't create link without text
        return false;
    }

    // Step 3: Get the range
    const range = SelectionImpl.call_getRangeAt(selection, 0) catch return false;

    // Step 4: Create anchor element
    const anchor = call_createElement(document, runtime.DOMString.initInterned("a"), webidl.Opt(runtime.JSValue).notPassed()) catch return false;

    // Step 5: Set href attribute
    // Use Element interface to set attribute
    interfaces.Element.call_setAttribute(anchor, runtime.DOMString.initInterned("href"), runtime.DOMString.initInterned(url)) catch return false;

    // Step 6: Surround selection with anchor
    RangeImpl.call_surroundContents(range, anchor) catch return false;

    return true;
}

/// Apply insertText by inserting text at selection
fn applyInsertText(document: *runtime.Instance, _: *InternalState, text: []const u8) bool {
    // Step 1: Get selection
    const selection_opt = call_getSelection(document) catch return false;
    const selection = selection_opt orelse return false;

    // Step 2: Get the range (or create one if collapsed)
    const range = SelectionImpl.call_getRangeAt(selection, 0) catch return false;

    // Step 3: Delete selected content if any
    const is_collapsed = SelectionImpl.get_isCollapsed(selection) catch false;
    if (!is_collapsed) {
        RangeImpl.call_deleteContents(range) catch return false;
    }

    // Step 4: Create text node
    const text_node = call_createTextNode(document, runtime.DOMString.initInterned(text)) catch return false;

    // Step 5: Insert text node at range position
    RangeImpl.call_insertNode(range, text_node) catch return false;

    // Step 6: Collapse selection after the inserted text
    SelectionImpl.call_collapseToEnd(selection) catch {};

    return true;
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
/// 6. If insertion point is undefined (no active parser), implicitly call document.open()
/// 7. Insert the input into the input stream just before the insertion point
///
/// This implementation handles two modes:
/// - During parsing: inserts into InputStreamManager at insertion point
/// - After parsing: accumulates in write_buffer (parsed on document.close())
pub fn call_write(instance: *runtime.Instance, text: []const runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: If this is an XML document, throw InvalidStateError
    if (internal.doc_type == .xml) {
        return error.InvalidStateError;
    }

    // Step 2: If throw-on-dynamic-markup-insertion counter > 0, throw InvalidStateError
    // This happens during custom element reactions and other restricted contexts
    if (internal.throw_on_dynamic_markup_insertion_counter > 0) {
        return error.InvalidStateError;
    }

    // Step 3/4: If active parser was aborted (e.g., by navigation), ignore
    if (internal.active_parser_was_aborted) {
        return;
    }

    // Step 5: If insertion point is undefined (no active parser)
    if (internal.insertion_point == null) {
        // Check if destructive writes should be ignored
        if (internal.ignore_destructive_writes_counter > 0 or internal.unload_counter > 0) {
            return;
        }
        // Implicitly call document.open() - this creates a script-created parser
        // For now, just set up write mode
        internal.is_script_created_parser = true;
        internal.insertion_point = 0;
        internal.write_buffer.clearRetainingCapacity();
    }

    // Concatenate all text arguments per spec
    // Spec: "Let input be the concatenation of all the arguments"
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

    // Step 7: Insert input into the input stream
    // Check if we have an active parser with InputStreamManager
    if (internal.input_stream_manager) |ism| {
        // During parsing: insert into InputStreamManager at insertion point
        // This allows the parser to process the inserted content inline
        ism.insert(buffer) catch |err| {
            return switch (err) {
                error.OutOfMemory => error.OutOfMemory,
            };
        };
    } else {
        // After parsing / script-created parser mode:
        // Accumulate in write_buffer, to be parsed when document.close() is called
        // or when we need to flush content
        internal.write_buffer.appendSlice(internal.allocator, buffer) catch {
            return error.OutOfMemory;
        };

        // For immediate effect (backwards compatibility), also append to body
        // This handles the common case where document.write is called after parsing
        const body = get_body(instance) catch null;
        if (body) |body_elem| {
            const HTMLParser = @import("HTMLParser.zig");

            const fragment = HTMLParser.parseFragment(
                internal.allocator,
                instance.ctx,
                buffer,
                body_elem,
            ) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                else => return,
            };
            defer interfaces.DocumentFragment.deinit(fragment);

            // Move children from fragment to body
            var child = NodeImpl.getFirstChild(fragment);
            while (child) |c| {
                const next = NodeImpl.getNextSibling(c);
                // Use interface instead of impl (per Golden Rule #13)
                _ = interfaces.Node.call_removeChild(fragment, c) catch break;
                _ = interfaces.Node.call_appendChild(body_elem, c) catch break;
                child = next;
            }
        }
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

    // Step 1: "If localName is not a valid attribute local name, then throw
    // an "InvalidCharacterError" DOMException."
    if (!names.isValidAttributeLocalName(localName.asSlice())) return error.InvalidCharacterError;

    // Step 2: "If this is an HTML document, then set localName to localName
    // in ASCII lowercase."
    const lowered: ?[]u8 = if (internal.doc_type == .html)
        try std.ascii.allocLowerString(internal.allocator, localName.asSlice())
    else
        null;
    defer if (lowered) |l| internal.allocator.free(l);
    const local_name = lowered orelse localName.asSlice();

    // Step 3: "Return a new attribute whose local name is localName and node
    // document is this."
    const attr = try interfaces.Attr.init(internal.allocator, instance.ctx);
    errdefer interfaces.Attr.deinit(attr);
    try NodeImpl.setOwnerDocument(attr, instance);
    try attr_nodes.name(attr, null, null, local_name);
    return attr;
}

/// Operation: clear
/// Legacy method - does nothing.
pub fn call_clear(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    // No-op - legacy method
}

/// Operation: queryCommandIndeterm
/// Returns whether an editing command is in an indeterminate state (mixed).
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-document-querycommandindeterm
pub fn call_queryCommandIndeterm(instance: *runtime.Instance, commandId: runtime.DOMString) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    const command_name = commandId.asSlice();

    return editing.queryCommandIndeterm(
        internal.allocator,
        @ptrCast(instance),
        command_name,
    ) catch false;
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
pub fn call_elementsFromPoint(instance: *runtime.Instance, x: f64, y: f64) anyerror!runtime.JSValue {
    _ = instance;
    _ = x;
    _ = y;
    // Without a layout engine, we cannot determine element positions
    // Return undefined for empty array
    return runtime.JSValue.jsUndefined;
}

/// Operation: createProcessingInstruction
/// DOM §4.6 - Creates a ProcessingInstruction node
/// Spec: https://dom.spec.whatwg.org/#dom-document-createprocessinginstruction
pub fn call_createProcessingInstruction(instance: *runtime.Instance, target: runtime.DOMString, data: runtime.DOMString) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // DOM 4.5: return a new ProcessingInstruction with target `target`, data
    // `data` and node document this. The target is readonly on the interface,
    // so it can only be set at creation.
    const pi = try ProcessingInstructionImpl.createProcessingInstruction(
        internal.allocator,
        instance.ctx,
        target.asSlice(),
        data.asSlice(),
    );
    errdefer interfaces.ProcessingInstruction.deinit(pi);

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
    _ = getInternal(instance) orelse return error.InvalidStateError;
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
    // Use interface instead of impl (per Golden Rule #13)
    const event = try interfaces.Event.call_constructor(instance.ctx, runtime.DOMString.initEmpty(), webidl.Opt(dictionaries.EventInit).passed(event_init));

    // Steps 6-8 fall out of constructing with an empty type: type is "",
    // isTrusted is false, timeStamp is current high resolution time.

    // Step 9: Unset event's initialized flag.
    //
    // The Event constructor SETS it, so without this the event created here is
    // indistinguishable from `new Event("")` and `dispatchEvent` never throws -
    // which is exactly what "If the event's initialized flag is not set, an
    // InvalidStateError must be thrown" checks. `initEvent` sets it again.
    EventImpl.setInitializedFlag(event, false);

    return event;
}

/// Operation: getBoxQuads
/// Returns the CSS box quads for this document.
/// Without a layout engine, returns an empty sequence.
pub fn call_getBoxQuads(instance: *runtime.Instance, options: webidl.Opt(dictionaries.BoxQuadOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = options;
    // Without a layout engine, we cannot compute box quads
    // Return undefined for empty array
    return runtime.JSValue.jsUndefined;
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
pub fn call_getAnimations(instance: *runtime.Instance) anyerror!runtime.JSValue {
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
        // Use interface instead of impl (per Golden Rule #13)
        return try interfaces.HTMLCollection.init(internal.allocator, instance.ctx);
    }

    // Create an HTMLCollection to hold results
    // Use interface instead of impl (per Golden Rule #13)
    const collection = try interfaces.HTMLCollection.init(internal.allocator, instance.ctx);
    errdefer interfaces.HTMLCollection.deinit(collection);

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
    // Use interface instead of impl (per Golden Rule #13)
    const collection = try interfaces.HTMLCollection.init(internal.allocator, instance.ctx);
    errdefer interfaces.HTMLCollection.deinit(collection);

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

/// Operation: hasStorageAccess
pub fn call_hasStorageAccess(instance: *runtime.Instance) anyerror!runtime.JSValue {
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
pub fn call_importNode(instance: *runtime.Instance, node: *runtime.Instance, options: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
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
            // Use interface instead of impl (per Golden Rule #13)
            const ElementImpl = @import("Element.zig");
            const elem = try interfaces.Element.init(internal.allocator, doc.ctx);
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

                // Copy all attributes using iterator
                var attr_iter = src_internal.attributeIterator();
                while (attr_iter.next()) |attr| {
                    const new_attr = ElementImpl.AttributeEntry{
                        .namespace_uri = if (attr.namespace_uri) |ns| try internal.allocator.dupe(u8, ns) else null,
                        .prefix = if (attr.prefix) |p| try internal.allocator.dupe(u8, p) else null,
                        .local_name = try internal.allocator.dupe(u8, attr.local_name),
                        .value = try internal.allocator.dupe(u8, attr.value),
                    };
                    try elem_internal.addAttribute(new_attr);
                }
            }

            break :blk elem;
        },
        NodeImpl.NodeType.TEXT_NODE => blk: {
            // Clone text data
            const CharacterDataImpl = @import("CharacterData.zig");
            const src_data = CharacterDataImpl.getData(node) orelse "";
            // Use interface instead of impl (per Golden Rule #13)
            const text = try interfaces.Text.call_constructor(doc.ctx, webidl.Opt(runtime.DOMString).passed(runtime.DOMString.initInterned(src_data)));
            break :blk text;
        },
        NodeImpl.NodeType.COMMENT_NODE => blk: {
            // Clone comment data
            const CharacterDataImpl = @import("CharacterData.zig");
            const src_data = CharacterDataImpl.getData(node) orelse "";
            // Use interface instead of impl (per Golden Rule #13)
            const comment = try interfaces.Comment.call_constructor(doc.ctx, webidl.Opt(runtime.DOMString).passed(runtime.DOMString.initInterned(src_data)));
            break :blk comment;
        },
        NodeImpl.NodeType.DOCUMENT_FRAGMENT_NODE => blk: {
            // Use interface instead of impl (per Golden Rule #13)
            const fragment = try interfaces.DocumentFragment.init(internal.allocator, doc.ctx);
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

            // Use interface instead of impl (per Golden Rule #13)
            const cdata = try interfaces.CDATASection.init(internal.allocator, doc.ctx);
            try NodeImpl.setNodeType(cdata, NodeImpl.NodeType.CDATA_SECTION_NODE);

            // Set the data via CharacterData (internal method)
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

    // Use interface instead of impl (per Golden Rule #13)
    const cdata = try interfaces.CDATASection.init(internal.allocator, instance.ctx);
    errdefer interfaces.CDATASection.deinit(cdata);

    // Set node type
    try NodeImpl.setNodeType(cdata, NodeImpl.NodeType.CDATA_SECTION_NODE);

    // DOM 4.5: the new CDATASection node's data is `data`.
    try interfaces.CharacterData.set_data(cdata, data);

    // Set owner document
    try NodeImpl.setOwnerDocument(cdata, instance);

    return cdata;
}

/// Operation: queryCommandEnabled
/// Returns whether an editing command is currently enabled.
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-document-querycommandenabled
pub fn call_queryCommandEnabled(instance: *runtime.Instance, commandId: runtime.DOMString) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    const command_name = commandId.asSlice();

    return editing.queryCommandEnabled(
        internal.allocator,
        @ptrCast(instance),
        command_name,
    ) catch false;
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
    // Use interface instead of impl (per Golden Rule #13)
    const range = try interfaces.Range.init(internal.allocator, instance.ctx);
    errdefer interfaces.Range.deinit(range);

    // Step 2: Set range's start and end to (this, 0), as a live range of this
    // document - the Range's own step, reached through dom.range_boundaries.
    try range_boundaries.collapseLive(range, instance, 0);

    // Step 3: Return range
    return range;
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

    // Step 1: "Let (namespace, prefix, localName) be the result of
    // validating and extracting namespace and qualifiedName given
    // "attribute"."
    const extracted = try names.validateAndExtract(
        if (namespace) |ns| ns.asSlice() else null,
        qualifiedName.asSlice(),
        .attribute,
    );

    // Step 2: "Return a new attribute whose namespace is namespace, namespace
    // prefix is prefix, local name is localName, and node document is this."
    const attr = try interfaces.Attr.init(internal.allocator, instance.ctx);
    errdefer interfaces.Attr.deinit(attr);
    try NodeImpl.setOwnerDocument(attr, instance);
    try attr_nodes.name(attr, extracted.namespace, extracted.prefix, extracted.local_name);
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
pub fn call_exitFullscreen(instance: *runtime.Instance) anyerror!runtime.JSValue {
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
        try NodeImpl.removeNodeFromParent(node, parent);
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
    _ = getInternal(instance) orelse return error.InvalidStateError;

    // Use interface instead of impl (per Golden Rule #13)
    const text = try interfaces.Text.call_constructor(instance.ctx, webidl.Opt(runtime.DOMString).passed(data));
    errdefer interfaces.Text.deinit(text);

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
    // The binding hands a callback argument over: the walker owns it from
    // here and releases it in its deinit.
    const filter_wrapper: ?*runtime.CallbackWrapper = if (filter.was_passed) (filter.value orelse null) else null;

    // Step 1: Create TreeWalker
    // Use interface instead of impl (per Golden Rule #13)
    const walker = try interfaces.TreeWalker.init(internal.allocator, instance.ctx);
    errdefer interfaces.TreeWalker.deinit(walker);

    // Steps 2-5: the walker's own state, set through dom.traversal.
    const what_to_show: u32 = if (whatToShow.was_passed) whatToShow.value else 0xFFFFFFFF;
    try traversal.setUpTreeWalker(walker, root, what_to_show, filter_wrapper);

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
    // Use interface instead of impl (per Golden Rule #13)
    const collection = try interfaces.HTMLCollection.init(internal.allocator, instance.ctx);
    errdefer interfaces.HTMLCollection.deinit(collection);

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
                // Look for "name" attribute in element's attributes using findAttribute
                if (elem_internal.findAttribute(null, "name")) |attr| {
                    if (std.mem.eql(u8, attr.value, target_name)) {
                        HTMLCollectionImpl.addElement(collection, c) catch return error.OutOfMemory;
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
/// Algorithm: Concatenate text arguments with "\n" at end, then call write() logic.
pub fn call_writeln(instance: *runtime.Instance, text: []const runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: If this is an XML document, throw InvalidStateError
    if (internal.doc_type == .xml) {
        return error.InvalidStateError;
    }

    // Step 2: If throw-on-dynamic-markup-insertion counter > 0, throw InvalidStateError
    if (internal.throw_on_dynamic_markup_insertion_counter > 0) {
        return error.InvalidStateError;
    }

    // Step 3/4: If active parser was aborted, ignore
    if (internal.active_parser_was_aborted) {
        return;
    }

    // Step 5: If insertion point is undefined (no active parser)
    if (internal.insertion_point == null) {
        // Check if destructive writes should be ignored
        if (internal.ignore_destructive_writes_counter > 0 or internal.unload_counter > 0) {
            return;
        }
        // Implicitly call document.open()
        internal.is_script_created_parser = true;
        internal.insertion_point = 0;
        internal.write_buffer.clearRetainingCapacity();
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

    // Insert into input stream or write buffer
    if (internal.input_stream_manager) |ism| {
        // During parsing: insert into InputStreamManager
        ism.insert(buffer) catch |err| {
            return switch (err) {
                error.OutOfMemory => error.OutOfMemory,
            };
        };
    } else {
        // After parsing: accumulate in write_buffer
        internal.write_buffer.appendSlice(internal.allocator, buffer) catch {
            return error.OutOfMemory;
        };

        // Also append to body for immediate effect
        const body = get_body(instance) catch null;
        if (body) |body_elem| {
            const HTMLParser = @import("HTMLParser.zig");

            const fragment = HTMLParser.parseFragment(
                internal.allocator,
                instance.ctx,
                buffer,
                body_elem,
            ) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                else => return,
            };
            defer interfaces.DocumentFragment.deinit(fragment);

            // Move children from fragment to body
            var child = NodeImpl.getFirstChild(fragment);
            while (child) |c| {
                const next = NodeImpl.getNextSibling(c);
                _ = interfaces.Node.call_removeChild(fragment, c) catch break;
                _ = interfaces.Node.call_appendChild(body_elem, c) catch break;
                child = next;
            }
        }
    }
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
/// Returns the current value for a valued command (e.g., fontName, fontSize).
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-document-querycommandvalue
pub fn call_queryCommandValue(instance: *runtime.Instance, commandId: runtime.DOMString) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initEmpty();
    const command_name = commandId.asSlice();

    const result = editing.queryCommandValue(
        internal.allocator,
        @ptrCast(instance),
        command_name,
    ) catch {
        return runtime.DOMString.initEmpty();
    };

    if (result) |value| {
        return runtime.DOMString.initInterned(value);
    }
    return runtime.DOMString.initEmpty();
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
pub fn call_startViewTransition(instance: *runtime.Instance, callbackOptions: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
    _ = instance;
    _ = callbackOptions;
    return error.NotImplemented;
}

/// Operation: createComment
/// DOM §4.6 - Creates a Comment node with the given data
/// Spec: https://dom.spec.whatwg.org/#dom-document-createcomment
pub fn call_createComment(instance: *runtime.Instance, data: runtime.DOMString) anyerror!*runtime.Instance {
    _ = getInternal(instance) orelse return error.InvalidStateError;

    // Use interface instead of impl (per Golden Rule #13)
    const comment = try interfaces.Comment.call_constructor(instance.ctx, webidl.Opt(runtime.DOMString).passed(data));
    errdefer interfaces.Comment.deinit(comment);

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
    // Use interface instead of impl (per Golden Rule #13)
    const fragment = try interfaces.DocumentFragment.init(internal.allocator, instance.ctx);
    errdefer interfaces.DocumentFragment.deinit(fragment);

    // Set node type
    try NodeImpl.setNodeType(fragment, NodeImpl.NodeType.DOCUMENT_FRAGMENT_NODE);

    // Set owner document
    try NodeImpl.setOwnerDocument(fragment, instance);

    return fragment;
}

/// Operation: getSelection
/// Returns the Selection object for the document.
/// Spec: https://w3c.github.io/selection-api/#dom-document-getselection
///
/// The Selection object is lazily created and cached per document ([SameObject]).
/// Returns the Selection associated with this document.
pub fn call_getSelection(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;

    // Return cached selection if already created ([SameObject])
    if (internal.selection) |selection| {
        return selection;
    }

    // Create new Selection for this document
    const selection = SelectionImpl.createSelection(internal.allocator, instance.ctx, instance) catch |err| {
        if (@import("builtin").mode == .Debug) {
            log.err("Failed to create Selection: {any}", .{err});
        }
        return null;
    };

    // Cache the selection
    internal.selection = selection;
    return selection;
}

/// Operation: close
/// HTML §8.4.4 - Closes the document output stream
/// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-document-close
///
/// Algorithm:
/// 1. If throw-on-dynamic-markup-insertion counter > 0, throw InvalidStateError
/// 2. If no script-created parser, return
/// 3. Set insertion point to undefined
/// 4. Parse any buffered content
pub fn call_close(instance: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: "If this is an XML document, then throw an "InvalidStateError"
    // DOMException."
    if (internal.doc_type == .xml) return error.InvalidStateError;

    // Step 2: If throw-on-dynamic-markup-insertion counter > 0, throw InvalidStateError
    if (internal.throw_on_dynamic_markup_insertion_counter > 0) {
        return error.InvalidStateError;
    }

    // Step 3: "If there is no script-created parser associated with this,
    // then return."
    if (!internal.is_script_created_parser) {
        return;
    }

    // Steps 4-6: insert an explicit EOF at the end of the input stream and run
    // the tokenizer until it reaches it. The script-created parser has
    // buffered everything document.write() inserted, so this is the parse of
    // that stream as the document's own - from the initial insertion mode,
    // into the document open() emptied - by the parser a navigation uses. It
    // used to be parsed as a fragment, which never made the html, head and
    // body elements a document has. Deviation, stated: step 5 (a pending
    // parsing-blocking script) does not arise - scripts in the stream run as
    // the parser meets them.
    const input = try internal.allocator.dupe(u8, internal.write_buffer.items);
    defer internal.allocator.free(input);
    internal.write_buffer.clearRetainingCapacity();
    const window: ?*runtime.Instance = get_defaultView(instance) catch null;
    _ = @import("html").scripted_parser.parseHTMLWithScripting(internal.allocator, instance.ctx, input, .{
        .scripting_enabled = window != null,
        .window = window,
        .document = instance,
    }) catch |err| log.warn("document.close(): the parser stopped early: {}", .{err});
    internal.is_script_created_parser = false;
    internal.insertion_point = null;

    // The tokenizer reached the explicit EOF, so the parser stops: "the end".
    theEnd(instance);
}

// =============================================================================
// "The end" (HTML §13.2.7) for a script-created parser
// =============================================================================

/// "Update the current document readiness": if `readiness` is new, set it
/// and fire readystatechange at the document.
fn updateReadiness(instance: *runtime.Instance, readiness: enums.DocumentReadyState) void {
    const internal = getInternal(instance) orelse return;
    if (internal.ready_state == readiness) return;
    internal.ready_state = readiness;
    fireEvent(instance, instance, "readystatechange", false);
}

/// "The end" from step 3, once document.close()'s parse has stopped.
/// Deviations, stated: no deferred scripts run (step 5), and load's legacy
/// target override is not modelled.
fn theEnd(instance: *runtime.Instance) void {
    lifecycleParsingStopped(instance);
    lifecycleFinishLoading(instance);
}

/// dom.document_lifecycle: "the end" step 3, "Update the current document
/// readiness to "interactive"."
fn lifecycleParsingStopped(document: *runtime.Instance) void {
    // A parser that runs outside script - the top-level one, loading a page -
    // has no scope open, and readystatechange needs one.
    const scope = @import("v8").JsScope.init(document.ctx) orelse return;
    defer scope.deinit();
    updateReadiness(document, ._interactive_);
}

/// dom.document_lifecycle: step 6's task fires DOMContentLoaded; step 9's
/// completes the load, once step 8 finds nothing delaying it.
fn lifecycleFinishLoading(document: *runtime.Instance) void {
    queueLifecycleTask(document, .dom_content_loaded);
    // Step 7 - the scripts that execute as soon as possible - runs them as
    // they arrive (script_execution), so nothing is left to wait for here.
    queueLoadUnlessDelayed(document);
}

/// "The end" step 8: "Spin the event loop until there is nothing that delays
/// the load event in the Document." Then step 9: queue the task that
/// completes the load. Spinning is waiting here: a document something still
/// delays is marked, and whatever delayed it calls `loadDelayMayHaveEnded`
/// when it stops (dom.content_navigables: a frame that finished loading, or
/// went away).
///
/// A frame's navigation is what delays it today. Without this the window's
/// load event, and every `onload` test reading its frames, ran before the
/// frames it contains had loaded as soon as frame navigation stopped being
/// synchronous.
fn queueLoadUnlessDelayed(document: *runtime.Instance) void {
    const internal = getInternal(document) orelse return;
    if (@import("dom").content_navigables.delaysLoadEvent(document)) {
        internal.load_waiting_on_delay = true;
        return;
    }
    internal.load_waiting_on_delay = false;
    queueLifecycleTask(document, .load);
}

/// dom.document_lifecycle: something that delayed `document`'s load event
/// may have stopped. If "the end" waits at step 8, look again.
fn lifecycleLoadDelayMayHaveEnded(document: *runtime.Instance) void {
    const internal = getInternal(document) orelse return;
    if (!internal.load_waiting_on_delay) return;
    queueLoadUnlessDelayed(document);
}

fn lifecycleIsCompletelyLoaded(document: *runtime.Instance) bool {
    const internal = getInternal(document) orelse return true;
    return internal.completely_loaded;
}

fn lifecycleIsInitialAboutBlank(document: *runtime.Instance) bool {
    const internal = getInternal(document) orelse return false;
    return internal.is_initial_about_blank;
}

/// HTML "create a new browsing context and document": step 15 makes the
/// document with "is initial about:blank" true, and step 21 completely
/// finishes loading it - with no container yet, so no load event.
fn lifecycleMarkInitialAboutBlank(document: *runtime.Instance) void {
    const internal = getInternal(document) orelse return;
    internal.is_initial_about_blank = true;
    internal.completely_loaded = true;
    // "Current document readiness" is initially "complete" (HTML §3.1.1);
    // only "create and initialize a Document object" - navigation - makes
    // it "loading". This document never went through that.
    internal.ready_state = ._complete_;
}

fn lifecycleIsUnloading(document: *runtime.Instance) bool {
    const internal = getInternal(document) orelse return false;
    return internal.unload_counter > 0;
}

/// dom.document_lifecycle: the "steps to fire beforeunload" given
/// `document` (HTML §7.4.2.4), from a task on the navigation and traversal
/// task source - so it opens the scope an event needs.
///
/// Step 6's prompt needs sticky activation, which nothing in this engine
/// grants, so no prompt is shown and nothing is cancelled: a handler that
/// cancels the event or sets its returnValue is recorded in the result's
/// `prompt_requested` and changes nothing else, as in a browser whose user
/// never interacted with the page.
fn lifecycleFireBeforeUnload(document: *runtime.Instance) @import("dom").document_lifecycle.BeforeUnloadResult {
    const internal = getInternal(document) orelse return .{};
    const window = (get_defaultView(document) catch null) orelse return .{};
    const scope = @import("v8").JsScope.init(document.ctx) orelse return .{};
    defer scope.deinit();

    // Step 2: "Increase the document's unload counter by 1." Step 7 lowers
    // it again, however the event handlers leave.
    internal.unload_counter += 1;
    defer internal.unload_counter -= 1;
    // Steps 3 and 5: the event loop's termination nesting level, around the
    // event - window.open() returns null inside it.
    const termination_nesting = @import("html_core").navigation.termination_nesting;
    termination_nesting.enter();
    defer termination_nesting.leave();

    // Step 4: "Let eventFiringResult be the result of firing an event named
    // beforeunload at document's relevant global object, using
    // BeforeUnloadEvent, with the cancelable attribute initialized to true."
    const event = interfaces.BeforeUnloadEvent.init(document.ctx.allocator, document.ctx) catch return .{};
    const generation = runtime.SlabAllocator.generationOf(event);
    defer event.releaseIfUnwrapped(generation);
    interfaces.Event.call_initEvent(event, runtime.DOMString.initInterned("beforeunload"), webidl.Opt(bool).passed(false), webidl.Opt(bool).passed(true)) catch return .{};
    const not_canceled = @import("EventTarget.zig").dispatchTrusted(window, event) catch true;
    // Step 6's condition, less sticky activation: "eventFiringResult is
    // false, or the returnValue attribute of event is not the empty string".
    const return_value = interfaces.BeforeUnloadEvent.get_returnValue(event) catch runtime.DOMString.initEmpty();
    return .{ .prompt_requested = !not_canceled or return_value.asSlice().len > 0 };
}

/// dom.document_lifecycle: "unload" `document` (HTML §7.5.9) with no new
/// document given - the unload timing info is not modelled - from a task.
///
/// Step 5: Crane keeps no document alive for history traversal, so
/// intendToKeepInBfcache is false and the document is not salvageable.
/// Steps 16 and 18-20 (suspended timers, cleanup steps, destroy) are the
/// navigable's: navigation clears the window's timers once this returns.
fn lifecycleUnload(document: *runtime.Instance) void {
    const internal = getInternal(document) orelse return;
    const window = (get_defaultView(document) catch null) orelse return;
    const scope = @import("v8").JsScope.init(document.ctx) orelse return;
    defer scope.deinit();

    // Step 7: "Increase eventLoop's termination nesting level by 1"; step 14
    // lowers it after the unload event.
    const termination_nesting = @import("html_core").navigation.termination_nesting;
    termination_nesting.enter();
    var terminating = true;
    defer if (terminating) termination_nesting.leave();
    // Step 8: "Increase oldDocument's unload counter by 1." Step 21 lowers
    // it - document.open() is ignored in between (§8.4.1 step 5).
    internal.unload_counter += 1;
    defer internal.unload_counter -= 1;
    // Step 9: intendToKeepInBfcache is false, so not salvageable.
    internal.salvageable = false;
    // Step 10: pagehide and hidden, if the page was showing.
    if (internal.page_showing) {
        internal.page_showing = false;
        firePageTransition(document, window, "pagehide", internal.salvageable);
        updateVisibilityState(document, ._hidden_);
    }
    // Step 12: "If oldDocument's salvageable state is false, then fire an
    // event named unload at oldDocument's relevant global object, with legacy
    // target override flag set." The override is not modelled.
    if (!internal.salvageable) fireEvent(document, window, "unload", false);
    // Step 14.
    termination_nesting.leave();
    terminating = false;
}

/// Page Visibility "update the visibility state" of `document`.
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#update-the-visibility-state
fn updateVisibilityState(document: *runtime.Instance, state: enums.DocumentVisibilityState) void {
    const internal = getInternal(document) orelse return;
    // Step 1: "If document's visibility state equals visibilityState, then return."
    if (internal.visibility_state == state) return;
    // Step 2: set it.
    internal.visibility_state = state;
    internal.hidden = state == ._hidden_;
    // Step 6: "Fire an event named visibilitychange at document, with its
    // bubbles attribute initialized to true."
    fireEvent(document, document, "visibilitychange", true);
}

const LifecycleStep = enum { dom_content_loaded, load, container_load };

const LifecycleTask = struct {
    allocator: std.mem.Allocator,
    target: *runtime.Instance,
    generation: u64,
    step: LifecycleStep,
};

fn queueLifecycleTask(target: *runtime.Instance, step: LifecycleStep) void {
    const allocator = target.ctx.allocator;
    const task = allocator.create(LifecycleTask) catch return;
    task.* = .{
        .allocator = allocator,
        .target = target,
        .generation = runtime.SlabAllocator.generationOf(target),
        .step = step,
    };
    const loop = target.ctx.getOptionalEventLoop() orelse {
        // No loop to queue on (a context built for tests): the events are
        // still owed, so fire them now rather than lose them.
        runLifecycleTask(task);
        return;
    };
    loop.queueTask(.{ .callback = &runLifecycleTask, .context = task, .drop = &dropLifecycleTask });
}

fn dropLifecycleTask(context: ?*anyopaque) void {
    const task: *LifecycleTask = @ptrCast(@alignCast(context orelse return));
    task.allocator.destroy(task);
}

fn runLifecycleTask(context: ?*anyopaque) void {
    const task: *LifecycleTask = @ptrCast(@alignCast(context orelse return));
    defer task.allocator.destroy(task);
    // Collected and its slot reissued: nothing is left to finish loading.
    if (runtime.SlabAllocator.generationOf(task.target) != task.generation) return;
    // A task runs from the event loop, not from V8, so it opens the scope and
    // enters the context an event needs.
    const scope = @import("v8").JsScope.init(task.target.ctx) orelse return;
    defer scope.deinit();

    // The event loop runs only a task whose document is fully active: a
    // navigation that replaced the document before its "the end" ran leaves
    // those tasks nothing to do. Running them fired a second load at the
    // frame's container, for a document the frame no longer shows.
    switch (task.step) {
        .dom_content_loaded, .load => if (!isShownByItsWindow(task.target)) return,
        .container_load => {},
    }

    switch (task.step) {
        // Step 6.2: "Fire an event named DOMContentLoaded at the Document
        // object, with its bubbles attribute initialized to true."
        .dom_content_loaded => fireEvent(task.target, task.target, "DOMContentLoaded", true),
        .load => completeLoading(task.target),
        // "Completely finish loading" step 4: the container's load event
        // steps - the iframe's own (dom.content_navigables), which end the
        // delay its navigation put on its node document's load event; step
        // 5 for any other container: "fire an event named load at element".
        .container_load => if (!@import("dom").content_navigables.runLoadEventSteps(task.target)) {
            fireEvent(task.target, task.target, "load", false);
        },
    }
}

/// Whether `document` is still its window's document - false once a
/// navigation has put another in its place. A document with no window is
/// not replaced by anything.
///
/// A navigation that makes a new Window leaves the old one's document in
/// place, so asking the Window is not enough: an unloaded document - not
/// salvageable, since Crane keeps no bfcache - is never fully active again.
fn isShownByItsWindow(document: *runtime.Instance) bool {
    if (getInternal(document)) |internal| {
        if (!internal.salvageable) return false;
    }
    const window = (get_defaultView(document) catch null) orelse return true;
    const shown = interfaces.Window.get_document(window) catch return true;
    return shown == document;
}

/// "The end" step 9's task: readiness "complete", load at the window,
/// pageshow, and the container's load.
fn completeLoading(document: *runtime.Instance) void {
    // Step 9.1: "Update the current document readiness to "complete"."
    updateReadiness(document, ._complete_);
    // Steps 9.2-9.3: no browsing context, nothing more.
    const window = (get_defaultView(document) catch null) orelse return;
    // Step 9.5: "Fire an event named load at window".
    fireEvent(document, window, "load", false);
    // Steps 9.9-9.11: page showing becomes true and pageshow fires,
    // persisted false - unless the document is showing already.
    const internal = getInternal(document) orelse return;
    if (!internal.page_showing) {
        internal.page_showing = true;
        firePageShow(document, window);
    }
    // Step 9.12: "completely finish loading". Its step 2 sets the completely
    // loaded time; step 4 queues the container's load event (the iframe load
    // event steps).
    internal.completely_loaded = true;
    if (@import("dom").navigable_container.of(window)) |container| {
        queueLifecycleTask(container, .container_load);
    }
}

/// Fire an event named `event_type` at `target`, created in `realm_of`'s
/// realm - the user agent's, so trusted (DOM 2.10).
fn fireEvent(realm_of: *runtime.Instance, target: *runtime.Instance, event_type: []const u8, bubbles: bool) void {
    fireEventWith(realm_of, target, event_type, .{ .bubbles = bubbles });
}

fn fireEventWith(realm_of: *runtime.Instance, target: *runtime.Instance, event_type: []const u8, init_dict: dictionaries.EventInit) void {
    const event = interfaces.Event.call_constructor(
        realm_of.ctx,
        runtime.DOMString.initInterned(event_type),
        webidl.Opt(dictionaries.EventInit).passed(init_dict),
    ) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    _ = @import("EventTarget.zig").dispatchTrusted(target, event) catch {};
    // A listener that kept the event keeps it alive; otherwise it is done.
    event.releaseIfUnwrapped(generation);
}

/// "Fire a page transition event named pageshow at window with persisted"
/// false.
fn firePageShow(document: *runtime.Instance, window: *runtime.Instance) void {
    firePageTransition(document, window, "pageshow", false);
}

/// "Fire a page transition event named `event_type` at window with
/// `persisted`".
fn firePageTransition(document: *runtime.Instance, window: *runtime.Instance, event_type: []const u8, persisted: bool) void {
    const event = interfaces.PageTransitionEvent.call_constructor(
        document.ctx,
        runtime.DOMString.initInterned(event_type),
        webidl.Opt(dictionaries.PageTransitionEventInit).passed(.{ .base = .{}, .persisted = persisted }),
    ) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    _ = @import("EventTarget.zig").dispatchTrusted(window, event) catch {};
    event.releaseIfUnwrapped(generation);
}

/// Operation: requestStorageAccess
pub fn call_requestStorageAccess(instance: *runtime.Instance) anyerror!runtime.JSValue {
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
pub fn call_createElementNS(instance: *runtime.Instance, namespace: ?runtime.DOMString, qualifiedName: runtime.DOMString, options: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
    _ = options; // TODO: Handle ElementCreationOptions (custom elements)

    // DOM 4.5 "internal createElementNS steps" step 1: "Let (namespace,
    // prefix, localName) be the result of validating and extracting namespace
    // and qualifiedName given "element"."
    const extracted = try names.validateAndExtract(
        if (namespace) |ns| ns.asSlice() else null,
        qualifiedName.asSlice(),
        .element,
    );

    // Step 5: "Return the result of creating an element given document,
    // localName, namespace, prefix, is, and true."
    return createAnElement(instance, extracted.local_name, extracted.namespace, extracted.prefix);
}

/// Operation: captureEvents
pub fn call_captureEvents(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: browsingTopics
pub fn call_browsingTopics(instance: *runtime.Instance, options: webidl.Opt(dictionaries.BrowsingTopicsOptions)) anyerror!runtime.JSValue {
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
    // The binding hands a callback argument over: the iterator owns it from
    // here and releases it in its deinit.
    const filter_wrapper: ?*runtime.CallbackWrapper = if (filter.was_passed) (filter.value orelse null) else null;

    // Step 1: Create NodeIterator
    // Use interface instead of impl (per Golden Rule #13)
    const iterator = try interfaces.NodeIterator.init(internal.allocator, instance.ctx);
    errdefer interfaces.NodeIterator.deinit(iterator);

    // Steps 2-6: the iterator's own state, set through dom.traversal.
    const what_to_show: u32 = if (whatToShow.was_passed) whatToShow.value else 0xFFFFFFFF;
    try traversal.setUpNodeIterator(iterator, root, what_to_show, filter_wrapper, instance);

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
    try internal.scripts_to_execute_asap.append(internal.allocator, script);
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
    try internal.scripts_to_execute_in_order_asap.append(internal.allocator, script);
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
    try internal.scripts_to_execute_when_parsing_finished.append(internal.allocator, script);
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

// =============================================================================
// Document Write / Parsing State Management (HTML Standard §8.4)
// =============================================================================

/// Get the current insertion point
/// Spec: https://html.spec.whatwg.org/multipage/parsing.html#insertion-point
///
/// Returns null if parsing has finished or not started.
pub fn getInsertionPoint(instance: *runtime.Instance) ?usize {
    const internal = getInternal(instance) orelse return null;
    return internal.insertion_point;
}

/// Set the insertion point (called when parser starts/updates position)
/// Spec: https://html.spec.whatwg.org/multipage/parsing.html#insertion-point
pub fn setInsertionPoint(instance: *runtime.Instance, position: ?usize) void {
    if (getInternal(instance)) |internal| {
        internal.insertion_point = position;
    }
}

/// Clear the insertion point (called when parsing finishes)
pub fn clearInsertionPoint(instance: *runtime.Instance) void {
    if (getInternal(instance)) |internal| {
        internal.insertion_point = null;
    }
}

/// Check if parsing is currently active (insertion point is defined)
pub fn isParsingActive(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    return internal.insertion_point != null;
}

/// Set the InputStreamManager for document.write() during parsing
/// Called by HTMLParser when starting to parse with scripting enabled.
pub fn setInputStreamManager(instance: *runtime.Instance, manager: ?*html_core.parser.document_write.InputStreamManager) void {
    if (getInternal(instance)) |internal| {
        internal.input_stream_manager = manager;
    }
}

/// Get the InputStreamManager (for document.write() during parsing)
pub fn getInputStreamManager(instance: *runtime.Instance) ?*html_core.parser.document_write.InputStreamManager {
    const internal = getInternal(instance) orelse return null;
    return internal.input_stream_manager;
}

/// Increment throw-on-dynamic-markup-insertion counter
/// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#throw-on-dynamic-markup-insertion-counter
/// Called during custom element reactions and other contexts where dynamic markup is not allowed.
pub fn incrementThrowOnDynamicMarkupInsertionCounter(instance: *runtime.Instance) void {
    if (getInternal(instance)) |internal| {
        internal.throw_on_dynamic_markup_insertion_counter += 1;
    }
}

/// Decrement throw-on-dynamic-markup-insertion counter
pub fn decrementThrowOnDynamicMarkupInsertionCounter(instance: *runtime.Instance) void {
    if (getInternal(instance)) |internal| {
        if (internal.throw_on_dynamic_markup_insertion_counter > 0) {
            internal.throw_on_dynamic_markup_insertion_counter -= 1;
        }
    }
}

/// Increment unload counter
/// Spec: https://html.spec.whatwg.org/multipage/browsing-the-web.html#unload-counter
/// Called during beforeunload/unload event handling
pub fn incrementUnloadCounter(instance: *runtime.Instance) void {
    if (getInternal(instance)) |internal| {
        internal.unload_counter += 1;
    }
}

/// Decrement unload counter
pub fn decrementUnloadCounter(instance: *runtime.Instance) void {
    if (getInternal(instance)) |internal| {
        if (internal.unload_counter > 0) {
            internal.unload_counter -= 1;
        }
    }
}

/// Abort the active parser (e.g., due to navigation)
/// Spec: https://html.spec.whatwg.org/multipage/parsing.html#abort-a-parser
pub fn abortParser(instance: *runtime.Instance) void {
    if (getInternal(instance)) |internal| {
        internal.active_parser_was_aborted = true;
        internal.insertion_point = null;
        internal.input_stream_manager = null;
    }
}

/// Check if the active parser was aborted
pub fn wasParserAborted(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    return internal.active_parser_was_aborted;
}

/// Get the write buffer content (for document.write() in after-parsing mode)
pub fn getWriteBuffer(instance: *runtime.Instance) []const u8 {
    const internal = getInternal(instance) orelse return "";
    return internal.write_buffer.items;
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
        // Dispose the old module handle using stored function pointer
        // (null if no JS engine configured, e.g., in stub test mode)
        if (internal.dispose_module_fn) |dispose_fn| {
            dispose_fn(old_module);
        }
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

/// Set the module disposal function for this document
/// Called when a JS engine is configured to enable proper module cleanup.
/// Without this, modules won't be disposed (acceptable in stub test mode).
pub fn setModuleDisposeFunction(instance: *runtime.Instance, dispose_fn: ?*const fn (*anyopaque) void) void {
    if (getInternal(instance)) |internal| {
        internal.dispose_module_fn = dispose_fn;
    }
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
        const directive = csp.fallback.getEffectiveScriptSrcElem(policy) orelse continue;

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
        const directive = csp.fallback.getEffectiveScriptSrcElem(policy) orelse continue;

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

// =============================================================================
// Stylesheet Blocking (HTML Standard §14.3.3)
// =============================================================================

/// Check if document has a style sheet that is blocking scripts
/// Spec: https://html.spec.whatwg.org/multipage/semantics.html#has-a-style-sheet-that-is-blocking-scripts
///
/// "A Document has a style sheet that is blocking scripts if it has a
/// pending parsing-blocking style sheet or a pending render-blocking element."
///
/// This should be called before executing parser-inserted scripts per
/// HTML Standard §4.12.1.1 step 36.2.
pub fn hasStyleSheetBlockingScripts(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    return internal.stylesheet_tracker.hasBlockingStylesheet();
}

/// Get the stylesheet blocking tracker for direct manipulation
/// Used by HTMLParser and link element processing to track stylesheet loads.
pub fn getStylesheetTracker(instance: *runtime.Instance) ?*StylesheetBlockingTracker {
    const internal = getInternal(instance) orelse return null;
    return &internal.stylesheet_tracker;
}

/// Add a stylesheet to the blocking tracker
/// Spec: HTML Standard § 4.2.4 "A link element that creates a style sheet"
///
/// Call this when a parser-inserted stylesheet link element starts loading.
/// The id parameter should be unique (typically the resolved URL).
pub fn addBlockingStylesheet(
    instance: *runtime.Instance,
    id: []const u8,
    url: []const u8,
    is_blocking: bool,
) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try internal.stylesheet_tracker.addStylesheet(id, url, is_blocking);
}

/// Mark a stylesheet as loaded
/// Call this when a stylesheet finishes loading successfully.
/// This may unblock pending script execution.
pub fn markStylesheetLoaded(instance: *runtime.Instance, id: []const u8) void {
    const internal = getInternal(instance) orelse return;
    internal.stylesheet_tracker.markLoaded(id);
}

/// Mark a stylesheet as failed
/// Call this when a stylesheet fails to load (network error, 404, etc.).
/// Per spec, failed stylesheets should unblock scripts to prevent permanent hangs.
pub fn markStylesheetFailed(instance: *runtime.Instance, id: []const u8) void {
    const internal = getInternal(instance) orelse return;
    internal.stylesheet_tracker.markFailed(id);
}

/// Remove a stylesheet from tracking
/// Call this when a link element is removed from the document.
pub fn removeBlockingStylesheet(instance: *runtime.Instance, id: []const u8) void {
    const internal = getInternal(instance) orelse return;
    internal.stylesheet_tracker.removeStylesheet(id);
}

/// Get the count of blocking stylesheets
/// Useful for debugging and determining if scripts are being blocked.
pub fn getBlockingStylesheetCount(instance: *runtime.Instance) usize {
    const internal = getInternal(instance) orelse return 0;
    return internal.stylesheet_tracker.getBlockingCount();
}

/// Set callback for when all blocking stylesheets are resolved
/// This callback is invoked when the blocking count reaches zero.
/// Can be used to resume deferred script execution.
pub fn setStylesheetBlockingResolvedCallback(
    instance: *runtime.Instance,
    callback: StylesheetBlockingTracker.BlockingResolvedCallback,
    context: ?*anyopaque,
) void {
    const internal = getInternal(instance) orelse return;
    internal.stylesheet_tracker.setBlockingResolvedCallback(callback, context);
}

// =============================================================================
// Named Property Access (HTML Standard § 7.3.3)
// =============================================================================

/// Get the supported property names for named property access.
/// Per HTML spec, documents expose named elements (name/id attributes) as properties.
/// This is used by the named property enumerator for Object.keys(document).
///
/// TODO: Implement proper named element collection per HTML spec.
/// Currently returns empty array to avoid breaking compilation.
pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {
    _ = instance;
    _ = allocator;
    // TODO: Return names of elements with name/id attributes that are
    // accessible via document.name syntax per HTML spec § 7.3.3
    return &.{};
}

/// Named property getter for accessing elements by name/id.
/// Per HTML spec § 7.3.3, documents expose named elements as properties.
/// For example: document.myForm returns the form with name="myForm" or id="myForm".
///
/// TODO: Implement proper named element access per HTML spec.
/// Currently returns null to indicate property not found.
pub fn call_getter(instance: *runtime.Instance, name: runtime.DOMString) anyerror!runtime.JSValue {
    _ = instance;
    _ = name;
    // TODO: Implement HTML spec § 7.3.3 named element access
    // Should return the element with matching name/id, or HTMLCollection if multiple
    return .null;
}

/// Clean up ALL remaining internal states.
pub fn cleanupAllRemainingInternal() void {
    Registry.deinitAllAndClear();
}
