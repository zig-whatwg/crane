//! kit/browser_state: the per-Browser platform state every built-in platform
//! keeps (docs/platform-protocol.md 3.3) - the Browser's options, its
//! EventSink and its stores - plus whatever the platform adds (`Extra`).
//! `createBrowserPlatform` makes one, `destroyBrowserPlatform` ends it, and
//! every per-Browser operation finds it again from the opaque
//! `*BrowserPlatform` with `of`.
//!
//! `Extra` may declare `fn init(allocator, *const platform.BrowserOptions)
//! error{OutOfMemory}!Extra` and `fn deinit(*Extra) void`; a platform with no
//! state of its own passes `struct {}`.
//!
//! `Extra` may declare `ProfileLock`, a type with `fn acquire(directory:
//! []const u8) platform.Error!ProfileLock` and `fn release(*ProfileLock)
//! void` (kit/posix's): a Browser given a profile directory holds it for its
//! life - one live Browser per directory (docs/instances.md), a second is
//! error.Busy - and a platform with no file system of its own declares none.
//!
//! `Extra` may declare `persistent_store`, a storage engine namespace with
//! kit/memory_store's operations and a `Stores` with `open(allocator,
//! profile_dir)`, `deinit`, `openStore` and `deleteStore` (kit/sqlite's): a
//! Browser given a profile directory keeps its stores there; one with none,
//! in kit/memory_store. The two engines' handles are told apart by the
//! `platform.StorageEngine` each handle points at (both kits hand out the
//! address of such a field), so the store operations below dispatch.
//!
//! `Extra` may also declare `fn start(*Extra, platform.EventSink) void`: the
//! platform's observers (docs/platform-protocol.md 3.3), which report through
//! the Browser's EventSink from threads of their own. `create` calls it last,
//! once the state is at its final address - an observer's context is a
//! pointer into `extra`, which never moves after - and `deinit`, the first
//! step of `destroy`, stops them: no observer posts after `destroy` returns
//! (the contract: the EventSink is borrowed "until destroyBrowserPlatform
//! returns").

const std = @import("std");
const platform = @import("platform");
const memory_store = @import("kit_memory_store");

pub fn BrowserState(comptime Extra: type) type {
    return struct {
        const Self = @This();
        const has_persistent = @hasDecl(Extra, "persistent_store");
        const Persistent = if (has_persistent) Extra.persistent_store else struct {};

        allocator: std.mem.Allocator,
        events: platform.EventSink,
        /// Owned copy of BrowserOptions.profile_dir; null: in memory.
        profile_dir: ?[]u8,
        /// The Browser's hold on its profile directory, while it has one.
        profile_lock: if (@hasDecl(Extra, "ProfileLock")) ?Extra.ProfileLock else void,
        stores: memory_store.Stores,
        /// The stores under the profile directory, when the Browser has one
        /// and the platform an engine for them (`persistent_store`).
        persistent: if (has_persistent) ?Persistent.Stores else void,
        platform_options: platform.PlatformBrowserOptions,
        extra: Extra,

        pub fn create(allocator: std.mem.Allocator, options: *const platform.BrowserOptions, events: platform.EventSink) platform.Error!*platform.BrowserPlatform {
            const self = try allocator.create(Self);
            errdefer allocator.destroy(self);
            const profile_dir: ?[]u8 = if (options.profile_dir) |dir| try allocator.dupe(u8, dir.slice()) else null;
            errdefer if (profile_dir) |dir| allocator.free(dir);
            // One live Browser per profile directory: taken before anything
            // else is made, so a refused Browser leaves nothing behind.
            var profile_lock: if (@hasDecl(Extra, "ProfileLock")) ?Extra.ProfileLock else void = if (@hasDecl(Extra, "ProfileLock")) null else {};
            if (@hasDecl(Extra, "ProfileLock")) {
                if (profile_dir) |dir| profile_lock = try Extra.ProfileLock.acquire(dir);
            }
            errdefer if (@hasDecl(Extra, "ProfileLock")) {
                if (profile_lock) |*held| held.release();
            };
            // The profile's stores, under the lock.
            var persistent: if (has_persistent) ?Persistent.Stores else void = if (has_persistent) null else {};
            if (has_persistent) {
                if (profile_dir) |dir| persistent = Persistent.Stores.open(allocator, dir) catch |err| return switch (err) {
                    error.OutOfMemory => error.OutOfMemory,
                    else => error.Io,
                };
            }
            errdefer if (has_persistent) {
                if (persistent) |*opened| opened.deinit();
            };
            const extra: Extra = if (@hasDecl(Extra, "init")) try Extra.init(allocator, options) else .{};
            self.* = .{
                .allocator = allocator,
                .events = events,
                .profile_dir = profile_dir,
                .profile_lock = profile_lock,
                .stores = .init(allocator),
                .persistent = persistent,
                .platform_options = options.platform,
                .extra = extra,
            };
            if (@hasDecl(Extra, "start")) self.extra.start(events);
            return @ptrCast(self);
        }

        pub fn destroy(browser: *platform.BrowserPlatform) void {
            const self = of(browser);
            if (@hasDecl(Extra, "deinit")) self.extra.deinit();
            self.stores.deinit();
            if (has_persistent) {
                if (self.persistent) |*opened| opened.deinit();
            }
            // The directory is free for the next Browser once its stores
            // are closed.
            if (@hasDecl(Extra, "ProfileLock")) {
                if (self.profile_lock) |*held| held.release();
            }
            if (self.profile_dir) |dir| self.allocator.free(dir);
            self.allocator.destroy(self);
        }

        pub fn of(browser: *platform.BrowserPlatform) *Self {
            return @ptrCast(@alignCast(browser));
        }

        /// The protocol's openStore over this Browser's stores: under its
        /// profile directory (`persistent_store`: kit/sqlite, the user's
        /// ruling 2026-11-21), else in memory (kit/memory_store).
        pub fn openStore(browser: *platform.BrowserPlatform, store_name: platform.Str, options: platform.StoreOptions) platform.StoreError!*platform.Store {
            const self = of(browser);
            if (has_persistent) {
                if (self.persistent) |*opened| return opened.openStore(store_name, options);
            }
            return self.stores.open(store_name, options);
        }

        pub fn deleteStore(browser: *platform.BrowserPlatform, store_name: platform.Str) platform.StoreError!void {
            const self = of(browser);
            if (has_persistent) {
                if (self.persistent) |*opened| return opened.deleteStore(store_name);
            }
            return self.stores.delete(store_name);
        }

        /// The engine whose handle `handle` is (a store, a transaction or a
        /// cursor): the `platform.StorageEngine` it points at.
        fn engineOf(handle: anytype) platform.StorageEngine {
            const engine: *const platform.StorageEngine = @ptrCast(@alignCast(handle));
            return engine.*;
        }

        fn persistentHandle(handle: anytype) bool {
            return has_persistent and engineOf(handle) == .sqlite;
        }

        pub fn closeStore(store: *platform.Store) void {
            if (persistentHandle(store)) return Persistent.closeStore(store);
            memory_store.closeStore(store);
        }

        pub fn beginTransaction(store: *platform.Store, mode: platform.TransactionMode) platform.StoreError!*platform.StoreTransaction {
            if (persistentHandle(store)) return Persistent.beginTransaction(store, mode);
            return memory_store.beginTransaction(store, mode);
        }

        pub fn commitTransaction(transaction: *platform.StoreTransaction) platform.StoreError!void {
            if (persistentHandle(transaction)) return Persistent.commitTransaction(transaction);
            return memory_store.commitTransaction(transaction);
        }

        pub fn abortTransaction(transaction: *platform.StoreTransaction) void {
            if (persistentHandle(transaction)) return Persistent.abortTransaction(transaction);
            memory_store.abortTransaction(transaction);
        }

        pub fn storeGet(transaction: *platform.StoreTransaction, allocator: std.mem.Allocator, key: platform.Bytes) platform.StoreError!?[]u8 {
            if (persistentHandle(transaction)) return Persistent.storeGet(transaction, allocator, key);
            return memory_store.storeGet(transaction, allocator, key);
        }

        pub fn storePut(transaction: *platform.StoreTransaction, key: platform.Bytes, value: platform.Bytes) platform.StoreError!void {
            if (persistentHandle(transaction)) return Persistent.storePut(transaction, key, value);
            return memory_store.storePut(transaction, key, value);
        }

        pub fn storeDelete(transaction: *platform.StoreTransaction, key: platform.Bytes) platform.StoreError!void {
            if (persistentHandle(transaction)) return Persistent.storeDelete(transaction, key);
            return memory_store.storeDelete(transaction, key);
        }

        pub fn storeDeleteRange(transaction: *platform.StoreTransaction, range: platform.KeyRange) platform.StoreError!void {
            if (persistentHandle(transaction)) return Persistent.storeDeleteRange(transaction, range);
            return memory_store.storeDeleteRange(transaction, range);
        }

        pub fn openCursor(transaction: *platform.StoreTransaction, range: platform.KeyRange, direction: platform.CursorDirection) platform.StoreError!*platform.StoreCursor {
            if (persistentHandle(transaction)) return Persistent.openCursor(transaction, range, direction);
            return memory_store.openCursor(transaction, range, direction);
        }

        pub fn cursorNext(cursor: *platform.StoreCursor, allocator: std.mem.Allocator) platform.StoreError!?platform.KeyValue {
            if (persistentHandle(cursor)) return Persistent.cursorNext(cursor, allocator);
            return memory_store.cursorNext(cursor, allocator);
        }

        pub fn closeCursor(cursor: *platform.StoreCursor) void {
            if (persistentHandle(cursor)) return Persistent.closeCursor(cursor);
            memory_store.closeCursor(cursor);
        }

        pub fn storeSize(store: *platform.Store) platform.StoreError!u64 {
            if (persistentHandle(store)) return Persistent.storeSize(store);
            return memory_store.storeSize(store);
        }
    };
}
