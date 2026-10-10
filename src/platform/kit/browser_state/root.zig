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
        stores: memory_store.Stores,
        platform_options: platform.PlatformBrowserOptions,
        extra: Extra,

        pub fn create(allocator: std.mem.Allocator, options: *const platform.BrowserOptions, events: platform.EventSink) platform.Error!*platform.BrowserPlatform {
            const self = try allocator.create(Self);
            errdefer allocator.destroy(self);
            const profile_dir: ?[]u8 = if (options.profile_dir) |dir| try allocator.dupe(u8, dir.slice()) else null;
            errdefer if (profile_dir) |dir| allocator.free(dir);
            const extra: Extra = if (@hasDecl(Extra, "init")) try Extra.init(allocator, options) else .{};
            self.* = .{
                .allocator = allocator,
                .events = events,
                .profile_dir = profile_dir,
                .stores = .init(allocator),
                .platform_options = options.platform,
                .extra = extra,
            };
            return @ptrCast(self);
        }

        pub fn destroy(browser: *platform.BrowserPlatform) void {
            const self = of(browser);
            if (@hasDecl(Extra, "deinit")) self.extra.deinit();
            self.stores.deinit();
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
