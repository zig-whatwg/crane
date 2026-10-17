//! Worklets (HTML 11), end to end in a Browser: addModule makes the worklet's
//! global scope, fetches the module with the document as the fetch client,
//! runs it in the global scope's own realm and settles the promise in the
//! Window's; the global scopes end with their document (HTML 11.3.3), and a
//! Browser that made worklets ends with nothing left of them (every test's
//! allocator checks for leaks).
//!
//! Each case runs on a thread of its own (a fresh per-thread state), and the
//! two-Browser case gives each Browser a DebugAllocator of its own, so the two
//! threads really run at once (AGENTS.md, "Tests come first").

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const engine = @import("engine");
const html = @import("html");

const worklet_host = html.worklet_host;

fn onFreshThread(comptime exercise: fn () anyerror!void) !void {
    const Run = struct {
        failure: ?anyerror = null,
        fn thread(self: *@This()) void {
            exercise() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

fn openBrowser(allocator: std.mem.Allocator) !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    return browser;
}

fn runScript(browser: *browser_mod.Browser, source: []const u8) !void {
    const page = browser.current_context orelse return error.NoPage;
    page.runScript(source) catch |err| {
        std.debug.print("script failed: {s}\n", .{source});
        return err;
    };
}

/// The completion of `source` in the page, OWNED by `allocator`.
fn evaluate(browser: *browser_mod.Browser, source: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const page = browser.current_context orelse return error.NoPage;
    return page.evaluateScriptToString(source, allocator);
}

/// Turn the event loop until `condition` (page script) is true, or a bound.
fn turnUntil(browser: *browser_mod.Browser, condition: []const u8, allocator: std.mem.Allocator) !void {
    var turns: usize = 0;
    while (turns < 400) : (turns += 1) {
        _ = try browser.runEventLoopBlocking(10);
        const answer = try evaluate(browser, condition, allocator);
        defer allocator.free(answer);
        if (std.mem.eql(u8, answer, "true")) return;
    }
    return error.NeverSettled;
}

fn pageRealm(browser: *browser_mod.Browser) !runtime.Context {
    const page = browser.current_context orelse return error.NoPage;
    return page.realm orelse error.NoPageRealm;
}

const Reports = struct {
    fn report(_: ?*anyopaque, info: *const engine.ErrorInfo) void {
        std.debug.print("reported in a worklet realm: {s}\n", .{info.message});
    }
    const reporter: engine.Reporter = .{ .report = report, .host = null };
};

/// `source` evaluated in each live worklet global scope of the page, joined
/// with spaces, in the order the scopes were made. OWNED by `allocator`.
fn evaluateInScopes(browser: *browser_mod.Browser, source: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const registry = worklet_host.Registry.existingOf(try pageRealm(browser)) orelse return allocator.dupe(u8, "");
    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(allocator);
    for (registry.scopes.items, 0..) |scope, i| {
        if (i > 0) try out.append(allocator, ' ');
        const got = try engine.evaluateClassicScriptToString(scope.realm, .{ .utf8 = source }, "", null, allocator, Reports.reporter);
        defer allocator.free(got);
        try out.appendSlice(allocator, got);
    }
    return out.toOwnedSlice(allocator);
}

fn liveScopes(browser: *browser_mod.Browser) !usize {
    const registry = worklet_host.Registry.existingOf(try pageRealm(browser)) orelse return 0;
    return registry.scopes.items.len;
}

const add_to_every_worklet =
    \\globalThis.outcomes = [];
    \\for (const [name, w] of [['paint', CSS.paintWorklet], ['layout', CSS.layoutWorklet],
    \\    ['animation', CSS.animationWorklet], ['audio', new OfflineAudioContext(2, 44100, 44100).audioWorklet]]) {
    \\  w.addModule('data:text/javascript,globalThis.ran = "' + name + '";')
    \\    .then(v => outcomes.push(name + ':' + v), e => outcomes.push(name + ':' + e.name));
    \\}
;

fn modulesRunInTheirOwnGlobalScopes() !void {
    const allocator = testing.allocator;
    const browser = try openBrowser(allocator);
    defer browser.deinit();
    try runScript(browser, add_to_every_worklet);
    try turnUntil(browser, "String(outcomes.length === 4)", allocator);
    const outcomes = try evaluate(browser, "outcomes.slice().sort().join()", allocator);
    defer allocator.free(outcomes);
    try testing.expectEqualStrings("animation:undefined,audio:undefined,layout:undefined,paint:undefined", outcomes);

    // One global scope per worklet, each its own realm, each having run its
    // module; the page's own global saw none of it.
    try testing.expectEqual(@as(usize, 4), try liveScopes(browser));
    const ran = try evaluateInScopes(browser, "String(globalThis.ran)", allocator);
    defer allocator.free(ran);
    try testing.expectEqualStrings("paint layout animation audio", ran);
    const page_ran = try evaluate(browser, "String(typeof globalThis.ran)", allocator);
    defer allocator.free(page_ran);
    try testing.expectEqualStrings("undefined", page_ran);
}

test "a module added to each worklet runs in that worklet's own global scope, and the Browser ends with none left" {
    try onFreshThread(modulesRunInTheirOwnGlobalScopes);
}

fn registrationsAreRecordedAndImportIsRefused() !void {
    const allocator = testing.allocator;
    const browser = try openBrowser(allocator);
    defer browser.deinit();
    // registerPaint records the definition (a second one under the name
    // throws), and import() in a worklet rejects with a TypeError
    // (HTML HostLoadImportedModule step 2).
    try runScript(browser,
        \\globalThis.done = false;
        \\const source = `
        \\  registerPaint('checker', class { paint() {} });
        \\  try { registerPaint('checker', class { paint() {} }); globalThis.second = 'none'; }
        \\  catch (e) { globalThis.second = e.name; }
        \\  globalThis.importOutcome = 'pending';
        \\  import('data:text/javascript,export default 1').then(
        \\    () => { globalThis.importOutcome = 'resolved'; },
        \\    e => { globalThis.importOutcome = e instanceof TypeError ? 'TypeError' : String(e); });
        \\`;
        \\CSS.paintWorklet.addModule('data:text/javascript,' + encodeURIComponent(source))
        \\  .then(() => { done = true; }, e => { done = 'failed: ' + e; });
    );
    try turnUntil(browser, "String(done === true)", allocator);
    for (0..5) |_| _ = try browser.runEventLoopBlocking(10);
    const second = try evaluateInScopes(browser, "String(second)", allocator);
    defer allocator.free(second);
    try testing.expectEqualStrings("InvalidModificationError", second);
    const imported = try evaluateInScopes(browser, "String(importOutcome)", allocator);
    defer allocator.free(imported);
    try testing.expectEqualStrings("TypeError", imported);
}

test "registerPaint records its definition, and import() in a worklet rejects with a TypeError" {
    try onFreshThread(registrationsAreRecordedAndImportIsRefused);
}

fn unhandledRejectionsInAWorkletFireNothing() !void {
    const allocator = testing.allocator;
    const browser = try openBrowser(allocator);
    defer browser.deinit();
    // A WorkletGlobalScope is no EventTarget: HTML "notify about rejected
    // promises" has nothing to fire at, and the page's own global hears
    // nothing either. A throwing module still resolves addModule (HTML
    // 11.3.2 step 6.4.4 reports its error).
    try runScript(browser,
        \\globalThis.done = false;
        \\globalThis.pageHeard = 0;
        \\addEventListener('unhandledrejection', () => { pageHeard++; });
        \\CSS.paintWorklet.addModule('data:text/javascript,Promise.reject(new Error("unhandled")); throw new Error("thrown");')
        \\  .then(() => { done = true; }, e => { done = 'failed: ' + e; });
    );
    try turnUntil(browser, "String(done === true)", allocator);
    for (0..5) |_| _ = try browser.runEventLoopBlocking(10);
    const heard = try evaluate(browser, "String(pageHeard)", allocator);
    defer allocator.free(heard);
    try testing.expectEqualStrings("0", heard);
}

test "an unhandled rejection in a worklet fires nothing, and a throwing module still resolves" {
    try onFreshThread(unhandledRejectionsInAWorkletFireNothing);
}

fn frameWorkletsEndWithTheirDocument() !void {
    const allocator = testing.allocator;
    const browser = try openBrowser(allocator);
    defer browser.deinit();
    try runScript(browser,
        \\globalThis.done = false;
        \\globalThis.frame = document.createElement('iframe');
        \\document.body.append(frame);
        \\frame.contentWindow.CSS.paintWorklet.addModule('data:text/javascript,1')
        \\  .then(() => { done = true; }, e => { done = 'failed: ' + e; });
    );
    try turnUntil(browser, "String(done === true)", allocator);
    // The frame's worklet global scope lives while the frame does.
    const registry = worklet_host.Registry.existingOf(try pageRealm(browser)) orelse return error.NoRegistry;
    try testing.expectEqual(@as(usize, 1), registry.scopes.items.len);
    // HTML 11.3.3: destroying the document terminates its worklet global
    // scopes. Removing the iframe destroys the frame's document.
    try runScript(browser, "frame.remove();");
    for (0..5) |_| _ = try browser.runEventLoopBlocking(10);
    try testing.expectEqual(@as(usize, 0), registry.scopes.items.len);
}

test "a frame's worklet global scopes end with the frame's document" {
    try onFreshThread(frameWorkletsEndWithTheirDocument);
}

const Side = struct {
    failure: ?anyerror = null,
    /// This Browser's alone: a shared allocator would make the two threads
    /// take turns (AGENTS.md, "Tests come first").
    debug_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init,

    fn run(self: *Side) void {
        self.steps() catch |err| {
            self.failure = err;
        };
        if (self.debug_allocator.deinit() == .leak and self.failure == null) self.failure = error.Leaked;
    }

    fn steps(self: *Side) !void {
        const allocator = self.debug_allocator.allocator();
        const browser = try openBrowser(allocator);
        defer browser.deinit();
        for (0..3) |_| {
            try runScript(browser, add_to_every_worklet);
            try turnUntil(browser, "String(outcomes.length === 4)", allocator);
            const outcomes = try evaluate(browser, "outcomes.slice().sort().join()", allocator);
            defer allocator.free(outcomes);
            try testing.expectEqualStrings("animation:undefined,audio:undefined,layout:undefined,paint:undefined", outcomes);
        }
    }
};

test "two Browsers on two threads make worklets at once, and each ends with nothing left" {
    var sides = [_]Side{ .{}, .{} };
    var threads: [2]std.Thread = undefined;
    for (&threads, &sides) |*thread, *side| thread.* = try std.Thread.spawn(.{}, Side.run, .{side});
    for (threads) |thread| thread.join();
    for (sides) |side| if (side.failure) |err| return err;
}
