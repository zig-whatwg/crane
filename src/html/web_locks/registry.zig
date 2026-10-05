//! A Browser's lock managers (W3C Web Locks API, section 2), and the
//! environments that use them.
//!
//! "Each storage bucket includes one lock manager", and "pages and workers
//! (agents) sharing a storage bucket opened in the same user agent share a
//! lock manager even if they are in unrelated browsing contexts"; separate
//! user profiles are separate user agents (section 2). So one Registry is one
//! Browser's (a supplement of its scope, runtime.BrowserScope - shared by its
//! tabs, never by another Browser), and it holds one lock manager per storage
//! key: the held lock set and the lock request queue map.
//!
//! Its users run on several threads - the window agent's and one per
//! dedicated worker (docs/instances.md) - so everything here is under one
//! mutex, and nothing here touches an engine. The lock task queue's steps
//! (the spec runs them "in parallel", on one queue for the user agent) run
//! under that mutex, synchronously, on the thread that enqueues them: the
//! order of every step on the queue is the order the mutex is taken, which
//! is all the parallel queue promises. What the queue's steps hand back to
//! script - "enqueue the following steps on callback's relevant settings
//! object's responsible event loop" - is an Event posted to the requester's
//! Delivery, which runs it as a task of that environment's event loop, on
//! that environment's own thread.
//!
//! An environment is a Client: its realm (compared, never dereferenced
//! here), its clientId, its storage key (copied when it registers; null when
//! obtaining a lock manager fails - an opaque origin), and its Delivery.
//! Requests and held locks belong to a Client, and a Client's end - "terminate
//! remaining locks and requests" - removes every one of them before the
//! Client goes, so no entry outlives the Client it names.
//!
//! Stated deviations:
//! - Termination is per environment (realm), not per agent: a document's
//!   unloading cleanup ends ITS requests and locks, not those of the
//!   same-agent documents beside it - as Blink, where the LockManager is an
//!   ExecutionContext's and ContextDestroyed cancels its requests and drops
//!   its held locks (third_party/blink/renderer/modules/locks/lock_manager.cc,
//!   LockManager::ContextDestroyed). Section 2.6's "with its agent" would
//!   end an iframe's parent's locks with the iframe.
//! - An empty lock request queue leaves the lock request queue map (the spec
//!   keeps it). Nothing observes an empty queue: the snapshot lists requests,
//!   and gives no order across resources.
//!
//! Spec: https://w3c.github.io/web-locks/

const std = @import("std");
const Allocator = std.mem.Allocator;

/// A lock's or a request's mode (section 2.3).
pub const Mode = enum { shared, exclusive };

/// What the lock task queue hands back to an environment.
pub const EventKind = enum {
    /// "Process the lock request queue" step 14: the request `id` was
    /// granted - the lock `id` is in the held lock set - and its callback is
    /// to be invoked with a new Lock.
    granted,
    /// "Request a lock" step 3.5.1: `ifAvailable` was set and the request
    /// `id` was not grantable; its callback is to be invoked with null. The
    /// request never entered a queue.
    not_granted,
    /// "Request a lock" step 3.4.1.1: another request stole the lock `id`;
    /// its released promise is to be rejected with an "AbortError". The lock
    /// is no longer held.
    stolen,
};

pub const Event = struct {
    kind: EventKind,
    /// The request's id - also its lock's, once granted.
    id: u64,
};

/// How an environment hears from the lock task queue.
pub const Delivery = struct {
    ctx: *anyopaque,
    /// Post `event` to the environment's event loop. Runs on any thread,
    /// with the registry's lock held: it must not call back into the
    /// registry, and must not block (posting to a TaskSink takes only the
    /// sink's own lock).
    post: *const fn (ctx: *anyopaque, event: Event) void,
    /// The Client is gone: free `ctx`. Runs with the registry's lock NOT
    /// held, on the thread that removed the Client.
    deinit: *const fn (ctx: *anyopaque) void,
};

/// The length of a clientId: a UUID's string form.
pub const client_id_len = 36;

/// One environment's side of the lock managers.
pub const Client = struct {
    /// The environment (its realm). Compared, never dereferenced here.
    environment: *const anyopaque,
    /// The environment's LockManager object, handed back by `clientOf`.
    /// Never dereferenced here.
    owner: *anyopaque,
    /// "A lock has a clientId which is an opaque string": the environment's
    /// id, a random UUID.
    id: [client_id_len]u8,
    /// The storage key its lock manager is found by; null when "obtain a
    /// lock manager" fails for it. Owned.
    storage_key: ?[]u8,
    delivery: Delivery,
    /// "Terminate remaining locks and requests" ran for it: it has none, and
    /// makes none.
    ended: bool = false,
};

/// A lock request in a queue, or a lock in the held lock set: they have the
/// same items here. A request's callback, promise and signal are its
/// environment's, kept with its LockManager object by `id`.
const Entry = struct {
    id: u64,
    client: *Client,
    /// The resource name. Owned.
    name: []u8,
    mode: Mode,
};

/// A lock request queue (section 2.5).
const Queue = std.ArrayListUnmanaged(Entry);

/// A lock manager (section 2.2).
const Manager = struct {
    /// "Each lock manager has a held lock set", in the order its locks were
    /// granted.
    held: std.ArrayListUnmanaged(Entry) = .empty,
    /// "Each lock manager has a lock request queue map": resource name (an
    /// owned copy, the key) to its queue, in the order the queues were made.
    queues: std.StringArrayHashMapUnmanaged(Queue) = .empty,
};

/// One lock or request as "snapshot the lock state" lists it: the
/// LockInfo dictionary's members.
pub const Info = struct {
    /// Owned by the snapshot.
    name: []u8,
    mode: Mode,
    client_id: [client_id_len]u8,
};

/// "Snapshot the lock state": copies, so the caller reads them without
/// the lock.
pub const Snapshot = struct {
    held: []Info = &.{},
    pending: []Info = &.{},

    pub fn deinit(self: *Snapshot, allocator: Allocator) void {
        freeInfos(allocator, self.held);
        freeInfos(allocator, self.pending);
        self.* = .{};
    }
};

fn freeInfos(allocator: Allocator, infos: []Info) void {
    for (infos) |info| allocator.free(info.name);
    allocator.free(infos);
}

/// What `request` takes from the LockOptions (validated by the caller:
/// section 3.2.1 steps 5-9 reject the combinations that cannot reach here).
pub const RequestOptions = struct {
    mode: Mode = .exclusive,
    if_available: bool = false,
    steal: bool = false,
};

pub const Error = error{
    OutOfMemory,
    /// The Client ended ("terminate remaining locks and requests" ran).
    Ended,
    /// "Obtain a lock manager" failed for the Client.
    NoLockManager,
};

pub const Registry = struct {
    /// Thread-safe: an entry made on one thread is freed on another.
    allocator: Allocator,
    /// Protects everything below. Held across the lock task queue's steps,
    /// and across a Delivery's `post` - never across its `deinit`.
    mutex: std.Io.Mutex = .init,
    /// Request ids, unique in this Browser.
    next_id: u64 = 1,
    /// For clientIds.
    prng: std.Random.DefaultPrng,
    clients: std.ArrayListUnmanaged(*Client) = .empty,
    /// Storage key (an owned copy, the key) to its lock manager.
    managers: std.StringArrayHashMapUnmanaged(*Manager) = .empty,

    pub fn init(allocator: Allocator) Registry {
        var seed: u64 = 0;
        if (getentropy(std.mem.asBytes(&seed).ptr, @sizeOf(u64)) != 0) seed = @intFromPtr(&seed);
        return .{ .allocator = allocator, .prng = std.Random.DefaultPrng.init(seed) };
    }

    /// The Browser's end: every environment has ended, so every Client was
    /// unregistered - what is left is freed regardless.
    pub fn deinit(self: *Registry) void {
        for (self.managers.keys(), self.managers.values()) |key, manager| {
            for (manager.held.items) |entry| self.allocator.free(entry.name);
            manager.held.deinit(self.allocator);
            for (manager.queues.keys(), manager.queues.values()) |name, *queue| {
                for (queue.items) |entry| self.allocator.free(entry.name);
                queue.deinit(self.allocator);
                self.allocator.free(name);
            }
            manager.queues.deinit(self.allocator);
            self.allocator.destroy(manager);
            self.allocator.free(key);
        }
        self.managers.deinit(self.allocator);
        for (self.clients.items) |client| self.destroyClient(client);
        self.clients.deinit(self.allocator);
    }

    fn lock(self: *Registry) void {
        std.Io.Threaded.mutexLock(&self.mutex);
    }

    fn unlock(self: *Registry) void {
        std.Io.Threaded.mutexUnlock(&self.mutex);
    }

    // ------------------------------------------------------------------
    // Environments
    // ------------------------------------------------------------------

    /// A new Client for `environment`, whose lock manager is the one of
    /// `storage_key` (BORROWED; copied) - null when "obtain a lock manager"
    /// fails for it. `delivery` is the Client's from now on: its `deinit`
    /// runs when the Client goes, and on failure here.
    pub fn register(
        self: *Registry,
        environment: *const anyopaque,
        owner: *anyopaque,
        storage_key: ?[]const u8,
        delivery: Delivery,
    ) Allocator.Error!*Client {
        errdefer delivery.deinit(delivery.ctx);
        const client = try self.allocator.create(Client);
        errdefer self.allocator.destroy(client);
        const key: ?[]u8 = if (storage_key) |k| try self.allocator.dupe(u8, k) else null;
        errdefer if (key) |k| self.allocator.free(k);
        self.lock();
        defer self.unlock();
        try self.clients.ensureUnusedCapacity(self.allocator, 1);
        client.* = .{
            .environment = environment,
            .owner = owner,
            .id = self.randomUuid(),
            .storage_key = key,
            .delivery = delivery,
        };
        self.clients.appendAssumeCapacity(client);
        return client;
    }

    /// The Client registered for `environment`, if any.
    pub fn clientOf(self: *Registry, environment: *const anyopaque) ?*Client {
        self.lock();
        defer self.unlock();
        for (self.clients.items) |client| {
            if (client.environment == environment) return client;
        }
        return null;
    }

    /// Whether `client` has ended.
    pub fn ended(self: *Registry, client: *Client) bool {
        self.lock();
        defer self.unlock();
        return client.ended;
    }

    /// Section 2.6, "terminate remaining locks and requests" with `client`:
    /// its requests leave their queues and its locks leave the held lock
    /// set, and every queue they were in is processed - other environments'
    /// requests waiting behind them are granted. The Client stays
    /// registered, ended. Running it again does nothing.
    pub fn terminate(self: *Registry, client: *Client) void {
        self.lock();
        defer self.unlock();
        self.terminateLocked(client);
    }

    fn terminateLocked(self: *Registry, client: *Client) void {
        if (client.ended) return;
        client.ended = true;
        const key = client.storage_key orelse return;
        const manager = self.managers.get(key) orelse return;
        // "1. For each lock request request with agent equal to agent: abort
        // the request request." Every one leaves its queue first, and no
        // queue is processed until all have, so none of them is granted on
        // the way out.
        for (manager.queues.values()) |*queue| {
            var i: usize = 0;
            while (i < queue.items.len) {
                if (queue.items[i].client == client) {
                    const entry = queue.orderedRemove(i);
                    self.allocator.free(entry.name);
                } else i += 1;
            }
        }
        // "2. For each lock lock with agent equal to agent: release the lock
        // lock."
        var i: usize = 0;
        while (i < manager.held.items.len) {
            if (manager.held.items[i].client == client) {
                const entry = manager.held.orderedRemove(i);
                self.allocator.free(entry.name);
            } else i += 1;
        }
        // "Abort the request" and "release the lock" each end by processing
        // their queue: process every queue now (an unchanged one grants
        // nothing new).
        self.processAllQueues(manager);
    }

    /// `client`'s environment is gone: terminate it, then forget it. Its
    /// Delivery's `deinit` runs.
    pub fn unregister(self: *Registry, client: *Client) void {
        {
            self.lock();
            defer self.unlock();
            self.terminateLocked(client);
            for (self.clients.items, 0..) |registered, i| {
                if (registered == client) {
                    _ = self.clients.swapRemove(i);
                    break;
                }
            }
        }
        self.destroyClient(client);
    }

    fn destroyClient(self: *Registry, client: *Client) void {
        if (client.storage_key) |key| self.allocator.free(key);
        const delivery = client.delivery;
        self.allocator.destroy(client);
        delivery.deinit(delivery.ctx);
    }

    // ------------------------------------------------------------------
    // The lock task queue's steps
    // ------------------------------------------------------------------

    /// Section 4.1 "request a lock", the steps it enqueues on the lock task
    /// queue (3.1-3.6), for a request of `client` named `name` (BORROWED;
    /// copied). Returns the request's id, which every Event about it
    /// carries. Section 3.2.1's checks come first, the caller's.
    pub fn request(self: *Registry, client: *Client, name: []const u8, options: RequestOptions) Error!u64 {
        self.lock();
        defer self.unlock();
        if (client.ended) return error.Ended;
        const key = client.storage_key orelse return error.NoLockManager;
        const manager = try self.managerOf(key);
        const id = self.next_id;
        self.next_id += 1;

        // "3.1 Let queueMap be manager's lock request queue map." "3.3 Let
        // held be manager's held lock set."
        if (!options.steal) {
            // "3.5.1 If ifAvailable is true and request is not grantable,
            // then enqueue the following steps on callback's relevant
            // settings object's responsible event loop: invoke callback with
            // null, resolve promise with the result." The request is not in
            // the queue, so it is grantable only when the queue is empty.
            if (options.if_available and !newRequestGrantable(manager, name, options.mode)) {
                client.delivery.post(client.delivery.ctx, .{ .kind = .not_granted, .id = id });
                return id;
            }
        }

        // Everything that can fail first: the request's copy of its name, and
        // room for it in its queue ("3.2 Let queue be the result of getting
        // the lock request queue from queueMap for name").
        const owned_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(owned_name);
        const queue = try self.queueOf(manager, name);
        try queue.ensureUnusedCapacity(self.allocator, 1);
        const entry: Entry = .{ .id = id, .client = client, .name = owned_name, .mode = options.mode };

        if (options.steal) {
            // "3.4.1 For each lock of held: if lock's name is name, then
            // remove lock from held, and reject lock's released promise with
            // an "AbortError" DOMException."
            var i: usize = 0;
            while (i < manager.held.items.len) {
                const held = manager.held.items[i];
                if (std.mem.eql(u8, held.name, name)) {
                    _ = manager.held.orderedRemove(i);
                    held.client.delivery.post(held.client.delivery.ctx, .{ .kind = .stolen, .id = held.id });
                    self.allocator.free(held.name);
                } else i += 1;
            }
            // "3.4.2 Prepend request in queue."
            queue.insertAssumeCapacity(0, entry);
        } else {
            // "3.5.2 Enqueue request in queue."
            queue.appendAssumeCapacity(entry);
        }
        // "3.6 Process the lock request queue queue."
        self.processQueue(manager, name);
        return id;
    }

    /// Section 4.2 "release the lock" for the lock `id`: it leaves the held
    /// lock set, and its queue is processed. A lock no longer held - released
    /// already, stolen, or its environment terminated - is left alone.
    pub fn release(self: *Registry, id: u64) void {
        self.lock();
        defer self.unlock();
        for (self.managers.values()) |manager| {
            for (manager.held.items, 0..) |entry, i| {
                if (entry.id != id) continue;
                // "6. Remove lock from the manager's held lock set."
                _ = manager.held.orderedRemove(i);
                // "7. Process the lock request queue queue."
                self.processQueue(manager, entry.name);
                self.allocator.free(entry.name);
                return;
            }
        }
    }

    /// Section 4.3 "abort the request" for the request `id`: it leaves its
    /// queue, and the queue is processed. True when it was still in its
    /// queue - no Event about it will come. False when it was not: granted
    /// already (its `granted` Event is on its way, or was delivered), or its
    /// environment terminated.
    pub fn abort(self: *Registry, id: u64) bool {
        self.lock();
        defer self.unlock();
        for (self.managers.values()) |manager| {
            for (manager.queues.values()) |*queue| {
                for (queue.items, 0..) |entry, i| {
                    if (entry.id != id) continue;
                    // "6. Remove request from queue."
                    _ = queue.orderedRemove(i);
                    // "7. Process the lock request queue queue."
                    self.processQueue(manager, entry.name);
                    self.allocator.free(entry.name);
                    return true;
                }
            }
        }
        return false;
    }

    /// Section 4.5 "snapshot the lock state" for `client`'s lock manager:
    /// copies in `allocator`. Pending requests are listed queue by queue, in
    /// queue order; held locks in the order they were granted.
    pub fn snapshot(self: *Registry, client: *Client, allocator: Allocator) Error!Snapshot {
        self.lock();
        defer self.unlock();
        const key = client.storage_key orelse return error.NoLockManager;
        const manager = self.managers.get(key) orelse return .{};

        var pending: std.ArrayListUnmanaged(Info) = .empty;
        errdefer {
            for (pending.items) |info| allocator.free(info.name);
            pending.deinit(allocator);
        }
        // "3. For each queue of manager's lock request queue map's values:
        // for each request of queue: append «[ "name" → request's name,
        // "mode" → request's mode, "clientId" → request's clientId ]» to
        // pending."
        for (manager.queues.values()) |queue| {
            for (queue.items) |entry| try appendInfo(&pending, allocator, entry);
        }
        var held: std.ArrayListUnmanaged(Info) = .empty;
        errdefer {
            for (held.items) |info| allocator.free(info.name);
            held.deinit(allocator);
        }
        // "5. For each lock of manager's held lock set: append ... to held."
        for (manager.held.items) |entry| try appendInfo(&held, allocator, entry);

        const held_slice = try held.toOwnedSlice(allocator);
        errdefer freeInfos(allocator, held_slice);
        return .{ .held = held_slice, .pending = try pending.toOwnedSlice(allocator) };
    }

    fn appendInfo(list: *std.ArrayListUnmanaged(Info), allocator: Allocator, entry: Entry) Allocator.Error!void {
        try list.ensureUnusedCapacity(allocator, 1);
        list.appendAssumeCapacity(.{
            .name = try allocator.dupe(u8, entry.name),
            .mode = entry.mode,
            .client_id = entry.client.id,
        });
    }

    // ------------------------------------------------------------------
    // Lock managers and their queues
    // ------------------------------------------------------------------

    /// The lock manager of `key`, made on first use.
    fn managerOf(self: *Registry, key: []const u8) Allocator.Error!*Manager {
        if (self.managers.get(key)) |manager| return manager;
        const owned_key = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(owned_key);
        const manager = try self.allocator.create(Manager);
        errdefer self.allocator.destroy(manager);
        manager.* = .{};
        try self.managers.put(self.allocator, owned_key, manager);
        return manager;
    }

    /// "Get the lock request queue" from `manager`'s map for `name`: made
    /// when it does not exist. The pointer is good until the map next
    /// changes.
    fn queueOf(self: *Registry, manager: *Manager, name: []const u8) Allocator.Error!*Queue {
        if (manager.queues.getPtr(name)) |queue| return queue;
        const owned_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(owned_name);
        try manager.queues.put(self.allocator, owned_name, .empty);
        return manager.queues.getPtr(name).?;
    }

    /// Section 4.4 "process the lock request queue" of `name` in `manager`:
    /// while its first request is grantable, it leaves the queue, becomes a
    /// lock in the held lock set, and its environment is told. An emptied
    /// queue leaves the map. `name` is BORROWED, and need not be the map's
    /// key.
    fn processQueue(self: *Registry, manager: *Manager, name: []const u8) void {
        const index = manager.queues.getIndex(name) orelse return;
        const queue = &manager.queues.values()[index];
        // "2. For each request of queue: if request is not grantable, then
        // return." Only the first item of a queue is grantable.
        while (queue.items.len > 0) {
            const first = queue.items[0];
            if (!heldAllows(manager, first.name, first.mode)) break;
            // Room in the held lock set before the request leaves its queue:
            // without it, the request waits for the next time its queue is
            // processed.
            manager.held.ensureUnusedCapacity(self.allocator, 1) catch break;
            // "2.2 Remove request from queue." "2.12 Let lock be a new lock
            // with agent, clientId, manager, mode, name, released promise
            // and waiting promise." "2.13 Append lock to manager's held lock
            // set."
            _ = queue.orderedRemove(0);
            manager.held.appendAssumeCapacity(first);
            // "2.14 Enqueue the following steps on callback's relevant
            // settings object's responsible event loop" - the environment's
            // Delivery runs them.
            first.client.delivery.post(first.client.delivery.ctx, .{ .kind = .granted, .id = first.id });
        }
        if (queue.items.len == 0) {
            const key = manager.queues.keys()[index];
            queue.deinit(self.allocator);
            manager.queues.orderedRemoveAt(index);
            self.allocator.free(key);
        }
    }

    /// Process every queue of `manager`, once each.
    fn processAllQueues(self: *Registry, manager: *Manager) void {
        var i: usize = 0;
        while (i < manager.queues.count()) {
            const before = manager.queues.count();
            self.processQueue(manager, manager.queues.keys()[i]);
            // An emptied queue left the map: the next one is at `i` now.
            if (manager.queues.count() == before) i += 1;
        }
    }

    /// "Generate a random UUID": a version 4 UUID, lowercase. Under the
    /// lock.
    fn randomUuid(self: *Registry) [client_id_len]u8 {
        var bytes: [16]u8 = undefined;
        self.prng.random().bytes(&bytes);
        bytes[6] = (bytes[6] & 0x0f) | 0x40;
        bytes[8] = (bytes[8] & 0x3f) | 0x80;
        var out: [client_id_len]u8 = undefined;
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
        return out;
    }
};

/// "Grantable" (section 2.5) for a request not in its queue yet - the
/// ifAvailable check of "request a lock" step 3.5.1: "If queue is not empty
/// and request is not the first item in queue, then return false" - so only
/// with no queue for `name` - then the held lock set decides.
fn newRequestGrantable(manager: *Manager, name: []const u8, mode: Mode) bool {
    if (manager.queues.get(name)) |queue| {
        if (queue.items.len > 0) return false;
    }
    return heldAllows(manager, name, mode);
}

/// "Grantable" steps 8-9 (section 2.5), for the first request of its queue:
/// an exclusive request when no lock named `name` is held; a shared one when
/// no exclusive lock named `name` is.
fn heldAllows(manager: *Manager, name: []const u8, mode: Mode) bool {
    for (manager.held.items) |held| {
        if (!std.mem.eql(u8, held.name, name)) continue;
        switch (mode) {
            .exclusive => return false,
            .shared => if (held.mode == .exclusive) return false,
        }
    }
    return true;
}

extern "c" fn getentropy(buf: [*]u8, len: usize) c_int;
