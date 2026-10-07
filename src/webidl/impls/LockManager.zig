//! Implementation for LockManager interface
//!
//! Web Locks API section 3.2: an environment's view of its lock manager -
//! request() and query() - and the requests it has made.
//!
//! The lock manager itself - its held lock set and its lock request queues -
//! is the Browser's, shared by every environment of a storage key on every
//! thread (html.web_locks.Registry, a BrowserScope supplement), and touches no
//! engine. This object is one environment's side of it: the Client it
//! registered (its clientId, its storage key, and how the lock task queue
//! posts to it), and a Record per request whose promise, callback and signal
//! it still holds - engine values of this realm, touched only on its thread.
//! The lock task queue tells it what happened as a task posted to this realm's
//! event loop (runtime.TaskSink): a request granted, refused (ifAvailable), or
//! its lock stolen. The task runs the spec's steps for it here.
//!
//! "Each environment settings object has a LockManager object": made on the
//! first `navigator.locks` (html.web_locks.lock_managers, installed below),
//! found again through the registry, and held for its realm's life. Its
//! environment's end - the unloading document cleanup steps, which also run
//! when a worker's realm ends (dom.unloading_cleanup) - is "terminate
//! remaining locks and requests": its locks and queued requests leave the
//! lock manager, so other environments' requests proceed, and the promises of
//! requests that will never be granted are let go.
//!
//! A shared worker's realm runs on its creator's thread until workers batch 2;
//! its realm's task sink is its creator loop's, so what is posted for its
//! requests runs there, entering the worker's realm (engine.runTaskInRealm).
//!
//! Stated deviations:
//! - "Converting the callback's result to Promise<any>" (PromiseResolve) has
//!   no protocol operation: a result that is an object resolves the waiting
//!   promise directly. Exact for a promise of %Promise% (PromiseResolve returns
//!   it); a thenable or another object settles the waiting promise two
//!   microtask ticks sooner than the spec. Primitives and abrupt completions
//!   are converted exactly.
//! - The clientId is a random UUID made for this environment: no environment
//!   settings object id exists elsewhere yet (the Clients API would share it).
//! - Termination is per environment, as Blink's ContextDestroyed (see
//!   html/web_locks/registry.zig).
//!
//! Spec: https://w3c.github.io/web-locks/

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const engine = @import("engine");
const dom = @import("dom");
const web_locks = @import("html").web_locks;
const LockManager = interfaces.LockManager;

const log = std.log.scoped(.web_locks);

pub const State = LockManager.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    SecurityError,
    NotSupportedError,
    TypeError,
};

/// This environment's side of the Browser's lock managers.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// The Browser's lock managers. BORROWED: the Browser's scope outlives
    /// every realm. Null for a realm no Browser made.
    registry: ?*web_locks.Registry = null,
    /// This environment, as the lock managers know it. Null with no
    /// registry.
    client: ?*web_locks.Client = null,
    /// The requests whose promise this object still settles.
    records: std.ArrayListUnmanaged(*Record) = .empty,
    /// The query() calls whose promise waits for its task.
    queries: std.ArrayListUnmanaged(*Query) = .empty,
    next_query: u64 = 1,
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// The hooks this impl owns, installed once at process start: the `locks`
/// getter's way to this object, and the end of an environment.
pub fn installHooks() void {
    web_locks.lock_managers.install(.{ .of = lockManagerOf });
    dom.unloading_cleanup.install(&endEnvironment);
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(StateType).own._internal = internal;
    return instance;
}

/// Deinitialize instance: its realm has ended. The environment is
/// terminated if it was not already, and forgotten; the records still
/// waiting for an event go, and a record a promise reaction owns is left to
/// it.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    if (internal.client) |client| internal.registry.?.unregister(client);
    internal.client = null;
    for (internal.records.items) |record| {
        record.owner = null;
        if (record.phase == .pending) record.destroy();
    }
    internal.records.deinit(internal.allocator);
    for (internal.queries.items) |query| query.destroy(internal.allocator);
    internal.queries.deinit(internal.allocator);
    internal.allocator.destroy(internal);
    state.own._internal = null;
    // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

// ----------------------------------------------------------------------------
// The environment's LockManager
// ----------------------------------------------------------------------------

/// "This's relevant settings object's LockManager object" for `realm`: the
/// one registered for it, or a new one, registered.
fn lockManagerOf(realm: runtime.Context) anyerror!*runtime.Instance {
    const scope = realm.browser_scope orelse {
        // A realm no Browser made has no lock manager to share: a
        // LockManager whose requests fail "obtain a lock manager".
        return LockManager.init(realm.allocator, realm);
    };
    const registry = try scope.of(web_locks.Registry);
    if (registry.clientOf(realm)) |client| return @ptrCast(@alignCast(client.owner));

    const instance = try LockManager.init(realm.allocator, realm);
    errdefer runtime.Instance.deinit(instance);
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // The storage key "obtain a lock manager" finds the lock manager by: the
    // origin, serialized; an opaque origin has none (Storage: "obtain a
    // storage key" fails for it), so its requests reject with
    // "SecurityError".
    const origin = originOf(realm);
    defer if (origin) |o| realm.allocator.free(o);
    const storage_key: ?[]const u8 = if (origin) |o| (if (std.mem.eql(u8, o, "null")) null else o) else null;
    const target = try Target.create(registry.allocator, instance, realm.task_sink);
    internal.client = try registry.register(realm, instance, storage_key, target.delivery());
    internal.registry = registry;
    // The settings object's one LockManager: kept for its realm's life, with
    // the promises of the requests it makes.
    engine.keepPlatformObjectAlive(instance);
    return instance;
}

/// `realm`'s settings object's origin, serialized; null when no kind of
/// global answers for it. Owned, `realm.allocator`.
fn originOf(realm: runtime.Context) ?[]const u8 {
    const global = globalOf(realm) orelse return null;
    const settings = dom.global_settings.of(global) orelse return null;
    return settings.origin(global) catch null;
}

fn globalOf(realm: runtime.Context) ?*runtime.Instance {
    const record = realm.getRealm() orelse return null;
    return @ptrCast(@alignCast(record.global_object orelse return null));
}

/// Section 3.2.1 step 3 / 3.2.2 step 2: "If environment's relevant global
/// object's associated Document is not fully active". A worker's global has
/// no associated Document. A realm that has ended is not fully active.
fn associatedDocumentFullyActive(instance: *runtime.Instance) bool {
    if (!instance.ctx.hasEngine()) return false;
    const global = globalOf(instance.ctx) orelse return true;
    if (global.stateAs(interfaces.Window.State) == null) return true;
    const document = interfaces.Window.get_document(global) catch return false;
    return dom.document_activity.fullyActive(document, runtime.SlabAllocator.generationOf(document));
}

/// The unloading document cleanup steps (dom.unloading_cleanup) - Web Locks
/// 2.6: "Whenever the unloading document cleanup steps run with a document,
/// terminate remaining locks and requests with its agent", and "when an agent
/// terminates" (a worker's realm ends: the steps run for it too). Runs on the
/// environment's own thread, while its realm still lives.
fn endEnvironment(realm: runtime.Context) void {
    const scope = realm.browser_scope orelse return;
    const registry = scope.existing(web_locks.Registry) orelse return;
    const client = registry.clientOf(realm) orelse return;
    registry.terminate(client);
    // The LockManager is the realm's, held until it ends: alive here.
    const instance: *runtime.Instance = @ptrCast(@alignCast(client.owner));
    const internal = getInternal(instance) orelse return;
    // Requests that will never be granted: their promises and callbacks go.
    // A held lock's record stays with its waiting promise's reaction.
    var i: usize = 0;
    while (i < internal.records.items.len) {
        const record = internal.records.items[i];
        if (record.phase == .pending) {
            _ = internal.records.orderedRemove(i);
            record.owner = null;
            record.destroy();
        } else i += 1;
    }
}

// ----------------------------------------------------------------------------
// request()
// ----------------------------------------------------------------------------

/// request(name, callback)
pub fn call_request(instance: *runtime.Instance, name: runtime.DOMString, callback: callbacks.LockGrantedCallback) anyerror!runtime.JSValue {
    return request(instance, name.asSlice(), .{}, @ptrCast(callback));
}

/// request(name, options, callback)
pub fn call_request__1(instance: *runtime.Instance, name: runtime.DOMString, options: dictionaries.LockOptions, callback: callbacks.LockGrantedCallback) anyerror!runtime.JSValue {
    return request(instance, name.asSlice(), options, @ptrCast(callback));
}

/// Section 3.2.1, the request() method steps.
fn request(instance: *runtime.Instance, name: []const u8, options: dictionaries.LockOptions, callback_argument: *const anyopaque) anyerror!runtime.JSValue {
    // The callback, converted: this function's until a request keeps it.
    var callback: ?engine.CallbackFunction = engine.takeCallbackFunction(callback_argument);
    defer if (callback) |c| c.release();
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // "1. If options was not passed, then let options be a new LockOptions
    // dictionary with default members." The generated dictionary's null is
    // a member not present: mode "exclusive", ifAvailable and steal false.
    const mode: web_locks.Mode = if (options.mode) |m| switch (m) {
        ._shared_ => .shared,
        ._exclusive_ => .exclusive,
    } else .exclusive;
    const if_available = options.ifAvailable orelse false;
    const steal = options.steal orelse false;
    const signal = options.signal;
    if (signal) |s| if (s.stateAs(interfaces.AbortSignal.State) == null) return error.TypeError;

    // "2. Let environment be this's relevant settings object." "3. If
    // environment's relevant global object's associated Document is not
    // fully active, then return a promise rejected with an
    // "InvalidStateError" DOMException." An environment whose locks were
    // terminated is not active either.
    if (!associatedDocumentFullyActive(instance)) return error.InvalidStateError;
    const registry = internal.registry orelse return error.SecurityError;
    const client = internal.client orelse return error.SecurityError;
    if (registry.ended(client)) return error.InvalidStateError;
    // "4. Let manager be the result of obtaining a lock manager given
    // environment. If that returned failure, then return a promise rejected
    // with a "SecurityError" DOMException."
    if (client.storage_key == null) return error.SecurityError;
    // "5. If name starts with U+002D HYPHEN-MINUS (-), then return a promise
    // rejected with a "NotSupportedError" DOMException."
    if (name.len > 0 and name[0] == '-') return error.NotSupportedError;
    // "6. If both options["steal"] and options["ifAvailable"] are true, ..."
    if (steal and if_available) return error.NotSupportedError;
    // "7. If options["steal"] is true and options["mode"] is not "exclusive",
    // ..."
    if (steal and mode != .exclusive) return error.NotSupportedError;
    // "8. If options["signal"] exists, and either of options["steal"] or
    // options["ifAvailable"] is true, ..."
    if (signal != null and (steal or if_available)) return error.NotSupportedError;
    // The promise, and what rejects it, are made in the current realm.
    const realm = engine.currentRealm() orelse instance.ctx;
    // "9. If options["signal"] exists and is aborted, then return a promise
    // rejected with options["signal"]'s abort reason."
    if (signal) |s| {
        if (try interfaces.AbortSignal.get_aborted(s)) {
            const reason: engine.Owned = .{ .value = try interfaces.AbortSignal.get_reason(s) };
            defer reason.release();
            return (try engine.createRejectedPromise(realm, reason.borrow())).take();
        }
    }

    // "10. Let promise be a new promise."
    var promise = try engine.createPromise(realm);
    var promise_owned = true;
    defer if (promise_owned) engine.releasePromiseCapability(&promise);
    const result = try engine.retainValue(realm, promise.promise);
    errdefer result.release();

    // "11. Request a lock with promise, the current agent, environment's id,
    // manager, callback, name, options["mode"], options["ifAvailable"],
    // options["steal"], and options["signal"]." Section 4.1:
    // "1. Let request be a new lock request (agent, clientId, manager, name,
    // mode, callback, promise, signal)."
    const record = try internal.allocator.create(Record);
    errdefer internal.allocator.destroy(record);
    const owned_name = try internal.allocator.dupe(u8, name);
    errdefer internal.allocator.free(owned_name);
    try internal.records.ensureUnusedCapacity(internal.allocator, 1);
    // "3. Enqueue the following steps to the lock task queue" - run now,
    // under the lock managers' lock; what they hand back comes as a task.
    const id = registry.request(client, name, .{ .mode = mode, .if_available = if_available, .steal = steal }) catch |err| switch (err) {
        error.Ended => return error.InvalidStateError,
        error.NoLockManager => return error.SecurityError,
        error.OutOfMemory => return error.OutOfMemory,
    };
    record.* = .{
        .allocator = internal.allocator,
        .id = id,
        .registry = registry,
        .owner = instance,
        .owner_generation = runtime.SlabAllocator.generationOf(instance),
        .name = owned_name,
        .mode = mode,
        .callback = callback.?,
        .promise = promise,
    };
    callback = null;
    promise_owned = false;
    internal.records.appendAssumeCapacity(record);
    // "2. If signal is present, then add the algorithm signal to abort the
    // request request with signal to signal." After the request has its id:
    // no script runs in between, so the signal cannot abort first.
    if (signal) |s| {
        dom.abort_algorithms.add(s, .{ .ctx = record, .run = Record.signalToAbort, .drop = Record.signalDropped }) catch |err| {
            log.debug("abort algorithm not added: {s}", .{@errorName(err)});
        };
        record.signal = s;
        record.signal_generation = runtime.SlabAllocator.generationOf(s);
    }
    // "12. Return promise."
    return result.take();
}

/// One request this environment made: what the spec's lock request holds
/// that is script's - its promise (the lock's released promise, once
/// granted), callback and signal - and, once granted, its waiting promise.
///
/// A `.pending` record is its LockManager's, listed in its records, until an
/// event about it arrives (or its environment ends). While its callback runs
/// it is `.running`, the event's task's: script in the callback can end the
/// environment (a frame removing itself), and the environment's end must
/// leave the record to the task that is using it. Once its callback has run
/// it is `.holding`: the waiting promise's reaction owns it, and frees it
/// when the promise settles - or when the engine drops the reaction. It stays
/// listed while its LockManager lives, for a `stolen` event to find it.
const Record = struct {
    allocator: std.mem.Allocator,
    /// The request's id; its lock's too.
    id: u64,
    /// The Browser's lock managers. BORROWED: they outlive every realm.
    registry: *web_locks.Registry,
    /// The LockManager listing it, by address and slab generation; null once
    /// it is not listed.
    owner: ?*runtime.Instance,
    owner_generation: u64,
    /// The resource name, for the Lock. Owned.
    name: []u8,
    mode: web_locks.Mode,
    /// Invoked once, then released.
    callback: ?engine.CallbackFunction,
    /// The request's promise: the released promise.
    promise: engine.PromiseCapability,
    /// The lock's waiting promise, once granted.
    waiting: ?engine.PromiseCapability = null,
    /// The signal whose abort algorithm is this record's, while it is.
    signal: ?*runtime.Instance = null,
    signal_generation: u64 = 0,
    /// Its signal aborted it ("signal to abort the request" ran): its
    /// promise is rejected, and a grant on its way releases the lock.
    aborted: bool = false,
    phase: enum { pending, running, holding } = .pending,

    /// Free it: its engine values go, its abort algorithm leaves its signal,
    /// and it leaves its LockManager's list.
    fn destroy(self: *Record) void {
        self.forgetSignal();
        if (self.owner) |owner| {
            if (runtime.SlabAllocator.generationOf(owner) == self.owner_generation) {
                if (getInternal(owner)) |internal| {
                    for (internal.records.items, 0..) |listed, i| {
                        if (listed == self) {
                            _ = internal.records.orderedRemove(i);
                            break;
                        }
                    }
                }
            }
            self.owner = null;
        }
        if (self.callback) |c| c.release();
        self.callback = null;
        engine.releasePromiseCapability(&self.promise);
        if (self.waiting) |*waiting| engine.releasePromiseCapability(waiting);
        self.waiting = null;
        self.allocator.free(self.name);
        self.allocator.destroy(self);
    }

    /// "Remove the algorithm signal to abort the request request from
    /// signal", if the signal still has it.
    fn forgetSignal(self: *Record) void {
        const signal = self.signal orelse return;
        self.signal = null;
        if (runtime.SlabAllocator.generationOf(signal) != self.signal_generation) return;
        dom.abort_algorithms.remove(signal, self);
    }

    fn signalAborted(self: *Record) bool {
        const signal = self.signal orelse return false;
        if (runtime.SlabAllocator.generationOf(signal) != self.signal_generation) return false;
        return interfaces.AbortSignal.get_aborted(signal) catch false;
    }

    /// The signal went away with the algorithm unrun.
    fn signalDropped(ctx: *anyopaque) void {
        const self: *Record = @ptrCast(@alignCast(ctx));
        self.signal = null;
    }

    /// Section 4.3, "signal to abort the request" with the record's signal.
    fn signalToAbort(ctx: *anyopaque) void {
        const self: *Record = @ptrCast(@alignCast(ctx));
        const signal = self.signal orelse return;
        // The algorithm ran: the signal has it no more.
        self.signal = null;
        self.aborted = true;
        // "1. Enqueue the steps to abort the request request to the lock task
        // queue." True when it was still queued: nothing about it will come.
        const removed = self.registry.abort(self.id);
        // "2. Reject request's promise with signal's abort reason."
        if (interfaces.AbortSignal.get_reason(signal)) |value| {
            const reason: engine.Owned = .{ .value = value };
            defer reason.release();
            engine.rejectPromise(&self.promise, reason.borrow()) catch {};
        } else |_| {}
        // A granted request's grant is on its way: it finds the signal
        // aborted and releases the lock ("process the lock request queue"
        // step 14.1.1). Otherwise the record's work is done.
        if (removed) self.destroy();
    }
};

// ----------------------------------------------------------------------------
// What the lock task queue posts
// ----------------------------------------------------------------------------

/// The Delivery of one LockManager: a task posted to its realm's event loop
/// per Event. Made with the registry's allocator, which is thread-safe: a
/// task is made on the posting thread and freed on this one.
const Target = struct {
    allocator: std.mem.Allocator,
    /// The LockManager, by address and slab generation: dereferenced only by
    /// a task, on its own thread.
    manager: *runtime.Instance,
    generation: u64,
    /// Its realm's loop's inbox, a reference; null for a realm with no loop
    /// (a test's): nothing reaches it.
    sink: ?*runtime.TaskSink,

    fn create(allocator: std.mem.Allocator, manager: *runtime.Instance, sink: ?*runtime.TaskSink) !*Target {
        const self = try allocator.create(Target);
        self.* = .{
            .allocator = allocator,
            .manager = manager,
            .generation = runtime.SlabAllocator.generationOf(manager),
            .sink = if (sink) |s| s.retain() else null,
        };
        return self;
    }

    fn delivery(self: *Target) web_locks.Delivery {
        return .{ .ctx = self, .post = post, .deinit = deinitCtx };
    }

    /// Any thread, the registry's lock held: post the event's task.
    fn post(ctx: *anyopaque, event: web_locks.Event) void {
        const self: *Target = @ptrCast(@alignCast(ctx));
        const sink = self.sink orelse return;
        const task = self.allocator.create(Task) catch {
            log.debug("out of memory posting a lock event; dropped", .{});
            return;
        };
        task.* = .{ .allocator = self.allocator, .manager = self.manager, .generation = self.generation, .event = event };
        // A closed sink - its loop has ended - drops the task.
        _ = sink.post(.{ .run = Task.run, .drop = Task.drop, .data = task });
    }

    fn deinitCtx(ctx: *anyopaque) void {
        const self: *Target = @ptrCast(@alignCast(ctx));
        if (self.sink) |sink| sink.release();
        self.allocator.destroy(self);
    }
};

/// One Event, as a task of the LockManager's realm.
const Task = struct {
    allocator: std.mem.Allocator,
    manager: *runtime.Instance,
    generation: u64,
    event: web_locks.Event,

    fn live(self: *const Task) ?*runtime.Instance {
        if (runtime.SlabAllocator.generationOf(self.manager) != self.generation) return null;
        return self.manager;
    }

    /// Never run: its loop has ended. Any thread; no engine.
    fn drop(data: ?*anyopaque) void {
        const self: *Task = @ptrCast(@alignCast(data orelse return));
        self.allocator.destroy(self);
    }

    /// The task, from the LockManager's event loop.
    fn run(data: ?*anyopaque) void {
        const self: *Task = @ptrCast(@alignCast(data orelse return));
        defer self.allocator.destroy(self);
        const manager = self.live() orelse return;
        engine.runTaskInRealm(manager.ctx, steps, self) catch |err| {
            log.debug("lock event not run: {s}", .{@errorName(err)});
        };
    }

    fn steps(data: ?*anyopaque) void {
        const self: *Task = @ptrCast(@alignCast(data orelse return));
        const manager = self.live() orelse return;
        const internal = getInternal(manager) orelse return;
        switch (self.event.kind) {
            .granted => granted(manager, internal, self.event.id),
            .not_granted => notGranted(manager, internal, self.event.id),
            .stolen => stolen(manager, internal, self.event.id),
        }
    }
};

fn findRecord(internal: *InternalState, id: u64) ?*Record {
    for (internal.records.items) |record| {
        if (record.id == id) return record;
    }
    return null;
}

/// Section 4.4 "process the lock request queue", step 14: the steps enqueued
/// on the callback's responsible event loop for a granted request.
fn granted(manager: *runtime.Instance, internal: *InternalState, id: u64) void {
    const registry = internal.registry orelse return;
    const record = findRecord(internal, id) orelse {
        // Its environment ended, and its records went: the lock was released
        // with it. Release it anyway - releasing twice is harmless.
        registry.release(id);
        return;
    };
    if (record.phase != .pending) return;
    // "1. If signal is present, then run these steps:"
    if (record.aborted or record.signal != null) {
        // "1. If signal is aborted, then: enqueue the following step to the
        // lock task queue: release the lock lock. Return." The request's
        // promise was rejected when the signal aborted.
        if (record.aborted or record.signalAborted()) {
            registry.release(id);
            record.destroy();
            return;
        }
        // "2. Remove the algorithm signal to abort the request request from
        // signal."
        record.forgetSignal();
    }
    const realm = manager.ctx;
    // This task's from here: the callback may end the environment.
    record.phase = .running;
    // "2. Let r be the result of invoking callback with a new Lock object
    // associated with lock as the only argument."
    const lock = web_locks.lock_objects.create(realm, record.name, record.mode) catch |err| {
        log.debug("no Lock for a granted request: {s}", .{@errorName(err)});
        registry.release(id);
        record.destroy();
        return;
    };
    const lock_generation = runtime.SlabAllocator.generationOf(lock);
    const completion = invokeCallback(realm, record, .{ .instance = lock });
    // Not wrapped - the invocation failed before it was - it is still ours.
    lock.releaseIfUnwrapped(lock_generation);
    const r = completion orelse {
        registry.release(id);
        record.destroy();
        return;
    };
    defer r.release();
    // "3. Resolve waiting with r." Section 4.4 step 11: "Let waiting be a new
    // promise."
    var waiting = engine.createPromise(realm) catch {
        registry.release(id);
        record.destroy();
        return;
    };
    engine.resolvePromise(&waiting, r.borrow()) catch {};
    record.waiting = waiting;
    // Section 2.4: "When lock's waiting promise settles (fulfills or
    // rejects), enqueue the following steps on the lock task queue". The
    // reaction owns the record from here.
    record.phase = .holding;
    engine.reactToPromise(realm, waiting.promise, &holding_steps, record) catch {
        registry.release(id);
        record.destroy();
    };
}

/// Section 4.1 step 3.5.1, the steps on the callback's responsible event
/// loop for an ifAvailable request that was not grantable.
fn notGranted(manager: *runtime.Instance, internal: *InternalState, id: u64) void {
    const record = findRecord(internal, id) orelse return;
    if (record.phase != .pending) return;
    // This task's: the callback may end the environment.
    record.phase = .running;
    defer record.destroy();
    // "1. Let r be the result of invoking callback with null as the only
    // argument."
    const r = invokeCallback(manager.ctx, record, runtime.JSValue.jsNull) orelse return;
    defer r.release();
    // "2. Resolve promise with r and abort these steps."
    engine.resolvePromise(&record.promise, r.borrow()) catch {};
}

/// Section 4.1 step 3.4.1.1.2: "Reject lock's released promise with an
/// "AbortError" DOMException." The lock left the held lock set; the record
/// stays with its waiting promise.
fn stolen(manager: *runtime.Instance, internal: *InternalState, id: u64) void {
    const record = findRecord(internal, id) orelse return;
    const error_value = engine.createDOMException(manager.ctx, "AbortError", "The lock was stolen by another request.") catch return;
    defer error_value.release();
    engine.rejectPromise(&record.promise, error_value.borrow()) catch {};
}

/// WebIDL "invoke a callback function" with the record's callback - whose
/// return type is Promise<any> - and `argument`: the callback's result as a
/// Promise<any>, OWNED. The callback is released after its one invocation.
/// Null when it could not be invoked at all.
fn invokeCallback(realm: runtime.Context, record: *Record, argument: runtime.JSValue) ?engine.Owned {
    const callback = record.callback orelse return null;
    record.callback = null;
    defer callback.release();
    const completion = engine.invokeCallbackFunction(realm, &callback, .undefined, &.{argument}, .rethrow) catch |err| {
        log.debug("lock callback not invoked: {s}", .{@errorName(err)});
        return null;
    };
    switch (completion) {
        // "If completion is an abrupt completion ... return a promise
        // rejected with completion.[[Value]]" (the return type is a promise
        // type).
        .throw => |thrown| {
            defer thrown.release();
            return engine.createRejectedPromise(realm, thrown.borrow()) catch null;
        },
        // Converted to Promise<any>: PromiseResolve(%Promise%, V). A
        // primitive is a new promise resolved with it; an object is resolved
        // with as it is (the stated deviation in the file comment).
        .normal => |value| {
            if (engine.typeOf(realm, value.value) == .object) return value;
            defer value.release();
            return engine.createResolvedPromise(realm, value.borrow()) catch null;
        },
    }
}

const holding_steps: engine.PromiseReactionSteps = .{
    .fulfilled = waitingSettled,
    .rejected = waitingSettled,
    .dropped = waitingDropped,
};

/// Section 2.4, when the waiting promise settles: "1. Release the lock lock.
/// 2. Resolve lock's released promise with lock's waiting promise."
fn waitingSettled(data: ?*anyopaque, _: runtime.JSValue) void {
    const record: *Record = @ptrCast(@alignCast(data orelse return));
    record.registry.release(record.id);
    if (record.waiting) |waiting| engine.resolvePromise(&record.promise, waiting.promise) catch {};
    record.destroy();
}

/// The engine ended the reaction unsettled - its realm or agent ended: the
/// lock goes (the environment's end released it already), and so does the
/// record.
fn waitingDropped(data: ?*anyopaque) void {
    const record: *Record = @ptrCast(@alignCast(data orelse return));
    record.registry.release(record.id);
    record.destroy();
}

// ----------------------------------------------------------------------------
// query()
// ----------------------------------------------------------------------------

/// Section 3.2.2, the query() method steps.
pub fn call_query(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // "1. Let environment be this's relevant settings object." "2. If
    // environment's relevant global object's associated Document is not
    // fully active, then return a promise rejected with an
    // "InvalidStateError" DOMException."
    if (!associatedDocumentFullyActive(instance)) return error.InvalidStateError;
    const registry = internal.registry orelse return error.SecurityError;
    const client = internal.client orelse return error.SecurityError;
    if (registry.ended(client)) return error.InvalidStateError;
    // "3. Let manager be the result of obtaining a lock manager given
    // environment. If that returned failure, then return a promise rejected
    // with a "SecurityError" DOMException."
    if (client.storage_key == null) return error.SecurityError;
    // "5. Enqueue the steps to snapshot the lock state for manager with
    // promise to the lock task queue" - run now, under the lock managers'
    // lock.
    var snapshot = registry.snapshot(client, internal.allocator) catch |err| switch (err) {
        error.NoLockManager => return error.SecurityError,
        error.Ended => return error.InvalidStateError,
        error.OutOfMemory => return error.OutOfMemory,
    };
    var snapshot_owned = true;
    defer if (snapshot_owned) snapshot.deinit(internal.allocator);
    const realm = engine.currentRealm() orelse instance.ctx;
    // Its step 6, "resolve promise with" the snapshot, reaches script from
    // the lock task queue: as a task of this realm - the answer comes after
    // the tasks the queue posted before it, as it does in browsers (an IPC
    // reply). A realm with no loop (a test's) is answered at once.
    const sink = instance.ctx.task_sink orelse {
        const value = try snapshotObject(realm, snapshot, internal.allocator);
        defer value.release();
        return (try engine.createResolvedPromise(realm, value.borrow())).take();
    };
    // "4. Let promise be a new promise."
    var promise = try engine.createPromise(realm);
    var promise_owned = true;
    defer if (promise_owned) engine.releasePromiseCapability(&promise);
    const result = try engine.retainValue(realm, promise.promise);
    errdefer result.release();
    const query = try internal.allocator.create(Query);
    errdefer internal.allocator.destroy(query);
    try internal.queries.ensureUnusedCapacity(internal.allocator, 1);
    const task = try registry.allocator.create(QueryTask);
    query.* = .{ .id = internal.next_query, .promise = promise, .snapshot = snapshot, .realm = realm };
    internal.next_query += 1;
    promise_owned = false;
    snapshot_owned = false;
    internal.queries.appendAssumeCapacity(query);
    task.* = .{
        .allocator = registry.allocator,
        .manager = instance,
        .generation = runtime.SlabAllocator.generationOf(instance),
        .id = query.id,
    };
    // Dropped unrun - the loop ended - the query stays listed, and goes with
    // this object.
    _ = sink.post(.{ .run = QueryTask.run, .drop = QueryTask.drop, .data = task });
    // "6. Return promise."
    return result.take();
}

/// A query() whose promise waits for its task: the snapshot taken when it
/// was called, and the realm its result is made in.
const Query = struct {
    id: u64,
    promise: engine.PromiseCapability,
    /// Owned.
    snapshot: web_locks.Snapshot,
    realm: runtime.Context,

    fn destroy(self: *Query, allocator: std.mem.Allocator) void {
        engine.releasePromiseCapability(&self.promise);
        self.snapshot.deinit(allocator);
        allocator.destroy(self);
    }
};

/// Section 4.5 step 6, "resolve promise with «[ "held" → held, "pending" →
/// pending ]»", as a task of the LockManager's realm.
const QueryTask = struct {
    allocator: std.mem.Allocator,
    manager: *runtime.Instance,
    generation: u64,
    id: u64,

    fn live(self: *const QueryTask) ?*runtime.Instance {
        if (runtime.SlabAllocator.generationOf(self.manager) != self.generation) return null;
        return self.manager;
    }

    /// Never run: its loop has ended. Any thread; no engine.
    fn drop(data: ?*anyopaque) void {
        const self: *QueryTask = @ptrCast(@alignCast(data orelse return));
        self.allocator.destroy(self);
    }

    fn run(data: ?*anyopaque) void {
        const self: *QueryTask = @ptrCast(@alignCast(data orelse return));
        defer self.allocator.destroy(self);
        const manager = self.live() orelse return;
        engine.runTaskInRealm(manager.ctx, steps, self) catch |err| {
            log.debug("query answer not run: {s}", .{@errorName(err)});
        };
    }

    fn steps(data: ?*anyopaque) void {
        const self: *QueryTask = @ptrCast(@alignCast(data orelse return));
        const manager = self.live() orelse return;
        const internal = getInternal(manager) orelse return;
        const query = for (internal.queries.items, 0..) |listed, i| {
            if (listed.id == self.id) break internal.queries.orderedRemove(i);
        } else return;
        defer query.destroy(internal.allocator);
        const value = snapshotObject(query.realm, query.snapshot, internal.allocator) catch return;
        defer value.release();
        engine.resolvePromise(&query.promise, value.borrow()) catch {};
    }
};

/// Section 4.5 step 6's «[ "held" → held, "pending" → pending ]», as the
/// LockManagerSnapshot dictionary it converts to. OWNED.
fn snapshotObject(realm: runtime.Context, snapshot: web_locks.Snapshot, allocator: std.mem.Allocator) !engine.Owned {
    const held = try infoSequence(realm, snapshot.held, allocator);
    defer held.release();
    const pending = try infoSequence(realm, snapshot.pending, allocator);
    defer pending.release();
    return engine.createDictionaryObject(realm, &.{
        .{ .name = "held", .value = held.borrow() },
        .{ .name = "pending", .value = pending.borrow() },
    });
}

/// A sequence<LockInfo>. OWNED.
fn infoSequence(realm: runtime.Context, infos: []const web_locks.Info, allocator: std.mem.Allocator) !engine.Owned {
    const objects = try allocator.alloc(engine.Owned, infos.len);
    defer allocator.free(objects);
    var made: usize = 0;
    defer {
        for (objects[0..made]) |object| object.release();
    }
    for (infos) |info| {
        // LockInfo's members, in the dictionary's (lexicographic) order.
        objects[made] = try engine.createDictionaryObject(realm, &.{
            .{ .name = "clientId", .value = runtime.JSValue.fromStringRef(&info.client_id) },
            .{ .name = "mode", .value = runtime.JSValue.fromStringRef(@tagName(info.mode)) },
            .{ .name = "name", .value = runtime.JSValue.fromStringRef(info.name) },
        });
        made += 1;
    }
    const values = try allocator.alloc(runtime.JSValue, made);
    defer allocator.free(values);
    for (objects[0..made], values) |object, *value| value.* = object.borrow();
    return engine.createSequenceOfValues(realm, values);
}
