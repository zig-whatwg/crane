//! Document's state TYPE: the fields a Document keeps, and their own
//! construction and teardown. Document's impl owns the state - it makes one
//! per Document in its construction steps and frees it in its own teardown -
//! and src/dom's algorithms over a document (dom.document_internals) read
//! it here, without naming the impl (AGENTS.md, the impls boundary; impls
//! batch 7, tmp/plans/impls-boundary-design.md 3.3 and e11: move the state's
//! TYPE, not the state).
//!
//! The state is in its Browser's side table under `Registry`: the impl
//! registers it, and `dom.document_internals.getInternal` looks it up - the
//! same table, since both name this one registry type.
//!
//! Spec: https://dom.spec.whatwg.org/#concept-document

const std = @import("std");
const runtime = @import("runtime");
const enums = @import("enums");
const fetch = @import("fetch");
const csp = @import("csp");
const html_core = @import("html_core");
const same_object = @import("same_object.zig");
const KeptChild = same_object.KeptChild;
const OriginRecord = @import("origin_record.zig").OriginRecord;
const SandboxingFlagSet = @import("sandboxing.zig").SandboxingFlagSet;
const StylesheetBlockingTracker = html_core.StylesheetBlockingTracker;
const dom_document_scripts = @import("document_scripts.zig");
const dom_document_modules = @import("document_modules.zig");
const SpeculationEagerness = dom_document_scripts.SpeculationEagerness;

/// Each Document's state, in its Browser's side table.
pub const Registry = runtime.InstanceRegistry(.document, InternalState);

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

/// Independently owned state behind one Document-owned pointer. The policy
/// pointer is always set at construction; interaction members stay lazy.
/// New Document extension pointers join this block so the inline state stays
/// within its pinned 2048-byte allocation class.
pub const InteractionState = struct {
    top_layer: ?*@import("top_layer.zig").State = null,
    autofocus: ?*@import("document_autofocus.zig").State = null,
    /// Permissions Policy §§9.5–9.6: an owned construction fact, separate
    /// from Fetch's policy container.
    permissions_policy: ?*html_core.permissions_policy.Policies = null,
};

/// Document's state (the impl keeps one per Document, in `Registry`).
/// Spec: https://dom.spec.whatwg.org/#concept-document
/// A pending lifecycle task's place in its Browser's list
/// (`PendingLifecycleTasks`; Document.zig's LifecycleTask embeds one), from
/// its queueing to its run, its drop or an unobserved drop (refcount step
/// 7a). It names its document by address and generation, and nothing reads
/// the document through it once the document's slot is another's.
pub const LifecycleLink = struct {
    prev: ?*LifecycleLink = null,
    next: ?*LifecycleLink = null,
    document: ?*runtime.Instance = null,
    generation: u64 = 0,
    linked: bool = false,
};

/// A Browser's pending document lifecycle tasks (a runtime.BrowserScope
/// supplement), each holding its document counted until it runs or drops
/// (refcount8, H-RC8-DOC-LIFECYCLE): the list refcount step 7a reads when a
/// document's last reference from outside its own pending work goes
/// (refcount_teardown.documentDereffed) - kept per Browser, not in the
/// Document's state, which stays in its 2,048-byte allocation class. Only
/// the Browser's window agent's thread queues and runs them.
pub const PendingLifecycleTasks = struct {
    head: ?*LifecycleLink = null,

    pub fn init(_: std.mem.Allocator) PendingLifecycleTasks {
        return .{};
    }

    /// The Browser's end: the loop dropped its tasks before (each unlinked
    /// itself); any left forget the list.
    pub fn deinit(self: *PendingLifecycleTasks) void {
        var at = self.head;
        self.head = null;
        while (at) |link| {
            at = link.next;
            link.* = .{};
        }
    }

    pub fn add(self: *PendingLifecycleTasks, link: *LifecycleLink, document: *runtime.Instance) void {
        link.* = .{ .next = self.head, .document = document, .generation = runtime.SlabAllocator.generationOf(document), .linked = true };
        if (self.head) |head| head.prev = link;
        self.head = link;
    }

    pub fn remove(self: *PendingLifecycleTasks, link: *LifecycleLink) void {
        if (!link.linked) return;
        if (link.prev) |prev| prev.next = link.next else self.head = link.next;
        if (link.next) |next| next.prev = link.prev;
        link.* = .{};
    }

    /// The pending tasks of `document` (the same object: its generation).
    pub fn countFor(self: *const PendingLifecycleTasks, document: *runtime.Instance) u32 {
        const generation = runtime.SlabAllocator.generationOf(document);
        var held: u32 = 0;
        var at = self.head;
        while (at) |link| : (at = link.next) {
            if (link.document == document and link.generation == generation) held += 1;
        }
        return held;
    }

    /// `document`'s pending tasks, or none.
    pub fn of(document: *runtime.Instance) ?*PendingLifecycleTasks {
        return runtime.BrowserScope.ofInstance(document).existing(PendingLifecycleTasks);
    }
};

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
    refcounts: @import("refcount.zig").DocumentCounts = .{},

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
    target_element: ?same_object.Link = null,
    /// HTML 4.16.3: the elements :hover and :active rest on - designated by
    /// a pointing device, being actively pointed at, in a formal activation
    /// state (dom.pointer_states). Weak links, like target_element.
    hovered_element: ?same_object.Link = null,
    pointed_element: ?same_object.Link = null,
    activated_element: ?same_object.Link = null,
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
    ranges: @import("live_range_list.zig").LiveList(*runtime.Instance),

    /// The NodeIterators whose root's node document this is, walked by the
    /// NodeIterator pre-removing steps the same way.
    node_iterators: @import("live_range_list.zig").LiveList(*runtime.Instance),

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
    render_blocking_elements: @import("document_rendering.zig").ElementSet,
    /// The document's style engine (dom.style): its sheets and its
    /// elements' computed styles. By value - the engine's type is
    /// dom.style's, the state this document's - and reached through the
    /// `engine_of` hook below (lane style1).
    style_engine: @import("style/root.zig").StyleEngine,

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
    adopted_style_sheets: @import("style/root.zig").adopted.AdoptedSheets,

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
    parser_form_associations: std.ArrayListUnmanaged(@import("document_internals.zig").ParserFormAssociation) = .empty,
    custom_element_registry: @import("custom_elements.zig").RegistryAssociation = .{},
    owns_native_global_registry: bool = false,

    /// domindex1: this tree scope's maps from IDs, and from its named
    /// properties' names, to its elements (dom.tree_ordered_map): what
    /// getElementById, the named getter and the Window's named properties
    /// answer from. Kept by the mutation and attribute change hooks.
    tree_index: @import("tree_ordered_map.zig").Maps,

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
            .render_blocking_elements = @import("document_rendering.zig").ElementSet.init(allocator),
            .style_engine = @import("style/root.zig").StyleEngine.init(allocator),
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
            .adopted_style_sheets = @import("style/root.zig").adopted.AdoptedSheets.init(allocator),
            // FontFaceSet (CSS Font Loading)
            .fonts = null,
            // HTMLAllCollection (undetectable legacy object)
            .all_collection = null,
            .tree_index = @import("tree_ordered_map.zig").Maps.init(allocator, .document),
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

    /// Remove `url`'s entry from the module map. The key and the module are
    /// the caller's to release. The map's removals are its type's steps, so
    /// the map and every removal from it stay in one file
    /// (tools/lint_tombstones.zig sees an unguarded map only there).
    pub fn removeModuleMapEntry(self: *InternalState, url: []const u8) bool {
        return self.module_map.remove(url);
    }

    /// Remove `specifier`'s entry from the import map's imports. The key and
    /// the value are the caller's to release.
    pub fn removeImport(self: *InternalState, specifier: []const u8) bool {
        return self.import_map_imports.remove(specifier);
    }

    pub fn ensureInteractionState(self: *InternalState) !*InteractionState {
        if (self.interaction_state) |shared| return shared;
        const shared = try self.allocator.create(InteractionState);
        shared.* = .{};
        self.interaction_state = shared;
        return shared;
    }

    /// Roll back a newly allocated container when its first child allocation
    /// fails. An existing sibling or policy is never discarded by this path.
    pub fn discardEmptyInteractionState(self: *InternalState, shared: *InteractionState) void {
        std.debug.assert(self.interaction_state == shared);
        if (shared.permissions_policy != null) return;
        std.debug.assert(shared.top_layer == null and shared.autofocus == null);
        self.interaction_state = null;
        self.allocator.destroy(shared);
    }

    pub fn clearTopLayer(self: *InternalState) void {
        const shared = self.interaction_state orelse return;
        const layer = shared.top_layer orelse return;
        shared.top_layer = null;
        layer.deinit();
        self.allocator.destroy(layer);
    }
};

/// A refresh the shared declarative refresh steps set up for a document:
/// where it goes and after how long, and - once the document has completely
/// loaded - the timer it waits on. The document owns it
/// (`InternalState.declarative_refresh`) until it fires; the document's end
/// cancels it.
pub const DeclarativeRefresh = struct {
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

    pub fn destroy(self: *DeclarativeRefresh) void {
        self.allocator.free(self.url);
        self.allocator.destroy(self);
    }

    /// The document is going: the timer must not fire into it.
    pub fn cancel(self: *DeclarativeRefresh) void {
        if (self.timer) |timer| _ = timer.clearTimeout(self.timer_id);
        self.destroy();
    }
};
