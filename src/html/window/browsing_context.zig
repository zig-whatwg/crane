//! Browsing Context - HTML Standard §7.1
//!
//! A browsing context is an environment in which Document objects are presented to the user.
//!
//! Spec: https://html.spec.whatwg.org/multipage/document-sequences.html#browsing-context
//!
//! ## Key Concepts
//!
//! - Browsing contexts present Documents to users (typically in tabs, windows, or iframes)
//! - Each browsing context has a corresponding WindowProxy object
//! - Browsing contexts can be "top-level" (browser tab/window) or "child" (iframe)
//! - The "opener" relationship tracks which context opened which
//!
//! ## Architecture
//!
//! ```
//! BrowsingContext
//! ├── window_proxy: *WindowProxy       # Associated WindowProxy
//! ├── opener: ?*BrowsingContext        # Context that opened this one
//! ├── navigable: ?*Navigable           # Associated navigable
//! ├── is_popup: bool                   # Created via window.open()
//! ├── disowned: bool                   # Opener relationship severed
//! └── virtual_group_id: u64            # Browsing context group ID
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.browsing_context);
const infra = @import("infra");
const cookiestore = @import("cookiestore");
const storage = @import("storage");
const clock = @import("clock");

// Import Origin type from window module
const Origin = @import("window_proxy.zig").Origin;
const IFrameIntegration = @import("iframe_integration.zig").IFrameIntegration;

/// Opaque type for runtime.Instance pointer storage.
/// We use *anyopaque instead of importing runtime to avoid module conflicts.
/// The actual type is runtime.Instance but we store it opaquely here.
/// Consumers that need to use the instance should cast it appropriately.
pub const InstancePtr = *anyopaque;

/// A top-level traversable's last user interaction (`BrowsingContext.
/// input_modality`): the document it happened in - an identity, never read
/// through, with its slab generation (a later page is a new document) - and
/// whether it was a pointer press.
pub const InputModality = struct {
    document: InstancePtr,
    generation: u64,
    pointer: bool,
};

/// `BrowsingContext.focus_visible`: the element focus() was called on with
/// focusVisible given - an identity with its slab generation - and the value.
pub const FocusVisible = struct {
    element: InstancePtr,
    generation: u64,
    visible: bool,
};

/// A top-level traversable's text controls with an uncommitted user edit
/// (`BrowsingContext.pending_edits`), oldest first: each control - an
/// identity, with its slab generation, so one that was freed is never matched
/// again - and its value's hash when the edit began. html.focus keeps it.
pub const PendingEdits = struct {
    pub const capacity = 16;
    pub const Edit = struct {
        element: InstancePtr,
        generation: u64,
        original_hash: u64,
    };
    items: [capacity]Edit = undefined,
    count: usize = 0,
};

/// A top-level traversable's active pointers (`BrowsingContext.
/// active_pointers`; Pointer Events 4: an "active pointer" is any touch
/// contact, pen or mouse that can produce events), with each one's pointer
/// capture state. html.pointer_capture keeps it; it holds no heap memory.
/// Every element or document is an identity with its slab generation, so one
/// that was freed is never matched or read again.
pub const ActivePointers = struct {
    pub const capacity = 16;
    pub const Ref = struct {
        node: InstancePtr,
        generation: u64,
    };
    pub const Entry = struct {
        /// The pointerId.
        id: i32,
        /// html.pointer_capture.Kind.
        kind: u8,
        /// "Active buttons state": a mouse with a button down, a touch or
        /// pen in contact.
        buttons_active: bool = false,
        /// The pointer's "active document": the node document of the last
        /// pointerdown, pointermove or pointerup it fired.
        active_document: ?Ref = null,
        /// "Pending pointer capture target override" and "pointer capture
        /// target override" (Pointer Events 4 section 8).
        pending: ?Ref = null,
        override: ?Ref = null,
    };
    items: [capacity]Entry = undefined,
    count: usize = 0,
};

const joint_history = @import("../navigation/joint_history.zig");
const JointHistory = joint_history.JointHistory;
const traversal_queue = @import("../navigation/traversal_queue.zig");
const TraversalQueue = traversal_queue.TraversalQueue;

/// HTML "cross-origin isolation mode". Crane always chooses "concrete"
/// where HTML lets the user agent pick "logical" or "concrete" (an
/// implementation-defined choice): it grants the cross-origin isolated
/// capability wherever the group is isolated, as Chrome, Firefox and
/// Safari do on desktop (stated).
/// Spec: https://html.spec.whatwg.org/multipage/document-sequences.html#cross-origin-isolation-mode
pub const CrossOriginIsolationMode = enum { none, logical, concrete };

/// Unique ID generators for browsing contexts and browsing context groups:
/// an id names one context (or group) among every Browser's in the process.
// process-wide: an id counter whose only property is uniqueness in the process; every Browser's thread draws from it with an atomic fetch-add, and it carries no state of any instance.
var next_context_id: u64 = 1;
// process-wide: an id counter whose only property is uniqueness in the process; every Browser's thread draws from it with an atomic fetch-add, and it carries no state of any instance.
var next_group_id: u64 = 1;

// ============================================================================
// Sandboxing - HTML Standard §7.1.5
// ============================================================================

/// HTML's sandboxing flag set (dom.sandboxing): a set flag restricts.
pub const SandboxingFlagSet = @import("dom").sandboxing.SandboxingFlagSet;

/// One Browser's browsing contexts (docs/instances.md: the Browser owns its
/// navigables) - a side table of its scope (runtime.BrowserScope, tag
/// `.navigables`), reached from a realm through dom.browser_state
/// (`navigablesOf`, `browsingContextOf`). Every context carries the list it
/// is on (`BrowsingContext.navigables`): a child and an auxiliary context
/// join their parent's or opener's.
///
/// Read and written on the Browser's window agent thread only, which makes,
/// discards and frees every browsing context of the Browser: a worker has
/// none, and its realm never asks.
pub const Navigables = struct {
    allocator: Allocator,
    /// Every browsing context not yet freed, for `ofWindow` and `byId`.
    live: std.ArrayListUnmanaged(*BrowsingContext) = .empty,
    /// The Browser-end net, which must stay empty: a context is freed when
    /// its owner released it and no Window holds it
    /// (`BrowsingContext.window_holds`), never kept here. It once held every
    /// context a container discarded while a Window might still read it,
    /// freed only at the Browser's end (`freeRetired`): one per removed
    /// iframe for the Browser's whole life (lane rep1 b2).
    retired: std.ArrayListUnmanaged(*BrowsingContext) = .empty,
    /// The Browser's navigables that this engine made content for - an
    /// iframe's, a popup's, the host page's (`IFrameIntegration`, made and
    /// driven by HTMLIFrameElement): joined when its context is attached,
    /// left as the navigable is destroyed or its integration deinit'd. It
    /// was one list per thread: an integration never deinit'd stayed listed
    /// past its Browser, and the next Browser on the thread read the freed
    /// block (lane gstate4).
    integrations: std.ArrayListUnmanaged(*IFrameIntegration) = .empty,
    /// Every navigation in flight of the Browser's navigables, by its ID
    /// (HTMLIFrameElement's records, opaque here: a navigation's record is
    /// its navigable's, and each ends with its integration). Whoever keeps
    /// only an ID - an event-loop task, a fetch's client, a streamed body's
    /// holder - keeps this list with it, and a navigation ended meanwhile is
    /// simply not found. It was one map per thread (lane gstate4).
    navigations: std.AutoHashMapUnmanaged(u64, *anyopaque) = .empty,
    navigations_guard: infra.tombstones.TombstoneGuard = .{},
    /// The storage sheds the Browser's traversable navigables hold - session
    /// storage (Storage 4.3: "A traversable navigable holds a storage shed"),
    /// by each one's top-level browsing context id; each ends with its
    /// context's record (`BrowsingContext.deinit`). Window-thread state, as
    /// this list is: sessionStorage is [Exposed=Window].
    traversable_storage: storage.TraversableStorageSheds,
    /// The Browser's navigation observer - its one slot, which the Browser
    /// sets to its own dispatcher (src/html/navigation/observer.zig): told
    /// each navigation milestone of these navigables, on the window thread.
    observer: ?@import("../navigation/observer.zig").Observer = null,
    /// The Browser's document-start host script hook - its one slot, which
    /// the Browser sets to its own dispatcher (src/html/navigation/
    /// document_start.zig): run as each new document's Window realm is set
    /// up, before its parser runs a script. Unlike the observer, it may run
    /// script.
    document_start: ?@import("../navigation/document_start.zig").Hook = null,
    /// The Browser's user prompt hook (navigation/user_prompts.zig): told as
    /// each simple dialog opens and closes (WebDriver BiDi's user prompt
    /// opened and closed). One slot, which the Browser sets to its own
    /// dispatcher.
    user_prompts: ?@import("../navigation/user_prompts.zig").Hook = null,

    pub fn init(allocator: Allocator) Navigables {
        return .{ .allocator = allocator, .traversable_storage = .init(allocator) };
    }

    /// The list's end, with its Browser's scope: the retired contexts are
    /// freed (no Window is left to read them). A context still live outlived
    /// its Browser - its owner never freed it - and leaves the list here, so
    /// that its own end, if it ever comes, touches no freed list.
    pub fn deinit(self: *Navigables) void {
        self.freeRetired();
        for (self.live.items) |ctx| ctx.navigables = null;
        self.live.deinit(self.allocator);
        // An integration still listed outlived its Browser: it leaves no list
        // when it ends. (One that left is not reached any more: its block
        // and its Browser's end together.)
        for (self.integrations.items) |integration| integration.navigables = null;
        self.integrations.deinit(self.allocator);
        // A navigation ends with its integration, before its Browser does.
        self.navigations.deinit(self.allocator);
        // The storage sheds of traversables whose records outlived the list
        // (the contexts above, freed by their own ends, took theirs).
        self.traversable_storage.deinit();
        self.* = .{ .allocator = self.allocator, .traversable_storage = .init(self.allocator) };
    }

    /// `integration` joins this list (once) - the list of its browsing
    /// context's Browser. It names the list from now on, through its
    /// navigations' end.
    pub fn joinIntegration(self: *Navigables, integration: *IFrameIntegration) Allocator.Error!void {
        if (self.listsIntegration(integration)) return;
        if (integration.navigables) |other| if (other != self) leaveIntegration(integration);
        try self.integrations.append(self.allocator, integration);
        integration.navigables = self;
    }

    /// `integration` leaves the list it is on, if any - it no longer lives.
    /// It still names the list: its navigations in flight end after it
    /// leaves (IFrameIntegration.deinit runs `deinit_callback`, then
    /// `abandon_navigations_callback`).
    pub fn leaveIntegration(integration: *IFrameIntegration) void {
        const self = integration.navigables orelse return;
        for (self.integrations.items, 0..) |existing, i| {
            if (existing == integration) {
                _ = self.integrations.swapRemove(i);
                return;
            }
        }
    }

    /// Record navigation `id` in flight.
    pub fn putNavigation(self: *Navigables, id: u64, record: *anyopaque) Allocator.Error!void {
        self.navigations_guard.beforeInsert(&self.navigations);
        try self.navigations.put(self.allocator, id, record);
    }

    /// Navigation `id`'s record, while it is in flight.
    pub fn navigation(self: *const Navigables, id: u64) ?*anyopaque {
        return self.navigations.get(id);
    }

    /// Navigation `id`'s record, taken out of the list.
    pub fn takeNavigation(self: *Navigables, id: u64) ?*anyopaque {
        const kv = self.navigations.fetchRemove(id) orelse return null;
        self.navigations_guard.noteRemoval(&self.navigations);
        return kv.value;
    }

    /// The navigations in flight. A walk must not add or take one.
    pub fn navigationIterator(self: *const Navigables) std.AutoHashMapUnmanaged(u64, *anyopaque).Iterator {
        return self.navigations.iterator();
    }

    /// Whether `integration` is on this list - its navigable lives. Compares
    /// only: `integration` may have been freed.
    pub fn listsIntegration(self: *const Navigables, integration: *const IFrameIntegration) bool {
        for (self.integrations.items) |existing| {
            if (existing == integration) return true;
        }
        return false;
    }

    /// The Browser's teardown, after its last Window is gone: the net for a
    /// context whose owner released it and whose Window holds were never all
    /// released - a missed release, reported (log.err, which fails a test)
    /// and freed. Normally there is none: the last hold's release frees it.
    /// Another Browser's contexts are its own.
    pub fn freeRetired(self: *Navigables) void {
        var released: std.ArrayListUnmanaged(*BrowsingContext) = .empty;
        defer released.deinit(self.allocator);
        for (self.live.items) |ctx| {
            if (ctx.owner_released) released.append(self.allocator, ctx) catch {};
        }
        for (self.retired.items) |ctx| {
            if (!ctx.owner_released) released.append(self.allocator, ctx) catch {};
        }
        self.retired.clearAndFree(self.allocator);
        if (released.items.len != 0) log.err("{d} browsing context(s) outlived their owner and every Window that held them: a Window hold was not released", .{released.items.len});
        // A context leaves `live` as it is freed: the list was taken first.
        for (released.items) |ctx| ctx.deinit();
    }

    /// The browsing context whose active window is `window`, if one is live.
    /// A Window a navigation replaced is no browsing context's active window:
    /// its document is not fully active.
    pub fn ofWindow(self: *const Navigables, window: InstancePtr) ?*BrowsingContext {
        for (self.live.items) |ctx| {
            if (ctx.active_window == window and !ctx.orphaned) return ctx;
        }
        return null;
    }

    /// A Window's teardown, which frees its associated `document` with it: no
    /// browsing context of this Browser - live or retired (a retired context
    /// stays on `live` until `freeRetired` frees it) - names `window` as its
    /// active window from here on, and none names `document` as its active
    /// document, WHATEVER its active window is (lane winslot1, kind 1; lane
    /// nav2, item 0). A retired context - a removed iframe's, kept while a
    /// Window might still read it (`discard`) - named its torn-down Window
    /// for the rest of the Browser's life, and every reader of it (user
    /// activation, the opener, frames[i], a frame's named property) read
    /// whatever the slab put at that address next.
    ///
    /// The document is cleared on its own, not only where the window
    /// matches: a context's two pointers diverge whenever a navigation gave
    /// it a new Window before that Window's document became active - a
    /// frame commit that failed after the realm swap (HTMLIFrameElement
    /// replaceRealm, then no new document), or a kept page whose commit
    /// failed. The context then named the old Window's freed document, and
    /// the next navigation's abort read it (a Bus error hashing the freed
    /// Document's interface name in template_registry, under
    /// Document.abortDocument's retainValue; tests/html/nav2_failed_
    /// navigation_active_document_test.zig). Blink has no second pointer to
    /// forget: a frame's document IS its window's document
    /// (Frame::GetDocument reads DomWindow()->document()), and it clears both
    /// sides when a window leaves its frame (DOMWindow::DisconnectFromFrame).
    /// Compares only; reads neither.
    pub fn forgetWindow(self: *Navigables, window: InstancePtr, document: ?InstancePtr) void {
        for (self.live.items) |ctx| {
            if (ctx.active_window == window) ctx.active_window = null;
            if (document) |d| {
                if (ctx.active_document == d) ctx.active_document = null;
            }
        }
    }

    /// The live browsing context with this id, if any.
    pub fn byId(self: *const Navigables, id: u64) ?*BrowsingContext {
        for (self.live.items) |ctx| {
            if (ctx.id == id) return ctx;
        }
        return null;
    }

    /// Every live browsing context of this Browser - its pages' top-level
    /// ones, their frames' and their popups' - including orphaned ones,
    /// which the caller skips. BORROWED until a context is made or freed.
    pub fn contexts(self: *const Navigables) []const *BrowsingContext {
        return self.live.items;
    }

    fn add(self: *Navigables, ctx: *BrowsingContext) Allocator.Error!void {
        try self.live.append(self.allocator, ctx);
    }

    fn remove(self: *Navigables, ctx: *BrowsingContext) void {
        for (self.live.items, 0..) |c, i| {
            if (c == ctx) {
                _ = self.live.swapRemove(i);
                return;
            }
        }
    }
};

/// A window's position (its left and top edges on the Web-exposed screen
/// area) and its viewport's size, in CSS pixels; null for "not given".
pub const WindowGeometry = struct {
    x: ?i32 = null,
    y: ?i32 = null,
    width: ?i32 = null,
    height: ?i32 = null,
};

/// HTML 7.3.1.1 "system visibility state": "hidden" or "visible".
pub const SystemVisibility = enum { visible, hidden };

/// A viewport's size in CSS pixels (CSSOM View innerWidth/innerHeight are
/// `long`).
pub const ViewportSize = struct { width: i32, height: i32 };

pub const BrowsingContext = struct {
    /// Allocator used for this context
    allocator: Allocator,

    /// Unique identifier for this browsing context
    id: u64,

    /// The Browser's list this context is on (`Navigables`), from its
    /// making until it is freed: its parent's or opener's for a child or an
    /// auxiliary context. Null only once the list ended first (a context its
    /// owner never freed before its Browser's end).
    navigables: ?*Navigables,

    /// The opener browsing context (§7.1)
    /// The browsing context that opened this one via window.open() or similar.
    /// Null for initially created contexts.
    opener: ?*BrowsingContext,

    /// Whether the opener relationship has been disowned (§7.1)
    /// Set to true when noopener is used or relationship is severed.
    disowned: bool,

    /// Whether this is a popup browsing context (§7.1)
    /// True if created via window.open() with is_popup flag.
    is_popup: bool,

    /// Virtual browsing context group ID (§7.1.3)
    /// Contexts with the same ID are in the same group.
    virtual_group_id: u64,

    /// HTML 7.3.2's "virtual browsing context group ID" - not the group
    /// (`virtual_group_id` is that): "used by opener policy reporting, to
    /// keep track of the browsing context group switches that would have
    /// happened if the report-only policy had been enforced". Read from a
    /// top-level context only ("check if an access between two browsing
    /// contexts should be reported" step 8). Copied from the opener's or
    /// the creator's top-level context ("create a new auxiliary browsing
    /// context and document" step 8, "create a new browsing context and
    /// document" step 5.3), renewed by "obtain a browsing context to use for
    /// a navigation response" step 9.1 (`startVirtualGroup`). A context made
    /// with no creator, and every group switch, takes a new unique one, as
    /// Chromium's CrossOriginOpenerPolicyStatus::EnforceCOOP does on a
    /// BrowsingInstance swap (HTML leaves such a context's at its initial 0,
    /// which no access across groups can observe).
    virtual_browsing_context_group_id: u64 = 0,

    /// Whether this context is closed
    is_closed: bool,

    /// HTML "is closing" of the traversable this is the active browsing
    /// context of: window.close() was accepted, and "definitely close" is
    /// queued. `window.closed` is true from here.
    is_closing: bool = false,

    /// HTML "is created by web content" of its traversable: made by "the
    /// rules for choosing a navigable" for a new top-level traversable -
    /// window.open(), or a link's or form's target - not by the host.
    is_created_by_web_content: bool = false,

    /// Target name for this browsing context
    /// Used for named targeting (e.g., <a target="name">)
    target_name: []const u8,

    /// Parent browsing context (for child contexts)
    parent: ?*BrowsingContext,

    /// HTML "container": the element whose content navigable this is - an
    /// iframe - or null for a top-level context. Set by the element when it
    /// creates the context, and cleared when the context is discarded, before
    /// the element can go.
    container: ?*anyopaque = null,

    /// Child browsing contexts (iframes, frames)
    children: std.ArrayListUnmanaged(*BrowsingContext),

    /// The user agent's cookie jar - the Browser's, one for every window,
    /// frame and worker it runs. Set on each top-level context as the
    /// Browser makes it (auxiliary ones too, from their opener); a child
    /// reads its top's (`cookieJar`).
    cookie_jar: ?*cookiestore.CookieJar = null,

    /// Initial URL for this browsing context
    initial_url: ?[]const u8,

    /// HTML's "opener origin at creation": the origin of its opener's active
    /// document when this auxiliary context was made ("create a new
    /// auxiliary browsing context" step 9), serialized ("null" for an opaque
    /// one); null for a context with no opener. Chromium keeps it as the
    /// FrameTreeNode's popup_creator_origin. Read by opener policy access
    /// reports (dom.coop_reporting: an openee's initialPopupURL). OWNED.
    opener_origin_at_creation: ?[]u8 = null,

    /// HTML's popup sandboxing flag set: empty when the context is created,
    /// populated by "the rules for choosing a navigable" for a top-level
    /// traversable opened from a sandboxed document - its creation
    /// sandboxing flags, and those of every navigation in it. A child
    /// context's flags are its container's (dom.sandboxing), never stored
    /// here: an iframe's sandbox attribute reaches a document only when the
    /// iframe navigates, and every document keeps its own active set.
    /// Spec: https://html.spec.whatwg.org/multipage/browsers.html#popup-sandboxing-flag-set
    popup_sandboxing_flags: SandboxingFlagSet = .empty,

    /// HTML 7.3.1.1: a traversable navigable's system visibility state -
    /// whether its window is minimized, its tab in the background, the page
    /// covered by a system element. "Determined by the user agent, including
    /// its initial value upon creation" (HTML 6.2): the platform's
    /// (`systemVisibility` when the traversable is made, `visibility_changed`
    /// after). Kept on the top-level traversable - every traversable is one -
    /// and read for any navigable through `traversableSystemVisibility`.
    system_visibility: SystemVisibility = .visible,

    /// A top-level traversable's viewport size in CSS pixels, as the
    /// platform's window reports it (`window_rect_changed(tab, rect)`: a
    /// headless window has no chrome, so its rect's size is its viewport -
    /// the integrator's ruling C, 2026-11-21), or null while the platform has
    /// said nothing (the Window's own size then: its defaults, or what
    /// window.open's features asked for). CSSOM View's innerWidth/innerHeight,
    /// and the media queries that read them, read it through
    /// `traversableViewport`.
    viewport: ?ViewportSize = null,
    /// A host's override of that viewport (an automation client's device
    /// metrics: CDP Emulation.setDeviceMetricsOverride, as Chrome's
    /// EmulationHandler and Blink's InspectorEmulationAgent keep one per
    /// page), which wins over the platform's while set.
    viewport_override: ?ViewportSize = null,
    /// A host's overrides of the platform's other answers for this tab -
    /// media, touch points, user agent (host_overrides.zig: CDP Emulation,
    /// WebDriver BiDi emulation). A top-level traversable's; read through
    /// `getTop()`. Owned: freed by `deinit`.
    host_overrides: @import("host_overrides.zig").HostOverrides = .{},

    /// HTML's one permitted sandboxed navigator: the browsing context that
    /// opened this one from a document with the sandboxed navigation browsing
    /// context flag set, which may still navigate it ("allowed by sandboxing
    /// to navigate" step 4.1). Null otherwise. Compared, never dereferenced:
    /// it may be gone.
    /// Spec: https://html.spec.whatwg.org/multipage/browsers.html#one-permitted-sandboxed-navigator
    one_permitted_sandboxed_navigator: ?*const BrowsingContext = null,

    /// The `iframe` element referrer policy its active document was created
    /// with: navigationParams's (navigate step 8's target snapshot params,
    /// taken as the navigation started), or for the initial about:blank
    /// document its embedder's referrerpolicy attribute then ("create a new
    /// browsing context and document" step 16). Empty for a top-level
    /// traversable and any container that is not an iframe. The internal
    /// ancestor origin objects list creation steps 8-9 read it
    /// (Location.ancestorOrigins).
    /// Spec: https://html.spec.whatwg.org/multipage/document-sequences.html#internal-ancestor-origin-objects-list-creation-steps
    ancestor_origins_policy: @import("fetch").internal.ReferrerPolicy = .empty,

    /// Fetch 4.12.1: this navigable's container's "reserved deferred-fetch
    /// quota" - 0, minimal quota (8 KiB) or normal quota (64 KiB) - kept on
    /// the container's content navigable, which a container has while it
    /// holds the reservation. HTML navigate step 23 sets it
    /// (dom.deferred_fetches.reserveQuota), "create and initialize a
    /// Document object" step 21 clears it for a same-origin document
    /// (potentiallyFreeQuota). 0 for a top-level traversable.
    /// Spec: https://fetch.spec.whatwg.org/#reserved-deferred-fetch-quota
    reserved_deferred_fetch_quota: @import("dom").deferred_fetches.ReservedQuota = .none,

    /// HTML "cross-origin isolation mode" of this context's browsing
    /// context group. A group's mode is set once, as the group is made
    /// ("obtain a browsing context to use for a navigation response" step
    /// 12), and every context that joins the group later - a child, an
    /// auxiliary - copies it (initChild, initAuxiliary), so each context's
    /// copy is its group's. The agent clusters of the group's windows take
    /// it too ("obtain a similar-origin window agent" step 6.2): a Window's
    /// cross-origin isolated capability reads it here.
    /// Spec: https://html.spec.whatwg.org/multipage/document-sequences.html#bcg-cross-origin-isolation
    cross_origin_isolation_mode: CrossOriginIsolationMode = .none,

    /// Origin of this browsing context's active document
    /// Used for same-origin checks per HTML Standard §7.5
    /// Defaults to opaque origin until set by navigation/document creation
    origin: Origin = Origin.createOpaque(),

    /// The active document in this browsing context (HTML §7.3.1)
    /// Per spec: "A browsing context has an active document — the Document
    /// that is currently displayed in the browsing context."
    /// This is a pointer to a Document instance (runtime.Instance).
    /// Stored as ?InstancePtr to avoid module import conflicts.
    active_document: ?InstancePtr = null,

    /// The associated Window object (HTML §7.3)
    /// Per spec: Each browsing context has a WindowProxy and associated Window.
    /// This is a pointer to a Window instance (runtime.Instance).
    /// Stored as ?InstancePtr to avoid module import conflicts.
    active_window: ?InstancePtr = null,

    /// The container discarded this context while a Window still pointed at
    /// it (script can hold `iframe.contentWindow` past `iframe.remove()`), so it
    /// lives on for that Window only. See `discard` and `window_holds`.
    orphaned: bool = false,

    /// The Windows that read this context and do not own it - each Window it
    /// was shown in (Window's InternalState.browsing_context) that has not
    /// ended: counted, the refcount shape of the DOM's (src/AGENTS.md "DOM
    /// lifetime: reference counting"). A Window holds it from the moment it
    /// shows it (`holdForWindow`) until its own end (`releaseFromWindow`).
    window_holds: u32 = 0,

    /// Its owner - an iframe's or a popup's navigable record
    /// (IFrameIntegration), or the host page's traversable record - let it
    /// go (`releaseByOwner`, `discard`). It is freed when this is set and no
    /// Window holds it, whichever comes last.
    owner_released: bool = false,

    /// The traversable navigable's session history, on a top-level context
    /// (see `jointHistory`). Owned.
    joint_history: ?*JointHistory = null,

    /// The traversable navigable's session history traversal queue, on a
    /// top-level context (see `traversalQueue`; HTML 7.4.1.3). Owned.
    traversal_queue: ?*TraversalQueue = null,

    /// CSSOM View "set up browsing context features": the position and
    /// viewport size window.open() asked for this context's window - what
    /// every Window it shows reports as screenX/screenY and
    /// innerWidth/innerHeight. Null: the default.
    requested_window: WindowGeometry = .{},

    /// "Allowed to perform a navigation or history update"'s window: when
    /// it began (monotonic ns) and how many navigations and history updates
    /// it has counted (see `allowedToNavigateOrUpdateHistory`).
    navigation_rate_window_start: u64 = 0,
    navigation_rate_count: u32 = 0,

    /// The input modality of the last user interaction in this top-level
    /// traversable (html.focus, for :focus-visible): a pointer press or a key
    /// press, in which of its documents. A top-level context's, beside its
    /// session history; null until the first interaction. It was one per
    /// thread, so another tab's key press decided this tab's :focus-visible.
    input_modality: ?InputModality = null,

    /// The element whose focus a focus() call with FocusOptions.focusVisible
    /// last indicated or not (html.focus, for :focus-visible): an identity,
    /// never read through, with its slab generation. It overrides the
    /// heuristic for that element until the next focus() or user input.
    focus_visible: ?FocusVisible = null,

    /// The text controls in this top-level traversable whose value the user
    /// changed and has not committed (html.focus, the focus update steps'
    /// step 2.1). A top-level context's; holds no heap memory. It was one
    /// table per thread, and another tab's edits pushed this tab's out.
    pending_edits: PendingEdits = .{},

    /// The active pointers acting on this top-level traversable and their
    /// pointer capture state (html.pointer_capture). A top-level context's,
    /// as each tab of a browser has its own pointers: a touch in one tab is
    /// no active pointer of another, and Element.setPointerCapture() in one
    /// never captures another's. Holds no heap memory.
    active_pointers: ActivePointers = .{},

    /// The type of `pending_edits`, for html.focus.
    pub const PendingEditsTable = PendingEdits;

    /// How many navigations and history updates a navigable may perform in
    /// one window of `navigation_rate_window` - Blink's NavigationRateLimiter
    /// (kStateUpdateLimit, 200 per 10 seconds).
    pub const navigation_rate_limit: u32 = 200;
    pub const navigation_rate_window: u64 = 10 * std.time.ns_per_s;

    /// Create a new browsing context, on `navigables` - its Browser's list.
    pub fn init(allocator: Allocator, navigables: *Navigables) !*BrowsingContext {
        const ctx = try allocator.create(BrowsingContext);
        errdefer allocator.destroy(ctx);
        try navigables.add(ctx);
        ctx.* = .{
            .allocator = allocator,
            .id = @atomicRmw(u64, &next_context_id, .Add, 1, .monotonic),
            .navigables = navigables,
            .opener = null,
            .disowned = false,
            .is_popup = false,
            .virtual_group_id = 0,
            .is_closed = false,
            .target_name = "",
            .parent = null,
            .children = .empty,
            .initial_url = null,
        };
        return ctx;
    }

    /// Create a new top-level browsing context, on `navigables`.
    pub fn initTopLevel(allocator: Allocator, navigables: *Navigables) !*BrowsingContext {
        const ctx = try init(allocator, navigables);
        ctx.virtual_group_id = @atomicRmw(u64, &next_group_id, .Add, 1, .monotonic);
        ctx.virtual_browsing_context_group_id = newVirtualGroupId();
        return ctx;
    }

    /// A new unique virtual browsing context group ID. Drawn from the group
    /// counter: both only need uniqueness.
    fn newVirtualGroupId() u64 {
        return @atomicRmw(u64, &next_group_id, .Add, 1, .monotonic);
    }

    /// Create a new child browsing context with the given parent, on its
    /// parent's list.
    pub fn initChild(allocator: Allocator, parent_ctx: *BrowsingContext) !*BrowsingContext {
        const ctx = try init(allocator, parent_ctx.navigables orelse return error.NoNavigables);
        errdefer ctx.deinit();
        ctx.parent = parent_ctx;
        ctx.virtual_group_id = parent_ctx.virtual_group_id;
        // "Create a new browsing context and document" step 5.3: the
        // creator's top-level browsing context's virtual group ID.
        ctx.virtual_browsing_context_group_id = parent_ctx.getTop().virtual_browsing_context_group_id;
        ctx.cross_origin_isolation_mode = parent_ctx.cross_origin_isolation_mode;
        try parent_ctx.children.append(parent_ctx.allocator, ctx);
        return ctx;
    }

    /// The user agent's cookie jar, as this context reaches it: its own, or
    /// its nearest ancestor's - a frame's is its top-level context's. Null
    /// for a context no Browser made (a test's, a detached document's).
    pub fn cookieJar(self: *const BrowsingContext) ?*cookiestore.CookieJar {
        var context: ?*const BrowsingContext = self;
        while (context) |c| : (context = c.parent) {
            if (c.cookie_jar) |jar| return jar;
        }
        return null;
    }

    /// Create a new auxiliary browsing context (via window.open()), on its
    /// opener's list.
    pub fn initAuxiliary(allocator: Allocator, opener_ctx: *BrowsingContext, is_popup_flag: bool) !*BrowsingContext {
        const ctx = try initTopLevel(allocator, opener_ctx.navigables orelse return error.NoNavigables);
        errdefer ctx.deinit();
        // HTML "create a new auxiliary browsing context" step 1-2: "Let group
        // be openerBrowsingContext's top-level browsing context's group",
        // which the new context joins.
        ctx.virtual_group_id = opener_ctx.getTop().virtual_group_id;
        // Step 8: "Set browsingContext's virtual browsing context group ID to
        // openerTopLevelBrowsingContext's virtual browsing context group ID."
        ctx.virtual_browsing_context_group_id = opener_ctx.getTop().virtual_browsing_context_group_id;
        ctx.cross_origin_isolation_mode = opener_ctx.getTop().cross_origin_isolation_mode;
        ctx.opener = opener_ctx;
        ctx.is_popup = is_popup_flag;
        // Step 9: "Set browsingContext's opener origin at creation to
        // opener's active document's origin."
        ctx.opener_origin_at_creation = try serializeOrigin(allocator, opener_ctx.origin);
        // "The rules for choosing a navigable" step 8.10: "Set chosen's is
        // created by web content to true."
        ctx.is_created_by_web_content = true;
        return ctx;
    }

    /// HTML's ASCII serialization of an origin: "null" for an opaque one,
    /// else scheme "://" host, then ":" port when it has one. OWNED.
    fn serializeOrigin(allocator: Allocator, origin: Origin) error{OutOfMemory}![]u8 {
        if (origin.is_opaque) return allocator.dupe(u8, "null");
        if (origin.port) |port| return std.fmt.allocPrint(allocator, "{s}://{s}:{d}", .{ origin.scheme, origin.host, port });
        return std.fmt.allocPrint(allocator, "{s}://{s}", .{ origin.scheme, origin.host });
    }

    /// Leave the parent: off its children list, and the link to it gone. The
    /// parent link and the parent's list are one fact, ended at both ends -
    /// as Blink's Frame::RemoveChild clears the child's parent as it unlinks
    /// it. A context with no parent has nothing to leave.
    pub fn removeFromParent(self: *BrowsingContext) void {
        const parent_ctx = self.parent orelse return;
        for (parent_ctx.children.items, 0..) |child, i| {
            if (child == self) {
                _ = parent_ctx.children.orderedRemove(i);
                break;
            }
        }
        self.parent = null;
    }

    /// Let go of every child: each one's link to this context ends with its
    /// entry on the list.
    fn releaseChildren(self: *BrowsingContext) void {
        for (self.children.items) |child| child.parent = null;
        self.children.clearRetainingCapacity();
    }

    /// Discard this context for its container (HTML "destroy a child
    /// navigable"): it leaves its parent, closes, and lets go of its children -
    /// a discarded navigable has none - so a Window that script still holds
    /// reads `closed` true and `length` 0. Returns whether the caller may free
    /// it now: when no Window holds it. Otherwise its owner has released it,
    /// and the last Window's end frees it (`releaseFromWindow`): freeing it
    /// here left `w.length` reading a freed child list (an @intCast panic in
    /// Window.get_length), and keeping it until the Browser's end kept one
    /// per removed iframe for the Browser's whole life.
    pub fn discard(self: *BrowsingContext) bool {
        self.container = null;
        self.removeFromParent();
        self.close();
        self.releaseChildren();
        if (self.window_holds == 0) return true;
        self.orphaned = true;
        self.owner_released = true;
        return false;
    }

    /// A Window shows this context and reads it from now on, until its end.
    pub fn holdForWindow(self: *BrowsingContext) void {
        self.window_holds += 1;
    }

    /// A Window that held this context ended: the context is freed if its
    /// owner released it and this was the last hold. Returns whether it was
    /// freed - the caller reads nothing of it then.
    pub fn releaseFromWindow(self: *BrowsingContext) bool {
        std.debug.assert(self.window_holds > 0);
        self.window_holds -= 1;
        if (self.window_holds != 0 or !self.owner_released) return false;
        self.deinit();
        return true;
    }

    /// The owner lets go: freed now if no Window holds it, else discarded
    /// (closed, out of the tree) and freed by the last Window's end.
    pub fn releaseByOwner(self: *BrowsingContext) void {
        if (self.window_holds == 0) return self.deinit();
        _ = self.discard();
    }

    /// Deinitialize and free resources
    pub fn deinit(self: *BrowsingContext) void {
        self.host_overrides.deinit(self.allocator);
        // The tree's links end at both ends before the memory goes: off the
        // parent's children list, and every child's link to this context
        // gone. Each context is owned elsewhere - an IFrameIntegration, a
        // Window - and freed on its owner's schedule, in no fixed order with
        // its parent or its children; a list or link left behind was read
        // freed by the next walk ("definitely close", History's traversal,
        // window[i]). With both ends ended at every unlink, a link that is
        // set always names a context that is still allocated. Children are
        // not freed here: their owners free them.
        self.removeFromParent();
        self.releaseChildren();
        // The opener links to this context end too: a context it opened - a
        // popup, or a frame window.open() navigated by name (window open
        // steps 16.2) - is freed on its own owner's schedule, and its
        // window.opener then answers null, as Blink's Frame::Detach clears
        // every openee's opener (OpenedFrameTracker).
        if (self.navigables) |navigables| {
            for (navigables.contexts()) |other| {
                if (other != self and other.opener == self) other.opener = null;
            }
        }

        // Only deinit the children list if it was actually allocated (capacity > 0).
        // An unallocated ArrayListUnmanaged (initialized with .{}) has capacity 0
        // and a pointer to static memory that should not be freed.
        if (self.children.capacity > 0) {
            self.children.deinit(self.allocator);
        }

        // Free target name if allocated
        if (self.target_name.len > 0) {
            self.allocator.free(self.target_name);
        }
        if (self.opener_origin_at_creation) |origin| self.allocator.free(origin);
        self.opener_origin_at_creation = null;

        // Free initial URL if allocated
        if (self.initial_url) |url| {
            self.allocator.free(url);
        }

        // Clear document and window references
        // Note: The actual Document and Window instances are managed by the GC/runtime,
        // we just clear our references to them to avoid dangling pointers.
        self.active_document = null;
        self.active_window = null;

        // Its traversal queue's items go first (each destroyed once; a waiter
        // that completes later finds no queue): they may name its history.
        if (self.traversal_queue) |queue| {
            self.traversal_queue = null;
            queue.deinit();
            self.allocator.destroy(queue);
        }
        if (self.joint_history) |history| {
            history.deinit();
            self.allocator.destroy(history);
            self.joint_history = null;
        }
        if (self.navigables) |navigables| {
            // Its traversable's storage shed - session storage - goes with
            // it, as its session history just did (Storage 4.3: a
            // traversable navigable holds it; HTML "destroy a top-level
            // traversable" step 5 removes the traversable). This record is
            // the last of the traversable: freed once its owner released it
            // and no Window holds it, so no Storage reads the shed any more
            // (storage.TraversableStorageSheds). A frame's context has none.
            navigables.traversable_storage.discard(self.id);
            navigables.remove(self);
        }

        self.allocator.destroy(self);
    }

    /// The session history traversal queue of this context's traversable
    /// navigable - its top - made on first use with `schedule`, which queues
    /// its service task on the traversable's event loop. Null when the
    /// context is on no Browser's list (the service task finds a traversable
    /// by ID there).
    pub fn traversalQueue(self: *BrowsingContext, schedule: traversal_queue.Schedule) !*TraversalQueue {
        const top = self.getTop();
        if (top.traversal_queue) |queue| return queue;
        const navigables = top.navigables orelse return error.NoNavigables;
        const queue = try top.allocator.create(TraversalQueue);
        queue.* = TraversalQueue.init(top.allocator, navigables, top.id, schedule);
        top.traversal_queue = queue;
        return queue;
    }

    /// The session history of this context's traversable navigable - its top
    /// - made on first use.
    pub fn jointHistory(self: *BrowsingContext) !*JointHistory {
        const top = self.getTop();
        if (top.joint_history) |history| return history;
        const history = try top.allocator.create(JointHistory);
        history.* = JointHistory.init(top.allocator);
        top.joint_history = history;
        return history;
    }

    /// The session history of this context's traversable, with an entry for
    /// this context and every context from it up to its traversable ("initialize
    /// the navigable"): each one missing gets an entry for its active
    /// document - the traversable's at the current step, a child's at the
    /// step its parent's document began at ("create a new child navigable"
    /// 12.4). `info_of` gives a document's URL and origin, owned by the
    /// allocator it is given.
    pub fn ensureHistoryEntries(
        self: *BrowsingContext,
        info_of: *const fn (document: InstancePtr, allocator: Allocator) anyerror!joint_history.DocumentInfo,
    ) !*JointHistory {
        const history = try self.jointHistory();
        // From the traversable down: a child's first entry takes its step
        // from its parent's entries.
        var chain: [65]*BrowsingContext = undefined;
        var count: usize = 0;
        var current: ?*BrowsingContext = self;
        while (current) |ctx| : (current = ctx.parent) {
            if (count == chain.len) break;
            chain[count] = ctx;
            count += 1;
        }
        var i = count;
        while (i > 0) {
            i -= 1;
            const ctx = chain[i];
            if (history.hasNavigable(ctx.id)) continue;
            const document = ctx.getActiveDocument() orelse continue;
            const info = try info_of(document, history.allocator);
            defer history.allocator.free(info.url);
            defer history.allocator.free(info.origin);
            if (ctx.parent) |parent| {
                try history.addChildInitialEntry(ctx.id, parent.id, info.url, document, info.origin);
            } else {
                try history.addInitialEntry(ctx.id, info.url, document, info.origin);
            }
        }
        return history;
    }

    /// The live descendants of this context, parents first, into `out`.
    pub fn collectDescendants(self: *BrowsingContext, allocator: Allocator, out: *std.ArrayListUnmanaged(*BrowsingContext)) !void {
        var index = out.items.len;
        try out.append(allocator, self);
        while (index < out.items.len and out.items.len < 1024) : (index += 1) {
            for (out.items[index].children.items) |child| try out.append(allocator, child);
        }
    }

    /// HTML "allowed to perform a navigation or history update", the
    /// navigable's implementation-defined algorithm ("this can return
    /// blocked if invoked too many times within a certain timespan"): true
    /// (allowed) for the first `navigation_rate_limit` calls of a window,
    /// false (blocked) after, until `navigation_rate_window` has passed since
    /// the window began, when a new one begins. Every call counts, as in
    /// Blink's NavigationRateLimiter::CanProceed. Asked by navigate (step
    /// 12), the shared history push/replace state steps (step 6) and delta
    /// traverse (step 3).
    pub fn allowedToNavigateOrUpdateHistory(self: *BrowsingContext) bool {
        return self.allowedToNavigateOrUpdateHistoryAt(@intCast(@max(0, clock.monotonicNanos())));
    }

    /// `allowedToNavigateOrUpdateHistory` at `now` (monotonic ns).
    pub fn allowedToNavigateOrUpdateHistoryAt(self: *BrowsingContext, now: u64) bool {
        if (self.navigation_rate_count == 0 or now -| self.navigation_rate_window_start >= navigation_rate_window) {
            self.navigation_rate_window_start = now;
            self.navigation_rate_count = 0;
        }
        self.navigation_rate_count +|= 1;
        return self.navigation_rate_count <= navigation_rate_limit;
    }

    /// Check if this browsing context is a top-level browsing context (§7.1)
    pub fn isTopLevel(self: *const BrowsingContext) bool {
        return self.parent == null;
    }

    /// Check if this browsing context is a child browsing context (§7.1)
    pub fn isChild(self: *const BrowsingContext) bool {
        return self.parent != null;
    }

    /// HTML "script-closable" (7.2.2.1), for the navigable this is the
    /// active browsing context of: "if it is a top-level traversable, and any
    /// of the following are true: its is created by web content is true; or
    /// its session history entries's size is 1." A traversable whose history
    /// has not been recorded yet has its initial entry only.
    pub fn isScriptClosable(self: *const BrowsingContext) bool {
        if (self.parent != null) return false;
        if (self.is_created_by_web_content) return true;
        const history = self.joint_history orelse return true;
        return history.entryCount(self.id) <= 1;
    }

    /// Get the top-level browsing context
    pub fn getTop(self: *BrowsingContext) *BrowsingContext {
        var current = self;
        while (current.parent) |p| {
            current = p;
        }
        return current;
    }

    /// The system visibility state of this navigable's traversable navigable
    /// (HTML 6.2): what "set the initial visibility state" gives a document
    /// it makes active.
    pub fn traversableSystemVisibility(self: *BrowsingContext) SystemVisibility {
        return self.getTop().system_visibility;
    }

    /// The viewport size of this navigable's top-level traversable - a
    /// host's override, else the platform's window - or null when neither
    /// is known. Only a top-level traversable's viewport is the window's: a
    /// child navigable's is its container's box, which a renderer answers.
    pub fn traversableViewport(self: *BrowsingContext) ?ViewportSize {
        const top = self.getTop();
        return top.viewport_override orelse top.viewport;
    }

    /// Check if two browsing contexts are same origin
    /// Per HTML Standard §7.5 - "Two origins are same origin if their schemes,
    /// hosts, and ports are identical"
    pub fn isSameOrigin(self: *const BrowsingContext, other: *const BrowsingContext) bool {
        return self.origin.isSameOrigin(other.origin);
    }

    /// Set the origin for this browsing context
    /// Called when navigating to a new document or when the document's origin changes
    pub fn setOrigin(self: *BrowsingContext, origin_value: Origin) void {
        self.origin = origin_value;
    }

    /// Get the origin for this browsing context
    pub fn getOrigin(self: *const BrowsingContext) Origin {
        return self.origin;
    }

    /// Set the active document for this browsing context
    /// Per HTML §7.3.1: "A browsing context has an active document"
    ///
    /// This method atomically updates both the active document and associated window.
    /// It should be called during document creation and navigation.
    ///
    /// Parameters:
    /// - doc: The Document instance to set as active (runtime.Instance pointer)
    /// - window: The associated Window instance (runtime.Instance pointer)
    pub fn setActiveDocument(self: *BrowsingContext, doc: InstancePtr, window: InstancePtr) void {
        self.active_document = doc;
        self.active_window = window;
    }

    /// Set only the active window for this browsing context
    /// Per HTML spec §7.3, every browsing context has an associated Window.
    /// This is called when creating a Window before the Document is ready.
    pub fn setActiveWindow(self: *BrowsingContext, window: InstancePtr) void {
        self.active_window = window;
    }

    /// Get the active document for this browsing context
    /// Returns null if no document has been loaded yet
    pub fn getActiveDocument(self: *const BrowsingContext) ?InstancePtr {
        return self.active_document;
    }

    /// Get the active window for this browsing context
    /// Returns null if no window has been created yet
    pub fn getActiveWindow(self: *const BrowsingContext) ?InstancePtr {
        return self.active_window;
    }

    /// Move this top-level context into a browsing context group of its own:
    /// HTML "the rules for choosing a navigable" step 8.7, a new top-level
    /// traversable made with noopener, is "created given null" opener - a
    /// new top-level browsing context, in a new group ("create a new
    /// top-level browsing context and document" step 1).
    pub fn startOwnGroup(self: *BrowsingContext) void {
        self.virtual_group_id = @atomicRmw(u64, &next_group_id, .Add, 1, .monotonic);
        self.virtual_browsing_context_group_id = newVirtualGroupId();
        // "Create a new browsing context group": its cross-origin isolation
        // mode is initially "none".
        self.cross_origin_isolation_mode = .none;
    }

    /// HTML "obtain a browsing context to use for a navigation response"
    /// steps 10-14, for this top-level context whose navigation needs a
    /// browsing context group switch. HTML makes a NEW top-level browsing
    /// context, in a new group, for the navigable; Crane's context is also
    /// the navigable (its session history, its traversal queue), so the
    /// navigable keeps this object and it becomes the new context: a new
    /// group (step 10), whose cross-origin isolation mode is `mode` (step
    /// 12: "logical" or "concrete" for a "same-origin-plus-COEP"
    /// navigation, else "none"), no opener, and the popup sandboxing flag
    /// set `sandbox_flags` (step 14). What reached the replaced context
    /// reaches it no longer: its WindowProxy is the caller's (the new
    /// document gets a new one), and every context it had opened loses
    /// its opener - the replaced context is not theirs to reach (Chromium
    /// drops the openee's proxy of a frame that swapped BrowsingInstance).
    /// The navigable's target name is cleared too: Chromium clears the
    /// frame name on a COOP BrowsingInstance swap
    /// (RenderFrameHostManager, ShouldClearWindowName), which COOP's tests
    /// expect (popup tests read "" in the new page); HTML clears it only
    /// for a cross-origin navigation ("apply the history step" 12.3).
    pub fn switchGroup(self: *BrowsingContext, mode: CrossOriginIsolationMode, sandbox_flags: SandboxingFlagSet) void {
        self.startOwnGroup();
        self.cross_origin_isolation_mode = mode;
        self.opener = null;
        self.popup_sandboxing_flags = sandbox_flags;
        if (self.target_name.len > 0) self.allocator.free(self.target_name);
        self.target_name = "";
        if (self.navigables) |navigables| {
            for (navigables.contexts()) |other| {
                // Disowned, not only unlinked: Window's opener getter reads
                // `disowned` before the opener Window it kept from open(),
                // which would still answer the old Window.
                if (other != self and other.opener == self) other.disown();
            }
        }
    }

    /// HTML "obtain a browsing context to use for a navigation response"
    /// step 9.1, for this top-level context, which keeps its group: "If
    /// coopEnforcementResult's would need a browsing context group switch due
    /// to report-only is true, set browsingContext's virtual browsing context
    /// group ID to a new unique identifier."
    pub fn startVirtualGroup(self: *BrowsingContext) void {
        self.virtual_browsing_context_group_id = newVirtualGroupId();
    }

    /// HTML "enforce a response's opener policy" steps 4.2 and 5.2: whether
    /// "browsingContext's group's browsing context set's size is greater
    /// than 1" - another live top-level context (the set holds top-level
    /// ones only) is in this context's group. Chromium's EnforceCOOP asks
    /// the same (has_other_window_in_browsing_context_group).
    pub fn groupHoldsOthers(self: *const BrowsingContext) bool {
        const navigables = self.navigables orelse return false;
        for (navigables.contexts()) |other| {
            if (other == self or other.parent != null or other.is_closed) continue;
            if (other.virtual_group_id == self.virtual_group_id) return true;
        }
        return false;
    }

    /// Whether this context's group is cross-origin isolated ("logical" or
    /// "concrete"): its agent clusters are origin-keyed ("obtain a
    /// similar-origin window agent" step 3). Not the cross-origin isolated
    /// capability, which only "concrete" grants and the Window decides.
    pub fn groupIsCrossOriginIsolated(self: *const BrowsingContext) bool {
        return self.cross_origin_isolation_mode != .none;
    }

    /// Check if two browsing contexts are in the same browsing context group
    pub fn isInSameGroup(self: *const BrowsingContext, other: *const BrowsingContext) bool {
        return self.virtual_group_id == other.virtual_group_id;
    }

    /// Check if this context is familiar with another (§7.1)
    pub fn isFamiliarWith(self: *const BrowsingContext, other: *const BrowsingContext) bool {
        // Per spec: familiar if:
        // - related browsing contexts, or
        // - both top-level with related groups, or
        // - in same unit of related similar-origin browsing contexts

        // Check if they share the same top-level traversable
        if (self.isInSameGroup(other)) {
            return true;
        }

        // Check opener chain
        var ctx: ?*const BrowsingContext = self;
        while (ctx) |c| {
            if (c == other) return true;
            ctx = c.opener;
        }

        ctx = other;
        while (ctx) |c| {
            if (c == self) return true;
            ctx = c.opener;
        }

        return false;
    }

    /// Close this browsing context
    pub fn close(self: *BrowsingContext) void {
        // A top-level traversable closing: its documents were unloaded and
        // destroyed before ("close a top-level traversable" -> "destroy a
        // top-level traversable"), so the Browser's navigation observer
        // hears it is gone now, once. (A child navigable's end is told by
        // "destroy a child navigable", dom.navigables.)
        if (self.parent == null and !self.is_closed) {
            @import("../navigation/observer.zig").notify(self.navigables, .{ .navigable_id = self.id, .event = .navigable_destroyed });
        }
        self.is_closed = true;

        // Disown the opener relationship
        self.disowned = true;

        // Close all children
        for (self.children.items) |child| {
            child.close();
        }
    }

    /// Disown the opener relationship (noopener)
    pub fn disown(self: *BrowsingContext) void {
        self.disowned = true;
        self.opener = null;
    }

    /// Set the target name
    pub fn setTargetName(self: *BrowsingContext, name: []const u8) !void {
        if (self.target_name.len > 0) {
            self.allocator.free(self.target_name);
        }
        self.target_name = try self.allocator.dupe(u8, name);
    }

    /// Get the number of child browsing contexts
    pub fn getChildCount(self: *const BrowsingContext) u32 {
        return @intCast(self.children.items.len);
    }

    /// Get a child browsing context by index
    pub fn getChildByIndex(self: *const BrowsingContext, index: u32) ?*BrowsingContext {
        if (index >= self.children.items.len) return null;
        return self.children.items[index];
    }

    /// Find a browsing context by target name
    pub fn findByTargetName(self: *BrowsingContext, name: []const u8) ?*BrowsingContext {
        // Check self
        if (std.mem.eql(u8, self.target_name, name)) {
            return self;
        }

        // Check children recursively
        for (self.children.items) |child| {
            if (child.findByTargetName(name)) |found| {
                return found;
            }
        }

        return null;
    }
};

/// Browsing context group - manages a group of related browsing contexts
pub const BrowsingContextGroup = struct {
    allocator: Allocator,
    id: u64,
    contexts: infra.List(*BrowsingContext),

    /// Create a new browsing context group
    pub fn init(allocator: Allocator) !*BrowsingContextGroup {
        const group = try allocator.create(BrowsingContextGroup);
        group.* = .{
            .allocator = allocator,
            .id = @atomicRmw(u64, &next_group_id, .Add, 1, .monotonic),
            .contexts = infra.List(*BrowsingContext).init(allocator),
        };
        return group;
    }

    /// Add a browsing context to this group
    pub fn addContext(self: *BrowsingContextGroup, ctx: *BrowsingContext) !void {
        ctx.virtual_group_id = self.id;
        try self.contexts.append(ctx);
    }

    /// Remove a browsing context from this group
    pub fn removeContext(self: *BrowsingContextGroup, ctx: *BrowsingContext) void {
        for (self.contexts.items, 0..) |c, i| {
            if (c == ctx) {
                _ = self.contexts.orderedRemove(i);
                break;
            }
        }
    }

    /// Deinitialize and free resources
    pub fn deinit(self: *BrowsingContextGroup) void {
        self.contexts.deinit();
        self.allocator.destroy(self);
    }

    /// Get the number of contexts in this group
    pub fn getSize(self: *const BrowsingContextGroup) usize {
        return self.contexts.size();
    }
};

test "BrowsingContext - init and deinit" {
    const allocator = std.testing.allocator;
    var navigables = Navigables.init(allocator);
    defer navigables.deinit();

    const ctx = try BrowsingContext.init(allocator, &navigables);
    defer ctx.deinit();

    try std.testing.expect(ctx.opener == null);
    try std.testing.expect(!ctx.disowned);
    try std.testing.expect(!ctx.is_popup);
    try std.testing.expect(!ctx.is_closed);
}

test "BrowsingContext - top-level creation" {
    const allocator = std.testing.allocator;
    var navigables = Navigables.init(allocator);
    defer navigables.deinit();

    const ctx = try BrowsingContext.initTopLevel(allocator, &navigables);
    defer ctx.deinit();

    try std.testing.expect(ctx.isTopLevel());
    try std.testing.expect(!ctx.isChild());
    try std.testing.expect(ctx.virtual_group_id > 0);
}

test "BrowsingContext - child creation" {
    const allocator = std.testing.allocator;
    var navigables = Navigables.init(allocator);
    defer navigables.deinit();

    const parent = try BrowsingContext.initTopLevel(allocator, &navigables);
    defer parent.deinit();

    const child = try BrowsingContext.initChild(allocator, parent);
    // child is freed by parent.deinit()

    try std.testing.expect(child.isChild());
    try std.testing.expect(!child.isTopLevel());
    try std.testing.expect(child.parent == parent);
    try std.testing.expectEqual(@as(u32, 1), parent.getChildCount());
}

test "BrowsingContext - auxiliary creation" {
    const allocator = std.testing.allocator;
    var navigables = Navigables.init(allocator);
    defer navigables.deinit();

    const opener = try BrowsingContext.initTopLevel(allocator, &navigables);
    defer opener.deinit();

    const popup = try BrowsingContext.initAuxiliary(allocator, opener, true);
    defer popup.deinit();

    try std.testing.expect(popup.opener == opener);
    try std.testing.expect(popup.is_popup);
    try std.testing.expect(popup.isTopLevel());
}

test "BrowsingContext - getTop" {
    const allocator = std.testing.allocator;
    var navigables = Navigables.init(allocator);
    defer navigables.deinit();

    const top = try BrowsingContext.initTopLevel(allocator, &navigables);
    defer top.deinit();

    const child1 = try BrowsingContext.initChild(allocator, top);
    const child2 = try BrowsingContext.initChild(allocator, child1);

    try std.testing.expect(top.getTop() == top);
    try std.testing.expect(child1.getTop() == top);
    try std.testing.expect(child2.getTop() == top);
}

test "BrowsingContext - target name" {
    const allocator = std.testing.allocator;
    var navigables = Navigables.init(allocator);
    defer navigables.deinit();

    const ctx = try BrowsingContext.init(allocator, &navigables);
    defer ctx.deinit();

    try ctx.setTargetName("myframe");
    try std.testing.expectEqualStrings("myframe", ctx.target_name);
}

test "BrowsingContext - close" {
    const allocator = std.testing.allocator;
    var navigables = Navigables.init(allocator);
    defer navigables.deinit();

    const ctx = try BrowsingContext.init(allocator, &navigables);
    defer ctx.deinit();

    try std.testing.expect(!ctx.is_closed);
    ctx.close();
    try std.testing.expect(ctx.is_closed);
    try std.testing.expect(ctx.disowned);
}

test "BrowsingContext - disown severs opener relationship" {
    const allocator = std.testing.allocator;
    var navigables = Navigables.init(allocator);
    defer navigables.deinit();

    // Create opener and popup
    const opener = try BrowsingContext.initTopLevel(allocator, &navigables);
    defer opener.deinit();

    const popup = try BrowsingContext.initAuxiliary(allocator, opener, true);
    defer popup.deinit();

    // Verify opener is set
    try std.testing.expect(popup.opener == opener);
    try std.testing.expect(!popup.disowned);

    // Disown - this simulates window.opener = null
    popup.disown();

    // Verify relationship is severed
    try std.testing.expect(popup.opener == null);
    try std.testing.expect(popup.disowned);
}

test "BrowsingContext - auxiliary with noopener starts disowned" {
    const allocator = std.testing.allocator;
    var navigables = Navigables.init(allocator);
    defer navigables.deinit();

    // Create opener
    const opener = try BrowsingContext.initTopLevel(allocator, &navigables);
    defer opener.deinit();

    // Simulate noopener: create auxiliary but immediately disown
    const popup = try BrowsingContext.initAuxiliary(allocator, opener, true);
    defer popup.deinit();
    popup.disown(); // noopener semantics

    // The popup should have no accessible opener
    try std.testing.expect(popup.opener == null);
    try std.testing.expect(popup.disowned);
}

test "BrowsingContextGroup - basic operations" {
    const allocator = std.testing.allocator;
    var navigables = Navigables.init(allocator);
    defer navigables.deinit();

    const group = try BrowsingContextGroup.init(allocator);
    defer group.deinit();

    const ctx1 = try BrowsingContext.init(allocator, &navigables);
    defer ctx1.deinit();

    const ctx2 = try BrowsingContext.init(allocator, &navigables);
    defer ctx2.deinit();

    try group.addContext(ctx1);
    try group.addContext(ctx2);

    try std.testing.expectEqual(@as(usize, 2), group.getSize());
    try std.testing.expect(ctx1.isInSameGroup(ctx2));
}

// ============================================================================
// Sandboxing Tests
// ============================================================================

test "BrowsingContext - a new context has an empty popup sandboxing flag set and no permitted navigator" {
    const allocator = std.testing.allocator;
    var navigables = Navigables.init(allocator);
    defer navigables.deinit();

    const ctx = try BrowsingContext.init(allocator, &navigables);
    defer ctx.deinit();
    try std.testing.expect(ctx.popup_sandboxing_flags.isEmpty());
    try std.testing.expect(ctx.one_permitted_sandboxed_navigator == null);

    const child = try BrowsingContext.initChild(allocator, ctx);
    defer child.deinit();
    try std.testing.expect(child.popup_sandboxing_flags.isEmpty());
}
