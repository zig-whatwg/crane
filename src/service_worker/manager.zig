//! A Browser's service workers: its registry (registry.zig) under one lock,
//! the job thread that runs the spec's "in parallel" steps that wait, and the
//! service worker threads it starts. A supplement of the Browser's scope
//! (runtime.BrowserScope, docs/instances.md rule 2): registrations, their
//! service workers and the clients that see them are a profile's state, so
//! two Browsers share none, and every tab, frame and worker of one Browser
//! shares its.
//!
//! Threads (tmp/plans/sw1-design.md):
//! - A realm's own thread - a window's, a worker's - runs the short atomic
//!   steps under the lock: Start Register's checks are done before, then
//!   Create Job and Schedule Job, Match Service Worker Registration, the
//!   registration map's reads, an environment's arrival and its end
//!   (Handle Service Worker Client Unload).
//! - The job thread - an html.WorkerThread whose host makes no agent,
//!   registered in the Browser's WorkerRegistry, so the Browser's end
//!   terminates and joins it before the realms' teardown - runs Run Job, the
//!   Update algorithm's script fetch (without the lock), the start of each
//!   service worker thread (Run Service Worker steps 7-9), and every report a
//!   service worker thread sends back: its start status, the end of an
//!   install or activate event's extended lifetime, its extended events,
//!   skipWaiting() and claim(), its end. It ends the service worker threads
//!   it started (their links' owner sink is its loop's: WorkerThread step b).
//! - A service worker's own thread runs its script and its events (html's
//!   worker host, `Host.start`); what it learns goes to the job thread as a
//!   task, never straight into the registry - a report may end the worker it
//!   came from (Activate step 2), which only another thread may do.
//!
//! What the registry hands to a realm is a Delivery - a Message with its
//! strings copied - posted to the realm's sink (`Endpoint`), which runs it on
//! the realm's thread if the environment is still there: it looks the
//! environment up by id under the lock, and an environment ends only on its
//! own thread.
//!
//! Nothing here touches an engine: realms are reached through Endpoints, and
//! service worker threads through `Host` (production: run.zig).
//!
//! Spec: https://w3c.github.io/ServiceWorker/#algorithms

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const platform = @import("platform");
const html = @import("html");
const registry_mod = @import("registry.zig");

const Registry = registry_mod.Registry;
const TaskSink = runtime.TaskSink;
const WorkerLink = html.WorkerLink;

const log = std.log.scoped(.service_worker);

pub const WorkerState = registry_mod.WorkerState;
pub const Slot = registry_mod.Slot;
pub const ErrorKind = registry_mod.ErrorKind;
pub const LifecycleEvent = registry_mod.LifecycleEvent;

/// A service worker as a realm sees it when it makes its ServiceWorker
/// object ("get the service worker object" step 2). OWNED.
pub const WorkerInfo = struct {
    id: u64,
    script_url: []u8,
    state: WorkerState,

    pub fn of(allocator: Allocator, snapshot: registry_mod.WorkerSnapshot) Allocator.Error!WorkerInfo {
        return .{ .id = snapshot.id, .script_url = try allocator.dupe(u8, snapshot.script_url), .state = snapshot.state };
    }

    pub fn deinit(self: *WorkerInfo, allocator: Allocator) void {
        allocator.free(self.script_url);
    }
};

/// A registration as a realm makes its ServiceWorkerRegistration object from
/// it ("get the service worker registration object" steps 2.1-2.8). OWNED.
pub const RegistrationInfo = struct {
    id: u64,
    scope_url: []u8,
    /// The registration's storage key (its origin, serialized).
    storage_key: []u8,
    update_via_cache: registry_mod.UpdateViaCache,
    installing: ?WorkerInfo = null,
    waiting: ?WorkerInfo = null,
    active: ?WorkerInfo = null,

    pub fn of(allocator: Allocator, registration: *const registry_mod.Registration) Allocator.Error!RegistrationInfo {
        const snapshot = Registry.snapshotRegistration(registration);
        var info: RegistrationInfo = .{
            .id = snapshot.id,
            .scope_url = try allocator.dupe(u8, snapshot.scope_url),
            .storage_key = undefined,
            .update_via_cache = snapshot.update_via_cache,
        };
        errdefer allocator.free(info.scope_url);
        info.storage_key = try allocator.dupe(u8, registration.storage_key);
        errdefer info.deinitWorkers(allocator);
        if (snapshot.installing) |w| info.installing = try WorkerInfo.of(allocator, w);
        if (snapshot.waiting) |w| info.waiting = try WorkerInfo.of(allocator, w);
        if (snapshot.active) |w| info.active = try WorkerInfo.of(allocator, w);
        return info;
    }

    fn deinitWorkers(self: *RegistrationInfo, allocator: Allocator) void {
        if (self.installing) |*w| w.deinit(allocator);
        if (self.waiting) |*w| w.deinit(allocator);
        if (self.active) |*w| w.deinit(allocator);
        self.installing = null;
        self.waiting = null;
        self.active = null;
    }

    pub fn deinit(self: *RegistrationInfo, allocator: Allocator) void {
        self.deinitWorkers(allocator);
        allocator.free(self.scope_url);
        allocator.free(self.storage_key);
    }
};

/// A registry Message, its strings copied, as it crosses to a realm's
/// thread. OWNED (`deinit`).
pub const Delivery = union(enum) {
    resolve_registration: struct { promise: u64, registration: RegistrationInfo },
    resolve_boolean: struct { promise: u64, value: bool },
    resolve_undefined: struct { promise: u64 },
    /// `message` is static text.
    reject: struct { promise: u64, kind: ErrorKind, message: []const u8 },
    worker_state: struct { worker: u64, state: WorkerState },
    registration_slot: struct { registration: u64, slot: Slot, worker: ?WorkerInfo },
    update_found: struct { registration: u64 },
    controller_change,
    ready: RegistrationInfo,
    /// getRegistration() step 8.2: the registration matched, or undefined.
    resolve_optional_registration: struct { promise: u64, registration: ?RegistrationInfo },
    /// getRegistrations() step 4.3: the registrations of the client's
    /// storage key. OWNED, each and the slice.
    resolve_registrations: struct { promise: u64, registrations: []RegistrationInfo },

    /// `message`, copied - with the registry's lock held (its borrowed
    /// strings are valid until then). `registration`: the record a
    /// registration message names, for its storage key.
    fn of(allocator: Allocator, registry: *const Registry, message: registry_mod.Message) Allocator.Error!Delivery {
        return switch (message) {
            .resolve_registration => |m| .{ .resolve_registration = .{
                .promise = m.promise,
                .registration = try infoOfSnapshot(allocator, registry, m.registration),
            } },
            .resolve_boolean => |m| .{ .resolve_boolean = .{ .promise = m.promise, .value = m.value } },
            .resolve_undefined => |m| .{ .resolve_undefined = .{ .promise = m.promise } },
            .reject => |m| .{ .reject = .{ .promise = m.promise, .kind = m.kind, .message = m.message } },
            .worker_state => |m| .{ .worker_state = .{ .worker = m.worker, .state = m.state } },
            .registration_slot => |m| .{ .registration_slot = .{
                .registration = m.registration,
                .slot = m.slot,
                .worker = if (m.worker) |w| try WorkerInfo.of(allocator, w) else null,
            } },
            .update_found => |m| .{ .update_found = .{ .registration = m.registration } },
            .controller_change => .controller_change,
            .ready => |snapshot| .{ .ready = try infoOfSnapshot(allocator, registry, snapshot) },
        };
    }

    pub fn deinit(self: *Delivery, allocator: Allocator) void {
        switch (self.*) {
            .resolve_registration => |*m| m.registration.deinit(allocator),
            .registration_slot => |*m| if (m.worker) |*w| w.deinit(allocator),
            .ready => |*info| info.deinit(allocator),
            .resolve_optional_registration => |*m| if (m.registration) |*info| info.deinit(allocator),
            .resolve_registrations => |m| {
                for (m.registrations) |*info| info.deinit(allocator);
                allocator.free(m.registrations);
            },
            else => {},
        }
    }
};

/// A registration message's registration, copied from the record itself
/// (the snapshot carries no storage key). The record is there: the message
/// was made from it under the same lock.
fn infoOfSnapshot(allocator: Allocator, registry: *const Registry, snapshot: registry_mod.RegistrationSnapshot) Allocator.Error!RegistrationInfo {
    const registration = registry.findRegistration(snapshot.id) orelse return error.OutOfMemory;
    return RegistrationInfo.of(allocator, registration);
}

/// A realm's side of an environment: where Deliveries for it go. The realm
/// side (realm.zig) embeds it; the manager reads `sink` and calls `deliver`
/// only as described.
pub const Endpoint = struct {
    /// The realm's loop's inbox. BORROWED: the realm side holds a reference
    /// for as long as the environment is in the manager.
    sink: *TaskSink,
    /// The realm, as the realm side finds its environment again
    /// (`endpointOf`). Compared, never dereferenced here.
    realm: *const anyopaque,
    /// On the realm's thread, with the lock NOT held: act on `delivery`
    /// (BORROWED) for this environment.
    deliver: *const fn (endpoint: *Endpoint, delivery: *const Delivery) void,
};

/// What a service worker's thread starts with (Run Service Worker steps 7-9,
/// Setup ServiceWorkerGlobalScope). Every slice BORROWED for the call.
pub const WorkerStart = struct {
    worker_id: u64,
    registration_id: u64,
    script_url: []const u8,
    scope_url: []const u8,
    worker_type: registry_mod.WorkerType,
    /// The script resource: the main script's body.
    source: []const u8,
    /// The script resource's policy container (`Host.start` clones it), or
    /// null.
    policy: ?*anyopaque,
    force_bypass_cache: bool,
};

/// A started service worker thread, as the manager keeps it. Opaque but for
/// `link`.
pub const Started = struct {
    /// The worker's link (the manager's reference), or null for a host that
    /// runs no thread (tests).
    link: ?*WorkerLink,
    /// The host's handle on the worker (html's thread host).
    handle: ?*anyopaque = null,
};

/// How the manager reaches beyond the registry: the script fetch, and the
/// service worker threads. Production: run.zig. Each is called on the job
/// thread with the lock NOT held.
pub const Host = struct {
    /// Update step 7: perform `plan`'s fetch, and the byte-for-byte checks.
    fetch: *const fn (manager: *Manager, plan: *const registry_mod.FetchPlan) registry_mod.FetchOutcome,
    /// Run Service Worker steps 7-9: start the worker on a thread of its own.
    /// Its start status comes back as `reportEvaluated`, its end as
    /// `reportEnded`.
    start: *const fn (manager: *Manager, start: *const WorkerStart) anyerror!Started,
    /// Queue the task that fires `event` at the worker's global object and
    /// waits for its extended lifetime; its end comes back as
    /// `reportLifecycleDone(op, ...)` - also when the task never runs.
    dispatch: *const fn (manager: *Manager, started: Started, event: LifecycleEvent, op: u64) void,
};

/// A service worker the manager started, until its thread has ended.
const Running = struct {
    worker_id: u64,
    /// Null while the job thread is starting it.
    started: ?Started = null,
    /// Terminate Service Worker was asked for before its thread existed.
    terminate_requested: bool = false,
    /// Bumped by every event dispatched to it: an idle check armed before
    /// finds another.
    epoch: u64 = 0,
};

pub const Manager = struct {
    allocator: Allocator,
    /// Protects every field below but `host`, `idle_timeout_ms`, the job
    /// thread's fields and `closed`. Never held across a fetch, a thread's
    /// join, or a Delivery.
    mutex: std.Io.Mutex = .init,
    /// Protects the start of the job thread and `closed`. Taken with
    /// `mutex` held or not (an effect posts to the job thread; so does a
    /// report from a service worker's thread), never the other way round.
    job_lock: std.Io.Mutex = .init,
    registry: Registry,
    /// The Browser's scope, once a realm has reached the manager (`of`).
    /// BORROWED. Null for a manager a test makes.
    scope: ?*runtime.BrowserScope = null,
    host: *const Host = &@import("run.zig").host,
    /// How long a running worker with no event to handle lives on (2.1.1):
    /// Chromium's idle timeout.
    idle_timeout_ms: u64 = 30_000,
    /// "The timed out flag ... is set after an optional user agent imposed
    /// delay if the pending promises count is greater than zero" (4.4): an
    /// install or activate event still extended after this long times out -
    /// it fails, and its worker is terminated. Chromium's request timeout
    /// (ServiceWorkerVersion kRequestTimeout, 5 minutes). Without it a worker
    /// whose waitUntil() never settles holds its job queue - and its thread -
    /// for the Browser's life.
    lifecycle_timeout_ms: u64 = 5 * 60_000,
    /// "A user agent may terminate service workers at any time it ... detects
    /// abnormal operation: such as infinite loops" (2.1.1): a worker whose
    /// script has not finished evaluating after this long is terminated, and
    /// its start fails. Chromium's start timeout (5 minutes).
    start_timeout_ms: u64 = 5 * 60_000,
    /// The job thread's link (the manager's reference), once started.
    job_link: ?*WorkerLink = null,
    /// The job thread's loop, while it runs. Read only on the job thread.
    job_loop: ?*html.WorkerEventLoop = null,
    /// Where the job thread's end is posted: no loop runs it; the manager's
    /// end drops it.
    owner_sink: ?*TaskSink = null,
    /// The Browser is ending: no job thread starts.
    closed: bool = false,
    running: std.ArrayListUnmanaged(Running) = .empty,
    /// The Browser's cookie jar, as the first environment's settings object
    /// reaches it (Browser-lifetime): a service worker global's.
    cookie_jar: ?*@import("fetch").internal.CookieJar = null,

    /// A BrowserScope supplement's init: called with the scope's lock held,
    /// so it reaches nothing else.
    pub fn init(allocator: Allocator) Manager {
        var seed: u64 = undefined;
        platform.fillRandom(std.mem.asBytes(&seed));
        return .{
            .allocator = allocator,
            .registry = Registry.init(allocator, undefined, seed),
        };
    }

    /// The scope's end, after every thread was joined (Browser.deinit joins
    /// the WorkerRegistry's first) - or a test's.
    pub fn deinit(self: *Manager) void {
        if (self.job_link) |link| {
            // A manager no Browser ran (a test's): its job thread is ended
            // here. A Browser's was terminated and joined already.
            _ = link.terminate();
            link.join();
            if (self.scope) |scope| if (scope.existing(html.WorkerRegistry)) |r| r.unregister(link);
            link.release();
            self.job_link = null;
        }
        for (self.running.items) |entry| {
            if (entry.started) |started| if (started.link) |link| {
                _ = link.terminate();
                link.join();
                link.release();
            };
        }
        self.running.deinit(self.allocator);
        if (self.owner_sink) |sink| {
            sink.close();
            sink.release();
        }
        self.bindEffects();
        self.registry.deinit();
    }

    /// The manager of the Browser `realm` belongs to, made on first use;
    /// null for a realm with none.
    pub fn of(realm: runtime.Context) ?*Manager {
        const scope = realm.browserScope() orelse return null;
        const manager = scope.of(Manager) catch return null;
        std.Io.Threaded.mutexLock(&manager.mutex);
        defer std.Io.Threaded.mutexUnlock(&manager.mutex);
        if (manager.scope == null) manager.scope = scope;
        return manager;
    }

    /// The manager of `realm`'s Browser if one was made; never makes one.
    pub fn existingOf(realm: runtime.Context) ?*Manager {
        const scope = realm.browserScope() orelse return null;
        return scope.existing(Manager);
    }

    fn lock(self: *Manager) void {
        std.Io.Threaded.mutexLock(&self.mutex);
        self.bindEffects();
    }

    fn unlock(self: *Manager) void {
        std.Io.Threaded.mutexUnlock(&self.mutex);
    }

    /// The registry's effects reach this manager (its address is stable
    /// from the scope's allocation on).
    fn bindEffects(self: *Manager) void {
        self.registry.effects = .{
            .ctx = self,
            .notify = notify,
            .queue_run_job = queueRunJob,
            .start_worker = startWorker,
            .terminate_worker = terminateWorker,
            .dispatch_lifecycle = dispatchLifecycle,
            .start_answered = startAnswered,
            .free_fetch_client = freeFetchClient,
            .free_policy = freePolicy,
            .now_ms = nowMs,
            .idle = idle,
        };
    }

    // ------------------------------------------------------------------
    // A realm's steps (its own thread)
    // ------------------------------------------------------------------

    /// A realm reached the service worker API: it is an environment the
    /// registry tells of its registrations and workers. Its id.
    pub fn addEnvironment(self: *Manager, values: Registry.EnvironmentInit) Allocator.Error!u64 {
        self.lock();
        defer self.unlock();
        const environment = try self.registry.addEnvironment(values);
        return environment.id;
    }

    /// The environment `id` has ended (its realm's unloading cleanup):
    /// Handle Service Worker Client Unload, and it hears nothing more. Its
    /// endpoint is the caller's again.
    pub fn removeEnvironment(self: *Manager, id: u64) void {
        self.lock();
        defer self.unlock();
        const environment = self.registry.findEnvironment(id) orelse return;
        self.registry.removeEnvironment(environment);
    }

    /// Note the Browser's cookie jar, if none is noted yet.
    pub fn noteCookieJar(self: *Manager, jar: ?*@import("fetch").internal.CookieJar) void {
        self.lock();
        defer self.unlock();
        if (self.cookie_jar == null) self.cookie_jar = jar;
    }

    /// The endpoint of the environment whose realm is `realm`, if it is one.
    pub fn endpointOf(self: *Manager, realm: *const anyopaque) ?*Endpoint {
        self.lock();
        defer self.unlock();
        for (self.registry.environments.items) |environment| {
            const endpoint: *Endpoint = @ptrCast(@alignCast(environment.endpoint));
            if (endpoint.realm == realm) return endpoint;
        }
        return null;
    }

    /// Hand `delivery` (taken) to the environment `id` as a later task of
    /// its realm's loop - HTML "queue a task" for a result found now: the
    /// getRegistration(), getRegistrations() and ready steps. Dropped when
    /// the environment has gone.
    pub fn deliverLater(self: *Manager, id: u64, delivery: Delivery) void {
        var owned = delivery;
        self.lock();
        defer self.unlock();
        const environment = self.registry.findEnvironment(id) orelse return owned.deinit(self.allocator);
        const endpoint: *Endpoint = @ptrCast(@alignCast(environment.endpoint));
        const task = self.allocator.create(DeliveryTask) catch return owned.deinit(self.allocator);
        task.* = .{ .manager = self, .environment = id, .delivery = owned };
        _ = endpoint.sink.post(.{ .run = DeliveryTask.run, .drop = DeliveryTask.drop, .data = task });
    }

    /// Whether the service worker `id` is its registration's active worker
    /// (claim() step 1).
    pub fn isActiveWorker(self: *Manager, id: u64) bool {
        self.lock();
        defer self.unlock();
        const worker = self.registry.findWorker(id) orelse return false;
        return worker.registration.active == worker;
    }

    /// The environment `id`'s client id (a UUID), or null.
    pub fn clientIdOf(self: *Manager, id: u64) ?[36]u8 {
        self.lock();
        defer self.unlock();
        const environment = self.registry.findEnvironment(id) orelse return null;
        return environment.client_id;
    }

    /// Create Job and Schedule Job. Takes `values.client.fetch_client`
    /// whatever happens.
    pub fn schedule(self: *Manager, values: Registry.JobInit) Allocator.Error!void {
        self.lock();
        defer self.unlock();
        const job = self.registry.createJob(values) catch |err| {
            if (values.client) |client| if (client.fetch_client) |fc| freeFetchClient(self, fc);
            return err;
        };
        try self.registry.scheduleJob(job);
    }

    /// Match Service Worker Registration for `storage_key` and `client_url`
    /// (serialized), as a realm makes its object from it. OWNED.
    pub fn match(self: *Manager, allocator: Allocator, storage_key: []const u8, client_url: []const u8) Allocator.Error!?RegistrationInfo {
        self.lock();
        defer self.unlock();
        const registration = self.registry.matchRegistration(storage_key, client_url) orelse return null;
        return try RegistrationInfo.of(allocator, registration);
    }

    /// The ready attribute's in-parallel steps 3.1-3.4: the registration that
    /// matches the environment's creation URL, when its active worker is not
    /// null. OWNED.
    pub fn readyRegistration(self: *Manager, allocator: Allocator, storage_key: []const u8, client_url: []const u8) Allocator.Error!?RegistrationInfo {
        self.lock();
        defer self.unlock();
        const registration = self.registry.matchRegistration(storage_key, client_url) orelse return null;
        if (registration.active == null) return null;
        return try RegistrationInfo.of(allocator, registration);
    }

    /// getRegistrations() step 4: every registration of `storage_key`, in
    /// the registration map's order. OWNED, each and the slice.
    pub fn registrationsOf(self: *Manager, allocator: Allocator, storage_key: []const u8) Allocator.Error![]RegistrationInfo {
        self.lock();
        defer self.unlock();
        const registrations = try self.registry.registrationsOf(allocator, storage_key);
        defer allocator.free(registrations);
        const infos = try allocator.alloc(RegistrationInfo, registrations.len);
        var made: usize = 0;
        errdefer {
            for (infos[0..made]) |*info| info.deinit(allocator);
            allocator.free(infos);
        }
        for (registrations) |registration| {
            infos[made] = try RegistrationInfo.of(allocator, registration);
            made += 1;
        }
        return infos;
    }

    /// The registration `id` (in the map or not), as a realm makes its
    /// object from it. OWNED; null when it has gone.
    pub fn registrationInfo(self: *Manager, allocator: Allocator, id: u64) Allocator.Error!?RegistrationInfo {
        self.lock();
        defer self.unlock();
        const registration = self.registry.findRegistration(id) orelse return null;
        return try RegistrationInfo.of(allocator, registration);
    }

    /// The service worker `id`, as a realm makes its object from it. OWNED;
    /// null when it has gone.
    pub fn workerInfo(self: *Manager, allocator: Allocator, id: u64) Allocator.Error!?WorkerInfo {
        self.lock();
        defer self.unlock();
        const worker = self.registry.findWorker(id) orelse return null;
        return try WorkerInfo.of(allocator, Registry.snapshotWorker(worker));
    }

    /// The registration that contains the service worker `id`. OWNED; null
    /// when the worker has gone.
    pub fn registrationOfWorker(self: *Manager, allocator: Allocator, worker_id: u64) Allocator.Error!?RegistrationInfo {
        self.lock();
        defer self.unlock();
        const worker = self.registry.findWorker(worker_id) orelse return null;
        return try RegistrationInfo.of(allocator, worker.registration);
    }

    /// The `controller` attribute's step 2: the environment's active service
    /// worker. OWNED; null when it has none.
    pub fn controllerOf(self: *Manager, allocator: Allocator, environment_id: u64) Allocator.Error!?WorkerInfo {
        self.lock();
        defer self.unlock();
        const environment = self.registry.findEnvironment(environment_id) orelse return null;
        const worker = environment.active_worker orelse return null;
        return try WorkerInfo.of(allocator, Registry.snapshotWorker(worker));
    }

    /// What `update()` needs of the registration `id`: its storage key,
    /// scope url and newest worker (steps 2-7). Null when it has no newest
    /// worker - step 3's InvalidStateError.
    pub const UpdateTarget = struct {
        /// OWNED.
        storage_key: []u8,
        scope_url: []u8,
        script_url: []u8,
        worker_type: registry_mod.WorkerType,
        update_via_cache: registry_mod.UpdateViaCache,
        newest_state: WorkerState,

        pub fn deinit(self: *UpdateTarget, allocator: Allocator) void {
            allocator.free(self.storage_key);
            allocator.free(self.scope_url);
            allocator.free(self.script_url);
        }
    };

    pub fn updateTarget(self: *Manager, allocator: Allocator, registration_id: u64) Allocator.Error!?UpdateTarget {
        self.lock();
        defer self.unlock();
        const registration = self.registry.findRegistration(registration_id) orelse return null;
        const newest = Registry.getNewestWorker(registration) orelse return null;
        const storage_key = try allocator.dupe(u8, registration.storage_key);
        errdefer allocator.free(storage_key);
        const scope_url = try allocator.dupe(u8, registration.scope_url);
        errdefer allocator.free(scope_url);
        return .{
            .storage_key = storage_key,
            .scope_url = scope_url,
            .script_url = try allocator.dupe(u8, newest.script_url),
            .worker_type = newest.worker_type,
            .update_via_cache = registration.update_via_cache,
            .newest_state = newest.state,
        };
    }

    // ------------------------------------------------------------------
    // Reports from a service worker's thread (posted to the job thread)
    // ------------------------------------------------------------------

    /// What a service worker's thread reports.
    pub const Report = union(enum) {
        /// Run Service Worker step 9: its script was evaluated (`ok` false:
        /// it did not run to completion, or its global could not be made).
        evaluated: struct { worker: u64, ok: bool },
        /// The install or activate event `op` is no longer active, and its
        /// extend lifetime promises settled - `failed` when one rejected, it
        /// timed out, or its task was discarded.
        lifecycle_done: struct { op: u64, failed: bool },
        /// The worker's count of active extended events is now `active`.
        extended_events: struct { worker: u64, active: u32 },
        /// skipWaiting() in the worker: its promise is `promise` of the
        /// worker's own environment.
        skip_waiting: struct { worker: u64, environment: u64, promise: u64 },
        /// clients.claim() in the worker.
        claim: struct { worker: u64, environment: u64, promise: u64 },
    };

    /// Post `report` to the job thread. Any thread; a manager whose job
    /// thread has ended drops it.
    pub fn report(self: *Manager, from: Report) void {
        const task = self.allocator.create(ReportTask) catch {
            log.debug("out of memory posting a service worker's report; dropped", .{});
            return;
        };
        task.* = .{ .manager = self, .report = from };
        self.postToJobThread(.{ .run = ReportTask.run, .drop = ReportTask.drop, .data = task });
    }

    const ReportTask = struct {
        manager: *Manager,
        report: Report,

        fn run(data: ?*anyopaque) void {
            const self: *ReportTask = @ptrCast(@alignCast(data.?));
            const manager = self.manager;
            const from = self.report;
            manager.allocator.destroy(self);
            manager.handleReport(from) catch |err| log.debug("a service worker's report: {s}", .{@errorName(err)});
        }

        fn drop(data: ?*anyopaque) void {
            const self: *ReportTask = @ptrCast(@alignCast(data.?));
            self.manager.allocator.destroy(self);
        }
    };

    fn handleReport(self: *Manager, from: Report) Allocator.Error!void {
        self.lock();
        defer self.unlock();
        switch (from) {
            .evaluated => |r| try self.registry.workerEvaluated(r.worker, r.ok),
            .lifecycle_done => |r| try self.registry.lifecycleEventDone(r.op, r.failed),
            .extended_events => |r| try self.registry.extendedEventsChanged(r.worker, r.active),
            .skip_waiting => |r| {
                // skipWaiting() step 2.1-2.2, then 2.3's resolution.
                try self.registry.skipWaiting(r.worker);
                self.settle(r.environment, .{ .resolve_undefined = .{ .promise = r.promise } });
            },
            .claim => |r| {
                // claim() step 1 (checked again here: the worker may have
                // stopped being active since), step 3.
                self.registry.claim(r.worker) catch |err| switch (err) {
                    error.InvalidStateError => return self.settle(r.environment, .{ .reject = .{
                        .promise = r.promise,
                        .kind = .invalid_state_error,
                        .message = "The service worker is not the active worker",
                    } }),
                    error.OutOfMemory => return error.OutOfMemory,
                };
                self.settle(r.environment, .{ .resolve_undefined = .{ .promise = r.promise } });
            },
        }
    }

    /// Hand `message` to the environment `id`, if it is still there. Locked.
    fn settle(self: *Manager, id: u64, message: registry_mod.Message) void {
        const environment = self.registry.findEnvironment(id) orelse return;
        notify(self, environment, message);
    }

    /// importScripts() in the service worker `worker_id` (6.3.2), steps 1-8:
    /// on its own thread, under the lock.
    pub fn importStep(self: *Manager, worker_id: u64, url: []const u8) Allocator.Error!Registry.ImportStep {
        self.lock();
        defer self.unlock();
        return self.registry.importStep(worker_id, url);
    }

    /// importScripts()' fetch hook steps 10-14. Takes `resource`.
    pub fn addImportedScript(self: *Manager, worker_id: u64, resource: registry_mod.Resource, checked_network: bool) Allocator.Error!void {
        self.lock();
        defer self.unlock();
        return self.registry.addImportedScript(worker_id, resource, checked_network);
    }

    /// The service worker `worker_id`'s thread has ended, and its owner (the
    /// job thread) has joined it: it is not running. Job thread.
    pub fn reportEnded(self: *Manager, worker_id: u64) void {
        self.lock();
        defer self.unlock();
        self.forgetRunning(worker_id);
        self.registry.workerEnded(worker_id) catch |err| log.debug("a service worker's end: {s}", .{@errorName(err)});
    }

    fn forgetRunning(self: *Manager, worker_id: u64) void {
        for (self.running.items, 0..) |entry, i| {
            if (entry.worker_id != worker_id) continue;
            if (entry.started) |started| if (started.link) |link| link.release();
            _ = self.running.swapRemove(i);
            return;
        }
    }

    fn findRunning(self: *Manager, worker_id: u64) ?*Running {
        for (self.running.items) |*entry| if (entry.worker_id == worker_id) return entry;
        return null;
    }

    // ------------------------------------------------------------------
    // The job thread
    // ------------------------------------------------------------------

    /// Post `task` to the job thread, starting it on first use. A Browser
    /// that is ending runs none: the task is dropped. Locked or not.
    fn postToJobThread(self: *Manager, task: runtime.CrossThreadTask) void {
        const link = self.jobLink() orelse return task.drop(task.data);
        // A closed sink - the thread is ending - drops it.
        _ = link.worker_sink.post(task);
    }

    /// The job thread's link, made and started on first use.
    fn jobLink(self: *Manager) ?*WorkerLink {
        // The link is set once, under its own lock below, and lives until
        // the manager's end: read it with an acquire load.
        if (@atomicLoad(?*WorkerLink, &self.job_link, .acquire)) |link| return link;
        std.Io.Threaded.mutexLock(&self.job_lock);
        defer std.Io.Threaded.mutexUnlock(&self.job_lock);
        if (self.job_link) |link| return link;
        if (self.closed) return null;
        return self.startJobThread() catch |err| {
            log.debug("the service worker job thread did not start: {s}", .{@errorName(err)});
            self.closed = true;
            return null;
        };
    }

    fn startJobThread(self: *Manager) !*WorkerLink {
        const owner_sink = self.owner_sink orelse blk: {
            const sink = try TaskSink.create(self.allocator);
            self.owner_sink = sink;
            break :blk sink;
        };
        const link = try WorkerLink.create(self.allocator, owner_sink);
        errdefer link.release();
        const registry: ?*html.WorkerRegistry = if (self.scope) |scope| scope.of(html.WorkerRegistry) catch null else null;
        if (registry) |r| try r.register(link);
        errdefer if (registry) |r| r.unregister(link);
        try html.WorkerThread.spawn(self.allocator, link, .{
            .data = self,
            .start = jobThreadStart,
            .end_realm = jobThreadEnd,
            .free = jobThreadFree,
        }, .{ .data = null, .ended = jobThreadEnded, .drop = jobThreadEnded }, registry);
        @atomicStore(?*WorkerLink, &self.job_link, link, .release);
        return link;
    }

    /// The job thread's start: no agent, no realm - its loop runs the
    /// manager's tasks.
    fn jobThreadStart(data: ?*anyopaque, thread: *html.WorkerThread) bool {
        const self: *Manager = @ptrCast(@alignCast(data.?));
        self.job_loop = &thread.loop;
        return true;
    }

    /// The job thread's loop has stopped: its idle checks go with its timers.
    fn jobThreadEnd(data: ?*anyopaque, _: *html.WorkerThread) void {
        const self: *Manager = @ptrCast(@alignCast(data.?));
        self.job_loop = null;
    }

    fn jobThreadFree(_: ?*anyopaque) void {}

    /// The job thread's end, posted to `owner_sink`, which no loop runs: it
    /// is dropped at the manager's end, which joins the thread.
    fn jobThreadEnded(_: ?*anyopaque, _: *WorkerLink) void {}

    /// Run Job's task (step 2): the queue's first job runs; a register or
    /// update job that reaches its fetch fetches here, without the lock.
    const RunJobTask = struct {
        manager: *Manager,
        /// OWNED.
        scope_url: []u8,

        fn run(data: ?*anyopaque) void {
            const self: *RunJobTask = @ptrCast(@alignCast(data.?));
            const manager = self.manager;
            defer self.destroy();
            manager.runJob(self.scope_url) catch |err| log.debug("Run Job: {s}", .{@errorName(err)});
        }

        fn drop(data: ?*anyopaque) void {
            const self: *RunJobTask = @ptrCast(@alignCast(data.?));
            self.destroy();
        }

        fn destroy(self: *RunJobTask) void {
            const allocator = self.manager.allocator;
            allocator.free(self.scope_url);
            allocator.destroy(self);
        }
    };

    fn runJob(self: *Manager, scope_url: []const u8) Allocator.Error!void {
        var plan = blk: {
            self.lock();
            defer self.unlock();
            break :blk (try self.registry.runJob(scope_url)) orelse return;
        };
        defer plan.deinit(self.allocator);
        // Update step 7: the fetch, with the lock not held (the job stays
        // first in its queue; nothing else runs it).
        var outcome = self.host.fetch(self, &plan);
        self.lock();
        defer self.unlock();
        try self.registry.updateFetched(plan.job, &outcome);
    }

    /// Run Service Worker steps 7-9, on the job thread.
    const StartTask = struct {
        manager: *Manager,
        worker_id: u64,
        force_bypass_cache: bool,

        fn run(data: ?*anyopaque) void {
            const self: *StartTask = @ptrCast(@alignCast(data.?));
            const manager = self.manager;
            const worker_id = self.worker_id;
            const force = self.force_bypass_cache;
            manager.allocator.destroy(self);
            manager.startNow(worker_id, force);
        }

        fn drop(data: ?*anyopaque) void {
            const self: *StartTask = @ptrCast(@alignCast(data.?));
            self.manager.allocator.destroy(self);
        }
    };

    fn startNow(self: *Manager, worker_id: u64, force_bypass_cache: bool) void {
        // What the thread starts with, copied under the lock.
        var copied = blk: {
            self.lock();
            defer self.unlock();
            const worker = self.registry.findWorker(worker_id) orelse return;
            if (worker.run != .starting) return;
            break :blk StartCopy.of(self.allocator, worker, force_bypass_cache) catch {
                self.registry.workerEnded(worker_id) catch {};
                return;
            };
        };
        defer copied.deinit(self.allocator);
        const started = self.host.start(self, &copied.start) catch |err| {
            log.debug("a service worker's thread did not start: {s}", .{@errorName(err)});
            self.lock();
            defer self.unlock();
            self.forgetRunning(worker_id);
            self.registry.workerEnded(worker_id) catch {};
            return;
        };
        self.lock();
        defer self.unlock();
        const entry = self.findRunning(worker_id) orelse {
            // Never recorded (no memory): its end finds nothing to forget.
            if (started.link) |link| {
                _ = link.terminate();
                link.release();
            }
            return;
        };
        entry.started = started;
        if (entry.terminate_requested) if (started.link) |link| {
            _ = link.terminate();
        };
        // The start's timeout: an evaluation that never ends is aborted.
        const check = self.allocator.create(StartTimeout) catch return;
        check.* = .{ .manager = self, .worker_id = worker_id, .epoch = entry.epoch };
        const loop = self.job_loop orelse return self.allocator.destroy(check);
        if (loop.timerInterface().setTimeoutOwned(self.start_timeout_ms, StartTimeout.fire, check, StartTimeout.drop) == 0) {
            self.allocator.destroy(check);
        }
    }

    /// A service worker's start that has not answered in `start_timeout_ms`.
    const StartTimeout = struct {
        manager: *Manager,
        worker_id: u64,
        epoch: u64,

        fn drop(data: ?*anyopaque) void {
            const self: *StartTimeout = @ptrCast(@alignCast(data.?));
            self.manager.allocator.destroy(self);
        }

        fn fire(data: ?*anyopaque) void {
            const self: *StartTimeout = @ptrCast(@alignCast(data.?));
            const manager = self.manager;
            const worker_id = self.worker_id;
            const epoch = self.epoch;
            manager.allocator.destroy(self);
            manager.lock();
            defer manager.unlock();
            const entry = manager.findRunning(worker_id) orelse return;
            if (entry.epoch != epoch) return;
            const worker = manager.registry.findWorker(worker_id) orelse return;
            if (worker.run != .starting) return;
            log.debug("service worker {d} did not finish evaluating; terminated", .{worker_id});
            terminateWorker(manager, worker);
        }
    };

    const StartCopy = struct {
        start: WorkerStart,

        fn of(allocator: Allocator, worker: *const registry_mod.Worker, force: bool) Allocator.Error!StartCopy {
            const script_url = try allocator.dupe(u8, worker.script_url);
            errdefer allocator.free(script_url);
            const scope_url = try allocator.dupe(u8, worker.registration.scope_url);
            errdefer allocator.free(scope_url);
            const main = worker.mainScript();
            const source = try allocator.dupe(u8, if (main) |m| m.body else "");
            return .{ .start = .{
                .worker_id = worker.id,
                .registration_id = worker.registration.id,
                .script_url = script_url,
                .scope_url = scope_url,
                .worker_type = worker.worker_type,
                .source = source,
                .policy = worker.policy,
                .force_bypass_cache = force,
            } };
        }

        fn deinit(self: *StartCopy, allocator: Allocator) void {
            allocator.free(self.start.script_url);
            allocator.free(self.start.scope_url);
            allocator.free(self.start.source);
        }
    };

    // ------------------------------------------------------------------
    // Idle termination (2.1.1)
    // ------------------------------------------------------------------

    const IdleCheck = struct {
        manager: *Manager,
        worker_id: u64,
        epoch: u64,

        /// On the job thread: arm the check.
        fn arm(data: ?*anyopaque) void {
            const self: *IdleCheck = @ptrCast(@alignCast(data.?));
            const manager = self.manager;
            const loop = manager.job_loop orelse return manager.allocator.destroy(self);
            if (loop.timerInterface().setTimeoutOwned(manager.idle_timeout_ms, fire, self, dropArmed) == 0) {
                manager.allocator.destroy(self);
            }
        }

        fn dropPosted(data: ?*anyopaque) void {
            const self: *IdleCheck = @ptrCast(@alignCast(data.?));
            self.manager.allocator.destroy(self);
        }

        fn dropArmed(data: ?*anyopaque) void {
            dropPosted(data);
        }

        /// The idle timeout passed: terminate the worker if it is still idle
        /// and nothing was dispatched to it since.
        fn fire(data: ?*anyopaque) void {
            const self: *IdleCheck = @ptrCast(@alignCast(data.?));
            const manager = self.manager;
            const worker_id = self.worker_id;
            const epoch = self.epoch;
            manager.allocator.destroy(self);
            manager.lock();
            defer manager.unlock();
            const entry = manager.findRunning(worker_id) orelse return;
            if (entry.epoch != epoch) return;
            const worker = manager.registry.findWorker(worker_id) orelse return;
            if (!manager.registry.isIdle(worker)) return;
            terminateWorker(manager, worker);
        }
    };

    /// An install or activate event's timeout (`lifecycle_timeout_ms`).
    const LifecycleTimeout = struct {
        manager: *Manager,
        op: u64,
        worker_id: u64,

        fn arm(data: ?*anyopaque) void {
            const self: *LifecycleTimeout = @ptrCast(@alignCast(data.?));
            const manager = self.manager;
            const loop = manager.job_loop orelse return manager.allocator.destroy(self);
            if (loop.timerInterface().setTimeoutOwned(manager.lifecycle_timeout_ms, fire, self, dropPosted) == 0) {
                manager.allocator.destroy(self);
            }
        }

        fn dropPosted(data: ?*anyopaque) void {
            const self: *LifecycleTimeout = @ptrCast(@alignCast(data.?));
            self.manager.allocator.destroy(self);
        }

        /// Still extended: timed out - the event fails (Install step
        /// 11.3.1.4.2: installFailed), and the worker is terminated.
        fn fire(data: ?*anyopaque) void {
            const self: *LifecycleTimeout = @ptrCast(@alignCast(data.?));
            const manager = self.manager;
            const op = self.op;
            const worker_id = self.worker_id;
            manager.allocator.destroy(self);
            manager.lock();
            defer manager.unlock();
            if (manager.registry.opWorker(op) == null) return;
            log.debug("a lifecycle event of service worker {d} timed out", .{worker_id});
            manager.registry.lifecycleEventDone(op, true) catch {};
            if (manager.registry.findWorker(worker_id)) |worker| terminateWorker(manager, worker);
        }
    };

    // ------------------------------------------------------------------
    // The registry's effects (lock held)
    // ------------------------------------------------------------------

    fn ofCtx(ctx: *anyopaque) *Manager {
        return @ptrCast(@alignCast(ctx));
    }

    fn notify(ctx: *anyopaque, environment: *registry_mod.Environment, message: registry_mod.Message) void {
        const self = ofCtx(ctx);
        const endpoint: *Endpoint = @ptrCast(@alignCast(environment.endpoint));
        const task = self.allocator.create(DeliveryTask) catch return;
        task.* = .{
            .manager = self,
            .environment = environment.id,
            .delivery = Delivery.of(self.allocator, &self.registry, message) catch {
                self.allocator.destroy(task);
                log.debug("out of memory copying a message for a realm; dropped", .{});
                return;
            },
        };
        // A closed sink - the realm's loop has ended - drops it.
        _ = endpoint.sink.post(.{ .run = DeliveryTask.run, .drop = DeliveryTask.drop, .data = task });
    }

    fn queueRunJob(ctx: *anyopaque, scope_url: []const u8) void {
        const self = ofCtx(ctx);
        const task = self.allocator.create(RunJobTask) catch return;
        task.* = .{ .manager = self, .scope_url = self.allocator.dupe(u8, scope_url) catch {
            self.allocator.destroy(task);
            return;
        } };
        self.postToJobThread(.{ .run = RunJobTask.run, .drop = RunJobTask.drop, .data = task });
    }

    fn startWorker(ctx: *anyopaque, worker: *registry_mod.Worker, force_bypass_cache: bool) void {
        const self = ofCtx(ctx);
        // Recorded now, so a termination asked for before the thread exists
        // is kept.
        self.running.append(self.allocator, .{ .worker_id = worker.id }) catch {};
        const task = self.allocator.create(StartTask) catch return;
        task.* = .{ .manager = self, .worker_id = worker.id, .force_bypass_cache = force_bypass_cache };
        self.postToJobThread(.{ .run = StartTask.run, .drop = StartTask.drop, .data = task });
    }

    fn terminateWorker(ctx: *anyopaque, worker: *registry_mod.Worker) void {
        const self = ofCtx(ctx);
        const entry = self.findRunning(worker.id) orelse return;
        const started = entry.started orelse {
            entry.terminate_requested = true;
            return;
        };
        // Terminate Service Worker steps 1.2-1.5: the closing flag, the
        // tasks discarded, the running script aborted - "terminate a worker"
        // on its thread. Its end comes back as reportEnded.
        if (started.link) |link| _ = link.terminate();
    }

    fn dispatchLifecycle(ctx: *anyopaque, worker: *registry_mod.Worker, event: LifecycleEvent, op: u64) void {
        const self = ofCtx(ctx);
        const entry = self.findRunning(worker.id) orelse return;
        entry.epoch +%= 1;
        const started = entry.started orelse return;
        self.host.dispatch(self, started, event, op);
        // Its timeout, armed on the job thread.
        const task = self.allocator.create(LifecycleTimeout) catch return;
        task.* = .{ .manager = self, .op = op, .worker_id = worker.id };
        self.postToJobThread(.{ .run = LifecycleTimeout.arm, .drop = LifecycleTimeout.dropPosted, .data = task });
    }

    fn startAnswered(_: *anyopaque, _: *registry_mod.Worker, _: u64, _: bool) void {}

    fn freeFetchClient(ctx: *anyopaque, fetch_client: *anyopaque) void {
        _ = ctx;
        @import("run.zig").FetchClient.destroy(@ptrCast(@alignCast(fetch_client)));
    }

    fn freePolicy(ctx: *anyopaque, policy: *anyopaque) void {
        _ = ctx;
        @import("run.zig").destroyPolicy(policy);
    }

    fn nowMs(_: *anyopaque) i64 {
        return platform.wallMillis();
    }

    fn idle(ctx: *anyopaque, worker: *registry_mod.Worker) void {
        const self = ofCtx(ctx);
        const entry = self.findRunning(worker.id) orelse return;
        const task = self.allocator.create(IdleCheck) catch return;
        task.* = .{ .manager = self, .worker_id = worker.id, .epoch = entry.epoch };
        self.postToJobThread(.{ .run = IdleCheck.arm, .drop = IdleCheck.dropPosted, .data = task });
    }
};

/// A Delivery for one environment, as a task of its realm's loop.
const DeliveryTask = struct {
    manager: *Manager,
    environment: u64,
    delivery: Delivery,

    /// On the realm's thread: deliver, if the environment is still there.
    fn run(data: ?*anyopaque) void {
        const self: *DeliveryTask = @ptrCast(@alignCast(data.?));
        const manager = self.manager;
        defer self.destroy();
        const endpoint = blk: {
            manager.lock();
            defer manager.unlock();
            const environment = manager.registry.findEnvironment(self.environment) orelse return;
            break :blk @as(*Endpoint, @ptrCast(@alignCast(environment.endpoint)));
        };
        // The environment ends only on this thread: it is there for the call
        // (the realm side guards its own end inside it).
        endpoint.deliver(endpoint, &self.delivery);
    }

    fn drop(data: ?*anyopaque) void {
        const self: *DeliveryTask = @ptrCast(@alignCast(data.?));
        self.destroy();
    }

    fn destroy(self: *DeliveryTask) void {
        const allocator = self.manager.allocator;
        self.delivery.deinit(allocator);
        allocator.destroy(self);
    }
};
