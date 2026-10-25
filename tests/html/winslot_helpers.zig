//! Lane winslot1's forced-reuse tests share this: a page whose frames' realms
//! end, the Window such an end tears down found in the Browser's slab, its
//! slot given back and reissued to an impostor that announces itself
//! (docs/lessons/debugging-give-the-objects-that-reissue-a-freed-slot-a-voice.md),
//! and the holder read afterwards.
//!
//! Until every holder kind is safe (runtime.window_holders.reusable) a
//! realm's end keeps its Window's slot, so a test gives it back itself
//! (`releaseTornDown`) - after checking the realm's end tore the Window down
//! - exactly as the realm's end will once the switch is on; with it on, the
//! slot is back already and the test finds it so.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");

pub fn onFreshThread(comptime exercise: fn () anyerror!void) !void {
    const Run = struct {
        failure: ?anyerror = null,
        fn thread(self: *@This()) void {
            exercise() catch |err| {
                std.debug.print("test thread failed: {s}\n", .{@errorName(err)});
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

pub const Page = struct {
    browser: *browser_mod.Browser,

    pub fn open() !Page {
        const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
        errdefer browser.deinit();
        try browser.navigate("about:blank", .window);
        const page = browser.current_context orelse return error.NoPage;
        try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
        return .{ .browser = browser };
    }

    pub fn close(self: Page) void {
        self.browser.deinit();
    }

    /// Run `source`; a thrown error fails the test.
    pub fn run(self: Page, source: []const u8) !void {
        const page = self.browser.current_context orelse return error.NoPage;
        page.runScript(source) catch |err| {
            std.debug.print("script failed: {s}\n", .{source});
            return err;
        };
    }

    /// The completion of `source` as a string, OWNED by std.testing.allocator.
    pub fn eval(self: Page, source: []const u8) ![]u8 {
        const page = self.browser.current_context orelse return error.NoPage;
        return page.evaluateScriptToString(source, testing.allocator);
    }

    pub fn expectEval(self: Page, source: []const u8, expected: []const u8) !void {
        const got = try self.eval(source);
        defer testing.allocator.free(got);
        if (!std.mem.eql(u8, got, expected)) std.debug.print("{s}\n  expected: {s}\n  got:      {s}\n", .{ source, expected, got });
        try testing.expectEqualStrings(expected, got);
    }

    /// Run the page's tasks until `globalThis.pending` is falsy (bounded at
    /// 10 s); never a fixed delay.
    pub fn settle(self: Page) !void {
        var waited: usize = 0;
        while (true) : (waited += 50) {
            _ = try self.browser.runEventLoopBlocking(50);
            const pending = try self.eval("String(!!globalThis.pending)");
            defer testing.allocator.free(pending);
            if (std.mem.eql(u8, pending, "false")) return;
            if (waited >= 10_000) return error.PageNeverSettled;
        }
    }

    /// Collect, and let the tasks a collection queues run - a detached
    /// realm's end among them (protocol_realms.endCollectedRealm) - a few
    /// times over.
    pub fn collect(self: Page) !void {
        for (0..3) |_| {
            try self.run("globalThis.pending = 1; TestUtils.gc(); TestUtils.gc(); setTimeout(() => { TestUtils.gc(); pending = 0; }, 0);");
            try self.settle();
        }
    }
};

/// Every live Window in the Browser's slab, into `list` (testing.allocator).
pub fn windows(browser: *browser_mod.Browser, list: *std.ArrayListUnmanaged(*runtime.Instance)) !void {
    list.clearRetainingCapacity();
    var slab = browser.scope.slab.slabs;
    while (slab) |each| : (slab = each.next) {
        for (&each.slots) |*slot| {
            const instance: *runtime.Instance = @ptrCast(slot);
            if (runtime.SlabAllocator.generationOf(instance) == runtime.SlabAllocator.dead_generation) continue;
            if (std.mem.eql(u8, instance.vtable.name, "Window")) try list.append(testing.allocator, instance);
        }
    }
}

/// A Window, with its slab generation when found.
pub const Held = struct {
    window: *runtime.Instance,
    generation: u64,

    /// Its realm's end has run: torn down - or its slot back already.
    pub fn ended(self: Held) bool {
        if (runtime.SlabAllocator.generationOf(self.window) != self.generation) return true;
        return runtime.instance_lifecycle.isCleanedUp(self.window);
    }
};

/// The newest live Window that `before` does not hold - a frame's current
/// one, when its first document replaced its initial about:blank's.
pub fn newWindow(browser: *browser_mod.Browser, before: []const *runtime.Instance) !Held {
    var now: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer now.deinit(testing.allocator);
    try windows(browser, &now);
    var found: ?Held = null;
    outer: for (now.items) |w| {
        for (before) |b| if (b == w) continue :outer;
        const generation = runtime.SlabAllocator.generationOf(w);
        if (found == null or generation > found.?.generation) found = .{ .window = w, .generation = generation };
    }
    return found orelse error.NoNewWindow;
}

/// The torn-down Window's slot back, as the realm's end gives it back once
/// every holder is safe - unless it is back already.
pub fn releaseTornDown(held: Held) !void {
    if (runtime.SlabAllocator.generationOf(held.window) != held.generation) return;
    try testing.expect(runtime.instance_lifecycle.isCleanedUp(held.window));
    runtime.gc.releaseStorage(held.window);
}

/// Reissue the freed slot to an impostor that announces itself: spans with
/// id "impostor" (kept in globalThis.impostors) until one lands there.
pub fn reissue(page: Page, held: Held) !void {
    for (0..64) |_| {
        const generation = runtime.SlabAllocator.generationOf(held.window);
        if (generation != runtime.SlabAllocator.dead_generation and generation != held.generation and
            std.mem.eql(u8, held.window.vtable.name, "HTMLSpanElement")) return;
        try page.run("(globalThis.impostors ||= []).push(Object.assign(document.createElement('span'), { id: 'impostor' }));");
    }
    return error.SlotNotReissued;
}
