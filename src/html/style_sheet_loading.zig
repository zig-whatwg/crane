//! A style sheet's load, with its critical subresources.
//!
//! Shared by the two elements that own style sheets - and by a link
//! element's preload (4.6.7.20), which is the same fetch without the sheet. A `link` element's
//! sheet is fetched first - HTML 4.2.4.3 "fetch and process the linked
//! resource", with the stylesheet link type's "process the linked resource"
//! (4.6.7.23) - and a `style` element's is its text (4.2.6 "update a style
//! block"). Either way the sheet's @import rules are its critical
//! subresources: each is fetched as CSS Cascade's "fetch an @import" does,
//! and the imported sheets' own @import rules after them, recursively.
//!
//! When every fetch has ended, a task fires `load` at the element if all of
//! them succeeded, or `error` if any failed: a network error, a status that
//! is not ok, or a Content-Type that is not text/css (in quirks mode, a
//! CORS-same-origin response is taken as text/css whatever it says). The
//! task is an element task on the networking task source (4.2.6 step 4;
//! for a link, "process the linked resource" runs in the fetch's task).
//! Until it has run, the load delays the element's node document's load
//! event (`dom.style_sheet_owners`), and keeps the element alive.
//!
//! Each sheet a load fetches successfully - a link's own, an @import's - is
//! handed to the style engine (`dom.style.deliverSheet`), which makes it
//! the link's CSS style sheet or attaches it to its @import rule (lane
//! style1); the loads here only fetch, and read @import rules
//! (`css.import_rules`) to know what to fetch.
//!
//! Deviations, stated:
//! - The status checked is the response's own, not its filtered status: an
//!   opaque filtered response - every cross-origin no-cors sheet - has
//!   status 0, which the letter of 4.2.4.3 step 7.2 would turn into an error
//!   for every such sheet. Browsers read the real status (Blink fails a
//!   subresource on a status of 400 or more), and so does this.
//! - An import that would fetch a sheet already on its chain of parents is
//!   skipped (a cycle), as is one more than 16 levels deep.
//!
//! Spec: https://html.spec.whatwg.org/multipage/semantics.html#fetching-and-processing-a-resource-from-a-link-element
//! Spec: https://html.spec.whatwg.org/multipage/links.html#link-type-stylesheet
//! Spec: https://html.spec.whatwg.org/multipage/semantics.html#update-a-style-block
//! Spec: https://drafts.csswg.org/css-cascade-5/#fetch-an-import

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const engine = @import("engine");
const fetch = @import("fetch");
const css = @import("css");
const dom = @import("dom");

const AsyncFetch = fetch.algorithms.AsyncFetch;
// modulepreload: the document's module loader.
const module_script = @import("module_script.zig");
const script_execution = @import("script_execution.zig");

const log = std.log.scoped(.style_sheets);

/// A CORS settings attribute's state (HTML 2.5.4).
pub const CorsSetting = enum {
    no_cors,
    anonymous,
    use_credentials,

    /// A crossorigin attribute's state: "The attribute's missing value
    /// default is the No CORS state, and its invalid value default is the
    /// Anonymous state."
    pub fn fromAttribute(value: ?[]const u8) CorsSetting {
        const v = value orelse return .no_cors;
        if (std.ascii.eqlIgnoreCase(v, "use-credentials")) return .use_credentials;
        return .anonymous;
    }
};

/// What a link element's request takes from its link processing options.
pub const LinkOptions = struct {
    /// The element was created by its node document's parser (implicitly
    /// potentially render-blocking, for a stylesheet link).
    parser_created: bool = false,
    /// The href attribute's value.
    href: []const u8,
    cors: CorsSetting = .no_cors,
    /// The referrerpolicy attribute's state; `.empty` for none.
    referrer_policy: fetch.internal.ReferrerPolicy = .empty,
    nonce: []const u8 = "",
    integrity: []const u8 = "",
    fetch_priority: fetch.internal.request.Priority = .auto,
};

/// Imports deeper than this are not fetched.
const max_import_depth = 16;

/// What a load fetches.
const Kind = enum {
    /// A link element's style sheet, then its critical subresources.
    stylesheet,
    /// A style element's style sheet's critical subresources.
    style,
    /// A link element's preload: the one resource, no subresources, and no
    /// delay on the document's load event.
    preload,
    /// HTML 4.6.8.19: a speculative fetch, with no load-event delay.
    prefetch,
    /// A link element's modulepreload: one module script, fetched "cors",
    /// failing on a MIME type that is not JavaScript; no delay on the
    /// document's load event either.
    modulepreload,
    /// A top-level document's icon: image fetch only, no link event or
    /// document load delay, no decoding and no stylesheet processing.
    icon,
};

const Load = struct {
    id: u64,
    kind: Kind,
    allocator: std.mem.Allocator,
    element: *runtime.Instance,
    element_generation: u64,
    document: *runtime.Instance,
    document_generation: u64,
    /// The element's realm: its settings object is the requests' client,
    /// and a realm that has ended terminates the fetches.
    realm: runtime.Context,
    /// The node document is in quirks mode.
    quirks: bool,
    /// Every sheet this load has fetched or is fetching.
    sheets: std.ArrayListUnmanaged(*Sheet) = .empty,
    /// Fetches not yet answered.
    in_flight: u32 = 0,
    /// A modulepreload's module fetch, through the document's module
    /// loader, is one of them (`ModulePreload`).
    module_in_flight: bool = false,
    /// A fetch failed: the event is `error`.
    failed: bool = false,
    /// The event's task is queued.
    event_queued: bool = false,
    /// The queued event task's counted reference on the element, beside the
    /// element's shared keep, from queueing to the task's end: refcount step
    /// 5d's GCReachableRef in shadow mode (WebKit keeps a node a queued task
    /// will fire at with queueTaskKeepingThisNodeAlive).
    event_ref: dom.node_holds.CountedRef = .{},
    /// The event is not to fire: the element fetches again (a link whose
    /// href changed), or is gone. The queued task only ends the load.
    superseded: bool = false,
    document_abort_pending: bool = false,
    /// The load put its element in its node document's render-blocking
    /// element set (HTML 4.2.6 step 6 for a style element, 4.6.7.23 for a
    /// stylesheet link): it takes the element out when it ends.
    render_blocking: bool = false,
    /// Request metadata captured before the first fetch. Imports inherit it
    /// even if attributes or actual document membership subsequently change.
    fetch_render_blocking: bool = false,
    /// Static eligibility for the node document's script-blocking style
    /// sheet set: enabled at parser creation. Root and media are current
    /// conditions, checked by blocksScripts. Completion, cancellation and
    /// removal end eligibility with the load.
    blocks_scripts: bool = false,

    fn elementIsLive(self: *const Load) bool {
        return runtime.SlabAllocator.generationOf(self.element) == self.element_generation;
    }

    fn documentIsLive(self: *const Load) bool {
        return runtime.SlabAllocator.generationOf(self.document) == self.document_generation;
    }
};

/// One sheet's fetch: the link's own, or an @import's.
const Sheet = struct {
    load: *Load,
    /// The request's URL. OWNED.
    url: []u8,
    /// The sheet whose @import rule this is; null for the link's own sheet.
    parent: ?*Sheet,
    depth: usize,
    /// HTML's create-a-CSS-style-sheet origin-clean flag, set from the
    /// fetched response before this sheet's imports start.
    origin_clean: bool = false,
    /// For an @import's sheet: the rule's index among its sheet's @import
    /// rules (`css.import_rules` order, which the style engine counts too).
    import_index: u16 = 0,
    /// Once fetched: the sheet's location (its response's URL, OWNED) and the
    /// referrer policy its response's Referrer-Policy header gave - the
    /// referrer and policy its own @imports are fetched with.
    location: ?[]u8 = null,
    referrer_policy: fetch.internal.ReferrerPolicy = .empty,
    /// While the fetch runs.
    fetch: ?*AsyncFetch = null,

    fn client(self: *Sheet) AsyncFetch.Client {
        return .{ .context = self, .done = fetchDone, .alive = fetchAlive, .gone = fetchGone };
    }

    /// Whether a sheet on this one's chain of parents - or this one - has
    /// `url`.
    fn chainHas(self: *const Sheet, url: []const u8) bool {
        var sheet: ?*const Sheet = self;
        while (sheet) |s| : (sheet = s.parent) {
            if (std.mem.eql(u8, s.url, url)) return true;
        }
        return false;
    }
};

/// Every load on this thread whose event has not yet fired. Never freed:
/// it lives as long as the thread, as the fetches' own list does.
threadlocal var loads: std.ArrayListUnmanaged(*Load) = .empty;
threadlocal var next_id: u64 = 1;

// ============================================================================
// The owners' interface
// ============================================================================

/// `dom.style_sheet_owners`: whether a load for an element in `document`
/// has not yet fired its event.
pub fn delaysLoadEvent(document: *runtime.Instance) bool {
    for (loads.items) |load| {
        // "A user agent must not delay the load event for this link type"
        // - preload and modulepreload. Prefetch also does not block in
        // browsers, despite HTML 4.2.4.3's default delay rule: Gecko fetches
        // it with LOAD_BACKGROUND (nsPrefetchNode::OpenChannel). WPT
        // preload/prefetch-load-event.html is 1/1 in Chrome 154, Firefox 157
        // and Safari 27 at cc74d2669f (Safari does not fetch prefetch).
        // Icons do not delay page load in browsers, despite HTML
        // 4.2.4.3's default delay rule: Chromium UpdateFaviconURL waits
        // until LoadEventFinished; Gecko FaviconLoad uses LOAD_BACKGROUND;
        // WebKit IconLoader uses the separate requestIcon loader.
        if (load.kind == .preload or load.kind == .modulepreload or load.kind == .prefetch or load.kind == .icon) continue;
        if (!load.superseded and load.document == document and load.documentIsLive()) return true;
    }
    return false;
}

/// HTML 4.2.7: this document's own script-blocking style sheet set. A load
/// stays in the set through its load/error event, including critical imports.
/// Superseded or abandoned sheets count as given up, and no longer block.
pub fn blocksScripts(document: *runtime.Instance) bool {
    for (loads.items) |load| {
        if (!load.blocks_scripts or load.superseded or load.document != document or !load.documentIsLive() or !load.elementIsLive()) continue;
        if (connectedToDocument(load.element, document) and mediaMatches(load.element)) return true;
    }
    return false;
}

fn connectedToDocument(element: *runtime.Instance, document: *runtime.Instance) bool {
    // A connected shadow-tree sheet does not have the document as its root.
    return (interfaces.Node.call_getRootNode(element, webidl.Opt(dictionaries.GetRootNodeOptions).notPassed()) catch return false) == document;
}

/// Whether the element's media attribute matches its document's
/// environment.
fn mediaMatches(element: *runtime.Instance) bool {
    const media = if (element.stateAs(interfaces.ProcessingInstruction.State) != null)
        interfaces.ProcessingInstruction.call_getAttribute(element, runtime.DOMString.initInterned("media")) catch null
    else
        interfaces.Element.call_getAttributeNS(element, null, runtime.DOMString.initInterned("media")) catch null;
    defer if (media) |value| {
        var owned = value;
        owned.deinit(element.ctx.allocator);
    };
    const text = if (media) |value| value.asSlice() else "";
    // HTML 4.2.7 "contributes a script-blocking style sheet": "el's media
    // attribute's value matches the environment" - Media Queries 5 against
    // the node document's environment (dom.style; lane style1).
    const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return true;
    const values = dom.style.hooks.mediaValues(document);
    return css.media_queries.MediaQueryList.matchesQuery(element.ctx.allocator, text, &values) catch true;
}

/// Wake a document waiting on stylesheets and its immediate child documents,
/// whose readiness also checks this document's set (HTML 4.2.7 steps 3-4).
/// Snapshot and pin all children before running any script. Each callback
/// can destroy a sibling frame or replace its active document.
pub fn blockingMayHaveEnded(document: *runtime.Instance) void {
    const realm = document.ctx;
    const generation = runtime.SlabAllocator.generationOf(document);
    const parent_pin: ?engine.Owned = if (realm.hasEngine()) engine.retainValue(realm, .{ .instance = document }) catch return else null;
    defer if (parent_pin) |pin| pin.release();
    const allocator = realm.allocator;
    const Child = struct {
        document: *runtime.Instance,
        generation: u64,
        realm: runtime.Context,
        navigable_id: u64,
        pin: engine.Owned,
    };
    var snapshot: std.ArrayListUnmanaged(Child) = .empty;
    defer {
        for (snapshot.items) |child| child.pin.release();
        snapshot.deinit(allocator);
    }
    var children = dom.navigables.childNavigablesOf(document, allocator);
    defer children.deinit(allocator);
    for (children.items) |child| {
        const child_document: *runtime.Instance = @ptrCast(@alignCast(child.browsing_context.getActiveDocument() orelse continue));
        if (!child_document.ctx.hasEngine()) continue;
        const pin = engine.retainValue(child_document.ctx, .{ .instance = child_document }) catch continue;
        snapshot.append(allocator, .{
            .document = child_document,
            .generation = runtime.SlabAllocator.generationOf(child_document),
            .realm = child_document.ctx,
            .navigable_id = child.browsing_context.id,
            .pin = pin,
        }) catch {
            pin.release();
            break;
        };
    }
    dom.document_lifecycle.loadDelayMayHaveEnded(document);
    for (snapshot.items) |child| {
        if (parent_pin != null and !realm.hasEngine()) return;
        if (runtime.SlabAllocator.generationOf(document) != generation) return;
        if (!child.realm.hasEngine() or runtime.SlabAllocator.generationOf(child.document) != child.generation) continue;
        const navigables = dom.browser_state.navigablesOf(realm) orelse return;
        const navigable = navigables.byId(child.navigable_id) orelse continue;
        if (navigable.orphaned or navigable.is_closed or navigable.getActiveDocument() != @as(?*anyopaque, @ptrCast(child.document))) continue;
        const window = (interfaces.Document.get_defaultView(child.document) catch null) orelse continue;
        const container = dom.navigable_container.of(window) orelse continue;
        if ((interfaces.Node.get_ownerDocument(container) catch null) != document) continue;
        dom.document_lifecycle.loadDelayMayHaveEnded(child.document);
    }
}

/// A mutation may remove a blocker while ordinary JavaScript is still
/// running. The pending parser resumes from a task after that script returns,
/// rather than nested inside an attribute setter or removal operation.
pub fn queueBlockingMayHaveEnded(document: *runtime.Instance) void {
    const realm = document.ctx;
    const loop = realm.getOptionalEventLoop() orelse return blockingMayHaveEnded(document);
    if (!realm.hasEngine()) return;
    const allocator = realm.allocator;
    const task = allocator.create(BlockingWake) catch return;
    const pin = engine.retainValue(realm, .{ .instance = document }) catch {
        allocator.destroy(task);
        return;
    };
    task.* = .{
        .document = document,
        .generation = runtime.SlabAllocator.generationOf(document),
        .realm = realm,
        .allocator = allocator,
        .pin = pin,
    };
    loop.queueTask(.{ .callback = &BlockingWake.run, .context = task, .drop = &BlockingWake.drop, .document = document, .document_generation = task.generation });
}

const BlockingWake = struct {
    document: *runtime.Instance,
    generation: u64,
    realm: runtime.Context,
    allocator: std.mem.Allocator,
    pin: engine.Owned,

    fn run(context: ?*anyopaque) void {
        const self: *@This() = @ptrCast(@alignCast(context orelse return));
        defer self.destroy();
        if (!self.realm.hasEngine() or runtime.SlabAllocator.generationOf(self.document) != self.generation) return;
        blockingMayHaveEnded(self.document);
    }

    fn drop(context: ?*anyopaque) void {
        const self: *@This() = @ptrCast(@alignCast(context orelse return));
        self.destroy();
    }

    fn destroy(self: *@This()) void {
        self.pin.release();
        self.allocator.destroy(self);
    }
};

/// The element owner installs this shared loader's cancellation hooks once.
pub fn installDocumentAbort() void {
    dom.document_fetches.install(.{ .discard = discardRealm, .prepare_abort = prepareDocumentAbort, .abort = abortDocument });
}
fn prepareDocumentAbort(document: *runtime.Instance) bool {
    var canceled = false;
    for (loads.items) |load| {
        if (load.superseded or load.document != document or !load.documentIsLive()) continue;
        if (load.in_flight == 0 and !load.event_queued) continue;
        load.document_abort_pending = true;
        canceled = true;
    }
    return canceled;
}
fn abortDocument(document: *runtime.Instance) void {
    while (true) {
        const load: *Load = blk: {
            for (loads.items) |candidate| {
                if (candidate.document_abort_pending and candidate.document == document and candidate.documentIsLive()) break :blk candidate;
            }
            return;
        };
        load.document_abort_pending = false;
        // Abort owns parser readiness from here: releasing its last sheet
        // must not execute the script the document is about to discard.
        terminateFetches(load);
        load.blocks_scripts = false;
        if (load.event_queued) load.superseded = true else release(load, .teardown);
    }
}
fn discardRealm(realm: runtime.Context) void {
    var index: usize = 0;
    while (index < loads.items.len) {
        const load = loads.items[index];
        if (load.realm != realm) {
            index += 1;
            continue;
        }
        load.document_abort_pending = false;
        terminateFetches(load);
        if (load.event_queued) {
            load.superseded = true;
            index += 1;
        } else release(load, .teardown);
    }
}

/// HTML "default fetch and process the linked resource" for `element`, a
/// link element whose stylesheet link is to be fetched: create a link
/// request from its options, fetch it, and then its critical subresources.
/// The load's id, or null when there is nothing to fetch ("If request is
/// null, then return": the href does not parse) - and then no event fires.
pub fn startLink(element: *runtime.Instance, options: LinkOptions, parser_sheet_enabled: bool) ?u64 {
    // "Create a link request", step 1: "Assert: options's href is not the
    // empty string" - the caller returns before an empty one.
    const id = startLinkFetch(element, .stylesheet, options, .style) orelse return null;
    const load = find(id) orelse return null;
    load.blocks_scripts = parser_sheet_enabled;
    // The stylesheet link type's linked resource fetch setup steps, step 4:
    // "If el is potentially render-blocking, then block rendering on el" -
    // a link the parser made is implicitly so (4.6.7.23).
    blockRenderingFor(load, options.parser_created);
    return id;
}

/// HTML "block rendering" on the load's element when it is potentially
/// render-blocking - its blocking attribute has `render`, or it is
/// implicitly so (`parser_created`) - and its media matches the
/// environment (4.2.6 step 6's condition, the same for a link).
fn blockRenderingFor(load: *Load, parser_created: bool) void {
    if (!potentiallyRenderBlocking(load.element, parser_created)) return;
    if (!mediaMatches(load.element)) return;
    dom.document_rendering.block(load.element) catch return;
    load.render_blocking = dom.document_rendering.contains(load.document, load.element);
}

/// HTML stylesheet fetch setup steps 3-4 / update a style block step 6,
/// and CSS Values "fetch a style resource" step 4's inherited metadata.
/// Chrome alone ships renderBlockingStatus. Blink's
/// core/css/pending_sheet_type.cc classifies critical parser sheets outside
/// body as blocking, and dynamic sheets by their explicit render token;
/// LinkStyle additionally excludes alternate sheets. This is request
/// metadata, independent of the document's current blocking-element set.
fn fetchRenderBlocking(load: *Load, parser_created: bool) bool {
    if (!mediaMatches(load.element)) return false;
    if (load.kind == .stylesheet) {
        const rel = interfaces.Element.call_getAttributeNS(load.element, null, runtime.DOMString.initInterned("rel")) catch null;
        if (rel) |value| {
            var tokens = std.mem.tokenizeAny(u8, value.asSlice(), "\t\n\x0C\r ");
            while (tokens.next()) |token| {
                if (std.ascii.eqlIgnoreCase(token, "alternate")) return false;
            }
        }
    }
    if (parser_created) {
        const body = interfaces.Document.get_body(load.document) catch null;
        if (body) |element| {
            if (interfaces.Node.call_contains(element, load.element) catch false) return false;
        }
        return true;
    }
    return potentiallyRenderBlocking(load.element, false);
}

/// HTML 2.5.8 "potentially render-blocking": the blocking tokens set holds
/// "render", or the element is implicitly potentially render-blocking.
pub fn potentiallyRenderBlocking(element: *runtime.Instance, implicitly: bool) bool {
    if (implicitly) return true;
    const blocking = interfaces.Element.call_getAttributeNS(element, null, runtime.DOMString.initInterned("blocking")) catch null;
    return dom.document_rendering.hasRenderToken(if (blocking) |b| b.asSlice() else "");
}

/// "Unblock rendering" on the load's element, if it blocked it.
fn unblockRenderingFor(load: *Load) void {
    if (!load.render_blocking) return;
    load.render_blocking = false;
    if (load.elementIsLive() and load.documentIsLive()) dom.document_rendering.remove(load.document, load.element);
}

/// HTML "fetch and process the linked resource" for `element`, a link
/// element whose preload link is to be fetched, `destination` its `as`
/// attribute's state translated ("translate a preload destination"): the
/// preload steps' fetch, then `error` at the element for a network error and
/// `load` otherwise. The load's id, or null when nothing is fetched.
///
/// Not modelled, stated: the document's map of preloaded resources, which a
/// later fetch of the same resource would consume instead of the network.
/// A preload fetches, and fires its event; the fetch that would have used it
/// goes to the network again.
pub fn startPreload(element: *runtime.Instance, options: LinkOptions, destination: fetch.internal.Destination) ?u64 {
    return startLinkFetch(element, .preload, options, destination);
}

/// HTML 4.6.8.19 steps 2-7: a link request with the empty destination,
/// prefetch initiator and the element's CORS settings. The existing Load
/// owns the fetch and its eventual load/error event.
pub fn startPrefetch(element: *runtime.Instance, options: LinkOptions) ?u64 {
    return startLinkFetch(element, .prefetch, options, .empty);
}

/// HTML 4.6.8.9 "icon", linked resource fetch setup steps 1-2: image
/// destination. The existing link fetch carries the policy container,
/// referrer and credentials through Fetch; the Load owns its lifetime.
/// The caller limits icons to top-level documents, as browsers do.
pub fn startIcon(element: *runtime.Instance, options: LinkOptions) ?u64 {
    if (!mediaMatches(element)) return null;
    return startLinkFetch(element, .icon, options, .image);
}

/// HTML "fetch and process the linked resource" for `element`, a link
/// element whose modulepreload link is to be fetched, `destination` its `as`
/// attribute's state ("script" when it has none): step 3, a destination
/// that is not a module preload destination fires `error` from a task;
/// otherwise step 14, "fetch a modulepreload module script graph" - "fetch
/// a single module script" into the node document's module map, through its
/// module loader (script_execution.fetchModulePreload) - then `error` if
/// there is no module script, `load` if there is (a module that fails to
/// parse is a module script, with a parse error). A later import of the URL
/// takes the module from the map, or joins its fetch.
///
/// Not done, stated: step 1.3's optional "fetch the descendants of and
/// link" - the script's own imports.
pub fn startModulePreload(element: *runtime.Instance, options: LinkOptions, destination: fetch.internal.Destination) ?u64 {
    const load = newLoad(element, .modulepreload) orelse return null;
    // `complete` and `release` can free the load.
    const id = load.id;
    // Step 3: "A module preload destination is "json", "style", "text", or
    // a script-like destination."
    if (!(destination.isScriptLike() or destination == .json or destination == .style or destination == .text)) {
        load.failed = true;
        complete(load);
        return id;
    }
    const document_allocator = load.document.ctx.allocator;
    // Steps 4-5: encoding-parse the href relative to the node document;
    // failure is no fetch.
    const base = interfaces.Node.get_baseURI(load.document) catch null;
    defer if (base) |b| document_allocator.free(b);
    const url = resolve(element, options.href, base) orelse {
        release(load, .settled);
        return null;
    };
    defer element.ctx.allocator.free(url);
    // Steps 7-13: the script fetch options - the crossorigin attribute's
    // CORS settings attribute credentials mode, the nonce, the integrity
    // (the import map's, for an absent attribute: the caller's), "not
    // parser-inserted", the referrer policy and the fetch priority.
    const module_options: module_script.FetchOptions = .{
        .nonce = options.nonce,
        .integrity = options.integrity,
        .parser_inserted = false,
        .referrer_policy = options.referrer_policy,
        .credentials_mode = if (options.cors == .use_credentials) .include else .same_origin,
        .fetch_priority = options.fetch_priority,
    };
    const preload = std.heap.c_allocator.create(ModulePreload) catch {
        load.failed = true;
        complete(load);
        return id;
    };
    preload.* = .{ .load_id = id };
    // The fetch counts as in flight from here: its client can run at once
    // (a task dropped by an ending loop).
    load.module_in_flight = true;
    load.in_flight += 1;
    if (!script_execution.fetchModulePreload(load.document, element, url, destination, module_options, preload.client())) {
        std.heap.c_allocator.destroy(preload);
        load.module_in_flight = false;
        load.in_flight -= 1;
        load.failed = true;
        complete(load);
    }
    return id;
}

/// A modulepreload's fetch, as its module loader's client. It names its load
/// by id rather than by address: a load that ended first - its element went,
/// or fetches again - is not found, and the fetch, which the module map
/// still takes, ends with no event (WebKit's ScriptModuleLoader clears a
/// loader's client the same way; Blink's ModuleMap keeps the fetch).
const ModulePreload = struct {
    load_id: u64,

    fn client(self: *ModulePreload) module_script.AsyncModuleLoader.Client {
        return .{ .context = self, .done = done, .gone = gone };
    }

    /// The load still waiting on this fetch, freeing `self`.
    fn take(context: *anyopaque) ?*Load {
        const self: *ModulePreload = @ptrCast(@alignCast(context));
        const id = self.load_id;
        std.heap.c_allocator.destroy(self);
        const load = find(id) orelse return null;
        if (!load.module_in_flight) return null;
        load.module_in_flight = false;
        load.in_flight -= 1;
        return load;
    }

    /// Step 14's onComplete: `error` for null, `load` for a module script.
    fn done(context: *anyopaque, result: ?*module_script.ModuleScript) void {
        const load = take(context) orelse return;
        if (result == null) load.failed = true;
        if (load.in_flight == 0 and !load.event_queued) complete(load);
    }

    /// The document or its realm is going away: no event.
    fn gone(context: *anyopaque) void {
        const load = take(context) orelse return;
        if (load.in_flight == 0 and !load.event_queued) release(load, .teardown);
    }
};

fn startLinkFetch(element: *runtime.Instance, kind: Kind, options: LinkOptions, destination: fetch.internal.Destination) ?u64 {
    const load = newLoad(element, kind) orelse return null;
    load.fetch_render_blocking = kind == .stylesheet and fetchRenderBlocking(load, options.parser_created);
    // `complete` can free the load: what is read after it is taken first.
    const id = load.id;
    const document_allocator = load.document.ctx.allocator;
    // Step 2: "Let url be the result of encoding-parsing a URL given
    // options's href, relative to options's base URL." Step 3: failure is
    // no request.
    const base = interfaces.Node.get_baseURI(load.document) catch null;
    defer if (base) |b| document_allocator.free(b);
    const url = resolve(element, options.href, base) orelse {
        release(load, .settled);
        return null;
    };
    defer element.ctx.allocator.free(url);
    startFetch(load, url, null, options, destination);
    if (load.in_flight == 0) complete(load);
    return id;
}

/// HTML "update a style block" step 6 onwards, for `element`, a style
/// element whose style sheet is `text`: fetch the sheet's critical
/// subresources, then fire its event. The load's id, or null when none
/// could start (no event fires).
pub fn startStyle(element: *runtime.Instance, text: []const u8, parser_created: bool) ?u64 {
    const load = newLoad(element, .style) orelse return null;
    load.fetch_render_blocking = fetchRenderBlocking(load, parser_created);
    // `complete` can free the load (a realm with no event loop releases it
    // at once): what is read after it is taken first.
    const id = load.id;
    const document_allocator = load.document.ctx.allocator;
    // The sheet's location is null: its imports resolve against the node
    // document's base URL (CSSOM "style sheet base URL").
    const base = interfaces.Node.get_baseURI(load.document) catch null;
    defer if (base) |b| document_allocator.free(b);
    fetchImports(load, null, text, base);
    // Without critical subresources the rules are immediately available
    // to script (HTML 4.2.7), even though the load event runs in a task.
    load.blocks_scripts = parser_created and load.in_flight > 0;
    // 4.2.6 step 6: "If element's media attribute's value matches the
    // environment and element is potentially render-blocking, then block
    // rendering on element" - a style element the parser made is implicitly
    // so.
    blockRenderingFor(load, parser_created);
    // "If the style sheet has no critical subresources, once the style sheet
    // has been parsed and processed": now.
    if (load.in_flight == 0) complete(load);
    return id;
}

/// A style element whose block Content Security Policy blocked ("update a
/// style block" step 5): no sheet is made, and the element fires `error`
/// as one whose sheet failed would. The load's id, or null when none could
/// start (no event fires).
///
/// Deviation, stated (golden rule 2, browser majority): HTML's step 5
/// returns with no event. Chrome and Safari fire `error` at a CSP-blocked
/// style element (WebKit d487138f2ba5, bug 246710, "Fire error event when
/// CSP blocks inline stylesheets"); Firefox fires it for a blocked `link`
/// only. WPT tests it: content-security-policy/style-src/
/// style-src-error-event-fires.html and style-src-inline-style-nonce-
/// blocked-error-event.html, Chrome 2/2, Firefox 1/2, Safari 2/2 at
/// wpt.fyi cc74d2669f. No whatwg/html issue asks for it.
pub fn startBlockedStyle(element: *runtime.Instance) ?u64 {
    const load = newLoad(element, .style) orelse return null;
    // `complete` can free the load.
    const id = load.id;
    load.failed = true;
    complete(load);
    return id;
}

/// The element fetches again, or no longer has a style sheet: the load `id`
/// ends, its fetches terminated, and its event does not fire - HTML
/// "process the linked resource" step 2, "if el no longer creates an
/// external resource link that contributes to the styling processing model,
/// or if, since the resource in question was fetched, it has become
/// appropriate to fetch it again".
pub fn cancel(id: u64) void {
    const load = find(id) orelse return;
    terminateFetches(load);
    if (load.event_queued) {
        load.superseded = true;
        if (load.documentIsLive()) queueBlockingMayHaveEnded(load.document);
        return;
    }
    release(load, .mutation);
}

/// A style element's sheet is removed ("update a style block" step 2): a
/// load still fetching the sheet's critical subresources ends with no event,
/// as the sheet has no element to fire it at any more. One whose event is
/// already queued still fires it: the task is in the queue.
pub fn abandon(id: u64) void {
    const load = find(id) orelse return;
    if (load.event_queued) {
        load.blocks_scripts = false;
        if (load.documentIsLive()) queueBlockingMayHaveEnded(load.document);
        return;
    }
    terminateFetches(load);
    release(load, .mutation);
}

/// `element` is being destroyed: every load it has ends.
pub fn elementGone(element: *runtime.Instance) void {
    var i: usize = 0;
    while (i < loads.items.len) {
        const load = loads.items[i];
        if (load.element != element or !load.elementIsLive()) {
            i += 1;
            continue;
        }
        terminateFetches(load);
        if (load.event_queued) {
            load.superseded = true;
            i += 1;
            continue;
        }
        release(load, .teardown);
    }
}

// ============================================================================
// Loads
// ============================================================================

fn newLoad(element: *runtime.Instance, kind: Kind) ?*Load {
    const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return null;
    const mode = interfaces.Document.get_compatMode(document) catch runtime.DOMString.initInterned("CSS1Compat");
    const allocator = element.ctx.allocator;
    const load = allocator.create(Load) catch return null;
    load.* = .{
        .id = next_id,
        .kind = kind,
        .allocator = allocator,
        .element = element,
        .element_generation = runtime.SlabAllocator.generationOf(element),
        .document = document,
        .document_generation = runtime.SlabAllocator.generationOf(document),
        .realm = element.ctx,
        .quirks = std.mem.eql(u8, mode.asSlice(), "BackCompat"),
    };
    loads.append(std.heap.smp_allocator, load) catch {
        allocator.destroy(load);
        return null;
    };
    next_id += 1;
    return load;
}

fn find(id: u64) ?*Load {
    for (loads.items) |load| {
        if (load.id == id) return load;
    }
    return null;
}

/// Terminate every fetch `load` has running. Their clients hear nothing
/// more. A modulepreload's module fetch runs on - the module map takes it -
/// but no longer counts for the load (`ModulePreload`).
fn terminateFetches(load: *Load) void {
    if (load.module_in_flight) {
        load.module_in_flight = false;
        load.in_flight -= 1;
    }
    for (load.sheets.items) |sheet| {
        if (sheet.fetch) |f| {
            sheet.fetch = null;
            f.terminate();
            load.in_flight -= 1;
        }
    }
}

/// How a load ends, which says whether its document is told.
const Ending = enum {
    /// The event fired, or the element ended the load: the document, which
    /// may be waiting for it at "the end" step 8, is told.
    settled,
    /// A mutation ended the load; resume only after its caller returns.
    mutation,
    /// The element, its realm or its event loop is going away: teardown,
    /// in which nothing is queued for the document any more.
    teardown,
};

/// `load` is over: it leaves the list, and - unless it ends in teardown -
/// its document is told.
fn release(load: *Load, ending: Ending) void {
    unblockRenderingFor(load);
    for (loads.items, 0..) |l, i| {
        if (l == load) {
            _ = loads.swapRemove(i);
            break;
        }
    }
    terminateFetches(load);
    for (load.sheets.items) |sheet| {
        load.allocator.free(sheet.url);
        if (sheet.location) |l| load.allocator.free(l);
        load.allocator.destroy(sheet);
    }
    load.sheets.deinit(load.allocator);
    const document = load.document;
    const document_live = load.documentIsLive();
    load.allocator.destroy(load);
    // Font Loading 3 §3.1: the pending request has left loads. Mark the
    // next rendering turn; preserve the stylesheet event/blocking order.
    if (document_live and ending != .teardown) dom.style.engine.resource_loading.fontEnvironmentChanged(document);
    if (document_live) switch (ending) {
        .settled => blockingMayHaveEnded(document),
        .mutation => queueBlockingMayHaveEnded(document),
        .teardown => {},
    };
}

/// Every fetch has ended: queue the task that fires the event.
fn complete(load: *Load) void {
    // HTML 4.2.4.3: icon has no "process the linked resource" algorithm,
    // so it does nothing. Browsers notify their favicon UI, not the link
    // element (WebKit IconLoader::notifyFinished, Blink LinkStyle::Process).
    if (load.kind == .icon) return release(load, .settled);
    // The style element's steps once its critical subresources are
    // obtained, and the link's "process the linked resource": "unblock
    // rendering on el".
    unblockRenderingFor(load);
    if (!load.elementIsLive() or load.realm.engine_ctx == null) return release(load, .teardown);
    const loop = load.element.ctx.getOptionalEventLoop() orelse {
        log.warn("style sheet load event not queued: the element's realm has no event loop", .{});
        return release(load, .settled);
    };
    // The queued task keeps the element alive: a link made by script,
    // inserted and dropped still fires. The hold is a flag, so it is taken
    // for an element's first waiting task and ended with its last.
    if (!otherEventQueued(load)) engine.keepPlatformObjectAlive(load.element);
    load.event_ref.take(load.element, dom.instance_bridge.getNodeBase(load.element));
    load.event_queued = true;
    loop.queueTask(.{ .callback = &runEventTask, .context = load, .drop = &dropEventTask });
}

/// Whether another load of `load`'s element has its event task queued.
fn otherEventQueued(load: *const Load) bool {
    for (loads.items) |other| {
        if (other != load and other.element == load.element and other.event_queued and other.elementIsLive()) return true;
    }
    return false;
}

/// The element task: fire `load` or `error` at the element.
fn runEventTask(data: ?*anyopaque) void {
    const load: *Load = @ptrCast(@alignCast(data orelse return));
    defer finishEventTask(load, .settled);
    if (load.superseded or !load.elementIsLive()) return;
    // A realm retired by a navigation runs none of its tasks.
    if (load.element.ctx.engine_ctx == null) return;
    // A task runs from the event loop, in no realm: it runs in the
    // element's.
    engine.runTaskInRealm(load.element.ctx, fireEventSteps, load) catch |err| {
        log.warn("style sheet {s} event not fired: {}", .{ eventType(load), err });
    };
}

/// `Task.drop`: the loop is ending with the task still queued.
fn dropEventTask(data: ?*anyopaque) void {
    const load: *Load = @ptrCast(@alignCast(data orelse return));
    finishEventTask(load, .teardown);
}

fn finishEventTask(load: *Load, ending: Ending) void {
    load.event_queued = false;
    if (load.elementIsLive() and !otherEventQueued(load)) engine.releasePlatformObject(load.element);
    load.event_ref.release(load.element);
    release(load, ending);
}

fn eventType(load: *const Load) []const u8 {
    return if (load.failed) "error" else "load";
}

/// "If success is true, fire an event named load at element. Otherwise,
/// fire an event named error at element."
fn fireEventSteps(data: ?*anyopaque) void {
    const load: *Load = @ptrCast(@alignCast(data orelse return));
    const element = load.element;
    const event = interfaces.Event.call_constructor(
        element.ctx,
        runtime.DOMString.initInterned(eventType(load)),
        webidl.Opt(dictionaries.EventInit).passed(.{}),
    ) catch |err| {
        log.warn("style sheet {s} event not made: {}", .{ eventType(load), err });
        return;
    };
    const generation = runtime.SlabAllocator.generationOf(event);
    // A listener that kept the event keeps it alive; otherwise it is done.
    defer event.releaseIfUnwrapped(generation);
    _ = dom.fire_event.dispatchTrusted(element, event) catch |err| blk: {
        log.warn("style sheet {s} event not dispatched: {}", .{ eventType(load), err });
        break :blk false;
    };
}

// ============================================================================
// Fetches
// ============================================================================

/// Fetch `url` for `load`: the link's own sheet when `parent` is null, an
/// @import of `parent` otherwise. A request that cannot start is a failure.
fn startFetch(load: *Load, url: []const u8, parent: ?*Sheet, options: LinkOptions, destination: fetch.internal.Destination) void {
    startFetchImport(load, url, parent, 0, options, destination);
}

fn startFetchImport(load: *Load, url: []const u8, parent: ?*Sheet, import_index: u16, options: LinkOptions, destination: fetch.internal.Destination) void {
    startFetchOrFail(load, url, parent, import_index, options, destination) catch |err| {
        log.debug("style sheet fetch of {s} not started: {}", .{ url, err });
        load.failed = true;
    };
}

fn startFetchOrFail(load: *Load, url: []const u8, parent: ?*Sheet, import_index: u16, options: LinkOptions, destination: fetch.internal.Destination) !void {
    const allocator = load.allocator;
    const cors = options.cors;
    const sheet = try allocator.create(Sheet);
    errdefer allocator.destroy(sheet);
    sheet.* = .{
        .load = load,
        .url = try allocator.dupe(u8, url),
        .parent = parent,
        .depth = if (parent) |p| p.depth + 1 else 0,
        .import_index = import_index,
    };
    errdefer allocator.free(sheet.url);

    // HTML "create a potential-CORS request" given url, "style" and the
    // CORS setting: "Let mode be "no-cors" if corsAttributeState is No CORS,
    // and "cors" otherwise. Let credentialsMode be "include"; if
    // corsAttributeState is Anonymous, "same-origin". A new request whose
    // URL is url, destination is destination, mode is mode, credentials mode
    // is credentialsMode, and whose use-URL-credentials flag is set." An
    // @import is fetched "no-cors", credentials "include" (CSS Values
    // "fetch a style resource", steps 3-4).
    const request = try fetch.internal.InternalRequest.init(allocator, url);
    var request_owned = true;
    defer if (request_owned) request.deinit();
    request.destination = destination;
    request.mode = if (cors == .no_cors) .no_cors else .cors;
    request.credentials_mode = if (cors == .anonymous) .same_origin else .include;
    request.use_url_credentials = true;
    request.render_blocking = load.fetch_render_blocking;
    // "Set request's referrer policy to options's referrer policy."
    request.referrer_policy = options.referrer_policy;
    // HTML "create a link request", steps 6-7 and 10: the link's integrity,
    // cryptographic nonce and fetch priority. CSS imports use defaults.
    try request.setIntegrityMetadata(options.integrity);
    if (options.nonce.len != 0) try request.setCryptographicNonceMetadata(options.nonce);
    request.priority = options.fetch_priority;
    // Resource Timing initiatorType: CSS imports (including an inline
    // style's first import) are "css"; link requests are "link" (a
    // modulepreload's too - its request is the module loader's,
    // module_script.AsyncModuleLoader.startModulePreload).
    // CSS Values 4 §4.5.4 step 7: an origin-dirty parent does not expose
    // its imported URLs through resource timing. Inline styles are clean.
    request.initiator_type = if (parent != null and !parent.?.origin_clean) null else if (parent != null or load.kind == .style) .css else .link;
    // Prefetch step 5. Fetch consumes this for CSP's union check.
    // It is distinct from Resource Timing's initiatorType.
    if (load.kind == .prefetch) request.initiator = .prefetch;
    // "Set request's client to options's environment": the element's
    // relevant settings object - its realm's global's.
    if (globalOf(load.realm)) |global| {
        var client = try dom.global_settings.requestClient(global);
        defer client.deinit();
        try fetch.internal.populateRequestFromClient(request, client.request);
    }

    // An @import of a fetched sheet: the sheet's URL is the referrer, and
    // its own Referrer-Policy header, if it had one, the policy. Golden rule
    // 2: CSS Values 4 "fetch a style resource" sets the referrer to
    // "client" for a no-cors request; Chrome and Firefox send the style
    // sheet's URL under the style sheet's policy (referrer-policy/
    // css-integration/child-css/external-import-stylesheet.html and
    // internal-import-stylesheet.html: Chrome 1/1, Firefox 1/1, Safari 0/1 at
    // wpt.fyi stable, df642c4142). A style element's own imports stay the
    // document's: the sheet has no location.
    if (parent) |p| {
        if (p.location) |location| try request.setReferrerUrl(location);
        if (p.referrer_policy != .empty) request.referrer_policy = p.referrer_policy;
    }

    // The fetch owns the request from here, even when it fails to start.
    request_owned = false;
    const started = try AsyncFetch.start(allocator, request, .{}, dom.agent_fetches.of(load.realm), sheet.client());
    load.sheets.append(allocator, sheet) catch |err| {
        started.terminate();
        return err;
    };
    sheet.fetch = started;
    load.in_flight += 1;
}

/// The global of `realm`, whose settings object is the requests' client.
fn globalOf(realm: runtime.Context) ?*runtime.Instance {
    const record = realm.getRealm() orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    return global;
}

fn fetchAlive(context: *anyopaque) bool {
    const sheet: *Sheet = @ptrCast(@alignCast(context));
    return sheet.load.realm.engine_ctx != null;
}

/// The element's realm has ended with the fetch in flight, and the fetch has
/// been terminated. Once the last of the load's fetches has gone, so does
/// the load, with no event.
fn fetchGone(context: *anyopaque) void {
    const sheet: *Sheet = @ptrCast(@alignCast(context));
    const load = sheet.load;
    sheet.fetch = null;
    load.in_flight -= 1;
    if (load.in_flight == 0 and !load.event_queued) release(load, .teardown);
}

/// A sheet's fetch has its response, body and all (from the event loop's
/// network step): check it, fetch its imports, and once nothing is left in
/// flight, queue the event.
fn fetchDone(context: *anyopaque, outcome: fetch.algorithms.FetchError!fetch.algorithms.FetchResult) void {
    const sheet: *Sheet = @ptrCast(@alignCast(context));
    const load = sheet.load;
    sheet.fetch = null;
    load.in_flight -= 1;
    processResponse(sheet, outcome);
    if (load.in_flight == 0 and !load.event_queued) complete(load);
}

/// HTML 4.2.4.3 step 7's processResponseConsumeBody and the stylesheet
/// link type's "process the linked resource" steps 1 and 4 - or, for an
/// import, CSS Cascade "fetch an @import" step 3's processResponse - up to
/// the sheet's own imports.
fn processResponse(sheet: *Sheet, outcome: fetch.algorithms.FetchError!fetch.algorithms.FetchResult) void {
    const load = sheet.load;
    // Icon has no response-processing algorithm or decoder. Fetch already
    // performed its CSP checks and timing; release its response unchanged.
    if (load.kind == .icon) {
        var icon_result = outcome catch return;
        icon_result.deinit();
        return;
    }
    var result = outcome catch {
        load.failed = true;
        return;
    };
    defer result.deinit();
    const response = result.response;
    // 4.2.4.3 step 7.2: "If bodyBytes is null or failure; or response's
    // status is not an ok status, then set success to false." A network
    // error has neither.
    if (response.response_type == .@"error") return fail(load);
    // Prefetch step 6: any non-network-error response fires load, including
    // a null body (204) and an opaque filtered response.
    if (load.kind == .prefetch) return;
    // Deviation from step 7.2's "bodyBytes is null", as all three browsers
    // do (golden rule 2, no newer spec: the text is the
    // processResponseConsumeBody refactor's, whatwg/html#9066): a null body
    // - a service worker's `new Response(null)`, a null body status - is an
    // empty style sheet, and load fires. Chrome, Firefox and Safari fire
    // load for a stylesheet a worker's fetch handler answers with
    // `new Response(null)` (static-router-request-destination's "Subreosurce
    // load not matched ..." waits on the link's load: PASS in all three at
    // wpt.fyi 23b0b89b1a; Chrome and Safari pass -mutiple-conditions' two
    // too, which Firefox fails for want of static routing). In Gecko,
    // StreamLoader::OnStopRequest parses zero bytes as an empty sheet, with
    // no case for an empty or null body. Only a network error fails.
    const body_bytes: []const u8 = if (response.body) |body| body.getBytes() else "";
    // A preload: "If response is a network error, fire an event named error
    // at el. Otherwise, fire an event named load at el" - whatever its
    // status or type.
    if (load.kind == .preload) return;
    if (!fetch.internal.isOkStatus(response.status)) {
        // HTML stylesheet processing step 4 gates sheet creation on success,
        // but browsers retain an empty sheet after an HTTP error. Blink's
        // LinkStyle::NotifyFinished and WebKit's setCSSStyleSheet create it
        // before rejecting the response body (old spec, golden rule 2).
        // Keep step 5's error event; never parse the failed response's CSS.
        if (load.kind == .stylesheet and sheet.parent == null and response.status != 0) {
            sheet.origin_clean = response.response_type != .@"opaque" and response.response_type != .opaqueredirect;
            deliver(load, sheet, "", response.url() orelse sheet.url);
        }
        return fail(load);
    }
    // "If the resource's Content-Type metadata is not text/css, then set
    // success to false" - with the quirk: "If the document has been set to
    // quirks mode, has the same origin as the URL of the external resource,
    // and the Content-Type metadata of the external resource is not a
    // supported style sheet type, the user agent must instead assume it to
    // be text/css." An import: "If parentStylesheet is in quirks mode and
    // response is CORS-same-origin, let content type be "text/css"." No
    // Content-Type, or one that does not parse, is the stylesheet link
    // type's default type, text/css (4.2.4.2).
    const cors_same_origin = response.response_type != .@"opaque" and response.response_type != .opaqueredirect;
    if (!(load.quirks and cors_same_origin)) {
        const essence = fetch.internal.mime.extractMimeEssence(load.allocator, &response.header_list) catch return fail(load);
        if (essence) |e| {
            defer load.allocator.free(e);
            if (!std.mem.eql(u8, e, "text/css")) return fail(load);
        }
    }
    // The sheet is parsed; its @import rules are fetched relative to its
    // location, the response's URL.
    // HTML stylesheet processing: origin-clean is set for a
    // CORS-same-origin response, independently of its URL or TAO headers.
    sheet.origin_clean = cors_same_origin;
    const location = response.url() orelse sheet.url;
    sheet.location = load.allocator.dupe(u8, location) catch null;
    const policy_header = response.header_list.get(load.allocator, "Referrer-Policy") catch null;
    defer if (policy_header) |h| load.allocator.free(h);
    sheet.referrer_policy = fetch.internal.policy_container.parseReferrerPolicyHeader(policy_header);
    deliver(load, sheet, body_bytes, location);
    fetchImports(load, sheet, body_bytes, location);
}

/// Hand a fetched sheet to the style engine: the link's own (the
/// stylesheet link type's "process the linked resource" step 4, "create a
/// CSS style sheet") or an @import's (CSS Cascade "fetch an @import" step 3).
/// A superseded load's sheets are no longer the element's.
fn deliver(load: *Load, sheet: *Sheet, bytes: []const u8, location: []const u8) void {
    if (load.kind != .stylesheet and load.kind != .style) return;
    if (load.superseded or !load.elementIsLive()) return;
    // The @import path from the element's own sheet, outermost first. A
    // style element's own sheet is its text, never fetched: every Sheet of
    // its load is an import.
    var path: [max_import_depth + 2]u16 = undefined;
    var n: usize = 0;
    var current: ?*Sheet = sheet;
    while (current) |s| : (current = s.parent) {
        if (s.parent == null and load.kind == .stylesheet) break;
        if (n == path.len) return;
        path[n] = s.import_index;
        n += 1;
    }
    std.mem.reverse(u16, path[0..n]);
    dom.style.deliverSheet(load.element, path[0..n], bytes, location, sheet.origin_clean);
    dom.style.setDeliveredSheetPolicy(load.element, path[0..n], sheet.referrer_policy);
}

fn fail(load: *Load) void {
    load.failed = true;
}

/// Fetch the @import rules of `text`, the sheet `sheet` fetched (null: the
/// style element's own), resolving them against `base`.
fn fetchImports(load: *Load, sheet: ?*Sheet, text: []const u8, base: ?[]const u8) void {
    const urls = css.import_rules.importUrls(load.allocator, text) catch {
        load.failed = true;
        return;
    };
    defer css.import_rules.freeUrls(load.allocator, urls);
    for (urls, 0..) |raw, index| {
        // CSS Values "fetch a style resource" step 1: "If that failed,
        // return" - an import whose URL does not parse is not fetched.
        const url = resolve(load.element, raw, base) orelse continue;
        defer load.element.ctx.allocator.free(url);
        if (sheet) |parent| {
            if (parent.chainHas(url) or parent.depth + 1 > max_import_depth) {
                log.debug("style sheet import of {s} skipped: a cycle, or too deep", .{url});
                continue;
            }
        }
        startFetchImport(load, url, sheet, @intCast(@min(index, std.math.maxInt(u16))), .{ .href = url }, .style);
    }
}

/// `url` parsed relative to `base` and serialized, owned by `element`'s
/// context allocator; null when it does not parse.
fn resolve(element: *runtime.Instance, url: []const u8, base: ?[]const u8) ?[]u8 {
    const base_arg = if (base) |b|
        (if (b.len > 0) webidl.Opt(runtime.USVString).passed(b) else webidl.Opt(runtime.USVString).notPassed())
    else
        webidl.Opt(runtime.USVString).notPassed();
    const parsed = (interfaces.URL.call_static_parse(element, url, base_arg) catch null) orelse return null;
    defer runtime.Instance.deinit(parsed);
    const href = interfaces.URL.get_href(parsed) catch return null;
    return @constCast(href);
}
