//! The manager's reach beyond the registry in a running Browser
//! (manager.Host): the Update algorithm's script fetch over Fetch, and Run
//! Service Worker over html's worker threads - a service worker is html's
//! third kind of worker (html.worker_host's ServiceThreadHost) - with the
//! install and activate events dispatched on the worker's thread, and its
//! importScripts() fetch hook.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#run-service-worker-algorithm

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const html = @import("html");
const html_core = @import("html_core");
const fetch = @import("fetch");
const registry_mod = @import("registry.zig");
const manager_mod = @import("manager.zig");
const scope_mod = @import("scope.zig");
const update_fetch = @import("update_fetch.zig");
const realm_mod = @import("realm.zig");
const objects = @import("objects.zig");
const ExtendLifetime = @import("extend_lifetime.zig").ExtendLifetime;
const FunctionalEvent = @import("functional_event.zig").FunctionalEvent;

const Manager = manager_mod.Manager;
const script_fetch = html_core.workers.script_fetch;
const worker_host = html.worker_host;

const log = std.log.scoped(.service_worker);

pub const host: manager_mod.Host = .{
    .fetch = fetchForUpdate,
    .start = start,
    .dispatch = dispatch,
    .post_message = postMessage,
    .dispatch_fetch = dispatchFetch,
    .dispatch_functional = dispatchFunctional,
};

// ============================================================================
// The job's client, for the fetch
// ============================================================================

/// What the Update algorithm's fetch reads of its job's client - copied on
/// the client's thread when the job is made, since the fetch runs on the
/// Browser's job thread (Job.Client.fetch_client).
pub const FetchClient = struct {
    allocator: Allocator,
    /// The client's origin, serialized. OWNED.
    origin: ?[]u8,
    /// A clone of the client's policy container WITHOUT its CSP list
    /// (`jobContainer`): its referrer policy still applies to the fetch.
    policy_container: ?fetch.internal.PolicyContainer,
    /// The client's Browser's (Browser-lifetime).
    cookie_jar: ?*fetch.internal.CookieJar,
    network: ?*fetch.network.NetworkContext,
    blob_url_store: ?*anyopaque,

    pub fn create(scope: ?*runtime.BrowserScope, client: *const fetch.internal.RequestClient) Allocator.Error!*FetchClient {
        const allocator = if (scope) |s| s.allocator else std.heap.c_allocator;
        const self = try allocator.create(FetchClient);
        errdefer allocator.destroy(self);
        const origin = if (client.origin) |o| try allocator.dupe(u8, o) else null;
        errdefer if (origin) |o| allocator.free(o);
        self.* = .{
            .allocator = allocator,
            .origin = origin,
            .policy_container = if (client.policy_container) |container| try jobContainer(allocator, container) else null,
            .cookie_jar = client.cookie_jar,
            .network = client.network,
            .blob_url_store = client.blob_url_store,
        };
        return self;
    }

    /// The client's policy container as the job's fetches use it: a clone
    /// with an empty CSP list. Stated deviation: Update step 7 fetches given
    /// job's client, so main fetch step 7 would check the script against the
    /// client's CSP list - a blocked update() rejecting with Update step 8's
    /// TypeError. All three browsers check the script URL once, at
    /// register() on the client's thread (realm.zig register), and enforce
    /// nothing on the job's own fetch: WebKit ServiceWorkerJob::
    /// fetchScriptWithContext loads with ContentSecurityPolicyEnforcement::
    /// DoNotEnforce; Chromium's ServiceWorkerRegistration::update checks no
    /// CSP and its service_worker_register_job.cc and
    /// service_worker_new_script_loader.cc check none; Gecko's
    /// ServiceWorkerScriptCache (CompareNetwork::Initialize) opens its
    /// channel with no CSP. So update() under a policy added after
    /// registration still fetches (crane/sw1b10-update-csp.https.html).
    /// Golden rule 2: the browsers agree against the spec text.
    fn jobContainer(allocator: Allocator, container: *const fetch.internal.PolicyContainer) Allocator.Error!fetch.internal.PolicyContainer {
        var copy = try container.clone(allocator);
        copy.csp_list.deinit();
        copy.csp_list = @TypeOf(copy.csp_list).init(allocator);
        return copy;
    }

    pub fn destroy(self: *FetchClient) void {
        if (self.origin) |o| self.allocator.free(o);
        if (self.policy_container) |*container| container.deinit();
        self.allocator.destroy(self);
    }
};

/// A script resource's policy container, as the registry keeps it opaque
/// (Worker.policy).
pub const PolicyBox = struct {
    allocator: Allocator,
    container: fetch.internal.PolicyContainer,
};

pub fn destroyPolicy(policy: *anyopaque) void {
    const box: *PolicyBox = @ptrCast(@alignCast(policy));
    box.container.deinit();
    box.allocator.destroy(box);
}

// ============================================================================
// Update step 7
// ============================================================================

fn fetchForUpdate(manager: *Manager, plan: *const registry_mod.FetchPlan) registry_mod.FetchOutcome {
    const client: ?*const FetchClient = if (plan.fetch_client) |fc| @ptrCast(@alignCast(fc)) else null;
    // A job with no client (Soft Update's) fetches as its registration's
    // origin - the script url's, which Register checked against the scope's.
    const own_origin = scope_mod.originOf(manager.allocator, plan.script_url) catch return .{ .failure = .network };
    defer manager.allocator.free(own_origin);
    var fetcher: Fetcher = .{ .client = client, .manager = manager, .fallback_origin = own_origin, .referrer = plan.referrer };
    return update_fetch.run(manager.allocator, plan, fetcher.interface());
}

/// The real fetch, over Fetch (html_core's service worker script fetch).
const Fetcher = struct {
    client: ?*const FetchClient,
    manager: *Manager,
    /// The request's origin when the client has none to give.
    fallback_origin: []const u8,
    /// The job's referrer (BORROWED from the plan), or null.
    referrer: ?[]const u8 = null,

    fn interface(self: *Fetcher) update_fetch.Fetcher {
        return .{ .ctx = self, .fetch = fetchOne, .wrap_policy = wrapPolicy };
    }

    fn fetchOne(ctx: *anyopaque, allocator: Allocator, url: []const u8, kind: script_fetch.ServiceWorkerResourceKind, bypass_http_cache: bool) error{ NetworkError, OutOfMemory }!script_fetch.ServiceWorkerResource {
        const self: *Fetcher = @ptrCast(@alignCast(ctx));
        const client = self.client;
        return script_fetch.fetchServiceWorkerResource(allocator, url, .{
            .kind = kind,
            .bypass_http_cache = bypass_http_cache,
            .origin = if (client) |c| c.origin orelse self.fallback_origin else self.fallback_origin,
            .policy_container = if (client) |c| if (c.policy_container) |*p| p else null else null,
            .cookie_jar = if (client) |c| c.cookie_jar else null,
            .network = if (client) |c| c.network else self.networkOfManager(),
            .blob_url_store = if (client) |c| c.blob_url_store else null,
            .referrer = self.referrer,
        });
    }

    /// A Soft Update's job has no client: the Browser's own network.
    fn networkOfManager(self: *Fetcher) ?*fetch.network.NetworkContext {
        const scope = self.manager.scope orelse return null;
        return scope.of(fetch.network.NetworkContext) catch null;
    }

    fn wrapPolicy(ctx: *anyopaque, allocator: Allocator, container: fetch.internal.PolicyContainer) ?*anyopaque {
        _ = ctx;
        var taken = container;
        const box = allocator.create(PolicyBox) catch {
            taken.deinit();
            return null;
        };
        box.* = .{ .allocator = allocator, .container = taken };
        return box;
    }
};

// ============================================================================
// Run Service Worker steps 7-9
// ============================================================================

fn start(manager: *Manager, values: *const manager_mod.WorkerStart) anyerror!manager_mod.Started {
    const job_link = manager.job_link orelse return error.NoJobThread;
    const allocator = manager.allocator;
    const owner = try allocator.create(OwnerEnd);
    errdefer allocator.destroy(owner);
    owner.* = .{ .manager = manager, .worker_id = values.worker_id };
    var policy: ?fetch.internal.PolicyContainer = null;
    if (values.policy) |p| {
        const box: *PolicyBox = @ptrCast(@alignCast(p));
        policy = try box.container.clone(allocator);
    }
    defer if (policy) |*container| container.deinit();
    var thread_start: worker_host.ServiceWorkerStart = .{
        .source = values.source,
        .script_url = values.script_url,
        .worker_type = switch (values.worker_type) {
            .classic => .classic,
            .module => .module,
        },
        .policy_container = policy,
        .cookie_jar = manager.cookie_jar,
        .browser_scope = manager.scope,
        .owner_sink = job_link.worker_sink,
        .owner = .{ .data = owner, .ended = OwnerEnd.ended, .drop = OwnerEnd.dropped },
        .service = .{
            .worker_id = values.worker_id,
            .registration_id = values.registration_id,
            .manager = manager,
            .hooks = &service_hooks,
        },
        // Setup ServiceWorkerGlobalScope step 1: the unsafe creation time.
        .time_origin_ns = @intCast(@import("hr_time").MonotonicClock.unsafeCurrentTime()),
    };
    const started = try worker_host.startServiceWorker(allocator, &thread_start);
    // Taken by the thread.
    policy = null;
    return .{ .link = started.link, .handle = started.handle };
}

/// A service worker's end, a task of the job thread's loop (its owner's).
const OwnerEnd = struct {
    manager: *Manager,
    worker_id: u64,

    /// The job thread: join the worker's thread, forget it in the Browser's
    /// WorkerRegistry, and tell the registry it has stopped.
    fn ended(data: ?*anyopaque, link: *html.WorkerLink) void {
        const self: *OwnerEnd = @ptrCast(@alignCast(data.?));
        const manager = self.manager;
        const worker_id = self.worker_id;
        manager.allocator.destroy(self);
        worker_host.endServiceWorkerLink(manager.scope, link);
        manager.reportEnded(worker_id);
    }

    /// The job thread's loop ended first: the Browser's end, which joins
    /// every thread itself.
    fn dropped(data: ?*anyopaque, link: *html.WorkerLink) void {
        const self: *OwnerEnd = @ptrCast(@alignCast(data.?));
        const manager = self.manager;
        manager.allocator.destroy(self);
        if (link.hasThread()) return;
        if (manager.scope) |scope| if (scope.existing(html.WorkerRegistry)) |registry| registry.unregister(link);
    }
};

const service_hooks: worker_host.ServiceHooks = .{
    .evaluated = evaluated,
    .import_script = importScript,
    .module_fetched = moduleFetched,
};

/// A module service worker's graph fetched `url` (a good response): kept in
/// the worker's script resource map while it is parsed or installing, for
/// an update to compare (update_fetch.zig).
fn moduleFetched(manager_ptr: *anyopaque, worker_id: u64, url: []const u8, content_type: []const u8, body: []const u8) void {
    const manager = managerOf(manager_ptr);
    const allocator = manager.allocator;
    const owned_url = allocator.dupe(u8, url) catch return;
    const owned_body = allocator.dupe(u8, body) catch {
        allocator.free(owned_url);
        return;
    };
    const owned_type = allocator.dupe(u8, content_type) catch {
        allocator.free(owned_url);
        allocator.free(owned_body);
        return;
    };
    manager.addModuleScript(worker_id, .{ .url = owned_url, .body = owned_body, .content_type = owned_type }) catch |err|
        log.debug("a service worker's imported module was not kept: {s}", .{@errorName(err)});
}

fn managerOf(ctx: *anyopaque) *Manager {
    return @ptrCast(@alignCast(ctx));
}

/// Run Service Worker step 9.7, from the worker's thread - with what step
/// 9.8's set of event types to handle needs of the global's event listeners,
/// read now, after the script ran (the registry keeps it only the first
/// time, when the script's has ever been evaluated flag is unset).
fn evaluated(manager: *anyopaque, worker_id: u64, ok: bool, global: ?*runtime.Instance) void {
    const handles_fetch = if (global) |g| dom.event_listener_types.hasListenersOfType(g, "fetch") else false;
    // Before the job thread hears of it - and so before Install or Activate
    // can change what they show: the global's own objects exist.
    if (ok) if (global) |g| realm_mod.makeOwnObjects(g);
    managerOf(manager).report(.{ .evaluated = .{ .worker = worker_id, .ok = ok, .handles_fetch = handles_fetch } });
}

/// importScripts() in a service worker (6.3.2): the fetch hook's steps for
/// `url`, on the worker's thread.
fn importScript(manager_ptr: *anyopaque, worker_id: u64, ctx: runtime.Context, url: []const u8) error{ NetworkError, OutOfMemory }!worker_host.ImportedScript {
    const manager = managerOf(manager_ptr);
    const allocator = ctx.allocator;
    switch (try manager.importStep(worker_id, url)) {
        .network_error => return error.NetworkError,
        .stored => |stored| {
            var resource = stored;
            defer resource.deinit(manager.allocator);
            // Step 11's check, which a stored response already passed.
            return importedScript(allocator, ctx, resource.url, resource.body);
        },
        .fetch => |plan| {
            // 9. Fetch it - with the worker's settings as its client.
            const global = globalOf(ctx);
            var client = if (global) |g| try dom.global_settings.requestClient(g) else dom.global_settings.Client{ .allocator = allocator };
            defer client.deinit();
            var response = script_fetch.fetchServiceWorkerResource(allocator, url, .{
                .kind = .imported_script,
                .bypass_http_cache = plan.bypass_http_cache,
                .origin = client.request.origin,
                .policy_container = client.request.policy_container,
                // Its violations go to the worker's own global, on this
                // thread (CSP 2.4.2: the request's client's).
                .csp_violation_reporter = client.request.csp_violation_reporter,
                .cookie_jar = client.request.cookie_jar,
                .network = client.request.network,
                .blob_url_store = client.request.blob_url_store,
            }) catch |err| return err;
            defer response.deinit();
            // 11. A bad import script response is a network error.
            if (update_fetch.isBadImportScriptResponse(&response)) return error.NetworkError;
            // 10, 12-14. Recorded in the worker's script resource map.
            const kept: registry_mod.Resource = .{
                .url = try manager.allocator.dupe(u8, url),
                .body = try manager.allocator.dupe(u8, response.body),
                .content_type = try manager.allocator.dupe(u8, response.content_type),
            };
            try manager.addImportedScript(worker_id, kept, response.from_network);
            return importedScript(allocator, ctx, response.final_url, response.body);
        },
    }
}

fn globalOf(realm: runtime.Context) ?*runtime.Instance {
    const record = realm.getRealm() orelse return null;
    return @ptrCast(@alignCast(record.global_object orelse return null));
}

/// What importScripts() runs: the source, UTF-8 (a leading BOM gone), with
/// muted errors when it is not same-origin with the worker.
fn importedScript(allocator: Allocator, ctx: runtime.Context, url: []const u8, body: []const u8) error{OutOfMemory}!worker_host.ImportedScript {
    const text = if (std.mem.startsWith(u8, body, "\xEF\xBB\xBF")) body[3..] else body;
    const source = try allocator.dupe(u8, text);
    errdefer allocator.free(source);
    const own = ctx.documentUrl() orelse "";
    const muted = !(scope_mod.sameOriginUrls(allocator, url, own) catch false);
    return .{ .allocator = allocator, .source = source, .url = try allocator.dupe(u8, url), .muted = muted };
}

// ============================================================================
// The install and activate events (Install step 11.3, Activate step 10.1)
// ============================================================================

fn dispatch(manager: *Manager, started: manager_mod.Started, event: registry_mod.LifecycleEvent, op: u64) void {
    const link = started.link orelse return;
    const handle = started.handle orelse return;
    const task = manager.allocator.create(LifecycleTask) catch {
        manager.report(.{ .lifecycle_done = .{ .op = op, .failed = true } });
        return;
    };
    task.* = .{ .manager = manager, .event = event, .op = op };
    worker_host.postServiceTask(manager.allocator, link, handle, .{ .run = LifecycleTask.run, .drop = LifecycleTask.drop, .data = task });
}

/// The task queued on the worker's event loop, using the DOM manipulation
/// task source.
const LifecycleTask = struct {
    manager: *Manager,
    event: registry_mod.LifecycleEvent,
    op: u64,

    /// On the worker's thread, in its realm.
    fn run(data: ?*anyopaque, realm: runtime.Context, global_scope: *runtime.Instance) void {
        const self: *LifecycleTask = @ptrCast(@alignCast(data.?));
        const manager = self.manager;
        const op = self.op;
        const event = self.event;
        manager.allocator.destroy(self);
        fire(manager, realm, global_scope, event, op) catch |err| {
            log.debug("a {s} event was not fired: {s}", .{ @tagName(event), @errorName(err) });
            manager.report(.{ .lifecycle_done = .{ .op = op, .failed = true } });
        };
    }

    /// Discarded (the worker is ending): "if task is discarded, set
    /// installFailed to true". Any thread.
    fn drop(data: ?*anyopaque) void {
        const self: *LifecycleTask = @ptrCast(@alignCast(data.?));
        const manager = self.manager;
        const op = self.op;
        manager.allocator.destroy(self);
        manager.report(.{ .lifecycle_done = .{ .op = op, .failed = true } });
    }
};

/// What the event's end reports, once.
const Done = struct {
    manager: *Manager,
    op: u64,

    fn run(ctx: *anyopaque, failed: bool) void {
        const self: *Done = @ptrCast(@alignCast(ctx));
        const manager = self.manager;
        const op = self.op;
        manager.allocator.destroy(self);
        manager.report(.{ .lifecycle_done = .{ .op = op, .failed = failed } });
    }

    fn drop(ctx: *anyopaque) void {
        const self: *Done = @ptrCast(@alignCast(ctx));
        self.manager.allocator.destroy(self);
    }
};

/// Install 11.3.1.1-4 / Activate 10.1.1.1-4: e, an InstallEvent (or an
/// ExtendableEvent) named install (or activate), dispatched at the global;
/// then, once e is not active, its end reported - failed when an extend
/// lifetime promise rejected.
fn fire(manager: *Manager, realm: runtime.Context, global_scope: *runtime.Instance, event: registry_mod.LifecycleEvent, op: u64) !void {
    const done = try manager.allocator.create(Done);
    done.* = .{ .manager = manager, .op = op };
    const lifetime = ExtendLifetime.create(realm.allocator, .{ .ctx = done, .run = Done.run, .drop = Done.drop }) catch |err| {
        manager.allocator.destroy(done);
        return err;
    };
    // The dispatcher's reference.
    defer lifetime.release();
    const type_name = switch (event) {
        .install => "install",
        .activate => "activate",
    };
    const instance = switch (event) {
        .install => try interfaces.InstallEvent.initWith(realm.allocator, realm, .{ .lifetime = lifetime }),
        .activate => try interfaces.ExtendableEvent.initWith(realm.allocator, realm, .{ .lifetime = lifetime }),
    };
    const generation = runtime.SlabAllocator.generationOf(instance);
    defer instance.releaseIfUnwrapped(generation);
    try dom.event_construction.innerEventCreationSteps(instance, runtime.DOMString.initInterned(type_name), dom.event_construction.eventInitFrom(@import("dictionaries").EventInit{}));
    lifetime.dispatching = true;
    _ = dom.fire_event.dispatchTrusted(global_scope, instance) catch {};
    // WaitForAsynchronousExtensions: reported now if nothing extends it, or
    // when its last extend lifetime promise settles.
    lifetime.dispatchEnded();
}

// ============================================================================
// The message event (ServiceWorker.postMessage step 6.2)
// ============================================================================

fn postMessage(manager: *Manager, started: manager_mod.Started, message: *manager_mod.WorkerMessage, worker_id: u64, generation: u64) void {
    const link = started.link orelse return messageLost(manager, message, worker_id, generation);
    const handle = started.handle orelse return messageLost(manager, message, worker_id, generation);
    const task = manager.allocator.create(MessageTask) catch return messageLost(manager, message, worker_id, generation);
    task.* = .{ .manager = manager, .message = message, .worker_id = worker_id, .generation = generation };
    worker_host.postServiceTask(manager.allocator, link, handle, .{ .run = MessageTask.run, .drop = MessageTask.drop, .data = task });
}

/// A message that never reaches its worker: dropped with its ports, and its
/// event reported done.
fn messageLost(manager: *Manager, message: *manager_mod.WorkerMessage, worker_id: u64, generation: u64) void {
    message.destroy();
    manager.report(.{ .message_done = .{ .worker = worker_id, .generation = generation } });
}

/// The task queued on the worker's event loop, using the DOM manipulation
/// task source.
const MessageTask = struct {
    manager: *Manager,
    message: *manager_mod.WorkerMessage,
    worker_id: u64,
    generation: u64,

    /// On the worker's thread, in its realm.
    fn run(data: ?*anyopaque, realm: runtime.Context, global_scope: *runtime.Instance) void {
        const self: *MessageTask = @ptrCast(@alignCast(data.?));
        const manager = self.manager;
        const message = self.message;
        const done: MessageDone = .{ .manager = manager, .worker_id = self.worker_id, .generation = self.generation };
        manager.allocator.destroy(self);
        defer message.destroy();
        fireMessage(manager, realm, global_scope, message, done) catch |err| {
            log.debug("a message event was not fired: {s}", .{@errorName(err)});
            done.report();
        };
    }

    /// Discarded (the worker is ending). Any thread.
    fn drop(data: ?*anyopaque) void {
        const self: *MessageTask = @ptrCast(@alignCast(data.?));
        const manager = self.manager;
        const done: MessageDone = .{ .manager = manager, .worker_id = self.worker_id, .generation = self.generation };
        self.message.destroy();
        manager.allocator.destroy(self);
        done.report();
    }
};

/// What a message event's end reports.
const MessageDone = struct {
    manager: *Manager,
    worker_id: u64,
    generation: u64,

    fn report(self: MessageDone) void {
        self.manager.report(.{ .message_done = .{ .worker = self.worker_id, .generation = self.generation } });
    }
};

/// The extended lifetime's settled callback: the event is done.
const MessageSettled = struct {
    done: MessageDone,

    fn run(ctx: *anyopaque, _: bool) void {
        const self: *MessageSettled = @ptrCast(@alignCast(ctx));
        const done = self.done;
        done.manager.allocator.destroy(self);
        done.report();
    }

    fn drop(ctx: *anyopaque) void {
        const self: *MessageSettled = @ptrCast(@alignCast(ctx));
        const done = self.done;
        done.manager.allocator.destroy(self);
        // The event never settles here (its realm ended): the worker's end
        // tells the manager.
        done.report();
    }
};

/// ServiceWorker.postMessage steps 6.2.1-6.2.7 on the worker's thread:
/// source, origin, the deserialization, the event (message, or messageerror)
/// dispatched at the global, and Update Service Worker Extended Events Set -
/// the event's end is reported once it is not active.
fn fireMessage(manager: *Manager, realm: runtime.Context, global_scope: *runtime.Instance, message: *manager_mod.WorkerMessage, done: MessageDone) !void {
    const environment = realm_mod.environmentOf(realm, true) orelse return error.InvalidStateError;
    // 6.2.1. source: a service worker's own global posted it - the
    // ServiceWorker object of its worker here; a client - a new WindowClient
    // or Client representing it.
    const source = switch (message.source) {
        .service_worker => |info| try environment.workerObject(info),
        .client => |*info| try environment.clientObject(info),
    };
    // 6.2.3. destination: the worker's global.
    // 6.2.4. StructuredDeserializeWithTransfer, its transferred ports
    // received here first.
    var ports: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer ports.deinit(manager.allocator);
    var event_type: []const u8 = "message";
    var data_hold: ?engine.Owned = null;
    defer if (data_hold) |hold| hold.release();
    if (message.message) |port_message| {
        message.message = null;
        defer port_message.destroy();
        const ends = port_message.takeEnds();
        defer port_message.allocator.free(ends);
        for (ends) |end| {
            const port = dom.message_ports.receive(realm, @ptrCast(end)) catch continue;
            ports.append(manager.allocator, port) catch continue;
        }
        data_hold = engine.structuredDeserializeWithTransfer(realm, port_message.serialized, port_message.array_buffers, ports.items) catch blk: {
            // "If this throws an exception, let e be ... messageerror".
            event_type = "messageerror";
            ports.clearRetainingCapacity();
            break :blk null;
        };
    }
    const settled = try manager.allocator.create(MessageSettled);
    settled.* = .{ .done = done };
    const lifetime = ExtendLifetime.create(realm.allocator, .{ .ctx = settled, .run = MessageSettled.run, .drop = MessageSettled.drop }) catch |err| {
        manager.allocator.destroy(settled);
        return err;
    };
    // The dispatcher's reference. From here the lifetime reports the end -
    // so nothing below returns an error, which would report it again.
    defer lifetime.release();
    // 6.2.5.3: an ExtendableMessageEvent with its origin, source, data and
    // ports.
    const instance = interfaces.ExtendableMessageEvent.initWith(realm.allocator, realm, .{
        .lifetime = lifetime,
        .message = objects.ExtendableMessageInit{
            .data = if (data_hold) |hold| hold.value else runtime.JSValue.jsNull,
            .origin = message.origin,
            .source = source,
            .ports = ports.items,
        },
    }) catch |err| {
        log.debug("no message event: {s}", .{@errorName(err)});
        lifetime.dispatchEnded();
        return;
    };
    const generation = runtime.SlabAllocator.generationOf(instance);
    defer instance.releaseIfUnwrapped(generation);
    dom.event_construction.innerEventCreationSteps(instance, runtime.DOMString.initInterned(event_type), dom.event_construction.eventInitFrom(@import("dictionaries").EventInit{})) catch |err| {
        log.debug("no message event: {s}", .{@errorName(err)});
        lifetime.dispatchEnded();
        return;
    };
    lifetime.dispatching = true;
    // 6.2.6. Dispatch e at destination.
    _ = dom.fire_event.dispatchTrusted(global_scope, instance) catch {};
    // 6.2.7. Update Service Worker Extended Events Set: the event stays in
    // flight while it is active, and reports its end once it is not.
    lifetime.dispatchEnded();
}

// ============================================================================
// Functional events (Fire Functional Event step 6)
// ============================================================================

fn dispatchFunctional(manager: *Manager, started: manager_mod.Started, event: *FunctionalEvent, worker_id: u64, generation: u64) void {
    const done: FunctionalDone = .{ .manager = manager, .worker_id = worker_id, .generation = generation, .registration = event.registration_id };
    const link = started.link orelse return functionalLost(event, done);
    const handle = started.handle orelse return functionalLost(event, done);
    const task = manager.allocator.create(FunctionalTask) catch return functionalLost(event, done);
    task.* = .{ .event = event, .done = done };
    worker_host.postServiceTask(manager.allocator, link, handle, .{ .run = FunctionalTask.run, .drop = FunctionalTask.drop, .data = task });
}

/// An event that never reaches its worker (step 7: "or been discarded"):
/// dropped, and reported done.
fn functionalLost(event: *FunctionalEvent, done: FunctionalDone) void {
    event.destroy();
    done.report();
}

/// The task queued on the worker's event loop, using the handle functional
/// event task source.
const FunctionalTask = struct {
    event: *FunctionalEvent,
    done: FunctionalDone,

    /// On the worker's thread, in its realm.
    fn run(data: ?*anyopaque, realm: runtime.Context, global_scope: *runtime.Instance) void {
        const self: *FunctionalTask = @ptrCast(@alignCast(data.?));
        const event = self.event;
        const done = self.done;
        done.manager.allocator.destroy(self);
        defer event.destroy();
        fireFunctional(realm, global_scope, event, done) catch |err| {
            log.debug("a {s} event was not fired: {s}", .{ event.name(), @errorName(err) });
            done.report();
        };
    }

    /// Discarded (the worker is ending). Any thread.
    fn drop(data: ?*anyopaque) void {
        const self: *FunctionalTask = @ptrCast(@alignCast(data.?));
        const event = self.event;
        const done = self.done;
        done.manager.allocator.destroy(self);
        functionalLost(event, done);
    }
};

/// What a functional event's end reports.
const FunctionalDone = struct {
    manager: *Manager,
    worker_id: u64,
    generation: u64,
    registration: u64,

    fn report(self: FunctionalDone) void {
        self.manager.report(.{ .functional_done = .{ .worker = self.worker_id, .generation = self.generation, .registration = self.registration } });
    }
};

/// The extended lifetime's settled callback: the event is done.
const FunctionalSettled = struct {
    done: FunctionalDone,

    fn run(ctx: *anyopaque, _: bool) void {
        const self: *FunctionalSettled = @ptrCast(@alignCast(ctx));
        const done = self.done;
        done.manager.allocator.destroy(self);
        done.report();
    }

    fn drop(ctx: *anyopaque) void {
        const self: *FunctionalSettled = @ptrCast(@alignCast(ctx));
        const done = self.done;
        done.manager.allocator.destroy(self);
        done.report();
    }
};

/// Fire Functional Event steps 6.1-6.4 on the worker's thread: the event
/// created in the global's realm and initialized, dispatched at the global,
/// and Update Service Worker Extended Events Set - its end is reported once
/// it is not active.
fn fireFunctional(realm: runtime.Context, global_scope: *runtime.Instance, event: *FunctionalEvent, done: FunctionalDone) !void {
    const manager = done.manager;
    const settled = try manager.allocator.create(FunctionalSettled);
    settled.* = .{ .done = done };
    const lifetime = ExtendLifetime.create(realm.allocator, .{ .ctx = settled, .run = FunctionalSettled.run, .drop = FunctionalSettled.drop }) catch |err| {
        manager.allocator.destroy(settled);
        return err;
    };
    // The dispatcher's reference. From here the lifetime reports the end -
    // so nothing below returns an error, which would report it again.
    defer lifetime.release();
    // 6.1-6.2. Created with its constructor in the global's relevant realm,
    // initialized with the event's properties.
    const made = switch (event.kind) {
        .cookie_change => |*lists| interfaces.ExtendableCookieChangeEvent.initWith(realm.allocator, realm, .{ .lifetime = lifetime, .cookie_changes = lists }),
    };
    const instance = made catch |err| {
        log.debug("no {s} event: {s}", .{ event.name(), @errorName(err) });
        lifetime.dispatchEnded();
        return;
    };
    const generation = runtime.SlabAllocator.generationOf(instance);
    defer instance.releaseIfUnwrapped(generation);
    dom.event_construction.innerEventCreationSteps(instance, runtime.DOMString.initInterned(event.name()), dom.event_construction.eventInitFrom(@import("dictionaries").EventInit{})) catch |err| {
        log.debug("no {s} event: {s}", .{ event.name(), @errorName(err) });
        lifetime.dispatchEnded();
        return;
    };
    lifetime.dispatching = true;
    // 6.3. Dispatch it on the global.
    _ = dom.fire_event.dispatchTrusted(global_scope, instance) catch {};
    // 6.4. Update Service Worker Extended Events Set.
    lifetime.dispatchEnded();
}

// ============================================================================
// The fetch event (Create Fetch Event and Dispatch step 17.4)
// ============================================================================

const fetch_event = @import("fetch_event.zig");

fn dispatchFetch(manager: *Manager, started: manager_mod.Started, fetch_dispatch: *manager_mod.FetchDispatch, worker_id: u64, generation: u64) void {
    const done: fetch_event.FetchDone = .{
        .manager = manager,
        .worker_id = worker_id,
        .generation = generation,
        // Create Fetch Event and Dispatch step 19.
        .soft_update = if (fetch_dispatch.soft_update) fetch_dispatch.registration_id else 0,
    };
    const link = started.link orelse return fetchLost(fetch_dispatch, done);
    const handle = started.handle orelse return fetchLost(fetch_dispatch, done);
    const task = manager.allocator.create(FetchTask) catch return fetchLost(fetch_dispatch, done);
    task.* = .{ .dispatch = fetch_dispatch, .done = done };
    worker_host.postServiceTask(manager.allocator, link, handle, .{ .run = FetchTask.run, .drop = FetchTask.drop, .data = task });
}

/// "If task is discarded, set handleFetchFailed to true": a network error,
/// and the event reported done.
fn fetchLost(fetch_dispatch: *manager_mod.FetchDispatch, done: fetch_event.FetchDone) void {
    fetch_dispatch.fail();
    done.report();
}

/// The task queued on the worker's event loop, using the handle fetch task
/// source.
const FetchTask = struct {
    dispatch: *manager_mod.FetchDispatch,
    done: fetch_event.FetchDone,

    /// On the worker's thread, in its realm.
    fn run(data: ?*anyopaque, realm: runtime.Context, global_scope: *runtime.Instance) void {
        const self: *FetchTask = @ptrCast(@alignCast(data.?));
        const fetch_dispatch = self.dispatch;
        const done = self.done;
        done.manager.allocator.destroy(self);
        fetch_event.fire(done.manager, realm, global_scope, fetch_dispatch, done);
    }

    /// Discarded (the worker is ending). Any thread.
    fn drop(data: ?*anyopaque) void {
        const self: *FetchTask = @ptrCast(@alignCast(data.?));
        const fetch_dispatch = self.dispatch;
        const done = self.done;
        done.manager.allocator.destroy(self);
        fetchLost(fetch_dispatch, done);
    }
};
