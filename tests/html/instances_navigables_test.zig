//! Each Browser's browsing contexts are its own (instances B3, the
//! navigables list): two Browsers on two threads at once each retire a
//! frame whose Window script still holds, and one Browser's end frees only
//! its own retired contexts - never the other's, which that other's script
//! still reads (`w.closed`, `w.length`).
//!
//! A frame removed while its Window is reachable is retired, not freed
//! (BrowsingContext.discard): the Window reads its context until no Window
//! is left, at its Browser's end. A process-wide retired list let the first
//! Browser to end free every Browser's retired contexts under their
//! Windows.
//!
//! The Browsers allocate from `Pages`: every allocation its own mapping,
//! unmapped when freed, so reading a context another Browser freed faults
//! at once instead of reading stale bytes - and every allocation is counted,
//! so nothing either Browser made outlives both.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");

const page_url = "http://inst5.test/page.html";

/// The page allocator, counting what is live.
const Pages = struct {
    live: std.atomic.Value(isize) = .init(0),

    fn allocator(self: *Pages) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable: std.mem.Allocator.VTable = .{ .alloc = alloc, .resize = resize, .remap = remap, .free = free };
    const inner = std.heap.page_allocator;

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ret: usize) ?[*]u8 {
        const self: *Pages = @ptrCast(@alignCast(ctx));
        const made = inner.vtable.alloc(inner.ptr, len, alignment, ret) orelse return null;
        _ = self.live.fetchAdd(1, .monotonic);
        return made;
    }
    fn resize(_: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret: usize) bool {
        return inner.vtable.resize(inner.ptr, memory, alignment, new_len, ret);
    }
    fn remap(_: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret: usize) ?[*]u8 {
        return inner.vtable.remap(inner.ptr, memory, alignment, new_len, ret);
    }
    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret: usize) void {
        const self: *Pages = @ptrCast(@alignCast(ctx));
        inner.vtable.free(inner.ptr, memory, alignment, ret);
        _ = self.live.fetchSub(1, .monotonic);
    }
};

fn startBrowser(allocator: std.mem.Allocator) !*browser_mod.Browser {
    return browser_mod.Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
}

fn openPage(browser: *browser_mod.Browser) !void {
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><div id=root></div></body>", .{ .base_url = page_url });
}

fn truthy(browser: *browser_mod.Browser, source: []const u8) !bool {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.toBoolean(realm, held.borrow());
}

fn expectScript(browser: *browser_mod.Browser, source: []const u8) !void {
    if (!try truthy(browser, source)) {
        std.debug.print("false: {s}\n", .{source});
        return error.ScriptAnsweredFalse;
    }
}

const Shared = struct {
    /// What both Browsers allocate from.
    pages: Pages = .{},
    arrived: std.atomic.Value(u32) = .init(0),
    first_ended: std.atomic.Value(bool) = .init(false),

    fn meet(self: *Shared, point: u32) !void {
        _ = self.arrived.fetchAdd(1, .acq_rel);
        var spins: usize = 0;
        while (self.arrived.load(.acquire) < 2 * point) : (spins += 1) {
            if (spins > 20_000_000) return error.TheOtherBrowserNeverArrived;
            std.Thread.yield() catch {};
        }
    }
};

/// Frames made, kept by a Window reference, and removed: each a retired
/// context of this Browser.
const retire_frames =
    \\globalThis.kept = [];
    \\for (let i = 0; i < 8; i++) {
    \\  const frame = document.createElement('iframe');
    \\  document.body.appendChild(frame);
    \\  const w = frame.contentWindow;
    \\  if (!w || w.closed) throw new Error('no frame window');
    \\  kept.push(w);
    \\  frame.remove();
    \\}
    \\kept.every(w => w.closed === true && w.length === 0)
;

/// Every retired frame's Window still reads its own context.
const read_retired = "kept.length === 8 && kept.every(w => w.closed === true && w.length === 0 && w.frames === w)";

const Side = struct {
    index: usize,
    shared: *Shared,
    failure: ?anyerror = null,

    fn run(self: *Side) void {
        self.steps() catch |err| {
            self.failure = err;
            _ = self.shared.arrived.fetchAdd(2, .acq_rel);
            self.shared.first_ended.store(true, .release);
        };
    }

    fn steps(self: *Side) !void {
        const shared = self.shared;
        const browser = try startBrowser(shared.pages.allocator());
        var ended = false;
        defer if (!ended) browser.deinit();
        try openPage(browser);

        // Both Browsers retire frames at once.
        try expectScript(browser, retire_frames);
        try shared.meet(1);

        if (self.index == 0) {
            // A ends - and frees its own retired contexts.
            ended = true;
            browser.deinit();
            shared.first_ended.store(true, .release);
            return;
        }
        // B, after A's end: its retired contexts are still there to read,
        // and it can retire more.
        var spins: usize = 0;
        while (!shared.first_ended.load(.acquire)) : (spins += 1) {
            if (spins > 20_000_000) return error.TheOtherBrowserNeverEnded;
            std.Thread.yield() catch {};
        }
        try expectScript(browser, read_retired);
        try expectScript(browser, "TestUtils.gc(); true");
        try expectScript(browser, read_retired);
        try openPage(browser);
        try expectScript(browser, retire_frames);
    }
};

test "two Browsers on two threads each retire frames, and one's end frees none of the other's" {
    var shared: Shared = .{};
    var sides = [_]Side{ .{ .index = 0, .shared = &shared }, .{ .index = 1, .shared = &shared } };
    var threads: [2]std.Thread = undefined;
    for (&threads, &sides) |*thread, *side| thread.* = try std.Thread.spawn(.{}, Side.run, .{side});
    for (threads) |thread| thread.join();
    for (sides) |side| if (side.failure) |err| return err;
    try testing.expectEqual(@as(isize, 0), shared.pages.live.load(.acquire));
}
