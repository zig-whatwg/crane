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
const engine = @import("engine");
const dom_creation = @import("dom").node_creation;
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const url_mod = @import("url");
const Document = interfaces.Document;

// Use shared InstanceRegistry utility for internal state management
const utils = webidl.utils;
const Registry = utils.InstanceRegistry(InternalState);

// Import impls ONLY for internal initialization methods not exposed via interfaces
const NodeImpl = @import("Node.zig");
const EventTargetImpl = @import("EventTarget.zig");
const EventImpl = @import("Event.zig");
const ProcessingInstructionImpl = @import("ProcessingInstruction.zig");
const RangeImpl = @import("Range.zig");
const SelectionImpl = @import("Selection.zig");
const same_object = @import("same_object.zig");

// Import ParentNode mixin for shared ParentNode interface methods
const mixins = @import("mixins");

// Content Security Policy
const csp = @import("csp");
const fetch = @import("fetch");

// HTML module for stylesheet blocking and editing
const html_core = @import("html_core");
const range_boundaries = @import("dom").range_boundaries;
const names = @import("dom").names;
const attr_nodes = @import("dom").attr_nodes;
const traversal = @import("dom").traversal;
const live_collections = @import("dom").live_collections;
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

/// A document's mode.
///
/// Spec: https://dom.spec.whatwg.org/#concept-document-mode
/// "Each document has an associated ... mode ("no-quirks", "quirks", or
///  "limited-quirks")." "Unless stated otherwise, a document's ... mode is
///  "no-quirks"." Limited-quirks is recorded although nothing here reads it
///  yet: a CSS or layout host does.
pub const Mode = enum {
    no_quirks,
    quirks,
    limited_quirks,
};

/// Speculation rule eagerness levels - defined with the hook html's script
/// processing model hands prefetch hints through.
/// Spec: https://html.spec.whatwg.org/multipage/speculative-loading.html#speculation-rule-eagerness
pub const SpeculationEagerness = @import("dom").document_scripts.SpeculationEagerness;

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

    /// The document's mode (DOM): set by the HTML parser's "initial"
    /// insertion mode, by document.open(), and by the Document's creator.
    mode: Mode = .no_quirks,

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
    /// HTML "iframe load in progress": set while the iframe load event steps
    /// fire load at the iframe whose content navigable shows this document
    /// (steps 5-7).
    iframe_load_in_progress: bool = false,
    /// HTML "mute iframe load": the document was opened (document open steps
    /// step 14) while its iframe load was in progress, and the iframe load
    /// event steps fire no load for it (step 3).
    mute_iframe_load: bool = false,
    /// HTML "salvageable"; set false by "unload" (Crane keeps no bfcache).
    salvageable: bool = true,
    /// HTML "destroy" has run: the document's browsing context is null. It
    /// stays readable - script elsewhere may hold it - but has no view.
    destroyed: bool = false,
    /// HTML "about base URL": the document base URL of the document that
    /// created it, or of the navigation's source document, for an
    /// about:blank or about:srcdoc document; null otherwise. Owned.
    about_base_url: ?[]u8 = null,
    /// "The end" is waiting at step 8 - something delays the load event -
    /// and has not queued step 9's task yet.
    load_waiting_on_delay: bool = false,
    /// HTML "delay the load event": how many delays are held on this
    /// document's load event (dom.document_lifecycle.delayLoadEvent) - an
    /// object element's fetch, say. Blink's load_event_delay_count_.
    load_event_delay_count: u32 = 0,
    /// HTML 7.4.6.4 "target element": what :target matches, set by "scroll
    /// to the fragment"; initially null. A weak link - the element can be
    /// removed and freed while it is the target (dom.target_element).
    target_element: ?@import("same_object.zig").Link = null,
    /// HTML "will declaratively refresh": the shared declarative refresh
    /// steps have run to step 12 for this document.
    will_declaratively_refresh: bool = false,
    /// The refresh those steps set up, until it comes due (or the document
    /// goes, which cancels it). Owned.
    declarative_refresh: ?*DeclarativeRefresh = null,

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

    /// Document dir (text direction: "ltr", "rtl", or "")
    dir: runtime.DOMString,

    /// The document's origin's domain (HTML 7.1.1.2), serialized: what the
    /// document.domain setter set. Empty while it is null. Owned.
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
    /// `active_element`'s slab generation when it was designated
    /// (dom.focused_area.Designation): a removed element can be collected
    /// while the document still names it.
    active_element_generation: u64 = 0,

    // === StyleSheetList (DocumentOrShadowRoot mixin) ===
    style_sheets: ?*runtime.Instance,
    /// `style_sheets` and its wrapper, for as long as this document lives:
    /// see `KeptChild`.
    style_sheets_kept: KeptChild = .{},

    // === Script execution state (HTML Standard §4.12.1.1) ===

    /// The pending parsing-blocking script, the three script lists,
    /// currentScript and the ignore-destructive-writes counter - reached by
    /// html's script processing model through dom.document_scripts, which
    /// this impl installs.
    scripts: dom_document_scripts.Scripts,

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

    /// The document's policy container (HTML 7.1.6): a new one until a
    /// navigation gives it the one "determine navigation params policy
    /// container" chose ("create and initialize a Document object" step 9),
    /// or a meta element named referrer changes its referrer policy. Owned;
    /// every request the document's settings object makes takes a clone.
    /// Reached from outside through `dom.policy_containers`.
    policy_container: fetch.internal.PolicyContainer,

    // === Content Security Policy (CSP Level 3) ===
    // The CSP list is the policy container's (`policy_container.csp_list`).

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
    /// `selection` and its wrapper, for as long as this document lives: see
    /// `KeptChild`.
    selection_kept: KeptChild = .{},

    // === Adopted Style Sheets (CSSOM) ===

    /// Adopted style sheets (ObservableArray exotic object)
    /// Spec: https://drafts.csswg.org/cssom/#dom-documentorshadowroot-adoptedstylesheets
    /// Stored as V8 handle pointer (Proxy object), not a runtime.Instance
    adopted_style_sheets: ?*anyopaque,

    /// Cached FontFaceSet instance ([SameObject])
    /// Spec: https://drafts.csswg.org/css-font-loading/#dom-fontfacesource-fonts
    fonts: ?*runtime.Instance,
    /// `fonts` and its wrapper, for as long as this document lives: see
    /// `KeptChild`.
    fonts_kept: KeptChild = .{},

    /// Cached HTMLAllCollection instance ([SameObject])
    /// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-all
    /// This collection has [[IsHTMLDDA]] internal slot (undetectable)
    all_collection: ?*runtime.Instance,
    /// `all_collection` and its wrapper, for as long as this document lives:
    /// see `KeptChild`.
    all_collection_kept: KeptChild = .{},

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
            .encoding = runtime.DOMString.initInterned("UTF-8"), // DOM: "unless stated otherwise, a document's encoding is the utf-8 encoding"
            .ready_state = ._loading_,
            .document_element = null,
            .doctype = null,
            .ranges = .empty,
            .node_iterators = .empty,
            // HTML properties
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
            // Script execution state
            .scripts = dom_document_scripts.Scripts.init(allocator),
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
            .policy_container = fetch.internal.PolicyContainer.init(allocator),
            // CSP
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
        if (self.about_base_url) |url| {
            self.allocator.free(url);
            self.about_base_url = null;
        }
        // A refresh still waiting must not fire into a freed document.
        if (self.declarative_refresh) |refresh| {
            self.declarative_refresh = null;
            refresh.cancel();
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
        self.dir.deinit(self.allocator);
        self.design_mode.deinit(self.allocator);
        self.fg_color.deinit(self.allocator);
        self.link_color.deinit(self.allocator);
        self.vlink_color.deinit(self.allocator);
        self.alink_color.deinit(self.allocator);
        self.bg_color.deinit(self.allocator);

        // Event handlers

        // Write buffer (for document.write() in after-parsing mode)
        self.write_buffer.deinit(self.allocator);

        // Note: input_stream_manager is NOT owned by Document - it's owned by HTMLParser
        // and is just a reference here for document.write() integration

        // Script execution lists (don't own the script elements, just the list storage)
        self.scripts.deinit();

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

        self.policy_container.deinit();

        // CSP origin (the list is the policy container's)
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

        // The objects this document handed out as the same object for its
        // whole life: each is severed from it here (see `KeptChild`).
        if (self.all_collection) |all| self.all_collection_kept.release(all, interfaces.HTMLAllCollection.deinit);
        if (self.fonts) |fonts_inst| self.fonts_kept.release(fonts_inst, interfaces.FontFaceSet.deinit);
        if (self.selection) |sel| self.selection_kept.release(sel, interfaces.Selection.deinit);
        if (self.style_sheets) |ss| self.style_sheets_kept.release(ss, interfaces.StyleSheetList.deinit);
    }
};

/// An object the document makes once, keeps in its own state and hands out as
/// the same object for its whole life - getSelection()'s Selection,
/// document.all, document.fonts, document.styleSheets - kept alive from the
/// first hand-out until the document goes. One mechanism with Element's
/// shadow root: see `same_object.KeptChild`.
const KeptChild = same_object.KeptChild;

/// Get the internal state from an instance
/// Made public for use by HTMLParser, DOMParser, and other modules that need
/// access to document internals for DOM construction.
pub fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

/// dom.policy_containers: `document`'s policy container.
fn policyContainerOf(document: *runtime.Instance) ?*fetch.internal.PolicyContainer {
    const internal = getInternal(document) orelse return null;
    return &internal.policy_container;
}

/// Get the Node internal state from a Document instance
/// Uses the registry pattern for proper inheritance chain
pub fn getNodeInternal(instance: *runtime.Instance) ?*NodeImpl.InternalState {
    return NodeImpl.getInternalState(instance);
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
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
        .abort = &lifecycleAbort,
        .destroy = &lifecycleDestroy,
        .set_about_base_url = &lifecycleSetAboutBaseUrl,
        .about_fallback_base_url = &lifecycleAboutFallbackBaseUrl,
        .declarative_refresh = &lifecycleDeclarativeRefresh,
        .set_iframe_load_in_progress = &lifecycleSetIframeLoadInProgress,
        .is_iframe_load_muted = &lifecycleIsIframeLoadMuted,
        .delay_load_event = &lifecycleDelayLoadEvent,
        .undelay_load_event = &lifecycleUndelayLoadEvent,
    });
    @import("dom").document_origin.install(.{ .domain = &originDomain });
    // Its policy container, for whatever sets or reads one without naming
    // this impl (navigation, meta referrer, a Window's settings object).
    @import("dom").policy_containers.install(.{ .of = &policyContainerOf });
    // A clone of a Document keeps its mode. Installed here, before any
    // Document exists to be cloned.
    @import("dom").cloning_steps.install(&cloningSteps);
    // The target element :target matches and "scroll to the fragment" sets.
    @import("dom").target_element.install(.{ .get = &targetElement, .set = &setTargetElement });
    // User input (testdriver lane): the focusing steps designate a document's
    // focused area (src/html/focus.zig), and a top-level traversable's system
    // visibility state updates its documents' visibility state, through these
    // hooks.
    @import("dom").focused_area.install(.{ .get = &focusedArea, .set = &setFocusedArea });
    @import("dom").visibility_state.install(.{ .update = &updateVisibilityStateFromHook });
    // The selector matchers ask whether an element matches :focus,
    // :focus-within and :focus-visible through this one (html.focus, which
    // applies the focus fixup rule as activeElement does).
    const focus = @import("html").focus;
    @import("dom").focus_matching.install(.{
        .matches_focus = &focus.matchesFocus,
        .matches_focus_within = &focus.matchesFocusWithin,
        .matches_focus_visible = &focus.matchesFocusVisible,
    });
    // html's script processing model reaches a document's script state.
    installScriptHooks();
    // The event loop runs a task only while its document is fully active.
    @import("dom").document_activity.install(.{ .fully_active = &isFullyActive });
}

/// dom.document_activity: whether a task's document is fully active - "the
/// active document of a navigable navigable, and either navigable is a
/// top-level traversable or navigable's container document is fully
/// active". A document that was unloaded (not salvageable: Crane keeps no
/// bfcache) or destroyed is no navigable's active document; nor is one whose
/// window is no navigable's active window any more, or whose navigable shows
/// another. Removing a frame discards its navigable and every one inside it
/// (BrowsingContext.discard closes them all), so the container documents
/// need no walk. A document with no window (createHTMLDocument, DOMParser)
/// is not fully active.
///
/// A global task on a Window names the Window: its associated Document when
/// the task runs is the one asked about (see runtime.EventLoopTask.document).
///
/// The navigable's own record, not `Window.document`: the event loop asks
/// with no script running, and the getter's cross-origin check would answer
/// for whichever realm happens to be current - a message to a cross-origin
/// or sandboxed frame was dropped that way (the lesson "A frame's load event
/// has exactly one owner": engine code must not use script's getters).
fn isFullyActive(object: *runtime.Instance) bool {
    if (object.stateAs(interfaces.Window.State) != null) {
        const navigable = html_core.window.BrowsingContext.ofWindow(@ptrCast(object)) orelse return false;
        if (navigable.is_closed) return false;
        const active = navigable.active_document orelse return true;
        return isActiveDocumentFullyActive(@ptrCast(@alignCast(active)));
    }
    const internal = getInternal(object) orelse return false;
    if (internal.destroyed or !internal.salvageable) return false;
    const window = internal.default_view orelse return false;
    const navigable = html_core.window.BrowsingContext.ofWindow(@ptrCast(window)) orelse return false;
    if (navigable.is_closed) return false;
    const active = navigable.active_document orelse return true;
    return active == @as(*anyopaque, @ptrCast(object));
}

/// A navigable's active document, as its own state says: neither unloaded nor
/// destroyed.
fn isActiveDocumentFullyActive(document: *runtime.Instance) bool {
    const internal = getInternal(document) orelse return false;
    return !internal.destroyed and internal.salvageable;
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

    return instance;
}

/// dom.target_element: `document`'s target element, or null once the
/// element it names has been freed.
fn targetElement(document: *runtime.Instance) ?*runtime.Instance {
    const internal = getInternal(document) orelse return null;
    const link = internal.target_element orelse return null;
    return if (link.isLive()) link.instance else null;
}

/// dom.target_element: "set document's target element to" `element`.
fn setTargetElement(document: *runtime.Instance, element: ?*runtime.Instance) void {
    const internal = getInternal(document) orelse return;
    internal.target_element = if (element) |e| @import("same_object.zig").Link.to(e) else null;
}

/// dom.focused_area: `document`'s focused area, or null for its viewport.
fn focusedArea(document: *runtime.Instance) ?@import("dom").focused_area.Designation {
    const internal = getInternal(document) orelse return null;
    const element = internal.active_element orelse return null;
    return .{ .element = element, .generation = internal.active_element_generation };
}

/// dom.focused_area: designate an element (null: the viewport) as
/// `document`'s focused area.
fn setFocusedArea(document: *runtime.Instance, designation: ?@import("dom").focused_area.Designation) void {
    const internal = getInternal(document) orelse return;
    internal.active_element = if (designation) |d| d.element else null;
    internal.active_element_generation = if (designation) |d| d.generation else 0;
}

/// dom.visibility_state: "update the visibility state" of `document`.
fn updateVisibilityStateFromHook(document: *runtime.Instance, state: @import("dom").visibility_state.State) void {
    if (getInternal(document) == null) return;
    updateVisibilityState(document, switch (state) {
        .visible => ._visible_,
        .hidden => ._hidden_,
    });
}

/// DOM "clone a single node" step 3.1, for a Document: "set copy's encoding,
/// content type, URL, origin, type, and mode to those of node". This copies
/// the encoding and the mode; the rest are Node.zig's stated deviation.
/// (Installed through dom.cloning_steps, as Node's clone algorithm may not
/// reach Document's state; a no-op for any other node.)
fn cloningSteps(node: *runtime.Instance, copy: *runtime.Instance, subtree: bool) anyerror!void {
    _ = subtree;
    const source = getInternal(node) orelse return;
    const target = getInternal(copy) orelse return;
    const encoding = try source.encoding.clone(target.allocator);
    target.encoding.deinit(target.allocator);
    target.encoding = encoding;
    target.mode = source.mode;
}

/// Get Document's internal state from the registry
/// Alias for getInternal for backward compatibility
pub fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

/// Set the engine's wrapper for this Document (created in the Document's
/// owning realm). This should be called immediately after creating the
/// Document, before returning it to any other realm. The wrapper ensures
/// cross-realm access works correctly.
pub fn setBoundV8Wrapper(instance: *runtime.Instance, wrapper: *anyopaque) void {
    if (getInternalState(instance)) |internal| {
        internal.bound_v8_wrapper = wrapper;
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
    const url = instance.ctx.documentUrl() orelse return null;
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
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // HTML: "1. If this is in quirks mode, then return "BackCompat".
    // 2. Return "CSS1Compat"." (Limited-quirks is "CSS1Compat".)
    return runtime.DOMString.initInterned(if (internal.mode == .quirks) "BackCompat" else "CSS1Compat");
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

/// HTML document.domain's getter.
/// Spec: https://html.spec.whatwg.org/multipage/browsers.html#dom-document-domain
pub fn get_domain(instance: *runtime.Instance) anyerror!runtime.USVString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const allocator = instance.ctx.allocator;
    // 1. "Let effectiveDomain be this's origin's effective domain."
    // 2. "If effectiveDomain is null, then return the empty string."
    // 3. "Return effectiveDomain, serialized." (The binding frees it.)
    return (try effectiveDomain(instance, internal, allocator)) orelse try allocator.dupe(u8, "");
}

/// HTML "effective domain" of `document`'s origin, serialized: its domain
/// when the document.domain setter set one, else its host; null for an
/// opaque origin. OWNED by `allocator`.
fn effectiveDomain(document: *runtime.Instance, internal: *InternalState, allocator: std.mem.Allocator) !?[]u8 {
    if (internal.domain.len > 0) return try allocator.dupe(u8, internal.domain);
    const serialized = (try serializedOrigin(document, internal, allocator)) orelse return null;
    defer allocator.free(serialized);
    const host = hostOfSerializedOrigin(serialized) orelse return null;
    return try allocator.dupe(u8, host);
}

/// `document`'s origin, serialized - its window's (the relevant settings
/// object's) when it has one, else its URL's - or null for an opaque origin.
/// OWNED by `allocator`.
fn serializedOrigin(document: *runtime.Instance, internal: *InternalState, allocator: std.mem.Allocator) !?[]u8 {
    if (internal.default_view) |window| {
        // The getter's string is the window realm's to free.
        const serialized = try interfaces.Window.get_origin(window);
        defer window.ctx.allocator.free(serialized);
        if (std.mem.eql(u8, serialized, "null")) return null;
        return try allocator.dupe(u8, serialized);
    }
    const url = try get_URL(document);
    defer document.ctx.allocator.free(url);
    const parsed = (interfaces.URL.call_static_parse(document, url, webidl.Opt(runtime.USVString).notPassed()) catch null) orelse
        return null;
    defer runtime.Instance.deinit(parsed);
    const serialized = try interfaces.URL.get_origin(parsed);
    defer parsed.ctx.allocator.free(serialized);
    if (std.mem.eql(u8, serialized, "null")) return null;
    return try allocator.dupe(u8, serialized);
}

/// The host of a tuple origin's serialization ("scheme://host[:port]"): an
/// IPv6 address keeps its brackets. Null when it has no host.
fn hostOfSerializedOrigin(serialized: []const u8) ?[]const u8 {
    const start = (std.mem.indexOf(u8, serialized, "://") orelse return null) + 3;
    const rest = serialized[start..];
    if (rest.len == 0) return null;
    if (rest[0] == '[') return rest[0 .. (std.mem.indexOfScalar(u8, rest, ']') orelse return null) + 1];
    return rest[0 .. std.mem.indexOfScalar(u8, rest, ':') orelse rest.len];
}

/// HTML "is a registrable domain suffix of or is equal to":
/// `host_suffix_string` against `original_host` (a host, serialized).
fn isRegistrableDomainSuffixOfOrEqualTo(allocator: std.mem.Allocator, host_suffix_string: []const u8, original_host: []const u8) !bool {
    // 1. "If hostSuffixString is the empty string, then return false."
    if (host_suffix_string.len == 0) return false;
    // 2-3. "Let hostSuffix be the result of parsing hostSuffixString. If
    // hostSuffix is failure, then return false."
    const host_suffix = url_mod.host_parser.parseHost(allocator, host_suffix_string, false, null) catch return false;
    defer host_suffix.deinit(allocator);
    const original = url_mod.host_parser.parseHost(allocator, original_host, false, null) catch return false;
    defer original.deinit(allocator);
    const suffix_serialized = try url_mod.host_serializer.serializeHost(allocator, host_suffix);
    defer allocator.free(suffix_serialized);
    const original_serialized = try url_mod.host_serializer.serializeHost(allocator, original);
    defer allocator.free(original_serialized);

    // 4. "If hostSuffix does not equal originalHost, then:"
    if (!std.mem.eql(u8, suffix_serialized, original_serialized)) {
        // 4.1. "If hostSuffix or originalHost is not a domain, then return
        // false." (IP addresses.)
        if (host_suffix != .domain or original != .domain) return false;
        // 4.2. "If hostSuffix, prefixed by U+002E (.), does not match the end
        // of originalHost, then return false."
        if (!endsWithDotted(original_serialized, suffix_serialized)) return false;
        // 4.3. "If hostSuffix equals hostSuffix's public suffix; or
        // hostSuffix, prefixed by U+002E (.), matches the end of
        // originalHost's public suffix, then return false."
        const suffix_public = try url_mod.public_suffix.getPublicSuffix(allocator, host_suffix);
        defer if (suffix_public) |p| allocator.free(p);
        if (suffix_public) |p| {
            if (std.mem.eql(u8, p, suffix_serialized)) return false;
        }
        const original_public = try url_mod.public_suffix.getPublicSuffix(allocator, original);
        defer if (original_public) |p| allocator.free(p);
        if (original_public) |p| {
            if (endsWithDotted(p, suffix_serialized)) return false;
        }
    }
    // 5. "Return true."
    return true;
}

/// Whether `suffix`, prefixed by ".", matches the end of `host`.
fn endsWithDotted(host: []const u8, suffix: []const u8) bool {
    return host.len > suffix.len and std.mem.endsWith(u8, host, suffix) and host[host.len - suffix.len - 1] == '.';
}

/// dom.document_origin: `document`'s origin's domain, or null.
fn originDomain(document: *runtime.Instance) ?[]const u8 {
    const internal = getInternal(document) orelse return null;
    return if (internal.domain.len > 0) internal.domain else null;
}

/// Getter for referrer
/// HTML §7.5.2 - Returns the document's referrer
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-referrer
pub fn get_referrer(instance: *runtime.Instance) anyerror!runtime.USVString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Clone to transfer ownership to caller (interface layer will free)
    return try instance.ctx.allocator.dupe(u8, internal.referrer);
}

/// HTML document.cookie's getter: "" for a cookie-averse Document, a
/// SecurityError for an opaque origin, and otherwise the cookie-string for
/// the document's URL for a "non-HTTP" API - no HttpOnly cookie - UTF-8
/// decoded.
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-cookie
pub fn get_cookie(instance: *runtime.Instance) anyerror!runtime.USVString {
    const allocator = instance.ctx.allocator;
    var target = (try cookieTarget(instance)) orelse return allocator.dupe(u8, "");
    defer target.deinit();
    const cookie_string = try @import("cookiestore").http_integration.generateCookieHeader(allocator, target.jar, .{
        .host = target.parts.host,
        .path = target.parts.path,
        .is_http = false,
        .is_secure = target.parts.secure,
        // TODO: the same-site mode of the document - "strict-or-less" until
        //       fetch has "same site" (fetch/algorithms/cookies.zig).
        .same_site = .strict_or_less,
    });
    if (std.unicode.utf8ValidateSlice(cookie_string)) return cookie_string;
    defer allocator.free(cookie_string);
    return utf8DecodeLossy(allocator, cookie_string);
}

/// What document.cookie reads and writes: the user agent's cookie jar and
/// the document's URL (`url` OWNED; `parts` point into it).
const CookieTarget = struct {
    jar: *@import("cookiestore").CookieJar,
    url: []const u8,
    parts: @import("cookiestore").RequestUrl,
    allocator: std.mem.Allocator,

    fn deinit(self: *CookieTarget) void {
        self.allocator.free(self.url);
    }
};

/// document.cookie's target for `document`, or null for a cookie-averse
/// Document - one whose browsing context is null, or whose URL's scheme is
/// not an HTTP(S) scheme - or one no user agent jar reaches. An opaque
/// origin is a SecurityError.
fn cookieTarget(document: *runtime.Instance) !?CookieTarget {
    const internal = getInternal(document) orelse return null;
    if (internal.destroyed) return null;
    const window = internal.default_view orelse return null;
    const allocator = document.ctx.allocator;
    const url = try get_URL(document);
    errdefer allocator.free(url);
    if (!std.ascii.startsWithIgnoreCase(url, "http:") and !std.ascii.startsWithIgnoreCase(url, "https:")) {
        allocator.free(url);
        return null;
    }
    const origin = (try serializedOrigin(document, internal, allocator)) orelse return error.SecurityError;
    allocator.free(origin);
    const jar = @import("dom").global_settings.cookieJarOf(window) orelse {
        allocator.free(url);
        return null;
    };
    const parts = @import("cookiestore").RequestUrl.of(url) orelse {
        allocator.free(url);
        return null;
    };
    return .{ .jar = jar, .url = url, .parts = parts, .allocator = allocator };
}

/// Encoding "UTF-8 decode without BOM" of `bytes`, as UTF-8: each invalid
/// sequence becomes U+FFFD. OWNED.
fn utf8DecodeLossy(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    var output: std.ArrayListUnmanaged(u8) = .empty;
    errdefer output.deinit(allocator);
    var i: usize = 0;
    while (i < bytes.len) {
        const length: usize = std.unicode.utf8ByteSequenceLength(bytes[i]) catch 0;
        const valid = length > 0 and i + length <= bytes.len and
            if (std.unicode.utf8Decode(bytes[i .. i + length])) |_| true else |_| false;
        if (valid) {
            try output.appendSlice(allocator, bytes[i .. i + length]);
            i += length;
        } else {
            try output.appendSlice(allocator, "\u{FFFD}");
            i += 1;
        }
    }
    return output.toOwnedSlice(allocator);
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

/// HTML `document.title`'s getter.
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#document.title
pub fn get_title(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = getInternal(instance) orelse return error.InvalidStateError;
    const allocator = instance.ctx.allocator;

    // Step 1: "If the document element is an SVG svg element, then let value
    // be the child text content of the first SVG title element that is a
    // child of the document element."
    // Step 2: "Otherwise, let value be the child text content of the title
    // element, or the empty string if the title element is null."
    const source: ?*runtime.Instance = if (svgDocumentElement(instance)) |svg|
        firstChildNamed(svg, svg_namespace, "title")
    else
        titleElementOf(instance);
    const value = if (source) |element| try childTextContent(allocator, element) else try allocator.dupe(u8, "");
    defer allocator.free(value);

    // Steps 3-4: "Strip and collapse ASCII whitespace in value. Return value."
    return runtime.DOMString.initOwned(try stripAndCollapseWhitespace(allocator, value));
}

const svg_namespace = "http://www.w3.org/2000/svg";

/// Whether `node` is an element in `namespace` whose local name is
/// `local_name`.
fn isElementNamed(node: *runtime.Instance, namespace: []const u8, local_name: []const u8) bool {
    if ((NodeImpl.getNodeType(node) orelse 0) != NodeImpl.NodeType.ELEMENT_NODE) return false;
    const allocator = node.ctx.allocator;
    var name = interfaces.Element.get_localName(node) catch return false;
    defer name.deinit(allocator);
    if (!std.mem.eql(u8, name.asSlice(), local_name)) return false;
    var element_namespace = (interfaces.Element.get_namespaceURI(node) catch return false) orelse return false;
    defer element_namespace.deinit(allocator);
    return std.mem.eql(u8, element_namespace.asSlice(), namespace);
}

/// The first child of `parent` that is an element in `namespace` named
/// `local_name`, or null.
fn firstChildNamed(parent: *runtime.Instance, namespace: []const u8, local_name: []const u8) ?*runtime.Instance {
    var child = NodeImpl.getFirstChild(parent);
    while (child) |c| : (child = NodeImpl.getNextSibling(c)) {
        if (isElementNamed(c, namespace, local_name)) return c;
    }
    return null;
}

/// The document element, if it is an SVG `svg` element.
fn svgDocumentElement(document: *runtime.Instance) ?*runtime.Instance {
    const element = documentElementOf(document) orelse return null;
    return if (isElementNamed(element, svg_namespace, "svg")) element else null;
}

/// HTML "the html element": the document element, if it is an html
/// element.
fn htmlElementOf(document: *runtime.Instance) ?*runtime.Instance {
    const element = documentElementOf(document) orelse return null;
    return if (isElementNamed(element, html_namespace, "html")) element else null;
}

/// HTML "the head element": the first head element that is a child of the
/// html element, if there is one, or null otherwise.
fn headElementOf(document: *runtime.Instance) ?*runtime.Instance {
    return firstChildNamed(htmlElementOf(document) orelse return null, html_namespace, "head");
}

/// HTML "the title element": the first title element in the document, in
/// tree order, if there is one, or null otherwise.
fn titleElementOf(document: *runtime.Instance) ?*runtime.Instance {
    return firstDescendantNamed(document, html_namespace, "title");
}

/// The first inclusive descendant of `root`'s children, in tree order, that
/// is an element in `namespace` named `local_name`.
fn firstDescendantNamed(root: *runtime.Instance, namespace: []const u8, local_name: []const u8) ?*runtime.Instance {
    var child = NodeImpl.getFirstChild(root);
    while (child) |c| : (child = NodeImpl.getNextSibling(c)) {
        if (isElementNamed(c, namespace, local_name)) return c;
        if (firstDescendantNamed(c, namespace, local_name)) |found| return found;
    }
    return null;
}

/// DOM "child text content": the concatenation of the data of all the Text
/// node children of `node`, in tree order. OWNED by `allocator`.
fn childTextContent(allocator: std.mem.Allocator, node: *runtime.Instance) ![]u8 {
    var text: std.ArrayListUnmanaged(u8) = .empty;
    errdefer text.deinit(allocator);
    var child = NodeImpl.getFirstChild(node);
    while (child) |c| : (child = NodeImpl.getNextSibling(c)) {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        // A CDATASection is a Text node too.
        if (node_type != NodeImpl.NodeType.TEXT_NODE and node_type != NodeImpl.NodeType.CDATA_SECTION_NODE) continue;
        var data = try interfaces.CharacterData.get_data(c);
        defer data.deinit(c.ctx.allocator);
        try text.appendSlice(allocator, data.asSlice());
    }
    return text.toOwnedSlice(allocator);
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

/// HTML `document.head`: the head element - the first head element that is
/// a child of the html element, if there is one, or null otherwise.
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-head
pub fn get_head(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = getInternal(instance) orelse return error.InvalidStateError;
    return headElementOf(instance);
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
/// dom.document_scripts; this getter used to ignore that and return null always.
pub fn get_currentScript(instance: *runtime.Instance) anyerror!?typedefs.HTMLOrSVGScriptElement {
    const internal = getInternal(instance) orelse return null;
    const script = internal.scripts.current_script orelse return null;
    return .{ .htmlscript_element = script };
}

/// Getter for defaultView
/// HTML §7.3.1 - Returns the Window object associated with the document, or null
/// Spec: https://html.spec.whatwg.org/multipage/window-object.html#dom-document-defaultview
///
/// "1. If this's browsing context is null, then return null. 2. Return this's
/// browsing context's WindowProxy object." A document made without one
/// (createHTMLDocument, DOMParser) has no view; a document that has been
/// destroyed - unloaded by a navigation that replaced it, or its frame
/// removed - has had its browsing context set to null ("destroy" step 7),
/// though its Window, which it still names, may live on.
pub fn get_defaultView(instance: *runtime.Instance) anyerror!?typedefs.WindowProxy {
    const internal = getInternal(instance) orelse return null;
    if (internal.destroyed) return null;
    const window = internal.default_view orelse return null;
    return @ptrCast(window);
}

/// Set the default view (window) associated with this document.
/// Called when the document is associated with a window (e.g., during iframe setup).
/// This establishes the bidirectional Document <-> Window relationship.
///
/// The window keeps this document's wrapper from then on - WebKit's
/// `document` is a strong reference, Blink traces document_ from
/// LocalDOMWindow - by an edge from its global object, its member
/// `document`: the wrapper lives as long as the window's realm, and the
/// children the document keeps (`KeptChild`) with it. A document whose
/// wrapper was collected under its window died on the next `document` access
/// (custom-elements/connected-callbacks.html, SIGTRAP). Every caller has made
/// this document the window's (Window.setDocument), which keeps a document it
/// replaces.
pub fn setDefaultView(instance: *runtime.Instance, window: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    internal.default_view = window;
    engine.traceChild(window, instance, .{ .name = "document" });
}

/// dom.document_browsing_context: this document was destroyed. HTML
/// "destroy a document" step 8: "Set document's browsing context to null" -
/// its defaultView answers null from now on, and its window no longer keeps
/// it (the window's `document` edge is its successor's). Script that holds
/// it still has a working node tree; once script drops it, the collector
/// takes it - its wrapper no longer reads as the window's (a document with a
/// default view is never freed by its wrapper), which the pending-activity
/// hold and release below makes the wrapper cache read again.
fn clearDefaultView(instance: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    internal.default_view = null;
    engine.keepPlatformObjectAlive(instance);
    engine.releasePlatformObject(instance);
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

    // One HTMLAllCollection for the document's whole life ([SameObject]),
    // made on first use. The HTMLAllCollection template is marked
    // undetectable by the V8Interface binding code (see interface.zig
    // HTMLAllCollection handling).
    const all = internal.all_collection orelse blk: {
        const made = try interfaces.HTMLAllCollection.init(internal.allocator, instance.ctx);
        internal.all_collection = made;
        internal.all_collection_kept.made(made);
        break :blk made;
    };
    internal.all_collection_kept.handOut(instance, all, .{ .name = "all" });
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
    const fonts = internal.fonts orelse blk: {
        const made = interfaces.FontFaceSet.init(internal.allocator, instance.ctx) catch return error.OutOfMemory;
        internal.fonts = made;
        internal.fonts_kept.made(made);
        break :blk made;
    };
    internal.fonts_kept.handOut(instance, fonts, .{ .name = "fonts" });
    return fonts;
}

/// Getter for customElementRegistry
/// Returns the custom element registry associated with this document, or null.
pub fn get_customElementRegistry(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    // Deviation: the global registry is currently kept by Window. The spec
    // keeps it on Document even after its browsing context ends. Moving that
    // ownership, together with scoped registries, is a follow-up batch.
    const window = (try get_defaultView(instance)) orelse return null;
    return try interfaces.Window.get_customElements(window);
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
    const sheets = internal.style_sheets orelse blk: {
        const made = interfaces.StyleSheetList.init(internal.allocator, instance.ctx) catch return error.OutOfMemory;
        internal.style_sheets = made;
        internal.style_sheets_kept.made(made);
        break :blk made;
    };
    internal.style_sheets_kept.handOut(instance, sheets, .{ .name = "styleSheets" });
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

    // The document keeps its array ([SameObject]); the binding gets a hold
    // of its own.
    if (internal.adopted_style_sheets) |sheets| {
        return (try engine.retainValue(instance.ctx, runtime.JSValue.fromHandle(sheets))).take();
    }

    // Create new ObservableArray exotic object
    const observable_array = engine.createObservableArray(instance.ctx) catch {
        // If we can't create the ObservableArray (e.g., no V8 context), return undefined
        // This gracefully degrades for testing scenarios without full V8 setup
        return runtime.JSValue.jsUndefined;
    };

    // The document keeps the array's handle (engine.createObservableArray
    // handed it over) for every later read; the binding gets a hold of its
    // own.
    internal.adopted_style_sheets = switch (observable_array) {
        .handle => |h| h.ptr,
        else => return observable_array,
    };
    return (try engine.retainValue(instance.ctx, observable_array)).take();
}

/// Getter for activeElement (DocumentOrShadowRoot): HTML's activeElement
/// getter steps, in src/html/focus.zig - the focused area's DOM anchor
/// retargeted against this document; the body element, else the document
/// element, when the viewport has the focus.
///
/// Stated deviation: the spec applies the focus fixup rule ("When the
/// designated focused area of the document is removed from that Document in
/// some way ..., designate the Document's viewport to be the new focused
/// area of the document") as a state change during "update the rendering";
/// html.focus.focusedAreaOf applies it when the focused area is read, here
/// and in every other reader. The rule fires no event, so activeElement
/// reads the same either way.
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-documentorshadowroot-activeelement
pub fn get_activeElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    if (getInternal(instance) == null) return error.InvalidStateError;
    return @import("html").focus.activeElement(instance);
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

/// HTML document.domain's setter.
/// Spec: https://html.spec.whatwg.org/multipage/browsers.html#dom-document-domain
///
/// Deviation, stated: step 2's sandboxed document.domain browsing context
/// flag is not read - a document here cannot see its browsing context's
/// sandboxing flags. A sandboxed frame without allow-same-origin has an
/// opaque origin and throws at step 4 anyway; one with allow-same-origin can
/// set its domain, where the spec throws.
pub fn set_domain(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const allocator = instance.ctx.allocator;

    // 1. "If this's browsing context is null, then throw a SecurityError." A
    // document has one here exactly when it has a window.
    if (internal.default_view == null) return error.SecurityError;

    // 3-4. "Let effectiveDomain be this's origin's effective domain. If
    // effectiveDomain is null, then throw a SecurityError."
    const effective = (try effectiveDomain(instance, internal, allocator)) orelse return error.SecurityError;
    defer allocator.free(effective);

    // 5. "If the given value is not a registrable domain suffix of and is not
    // equal to effectiveDomain, then throw a SecurityError."
    if (!try isRegistrableDomainSuffixOfOrEqualTo(allocator, value, effective)) return error.SecurityError;

    // 6. "If the surrounding agent's agent cluster's is origin-keyed is true,
    // then return." Crane's agent clusters are site-keyed
    // (Window.originAgentCluster is false).

    // 7. "Set this's origin's domain to the result of parsing the given
    // value."
    const host = url_mod.host_parser.parseHost(allocator, value, false, null) catch return error.SecurityError;
    defer host.deinit(allocator);
    const domain = try url_mod.host_serializer.serializeHost(internal.allocator, host);
    if (internal.domain.len > 0) internal.allocator.free(internal.domain);
    internal.domain = domain;
}

/// HTML document.cookie's setter: nothing for a cookie-averse Document, a
/// SecurityError for an opaque origin, and otherwise the storage model's
/// "receives a set-cookie-string" for the document's URL via a "non-HTTP"
/// API - which cannot set or replace an HttpOnly cookie.
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-cookie
pub fn set_cookie(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    var target = (try cookieTarget(instance)) orelse return;
    defer target.deinit();
    _ = try @import("cookiestore").http_integration.parseAndStoreCookie(instance.ctx.allocator, target.jar, value, target.parts.path, .{
        .is_secure = target.parts.secure,
        .host = target.parts.host,
        .http_only_allowed = false,
    });
}

/// HTML `document.title`'s setter: the steps of the first matching
/// condition.
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#document.title
pub fn set_title(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = getInternal(instance) orelse return error.InvalidStateError;

    const element: *runtime.Instance = if (svgDocumentElement(instance)) |svg| blk: {
        // "If the document element is an SVG svg element":
        // 1. "If there is an SVG title element that is a child of the
        //    document element, let element be the first such element."
        if (firstChildNamed(svg, svg_namespace, "title")) |title| break :blk title;
        // 2. "Otherwise: let element be the result of creating an element
        //    given the document element's node document, "title", and the
        //    SVG namespace. Insert element as the first child of the
        //    document element."
        const title = try createTitle(instance, svg_namespace);
        errdefer NodeImpl.deinitNodeByType(title);
        _ = try interfaces.Node.call_insertBefore(svg, title, NodeImpl.getFirstChild(svg));
        break :blk title;
    } else if (documentElementInHtmlNamespace(instance)) blk: {
        // "If the document element is in the HTML namespace":
        // 2. "If the title element is non-null, let element be the title
        //    element."
        if (titleElementOf(instance)) |title| break :blk title;
        // 1. "If the title element is null and the head element is null,
        //    then return."
        const head = headElementOf(instance) orelse return;
        // 3. "Otherwise: let element be the result of creating an element
        //    given the document element's node document, "title", and the
        //    HTML namespace. Append element to the head element."
        const title = try createTitle(instance, html_namespace);
        errdefer NodeImpl.deinitNodeByType(title);
        _ = try interfaces.Node.call_appendChild(head, title);
        break :blk title;
    } else {
        // "Otherwise: do nothing."
        return;
    };

    // "String replace all with the given value within element" - the
    // textContent setter's steps for an element.
    try interfaces.Node.set_textContent(element, value);
}

/// Whether the document element is in the HTML namespace.
fn documentElementInHtmlNamespace(document: *runtime.Instance) bool {
    const element = documentElementOf(document) orelse return false;
    if ((NodeImpl.getNodeType(element) orelse 0) != NodeImpl.NodeType.ELEMENT_NODE) return false;
    const allocator = element.ctx.allocator;
    var namespace = (interfaces.Element.get_namespaceURI(element) catch return false) orelse return false;
    defer namespace.deinit(allocator);
    return std.mem.eql(u8, namespace.asSlice(), html_namespace);
}

/// "Create an element" given `document` (the document element's node
/// document), "title" and `namespace`.
fn createTitle(document: *runtime.Instance, namespace: []const u8) !*runtime.Instance {
    return createAnElement(document, "title", namespace, null);
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
pub fn call_static_parseHTMLUnsafe(instance: *runtime.Instance, html: typedefs.TrustedHTMLOrDOMString) anyerror!*runtime.Instance {
    // Step 1: "Let compliantHTML be the result of invoking the get trusted
    // type compliant string algorithm with TrustedHTML, the current global
    // object, html, "Document parseHTMLUnsafe", and "script"."
    const allocator = instance.ctx.allocator;
    const compliant = try @import("dom").trusted_types.compliantStringForRealm(allocator, .html, engine.currentRealm() orelse instance.ctx, html, "Document parseHTMLUnsafe");
    defer allocator.free(compliant);
    // TODO: steps 2-5 - a new HTML document, parsed from compliantHTML with
    // declarative shadow roots allowed.
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
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const realm = instance.ctx;
    const allocator = realm.allocator;
    const was_live = realm.hasEngine();

    // DOM 4.5 createElement step 1: "If localName is not a valid element local
    // name, then throw an "InvalidCharacterError" DOMException."
    if (!names.isValidElementLocalName(localName.asSlice())) return error.InvalidCharacterError;

    // Step 2: "If this is an HTML document, then set localName to localName in
    // ASCII lowercase."
    const lowered: ?[]u8 = if (internal.doc_type == .html) try std.ascii.allocLowerString(allocator, localName.asSlice()) else null;
    defer if (lowered) |l| allocator.free(l);
    const local_name_slice: []const u8 = lowered orelse localName.asSlice();

    // Step 3: flatten element creation options; the legacy string is ignored.
    // customElementRegistry options are the deferred scoped-registry work.
    const is_value = try @import("html").custom_element_creation.flattenIs(instance, options);
    defer if (is_value) |value| allocator.free(value);
    if (was_live and !realm.hasEngine()) return error.InvalidStateError;

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
    return @import("html").custom_element_creation.create(.{
        .document = instance,
        .local_name = local_name_slice,
        .namespace = if (in_html_namespace) html_namespace else null,
        .is_value = is_value,
        .synchronous = true,
    });
}

const html_namespace = "http://www.w3.org/1999/xhtml";

/// DOM create-an-element with the default options, used by Document's other
/// algorithms. The factory operations explicitly set synchronous creation.
fn createAnElement(instance: *runtime.Instance, local_name: []const u8, namespace: ?[]const u8, prefix: ?[]const u8) !*runtime.Instance {
    return @import("html").custom_element_creation.create(.{
        .document = instance,
        .local_name = local_name,
        .namespace = namespace,
        .prefix = prefix,
    });
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

    // Step 5: "If document has an active parser whose script nesting level
    // is greater than 0, then return document." - an inline script of the
    // page being parsed calls document.open(), which is ignored. The parser
    // sets the insertion point as it raises its script nesting level for a
    // parser-inserted script, and restores it as it lowers it (the script
    // end tag steps, and the pending parsing-blocking script's), so while
    // the document's parser has an input stream, an insertion point in it
    // is that nesting level above 0.
    if (internal.input_stream_manager) |stream| {
        if (stream.hasInsertionPoint()) return instance;
    }

    // Step 6: Check unload counter
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

    // Step 9: "For each shadow-including inclusive descendant node of
    // document, erase all event listeners and handlers given node." (No
    // shadow trees exist yet.)
    eraseListenersOfTree(instance);

    // Step 10: "If document is the associated Document of document's
    // relevant global object, then erase all event listeners and handlers
    // given document's relevant global object."
    if (internal.default_view) |window| {
        if ((interfaces.Window.get_document(window) catch null) == instance) {
            EventTargetImpl.eraseAllEventListenersAndHandlers(window);
        }
    }

    // Step 11: "Replace all with null within document."
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

    // Step 14: "If document's iframe load in progress flag is set, then set
    // document's mute iframe load flag." A load handler that writes to its
    // frame's document does not make the frame fire load again.
    if (internal.iframe_load_in_progress) internal.mute_iframe_load = true;

    // Step 15: "Set document to no-quirks mode."
    internal.mode = .no_quirks;

    // Step 16: Create new HTML parser (script-created)
    internal.is_script_created_parser = true;

    // Step 17: Set insertion point to 0 (beginning of stream)
    internal.insertion_point = 0;

    // Clear any previously buffered content
    internal.write_buffer.clearRetainingCapacity();

    // Step 18: "Update the current document readiness of document to
    // "loading"." Not implemented, stated: step 14 (mute the iframe load
    // event).
    updateReadiness(instance, ._loading_);

    // Return the document
    return instance;
}

/// open(url, name, features): "1. If this is not fully active, then throw an
/// "InvalidAccessError" DOMException. 2. Return the result of running the
/// window open steps with url, name, and features." - on this's relevant
/// global object, whose open() runs them.
pub fn call_open__1(instance: *runtime.Instance, url: runtime.USVString, name: runtime.DOMString, features: runtime.DOMString) anyerror!?typedefs.WindowProxy {
    const internal = getInternal(instance) orelse return error.InvalidAccessError;
    // Step 1: fully active - the active document of a browsing context that
    // still has it.
    if (internal.destroyed) return error.InvalidAccessError;
    const window = internal.default_view orelse return error.InvalidAccessError;
    if ((interfaces.Window.get_document(window) catch null) != instance) return error.InvalidAccessError;
    // Step 2.
    return interfaces.Window.call_open(
        window,
        webidl.Opt(runtime.USVString).passed(url),
        webidl.Opt(runtime.DOMString).passed(name),
        webidl.Opt(runtime.DOMString).passed(features),
    );
}

/// document.open() step 9: "erase all event listeners and handlers" of
/// `document` and each of its descendants, in tree order.
fn eraseListenersOfTree(document: *runtime.Instance) void {
    var node: ?*runtime.Instance = document;
    while (node) |current| {
        EventTargetImpl.eraseAllEventListenersAndHandlers(current);
        if (NodeImpl.getFirstChild(current)) |first| {
            node = first;
            continue;
        }
        var cursor = current;
        node = while (true) {
            if (cursor == document) break null;
            if (NodeImpl.getNextSibling(cursor)) |next| break next;
            cursor = NodeImpl.getParent(cursor) orelse break null;
        };
    }
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
pub fn call_execCommand(instance: *runtime.Instance, commandId: runtime.DOMString, showUI: webidl.Opt(bool), value: webidl.Opt(typedefs.TrustedHTMLOrDOMString)) anyerror!bool {
    const internal = getInternal(instance) orelse return false;

    // Get command name (case-insensitive per spec)
    const command_name = commandId.asSlice();
    _ = showUI; // Ignored by modern browsers

    // The editing spec declares value as (TrustedHTML or DOMString), default
    // "" (https://w3c.github.io/editing/docs/execCommand/#execcommand()). Its
    // steps name no Trusted Types check; the engines run one for the
    // insertHTML command only, once the command is known (Gecko,
    // dom/base/Document.cpp ConvertToInternalCommand: sink "Document
    // execCommand", the 'script' sink group): value becomes the result of
    // the get trusted type compliant string algorithm with TrustedHTML,
    // this's relevant global object, value, "Document execCommand" and
    // "script" - the IDL default "" included, a string. Every other command
    // takes the string, or the TrustedHTML's data.
    var compliant: ?[]u8 = null;
    defer if (compliant) |text| internal.allocator.free(text);
    const value_slice: ?[]const u8 = if (std.ascii.eqlIgnoreCase(command_name, "insertHTML")) checked: {
        const given: typedefs.TrustedHTMLOrDOMString = if (value.wasPassed()) value.value else .{ .domstring = runtime.DOMString.initInterned("") };
        compliant = try @import("dom").trusted_types.compliantStringFor(internal.allocator, .html, instance, given, "Document execCommand");
        break :checked compliant.?;
    } else if (value.wasPassed())
        @import("dom").trusted_types.inputFrom(value.value).stringified()
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
    interfaces.Element.call_setAttribute(anchor, runtime.DOMString.initInterned("href"), .{ .domstring = runtime.DOMString.initInterned(url) }) catch return false;

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
/// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-document-write
/// "The document.write(...text) method steps are to run the document write
/// steps with this, text, false, and "Document write"."
pub fn call_write(instance: *runtime.Instance, text: []const typedefs.TrustedHTMLOrDOMString) anyerror!void {
    return documentWriteSteps(instance, text, false, "Document write");
}

/// The document write steps, given `instance`, `text`, `line_feed` and
/// `sink`.
///
/// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#document-write-steps
fn documentWriteSteps(instance: *runtime.Instance, text: []const typedefs.TrustedHTMLOrDOMString, line_feed: bool, sink: []const u8) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const trusted_types = @import("dom").trusted_types;

    // Step 1: "Let string be the empty string."
    var string: std.ArrayList(u8) = .empty;
    defer string.deinit(internal.allocator);
    // Step 2: "Let isTrusted be false if text contains a string; otherwise
    // true."
    var is_trusted = true;
    // Step 3: "For each value of text: if value is a TrustedHTML object,
    // then append value's associated data to string; otherwise, append
    // value to string."
    for (text) |value| {
        const input = trusted_types.inputFrom(value);
        if (input == .string) is_trusted = false;
        try string.appendSlice(internal.allocator, input.stringified());
    }
    // Step 4: "If isTrusted is false, set string to the result of invoking
    // the get trusted type compliant string algorithm with TrustedHTML,
    // this's relevant global object, string, sink, and "script"."
    if (!is_trusted) {
        const compliant = try trusted_types.compliantStringFor(internal.allocator, .html, instance, typedefs.TrustedHTMLOrDOMString{ .domstring = runtime.DOMString.initInterned(string.items) }, sink);
        defer internal.allocator.free(compliant);
        string.clearRetainingCapacity();
        try string.appendSlice(internal.allocator, compliant);
    }
    // Step 5: "If lineFeed is true, append U+000A LINE FEED to string."
    if (line_feed) try string.append(internal.allocator, '\n');

    // Step 6: "If document is an XML document, then throw an
    // "InvalidStateError" DOMException."
    if (internal.doc_type == .xml) return error.InvalidStateError;

    // Step 7: "If document's throw-on-dynamic-markup-insertion counter is
    // greater than 0, then throw an "InvalidStateError" DOMException."
    if (internal.throw_on_dynamic_markup_insertion_counter > 0) return error.InvalidStateError;

    // Step 8: "If document's active parser was aborted is true, then return."
    if (internal.active_parser_was_aborted) return;

    // A parser is running (the document's own, a frame's, or document.close()'s)
    // and has an insertion point - it runs the script calling us, or a script
    // that script's write() inserted.
    if (internal.input_stream_manager) |stream| {
        if (stream.hasInsertionPoint()) {
            // Step 10: "Insert string into the input stream just before the
            // insertion point."
            try stream.insert(string.items);
            // Step 11: "If document's pending parsing-blocking script is
            // null, then have the HTML parser process string, one code point
            // at a time, processing resulting tokens as they are emitted, and
            // stopping when the tokenizer reaches the insertion point or when
            // the processing of the tokenizer is aborted by the tree
            // construction stage."
            if (internal.scripts.pending_parsing_blocking_script == null) stream.processInserted();
            return;
        }
    }

    // Step 9: the insertion point is undefined.
    if (internal.insertion_point == null) {
        // Step 9.1: "If document's unload counter is greater than 0 or
        // document's ignore-destructive-writes counter is greater than 0, then
        // return."
        if (internal.scripts.ignore_destructive_writes_counter > 0 or internal.unload_counter > 0) {
            return;
        }
        // Step 9.2: "Run the document open steps with document": its
        // listeners are erased, its children replaced with nothing, and a
        // script-created parser is its parser, with an insertion point.
        _ = try call_open(instance, webidl.Opt(runtime.DOMString).notPassed(), webidl.Opt(runtime.DOMString).notPassed());
        // The open steps return early - an active parser running a script,
        // an unload in progress, an aborted parser - without a
        // script-created parser; then nothing is written.
        if (!internal.is_script_created_parser) return;
    }

    if (string.items.len == 0) return;
    try appendToScriptCreatedParserInput(instance, internal, string.items);
}

/// A script-created parser's input: buffered for document.close() to parse,
/// and - so the document shows it before then - parsed as a fragment into the
/// body. Deviation, stated: the script-created parser does not process each
/// write as it arrives; that needs document.open()'s parser, which is not this
/// function's to create.
/// Steps 10-11 for a script-created parser: insert string into its input
/// stream. Deviation, stated (as for document.open()): the script-created
/// parser processes its stream when document.close() inserts the explicit
/// EOF, not as each write() inserts - so what was written is not in the
/// tree until then.
fn appendToScriptCreatedParserInput(instance: *runtime.Instance, internal: *InternalState, buffer: []const u8) !void {
    _ = instance;
    internal.write_buffer.appendSlice(internal.allocator, buffer) catch {
        return error.OutOfMemory;
    };
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

/// DOM `createEvent(interface)` (legacy).
/// Spec: https://dom.spec.whatwg.org/#dom-document-createevent
pub fn call_createEvent(instance: *runtime.Instance, interface: runtime.DOMString) anyerror!*runtime.Instance {
    _ = getInternal(instance) orelse return error.InvalidStateError;

    // Steps 1-2: "Let constructor be null. If interface is an ASCII
    // case-insensitive match for any of the strings in the first column in
    // the following table, then set constructor to the interface in the
    // second column on the same row as the matching string."
    // Step 3: "If constructor is null, then throw a NotSupportedError."
    const constructor = legacyEventInterface(interface.asSlice()) orelse return error.NotSupportedError;

    // Step 4: "If the interface indicated by constructor is not exposed on the
    // relevant global object of this, then throw a NotSupportedError." Every
    // interface in the table is exposed on Window here - TouchEvent too, since
    // this engine exposes the legacy touch event APIs (`ontouchstart` is in
    // document) - and a document's relevant global is a Window.

    // Step 5: "Let event be the result of creating an event given
    // constructor": its constructor with the dictionary undefined converts
    // to - where it has one - and otherwise a new object of the interface.
    // Steps 6-8 fall out of that: type is "", timeStamp is the current high
    // resolution time, isTrusted is false.
    const event = try createLegacyEvent(instance.ctx, constructor);

    // Step 9: "Unset event's initialized flag." Creating it SETS it, so
    // without this the event is indistinguishable from `new Event("")` and
    // dispatchEvent never throws - which is exactly what "If the event's
    // initialized flag is not set, an InvalidStateError must be thrown"
    // checks. initEvent() sets it again.
    EventImpl.setInitializedFlag(event, false);

    // Step 10.
    return event;
}

/// The interfaces createEvent() can create.
const LegacyEventInterface = enum {
    BeforeUnloadEvent,
    CompositionEvent,
    CustomEvent,
    DeviceMotionEvent,
    DeviceOrientationEvent,
    DragEvent,
    Event,
    FocusEvent,
    HashChangeEvent,
    KeyboardEvent,
    MessageEvent,
    MouseEvent,
    StorageEvent,
    TextEvent,
    TouchEvent,
    UIEvent,
};

/// createEvent() step 2's table: each string, and the interface it names.
const legacy_event_table = [_]struct { []const u8, LegacyEventInterface }{
    .{ "beforeunloadevent", .BeforeUnloadEvent },
    .{ "compositionevent", .CompositionEvent },
    .{ "customevent", .CustomEvent },
    .{ "devicemotionevent", .DeviceMotionEvent },
    .{ "deviceorientationevent", .DeviceOrientationEvent },
    .{ "dragevent", .DragEvent },
    .{ "event", .Event },
    .{ "events", .Event },
    .{ "focusevent", .FocusEvent },
    .{ "hashchangeevent", .HashChangeEvent },
    .{ "htmlevents", .Event },
    .{ "keyboardevent", .KeyboardEvent },
    .{ "messageevent", .MessageEvent },
    .{ "mouseevent", .MouseEvent },
    .{ "mouseevents", .MouseEvent },
    .{ "storageevent", .StorageEvent },
    .{ "svgevents", .Event },
    .{ "textevent", .TextEvent },
    .{ "touchevent", .TouchEvent },
    .{ "uievent", .UIEvent },
    .{ "uievents", .UIEvent },
};

/// The interface `name` names in createEvent()'s table - an ASCII
/// case-insensitive match - or null.
fn legacyEventInterface(name: []const u8) ?LegacyEventInterface {
    for (legacy_event_table) |row| {
        if (std.ascii.eqlIgnoreCase(name, row[0])) return row[1];
    }
    return null;
}

/// DOM "create an event" given `interface`, in `realm`, less its step 4
/// (isTrusted stays false, as createEvent() wants it).
fn createLegacyEvent(realm: runtime.Context, interface: LegacyEventInterface) anyerror!*runtime.Instance {
    switch (interface) {
        inline else => |tag| {
            const Interface = @field(interfaces, @tagName(tag));
            if (comptime @hasDecl(Interface, "call_constructor")) {
                // Step 2: the dictionary the JavaScript value undefined
                // converts to - the constructor's, not passed.
                const Dictionary = @typeInfo(@TypeOf(Interface.call_constructor)).@"fn".params[2].type.?;
                return Interface.call_constructor(realm, runtime.DOMString.initEmpty(), Dictionary.notPassed());
            } else {
                // No constructor (BeforeUnloadEvent, TextEvent): a new object
                // of the interface, with the Event defaults.
                return Interface.init(realm.allocator, realm);
            }
        },
    }
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
///
/// Spec: https://dom.spec.whatwg.org/#dom-document-getelementsbyclassname
/// "The getElementsByClassName(classNames) method steps are to return the
///  list of elements with class names classNames for this."
///
/// Spec: https://dom.spec.whatwg.org/#concept-getelementsbyclassname
/// "1. Let classes be the result of running the ordered set parser on
///  classNames. 2. If classes is the empty set, return an empty
///  HTMLCollection. 3. Return an HTMLCollection rooted at root, whose filter
///  matches descendant elements that have all their classes in classes."
///
/// Step 3's collection is LIVE, which HTMLCollection keeps
/// (dom.live_collections): a snapshot missed every class that changed after
/// the call (dom/nodes/getElementsByClassName-03, -05).
pub fn call_getElementsByClassName(instance: *runtime.Instance, classNames: runtime.DOMString) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const class_names = classNames.asSlice();

    const collection = try interfaces.HTMLCollection.init(internal.allocator, instance.ctx);
    errdefer interfaces.HTMLCollection.deinit(collection);

    // Steps 1-2: the ordered set parser's tokens are the pieces between ASCII
    // whitespace; none means the empty set, and the empty collection.
    var tokens = std.mem.tokenizeAny(u8, class_names, "\t\n\x0C\r ");
    if (tokens.next() == null) return collection;

    // Step 3.
    try live_collections.elementsWithClassNames(collection, instance, class_names);
    return collection;
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
    const realm = instance.ctx;
    const was_live = realm.hasEngine();
    // Step 1: neither documents nor shadow roots can be imported.
    if (try interfaces.Node.get_nodeType(node) == interfaces.Node.get_DOCUMENT_NODE() or
        node.stateAs(interfaces.ShadowRoot.State) != null) return error.NotSupportedError;

    // Steps 2–5.1: WebIDL selects the dictionary for objects/null and the
    // boolean branch for other values. Omitted options default to false.
    // Scoped customElementRegistry options remain a follow-up batch.
    const subtree = if (!options.was_passed) false else switch (engine.typeOf(realm, options.value)) {
        .undefined => false,
        .null => true,
        .object => blk: {
            const self_only = try engine.getProperty(realm, options.value, "selfOnly");
            defer self_only.release();
            break :blk !engine.toBoolean(realm, self_only.value);
        },
        else => engine.toBoolean(realm, options.value),
    };
    if (was_live and !realm.hasEngine()) return error.InvalidStateError;
    // Steps 6–7: cloning uses this document's global registry, not the source
    // document's, and never runs adoption steps.
    return dom_creation.clone(node, instance, subtree, null);
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
/// 3. Adopt node into this document
/// 4. Return node
pub fn call_adoptNode(instance: *runtime.Instance, node: *runtime.Instance) anyerror!*runtime.Instance {
    // Step 1: Document nodes cannot be adopted
    if (try interfaces.Node.get_nodeType(node) == interfaces.Node.get_DOCUMENT_NODE()) {
        return error.NotSupportedError;
    }

    // Step 2: Shadow roots cannot be adopted
    if (node.stateAs(interfaces.ShadowRoot.State) != null) return error.HierarchyRequestError;

    // Step 3: the shared adoption algorithm removes the old parent, updates
    // shadow-including descendants and live ranges, and enqueues reactions.
    const dom = @import("dom");
    const node_base = dom.instance_bridge.getNodeBase(node) orelse return error.InvalidStateError;
    const document_base = dom.instance_bridge.getNodeBase(instance) orelse return error.InvalidStateError;
    const document = document_base.getNodeDocument() orelse return error.InvalidStateError;
    try dom.mutation.adopt(node_base, document);

    // Step 4: Return node
    return node;
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
    // The filter argument, borrowed for the call: the walker takes its own.
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
/// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-document-writeln
/// "The document.writeln(...text) method steps are to run the document write
/// steps with this, text, true, and "Document writeln"."
pub fn call_writeln(instance: *runtime.Instance, text: []const typedefs.TrustedHTMLOrDOMString) anyerror!void {
    return documentWriteSteps(instance, text, true, "Document writeln");
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

    // The document's one selection, made on first use.
    const selection = internal.selection orelse blk: {
        const made = interfaces.Selection.init(internal.allocator, instance.ctx) catch |err| {
            if (@import("builtin").mode == .Debug) {
                log.err("Failed to create Selection: {any}", .{err});
            }
            return null;
        };
        internal.selection = made;
        internal.selection_kept.made(made);
        break :blk made;
    };
    // It is this document's for the document's whole life, whatever script
    // keeps of it (`KeptChild`).
    internal.selection_kept.handOut(instance, selection, .{ .name = "selection" });
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
    // Steps 1-2.
    if (internal.ready_state == readiness) return;
    internal.ready_state = readiness;
    // Step 3: the load timing info's DOM complete or DOM interactive time,
    // the first time each comes - for the document its window shows (the
    // timeline keeps that document's load timing info; another document of
    // the realm - a DOMParser's - has none to record into).
    if (isShownByItsWindow(instance) and (get_defaultView(instance) catch null) != null) switch (readiness) {
        ._complete_ => @import("dom").performance_timeline.recordLoadTiming(instance.ctx, .dom_complete),
        ._interactive_ => @import("dom").performance_timeline.recordLoadTiming(instance.ctx, .dom_interactive),
        else => {},
    };
    // Step 4.
    fireEvent(instance, instance, "readystatechange", false);
}

/// "The end" from step 3, once document.close()'s parse has stopped: step 5
/// runs the scripts that will execute when the document has finished
/// parsing - a defer script document.write() put in the stream - as the
/// other parser drivers' "the end" does (HTMLParser.zig, a frame's parse).
/// Deviation, stated: load's legacy target override is not modelled.
fn theEnd(instance: *runtime.Instance) void {
    lifecycleParsingStopped(instance);
    const internal = getInternal(instance);
    const scripting = (get_defaultView(instance) catch null) != null;
    if (internal != null and scripting) {
        @import("html").script_execution.executeScriptsWhenParsingFinished(internal.?.allocator, instance);
    }
    lifecycleFinishLoading(instance);
}

/// dom.document_lifecycle: "the end" step 3, "Update the current document
/// readiness to "interactive"."
fn lifecycleParsingStopped(document: *runtime.Instance) void {
    // A parser that runs outside script - the top-level one, loading a page -
    // is in no realm, and readystatechange's listeners run in the document's.
    engine.runInRealm(document.ctx, becomeInteractive, document) catch |err| {
        log.debug("readystatechange (interactive) not fired: {}", .{err});
    };
}

fn becomeInteractive(data: ?*anyopaque) void {
    updateReadiness(@ptrCast(@alignCast(data.?)), ._interactive_);
}

fn becomeComplete(data: ?*anyopaque) void {
    updateReadiness(@ptrCast(@alignCast(data.?)), ._complete_);
}

/// dom.document_lifecycle: HTML "abort" a document (§7.5.6). Step 2 (the
/// document's fetches) and step 3 (WebDriver BiDi) are not modelled. Step 4:
/// "If document has an active parser": set its active parser was aborted,
/// abort that parser, and make document unsalvageable.
///
/// Crane parses a frame's document in one synchronous run, so its parser is
/// "active" exactly while readiness is "loading" - a navigation started by
/// the document's own script during the parse. The parse runs to its end
/// (the rest of the markup is still parsed, stated), and lifecycleFinishLoading
/// then does "abort a parser" step 4 instead of "the end": as in Blink and
/// Gecko, a document whose load a navigation interrupted never fires load,
/// and neither does its iframe (navigating-across-documents/
/// replace-before-load/*).
fn lifecycleAbort(document: *runtime.Instance) void {
    const internal = getInternal(document) orelse return;
    if (internal.ready_state != ._loading_) return;
    internal.active_parser_was_aborted = true;
    // "Make document unsalvageable" is left to the unload that follows:
    // Crane reads an unsalvageable document as unloaded (isShownByItsWindow),
    // and this one stays its navigable's active document until the
    // navigation commits. With no bfcache, nothing salvages it either way.
}

/// dom.document_lifecycle: step 6's task fires DOMContentLoaded; step 9's
/// completes the load, once step 8 finds nothing delaying it.
fn lifecycleFinishLoading(document: *runtime.Instance) void {
    // A parser a navigation aborted (lifecycleAbort) stops without "the
    // end": HTML "abort a parser" step 4, "Update the current document
    // readiness to "complete"" - and no DOMContentLoaded, load, pageshow or
    // load at the container.
    if (getInternal(document)) |internal| if (internal.active_parser_was_aborted) {
        engine.runInRealm(document.ctx, becomeComplete, document) catch {};
        return;
    };
    // HTML "try to scroll to the fragment" queues its scroll while the parser
    // runs and gives up once it has stopped; Crane parses a document in one
    // run, so that task would always give up. Scroll once parsing is done,
    // before DOMContentLoaded, as WebKit (FrameLoader::finishedParsing ->
    // scrollToFragment) and Blink (FragmentAnchor, from
    // Document::FinishedParsing) do - :target then holds in load listeners.
    @import("dom").fragment_scroll.scrollToTheFragment(document);
    queueLifecycleTask(document, .dom_content_loaded);
    // Step 7 - the scripts that execute as soon as possible, or in order as
    // soon as possible - run as their results arrive (script_execution); a
    // script-inserted script still fetching keeps them non-empty, which
    // queueLoadUnlessDelayed waits on.
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
    // Step 7: "Spin the event loop until the set of scripts that will
    // execute as soon as possible and the list of scripts that will execute
    // in order as soon as possible are empty" - script_execution says when a
    // script leaves them (loadDelayMayHaveEnded). Then step 8.
    const scripts_pending = internal.scripts.scripts_to_execute_asap.items.len > 0 or internal.scripts.scripts_to_execute_in_order_asap.items.len > 0;
    if (scripts_pending or internal.load_event_delay_count > 0 or @import("dom").content_navigables.delaysLoadEvent(document) or @import("dom").style_sheet_owners.delaysLoadEvent(document) or @import("dom").media_elements.mediaDelaysLoadEvent(document)) {
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

/// dom.document_lifecycle: HTML "delay the load event" - one more thing
/// the load event waits on (Blink's IncrementLoadEventDelayCount).
fn lifecycleDelayLoadEvent(document: *runtime.Instance) void {
    const internal = getInternal(document) orelse return;
    internal.load_event_delay_count += 1;
}

/// dom.document_lifecycle: one delay ended (Blink's
/// DecrementLoadEventDelayCount); "the end" goes on if it was the last.
fn lifecycleUndelayLoadEvent(document: *runtime.Instance) void {
    const internal = getInternal(document) orelse return;
    internal.load_event_delay_count -|= 1;
    if (internal.load_event_delay_count == 0) lifecycleLoadDelayMayHaveEnded(document);
}

fn lifecycleIsCompletelyLoaded(document: *runtime.Instance) bool {
    const internal = getInternal(document) orelse return true;
    return internal.completely_loaded;
}

fn lifecycleIsInitialAboutBlank(document: *runtime.Instance) bool {
    const internal = getInternal(document) orelse return false;
    return internal.is_initial_about_blank;
}

fn lifecycleSetIframeLoadInProgress(document: *runtime.Instance, in_progress: bool) void {
    const internal = getInternal(document) orelse return;
    internal.iframe_load_in_progress = in_progress;
}

fn lifecycleIsIframeLoadMuted(document: *runtime.Instance) bool {
    const internal = getInternal(document) orelse return false;
    return internal.mute_iframe_load;
}

/// HTML "create a new browsing context and document": step 15 makes the
/// document with "is initial about:blank" true, and step 21 completely
/// finishes loading it - with no container yet, so no load event.
fn lifecycleMarkInitialAboutBlank(document: *runtime.Instance) void {
    const internal = getInternal(document) orelse return;
    internal.is_initial_about_blank = true;
    // "Create a new browsing context and document" step 15: the document's
    // mode is "quirks".
    internal.mode = .quirks;
    internal.completely_loaded = true;
    // "Current document readiness" is initially "complete" (HTML §3.1.1);
    // only "create and initialize a Document object" - navigation - makes
    // it "loading". This document never went through that.
    internal.ready_state = ._complete_;
    // Deviation, stated, matching every browser: the initial about:blank
    // document is showing. HTML sets "page showing" only where it fires
    // pageshow ("the end", reactivation), which this document never
    // reaches - so, as written, closing a never-navigated window.open()
    // popup fires no pagehide. Every engine fires it (close-method,
    // self-et-al and open-close/close_pagehide assume it), and the review of
    // whatwg/html PR #6869 agreed the initial about:blank "should also fire
    // pageshow" (Firefox does). Its unload event is not gated on this: that
    // follows salvageable (unload step 12).
    internal.page_showing = true;
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
fn lifecycleFireBeforeUnload(document: *runtime.Instance) BeforeUnloadResult {
    var call: BeforeUnloadCall = .{ .document = document };
    engine.runInRealm(document.ctx, BeforeUnloadCall.steps, &call) catch return .{};
    return call.result;
}

const BeforeUnloadResult = @import("dom").document_lifecycle.BeforeUnloadResult;

/// The steps to fire beforeunload, run in the document's realm.
const BeforeUnloadCall = struct {
    document: *runtime.Instance,
    result: BeforeUnloadResult = .{},

    fn steps(data: ?*anyopaque) void {
        const call: *BeforeUnloadCall = @ptrCast(@alignCast(data.?));
        call.result = fireBeforeUnload(call.document);
    }
};

fn fireBeforeUnload(document: *runtime.Instance) BeforeUnloadResult {
    const internal = getInternal(document) orelse return .{};
    const window = (get_defaultView(document) catch null) orelse return .{};

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
    engine.runInRealm(document.ctx, unloadSteps, document) catch |err| {
        log.debug("unload not run: {}", .{err});
    };
}

fn unloadSteps(data: ?*anyopaque) void {
    const document: *runtime.Instance = @ptrCast(@alignCast(data.?));
    const internal = getInternal(document) orelse return;
    const window = (get_defaultView(document) catch null) orelse return;

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
    // Step 19: "If oldDocument's salvageable state is false, then destroy
    // oldDocument." Its handlers above still saw it fully active.
    if (!internal.salvageable) lifecycleDestroy(document);
}

/// dom.document_lifecycle: HTML "destroy" `document` (§7.5.5), the steps
/// that are the document's own. Step 2: "Set document's salvageable state to
/// false." Step 7: "Set document's browsing context to null." Not modelled
/// here, stated: steps 1 and 3-6 and 8-9 - its descendants' documents are
/// the navigable's to destroy (they are destroyed first), its tasks are
/// dropped by the event loop's fully-active check, and its message ports,
/// fetches and worker owner sets are not tracked per document.
fn lifecycleDestroy(document: *runtime.Instance) void {
    const internal = getInternal(document) orelse return;
    internal.salvageable = false;
    internal.destroyed = true;
}

/// dom.document_lifecycle: set `document`'s about base URL (a copy).
fn lifecycleSetAboutBaseUrl(document: *runtime.Instance, url: ?[]const u8) void {
    const internal = getInternal(document) orelse return;
    const copy: ?[]u8 = if (url) |u| internal.allocator.dupe(u8, u) catch return else null;
    if (internal.about_base_url) |old| internal.allocator.free(old);
    internal.about_base_url = copy;
}

/// dom.document_lifecycle: "fallback base URL" steps 1-2. "1. If document is
/// an iframe srcdoc document, then: assert document's about base URL is
/// non-null; return document's about base URL. 2. If document's URL matches
/// about:blank and document's about base URL is non-null, then return
/// document's about base URL." Crane has no separate srcdoc flag: a document
/// at about:srcdoc is one.
fn lifecycleAboutFallbackBaseUrl(document: *runtime.Instance) ?[]const u8 {
    const internal = getInternal(document) orelse return null;
    const about = internal.about_base_url orelse return null;
    const url = get_URL(document) catch return null;
    defer document.ctx.allocator.free(url);
    const navigate_steps = @import("html_core").navigation.navigate_steps;
    if (navigate_steps.matchesAboutSrcdoc(url) or navigate_steps.matchesAboutBlank(url)) return about;
    return null;
}

// ============================================================================
// Declarative refresh (HTML §4.2.5.3)
// ============================================================================

/// A refresh the shared declarative refresh steps set up for a document:
/// where it goes and after how long, and - once the document has completely
/// loaded - the timer it waits on. The document owns it
/// (`InternalState.declarative_refresh`) until it fires; the document's end
/// cancels it.
const DeclarativeRefresh = struct {
    allocator: std.mem.Allocator,
    document: *runtime.Instance,
    generation: u64,
    /// urlRecord, serialized. Owned.
    url: []u8,
    /// `time`, in milliseconds.
    delay_ms: u64,
    /// The timer it waits on, once armed.
    timer: ?runtime.TimerInterface = null,
    timer_id: runtime.TimerId = 0,

    fn destroy(self: *DeclarativeRefresh) void {
        self.allocator.free(self.url);
        self.allocator.destroy(self);
    }

    /// The document is going: the timer must not fire into it.
    fn cancel(self: *DeclarativeRefresh) void {
        if (self.timer) |timer| _ = timer.clearTimeout(self.timer_id);
        self.destroy();
    }

    /// The refresh has come due. The document gives it up, and its step
    /// runs as a task of the document's realm, entered from the event loop.
    fn fire(data: ?*anyopaque) void {
        const self: *DeclarativeRefresh = @ptrCast(@alignCast(data orelse return));
        defer self.destroy();
        if (runtime.SlabAllocator.generationOf(self.document) != self.generation) return;
        const internal = getInternal(self.document) orelse return;
        if (internal.declarative_refresh == self) internal.declarative_refresh = null;
        engine.runTaskInRealm(self.document.ctx, refreshComesDue, self) catch |err| {
            log.debug("declarative refresh not run: {}", .{err});
        };
    }
};

/// dom.document_lifecycle: HTML "shared declarative refresh steps" given
/// `document`, `input` and, for a meta element's Refresh pragma, `meta`.
/// Steps 2-11.10 are html_core's `declarative_refresh.parse`.
///
/// Step 13 takes its first option: navigate once the refresh has come due.
/// "The later of" `time` seconds after the completely loaded time and after
/// the meta element's insertion is `time` seconds from now for a document
/// that has completely loaded - the element was inserted just now - and
/// `time` seconds from the completely loaded time otherwise.
///
/// Not modelled, stated: the document's active sandboxing flag set is not
/// recorded, so step 13's sandboxed automatic features browsing context flag
/// is read from its navigable's sandboxing flags when the steps run; the
/// flag is set exactly when allow-scripts is absent.
fn lifecycleDeclarativeRefresh(document: *runtime.Instance, input: []const u8, meta: ?*runtime.Instance) void {
    const internal = getInternal(document) orelse return;
    // Step 1: "If document's will declaratively refresh is true, then
    // return."
    if (internal.will_declaratively_refresh) return;
    // Steps 2-11.10.
    const parsed = html_core.navigation.declarative_refresh.parse(input) orelse return;
    // Step 9: "Let urlRecord be document's URL." Steps 11.11-11.12: "Set
    // urlRecord to the result of encoding-parsing a URL given urlString,
    // relative to document. If urlRecord is failure, then return."
    const url: []u8 = if (parsed.url) |url_string|
        parseRelativeToDocument(document, url_string, internal.allocator) orelse return
    else blk: {
        const own = get_URL(document) catch return;
        defer document.ctx.allocator.free(own);
        break :blk internal.allocator.dupe(u8, own) catch return;
    };
    // Step 11.13: "If urlRecord's scheme is "javascript", then return."
    if (html_core.navigation.navigate_steps.isJavascript(url)) {
        internal.allocator.free(url);
        return;
    }
    // Step 12: "Set document's will declaratively refresh to true."
    internal.will_declaratively_refresh = true;
    // Step 13: "if meta is given, document's active sandboxing flag set does
    // not have the sandboxed automatic features browsing context flag set" -
    // a refresh that may never navigate is not set up.
    if (meta != null and automaticFeaturesSandboxed(document)) {
        internal.allocator.free(url);
        return;
    }
    const refresh = internal.allocator.create(DeclarativeRefresh) catch {
        internal.allocator.free(url);
        return;
    };
    refresh.* = .{
        .allocator = internal.allocator,
        .document = document,
        .generation = runtime.SlabAllocator.generationOf(document),
        .url = url,
        .delay_ms = std.math.mul(u64, parsed.time, std.time.ms_per_s) catch std.math.maxInt(u64),
    };
    internal.declarative_refresh = refresh;
    // A document still loading starts the wait from "completely finish
    // loading" (completeLoading).
    if (internal.completely_loaded) armDeclarativeRefresh(document);
}

/// Start `document`'s declarative refresh waiting: `time` seconds from now.
fn armDeclarativeRefresh(document: *runtime.Instance) void {
    const internal = getInternal(document) orelse return;
    const refresh = internal.declarative_refresh orelse return;
    if (refresh.timer != null) return;
    const timer = document.ctx.getOptionalTimer() orelse return;
    const id = timer.setTimeout(refresh.delay_ms, &DeclarativeRefresh.fire, refresh);
    if (id == 0) return;
    refresh.timer = timer;
    refresh.timer_id = id;
}

/// Step 13's navigation, once the refresh has come due: "navigate document's
/// node navigable to urlRecord using document, with historyHandling set to
/// "replace"" - for a document that is still fully active.
fn refreshComesDue(data: ?*anyopaque) void {
    const refresh: *DeclarativeRefresh = @ptrCast(@alignCast(data.?));
    const document = refresh.document;
    if (!isShownByItsWindow(document)) return;
    const window = (get_defaultView(document) catch null) orelse return;
    const internal = getInternal(document) orelse return;
    const own_url = get_URL(document) catch return;
    defer document.ctx.allocator.free(own_url);
    const navigate_steps = html_core.navigation.navigate_steps;
    // Deviation, stated: a refresh to the document's own URL - fragments
    // excluded, with no fragment of its own - is a reload, not a replace
    // navigation. All three browsers report navigationType "reload" for it
    // (navigation-api/navigate-event/navigate-meta-refresh.html passes in
    // Chrome, Firefox and Safari); the spec navigates with "replace". This
    // is Blink's HttpRefreshScheduler::NavigateTask (EqualIgnoringFragmentIdentifier
    // and no fragment: WebFrameLoadType::kReload), and Gecko's
    // nsDocShell::ForceRefreshURI (the same URI: LOAD_REFRESH, not
    // LOAD_REFRESH_REPLACE). Blink also refuses the reload for a frame
    // that has shown only initial empty documents.
    const reload = navigate_steps.equalsExcludingFragments(refresh.url, own_url) and
        std.mem.indexOfScalar(u8, refresh.url, '#') == null and
        !internal.is_initial_about_blank;
    const dom = @import("dom");
    if (reload) {
        // Location.reload()'s path: History installs the hook when it is
        // made.
        if (!dom.history_traversal.isInstalled()) _ = interfaces.Window.get_history(window) catch {};
        dom.history_traversal.reload(window);
        return;
    }
    if (dom.navigables.isInstalled()) {
        dom.navigables.navigateByTarget(document, .{ .target = "_self", .url = refresh.url, .history_behavior = .replace });
        return;
    }
    // No navigable container on this thread has made the hook: the
    // document is its page's, which its Location navigates.
    if (!dom.top_level_navigation.isInstalled()) _ = interfaces.Window.get_location(window) catch return;
    dom.top_level_navigation.navigate(window, refresh.url, .{ .history_behavior = .replace, .source_document = document });
}

/// Whether `document`'s navigable is sandboxed without allow-scripts - which
/// sets the sandboxed automatic features browsing context flag.
fn automaticFeaturesSandboxed(document: *runtime.Instance) bool {
    const window = (get_defaultView(document) catch null) orelse return false;
    const browsing_context = html_core.window.BrowsingContext.ofWindow(@ptrCast(window)) orelse return false;
    return !browsing_context.allowsScripts();
}

/// `url_string` encoding-parsed relative to `document` and serialized,
/// owned by `allocator`; null on failure.
fn parseRelativeToDocument(document: *runtime.Instance, url_string: []const u8, allocator: std.mem.Allocator) ?[]u8 {
    const href = (@import("html").encoding_parse.encodingParseAndSerialize(document, url_string) catch return null) orelse return null;
    defer document.ctx.allocator.free(href);
    return allocator.dupe(u8, href) catch null;
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

const LifecycleStep = enum { dom_content_loaded, load, container_load, declarative_refresh };

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
    // A task runs from the event loop, in no realm: it runs in the target's.
    engine.runTaskInRealm(task.target.ctx, lifecycleTaskSteps, task) catch |err| {
        log.debug("document lifecycle task not run: {}", .{err});
    };
}

fn lifecycleTaskSteps(data: ?*anyopaque) void {
    const task: *LifecycleTask = @ptrCast(@alignCast(data.?));

    // The event loop runs only a task whose document is fully active: a
    // navigation that replaced the document before its "the end" ran leaves
    // those tasks nothing to do. Running them fired a second load at the
    // frame's container, for a document the frame no longer shows.
    switch (task.step) {
        .dom_content_loaded, .load, .declarative_refresh => if (!isShownByItsWindow(task.target)) return,
        .container_load => {},
    }

    switch (task.step) {
        // Step 6.1-6.3: the DOM content loaded event start time; "Fire an
        // event named DOMContentLoaded at the Document object, with its
        // bubbles attribute initialized to true"; its end time.
        .dom_content_loaded => {
            // (The timeline keeps the load timing info of the document a
            // window shows; a windowless document's is not recorded.)
            const has_window = (get_defaultView(task.target) catch null) != null;
            if (has_window) @import("dom").performance_timeline.recordLoadTiming(task.target.ctx, .dom_content_loaded_event_start);
            fireEvent(task.target, task.target, "DOMContentLoaded", true);
            if (has_window) @import("dom").performance_timeline.recordLoadTiming(task.target.ctx, .dom_content_loaded_event_end);
        },
        .load => completeLoading(task.target),
        // "Completely finish loading" step 4: the container's load event
        // steps - the iframe's own (dom.content_navigables), which end the
        // delay its navigation put on its node document's load event; step
        // 5 for any other container: "fire an event named load at element".
        .container_load => if (!@import("dom").content_navigables.runLoadEventSteps(task.target)) {
            fireEvent(task.target, task.target, "load", false);
        },
        // A refresh set up while the document loaded starts waiting now.
        .declarative_refresh => armDeclarativeRefresh(task.target),
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
    // Step 9.4: the load event start time.
    @import("dom").performance_timeline.recordLoadTiming(document.ctx, .load_event_start);
    // Step 9.5: "Fire an event named load at window".
    fireEvent(document, window, "load", false);
    // Step 9.8: the load event end time.
    @import("dom").performance_timeline.recordLoadTiming(document.ctx, .load_event_end);
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
    // Step 9.13: "Queue the navigation timing entry for the Document."
    @import("dom").performance_timeline.queueNavigationTimingEntry(document.ctx);
    // A declarative refresh comes due `time` seconds after the completely
    // loaded time. Its wait starts in a task queued behind the container's
    // load event, so a refresh of no time never overtakes that event.
    if (internal.declarative_refresh != null) queueLifecycleTask(document, .declarative_refresh);
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

/// Operation: requestStorageAccess(optional StorageAccessTypes types = {})
/// (saa-non-cookie-storage.idl). Overload 0: codegen numbers overloads in
/// member order, partials by file name, and saa-non-cookie-storage.idl sorts
/// before storage-access.idl, whose requestStorageAccess() is overload 1.
pub fn call_requestStorageAccess(instance: *runtime.Instance, types: webidl.Opt(dictionaries.StorageAccessTypes)) anyerror!runtime.JSValue {
    _ = instance;
    _ = types;
    return error.NotImplemented;
}

/// Operation: requestStorageAccess() (storage-access.idl), overload 1.
pub fn call_requestStorageAccess__1(instance: *runtime.Instance) anyerror!runtime.JSValue {
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
    const realm = instance.ctx;
    const allocator = realm.allocator;
    const was_live = realm.hasEngine();

    // DOM 4.5 "internal createElementNS steps" step 1: "Let (namespace,
    // prefix, localName) be the result of validating and extracting namespace
    // and qualifiedName given "element"."
    const extracted = try names.validateAndExtract(
        if (namespace) |ns| ns.asSlice() else null,
        qualifiedName.asSlice(),
        .element,
    );

    // Internal createElementNS step 2: flatten element creation options.
    const is_value = try @import("html").custom_element_creation.flattenIs(instance, options);
    defer if (is_value) |value| allocator.free(value);
    if (was_live and !realm.hasEngine()) return error.InvalidStateError;

    // Step 3: "Return the result of creating an element given document,
    // localName, namespace, prefix, is, and true."
    return @import("html").custom_element_creation.create(.{
        .document = instance,
        .local_name = extracted.local_name,
        .namespace = extracted.namespace,
        .prefix = extracted.prefix,
        .is_value = is_value,
        .synchronous = true,
    });
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
    // The filter argument, borrowed for the call: the iterator takes its own.
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
//
// The script processing model's state on a Document - its script lists,
// currentScript, the ignore-destructive-writes counter - and its module and
// import maps are reached by html/script_execution.zig through the hooks this
// block installs, and a frame's parser sets its window through another; they
// are their own install, apart from the others in `init`.

const dom_document_scripts = @import("dom").document_scripts;
const dom_document_modules = @import("dom").document_modules;
const dom_document_browsing_context = @import("dom").document_browsing_context;

/// Install the hooks html's script processing model reaches a Document's
/// script state through. Idempotent; called from `init`, before any Document
/// exists to be asked.
fn installScriptHooks() void {
    dom_document_scripts.install(.{
        .scripts = &scriptsOf,
        .scripting_enabled = &isScriptingEnabled,
        .has_style_sheet_blocking_scripts = &hasStyleSheetBlockingScripts,
        .inline_script_allowed_by_csp = &isInlineScriptAllowedByCSP,
        .add_prefetch_hint = &addPrefetchHintStep,
        .url = &recordedUrl,
    });
    dom_document_browsing_context.install(.{ .set_window = &setDefaultView, .clear_window = &clearDefaultView });
    dom_document_modules.install(.{
        .allocator = &moduleAllocator,
        .get_module = &getModule,
        .set_module = &setModuleStep,
        .set_module_dispose_function = &setModuleDisposeFunction,
        .import_map_acquired = &hasImportMapAcquired,
        .acquire_import_map = &setImportMapAcquired,
        .add_import_mapping = &addImportMappingStep,
        .add_scoped_import_mapping = &addScopedImportMappingStep,
        .resolve_import_specifier = &resolveImportSpecifier,
    });
}

/// dom.document_scripts: the document's scripts.
fn scriptsOf(instance: *runtime.Instance) ?*dom_document_scripts.Scripts {
    const internal = getInternal(instance) orelse return null;
    return &internal.scripts;
}

/// dom.document_scripts: the document's URL as recorded ("" when unset).
fn recordedUrl(instance: *runtime.Instance) []const u8 {
    const internal = getInternal(instance) orelse return "";
    return internal.url;
}

fn addPrefetchHintStep(instance: *runtime.Instance, url: []const u8, eagerness: SpeculationEagerness) error{ InvalidStateError, OutOfMemory }!void {
    return addPrefetchHint(instance, url, eagerness);
}

/// dom.document_modules: the allocator module scripts are made with.
fn moduleAllocator(instance: *runtime.Instance) ?std.mem.Allocator {
    const internal = getInternal(instance) orelse return null;
    return internal.allocator;
}

fn setModuleStep(instance: *runtime.Instance, url: []const u8, module: *anyopaque) dom_document_modules.Error!void {
    return setModule(instance, url, module);
}

fn addImportMappingStep(instance: *runtime.Instance, specifier: []const u8, resolved_url: []const u8) dom_document_modules.Error!void {
    return addImportMapping(instance, specifier, resolved_url);
}

fn addScopedImportMappingStep(instance: *runtime.Instance, scope_prefix: []const u8, specifier: []const u8, resolved_url: []const u8) dom_document_modules.Error!void {
    return addScopedImportMapping(instance, scope_prefix, specifier, resolved_url);
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
    return &internal.policy_container.csp_list;
}

/// Set the CSP list for this document
/// Takes ownership of the CSP list.
pub fn setCSPList(instance: *runtime.Instance, csp_list: *csp.CSPList) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // The policy container\'s list is replaced by this one, which was
    // allocated with the document\'s allocator.
    internal.policy_container.csp_list.deinit();
    internal.policy_container.csp_list = csp_list.*;
    internal.allocator.destroy(csp_list);
}

/// Add a policy to the document's CSP list
/// Spec: https://www.w3.org/TR/CSP3/ §2.2.1
pub fn addCSPPolicy(instance: *runtime.Instance, policy: csp.Policy) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try internal.policy_container.csp_list.append(policy);
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

/// CSP §4.2.3 "Should element's inline type behavior be blocked by Content
/// Security Policy?" for the inline script `element` (type "script") with
/// `source`: for each policy of the document's CSP list, the inline check
/// of the directive §6.8.4 picks (csp.inline_check: nonce, hash -
/// base64url too - 'strict-dynamic', 'unsafe-inline'); a policy it blocks
/// reports a violation - resource "inline", the element, a sample under
/// 'report-sample' - to the document's window, and blocks the script when
/// it is enforced. `nonce` is the element's nonce attribute when it is
/// nonceable (§6.7.3.1).
///
/// Spec: https://w3c.github.io/webappsec-csp/#should-block-inline
pub fn isInlineScriptAllowedByCSP(
    instance: *runtime.Instance,
    element: *runtime.Instance,
    source: []const u8,
    nonce: ?[]const u8,
    parser_inserted: bool,
) bool {
    const internal = getInternal(instance) orelse return true; // No document = allow
    // The violation's global: the current settings object's - the
    // document's window, for a script its parser or its script inserted.
    const window: ?*runtime.Instance = get_defaultView(instance) catch null;
    // 2. Let result be "Allowed".
    var allowed = true;
    // 3. For each policy of the CSP list:
    for (internal.policy_container.csp_list.policies.items) |*policy| {
        // 3.1.1. A directive whose inline check allows it is skipped.
        const directive = csp.inline_check.blockingDirective(policy, .{ .nonce = nonce, .parser_inserted = parser_inserted }, .script, source) orelse continue;
        // 3.1.2-3.1.7. A violation of the effective directive for inline
        // checks, resource "inline", the element, and a sample when the
        // directive asks for one, reported.
        if (window) |w| @import("dom").csp_violations.reportViolation(w, &.{
            .policy = policy,
            .effective_directive = csp.inline_check.effectiveDirectiveForInlineCheck(.script),
            .resource = .@"inline",
            .element = element,
            .sample = csp.violation_events.sampleFor(directive, source),
        });
        // 3.1.8. An enforced policy blocks.
        if (policy.disposition == .enforce) allowed = false;
    }
    // 4. Return result.
    return allowed;
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
