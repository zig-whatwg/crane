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
const router = @import("router.zig");

const Registry = registry_mod.Registry;
const TaskSink = runtime.TaskSink;
const WorkerLink = html.WorkerLink;
const PortMessage = @import("dom").port_channels.PortMessage;
const fetch = @import("fetch");
const InternalRequest = fetch.internal.InternalRequest;
const service_worker_fetch = fetch.internal.service_worker_fetch;
const Call = service_worker_fetch.Call;

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

/// A WindowClient's window data (Service Workers 4.2: its frame type is the
/// Client's; these are its visibility state, focus state and ancestor
/// origins array), as the window's own thread found them. OWNED.
pub const WindowData = struct {
    /// The active document's visibilityState is "visible".
    visible: bool = true,
    /// The has focus steps for the active document.
    focused: bool = false,
    /// The active document's ancestor origins list, serialized. OWNED, each
    /// and the slice.
    ancestor_origins: [][]u8 = &.{},

    pub fn clone(self: *const WindowData, allocator: Allocator) Allocator.Error!WindowData {
        const origins = try allocator.alloc([]u8, self.ancestor_origins.len);
        var made: usize = 0;
        errdefer {
            for (origins[0..made]) |o| allocator.free(o);
            allocator.free(origins);
        }
        for (self.ancestor_origins) |origin| {
            origins[made] = try allocator.dupe(u8, origin);
            made += 1;
        }
        return .{ .visible = self.visible, .focused = self.focused, .ancestor_origins = origins };
    }

    pub fn deinit(self: *WindowData, allocator: Allocator) void {
        for (self.ancestor_origins) |origin| allocator.free(origin);
        allocator.free(self.ancestor_origins);
        self.ancestor_origins = &.{};
    }
};

/// A service worker client as a service worker's realm makes its Client or
/// WindowClient object from it (Create Client, Create Window Client). OWNED.
pub const ClientInfo = struct {
    /// The client's environment in the registry: what Client.postMessage
    /// posts to.
    environment: u64,
    /// Its id.
    id: [36]u8,
    /// Its creation URL, serialized. OWNED.
    url: []u8,
    kind: registry_mod.EnvironmentKind,
    frame_type: registry_mod.FrameType = .none,
    /// A window client's window data: the object is a WindowClient. Null for
    /// a worker client.
    window: ?WindowData = null,

    /// The client `environment`, without its window data. Locked.
    fn of(allocator: Allocator, environment: *const registry_mod.Environment) Allocator.Error!ClientInfo {
        return .{
            .environment = environment.id,
            .id = environment.client_id,
            .url = try allocator.dupe(u8, environment.creation_url),
            .kind = environment.kind,
            .frame_type = environment.frame_type,
        };
    }

    pub fn clone(self: *const ClientInfo, allocator: Allocator) Allocator.Error!ClientInfo {
        var copy = self.*;
        copy.url = try allocator.dupe(u8, self.url);
        errdefer allocator.free(copy.url);
        copy.window = if (self.window) |*w| try w.clone(allocator) else null;
        return copy;
    }

    pub fn deinit(self: *ClientInfo, allocator: Allocator) void {
        allocator.free(self.url);
        if (self.window) |*w| w.deinit(allocator);
        self.window = null;
    }
};

/// Who posted a message to a service worker (ServiceWorker.postMessage step
/// 6.2.1): what its event's source is made from in the worker's realm.
pub const MessageSource = union(enum) {
    /// A service worker's global: the ServiceWorker object of its worker.
    service_worker: WorkerInfo,
    /// A client: a new WindowClient or Client representing it.
    client: ClientInfo,

    pub fn deinit(self: *MessageSource, allocator: Allocator) void {
        switch (self.*) {
            .service_worker => |*w| w.deinit(allocator),
            .client => |*c| c.deinit(allocator),
        }
    }
};

/// A message on its way to a service worker (ServiceWorker.postMessage):
/// StructuredSerializeWithTransfer's result with its transferred ports'
/// ends, who sent it and from which origin. Crosses threads; OWNED
/// (`destroy`) by whoever holds it last - the worker's task, or whatever
/// drops it, which discards its ports' ends.
pub const WorkerMessage = struct {
    allocator: Allocator,
    /// Taken by the task that delivers it.
    message: ?*PortMessage,
    /// incumbentSettings' origin, serialized. OWNED.
    origin: []u8,
    source: MessageSource,

    pub fn destroy(self: *WorkerMessage) void {
        if (self.message) |m| m.destroy();
        self.allocator.free(self.origin);
        self.source.deinit(self.allocator);
        self.allocator.destroy(self);
    }
};

/// A message on its way from a service worker to a client
/// (Client.postMessage step 4.5): the serialized message with its ports'
/// ends, sourceSettings' origin, and the service worker that sent it (its
/// ServiceWorker object in the client's realm is the source). OWNED
/// (`destroy`).
pub const ClientMessage = struct {
    allocator: Allocator,
    /// Taken by the task that delivers it.
    message: ?*PortMessage,
    /// sourceSettings' origin, serialized. OWNED.
    origin: []u8,
    /// The sending service worker, as the client's realm makes its object;
    /// filled in by the manager.
    source: ?WorkerInfo = null,

    pub fn destroy(self: *ClientMessage) void {
        if (self.message) |m| m.destroy();
        self.allocator.free(self.origin);
        if (self.source) |*s| s.deinit(self.allocator);
        self.allocator.destroy(self);
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
    /// The new controller as Notify Controller Change saw it.
    controller_change: ?WorkerInfo,
    ready: RegistrationInfo,
    /// getRegistration() step 8.2: the registration matched, or undefined.
    resolve_optional_registration: struct { promise: u64, registration: ?RegistrationInfo },
    /// getRegistrations() step 4.3: the registrations of the client's
    /// storage key. OWNED, each and the slice.
    resolve_registrations: struct { promise: u64, registrations: []RegistrationInfo },
    /// Client.postMessage step 4.5: a task for the client's container's
    /// client message queue. The message is OWNED until the realm side takes
    /// it (it sets the field to null).
    client_message: ?*ClientMessage,
    /// Clients' matchAll() step 2.6: the matched clients, sorted. OWNED,
    /// each and the slice.
    resolve_clients: struct { promise: u64, clients: []ClientInfo },
    /// Clients' get(id): the client (Resolve Get Client Promise), or
    /// undefined.
    resolve_client: struct { promise: u64, client: ?ClientInfo },
    /// WindowClient.navigate() step 7: navigate the window client's
    /// browsing context to `url` (OWNED) from its own event loop; the
    /// manager's navigate `id` hears how it went.
    navigate: struct { id: u64, url: []u8 },
    /// NavigationPreloadManager.getState() step 2.5: a NavigationPreloadState
    /// with the registration's flag and header value (OWNED).
    resolve_preload_state: struct { promise: u64, enabled: bool, header_value: []u8 },

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
            .controller_change => |m| .{ .controller_change = if (m) |w| try WorkerInfo.of(allocator, w) else null },
            .ready => |snapshot| .{ .ready = try infoOfSnapshot(allocator, registry, snapshot) },
        };
    }

    pub fn deinit(self: *Delivery, allocator: Allocator) void {
        switch (self.*) {
            .resolve_registration => |*m| m.registration.deinit(allocator),
            .registration_slot => |*m| if (m.worker) |*w| w.deinit(allocator),
            .controller_change => |*m| if (m.*) |*w| w.deinit(allocator),
            .ready => |*info| info.deinit(allocator),
            .resolve_optional_registration => |*m| if (m.registration) |*info| info.deinit(allocator),
            .resolve_registrations => |m| {
                for (m.registrations) |*info| info.deinit(allocator);
                allocator.free(m.registrations);
            },
            .client_message => |m| if (m) |message| message.destroy(),
            .resolve_clients => |m| {
                for (m.clients) |*info| info.deinit(allocator);
                allocator.free(m.clients);
            },
            .resolve_client => |*m| if (m.client) |*info| info.deinit(allocator),
            .navigate => |m| allocator.free(m.url),
            .resolve_preload_state => |m| allocator.free(m.header_value),
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

/// The realm side of `environment`, or null for a reserved client (no realm
/// yet). Locked.
fn endpointOfEnvironment(environment: *const registry_mod.Environment) ?*Endpoint {
    const opaque_endpoint = environment.endpoint orelse return null;
    return @ptrCast(@alignCast(opaque_endpoint));
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
    /// (BORROWED; what it takes of it, it clears) for this environment.
    deliver: *const fn (endpoint: *Endpoint, delivery: *Delivery) void,
    /// On the realm's thread, with the lock NOT held: a window client's
    /// window data, as a task on its event loop finds them (matchAll() step
    /// 2.5.1.6, Resolve Get Client Promise step 4.5) - null when the client
    /// is not enumerable (its document is no longer its browsing context's
    /// active document).
    window_data: *const fn (endpoint: *Endpoint, allocator: Allocator) ?WindowData,
    /// The same, read at once on the realm's thread from inside script (no
    /// task): what a thread about to block in a synchronous fetch leaves for
    /// the manager to answer from while it cannot run a task.
    window_data_now: *const fn (endpoint: *Endpoint, allocator: Allocator) ?WindowData,
    /// Static routing on the realm's thread (Handle Fetch step 13), for a
    /// request whose client - or whose reserved client's creator - this
    /// environment is. Null for an endpoint with no realm to lend (a test's):
    /// URL patterns then match nothing, and the cache finds nothing.
    router: ?*const RouterSteps = null,
};

/// What Handle Fetch's router asks of a realm on the fetching thread.
pub const RouterSteps = struct {
    /// Match Router Condition step 3.1.3: whether `url` matches `pattern` (a
    /// rule's compiled URL pattern), its regexps run in this realm.
    match_url_pattern: *const fn (endpoint: *Endpoint, pattern: *anyopaque, url: []const u8) bool,
    /// Step 13.3.3's cache source: the Browser's Cache Storage's response
    /// for `request` in `storage_key`'s caches (`cache_name`'s, or the first
    /// one), as fetch takes a service worker's - its body null, its bytes
    /// apart. OWNED by `allocator`; null: the network.
    cache_match: *const fn (endpoint: *Endpoint, allocator: Allocator, storage_key: []const u8, cache_name: ?[]const u8, request: *const InternalRequest) ?CacheHit,
};

/// A cache source's answer: the response (its body null) and its body's
/// bytes. OWNED.
pub const CacheHit = struct {
    response: *fetch.internal.InternalResponse,
    body: ?[]u8 = null,
};

/// A navigation's or a worker's reserved client (HTML "create navigation
/// params by fetching"'s, "run a worker" step 7's inside settings before the
/// fetch), as its creator holds it - dom.service_worker_clients' opaque
/// handle. OWNED by the creator until `createClient` or `releaseReserved`.
pub const ReservedClient = struct {
    manager: *Manager,
    kind: registry_mod.EnvironmentKind,
    /// The reserved environment, once Handle Fetch made one (0: none - no
    /// registration matched, or no fetch has asked).
    environment: u64 = 0,
    /// The creator's environment (0: none): a navigation request's client
    /// (its fetch event's clientId), and the thread a blocking fetch blocks.
    creator: u64 = 0,
    /// A worker whose script is a blob: URL of its owner's origin: the
    /// owner's active service worker when it was reserved (SW 2.5.2).
    inherited_worker: u64 = 0,
};

/// A fetch Handle Fetch hands to a service worker (Create Fetch Event and
/// Dispatch's inputs): the request as the worker's thread makes its Request
/// object from, the client ids its FetchEvent names, the worker, and the
/// call its answer goes to. OWNED by whoever holds it last - the job
/// thread, then the worker's task; `fail` answers handleFetchFailed.
pub const FetchDispatch = struct {
    allocator: Allocator,
    /// The service worker side's reference.
    call: *Call,
    /// requestForServiceWorker (HTTP fetch step 3.1), its body's bytes
    /// copied. OWNED, made with `allocator`.
    request: *InternalRequest,
    /// The request's client's id: clientId.
    client_id: ?[36]u8 = null,
    /// The reserved client's id: resultingClientId.
    resulting_client_id: ?[36]u8 = null,
    /// The request's replaces client id. OWNED.
    replaces_client_id: []u8,
    worker_id: u64,
    registration_id: u64,
    /// Handle Fetch step 12: Soft Update once the event was dispatched.
    soft_update: bool,
    /// Handle Fetch step 15.1: the registration's navigation preload header
    /// value, when its navigation preload is to be fetched for this request
    /// (a GET navigation of a registration whose flag is set). OWNED.
    preload_header: ?[]u8 = null,
    /// Handle Fetch step 14: timingInfo's start time - taken before step
    /// 15 waits for an activating worker (fetch's clock, ms).
    timing_start: f64 = 0,

    pub fn destroy(self: *FetchDispatch) void {
        self.request.deinit();
        self.allocator.free(self.replaces_client_id);
        if (self.preload_header) |value| self.allocator.free(value);
        self.call.release();
        self.allocator.destroy(self);
    }

    /// The event never ran: Handle Fetch returns a network error
    /// (handleFetchFailed), and the dispatch goes.
    pub fn fail(self: *FetchDispatch) void {
        self.call.answer(.network_error);
        self.destroy();
    }
};

/// A copy of `request` for another thread (HTTP fetch step 3.1's
/// requestForServiceWorker): what a Request object reads of it, nothing that
/// points back at its client. Its body's bytes are copied and owned. Null:
/// a body this thread cannot copy (a stream's), which goes to the network.
pub fn copyRequestForWorker(allocator: Allocator, request: *const InternalRequest) Allocator.Error!?*InternalRequest {
    const body_bytes: ?[]const u8 = if (request.body) |b| switch (b) {
        .bytes => |bytes| bytes,
        // A body still arriving through a pipe: its bytes are not here.
        .body => |body| if (body.pipe != null) null else body.getBytes(),
    } else &.{};
    const bytes = body_bytes orelse return null;
    // Its URL is the request's current URL - a redirect's next hop is the
    // request the worker sees, its url that hop's: what every browser's
    // fetch event shows (navigation-redirect.https.html's intercepted URLs,
    // fetch-event-redirect.https.html), where a clone's URL list would make
    // its Request object's url the first hop's (Fetch's request URL), and a
    // worker that redirects its navigation's first URL would see that URL
    // again at every hop.
    const copy = try InternalRequest.init(allocator, request.currentUrl());
    errdefer copy.deinit();
    try copy.setMethod(request.method);
    copy.header_list.deinit();
    copy.header_list = try request.header_list.clone(allocator);
    if (request.body != null) {
        const body = try allocator.create(fetch.internal.Body);
        body.* = fetch.internal.Body.init(allocator);
        body.data.appendSlice(allocator, bytes) catch |err| {
            body.deinit();
            return err;
        };
        body.length = bytes.len;
        // A byte sequence's body: its source is its own bytes (a body with
        // no source has its bytes only in a stream, which fetch() reads).
        body.source = .{ .bytes = body.data.items };
        copy.body = .{ .body = body };
    }
    copy.mode = request.mode;
    copy.credentials_mode = request.credentials_mode;
    copy.cache_mode = request.cache_mode;
    copy.redirect_mode = request.redirect_mode;
    copy.destination = request.destination;
    copy.initiator = request.initiator;
    copy.keepalive = request.keepalive;
    copy.priority = request.priority;
    copy.reload_navigation = request.reload_navigation;
    copy.history_navigation = request.history_navigation;
    copy.referrer_policy = request.referrer_policy;
    copy.service_workers_mode = request.service_workers_mode;
    switch (request.referrer) {
        .url => |url| try copy.setReferrerUrl(url),
        .no_referrer => copy.setReferrer(.no_referrer),
        .client => copy.setReferrer(.client),
    }
    switch (request.origin) {
        .origin => |origin| try copy.setOrigin(origin),
        .client => {},
    }
    // Its URL list is the hop alone: the redirect-taint the earlier hops
    // gave the request goes with it (InternalRequest.redirect_tainted).
    // Not computable (an unparsable URL in the list): tainted - the origin
    // serializes as "null".
    copy.redirect_tainted = !(request.redirectTaintIsSameOrigin() catch false);
    if (request.integrity_metadata.len > 0) copy.integrity_metadata = try allocator.dupe(u8, request.integrity_metadata);
    return copy;
}

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
    /// ServiceWorker.postMessage step 6.2: queue the task that fires
    /// `message`'s event (taken) at the worker's global object; once it is
    /// dispatched and no longer active - or its task is discarded - the
    /// worker reports `.message_done` with `worker_id` and `generation`.
    /// Called with the lock held: it only posts.
    post_message: *const fn (manager: *Manager, started: Started, message: *WorkerMessage, worker_id: u64, generation: u64) void,
    /// Create Fetch Event and Dispatch step 17.4: queue the task that fires
    /// `dispatch`'s fetch event (taken) at the worker's global object; its
    /// answer goes to the dispatch's call, and once the event is no longer
    /// active - or its task is discarded - the worker reports `.fetch_done`
    /// with `worker_id` and `generation`. Called with the lock held: it only
    /// posts.
    dispatch_fetch: *const fn (manager: *Manager, started: Started, dispatch: *FetchDispatch, worker_id: u64, generation: u64) void,
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
    /// Messages waiting for their service worker to start
    /// (ServiceWorker.postMessage step 6.1), by the registry `other` waiter
    /// that will answer for them.
    pending_messages: std.ArrayListUnmanaged(PendingMessage) = .empty,
    next_waiter: u64 = 1,
    /// Clients' matchAll() and get() calls waiting for their window
    /// clients' window data.
    client_queries: std.ArrayListUnmanaged(*ClientQuery) = .empty,
    next_query: u64 = 1,
    /// Fetch events waiting for their service worker to start (Create Fetch
    /// Event and Dispatch steps 15-16), by the registry `other` waiter that
    /// will answer for them.
    pending_fetches: std.ArrayListUnmanaged(PendingFetch) = .empty,
    /// Threads blocked in a synchronous fetch a service worker answers, by
    /// their loop's sink: their window clients' data, read before they
    /// blocked, which a client query is answered from meanwhile.
    blocked: std.ArrayListUnmanaged(BlockedThread) = .empty,
    /// Registrations whose Soft Update waits out `soft_update_delay_ms`.
    soft_updates: std.ArrayListUnmanaged(PendingSoftUpdate) = .empty,
    /// Client.postMessage()s to a reserved client, waiting for the realm
    /// that adopts it (`createClient`) - or for its discard, which drops
    /// them.
    reserved_messages: std.ArrayListUnmanaged(ReservedMessage) = .empty,
    /// WindowClient.navigate() calls waiting for the browsing context they
    /// navigate to have its next window client.
    navigates: std.ArrayListUnmanaged(PendingNavigate) = .empty,
    next_navigate: u64 = 1,
    /// How long a fetch's Soft Update waits for the burst it is part of to
    /// end (`scheduleSoftUpdate`).
    soft_update_delay_ms: u64 = 1000,

    const PendingMessage = struct {
        waiter: u64,
        message: *WorkerMessage,
    };

    const ReservedMessage = struct {
        environment: u64,
        message: *ClientMessage,
    };

    const PendingNavigate = struct {
        id: u64,
        /// The navigated client's browsing context (identity).
        navigable: usize,
        /// The service worker's environment, whose promise it settles, and
        /// its origin (step 7.9.1). OWNED.
        environment: u64,
        promise: u64,
        origin: []u8,
    };

    const PendingFetch = struct {
        waiter: u64,
        dispatch: *FetchDispatch,
    };

    const BlockedThread = struct {
        /// BORROWED (each snapshot's realm holds its sink).
        sink: *TaskSink,
        /// How many blocking waits on that thread are under way (nested
        /// ones cannot be; counted for safety).
        depth: u32 = 1,
        snapshots: std.ArrayListUnmanaged(Snapshot) = .empty,

        const Snapshot = struct {
            environment: u64,
            data: WindowData,
        };

        fn deinit(self: *BlockedThread, allocator: Allocator) void {
            for (self.snapshots.items) |*snapshot| snapshot.data.deinit(allocator);
            self.snapshots.deinit(allocator);
        }
    };

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
        for (self.pending_messages.items) |pending| pending.message.destroy();
        self.pending_messages.deinit(self.allocator);
        for (self.client_queries.items) |query| query.destroy(self.allocator);
        self.client_queries.deinit(self.allocator);
        for (self.pending_fetches.items) |pending| pending.dispatch.fail();
        self.pending_fetches.deinit(self.allocator);
        for (self.blocked.items) |*thread| thread.deinit(self.allocator);
        self.blocked.deinit(self.allocator);
        self.soft_updates.deinit(self.allocator);
        for (self.reserved_messages.items) |entry| entry.message.destroy();
        self.reserved_messages.deinit(self.allocator);
        for (self.navigates.items) |pending| self.allocator.free(pending.origin);
        self.navigates.deinit(self.allocator);
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
            const endpoint = endpointOfEnvironment(environment) orelse continue;
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
        const endpoint = endpointOfEnvironment(environment) orelse return owned.deinit(self.allocator);
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

    /// Whether the client whose id is `client_id` is controlled by the
    /// service worker `worker_id` (WindowClient.navigate() step 4).
    pub fn clientControlledBy(self: *Manager, client_id: []const u8, worker_id: u64) bool {
        self.lock();
        defer self.unlock();
        const client = self.registry.findClient(client_id) orelse return false;
        const worker = client.active_worker orelse return false;
        return worker.id == worker_id;
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

    /// A NavigationPreloadManager method's "in parallel" steps (3.6.1-3.6.4).
    pub const PreloadOp = union(enum) {
        enable,
        disable,
        /// The normalized header value (BORROWED for the call).
        set_header_value: []const u8,
        get_state,
    };

    /// NavigationPreloadManager's in parallel steps for the registration
    /// `registration_id`, for the promise `promise` of the environment
    /// `environment_id`: atomic reads and writes of the registration's
    /// navigation preload enabled flag and header value - its record holds
    /// them for as long as it lives - done under the lock, then the promise
    /// settled in a later task of the environment's loop (steps 2.2 and 2.4:
    /// "queue a task on promise's relevant settings object's responsible
    /// event loop, using the DOM manipulation task source").
    pub fn navigationPreload(self: *Manager, environment_id: u64, registration_id: u64, op: PreloadOp, promise: u64) void {
        const delivery = self.navigationPreloadSteps(registration_id, op, promise) catch
            Delivery{ .reject = .{ .promise = promise, .kind = .type_error, .message = "Out of memory" } };
        self.deliverLater(environment_id, delivery);
    }

    fn navigationPreloadSteps(self: *Manager, registration_id: u64, op: PreloadOp, promise: u64) Allocator.Error!Delivery {
        self.lock();
        defer self.unlock();
        const registration = self.registry.findRegistration(registration_id);
        switch (op) {
            .get_state => {
                // 2.2-2.4. A new NavigationPreloadState: enabled when the
                // flag is set; headerValue the registration's.
                const r = registration orelse return .{ .reject = .{ .promise = promise, .kind = .invalid_state_error, .message = "The registration has gone" } };
                return .{ .resolve_preload_state = .{
                    .promise = promise,
                    .enabled = r.navigation_preload_enabled,
                    .header_value = try self.allocator.dupe(u8, r.navigation_preload_header_value),
                } };
            },
            else => {},
        }
        // 2.2 (enable, disable) / 4.2 (setHeaderValue): no active worker -
        // an InvalidStateError.
        const r = registration orelse return noActiveWorker(promise);
        if (r.active == null) return noActiveWorker(promise);
        switch (op) {
            // 2.3. Set / unset the navigation preload enabled flag.
            .enable => r.navigation_preload_enabled = true,
            .disable => r.navigation_preload_enabled = false,
            // 4.3. Set the navigation preload header value.
            .set_header_value => |value| {
                const owned = try self.allocator.dupe(u8, value);
                self.allocator.free(r.navigation_preload_header_value);
                r.navigation_preload_header_value = owned;
            },
            .get_state => unreachable,
        }
        // 2.4 / 4.4. Resolve with undefined.
        return .{ .resolve_undefined = .{ .promise = promise } };
    }

    fn noActiveWorker(promise: u64) Delivery {
        return .{ .reject = .{ .promise = promise, .kind = .invalid_state_error, .message = "The registration has no active worker" } };
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
        /// it did not run to completion, or its global could not be made);
        /// `handles_fetch`: its global has a listener of type fetch now (the
        /// set of event types to handle, kept the first time).
        evaluated: struct { worker: u64, ok: bool, handles_fetch: bool },
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
        /// ServiceWorker.postMessage step 6: `message` (OWNED) for the
        /// service worker `worker`.
        post_message: struct { worker: u64, message: *WorkerMessage },
        /// A message event handed to `worker` in its run `generation` is
        /// done: dispatched and no longer active, or its task discarded.
        message_done: struct { worker: u64, generation: u64 },
        /// The window data task for `slot` of the client query `query` was
        /// discarded: that client is not enumerable.
        window_data_missing: struct { query: u64, slot: usize },
        /// Handle Fetch handed a request to a service worker: Create Fetch
        /// Event and Dispatch from step 15. OWNED.
        fetch: *FetchDispatch,
        /// A fetch event handed to `worker` in its run `generation` is done:
        /// dispatched and no longer active, or its task discarded. Its
        /// registration `soft_update` (0: none) is to be soft-updated
        /// (Create Fetch Event and Dispatch step 19).
        fetch_done: struct { worker: u64, generation: u64, soft_update: u64 = 0 },
        /// Soft Update for the registration (Create Fetch Event and Dispatch
        /// step 11.1 for a skipped event; Handle Fetch step 13's router
        /// sources).
        soft_update: u64,
        /// InstallEvent.addRoutes() step 9, enqueued to the worker's
        /// [[service worker queue]] (this thread): `rules` (OWNED, made with
        /// the manager's allocator, freed through `ops`) joins the worker's
        /// list of router rules if Check Router Registration Limit allows;
        /// the promise `promise` of the worker's environment `environment`
        /// settles either way.
        add_routes: struct { allocator: Allocator, worker: u64, rules: []router.Rule, ops: router.PatternOps, environment: u64, promise: u64 },

        fn deinit(self: *Report) void {
            switch (self.*) {
                .post_message => |r| r.message.destroy(),
                .fetch => |dispatch| dispatch.fail(),
                .add_routes => |r| router.freeRules(r.allocator, r.rules, r.ops),
                else => {},
            }
        }
    };

    /// Post `report` (taken) to the job thread. Any thread; a manager whose
    /// job thread has ended drops it.
    pub fn report(self: *Manager, from: Report) void {
        var owned = from;
        const task = self.allocator.create(ReportTask) catch {
            log.debug("out of memory posting a service worker's report; dropped", .{});
            owned.deinit();
            return;
        };
        task.* = .{ .manager = self, .report = owned };
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
            self.report.deinit();
            self.manager.allocator.destroy(self);
        }
    };

    fn handleReport(self: *Manager, from: Report) Allocator.Error!void {
        self.lock();
        defer self.unlock();
        switch (from) {
            .evaluated => |r| try self.registry.workerEvaluated(r.worker, r.ok, r.handles_fetch),
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
            .post_message => |r| try self.postMessageNow(r.worker, r.message),
            .message_done => |r| try self.registry.functionalEventDone(r.worker, r.generation),
            .window_data_missing => |r| {
                const query = self.findQuery(r.query) orelse return;
                self.queryAnswered(query, r.slot, null);
            },
            .fetch => |dispatch| try self.fetchNow(dispatch),
            .fetch_done => |r| {
                try self.registry.functionalEventDone(r.worker, r.generation);
                if (r.soft_update != 0) self.scheduleSoftUpdate(r.soft_update);
            },
            .soft_update => |id| self.scheduleSoftUpdate(id),
            .add_routes => |r| try self.addRoutesNow(r.worker, r.rules, r.ops, r.environment, r.promise),
        }
    }

    // ------------------------------------------------------------------
    // Clients at creation (a realm's own thread)
    // ------------------------------------------------------------------

    /// A reserved client for a fetch made from the environment `creator`
    /// (0: none), for a client of `kind`; `inherited_worker` is a worker's
    /// owner's active service worker it inherits (a blob: script). OWNED by
    /// the caller (`createClient` or `releaseReserved`).
    pub fn reserveClient(self: *Manager, kind: registry_mod.EnvironmentKind, creator: u64, inherited_worker: u64) ?*ReservedClient {
        const handle = self.allocator.create(ReservedClient) catch return null;
        handle.* = .{ .manager = self, .kind = kind, .creator = creator, .inherited_worker = inherited_worker };
        return handle;
    }

    /// The active service worker of the environment `id` when its origin
    /// is `origin` (0: none, or another origin).
    pub fn controllerOfSameOrigin(self: *Manager, id: u64, origin: []const u8) u64 {
        self.lock();
        defer self.unlock();
        const environment = self.registry.findEnvironment(id) orelse return 0;
        if (!std.mem.eql(u8, environment.origin, origin)) return 0;
        const worker = environment.active_worker orelse return 0;
        return worker.id;
    }

    /// What a realm becoming a client brings (`createClient`).
    pub const ClientValues = struct {
        kind: registry_mod.EnvironmentKind,
        /// Serialized; its storage key.
        origin: []const u8,
        creation_url: []const u8,
        secure_context: bool,
        frame_type: registry_mod.FrameType = .none,
        endpoint: *Endpoint,
        /// TAKEN: the reserved client of the fetch that made the realm's
        /// document or script, if one went through HTTP fetch.
        reserved: ?*ReservedClient = null,
        /// A window's creator's environment (0: none).
        creator: u64 = 0,
        /// A window client's browsing context, as an identity (0: none).
        navigable: usize = 0,
    };

    /// A realm is a service worker client from now on (Service Workers 2.5;
    /// HTML "set up a window environment settings object" step 4, "run a
    /// worker" step 7). It takes over its reserved environment - the id and
    /// active service worker Handle Fetch gave it - when there is one of the
    /// same origin; a reserved environment of another origin (a cross-origin
    /// redirect, a sandboxed opaque document) is discarded. Otherwise its
    /// active service worker is what it inherits: a window's creator's, same
    /// origin, when no fetch went through HTTP for it (2.5.1); a worker's,
    /// what its reservation decided (2.5.2). Its id.
    pub fn createClient(self: *Manager, values: ClientValues) Allocator.Error!u64 {
        var requests: std.ArrayListUnmanaged(WindowDataRequest) = .empty;
        defer requests.deinit(self.allocator);
        defer if (values.reserved) |reserved| self.allocator.destroy(reserved);
        const id = blk: {
            self.lock();
            defer self.unlock();
            if (values.reserved) |reserved| if (reserved.environment != 0) {
                if (self.registry.findEnvironment(reserved.environment)) |environment| {
                    if (environment.endpoint == null and std.mem.eql(u8, environment.origin, values.origin)) {
                        try self.registry.adoptEnvironment(environment, .{
                            .endpoint = values.endpoint,
                            .creation_url = values.creation_url,
                            .frame_type = values.frame_type,
                        });
                        environment.secure_context = values.secure_context;
                        environment.navigable = values.navigable;
                        // The messages a service worker sent it meanwhile.
                        self.deliverReservedMessages(environment);
                        self.navigated(&requests, values.navigable, environment) catch {};
                        break :blk environment.id;
                    }
                    if (environment.endpoint == null) self.discardReserved(environment);
                }
            };
            const environment = try self.registry.addEnvironment(.{
                .kind = values.kind,
                .origin = values.origin,
                .creation_url = values.creation_url,
                .secure_context = values.secure_context,
                .frame_type = values.frame_type,
                .navigable = values.navigable,
                .endpoint = values.endpoint,
            });
            const inherited: ?*registry_mod.Worker = if (values.reserved) |reserved|
                (if (reserved.inherited_worker != 0) self.registry.findWorker(reserved.inherited_worker) else null)
            else if (values.creator != 0) inherit: {
                const creator = self.registry.findEnvironment(values.creator) orelse break :inherit null;
                if (!std.mem.eql(u8, creator.origin, values.origin)) break :inherit null;
                break :inherit creator.active_worker;
            } else null;
            if (inherited) |worker| self.registry.setActiveWorker(environment, worker);
            self.navigated(&requests, values.navigable, environment) catch {};
            break :blk environment.id;
        };
        self.postWindowDataRequests(requests.items);
        return id;
    }

    /// A reserved client never handed to `createClient` (taken): its
    /// reserved environment, if Handle Fetch made one, is discarded - HTML's
    /// environment discarding steps (SW 2.4: its discarded flag): a get() of
    /// it is undefined from now on, and the messages waiting for it go.
    pub fn releaseReserved(self: *Manager, reserved: *ReservedClient) void {
        {
            self.lock();
            defer self.unlock();
            if (reserved.environment != 0) {
                if (self.registry.findEnvironment(reserved.environment)) |environment| {
                    if (environment.endpoint == null) self.discardReserved(environment);
                }
            }
        }
        self.allocator.destroy(reserved);
    }

    // ------------------------------------------------------------------
    // WindowClient.navigate() (steps 5-7.9)
    // ------------------------------------------------------------------

    /// WindowClient.navigate() steps 5-7 for the service worker whose
    /// environment is `environment_id` (its origin `origin`), settling its
    /// promise `promise`: the window client `client_id` navigates its
    /// browsing context to `url` (serialized) as a task of its own loop; the
    /// next window client of that browsing context settles the promise
    /// (`navigated`). A client gone, or no window, rejects with a TypeError.
    pub fn navigateClient(self: *Manager, client_id: []const u8, url: []const u8, environment_id: u64, origin: []const u8, promise: u64) Allocator.Error!void {
        self.lock();
        defer self.unlock();
        const client = self.registry.findClient(client_id) orelse return self.navigateFailed(environment_id, promise);
        if (client.kind != .window or client.navigable == 0 or client.endpoint == null) return self.navigateFailed(environment_id, promise);
        const owned_origin = try self.allocator.dupe(u8, origin);
        errdefer self.allocator.free(owned_origin);
        const owned_url = try self.allocator.dupe(u8, url);
        errdefer self.allocator.free(owned_url);
        const id = self.next_navigate;
        self.next_navigate += 1;
        try self.navigates.append(self.allocator, .{ .id = id, .navigable = client.navigable, .environment = environment_id, .promise = promise, .origin = owned_origin });
        self.postDelivery(client, .{ .navigate = .{ .id = id, .url = owned_url } });
    }

    fn navigateFailed(self: *Manager, environment_id: u64, promise: u64) void {
        self.postDeliveryTo(environment_id, .{ .reject = .{ .promise = promise, .kind = .type_error, .message = "The client could not be navigated" } });
    }

    /// Step 7.2/7.4 from the client's thread: the navigation `id` could not
    /// start (the document is not fully active, or navigating threw) - a
    /// TypeError.
    pub fn navigateEnded(self: *Manager, id: u64) void {
        self.lock();
        defer self.unlock();
        for (self.navigates.items, 0..) |pending, i| {
            if (pending.id != id) continue;
            _ = self.navigates.swapRemove(i);
            self.allocator.free(pending.origin);
            return self.navigateFailed(pending.environment, pending.promise);
        }
    }

    /// The browsing context `navigable` has a new window client,
    /// `environment` (null: one of an opaque origin, which is none): each
    /// navigate() waiting for it resolves - with null for another origin
    /// than the service worker's (7.9.1), with the client otherwise (7.9.2:
    /// Create Window Client, its window data from its loop). Locked.
    fn navigated(self: *Manager, requests: *std.ArrayListUnmanaged(WindowDataRequest), navigable: usize, environment: ?*registry_mod.Environment) Allocator.Error!void {
        if (navigable == 0) return;
        var index: usize = 0;
        while (index < self.navigates.items.len) {
            const pending = self.navigates.items[index];
            if (pending.navigable != navigable) {
                index += 1;
                continue;
            }
            _ = self.navigates.swapRemove(index);
            defer self.allocator.free(pending.origin);
            const client = environment orelse {
                self.postDeliveryTo(pending.environment, .{ .resolve_client = .{ .promise = pending.promise, .client = null } });
                continue;
            };
            if (!std.mem.eql(u8, client.origin, pending.origin)) {
                self.postDeliveryTo(pending.environment, .{ .resolve_client = .{ .promise = pending.promise, .client = null } });
                continue;
            }
            try self.resolveGetClient(requests, pending.environment, client, pending.promise);
        }
    }

    /// The browsing context `navigable` has a new document of an opaque
    /// origin, which is no client: a navigate() waiting for it resolves with
    /// null.
    pub fn navigatedToOpaque(self: *Manager, navigable: usize) void {
        var requests: std.ArrayListUnmanaged(WindowDataRequest) = .empty;
        defer requests.deinit(self.allocator);
        {
            self.lock();
            defer self.unlock();
            self.navigated(&requests, navigable, null) catch {};
        }
        self.postWindowDataRequests(requests.items);
    }

    /// The route the requests of the client whose realm is `realm` take to
    /// Handle Fetch - only while a service worker controls it (step 10).
    pub fn routeForRealm(self: *Manager, realm: *const anyopaque) ?service_worker_fetch.Route {
        self.lock();
        defer self.unlock();
        for (self.registry.environments.items) |environment| {
            const endpoint = endpointOfEnvironment(environment) orelse continue;
            if (endpoint.realm != realm) continue;
            if (environment.active_worker == null) return null;
            return .{ .context = self, .client = environment.id, .handle = handleFetchRoute };
        }
        return null;
    }

    /// How many registrations the registration map holds.
    pub fn registrationCount(self: *Manager) usize {
        self.lock();
        defer self.unlock();
        return self.registry.registrations.items.len;
    }

    /// The route a reserved client's request takes to Handle Fetch.
    pub fn routeOfReserved(self: *Manager) service_worker_fetch.Route {
        return .{ .context = self, .client = 0, .handle = handleFetchRoute };
    }

    // ------------------------------------------------------------------
    // Handle Fetch (the fetching thread)
    // ------------------------------------------------------------------

    fn handleFetchRoute(context: *anyopaque, request: *const InternalRequest, client: u64) Allocator.Error!service_worker_fetch.Route.Start {
        const self: *Manager = @ptrCast(@alignCast(context));
        return self.handleFetch(request, client);
    }

    /// Handle Fetch steps 1-12, on the fetching thread: whether a service
    /// worker handles `request` - and, if one does, Create Fetch Event and
    /// Dispatch begins on the job thread with requestForServiceWorker, and
    /// the call its answer comes on goes back to fetch.
    pub fn handleFetch(self: *Manager, request: *const InternalRequest, client: u64) Allocator.Error!service_worker_fetch.Route.Start {
        // 7-8. A service worker's own script never comes here (its fetch's
        // service-workers mode is "none"); embed and object are not handled.
        switch (request.destination) {
            .serviceworker, .embed, .object => return .network,
            else => {},
        }
        var worker_id: u64 = 0;
        var registration_id: u64 = 0;
        var soft_update = false;
        var client_id: ?[36]u8 = null;
        var resulting_client_id: ?[36]u8 = null;
        var blocked: u64 = 0;
        // Create Fetch Event and Dispatch step 11: Should Skip Event.
        var skip = false;
        // Handle Fetch step 15.1's preloadRequest header value.
        var preload_header: ?[]u8 = null;
        defer if (preload_header) |value| self.allocator.free(value);
        // Step 13.3.4: a "race-network-and-fetch-handler" source - the fetch
        // event races the network.
        var race = false;
        // Step 13: the active worker's list of router rules (a reference),
        // whether it runs, the environment whose realm evaluates them on
        // this thread, and the storage key a cache source reads.
        var routing: Routing = .{};
        defer routing.deinit(self.allocator);
        if (request.isNonSubresourceRequest()) {
            // 9. A navigation's or a worker's: its reserved client decides.
            const opaque_reserved = request.reserved_client orelse return .network;
            const reserved: *ReservedClient = @ptrCast(@alignCast(opaque_reserved));
            const url = request.currentUrl();
            const origin = try @import("scope.zig").originOf(self.allocator, url);
            defer self.allocator.free(origin);
            // 9.1-9.2. The reserved client is no settings object yet: the
            // request's URL must be potentially trustworthy.
            if (!(try fetch.mixed_content.isOriginAuthenticated(self.allocator, origin))) return .network;
            // 9.3. Crane's navigations are never shift+reload.
            self.lock();
            defer self.unlock();
            const existing = if (reserved.environment != 0) self.registry.findEnvironment(reserved.environment) else null;
            // 9.1-9.2 for a nested navigable's reserved environment: HTML "is
            // a secure context" reads an environment's top-level creation URL
            // (step 2), so a frame inside a document that is not a secure
            // context is none either, whatever its own URL - its creator, the
            // container document, says so. Step 9.2.1's URL check is a
            // top-level navigation's answer. All three browsers bypass the
            // service worker here (secure-context.https.html: an https frame
            // in an http document is not intercepted; wpt.fyi df642c4142).
            if (request.destination == .iframe or request.destination == .frame) {
                if (reserved.creator != 0) if (self.registry.findEnvironment(reserved.creator)) |creator| {
                    if (!creator.secure_context) return .network;
                };
            }
            // 9.5-9.8, 11-12.
            const matched = (try self.registry.handleFetchNonSubresource(.{
                .url = url,
                .reserve = .{ .kind = reserved.kind, .origin = origin, .creation_url = url },
                .reserved = existing,
                .destination_is_report = request.destination == .report,
            })) orelse return .network;
            if (matched.reserved) |environment| {
                reserved.environment = environment.id;
                // Create Fetch Event and Dispatch step 17.4.9: resultingClientId.
                resulting_client_id = environment.client_id;
            }
            // 17.4.8: clientId, the request's client's - its initiator's. A
            // navigation's is the empty string in every browser (wpt.fyi
            // fetch-event.https.html "existing client id": Chrome, Firefox and
            // Safari answer "Client ID Not Found" for a frame's navigation);
            // a worker's script names its owner.
            if (!request.isNavigationRequest() and reserved.creator != 0) {
                if (self.registry.findEnvironment(reserved.creator)) |creator| client_id = creator.client_id;
            }
            worker_id = matched.worker.id;
            registration_id = matched.worker.registration.id;
            soft_update = matched.soft_update;
            blocked = reserved.creator;
            skip = shouldSkipFetchEvent(matched.worker);
            // 13.3.3.4: a non-subresource request's cache source reads the
            // reserved client's storage - its origin's.
            try routing.take(self, matched.worker, reserved.creator, origin);
            // 15. A GET navigation request of a registration whose active
            // worker handles fetch: with its navigation preload enabled flag
            // set, the preload request is fetched (15.1) - by the service
            // worker's thread, from its fetch event's task (navigation_preload
            // .zig says why there). The active worker's all fetch listeners
            // are empty flag is not tracked (stated, batch 1).
            if (!skip and request.isNavigationRequest() and std.mem.eql(u8, request.method, "GET") and
                matched.worker.registration.navigation_preload_enabled)
            {
                preload_header = try self.allocator.dupe(u8, matched.worker.registration.navigation_preload_header_value);
            }
        } else {
            // 10. A subresource request: its client's active service worker.
            if (client == 0) return .network;
            self.lock();
            defer self.unlock();
            const environment = self.registry.findEnvironment(client) orelse return .network;
            const matched = self.registry.handleFetchSubresource(environment) orelse return .network;
            client_id = environment.client_id;
            worker_id = matched.worker.id;
            registration_id = matched.worker.registration.id;
            soft_update = matched.soft_update;
            blocked = client;
            skip = shouldSkipFetchEvent(matched.worker);
            // 13.3.3.5: a subresource request's, its client's.
            try routing.take(self, matched.worker, client, environment.origin);
        }
        // 13. Router rules: their source decides, before any fetch event.
        if (routing.rules) |list| {
            // 13.1 (the worker router evaluation start) is no timing Crane
            // reports. 13.2. Get Router Source.
            const facts: router.RequestFacts = .{
                .url = request.currentUrl(),
                .method = request.method,
                .mode = request.mode,
                .destination = request.destination,
            };
            const matcher: ?router.Matcher = if (routing.endpoint) |endpoint|
                (if (endpoint.router != null) router.Matcher{ .context = endpoint, .matches = endpointMatches } else null)
            else
                null;
            if (router.getRouterSource(list.rules, routing.running, facts, matcher)) |source| switch (source.*) {
                // 13.3.2. network: Soft Update when due; Handle Fetch
                // returns the timing info - the network.
                .network => {
                    if (soft_update) self.report(.{ .soft_update = registration_id });
                    return .network;
                },
                // 13.3.3. cache: Soft Update when due; the cache's response,
                // or the network.
                .cache => |name| {
                    if (soft_update) self.report(.{ .soft_update = registration_id });
                    if (try self.cacheSourceAnswer(&routing, name, request)) |call| return .{ .call = call };
                    return .network;
                },
                // 13.3.4. race-network-and-fetch-handler, for a GET: the fetch
                // event is dispatched as for fetch-event (13.3.4.7), and the
                // call goes back to fetch as a race - its driver fetches the
                // request from the network beside it (13.3.4.5, AsyncFetch's
                // race) and takes the first usable answer. No navigation
                // preload (13.3.4.6 resolves preloadResponse with
                // undefined). The Soft Update of 13.3.4.1 is the event's own
                // (step 19's), once - two would queue one update. Another
                // method: 13.3.5, fetch-event.
                .race_network_and_fetch_handler => race = std.mem.eql(u8, request.method, "GET"),
                // 13.3.5. fetch-event: on to step 14.
                .fetch_event => {},
            };
        }
        // Create Fetch Event and Dispatch step 11: the event is skipped - Soft
        // Update if it was due, and Handle Fetch returns null (the network).
        // The client a navigation reserved is controlled all the same (step
        // 9.8 ran).
        if (skip) {
            if (soft_update) self.report(.{ .soft_update = registration_id });
            return .network;
        }
        // 13.3.4.6: a raced request's preloadResponse is undefined.
        if (race) if (preload_header) |value| {
            self.allocator.free(value);
            preload_header = null;
        };
        // 3.1-3.2 (HTTP fetch): requestForServiceWorker, for the worker's
        // thread. A body only a stream holds goes to the network (stated).
        const copy = (try copyRequestForWorker(self.allocator, request)) orelse return .network;
        errdefer copy.deinit();
        const replaces = try self.allocator.dupe(u8, request.replaces_client_id);
        errdefer self.allocator.free(replaces);
        const call = try Call.create(self.allocator);
        errdefer self.allocator.destroy(call);
        const dispatch = try self.allocator.create(FetchDispatch);
        dispatch.* = .{
            .allocator = self.allocator,
            .call = call,
            .request = copy,
            .client_id = client_id,
            .resulting_client_id = resulting_client_id,
            .replaces_client_id = replaces,
            .worker_id = worker_id,
            .registration_id = registration_id,
            .soft_update = soft_update,
            .preload_header = preload_header,
            // 14. timingInfo's start time: the coarsened shared current time
            // (fetch's clock; Resource Timing coarsens on conversion).
            .timing_start = fetch.algorithms.http_fetch.getCurrentTimeMs(),
        };
        preload_header = null;
        // A fetch that blocks its thread leaves that thread's window data
        // answerable meanwhile (`beforeBlockingWait`).
        call.blocking = .{ .context = self, .data = blocked, .before_wait = beforeBlockingWait, .after_wait = afterBlockingWait };
        // 17. Create Fetch Event and Dispatch, from step 15, on the job
        // thread.
        self.report(.{ .fetch = dispatch });
        if (race) return .{ .race = call };
        return .{ .call = call };
    }

    /// What Handle Fetch step 13 needs, gathered under the lock and used
    /// after it.
    const Routing = struct {
        /// The active worker's list of router rules: a reference.
        rules: ?*router.Rules = null,
        /// The active worker is running (runningStatus).
        running: bool = false,
        /// The environment - the request's client, or the reserved client's
        /// creator - whose realm, on this thread, matches URL patterns and
        /// reads the cache. It ends only on this thread: it outlives the
        /// call.
        endpoint: ?*Endpoint = null,
        /// The storage key a cache source reads. OWNED.
        storage_key: ?[]u8 = null,

        /// For `worker`'s rules, if it has any (a registration with none
        /// pays nothing more).
        fn take(self: *Routing, manager: *Manager, worker: *const registry_mod.Worker, environment_id: u64, storage_key: []const u8) Allocator.Error!void {
            const list = worker.router_rules orelse return;
            self.storage_key = try manager.allocator.dupe(u8, storage_key);
            self.rules = list.retain();
            self.running = worker.run == .running;
            if (environment_id != 0) {
                if (manager.registry.findEnvironment(environment_id)) |environment| self.endpoint = endpointOfEnvironment(environment);
            }
        }

        fn deinit(self: *Routing, allocator: Allocator) void {
            if (self.rules) |list| list.release();
            if (self.storage_key) |key| allocator.free(key);
            self.* = .{};
        }
    };

    fn endpointMatches(context: ?*anyopaque, pattern: *anyopaque, url: []const u8) bool {
        const endpoint: *Endpoint = @ptrCast(@alignCast(context.?));
        const steps = endpoint.router orelse return false;
        return steps.match_url_pattern(endpoint, pattern, url);
    }

    /// Handle Fetch step 13.3.3 for the cache source `cache_name`: the
    /// response the Browser's Cache Storage holds for `request`, as a call
    /// already answered - fetch takes it as it takes a service worker's,
    /// its body through a relay. Null: none, the network.
    fn cacheSourceAnswer(self: *Manager, routing: *const Routing, cache_name: ?[]const u8, request: *const InternalRequest) Allocator.Error!?*Call {
        const endpoint = routing.endpoint orelse return null;
        const steps = endpoint.router orelse return null;
        const hit = steps.cache_match(endpoint, self.allocator, routing.storage_key.?, cache_name, request) orelse return null;
        const call = Call.create(self.allocator) catch |err| {
            hit.response.deinit();
            if (hit.body) |b| self.allocator.free(b);
            return err;
        };
        var relay: ?*service_worker_fetch.BodyRelay = null;
        if (hit.body) |bytes| {
            defer self.allocator.free(bytes);
            const r = service_worker_fetch.BodyRelay.create(self.allocator) catch |err| {
                hit.response.deinit();
                call.release();
                call.release();
                return err;
            };
            _ = r.write(bytes);
            r.close();
            // The writer's reference: all written.
            r.release();
            relay = r;
        }
        // The answer, and the side that gave it lets go.
        call.answer(.{ .response = .{ .response = hit.response, .body = relay } });
        call.release();
        return call;
    }

    /// InstallEvent.addRoutes() steps 9.1-9.5 on the job thread, locked:
    /// allRules, the worker's list with `rules` (taken) appended; Check
    /// Router Registration Limit; the list set; the promise settled.
    fn addRoutesNow(self: *Manager, worker_id: u64, rules: []router.Rule, ops: router.PatternOps, environment: u64, promise: u64) Allocator.Error!void {
        const worker = self.registry.findWorker(worker_id) orelse {
            router.freeRules(self.allocator, rules, ops);
            return self.settle(environment, .{ .reject = .{ .promise = promise, .kind = .invalid_state_error, .message = "The service worker has gone" } });
        };
        // 9.1-9.2. allRules: a copy of the worker's list, then each rule.
        const existing: []const router.Rule = if (worker.router_rules) |list| list.rules else &.{};
        const all = self.allocator.alloc(router.Rule, existing.len + rules.len) catch |err| {
            router.freeRules(self.allocator, rules, ops);
            self.settle(environment, .{ .reject = .{ .promise = promise, .kind = .type_error, .message = "Out of memory" } });
            return err;
        };
        @memcpy(all[0..existing.len], existing);
        @memcpy(all[existing.len..], rules);
        // 9.3. Over the limit: the promise rejects with a TypeError, and the
        // list stays as it was.
        if (!router.checkRegistrationLimit(all)) {
            self.allocator.free(all);
            router.freeRules(self.allocator, rules, ops);
            return self.settle(environment, .{ .reject = .{ .promise = promise, .kind = .type_error, .message = "Too many router conditions" } });
        }
        // 9.4. The worker's list of router rules is allRules. Nothing else
        // holds an installing worker's list (Handle Fetch reads only an
        // active worker's), so its rules move into the new one.
        if (worker.router_rules) |old| {
            const moved = old.unwrap() orelse {
                self.allocator.free(all);
                router.freeRules(self.allocator, rules, ops);
                return self.settle(environment, .{ .reject = .{ .promise = promise, .kind = .invalid_state_error, .message = "The service worker's routes are in use" } });
            };
            self.allocator.free(moved);
            worker.router_rules = null;
        }
        self.allocator.free(rules);
        worker.router_rules = router.Rules.create(self.allocator, all, ops) catch |err| {
            router.freeRules(self.allocator, all, ops);
            self.settle(environment, .{ .reject = .{ .promise = promise, .kind = .type_error, .message = "Out of memory" } });
            return err;
        };
        // 9.5. Resolve the promise with undefined.
        self.settle(environment, .{ .resolve_undefined = .{ .promise = promise } });
    }

    /// Whether the service worker `id`'s set of event types to handle
    /// contains fetch (InstallEvent.addRoutes() step 3.2).
    pub fn workerHandlesFetch(self: *Manager, id: u64) bool {
        self.lock();
        defer self.unlock();
        const worker = self.registry.findWorker(id) orelse return false;
        return worker.handles_fetch;
    }

    /// Should Skip Event ("fetch", `worker`): "If serviceWorker's set of
    /// event types to handle does not contain eventName, then the user agent
    /// may return true" - Crane does, as Chromium (ServiceWorkerVersion's
    /// fetch_handler_existence), Gecko (ServiceWorkerInfo::HandlesFetch) and
    /// WebKit (SWServerWorker::shouldSkipFetchEvent) do: a worker with no fetch
    /// listener is not started for a fetch.
    fn shouldSkipFetchEvent(worker: *const registry_mod.Worker) bool {
        return !worker.handles_fetch;
    }

    /// Steps 15-16 on the job thread, locked: wait for "activated", then Run
    /// Service Worker; its answer is `startAnswered`.
    fn fetchNow(self: *Manager, dispatch: *FetchDispatch) Allocator.Error!void {
        const worker = self.registry.findWorker(dispatch.worker_id) orelse return dispatch.fail();
        const waiter = self.next_waiter;
        self.next_waiter += 1;
        self.pending_fetches.append(self.allocator, .{ .waiter = waiter, .dispatch = dispatch }) catch |err| {
            dispatch.fail();
            return err;
        };
        self.registry.runServiceWorkerForFetch(worker, .{ .other = waiter }) catch |err| {
            if (self.takePendingFetch(waiter)) |pending| pending.fail();
            return err;
        };
    }

    fn takePendingFetch(self: *Manager, waiter: u64) ?*FetchDispatch {
        for (self.pending_fetches.items, 0..) |pending, i| {
            if (pending.waiter != waiter) continue;
            _ = self.pending_fetches.swapRemove(i);
            return pending.dispatch;
        }
        return null;
    }

    // ------------------------------------------------------------------
    // A thread blocked in a synchronous fetch
    // ------------------------------------------------------------------

    /// Before a blocking fetch's thread sleeps until a service worker
    /// answers (Call.wait), on that thread: the window data of every window
    /// client its loop runs - which it cannot answer as a task while it
    /// sleeps - read now, and what client queries wait for answered from it.
    /// A fetch handler that asks clients.matchAll() or clients.get() then
    /// finishes, instead of waiting on a thread that waits on it.
    fn beforeBlockingWait(context: *anyopaque, environment_id: u64) void {
        const self: *Manager = @ptrCast(@alignCast(context));
        if (environment_id == 0) return;
        const Window = struct { id: u64, endpoint: *Endpoint };
        var windows: std.ArrayListUnmanaged(Window) = .empty;
        defer windows.deinit(self.allocator);
        const sink = blk: {
            self.lock();
            defer self.unlock();
            const blocked = self.registry.findEnvironment(environment_id) orelse return;
            const own = endpointOfEnvironment(blocked) orelse return;
            for (self.blocked.items) |*thread| if (thread.sink == own.sink) {
                thread.depth += 1;
                return;
            };
            for (self.registry.environments.items) |environment| {
                if (environment.kind != .window) continue;
                const endpoint = endpointOfEnvironment(environment) orelse continue;
                if (endpoint.sink != own.sink) continue;
                windows.append(self.allocator, .{ .id = environment.id, .endpoint = endpoint }) catch return;
            }
            break :blk own.sink;
        };
        // On this thread, outside the lock: an environment of this loop ends
        // only on this thread, so each endpoint is there for the read.
        var thread: BlockedThread = .{ .sink = sink };
        for (windows.items) |window| {
            const data = window.endpoint.window_data_now(window.endpoint, self.allocator) orelse continue;
            thread.snapshots.append(self.allocator, .{ .environment = window.id, .data = data }) catch {
                var lost = data;
                lost.deinit(self.allocator);
            };
        }
        self.lock();
        defer self.unlock();
        self.blocked.append(self.allocator, thread) catch {
            thread.deinit(self.allocator);
            return;
        };
        self.answerFromSnapshots(&self.blocked.items[self.blocked.items.len - 1]);
    }

    /// After the blocking wait: the thread answers its window data as tasks
    /// again.
    fn afterBlockingWait(context: *anyopaque, environment_id: u64) void {
        const self: *Manager = @ptrCast(@alignCast(context));
        if (environment_id == 0) return;
        self.lock();
        defer self.unlock();
        const blocked = self.registry.findEnvironment(environment_id) orelse return;
        const own = endpointOfEnvironment(blocked) orelse return;
        for (self.blocked.items, 0..) |*thread, i| {
            if (thread.sink != own.sink) continue;
            thread.depth -= 1;
            if (thread.depth > 0) return;
            thread.deinit(self.allocator);
            _ = self.blocked.swapRemove(i);
            return;
        }
    }

    /// The snapshot of a blocked thread's window client `id`, if any.
    /// Locked.
    fn blockedWindowData(self: *Manager, id: u64) ?*const WindowData {
        for (self.blocked.items) |*thread| {
            for (thread.snapshots.items) |*snapshot| if (snapshot.environment == id) return &snapshot.data;
        }
        return null;
    }

    /// Answer every slot of every client query that waits for a window
    /// client of `thread`. Locked.
    fn answerFromSnapshots(self: *Manager, thread: *const BlockedThread) void {
        var index: usize = 0;
        next_query: while (index < self.client_queries.items.len) {
            const query = self.client_queries.items[index];
            for (query.slots, 0..) |slot, slot_index| {
                if (slot.answered) continue;
                const data = for (thread.snapshots.items) |*snapshot| {
                    if (snapshot.environment == slot.environment) break &snapshot.data;
                } else continue;
                const copy = data.clone(self.allocator) catch continue;
                const before = self.client_queries.items.len;
                self.queryAnswered(query, slot_index, copy);
                // The query finished and went: what is at this index now is
                // another.
                if (self.client_queries.items.len != before) continue :next_query;
            }
            index += 1;
        }
    }

    // ------------------------------------------------------------------
    // Messages (ServiceWorker.postMessage, Client.postMessage)
    // ------------------------------------------------------------------

    /// ServiceWorker.postMessage step 6, from any thread: `message` (taken)
    /// goes to the service worker `worker_id` once Run Service Worker has
    /// answered - and is dropped when it fails (6.1).
    pub fn postToWorker(self: *Manager, worker_id: u64, message: *WorkerMessage) void {
        self.report(.{ .post_message = .{ .worker = worker_id, .message = message } });
    }

    /// Step 6.1 on the job thread, locked: Run Service Worker, its answer
    /// `startAnswered`.
    fn postMessageNow(self: *Manager, worker_id: u64, message: *WorkerMessage) Allocator.Error!void {
        const worker = self.registry.findWorker(worker_id) orelse return message.destroy();
        const waiter = self.next_waiter;
        self.next_waiter += 1;
        self.pending_messages.append(self.allocator, .{ .waiter = waiter, .message = message }) catch |err| {
            message.destroy();
            return err;
        };
        self.registry.runServiceWorker(worker, false, .{ .other = waiter }) catch |err| {
            // The waiter was not recorded: nothing will answer for it.
            if (self.takePendingMessage(waiter)) |pending| pending.destroy();
            return err;
        };
    }

    fn takePendingMessage(self: *Manager, waiter: u64) ?*WorkerMessage {
        for (self.pending_messages.items, 0..) |pending, i| {
            if (pending.waiter != waiter) continue;
            _ = self.pending_messages.swapRemove(i);
            return pending.message;
        }
        return null;
    }

    /// Client.postMessage step 4, from the service worker `worker_id`'s
    /// thread: `message` (taken) is a task for the client message queue of
    /// the container of the client whose environment is `environment_id`
    /// (4.4-4.5) - dropped when that client has gone (4.3).
    pub fn postToClient(self: *Manager, environment_id: u64, worker_id: u64, message: *ClientMessage) void {
        self.lock();
        defer self.unlock();
        const environment = self.registry.findEnvironment(environment_id) orelse return message.destroy();
        if (!environment.kind.isClient()) return message.destroy();
        // 4.5.2's source: the service worker's object in the client's realm,
        // as the worker is now.
        const worker = self.registry.findWorker(worker_id) orelse return message.destroy();
        message.source = WorkerInfo.of(self.allocator, Registry.snapshotWorker(worker)) catch return message.destroy();
        // A reserved client: the message waits for the realm that adopts it.
        if (environment.endpoint == null) {
            self.reserved_messages.append(self.allocator, .{ .environment = environment.id, .message = message }) catch message.destroy();
            return;
        }
        self.postDelivery(environment, .{ .client_message = message });
    }

    /// Post `delivery` (taken) to `environment`'s realm. Locked.
    fn postDelivery(self: *Manager, environment: *registry_mod.Environment, delivery: Delivery) void {
        var owned = delivery;
        const endpoint = endpointOfEnvironment(environment) orelse return owned.deinit(self.allocator);
        const task = self.allocator.create(DeliveryTask) catch return owned.deinit(self.allocator);
        task.* = .{ .manager = self, .environment = environment.id, .delivery = owned };
        // A closed sink - the realm's loop has ended - drops it.
        _ = endpoint.sink.post(.{ .run = DeliveryTask.run, .drop = DeliveryTask.drop, .data = task });
    }

    /// Post `delivery` (taken) to the environment `id`, if it is still there.
    /// Locked.
    fn postDeliveryTo(self: *Manager, id: u64, delivery: Delivery) void {
        var owned = delivery;
        const environment = self.registry.findEnvironment(id) orelse return owned.deinit(self.allocator);
        self.postDelivery(environment, owned);
    }

    // ------------------------------------------------------------------
    // Clients' get() and matchAll()
    // ------------------------------------------------------------------

    /// ClientQueryOptions' type.
    pub const ClientType = enum { window, worker, sharedworker, all };

    /// A get() or matchAll() call waiting for its window clients' data.
    pub const ClientQuery = struct {
        id: u64,
        /// The service worker's environment, whose promise it settles.
        environment: u64,
        promise: u64,
        kind: enum { match_all, get },
        /// One per target client, in creation order.
        slots: []QuerySlot,
        /// Window data tasks not yet answered.
        outstanding: usize = 0,

        const QuerySlot = struct {
            /// The target client's environment.
            environment: u64 = 0,
            /// The client, once known; null while its window data is being
            /// gathered, and for a client that is not enumerable.
            info: ?ClientInfo = null,
            /// Its window data task has answered (or it needed none).
            answered: bool = false,
        };

        fn destroy(self: *ClientQuery, allocator: Allocator) void {
            for (self.slots) |*slot| if (slot.info) |*info| info.deinit(allocator);
            allocator.free(self.slots);
            allocator.destroy(self);
        }
    };

    fn findQuery(self: *Manager, id: u64) ?*ClientQuery {
        for (self.client_queries.items) |query| if (query.id == id) return query;
        return null;
    }

    /// A window data request, posted after the lock is let go.
    const WindowDataRequest = struct {
        sink: *TaskSink,
        task: *WindowDataTask,
    };

    /// Clients' matchAll(options) step 2, for the service worker `worker_id`
    /// whose environment is `environment_id`, settling its promise `promise`
    /// (any thread but a window client's own; the service worker's).
    pub fn matchAll(self: *Manager, environment_id: u64, worker_id: u64, include_uncontrolled: bool, client_type: ClientType, promise: u64) Allocator.Error!void {
        var requests: std.ArrayListUnmanaged(WindowDataRequest) = .empty;
        defer requests.deinit(self.allocator);
        errdefer self.discardWindowDataRequests(requests.items);
        {
            self.lock();
            defer self.unlock();
            const worker = self.registry.findWorker(worker_id) orelse {
                self.postDeliveryTo(environment_id, .{ .resolve_clients = .{ .promise = promise, .clients = &.{} } });
                return;
            };
            // 2.1-2.2. targetClients.
            const targets = try self.registry.matchAllClients(self.allocator, worker, include_uncontrolled);
            defer self.allocator.free(targets);
            const query = try self.newQuery(environment_id, promise, .match_all, targets.len);
            errdefer self.dropQuery(query);
            // 2.5. Window clients need their window data, gathered on their
            // own event loops; worker clients of the type asked for are
            // matched as they are.
            for (targets, query.slots) |client, *slot| {
                slot.environment = client.id;
                const wants_window = (client_type == .window or client_type == .all) and client.kind == .window;
                if (wants_window) {
                    try self.requestWindowData(&requests, query, client, slot);
                    continue;
                }
                slot.answered = true;
                const wanted = switch (client.kind) {
                    .dedicated_worker => client_type == .worker or client_type == .all,
                    .shared_worker => client_type == .sharedworker or client_type == .all,
                    else => false,
                };
                if (wanted) slot.info = try ClientInfo.of(self.allocator, client);
            }
            if (query.outstanding == 0) self.finishQuery(query);
        }
        self.postWindowDataRequests(requests.items);
    }

    /// Clients' get(id) step 2 and Resolve Get Client Promise, for the
    /// service worker `worker_id` whose environment is `environment_id`.
    pub fn getClient(self: *Manager, environment_id: u64, worker_id: u64, id: []const u8, promise: u64) Allocator.Error!void {
        var requests: std.ArrayListUnmanaged(WindowDataRequest) = .empty;
        defer requests.deinit(self.allocator);
        errdefer self.discardWindowDataRequests(requests.items);
        {
            self.lock();
            defer self.unlock();
            const worker = self.registry.findWorker(worker_id) orelse {
                self.postDeliveryTo(environment_id, .{ .resolve_client = .{ .promise = promise, .client = null } });
                return;
            };
            // 2.1. The client of the worker's storage key whose id is `id`;
            // 2.2, none: undefined.
            const client = self.registry.getClient(worker, id) orelse {
                self.postDeliveryTo(environment_id, .{ .resolve_client = .{ .promise = promise, .client = null } });
                return;
            };
            // 2.1.2 says to wait for its execution ready flag or its
            // discarded flag. Firefox and Safari resolve at once with a
            // reserved client - a navigation's resultingClientId, a worker's
            // - whose messages then wait for the realm that adopts it
            // (wpt.fyi 2026-10-16, controlled-iframe-postMessage.https.html:
            // Chrome 2/5, Firefox 5/5, Safari 5/5 - the fetch handler awaits
            // clients.get(resultingClientId) before its respondWith()
            // settles, which a client made execution ready by that very
            // response could never satisfy). Crane does as they do.
            if (client.discarded) {
                self.postDeliveryTo(environment_id, .{ .resolve_client = .{ .promise = promise, .client = null } });
                return;
            }
            try self.resolveGetClient(&requests, environment_id, client, promise);
        }
        self.postWindowDataRequests(requests.items);
    }

    /// Clients' get(id) step 2.1.3 for the execution ready `client`:
    /// Resolve Get Client Promise. Window data requests go to `requests`.
    /// Locked.
    fn resolveGetClient(self: *Manager, requests: *std.ArrayListUnmanaged(WindowDataRequest), environment_id: u64, client: *registry_mod.Environment, promise: u64) Allocator.Error!void {
        // Resolve Get Client Promise step 1.1: not a secure context.
        if (!client.secure_context) {
            self.postDeliveryTo(environment_id, .{ .reject = .{
                .promise = promise,
                .kind = .security_error,
                .message = "The client is not a secure context",
            } });
            return;
        }
        // Step 3: a worker client - Create Client.
        if (client.kind != .window) {
            self.postDeliveryTo(environment_id, .{ .resolve_client = .{ .promise = promise, .client = try ClientInfo.of(self.allocator, client) } });
            return;
        }
        // A reserved window client has no realm yet: its window data are a
        // new document's (visible, not focused, its ancestors not known).
        if (client.endpoint == null) {
            var info = try ClientInfo.of(self.allocator, client);
            errdefer info.deinit(self.allocator);
            info.window = .{};
            self.postDeliveryTo(environment_id, .{ .resolve_client = .{ .promise = promise, .client = info } });
            return;
        }
        // Step 4: a window client - its window data, on its event loop.
        const query = try self.newQuery(environment_id, promise, .get, 1);
        errdefer self.dropQuery(query);
        query.slots[0].environment = client.id;
        try self.requestWindowData(requests, query, client, &query.slots[0]);
        // A blocked thread's window answered at once.
        if (query.outstanding == 0) self.finishQuery(query);
    }

    /// The reserved client `environment` is gone - its document is
    /// another origin's, or none came (HTML "environment discarding steps",
    /// SW 2.4 its discarded flag): the messages that waited for it go too.
    /// Locked.
    fn discardReserved(self: *Manager, environment: *registry_mod.Environment) void {
        const id = environment.id;
        self.registry.removeEnvironment(environment);
        var index: usize = 0;
        while (index < self.reserved_messages.items.len) {
            const entry = self.reserved_messages.items[index];
            if (entry.environment != id) {
                index += 1;
                continue;
            }
            _ = self.reserved_messages.orderedRemove(index);
            entry.message.destroy();
        }
    }

    /// The reserved client `environment` was adopted: the messages that
    /// waited for it go to its realm now, in the order they were sent.
    /// Locked.
    fn deliverReservedMessages(self: *Manager, environment: *registry_mod.Environment) void {
        var index: usize = 0;
        while (index < self.reserved_messages.items.len) {
            const entry = self.reserved_messages.items[index];
            if (entry.environment != environment.id) {
                index += 1;
                continue;
            }
            _ = self.reserved_messages.orderedRemove(index);
            self.postDelivery(environment, .{ .client_message = entry.message });
        }
    }

    fn newQuery(self: *Manager, environment_id: u64, promise: u64, kind: @FieldType(ClientQuery, "kind"), slots: usize) Allocator.Error!*ClientQuery {
        const query = try self.allocator.create(ClientQuery);
        errdefer self.allocator.destroy(query);
        const slot_list = try self.allocator.alloc(ClientQuery.QuerySlot, slots);
        errdefer self.allocator.free(slot_list);
        @memset(slot_list, .{});
        query.* = .{ .id = self.next_query, .environment = environment_id, .promise = promise, .kind = kind, .slots = slot_list };
        self.next_query += 1;
        try self.client_queries.append(self.allocator, query);
        return query;
    }

    /// Remove `query` from the list and free it. Locked.
    fn dropQuery(self: *Manager, query: *ClientQuery) void {
        for (self.client_queries.items, 0..) |listed, i| {
            if (listed == query) {
                _ = self.client_queries.swapRemove(i);
                break;
            }
        }
        query.destroy(self.allocator);
    }

    /// Ask the window client `client` for its window data, for `slot` of
    /// `query`: a task of its realm's loop, posted once the lock is let go.
    /// Locked.
    fn requestWindowData(self: *Manager, requests: *std.ArrayListUnmanaged(WindowDataRequest), query: *ClientQuery, client: *const registry_mod.Environment, slot: *ClientQuery.QuerySlot) Allocator.Error!void {
        // A window of a thread blocked in a synchronous fetch: answered from
        // what it left before it blocked (`beforeBlockingWait`).
        if (self.blockedWindowData(client.id)) |data| {
            var info = try ClientInfo.of(self.allocator, client);
            errdefer info.deinit(self.allocator);
            info.window = try data.clone(self.allocator);
            slot.info = info;
            slot.answered = true;
            return;
        }
        // A client with no realm is not enumerable.
        const endpoint = endpointOfEnvironment(client) orelse {
            slot.answered = true;
            return;
        };
        const task = try self.allocator.create(WindowDataTask);
        errdefer self.allocator.destroy(task);
        task.* = .{
            .manager = self,
            .query = query.id,
            .slot = (@intFromPtr(slot) - @intFromPtr(query.slots.ptr)) / @sizeOf(ClientQuery.QuerySlot),
            .environment = client.id,
        };
        try requests.append(self.allocator, .{ .sink = endpoint.sink.retain(), .task = task });
        query.outstanding += 1;
    }

    /// Requests that were never posted: their query has gone with the error.
    fn discardWindowDataRequests(self: *Manager, requests: []const WindowDataRequest) void {
        for (requests) |request| {
            request.sink.release();
            self.allocator.destroy(request.task);
        }
    }

    fn postWindowDataRequests(self: *Manager, requests: []const WindowDataRequest) void {
        _ = self;
        for (requests) |request| {
            // A closed sink - the client's loop has ended - drops it, which
            // reports the client as not enumerable.
            _ = request.sink.post(.{ .run = WindowDataTask.run, .drop = WindowDataTask.drop, .data = request.task });
            request.sink.release();
        }
    }

    /// `slot` of `query` answered: `data` (taken) is the client's window
    /// data, or null when it is not enumerable. Locked.
    fn queryAnswered(self: *Manager, query: *ClientQuery, slot_index: usize, data: ?WindowData) void {
        var owned = data;
        if (slot_index >= query.slots.len or query.slots[slot_index].answered) {
            if (owned) |*d| d.deinit(self.allocator);
            return;
        }
        const slot = &query.slots[slot_index];
        slot.answered = true;
        query.outstanding -= 1;
        if (owned) |window| {
            // The client, as it is now - if it is still there.
            if (self.findClientEnvironment(query, slot_index)) |client| {
                if (ClientInfo.of(self.allocator, client)) |info| {
                    slot.info = info;
                    slot.info.?.window = window;
                    owned = null;
                } else |_| {}
            }
        }
        if (owned) |*d| d.deinit(self.allocator);
        if (query.outstanding == 0) self.finishQuery(query);
    }

    fn findClientEnvironment(self: *Manager, query: *ClientQuery, slot_index: usize) ?*registry_mod.Environment {
        return self.registry.findEnvironment(query.slots[slot_index].environment);
    }

    /// Every slot of `query` has answered: settle its promise (matchAll()
    /// step 2.6, Resolve Get Client Promise step 4.5.6). Locked; `query`
    /// goes.
    fn finishQuery(self: *Manager, query: *ClientQuery) void {
        defer self.dropQuery(query);
        switch (query.kind) {
            .get => {
                const info = query.slots[0].info;
                query.slots[0].info = null;
                self.postDeliveryTo(query.environment, .{ .resolve_client = .{ .promise = query.promise, .client = info } });
            },
            .match_all => {
                var clients: std.ArrayListUnmanaged(ClientInfo) = .empty;
                for (query.slots) |*slot| {
                    const info = slot.info orelse continue;
                    clients.append(self.allocator, info) catch continue;
                    slot.info = null;
                }
                // 2.6.4: window clients first - focused ones before the
                // others - then worker clients, each group in creation
                // order (the slots' order). Stated deviation: the order of
                // the focused windows among themselves is creation order,
                // not most recently focused first - no focus history is
                // kept.
                std.mem.sort(ClientInfo, clients.items, {}, struct {
                    fn rank(info: ClientInfo) u2 {
                        const window = info.window orelse return 2;
                        return if (window.focused) 0 else 1;
                    }
                    fn lessThan(_: void, a: ClientInfo, b: ClientInfo) bool {
                        const ra = rank(a);
                        const rb = rank(b);
                        if (ra != rb) return ra < rb;
                        return a.environment < b.environment;
                    }
                }.lessThan);
                const slice = clients.toOwnedSlice(self.allocator) catch {
                    for (clients.items) |*info| info.deinit(self.allocator);
                    clients.deinit(self.allocator);
                    return;
                };
                self.postDeliveryTo(query.environment, .{ .resolve_clients = .{ .promise = query.promise, .clients = slice } });
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

    /// A module service worker's graph fetched `resource` (taken) beyond its
    /// root: Registry.addModuleScript.
    pub fn addModuleScript(self: *Manager, worker_id: u64, resource: registry_mod.Resource) Allocator.Error!void {
        self.lock();
        defer self.unlock();
        return self.registry.addModuleScript(worker_id, resource);
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

    /// Soft Update for the registration `id`, once `soft_update_delay_ms`
    /// has passed without another asking (Handle Fetch step 12, Create Fetch
    /// Event and Dispatch step 19). On the job thread, locked. Chromium's
    /// delay: ServiceWorkerVersion::ScheduleUpdate starts its update timer
    /// with ServiceWorkerContext::kUpdateDelay (1000 ms) and resets it while
    /// it runs, so a page's burst of navigations makes one update check.
    fn scheduleSoftUpdate(self: *Manager, id: u64) void {
        for (self.soft_updates.items) |*pending| if (pending.registration == id) {
            pending.epoch +%= 1;
            SoftUpdateTimer.arm(self, id, pending.epoch);
            return;
        };
        self.soft_updates.append(self.allocator, .{ .registration = id }) catch return;
        SoftUpdateTimer.arm(self, id, 0);
    }

    const PendingSoftUpdate = struct {
        registration: u64,
        /// Bumped by every later ask: an earlier timer finds another.
        epoch: u64 = 0,
    };

    const SoftUpdateTimer = struct {
        manager: *Manager,
        registration: u64,
        epoch: u64,

        /// On the job thread.
        fn arm(manager: *Manager, registration: u64, epoch: u64) void {
            const loop = manager.job_loop orelse return;
            const self = manager.allocator.create(SoftUpdateTimer) catch return;
            self.* = .{ .manager = manager, .registration = registration, .epoch = epoch };
            if (loop.timerInterface().setTimeoutOwned(manager.soft_update_delay_ms, fire, self, drop) == 0) {
                manager.allocator.destroy(self);
            }
        }

        fn drop(data: ?*anyopaque) void {
            const self: *SoftUpdateTimer = @ptrCast(@alignCast(data.?));
            self.manager.allocator.destroy(self);
        }

        fn fire(data: ?*anyopaque) void {
            const self: *SoftUpdateTimer = @ptrCast(@alignCast(data.?));
            const manager = self.manager;
            const registration_id = self.registration;
            const epoch = self.epoch;
            manager.allocator.destroy(self);
            manager.lock();
            defer manager.unlock();
            for (manager.soft_updates.items, 0..) |pending, i| {
                if (pending.registration != registration_id) continue;
                if (pending.epoch != epoch) return;
                _ = manager.soft_updates.swapRemove(i);
                break;
            } else return;
            const registration = manager.registry.findRegistration(registration_id) orelse return;
            if (!registration.in_map) return;
            manager.registry.softUpdate(registration, false) catch |err| log.debug("a soft update: {s}", .{@errorName(err)});
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
        const endpoint = endpointOfEnvironment(environment) orelse return;
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

    /// ServiceWorker.postMessage step 6.1's answer: the worker started (or
    /// was running) - 6.2, queue its message task - or did not, and the
    /// message is dropped. The registry counted the event in flight when
    /// `ok`: a message that cannot be handed over reports itself done.
    fn startAnswered(ctx: *anyopaque, worker: *registry_mod.Worker, waiter: u64, ok: bool) void {
        const self = ofCtx(ctx);
        const generation = worker.run_generation;
        if (self.takePendingFetch(waiter)) |dispatch| {
            // Create Fetch Event and Dispatch step 16: Run Service Worker
            // failed - handleFetchFailed.
            if (!ok) return dispatch.fail();
            const entry = self.findRunning(worker.id);
            const started = if (entry) |e| e.started else null;
            if (started == null) {
                dispatch.fail();
                self.report(.{ .fetch_done = .{ .worker = worker.id, .generation = generation } });
                return;
            }
            entry.?.epoch +%= 1;
            self.host.dispatch_fetch(self, started.?, dispatch, worker.id, generation);
            return;
        }
        const message = self.takePendingMessage(waiter) orelse {
            if (ok) self.report(.{ .message_done = .{ .worker = worker.id, .generation = generation } });
            return;
        };
        if (!ok) return message.destroy();
        const entry = self.findRunning(worker.id);
        const started = if (entry) |e| e.started else null;
        if (started == null) {
            message.destroy();
            self.report(.{ .message_done = .{ .worker = worker.id, .generation = generation } });
            return;
        }
        // An idle check armed before finds another event since.
        entry.?.epoch +%= 1;
        self.host.post_message(self, started.?, message, worker.id, generation);
    }

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
            break :blk endpointOfEnvironment(environment) orelse return;
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

/// A window client's window data, gathered by a task of its realm's loop
/// (matchAll() step 2.5.1.6, Resolve Get Client Promise step 4.5) for one
/// slot of a client query.
const WindowDataTask = struct {
    manager: *Manager,
    query: u64,
    slot: usize,
    environment: u64,

    /// On the client's thread.
    fn run(data: ?*anyopaque) void {
        const self: *WindowDataTask = @ptrCast(@alignCast(data.?));
        const manager = self.manager;
        defer manager.allocator.destroy(self);
        const endpoint = blk: {
            manager.lock();
            defer manager.unlock();
            const environment = manager.registry.findEnvironment(self.environment) orelse break :blk null;
            break :blk endpointOfEnvironment(environment);
        };
        // The environment ends only on this thread: it is there for the
        // call. One that has ended is not enumerable.
        var window: ?WindowData = if (endpoint) |e| e.window_data(e, manager.allocator) else null;
        manager.lock();
        defer manager.unlock();
        const query = manager.findQuery(self.query) orelse {
            if (window) |*w| w.deinit(manager.allocator);
            return;
        };
        manager.queryAnswered(query, self.slot, window);
    }

    /// Discarded - the client's loop has ended: the client is not
    /// enumerable. Any thread; the answer goes through the job thread.
    fn drop(data: ?*anyopaque) void {
        const self: *WindowDataTask = @ptrCast(@alignCast(data.?));
        const manager = self.manager;
        const query = self.query;
        const slot = self.slot;
        manager.allocator.destroy(self);
        manager.report(.{ .window_data_missing = .{ .query = query, .slot = slot } });
    }
};
