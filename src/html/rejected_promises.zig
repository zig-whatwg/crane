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

    fn release(self: Rejected) void {
        self.promise.release();
        if (self.reason) |reason| reason.release();
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
    /// Notifications queued as timers (a worker's realm has no event loop of
    /// its own) that have not run: `forgetGlobal` cancels them, since the
    /// promises they carry belong to an agent that is about to end.
    armed: std.ArrayListUnmanaged(Armed) = .empty,

    fn isAlive(self: *const Tracked) bool {
        return runtime.SlabAllocator.generationOf(self.global) == self.generation;
    }

    /// Whether the global's realm is one of `agent`'s.
    fn inAgent(self: *const Tracked, agent: *engine.Agent) bool {
        const own = self.global.ctx.agent orelse return false;
        return @intFromPtr(own) == @intFromPtr(agent);
    }

    fn destroy(self: *Tracked) void {
        for (self.armed.items) |armed| {
            _ = armed.timer.clearTimeout(armed.id);
            armed.task.discard();
        }
        self.armed.deinit(allocator);
        releaseAll(self.about_to_be_notified.items);
        releaseAll(self.outstanding.items);
        self.about_to_be_notified.deinit(allocator);
        self.outstanding.deinit(allocator);
        allocator.destroy(self);
    }
};

/// A notification armed as a timer, and its id.
const Armed = struct {
    task: *Notification,
    timer: runtime.TimerInterface,
    id: runtime.TimerId,
};

var tracked: std.ArrayListUnmanaged(*Tracked) = .empty;

fn releaseAll(list: []const Rejected) void {
    for (list) |rejected| rejected.release();
}

/// Release every promise held, before the agent is destroyed.
pub fn releaseTracked() void {
    for (tracked.items) |t| t.destroy();
    tracked.deinit(allocator);
    tracked = .empty;
}

/// Release what is held for `global` - its lists, and the notifications
/// queued for it that have not run - while its agent still exists: a worker's
/// realm ends, and one timer later its agent (worker_host teardownRealm).
/// Every promise here is a Global of that agent, and releasing one after its
/// isolate is disposed touches freed memory: before disposing an isolate,
/// find everything the process keeps for it
/// (docs/lessons/architecture-before-disposing-an-isolate-find-everything-the.md).
pub fn forgetGlobal(global: *runtime.Instance) void {
    for (tracked.items, 0..) |t, i| {
        if (t.global != global) continue;
        _ = tracked.swapRemove(i);
        t.destroy();
        return;
    }
}

/// The bookkeeping for `global`, created on first use. Entries whose global
/// has gone are released on the way.
fn trackedFor(global: *runtime.Instance, create: bool) ?*Tracked {
    var i: usize = 0;
    var found: ?*Tracked = null;
    while (i < tracked.items.len) {
        const t = tracked.items[i];
        if (!t.isAlive()) {
            t.destroy();
            _ = tracked.swapRemove(i);
            continue;
        }
        if (t.global == global) found = t;
        i += 1;
    }
    if (found != null or !create) return found;

    const t = allocator.create(Tracked) catch return null;
    t.* = .{ .global = global, .generation = runtime.SlabAllocator.generationOf(global) };
    tracked.append(allocator, t) catch {
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
    const rejected: Rejected = .{ .promise = promise, .reason = reason };

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
    var i: usize = 0;
    while (i < tracked.items.len) {
        const t = tracked.items[i];
        if (!t.isAlive()) {
            t.destroy();
            _ = tracked.swapRemove(i);
            continue;
        }
        i += 1;
        if (!t.inAgent(agent)) continue;
        // Steps 1-3: take the list, leaving it empty; nothing to do when it
        // is empty.
        if (t.about_to_be_notified.items.len == 0) continue;
        const list = t.about_to_be_notified.toOwnedSlice(allocator) catch continue;
        defer allocator.free(list);
        // Step 4: queue a global task.
        queueNotification(t.global, .unhandled_rejection, list);
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
/// A window's realm has an event loop. A worker's has none of its own: its
/// tasks run as timers on its owner's loop, and so does this one - tracked,
/// so that the worker's end can cancel it (`forgetGlobal`).
fn queueNotification(global: *runtime.Instance, kind: Kind, promises: []const Rejected) void {
    const loop = global.ctx.getOptionalEventLoop();
    const timer = if (loop == null) global.ctx.getOptionalTimer() else null;
    if (loop == null and timer == null) return releaseAll(promises);
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
    if (loop) |l| return l.queueTask(.{ .callback = &runNotification, .context = task });
    const t = trackedFor(global, true) orelse return task.discard();
    const id = timer.?.setTimeout(0, &runNotification, task);
    if (id == 0) return task.discard();
    t.armed.append(allocator, .{ .task = task, .timer = timer.?, .id = id }) catch {};
}

/// The queued global task: its steps run as a task of the global's realm -
/// for a worker's, ended the worker's way.
fn runNotification(data: ?*anyopaque) void {
    const task: *Notification = @ptrCast(@alignCast(data orelse return));
    forgetArmed(task);
    defer {
        allocator.free(task.promises);
        allocator.destroy(task);
    }
    if (runtime.SlabAllocator.generationOf(task.global) != task.generation) return releaseAll(task.promises);
    engine.runTaskInRealm(task.global.ctx, notificationSteps, task) catch releaseAll(task.promises);
}

/// `task` has fired: it is no longer armed.
fn forgetArmed(task: *Notification) void {
    for (tracked.items) |t| {
        for (t.armed.items, 0..) |armed, i| {
            if (armed.task == task) {
                _ = t.armed.swapRemove(i);
                return;
            }
        }
    }
}

fn notificationSteps(data: ?*anyopaque) void {
    const task: *Notification = @ptrCast(@alignCast(data.?));
    for (task.promises) |rejected| {
        switch (task.kind) {
            .unhandled_rejection => notifyOne(task.global, rejected),
            .rejection_handled => {
                defer rejected.release();
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

    // 4.1.3: the user agent may report it to a developer console.
    if (not_canceled) log.debug("unhandled promise rejection", .{});

    // 4.1.4: If p.[[PromiseIsHandled]] is false, append p to the global's
    // outstanding rejected promises weak set.
    if (isHandled(realm, rejected.promise.value)) return rejected.release();
    const t = trackedFor(global, true) orelse return rejected.release();
    if (t.outstanding.items.len >= max_outstanding) t.outstanding.orderedRemove(0).release();
    t.outstanding.append(allocator, rejected) catch rejected.release();
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
    // Fired by the user agent, so trusted (DOM 2.10).
    const not_canceled = @import("dom").fire_event.dispatchTrusted(global, event) catch true;
    event.releaseIfUnwrapped(generation);
    return not_canceled;
}
