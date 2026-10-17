//! What a realm keeps of service workers: its environment (Service Workers
//! 2.4, a service worker client - or a service worker's own global, which
//! sees service worker objects and is no client), with the realm's service
//! worker object map and service worker registration object map (3.1.1,
//! 3.2.1), the job promises it waits on, its container's ready promise, and
//! the steps of the API members that script calls in it
//! (ServiceWorkerContainer, ServiceWorkerRegistration, the service worker
//! global's registration, serviceWorker, skipWaiting and clients.claim).
//!
//! Everything here runs on the realm's own thread. What reaches it from the
//! Browser's manager (manager.zig) arrives as a Delivery task on the realm's
//! sink; an environment ends only on its own thread (its realm's unloading
//! cleanup, `environmentEnded`), so a Delivery that finds it finds it alive.
//!
//! Clients at creation (batch 3): a frame's or popup's window realm, and a
//! dedicated or shared worker's, is a client from its creation
//! (dom.service_worker_clients, `clientCreated`), its active service worker
//! decided then - the reserved client Handle Fetch controlled, or its
//! creator's (SW 2.5).
//!
//! Stated deviations (tmp/plans/sw1-design.md, tmp/plans/sw1-b3-design.md):
//! - The top-level page (Browser.navigate) and a javascript: URL's document
//!   become an environment when they first reach the API (its navigator's
//!   ServiceWorkerContainer, or a service worker global's members): no
//!   realm-creation hook reaches them, and the top-level page's navigation
//!   goes to no service worker.
//! - A frame's initial about:blank client ends when its document is
//!   unloaded, and the document that replaces it - in the same Window - is a
//!   client of its own, the navigation's reserved client (Chrome's model:
//!   wpt.fyi 2026-10-16, about-blank-replacement.https.html Chrome 2/7,
//!   Firefox 7/7, Safari 4/7; clients-get-resultingClientId.https.html 6/6 in
//!   all three, which Firefox's reuse of the about:blank client also passes).
//! - A window realm whose document is not fully active - a removed frame's,
//!   a closed window's - becomes no environment: what it calls is rejected
//!   with an "InvalidStateError" (Chromium's answer for a detached context),
//!   and the promises it was waiting on when its environment ended stay
//!   pending (nothing runs in a realm that has gone).
//!
//! Spec: https://w3c.github.io/ServiceWorker/#client-context

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const html = @import("html");
const registry_mod = @import("registry.zig");
const manager_mod = @import("manager.zig");
const scope_mod = @import("scope.zig");
const objects = @import("objects.zig");
const run_mod = @import("run.zig");

const Manager = manager_mod.Manager;
const Delivery = manager_mod.Delivery;
const WorkerInfo = manager_mod.WorkerInfo;
const RegistrationInfo = manager_mod.RegistrationInfo;
const ClientInfo = manager_mod.ClientInfo;
const ClientMessage = manager_mod.ClientMessage;
const WindowData = manager_mod.WindowData;

const log = std.log.scoped(.service_worker);

/// One realm's environment.
pub const RealmEnvironment = struct {
    /// What the manager posts to.
    endpoint: manager_mod.Endpoint,
    allocator: Allocator,
    manager: *Manager,
    /// The realm. Compared; dereferenced only on its thread.
    realm: runtime.Context,
    /// The environment's id in the manager.
    id: u64,
    kind: registry_mod.EnvironmentKind,
    /// Its origin, serialized: also its storage key. OWNED.
    origin: []u8,
    /// Its creation URL, serialized. OWNED.
    creation_url: []u8,
    /// A service worker's own global: which worker it runs.
    service_worker_id: u64 = 0,
    /// A window client's frame type (Get Frame Type), as it was when the
    /// environment was made.
    frame_type: registry_mod.FrameType = .none,
    /// The realm's navigator's ServiceWorkerContainer, once made.
    container: ?Held = null,
    /// The service worker object map (3.1.1).
    workers: std.ArrayListUnmanaged(WorkerEntry) = .empty,
    /// The service worker registration object map (3.2.1).
    registrations: std.ArrayListUnmanaged(RegistrationEntry) = .empty,
    /// The promises its jobs and requests settle, by id.
    promises: std.ArrayListUnmanaged(PendingPromise) = .empty,
    next_promise: u64 = 1,
    /// The container's ready promise: made by the first `ready` read.
    ready: ?Ready = null,
    /// A Delivery is running: an end it causes (a listener that removes its
    /// own frame) leaves the memory to the Delivery.
    delivering: u32 = 0,
    ended: bool = false,
    /// The container's client message queue (3.4) is enabled: its tasks
    /// run. Until then the messages Client.postMessage adds to it wait in
    /// `client_queue`.
    client_queue_enabled: bool = false,
    client_queue: std.ArrayListUnmanaged(*ClientMessage) = .empty,

    const Held = struct {
        instance: *runtime.Instance,
        generation: u64,

        fn live(self: Held) ?*runtime.Instance {
            if (runtime.SlabAllocator.generationOf(self.instance) != self.generation) return null;
            return self.instance;
        }
    };

    const WorkerEntry = struct {
        worker_id: u64,
        object: Held,
        /// The object's state (its impl owns it; valid while it lives).
        data: *objects.ServiceWorkerObject,
    };

    const RegistrationEntry = struct {
        registration_id: u64,
        object: Held,
        data: *objects.RegistrationObject,
    };

    const PendingPromise = struct {
        id: u64,
        capability: engine.PromiseCapability,
    };

    const Ready = struct {
        capability: engine.PromiseCapability,
        /// The promise, held for every `ready` read.
        promise: engine.Owned,
        settled: bool = false,
    };

    fn ofEndpoint(endpoint: *manager_mod.Endpoint) *RealmEnvironment {
        return @fieldParentPtr("endpoint", endpoint);
    }

    // ------------------------------------------------------------------
    // Objects (3.1.1, 3.2.1)
    // ------------------------------------------------------------------

    /// "Get the service worker object representing `info`" in this realm.
    pub fn workerObject(self: *RealmEnvironment, info: WorkerInfo) !*runtime.Instance {
        // 1-2. objectMap[serviceWorker], if it exists.
        for (self.workers.items) |entry| {
            if (entry.worker_id != info.id) continue;
            if (entry.object.live()) |instance| return instance;
        }
        // 2.1-2.3. A new ServiceWorker in the realm, associated with it, its
        // state the service worker's.
        const data = try objects.ServiceWorkerObject.create(self.allocator, info.id, info.script_url, info.state);
        const instance = interfaces.ServiceWorker.initWith(self.realm.allocator, self.realm, .{ .service_worker = data }) catch |err| {
            data.destroy();
            return err;
        };
        try self.keep(instance);
        try self.workers.append(self.allocator, .{ .worker_id = info.id, .object = held(instance), .data = data });
        return instance;
    }

    /// "Get the service worker registration object representing `info`" in
    /// this realm.
    pub fn registrationObject(self: *RealmEnvironment, info: *const RegistrationInfo) !*runtime.Instance {
        for (self.registrations.items) |entry| {
            if (entry.registration_id != info.id) continue;
            if (entry.object.live()) |instance| return instance;
        }
        // 2.1-2.5. A new ServiceWorkerRegistration with null slots.
        const data = try objects.RegistrationObject.create(self.allocator, info.id, info.scope_url, info.storage_key, info.update_via_cache);
        const instance = interfaces.ServiceWorkerRegistration.initWith(self.realm.allocator, self.realm, .{ .service_worker_registration = data }) catch |err| {
            data.destroy();
            return err;
        };
        try self.keep(instance);
        try self.registrations.append(self.allocator, .{ .registration_id = info.id, .object = held(instance), .data = data });
        // 2.6-2.8. Each slot the registration has.
        if (info.installing) |w| setSlot(instance, data, .installing, try self.workerObject(w));
        if (info.waiting) |w| setSlot(instance, data, .waiting, try self.workerObject(w));
        if (info.active) |w| setSlot(instance, data, .active, try self.workerObject(w));
        return instance;
    }

    /// The object maps keep their objects while the environment lives: what
    /// script does not hold is still the same object the next time it is
    /// got, and still hears statechange and updatefound (Blink's
    /// ServiceWorker and ServiceWorkerRegistration have pending activity
    /// while their context lives). Each is wrapped at once - its wrapper
    /// owns it, so the collector frees it once the environment's end has let
    /// it go and script holds none of it.
    fn keep(self: *RealmEnvironment, instance: *runtime.Instance) !void {
        const wrapper = try engine.retainValue(self.realm, runtime.JSValue.fromInstance(instance));
        wrapper.release();
        engine.keepPlatformObjectAlive(instance);
    }

    // ------------------------------------------------------------------
    // Promises
    // ------------------------------------------------------------------

    /// A new promise in the realm, kept under a new id until a Delivery
    /// settles it. The promise, held for the caller (an impl's result).
    fn newPromise(self: *RealmEnvironment) !struct { id: u64, promise: engine.Owned } {
        var capability = try engine.createPromise(self.realm);
        errdefer engine.releasePromiseCapability(&capability);
        const promise = try engine.retainValue(self.realm, capability.promise);
        errdefer promise.release();
        const id = self.next_promise;
        self.next_promise += 1;
        try self.promises.append(self.allocator, .{ .id = id, .capability = capability });
        return .{ .id = id, .promise = promise };
    }

    /// Take the promise `id`: the caller settles and releases it.
    fn takePromise(self: *RealmEnvironment, id: u64) ?engine.PromiseCapability {
        for (self.promises.items, 0..) |entry, i| {
            if (entry.id == id) {
                _ = self.promises.swapRemove(i);
                return entry.capability;
            }
        }
        return null;
    }

    // ------------------------------------------------------------------
    // Deliveries
    // ------------------------------------------------------------------

    /// A Delivery reaches the realm's thread from its sink: it runs as a
    /// task of the realm (HTML "queue a task ... using the DOM manipulation
    /// task source"), its agent entered - a worker loop runs what its sink
    /// takes outside any realm.
    fn deliver(endpoint: *manager_mod.Endpoint, delivery: *Delivery) void {
        const self = RealmEnvironment.ofEndpoint(endpoint);
        if (self.ended) return;
        self.delivering += 1;
        defer {
            self.delivering -= 1;
            if (self.ended and self.delivering == 0) self.destroy();
        }
        var task: DeliveryInRealm = .{ .environment = self, .delivery = delivery };
        engine.runTaskInRealm(self.realm, DeliveryInRealm.steps, &task) catch |err| {
            log.debug("a service worker delivery found no realm: {s}", .{@errorName(err)});
        };
    }

    const DeliveryInRealm = struct {
        environment: *RealmEnvironment,
        delivery: *Delivery,

        fn steps(data: ?*anyopaque) void {
            const self: *DeliveryInRealm = @ptrCast(@alignCast(data.?));
            self.environment.handle(self.delivery) catch |err| log.debug("a service worker delivery: {s}", .{@errorName(err)});
        }
    };

    fn handle(self: *RealmEnvironment, delivery: *Delivery) !void {
        switch (delivery.*) {
            // Resolve Job Promise 1.2-1.4: the registration's object here.
            .resolve_registration => |m| {
                var capability = self.takePromise(m.promise) orelse return;
                defer engine.releasePromiseCapability(&capability);
                const object = try self.registrationObject(&m.registration);
                try engine.resolvePromise(&capability, runtime.JSValue.fromInstance(object));
            },
            // 1.3: the value, in the client's realm.
            .resolve_boolean => |m| {
                var capability = self.takePromise(m.promise) orelse return;
                defer engine.releasePromiseCapability(&capability);
                try engine.resolvePromise(&capability, runtime.JSValue.fromBoolean(m.value));
            },
            .resolve_undefined => |m| {
                var capability = self.takePromise(m.promise) orelse return;
                defer engine.releasePromiseCapability(&capability);
                try engine.resolvePromise(&capability, runtime.JSValue.jsUndefined);
            },
            .resolve_optional_registration => |m| {
                var capability = self.takePromise(m.promise) orelse return;
                defer engine.releasePromiseCapability(&capability);
                // getRegistration() 8.2.1-8.2.2.
                const info = m.registration orelse return engine.resolvePromise(&capability, runtime.JSValue.jsUndefined);
                const object = try self.registrationObject(&info);
                try engine.resolvePromise(&capability, runtime.JSValue.fromInstance(object));
            },
            .resolve_registrations => |m| {
                var capability = self.takePromise(m.promise) orelse return;
                defer engine.releasePromiseCapability(&capability);
                // getRegistrations() 4.3.1-4.3.3: each registration's object,
                // then a new frozen array of them in the promise's realm.
                const values = try self.allocator.alloc(runtime.JSValue, m.registrations.len);
                defer self.allocator.free(values);
                for (m.registrations, values) |*info, *value| {
                    value.* = runtime.JSValue.fromInstance(try self.registrationObject(info));
                }
                const array = try engine.createFrozenArray(self.realm, values);
                defer array.release();
                try engine.resolvePromise(&capability, array.borrow());
            },
            // Reject Job Promise: a new exception with errorData, in the
            // client's realm.
            .reject => |m| {
                var capability = self.takePromise(m.promise) orelse return;
                defer engine.releasePromiseCapability(&capability);
                const exception = switch (m.kind) {
                    .type_error => try engine.createSimpleException(self.realm, .TypeError, m.message),
                    .security_error => try engine.createDOMException(self.realm, "SecurityError", m.message),
                    .invalid_state_error => try engine.createDOMException(self.realm, "InvalidStateError", m.message),
                    .invalid_access_error => try engine.createDOMException(self.realm, "InvalidAccessError", m.message),
                    .not_supported_error => try engine.createDOMException(self.realm, "NotSupportedError", m.message),
                };
                defer exception.release();
                try engine.rejectPromise(&capability, exception.borrow());
            },
            // Update Worker State 4.1-4.5: the object's state, then
            // statechange - if the realm has an object for the worker.
            .worker_state => |m| {
                const entry = self.workerEntry(m.worker) orelse return;
                const instance = entry.object.live() orelse return;
                entry.data.state = m.state;
                dom.navigables.fireSimpleEvent(instance, "statechange");
            },
            // Update Registration State 2-4: the attribute is the worker's
            // object here, or null.
            .registration_slot => |m| {
                const entry = self.registrationEntry(m.registration) orelse return;
                if (entry.object.live() == null) return;
                const value: ?*runtime.Instance = if (m.worker) |w| try self.workerObject(w) else null;
                // workerObject may have grown the list: find the entry again.
                const again = self.registrationEntry(m.registration) orelse return;
                const registration = again.object.live() orelse return;
                setSlot(registration, again.data, m.slot, value);
            },
            // Install step 9.2: updatefound at the registration's objects.
            .update_found => |m| {
                const entry = self.registrationEntry(m.registration) orelse return;
                const instance = entry.object.live() orelse return;
                dom.navigables.fireSimpleEvent(instance, "updatefound");
            },
            // Notify Controller Change step 2.
            .controller_change => {
                const container = (self.container orelse return).live() orelse return;
                dom.navigables.fireSimpleEvent(container, "controllerchange");
            },
            // Activate step 7 and the ready getter's step 3.4: resolve the
            // ready promise if it is pending.
            .ready => |*info| {
                const kept = if (self.ready) |*r| r else return;
                if (kept.settled) return;
                kept.settled = true;
                const object = try self.registrationObject(info);
                try engine.resolvePromise(&kept.capability, runtime.JSValue.fromInstance(object));
            },
            // Client.postMessage step 4.5: a task of the container's client
            // message queue - run now if the queue is enabled, kept until it
            // is otherwise.
            .client_message => |*m| {
                const message = m.* orelse return;
                m.* = null;
                if (!self.client_queue_enabled) {
                    self.client_queue.append(self.allocator, message) catch |err| {
                        message.destroy();
                        return err;
                    };
                    return;
                }
                try self.dispatchClientMessage(message);
            },
            // matchAll() step 2.6.1-2.6.5: a Client or WindowClient for each
            // matched client, in a new frozen array.
            .resolve_clients => |m| {
                var capability = self.takePromise(m.promise) orelse return;
                defer engine.releasePromiseCapability(&capability);
                const values = try self.allocator.alloc(runtime.JSValue, m.clients.len);
                defer self.allocator.free(values);
                for (m.clients, values) |*info, *value| value.* = runtime.JSValue.fromInstance(try self.clientObject(info));
                const array = try engine.createFrozenArray(self.realm, values);
                defer array.release();
                try engine.resolvePromise(&capability, array.borrow());
            },
            // WindowClient.navigate() step 7, on this client's loop: 7.2, a
            // document that is not fully active, and 7.4, a navigation that
            // throws, reject; 7.3 navigates the browsing context as its
            // document's Location would.
            .navigate => |m| {
                const navigated = blk: {
                    const global = globalOf(self.realm) orelse break :blk false;
                    if (!dom.document_activity.fullyActive(global, runtime.SlabAllocator.generationOf(global))) break :blk false;
                    const location = interfaces.Window.get_location(global) catch break :blk false;
                    interfaces.Location.call_assign(location, m.url) catch break :blk false;
                    break :blk true;
                };
                if (!navigated) self.manager.navigateEnded(m.id);
            },
            // get(id): Resolve Get Client Promise's resolution, or undefined.
            .resolve_client => |*m| {
                var capability = self.takePromise(m.promise) orelse return;
                defer engine.releasePromiseCapability(&capability);
                const info = if (m.client) |*c| c else return engine.resolvePromise(&capability, runtime.JSValue.jsUndefined);
                try engine.resolvePromise(&capability, runtime.JSValue.fromInstance(try self.clientObject(info)));
            },
        }
    }

    // ------------------------------------------------------------------
    // Clients (Create Client, Create Window Client)
    // ------------------------------------------------------------------

    /// A new Client - a WindowClient when `info` has window data - in this
    /// (a service worker's) realm, representing `info`'s client.
    pub fn clientObject(self: *RealmEnvironment, info: *const ClientInfo) !*runtime.Instance {
        // The Client impl takes the object's state from `holder`; what it
        // has not taken when the construction fails is still ours.
        var holder: ?*objects.ClientObject = try objects.ClientObject.create(self.allocator, info);
        errdefer if (holder) |data| data.destroy();
        const data = holder.?;
        const instance = if (data.window) |*window|
            try interfaces.WindowClient.initWith(self.realm.allocator, self.realm, .{ .client = &holder, .window_client = window })
        else
            try interfaces.Client.initWith(self.realm.allocator, self.realm, .{ .client = &holder });
        // Wrapped at once: its wrapper owns it from here, so a step that
        // fails before script holds it leaves nothing behind.
        const wrapper = engine.retainValue(self.realm, runtime.JSValue.fromInstance(instance)) catch |err| {
            instance.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(instance));
            return err;
        };
        wrapper.release();
        return instance;
    }

    /// This environment as a client its service worker sees: its id, URL,
    /// type and frame type, and a window's window data now. OWNED (the
    /// manager's allocator: it crosses threads).
    fn clientInfo(self: *RealmEnvironment) !ClientInfo {
        const allocator = self.manager.allocator;
        const id = self.manager.clientIdOf(self.id) orelse return error.InvalidStateError;
        var info: ClientInfo = .{
            .environment = self.id,
            .id = id,
            .url = try allocator.dupe(u8, self.creation_url),
            .kind = self.kind,
            .frame_type = self.frame_type,
        };
        errdefer info.deinit(allocator);
        if (self.kind == .window) info.window = (try windowDataOf(allocator, self.realm)) orelse .{};
        return info;
    }

    // ------------------------------------------------------------------
    // The client message queue (3.4)
    // ------------------------------------------------------------------

    /// Enable the container's client message queue, if it is not enabled:
    /// the messages waiting in it run, each as a task of its own, in order.
    pub fn enableClientMessageQueue(self: *RealmEnvironment) void {
        if (self.client_queue_enabled) return;
        self.client_queue_enabled = true;
        const waiting = self.client_queue;
        self.client_queue = .empty;
        var list = waiting;
        defer list.deinit(self.allocator);
        for (list.items) |message| self.manager.deliverLater(self.id, .{ .client_message = message });
    }

    /// Client.postMessage step 4.5.1-4.5.6, a task of the client message
    /// queue: `message` (taken) dispatched at the container.
    fn dispatchClientMessage(self: *RealmEnvironment, message: *ClientMessage) !void {
        defer message.destroy();
        const realm = self.realm;
        // 4.4. destination: the container whose client this is.
        const destination = (try self.containerInstance()) orelse return;
        // 4.5.1. origin: sourceSettings' origin.
        const origin = message.origin;
        // 4.5.2. source: the service worker's object in this realm.
        const source_info = message.source orelse return;
        const source = try self.workerObject(source_info);
        const port_message = message.message orelse return;
        message.message = null;
        defer port_message.destroy();
        // The transferred ports, received here (their transfer-receiving
        // steps), then 4.5.3 StructuredDeserializeWithTransfer.
        var ports: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
        defer ports.deinit(self.allocator);
        const ends = port_message.takeEnds();
        defer port_message.allocator.free(ends);
        for (ends) |shipped| {
            const port = dom.message_ports.receive(realm, @ptrCast(shipped)) catch continue;
            ports.append(self.allocator, port) catch continue;
        }
        const data = engine.structuredDeserializeWithTransfer(realm, port_message.serialized, port_message.array_buffers, ports.items) catch {
            // "If this throws an exception, catch it, fire an event named
            // messageerror at destination, using MessageEvent, with its
            // origin initialized to origin and the source attribute
            // initialized to source."
            fireContainerMessage(realm, destination, "messageerror", runtime.JSValue.jsNull, origin, source, &.{});
            return;
        };
        defer data.release();
        // 4.5.4-4.5.6.
        fireContainerMessage(realm, destination, "message", data.value, origin, source, ports.items);
    }

    /// The realm's navigator's ServiceWorkerContainer, made if the realm
    /// never asked for it ("the user agent must create a
    /// ServiceWorkerContainer object when a Navigator object or a
    /// WorkerNavigator object is created").
    fn containerInstance(self: *RealmEnvironment) !?*runtime.Instance {
        if (self.container) |held_container| if (held_container.live()) |instance| return instance;
        const global = globalOf(self.realm) orelse return null;
        const navigator = switch (self.kind) {
            .window => try interfaces.Window.get_navigator(global),
            .dedicated_worker, .shared_worker => try interfaces.WorkerGlobalScope.get_navigator(global),
            .service_worker => return null,
        };
        const container = switch (self.kind) {
            .window => try interfaces.Navigator.get_serviceWorker(navigator),
            else => try interfaces.WorkerNavigator.get_serviceWorker(navigator),
        };
        // Its construction made it this environment's container.
        return container;
    }

    fn workerEntry(self: *RealmEnvironment, worker_id: u64) ?*WorkerEntry {
        for (self.workers.items) |*entry| if (entry.worker_id == worker_id) return entry;
        return null;
    }

    fn registrationEntry(self: *RealmEnvironment, registration_id: u64) ?*RegistrationEntry {
        for (self.registrations.items) |*entry| if (entry.registration_id == registration_id) return entry;
        return null;
    }

    // ------------------------------------------------------------------
    // The end
    // ------------------------------------------------------------------

    /// The environment's end, on its thread: Handle Service Worker Client
    /// Unload (the manager's), and nothing reaches it any more. Its memory
    /// goes now, or when the Delivery that caused the end returns.
    fn end(self: *RealmEnvironment) void {
        if (self.ended) return;
        self.ended = true;
        self.manager.removeEnvironment(self.id);
        // The promises its jobs would have settled stay pending: their
        // capabilities go while the agent lives (the realm's end runs this
        // before the realm and its agent end).
        for (self.promises.items) |*entry| engine.releasePromiseCapability(&entry.capability);
        self.promises.clearAndFree(self.allocator);
        // The objects are no longer kept for it: script's hold, and a
        // registration object's edges to its workers', keep them now.
        for (self.workers.items) |entry| if (entry.object.live()) |instance| engine.releasePlatformObject(instance);
        for (self.registrations.items) |entry| if (entry.object.live()) |instance| engine.releasePlatformObject(instance);
        self.workers.clearAndFree(self.allocator);
        self.registrations.clearAndFree(self.allocator);
        if (self.ready) |*kept| {
            engine.releasePromiseCapability(&kept.capability);
            kept.promise.release();
            self.ready = null;
        }
        // The messages still waiting for the client message queue are
        // discarded with their ports.
        for (self.client_queue.items) |message| message.destroy();
        self.client_queue.clearAndFree(self.allocator);
        if (self.delivering == 0) self.destroy();
    }

    fn destroy(self: *RealmEnvironment) void {
        for (self.client_queue.items) |message| message.destroy();
        self.client_queue.deinit(self.allocator);
        self.workers.deinit(self.allocator);
        self.registrations.deinit(self.allocator);
        self.promises.deinit(self.allocator);
        self.endpoint.sink.release();
        self.allocator.free(self.origin);
        self.allocator.free(self.creation_url);
        self.allocator.destroy(self);
    }
};

/// Set a registration object's `which` attribute to `worker` (an object of
/// the same realm) or null, with an edge from the registration's wrapper to
/// the worker's: the worker object lives as long as the registration object
/// does, once the environment no longer keeps either.
fn setSlot(registration: *runtime.Instance, data: *objects.RegistrationObject, which: registry_mod.Slot, worker: ?*runtime.Instance) void {
    const slot_name: engine.TracedSlot = .{ .name = @tagName(which) };
    data.slot(which).* = worker;
    if (worker) |w| engine.traceChild(registration, w, slot_name) else engine.forgetTracedChild(registration, slot_name);
}

fn held(instance: *runtime.Instance) RealmEnvironment.Held {
    return .{ .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance) };
}

// ============================================================================
// Finding a realm's environment
// ============================================================================

/// The environment of `realm`, made on first use when `create` - unless the
/// realm cannot be one: a Browser-less realm, a window whose document is not
/// fully active (a removed frame's), a worker that is closing, a realm whose
/// origin is opaque.
pub fn environmentOf(realm: runtime.Context, create: bool) ?*RealmEnvironment {
    const manager = Manager.of(realm) orelse return null;
    if (manager.endpointOf(realm)) |endpoint| {
        const found = RealmEnvironment.ofEndpoint(endpoint);
        return if (found.ended) null else found;
    }
    if (!create) return null;
    return makeEnvironment(manager, realm) catch |err| {
        log.debug("no service worker environment for a realm: {s}", .{@errorName(err)});
        return null;
    };
}

fn globalOf(realm: runtime.Context) ?*runtime.Instance {
    const record = realm.getRealm() orelse return null;
    return @ptrCast(@alignCast(record.global_object orelse return null));
}

/// What a realm's environment is made with.
const EnvironmentValues = struct {
    kind: registry_mod.EnvironmentKind,
    origin: []const u8,
    creation_url: []const u8,
    secure_context: bool,
    service_worker_id: u64 = 0,
    frame_type: registry_mod.FrameType = .none,
    client_queue_enabled: bool,
};

/// A RealmEnvironment for `realm`, not yet in the manager (its id 0).
fn newRealmEnvironment(manager: *Manager, realm: runtime.Context, values: EnvironmentValues) !*RealmEnvironment {
    const sink = realm.task_sink orelse return error.NoEventLoop;
    const allocator = manager.allocator;
    const self = try allocator.create(RealmEnvironment);
    errdefer allocator.destroy(self);
    const owned_origin = try allocator.dupe(u8, values.origin);
    errdefer allocator.free(owned_origin);
    const owned_url = try allocator.dupe(u8, values.creation_url);
    errdefer allocator.free(owned_url);
    self.* = .{
        .endpoint = .{
            .sink = sink.retain(),
            .deliver = RealmEnvironment.deliver,
            .window_data = endpointWindowData,
            .window_data_now = endpointWindowDataNow,
            .realm = realm,
        },
        .allocator = allocator,
        .manager = manager,
        .realm = realm,
        .id = 0,
        .kind = values.kind,
        .origin = owned_origin,
        .creation_url = owned_url,
        .service_worker_id = values.service_worker_id,
        .frame_type = values.frame_type,
        .client_queue_enabled = values.client_queue_enabled,
    };
    return self;
}

/// Free a RealmEnvironment the manager never took.
fn discardRealmEnvironment(self: *RealmEnvironment) void {
    self.ended = true;
    self.destroy();
}

fn makeEnvironment(manager: *Manager, realm: runtime.Context) !?*RealmEnvironment {
    const record = realm.getRealm() orelse return null;
    const global = globalOf(realm) orelse return null;
    const kind: registry_mod.EnvironmentKind = switch (record.info.context_type) {
        .window => blk: {
            // A document that is not fully active makes no client.
            if (!dom.document_activity.fullyActive(global, runtime.SlabAllocator.generationOf(global))) return null;
            break :blk .window;
        },
        .dedicated_worker => .dedicated_worker,
        .shared_worker => .shared_worker,
        .service_worker => .service_worker,
        else => return null,
    };
    if (kind != .window) {
        if (html.worker_host.scopeClosing(realm) orelse false) return null;
    }
    if (realm.task_sink == null) return null;
    const settings = dom.global_settings.of(global) orelse return null;
    const origin = try settings.origin(global);
    defer realm.allocator.free(origin);
    const creation_url = realm.documentUrl() orelse return null;
    const is_secure = settings.is_secure_context(global);
    const service_worker_id: u64 = if (kind == .service_worker) blk: {
        const service = html.worker_host.serviceScopeOf(realm) orelse return null;
        break :blk service.worker_id;
    } else 0;
    manager.noteCookieJar(dom.global_settings.cookieJarOf(global));
    const frame_type: registry_mod.FrameType = if (kind == .window) frameTypeOf(global) else .none;
    // The client message queue: a worker's is enabled once its script has
    // run (HTML "run a worker" step 14) - before any task of its loop, so
    // before any message could reach it; a window's after DOMContentLoaded
    // ("the end" step 6.4, `enableClientMessageQueueOf`), which a document
    // past "loading" has fired or is about to. (A message that arrives
    // between readiness "interactive" and the DOMContentLoaded task runs
    // before that event: stated deviation.)
    const queue_enabled = switch (kind) {
        .window => !documentIsLoading(global),
        .dedicated_worker, .shared_worker => true,
        .service_worker => false,
    };

    const self = try newRealmEnvironment(manager, realm, .{
        .kind = kind,
        .origin = origin,
        .creation_url = creation_url,
        .secure_context = is_secure,
        .service_worker_id = service_worker_id,
        .frame_type = frame_type,
        .client_queue_enabled = queue_enabled,
    });
    errdefer discardRealmEnvironment(self);
    self.id = try manager.addEnvironment(.{
        .kind = kind,
        .origin = self.origin,
        .creation_url = self.creation_url,
        .secure_context = is_secure,
        .frame_type = frame_type,
        .service_worker_id = service_worker_id,
        .endpoint = &self.endpoint,
    });
    return self;
}

// ============================================================================
// Clients at creation (dom.service_worker_clients)
// ============================================================================

const ClientKind = dom.service_worker_clients.ClientKind;

fn environmentKindOf(kind: ClientKind) registry_mod.EnvironmentKind {
    return switch (kind) {
        .window => .window,
        .dedicated_worker => .dedicated_worker,
        .shared_worker => .shared_worker,
    };
}

/// dom.service_worker_clients' `reserve`, on the creator's thread: the
/// reserved client of a navigation or a worker made from `creator`. A
/// worker's blob: script inherits its owner's active service worker when it
/// is of the owner's origin (SW 2.5.2: decided here, where the owner is).
pub fn reserveClient(creator: runtime.Context, kind: ClientKind, url: []const u8) ?*anyopaque {
    const manager = Manager.of(creator) orelse return null;
    // The creator is a client itself (its navigation request's client).
    const creator_environment = environmentOf(creator, true);
    const creator_id: u64 = if (creator_environment) |e| e.id else 0;
    var inherited: u64 = 0;
    if (kind != .window and std.mem.startsWith(u8, url, "blob:")) {
        if (creator_environment) |owner| {
            const origin = scope_mod.originOf(manager.allocator, url["blob:".len..]) catch null;
            defer if (origin) |o| manager.allocator.free(o);
            if (origin) |o| inherited = manager.controllerOfSameOrigin(owner.id, o);
        }
    }
    const handle = manager.reserveClient(environmentKindOf(kind), creator_id, inherited) orelse return null;
    return handle;
}

/// dom.service_worker_clients' `route_of_reserved`.
pub fn routeOfReserved(reserved: *anyopaque) ?@import("fetch").internal.ServiceWorkerRoute {
    const handle: *manager_mod.ReservedClient = @ptrCast(@alignCast(reserved));
    return handle.manager.routeOfReserved();
}

/// dom.service_worker_clients' `release`.
pub fn releaseReserved(reserved: *anyopaque) void {
    const handle: *manager_mod.ReservedClient = @ptrCast(@alignCast(reserved));
    handle.manager.releaseReserved(handle);
}

/// dom.service_worker_clients' `route_for_global`: "populate request from
/// client" - the route of a controlled client's requests.
pub fn routeForGlobal(global: *runtime.Instance) ?@import("fetch").internal.ServiceWorkerRoute {
    const manager = Manager.existingOf(global.ctx) orelse return null;
    return manager.routeForRealm(global.ctx);
}

/// dom.service_worker_clients' `created`: `realm` is a service worker client
/// from now on, before any of its script runs (SW 2.5.1, 2.5.2). An
/// environment the realm still has - its previous document's - ends first.
/// A realm of an opaque origin is no client (as `environmentOf` decides).
pub fn clientCreated(realm: runtime.Context, init: dom.service_worker_clients.ClientInit) void {
    const reserved: ?*manager_mod.ReservedClient = if (init.reserved) |r| @ptrCast(@alignCast(r)) else null;
    const manager = Manager.of(realm) orelse {
        if (reserved) |r| r.manager.releaseReserved(r);
        return;
    };
    const global_for_navigable = globalOf(realm);
    const navigable: usize = blk: {
        if (init.kind != .window) break :blk 0;
        const g = global_for_navigable orelse break :blk 0;
        const browsing_context = dom.browser_state.browsingContextOf(g) orelse break :blk 0;
        break :blk @intFromPtr(browsing_context);
    };
    if (std.mem.eql(u8, init.origin, "null")) {
        if (reserved) |r| manager.releaseReserved(r);
        // A navigate() that brought this document resolves with null.
        manager.navigatedToOpaque(navigable);
        return;
    }
    if (manager.endpointOf(realm)) |endpoint| RealmEnvironment.ofEndpoint(endpoint).end();
    const kind = environmentKindOf(init.kind);
    const global = globalOf(realm);
    const frame_type: registry_mod.FrameType = if (kind == .window) (if (global) |g| frameTypeOf(g) else .none) else .none;
    const self = newRealmEnvironment(manager, realm, .{
        .kind = kind,
        .origin = init.origin,
        .creation_url = init.creation_url,
        .secure_context = init.secure_context,
        .frame_type = frame_type,
        // A window's queue is enabled after DOMContentLoaded ("the end"
        // step 6.4); a worker's once its script has run, before any task.
        .client_queue_enabled = kind != .window,
    }) catch |err| {
        log.debug("no service worker client for a new realm: {s}", .{@errorName(err)});
        if (reserved) |r| manager.releaseReserved(r);
        return;
    };
    const creator: u64 = if (init.creator) |c| blk: {
        const found = environmentOf(c, false) orelse break :blk 0;
        break :blk found.id;
    } else 0;
    if (global) |g| manager.noteCookieJar(dom.global_settings.cookieJarOf(g));
    self.id = manager.createClient(.{
        .kind = kind,
        .origin = self.origin,
        .creation_url = self.creation_url,
        .secure_context = init.secure_context,
        .frame_type = frame_type,
        .endpoint = &self.endpoint,
        .reserved = reserved,
        .creator = creator,
        .navigable = navigable,
    }) catch |err| {
        log.debug("no service worker client for a new realm: {s}", .{@errorName(err)});
        discardRealmEnvironment(self);
        return;
    };
}

/// Whether the document of the Window `global` is still loading (its
/// readiness "loading": DOMContentLoaded has not fired).
fn documentIsLoading(global: *runtime.Instance) bool {
    const document = interfaces.Window.get_document(global) catch return false;
    const readiness = interfaces.Document.get_readyState(document) catch return false;
    return readiness == ._loading_;
}

/// Get Frame Type for the navigable of the Window `global`: "nested" when it
/// has a parent, "auxiliary" when its browsing context is an auxiliary one
/// (it has an opener: Chromium's GetFrameType asks HasOpener), "top-level"
/// otherwise.
fn frameTypeOf(global: *runtime.Instance) registry_mod.FrameType {
    // 1. A parent: nested.
    const parent = interfaces.Window.get_parent(global) catch return .@"top-level";
    if (parent) |p| if (p != global) return .nested;
    // 2. An auxiliary browsing context.
    const opener = interfaces.Window.get_opener(global) catch return .@"top-level";
    switch (opener) {
        .null, .undefined => {},
        else => return .auxiliary,
    }
    // 3.
    return .@"top-level";
}

/// A window client's window data, as a task of its event loop reads them
/// (matchAll() step 2.5.1.6.1-6, Resolve Get Client Promise 4.5): null when
/// the client is not enumerable - its document is not fully active (it is
/// not its browsing context's active document, or the context is gone).
/// OWNED (`allocator`). Run in the realm.
fn windowDataOf(allocator: std.mem.Allocator, realm: runtime.Context) !?WindowData {
    const global = globalOf(realm) orelse return null;
    if (!dom.document_activity.fullyActive(global, runtime.SlabAllocator.generationOf(global))) return null;
    const document = try interfaces.Window.get_document(global);
    var data: WindowData = .{};
    // visibilityState, and the has focus steps.
    data.visible = (try interfaces.Document.get_visibilityState(document)) == ._visible_;
    data.focused = try interfaces.Document.call_hasFocus(document);
    // The active document's ancestor origins list.
    const location = try interfaces.Window.get_location(global);
    const list = try interfaces.Location.get_ancestorOrigins(location);
    const count = try interfaces.DOMStringList.get_length(list);
    var origins: std.ArrayListUnmanaged([]u8) = .empty;
    errdefer {
        for (origins.items) |o| allocator.free(o);
        origins.deinit(allocator);
    }
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        var item = (try interfaces.DOMStringList.call_item(list, i)) orelse continue;
        defer item.deinit(realm.allocator);
        try origins.append(allocator, try allocator.dupe(u8, item.asSlice()));
    }
    data.ancestor_origins = try origins.toOwnedSlice(allocator);
    return data;
}

/// The endpoint's window data, on the realm's thread: entered in its realm
/// (a task from the sink runs in none).
fn endpointWindowData(endpoint: *manager_mod.Endpoint, allocator: std.mem.Allocator) ?WindowData {
    const self = RealmEnvironment.ofEndpoint(endpoint);
    if (self.ended or self.kind != .window) return null;
    var task: WindowDataInRealm = .{ .realm = self.realm, .allocator = allocator };
    engine.runTaskInRealm(self.realm, WindowDataInRealm.steps, &task) catch return null;
    return task.result;
}

/// The endpoint's window data read at once, on the realm's thread, from
/// inside script that blocks it (no task boundary, no checkpoint).
fn endpointWindowDataNow(endpoint: *manager_mod.Endpoint, allocator: std.mem.Allocator) ?WindowData {
    const self = RealmEnvironment.ofEndpoint(endpoint);
    if (self.ended or self.kind != .window) return null;
    var task: WindowDataInRealm = .{ .realm = self.realm, .allocator = allocator };
    engine.runInRealm(self.realm, WindowDataInRealm.steps, &task) catch return null;
    return task.result;
}

const WindowDataInRealm = struct {
    realm: runtime.Context,
    allocator: std.mem.Allocator,
    result: ?WindowData = null,

    fn steps(data: ?*anyopaque) void {
        const self: *WindowDataInRealm = @ptrCast(@alignCast(data.?));
        self.result = windowDataOf(self.allocator, self.realm) catch |err| blk: {
            log.debug("a window client's data: {s}", .{@errorName(err)});
            break :blk null;
        };
    }
};

/// Fire a MessageEvent named `event_type` at the container `destination`,
/// made in `realm`, with its data, origin, source (a ServiceWorker) and
/// ports (Client.postMessage step 4.5.3 / 4.5.6). Trusted: the user agent
/// fires it.
fn fireContainerMessage(
    realm: runtime.Context,
    destination: *runtime.Instance,
    event_type: []const u8,
    data: runtime.JSValue,
    origin: []const u8,
    source: *runtime.Instance,
    ports: []const *runtime.Instance,
) void {
    const init_dict = @import("dictionaries").MessageEventInit{
        .base = .{},
        .data = data,
        .origin = origin,
        .source = .{ .service_worker = source },
        .ports = ports,
    };
    const event = interfaces.MessageEvent.call_constructor(
        realm,
        runtime.DOMString.initInterned(event_type),
        @import("webidl").Opt(@import("dictionaries").MessageEventInit).passed(init_dict),
    ) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    _ = dom.fire_event.dispatchTrusted(destination, event) catch {};
    event.releaseIfUnwrapped(generation);
}

/// HTML's unloading document cleanup steps (and a worker's end), for
/// Service Workers: the environment ends - Handle Service Worker Client
/// Unload. Installed by ServiceWorkerContainer at process start; every
/// realm's end runs it, on the realm's thread.
pub fn environmentEnded(realm: runtime.Context) void {
    const manager = Manager.existingOf(realm) orelse return;
    const endpoint = manager.endpointOf(realm) orelse return;
    RealmEnvironment.ofEndpoint(endpoint).end();
}

// ============================================================================
// ServiceWorkerContainer
// ============================================================================

/// The container was made for `realm`'s navigator: its realm is an
/// environment from now on (the stated deviation above), and the container
/// is where controllerchange is fired.
pub fn containerMade(container: *runtime.Instance) void {
    const environment = environmentOf(container.ctx, true) orelse return;
    environment.container = held(container);
}

/// RegistrationOptions, as the container's impl converts them.
pub const RegisterOptions = struct {
    /// options["scope"], if it exists. BORROWED.
    scope: ?[]const u8 = null,
    worker_type: registry_mod.WorkerType = .classic,
    update_via_cache: registry_mod.UpdateViaCache = .imports,
};

/// What a realm that can be no environment gets - a removed frame's, a
/// closed window's: a promise rejected with an "InvalidStateError", as
/// Chromium's ServiceWorkerContainer and ServiceWorkerRegistration answer a
/// detached context ("The document is in an invalid state"). WPT
/// register-closed-window.https.html waits for register() to settle;
/// detached-context.https.html only checks that nothing resolves.
fn noEnvironment(realm: runtime.Context) !runtime.JSValue {
    return rejected(realm, .invalid_state_error, "The document is in an invalid state");
}

fn rejected(realm: runtime.Context, kind: registry_mod.ErrorKind, message: []const u8) !runtime.JSValue {
    const exception = switch (kind) {
        .type_error => try engine.createSimpleException(realm, .TypeError, message),
        .security_error => try engine.createDOMException(realm, "SecurityError", message),
        .invalid_state_error => try engine.createDOMException(realm, "InvalidStateError", message),
        .invalid_access_error => try engine.createDOMException(realm, "InvalidAccessError", message),
        .not_supported_error => try engine.createDOMException(realm, "NotSupportedError", message),
    };
    defer exception.release();
    return (try engine.createRejectedPromise(realm, exception.borrow())).take();
}

/// register(scriptURL, options) steps 3-8, `script_url` being step 2's
/// compliant string.
pub fn register(container: *runtime.Instance, script_url: []const u8, options: RegisterOptions) !runtime.JSValue {
    const realm = container.ctx;
    // 3. client: this's service worker client.
    const environment = environmentOf(realm, true) orelse return noEnvironment(realm);
    const allocator = environment.allocator;
    const base = realm.documentUrl();
    // 4. scriptURL, parsed with the API base URL (serialized; null: failure).
    const parsed_script = try scope_mod.parseAgainst(allocator, script_url, base);
    defer if (parsed_script) |s| allocator.free(s);
    // 5-6. scopeURL: options["scope"] parsed the same way, when it exists.
    var parsed_scope: ?[]u8 = null;
    defer if (parsed_scope) |s| allocator.free(s);
    var failed_scope = false;
    if (options.scope) |given| {
        parsed_scope = try scope_mod.parseAgainst(allocator, given, base);
        failed_scope = parsed_scope == null;
    }
    const made = try environment.newPromise();
    errdefer made.promise.release();
    // 7. Start Register.
    var urls = scope_mod.startRegister(allocator, parsed_script, parsed_scope, failed_scope) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.TypeError => {
            var capability = environment.takePromise(made.id).?;
            defer engine.releasePromiseCapability(&capability);
            const exception = try engine.createSimpleException(realm, .TypeError, "The script or scope URL is not a valid http(s) URL");
            defer exception.release();
            try engine.rejectPromise(&capability, exception.borrow());
            return made.promise.take();
        },
    };
    defer urls.deinit(allocator);
    // 10-15. The storage key (Crane's is the origin), Create Job with the
    // client's creation URL as its referrer, its worker type and update via
    // cache mode, and Schedule Job.
    try environment.manager.schedule(.{
        .job_type = .register,
        .storage_key = environment.origin,
        .scope_url = urls.scope_url,
        .script_url = urls.script_url,
        .worker_type = options.worker_type,
        .update_via_cache = options.update_via_cache,
        .client = .{ .environment = environment.id, .promise = made.id, .fetch_client = try fetchClientOf(realm) },
        .referrer = environment.creation_url,
    });
    // 8. Return p.
    return made.promise.take();
}

/// What the job thread's script fetch reads of `realm`'s settings object.
/// Null for a realm with none.
fn fetchClientOf(realm: runtime.Context) !?*anyopaque {
    const global = globalOf(realm) orelse return null;
    var client = try dom.global_settings.requestClient(global);
    defer client.deinit();
    const made = try run_mod.FetchClient.create(realm.browserScope(), &client.request);
    return @ptrCast(made);
}

/// getRegistration(clientURL) steps 1-9.
pub fn getRegistration(container: *runtime.Instance, client_url: []const u8) !runtime.JSValue {
    const realm = container.ctx;
    const environment = environmentOf(realm, true) orelse return noEnvironment(realm);
    const allocator = environment.allocator;
    // 3-5. clientURL, parsed with the API base URL, its fragment null.
    const parsed = try scope_mod.parseAgainst(allocator, client_url, realm.documentUrl()) orelse
        return rejected(realm, .type_error, "The client URL is not a valid URL");
    defer allocator.free(parsed);
    const url = try scope_mod.serializeExcludingFragment(allocator, parsed);
    defer allocator.free(url);
    // 6. Its origin must be the client's.
    const origin = try scope_mod.originOf(allocator, url);
    defer allocator.free(origin);
    if (!std.mem.eql(u8, origin, environment.origin)) return rejected(realm, .security_error, "The client URL is not same-origin with the document");
    const made = try environment.newPromise();
    errdefer made.promise.release();
    // 8.1. Match Service Worker Registration; 8.2, a task resolves.
    const info = try environment.manager.match(allocator, environment.origin, url);
    environment.manager.deliverLater(environment.id, .{ .resolve_optional_registration = .{ .promise = made.id, .registration = info } });
    return made.promise.take();
}

/// getRegistrations() steps 1-5.
pub fn getRegistrations(container: *runtime.Instance) !runtime.JSValue {
    const realm = container.ctx;
    const environment = environmentOf(realm, true) orelse return noEnvironment(realm);
    const made = try environment.newPromise();
    errdefer made.promise.release();
    // 4.1-4.2. Every registration of the client's storage key; 4.3, a task
    // resolves with their objects.
    const infos = try environment.manager.registrationsOf(environment.allocator, environment.origin);
    environment.manager.deliverLater(environment.id, .{ .resolve_registrations = .{ .promise = made.id, .registrations = infos } });
    return made.promise.take();
}

/// The ready attribute's getter steps.
pub fn ready(container: *runtime.Instance) !runtime.JSValue {
    const realm = container.ctx;
    // "The returned ready promise will never reject": a realm that can be no
    // environment gets one that never settles.
    const environment = environmentOf(realm, true) orelse {
        var capability = try engine.createPromise(realm);
        defer engine.releasePromiseCapability(&capability);
        return (try engine.retainValue(realm, capability.promise)).take();
    };
    // 1. A new promise the first time.
    if (environment.ready == null) {
        var capability = try engine.createPromise(realm);
        errdefer engine.releasePromiseCapability(&capability);
        const promise = try engine.retainValue(realm, capability.promise);
        environment.ready = .{ .capability = capability, .promise = promise };
    }
    const kept = &environment.ready.?;
    // 3. While it is pending: the registration matching the client's
    // creation URL, if its active worker is not null, resolves it in a task.
    if (!kept.settled) {
        if (try environment.manager.readyRegistration(environment.allocator, environment.origin, environment.creation_url)) |info| {
            environment.manager.deliverLater(environment.id, .{ .ready = info });
        }
    }
    // 4.
    return (try engine.retainValue(realm, kept.promise.value)).take();
}

/// The controller attribute's getter steps.
pub fn controller(container: *runtime.Instance) !?*runtime.Instance {
    const environment = environmentOf(container.ctx, true) orelse return null;
    // 2. The client's active service worker, or null.
    var info = (try environment.manager.controllerOf(environment.allocator, environment.id)) orelse return null;
    defer info.deinit(environment.allocator);
    // 3. Its object in this realm.
    return try environment.workerObject(info);
}

// ============================================================================
// ServiceWorkerRegistration
// ============================================================================

/// update() steps 1-9.
pub fn update(registration: *runtime.Instance, data: *const objects.RegistrationObject) !runtime.JSValue {
    const realm = registration.ctx;
    const environment = environmentOf(realm, true) orelse return noEnvironment(realm);
    const allocator = environment.allocator;
    // 2-3. newestWorker; null: InvalidStateError.
    var target = (try environment.manager.updateTarget(allocator, data.registration_id)) orelse
        return rejected(realm, .invalid_state_error, "The registration has no service worker to update");
    defer target.deinit(allocator);
    // 4. In a service worker global whose worker is installing:
    // InvalidStateError.
    if (environment.kind == .service_worker) {
        if (try environment.manager.workerInfo(allocator, environment.service_worker_id)) |info| {
            var own = info;
            defer own.deinit(allocator);
            if (own.state == .installing) return rejected(realm, .invalid_state_error, "The service worker is installing");
        }
    }
    const made = try environment.newPromise();
    errdefer made.promise.release();
    // 6-8. An update job for the newest worker's script url, its type the
    // newest worker's. Its update via cache mode is the registration's: the
    // browsers keep a registration's mode across update() (Chromium's
    // ServiceWorkerRegisterJob keeps the registration's
    // update_via_cache for an update job), where the spec leaves an update
    // job's mode unset and Install step 3 would copy it over.
    try environment.manager.schedule(.{
        .job_type = .update,
        .storage_key = target.storage_key,
        .scope_url = target.scope_url,
        .script_url = target.script_url,
        .worker_type = target.worker_type,
        .update_via_cache = target.update_via_cache,
        .client = .{ .environment = environment.id, .promise = made.id, .fetch_client = try fetchClientOf(realm) },
        .referrer = environment.creation_url,
    });
    return made.promise.take();
}

/// unregister() steps 1-5.
pub fn unregister(registration: *runtime.Instance, data: *const objects.RegistrationObject) !runtime.JSValue {
    const realm = registration.ctx;
    const environment = environmentOf(realm, true) orelse return noEnvironment(realm);
    const made = try environment.newPromise();
    errdefer made.promise.release();
    // 3-4. An unregister job for the registration's storage key and scope.
    try environment.manager.schedule(.{
        .job_type = .unregister,
        .storage_key = data.storage_key,
        .scope_url = data.scope_url,
        .client = .{ .environment = environment.id, .promise = made.id },
        .referrer = environment.creation_url,
    });
    return made.promise.take();
}

// ============================================================================
// ServiceWorkerGlobalScope
// ============================================================================

/// The serviceWorker getter: this global's service worker's object here.
pub fn serviceWorkerOf(global: *runtime.Instance) !*runtime.Instance {
    const environment = environmentOf(global.ctx, true) orelse return error.InvalidStateError;
    const allocator = environment.allocator;
    var info = (try environment.manager.workerInfo(allocator, environment.service_worker_id)) orelse WorkerInfo{
        // The worker has gone (its registration was cleared and its record
        // freed): an object as it was last seen - redundant.
        .id = environment.service_worker_id,
        .script_url = try allocator.dupe(u8, environment.creation_url),
        .state = .redundant,
    };
    defer info.deinit(allocator);
    return environment.workerObject(info);
}

/// The registration getter: this global's service worker's containing
/// registration's object here.
pub fn registrationOf(global: *runtime.Instance) !*runtime.Instance {
    const environment = environmentOf(global.ctx, true) orelse return error.InvalidStateError;
    var info = (try environment.manager.registrationOfWorker(environment.allocator, environment.service_worker_id)) orelse return error.InvalidStateError;
    defer info.deinit(environment.allocator);
    return environment.registrationObject(&info);
}

/// skipWaiting() steps 1-3: the job thread sets the flag and tries to
/// activate; its resolution comes back.
pub fn skipWaiting(global: *runtime.Instance) !runtime.JSValue {
    const realm = global.ctx;
    const environment = environmentOf(realm, true) orelse return noEnvironment(realm);
    const made = try environment.newPromise();
    environment.manager.report(.{ .skip_waiting = .{ .worker = environment.service_worker_id, .environment = environment.id, .promise = made.id } });
    return made.promise.take();
}

/// clients.claim() steps 1-4, for the Clients object `clients`.
pub fn claim(clients: *runtime.Instance) !runtime.JSValue {
    const realm = clients.ctx;
    const environment = environmentOf(realm, true) orelse return noEnvironment(realm);
    // 1. Not an active worker: InvalidStateError.
    if (!environment.manager.isActiveWorker(environment.service_worker_id)) {
        return rejected(realm, .invalid_state_error, "The service worker is not the active worker");
    }
    const made = try environment.newPromise();
    // 3. In parallel (the job thread); 3.2's resolution comes back.
    environment.manager.report(.{ .claim = .{ .worker = environment.service_worker_id, .environment = environment.id, .promise = made.id } });
    return made.promise.take();
}

// ============================================================================
// Messages: ServiceWorker.postMessage (3.1.5), Client.postMessage (4.2.6),
// the client message queue (3.4)
// ============================================================================

/// ServiceWorker.postMessage(message, options) steps 1-6, for the
/// ServiceWorker object `service_worker` whose state is `data`, with
/// `transfer` - options["transfer"].
pub fn postMessageToWorker(service_worker: *runtime.Instance, data: *const objects.ServiceWorkerObject, message: runtime.JSValue, transfer: []const runtime.JSValue) !void {
    const manager = Manager.of(service_worker.ctx) orelse return;
    const realm = engine.currentRealm() orelse service_worker.ctx;
    // 2-3. incumbentSettings and incumbentGlobal.
    const incumbent = engine.incumbentRealm() orelse service_worker.ctx;
    // 4. StructuredSerializeWithTransfer(message, options["transfer"]);
    // rethrow any exceptions.
    const port_message = try html.worker_host.serializePortMessage(realm, message, transfer, manager.allocator);
    // A sender that can be no environment - a removed frame's - sends
    // nothing (its realm is going).
    const environment = environmentOf(incumbent, true) orelse {
        port_message.destroy();
        return;
    };
    // 6.2.1-6.2.2: the source and origin, as the incumbent settings object
    // is now - read here, on its own thread.
    var source = messageSourceOf(environment) catch |err| {
        port_message.destroy();
        return err;
    };
    const outbound = manager.allocator.create(manager_mod.WorkerMessage) catch |err| {
        source.deinit(manager.allocator);
        port_message.destroy();
        return err;
    };
    outbound.* = .{
        .allocator = manager.allocator,
        .message = port_message,
        .origin = manager.allocator.dupe(u8, environment.origin) catch |err| {
            source.deinit(manager.allocator);
            port_message.destroy();
            manager.allocator.destroy(outbound);
            return err;
        },
        .source = source,
    };
    // 5. Should Skip Event never skips. 6. In parallel: Run Service Worker,
    // then the worker's task.
    manager.postToWorker(data.worker_id, outbound);
}

/// Who the incumbent `environment` is to a service worker's message event:
/// its own service worker (a service worker's global), or a client.
fn messageSourceOf(environment: *RealmEnvironment) !manager_mod.MessageSource {
    const allocator = environment.manager.allocator;
    if (environment.kind == .service_worker) {
        const info = (try environment.manager.workerInfo(allocator, environment.service_worker_id)) orelse WorkerInfo{
            .id = environment.service_worker_id,
            .script_url = try allocator.dupe(u8, environment.creation_url),
            .state = .redundant,
        };
        return .{ .service_worker = info };
    }
    return .{ .client = try environment.clientInfo() };
}

/// Client.postMessage(message, options) steps 1-4, for the Client object
/// `client` whose state is `data`, in a service worker's realm.
pub fn postMessageToClient(client: *runtime.Instance, data: *const objects.ClientObject, message: runtime.JSValue, transfer: []const runtime.JSValue) !void {
    const realm = engine.currentRealm() orelse client.ctx;
    // 2. sourceSettings: the Client's relevant settings object - the
    // service worker's global.
    const environment = environmentOf(client.ctx, true) orelse return;
    const manager = environment.manager;
    // 3. StructuredSerializeWithTransfer; rethrow any exceptions.
    const port_message = try html.worker_host.serializePortMessage(realm, message, transfer, manager.allocator);
    const outbound = manager.allocator.create(ClientMessage) catch |err| {
        port_message.destroy();
        return err;
    };
    outbound.* = .{
        .allocator = manager.allocator,
        .message = port_message,
        .origin = manager.allocator.dupe(u8, environment.origin) catch |err| {
            port_message.destroy();
            manager.allocator.destroy(outbound);
            return err;
        },
    };
    // 4. In parallel: the target client, if it is still there, gets a task
    // of its container's client message queue.
    manager.postToClient(data.environment, environment.service_worker_id, outbound);
}

/// startMessages() (3.4.6), and the first set of onmessage (3.4.7): enable
/// the container's client message queue.
pub fn startMessages(container: *runtime.Instance) void {
    const environment = environmentOf(container.ctx, true) orelse return;
    environment.enableClientMessageQueue();
}

/// HTML "the end" step 6.4 (after DOMContentLoaded): enable the client
/// message queue of the container whose client is `realm`'s settings
/// object, if it is an environment yet (one made later checks the
/// document's readiness).
pub fn enableClientMessageQueueOf(realm: runtime.Context) void {
    const manager = Manager.existingOf(realm) orelse return;
    const endpoint = manager.endpointOf(realm) orelse return;
    const environment = RealmEnvironment.ofEndpoint(endpoint);
    if (environment.ended) return;
    environment.enableClientMessageQueue();
}

// ============================================================================
// Clients (4.3): get(), matchAll(), openWindow(); WindowClient (4.2)
// ============================================================================

/// matchAll(options) steps 1-3, for the Clients object `clients`.
pub fn matchAll(clients: *runtime.Instance, include_uncontrolled: bool, client_type: Manager.ClientType) !runtime.JSValue {
    const realm = clients.ctx;
    const environment = environmentOf(realm, true) orelse return noEnvironment(realm);
    const made = try environment.newPromise();
    errdefer made.promise.release();
    // 2. In parallel - the manager's, its answer a task here.
    try environment.manager.matchAll(environment.id, environment.service_worker_id, include_uncontrolled, client_type, made.id);
    return made.promise.take();
}

/// get(id) steps 1-3, for the Clients object `clients`.
pub fn getClient(clients: *runtime.Instance, id: []const u8) !runtime.JSValue {
    const realm = clients.ctx;
    const environment = environmentOf(realm, true) orelse return noEnvironment(realm);
    const made = try environment.newPromise();
    errdefer made.promise.release();
    try environment.manager.getClient(environment.id, environment.service_worker_id, id, made.id);
    return made.promise.take();
}

/// openWindow(url) steps 1-4. Step 4 - "if no Window in this origin has
/// transient activation, return a promise rejected with an
/// InvalidAccessError" - is where every call ends: a headless user agent has
/// no user to activate a window, and a window's activation lives on its
/// own thread, which a service worker does not read. Chromium rejects
/// openWindow() without a user gesture the same way ("Not allowed to open a
/// window.").
pub fn openWindow(clients: *runtime.Instance, url: []const u8) !runtime.JSValue {
    const realm = clients.ctx;
    const allocator = realm.allocator;
    // 1-3. Parse url with the API base URL; failure or about:blank: TypeError.
    const parsed = try scope_mod.parseAgainst(allocator, url, realm.documentUrl()) orelse
        return rejected(realm, .type_error, "The URL is not valid");
    defer allocator.free(parsed);
    if (std.mem.eql(u8, parsed, "about:blank")) return rejected(realm, .type_error, "about:blank cannot be opened");
    // 4.
    return rejected(realm, .invalid_access_error, "Not allowed to open a window: no window has transient activation");
}

/// WindowClient.focus() step 1, where every call ends, as openWindow()
/// step 4 does: no Window in this origin has transient activation that a
/// service worker can see (Chromium: "Not allowed to focus a window.").
pub fn focusClient(window_client: *runtime.Instance) !runtime.JSValue {
    return rejected(window_client.ctx, .invalid_access_error, "Not allowed to focus a window: no window has transient activation");
}

/// WindowClient.navigate(url), for the WindowClient whose client has the id
/// `client_id`: steps 1-4 here; 5-7 navigate the client's browsing context
/// from its own event loop (the manager's `navigate` Delivery, as its
/// Location's assign() would), and the promise settles with the browsing
/// context's next window client - null when it is of another origin (7.9) -
/// as Chromium answers once the navigation has committed
/// (ServiceWorkerClientUtils' NavigateClient waits for the navigation to
/// finish).
pub fn navigateClient(window_client: *runtime.Instance, client_id: []const u8, url: []const u8) !runtime.JSValue {
    const realm = window_client.ctx;
    const allocator = realm.allocator;
    // 1-2. Parse url with the relevant settings object's API base URL.
    const parsed = try scope_mod.parseAgainst(allocator, url, realm.documentUrl()) orelse
        return rejected(realm, .type_error, "The URL is not valid");
    defer allocator.free(parsed);
    // 3. about:blank.
    if (std.mem.eql(u8, parsed, "about:blank")) return rejected(realm, .type_error, "A client cannot be navigated to about:blank");
    // 4. The client's active service worker must be this global's.
    const environment = environmentOf(realm, true) orelse return noEnvironment(realm);
    if (!environment.manager.clientControlledBy(client_id, environment.service_worker_id)) {
        return rejected(realm, .type_error, "The client is not controlled by this service worker");
    }
    // 5-8. In parallel - the manager's, its answer a task here.
    const made = try environment.newPromise();
    errdefer made.promise.release();
    try environment.manager.navigateClient(client_id, parsed, environment.id, environment.origin, made.id);
    return made.promise.take();
}
