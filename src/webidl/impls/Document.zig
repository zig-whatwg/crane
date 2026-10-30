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
//! This file uses interfaces for factory method calls (call_constructor, etc.);
//! a node's type is its interface's, set by the generated construction chain.

const std = @import("std");
const log = std.log.scoped(.document_impl);
const refcount_log = std.log.scoped(.refcount);
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
const Registry = runtime.InstanceRegistry(.document, InternalState);

// Import impls ONLY for internal initialization methods not exposed via interfaces
const NodeImpl = @import("Node.zig");
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
const OriginRecord = @import("dom").origin_record.OriginRecord;
const SandboxingFlagSet = @import("dom").sandboxing.SandboxingFlagSet;
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

/// Independently owned state behind one Document-owned pointer. The policy
/// pointer is always set at construction; interaction members stay lazy.
/// New Document extension pointers join this block so the inline state stays
/// within its pinned 2048-byte allocation class.
const InteractionState = struct {
    top_layer: ?*@import("dom").top_layer.State = null,
    autofocus: ?*@import("dom").document_autofocus.State = null,
    /// Permissions Policy §§9.5–9.6: an owned construction fact, separate
    /// from Fetch's policy container.
    permissions_policy: ?*html_core.permissions_policy.Policies = null,
};

/// Internal state for Document implementation
/// Spec: https://dom.spec.whatwg.org/#concept-document
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// Prepared at construction for the policy. The Document owns all
    /// members; top-layer and autofocus state remain independently lazy.
    interaction_state: ?*InteractionState = null,

    /// Cached DOMImplementation instance ([SameObject])
    implementation: ?*runtime.Instance,

    /// HTML 4.12.3: one inert owner document per ordinary document. An inert
    /// owner itself reuses its own document for nested templates.
    template_owner_document: ?*runtime.Instance = null,
    template_owner_generation: u64 = 0,
    is_template_owner_document: bool = false,

    /// The two counts of refcount design 1.5 (decision D6): the nodes that
    /// name this document, and the holds in its detached trees. Kept by
    /// src/dom/refcount.zig, through `countsOf`.
    refcounts: @import("dom").refcount.DocumentCounts = .{},

    /// String interning pool for tag names, attribute names, etc.
    /// Provides memory savings and O(1) string comparison via pointer equality
    string_pool: std.StringHashMap(void),

    /// Document base URL (fallback: empty string for about:blank)
    /// Stored as owned slice
    base_uri: []const u8,

    /// HTML's first base[href], resolved when a base mutation occurs.
    /// Owned bytes, independent of later changes to the document's URL.
    /// Null leaves the live fallback effective (including a rejected base).
    frozen_base_url: ?[]u8 = null,

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

    /// The document's origin (DOM "origin"; HTML 7.1.1): one reference to
    /// the record it shares with every document whose origin HTML says is
    /// this one's - its domain included. Set at construction (`initOwn`,
    /// the `origin` construction argument), released at deinit. Null only
    /// before initOwn runs.
    origin: ?*OriginRecord,

    /// Document encoding (default: UTF-8)
    /// Stored as DOMString for proper memory management
    encoding: runtime.DOMString,

    /// HTML 4.2.5.3: owned pragma-set default language, null before any
    /// content-language pragma. Removing its meta does not clear it.
    pragma_language: ?[]const u8 = null,

    /// Document ready state
    ready_state: enums.DocumentReadyState,
    /// HTML lastModified: the exact source timestamp, used only when known.
    /// Keep the tag in the boolean padding: ?WallTime raises this state from
    /// the arena's 2048-byte class to 4096 bytes (measured on row 76).
    last_modified: @import("platform").WallTime = .{ .ns_since_epoch = 0 },
    last_modified_known: bool = false,
    /// HTML "page showing": set when pageshow fires at the end of loading.
    page_showing: bool = false,
    /// HTML 7.4.6.3 "has been revealed": pagereveal fires once per
    /// activation - at the first rendering opportunity after the document is
    /// shown, and again after each reactivation (`revealStep`).
    has_been_revealed: bool = false,
    /// HTML "completely loaded": "completely finish loading" has run.
    completely_loaded: bool = false,
    /// HTML "ready for post-load tasks", reached by "the end" step 11.
    /// Document.open preserves this independently of readiness/loaded time.
    ready_for_post_load_tasks: bool = false,
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
    /// HTML "salvageable"; abort and unload may prevent bfcache storage
    /// without changing which document is currently active.
    salvageable: bool = true,
    /// HTML "destroy" has run: the document's browsing context is null. It
    /// stays readable - script elsewhere may hold it - but has no view.
    destroyed: bool = false,
    /// The window's counted keep of this document's wrapper (refcount step
    /// 5i, H-RC8-DOC-KEEP): taken when the document gets its default view
    /// (`setDefaultView`), ended when "destroy a document" clears it
    /// (`clearDefaultView`) - exactly where wrapper_cache's default-view rule
    /// holds the wrapper, which it sits beside until refcount step 9(d)
    /// deletes that rule. A document freed with its window drops it with
    /// its wrapper-cache entry.
    window_kept: bool = false,
    /// HTML "bfcache blocking details": the reasons "make document
    /// unsalvageable" recorded (dom.bfcache), in the order first recorded.
    bfcache_blocking_details: @import("html_core").navigation.not_restored_reasons.BlockingDetails = .{},
    /// HTML "suspension time": the current high resolution time of its
    /// window when it was last unloaded (unload step 15), 0 before. Its
    /// reactivation shifts the suspended timers by the time since (the
    /// back/forward cache's phase B).
    suspension_time: f64 = 0,
    /// HTML "suspended timer handles": the keys of its window's map of
    /// active timers when it was last unloaded (unload step 16). OWNED.
    suspended_timer_handles: []runtime.TimerId = &.{},
    /// Unload step 5: the user agent intends to keep this document in the
    /// back/forward cache (dom.bfcache.intendToKeep, the navigable's answer),
    /// for the next unload, which consumes it.
    intend_to_keep: bool = false,
    /// The last unload kept this document - salvageable at step 20, so not
    /// destroyed - for the back/forward cache, and neither "destroy" nor
    /// "reactivate" has run since (dom.bfcache.isKept).
    kept_in_bfcache: bool = false,
    /// HTML "about base URL": the document base URL of the document that
    /// created it, or of the navigation's source document, for an
    /// about:blank or about:srcdoc document; null otherwise. Owned.
    about_base_url: ?[]u8 = null,
    /// "The end" is waiting at step 8 - something delays the load event -
    /// and has not queued step 9's task yet.
    load_waiting_on_delay: bool = false,
    /// The token of the step 9 task "the end" queued and that has not run,
    /// or 0. A child navigable's load completes the document before that
    /// task runs (completeLoadingWithChild), which then does nothing.
    pending_load_token: u64 = 0,
    /// The step 9 task whose load completeLoadingWithChild ran early, or 0.
    early_load_token: u64 = 0,
    /// Load-task tokens and shadow-tree scope serials share this sequence:
    /// monotonic per document, never zero and never reused.
    next_serial: u64 = 1,
    /// "The end" is waiting for its deferred scripts before DOMContentLoaded.
    parsing_end_waiting_on_scripts: bool = false,
    /// Abort, destruction, and parser replacement discard deliveries without
    /// continuing the old document's normal loading steps. A new parser epoch
    /// enables delivery continuations again.
    script_delivery_continuation_suppressed: bool = false,
    /// The editing subsystem's editor state for this document (its undo
    /// history and command configuration), made with `allocator` on the
    /// first editing command and freed with the document
    /// (dom.editor_states). Opaque here: Document never names the editing
    /// code. It used to live in a process-global map keyed by the document's
    /// address that nothing ever emptied (lane leaks6).
    editor_state: ?*anyopaque = null,
    /// HTML "delay the load event": how many delays are held on this
    /// document's load event (dom.document_lifecycle.delayLoadEvent) - an
    /// object element's fetch, say. Blink's load_event_delay_count_.
    load_event_delay_count: u32 = 0,
    /// HTML 7.4.6.4 "target element": what :target matches, set by "scroll
    /// to the fragment"; initially null. A weak link - the element can be
    /// removed and freed while it is the target (dom.target_element).
    target_element: ?@import("same_object.zig").Link = null,
    /// HTML 4.16.3: the elements :hover and :active rest on - designated by
    /// a pointing device, being actively pointed at, in a formal activation
    /// state (dom.pointer_states). Weak links, like target_element.
    hovered_element: ?@import("same_object.zig").Link = null,
    pointed_element: ?@import("same_object.zig").Link = null,
    activated_element: ?@import("same_object.zig").Link = null,
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

    /// This document's live ranges: those whose start node's node document
    /// it is (Spec: https://dom.spec.whatwg.org/#concept-live-range). The
    /// mutation algorithms walk it while a step may tear a collected range
    /// down, which leaves the list mid-walk: a dom.live_range_list.LiveList,
    /// reached through dom.document_internals.
    ranges: @import("dom").live_range_list.LiveList(*runtime.Instance),

    /// The NodeIterators whose root's node document this is, walked by the
    /// NodeIterator pre-removing steps the same way.
    node_iterators: @import("dom").live_range_list.LiveList(*runtime.Instance),

    // === HTML Document Properties ===

    /// Document referrer (the URI of the page that linked to this page)
    referrer: []const u8,

    /// Design mode ("on" or "off")
    design_mode: runtime.DOMString,

    /// Visibility state
    visibility_state: enums.DocumentVisibilityState,

    /// Whether document is hidden
    hidden: bool,

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
    /// HTML 3.1.6: ordered set of elements blocking rendering.
    render_blocking_elements: @import("dom").document_rendering.ElementSet,
    /// The document's style engine (dom.style): its sheets and its
    /// elements' computed styles. By value - the engine's type is
    /// dom.style's, the state this document's - and reached through the
    /// `engine_of` hook below (lane style1).
    style_engine: @import("dom").style.StyleEngine,

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

    /// The document owns one reference to its navigation or script-created
    /// parser until EOF, cancellation, replacement, or destruction.
    active_parser: ?*@import("html").scripted_parser.DocumentParser,

    /// Distinguishes successive parsers of the same Document across script
    /// callbacks, including a replacement that already finished again.
    parser_epoch: u64 = 0,

    /// The InputStreamManager for document.write() during parsing
    /// This is set when parsing starts and cleared when parsing finishes
    input_stream_manager: ?*html_core.parser.document_write.InputStreamManager,

    /// Whether scripting is enabled for this document, before its sandbox:
    /// false for a document whose parser runs no script (DOMParser's,
    /// XMLHttpRequest's, a template's contents owner). `isScriptingEnabled`
    /// is the answer, which also asks the active sandboxing flag set.
    /// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#concept-n-noscript
    scripting_enabled: bool,

    /// HTML's active sandboxing flag set: empty when the document is
    /// created, populated by the navigation that made it ("create and
    /// initialize a Document object" step 9: navigationParams's final
    /// sandboxing flag set) - the `sandboxing_flags` construction argument -
    /// and never changed after. Its sandboxed scripts browsing context flag
    /// disables scripting for the document (HTML 8.1.3.4).
    /// Spec: https://html.spec.whatwg.org/multipage/browsers.html#active-sandboxing-flag-set
    active_sandboxing_flags: SandboxingFlagSet = .empty,

    // === Module Map (HTML Standard §8.1.3.10) ===

    /// Module map for caching compiled ES modules
    /// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#module-map
    /// Key: module specifier (resolved URL), Value: V8 Module handle
    module_map: std.StringHashMap(*anyopaque),
    module_loader: ?*anyopaque = null,
    dispose_module_loader: ?dom_document_modules.DisposeFn = null,

    /// Import map for the document (type="importmap")
    /// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#import-map
    /// Key: bare specifier, Value: resolved URL
    import_map_imports: std.StringHashMap([]const u8),
    /// HTML import map's integrity: owned serialized URLs and metadata.
    import_map_integrity: std.StringHashMap([]const u8),

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
    dispose_module_fn: ?dom_document_modules.ModuleDisposeFn,

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

    /// Adopted style sheets (CSSOM 6.2.3): the view of the
    /// ObservableArray<CSSStyleSheet>'s backing list the style engine reads
    /// (dom.style.adopted); the array itself the document keeps as a traced
    /// value of its wrapper.
    adopted_style_sheets: @import("dom").style.adopted.AdoptedSheets,

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
    /// DOM "allow declarative shadow roots", as stored. A navigable's document
    /// (navigation's and the initial about:blank, created with it true) is
    /// recognised by its browsing context instead
    /// (dom.document_internals.allowsDeclarativeShadowRoots); this is set by
    /// parseHTMLUnsafe and copied by cloning.
    allow_declarative_shadow_roots: bool = false,
    /// The HTML parser's form element pointer associations that differ from
    /// the tree's (a misnested or foster-parented control), kept until
    /// "reset the form owner" undoes them (html/form_associated.zig). Usually
    /// empty. Raw links, generation-checked: they keep nothing alive.
    parser_form_associations: std.ArrayListUnmanaged(@import("dom").document_internals.ParserFormAssociation) = .empty,
    custom_element_registry: @import("dom").custom_elements.RegistryAssociation = .{},
    owns_native_global_registry: bool = false,

    /// domindex1: this tree scope's maps from IDs, and from its named
    /// properties' names, to its elements (dom.tree_ordered_map): what
    /// getElementById, the named getter and the Window's named properties
    /// answer from. Kept by the mutation and attribute change hooks.
    tree_index: @import("dom").tree_ordered_map.Maps,

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
            // HTML 3.1.5: current document readiness is initially complete.
            // Navigation explicitly supplies loading through construction.
            .ready_state = ._complete_,
            .document_element = null,
            .doctype = null,
            .ranges = .empty,
            .node_iterators = .empty,
            // HTML properties
            .referrer = "",
            .design_mode = runtime.DOMString.initInterned("off"),
            .visibility_state = ._visible_,
            .hidden = false,
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
            .render_blocking_elements = @import("dom").document_rendering.ElementSet.init(allocator),
            .style_engine = @import("dom").style.StyleEngine.init(allocator),
            .throw_on_dynamic_markup_insertion_counter = 0,
            .unload_counter = 0,
            .insertion_point = null,
            .is_script_created_parser = false,
            .active_parser_was_aborted = false,
            .active_parser = null,
            .input_stream_manager = null,
            .scripting_enabled = true, // Default to true for browser environments
            // Module map and import map
            .module_map = std.StringHashMap(*anyopaque).init(allocator),
            .import_map_imports = std.StringHashMap([]const u8).init(allocator),
            .import_map_integrity = std.StringHashMap([]const u8).init(allocator),
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
            .adopted_style_sheets = @import("dom").style.adopted.AdoptedSheets.init(allocator),
            // FontFaceSet (CSS Font Loading)
            .fonts = null,
            // HTMLAllCollection (undetectable legacy object)
            .all_collection = null,
            .tree_index = @import("dom").tree_ordered_map.Maps.init(allocator, .document),
        };
    }

    pub fn deinit(self: *InternalState) void {
        const interaction = self.interaction_state;
        const permissions = if (interaction) |shared| shared.permissions_policy else null;
        self.interaction_state = null;
        if (interaction) |shared| if (shared.autofocus) |state| state.destroy(self.allocator);
        // domindex1: the maps go first, and keep nothing after: a node the
        // rest of this teardown releases is in no reader's answer.
        self.tree_index.deinit();
        if (interaction) |shared| {
            if (shared.top_layer) |layer| {
                layer.releaseAfterRealmEnded();
                self.allocator.destroy(layer);
            }
            self.allocator.destroy(shared);
        }
        self.script_delivery_continuation_suppressed = true;
        // Borrowed membership ends before parsers/module owners release nodes.
        self.render_blocking_elements.clear();
        if (self.active_parser) |parser| {
            self.active_parser = null;
            self.input_stream_manager = null;
            parser.detachForDocumentDestruction();
            parser.release();
        }
        // Loader cancellation can re-enter script delivery cleanup. Keep
        // the document's queues and borrowed render set usable until every
        // loader client has relinquished its preparation.
        if (self.module_loader) |loader| {
            self.module_loader = null;
            if (self.dispose_module_loader) |dispose| dispose(loader);
        }
        // Free all interned strings from pool
        var it = self.string_pool.keyIterator();
        while (it.next()) |key_ptr| {
            self.allocator.free(key_ptr.*);
        }
        self.string_pool.deinit();

        // Clean up lists (don't own the items, just the list storage)
        self.ranges.deinit(self.allocator);
        self.parser_form_associations.deinit(self.allocator);
        self.node_iterators.deinit(self.allocator);

        // Free owned strings
        if (self.base_uri.len > 0) {
            self.allocator.free(self.base_uri);
        }
        if (self.frozen_base_url) |url| {
            self.allocator.free(url);
            self.frozen_base_url = null;
        }
        if (self.about_base_url) |url| {
            self.allocator.free(url);
            self.about_base_url = null;
        }
        self.allocator.free(self.suspended_timer_handles);
        self.suspended_timer_handles = &.{};
        // A refresh still waiting must not fire into a freed document.
        if (self.declarative_refresh) |refresh| {
            self.declarative_refresh = null;
            refresh.cancel();
        }
        if (self.url.len > 0) {
            self.allocator.free(self.url);
        }
        if (self.origin) |record| {
            self.origin = null;
            record.release();
        }
        if (self.referrer.len > 0) {
            self.allocator.free(self.referrer);
        }

        // Free DOMString storage
        self.content_type.deinit(self.allocator);
        self.encoding.deinit(self.allocator);
        if (self.pragma_language) |language| self.allocator.free(language);
        self.design_mode.deinit(self.allocator);

        // Event handlers

        // A navigation's input_stream_manager is borrowed from its parser.

        // Script execution lists (don't own the script elements, just the list storage)
        self.scripts.deinit();
        self.render_blocking_elements.deinit();
        self.style_engine.deinit();
        self.adopted_style_sheets.deinit();

        // Module map - dispose module handles and free keys
        {
            var mod_it = self.module_map.iterator();
            while (mod_it.next()) |entry| {
                // Dispose module handle using stored function pointer
                // (null if no JS engine configured, e.g., in stub test mode)
                if (self.dispose_module_fn) |dispose_fn| {
                    dispose_fn(entry.key_ptr.*, entry.value_ptr.*);
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

        {
            var integrity_it = self.import_map_integrity.iterator();
            while (integrity_it.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                self.allocator.free(entry.value_ptr.*);
            }
            self.import_map_integrity.deinit();
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
        if (permissions) |policy| {
            policy.deinit();
            self.allocator.destroy(policy);
        }

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
        if (self.all_collection) |all| self.all_collection_kept.releaseOwned(all);
        if (self.fonts) |fonts_inst| self.fonts_kept.releaseOwned(fonts_inst);
        if (self.selection) |sel| self.selection_kept.releaseOwned(sel);
        if (self.style_sheets) |ss| self.style_sheets_kept.releaseOwned(ss);
    }

    fn ensureInteractionState(self: *InternalState) !*InteractionState {
        if (self.interaction_state) |shared| return shared;
        const shared = try self.allocator.create(InteractionState);
        shared.* = .{};
        self.interaction_state = shared;
        return shared;
    }

    /// Roll back a newly allocated container when its first child allocation
    /// fails. An existing sibling or policy is never discarded by this path.
    fn discardEmptyInteractionState(self: *InternalState, shared: *InteractionState) void {
        std.debug.assert(self.interaction_state == shared);
        if (shared.permissions_policy != null) return;
        std.debug.assert(shared.top_layer == null and shared.autofocus == null);
        self.interaction_state = null;
        self.allocator.destroy(shared);
    }

    fn clearTopLayer(self: *InternalState) void {
        const shared = self.interaction_state orelse return;
        const layer = shared.top_layer orelse return;
        shared.top_layer = null;
        layer.deinit();
        self.allocator.destroy(layer);
    }
};

fn topLayerState(instance: *runtime.Instance, create: bool) !?*@import("dom").top_layer.State {
    const internal = getInternal(instance) orelse return null;
    if (internal.interaction_state) |shared| if (shared.top_layer) |layer| return layer;
    if (!create) return null;
    const existed = internal.interaction_state != null;
    const shared = try internal.ensureInteractionState();
    errdefer if (!existed) internal.discardEmptyInteractionState(shared);
    const layer = try internal.allocator.create(@import("dom").top_layer.State);
    layer.* = @import("dom").top_layer.State.init(internal.allocator, instance);
    shared.top_layer = layer;
    return layer;
}

fn autofocusState(document: *runtime.Instance, create: bool) ?*@import("dom").document_autofocus.State {
    const internal = getInternal(document) orelse return null;
    if (internal.interaction_state) |shared| if (shared.autofocus) |state| return state;
    if (!create) return null;
    const existed = internal.interaction_state != null;
    const shared = internal.ensureInteractionState() catch return null;
    return @import("dom").document_autofocus.State.ensure(&shared.autofocus, internal.allocator) catch {
        if (!existed) internal.discardEmptyInteractionState(shared);
        return null;
    };
}

/// dom.style's `engine_of`: this document's style engine.
fn styleEngineOf(instance: *runtime.Instance) ?*@import("dom").style.StyleEngine {
    const internal = getInternal(instance) orelse return null;
    return &internal.style_engine;
}

/// dom.style's `media_values`: the environment Media Queries 5 evaluates
/// against for this document. The viewport is what the document's window
/// reports as innerWidth/innerHeight (ruling Q5: the headless default,
/// consistent with them); the screen and the user preferences are the
/// platform's (protocol 6.10.4); scripting follows the document's
/// browsing context and sandbox. A document with no window has no
/// viewport of its own and evaluates against the defaults, scripting none.
fn styleMediaValues(instance: *runtime.Instance) @import("css").media_queries.MediaValues {
    const platform = @import("platform");
    var values: @import("css").media_queries.MediaValues = .{};
    const window = (get_defaultView(instance) catch null) orelse {
        values.scripting = .none;
        return values;
    };
    values.width = @floatFromInt(interfaces.Window.get_innerWidth(window) catch 1024);
    values.height = @floatFromInt(interfaces.Window.get_innerHeight(window) catch 768);
    values.scripting = if (@import("dom").document_scripts.scriptingEnabled(instance)) .enabled else .none;
    if (@import("html").platform_state.of(instance.ctx)) |browser| {
        const screen = platform.screenInfo(browser);
        values.device_width = @floatFromInt(screen.width);
        values.device_height = @floatFromInt(screen.height);
        values.resolution = screen.device_pixel_ratio;
        values.color_bits = screen.color_depth / 3;
        const preferences = platform.userPreferences(browser);
        values.prefers_color_scheme = if (preferences.color_scheme == .dark) .dark else .light;
        values.prefers_reduced_motion = if (preferences.reduced_motion == .reduce) .reduce else .no_preference;
        values.prefers_contrast = switch (preferences.contrast) {
            .no_preference => .no_preference,
            .more => .more,
            .less => .less,
            .custom => .custom,
        };
        values.forced_colors = preferences.forced_colors;
    }
    return values;
}

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

/// dom.refcount: `document`'s two counts, or null for an instance that is no
/// live Document.
fn countsOf(document: *runtime.Instance) ?*@import("dom").refcount.DocumentCounts {
    const internal = getInternal(document) orelse return null;
    return &internal.refcounts;
}

/// dom.tree_ordered_map (domindex1): `document`'s maps, or null for an
/// instance that is no live Document.
fn treeIndexOf(document: *runtime.Instance) ?*@import("dom").tree_ordered_map.Maps {
    const internal = getInternal(document) orelse return null;
    return &internal.tree_index;
}

/// dom.policy_containers: `document`'s policy container.
fn policyContainerOf(document: *runtime.Instance) ?*fetch.internal.PolicyContainer {
    const internal = getInternal(document) orelse return null;
    return &internal.policy_container;
}

/// dom.policy_containers: both policies, owned by this Document.
fn permissionsPolicyOf(document: *runtime.Instance) ?*html_core.permissions_policy.Policies {
    const internal = getInternal(document) orelse return null;
    const shared = internal.interaction_state orelse return null;
    return shared.permissions_policy;
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    @import("dom").shadow_hosts.install(.{ .next_scope_serial = &nextTreeScopeSerial });
    @import("dom").top_layer.install(.{ .get = &topLayerState });
    // The editing commands' per-document state is freed with the document
    // (dom.editor_states): the editing subsystem installs its step.
    editing.executor.installHooks();
    // Its states left at its Browser's end (Browser.deinit).
    @import("dom").teardown_sweeps.install(.documents, &sweepRemaining);
    // The style engine this document keeps, and the media environment its
    // elements are styled in (lane style1).
    @import("dom").style.hooks.install(.{ .engine_of = &styleEngineOf, .media_values = &styleMediaValues, .document_adopted_sheets = &adoptedSheetsOf, .environment_revision = &@import("dom").style.environment_variables.revision });
    @import("dom").template_contents.install(.{ .owner_document = &templateOwnerDocument, .existing_owner_document = &existingTemplateOwnerDocument });
    @import("dom").refcount.install(.{ .document_counts = &countsOf });
    // domindex1: its tree scope's ID and named-property maps.
    @import("dom").tree_ordered_map.installDocument(&treeIndexOf);
    @import("dom").custom_elements.installDocument(.{
        .set_registry = &setCustomElementRegistry,
        .ensure_global_registry = &ensureGlobalRegistry,
    });
    @import("dom").document_lifecycle.install(.{
        .autofocus = &autofocusState,
        .rendering = .{
            .of = &renderBlockingElements,
            .allows_adding = &allowsAddingRenderBlockers,
            .current_time_ms = &renderBlockingTime,
            .on_parser_stack = &renderingOnParserStack,
        },
        .associate_parser = &lifecycleAssociateParser,
        .discard_parser = &lifecycleDiscardParser,
        .parser_finished = &lifecycleParserFinished,
        .finish_without_parser = &lifecycleFinishWithoutParser,
        .parsing_stopped = &lifecycleParsingStopped,
        .finish_loading = &lifecycleFinishLoading,
        .load_delay_may_have_ended = &lifecycleLoadDelayMayHaveEnded,
        .script_delivery_discarded = &lifecycleScriptDeliveryDiscarded,
        .delays_load_event = &lifecycleDelaysLoadEvent,
        .is_ready_for_post_load_tasks = &lifecycleIsReadyForPostLoadTasks,
        .mark_ready_for_post_load_tasks = &lifecycleMarkReadyForPostLoadTasks,
        .is_completely_loaded = &lifecycleIsCompletelyLoaded,
        .is_initial_about_blank = &lifecycleIsInitialAboutBlank,
        .mark_initial_about_blank = &lifecycleMarkInitialAboutBlank,
        .is_unloading = &lifecycleIsUnloading,
        .fire_beforeunload = &lifecycleFireBeforeUnload,
        .unload = &lifecycleUnload,
        .abort = &lifecycleAbort,
        .abort_for_navigation = &lifecycleAbortForNavigation,
        .propagate_abort = &lifecyclePropagateAbort,
        .destroy = &lifecycleDestroy,
        .set_about_base_url = &lifecycleSetAboutBaseUrl,
        .about_fallback_base_url = &lifecycleAboutFallbackBaseUrl,
        .declarative_refresh = &lifecycleDeclarativeRefresh,
        .set_iframe_load_in_progress = &lifecycleSetIframeLoadInProgress,
        .is_iframe_load_muted = &lifecycleIsIframeLoadMuted,
        .delay_load_event = &lifecycleDelayLoadEvent,
        .undelay_load_event = &lifecycleUndelayLoadEvent,
    });
    @import("dom").document_origin.install(.{
        .domain = &originDomain,
        .record = &originRecord,
        .shareable = &shareableOrigin,
    });
    @import("dom").document_language.install(.{
        .get = &pragmaLanguage,
        .set = &setPragmaLanguage,
    });
    // Its policy container, for whatever sets or reads one without naming
    // this impl (navigation, meta referrer, a Window's settings object).
    @import("dom").policy_containers.install(.{ .of = &policyContainerOf, .permissions = &permissionsPolicyOf });
    // A clone of a Document keeps its mode. Installed here, before any
    // Document exists to be cloned.
    @import("dom").cloning_steps.install(&cloningSteps);
    // The target element :target matches and "scroll to the fragment" sets.
    @import("dom").target_element.install(.{ .get = &targetElement, .set = &setTargetElement });
    // The elements :hover and :active rest on (user input sets them), and
    // the removing steps that pass them on when their element leaves.
    @import("dom").pointer_states.install(.{ .get = &pointerState, .set = &setPointerState, .get_all = &pointerStates });
    @import("dom").mutation.registerRemovingStepsCallback(&@import("dom").pointer_states.removingSteps) catch @panic("pointer state removing steps allocation");
    // User input (testdriver lane): the focusing steps designate a document's
    // focused area (src/html/focus.zig), and a top-level traversable's system
    // visibility state updates its documents' visibility state, through these
    // hooks.
    @import("dom").focused_area.install(.{ .get = &focusedArea, .set = &setFocusedArea });
    // HTML "update the rendering" step 6: reveal (dom.update_the_rendering).
    @import("dom").update_the_rendering.installStep(.reveal, &revealStep);
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
    // The event loop runs a task only while its document is fully active,
    // keeps it while the document may be again, and drops it once it cannot.
    @import("dom").document_activity.install(.{ .activity = &documentActivity });
    // "Make document unsalvageable", from the steps that end what a cached
    // document could not keep (WebSocket, LockManager, the navigation code).
    @import("dom").bfcache.install(.{
        .make_unsalvageable = &makeUnsalvageable,
        .blocking_details = &bfcacheBlockingDetails,
        .may_keep = &bfcacheMayKeep,
        .intend_to_keep = &bfcacheIntendToKeep,
        .is_kept = &bfcacheIsKept,
        .reactivate = &bfcacheReactivate,
    });
}

fn existingTemplateOwnerDocument(document: *runtime.Instance) ?*runtime.Instance {
    const internal = getInternal(document) orelse return null;
    // HTML 4.12.3: this is the existing relation, never its creating algorithm.
    if (internal.is_template_owner_document) return document;
    const owner = internal.template_owner_document orelse return null;
    return if (runtime.SlabAllocator.generationOf(owner) == internal.template_owner_generation) owner else null;
}

fn templateOwnerDocument(document: *runtime.Instance) !*runtime.Instance {
    const internal = getInternal(document) orelse return error.InvalidStateError;
    // Appropriate template contents owner document, step 1.
    if (internal.is_template_owner_document) return document;
    if (internal.template_owner_document) |owner| return owner;
    // Steps 1.1.1–1.1.3: create in the same realm, with no browsing context.
    // WebKit Document::ensureTemplateDocument keeps this state per document.
    const owner = try call_constructor(document.ctx);
    errdefer Document.deinit(owner);
    const owner_internal = getInternal(owner) orelse return error.InvalidStateError;
    owner_internal.is_template_owner_document = true;
    owner_internal.doc_type = internal.doc_type;
    owner_internal.scripting_enabled = false;
    internal.template_owner_document = owner;
    internal.template_owner_generation = runtime.SlabAllocator.generationOf(owner);
    // The document holds its template contents owner document counted
    // (refcount step 5i, H-RC8-DOC-TEMPLATE; WebKit's Document keeps
    // m_templateDocument as a RefPtr<Document>), taking its born reference
    // over, until its own teardown (deinitOwn).
    if (@import("dom").instance_bridge.getNodeBase(@ptrCast(owner))) |base| {
        @import("dom").refcount.holderRef(base);
        @import("dom").refcount.takeOverCreatorReference(base);
    }
    engine.traceChild(document, owner, .{ .name = "template owner document" });
    return owner;
}

fn renderBlockingElements(document: *runtime.Instance) ?*@import("dom").document_rendering.ElementSet {
    const internal = getInternal(document) orelse return null;
    return &internal.render_blocking_elements;
}

/// HTML 4.6.8.6 step 5: "on a stack of open elements of an HTML parser
/// whose associated Document is doc" - this document's active parser.
fn renderingOnParserStack(document: *runtime.Instance, element: *runtime.Instance) bool {
    const internal = getInternal(document) orelse return false;
    const parser = internal.active_parser orelse return false;
    return parser.isOnStackOfOpenElements(element);
}

/// HTML 3.1.6: content type text/html, with no body or frameset child of
/// the HTML document element. Read the current tree, not parser readiness.
fn allowsAddingRenderBlockers(document: *runtime.Instance) bool {
    const internal = getInternal(document) orelse return false;
    return @import("dom").document_rendering.allowsAdding(internal.content_type.asSlice(), renderingBodyElement(document) != null);
}

fn renderingBodyElement(document: *runtime.Instance) ?*runtime.Instance {
    const html = documentElementOf(document) orelse return null;
    if (!isElementNamed(html, "http://www.w3.org/1999/xhtml", "html")) return null;
    var child = interfaces.Node.get_firstChild(html) catch return null;
    while (child) |node| : (child = interfaces.Node.get_nextSibling(node) catch null) {
        if (isElementNamed(node, "http://www.w3.org/1999/xhtml", "body") or
            isElementNamed(node, "http://www.w3.org/1999/xhtml", "frameset")) return node;
    }
    return null;
}

/// HR-Time current high resolution time in the relevant global. With no
/// Window (native DOM tests), its empty origin is zero.
fn renderBlockingTime(document: *runtime.Instance) f64 {
    const internal = getInternal(document) orelse return 0;
    const window = internal.default_view orelse return 0;
    const settings = @import("dom").global_settings.of(window) orelse return 0;
    const origin_fn = settings.time_origin orelse return 0;
    const origin = origin_fn(window) orelse return 0;
    const hr_time = @import("hr_time");
    const now = hr_time.coarsenTime(hr_time.MonotonicClock.unsafeCurrentTime(), settings.cross_origin_isolated(window));
    const coarsened_origin = hr_time.coarsenTime(@as(i128, origin), settings.cross_origin_isolated(window));
    return hr_time.clock.toMilliseconds(@max(0, now - coarsened_origin));
}

/// dom.document_activity: a task's document classified - fully active ("the
/// active document of a navigable navigable, and either navigable is a
/// top-level traversable or navigable's container document is fully
/// active"), inactive (not fully active, and it may be again: its tasks
/// wait), or gone (it never can be again: its tasks are dropped).
///
/// Gone: a destroyed document (HTML "destroy" step 5 removes its tasks); one
/// with no window (createHTMLDocument, DOMParser - never given a browsing
/// context); one whose window is no navigable's active window any more, or
/// whose navigable has closed. Removing a frame discards its navigable and
/// every one inside it (BrowsingContext.discard closes them all), so the
/// container documents need no walk yet (phase C of the back/forward cache,
/// which keeps frames of a cached page alive, adds it).
///
/// Inactive: a live, undestroyed document whose navigable is open but shows
/// another document - a document the back/forward cache keeps (phase B), or
/// its Window: a cached page's Window is no navigable's active window
/// (Navigables.ofWindow misses it), so the cache is asked (dom.bfcache.holds)
/// before a Window or Document with no navigable is called gone.
///
/// A global task on a Window names the Window: its associated Document when
/// the task runs is the one asked about (see runtime.EventLoopTask.document).
/// A Window whose navigable moved to another Window and that no cache holds
/// is no navigable's, so gone.
///
/// The navigable's own record, not `Window.document`: the event loop asks
/// with no script running, and the getter's cross-origin check would answer
/// for whichever realm happens to be current - a message to a cross-origin
/// or sandboxed frame was dropped that way (the lesson "A frame's load event
/// has exactly one owner": engine code must not use script's getters).
fn documentActivity(object: *runtime.Instance) @import("dom").document_activity.Activity {
    if (object.stateAs(interfaces.Window.State) != null) {
        const navigable = @import("dom").browser_state.browsingContextOf(object) orelse return cachedOrGone(object);
        if (navigable.is_closed) return .gone;
        const active = navigable.active_document orelse return .fully_active;
        return if (isActiveDocumentFullyActive(@ptrCast(@alignCast(active)))) .fully_active else .gone;
    }
    const internal = getInternal(object) orelse return .gone;
    if (internal.destroyed) return .gone;
    const window = internal.default_view orelse return .gone;
    const navigable = @import("dom").browser_state.browsingContextOf(window) orelse return cachedOrGone(object);
    if (navigable.is_closed) return .gone;
    const active = navigable.active_document orelse return .fully_active;
    if (active == @as(*anyopaque, @ptrCast(object))) return .fully_active;
    return .inactive;
}

/// A Window or Document no navigable shows: inactive when the back/forward
/// cache keeps it (its page may be restored), else gone.
fn cachedOrGone(object: *runtime.Instance) @import("dom").document_activity.Activity {
    return if (@import("dom").bfcache.holds(object)) .inactive else .gone;
}

/// Whether `object` is fully active (`documentActivity`).
fn isFullyActive(object: *runtime.Instance) bool {
    return documentActivity(object) == .fully_active;
}

/// A navigable's active document, as its own state says: neither unloaded nor
/// destroyed.
fn isActiveDocumentFullyActive(document: *runtime.Instance) bool {
    const internal = getInternal(document) orelse return false;
    return !internal.destroyed;
}

/// Document's own construction steps: the generated chain runs Node's first.
///
/// IMPORTANT: Due to state hierarchy complexity, internal state is stored
/// in a global registry rather than in the State struct.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;

    // The document's origin, a construction fact (DOM: "origin ... an
    // opaque origin" unless its creator says otherwise): the `origin`
    // construction argument is the record of the document whose origin this
    // one's IS - shared, so document.domain set through either changes both
    // - and with none, an origin of its own, which a browsing-context
    // document still derives from its URL and window.
    const given: ?*OriginRecord = if (@hasField(@TypeOf(args), "origin")) args.origin else null;
    const origin = if (given) |record| record.retain() else try OriginRecord.createOwn(allocator);
    errdefer origin.release();

    // Keep the policy pair outside Document's pinned 2048-byte state class.
    // Until registry construction succeeds, this block is uninitialized and
    // the caller still owns any supplied pair (liaison Q30).
    const permissions = try allocator.create(html_core.permissions_policy.Policies);
    errdefer allocator.destroy(permissions);
    // Prepare the existing extension block before the registry too, so
    // either allocation failure leaves the caller's policy pair untouched.
    const shared = try allocator.create(InteractionState);
    errdefer allocator.destroy(shared);

    // Initialize Document's own internal state in registry
    // The registry owns this block, so `Registry.remove` returns it to the
    // arena. With `set` it was dropped from the map and held to process
    // exit - 904 bytes per discarded element, measured.
    const internal = try Registry.createIn(instance, runtime.arenaOf(instance));
    internal.* = InternalState.init(allocator);
    internal.origin = origin;
    // HTML create-and-initialize step 9. The generated chain transfers
    // the pair ONLY once construction succeeds; no fallible work follows.
    permissions.* = if (@hasField(@TypeOf(args), "permissions_policy"))
        args.permissions_policy
    else
        html_core.permissions_policy.Policies.init(allocator, origin);
    shared.* = .{ .permissions_policy = permissions };
    internal.interaction_state = shared;
    // HTML "create and initialize a Document object" step 9, and "create a
    // new browsing context and document" step 15: the active sandboxing flag
    // set the navigation (or the creation flags) gave it - empty otherwise.
    if (@hasField(@TypeOf(args), "sandboxing_flags")) internal.active_sandboxing_flags = args.sandboxing_flags;
    // HTML 3.1.5: a non-navigation document starts complete; navigation's
    // "create and initialize a Document" step 9 starts it loading.
    if (@hasField(@TypeOf(args), "ready_state")) internal.ready_state = args.ready_state;
    if (@hasField(@TypeOf(args), "last_modified")) {
        const last_modified: ?@import("platform").WallTime = args.last_modified;
        if (last_modified) |time| {
            internal.last_modified = time;
            internal.last_modified_known = true;
        }
    }
}

/// What a Document is given at construction (`initWith`): `origin`, the
/// record of the document whose origin it takes (BORROWED - the document
/// retains it), or null for an origin of its own; `sandboxing_flags`, its
/// active sandboxing flag set (a `dom.sandboxing.SandboxingFlagSet`), empty
/// when not given; `ready_state`, its initial HTML readiness; and
/// `last_modified`, the source's optional platform.WallTime (null: unknown);
/// and `permissions_policy`, the owned pair TAKEN only on success.
pub const construction_args = .{ "origin", "sandboxing_flags", "ready_state", "last_modified", "permissions_policy" };

/// dom.target_element: `document`'s target element, or null once the
/// element it names has been freed. A weak link (refcount step 5i: the
/// document's target element never counts): once weak references see
/// garbage, an element of a garbage tree reads as none too.
fn targetElement(document: *runtime.Instance) ?*runtime.Instance {
    const internal = getInternal(document) orelse return null;
    const link = internal.target_element orelse return null;
    return if (@import("dom").refcount.weakLinkLive(link.instance, link.generation)) link.instance else null;
}

/// dom.target_element: "set document's target element to" `element`.
fn setTargetElement(document: *runtime.Instance, element: ?*runtime.Instance) void {
    const internal = getInternal(document) orelse return;
    internal.target_element = if (element) |e| @import("same_object.zig").Link.to(e) else null;
}

/// dom.pointer_states: `document`'s element for `state`, or null once the
/// element it names has been freed.
fn pointerState(document: *runtime.Instance, state: @import("dom").pointer_states.State) ?*runtime.Instance {
    const internal = getInternal(document) orelse return null;
    const link = switch (state) {
        .hovered => internal.hovered_element,
        .pointed => internal.pointed_element,
        .activated => internal.activated_element,
    } orelse return null;
    return if (link.isLive()) link.instance else null;
}

/// dom.pointer_states: the three states, in State order, in one read.
fn pointerStates(document: *runtime.Instance) [3]?*runtime.Instance {
    const internal = getInternal(document) orelse return .{ null, null, null };
    const links = [3]?@import("same_object.zig").Link{ internal.hovered_element, internal.pointed_element, internal.activated_element };
    var out: [3]?*runtime.Instance = .{ null, null, null };
    for (links, 0..) |maybe, i| {
        if (maybe) |link| if (link.isLive()) {
            out[i] = link.instance;
        };
    }
    return out;
}

/// dom.pointer_states: designate `element` (null: nothing) for `state`.
fn setPointerState(document: *runtime.Instance, state: @import("dom").pointer_states.State, element: ?*runtime.Instance) void {
    const internal = getInternal(document) orelse return;
    const link: ?@import("same_object.zig").Link = if (element) |e| @import("same_object.zig").Link.to(e) else null;
    switch (state) {
        .hovered => internal.hovered_element = link,
        .pointed => internal.pointed_element = link,
        .activated => internal.activated_element = link,
    }
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
/// content type, URL, origin, type, and mode to those of node" - and its
/// allow declarative shadow roots. (Installed through dom.cloning_steps, as
/// Node's clone algorithm may not reach Document's state; a no-op for any
/// other node.)
fn cloningSteps(node: *runtime.Instance, copy: *runtime.Instance, subtree: bool) anyerror!void {
    _ = subtree;
    const source = getInternal(node) orelse return;
    const target = getInternal(copy) orelse return;
    const encoding = try source.encoding.clone(target.allocator);
    target.encoding.deinit(target.allocator);
    target.encoding = encoding;
    const content_type = try source.content_type.clone(target.allocator);
    target.content_type.deinit(target.allocator);
    target.content_type = content_type;
    const url = try target.allocator.dupe(u8, source.url);
    if (target.url.len > 0) target.allocator.free(target.url);
    target.url = url;
    // The copy's origin IS the original's: shared, resolved first so the
    // copy - which has no window - can serialize it.
    try shareOriginInto(target, node);
    target.doc_type = source.doc_type;
    target.mode = source.mode;
    // HTML 3.1.5: cloning creates a non-navigation document. Readiness and
    // a source modification time are not among DOM clone step 3.1's copies.
    target.ready_state = ._complete_;
    // DOM clone step 3.1 also copies "allow declarative shadow roots"
    // (dom/nodes/Node-cloneNode-document-allow-declarative-shadow-roots).
    target.allow_declarative_shadow_roots = source.allow_declarative_shadow_roots or source.default_view != null;
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

/// Document's own teardown: the generated chain runs Node's after it.
pub fn deinitOwn(instance: *runtime.Instance) void {
    if (autofocusState(instance, false)) |state| state.clear();
    if (getInternal(instance)) |internal| internal.clearTopLayer();
    if (getInternal(instance)) |internal| internal.script_delivery_continuation_suppressed = true;
    @import("html").script_execution.discardDocumentScripts(instance);
    // Clean up internal state from registry
    if (Registry.get(instance)) |internal| {
        // Shadow mode (refcount step 3): what the counts would have said.
        // Nodes outside this document's own tree that still name it are
        // the ones step 7 makes its storage wait for.
        if (@import("dom").refcount.diagnosticsOn()) {
            const document_base = @import("dom").instance_bridge.getNodeBase(instance);
            // refcount7: of the nodes in its tree, those whose born reference
            // is still their creator's, and those it alone holds.
            const census = if (document_base) |base| @import("dom").refcount.creatorCensus(base) else @import("dom").refcount.CreatorCensus{};
            refcount_log.warn("document freed: {d} referencing nodes, {d} holds in its tree, {d} foreign holds, {d} creator references in its tree ({d} alone)", .{
                internal.refcounts.referencing_nodes,
                if (document_base) |base| base.subtree_holds -| 1 else 0,
                internal.refcounts.foreign_holds,
                census.holding,
                census.alone,
            });
        }
        engine.forgetTracedChild(instance, .{ .name = "template owner document" });
        // The template contents owner document goes with this document: now
        // when nothing else can reach it - no engine realm, no wrapper (the
        // cache is never asked during a coordinated teardown), or, there, no
        // wrapper any more ([wrap_tracking]: its last one finalized, so the
        // realm's sweep has no entry left to free it; lane pageretention1).
        // Else its wrapper frees it.
        if (internal.template_owner_document) |owner| {
            if (runtime.SlabAllocator.generationOf(owner) == internal.template_owner_generation) {
                // This document's counted reference on it ends first
                // (refcount step 5i), unless its teardown began.
                if (!runtime.instance_lifecycle.isCleanupStarted(owner)) {
                    if (@import("dom").instance_bridge.getNodeBase(@ptrCast(owner))) |base| @import("dom").refcount.holderDeref(base);
                }
                if (!instance.ctx.hasEngine() or
                    (!runtime.cleanup_coordinator.isContextTearingDown() and !engine.hasWrapper(owner)))
                {
                    runtime.Instance.deinit(owner);
                } else if (runtime.cleanup_coordinator.isContextTearingDown() and
                    runtime.instance_lifecycle.provablyUnwrapped(engine.capabilities.wrap_tracking != .unsupported, owner))
                {
                    @import("dom").node_creation.destroyRoot(owner);
                }
            }
        }
        releaseNativeGlobalRegistry(internal);
        internal.custom_element_registry.release(instance);
        if (internal.editor_state) |editor_state| {
            internal.editor_state = null;
            @import("dom").editor_states.free(editor_state, internal.allocator);
        }
        internal.deinit();
    }
    Registry.remove(instance);
}

/// Constructor implementation
/// DOM §4.6 - new Document()
///
/// "The new Document() constructor steps are to set this's origin to the
/// origin of current global object's associated Document." - shared: the
/// settings object of a Window answers with its associated Document's
/// origin record (dom.global_settings), so a domain set on that document
/// later is this one's too, as in browsers (WebKit's Document constructor
/// takes the context document's SecurityOriginPolicy).
/// Spec: https://dom.spec.whatwg.org/#dom-document-document
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    const origin: ?*OriginRecord = if (globalOfRealm(ctx)) |global| try @import("dom").global_settings.shareableOriginOf(global) else null;
    const instance = try Document.initWith(ctx.allocator, ctx, .{ .origin = origin, .ready_state = ._complete_ });
    errdefer Document.deinit(instance);

    // Set default values
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.content_type = try runtime.DOMString.initDupe(ctx.allocator, "application/xml");
    internal.url = try ctx.allocator.dupe(u8, "about:blank");
    internal.encoding = try runtime.DOMString.initDupe(ctx.allocator, "UTF-8");

    // The binding wraps it: its wrapper takes its born reference (refcount7).
    @import("dom").refcount.offerDocument(instance);
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
    _ = getInternal(instance) orelse return error.InvalidStateError;
    // DOM's getter returns the document's doctype CHILD, or null. A parser
    // cache can still name a removed child and must not supply a fallback.
    var child = try interfaces.Node.get_firstChild(instance);
    while (child) |node| : (child = try interfaces.Node.get_nextSibling(node)) {
        if (try interfaces.Node.get_nodeType(node) == interfaces.Node.get_DOCUMENT_TYPE_NODE()) return node;
    }
    return null;
}

/// DOM's document element is its element child, or null. Every construction
/// path links that child before caching it (hd-document-root-writers.html).
/// Reading the tree also sees removal and replacement immediately, whereas
/// the parser's remembered pointer can name a detached element.
/// Spec: https://dom.spec.whatwg.org/#document-element
fn documentElementOf(instance: *runtime.Instance) ?*runtime.Instance {
    var child = interfaces.Node.get_firstChild(instance) catch return null;
    while (child) |node| : (child = interfaces.Node.get_nextSibling(node) catch return null) {
        if ((interfaces.Node.get_nodeType(node) catch 0) == interfaces.Node.get_ELEMENT_NODE()) return node;
    }
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

/// Getter for timeline (Web Animations 1 6.9): the default document
/// timeline, the same object for the document's life.
pub fn get_timeline(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return @import("dom").animations.defaultTimeline(instance);
}

/// Getter for pictureInPictureEnabled
/// Returns whether Picture-in-Picture mode is enabled for this document.
/// In a server-side/headless context, this is always false.
pub fn get_pictureInPictureEnabled(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return false;
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
    _ = getInternal(instance) orelse return error.InvalidStateError;
    // SVG 2 "Document interface extensions": rootElement is the document
    // element when that is an svg element, else null (Blink's
    // Document::rootElement is DynamicTo<SVGSVGElement>(documentElement())).
    const root = documentElementOf(instance) orelse return null;
    const root_names = @import("dom").node_creation.elementNames(root) orelse return null;
    const ns = root_names.namespace orelse return null;
    if (!std.mem.eql(u8, ns, "http://www.w3.org/2000/svg") or !std.mem.eql(u8, root_names.local_name, "svg")) return null;
    return root;
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
    if (originDomain(document)) |domain| return try allocator.dupe(u8, domain);
    const serialized = (try serializedOrigin(document, internal, allocator)) orelse return null;
    defer allocator.free(serialized);
    const host = hostOfSerializedOrigin(serialized) orelse return null;
    return try allocator.dupe(u8, host);
}

/// `document`'s origin, serialized - its window's (the relevant settings
/// object's) when it has one; else its origin record's, for a document made
/// with another's origin (new Document(), createHTMLDocument(), a clone);
/// else its URL's - or null for an opaque origin. OWNED by `allocator`.
fn serializedOrigin(document: *runtime.Instance, internal: *InternalState, allocator: std.mem.Allocator) !?[]u8 {
    if (internal.default_view) |window| {
        // The getter's string is the window realm's to free.
        const serialized = try interfaces.Window.get_origin(window);
        defer window.ctx.allocator.free(serialized);
        if (std.mem.eql(u8, serialized, "null")) return null;
        return try allocator.dupe(u8, serialized);
    }
    if (internal.origin) |record| {
        if (record.serialized) |serialized| {
            if (std.mem.eql(u8, serialized, "null")) return null;
            return try allocator.dupe(u8, serialized);
        }
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

/// dom.document_language: the Document-owned pragma default, or null.
fn pragmaLanguage(document: *runtime.Instance) ?[]const u8 {
    const internal = getInternal(document) orelse return null;
    return internal.pragma_language;
}

fn setPragmaLanguage(document: *runtime.Instance, language: []const u8) @import("dom").document_language.Error!void {
    const internal = getInternal(document) orelse return error.InvalidStateError;
    const owned = try internal.allocator.dupe(u8, language);
    if (internal.pragma_language) |old| internal.allocator.free(old);
    internal.pragma_language = owned;
}

/// dom.document_origin: `document`'s origin's domain, or null.
fn originDomain(document: *runtime.Instance) ?[]const u8 {
    const record = originRecord(document) orelse return null;
    return record.domain;
}

/// dom.document_origin: `document`'s origin record (borrowed).
fn originRecord(document: *runtime.Instance) ?*OriginRecord {
    const internal = getInternal(document) orelse return null;
    return internal.origin;
}

/// dom.document_origin: `document`'s origin record, its serialization
/// resolved (borrowed) - what a document made with this one's origin is
/// given.
fn shareableOrigin(document: *runtime.Instance) error{OutOfMemory}!?*OriginRecord {
    const internal = getInternal(document) orelse return null;
    const record = internal.origin orelse return null;
    if (record.serialized == null) {
        const serialized = serializedOrigin(document, internal, internal.allocator) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            // An origin no getter can answer is not known yet: the record
            // stays unresolved, and a document made with it reads its URL.
            else => return record,
        };
        defer if (serialized) |s| internal.allocator.free(s);
        try record.resolve(serialized orelse "null");
    }
    return record;
}

/// Make `target`'s origin `source_document`'s: its own reference goes, and
/// it holds the source's resolved record.
fn shareOriginInto(target: *InternalState, source_document: *runtime.Instance) error{OutOfMemory}!void {
    const record = (try shareableOrigin(source_document)) orelse return;
    const previous = target.origin;
    target.origin = record.retain();
    if (previous) |old| old.release();
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
        // TODO (cookies lane Q3, 2026-10-12): settings/navigation must
        // expose the document's captured site for cookies, including its
        // cross-site ancestors. An origin alone cannot decide this mode.
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
/// Document - one whose browsing context is null, or whose cookie URL's
/// scheme is not an HTTP(S) scheme - or one no user agent jar reaches. An
/// opaque origin is a SecurityError.
///
/// The URL is the cookie URL (dom.global_settings.cookieUrlOf), not the
/// document's current URL: the one it was made with, which pushState and
/// fragment navigations leave, and an about:blank or srcdoc document's
/// creator's. Blink's Document::cookie and WebKit's read their documents'
/// cookie URL, fixed at creation and inherited from the owner document for
/// about:blank (DocumentInit::GetCookieUrl, Document::initSecurityContext);
/// HTML's text says the document's URL, which makes such a frame
/// cookie-averse.
fn cookieTarget(document: *runtime.Instance) !?CookieTarget {
    const internal = getInternal(document) orelse return null;
    if (internal.destroyed) return null;
    const window = internal.default_view orelse return null;
    const allocator = document.ctx.allocator;
    const cookie_url = @import("dom").global_settings.cookieUrlOf(window) orelse return null;
    const url = try allocator.dupe(u8, cookie_url);
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
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const platform = @import("platform");
    // HTML lastModified: when the source's modification time is not known,
    // use the current time on each read. Blink Document::lastModified follows
    // this same source-or-now, local-calendar, numeric-format sequence:
    // https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/dom/document.cc
    const time = if (internal.last_modified_known) internal.last_modified else platform.wallNow();
    return runtime.DOMString.initOwned(try @import("dom").document_last_modified.format(
        instance.ctx.allocator,
        platform.localDateTime(time),
    ));
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
    if ((interfaces.Node.get_nodeType(node) catch 0) != interfaces.Node.get_ELEMENT_NODE()) return false;
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
    var child = interfaces.Node.get_firstChild(parent) catch null;
    while (child) |c| : (child = interfaces.Node.get_nextSibling(c) catch null) {
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
    var child = interfaces.Node.get_firstChild(root) catch null;
    while (child) |c| : (child = interfaces.Node.get_nextSibling(c) catch null) {
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
    var child = interfaces.Node.get_firstChild(node) catch null;
    while (child) |c| : (child = interfaces.Node.get_nextSibling(c) catch null) {
        const node_type = interfaces.Node.get_nodeType(c) catch 0;
        // A CDATASection is a Text node too.
        if (node_type != interfaces.Node.get_TEXT_NODE() and node_type != interfaces.Node.get_CDATA_SECTION_NODE()) continue;
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
    _ = getInternal(instance) orelse return error.InvalidStateError;
    const element = htmlElementOf(instance) orelse return runtime.DOMString.initEmpty();
    return interfaces.HTMLElement.get_dir(element);
}

/// Getter for body
/// HTML §3.1.3 - Returns the body element (the first body or frameset child of html element)
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-body
pub fn get_body(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = getInternal(instance) orelse return error.InvalidStateError;
    // HTML 3.1.7: the first body or frameset CHILD of the html element.
    // Both the root and candidate must be HTML elements, with exact names.
    const root = htmlElementOf(instance) orelse return null;
    var child = try interfaces.Node.get_firstChild(root);
    while (child) |element| : (child = try interfaces.Node.get_nextSibling(element)) {
        if (isElementNamed(element, html_namespace, "body") or
            isElementNamed(element, html_namespace, "frameset")) return element;
    }
    return null;
}

/// HTML `document.head`: the head element - the first head element that is
/// a child of the html element, if there is one, or null otherwise.
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-head
pub fn get_head(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = getInternal(instance) orelse return error.InvalidStateError;
    return headElementOf(instance);
}

/// HTML's document collections are live views with namespace-aware filters.
fn documentCollection(instance: *runtime.Instance, filter: live_collections.DocumentFilter) !*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const collection = try interfaces.HTMLCollection.init(internal.allocator, instance.ctx);
    errdefer interfaces.HTMLCollection.deinit(collection);
    try live_collections.documentElements(collection, instance, filter);
    return collection;
}

/// Getter for images
/// HTML §4.8.4 - Returns an HTMLCollection of all img elements
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-images
pub fn get_images(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return documentCollection(instance, .images);
}

/// Getter for embeds
/// HTML §4.8.6 - Returns an HTMLCollection of all embed elements
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-embeds
pub fn get_embeds(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return documentCollection(instance, .embeds);
}

/// Getter for plugins
/// HTML §4.8.6 - Returns the same as embeds (alias)
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-plugins
pub fn get_plugins(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return interfaces.Document.get_embeds(instance);
}

/// Getter for links
/// HTML §4.8.2 - Returns an HTMLCollection of all a and area elements with href attribute
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-links
pub fn get_links(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return documentCollection(instance, .links);
}

/// Getter for forms
/// HTML §4.10.3 - Returns an HTMLCollection of all form elements
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-forms
pub fn get_forms(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return documentCollection(instance, .forms);
}

/// Getter for scripts
/// HTML §4.12.1 - Returns an HTMLCollection of all script elements
/// Spec: https://html.spec.whatwg.org/multipage/dom.html#dom-document-scripts
pub fn get_scripts(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return documentCollection(instance, .scripts);
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
    // The window keeps the document's wrapper for as long as it is the
    // document's view (refcount step 5i: one counted keep, `window_kept`) -
    // on the wrapper the edge above made, whose cache entry counts the keep
    // and cannot fail to: a keep the engine could not record (no wrapper
    // under memory pressure, no engine realm) is not taken, so its release
    // ends nothing it did not take. The default-view rule holds the
    // wrapper meanwhile, until step 9(d) makes this keep the only reason.
    if (!internal.window_kept and engine.hasWrapper(instance)) {
        internal.window_kept = true;
        engine.keepPlatformObjectAlive(instance);
    }
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
    // HTML 3.1.6: the tree becomes browsing-context disconnected.
    internal.render_blocking_elements.clear();
    internal.default_view = null;
    // The window's keep ends here (refcount step 5i), and the release makes
    // the wrapper cache read the wrapper's strength again; a document that
    // never had the keep re-reads it with a keep and its release.
    if (internal.window_kept) {
        internal.window_kept = false;
    } else engine.keepPlatformObjectAlive(instance);
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

/// Getter for fgColor
/// HTML §14.3.11 (obsolete) - Returns document's text color
pub fn get_fgColor(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const dom = @import("dom");
    // HTML's obsolete Document colors: only the current HTML body reflects;
    // no body or a frameset returns "". Then DOMString getter steps 1-6.
    const body = (try interfaces.Document.get_body(instance)) orelse return runtime.DOMString.initEmpty();
    const data = dom.element_data.of(body) orelse return error.InvalidStateError;
    if (!std.mem.eql(u8, data.local_name.asSlice(), "body")) return runtime.DOMString.initEmpty();
    var value = try dom.reflection.get(runtime.DOMString, body, .{ .name = "text" });
    defer value.deinit(body.ctx.allocator);
    // An adopted body's realm can differ; this getter's caller frees with
    // the Document's allocator, not the body's.
    return value.clone(instance.ctx.allocator);
}

/// Getter for linkColor
/// HTML §14.3.11 (obsolete) - Returns document's link color
pub fn get_linkColor(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const dom = @import("dom");
    const body = (try interfaces.Document.get_body(instance)) orelse return runtime.DOMString.initEmpty();
    const data = dom.element_data.of(body) orelse return error.InvalidStateError;
    if (!std.mem.eql(u8, data.local_name.asSlice(), "body")) return runtime.DOMString.initEmpty();
    var value = try dom.reflection.get(runtime.DOMString, body, .{ .name = "link" });
    defer value.deinit(body.ctx.allocator);
    return value.clone(instance.ctx.allocator);
}

/// Getter for vlinkColor
/// HTML §14.3.11 (obsolete) - Returns document's visited link color
pub fn get_vlinkColor(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const dom = @import("dom");
    const body = (try interfaces.Document.get_body(instance)) orelse return runtime.DOMString.initEmpty();
    const data = dom.element_data.of(body) orelse return error.InvalidStateError;
    if (!std.mem.eql(u8, data.local_name.asSlice(), "body")) return runtime.DOMString.initEmpty();
    var value = try dom.reflection.get(runtime.DOMString, body, .{ .name = "vlink" });
    defer value.deinit(body.ctx.allocator);
    return value.clone(instance.ctx.allocator);
}

/// Getter for alinkColor
/// HTML §14.3.11 (obsolete) - Returns document's active link color
pub fn get_alinkColor(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const dom = @import("dom");
    const body = (try interfaces.Document.get_body(instance)) orelse return runtime.DOMString.initEmpty();
    const data = dom.element_data.of(body) orelse return error.InvalidStateError;
    if (!std.mem.eql(u8, data.local_name.asSlice(), "body")) return runtime.DOMString.initEmpty();
    var value = try dom.reflection.get(runtime.DOMString, body, .{ .name = "alink" });
    defer value.deinit(body.ctx.allocator);
    return value.clone(instance.ctx.allocator);
}

/// Getter for bgColor
/// HTML §14.3.11 (obsolete) - Returns document's background color
pub fn get_bgColor(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const dom = @import("dom");
    const body = (try interfaces.Document.get_body(instance)) orelse return runtime.DOMString.initEmpty();
    const data = dom.element_data.of(body) orelse return error.InvalidStateError;
    if (!std.mem.eql(u8, data.local_name.asSlice(), "body")) return runtime.DOMString.initEmpty();
    var value = try dom.reflection.get(runtime.DOMString, body, .{ .name = "bgcolor" });
    defer value.deinit(body.ctx.allocator);
    return value.clone(instance.ctx.allocator);
}

/// Getter for anchors
/// HTML (obsolete) - Returns an HTMLCollection of all a elements with name attribute
/// Spec: https://html.spec.whatwg.org/multipage/obsolete.html#dom-document-anchors
pub fn get_anchors(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return documentCollection(instance, .anchors);
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
        const made = interfaces.FontFaceSet.initWith(internal.allocator, instance.ctx, .{ .font_document = instance }) catch return error.OutOfMemory;
        internal.fonts = made;
        internal.fonts_kept.made(made);
        break :blk made;
    };
    internal.fonts_kept.handOut(instance, fonts, .{ .name = "fonts" });
    return fonts;
}

/// Getter for customElementRegistry
/// Returns the custom element registry associated with this document, or null.
/// A registry whose keeper went reads null, never a freed one (CE2-M2).
pub fn get_customElementRegistry(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return (getInternal(instance) orelse return error.InvalidStateError).custom_element_registry.get();
}

fn setCustomElementRegistry(instance: *runtime.Instance, registry: ?*runtime.Instance) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.custom_element_registry.get() != registry) releaseNativeGlobalRegistry(internal);
    internal.custom_element_registry.set(instance, registry);
}

fn releaseNativeGlobalRegistry(internal: *InternalState) void {
    if (internal.owns_native_global_registry and !internal.custom_element_registry.traced) {
        if (internal.custom_element_registry.get()) |registry| runtime.Instance.deinit(registry);
    }
    internal.owns_native_global_registry = false;
}

/// HTML create-and-initialize-a-Document: the global registry belongs to the
/// document. Window replacement must not change the previous document's edge.
fn ensureGlobalRegistry(instance: *runtime.Instance) !*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.custom_element_registry.get()) |registry| {
        if (!internal.custom_element_registry.traced) internal.custom_element_registry.set(instance, registry);
        return registry;
    }
    const registry = try interfaces.CustomElementRegistry.init(instance.ctx.allocator, instance.ctx);
    internal.custom_element_registry.set(instance, registry);
    internal.owns_native_global_registry = !instance.ctx.hasEngine();
    return registry;
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

/// Getter for styleSheets: "a StyleSheetList collection representing the
/// document or shadow root CSS style sheets" (CSSOM 6.2.3) - the list
/// reads this document's style engine live; made on first access.
pub fn get_styleSheets(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const sheets = internal.style_sheets orelse blk: {
        const made = interfaces.StyleSheetList.initWith(internal.allocator, instance.ctx, .{ .sheets_of = instance }) catch return error.OutOfMemory;
        internal.style_sheets = made;
        internal.style_sheets_kept.made(made);
        break :blk made;
    };
    internal.style_sheets_kept.handOut(instance, sheets, .{ .name = "styleSheets" });
    return sheets;
}

/// Getter for adoptedStyleSheets ([SameObject] in effect): the document's
/// ObservableArray<CSSStyleSheet>, made on first read (dom.style.adopted).
/// Spec: https://drafts.csswg.org/cssom/#dom-documentorshadowroot-adoptedstylesheets
pub fn get_adoptedStyleSheets(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = getInternal(instance) orelse return error.InvalidStateError;
    return @import("dom").style.adopted.get(instance);
}

/// dom.style's `document_adopted_sheets`.
fn adoptedSheetsOf(instance: *runtime.Instance) ?*@import("dom").style.adopted.AdoptedSheets {
    // The registry answers only for a Document (its subclasses included).
    const internal = getInternal(instance) orelse return null;
    return &internal.adopted_style_sheets;
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

// Document's own event handler IDL attributes (onreadystatechange,
// onvisibilitychange, ...) are the generated interface's: HTML's getter and
// setter, through dom.event_handlers (HTML 8.1.8.1).

/// HTML document.domain's setter.
/// Spec: https://html.spec.whatwg.org/multipage/browsers.html#dom-document-domain
pub fn set_domain(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const allocator = instance.ctx.allocator;

    // 1. "If this's browsing context is null, then throw a SecurityError." A
    // document has one here exactly when it has a window.
    if (internal.default_view == null) return error.SecurityError;

    // 2. "If this's active sandboxing flag set has its sandboxed
    // document.domain browsing context flag set, then throw a
    // SecurityError." Every sandbox sets it - no keyword lifts it - and it
    // is the set the document was created with, whatever its iframe's
    // sandbox attribute says now.
    if (internal.active_sandboxing_flags.document_domain) return error.SecurityError;

    // 3-4. "Let effectiveDomain be this's origin's effective domain. If
    // effectiveDomain is null, then throw a SecurityError."
    const effective = (try effectiveDomain(instance, internal, allocator)) orelse return error.SecurityError;
    defer allocator.free(effective);

    // 5. "If the given value is not a registrable domain suffix of and is not
    // equal to effectiveDomain, then throw a SecurityError."
    if (!try isRegistrableDomainSuffixOfOrEqualTo(allocator, value, effective)) return error.SecurityError;

    // 6. "If the surrounding agent's agent cluster's is origin-keyed is true,
    // then return." This document's window's agent cluster: script that
    // reaches this document is same origin-domain with it, so in its cluster
    // (Window.originAgentCluster answers for it).
    if (internal.default_view) |window| {
        if (try interfaces.Window.get_originAgentCluster(window)) return;
    }

    // 7. "Set this's origin's domain to the result of parsing the given
    // value."
    const host = url_mod.host_parser.parseHost(allocator, value, false, null) catch return error.SecurityError;
    defer host.deinit(allocator);
    const domain = try url_mod.host_serializer.serializeHost(allocator, host);
    defer allocator.free(domain);
    // The record every document of this origin shares (an about:blank or
    // srcdoc child, the document that made this one): they all see it.
    const record = internal.origin orelse return error.InvalidStateError;
    try record.setDomain(domain);
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
        // TODO (cookies lane Q3): consume the same captured site-for-cookies
        // fact here for same_site_strict_or_lax_allowed (RFC 6265bis 5.7.18).
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
        _ = try interfaces.Node.call_insertBefore(svg, title, interfaces.Node.get_firstChild(svg) catch null);
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
    if ((interfaces.Node.get_nodeType(element) catch 0) != interfaces.Node.get_ELEMENT_NODE()) return false;
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
    _ = getInternal(instance) orelse return error.InvalidStateError;
    // HTML 3.2.6.4: without an html element, setting document.dir does nothing.
    const element = htmlElementOf(instance) orelse return;
    try interfaces.HTMLElement.set_dir(element, value);
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

    // Step 1: Validate new value is body or frameset
    // Per WebIDL, undefined is converted to null for nullable types.
    // Per HTML spec, null is not a valid body element, so throw HierarchyRequestError.
    const actual_value = value orelse return error.HierarchyRequestError;
    const value_node_type = interfaces.Node.get_nodeType(actual_value) catch 0;
    if (value_node_type != interfaces.Node.get_ELEMENT_NODE()) {
        return error.HierarchyRequestError;
    }

    const value_data = @import("dom").element_data.of(actual_value) orelse return error.HierarchyRequestError;
    const tag_name = value_data.local_name.asSlice();

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

/// Setter for fgColor
/// HTML §14.3.11 (obsolete) - Sets document's text color
pub fn set_fgColor(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const dom = @import("dom");
    // No body or a frameset is a no-op. Otherwise run the DOMString
    // reflection setter: set the corresponding content attribute on body.
    const body = (try interfaces.Document.get_body(instance)) orelse return;
    const data = dom.element_data.of(body) orelse return error.InvalidStateError;
    if (!std.mem.eql(u8, data.local_name.asSlice(), "body")) return;
    try dom.reflection.set(runtime.DOMString, body, .{ .name = "text" }, value);
}

/// Setter for linkColor
/// HTML §14.3.11 (obsolete) - Sets document's link color
pub fn set_linkColor(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const dom = @import("dom");
    const body = (try interfaces.Document.get_body(instance)) orelse return;
    const data = dom.element_data.of(body) orelse return error.InvalidStateError;
    if (!std.mem.eql(u8, data.local_name.asSlice(), "body")) return;
    try dom.reflection.set(runtime.DOMString, body, .{ .name = "link" }, value);
}

/// Setter for vlinkColor
/// HTML §14.3.11 (obsolete) - Sets document's visited link color
pub fn set_vlinkColor(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const dom = @import("dom");
    const body = (try interfaces.Document.get_body(instance)) orelse return;
    const data = dom.element_data.of(body) orelse return error.InvalidStateError;
    if (!std.mem.eql(u8, data.local_name.asSlice(), "body")) return;
    try dom.reflection.set(runtime.DOMString, body, .{ .name = "vlink" }, value);
}

/// Setter for alinkColor
/// HTML §14.3.11 (obsolete) - Sets document's active link color
pub fn set_alinkColor(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const dom = @import("dom");
    const body = (try interfaces.Document.get_body(instance)) orelse return;
    const data = dom.element_data.of(body) orelse return error.InvalidStateError;
    if (!std.mem.eql(u8, data.local_name.asSlice(), "body")) return;
    try dom.reflection.set(runtime.DOMString, body, .{ .name = "alink" }, value);
}

/// Setter for bgColor
/// HTML §14.3.11 (obsolete) - Sets document's background color
pub fn set_bgColor(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const dom = @import("dom");
    const body = (try interfaces.Document.get_body(instance)) orelse return;
    const data = dom.element_data.of(body) orelse return error.InvalidStateError;
    if (!std.mem.eql(u8, data.local_name.asSlice(), "body")) return;
    try dom.reflection.set(runtime.DOMString, body, .{ .name = "bgcolor" }, value);
}

/// Setter for adoptedStyleSheets: WebIDL's for an observable array
/// attribute - the value converted to sequence<CSSStyleSheet>, then the
/// backing list replaced, each value through CSSOM's set-an-indexed-value
/// check (dom.style.adopted).
pub fn set_adoptedStyleSheets(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
    _ = getInternal(instance) orelse return error.InvalidStateError;
    try @import("dom").style.adopted.set(instance, value);
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

    // The Editing spec's commands in the html module (src/html/execcommand/):
    // null is "has no state" (step 1: false).
    if (@import("html").execcommand.Command.fromName(command_name)) |command| {
        return @import("html").execcommand.queryState(instance, command) orelse false;
    }

    return editing.queryCommandState(
        internal.allocator,
        @ptrCast(instance),
        command_name,
    ) catch false;
}

/// HTML 8.5.2 parseHTML, steps 1–6: an inactive HTML document, with the
/// relevant origin and declarative shadow roots, followed by safe filtering.
pub fn call_static_parseHTML(instance: *runtime.Instance, html: runtime.DOMString, options: webidl.Opt(dictionaries.SetHTMLOptions)) anyerror!*runtime.Instance {
    var converted = try @import("html").sanitizer.convertOptions(instance.ctx, options.getOrDefault(.{}).sanitizer, true);
    defer converted.deinit();
    const allocator = instance.ctx.allocator;
    const realm = engine.currentRealm() orelse instance.ctx;
    const origin: ?*OriginRecord = if (globalOfRealm(realm)) |global| try @import("dom").global_settings.shareableOriginOf(global) else null;
    const document = @import("html").dom_parser.parseHTML(allocator, realm, html.asSlice(), .{ .allow_declarative_shadow_roots = true, .origin = origin }) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.NotSupportedError,
    };
    errdefer @import("dom").node_creation.destroyUninserted(document);
    try @import("dom").document_internals.setContentType(document, "text/html");
    try @import("html").sanitizer.filterDocument(document, &converted, true);
    // To script: its first wrapper takes its born reference (refcount7).
    @import("dom").refcount.offerDocument(document);
    return document;
}

/// HTML 8.5.2 parseHTMLUnsafe, steps 1–7.
pub fn call_static_parseHTMLUnsafe(instance: *runtime.Instance, html: typedefs.TrustedHTMLOrDOMString, options: webidl.Opt(dictionaries.ParseHTMLUnsafeOptions)) anyerror!*runtime.Instance {
    var converted = try @import("html").sanitizer.convertOptions(instance.ctx, options.getOrDefault(.{}).sanitizer, false);
    defer converted.deinit();
    // Step 1: "Let compliantHTML be the result of invoking the get trusted
    // type compliant string algorithm with TrustedHTML, the current global
    // object, html, "Document parseHTMLUnsafe", and "script"."
    const allocator = instance.ctx.allocator;
    const realm = engine.currentRealm() orelse instance.ctx;
    const compliant = try @import("dom").trusted_types.compliantStringForRealm(allocator, .html, realm, html, "Document parseHTMLUnsafe");
    defer allocator.free(compliant);
    // Steps 2-4: "Let document be a new Document, whose content type is
    // "text/html" and origin is this's relevant global object's associated
    // Document's origin" (no browsing context: scripting is disabled); "set
    // document's allow declarative shadow roots to true"; "parse HTML from a
    // string given document and compliantHTML" - whose parser takes the
    // document's allow declarative shadow roots.
    const origin: ?*OriginRecord = if (globalOfRealm(realm)) |global| try @import("dom").global_settings.shareableOriginOf(global) else null;
    const document = @import("html").dom_parser.parseHTML(allocator, realm, compliant, .{ .allow_declarative_shadow_roots = true, .origin = origin }) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.NotSupportedError,
    };
    const document_internals = @import("dom").document_internals;
    errdefer @import("dom").node_creation.destroyUninserted(document);
    try document_internals.setContentType(document, "text/html");
    // Steps 5–6: configure the sanitizer and filter the parsed document -
    // only when a sanitizer was given (row 41 review M2/S2: an absent one
    // filters nothing, so skip the tree walk).
    if (options.getOrDefault(.{}).sanitizer != null) try @import("html").sanitizer.filterDocument(document, &converted, false);
    // To script: its first wrapper takes its born reference (refcount7).
    @import("dom").refcount.offerDocument(document);
    return document;
}

/// `realm`'s global object, if it has one.
fn globalOfRealm(realm: runtime.Context) ?*runtime.Instance {
    const engine_realm = realm.realm orelse return null;
    return @ptrCast(@alignCast(engine_realm.global_object orelse return null));
}

/// Operation: exitPictureInPicture
pub fn call_exitPictureInPicture(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: createExpression
pub fn call_createExpression(instance: *runtime.Instance, expression: runtime.DOMString, resolver: webidl.Opt(??*runtime.CallbackWrapper)) anyerror!*runtime.Instance {
    // DOM XPath: compile once; namespace callbacks run during construction.
    return interfaces.XPathExpression.initWith(instance.ctx.allocator, instance.ctx, .{
        .expression = expression,
        .resolver = resolver,
    });
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
    const flattened = try @import("html").custom_element_creation.flatten(instance, options);
    defer flattened.deinit(allocator);
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
        .is_value = flattened.is_value,
        .registry = .{ .explicit = flattened.registry },
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

/// Operation: open
/// HTML §8.4.1 - Opens the document for writing
/// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-document-open
///
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

    // Steps 3-4: the entry document's origin, before the parser/unload early
    // returns. document.domain relaxation does not change this comparison.
    const entry_document = documentOfRealm(engine.entryRealm()) orelse instance;
    if (!try sameOriginForOpen(instance, entry_document)) return error.SecurityError;
    const entry_pin = if (entry_document.ctx.hasEngine())
        try engine.retainValue(entry_document.ctx, .{ .instance = entry_document })
    else
        null;
    defer if (entry_pin) |held| held.release();

    // Step 5: "If document has an active parser whose script nesting level
    // is greater than 0, then return document." - an inline script of the
    // page being parsed calls document.open(), which is ignored. The parser
    // nesting level comes from tree construction, since a script-created
    // parser also has an insertion point while no script is running.
    if (internal.input_stream_manager) |stream| {
        if (stream.isExecutingScript()) return instance;
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
    @import("dom").content_navigables.stopLoadingIfNavigating(instance);

    // Detach the previous parser before replacing its DOM.
    // A parser pump currently on the stack keeps its own reference until
    // that invocation has restored its input stream's insertion limits.
    internal.script_delivery_continuation_suppressed = true;
    @import("html").script_execution.discardParserScripts(instance);
    discardDocumentParser(internal);
    internal.parsing_end_waiting_on_scripts = false;
    // Step 16 replaces the parser. An old "the end" suspended at steps
    // 7-8 no longer completes this stream; only its explicit EOF can do so.
    // Post-load readiness and completely-loaded time remain unchanged.
    internal.load_waiting_on_delay = false;

    // Step 9: "For each shadow-including inclusive descendant node of
    // document, erase all event listeners and handlers given node."
    eraseListenersOfTree(instance);

    // Step 10: "If document is the associated Document of document's
    // relevant global object, then erase all event listeners and handlers
    // given document's relevant global object."
    if (internal.default_view) |window| {
        if ((interfaces.Window.get_document(window) catch null) == instance) {
            @import("dom").event_handlers.eraseAll(window);
        }
    }

    // Step 11: "Replace all with null within document."
    // Keep removals in open's outer reaction scope. An inner removeChild
    // scope would invoke disconnected callbacks before step 16's parser.
    const dom = @import("dom");
    const document_base = dom.instance_bridge.getNodeBase(instance) orelse return error.InvalidStateError;
    try dom.mutation.replaceAll(@as(?*dom.NodeBase, null), document_base);

    // Reset document element and doctype references
    internal.document_element = null;
    internal.doctype = null;

    // Step 12: update the current history entry in place. The default
    // serializedData preserves history.state. Only a different entry
    // document loses its fragment; a detached document keeps its own URL.
    if (isFullyActive(instance)) {
        const entry_url = try interfaces.Document.get_URL(entry_document);
        defer entry_document.ctx.allocator.free(entry_url);
        const end = if (entry_document == instance) entry_url.len else std.mem.indexOfScalar(u8, entry_url, '#') orelse entry_url.len;
        if (internal.default_view) |window| {
            @import("dom").history_traversal.urlAndHistoryUpdate(window, entry_url[0..end], null, .replace);
            // Associated documents read the context's live URL. Drop a
            // prior explicit URL so later pushState updates stay visible.
            if (internal.url.len > 0) internal.allocator.free(internal.url);
            internal.url = "";
            // The cookie URL becomes the entry document's (its cookie URL,
            // not its current URL) - two of three browsers: Blink's
            // Document::open sets cookie_url_ to the entered window's
            // document's CookieURL() (document.cc, whose own comment weighs
            // removing it and keeps it for web compatibility), WebKit's does
            // setCookieURL(entryDocument->cookieURL()) (Document.cpp). The
            // URL update above is a same-document change, which leaves it.
            if (entry_document != instance) {
                if (getInternal(entry_document)) |entry_internal| if (entry_internal.default_view) |entry_window| {
                    if (dom.global_settings.cookieUrlOf(entry_window)) |cookie_url| window.ctx.setCreationUrl(cookie_url) catch {};
                };
            }
        }
    }

    // Step 13: "Set document's is initial about:blank to false."
    internal.is_initial_about_blank = false;

    // Step 14: "If document's iframe load in progress flag is set, then set
    // document's mute iframe load flag." A load handler that writes to its
    // frame's document does not make the frame fire load again.
    if (internal.iframe_load_in_progress) internal.mute_iframe_load = true;

    // Step 15: "Set document to no-quirks mode."
    internal.mode = .no_quirks;

    // Steps 16-17: create a parser that waits for document.close()'s EOF,
    // with its insertion point just before its empty stream's end.
    // Steps 11-12 can run unload/currententrychange handlers that open this
    // document again. Association replaces that parser too: release its
    // scripts and the document's reference before installing our parser.
    internal.script_delivery_continuation_suppressed = true;
    @import("html").script_execution.discardParserScripts(instance);
    discardDocumentParser(internal);
    internal.parsing_end_waiting_on_scripts = false;
    internal.load_waiting_on_delay = false;
    const parser = try @import("html").scripted_parser.DocumentParser.create(
        internal.allocator,
        instance.ctx,
        instance,
        // HTML 8.1.3.4: scripting is disabled for a node whose document's
        // browsing context is null, including a retained destroyed document.
        internal.default_view != null and !internal.destroyed and isScriptingEnabled(instance),
        &activeParserFinished,
    );
    internal.parser_epoch +%= 1;
    parser.document_epoch = internal.parser_epoch;
    internal.script_delivery_continuation_suppressed = false;
    internal.active_parser = parser;
    internal.input_stream_manager = &parser.input_stream;
    internal.is_script_created_parser = true;
    internal.insertion_point = 0;

    // Step 18: update readiness after erasing the old listeners.
    updateReadiness(instance, ._loading_);

    // Return the document
    return instance;
}

fn documentOfRealm(realm: ?runtime.Context) ?*runtime.Instance {
    const record = (realm orelse return null).getRealm() orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    if (global.stateAs(interfaces.Window.State) == null) return null;
    return interfaces.Window.get_document(global) catch null;
}

fn sameOriginForOpen(document: *runtime.Instance, entry_document: *runtime.Instance) !bool {
    // A detached document created in this realm inherits its creator's
    // origin, including an opaque origin's identity.
    if (document.ctx == entry_document.ctx) return true;
    const own_document = if ((getInternal(document) orelse return false).default_view == null)
        documentOfRealm(document.ctx) orelse document
    else
        document;
    const own = try serializedOrigin(own_document, getInternal(own_document) orelse return false, document.ctx.allocator);
    defer if (own) |value| document.ctx.allocator.free(value);
    const entry = try serializedOrigin(entry_document, getInternal(entry_document) orelse return false, document.ctx.allocator);
    defer if (entry) |value| document.ctx.allocator.free(value);
    if (own == null or entry == null) return false;
    return std.mem.eql(u8, own.?, entry.?);
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
        @import("dom").event_handlers.eraseAll(current);
        if (@import("dom").shadow_hosts.rootForHost(current)) |shadow| {
            eraseListenersOfTree(shadow);
        }
        if (interfaces.Node.get_firstChild(current) catch null) |first| {
            node = first;
            continue;
        }
        var cursor = current;
        node = while (true) {
            if (cursor == document) break null;
            if (interfaces.Node.get_nextSibling(cursor) catch null) |next| break next;
            cursor = (interfaces.Node.get_parentNode(cursor) catch null) orelse break null;
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

    // The Editing spec's commands in the html module
    // (src/html/execcommand/), which runs the method's enabled check and
    // input event itself; value is "" when not passed (step 2).
    if (@import("html").execcommand.Command.fromName(command_name)) |command| {
        return @import("html").execcommand.execCommand(instance, command, value_slice orelse "");
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

    // Keep document.open()'s parser alive through nested script and through
    // processInserted restoring the stream's limits. Reentrant open/close
    // can detach it before the outer write has returned.
    var kept_parser = internal.active_parser;
    var parser_call: ?@import("html").scripted_parser.DocumentParser.ActiveCall = if (kept_parser) |parser|
        try parser.protect()
    else
        null;
    defer if (parser_call) |held| held.deinit();

    // A parser is running (the document's own, a frame's, or a script-created)
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
            if (kept_parser) |parser| try parser.finishIfPossible();
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
        if (parser_call) |held| held.deinit();
        parser_call = null;
        kept_parser = internal.active_parser;
        if (kept_parser) |parser| parser_call = try parser.protect();
    }
    const stream = internal.input_stream_manager orelse return;
    // Steps 10-11 apply to the newly created parser as to an existing one.
    try stream.insert(string.items);
    if (internal.scripts.pending_parsing_blocking_script == null) stream.processInserted();
    if (kept_parser) |parser| try parser.finishIfPossible();
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

    // The Editing spec's commands in the html module: null is "has no
    // indeterminacy" (step 1: false).
    if (@import("html").execcommand.Command.fromName(command_name)) |command| {
        return @import("html").execcommand.queryIndeterm(instance, command) orelse false;
    }

    return editing.queryCommandIndeterm(
        internal.allocator,
        @ptrCast(instance),
        command_name,
    ) catch false;
}

/// Operation: getElementsByTagNameNS
pub fn call_getElementsByTagNameNS(instance: *runtime.Instance, namespace: ?runtime.DOMString, localName: runtime.DOMString) anyerror!*runtime.Instance {
    // DOM: "return the list of elements with namespace namespace and local
    // name localName for this" - a LIVE collection (dom.live_collections).
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const collection = try interfaces.HTMLCollection.init(internal.allocator, instance.ctx);
    errdefer interfaces.HTMLCollection.deinit(collection);
    try live_collections.elementsWithNamespaceAndLocalName(collection, instance, if (namespace) |ns| ns.asSlice() else null, localName.asSlice());
    return collection;
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

    // Create/initialize a processing instruction, steps 1-2: validate XML
    // Name and forbid ?> in data (the constructor shares these conditions).
    if (!@import("dom").pi_attributes.isXmlName(target.asSlice()) or std.mem.indexOf(u8, data.asSlice(), "?>") != null)
        return error.InvalidCharacterError;
    const pi = try interfaces.ProcessingInstruction.initWith(internal.allocator, instance.ctx, .{
        .target = target.asSlice(),
        .data = data.asSlice(),
    });
    errdefer interfaces.ProcessingInstruction.deinit(pi);
    try @import("dom").node_document.set(pi, instance);

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
    if (@import("dom").event_dispatch.of(event)) |state| state.initialized_flag = false;

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

/// Operation: getAnimations (Web Animations 1 6.10): the relevant
/// animations for this document's subtree, in composite order.
pub fn call_getAnimations(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return @import("dom").animations.rootAnimations(instance);
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
/// Spec: https://dom.spec.whatwg.org/#dom-document-getelementsbytagname
///
/// "The getElementsByTagName(qualifiedName) method steps are to return the
/// list of elements with qualified name qualifiedName for this" - a LIVE
/// collection (dom.live_collections), which holds this document (refcount
/// design 5h). It was a snapshot that compared local names ignoring case for
/// every element of an HTML document.
pub fn call_getElementsByTagName(instance: *runtime.Instance, qualifiedName: runtime.DOMString) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const collection = try interfaces.HTMLCollection.init(internal.allocator, instance.ctx);
    errdefer interfaces.HTMLCollection.deinit(collection);
    try live_collections.elementsWithQualifiedName(collection, instance, qualifiedName.asSlice());
    return collection;
}

/// Operation: evaluate
pub fn call_evaluate(instance: *runtime.Instance, expression: runtime.DOMString, contextNode: *runtime.Instance, resolver: webidl.Opt(??*runtime.CallbackWrapper), @"type": webidl.Opt(u16), result: webidl.Opt(?*runtime.Instance)) anyerror!*runtime.Instance {
    // DOM Level 3 XPath §1.4: compile, evaluate and convert to the requested type.
    const compiled = try interfaces.XPathExpression.initWith(instance.ctx.allocator, instance.ctx, .{
        .expression = expression,
        .resolver = resolver,
    });
    // This private, unwrapped temporary owns both its grammar and instance storage.
    defer runtime.Instance.deinit(compiled);
    return interfaces.XPathExpression.call_evaluate(compiled, contextNode, @"type", result);
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
    var fallback_registry: ?*runtime.Instance = null;
    var registry_root: ?engine.Owned = null;
    defer if (registry_root) |root| root.release();
    const subtree = if (!options.was_passed) false else switch (engine.typeOf(realm, options.value)) {
        .undefined => false,
        .null => true,
        .object => blk: {
            // WebIDL dictionary conversion reads customElementRegistry first;
            // unlike ElementCreationOptions its type is non-nullable.
            const registry_value = try engine.getProperty(realm, options.value, "customElementRegistry");
            registry_root = registry_value;
            if (engine.typeOf(realm, registry_value.value) != .undefined) {
                const registry = engine.convertToPlatformObject(realm, registry_value.value) orelse return error.TypeError;
                if (registry.stateAs(interfaces.CustomElementRegistry.State) == null) return error.TypeError;
                fallback_registry = registry;
            }
            const self_only = try engine.getProperty(realm, options.value, "selfOnly");
            defer self_only.release();
            break :blk !engine.toBoolean(realm, self_only.value);
        },
        else => engine.toBoolean(realm, options.value),
    };
    if (was_live and !realm.hasEngine()) return error.InvalidStateError;
    if (fallback_registry) |registry| {
        if (!@import("dom").custom_elements.isScoped(registry) and registry != try get_customElementRegistry(instance)) return error.NotSupportedError;
    }
    // Steps 6–7: the fallback applies only to null source associations.
    if (fallback_registry == null) fallback_registry = try get_customElementRegistry(instance);
    return dom_creation.cloneWithRegistry(node, instance, subtree, null, fallback_registry);
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

    // DOM createCDATASection step 2 follows the HTML-document check.
    if (std.mem.indexOf(u8, data.asSlice(), "]]>") != null) return error.InvalidCharacterError;

    // Step 3: create the node with this as its node document.
    const cdata = try interfaces.CDATASection.init(internal.allocator, instance.ctx);
    errdefer interfaces.CDATASection.deinit(cdata);

    // DOM 4.5: the new CDATASection node's data is `data`.
    try interfaces.CharacterData.set_data(cdata, data);

    // Set owner document
    try @import("dom").node_document.set(cdata, instance);

    return cdata;
}

/// Operation: queryCommandEnabled
/// Returns whether an editing command is currently enabled.
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-document-querycommandenabled
pub fn call_queryCommandEnabled(instance: *runtime.Instance, commandId: runtime.DOMString) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    const command_name = commandId.asSlice();

    // delete and forwardDelete: the Editing spec's "enabled" (the active
    // range lies in one editing host).
    if (@import("html").execcommand.Command.fromName(command_name)) |command| {
        return @import("html").execcommand.isEnabled(instance, command);
    }

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
/// HTML §6.6.6 - Whether this document is in the focused document chain.
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-document-hasfocus
pub fn call_hasFocus(instance: *runtime.Instance) anyerror!bool {
    // Has-focus steps 1-2 start from the node navigable's active document.
    // A windowless, destroyed or inactive document cannot be on that chain.
    if (!isFullyActive(instance)) return false;
    // The method's step is to run the existing has-focus steps. Their
    // system-focus policy and descent through child navigables are shared
    // with the focusing implementation.
    return @import("html").focus.hasFocus(instance);
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
/// 3. Adopt node into this document (including hosted template fragments).
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

    // Create-text-node steps: copy data without the script constructor's
    // current-global requirement, then assign this node document.
    const text = try interfaces.Text.initWith(instance.ctx.allocator, instance.ctx, .{ .data = data.asSlice() });
    errdefer interfaces.Text.deinit(text);

    // Set owner document
    try @import("dom").node_document.set(text, instance);

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
/// HTML's live NodeList contains HTML elements with an identical name.
/// A fresh list owns the query string; root retention is a refcount follow-up.
pub fn call_getElementsByName(instance: *runtime.Instance, elementName: runtime.DOMString) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const list = try interfaces.NodeList.init(internal.allocator, instance.ctx);
    errdefer interfaces.NodeList.deinit(list);
    try @import("dom").node_lists.elementsByName(list, instance, elementName.asSlice());
    return list;
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

    // The Editing spec's commands in the html module: null is "has no
    // value" (step 1: the empty string).
    if (@import("html").execcommand.Command.fromName(command_name)) |command| {
        const value = (@import("html").execcommand.queryValue(instance, command, instance.ctx.allocator) catch null) orelse return runtime.DOMString.initEmpty();
        if (value.len == 0) {
            instance.ctx.allocator.free(value);
            return runtime.DOMString.initEmpty();
        }
        return runtime.DOMString.initOwned(value);
    }

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

    // Create-comment-node steps: data and node document come from this call.
    const comment = try interfaces.Comment.initWith(instance.ctx.allocator, instance.ctx, .{ .data = data.asSlice() });
    errdefer interfaces.Comment.deinit(comment);

    // Set owner document
    try @import("dom").node_document.set(comment, instance);

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

    // Selection API: a document without a browsing context has no selection.
    if (internal.destroyed or internal.default_view == null) return null;

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
    @import("dom").selection.bindDocument(selection, instance);
    return selection;
}

/// Operation: close
/// HTML §8.4.4 - Closes the document output stream
/// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-document-close
///
/// Algorithm:
/// 1. If throw-on-dynamic-markup-insertion counter > 0, throw InvalidStateError
/// 2. If no script-created parser, return
/// 3. Return if there is no script-created parser
/// 4-6. Insert explicit EOF and resume the existing tokenizer
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

    const parser = internal.active_parser orelse return;
    const parser_call = try parser.protect();
    defer parser_call.deinit();
    try parser.close();
}

fn discardDocumentParser(internal: *InternalState) void {
    const parser = internal.active_parser orelse return;
    internal.active_parser = null;
    if (internal.input_stream_manager == &parser.input_stream) internal.input_stream_manager = null;
    internal.is_script_created_parser = false;
    internal.insertion_point = null;
    parser.detach();
    parser.release();
}

fn lifecycleAssociateParser(document: *runtime.Instance, opaque_parser: *anyopaque) bool {
    const internal = getInternal(document) orelse return false;
    const parser: *@import("html").scripted_parser.DocumentParser = @ptrCast(@alignCast(opaque_parser));
    internal.script_delivery_continuation_suppressed = true;
    @import("html").script_execution.discardParserScripts(document);
    discardDocumentParser(internal);
    internal.parser_epoch +%= 1;
    parser.document_epoch = internal.parser_epoch;
    internal.script_delivery_continuation_suppressed = false;
    parser.retain();
    internal.active_parser = parser;
    internal.input_stream_manager = &parser.input_stream;
    internal.insertion_point = null;
    internal.is_script_created_parser = false;
    internal.active_parser_was_aborted = false;
    internal.parsing_end_waiting_on_scripts = false;
    internal.load_waiting_on_delay = false;
    internal.scripting_enabled = parser.script_context.scripting_enabled;
    updateReadiness(document, ._loading_);
    return true;
}

fn lifecycleDiscardParser(document: *runtime.Instance, expected: ?*anyopaque) void {
    const internal = getInternal(document) orelse return;
    if (expected) |parser| if (internal.active_parser != @as(*@import("html").scripted_parser.DocumentParser, @ptrCast(@alignCast(parser)))) return;
    internal.script_delivery_continuation_suppressed = true;
    @import("html").script_execution.discardParserScripts(document);
    discardDocumentParser(internal);
}

fn lifecycleParserFinished(document: *runtime.Instance, parser: *anyopaque) void {
    activeParserFinished(document, @ptrCast(@alignCast(parser)));
}

fn activeParserFinished(instance: *runtime.Instance, parser: *@import("html").scripted_parser.DocumentParser) void {
    const internal = getInternal(instance) orelse return;
    if (internal.active_parser != parser) return;
    // End the parser association before the readiness events can run script.
    discardDocumentParser(internal);
    theEnd(instance);
}

// =============================================================================
// "The end" (HTML §13.2.7) for any document parser
// =============================================================================

/// "Update the current document readiness": if `readiness` is new, set it
/// and fire readystatechange at the document.
fn updateReadiness(instance: *runtime.Instance, readiness: enums.DocumentReadyState) void {
    const internal = getInternal(instance) orelse return;
    // Steps 1-2.
    if (internal.ready_state == readiness) return;
    internal.ready_state = readiness;
    // Font Loading 3 §3.1: schedule an existing set's environment check.
    // Readiness changes never create a font set or run its author reactions.
    if (internal.fonts) |fonts| if (@import("dom").style.hooks.fontSetOf(fonts)) |set| set.environmentChanged();
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

/// "The end" from step 3, once the active parser reaches EOF: step 5
/// runs the scripts that will execute when the document has finished
/// parsing - a defer script document.write() put in the stream - as the
/// navigation and written parsers both use these guarded lifecycle steps.
/// Deviation, stated: load's legacy target override is not modelled.
fn theEnd(instance: *runtime.Instance) void {
    const realm = instance.ctx;
    const had_engine = realm.hasEngine();
    const generation = runtime.SlabAllocator.generationOf(instance);
    const epoch = (getInternal(instance) orelse return).parser_epoch;
    lifecycleParsingStopped(instance);
    // HTML "the end" belongs to the parser that stopped. WebKit's
    // HTMLDocumentParser::prepareToStopParsing checks isDetached after the
    // interactive event; document.open may have installed another parser.
    if ((had_engine and !realm.hasEngine()) or runtime.SlabAllocator.generationOf(instance) != generation) return;
    const internal = getInternal(instance) orelse return;
    if (internal.parser_epoch != epoch) return;
    const scripting = (get_defaultView(instance) catch null) != null;
    if (scripting) {
        @import("html").script_execution.executeScriptsWhenParsingFinished(internal.allocator, instance);
    }
    if ((had_engine and !realm.hasEngine()) or runtime.SlabAllocator.generationOf(instance) != generation) return;
    if ((getInternal(instance) orelse return).parser_epoch != epoch) return;
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

/// HTML XML parsing uses the same end steps (§14.2, §13.2.7). Until the
/// navigation XML parser exists, its received empty document still needs
/// readiness, queued lifecycle events, and ready-for-post-load state.
fn lifecycleFinishWithoutParser(document: *runtime.Instance) void {
    const internal = getInternal(document) orelse return;
    if (internal.active_parser != null or internal.ready_state != ._loading_) return;
    theEnd(document);
}

fn becomeInteractive(data: ?*anyopaque) void {
    const document: *runtime.Instance = @ptrCast(@alignCast(data.?));
    const generation = runtime.SlabAllocator.generationOf(document);
    updateReadiness(document, ._interactive_);
    // "The end" step 4 and "abort a parser" step 4 pop every node off the
    // stack of open elements after step 3's readiness change, and each pop
    // processes the expect links (HTML 13.2.4.3), which a readiness other
    // than "loading" unblocks. Deviation, stated: Crane's tree builder pops
    // them all as it stops at the end of the input, BEFORE this readiness
    // change (TreeBuilder.popAllOpenElements), so the links are processed
    // once more here - the listeners of readystatechange may have destroyed
    // the document.
    if (runtime.SlabAllocator.generationOf(document) != generation) return;
    @import("dom").document_rendering.processInternalResourceLinks(document, null);
}

fn becomeComplete(data: ?*anyopaque) void {
    updateReadiness(@ptrCast(@alignCast(data.?)), ._complete_);
}

/// HTML "abort a document", steps 2 and 4. Fetch cancellation can run XHR
/// listeners synchronously; keep the document through those callbacks and
/// read its parser association again afterwards. Unsalvageable is a bfcache
/// property, independent of whether the document is still fully active.
fn lifecycleAbort(document: *runtime.Instance) void {
    abortDocument(document, false);
}

fn lifecycleAbortForNavigation(document: *runtime.Instance) void {
    abortDocument(document, true);
}

/// Only fetch-owner policy distinguishes provisional navigation here;
/// parser cancellation and all other lifecycle steps remain shared.
fn abortDocument(document: *runtime.Instance, for_navigation: bool) void {
    // Fetch cancellation can synchronously drop delivery tasks. Normal load
    // continuation is already forbidden before any cancellation callback.
    if (getInternal(document)) |internal| internal.script_delivery_continuation_suppressed = true;
    const realm = document.ctx;
    const had_engine = realm.hasEngine();
    const pin: ?engine.Owned = if (had_engine)
        engine.retainValue(realm, .{ .instance = document }) catch return
    else
        null;
    defer if (pin) |held| held.release();
    const generation = runtime.SlabAllocator.generationOf(document);
    // "Abort a document" cancels its fetches, clearing script/resource
    // delays. An already-ready child's written stream may hold the parent's
    // last delay with no navigation in progress (iframe delay predicate 3).
    // Wake only the parent: this parser must not resume or fire load.
    defer {
        if ((!had_engine or realm.hasEngine()) and runtime.SlabAllocator.generationOf(document) == generation) {
            @import("dom").content_navigables.loadDelayMayHaveEnded(document);
        }
    }
    const document_fetches = @import("dom").document_fetches;
    const canceled = if (for_navigation) document_fetches.abortForNavigation(document) else document_fetches.abort(document);
    if (had_engine and !realm.hasEngine()) return;
    if (runtime.SlabAllocator.generationOf(document) != generation) return;
    const internal = getInternal(document) orelse return;
    // Step 2: "If this resulted in any instances of the fetch algorithm
    // being canceled ..., then make document unsalvageable given document
    // and "fetch"."
    if (canceled) makeUnsalvageable(document, .fetch);
    internal.parsing_end_waiting_on_scripts = false;
    if (internal.input_stream_manager == null and internal.active_parser == null) return;
    if (internal.active_parser) |failed| if (failed.trace_failure != null) {
        // A failed trace append already discarded input. It must still be
        // cancellable, without resuming parsing or running cleanup callbacks.
        // If the root cannot be reacquired, preserve the Document association
        // for later destruction rather than clear its sole collector edge.
        const cleanup_call = failed.protectForCleanup() catch return;
        defer cleanup_call.deinit();
        internal.active_parser_was_aborted = true;
        // Step 4.3: "Make document unsalvageable given document and
        // "parser-aborted"."
        makeUnsalvageable(document, .parser_aborted);
        @import("html").script_execution.discardParserScripts(document);
        if (had_engine and !realm.hasEngine()) return;
        if (runtime.SlabAllocator.generationOf(document) != generation) return;
        const current = getInternal(document) orelse return;
        if (current.active_parser == failed) discardDocumentParser(current);
        return;
    };
    const stream = internal.input_stream_manager;
    if (stream) |input| if (input.aborted) return;
    const parser = internal.active_parser;
    const parser_call: ?@import("html").scripted_parser.DocumentParser.ActiveCall = if (parser) |active|
        active.protect() catch return
    else
        null;
    defer if (parser_call) |held| held.deinit();
    internal.active_parser_was_aborted = true;
    // Step 4.3: "Make document unsalvageable given document and
    // "parser-aborted"."
    makeUnsalvageable(document, .parser_aborted);
    @import("html").script_execution.discardParserScripts(document);
    // "Abort a parser", steps 1-2 discard the input, step 3 announces
    // interactive, step 4 pops the open elements, then step 5 is complete.
    // Keep the original parser through readiness listeners and do not clear
    // another parser's association if a callback replaced this one.
    if (stream) |input| input.discardInput();
    engine.runInRealm(realm, becomeInteractive, document) catch {};
    if (had_engine and !realm.hasEngine()) return;
    if (runtime.SlabAllocator.generationOf(document) != generation) return;
    if (stream) |input| input.abort();
    if (had_engine and !realm.hasEngine()) return;
    if (runtime.SlabAllocator.generationOf(document) != generation) return;
    const current = getInternal(document) orelse return;
    if (current.active_parser == parser) discardDocumentParser(current);
    if (current.input_stream_manager == stream) {
        current.input_stream_manager = null;
        current.insertion_point = null;
    }
    engine.runInRealm(realm, becomeComplete, document) catch {};
}

/// dom.bfcache: HTML "make document unsalvageable" given `document` and
/// `reason`: "1. Let details be a new not restored reason details whose
/// reason is reason. 2. Append details to document's bfcache blocking
/// details. 3. Set document's salvageable state to false."
fn makeUnsalvageable(document: *runtime.Instance, reason: @import("dom").bfcache.Reason) void {
    const internal = getInternal(document) orelse return;
    internal.bfcache_blocking_details.append(reason);
    internal.salvageable = false;
}

/// dom.bfcache: `document`'s bfcache blocking details, BORROWED.
fn bfcacheBlockingDetails(document: *runtime.Instance) []const @import("dom").bfcache.Reason {
    const internal = getInternal(document) orelse return &.{};
    return internal.bfcache_blocking_details.items();
}

/// dom.bfcache: the document's own part of unload step 5's
/// intendToKeepInBfcache - "This must be false if oldDocument is not
/// salvageable" - and its current document readiness "complete": Blink keeps
/// only a page whose load has finished (back_forward_cache_impl.cc,
/// kLoading), and the WPT helpers navigate away only after load.
fn bfcacheMayKeep(document: *runtime.Instance) bool {
    const internal = getInternal(document) orelse return false;
    if (internal.destroyed or !internal.salvageable) return false;
    return internal.ready_state == ._complete_;
}

/// dom.bfcache: the user agent intends to keep `document` (unload step 5).
fn bfcacheIntendToKeep(document: *runtime.Instance) void {
    const internal = getInternal(document) orelse return;
    internal.intend_to_keep = true;
}

/// dom.bfcache: whether `document`'s last unload kept it.
fn bfcacheIsKept(document: *runtime.Instance) bool {
    const internal = getInternal(document) orelse return false;
    return internal.kept_in_bfcache and !internal.destroyed;
}

/// dom.bfcache: HTML "reactivate" `document`, its navigable's active
/// document again, in its realm (the restore runs from a task).
fn bfcacheReactivate(document: *runtime.Instance) void {
    engine.runInRealm(document.ctx, reactivateSteps, document) catch |err| {
        log.debug("reactivate not run: {}", .{err});
    };
}

/// HTML "reactivate" (7.4.6.4) for a document out of the back/forward cache.
///
/// Step 1 (the form controls whose autofill field name is "off" are reset)
/// is not run, stated: Crane fills no form control in, so none holds a value
/// the user agent restored. Step 2 - the suspended timers moved by the
/// suspension's length - is the cache's, before this (dom.bfcache.reactivate:
/// each timer waits what it had left). Step 3, "update the navigation API
/// entries for reactivation", and pagereveal are phase C's.
fn reactivateSteps(data: ?*anyopaque) void {
    const document: *runtime.Instance = @ptrCast(@alignCast(data.?));
    const internal = getInternal(document) orelse return;
    internal.kept_in_bfcache = false;
    const window = (get_defaultView(document) catch null) orelse return;
    // Step 4: "If document's current document readiness is "complete", and
    // document's page showing is false":
    if (internal.ready_state != ._complete_ or internal.page_showing) return;
    // 4.1. "Set document's page showing to true."
    internal.page_showing = true;
    // 4.2. "Set document's has been revealed to false." Its next rendering
    // opportunity reveals it (pagereveal), so it asks for one.
    internal.has_been_revealed = false;
    @import("dom").update_the_rendering.requestFrame(document);
    // 4.3. "Update the visibility state of document to "visible"."
    updateVisibilityState(document, ._visible_);
    // 4.4. "Fire a page transition event named pageshow at document's
    // relevant global object with true."
    firePageTransition(document, window, "pageshow", true);
}

/// "Abort a document and its descendants", step 3.2.
fn lifecyclePropagateAbort(parent: *runtime.Instance, child: *runtime.Instance) void {
    const child_state = getInternal(child) orelse return;
    if (child_state.salvageable) return;
    const parent_state = getInternal(parent) orelse return;
    parent_state.salvageable = false;
}

/// dom.document_lifecycle: step 6's task fires DOMContentLoaded; step 9's
/// completes the load, once step 8 finds nothing delaying it.
fn lifecycleFinishLoading(document: *runtime.Instance) void {
    // A parser a navigation aborted (lifecycleAbort) stops without "the
    // end": HTML "abort a parser" step 5, "Update the current document
    // readiness to "complete"" - and no DOMContentLoaded, load, pageshow or
    // load at the container.
    if (getInternal(document)) |internal| if (internal.active_parser_was_aborted) {
        engine.runInRealm(document.ctx, becomeComplete, document) catch {};
        return;
    };
    // "The end", step 5: await each deferred script in order, including
    // its fetch and any style sheet that blocks scripts, before step 6.
    const internal = getInternal(document) orelse return;
    if (@import("html").script_execution.parsingFinishedScriptsPending(document)) {
        internal.parsing_end_waiting_on_scripts = true;
        return;
    }
    internal.parsing_end_waiting_on_scripts = false;
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
fn queueLoadUnlessDelayed(document: *runtime.Instance) void {
    const internal = getInternal(document) orelse return;
    // Step 7: "Spin the event loop until the set of scripts that will
    // execute as soon as possible and the list of scripts that will execute
    // in order as soon as possible are empty" - script_execution says when a
    // script leaves them (loadDelayMayHaveEnded). Then step 8.
    const scripts_pending = internal.scripts.scripts_to_execute_asap.items.len > 0 or internal.scripts.scripts_to_execute_in_order_asap.items.len > 0;
    if (scripts_pending or lifecycleDelaysLoadEvent(document)) {
        internal.load_waiting_on_delay = true;
        return;
    }
    internal.load_waiting_on_delay = false;
    // "The end" step 11 follows queueing step 9, without waiting for that
    // task to fire load. Set this before the native no-loop fallback can
    // synchronously run the queued task and its callbacks.
    internal.ready_for_post_load_tasks = true;
    const token = nextSerial(internal);
    internal.pending_load_token = token;
    queueLifecycleTaskWith(document, .load, token);
}

/// The resource conditions of "the end" step 8, also read by an iframe
/// about its active document (HTML §4.8.5's third delay predicate).
fn lifecycleDelaysLoadEvent(document: *runtime.Instance) bool {
    const internal = getInternal(document) orelse return false;
    const dom = @import("dom");
    return internal.load_event_delay_count > 0 or
        dom.script_elements.delaysLoadEvent(document) or
        dom.content_navigables.delaysLoadEvent(document) or
        dom.style_sheet_owners.delaysLoadEvent(document) or
        dom.media_elements.mediaDelaysLoadEvent(document);
}

fn lifecycleIsReadyForPostLoadTasks(document: *runtime.Instance) bool {
    const internal = getInternal(document) orelse return true;
    return internal.ready_for_post_load_tasks;
}

fn lifecycleMarkReadyForPostLoadTasks(document: *runtime.Instance) void {
    const internal = getInternal(document) orelse return;
    internal.ready_for_post_load_tasks = true;
}

/// dom.document_lifecycle: something that delayed `document`'s load event
/// may have stopped. If "the end" waits at step 8, look again.
fn lifecycleLoadDelayMayHaveEnded(document: *runtime.Instance) void {
    const internal = getInternal(document) orelse return;
    // "The end" steps 5 and 7 wait by spinning the event loop. A DOM
    // removal or resource undelay must not enter parser/deferred script on
    // its caller's stack; the epoch-checked document task resumes it.
    if (internal.parsing_end_waiting_on_scripts or
        @import("html").script_execution.pendingParserBlockingScriptReady(document))
    {
        queueScriptDeliveryContinuation(document, false);
    } else if (internal.load_waiting_on_delay) {
        // Rechecking step 8 only queues the load task; it executes no script.
        queueLoadUnlessDelayed(document);
    }
    @import("dom").content_navigables.loadDelayMayHaveEnded(document);
}

/// Task-only parser and deferred-script continuation after a load delay ends.
fn resumeAfterLoadDelay(document: *runtime.Instance) void {
    // An inline parser script can wait on a style sheet without a script
    // fetch of its own. Resume its parser when the last blocking sheet
    // finishes, using the same readiness test as fetched parser scripts.
    const realm = document.ctx;
    const had_engine = realm.hasEngine();
    const generation = runtime.SlabAllocator.generationOf(document);
    // An already-ready child's written stream can remain open after its
    // resource delay ends. Its parent still needs to recheck its own delay.
    // Parent callbacks may remove this child; do not access it afterward.
    defer {
        if ((!had_engine or realm.hasEngine()) and runtime.SlabAllocator.generationOf(document) == generation) {
            @import("dom").content_navigables.loadDelayMayHaveEnded(document);
        }
    }
    const epoch = (getInternal(document) orelse return).parser_epoch;
    if (@import("html").script_execution.pendingParserBlockingScriptReady(document)) {
        if ((getInternal(document) orelse return).input_stream_manager) |stream| {
            if (!stream.aborted and !stream.isExecutingScript()) stream.processInserted();
        }
    }
    // Resumed script may remove its frame or replace its parser.
    if ((had_engine and !realm.hasEngine()) or runtime.SlabAllocator.generationOf(document) != generation) return;
    const internal = getInternal(document) orelse return;
    if (internal.parser_epoch != epoch) return;
    if (internal.parsing_end_waiting_on_scripts) {
        @import("html").script_execution.executeScriptsWhenParsingFinished(internal.allocator, document);
        // A script can document.open(), ending this parser's "the end".
        if ((had_engine and !realm.hasEngine()) or runtime.SlabAllocator.generationOf(document) != generation) return;
        const current = getInternal(document) orelse return;
        if (current.parser_epoch != epoch or !current.parsing_end_waiting_on_scripts) return;
        if (@import("html").script_execution.parsingFinishedScriptsPending(document)) return;
        lifecycleFinishLoading(document);
        return;
    }
    if (!internal.load_waiting_on_delay) return;
    queueLoadUnlessDelayed(document);
}

/// A task drop only relinquishes delivery ownership. Continuing the parser,
/// running an already-ready ordered successor, or completing "the end" can
/// run script, so each belongs to a later document task.
fn lifecycleScriptDeliveryDiscarded(document: *runtime.Instance, removed_parser_blocker: bool) void {
    const internal = getInternal(document) orelse return;
    if (internal.script_delivery_continuation_suppressed or internal.active_parser_was_aborted or internal.destroyed) return;
    // Initial preparation can be dropped before it joins an execution queue.
    // With no parser or suspended lifecycle to wake, nothing is owed yet.
    if (!internal.load_waiting_on_delay and !internal.parsing_end_waiting_on_scripts and
        !(removed_parser_blocker and internal.active_parser != null) and
        internal.scripts.scripts_to_execute_asap.items.len == 0 and
        internal.scripts.scripts_to_execute_in_order_asap.items.len == 0) return;
    queueScriptDeliveryContinuation(document, removed_parser_blocker);
}

fn queueScriptDeliveryContinuation(document: *runtime.Instance, removed_parser_blocker: bool) void {
    const internal = getInternal(document) orelse return;
    const task = LifecycleTask{
        .allocator = document.ctx.allocator,
        .target = document,
        .generation = runtime.SlabAllocator.generationOf(document),
        .step = .resume_script_delivery,
        .parser_epoch = internal.parser_epoch,
        .had_engine = document.ctx.hasEngine(),
        .removed_parser_blocker = removed_parser_blocker,
    };
    if (!canResumeScriptDelivery(&task)) return;
    // No synchronous fallback: this hook can be running inside queueTask's
    // allocation-failure drop. Losing this task to OOM never retries it from
    // drop, nor turns an asynchronous completion into script on that stack.
    const loop = document.ctx.getOptionalEventLoop() orelse return;
    const queued = task.allocator.create(LifecycleTask) catch return;
    queued.* = task;
    queued.ref.take(document, @import("dom").instance_bridge.getNodeBase(@ptrCast(document)));
    loop.queueTask(.{
        .callback = &runLifecycleTask,
        .context = queued,
        .drop = &dropLifecycleTask,
        .document = document,
        .document_generation = task.generation,
    });
}

fn canResumeScriptDelivery(task: *const LifecycleTask) bool {
    if (runtime.SlabAllocator.generationOf(task.target) != task.generation) return false;
    const internal = getInternal(task.target) orelse return false;
    if (internal.parser_epoch != task.parser_epoch or internal.script_delivery_continuation_suppressed or
        internal.active_parser_was_aborted or internal.destroyed) return false;
    if (task.had_engine and !task.target.ctx.hasEngine()) return false;
    // Windowless native documents have no replacement navigable. A document
    // with a Window must still be that navigable's fully active document.
    return internal.default_view == null or isFullyActive(task.target);
}

fn resumeScriptDelivery(task: *LifecycleTask) void {
    if (!canResumeScriptDelivery(task)) return;
    const document = task.target;
    const internal = getInternal(document).?;
    if (task.removed_parser_blocker and internal.scripts.pending_parsing_blocking_script == null) {
        if (internal.active_parser) |parser| {
            // The removed script was the obstacle only while this parser's
            // script-end-tag loop awaited it. A replacement blocker keeps its
            // own pause, and abort/replacement never consumes this resume.
            if (!parser.detached and !parser.input_stream.aborted and !parser.input_stream.isExecutingScript() and
                parser.tree_builder.waiting_for_parser_blocking_script)
            {
                const parser_call = parser.protect() catch return;
                defer parser_call.deinit();
                parser.tree_builder.waiting_for_parser_blocking_script = false;
                parser.tree_builder.parser_pause_flag = false;
                parser.input_stream.processInserted();
            }
        }
    }
    // Resuming input and draining ready scripts can remove the document or
    // call document.open(). Never complete another parser's suspended end.
    if (!canResumeScriptDelivery(task)) return;
    @import("html").script_execution.executeScriptsAsap(document.ctx.allocator, document);
    if (!canResumeScriptDelivery(task)) return;
    resumeAfterLoadDelay(document);
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
    // "Create a new browsing context and document" marks its initial
    // about:blank document ready for post-load tasks before populating it.
    internal.ready_for_post_load_tasks = true;
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
    const not_canceled = @import("dom").fire_event.dispatchTrusted(window, event) catch true;
    // Step 6's condition, less sticky activation: "eventFiringResult is
    // false, or the returnValue attribute of event is not the empty string".
    const return_value = interfaces.BeforeUnloadEvent.get_returnValue(event) catch runtime.DOMString.initEmpty();
    return .{ .prompt_requested = !not_canceled or return_value.asSlice().len > 0 };
}

/// dom.document_lifecycle: "unload" `document` (HTML §7.5.9) with no new
/// document given - the unload timing info is not modelled - from a task.
///
/// Step 5: intendToKeepInBfcache is the navigable's answer, given before
/// the unload (dom.bfcache.intendToKeep), and the document's own: it is
/// still salvageable and loaded. Kept, the document stays salvageable:
/// pagehide reports persisted true, no unload event fires, and it is not
/// destroyed (steps 10, 12, 20). Steps 15-16 (suspension time, suspended
/// timer handles) and 20 (destroy) run here; steps 18-19 (cleanup steps,
/// not restored reasons) are the navigable's: navigation clears the window's
/// timers once this returns - or, for a kept document, suspends them.
fn lifecycleUnload(document: *runtime.Instance) void {
    engine.runInRealm(document.ctx, unloadSteps, document) catch |err| {
        log.debug("unload not run: {}", .{err});
    };
}

fn unloadSteps(data: ?*anyopaque) void {
    const document: *runtime.Instance = @ptrCast(@alignCast(data.?));
    const internal = getInternal(document) orelse return;
    const window = (get_defaultView(document) catch null) orelse return;

    // Before step 7: a dismissal handler can remove this document's frame
    // (including through document.open on its parent), reentering unload.
    // The original invocation still owns the event dispatch and cleanup.
    // WebKit FrameLoader::dispatchUnloadEvents likewise returns while a
    // dismissal event is being dispatched (FrameLoader.cpp); the existing
    // unload counter covers beforeunload, pagehide, visibilitychange and
    // unload without adding a second state flag.
    // https://github.com/WebKit/WebKit/blob/main/Source/WebCore/loader/FrameLoader.cpp
    if (internal.unload_counter > 0) return;

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
    // Step 5: "Let intendToKeepInBfcache be true if the user agent intends
    // to keep oldDocument alive in a session history entry ... This must be
    // false if oldDocument is not salvageable": the navigable's intent
    // (dom.bfcache.intendToKeep, consumed here) and the document's own part.
    const intend_to_keep = internal.intend_to_keep and bfcacheMayKeep(document);
    internal.intend_to_keep = false;
    // Step 9: "If intendToKeepInBfcache is false, then set oldDocument's
    // salvageable state to false."
    if (!intend_to_keep) internal.salvageable = false;
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
    // Steps 15-16: "Set oldDocument's suspension time to the current high
    // resolution time given document's relevant global object", and its
    // "suspended timer handles to the result of getting the keys for the map
    // of active timers". Read by reactivation (the back/forward cache's
    // phase B); a document destroyed below never is.
    recordSuspension(document, internal);
    // Step 20: "If oldDocument's salvageable state is false, then destroy
    // oldDocument." Its handlers above still saw it fully active. One still
    // salvageable is kept for the back/forward cache: the navigation code
    // reads it (dom.bfcache.isKept) and stores the page. (Steps 18-19 run
    // after this returns - see the doc comment - so a store step's reason
    // recorded there can still make it unsalvageable; the navigation code
    // destroys it then.)
    if (!internal.salvageable) lifecycleDestroy(document) else internal.kept_in_bfcache = true;
}

/// "Unload a document" steps 15-16 for `document`. Out of memory, the handles
/// are left empty: a reactivation then shifts no timer, as if none were set.
fn recordSuspension(document: *runtime.Instance, internal: *InternalState) void {
    internal.suspension_time = renderBlockingTime(document);
    const handles: []runtime.TimerId = @import("dom").window_documents.activeTimerHandles(document.ctx, internal.allocator) catch &.{};
    internal.allocator.free(internal.suspended_timer_handles);
    internal.suspended_timer_handles = handles;
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
    internal.script_delivery_continuation_suppressed = true;
    internal.render_blocking_elements.clear();
    internal.salvageable = false;
    internal.destroyed = true;
    internal.kept_in_bfcache = false;
    @import("html").script_execution.discardDocumentScripts(document);
    discardDocumentParser(internal);
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
    // The document's navigable - a frame's, a popup's or the host page's
    // traversable - navigated as any hyperlink targeting "_self" navigates it.
    dom.navigables.navigateByTarget(document, .{ .target = "_self", .url = refresh.url, .history_behavior = .replace });
}

/// Whether `document`'s active sandboxing flag set has the sandboxed
/// automatic features browsing context flag (set by a sandbox without
/// allow-scripts).
fn automaticFeaturesSandboxed(document: *runtime.Instance) bool {
    const internal = getInternal(document) orelse return false;
    return internal.active_sandboxing_flags.automatic_features;
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
    // A hidden document has no rendering opportunity (update the rendering
    // step 3) and its loop arms none for it: shown again, it asks for one,
    // for the animation frame callbacks and the work that waited.
    if (state == ._visible_) @import("dom").update_the_rendering.requestFrame(document);
}

const LifecycleStep = enum { dom_content_loaded, load, declarative_refresh, resume_script_delivery };

const LifecycleTask = struct {
    allocator: std.mem.Allocator,
    target: *runtime.Instance,
    generation: u64,
    step: LifecycleStep,
    /// Only delivery continuation captures the parser that lost its producer.
    parser_epoch: u64 = 0,
    /// A load task's token (Document.pending_load_token); 0 for other steps.
    load_token: u64 = 0,
    had_engine: bool = false,
    removed_parser_blocker: bool = false,
    /// The task's counted reference on its document, from its queueing to
    /// its run or drop (refcount step 7's missed holder, lane refcount8,
    /// H-RC8-DOC-LIFECYCLE: the zombie audit's full sweep found a windowless
    /// document's readystatechange and DOMContentLoaded taking it on after
    /// its tree counted zero). WebKit's document event tasks keep their
    /// document alive the same way.
    ref: @import("dom").node_holds.CountedRef = .{},
};

fn queueLifecycleTask(target: *runtime.Instance, step: LifecycleStep) void {
    queueLifecycleTaskWith(target, step, 0);
}

fn queueLifecycleTaskWith(target: *runtime.Instance, step: LifecycleStep, load_token: u64) void {
    const allocator = target.ctx.allocator;
    const task = allocator.create(LifecycleTask) catch return;
    task.* = .{
        .allocator = allocator,
        .target = target,
        .generation = runtime.SlabAllocator.generationOf(target),
        .step = step,
        .load_token = load_token,
    };
    task.ref.take(target, @import("dom").instance_bridge.getNodeBase(@ptrCast(target)));
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
    task.ref.release(task.target);
    task.allocator.destroy(task);
}

fn runLifecycleTask(context: ?*anyopaque) void {
    const task: *LifecycleTask = @ptrCast(@alignCast(context orelse return));
    defer task.allocator.destroy(task);
    defer task.ref.release(task.target);
    // Collected and its slot reissued: nothing is left to finish loading.
    if (runtime.SlabAllocator.generationOf(task.target) != task.generation) return;
    if (task.step == .resume_script_delivery) {
        if (!canResumeScriptDelivery(task)) return;
        // Engine-less native documents still run from their queued task.
        // A realm that used to have an engine is suppressed above instead.
        if (!task.target.ctx.hasEngine()) return lifecycleTaskSteps(task);
    }
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
        .resume_script_delivery => {},
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
            // Step 6.4: enable the client message queue of the
            // ServiceWorkerContainer whose client is the document's relevant
            // settings object.
            if (has_window) @import("dom").client_message_queues.domContentLoaded(task.target.ctx);
        },
        .load => {
            if (getInternal(task.target)) |internal| {
                // Its last child's load completed the document already.
                if (task.load_token != 0 and task.load_token == internal.early_load_token) return;
                if (internal.pending_load_token == task.load_token) internal.pending_load_token = 0;
            }
            completeLoading(task.target);
        },

        // A refresh set up while the document loaded starts waiting now.
        .declarative_refresh => armDeclarativeRefresh(task.target),
        .resume_script_delivery => resumeScriptDelivery(task),
    }
}

/// Whether `document` is still its window's document - false once a
/// navigation has put another in its place. A document with no window is
/// not replaced by anything.
///
/// A navigation that makes a new Window leaves the old one's document in
/// place, so asking the Window is not enough: a destroyed document is never
/// fully active again. Being unsalvageable alone does not end activity.
fn isShownByItsWindow(document: *runtime.Instance) bool {
    if (getInternal(document)) |internal| {
        if (internal.destroyed) return false;
    }
    const window = (get_defaultView(document) catch null) orelse return true;
    const shown = interfaces.Window.get_document(window) catch return true;
    return shown == document;
}

/// `container`'s load event steps have run: its navigable no longer delays
/// its node document. If that document's "the end" has queued step 9's task
/// already - nothing else delays it - complete its load now, in this task,
/// rather than in that one.
///
/// Deviation from the spec text, stated (golden rule 2). In HTML, "the end"
/// spins the event loop at step 8 until nothing delays the load event and
/// then queues step 9's task, so a parent's load comes at least one task
/// after its last frame's - after any task that frame's load handlers
/// queued, such as a postMessage. The browsers complete the parent
/// synchronously, as soon as its last child is done: Blink
/// FrameLoader::DidFinishNavigation calls parent->CheckCompleted(), whose
/// Document::CheckCompletedInternal fires load
/// (core/loader/frame_loader.cc, core/dom/document.cc); Gecko
/// nsDocLoader::NotifyDoneWithOnload calls the parent's
/// ChildDoneWithOnload, whose DocLoaderIsEmpty fires its load
/// (uriloader/base/nsDocLoader.cpp). wpt.fyi (run cc74d2669f):
/// navigating-across-documents/grandparent_session_aboutsrcdoc.sub.window.html
/// passes 4/4 in Chrome 154, Firefox 157 and Safari 27; its frame's
/// navigation on the first message is a push only if the frame has
/// completely loaded by then. It runs from the child's completeLoading, once
/// the child's container load and pageshow are done (Blink's
/// DidFinishNavigation checks the parent after Document::ImplicitClose,
/// which dispatched both).
fn completeLoadingWithChild(container: *runtime.Instance) void {
    const document = (interfaces.Node.get_ownerDocument(container) catch null) orelse return;
    const internal = getInternal(document) orelse return;
    if (internal.pending_load_token == 0) return;
    if (!isShownByItsWindow(document)) return;
    internal.early_load_token = internal.pending_load_token;
    internal.pending_load_token = 0;
    completeLoading(document);
}

/// "The end" step 9's task: readiness "complete", load at the window, the
/// container's load, pageshow, and the parent's completion.
///
/// Deviation from the spec text, stated (golden rule 2; no newer spec is
/// involved). HTML fires pageshow (step 9.11) and then "completely finish
/// loading" (9.12) QUEUES the container's load event steps (its steps 4-5):
/// a frame's pageshow comes before the iframe element's load. All three
/// browsers fire the container's load inside the child's window load
/// dispatch, before pageshow: Blink LocalDOMWindow::DispatchLoadEvent
/// (`owner->DispatchLoad()` after the window's load;
/// DispatchLoadAndPageshowEvents fires pageshow after it,
/// core/frame/local_dom_window.cc), WebKit LocalDOMWindow::dispatchLoadEvent
/// ("Send a separate load event to the element that owns this frame",
/// page/LocalDOMWindow.cpp) and Gecko nsGlobalWindowInner::FireFrameLoadEvent
/// (from PostHandleEvent for the window's load, dom/base/nsGlobalWindowInner.cpp).
/// wpt.fyi (stable runs of 2026-10-18): navigation-api/ordering-and-transition/
/// {navigate,back}-cross-document-event-order-with-pagehide.html pass in
/// Chrome 155, Firefox 158 and Safari 27, which want [..., readystatecomplete,
/// onload (the iframe's), onpageshow]; the variants with unload pass in
/// Firefox and Safari (Chrome fires no unload, and still the iframe's load
/// before pageshow). So "completely finish loading" steps 3-5 run here,
/// right after the window's load, with the container's load event steps
/// synchronous, in the container's realm; then pageshow, if the container's
/// listeners left this document fully active (one that removes the frame
/// destroys it); then the completely loaded time; then the parent's own
/// completion.
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
    const internal = getInternal(document) orelse return;
    // The window's load listeners ran script: a document they took out of
    // its navigable (they removed its frame) finishes nothing more.
    if (!isShownByItsWindow(document)) return;
    // "Completely finish loading" steps 3-5, moved before steps 9.9-9.11
    // (above): the container's load event steps, now, in its realm (the
    // iframe load event steps, or a load at an object or embed element).
    // The document has not completely loaded yet - step 2 comes after
    // pageshow, below - so a navigation the container's listeners start is
    // one of a document that has not completely loaded, a replace, as one
    // its own load or pageshow listeners start is (Blink fires the owner's
    // load while its Document's load_event_progress_ is
    // kLoadEventInProgress, Document::DispatchLoadEventAndFinalize).
    //
    // Step 9.10, "set the Document's page showing to true", comes before
    // them too, and step 9.11's pageshow after: a frame its container's
    // listeners remove or navigate away is unloaded showing, so "unload a
    // document" fires pagehide at it, as all three browsers do for a frame
    // removed as soon as its load event fired
    // (fetch/api/basic/keepalive.any.js's "on 'pagehide'" cases pass in
    // Chrome 155, Firefox 158 and Safari 27; Blink's
    // Document::DispatchUnloadEvents fires pagehide once the load event has
    // started, whether pageshow has fired or not).
    const container = @import("dom").navigable_container.of(window);
    const was_showing = internal.page_showing;
    internal.page_showing = true;
    if (container) |element| runContainerLoadEventSteps(element);
    // Step 9.11: pageshow, persisted false - unless the document was showing
    // already, or the container's listeners left it not fully active (they
    // removed the frame: its document is destroyed, and had its pagehide).
    // A navigation they started has not committed: the document is still
    // active, and gets its pageshow.
    if (!isShownByItsWindow(document)) return;
    if (!was_showing) firePageShow(document, window);
    // The document is shown: its first rendering opportunity reveals it
    // (HTML "update the rendering" step 6), whether or not script asked for
    // an animation frame.
    if (!internal.has_been_revealed) @import("dom").update_the_rendering.requestFrame(document);
    // Step 9.12's "completely finish loading" step 2: the completely loaded
    // time - after pageshow, so a navigation its listeners start is a
    // replace (replace-before-load/*-during-pageshow.html).
    internal.completely_loaded = true;
    // This frame no longer delays its container document: the parent's own
    // load completes now if nothing else delays it (completeLoadingWithChild),
    // after this document's pageshow.
    if (container) |element| completeLoadingWithChild(element);
    // Step 9.13: "Queue the navigation timing entry for the Document."
    @import("dom").performance_timeline.queueNavigationTimingEntry(document.ctx);
    // A declarative refresh comes due `time` seconds after the completely
    // loaded time. Its wait starts in a task queued behind the container's
    // load event, so a refresh of no time never overtakes that event.
    if (internal.declarative_refresh != null) queueLifecycleTask(document, .declarative_refresh);
}

/// "Completely finish loading" steps 4-5 for `container`, run in the
/// container's realm - the child document's task is in the child's: the
/// iframe load event steps (dom.content_navigables), which also end the
/// delay its navigation put on its node document's load event, or for any
/// other container "fire an event named load at element".
fn runContainerLoadEventSteps(container: *runtime.Instance) void {
    engine.runInRealm(container.ctx, containerLoadEventSteps, container) catch |err| {
        log.debug("a container's load event steps did not run: {}", .{err});
    };
}

fn containerLoadEventSteps(data: ?*anyopaque) void {
    const container: *runtime.Instance = @ptrCast(@alignCast(data.?));
    if (!@import("dom").content_navigables.runLoadEventSteps(container)) {
        fireEvent(container, container, "load", false);
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
    _ = @import("dom").fire_event.dispatchTrusted(target, event) catch {};
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
    _ = @import("dom").fire_event.dispatchTrusted(window, event) catch {};
    event.releaseIfUnwrapped(generation);
}

/// HTML 7.4.6.3 "reveal" `document`, update the rendering step 6.
fn revealStep(document: *runtime.Instance, frame: @import("dom").update_the_rendering.Frame) void {
    _ = frame;
    const internal = getInternal(document) orelse return;
    // 1. "If document's has been revealed is true, then return."
    if (internal.has_been_revealed) return;
    // 2. "Set document's has been revealed to true."
    internal.has_been_revealed = true;
    // 3. "Let transition be the result of resolving inbound cross-document
    // view-transition for document": null - Crane has no cross-document
    // view transitions (css-view-transitions-2 is not implemented), so
    // step 5 never runs.
    // 4. "Fire an event named pagereveal at document's relevant global
    // object, using PageRevealEvent with its viewTransition set to
    // transition." Chrome and Safari fire it (pagereveal/order-in-*: 1/1
    // each); Firefox does not ship it yet (0/1, wpt.fyi ffc4686d11).
    const window = (get_defaultView(document) catch null) orelse return;
    const event = interfaces.PageRevealEvent.call_constructor(
        document.ctx,
        runtime.DOMString.initInterned("pagereveal"),
        webidl.Opt(dictionaries.PageRevealEventInit).passed(.{ .base = .{}, .viewTransition = null }),
    ) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    _ = @import("dom").fire_event.dispatchTrusted(window, event) catch {};
    event.releaseIfUnwrapped(generation);
}

/// Operation: requestStorageAccess() (storage-access.idl). The
/// requestStorageAccess(StorageAccessTypes) overload is gone from
/// saa-non-cookie-storage.idl, so this is the only one.
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
    const flattened = try @import("html").custom_element_creation.flatten(instance, options);
    defer flattened.deinit(allocator);
    if (was_live and !realm.hasEngine()) return error.InvalidStateError;

    // Step 3: "Return the result of creating an element given document,
    // localName, namespace, prefix, is, and true."
    return @import("html").custom_element_creation.create(.{
        .document = instance,
        .local_name = extracted.local_name,
        .namespace = extracted.namespace,
        .prefix = extracted.prefix,
        .is_value = flattened.is_value,
        .registry = .{ .explicit = flattened.registry },
        .synchronous = true,
    });
}

/// Operation: captureEvents
pub fn call_captureEvents(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: createNSResolver
pub fn call_createNSResolver(instance: *runtime.Instance, nodeResolver: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    // DOM §8.3: return nodeResolver (the legacy method is an identity).
    return nodeResolver;
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
    // Removal runs pre-removing steps for iterators whose root's node
    // document is the removed node's document, even across factory documents.
    const root_document = if (try interfaces.Node.get_nodeType(root) == interfaces.Node.get_DOCUMENT_NODE())
        root
    else
        (try interfaces.Node.get_ownerDocument(root)) orelse return error.InvalidStateError;
    // The filter argument, borrowed for the call: the iterator takes its own.
    const filter_wrapper: ?*runtime.CallbackWrapper = if (filter.was_passed) (filter.value orelse null) else null;

    // Step 1: Create NodeIterator
    // Use interface instead of impl (per Golden Rule #13)
    const iterator = try interfaces.NodeIterator.init(internal.allocator, instance.ctx);
    errdefer interfaces.NodeIterator.deinit(iterator);

    // Steps 2-6: the iterator's own state, set through dom.traversal.
    const what_to_show: u32 = if (whatToShow.was_passed) whatToShow.value else 0xFFFFFFFF;
    try traversal.setUpNodeIterator(iterator, root, what_to_show, filter_wrapper, root_document);

    // Register in the same document recorded for generation-safe teardown.
    try @import("dom").document_internals.registerNodeIterator(root_document, iterator);

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
        .sandboxing_flags = &activeSandboxingFlags,
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
        .add_integrity_mapping = &addIntegrityMappingStep,
        .resolve_module_integrity = &resolveModuleIntegrityStep,
        .get_loader = &moduleLoaderOf,
        .set_loader = &setModuleLoader,
        .visit_realm_loaders = &visitRealmModuleLoaders,
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

fn moduleLoaderOf(instance: *runtime.Instance) ?*anyopaque {
    const internal = getInternal(instance) orelse return null;
    return internal.module_loader;
}

fn setModuleLoader(instance: *runtime.Instance, loader: *anyopaque, dispose: dom_document_modules.DisposeFn) dom_document_modules.Error!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.module_loader != null) return error.InvalidStateError;
    internal.module_loader = loader;
    internal.dispose_module_loader = dispose;
}

fn visitRealmModuleLoaders(realm: runtime.Context, visit: dom_document_modules.VisitLoaderFn, data: ?*anyopaque) void {
    // The realm's Browser's documents.
    var entries = Registry.iterator(realm.browserScope() orelse return) orelse return;
    while (entries.next()) |entry| {
        const document: *runtime.Instance = @ptrCast(@alignCast(entry.instance));
        if (document.ctx != realm) continue;
        if (entry.internal.module_loader) |loader| visit(loader, data);
    }
}

fn addImportMappingStep(instance: *runtime.Instance, specifier: []const u8, resolved_url: []const u8) dom_document_modules.Error!void {
    return addImportMapping(instance, specifier, resolved_url);
}

/// HTML merge existing and new import maps step 5. A later map never
/// replaces an entry, including one whose integrity is the empty string.
fn addIntegrityMappingStep(instance: *runtime.Instance, url: []const u8, integrity: []const u8) dom_document_modules.Error!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.import_map_integrity.contains(url)) return;
    const owned_url = try internal.allocator.dupe(u8, url);
    errdefer internal.allocator.free(owned_url);
    const owned_integrity = try internal.allocator.dupe(u8, integrity);
    errdefer internal.allocator.free(owned_integrity);
    try internal.import_map_integrity.put(owned_url, owned_integrity);
}

fn resolveModuleIntegrityStep(instance: *runtime.Instance, url: []const u8) ?[]const u8 {
    const internal = getInternal(instance) orelse return null;
    return internal.import_map_integrity.get(url);
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

/// Check if the active parser was aborted
pub fn wasParserAborted(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    return internal.active_parser_was_aborted;
}

/// The active parser's input, including script-created writes.
pub fn getWriteBuffer(instance: *runtime.Instance) []const u8 {
    const internal = getInternal(instance) orelse return "";
    const stream = internal.input_stream_manager orelse return "";
    return stream.buffer.items;
}

/// HTML 8.1.3.4 "scripting is enabled" for a node of `instance`: the
/// document runs script at all (`scripting_enabled`), and its active
/// sandboxing flag set does not have the sandboxed scripts browsing context
/// flag set - "settings's global object's associated Document's active
/// sandboxing flag set does not have its sandboxed scripts browsing context
/// flag set".
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#concept-n-noscript
pub fn isScriptingEnabled(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    // HTML 8.1.3.4: scripting is disabled for a Node whose "node
    // document's browsing context is null". A document retained in the
    // back/forward cache still has its browsing context; this does not
    // disable it merely because it is inactive.
    if ((get_defaultView(instance) catch null) == null) return false;
    return internal.scripting_enabled and !internal.active_sandboxing_flags.scripts;
}

/// `instance`'s active sandboxing flag set (dom.document_scripts); empty for
/// an object that is no Document.
fn activeSandboxingFlags(instance: *runtime.Instance) SandboxingFlagSet {
    const internal = getInternal(instance) orelse return .empty;
    return internal.active_sandboxing_flags;
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
            dispose_fn(url, old_module);
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
pub fn setModuleDisposeFunction(instance: *runtime.Instance, dispose_fn: ?dom_document_modules.ModuleDisposeFn) void {
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
    // A document with no internal state has no policy container to read:
    // not knowing its policies fails closed (csp.CSPList.unavailable). It
    // used to allow ("No document = allow").
    const internal = getInternal(instance) orelse return false;
    if (internal.policy_container.csp_list.isEmpty()) return true;
    // CSP §4.2.3 uses the same nonce eligibility and violation-reporting
    // algorithm for inline scripts as for the other inline behaviors.
    return !@import("dom").csp_violations.shouldBlockInline(element, .script, source, .{
        .nonce = nonce,
        .parser_inserted = parser_inserted,
    });
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
/// HTML 4.2.7: check this document's set, then its node navigable's
/// immediate container document's set. Ancestors beyond that do not count.
pub fn hasStyleSheetBlockingScripts(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    if (internal.stylesheet_tracker.hasBlockingStylesheet() or @import("dom").style_sheet_owners.blocksScripts(instance)) return true;
    const window = (get_defaultView(instance) catch null) orelse return false;
    const container = @import("dom").navigable_container.of(window) orelse return false;
    const container_document = (interfaces.Node.get_ownerDocument(container) catch null) orelse return false;
    const container_internal = getInternal(container_document) orelse return false;
    return container_internal.stylesheet_tracker.hasBlockingStylesheet() or @import("dom").style_sheet_owners.blocksScripts(container_document);
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

/// HTML 3.1.7: "The supported property names of a Document object document
/// at any moment consist of the following, for each element element in a
/// document tree with document as its root, in tree order, ignoring later
/// duplicates: the value of element's id content attribute, if element is a
/// named element with that value as its name; and then the value of
/// element's name content attribute, if element is a named element with
/// that value as its name." Enumeration only (Object.keys(document)): a
/// walk, and none at all while the document's maps hold no name
/// (domindex1). The browsers order these three ways - Blink by insertion,
/// WebKit sorted, Gecko by hash - and none is a majority, so the spec's
/// order stands; id-before-name per element is also Chrome's and Safari's
/// (nameditem-supported-property-names-order: Chrome, Safari pass).
pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {
    const list = try @import("dom").tree_ordered_map.supportedNames(instance, .document, allocator);
    // The unforgeable names are never visible (`unforgeable_names`): the
    // list holds only names the binding may show.
    var kept: usize = 0;
    for (list) |*name| {
        if (isUnforgeableName(name.asSlice())) {
            name.deinit(allocator);
            continue;
        }
        list[kept] = name.*;
        kept += 1;
    }
    if (kept == list.len) return list;
    if (allocator.resize(list, kept)) return list[0..kept];
    const copy = allocator.dupe(runtime.DOMString, list[0..kept]) catch |err| {
        for (list[0..kept]) |*name| name.deinit(allocator);
        allocator.free(list);
        return err;
    };
    allocator.free(list);
    return copy;
}

/// Document's [LegacyUnforgeable] members (HTML's partial interface: only
/// `location`). WebIDL 3.9.7 the named property visibility algorithm, step
/// 2: "If O has an own property named P, then return false" - and an
/// unforgeable attribute IS an own property of every Document (3.7.5),
/// which no named element shadows, [LegacyOverrideBuiltIns] or not
/// (named-access-on-the-window-object/strict-mode-redefine-readonly-property:
/// `<form name=location>` leaves document.location the Location, in all
/// three browsers). Stated deviation, compensated here: Crane's binding
/// defines Document's unforgeable attributes on Document.prototype, not on
/// the instance (v8 interface.zig makes only Location's members own), so its
/// visibility check cannot see them; the per-name query and the list leave
/// these names out instead, which is what the visibility algorithm answers.
const unforgeable_names = [_][]const u8{"location"};

fn isUnforgeableName(name: []const u8) bool {
    for (unforgeable_names) |unforgeable| if (std.mem.eql(u8, name, unforgeable)) return true;
    return false;
}

/// WebIDL 3.9.7 step 1 for ONE name - "is P a supported property name?" -
/// which the [LegacyOverrideBuiltIns] interceptor asks before every
/// property read of a document (document.body included): one lookup in the
/// document's maps, and none while they hold no name (domindex1; WebKit
/// HTMLDocument::isSupportedPropertyName, Blink HTMLDocument::HasNamedItem).
/// Agrees with the list above by construction: both read the maps' rule
/// (dom.tree_ordered_map keysOf).
pub fn isSupportedPropertyName(instance: *runtime.Instance, name: runtime.DOMString) anyerror!bool {
    if (isUnforgeableName(name.asSlice())) return false;
    return @import("dom").tree_ordered_map.isNamed(instance, .document, name.asSlice());
}

/// HTML 3.1.7 "determine the value of a named property" name for a
/// Document (domindex1):
///
/// 1. "Let elements be the list of named elements with the name name that
///    are in a document tree with the Document as their root." (The maps
///    count them and know the first.)
/// 2. "If elements has only one element, and that element is an iframe
///    element, and that iframe element's content navigable is not null, then
///    return the active WindowProxy of the element's content navigable."
/// 3. "Otherwise, if elements has only one element, return that element."
/// 4. "Otherwise, return an HTMLCollection rooted at the Document node,
///    whose filter matches only named elements with the name name." The
///    same collection while its wrapper lives (`document.a === document.a`;
///    Blink's EnsureCachedCollection(kDocumentNamedItems), WebKit's
///    documentNamedItems cache): all three browsers keep it
///    (nameditem-tree-order).
pub fn call_getter(instance: *runtime.Instance, name: runtime.DOMString) anyerror!runtime.JSValue {
    const tree_ordered_map = @import("dom").tree_ordered_map;
    // Step 1.
    const elements = tree_ordered_map.named(instance, .document, name.asSlice());
    if (elements.count == 0) return .undefined;
    if (elements.count == 1) {
        const first = elements.first.?;
        // Step 2.
        if (first.stateAs(interfaces.HTMLIFrameElement.State) != null) {
            if (try interfaces.HTMLIFrameElement.get_contentWindow(first)) |window| return .{ .instance = window };
        }
        // Step 3.
        return .{ .instance = first };
    }
    // Step 4.
    return .{ .instance = try tree_ordered_map.namedCollection(instance, .document, name.asSlice()) };
}

/// dom.teardown_sweeps: at its Browser's end, every Document state still in
/// `scope`'s table - an orphan's no teardown reached - frees what it owns.
fn sweepRemaining(scope: *runtime.BrowserScope) void {
    Registry.deinitAllAndClear(scope);
}

/// Getter for modelContext
pub fn get_modelContext(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: ariaNotify
pub fn call_ariaNotify(instance: *runtime.Instance, announcement: runtime.DOMString, options: webidl.Opt(dictionaries.AriaNotificationOptions)) anyerror!void {
    _ = instance;
    _ = announcement;
    _ = options;
    return error.NotImplemented;
}

/// Both consumers compare identities, never sequence gaps. Sharing the
/// document's existing sequence keeps its state in the 2048-byte class.
fn nextSerial(internal: *InternalState) u64 {
    const serial = internal.next_serial;
    internal.next_serial += 1;
    return serial;
}

/// Own document state reached only through the generated installHooks chain.
/// CSS Shadow1 §4.2 reserves zero for the document's own tree scope.
fn nextTreeScopeSerial(document: *runtime.Instance) u64 {
    const internal = getInternal(document) orelse return 0;
    return nextSerial(internal);
}
