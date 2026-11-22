//! The profile's stores: how a Browser given a profile directory (the
//! user's ruling D6, 2026-11-21: Puppeteer's and Playwright's
//! --user-data-dir fully supported; docs/instances.md) hands its platform
//! state to each part of its web state that persists there, and flushes
//! them at its end. A Browser with no profile directory calls neither, and
//! keeps everything in memory exactly as before.
//!
//! Browser.init calls `attach` once its platform state and its event loop
//! exist and before its first realm; Browser.deinit calls `flush` once its
//! pages have ended and before its event loop and its platform state end.
//! The platform state ends BEFORE the scope's supplements (Browser.deinit),
//! so no supplement touches a store at its own end: what is pending is
//! written here.
//!
//! Every write to the profile's stores runs on the Browser's storage
//! sequence (storage.StorageSequence; lane prof2) - a thread `attach` starts
//! and `flush` stops once every store handed over its last batch, so the
//! stop writes them all before the platform state ends - as Chromium writes
//! DOM storage, cookies, the disk cache and IndexedDB on sequences of their
//! own, never on the thread that made the change. A Browser with no profile
//! directory has no sequence and no thread.

const std = @import("std");
const runtime = @import("runtime");
const platform = @import("platform");
const storage = @import("storage");
const cookiestore = @import("cookiestore");
const fetch = @import("fetch");
const service_worker = @import("service_worker");
const log = std.log.scoped(.profile_stores);
const EventLoop = @import("event_loop.zig").EventLoop;

/// Hand `browser` - the Browser's platform state, whose stores are under
/// its profile directory - to each persisting part of the Browser's web
/// state, with the Browser's event loop to arm its commits on.
pub fn attach(scope: *runtime.BrowserScope, browser: *platform.BrowserPlatform, loop: *EventLoop, profile_dir: []const u8) !void {
    // Every part that persists exists before the storage sequence: the
    // scope ends its supplements in the reverse of the order they were made,
    // so a Browser whose start fails after this stops the sequence - running
    // what it was handed - while they still live (StorageSequence.deinit).
    const user_agent_storage = try scope.of(storage.UserAgentStorage);
    const jar = try scope.of(cookiestore.CookieJar);
    const caches = try scope.of(service_worker.cache.store.Storage);
    // The storage sequence: the thread every write below runs on.
    const sequence = try scope.of(storage.StorageSequence);
    try sequence.start();
    errdefer sequence.stop();
    // localStorage (D6 step 2): read per area on first use, committed in
    // batches (storage/profile.zig).
    try user_agent_storage.attachProfile(browser, commitTimer(loop), sequence);
    // Cookies (D6 step 3): the jar's persistent cookies read now, its
    // changes committed in batches (cookiestore/storage_integration.zig).
    try jar.attachProfile(browser, commitTimer(loop), sequence);
    // The HTTP cache (D6 step 5): a disk level under the memory cache,
    // capped from the profile volume's free space (Chromium's
    // PreferredCacheSize; fetch/cache/persistence.zig). A Browser
    // configured with no HTTP cache has none to keep.
    if (scope.existing(fetch.network.NetworkContext)) |network| {
        if (network.http_cache) |cache| {
            const space: ?platform.VolumeSpace = platform.volumeSpace(platform.Str.from(profile_dir)) catch null;
            try cache.attachProfile(browser, commitTimer(loop), if (space) |s| s.available else null);
        }
    }
    // Cache Storage (D6 step 5): it keeps its caches in the store already;
    // the caches an earlier Browser deleted while Cache objects held them
    // go now (service_worker/cache/store.zig).
    caches.purgeEarlierBrowsers(browser) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => log.err("the profile's deleted caches could not be purged ({s})", .{@errorName(err)}),
    };
}

/// Hand `browser` - the Browser's platform state - to the parts of its web
/// state that keep their data in its stores whether or not it has a profile
/// directory: IndexedDB (D6 step 4: one engine in both modes, kit/memory_store
/// or kit/sqlite). Every Browser's, before its first realm.
pub fn attachPlatform(scope: *runtime.BrowserScope, browser: *platform.BrowserPlatform) !void {
    const server = try scope.of(storage.indexeddb.IDBServer);
    server.attachPlatform(browser) catch |err| return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        // A store it cannot read: IndexedDB fails at its first use rather
        // than the Browser at its start.
        else => log.err("IndexedDB's store could not be opened ({s})", .{@errorName(err)}),
    };
}

/// Write what is pending to the profile: the Browser's end. Each store hands
/// its last batch to the storage sequence, then the sequence stops - it runs
/// everything it was handed, IndexedDB's commits included, and its thread
/// is joined (Chromium's BLOCK_SHUTDOWN sequences) - before the event loop
/// and the platform state end. A post after this is dropped.
pub fn flush(scope: *runtime.BrowserScope) void {
    if (scope.existing(storage.UserAgentStorage)) |user_agent_storage| user_agent_storage.flushProfile();
    if (scope.existing(cookiestore.CookieJar)) |jar| jar.flush();
    if (scope.existing(fetch.network.NetworkContext)) |network| {
        if (network.http_cache) |cache| cache.flushProfile();
    }
    if (scope.existing(storage.StorageSequence)) |sequence| sequence.stop();
}

/// The Browser's event loop's timers as storage's commit timer: an owned
/// timer (runtime.TimerInterface.setTimeoutOwned), dropped if the loop
/// ends with it armed. The loop outlives every commit armed on it - it ends
/// after `flush`.
fn commitTimer(loop: *EventLoop) ?storage.profile.CommitTimer {
    if (loop.timerInterface() == null) return null;
    return .{ .context = loop, .arm = arm, .cancel = cancel, .post = post };
}

fn loopOf(context: *anyopaque) *EventLoop {
    return @ptrCast(@alignCast(context));
}

fn arm(context: *anyopaque, ms: u64, run: *const fn (?*anyopaque) void, data: ?*anyopaque, drop: *const fn (?*anyopaque) void) u64 {
    const timers = loopOf(context).timerInterface() orelse return 0;
    return timers.setTimeoutOwned(ms, run, data, drop);
}

fn cancel(context: *anyopaque, id: u64) bool {
    const timers = loopOf(context).timerInterface() orelse return false;
    return timers.clearTimeout(id);
}

/// A `post`: what to arm once the loop runs it.
const Posted = struct {
    loop: *EventLoop,
    ms: u64,
    run: *const fn (?*anyopaque) void,
    data: ?*anyopaque,
    drop: *const fn (?*anyopaque) void,

    /// On the window thread: arm it there.
    fn runPosted(context: ?*anyopaque) void {
        const self: *Posted = @ptrCast(@alignCast(context orelse return));
        const loop = self.loop;
        const ms = self.ms;
        const run_it = self.run;
        const data = self.data;
        const drop_it = self.drop;
        loop.allocator.destroy(self);
        if (arm(loop, ms, run_it, data, drop_it) == 0) drop_it(data);
    }

    /// Never run (the loop ended): any thread.
    fn dropPosted(context: ?*anyopaque) void {
        const self: *Posted = @ptrCast(@alignCast(context orelse return));
        const data = self.data;
        const drop_it = self.drop;
        self.loop.allocator.destroy(self);
        drop_it(data);
    }
};

/// Any thread: the loop's task sink takes the post, and its run arms the
/// timer on the window thread (the timer manager is the loop's thread's
/// alone). The loop's allocator is thread-safe, as the sink's tasks need.
fn post(context: *anyopaque, ms: u64, run: *const fn (?*anyopaque) void, data: ?*anyopaque, drop: *const fn (?*anyopaque) void) void {
    const loop = loopOf(context);
    const posted = loop.allocator.create(Posted) catch return drop(data);
    posted.* = .{ .loop = loop, .ms = ms, .run = run, .data = data, .drop = drop };
    _ = loop.taskSink().post(.{ .run = Posted.runPosted, .drop = Posted.dropPosted, .data = posted });
}
