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
