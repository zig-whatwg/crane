//! A Browser's service worker state and the algorithms of Service Workers
//! Appendix A that change it: the registration map, the scope to job queue
//! map, the service workers, the environments that see them, and Create /
//! Schedule / Run / Finish Job, Register, Update, Install, Activate, Try
//! Activate, Unregister, Clear Registration, Update Registration State,
//! Update Worker State, Match Service Worker Registration, Get Registration
//! and Get Newest Worker.
//!
//! The spec runs these "in parallel" and "atomically". Here they run with
//! the owner's lock held (`Manager`), on whichever thread calls them, and
//! never block: what an algorithm waits for - a script fetched, a service
//! worker started, an install or activate event's extended lifetime - is an
//! `Effects` request whose answer comes back later as another call
//! (`updateFetched`, `workerEvaluated`, `lifecycleEventDone`, `workerEnded`),
//! and the algorithm resumes from the record it left (a Job, an
//! InstallOp, an ActivateOp). What an algorithm hands to a realm - a job
//! promise settled, a ServiceWorker object's state, a registration's
//! installing worker, updatefound, controllerchange, ready - is a `Message`
//! to that realm's Environment, which the owner posts as a task of the
//! realm's event loop.
//!
//! Records are found by id from outside: a realm's ServiceWorker and
//! ServiceWorkerRegistration objects name their worker and registration by
//! id, and a lookup that finds nothing reads as a redundant worker or an
//! unregistered registration. Inside, records are reference counted under
//! the owner's lock: a registration by the map and by each of its workers,
//! a worker by its registration's slots, by the clients it controls, and
//! while it runs.
//!
//! Nothing here touches a thread, a realm or an engine (tests/service_worker
//! drives it with std.testing).
//!
//! Spec: https://w3c.github.io/ServiceWorker/#algorithms

const std = @import("std");
const Allocator = std.mem.Allocator;
const scope_mod = @import("scope.zig");
const router = @import("router.zig");

const log = std.log.scoped(.service_worker);

pub const WorkerState = enum { parsed, installing, installed, activating, activated, redundant };
pub const WorkerType = enum { classic, module };
pub const UpdateViaCache = enum { imports, all, none };
pub const JobType = enum { register, update, unregister };
pub const Slot = enum { installing, waiting, active };
pub const LifecycleEvent = enum { install, activate };

/// What kind of global an environment's is (Service Workers 2.4: a window
/// client, a dedicated or shared worker client; a service worker's own
/// global is an environment that sees service worker objects, and no
/// client).
pub const EnvironmentKind = enum {
    window,
    dedicated_worker,
    shared_worker,
    service_worker,

    pub fn isClient(self: EnvironmentKind) bool {
        return self != .service_worker;
    }
};

/// Client's frame type (4.2).
pub const FrameType = enum { auxiliary, @"top-level", nested, none };

/// The exceptions an algorithm rejects a job promise with.
pub const ErrorKind = enum { type_error, security_error, invalid_state_error, invalid_access_error, not_supported_error };

/// One response a service worker keeps in its script resource map: what
/// importScripts() is answered from once installed, and what the Update
/// algorithm compares byte for byte. OWNED strings.
pub const Resource = struct {
    url: []u8,
    body: []u8,
    content_type: []u8,

    pub fn clone(self: Resource, allocator: Allocator) Allocator.Error!Resource {
        const url = try allocator.dupe(u8, self.url);
        errdefer allocator.free(url);
        const body = try allocator.dupe(u8, self.body);
        errdefer allocator.free(body);
        return .{ .url = url, .body = body, .content_type = try allocator.dupe(u8, self.content_type) };
    }

    pub fn deinit(self: *Resource, allocator: Allocator) void {
        allocator.free(self.url);
        allocator.free(self.body);
        allocator.free(self.content_type);
    }
};

/// A service worker (2.1).
pub const Worker = struct {
    id: u64,
    refs: u32 = 0,
    state: WorkerState = .parsed,
    /// Its script url, serialized. OWNED.
    script_url: []u8,
    worker_type: WorkerType,
    /// Its containing service worker registration (a counted reference).
    registration: *Registration,
    /// Its script resource map, in insertion order. The main script's entry
    /// is the script resource's response.
    resources: std.ArrayListUnmanaged(Resource) = .empty,
    /// Its set of used scripts. OWNED urls.
    used_scripts: std.ArrayListUnmanaged([]u8) = .empty,
    skip_waiting: bool = false,
    classic_scripts_imported: bool = false,
    /// The script resource's policy container, opaque here (the owner's to
    /// free: Effects.freePolicy).
    policy: ?*anyopaque = null,
    /// The script resource's has ever been evaluated flag.
    has_ever_been_evaluated: bool = false,
    /// Its set of event types to handle contains "fetch": its global had a
    /// fetch listener when its script first ran (Run Service Worker step
    /// 9.8). Handle Fetch's navigation preload condition, Should Skip Event
    /// and InstallEvent.addRoutes() step 3.2 read it.
    handles_fetch: bool = false,
    /// Its list of router rules (InstallEvent.addRoutes() step 9.4), or
    /// null for none: a counted, immutable list - Handle Fetch evaluates an
    /// active worker's on the fetching thread, holding a reference.
    router_rules: ?*router.Rules = null,
    /// Running: started (Run Service Worker) and not yet ended.
    run: RunState = .stopped,
    /// The extended events still active (the owner counts what the worker's
    /// thread reports): Service Worker Has No Pending Events.
    active_extended_events: u32 = 0,
    /// Functional events (a postMessage's message event) handed to the
    /// running worker and not yet done - dispatched and no longer active.
    /// They are pending events too, as Chromium's in-flight requests are: an
    /// active worker handling one is not replaced (Try Activate), cleared or
    /// idle.
    events_in_flight: u32 = 0,
    /// Bumped at every start: a functional event's end from an earlier run
    /// is not this run's.
    run_generation: u64 = 0,
    /// What waits for Run Service Worker's answer.
    start_waiters: std.ArrayListUnmanaged(Waiter) = .empty,
    /// Fetch events waiting for this worker, while it is "activating", to
    /// become "activated" (Create Fetch Event and Dispatch step 15) before
    /// Run Service Worker. A worker that goes redundant instead fails them.
    activation_waiters: std.ArrayListUnmanaged(Waiter) = .empty,
    /// Its global object's force bypass cache for import scripts flag (Run
    /// Service Worker step 9.1), for the run now started.
    force_bypass_cache_for_imports: bool = false,

    pub const RunState = enum { stopped, starting, running };

    pub fn mainScript(self: *const Worker) ?*const Resource {
        for (self.resources.items) |*entry| {
            if (std.mem.eql(u8, entry.url, self.script_url)) return entry;
        }
        return null;
    }

    pub fn resource(self: *const Worker, url: []const u8) ?*const Resource {
        for (self.resources.items) |*entry| {
            if (std.mem.eql(u8, entry.url, url)) return entry;
        }
        return null;
    }
};

/// What a worker's start is awaited by.
pub const Waiter = union(enum) {
    /// Update step 15.
    update: *Job,
    /// Install step 11.2.
    install: *InstallOp,
    /// Activate step 10.1.
    activate: *ActivateOp,
    /// Something outside the algorithms here (a postMessage, a functional
    /// event): the owner's, told through Effects.startAnswered. An answer
    /// that the worker started counts a functional event in flight
    /// (`Worker.events_in_flight`) until the owner reports it done
    /// (`functionalEventDone`, with the worker's `run_generation`).
    other: u64,
};

/// A service worker registration (2.3).
pub const Registration = struct {
    id: u64,
    refs: u32 = 0,
    /// OWNED.
    storage_key: []u8,
    /// Its scope url, serialized. OWNED.
    scope_url: []u8,
    installing: ?*Worker = null,
    waiting: ?*Worker = null,
    active: ?*Worker = null,
    /// Its last update check time (ms since the epoch), or null.
    last_update_check_time: ?i64 = null,
    update_via_cache: UpdateViaCache = .imports,
    navigation_preload_enabled: bool = false,
    /// OWNED.
    navigation_preload_header_value: []u8,
    /// Whether the registration map holds it: "unregistered" when not.
    in_map: bool = false,

    pub fn slot(self: *const Registration, which: Slot) ?*Worker {
        return switch (which) {
            .installing => self.installing,
            .waiting => self.waiting,
            .active => self.active,
        };
    }

    /// "Stale": its last update check time is more than 86400 seconds ago.
    pub fn isStale(self: *const Registration, now_ms: i64) bool {
        const last = self.last_update_check_time orelse return false;
        return now_ms - last > 86_400_000;
    }
};

/// A service worker client, or a service worker's own global, as the
/// algorithms see it: an environment settings object (2.4).
pub const Environment = struct {
    id: u64,
    kind: EnvironmentKind,
    /// Its id (an opaque string): a UUID. Clients' ids are what
    /// Clients.get() and FetchEvent.clientId name.
    client_id: [36]u8,
    /// Its origin, serialized - also its storage key (Crane partitions no
    /// storage). OWNED.
    origin: []u8,
    /// Its creation URL, serialized. OWNED.
    creation_url: []u8,
    secure_context: bool = true,
    execution_ready: bool = true,
    discarded: bool = false,
    /// Its active service worker (a counted reference): it is controlled.
    active_worker: ?*Worker = null,
    /// A window client's frame type and document state, as last reported.
    frame_type: FrameType = .none,
    visibility_visible: bool = true,
    focused: bool = false,
    /// For a service worker's own global: which worker it runs.
    service_worker_id: u64 = 0,
    /// A window client's browsing context, as an identity only (0: none):
    /// the next window client of the same one is what a navigation of this
    /// one made (WindowClient.navigate()).
    navigable: usize = 0,
    /// The owner's handle on the realm (its sink, its objects). Opaque. Null
    /// for a reserved client (a navigation's or a worker's, HTML "reserved
    /// client"), whose realm does not exist yet: nothing is posted to it until
    /// it is adopted (`adoptEnvironment`).
    endpoint: ?*anyopaque,
};

/// A job (Appendix A).
pub const Job = struct {
    id: u64,
    job_type: JobType,
    /// OWNED.
    storage_key: []u8,
    /// Serialized. OWNED.
    scope_url: []u8,
    /// Serialized; empty for an unregister job. OWNED.
    script_url: []u8,
    worker_type: WorkerType = .classic,
    update_via_cache: UpdateViaCache = .imports,
    /// Its client, as the environment that waits for its promise, or null
    /// (Soft Update's).
    client: ?Client = null,
    /// Its referrer, serialized, or null. OWNED.
    referrer: ?[]u8 = null,
    force_bypass_cache: bool = false,
    /// Its job promise has been resolved or rejected.
    promise_settled: bool = false,
    /// Its list of equivalent jobs (each OWNED by this job once appended).
    equivalent: std.ArrayListUnmanaged(*Job) = .empty,
    /// Its containing job queue's key (the scope url), when queued.
    queued: bool = false,

    pub const Client = struct {
        environment: u64,
        /// Which of the environment's pending promises is this job's.
        promise: u64,
        /// What a fetch made for the job reads of its client (origin,
        /// referrer source, policy container, cookie jar), opaque here: the
        /// owner's to free (Effects.freeFetchClient).
        fetch_client: ?*anyopaque = null,
    };

    /// Two jobs are equivalent when their job type is the same and, for
    /// register and update jobs, their scope url, script url, worker type
    /// and update via cache mode are the same; for unregister jobs, their
    /// scope url.
    pub fn equivalentTo(self: *const Job, other: *const Job) bool {
        if (self.job_type != other.job_type) return false;
        if (!std.mem.eql(u8, self.scope_url, other.scope_url)) return false;
        return switch (self.job_type) {
            .unregister => true,
            .register, .update => std.mem.eql(u8, self.script_url, other.script_url) and
                self.worker_type == other.worker_type and
                self.update_via_cache == other.update_via_cache,
        };
    }
};

/// Install's state while its install event's extended lifetime runs.
pub const InstallOp = struct {
    id: u64,
    job: *Job,
    worker: *Worker,
    registration: *Registration,
    newest_worker_was_null: bool,
    failed: bool = false,
};

/// Activate's state while its activate event's extended lifetime runs.
pub const ActivateOp = struct {
    id: u64,
    registration: *Registration,
    worker: *Worker,
};

/// A service worker as a realm makes its ServiceWorker object from it.
/// BORROWED strings: valid while the owner's lock is held.
pub const WorkerSnapshot = struct {
    id: u64,
    script_url: []const u8,
    state: WorkerState,
};

/// A registration as a realm makes its ServiceWorkerRegistration object from
/// it ("get the service worker registration object", steps 2.1-2.8).
/// BORROWED strings: valid while the owner's lock is held.
pub const RegistrationSnapshot = struct {
    id: u64,
    scope_url: []const u8,
    update_via_cache: UpdateViaCache,
    installing: ?WorkerSnapshot = null,
    waiting: ?WorkerSnapshot = null,
    active: ?WorkerSnapshot = null,
};

/// What an algorithm hands to a realm, as a task of its event loop.
pub const Message = union(enum) {
    /// Resolve Job Promise: a register or update job's registration, in the
    /// realm as its ServiceWorkerRegistration object.
    resolve_registration: struct { promise: u64, registration: RegistrationSnapshot },
    /// Resolve Job Promise: an unregister job's boolean.
    resolve_boolean: struct { promise: u64, value: bool },
    /// skipWaiting() step 2.3 and claim() step 3.2: resolve the promise with
    /// undefined.
    resolve_undefined: struct { promise: u64 },
    /// Reject Job Promise (and claim()'s InvalidStateError).
    reject: struct { promise: u64, kind: ErrorKind, message: []const u8 },
    /// Update Worker State step 4: set the ServiceWorker object's state, if
    /// the realm has one for the worker, and fire statechange at it.
    worker_state: struct { worker: u64, state: WorkerState },
    /// Update Registration State: set the registration object's installing,
    /// waiting or active attribute.
    registration_slot: struct { registration: u64, slot: Slot, worker: ?WorkerSnapshot },
    /// Install step 9: fire updatefound at the registration's objects.
    update_found: struct { registration: u64 },
    /// Notify Controller Change: fire controllerchange at the realm's
    /// ServiceWorkerContainer - its new controller, the environment's active
    /// service worker, as it is now (null: none).
    controller_change: ?WorkerSnapshot,
    /// Activate step 7: resolve the realm's ready promise if it is pending.
    ready: RegistrationSnapshot,
};

/// What the algorithms ask of their owner. Every call is made with the
/// owner's lock held, and none may call back into the Registry: what it
/// starts answers later through the Registry's resume calls.
pub const Effects = struct {
    ctx: *anyopaque,
    /// Post `message` to `environment`'s realm, as a task of its event loop.
    notify: *const fn (ctx: *anyopaque, environment: *Environment, message: Message) void,
    /// Run Job step 2: queue a task (on the job thread) that calls
    /// `runJob` for the job queue of `scope_url`.
    queue_run_job: *const fn (ctx: *anyopaque, scope_url: []const u8) void,
    /// Start running `worker` (Run Service Worker steps 7-9): its answer is
    /// `workerEvaluated`, or `workerEnded` when it never ran.
    start_worker: *const fn (ctx: *anyopaque, worker: *Worker, force_bypass_cache: bool) void,
    /// Terminate Service Worker: its end is `workerEnded`.
    terminate_worker: *const fn (ctx: *anyopaque, worker: *Worker) void,
    /// Queue the task that fires `event` at `worker`'s global and waits for
    /// its extended lifetime: its answer is `lifecycleEventDone(op, ...)`.
    dispatch_lifecycle: *const fn (ctx: *anyopaque, worker: *Worker, event: LifecycleEvent, op: u64) void,
    /// A start awaited by `Waiter.other` was answered.
    start_answered: *const fn (ctx: *anyopaque, worker: *Worker, waiter: u64, ok: bool) void,
    /// Free a job's fetch client (Job.Client.fetch_client).
    free_fetch_client: *const fn (ctx: *anyopaque, fetch_client: *anyopaque) void,
    /// Free a worker's policy container (Worker.policy).
    free_policy: *const fn (ctx: *anyopaque, policy: *anyopaque) void,
    /// The current time, in ms since the epoch.
    now_ms: *const fn (ctx: *anyopaque) i64,
    /// `worker` is running with nothing to do (`isIdle`): it has no event
    /// to handle, so the user agent may terminate it (2.1.1) - the owner
    /// does once it has stayed so for its idle timeout.
    idle: *const fn (ctx: *anyopaque, worker: *Worker) void,
};

/// The fetch the Update algorithm's step 7 makes, as the owner performs it
/// without the lock: everything it reads of the registration and the newest
/// worker, copied. OWNED (`deinit`).
pub const FetchPlan = struct {
    job: u64,
    /// Serialized.
    script_url: []u8,
    scope_url: []u8,
    worker_type: WorkerType,
    /// The fetch hook's step 2: the request's cache mode is "no-cache".
    bypass_http_cache: bool,
    /// Step 21.3's condition for the imported scripts' requests.
    bypass_http_cache_for_imports: bool,
    /// The job's fetch client (BORROWED: the job outlives the fetch - jobs
    /// end only on the job thread, which performs it).
    fetch_client: ?*anyopaque,
    /// The newest worker's script url and type, and its script resource map,
    /// copied - null when there is none.
    newest: ?Newest,

    pub const Newest = struct {
        script_url: []u8,
        worker_type: WorkerType,
        classic_scripts_imported: bool,
        resources: []Resource,
    };

    pub fn deinit(self: *FetchPlan, allocator: Allocator) void {
        allocator.free(self.script_url);
        allocator.free(self.scope_url);
        if (self.newest) |*newest| {
            allocator.free(newest.script_url);
            for (newest.resources) |*r| r.deinit(allocator);
            allocator.free(newest.resources);
        }
    }
};

/// What the owner's fetch for a FetchPlan found (Update step 7's
/// completion). OWNED by the caller of `updateFetched`, which takes
/// `resources` and `policy`.
pub const FetchOutcome = struct {
    /// Null script: "asynchronously complete these steps with a network
    /// error" - and why.
    failure: ?Failure = null,
    /// The updated resource map: the main script's entry first, then any
    /// imported scripts step 21 fetched.
    resources: std.ArrayListUnmanaged(Resource) = .empty,
    /// hasUpdatedResources.
    has_updated_resources: bool = false,
    /// A response came from the network (its cache state is not "local"):
    /// the registration's last update check time becomes now.
    checked_network: bool = false,
    /// policyContainer (step 10), opaque here.
    policy: ?*anyopaque = null,

    pub const Failure = enum {
        /// The fetch failed, or its status is not ok, or it redirected.
        network,
        /// Step 7 (not a JavaScript MIME type) or 16 (the scope is not
        /// allowed): Reject Job Promise with a SecurityError first.
        security,
    };
};

pub const Registry = struct {
    allocator: Allocator,
    effects: Effects,
    next_id: u64 = 1,
    /// The registration map: (storage key, serialized scope url) to a
    /// registration, in insertion order (getRegistrations() lists them so).
    registrations: std.ArrayListUnmanaged(*Registration) = .empty,
    /// Registrations no longer in the map that something still holds.
    detached: std.ArrayListUnmanaged(*Registration) = .empty,
    /// Every service worker record not yet freed.
    workers: std.ArrayListUnmanaged(*Worker) = .empty,
    /// The scope to job queue map: serialized scope url to its queue.
    job_queues: std.StringArrayHashMapUnmanaged(std.ArrayListUnmanaged(*Job)) = .empty,
    environments: std.ArrayListUnmanaged(*Environment) = .empty,
    installs: std.ArrayListUnmanaged(*InstallOp) = .empty,
    activates: std.ArrayListUnmanaged(*ActivateOp) = .empty,
    /// For client ids.
    prng: std.Random.DefaultPrng,

    pub fn init(allocator: Allocator, effects: Effects, seed: u64) Registry {
        return .{ .allocator = allocator, .effects = effects, .prng = std.Random.DefaultPrng.init(seed) };
    }

    /// Everything goes, whatever still refers to it: the owner's end, after
    /// every realm and thread that could.
    pub fn deinit(self: *Registry) void {
        for (self.installs.items) |op| self.allocator.destroy(op);
        self.installs.deinit(self.allocator);
        for (self.activates.items) |op| self.allocator.destroy(op);
        self.activates.deinit(self.allocator);
        for (self.job_queues.keys(), self.job_queues.values()) |key, *queue| {
            for (queue.items) |job| self.destroyJob(job);
            queue.deinit(self.allocator);
            self.allocator.free(key);
        }
        self.job_queues.deinit(self.allocator);
        for (self.environments.items) |environment| self.destroyEnvironment(environment);
        self.environments.deinit(self.allocator);
        for (self.workers.items) |worker| self.destroyWorker(worker);
        self.workers.deinit(self.allocator);
        for (self.registrations.items) |registration| self.destroyRegistration(registration);
        self.registrations.deinit(self.allocator);
        for (self.detached.items) |registration| self.destroyRegistration(registration);
        self.detached.deinit(self.allocator);
    }

    fn nextId(self: *Registry) u64 {
        const id = self.next_id;
        self.next_id += 1;
        return id;
    }

    // ------------------------------------------------------------------
    // Lookups
    // ------------------------------------------------------------------

    pub fn findWorker(self: *const Registry, id: u64) ?*Worker {
        for (self.workers.items) |worker| if (worker.id == id) return worker;
        return null;
    }

    pub fn findRegistration(self: *const Registry, id: u64) ?*Registration {
        for (self.registrations.items) |registration| if (registration.id == id) return registration;
        for (self.detached.items) |registration| if (registration.id == id) return registration;
        return null;
    }

    pub fn findEnvironment(self: *const Registry, id: u64) ?*Environment {
        for (self.environments.items) |environment| if (environment.id == id) return environment;
        return null;
    }

    pub fn findClient(self: *const Registry, client_id: []const u8) ?*Environment {
        for (self.environments.items) |environment| {
            if (environment.kind.isClient() and std.mem.eql(u8, &environment.client_id, client_id)) return environment;
        }
        return null;
    }

    /// Get Registration: the registration whose storage key is
    /// `storage_key` and whose scope url (serialized, fragment excluded) is
    /// `scope_url`, or null.
    pub fn getRegistration(self: *const Registry, storage_key: []const u8, scope_url: []const u8) ?*Registration {
        for (self.registrations.items) |registration| {
            if (std.mem.eql(u8, registration.storage_key, storage_key) and std.mem.eql(u8, registration.scope_url, scope_url)) return registration;
        }
        return null;
    }

    /// Match Service Worker Registration: the registration of `storage_key`
    /// whose scope is the longest prefix of `client_url` (serialized), or
    /// null.
    pub fn matchRegistration(self: *const Registry, storage_key: []const u8, client_url: []const u8) ?*Registration {
        var best: ?*Registration = null;
        for (self.registrations.items) |registration| {
            if (!std.mem.eql(u8, registration.storage_key, storage_key)) continue;
            if (!std.mem.startsWith(u8, client_url, registration.scope_url)) continue;
            if (best) |b| {
                if (b.scope_url.len >= registration.scope_url.len) continue;
            }
            best = registration;
        }
        return best;
    }

    /// getRegistrations() step 4.2: every registration in the map whose
    /// storage key is `storage_key`, in the map's order. The caller owns the
    /// list, not the registrations (valid while the lock is held).
    pub fn registrationsOf(self: *const Registry, allocator: Allocator, storage_key: []const u8) Allocator.Error![]*Registration {
        var list: std.ArrayListUnmanaged(*Registration) = .empty;
        errdefer list.deinit(allocator);
        for (self.registrations.items) |registration| {
            if (std.mem.eql(u8, registration.storage_key, storage_key)) try list.append(allocator, registration);
        }
        return list.toOwnedSlice(allocator);
    }

    /// Get Newest Worker.
    pub fn getNewestWorker(registration: *const Registration) ?*Worker {
        return registration.installing orelse registration.waiting orelse registration.active;
    }

    /// Whether `registration` is unregistered: the map does not hold it.
    pub fn isUnregistered(registration: *const Registration) bool {
        return !registration.in_map;
    }

    pub fn snapshotWorker(worker: *const Worker) WorkerSnapshot {
        return .{ .id = worker.id, .script_url = worker.script_url, .state = worker.state };
    }

    pub fn snapshotRegistration(registration: *const Registration) RegistrationSnapshot {
        return .{
            .id = registration.id,
            .scope_url = registration.scope_url,
            .update_via_cache = registration.update_via_cache,
            .installing = if (registration.installing) |w| snapshotWorker(w) else null,
            .waiting = if (registration.waiting) |w| snapshotWorker(w) else null,
            .active = if (registration.active) |w| snapshotWorker(w) else null,
        };
    }

    // ------------------------------------------------------------------
    // Environments
    // ------------------------------------------------------------------

    pub const EnvironmentInit = struct {
        kind: EnvironmentKind,
        origin: []const u8,
        creation_url: []const u8,
        secure_context: bool = true,
        frame_type: FrameType = .none,
        service_worker_id: u64 = 0,
        navigable: usize = 0,
        endpoint: ?*anyopaque,
    };

    /// A new environment, its strings copied.
    pub fn addEnvironment(self: *Registry, init_values: EnvironmentInit) Allocator.Error!*Environment {
        const environment = try self.allocator.create(Environment);
        errdefer self.allocator.destroy(environment);
        const origin = try self.allocator.dupe(u8, init_values.origin);
        errdefer self.allocator.free(origin);
        const creation_url = try self.allocator.dupe(u8, init_values.creation_url);
        errdefer self.allocator.free(creation_url);
        environment.* = .{
            .id = self.nextId(),
            .kind = init_values.kind,
            .client_id = undefined,
            .origin = origin,
            .creation_url = creation_url,
            .secure_context = init_values.secure_context,
            .frame_type = init_values.frame_type,
            .service_worker_id = init_values.service_worker_id,
            .navigable = init_values.navigable,
            .endpoint = init_values.endpoint,
        };
        self.makeUuid(&environment.client_id);
        try self.environments.append(self.allocator, environment);
        return environment;
    }

    /// What a reserved client is made with: an environment whose realm does
    /// not exist yet (HTML "create navigation params by fetching"'s reserved
    /// client, "run a worker" step 7's inside settings before the fetch).
    /// `origin` is its storage key - its creation URL's origin.
    pub const ReserveInit = struct {
        kind: EnvironmentKind,
        origin: []const u8,
        creation_url: []const u8,
        secure_context: bool = true,
    };

    /// A reserved client: an environment that is not execution ready and has
    /// no realm. Its id is a client id from now on - a fetch event's
    /// resultingClientId names it - but it is no target of claim(),
    /// matchAll() or a realm's messages until `adoptEnvironment`. One that is
    /// never adopted is discarded (`removeEnvironment`).
    pub fn reserveEnvironment(self: *Registry, init_values: ReserveInit) Allocator.Error!*Environment {
        const environment = try self.addEnvironment(.{
            .kind = init_values.kind,
            .origin = init_values.origin,
            .creation_url = init_values.creation_url,
            .secure_context = init_values.secure_context,
            .endpoint = null,
        });
        environment.execution_ready = false;
        return environment;
    }

    /// What a realm brings to the reserved client it becomes.
    pub const AdoptInit = struct {
        endpoint: *anyopaque,
        /// Its creation URL: the response's (a navigation's redirects).
        creation_url: []const u8,
        frame_type: FrameType = .none,
    };

    /// The realm the reserved client `environment` was reserved for exists:
    /// HTML "set up a window environment settings object" step 4 (and a
    /// worker's adoption of its inside settings) - the settings object takes
    /// the reserved environment's id and active service worker, and is
    /// execution ready.
    pub fn adoptEnvironment(self: *Registry, environment: *Environment, init_values: AdoptInit) Allocator.Error!void {
        const creation_url = try self.allocator.dupe(u8, init_values.creation_url);
        self.allocator.free(environment.creation_url);
        environment.creation_url = creation_url;
        environment.endpoint = init_values.endpoint;
        environment.frame_type = init_values.frame_type;
        environment.execution_ready = true;
    }

    /// The environment has ended: Handle Service Worker Client Unload, then
    /// it goes. Its endpoint is the caller's.
    pub fn removeEnvironment(self: *Registry, environment: *Environment) void {
        for (self.environments.items, 0..) |listed, i| {
            if (listed == environment) {
                _ = self.environments.swapRemove(i);
                break;
            }
        }
        environment.discarded = true;
        const used = if (environment.active_worker) |worker| worker.registration else null;
        if (used) |registration| registration.refs += 1;
        defer if (used) |registration| self.releaseRegistration(registration);
        if (environment.active_worker) |worker| self.releaseWorker(worker);
        environment.active_worker = null;
        self.destroyEnvironment(environment);
        if (used) |registration| self.handleClientUnload(registration);
    }

    fn destroyEnvironment(self: *Registry, environment: *Environment) void {
        if (environment.active_worker) |worker| self.releaseWorker(worker);
        self.allocator.free(environment.origin);
        self.allocator.free(environment.creation_url);
        self.allocator.destroy(environment);
    }

    fn makeUuid(self: *Registry, out: *[36]u8) void {
        var bytes: [16]u8 = undefined;
        self.prng.random().bytes(&bytes);
        bytes[6] = (bytes[6] & 0x0f) | 0x40;
        bytes[8] = (bytes[8] & 0x3f) | 0x80;
        const hex = "0123456789abcdef";
        var o: usize = 0;
        for (bytes, 0..) |b, i| {
            if (i == 4 or i == 6 or i == 8 or i == 10) {
                out[o] = '-';
                o += 1;
            }
            out[o] = hex[b >> 4];
            out[o + 1] = hex[b & 0x0f];
            o += 2;
        }
    }

    /// Whether some client other than `except` is using `registration`.
    fn hasClientUsing(self: *const Registry, registration: *const Registration, except: ?*const Environment) bool {
        for (self.environments.items) |environment| {
            if (except) |e| if (environment == e) continue;
            if (!environment.kind.isClient()) continue;
            const worker = environment.active_worker orelse continue;
            if (worker.registration == registration) return true;
        }
        return false;
    }

    /// Set `environment`'s active service worker to `worker` (taking a
    /// reference), releasing the one it had.
    pub fn setActiveWorker(self: *Registry, environment: *Environment, worker: ?*Worker) void {
        if (worker) |w| w.refs += 1;
        if (environment.active_worker) |old| self.releaseWorker(old);
        environment.active_worker = worker;
    }

    // ------------------------------------------------------------------
    // Records
    // ------------------------------------------------------------------

    fn createRegistration(self: *Registry, storage_key: []const u8, scope_url: []const u8, update_via_cache: UpdateViaCache) Allocator.Error!*Registration {
        const registration = try self.allocator.create(Registration);
        errdefer self.allocator.destroy(registration);
        const key = try self.allocator.dupe(u8, storage_key);
        errdefer self.allocator.free(key);
        const scope = try self.allocator.dupe(u8, scope_url);
        errdefer self.allocator.free(scope);
        registration.* = .{
            .id = self.nextId(),
            .storage_key = key,
            .scope_url = scope,
            .update_via_cache = update_via_cache,
            .navigation_preload_header_value = try self.allocator.dupe(u8, "true"),
        };
        return registration;
    }

    fn destroyRegistration(self: *Registry, registration: *Registration) void {
        self.allocator.free(registration.storage_key);
        self.allocator.free(registration.scope_url);
        self.allocator.free(registration.navigation_preload_header_value);
        self.allocator.destroy(registration);
    }

    /// Drop a reference; a registration nothing holds and the map no longer
    /// lists goes.
    fn releaseRegistration(self: *Registry, registration: *Registration) void {
        std.debug.assert(registration.refs > 0);
        registration.refs -= 1;
        if (registration.refs > 0) return;
        for (self.detached.items, 0..) |listed, i| {
            if (listed == registration) {
                _ = self.detached.swapRemove(i);
                self.destroyRegistration(registration);
                return;
            }
        }
    }

    fn createWorker(self: *Registry, registration: *Registration, script_url: []const u8, worker_type: WorkerType) Allocator.Error!*Worker {
        const worker = try self.allocator.create(Worker);
        errdefer self.allocator.destroy(worker);
        worker.* = .{
            .id = self.nextId(),
            .script_url = try self.allocator.dupe(u8, script_url),
            .worker_type = worker_type,
            .registration = registration,
        };
        errdefer self.allocator.free(worker.script_url);
        try self.workers.append(self.allocator, worker);
        registration.refs += 1;
        return worker;
    }

    fn destroyWorker(self: *Registry, worker: *Worker) void {
        for (worker.resources.items) |*resource| resource.deinit(self.allocator);
        worker.resources.deinit(self.allocator);
        for (worker.used_scripts.items) |url| self.allocator.free(url);
        worker.used_scripts.deinit(self.allocator);
        worker.start_waiters.deinit(self.allocator);
        worker.activation_waiters.deinit(self.allocator);
        if (worker.policy) |policy| self.effects.free_policy(self.effects.ctx, policy);
        if (worker.router_rules) |rules| rules.release();
        self.allocator.free(worker.script_url);
        self.allocator.destroy(worker);
    }

    /// Drop a reference; a worker nothing holds - no slot, no client, not
    /// running - goes, and with it its reference to its registration.
    fn releaseWorker(self: *Registry, worker: *Worker) void {
        std.debug.assert(worker.refs > 0);
        worker.refs -= 1;
        self.maybeFreeWorker(worker);
    }

    fn maybeFreeWorker(self: *Registry, worker: *Worker) void {
        if (worker.refs > 0 or worker.run != .stopped) return;
        for (self.workers.items, 0..) |listed, i| {
            if (listed == worker) {
                _ = self.workers.swapRemove(i);
                break;
            }
        }
        const registration = worker.registration;
        self.destroyWorker(worker);
        self.releaseRegistration(registration);
    }

    // ------------------------------------------------------------------
    // Jobs
    // ------------------------------------------------------------------

    pub const JobInit = struct {
        job_type: JobType,
        storage_key: []const u8,
        scope_url: []const u8,
        script_url: []const u8 = "",
        worker_type: WorkerType = .classic,
        update_via_cache: UpdateViaCache = .imports,
        client: ?Job.Client = null,
        /// Create Job step 8: the client's creation URL.
        referrer: ?[]const u8 = null,
        force_bypass_cache: bool = false,
    };

    /// Create Job. Its strings are copied; its client's fetch client is
    /// taken.
    pub fn createJob(self: *Registry, init_values: JobInit) Allocator.Error!*Job {
        const job = try self.allocator.create(Job);
        errdefer self.allocator.destroy(job);
        const storage_key = try self.allocator.dupe(u8, init_values.storage_key);
        errdefer self.allocator.free(storage_key);
        const scope_url = try self.allocator.dupe(u8, init_values.scope_url);
        errdefer self.allocator.free(scope_url);
        const script_url = try self.allocator.dupe(u8, init_values.script_url);
        errdefer self.allocator.free(script_url);
        const referrer = if (init_values.referrer) |r| try self.allocator.dupe(u8, r) else null;
        job.* = .{
            .id = self.nextId(),
            .job_type = init_values.job_type,
            .storage_key = storage_key,
            .scope_url = scope_url,
            .script_url = script_url,
            .worker_type = init_values.worker_type,
            .update_via_cache = init_values.update_via_cache,
            .client = init_values.client,
            .referrer = referrer,
            .force_bypass_cache = init_values.force_bypass_cache,
        };
        return job;
    }

    pub fn destroyJob(self: *Registry, job: *Job) void {
        for (job.equivalent.items) |equivalent| self.destroyJob(equivalent);
        job.equivalent.deinit(self.allocator);
        if (job.client) |client| if (client.fetch_client) |fc| self.effects.free_fetch_client(self.effects.ctx, fc);
        self.allocator.free(job.storage_key);
        self.allocator.free(job.scope_url);
        self.allocator.free(job.script_url);
        if (job.referrer) |r| self.allocator.free(r);
        self.allocator.destroy(job);
    }

    /// Schedule Job. Takes `job`.
    pub fn scheduleJob(self: *Registry, job: *Job) Allocator.Error!void {
        // 1-4. jobQueue: the scope to job queue map's queue for the job's
        // scope url, serialized - made when there is none.
        const entry = self.job_queues.getOrPut(self.allocator, job.scope_url) catch |err| {
            self.destroyJob(job);
            return err;
        };
        if (!entry.found_existing) {
            entry.key_ptr.* = self.allocator.dupe(u8, job.scope_url) catch |err| {
                self.job_queues.swapRemoveAt(entry.index);
                self.destroyJob(job);
                return err;
            };
            entry.value_ptr.* = .empty;
        }
        const queue = entry.value_ptr;
        // 5. If jobQueue is empty: enqueue job, and Run Job.
        if (queue.items.len == 0) {
            queue.append(self.allocator, job) catch |err| {
                self.destroyJob(job);
                return err;
            };
            job.queued = true;
            self.effects.queue_run_job(self.effects.ctx, entry.key_ptr.*);
            return;
        }
        // 6.1-6.2. If job is equivalent to the job at the back of the queue
        // and that job's promise has not settled, it joins that job's list
        // of equivalent jobs.
        const last = queue.items[queue.items.len - 1];
        if (job.equivalentTo(last) and !last.promise_settled) {
            last.equivalent.append(self.allocator, job) catch |err| {
                self.destroyJob(job);
                return err;
            };
            return;
        }
        // 6.3. Else enqueue it.
        queue.append(self.allocator, job) catch |err| {
            self.destroyJob(job);
            return err;
        };
        job.queued = true;
    }

    /// Run Job's task (step 2), for the queue of `scope_url`: the queue's
    /// first job runs. A register or update job that reaches its script
    /// fetch returns the fetch to make (the caller makes it without the
    /// lock, then calls `updateFetched`).
    pub fn runJob(self: *Registry, scope_url: []const u8) Allocator.Error!?FetchPlan {
        const queue = self.job_queues.getPtr(scope_url) orelse return null;
        // 1. Assert: jobQueue is not empty.
        if (queue.items.len == 0) return null;
        // 2.1. Let job be the first item in jobQueue.
        const job = queue.items[0];
        return switch (job.job_type) {
            // 2.2. Register.
            .register => self.register(job),
            // 2.3. Update.
            .update => self.update(job),
            // 2.4. Unregister.
            .unregister => blk: {
                self.unregister(job);
                break :blk null;
            },
        };
    }

    /// Finish Job.
    fn finishJob(self: *Registry, job: *Job) void {
        // 1. Let jobQueue be job's containing job queue.
        const queue = self.job_queues.getPtr(job.scope_url) orelse return self.destroyJob(job);
        // 2. Assert: the first item in jobQueue is job.
        std.debug.assert(queue.items.len > 0 and queue.items[0] == job);
        // 3. Dequeue from jobQueue.
        _ = queue.orderedRemove(0);
        const key = self.job_queues.getKey(job.scope_url).?;
        self.destroyJob(job);
        // 4. If jobQueue is not empty, invoke Run Job with jobQueue.
        if (queue.items.len > 0) {
            self.effects.queue_run_job(self.effects.ctx, key);
        }
    }

    /// Resolve Job Promise with a registration.
    fn resolveJobWithRegistration(self: *Registry, job: *Job, registration: *Registration) void {
        job.promise_settled = true;
        const snapshot = snapshotRegistration(registration);
        // 1. If job's client is not null, queue a task on its event loop to
        // resolve its promise with the registration's object there.
        if (job.client) |client| {
            if (self.findEnvironment(client.environment)) |environment| {
                self.notifyEnvironment(environment, .{ .resolve_registration = .{ .promise = client.promise, .registration = snapshot } });
            }
        }
        // 2. The same for each equivalent job's client.
        for (job.equivalent.items) |equivalent| {
            equivalent.promise_settled = true;
            const client = equivalent.client orelse continue;
            const environment = self.findEnvironment(client.environment) orelse continue;
            self.notifyEnvironment(environment, .{ .resolve_registration = .{ .promise = client.promise, .registration = snapshot } });
        }
    }

    /// Resolve Job Promise with a boolean (an unregister job's value).
    fn resolveJobWithBoolean(self: *Registry, job: *Job, value: bool) void {
        job.promise_settled = true;
        if (job.client) |client| {
            if (self.findEnvironment(client.environment)) |environment| {
                self.notifyEnvironment(environment, .{ .resolve_boolean = .{ .promise = client.promise, .value = value } });
            }
        }
        for (job.equivalent.items) |equivalent| {
            equivalent.promise_settled = true;
            const client = equivalent.client orelse continue;
            const environment = self.findEnvironment(client.environment) orelse continue;
            self.notifyEnvironment(environment, .{ .resolve_boolean = .{ .promise = client.promise, .value = value } });
        }
    }

    /// Reject Job Promise. A promise already settled is left alone (its
    /// task would do nothing).
    fn rejectJob(self: *Registry, job: *Job, kind: ErrorKind, message: []const u8) void {
        if (!job.promise_settled) {
            if (job.client) |client| {
                if (self.findEnvironment(client.environment)) |environment| {
                    self.notifyEnvironment(environment, .{ .reject = .{ .promise = client.promise, .kind = kind, .message = message } });
                }
            }
        }
        job.promise_settled = true;
        for (job.equivalent.items) |equivalent| {
            if (equivalent.promise_settled) continue;
            equivalent.promise_settled = true;
            const client = equivalent.client orelse continue;
            const environment = self.findEnvironment(client.environment) orelse continue;
            self.notifyEnvironment(environment, .{ .reject = .{ .promise = client.promise, .kind = kind, .message = message } });
        }
    }

    // ------------------------------------------------------------------
    // Register, Update
    // ------------------------------------------------------------------

    /// Register.
    fn register(self: *Registry, job: *Job) Allocator.Error!?FetchPlan {
        const allocator = self.allocator;
        // 1. If the origin of job's script url is not potentially
        // trustworthy: SecurityError.
        if (!try isTrustworthyUrl(allocator, job.script_url)) {
            self.rejectJob(job, .security_error, "The script URL's origin is not potentially trustworthy");
            self.finishJob(job);
            return null;
        }
        // 2. If job's script url's origin and job's referrer's origin are
        // not same origin: SecurityError.
        const referrer = job.referrer orelse "";
        if (!try scope_mod.sameOriginUrls(allocator, job.script_url, referrer)) {
            self.rejectJob(job, .security_error, "The script URL is not same-origin with its registering client");
            self.finishJob(job);
            return null;
        }
        // 3. If job's scope url's origin and job's referrer's origin are not
        // same origin: SecurityError.
        if (!try scope_mod.sameOriginUrls(allocator, job.scope_url, referrer)) {
            self.rejectJob(job, .security_error, "The scope is not same-origin with its registering client");
            self.finishJob(job);
            return null;
        }
        // 4. Let registration be the result of Get Registration.
        if (self.getRegistration(job.storage_key, job.scope_url)) |registration| {
            // 5.1. Let newestWorker be the result of Get Newest Worker.
            // 5.2. If newestWorker is not null, its script url equals job's,
            // its type equals job's worker type, and job's update via cache
            // mode equals registration's: resolve with registration, finish.
            if (getNewestWorker(registration)) |newest| {
                if (std.mem.eql(u8, newest.script_url, job.script_url) and
                    newest.worker_type == job.worker_type and
                    job.update_via_cache == registration.update_via_cache)
                {
                    self.resolveJobWithRegistration(job, registration);
                    self.finishJob(job);
                    return null;
                }
            }
        } else {
            // 6. Else: Set Registration.
            _ = try self.setRegistration(job.storage_key, job.scope_url, job.update_via_cache);
        }
        // 7. Invoke Update with job.
        return self.update(job);
    }

    /// Set Registration.
    fn setRegistration(self: *Registry, storage_key: []const u8, scope_url: []const u8, update_via_cache: UpdateViaCache) Allocator.Error!*Registration {
        // 3. A new registration whose storage key, scope url and update via
        // cache mode are the arguments.
        const registration = try self.createRegistration(storage_key, scope_url, update_via_cache);
        errdefer self.destroyRegistration(registration);
        // 4. Set registration map[(storage key, scopeString)] to it - one
        // with the same key is replaced (and detached).
        for (self.registrations.items, 0..) |existing, i| {
            if (std.mem.eql(u8, existing.storage_key, storage_key) and std.mem.eql(u8, existing.scope_url, scope_url)) {
                _ = self.registrations.orderedRemove(i);
                try self.detach(existing);
                break;
            }
        }
        try self.registrations.append(self.allocator, registration);
        registration.in_map = true;
        registration.refs += 1;
        return registration;
    }

    /// Remove registration map[(storage key, scope)]: the registration
    /// becomes unregistered, and lives on while something holds it.
    fn removeFromMap(self: *Registry, registration: *Registration) void {
        for (self.registrations.items, 0..) |listed, i| {
            if (listed == registration) {
                _ = self.registrations.orderedRemove(i);
                self.detach(registration) catch {
                    // No memory to list it: it is still counted, so it is
                    // freed by `deinit`'s sweep at the latest - list it in
                    // place of nothing. (Unreachable in practice.)
                    log.debug("no memory to detach a registration", .{});
                };
                return;
            }
        }
    }

    fn detach(self: *Registry, registration: *Registration) Allocator.Error!void {
        registration.in_map = false;
        try self.detached.append(self.allocator, registration);
        self.releaseRegistration(registration);
    }

    /// Update steps 1-7: the job's registration and newest worker checked,
    /// and the fetch to make. Null when the job has finished.
    fn update(self: *Registry, job: *Job) Allocator.Error!?FetchPlan {
        // 1. Let registration be the result of Get Registration.
        // 2. If registration is null: TypeError, finish.
        const registration = self.getRegistration(job.storage_key, job.scope_url) orelse {
            self.rejectJob(job, .type_error, "No registration for this scope");
            self.finishJob(job);
            return null;
        };
        // 3. Let newestWorker be the result of Get Newest Worker.
        const newest = getNewestWorker(registration);
        // 4. An update job whose newest worker's script url is not job's:
        // TypeError, finish.
        if (job.job_type == .update) {
            if (newest) |n| {
                if (!std.mem.eql(u8, n.script_url, job.script_url)) {
                    self.rejectJob(job, .type_error, "The registration's script URL changed");
                    self.finishJob(job);
                    return null;
                }
            }
        }
        // 7. The fetch, with its hook's cache mode (step 2) and the newest
        // worker's resources for the comparison (steps 20-21).
        const now = self.effects.now_ms(self.effects.ctx);
        const stale = registration.isStale(now);
        var plan: FetchPlan = .{
            .job = job.id,
            .script_url = try self.allocator.dupe(u8, job.script_url),
            .scope_url = undefined,
            .worker_type = job.worker_type,
            // Fetch hook step 2: no-cache when the registration's update via
            // cache mode is not "all", the job forces it, or the newest
            // worker's registration is stale.
            .bypass_http_cache = registration.update_via_cache != .all or job.force_bypass_cache or (newest != null and stale),
            // Step 21.3: no-cache when the mode is "none", the job forces
            // it, or the registration is stale.
            .bypass_http_cache_for_imports = registration.update_via_cache == .none or job.force_bypass_cache or stale,
            .fetch_client = if (job.client) |c| c.fetch_client else null,
            .newest = null,
        };
        errdefer self.allocator.free(plan.script_url);
        plan.scope_url = try self.allocator.dupe(u8, registration.scope_url);
        errdefer self.allocator.free(plan.scope_url);
        if (newest) |n| {
            const resources = try self.allocator.alloc(Resource, n.resources.items.len);
            var made: usize = 0;
            errdefer {
                for (resources[0..made]) |*r| r.deinit(self.allocator);
                self.allocator.free(resources);
            }
            for (n.resources.items) |r| {
                resources[made] = try r.clone(self.allocator);
                made += 1;
            }
            plan.newest = .{
                .script_url = try self.allocator.dupe(u8, n.script_url),
                .worker_type = n.worker_type,
                .classic_scripts_imported = n.classic_scripts_imported,
                .resources = resources,
            };
        }
        return plan;
    }

    /// Soft Update: an update job, with no client, for `registration`'s
    /// newest worker - unless it has none.
    pub fn softUpdate(self: *Registry, registration: *Registration, force_bypass_cache: bool) Allocator.Error!void {
        // 1-2. newestWorker; abort when null.
        const newest = getNewestWorker(registration) orelse return;
        // 3-5. Create Job with update, the registration's storage key and
        // scope url, newestWorker's script url, a null promise and client;
        // its worker type newestWorker's; its force bypass cache flag.
        const job = try self.createJob(.{
            .job_type = .update,
            .storage_key = registration.storage_key,
            .scope_url = registration.scope_url,
            .script_url = newest.script_url,
            .worker_type = newest.worker_type,
            // An update job keeps the registration's mode (Install step 3
            // sets the registration's from the job's).
            .update_via_cache = registration.update_via_cache,
            .force_bypass_cache = force_bypass_cache,
        });
        // 6. Schedule Job.
        try self.scheduleJob(job);
    }

    /// Update from step 7's completion: `outcome` is what the fetch made of
    /// the plan for the job `job_id` (its resources and policy taken). The
    /// job may have gone (the Browser ending), in which case nothing runs.
    pub fn updateFetched(self: *Registry, job_id: u64, outcome: *FetchOutcome) Allocator.Error!void {
        defer self.freeOutcome(outcome);
        const job = self.runningJob(job_id) orelse return;
        const registration = self.getRegistration(job.storage_key, job.scope_url) orelse {
            self.rejectJob(job, .type_error, "No registration for this scope");
            self.finishJob(job);
            return;
        };
        const newest = getNewestWorker(registration);
        // Steps 19 and 21.7: a response not from the local cache sets the
        // last update check time.
        if (outcome.checked_network) registration.last_update_check_time = self.effects.now_ms(self.effects.ctx);
        // 8. If script is null: TypeError (nothing, after a SecurityError);
        // remove the registration when it has no newest worker; finish.
        if (outcome.failure) |failure| {
            if (failure == .security) self.rejectJob(job, .security_error, "The script was refused (MIME type or scope)");
            self.rejectJob(job, .type_error, "The script could not be fetched");
            if (newest == null) self.removeFromMap(registration);
            self.finishJob(job);
            return;
        }
        // 9. If hasUpdatedResources is false: the registration's update via
        // cache mode becomes the job's, resolve with the registration,
        // finish.
        if (!outcome.has_updated_resources) {
            registration.update_via_cache = job.update_via_cache;
            self.resolveJobWithRegistration(job, registration);
            self.finishJob(job);
            return;
        }
        // 10-11. A new service worker: job's script url and type, the
        // fetched script as its script resource, the updated resource map.
        const worker = try self.createWorker(registration, job.script_url, job.worker_type);
        worker.resources = outcome.resources;
        outcome.resources = .empty;
        // 12. Append url to worker's set of used scripts.
        try worker.used_scripts.append(self.allocator, try self.allocator.dupe(u8, job.script_url));
        // 13. Its script resource's policy container.
        worker.policy = outcome.policy;
        outcome.policy = null;
        // 15. Run Service Worker with worker and forceBypassCache - its
        // answer resumes in `workerEvaluated` (16-17).
        try self.runServiceWorker(worker, job.force_bypass_cache, .{ .update = job });
    }

    fn freeOutcome(self: *Registry, outcome: *FetchOutcome) void {
        for (outcome.resources.items) |*r| r.deinit(self.allocator);
        outcome.resources.deinit(self.allocator);
        if (outcome.policy) |policy| self.effects.free_policy(self.effects.ctx, policy);
        outcome.policy = null;
    }

    fn runningJob(self: *Registry, job_id: u64) ?*Job {
        for (self.job_queues.values()) |queue| {
            if (queue.items.len > 0 and queue.items[0].id == job_id) return queue.items[0];
        }
        return null;
    }

    // ------------------------------------------------------------------
    // Handle Fetch's decision (steps 9-12)
    // ------------------------------------------------------------------

    /// Who handles a fetch: the registration's active worker, and whether
    /// Soft Update runs once the event was dispatched (step 12).
    pub const FetchMatch = struct {
        worker: *Worker,
        soft_update: bool,
        /// A non-subresource request's reserved client, made (or found) by
        /// step 9.8 - null for a report.
        reserved: ?*Environment = null,
    };

    /// Handle Fetch for a non-subresource request (navigation, worker).
    pub const NonSubresourceFetch = struct {
        /// The request's URL, serialized.
        url: []const u8,
        /// The reserved client, as it is made if the request is handled: its
        /// origin is the storage key step 9.5 obtains.
        reserve: ReserveInit,
        /// The reserved client an earlier call made for the same request.
        reserved: ?*Environment = null,
        /// The request's destination is "report" (step 9.8).
        destination_is_report: bool = false,
    };

    /// Handle Fetch steps 9.5-9.8 and 11-12 for a non-subresource request
    /// (9.1-9.4 are the caller's: secure context, shift+reload). Null:
    /// Handle Fetch returns null - no registration, or none active - and no
    /// reserved environment is made. Otherwise the reserved client is made
    /// now, if it was not, and controlled by the active worker (9.8: "From
    /// this point, the service worker client starts to use its active service
    /// worker's containing service worker registration").
    pub fn handleFetchNonSubresource(self: *Registry, fetch: NonSubresourceFetch) Allocator.Error!?FetchMatch {
        // 6. Match Service Worker Registration given storage key and url.
        const registration = self.matchRegistration(fetch.reserve.origin, fetch.url) orelse return null;
        // 7. A registration with no active worker: null.
        const active = registration.active orelse return null;
        // 8. Unless the destination is "report", the reserved client's
        // active service worker is the registration's active worker.
        var reserved = fetch.reserved;
        if (!fetch.destination_is_report) {
            if (reserved == null) reserved = try self.reserveEnvironment(fetch.reserve);
            self.setActiveWorker(reserved.?, active);
        }
        // 11-12. activeWorker; a non-subresource request soft-updates.
        return .{ .worker = active, .soft_update = true, .reserved = reserved };
    }

    /// Handle Fetch steps 10-12 for a subresource request whose client is
    /// `client`: its active service worker's containing registration's
    /// active worker - null when the client is not controlled - and Soft
    /// Update only for a stale registration.
    pub fn handleFetchSubresource(self: *const Registry, client: *const Environment) ?FetchMatch {
        // 10.1-10.2.
        const controller = client.active_worker orelse return null;
        const registration = controller.registration;
        // 11. activeWorker: the registration's active worker.
        const active = registration.active orelse return null;
        // 12.
        const now = self.effects.now_ms(self.effects.ctx);
        return .{ .worker = active, .soft_update = registration.isStale(now) };
    }

    /// Create Fetch Event and Dispatch steps 15-16: wait for an "activating"
    /// worker to become "activated", then Run Service Worker for `waiter`. A
    /// worker that goes redundant meanwhile fails the waiter.
    pub fn runServiceWorkerForFetch(self: *Registry, worker: *Worker, waiter: Waiter) Allocator.Error!void {
        if (worker.state == .activating) return worker.activation_waiters.append(self.allocator, waiter);
        return self.runServiceWorker(worker, false, waiter);
    }

    /// The worker's state left "activating": its fetch events go on (to
    /// Run Service Worker) or fail.
    fn releaseActivationWaiters(self: *Registry, worker: *Worker) void {
        if (worker.activation_waiters.items.len == 0) return;
        var waiters = worker.activation_waiters;
        worker.activation_waiters = .empty;
        defer waiters.deinit(self.allocator);
        worker.refs += 1;
        defer self.releaseWorker(worker);
        for (waiters.items) |waiter| {
            if (worker.state == .activated) {
                self.runServiceWorker(worker, false, waiter) catch {
                    self.answer(worker, waiter, false) catch {};
                };
            } else {
                self.answer(worker, waiter, false) catch {};
            }
        }
    }

    // ------------------------------------------------------------------
    // Run Service Worker
    // ------------------------------------------------------------------

    /// Run Service Worker, for `waiter`: a worker that is running answers at
    /// once (its start status - here: it started); one that is starting
    /// takes another waiter; a redundant one fails; a stopped one starts.
    pub fn runServiceWorker(self: *Registry, worker: *Worker, force_bypass_cache: bool, waiter: Waiter) Allocator.Error!void {
        switch (worker.run) {
            // 1. If serviceWorker is running, return its start status.
            .running => return self.answer(worker, waiter, true),
            .starting => return worker.start_waiters.append(self.allocator, waiter),
            .stopped => {},
        }
        // 2. If its state is "redundant", return failure.
        if (worker.state == .redundant) return self.answer(worker, waiter, false);
        try worker.start_waiters.append(self.allocator, waiter);
        worker.run = .starting;
        worker.run_generation +%= 1;
        // 9.1. The global's force bypass cache for import scripts flag.
        worker.force_bypass_cache_for_imports = force_bypass_cache;
        // 7-9. Setup ServiceWorkerGlobalScope and run the script, on the
        // worker's own thread.
        self.effects.start_worker(self.effects.ctx, worker, force_bypass_cache);
    }

    /// Whether `worker` runs with nothing to do: started, no start or
    /// lifecycle event waiting on it, and Service Worker Has No Pending
    /// Events. The user agent may terminate such a worker (2.1.1, "has no
    /// event to handle"); Run Service Worker starts it again when an event
    /// needs it.
    pub fn isIdle(self: *const Registry, worker: *const Worker) bool {
        if (worker.run != .running) return false;
        if (worker.start_waiters.items.len > 0) return false;
        if (!serviceWorkerHasNoPendingEvents(worker)) return false;
        for (self.installs.items) |op| if (op.worker == worker) return false;
        for (self.activates.items) |op| if (op.worker == worker) return false;
        return true;
    }

    /// Tell the owner when `worker` has nothing left to do.
    fn noteIfIdle(self: *Registry, worker: *Worker) void {
        if (self.isIdle(worker)) self.effects.idle(self.effects.ctx, worker);
    }

    /// Run Service Worker step 10: the worker's script has been evaluated
    /// (`ok` false: an abrupt completion, or its global could not be set
    /// up). Its waiters resume.
    pub fn workerEvaluated(self: *Registry, worker_id: u64, ok: bool, handles_fetch: bool) Allocator.Error!void {
        const worker = self.findWorker(worker_id) orelse return;
        if (worker.run != .starting) return;
        worker.run = .running;
        // 9.8. If the script's has ever been evaluated flag is unset: each
        // event type of the global's event listeners joins the set of event
        // types to handle (Crane keeps the one type the algorithms ask about,
        // fetch); then the flag is set.
        if (!worker.has_ever_been_evaluated) worker.handles_fetch = handles_fetch;
        worker.has_ever_been_evaluated = true;
        try self.answerWaiters(worker, ok);
        // A worker whose script failed to evaluate does not stay.
        if (!ok) return self.effects.terminate_worker(self.effects.ctx, worker);
        self.noteIfIdle(worker);
    }

    /// The worker's thread has ended - terminated, failed to start, or
    /// closed: it is not running, and whatever waited for its start or its
    /// lifecycle event hears that it will not come.
    pub fn workerEnded(self: *Registry, worker_id: u64) Allocator.Error!void {
        const worker = self.findWorker(worker_id) orelse return;
        const was = worker.run;
        worker.run = .stopped;
        worker.active_extended_events = 0;
        // Its functional events ended with it; their late reports carry this
        // run's generation and find a newer one, or none.
        worker.events_in_flight = 0;
        worker.refs += 1;
        defer self.releaseWorker(worker);
        if (was == .starting) try self.answerWaiters(worker, false);
        // An install or activate event whose task was discarded: what is left
        // of the worker's ops after the start's waiters were answered had its
        // event dispatched.
        var ids: std.ArrayListUnmanaged(u64) = .empty;
        defer ids.deinit(self.allocator);
        for (self.installs.items) |op| if (op.worker == worker) try ids.append(self.allocator, op.id);
        for (self.activates.items) |op| if (op.worker == worker) try ids.append(self.allocator, op.id);
        for (ids.items) |id| try self.lifecycleEventDone(id, true);
    }

    fn answerWaiters(self: *Registry, worker: *Worker, ok: bool) Allocator.Error!void {
        var waiters = worker.start_waiters;
        worker.start_waiters = .empty;
        defer waiters.deinit(self.allocator);
        // The worker may be freed by the last answer.
        worker.refs += 1;
        defer self.releaseWorker(worker);
        for (waiters.items) |waiter| try self.answer(worker, waiter, ok);
    }

    fn answer(self: *Registry, worker: *Worker, waiter: Waiter, ok: bool) Allocator.Error!void {
        switch (waiter) {
            .update => |job| try self.updateRan(job, worker, ok),
            .install => |op| try self.installStarted(op, ok),
            .activate => |op| self.activateStarted(op, ok),
            .other => |id| {
                // The owner hands its event to the running worker now: it is
                // in flight until `functionalEventDone`.
                if (ok) worker.events_in_flight += 1;
                self.effects.start_answered(self.effects.ctx, worker, id, ok);
            },
        }
    }

    /// A functional event the owner handed to `worker_id` (an `other` waiter
    /// answered with its start) is done: dispatched, and no longer active -
    /// or its task was discarded. `generation` is the worker's
    /// `run_generation` when it was handed over: an end from an earlier run
    /// does nothing. When the worker has no pending events left, waitUntil
    /// step 5.2's Try Clear Registration and Try Activate run, as for an
    /// extended event that settles.
    pub fn functionalEventDone(self: *Registry, worker_id: u64, generation: u64) Allocator.Error!void {
        const worker = self.findWorker(worker_id) orelse return;
        if (worker.run_generation != generation or worker.events_in_flight == 0) return;
        worker.events_in_flight -= 1;
        if (!serviceWorkerHasNoPendingEvents(worker)) return;
        try self.pendingEventsEnded(worker);
    }

    /// Update steps 16-17.
    fn updateRan(self: *Registry, job: *Job, worker: *Worker, ok: bool) Allocator.Error!void {
        const registration = worker.registration;
        if (!ok) {
            // 16.1. Reject with a TypeError.
            self.rejectJob(job, .type_error, "The service worker's script failed to run");
            // 16.2. If newestWorker is null, remove the registration.
            if (getNewestWorker(registration) == null and registration.in_map) self.removeFromMap(registration);
            // The worker that never installed is redundant.
            worker.state = .redundant;
            // 16.3. Finish Job.
            self.finishJob(job);
            self.maybeFreeWorker(worker);
            return;
        }
        // 17. Install.
        try self.install(job, worker, registration);
    }

    // ------------------------------------------------------------------
    // Install
    // ------------------------------------------------------------------

    /// Install steps 1-11.
    fn install(self: *Registry, job: *Job, worker: *Worker, registration: *Registration) Allocator.Error!void {
        // 1. Let installFailed be false.
        // 2. Let newestWorker be the result of Get Newest Worker.
        const newest = getNewestWorker(registration);
        // 3. registration's update via cache mode becomes job's.
        registration.update_via_cache = job.update_via_cache;
        // 4. Update Registration State (installing, worker).
        self.updateRegistrationState(registration, .installing, worker);
        // 5. Update Worker State (installing).
        self.updateWorkerState(worker, .installing);
        // 7. Resolve Job Promise with registration.
        self.resolveJobWithRegistration(job, registration);
        // 8-9. Every settings object of the scope's origin: fire updatefound
        // at its objects for the registration.
        self.notifySameOrigin(registration.scope_url, .{ .update_found = .{ .registration = registration.id } });
        // 10-11. Run Service Worker, then the install event.
        const op = try self.allocator.create(InstallOp);
        errdefer self.allocator.destroy(op);
        op.* = .{ .id = self.nextId(), .job = job, .worker = worker, .registration = registration, .newest_worker_was_null = newest == null };
        try self.installs.append(self.allocator, op);
        try self.runServiceWorker(worker, job.force_bypass_cache, .{ .install = op });
    }

    /// Install step 11.2's answer.
    fn installStarted(self: *Registry, op: *InstallOp, ok: bool) Allocator.Error!void {
        if (!ok) {
            // 11.2.1. installFailed.
            op.failed = true;
            return self.installFinish(op);
        }
        // 11.3.1. Queue the install event's task, and wait for it and its
        // extended lifetime.
        self.effects.dispatch_lifecycle(self.effects.ctx, op.worker, .install, op.id);
    }

    /// The lifecycle event `op_id` has finished: its task ran, or was
    /// discarded (`failed` then), and its extended lifetime ended - `failed`
    /// also when a lifetime promise rejected or it timed out.
    pub fn lifecycleEventDone(self: *Registry, op_id: u64, failed: bool) Allocator.Error!void {
        // The op's worker, held across the steps: once they are done it may
        // have nothing left to do.
        const worker = self.opWorker(op_id) orelse return;
        worker.refs += 1;
        defer {
            self.noteIfIdle(worker);
            self.releaseWorker(worker);
        }
        for (self.installs.items) |op| {
            if (op.id != op_id) continue;
            if (failed) op.failed = true;
            return self.installFinish(op);
        }
        for (self.activates.items, 0..) |op, i| {
            if (op.id != op_id) continue;
            _ = self.activates.swapRemove(i);
            defer self.allocator.destroy(op);
            return self.activateFinish(op);
        }
    }

    /// The worker of the install or activate event `op_id`, while it is
    /// pending; null once it is done.
    pub fn opWorker(self: *const Registry, op_id: u64) ?*Worker {
        for (self.installs.items) |op| if (op.id == op_id) return op.worker;
        for (self.activates.items) |op| if (op.id == op_id) return op.worker;
        return null;
    }

    /// Install steps 12-22.
    fn installFinish(self: *Registry, op: *InstallOp) Allocator.Error!void {
        for (self.installs.items, 0..) |listed, i| {
            if (listed == op) {
                _ = self.installs.swapRemove(i);
                break;
            }
        }
        defer self.allocator.destroy(op);
        const job = op.job;
        const registration = op.registration;
        const worker = op.worker;
        // 12. If installFailed:
        if (op.failed) {
            // 12.1. Update Worker State (installing worker, redundant).
            if (registration.installing == worker) {
                self.updateWorkerState(worker, .redundant);
                // 12.2. Update Registration State (installing, null).
                self.updateRegistrationState(registration, .installing, null);
            }
            // 12.3. If newestWorker was null, remove the registration.
            if (op.newest_worker_was_null and registration.in_map) self.removeFromMap(registration);
            self.effects.terminate_worker(self.effects.ctx, worker);
            // 12.4. Finish Job.
            self.finishJob(job);
            return;
        }
        // Cleared meanwhile (Clear Registration): nothing is left to install.
        if (registration.installing != worker) {
            self.finishJob(job);
            return;
        }
        // 13-15. Prune the script resource map to the set of used scripts.
        var i: usize = 0;
        while (i < worker.resources.items.len) {
            const url = worker.resources.items[i].url;
            const used = for (worker.used_scripts.items) |u| {
                if (std.mem.eql(u8, u, url)) break true;
            } else false;
            if (used) {
                i += 1;
            } else {
                var removed = worker.resources.orderedRemove(i);
                removed.deinit(self.allocator);
            }
        }
        // 16. If the registration's waiting worker is not null: terminate it,
        // and it is redundant.
        if (registration.waiting) |waiting| {
            self.effects.terminate_worker(self.effects.ctx, waiting);
            self.updateWorkerState(waiting, .redundant);
        }
        // 17. Update Registration State (waiting, installing worker).
        self.updateRegistrationState(registration, .waiting, worker);
        // 18. Update Registration State (installing, null).
        self.updateRegistrationState(registration, .installing, null);
        // 19. Update Worker State (waiting worker, installed).
        self.updateWorkerState(worker, .installed);
        // 20. Finish Job.
        self.finishJob(job);
        // 21. (The Update Worker State tasks are not waited for: each realm's
        // tasks run in order, so every realm sees installed before
        // activating.)
        // 22. Try Activate.
        try self.tryActivate(registration);
    }

    // ------------------------------------------------------------------
    // Activate
    // ------------------------------------------------------------------

    /// Try Activate.
    pub fn tryActivate(self: *Registry, registration: *Registration) Allocator.Error!void {
        // 1. If the waiting worker is null, return.
        const waiting = registration.waiting orelse return;
        // 2. If the active worker is activating, return.
        if (registration.active) |active| {
            if (active.state == .activating) return;
            // 3. Activate when the active worker has no pending events and
            // no client uses the registration or the waiting worker's skip
            // waiting flag is set.
            if (!serviceWorkerHasNoPendingEvents(active)) return;
            if (self.hasClientUsing(registration, null) and !waiting.skip_waiting) return;
        }
        try self.activate(registration);
    }

    /// Activate steps 1-10.
    fn activate(self: *Registry, registration: *Registration) Allocator.Error!void {
        // 1. If the waiting worker is null, abort.
        const waiting = registration.waiting orelse return;
        // 2. If the active worker is not null: terminate it, redundant.
        if (registration.active) |active| {
            self.effects.terminate_worker(self.effects.ctx, active);
            self.updateWorkerState(active, .redundant);
        }
        // 3. Update Registration State (active, waiting worker).
        self.updateRegistrationState(registration, .active, waiting);
        // 4. Update Registration State (waiting, null).
        self.updateRegistrationState(registration, .waiting, null);
        // 5. Update Worker State (active worker, activating).
        self.updateWorkerState(waiting, .activating);
        // 6-7. Every client whose creation URL matches the registration:
        // resolve its ready promise, if pending.
        const snapshot = snapshotRegistration(registration);
        for (self.environments.items) |environment| {
            if (!environment.kind.isClient()) continue;
            if (!self.creationUrlMatches(environment, registration)) continue;
            self.notifyEnvironment(environment, .{ .ready = snapshot });
        }
        // 8. Every client using the registration: its active worker is the
        // new one, and it hears controllerchange.
        for (self.environments.items) |environment| {
            if (!environment.kind.isClient()) continue;
            const current = environment.active_worker orelse continue;
            if (current.registration != registration) continue;
            self.setActiveWorker(environment, waiting);
            self.notifyControllerChange(environment);
        }
        // 9-10. Run Service Worker, then the activate event.
        const op = try self.allocator.create(ActivateOp);
        errdefer self.allocator.destroy(op);
        op.* = .{ .id = self.nextId(), .registration = registration, .worker = waiting };
        try self.activates.append(self.allocator, op);
        try self.runServiceWorker(waiting, false, .{ .activate = op });
    }

    /// Activate step 10.1's answer.
    fn activateStarted(self: *Registry, op: *ActivateOp, ok: bool) void {
        if (ok) {
            // 10.1.1. Queue the activate event's task; its answer is
            // `lifecycleEventDone`.
            self.effects.dispatch_lifecycle(self.effects.ctx, op.worker, .activate, op.id);
            return;
        }
        // Failure: "neither a runtime script error nor a force termination
        // of the active worker prevents the active worker from getting
        // activated" - step 11 now.
        for (self.activates.items, 0..) |listed, i| {
            if (listed == op) {
                _ = self.activates.swapRemove(i);
                break;
            }
        }
        defer self.allocator.destroy(op);
        self.activateFinish(op) catch {};
    }

    /// Activate step 11.
    fn activateFinish(self: *Registry, op: *ActivateOp) Allocator.Error!void {
        const registration = op.registration;
        // A registration cleared meanwhile left the worker redundant.
        if (registration.active != op.worker or op.worker.state != .activating) return;
        // 11. Update Worker State (active worker, activated).
        self.updateWorkerState(op.worker, .activated);
        // The registration may now be cleared (an unregister while it
        // activated), or another worker may be waiting.
        if (isUnregistered(registration)) self.tryClearRegistration(registration);
        if (registration.in_map) try self.tryActivate(registration);
    }

    /// Whether `environment`'s creation URL matches `registration`: same
    /// storage key, and the registration is what Match Service Worker
    /// Registration finds for it.
    fn creationUrlMatches(self: *const Registry, environment: *const Environment, registration: *const Registration) bool {
        if (!std.mem.eql(u8, environment.origin, registration.storage_key)) return false;
        const matched = self.matchRegistration(environment.origin, environment.creation_url) orelse return false;
        return matched == registration;
    }

    // ------------------------------------------------------------------
    // Unregister, Clear Registration
    // ------------------------------------------------------------------

    /// Unregister.
    fn unregister(self: *Registry, job: *Job) void {
        // 1. Let registration be the result of Get Registration.
        // 2. If registration is null: resolve with false, finish.
        const registration = self.getRegistration(job.storage_key, job.scope_url) orelse {
            self.resolveJobWithBoolean(job, false);
            self.finishJob(job);
            return;
        };
        registration.refs += 1;
        defer self.releaseRegistration(registration);
        // 3. Remove registration map[(storage key, scope url)].
        self.removeFromMap(registration);
        // 4. Resolve Job Promise with true.
        self.resolveJobWithBoolean(job, true);
        // 5. Try Clear Registration.
        self.tryClearRegistration(registration);
        // 6. Finish Job.
        self.finishJob(job);
    }

    /// Try Clear Registration.
    pub fn tryClearRegistration(self: *Registry, registration: *Registration) void {
        // 1. Clear Registration if no client is using it and none of its
        // workers has pending events.
        if (self.hasClientUsing(registration, null)) return;
        if (registration.installing) |w| if (!serviceWorkerHasNoPendingEvents(w)) return;
        if (registration.waiting) |w| if (!serviceWorkerHasNoPendingEvents(w)) return;
        if (registration.active) |w| if (!serviceWorkerHasNoPendingEvents(w)) return;
        self.clearRegistration(registration);
    }

    /// Clear Registration.
    fn clearRegistration(self: *Registry, registration: *Registration) void {
        registration.refs += 1;
        defer self.releaseRegistration(registration);
        // 2. The installing worker: terminated, redundant, slot cleared.
        if (registration.installing) |worker| {
            self.effects.terminate_worker(self.effects.ctx, worker);
            self.updateWorkerState(worker, .redundant);
            self.updateRegistrationState(registration, .installing, null);
        }
        // 3. The waiting worker.
        if (registration.waiting) |worker| {
            self.effects.terminate_worker(self.effects.ctx, worker);
            self.updateWorkerState(worker, .redundant);
            self.updateRegistrationState(registration, .waiting, null);
        }
        // 4. The active worker.
        if (registration.active) |worker| {
            self.effects.terminate_worker(self.effects.ctx, worker);
            self.updateWorkerState(worker, .redundant);
            self.updateRegistrationState(registration, .active, null);
        }
    }

    /// Handle Service Worker Client Unload, for the registration a client
    /// that has gone was using.
    fn handleClientUnload(self: *Registry, registration: *Registration) void {
        // 4. If any other client is using the registration, abort.
        if (self.hasClientUsing(registration, null)) return;
        // 5. If the registration is unregistered, Try Clear Registration.
        if (isUnregistered(registration)) self.tryClearRegistration(registration);
        // 6. Try Activate.
        self.tryActivate(registration) catch {};
    }

    // ------------------------------------------------------------------
    // State
    // ------------------------------------------------------------------

    /// Update Registration State: the slot is `source`, and each realm's
    /// registration object for it hears so.
    pub fn updateRegistrationState(self: *Registry, registration: *Registration, target: Slot, source: ?*Worker) void {
        const slot_ptr: *?*Worker = switch (target) {
            .installing => &registration.installing,
            .waiting => &registration.waiting,
            .active => &registration.active,
        };
        if (source) |w| w.refs += 1;
        const old = slot_ptr.*;
        slot_ptr.* = source;
        // Every environment with an object for the registration: the
        // registration objects are in their realms, so tell every realm of
        // the registration's origin - one with no object does nothing.
        const message: Message = .{ .registration_slot = .{
            .registration = registration.id,
            .slot = target,
            .worker = if (source) |w| snapshotWorker(w) else null,
        } };
        self.notifySameOrigin(registration.scope_url, message);
        if (old) |w| self.releaseWorker(w);
    }

    /// Update Worker State.
    pub fn updateWorkerState(self: *Registry, worker: *Worker, state: WorkerState) void {
        // 1. Assert: state is not "parsed".
        std.debug.assert(state != .parsed);
        // 2. Set worker's state.
        worker.state = state;
        // Fetch events waiting for "activated" go on, or fail.
        if (state == .activated or state == .redundant) self.releaseActivationWaiters(worker);
        // 3-4. Every settings object of the script url's origin: set its
        // ServiceWorker object's state and fire statechange.
        self.notifySameOrigin(worker.script_url, .{ .worker_state = .{ .worker = worker.id, .state = state } });
    }

    /// Post `message` to `environment`'s realm - none for a reserved client,
    /// whose realm does not exist yet.
    fn notifyEnvironment(self: *Registry, environment: *Environment, message: Message) void {
        if (environment.endpoint == null) return;
        self.effects.notify(self.effects.ctx, environment, message);
    }

    /// Notify Controller Change. The task carries the new controller as it
    /// is when the change is made - Activate step 8 makes it in step 5's
    /// "activating" - and the realm makes its ServiceWorker object from that
    /// before firing controllerchange. Read later, when the task runs, the
    /// worker may be "activated" already (the activate event ended on the
    /// job thread meanwhile), and a controller object made then would show
    /// that: skip-waiting-using-registration.https.html expects
    /// "activating" in the event, as Chromium's SetController hands the
    /// container its controller with the state of that moment
    /// (ServiceWorkerContainerHost::SendSetControllerServiceWorker).
    fn notifyControllerChange(self: *Registry, environment: *Environment) void {
        const controller: ?WorkerSnapshot = if (environment.active_worker) |w| snapshotWorker(w) else null;
        self.notifyEnvironment(environment, .{ .controller_change = controller });
    }

    /// Post `message` to every environment whose origin is `url`'s.
    fn notifySameOrigin(self: *Registry, url: []const u8, message: Message) void {
        const origin = scope_mod.originOf(self.allocator, url) catch return;
        defer self.allocator.free(origin);
        for (self.environments.items) |environment| {
            if (!std.mem.eql(u8, environment.origin, origin)) continue;
            self.notifyEnvironment(environment, message);
        }
    }

    // ------------------------------------------------------------------
    // From the service worker
    // ------------------------------------------------------------------

    /// skipWaiting() step 2.1: set the worker's skip waiting flag; then Try
    /// Activate its registration.
    pub fn skipWaiting(self: *Registry, worker_id: u64) Allocator.Error!void {
        const worker = self.findWorker(worker_id) orelse return;
        worker.skip_waiting = true;
        try self.tryActivate(worker.registration);
    }

    /// The worker's count of active extended events changed (an
    /// ExtendableEvent's pending promises count reached zero, or an event
    /// was dispatched with lifetime promises): when it reaches zero, waitUntil
    /// step 5.2's Try Clear Registration and Try Activate.
    pub fn extendedEventsChanged(self: *Registry, worker_id: u64, active: u32) Allocator.Error!void {
        const worker = self.findWorker(worker_id) orelse return;
        worker.active_extended_events = active;
        if (!serviceWorkerHasNoPendingEvents(worker)) return;
        try self.pendingEventsEnded(worker);
    }

    /// `worker` has no pending events left.
    fn pendingEventsEnded(self: *Registry, worker: *Worker) Allocator.Error!void {
        worker.refs += 1;
        defer {
            self.noteIfIdle(worker);
            self.releaseWorker(worker);
        }
        // waitUntil step 5.2.1-3: the registration is the current global's
        // worker's containing registration.
        const registration = worker.registration;
        if (isUnregistered(registration)) self.tryClearRegistration(registration);
        if (registration.in_map) try self.tryActivate(registration);
    }

    /// Clients' claim() steps 3.1: each client of the worker's storage key
    /// that matches its registration and is not controlled by it becomes
    /// controlled by it, and hears controllerchange. InvalidStateError when
    /// the worker is not its registration's active worker.
    pub fn claim(self: *Registry, worker_id: u64) error{ InvalidStateError, OutOfMemory }!void {
        const worker = self.findWorker(worker_id) orelse return error.InvalidStateError;
        const registration = worker.registration;
        // 1. If the service worker is not an active worker: InvalidStateError.
        if (registration.active != worker) return error.InvalidStateError;
        for (self.environments.items) |environment| {
            // 3.1. Clients of the registration's storage key.
            if (!environment.kind.isClient()) continue;
            if (!std.mem.eql(u8, environment.origin, registration.storage_key)) continue;
            // 3.1.1-2. Execution ready, not discarded, a secure context.
            if (!environment.execution_ready or environment.discarded or !environment.secure_context) continue;
            // 3.1.4-5. Whose matching registration is this one.
            const matched = self.matchRegistration(environment.origin, environment.creation_url) orelse continue;
            if (matched != registration) continue;
            // 3.1.6. Not already controlled by the worker.
            if (environment.active_worker == worker) continue;
            const previous = if (environment.active_worker) |w| w.registration else null;
            if (previous) |p| p.refs += 1;
            defer if (previous) |p| self.releaseRegistration(p);
            // 3.1.6.2. Its active service worker is the worker.
            self.setActiveWorker(environment, worker);
            // 3.1.6.1. Handle Service Worker Client Unload for what it used.
            if (previous) |p| self.handleClientUnload(p);
            // 3.1.6.3. Notify Controller Change.
            self.notifyControllerChange(environment);
        }
    }

    /// Clients' matchAll() step 2.2, for the associated service worker
    /// `worker`: targetClients - each service worker client whose storage key
    /// is the worker's registration's, execution ready and not discarded, a
    /// secure context, and controlled by `worker` unless
    /// `include_uncontrolled` - in creation order (step 2.5 sorts by it). The
    /// caller owns the slice, not the environments (valid while the lock is
    /// held).
    pub fn matchAllClients(self: *const Registry, allocator: Allocator, worker: *const Worker, include_uncontrolled: bool) Allocator.Error![]*Environment {
        var list: std.ArrayListUnmanaged(*Environment) = .empty;
        errdefer list.deinit(allocator);
        const storage_key = worker.registration.storage_key;
        for (self.environments.items) |environment| {
            if (!environment.kind.isClient()) continue;
            if (!std.mem.eql(u8, environment.origin, storage_key)) continue;
            // 2.2.1. Execution ready, not discarded.
            if (!environment.execution_ready or environment.discarded) continue;
            // 2.2.2. A secure context.
            if (!environment.secure_context) continue;
            // 2.2.3. Controlled by the worker, unless includeUncontrolled.
            if (!include_uncontrolled and environment.active_worker != worker) continue;
            try list.append(allocator, environment);
        }
        // Environment ids are given in creation order; the list's own order
        // is not kept (an environment's end swaps the last one in).
        std.mem.sort(*Environment, list.items, {}, struct {
            fn lessThan(_: void, a: *Environment, b: *Environment) bool {
                return a.id < b.id;
            }
        }.lessThan);
        return list.toOwnedSlice(allocator);
    }

    /// Clients' get(id) step 2.1, for the associated service worker
    /// `worker`: the service worker client whose storage key is the worker's
    /// registration's and whose id is `id`, or null.
    pub fn getClient(self: *const Registry, worker: *const Worker, id: []const u8) ?*Environment {
        const storage_key = worker.registration.storage_key;
        for (self.environments.items) |environment| {
            if (!environment.kind.isClient()) continue;
            if (!std.mem.eql(u8, environment.origin, storage_key)) continue;
            if (std.mem.eql(u8, &environment.client_id, id)) return environment;
        }
        return null;
    }

    /// What importScripts()'s fetch hook in a service worker (6.3.2) does
    /// for one URL, before any fetch.
    pub const ImportStep = union(enum) {
        /// Steps 4.1 and 5.2: the response the script resource map has for
        /// the URL. OWNED (a copy).
        stored: Resource,
        /// Step 4.1: the worker is past installing and its map has no entry
        /// for the URL - a network error.
        network_error,
        /// Steps 6-9: fetch it - with the request's cache mode "no-cache"
        /// when `bypass_http_cache` (step 8) - then `addImportedScript`.
        fetch: struct { bypass_http_cache: bool },
    };

    /// importScripts() in the service worker `worker_id`, the fetch hook's
    /// steps 1-8 for `url` (serialized): the stored response, a network
    /// error, or a fetch to make. Step 5.1's used script is recorded here.
    pub fn importStep(self: *Registry, worker_id: u64, url: []const u8) Allocator.Error!ImportStep {
        // 1. serviceWorker: request's client's global object's service worker.
        const worker = self.findWorker(worker_id) orelse return .network_error;
        // 2-3. map, url.
        const stored = worker.resource(url);
        // 4. If serviceWorker's state is not "parsed" or "installing": map[url]
        // if it exists, a network error otherwise.
        if (worker.state != .parsed and worker.state != .installing) {
            const found = stored orelse return .network_error;
            return .{ .stored = try found.clone(self.allocator) };
        }
        // 5. If map[url] exists: append url to the set of used scripts, and
        // return map[url].
        if (stored) |found| {
            try self.markUsed(worker, url);
            return .{ .stored = try found.clone(self.allocator) };
        }
        // 6-8. The request's cache mode is "no-cache" when the registration's
        // update via cache mode is "none", the global's force bypass cache
        // for import scripts flag is set, or the registration is stale.
        // (7, its service-workers mode "none", is the fetch's.)
        const registration = worker.registration;
        const now = self.effects.now_ms(self.effects.ctx);
        return .{ .fetch = .{
            .bypass_http_cache = registration.update_via_cache == .none or
                worker.force_bypass_cache_for_imports or
                registration.isStale(now),
        } };
    }

    /// importScripts() in a service worker (6.3.2), what the fetch hook keeps:
    /// `resource` (taken) joins the worker's script resource map and set of
    /// used scripts, and its classic scripts imported flag is set.
    pub fn addImportedScript(self: *Registry, worker_id: u64, resource: Resource, checked_network: bool) Allocator.Error!void {
        var owned = resource;
        const worker = self.findWorker(worker_id) orelse return owned.deinit(self.allocator);
        // 10. A response not from the local cache sets the last update check
        // time.
        if (checked_network) worker.registration.last_update_check_time = self.effects.now_ms(self.effects.ctx);
        // 12. Set map[url] to response.
        for (worker.resources.items) |*existing| {
            if (std.mem.eql(u8, existing.url, owned.url)) {
                existing.deinit(self.allocator);
                existing.* = owned;
                worker.classic_scripts_imported = true;
                return self.markUsed(worker, existing.url);
            }
        }
        try worker.resources.append(self.allocator, owned);
        // 13. Append url to the set of used scripts.
        try self.markUsed(worker, owned.url);
        // 14. Set the classic scripts imported flag.
        worker.classic_scripts_imported = true;
    }

    /// A module script a module service worker's graph fetched beyond its
    /// root (the Update fetch hook's step 4, the "perform the fetch" hook
    /// for a non-top-level fetch): `resource` (taken) joins the worker's
    /// script resource map and set of used scripts while the worker is
    /// parsed or installing - its installed map, which an update compares
    /// (update_fetch.zig says why: the browsers do) - and is let go after.
    /// The classic scripts imported flag is not set.
    pub fn addModuleScript(self: *Registry, worker_id: u64, resource: Resource) Allocator.Error!void {
        var owned = resource;
        const worker = self.findWorker(worker_id) orelse return owned.deinit(self.allocator);
        if (worker.state != .parsed and worker.state != .installing) return owned.deinit(self.allocator);
        for (worker.resources.items) |*existing| {
            if (std.mem.eql(u8, existing.url, owned.url)) {
                existing.deinit(self.allocator);
                existing.* = owned;
                return self.markUsed(worker, existing.url);
            }
        }
        try worker.resources.append(self.allocator, owned);
        try self.markUsed(worker, owned.url);
    }

    fn markUsed(self: *Registry, worker: *Worker, url: []const u8) Allocator.Error!void {
        for (worker.used_scripts.items) |used| if (std.mem.eql(u8, used, url)) return;
        try worker.used_scripts.append(self.allocator, try self.allocator.dupe(u8, url));
    }
};

/// Service Worker Has No Pending Events: no extended event is active - and,
/// as Chromium counts its in-flight requests, no functional event handed to
/// the worker is still being handled (`events_in_flight`).
pub fn serviceWorkerHasNoPendingEvents(worker: *const Worker) bool {
    return worker.active_extended_events == 0 and worker.events_in_flight == 0;
}

/// Potentially trustworthy origin, for a serialized URL.
fn isTrustworthyUrl(allocator: Allocator, url: []const u8) Allocator.Error!bool {
    const origin = try scope_mod.originOf(allocator, url);
    defer allocator.free(origin);
    return @import("fetch").mixed_content.isOriginAuthenticated(allocator, origin);
}
