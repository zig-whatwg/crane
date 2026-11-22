//! A destroyed navigable leaves nothing behind in a long-lived Browser (lane
//! rep1 batch 2, step 2). A browsing context is freed when its owner - an
//! iframe's or a popup's navigable record - has released it AND no Window
//! still holds it (a Window-hold count, the refcount shape of src/AGENTS.md
//! "DOM lifetime"); a closed popup's record goes with its browsing context's
//! last Window. Before, a removed iframe's browsing context went onto
//! Navigables.retired until the Browser's end, and a closed popup's record
//! stayed on its Browser's list until then too: a host that opens popups or
//! inserts iframes all day grew without bound.
//!
//! The checkpoint tests run a cycle of N, take a checkpoint (live bytes of
//! the Browser's allocator, the popup list, the retired list, the live
//! browsing contexts), run N more, and expect every one back at the
//! checkpoint. The order tests pin that a Window whose context's owner went
//! first still reads `closed` and `opener`, and the other way round.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const html_core = @import("html_core");
const dom = @import("dom");

/// The Browser's allocator: std.testing.allocator, with its live bytes
/// counted.
const Counting = struct {
    parent: std.mem.Allocator,
    live: std.atomic.Value(isize) = .init(0),

    fn allocator(self: *Counting) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &vtable };
    }
    const vtable: std.mem.Allocator.VTable = .{ .alloc = alloc, .resize = resize, .remap = remap, .free = free };
    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        const self: *Counting = @ptrCast(@alignCast(ctx));
        const p = self.parent.rawAlloc(len, alignment, ret_addr) orelse return null;
        _ = self.live.fetchAdd(@intCast(len), .monotonic);
        return p;
    }
    fn resize(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *Counting = @ptrCast(@alignCast(ctx));
        if (!self.parent.rawResize(memory, alignment, new_len, ret_addr)) return false;
        _ = self.live.fetchAdd(@as(isize, @intCast(new_len)) - @as(isize, @intCast(memory.len)), .monotonic);
        return true;
    }
    fn remap(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        const self: *Counting = @ptrCast(@alignCast(ctx));
        const p = self.parent.rawRemap(memory, alignment, new_len, ret_addr) orelse return null;
        _ = self.live.fetchAdd(@as(isize, @intCast(new_len)) - @as(isize, @intCast(memory.len)), .monotonic);
        return p;
    }
    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret_addr: usize) void {
        const self: *Counting = @ptrCast(@alignCast(ctx));
        self.parent.rawFree(memory, alignment, ret_addr);
        _ = self.live.fetchSub(@intCast(memory.len), .monotonic);
    }
};

fn onFreshThread(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        failure: ?anyerror = null,
        fn thread(self: *@This()) void {
            body() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| {
        std.debug.print("failed with {s}\n", .{@errorName(err)});
        return err;
    }
}

fn until(browser: *browser_mod.Browser, condition: []const u8) !void {
    var waited: usize = 0;
    while (waited < 5_000) : (waited += 10) {
        const page = browser.current_context orelse return error.NoPage;
        const result = try page.evaluateScriptToString(condition, testing.allocator);
        defer testing.allocator.free(result);
        if (std.mem.eql(u8, result, "true")) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    std.debug.print("never true: {s}\n", .{condition});
    return error.ConditionNeverMet;
}

fn expectEval(page: *browser_mod.Context, source: []const u8, expected: []const u8) !void {
    const got = try page.evaluateScriptToString(source, testing.allocator);
    defer testing.allocator.free(got);
    if (!std.mem.eql(u8, got, expected)) std.debug.print("{s}\n  expected: {s}\n  got:      {s}\n", .{ source, expected, got });
    try testing.expectEqualStrings(expected, got);
}

/// Collect, and let the tasks a collection queues run - a detached realm's
/// end among them - a few times over.
fn collect(browser: *browser_mod.Browser) !void {
    for (0..4) |_| {
        const page = browser.current_context orelse return error.NoPage;
        try page.runScript("TestUtils.gc(); TestUtils.gc();");
        _ = try browser.runEventLoopBlocking(20);
    }
}

/// The Browser's popup list's length (dom.auxiliary_navigables.count); 0 on
/// a tree that keeps popups on their opener's Window (the red run on main).
fn popupCount(browser: *browser_mod.Browser) usize {
    if (comptime @hasDecl(dom.auxiliary_navigables, "count")) return dom.auxiliary_navigables.count(browser.scope);
    return 0;
}

const Snapshot = struct {
    live_bytes: isize,
    popups: usize,
    retired: usize,
    contexts: usize,
    integrations: usize,

    fn take(browser: *browser_mod.Browser, counting: *Counting) !Snapshot {
        const navigables = try browser.scope.table(.navigables, html_core.Navigables);
        return .{
            .live_bytes = counting.live.load(.monotonic),
            .popups = popupCount(browser),
            .retired = navigables.retired.items.len,
            .contexts = navigables.contexts().len,
            .integrations = navigables.integrations.items.len,
        };
    }
};

const n = 24;
/// Live bytes a cycle may leave above what the same number of realms leaves
/// (the control below): hash tables and caches that grow once. A record per
/// navigable is far above it.
const slack_bytes = 8 * 1024;

/// The control: one kept iframe navigated `n` times - `n` new realms, and no
/// navigable made or destroyed. Each ended realm leaves its context manager
/// entry until the agent ends (context_manager ManagerState.retired: about
/// 800 bytes, queued as its own lifetime item), which a navigable cycle
/// leaves too, one realm per navigable; the cycle is measured against it.
const control_setup =
    \\ globalThis.kept = document.createElement('iframe'); kept.srcdoc = '<p>0</p>'; document.body.append(kept);
    \\ globalThis.navigations = 0;
    \\ globalThis.navigate = function () { let left = 24; kept.onload = () => { if (--left === 0) { globalThis.done = true; return; } kept.srcdoc = '<p>' + (++navigations) + '</p>'; }; kept.srcdoc = '<p>' + (++navigations) + '</p>'; };
;

fn runRound(browser: *browser_mod.Browser, comptime script: []const u8) !void {
    const page = browser.current_context orelse return error.NoPage;
    try page.runScript("globalThis.done = false; " ++ script);
    try until(browser, "globalThis.done === true");
    try collect(browser);
}

fn checkpointCycle(comptime cycle: []const u8) !void {
    var counting: Counting = .{ .parent = testing.allocator };
    const browser = try browser_mod.Browser.init(counting.allocator(), .{ .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><title>host</title><body>", .{ .base_url = "http://example.test/host" });
    try until(browser, "document.readyState === 'complete'");
    try page.runScript("globalThis.cycle = function () { " ++ cycle ++ " };");
    try page.runScript(control_setup);
    try until(browser, "kept.contentDocument !== null && kept.contentDocument.readyState === 'complete'");

    // A first round of each fills the Browser's state arena and its tables.
    try runRound(browser, "cycle();");
    try runRound(browser, "navigate();");
    const checkpoint = try Snapshot.take(browser, &counting);
    try runRound(browser, "cycle();");
    const after = try Snapshot.take(browser, &counting);
    try runRound(browser, "navigate();");
    const control = try Snapshot.take(browser, &counting);

    const grown = after.live_bytes - checkpoint.live_bytes;
    const per_realm = control.live_bytes - after.live_bytes;
    std.debug.print("{d} more navigables: live bytes {d} -> {d} ({d} per navigable; {d} realms alone: {d} per realm), popups {d} -> {d}, retired {d} -> {d}, browsing contexts {d} -> {d}, integrations {d} -> {d}\n", .{ n, checkpoint.live_bytes, after.live_bytes, @divTrunc(grown, n), n, @divTrunc(per_realm, n), checkpoint.popups, after.popups, checkpoint.retired, after.retired, checkpoint.contexts, after.contexts, checkpoint.integrations, after.integrations });
    try testing.expectEqual(checkpoint.popups, after.popups);
    try testing.expectEqual(checkpoint.retired, after.retired);
    try testing.expectEqual(checkpoint.contexts, after.contexts);
    try testing.expectEqual(checkpoint.integrations, after.integrations);
    try testing.expect(grown - per_realm <= slack_bytes);
}

fn popupsCheckpoint() !void {
    // Each popup opened and closed by script (close() queues its definitely
    // close), its WindowProxy dropped.
    try checkpointCycle(
        \\ let open = 0;
        \\ for (let i = 0; i < 24; i++) { const w = window.open('about:blank', '_blank'); w.close(); }
        \\ setTimeout(() => { globalThis.done = true; }, 50);
    );
}

test "N popups opened and closed leave the Browser's popup list, retired contexts and live bytes at the checkpoint" {
    try onFreshThread(popupsCheckpoint);
}

fn framesCheckpoint() !void {
    // One load listener for all of them (capture, on the document), so the
    // elements carry no listener of their own: what is measured is the
    // navigable, not per-element listener storage.
    try checkpointCycle(
        \\ if (!globalThis.frameLoads) {
        \\   globalThis.frameLoads = 0;
        \\   document.addEventListener('load', e => { if (e.target.localName !== 'iframe' || e.target === globalThis.kept) return; e.target.remove(); if (++frameLoads % 24 === 0) globalThis.done = true; }, true);
        \\ }
        \\ for (let i = 0; i < 24; i++) { const f = document.createElement('iframe'); f.srcdoc = '<p>frame</p>'; document.body.append(f); }
    );
}

test "N iframes inserted and removed leave the retired contexts, the live browsing contexts and live bytes at the checkpoint" {
    try onFreshThread(framesCheckpoint);
}

fn ownerFirst() !void {
    var counting: Counting = .{ .parent = testing.allocator };
    const browser = try browser_mod.Browser.init(counting.allocator(), .{ .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><title>host</title><body>", .{ .base_url = "http://example.test/host" });
    try until(browser, "document.readyState === 'complete'");
    const navigables = try browser.scope.table(.navigables, html_core.Navigables);
    const start = navigables.contexts().len;
    // The frame's owner (its element) goes first; script still holds its
    // Window, which reads its browsing context.
    try page.runScript(
        \\globalThis.f = document.createElement('iframe');
        \\f.srcdoc = '<p>frame</p>';
        \\document.body.append(f);
    );
    try until(browser, "f.contentDocument !== null && f.contentDocument.readyState === 'complete'");
    try page.runScript("globalThis.w = f.contentWindow; f.remove(); globalThis.f = null;");
    try collect(browser);
    try expectEval(page, "[w.closed, w.opener === null, w.parent === null || w.parent === undefined || w.parent === w].join()", "true,true,true");
    try testing.expectEqual(@as(usize, 0), navigables.retired.items.len);
    // The Window goes: so does its browsing context.
    try page.runScript("globalThis.w = null;");
    try collect(browser);
    try testing.expectEqual(start, navigables.contexts().len);
    try testing.expectEqual(@as(usize, 0), navigables.retired.items.len);
}

test "a Window whose browsing context's owner released it first still reads closed and opener, and the context goes with that Window" {
    try onFreshThread(ownerFirst);
}

fn windowFirst() !void {
    var counting: Counting = .{ .parent = testing.allocator };
    const browser = try browser_mod.Browser.init(counting.allocator(), .{ .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><title>host</title><body>", .{ .base_url = "http://example.test/host" });
    try until(browser, "document.readyState === 'complete'");
    const navigables = try browser.scope.table(.navigables, html_core.Navigables);
    const start = navigables.contexts().len;
    // The popup's first Window goes first: its navigation replaces it, and
    // the collector takes it - while the popup's record still owns the
    // context, which its current Window reads.
    try page.runScript("globalThis.p = window.open('about:blank', 'p');");
    try page.runScript("p.location.href = 'javascript:\"<p id=a>one</p>\"';");
    try until(browser, "p.document.getElementById('a') !== null");
    try page.runScript("p.location.href = 'javascript:\"<p id=b>two</p>\"';");
    try until(browser, "p.document.getElementById('b') !== null");
    try collect(browser);
    try expectEval(page, "[p.closed, p.opener === window].join()", "false,true");
    // Then its owner: the popup closes, and with its last Window gone the
    // record and the context go.
    try page.runScript("p.close();");
    // closed reads true from close() on (its is closing flag); the popup is
    // destroyed by the task close() queued, and then has no opener.
    try until(browser, "p.closed");
    _ = try browser.runEventLoopBlocking(50);
    try expectEval(page, "[p.closed, p.opener === null].join()", "true,true");
    try page.runScript("globalThis.p = null;");
    try collect(browser);
    try testing.expectEqual(start, navigables.contexts().len);
    try testing.expectEqual(@as(usize, 0), popupCount(browser));
    try testing.expectEqual(@as(usize, 0), navigables.retired.items.len);
}

test "a popup's earlier Window ends before its owner releases the context, the current one after it: closed and opener read right, and nothing is left" {
    try onFreshThread(windowFirst);
}
