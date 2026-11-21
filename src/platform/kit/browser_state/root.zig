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

        allocator: std.mem.Allocator,
        events: platform.EventSink,
        /// Owned copy of BrowserOptions.profile_dir; null: in memory.
        profile_dir: ?[]u8,
        /// The Browser's hold on its profile directory, while it has one.
        profile_lock: if (@hasDecl(Extra, "ProfileLock")) ?Extra.ProfileLock else void,
        stores: memory_store.Stores,
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
            const extra: Extra = if (@hasDecl(Extra, "init")) try Extra.init(allocator, options) else .{};
            self.* = .{
                .allocator = allocator,
                .events = events,
                .profile_dir = profile_dir,
                .profile_lock = profile_lock,
                // TODO(lane life1, D6): a Browser with a profile directory
                // opens its stores persistently under it - the persistent
                // backend behind the same openStore (docs/platform-protocol.md
                // 6.6) waits on the user's choice of engine (integrator,
                // 2026-11-21 6:38 PM ET); until then they are in memory.
                .stores = .init(allocator),
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

        /// The protocol's openStore over this Browser's stores. In memory in
        /// step 0 (kit/sqlite and kit/leveldb come with recipes step 4).
        pub fn openStore(browser: *platform.BrowserPlatform, store_name: platform.Str, options: platform.StoreOptions) platform.StoreError!*platform.Store {
            return of(browser).stores.open(store_name, options);
        }

        pub fn deleteStore(browser: *platform.BrowserPlatform, store_name: platform.Str) platform.StoreError!void {
            return of(browser).stores.delete(store_name);
        }
    };
}
