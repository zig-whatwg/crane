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
//! Deviations, stated:
//! - The sheets are not parsed into CSSOM: `sheet` stays null. Only their
//!   @import rules are read (`css.import_rules`).
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
    /// The href attribute's value.
    href: []const u8,
    cors: CorsSetting = .no_cors,
    /// The referrerpolicy attribute's state; `.empty` for none.
    referrer_policy: fetch.internal.ReferrerPolicy = .empty,
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
    /// A link element's modulepreload: one module script, fetched "cors",
    /// failing on a MIME type that is not JavaScript; no delay on the
    /// document's load event either.
    modulepreload,
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
    /// A fetch failed: the event is `error`.
    failed: bool = false,
    /// The event's task is queued.
    event_queued: bool = false,
    /// The event is not to fire: the element fetches again (a link whose
    /// href changed), or is gone. The queued task only ends the load.
    superseded: bool = false,

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
        // - preload and modulepreload.
        if (load.kind == .preload or load.kind == .modulepreload) continue;
        if (load.document == document and load.documentIsLive()) return true;
    }
    return false;
}

/// HTML "default fetch and process the linked resource" for `element`, a
/// link element whose stylesheet link is to be fetched: create a link
/// request from its options, fetch it, and then its critical subresources.
/// The load's id, or null when there is nothing to fetch ("If request is
/// null, then return": the href does not parse) - and then no event fires.
pub fn startLink(element: *runtime.Instance, options: LinkOptions) ?u64 {
    // "Create a link request", step 1: "Assert: options's href is not the
    // empty string" - the caller returns before an empty one.
    return startLinkFetch(element, .stylesheet, options, .style);
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

/// HTML "fetch and process the linked resource" for `element`, a link
/// element whose modulepreload link is to be fetched, `destination` its `as`
/// attribute's state ("script" when it has none): step 3, a destination
/// that is not script-like fires `error` from a task; otherwise "fetch a
/// modulepreload module script graph" - "fetch a single module script" -
/// then `error` if there is no module script, `load` if there is.
///
/// Not modelled, stated: the module map, which the fetched script would
/// enter for a later import to find, and "fetch the descendants" - the
/// script's own imports; and the script is not parsed, so a module that
/// fails to parse still fires load.
pub fn startModulePreload(element: *runtime.Instance, options: LinkOptions, destination: fetch.internal.Destination) ?u64 {
    if (!destination.isScriptLike()) {
        const load = newLoad(element, .modulepreload) orelse return null;
        load.failed = true;
        complete(load);
        return load.id;
    }
    return startLinkFetch(element, .modulepreload, options, destination);
}

fn startLinkFetch(element: *runtime.Instance, kind: Kind, options: LinkOptions, destination: fetch.internal.Destination) ?u64 {
    const load = newLoad(element, kind) orelse return null;
    // Step 2: "Let url be the result of encoding-parsing a URL given
    // options's href, relative to options's base URL." Step 3: failure is
    // no request.
    const base = interfaces.Node.get_baseURI(load.document) catch null;
    defer if (base) |b| load.document.ctx.allocator.free(b);
    const url = resolve(element, options.href, base) orelse {
        release(load, .settled);
        return null;
    };
    defer element.ctx.allocator.free(url);
    startFetch(load, url, null, options.cors, options.referrer_policy, destination);
    if (load.in_flight == 0) complete(load);
    return load.id;
}

/// HTML "update a style block" step 6 onwards, for `element`, a style
/// element whose style sheet is `text`: fetch the sheet's critical
/// subresources, then fire its event. The load's id, or null when none
/// could start (no event fires).
pub fn startStyle(element: *runtime.Instance, text: []const u8) ?u64 {
    const load = newLoad(element, .style) orelse return null;
    // The sheet's location is null: its imports resolve against the node
    // document's base URL (CSSOM "style sheet base URL").
    const base = interfaces.Node.get_baseURI(load.document) catch null;
    defer if (base) |b| load.document.ctx.allocator.free(b);
    fetchImports(load, null, text, base);
    // "If the style sheet has no critical subresources, once the style sheet
    // has been parsed and processed": now.
    if (load.in_flight == 0) complete(load);
    return load.id;
}

/// A style element whose block Content Security Policy blocked ("update a
/// style block" step 5): no sheet is made, and the element fires `error`
/// as one whose sheet failed would. The load's id, or null when none could
/// start (no event fires).
///
/// Deviation, stated: HTML's step 5 returns with no event. Chrome, Firefox
/// and Safari fire `error` at a CSP-blocked style element (WebKit
/// d487138f2ba5, bug 246710, "Fire error event when CSP blocks inline
/// stylesheets"), and WPT tests it: content-security-policy/style-src/
/// style-src-error-event-fires.html and style-src-inline-style-nonce-
/// blocked-error-event.html. No whatwg/html issue asks for it.
pub fn startBlockedStyle(element: *runtime.Instance) ?u64 {
    const load = newLoad(element, .style) orelse return null;
    load.failed = true;
    complete(load);
    return load.id;
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
        return;
    }
    release(load, .settled);
}

/// A style element's sheet is removed ("update a style block" step 2): a
/// load still fetching the sheet's critical subresources ends with no event,
/// as the sheet has no element to fire it at any more. One whose event is
/// already queued still fires it: the task is in the queue.
pub fn abandon(id: u64) void {
    const load = find(id) orelse return;
    if (load.event_queued) return;
    terminateFetches(load);
    release(load, .settled);
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
/// more.
fn terminateFetches(load: *Load) void {
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
    /// The element, its realm or its event loop is going away: teardown,
    /// in which nothing is queued for the document any more.
    teardown,
};

/// `load` is over: it leaves the list, and - unless it ends in teardown -
/// its document is told.
fn release(load: *Load, ending: Ending) void {
    for (loads.items, 0..) |l, i| {
        if (l == load) {
            _ = loads.swapRemove(i);
            break;
        }
    }
    terminateFetches(load);
    for (load.sheets.items) |sheet| {
        load.allocator.free(sheet.url);
        load.allocator.destroy(sheet);
    }
    load.sheets.deinit(load.allocator);
    const document = load.document;
    const document_live = load.documentIsLive();
    load.allocator.destroy(load);
    if (document_live and ending == .settled) dom.document_lifecycle.loadDelayMayHaveEnded(document);
}

/// Every fetch has ended: queue the task that fires the event.
fn complete(load: *Load) void {
    if (!load.elementIsLive() or load.realm.engine_ctx == null) return release(load, .teardown);
    const loop = load.element.ctx.getOptionalEventLoop() orelse {
        log.warn("style sheet load event not queued: the element's realm has no event loop", .{});
        return release(load, .settled);
    };
    // The queued task keeps the element alive: a link made by script,
    // inserted and dropped still fires. The hold is a flag, so it is taken
    // for an element's first waiting task and ended with its last.
    if (!otherEventQueued(load)) engine.keepPlatformObjectAlive(load.element);
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
fn startFetch(load: *Load, url: []const u8, parent: ?*Sheet, cors: CorsSetting, referrer_policy: fetch.internal.ReferrerPolicy, destination: fetch.internal.Destination) void {
    startFetchOrFail(load, url, parent, cors, referrer_policy, destination) catch |err| {
        log.debug("style sheet fetch of {s} not started: {}", .{ url, err });
        load.failed = true;
    };
}

fn startFetchOrFail(load: *Load, url: []const u8, parent: ?*Sheet, cors: CorsSetting, referrer_policy: fetch.internal.ReferrerPolicy, destination: fetch.internal.Destination) !void {
    const allocator = load.allocator;
    const sheet = try allocator.create(Sheet);
    errdefer allocator.destroy(sheet);
    sheet.* = .{
        .load = load,
        .url = try allocator.dupe(u8, url),
        .parent = parent,
        .depth = if (parent) |p| p.depth + 1 else 0,
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
    // A module script is fetched "cors" whatever the attribute, with its
    // "CORS settings attribute credentials mode": "same-origin" for No CORS
    // and Anonymous, "include" for Use Credentials.
    if (load.kind == .modulepreload) {
        request.mode = .cors;
        request.credentials_mode = if (cors == .use_credentials) .include else .same_origin;
    }
    request.use_url_credentials = true;
    // "Set request's referrer policy to options's referrer policy."
    request.referrer_policy = referrer_policy;
    // Step 6 of "default fetch and process the linked resource": the
    // initiator type is "css" for a stylesheet link, "link" otherwise; an
    // import's is "css" too.
    request.initiator_type = if (load.kind == .preload) .link else .css;
    // "Set request's client to options's environment": the element's
    // relevant settings object - its realm's global's.
    if (globalOf(load.realm)) |global| {
        var client = try dom.global_settings.requestClient(global);
        defer client.deinit();
        try fetch.internal.populateRequestFromClient(request, client.request);
    }

    // The fetch owns the request from here, even when it fails to start.
    request_owned = false;
    const started = try AsyncFetch.start(allocator, request, .{}, fetch.network.scheduler.threadScheduler(), sheet.client());
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
    const body = response.body orelse return fail(load);
    // A preload: "If response is a network error, fire an event named error
    // at el. Otherwise, fire an event named load at el" - whatever its
    // status or type.
    if (load.kind == .preload) return;
    // A modulepreload - "fetch a single module script": no module script
    // when the status is not ok, or the MIME type is not a JavaScript MIME
    // type (for a script-like destination).
    if (load.kind == .modulepreload) {
        if (!fetch.internal.isOkStatus(response.status)) return fail(load);
        const essence = fetch.internal.mime.extractMimeEssence(load.allocator, &response.header_list) catch return fail(load);
        const e = essence orelse return fail(load);
        defer load.allocator.free(e);
        if (!fetch.internal.mime.isJavaScriptEssence(e)) return fail(load);
        return;
    }
    if (!fetch.internal.isOkStatus(response.status)) return fail(load);
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
    const location = response.url() orelse sheet.url;
    fetchImports(load, sheet, body.getBytes(), location);
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
    for (urls) |raw| {
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
        startFetch(load, url, sheet, .no_cors, .empty, .style);
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
