//! One Browser's permission values and weak status subscriptions. Window
//! and worker threads reach it through BrowserScope. Delivery follows
//! dom/cookie_change_listeners.zig: retain the receiving TaskSink, copy only
//! values, and check the registration's slab generation on the target thread.
const std = @import("std");
const runtime = @import("runtime");
const types = @import("types.zig");
const query = @import("query.zig");
const OverrideStore = @import("override_store.zig").OverrideStore;
const ChangeBatch = @import("change_batch.zig").ChangeBatch;

pub const BrowserStore = struct {
    allocator: std.mem.Allocator,
    mutex: std.Io.Mutex = .init,
    overrides: OverrideStore,
    entries: std.ArrayListUnmanaged(Entry) = .empty,

    pub const Deliver = *const fn (*runtime.Instance, types.PermissionState) void;
    const Entry = struct {
        listener: *runtime.Instance,
        generation: u64,
        thread: std.Thread.Id,
        sink: ?*runtime.TaskSink,
        deliver: Deliver,
        key: []u8,
        descriptor: types.PermissionDescriptor,
    };

    pub fn init(allocator: std.mem.Allocator) BrowserStore {
        return .{ .allocator = allocator, .overrides = OverrideStore.init(allocator) };
    }

    pub fn deinit(self: *BrowserStore) void {
        // BrowserScope ends after all of its realms and task sinks.
        for (self.entries.items) |entry| self.freeEntry(entry);
        self.entries.deinit(self.allocator);
        self.overrides.deinit();
    }

    fn freeEntry(self: *BrowserStore, entry: Entry) void {
        self.allocator.free(entry.key);
        if (entry.sink) |sink| sink.release();
    }

    /// Register and read the initial state under one lock: a worker cannot
    /// change the override between the query's state read and subscription.
    pub fn listen(self: *BrowserStore, listener: *runtime.Instance, key: []const u8, descriptor: types.PermissionDescriptor, fallback: types.PermissionState, deliver: Deliver) std.mem.Allocator.Error!types.PermissionState {
        const owned_key = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(owned_key);
        return try self.listenOwned(listener, owned_key, self.allocator, descriptor, fallback, deliver);
    }

    /// Consume the caller's key only on successful registration. Every Entry
    /// belongs to the store allocator: move matching allocations, otherwise
    /// copy privately and release the incoming allocation only after append.
    /// On failure the caller still owns its original bytes. No allocator or
    /// pointer to a caller's ownership slot is retained in the registration.
    pub fn listenOwned(self: *BrowserStore, listener: *runtime.Instance, key: []u8, key_allocator: std.mem.Allocator, descriptor: types.PermissionDescriptor, fallback: types.PermissionState, deliver: Deliver) std.mem.Allocator.Error!types.PermissionState {
        const same_allocator = key_allocator.ptr == self.allocator.ptr and key_allocator.vtable == self.allocator.vtable;
        const owned_key = if (same_allocator) key else try self.allocator.dupe(u8, key);
        errdefer if (!same_allocator) self.allocator.free(owned_key);
        const sink = if (listener.ctx.task_sink) |s| s.retain() else null;
        errdefer if (sink) |s| s.release();
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        const state = query.resultState(descriptor.name, self.overrides.get(key, descriptor) orelse fallback);
        try self.entries.append(self.allocator, .{
            .listener = listener,
            .generation = runtime.SlabAllocator.generationOf(listener),
            .thread = std.Thread.getCurrentId(),
            .sink = sink,
            .deliver = deliver,
            .key = owned_key,
            .descriptor = descriptor,
        });
        if (!same_allocator) key_allocator.free(key);
        return state;
    }

    pub fn unlisten(self: *BrowserStore, listener: *runtime.Instance) void {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        var i: usize = 0;
        while (i < self.entries.items.len) {
            if (self.entries.items[i].listener != listener) {
                i += 1;
                continue;
            }
            self.freeEntry(self.entries.swapRemove(i));
        }
        if (self.entries.items.len == 0) self.entries.clearAndFree(self.allocator);
    }

    pub fn get(self: *BrowserStore, key: []const u8, descriptor: types.PermissionDescriptor) ?types.PermissionState {
        return self.overrides.get(key, descriptor);
    }

    fn isListening(self: *BrowserStore, listener: *runtime.Instance, generation: u64) bool {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        for (self.entries.items) |entry| {
            if (entry.listener == listener and entry.generation == generation) return true;
        }
        return false;
    }

    /// Permissions B "set a permission", steps 4-7. Every matching status
    /// receives its update on its own thread. The caller owns the returned
    /// batch share, and waits for isDone before completing its command.
    pub fn set(self: *BrowserStore, key: []const u8, descriptor: types.PermissionDescriptor, state: types.PermissionState) std.mem.Allocator.Error!*ChangeBatch {
        const batch = try ChangeBatch.create(self.allocator);
        errdefer batch.release();
        var local: std.ArrayListUnmanaged(*Delivery) = .empty;
        defer local.deinit(self.allocator);
        {
            std.Io.Threaded.mutexLockUncancelable(&self.mutex);
            defer std.Io.Threaded.mutexUnlock(&self.mutex);
            _ = try self.overrides.set(key, descriptor, state);
            for (self.entries.items) |*entry| {
                if (entry.descriptor.name != descriptor.name or !std.mem.eql(u8, entry.key, key)) continue;
                const overridden = self.overrides.get(key, entry.descriptor) orelse continue;
                const next = query.resultState(entry.descriptor.name, overridden);
                // A queued update can be skipped by an inactive document.
                // Only the target knows its actual state; it compares that
                // state when this task runs, including repeated overrides.
                const delivery = Delivery.create(self, entry.*, next, batch) catch continue;
                if (entry.sink) |sink| {
                    // post owns the record even when it immediately drops it.
                    // Drop releases bytes/counts only, never this mutex.
                    _ = sink.post(.{ .run = Delivery.run, .drop = Delivery.drop, .data = delivery });
                } else if (entry.thread == std.Thread.getCurrentId()) {
                    // Engine hosts without a loop use the existing immediate
                    // task fallback, after the subscription lock is released.
                    local.append(self.allocator, delivery) catch {
                        Delivery.drop(delivery);
                        continue;
                    };
                } else {
                    Delivery.drop(delivery);
                }
            }
        }
        for (local.items) |delivery| Delivery.run(delivery);
        return batch;
    }
};

const Delivery = struct {
    allocator: std.mem.Allocator,
    // The Browser's supplement outlives every one of its queues.
    store: *BrowserStore,
    listener: *runtime.Instance,
    generation: u64,
    deliver: BrowserStore.Deliver,
    state: types.PermissionState,
    batch: *ChangeBatch,

    fn create(store: *BrowserStore, entry: BrowserStore.Entry, state: types.PermissionState, batch: *ChangeBatch) !*Delivery {
        const self = try store.allocator.create(Delivery);
        self.* = .{
            .allocator = store.allocator,
            .store = store,
            .listener = entry.listener,
            .generation = entry.generation,
            .deliver = entry.deliver,
            .state = state,
            .batch = batch,
        };
        batch.startTask();
        return self;
    }

    fn finish(self: *Delivery) void {
        // runtime/task_sink.zig guarantees exactly one run OR drop for each
        // accepted record (including a post rejected by a closed sink).
        // The batch asserts its remaining count before giving back this share.
        const batch = self.batch;
        self.allocator.destroy(self);
        batch.finishTask();
    }

    fn run(data: ?*anyopaque) void {
        const self: *Delivery = @ptrCast(@alignCast(data.?));
        defer self.finish();
        if (!self.store.isListening(self.listener, self.generation)) return;
        if (runtime.SlabAllocator.generationOf(self.listener) != self.generation) return;
        self.deliver(self.listener, self.state);
    }

    fn drop(data: ?*anyopaque) void {
        // Any thread: bytes and atomic counts only, no realm access.
        const self: *Delivery = @ptrCast(@alignCast(data.?));
        self.finish();
    }
};
