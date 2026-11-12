//! Fetch 4.12, deferred fetching: the records `fetchLater()` queues in its
//! client's fetch group, and their lifetime - from "queue a deferred fetch"
//! until each is processed (sent), aborted, or its global goes.
//!
//! ## The interface (Codex row 126's fetchLater() calls it)
//!
//! ```zig
//! const deferred_fetches = @import("dom").deferred_fetches;
//! // fetchLater() steps 1-13 done (validation, the quota check, `requested`):
//! const activated = try deferred_fetches.queue(global, request, .{
//!     .total_request_length = requested,
//!     .activate_after_ms = activate_after, // init["activateAfter"], >= 0
//!     .signal = request_object_signal,
//! });
//! // Step 17: the result keeps `activated` (released in its deinitOwn); if
//! // making it fails, `activated.release()`.
//! ```
//!
//! - `queue` TAKES `request` on every path, error or not. The caller hands
//!   over its prepared request (requestObject's request) as it is and does
//!   not populate it: `queue` runs "queue a deferred fetch" steps 1-7 -
//!   populate request from client (`dom.global_settings.requestClient`,
//!   which gives it the client's realm-keyed reporters), service-workers
//!   mode "none", keepalive true, the record, appended to `global`'s fetch
//!   group, the activateAfter wait, the record kept by the group - and
//!   fetchLater() steps 14 ("activated" is false) and 16 (the abort steps
//!   on `signal`).
//! - `Activated` is fetchLater()'s "activated": the variable step 14 makes
//!   and step 17's getter steps return, shared by the record and the
//!   FetchLaterResult - two holds, each released once. `queue` returns the
//!   result's hold; FetchLaterResult takes it on success, and the caller
//!   releases it if the result cannot be made. A result made with none
//!   reads false.
//!
//! ## Lifetime
//!
//! A record is its fetch group's - the global's (a Window's InternalState)
//! - from `queue` until it is processed or aborted; then it is freed at
//! once (a record that is no longer pending counts toward no quota and is
//! never processed again). What it holds:
//! - its request, until processing hands it to a fetch;
//! - one `Activated` hold;
//! - its signal, PINNED while it is pending (DOM 3.3.1: a signal with abort
//!   algorithms must not be collected - the source's abort() reaches the
//!   abort steps through it, as fetch()'s call pins its own), with its abort
//!   algorithm on it, whose context is the record: removed before the
//!   record is freed, while the pin keeps the signal;
//! - its activateAfter timer's token, which the timer owns (armed with
//!   `setTimeoutOwned`) and which points back at the record until the
//!   record goes: a timer that fires, or is dropped, after that finds no
//!   record.
//!
//! "When a fetch group is terminated", step 2 - "process deferred fetches"
//! - is `terminate`, an unloading document cleanup step the Window
//! installs: HTML runs those steps as a document is unloaded and destroyed,
//! which is where Blink processes them (FetchLaterManager::ContextDestroyed,
//! third_party/blink/renderer/core/fetch/fetch_manager.cc at f510e70030):
//! a frame's removal, a navigation away, a popup's close, the page's end.
//! Its document is going, so each request is sent as a fetch already KEPT
//! (fetch.algorithms.AsyncFetch.keep): it reaches nothing of the realm, and
//! goes on on the agent's network side after the realm retires. A page the
//! back/forward cache keeps sends them as it is stored (`storeInCache`, a
//! dom.bfcache store step): Blink's ContextEnteredBackForwardCache does when
//! Background Sync is not granted, and Crane has no Background Sync
//! (fetch/fetch-later/send-on-deactivate.https.window.js expects it).
//!
//! A deferred send is not counted against the fetch group's 64 KiB
//! keepalive budget (keepalive_fetch.Load.deferred): it has the deferred
//! fetch quota instead, and Blink starts it through FetchLaterLoaderFactory,
//! never through the ResourceFetcher whose inflight_keepalive_bytes_ is that
//! budget.
//!
//! Spec: https://fetch.spec.whatwg.org/#deferred-fetching
//! Spec: https://fetch.spec.whatwg.org/#dom-window-fetchlater

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const fetch = @import("fetch");
const global_settings = @import("global_settings.zig");
const abort_algorithms = @import("abort_algorithms.zig");
const keepalive_fetch = @import("keepalive_fetch.zig");
const browser_state = @import("browser_state.zig");
const document_origin = @import("document_origin.zig");
const origin_record = @import("origin_record.zig");
const interfaces = @import("interfaces");
const BrowsingContext = @import("html_core").BrowsingContext;

const log = std.log.scoped(.deferred_fetches);
const InternalRequest = fetch.internal.InternalRequest;

/// fetchLater()'s "activated" (steps 14 and 17): false until its record is
/// processed. Two holds - the record's and the FetchLaterResult's - each
/// released once; the cell goes with the last.
pub const Activated = struct {
    value: bool = false,
    holds: u8,
    allocator: std.mem.Allocator,

    fn create(allocator: std.mem.Allocator) error{OutOfMemory}!*Activated {
        const self = try allocator.create(Activated);
        self.* = .{ .holds = 2, .allocator = allocator };
        return self;
    }

    /// Let one hold go.
    pub fn release(self: *Activated) void {
        std.debug.assert(self.holds > 0);
        self.holds -= 1;
        if (self.holds == 0) self.allocator.destroy(self);
    }
};

/// What `queue` takes besides the request.
pub const QueueOptions = struct {
    /// fetchLater() step 12's "requested": the request's total request
    /// length, which the available quota sums for pending records.
    total_request_length: u64,
    /// fetchLater() step 5's activateAfter, in milliseconds: null for none.
    /// Step 6 rejected a negative one.
    activate_after_ms: ?f64 = null,
    /// requestObject's signal: step 16's abort steps go on it.
    signal: ?*runtime.Instance = null,
};

/// A deferred fetch record (Fetch 2.4), as a fetch group holds it while it
/// is pending.
pub const Record = struct {
    allocator: std.mem.Allocator,
    /// The request's client's global, whose fetch group holds the record -
    /// so it is there for as long as the record is.
    global: *runtime.Instance,
    /// "request": OWNED until processing hands it to a fetch.
    request: ?*InternalRequest,
    /// Its total request length (`QueueOptions.total_request_length`).
    total_request_length: u64,
    /// Its URL's origin, serialized ("null" for an opaque one). OWNED.
    url_origin: []u8,
    /// "notify invoked" sets it.
    activated: *Activated,
    /// The signal its abort steps are on, pinned, and that signal's slab
    /// generation; null with none.
    signal: ?*runtime.Instance = null,
    signal_generation: u64 = 0,
    signal_pin: ?engine.Owned = null,
    /// The activateAfter timer's token, while it is armed; the timer owns
    /// it.
    timer: ?*TimerToken = null,
    /// The group whose list holds it (for the abort steps and the timer).
    records: *Records,

    /// The record leaves: its signal's abort steps and pin, its timer's
    /// link to it, its request if it still has one, its hold of
    /// `activated`. Not its place in the list - the caller's.
    fn destroy(self: *Record) void {
        if (self.signal) |signal| {
            // The pin kept the signal; a realm's end frees every object of
            // it whatever pins it, so check.
            if (runtime.SlabAllocator.generationOf(signal) == self.signal_generation) abort_algorithms.remove(signal, self);
        }
        if (self.signal_pin) |pin| pin.release();
        if (self.timer) |token| token.forget();
        if (self.request) |request| request.deinit();
        self.activated.release();
        self.allocator.free(self.url_origin);
        self.allocator.destroy(self);
    }
};

/// A fetch group's deferred fetch records (Fetch 2.4), in queueing order:
/// the pending ones only - a record is freed as soon as it is processed or
/// aborted. Part of `document_fetches.FetchGroup`; `deinit` with it.
pub const Records = struct {
    items: std.ArrayListUnmanaged(*Record) = .empty,
    /// The allocator `items` grew with: its global's realm's, set by the
    /// first `queue`.
    allocator: ?std.mem.Allocator = null,

    /// The group's global goes: what is still pending goes unsent (its
    /// document's unloading cleanup steps sent it, if they ran).
    pub fn deinit(self: *Records) void {
        while (self.items.pop()) |record| record.destroy();
        if (self.allocator) |allocator| self.items.deinit(allocator);
        self.* = .{};
    }

    /// How many records are pending.
    pub fn count(self: *const Records) usize {
        return self.items.items.len;
    }

    fn remove(self: *Records, record: *Record) void {
        for (self.items.items, 0..) |r, i| {
            if (r != record) continue;
            _ = self.items.orderedRemove(i);
            return;
        }
    }
};

/// An armed activateAfter timer's user data: OWNED by the timer
/// (`setTimeoutOwned`), freed when it fires or is dropped - or by the
/// record, when clearing the timer handed it back. Points at its record
/// until the record goes.
const TimerToken = struct {
    allocator: std.mem.Allocator,
    record: ?*Record,
    timer: runtime.TimerInterface,
    id: runtime.TimerId = 0,

    /// The record goes first: the timer will find nothing. A timer that
    /// can be cleared hands the token back.
    fn forget(self: *TimerToken) void {
        if (self.record) |record| record.timer = null;
        self.record = null;
        if (self.id != 0 and self.timer.clearTimeout(self.id)) self.allocator.destroy(self);
    }

    /// "Queue a deferred fetch" step 6.1's first condition: activateAfter
    /// milliseconds have passed. Step 6.2: process the record.
    fn fire(data: ?*anyopaque) void {
        const self: *TimerToken = @ptrCast(@alignCast(data orelse return));
        const record = self.record;
        if (record) |r| r.timer = null;
        self.allocator.destroy(self);
        const r = record orelse return;
        process(r, .alive);
    }

    /// The timer manager ended with the timer armed.
    fn drop(data: ?*anyopaque) void {
        const self: *TimerToken = @ptrCast(@alignCast(data orelse return));
        if (self.record) |record| record.timer = null;
        self.allocator.destroy(self);
    }
};

/// Fetch 4.12 "queue a deferred fetch" given `request`, activateAfter and
/// "set activated to true" - with fetchLater() steps 14 and 16 - for
/// `global`, the request's client's global (this's relevant global
/// object). See the module comment for what is the caller's. TAKES
/// `request` on every path. Returns the FetchLaterResult's hold of
/// "activated".
pub fn queue(global: *runtime.Instance, request: *InternalRequest, options: QueueOptions) !*Activated {
    var owns_request = true;
    defer if (owns_request) request.deinit();
    const group = global_settings.fetchGroupOf(global) orelse return error.InvalidStateError;
    const records = &group.deferred;
    const allocator = global.ctx.allocator;

    // 1. Populate request from client given request.
    {
        var client = try global_settings.requestClient(global);
        defer client.deinit();
        try fetch.internal.populateRequestFromClient(request, client.request);
    }
    // 2. Set request's service-workers mode to "none".
    request.service_workers_mode = .none;
    // 3. Set request's keepalive to true.
    request.keepalive = true;

    // 4. Let deferredRecord be a new deferred fetch record whose request is
    //    request, and whose notify invoked is onActivatedWithoutTermination
    //    ("set activated to true": the cell).
    const url_origin = try fetch.internal.origins.serializedOriginOf(allocator, request.getUrl());
    errdefer allocator.free(url_origin);
    const activated = try Activated.create(allocator);
    errdefer allocator.destroy(activated);
    const record = try allocator.create(Record);
    errdefer allocator.destroy(record);
    record.* = .{
        .allocator = allocator,
        .global = global,
        .request = request,
        .total_request_length = options.total_request_length,
        .url_origin = url_origin,
        .activated = activated,
        .records = records,
    };
    // 5. Append deferredRecord to request's client's fetch group's deferred
    //    fetch records.
    const list_allocator = records.allocator orelse allocator;
    try records.items.append(list_allocator, record);
    records.allocator = list_allocator;
    owns_request = false;
    // From here the record is the group's: a failure below leaves it
    // queued, as the spec has it, without what failed.

    // fetchLater() step 16: "Add the following abort steps to
    // requestObject's signal: Set deferredRecord's invoke state to
    // "aborted"." The signal is pinned while the record is pending.
    if (options.signal) |signal| {
        abort_algorithms.add(signal, .{ .ctx = record, .run = &abortSteps }) catch |err| {
            log.debug("deferred fetch abort steps not added: {s}", .{@errorName(err)});
        };
        record.signal = signal;
        record.signal_generation = runtime.SlabAllocator.generationOf(signal);
        record.signal_pin = engine.retainValue(signal.ctx, .{ .instance = signal }) catch null;
    }

    // 6. If activateAfter is non-null, then in parallel: wait until at
    //    least activateAfter milliseconds have passed, then process
    //    deferredRecord. (The step's other condition - the user agent is
    //    about to lose the opportunity to run script - is the unloading
    //    cleanup step and the back/forward cache's store step below.)
    if (options.activate_after_ms) |after| armTimer(global, record, after);

    // 7. Return deferredRecord: the group keeps it; the result keeps
    //    "activated".
    return activated;
}

/// Arm `record`'s activateAfter timer on `global`'s realm's timers. Not
/// armed (no timer, out of memory) leaves the record to its document's end.
fn armTimer(global: *runtime.Instance, record: *Record, after_ms: f64) void {
    const timer = global.ctx.getOptionalTimer() orelse return;
    const ms: u64 = if (after_ms <= 0) 0 else if (after_ms >= @as(f64, @floatFromInt(std.math.maxInt(u32)))) std.math.maxInt(u32) else @intFromFloat(@ceil(after_ms));
    const token = record.allocator.create(TimerToken) catch return;
    token.* = .{ .allocator = record.allocator, .record = record, .timer = timer };
    const id = timer.setTimeoutOwned(ms, &TimerToken.fire, token, &TimerToken.drop);
    if (id == 0) {
        record.allocator.destroy(token);
        return;
    }
    token.id = id;
    record.timer = token;
}

/// fetchLater() step 16's abort steps: "Set deferredRecord's invoke state
/// to "aborted"." An aborted record is never processed: it leaves now.
fn abortSteps(ctx: *anyopaque) void {
    const record: *Record = @ptrCast(@alignCast(ctx));
    // The signal is running its algorithms: it drops this one itself.
    record.signal = null;
    record.records.remove(record);
    record.destroy();
}

/// How a record is processed: while its document is there (its
/// activateAfter came), or as its document goes.
const Moment = enum { alive, leaving };

/// Fetch 4.12 "process a deferred fetch" `record`, which is pending (its
/// invoke state is "pending": step 1's other states have left the list).
fn process(record: *Record, moment: Moment) void {
    // 2. Set deferredRecord's invoke state to "sent": it leaves the group.
    record.records.remove(record);
    // 3. Fetch deferredRecord's request.
    if (record.request) |request| {
        record.request = null;
        send(record.global, request, moment);
    }
    // 4. Queue a global task on the deferred fetch task source with
    //    deferredRecord's request's client's global object to run
    //    deferredRecord's notify invoked. Set now, as Chromium does
    //    (DeferredLoader::Process: "Call sites are already triggered from
    //    other task queues"); Firefox and Safari do not ship fetchLater, so
    //    they have no say (golden rule 2).
    record.activated.value = true;
    record.destroy();
}

/// Fetch `request` (TAKEN) for `global`, its client's. While its document
/// is there the fetch is its realm's own, which the agent keeps if the
/// realm goes first; as the document goes it is kept at once - it reports
/// to nothing of a document that is going.
fn send(global: *runtime.Instance, request: *InternalRequest, moment: Moment) void {
    switch (moment) {
        .alive => _ = keepalive_fetch.start(global, request, .{ .load = .deferred }) catch |err| {
            log.debug("deferred fetch not sent: {s}", .{@errorName(err)});
        },
        .leaving => keepalive_fetch.startKept(global, request, .deferred) catch |err| {
            log.debug("deferred fetch not sent: {s}", .{@errorName(err)});
        },
    }
}

/// Fetch "when a fetch group is terminated" step 2, "process deferred
/// fetches" for `environment`'s global's fetch group: an unloading document
/// cleanup step (the Window installs it). Every pending record is sent, in
/// queueing order, as its document goes.
pub fn terminate(environment: runtime.Context) void {
    processAll(environment);
}

/// A page the back/forward cache stores: its pending records are sent now
/// (Blink's ContextEnteredBackForwardCache with Background Sync not
/// granted - Crane has none). A dom.bfcache store step (the Window
/// installs it).
pub fn storeInCache(environment: runtime.Context) void {
    processAll(environment);
}

fn processAll(environment: runtime.Context) void {
    const global = global_settings.liveGlobalOf(environment) orelse return;
    const group = global_settings.fetchGroupOf(global) orelse return;
    while (group.deferred.items.items.len > 0) {
        process(group.deferred.items.items[0], .leaving);
    }
}

// ============================================================================
// The deferred-fetch quota (Fetch 4.12.1)
// ============================================================================
//
// Reads over the navigables and their fetch groups: fetchLater() asks
// `availableQuota` at its step 11, with the "allowed to use" answers for the
// control document, which it computes. A navigable container's "reserved
// deferred-fetch quota" is kept on the container's content navigable
// (BrowsingContext.reserved_deferred_fetch_quota: a container has one
// content navigable while it holds the reservation); HTML navigate step 23
// sets it (`reserveQuota`), "create and initialize a Document object" step
// 21 clears it for a same-origin document (`potentiallyFreeQuota`), and
// "unless stated otherwise, it is 0".
//
// Golden rule 2: Chrome is the only browser that ships fetchLater (Firefox
// and Safari ship neither it nor the deferred-fetch policies), so only the
// spec decides here - fetch/fetch-later/quota/cross-origin-iframe/*: Chrome
// 157 passes all, wpt.fyi stable 24ddf405a0, 2026-11-11.

/// "Allowed to use" answers for a document - or, for a container's
/// reservation, the inherited policy's - given by the caller for the call.
pub const Policy = struct {
    /// The policy-controlled feature "deferred-fetch" (default allowlist
    /// "self").
    deferred_fetch: bool,
    /// "deferred-fetch-minimal" (default allowlist "*").
    deferred_fetch_minimal: bool,
};

const kib: u64 = 1024;
/// 640 kibibytes for a top-level traversable ("640kb should be enough for
/// everyone").
pub const top_level_quota: u64 = 640 * kib;
/// "The quota reserved for deferred-fetch-minimal is 128 kibibytes."
pub const minimal_reserve: u64 = 128 * kib;
/// Step 7's quotaForRequestOrigin.
pub const per_origin_quota: u64 = 64 * kib;

/// A navigable container's "reserved deferred-fetch quota": "Its possible
/// values are minimal quota, which is 8 kibibytes, and normal quota, which
/// is 0 or 64 kibibytes. Unless stated otherwise, it is 0."
pub const ReservedQuota = enum(u32) {
    none = 0,
    minimal = 8 * 1024,
    normal = 64 * 1024,

    pub fn bytes(self: ReservedQuota) u64 {
        return @backingInt(self);
    }
};

/// Fetch 4.12.1 "the deferred-fetch control document" of `document`: itself
/// when its node navigable's container document is null or not same origin
/// with it; otherwise its container document's control document.
pub fn controlDocumentOf(document: *runtime.Instance) *runtime.Instance {
    var current = document;
    // Each step goes up one navigable: the chain ends at the top.
    while (containerDocumentOf(current)) |container_document| {
        if (!sameOriginDocuments(container_document, current)) break;
        current = container_document;
    }
    return current;
}

/// What "the available deferred-fetch quota" steps 6-11 compute from: the
/// control document's place and policy (steps 3-5), its container's
/// reservation (step 6), and the sums of step 8 - every reservation of the
/// containers in the considered documents (8.1) and their pending records'
/// total request lengths (8.2), all of them and those same origin with the
/// request's.
pub const QuotaInputs = struct {
    is_top_level: bool,
    policy: Policy,
    /// The control document's node navigable's container's reservation.
    reserved: ReservedQuota = .none,
    reserved_by_containers: u64 = 0,
    pending: u64 = 0,
    pending_same_origin: u64 = 0,
};

/// Steps 6-11 of "the available deferred-fetch quota", over `inputs`. The
/// decrements saturate at 0: step 9 answers 0 for any quota at or below it.
pub fn quotaFrom(inputs: QuotaInputs) u64 {
    const policy = inputs.policy;
    // 6. "Let quota be the result of the first matching statement."
    var quota: u64 = if (inputs.is_top_level)
        (if (!policy.deferred_fetch) 0 else if (!policy.deferred_fetch_minimal) top_level_quota else top_level_quota - minimal_reserve)
    else if (policy.deferred_fetch and inputs.reserved == .normal)
        ReservedQuota.normal.bytes()
    else if (policy.deferred_fetch_minimal and inputs.reserved == .minimal)
        ReservedQuota.minimal.bytes()
    else
        0;
    // 7. "Let quotaForRequestOrigin be 64 kibibytes."
    var for_request_origin: u64 = per_origin_quota;
    // 8.1 and 8.2.3: decrement quota; 8.2.4: and quotaForRequestOrigin.
    quota -|= inputs.reserved_by_containers;
    quota -|= inputs.pending;
    for_request_origin -|= inputs.pending_same_origin;
    // 9. "If quota is equal or less than 0, then return 0."
    if (quota == 0) return 0;
    // 10. "If quota is less than quotaForRequestOrigin, then return quota."
    if (quota < for_request_origin) return quota;
    // 11. "Return quotaForRequestOrigin."
    return for_request_origin;
}

/// Fetch 4.12.1 "the available deferred-fetch quota" given `document` and
/// `request_origin` - the request URL's origin, serialized (null, or
/// "null" for an opaque one, which no record's origin is same origin
/// with). `policy` is the control document's "allowed to use" answers
/// (steps 4-5), which the caller computes for `controlDocumentOf(document)`.
pub fn availableQuota(document: *runtime.Instance, request_origin: ?[]const u8, policy: Policy) u64 {
    // 1. Let controlDocument be document's deferred-fetch control document.
    const control = controlDocumentOf(document);
    // 2-3. Its node navigable, and whether that is a top-level traversable.
    const navigable = navigableOf(control);
    var inputs: QuotaInputs = .{
        .is_top_level = if (navigable) |bc| bc.parent == null else true,
        .policy = policy,
        // 6's "navigable's navigable container's reserved deferred-fetch
        // quota".
        .reserved = if (navigable) |bc| bc.reserved_deferred_fetch_quota else .none,
    };
    // 8. For each navigable in controlDocument's node navigable's inclusive
    //    descendant navigables whose active document's control document is
    //    controlDocument:
    if (navigable) |top| {
        var tree: std.ArrayListUnmanaged(*BrowsingContext) = .empty;
        defer tree.deinit(std.heap.page_allocator);
        // Inclusive: collectDescendants puts `top` first.
        top.collectDescendants(std.heap.page_allocator, &tree) catch {};
        for (tree.items) |bc| {
            const active: *runtime.Instance = @ptrCast(@alignCast(bc.getActiveDocument() orelse continue));
            if (bc != top and controlDocumentOf(active) != control) continue;
            // 8.1. For each navigable container in its active document,
            //    decrement quota by the container's reservation: the
            //    containers of its child navigables.
            for (bc.children.items) |child| inputs.reserved_by_containers +|= child.reserved_deferred_fetch_quota.bytes();
            // 8.2. Its fetch group's pending records.
            const window: *runtime.Instance = @ptrCast(@alignCast(bc.getActiveWindow() orelse continue));
            addPending(window, request_origin, &inputs);
        }
    } else {
        // A document with no navigable: its own window's records, if any.
        if (windowOf(control)) |window| addPending(window, request_origin, &inputs);
    }
    return quotaFrom(inputs);
}

/// Step 8.2 for one fetch group: each pending record's total request
/// length, and - same origin with `request_origin` - again for the request
/// origin's quota. A record in the group is pending (one that is not is
/// freed at once).
fn addPending(window: *runtime.Instance, request_origin: ?[]const u8, inputs: *QuotaInputs) void {
    const group = global_settings.fetchGroupOf(window) orelse return;
    for (group.deferred.items.items) |record| {
        const length: u64 = record.total_request_length;
        inputs.pending +|= length;
        if (sameSerializedOrigin(record.url_origin, request_origin)) inputs.pending_same_origin +|= length;
    }
}

/// Fetch 4.12.1 "reserve deferred-fetch quota" for the navigable container
/// `container`, whose content navigable is `navigable`, given
/// `origin_to_navigate_to` (serialized; "null" for an opaque one) - HTML
/// navigate step 23, "if sourceDocument is navigable's container document".
/// The inherited policies come from the container's document's policy
/// (Permissions Policy 9.7, `policy_containers.inheritedDeferredFetchPolicy`)
/// and the control document's "allowed to use" answers from its own.
pub fn reserveQuota(navigable: *BrowsingContext, container: *runtime.Instance, origin_to_navigate_to: []const u8) void {
    // 1. "Set container's reserved deferred-fetch quota to 0."
    navigable.reserved_deferred_fetch_quota = .none;
    const policy_containers = @import("policy_containers.zig");
    // 2. "Let controlDocument be container's node document's deferred-fetch
    //    control document."
    const container_document = (interfaces.Node.get_ownerDocument(container) catch null) orelse return;
    const control = controlDocumentOf(container_document);
    // The inherited policy for each feature, container and
    // originToNavigateTo. One that cannot be computed is not "Enabled".
    const target: origin_record.Origin = .{ .serialized = origin_to_navigate_to };
    const inherited = policy_containers.inheritedDeferredFetchPolicy(container, &target) catch return;
    // 3. "If the inherited policy for "deferred-fetch", container and
    //    originToNavigateTo is "Enabled", and the available deferred-fetch
    //    quota for controlDocument is equal or greater than normal quota,
    //    then set container's reserved deferred-fetch quota to normal quota
    //    and return." (An origin-or-null of null: no record is same origin.)
    if (inherited.deferred_fetch) {
        const control_policy: Policy = .{
            .deferred_fetch = policy_containers.allowedToUseWith(control, .deferred_fetch, .{ .report = false }) catch false,
            .deferred_fetch_minimal = policy_containers.allowedToUseWith(control, .deferred_fetch_minimal, .{ .report = false }) catch false,
        };
        if (availableQuota(control, null, control_policy) >= ReservedQuota.normal.bytes()) {
            navigable.reserved_deferred_fetch_quota = .normal;
            return;
        }
    }
    // 4. If controlDocument's node navigable is a top-level traversable, the
    //    inherited policy for "deferred-fetch-minimal" is "Enabled", and its
    //    descendant navigables whose container holds minimal quota number
    //    fewer than 128 KiB / 8 KiB, set the reservation to minimal quota.
    const top = navigableOf(control) orelse return;
    if (top.parent != null or !inherited.deferred_fetch_minimal) return;
    if (minimalReservationAvailable(minimalReservations(top, navigable))) navigable.reserved_deferred_fetch_quota = .minimal;
}

/// Step 4's count: `top`'s descendant navigables whose container's
/// reservation is minimal quota - `navigable`'s own, set to 0 by step 1,
/// is not among them.
fn minimalReservations(top: *BrowsingContext, navigable: *BrowsingContext) usize {
    var tree: std.ArrayListUnmanaged(*BrowsingContext) = .empty;
    defer tree.deinit(std.heap.page_allocator);
    top.collectDescendants(std.heap.page_allocator, &tree) catch {};
    var count: usize = 0;
    // Descendants only: collectDescendants puts `top` first.
    for (tree.items[@min(1, tree.items.len)..]) |bc| {
        if (bc != navigable and bc.reserved_deferred_fetch_quota == .minimal) count += 1;
    }
    return count;
}

/// Step 4's last condition: `count` minimal reservations leave room for
/// another - fewer than "quota reserved for deferred-fetch-minimal /
/// minimal quota", 16.
pub fn minimalReservationAvailable(count: usize) bool {
    return count < minimal_reserve / ReservedQuota.minimal.bytes();
}

/// Fetch 4.12.1 "potentially free deferred-fetch quota" for `document`, a
/// document just created for `navigable` ("create and initialize a
/// Document object" step 21): "if document's node navigable's container
/// document is not null, and its origin is same origin with document, then
/// set document's node navigable's navigable container's reserved
/// deferred-fetch quota to 0" - a same-origin nested document shares its
/// parent's quota. Its origin is known only now, after redirects.
pub fn potentiallyFreeQuota(navigable: *BrowsingContext, document: *runtime.Instance) void {
    if (navigable.parent == null) return;
    const container: *runtime.Instance = @ptrCast(@alignCast(navigable.container orelse return));
    const container_document = (interfaces.Node.get_ownerDocument(container) catch null) orelse return;
    if (sameOriginDocuments(container_document, document)) navigable.reserved_deferred_fetch_quota = .none;
}

/// Whether two serialized origins are the same tuple origin: an opaque
/// one ("null") is same origin with nothing a serialization can name.
fn sameSerializedOrigin(a: []const u8, b: ?[]const u8) bool {
    const other = b orelse return false;
    if (std.mem.eql(u8, a, "null")) return false;
    return std.mem.eql(u8, a, other);
}

/// HTML "same origin" for two documents' origins.
fn sameOriginDocuments(a: *runtime.Instance, b: *runtime.Instance) bool {
    if (a == b) return true;
    const a_record = (document_origin.shareable(a) catch return false) orelse return false;
    const b_record = (document_origin.shareable(b) catch return false) orelse return false;
    return origin_record.sameOrigin(
        .{ .serialized = a_record.serialized orelse return false, .record = a_record },
        .{ .serialized = b_record.serialized orelse return false, .record = b_record },
    );
}

/// `document`'s window, if it has one.
fn windowOf(document: *runtime.Instance) ?*runtime.Instance {
    return interfaces.Document.get_defaultView(document) catch null;
}

/// `document`'s node navigable: its window's browsing context.
fn navigableOf(document: *runtime.Instance) ?*BrowsingContext {
    const window = windowOf(document) orelse return null;
    const bc = browser_state.browsingContextOf(window) orelse return null;
    // A window a later document took over is not this document's navigable.
    const active = bc.getActiveDocument() orelse return null;
    if (@as(*runtime.Instance, @ptrCast(@alignCast(active))) != document) return null;
    return bc;
}

/// "Its node navigable's container document": the node document of the
/// navigable's container, or null for a top-level traversable.
fn containerDocumentOf(document: *runtime.Instance) ?*runtime.Instance {
    const bc = navigableOf(document) orelse return null;
    if (bc.parent == null) return null;
    const container: *runtime.Instance = @ptrCast(@alignCast(bc.container orelse return null));
    return interfaces.Node.get_ownerDocument(container) catch null;
}

test "two serialized origins are same origin only as the same tuple origin" {
    try std.testing.expect(sameSerializedOrigin("https://a.test", "https://a.test"));
    try std.testing.expect(!sameSerializedOrigin("https://a.test", "https://b.test"));
    try std.testing.expect(!sameSerializedOrigin("https://a.test", null));
    try std.testing.expect(!sameSerializedOrigin("null", "null"));
}
