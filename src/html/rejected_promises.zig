//! Unhandled promise rejections: the "unhandledrejection" and
//! "rejectionhandled" events.
//!
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#unhandled-promise-rejections
//!       https://html.spec.whatwg.org/multipage/webappapis.html#the-hostpromiserejectiontracker-implementation
//!
//! The spec's side is `hooks`, the engine's HostHooks: HostPromiseRejectionTracker
//! (`promiseRejectionTracker`) and "perform a microtask checkpoint" step 5
//! (`afterMicrotaskCheckpoint`), over the engine protocol's types. The engine
//! hands the rejection reason over at "reject" - [[PromiseResult]] from then on,
//! which no protocol operation reads - and it is kept beside its promise.
//!
//! Nothing installed either callback before, so no page ever saw an
//! unhandledrejection event, and a test waiting on one waited out the harness
//! timeout.
//!
//! Deviation, stated: a global's "outstanding rejected promises weak set" holds
//! its promises STRONGLY here, released when the global goes away (or, past a
//! cap, oldest first). Weak engine handles carry teardown obligations (AGENTS.md
//! "Whoever ends a weak arm inherits V8's Reset obligation") that are not worth
//! taking on for a set whose only purpose is to notice a late handler. What it
//! changes: a promise nobody will ever handle stays alive until its page does.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const engine = @import("engine");

const log = std.log.scoped(.rejected_promises);
const allocator = std.heap.c_allocator;

/// How many outstanding rejected promises a global keeps before dropping the
/// oldest (see the module doc).
const max_outstanding = 1024;

/// The engine's host hooks for promise rejection tracking. The host that
/// creates an agent installs them (AgentOptions.hooks).
pub const hooks: engine.HostHooks = .{
    .promiseRejectionTracker = promiseRejectionTracker,
    .afterMicrotaskCheckpoint = afterMicrotaskCheckpoint,
};

/// A rejected promise and its [[PromiseResult]], both held (OWNED).
const Rejected = struct {
    promise: engine.Owned,
    /// Null when the engine gave none.
    reason: ?engine.Owned,
    /// The agent's inspector's id for the rejection it was told of
    /// (`reportToInspector`), for Runtime.exceptionRevoked when a handler
    /// comes; 0: none.
    inspector_id: u32 = 0,
    /// Where it was rejected, for the inspector's report
    /// (`reportToInspector`): the stack of the call that rejected, captured
    /// in HostPromiseRejectionTracker's "reject" - after which nothing of it
    /// is on the stack - as Blink's V8Initializer::PromiseRejectHandler
    /// captures its SourceLocation (third_party/blink/renderer/bindings/
    /// core/v8/v8_initializer.cc; BSD-3 - reproduced, not copied). OWNED;
    /// null when the agent has no inspector. Released once reported, and
    /// with the record (handled, revoked, dropped).
    site: ?*engine.InspectorStack = null,
    /// The isolated world of the realm that rejected it (engine section
    /// 4.2a), whose listeners alone hear of it - Blink's PromiseRejectionEvent
    /// ::CanBeDispatchedInWorld (third_party/blink/renderer/core/events/
    /// promise_rejection_event.cc; BSD-3 - reproduced, not copied) - or every
    /// listener's, for a Browser with no world (dom.fire_event.reportWorldOf).
    world: u32 = @import("dom").event_dispatch.DispatchPath.any_world,

    fn release(self: Rejected) void {
        self.promise.release();
        if (self.reason) |reason| reason.release();
        self.releaseSite();
    }

    fn releaseSite(self: Rejected) void {
        if (engine.capabilities.inspector_protocol != .unsupported) {
            if (self.site) |site| engine.inspectorReleaseStack(site);
        }
    }

    fn reasonValue(self: Rejected) ?runtime.JSValue {
        return if (self.reason) |reason| reason.borrow() else null;
    }
};

/// One global's rejection bookkeeping.
const Tracked = struct {
    /// The global, held as (address, slab generation): the slab reuses a freed
    /// Window's slot, and a stale entry must not be mistaken for the new one.
    global: *runtime.Instance,
    generation: u64,
    /// "about-to-be-notified rejected promises list".
    about_to_be_notified: std.ArrayListUnmanaged(Rejected) = .empty,
    /// "outstanding rejected promises weak set".
    outstanding: std.ArrayListUnmanaged(Rejected) = .empty,

    fn isAlive(self: *const Tracked) bool {
        return runtime.SlabAllocator.generationOf(self.global) == self.generation;
    }

    fn destroy(self: *Tracked) void {
        releaseAll(self.about_to_be_notified.items);
        releaseAll(self.outstanding.items);
        self.about_to_be_notified.deinit(allocator);
        self.outstanding.deinit(allocator);
        allocator.destroy(self);
    }
};

/// The bookkeeping of every global of `agent`'s realms: a list on the
/// agent's host (html_core AgentHost.rejections - agent state lives with
/// the agent, docs/instances.md), each entry a `*Tracked` it OWNS. Every
/// promise in it is one of the agent's handles, so the list is read,
/// changed and released only on the agent's thread, and released before the
/// agent ends (`releaseAgent`). (It was one process-wide list, and a
/// Browser's end released every Browser's entries - another Browser's
/// handles, into another isolate.) Null for an agent with no host (a unit
/// test's bare agent): nothing is tracked.
fn listOf(agent: ?*engine.Agent) ?*std.ArrayListUnmanaged(*anyopaque) {
    const host: *@import("html_core").agent_host.AgentHost = @ptrCast(@alignCast(engine.agentHost(agent orelse return null) orelse return null));
    return &host.rejections;
}

fn trackedAt(list: *std.ArrayListUnmanaged(*anyopaque), i: usize) *Tracked {
    return @ptrCast(@alignCast(list.items[i]));
}

fn releaseAll(list: []const Rejected) void {
    for (list) |rejected| rejected.release();
}

/// Release every promise `agent`'s globals hold, before the agent is
/// destroyed: the Browser's end for its window agent, a worker's for its.
pub fn releaseAgent(agent: *engine.Agent) void {
    const list = listOf(agent) orelse return;
    var taken = list.*;
    list.* = .empty;
    for (taken.items) |entry| {
        const t: *Tracked = @ptrCast(@alignCast(entry));
        t.destroy();
    }
    taken.deinit(allocator);
}

/// Release what is held for `global` - its lists - while its agent still
/// exists: a worker's realm ends, then its agent (worker_host teardownRealm,
/// on the worker's thread; the notifications queued for it on the worker's
/// loop were dropped before, and their drop released their promises).
/// Every promise here is a Global of that agent, and releasing one after its
/// isolate is disposed touches freed memory: before disposing an isolate,
/// find everything the process keeps for it
/// (docs/lessons/architecture-before-disposing-an-isolate-find-everything-the.md).
pub fn forgetGlobal(global: *runtime.Instance) void {
    const list = listOf(global.ctx.agent) orelse return;
    for (list.items, 0..) |_, i| {
        const t = trackedAt(list, i);
        if (t.global != global) continue;
        _ = list.swapRemove(i);
        t.destroy();
        break;
    }
    if (list.items.len == 0) list.clearAndFree(allocator);
}

/// The bookkeeping for `global`, created on first use. Entries of the agent
/// whose global has gone are released on the way.
fn trackedFor(global: *runtime.Instance, create: bool) ?*Tracked {
    const list = listOf(global.ctx.agent) orelse return null;
    var i: usize = 0;
    var found: ?*Tracked = null;
    while (i < list.items.len) {
        const t = trackedAt(list, i);
        if (!t.isAlive()) {
            _ = list.swapRemove(i);
            t.destroy();
            continue;
        }
        if (t.global == global) found = t;
        i += 1;
    }
    if (found != null or !create) return found;

    const t = allocator.create(Tracked) catch return null;
    t.* = .{ .global = global, .generation = runtime.SlabAllocator.generationOf(global) };
    list.append(allocator, t) catch {
        allocator.destroy(t);
        return null;
    };
    return t;
}

/// The global object of `realm`'s settings object.
fn globalOf(realm: runtime.Context) ?*runtime.Instance {
    const record = realm.getRealm() orelse return null;
    return @ptrCast(@alignCast(record.global_object orelse return null));
}

/// Remove the entry of `list` whose promise is `promise`, returning it
/// (owned). Promises are objects: SameValue is their identity.
fn takeMatching(realm: runtime.Context, list: *std.ArrayListUnmanaged(Rejected), promise: runtime.JSValue) ?Rejected {
    for (list.items, 0..) |candidate, i| {
        if (engine.sameValue(realm, candidate.promise.value, promise)) return list.orderedRemove(i);
    }
    return null;
}

/// HostPromiseRejectionTracker(promise, operation). `promise` and `reason`
/// are OWNED by this hook.
fn promiseRejectionTracker(host: ?*anyopaque, realm: runtime.Context, promise: engine.Owned, operation: engine.RejectionOperation, reason: ?engine.Owned) void {
    _ = host;
    var rejected: Rejected = .{ .promise = promise, .reason = reason, .world = @import("dom").fire_event.reportWorldOf(realm) };
    // Operation "reject" - V8's kPromiseRejectWithNoHandler, a rejection
    // with no handler yet - runs inside the call that rejected: its stack
    // is captured now for the inspector's report, as Blink's
    // PromiseRejectHandler does for that event alone (never for "handle").
    if (operation == .reject and engine.capabilities.inspector_protocol != .unsupported) {
        rejected.site = engine.inspectorCaptureStack(realm);
    }

    // Steps 1-5: the current settings object's global. (Step 2's muted-errors
    // exception needs the running script, which the engine does not report
    // here; step 4's script settings object is the current one for every
    // script this engine runs.)
    const global = globalOf(realm) orelse return rejected.release();

    switch (operation) {
        // Step 6: operation "reject" - append promise to the global's
        // about-to-be-notified rejected promises list.
        .reject => {
            const t = trackedFor(global, true) orelse return rejected.release();
            t.about_to_be_notified.append(allocator, rejected) catch rejected.release();
        },
        // Step 7: operation "handle".
        .handle => {
            defer rejected.release();
            const t = trackedFor(global, false) orelse return;
            // 7.1: still waiting to be notified - remove it and return.
            if (takeMatching(realm, &t.about_to_be_notified, promise.value)) |pending| return pending.release();
            // 7.2: not outstanding - nothing was ever reported.
            // 7.3: remove promise from the outstanding rejected promises weak set.
            const outstanding = takeMatching(realm, &t.outstanding, promise.value) orelse return;
            // 7.4: queue a global task to fire rejectionhandled.
            queueNotification(global, .rejection_handled, &.{outstanding});
        },
    }
}

/// "Perform a microtask checkpoint" step 5: "for each environment settings
/// object settingsObject whose responsible event loop is this event loop,
/// notify about rejected promises given settingsObject's global object" -
/// the globals of the checkpointing agent's realms: a window's and its
/// frames' share one, a worker's is its own. Every tracked global used to
/// be notified at every checkpoint, which once workers track rejections too
/// would notify the page's at a worker's.
pub fn afterMicrotaskCheckpoint(host: ?*anyopaque, agent: *engine.Agent) void {
    _ = host;
    const list = listOf(agent) orelse return;
    // This agent's live entries, taken first: notifying queues tasks, and
    // the list must not move under the walk. Gone globals' entries are
    // released on the way.
    var mine: std.ArrayListUnmanaged(*Tracked) = .empty;
    defer mine.deinit(allocator);
    var i: usize = 0;
    while (i < list.items.len) {
        const t = trackedAt(list, i);
        if (!t.isAlive()) {
            _ = list.swapRemove(i);
            t.destroy();
            continue;
        }
        i += 1;
        mine.append(allocator, t) catch continue;
    }
    for (mine.items) |t| {
        // Steps 1-3: take the list, leaving it empty; nothing to do when it
        // is empty.
        if (t.about_to_be_notified.items.len == 0) continue;
        const taken = t.about_to_be_notified.toOwnedSlice(allocator) catch continue;
        defer allocator.free(taken);
        // Step 4: queue a global task.
        queueNotification(t.global, .unhandled_rejection, taken);
    }
}

const Kind = enum { unhandled_rejection, rejection_handled };

const Notification = struct {
    global: *runtime.Instance,
    generation: u64,
    kind: Kind,
    /// Owned.
    promises: []Rejected,

    /// The task will not run: release what it carries.
    fn discard(self: *Notification) void {
        releaseAll(self.promises);
        allocator.free(self.promises);
        allocator.destroy(self);
    }
};

/// Queue a global task on the DOM manipulation task source to run
/// `runNotification`. Takes ownership of every entry in `promises` (the
/// slice itself is copied).
///
/// A window's realm and a worker's have an event loop - a worker's its own,
/// on its own thread - which owns the task until it runs or is dropped
/// (`dropNotification`). A bare realm with none (a unit test's) notifies
/// nothing.
fn queueNotification(global: *runtime.Instance, kind: Kind, promises: []const Rejected) void {
    const loop = global.ctx.getOptionalEventLoop() orelse return releaseAll(promises);
    const task = allocator.create(Notification) catch return releaseAll(promises);
    const copy = allocator.dupe(Rejected, promises) catch {
        allocator.destroy(task);
        return releaseAll(promises);
    };
    task.* = .{
        .global = global,
        .generation = runtime.SlabAllocator.generationOf(global),
        .kind = kind,
        .promises = copy,
    };
    loop.queueTask(.{ .callback = &runNotification, .context = task, .drop = &dropNotification });
}

/// The queued global task: its steps run as a task of the global's realm -
/// for a worker's, ended the worker's way.
fn runNotification(data: ?*anyopaque) void {
    const task: *Notification = @ptrCast(@alignCast(data orelse return));
    defer {
        allocator.free(task.promises);
        allocator.destroy(task);
    }
    if (runtime.SlabAllocator.generationOf(task.global) != task.generation) return releaseAll(task.promises);
    engine.runTaskInRealm(task.global.ctx, notificationSteps, task) catch releaseAll(task.promises);
}

/// The queued global task will never run: its loop dropped it - a closing
/// worker's loop discards its tasks (HTML close() and "terminate a
/// worker"), and a window's loop drops a task it ends with. What it carries
/// is released: its record, its list, and the promises and reasons it holds.
/// Both loops drop while the task's agent lives (a worker's queueTask drops
/// a closing worker's task at once; the window loop ends before its agent),
/// so the handles are released into a live isolate.
fn dropNotification(data: ?*anyopaque) void {
    const task: *Notification = @ptrCast(@alignCast(data orelse return));
    task.discard();
}

fn notificationSteps(data: ?*anyopaque) void {
    const task: *Notification = @ptrCast(@alignCast(data.?));
    for (task.promises) |rejected| {
        switch (task.kind) {
            .unhandled_rejection => notifyOne(task.global, rejected),
            .rejection_handled => {
                defer rejected.release();
                revokeAtInspector(inspectorRealm(task.global, rejected), rejected);
                _ = firePromiseRejectionEvent(task.global, "rejectionhandled", rejected, false);
            },
        }
    }
}

/// [[PromiseIsHandled]]. Only an engine with promise rejection tracking calls
/// the hooks at all; on another this is never reached.
fn isHandled(realm: runtime.Context, promise: runtime.JSValue) bool {
    if (engine.capabilities.promise_rejection_tracking != .unsupported) return engine.promiseIsHandled(realm, promise);
    return false;
}

/// "Notify about rejected promises" step 4.1, for one promise it owns.
fn notifyOne(global: *runtime.Instance, rejected: Rejected) void {
    const realm = global.ctx;
    // 4.1.1: If p.[[PromiseIsHandled]] is true, continue.
    if (isHandled(realm, rejected.promise.value)) return rejected.release();

    // 4.1.2: fire unhandledrejection, cancelable, with p and its result.
    const not_canceled = firePromiseRejectionEvent(global, "unhandledrejection", rejected, true);

    // 4.1.3: the user agent may report it to a developer console - its
    // Browser's, when its host shows one (dom.developer_console).
    if (not_canceled and !reportToDeveloperConsole(realm, rejected)) log.debug("unhandled promise rejection", .{});

    // And to the agent's inspector: Runtime.exceptionThrown, "Uncaught (in
    // promise)" (Blink's RejectedPromises::Message::Report ->
    // ThreadDebugger::PromiseRejected).
    var outstanding = rejected;
    if (not_canceled) outstanding.inspector_id = reportToInspector(inspectorRealm(global, rejected), rejected);
    // Its site has been reported (or never will be: canceled): the record
    // kept in the outstanding set does not hold it.
    outstanding.releaseSite();
    outstanding.site = null;

    // 4.1.4: If p.[[PromiseIsHandled]] is false, append p to the global's
    // outstanding rejected promises weak set.
    if (isHandled(realm, outstanding.promise.value)) return outstanding.release();
    const t = trackedFor(global, true) orelse return outstanding.release();
    if (t.outstanding.items.len >= max_outstanding) t.outstanding.orderedRemove(0).release();
    t.outstanding.append(allocator, outstanding) catch outstanding.release();
}

/// The realm the inspector is told a rejection happened in: its world's
/// realm of `global` (an isolated world's script rejected it), else the
/// global's own.
fn inspectorRealm(global: *runtime.Instance, rejected: Rejected) runtime.Context {
    const any_world = @import("dom").event_dispatch.DispatchPath.any_world;
    if (rejected.world == any_world or rejected.world == engine.main_world) return global.ctx;
    return engine.worldRealmFor(global.ctx, rejected.world) orelse global.ctx;
}

/// An unhandled rejection, to the agent's inspector (engine section 4.2b
/// [inspector_protocol]): its id, 0 when none took it (no inspector, the
/// realm not registered, or no inspector protocol: -Dcdp=false).
fn reportToInspector(realm: runtime.Context, rejected: Rejected) u32 {
    if (engine.capabilities.inspector_protocol != .unsupported) {
        const reason = rejected.reasonValue() orelse runtime.JSValue.jsUndefined;
        return engine.inspectorExceptionThrown(realm, reason, &.{ .message = "Uncaught (in promise)", .stack = rejected.site });
    }
    return 0;
}

/// A rejection the inspector was told of got its handler:
/// Runtime.exceptionRevoked (Blink's ThreadDebugger::PromiseRejectionRevoked).
fn revokeAtInspector(realm: runtime.Context, rejected: Rejected) void {
    if (rejected.inspector_id == 0) return;
    if (engine.capabilities.inspector_protocol != .unsupported) {
        engine.inspectorExceptionRevoked(realm, rejected.inspector_id, "Handler added to rejected promise");
    }
}

/// Step 4.1.3's report to `realm`'s Browser's developer console, as DevTools
/// reports an unhandled rejection: "Uncaught (in promise) " and the reason's
/// message, at the source "extract error information" finds for it (V8's
/// message for the value: an Error's throw site). Whether one took it (none
/// is attached: the debug log has it, as before).
fn reportToDeveloperConsole(realm: runtime.Context, rejected: Rejected) bool {
    const developer_console = @import("dom").developer_console;
    if (!developer_console.isAttached(realm)) return false;
    const reason = rejected.reasonValue() orelse runtime.JSValue.jsUndefined;
    const info = engine.extractErrorInformation(realm, reason, allocator) catch return false;
    defer allocator.free(info.message);
    defer allocator.free(info.filename);
    // V8 words the message of a thrown value "Uncaught <value>"; DevTools
    // says where it was not caught.
    const uncaught = "Uncaught ";
    const rest = if (std.mem.startsWith(u8, info.message, uncaught)) info.message[uncaught.len..] else info.message;
    const text = std.mem.concat(allocator, u8, &.{ "Uncaught (in promise) ", rest }) catch return false;
    defer allocator.free(text);
    return developer_console.report(&.{
        .realm = realm,
        .kind = .rejection,
        .level = .@"error",
        .text = text,
        .location = .{ .url = info.filename, .line = info.lineno, .column = info.colno },
    });
}

/// Fire a PromiseRejectionEvent named `event_type` at `global`, with
/// the promise and its [[PromiseResult]] as the reason. Returns notCanceled.
fn firePromiseRejectionEvent(global: *runtime.Instance, event_type: []const u8, rejected: Rejected, cancelable: bool) bool {
    const init = dictionaries.PromiseRejectionEventInit{
        .base = .{ .bubbles = false, .cancelable = cancelable, .composed = false },
        // BORROWED: the event holds values of its own.
        .promise = rejected.promise.borrow(),
        .reason = rejected.reasonValue(),
    };
    const event = interfaces.PromiseRejectionEvent.call_constructor(
        global.ctx,
        runtime.DOMString.initInterned(event_type),
        init,
    ) catch |err| {
        log.debug("could not create PromiseRejectionEvent: {}", .{err});
        return true;
    };
    const generation = runtime.SlabAllocator.generationOf(event);
    // Fired by the user agent, so trusted (DOM 2.10) - at the listeners of
    // the rejecting realm's world only (`Rejected.world`).
    const not_canceled = @import("dom").fire_event.dispatchTrustedInWorld(global, event, rejected.world) catch true;
    event.releaseIfUnwrapped(generation);
    return not_canceled;
}
