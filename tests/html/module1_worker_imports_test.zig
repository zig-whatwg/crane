//! import() through the module map's callback lists, in workers as in a
//! Window (HTML "fetch a single module script" steps 5-7 and 13, after
//! whatwg/html#10327 "Don't cache HTTP errors in the module map"):
//!
//! - a failed fetch leaves no entry, so the next import of the same URL
//!   fetches again and can succeed (repeated-imports.any.js);
//! - imports of a URL already being fetched join that fetch: one request,
//!   and every joined import hears that fetch's result - even when a
//!   sibling's rejection handler starts a fresh one
//!   (concurrent-failed-imports.any.js);
//! - an import of a module already in the map settles within microtasks,
//!   without waiting for a task (microtasks/basic.any.js, whatwg/html#8264);
//! - a worker that ends with an import in flight finishes it without
//!   running anything;
//! - two Browsers on two threads load one module graph in their workers at
//!   once, each from its own fetches into its own worker's map.
const std = @import("std");
const Browser = @import("browser").Browser;
const http = @import("module1_http_server.zig");

const routes = [_]http.Route{
    .{ .path = "/flaky.js", .fail_first = 1, .body = "export default 'flaky';" },
    .{ .path = "/slow.js", .delay_ms = 300, .body = "export default 'slow';" },
    .{ .path = "/slow-flaky.js", .delay_ms = 300, .fail_first = 1, .body = "export default 'recovered';" },
    .{ .path = "/empty.js", .body = "export default 'empty';" },
    .{ .path = "/hang.js", .delay_ms = 2000, .body = "export default 'late';" },
    .{ .path = "/root.js", .body = "import a from './a.js'; import b from './b.js'; export default a + b;" },
    .{ .path = "/a.js", .delay_ms = 50, .body = "import c from './c.js'; export default 'a' + c;" },
    .{ .path = "/b.js", .body = "import c from './c.js'; export default 'b' + c;" },
    .{ .path = "/c.js", .delay_ms = 50, .body = "export default 'c';" },
};

const page_url = "http://module1.test/page.html";
const base = "http://module1.test";

/// The cases, run in whatever global defines them; each resolves to a
/// string the test compares.
const cases_script =
    \\globalThis.ticker = (max) => {
    \\  let i = 0, stop = false;
    \\  Promise.resolve().then(function loop() { if (stop || i >= max) return; i++; Promise.resolve().then(loop); });
    \\  return () => { stop = true; return i; };
    \\};
    \\globalThis.moduleCases = {
    \\  async retry(base) {
    \\    let first;
    \\    try { await import(base + '/flaky.js'); first = 'loaded'; } catch (e) { first = e.name; }
    \\    const second = (await import(base + '/flaky.js')).default;
    \\    const third = (await import(base + '/flaky.js')).default;
    \\    return [first, second, third].join(',');
    \\  },
    \\  async joined(base) {
    \\    const all = await Promise.all([1, 2, 3].map(() => import(base + '/slow.js')));
    \\    return all.map(m => m.default).join(',');
    \\  },
    \\  async joinedFailure(base) {
    \\    const one = import(base + '/slow-flaky.js');
    \\    const two = import(base + '/slow-flaky.js');
    \\    const third = one.then(() => 'one-loaded', () => import(base + '/slow-flaky.js').then(m => m.default));
    \\    const second = two.then(() => 'two-loaded', e => e.name);
    \\    return (await third) + ',' + (await second);
    \\  },
    \\  async microtasks(base) {
    \\    await import(base + '/empty.js');
    \\    const getCount = ticker(1000);
    \\    await import(base + '/empty.js');
    \\    const loaded = getCount();
    \\    const fresh = ticker(1e6);
    \\    await import(base + '/root.js');
    \\    return (loaded < 1000) + ',' + fresh();
    \\  },
    \\  async graph(base) {
    \\    return (await import(base + '/root.js')).default;
    \\  },
    \\};
;

fn evaluate(browser: *Browser, source: []const u8) ![]u8 {
    const page = browser.current_context orelse return error.NoPage;
    return page.evaluateScriptToString(source, browser.allocator);
}

fn expectEval(browser: *Browser, source: []const u8, want: []const u8) !void {
    const got = try evaluate(browser, source);
    defer browser.allocator.free(got);
    try std.testing.expectEqualStrings(want, got);
}

fn waitForAnswer(browser: *Browser, turns: usize) ![]u8 {
    for (0..turns) |_| {
        const answer = try evaluate(browser, "answer");
        if (!std.mem.eql(u8, answer, "pending")) return answer;
        browser.allocator.free(answer);
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.TimedOut;
}

fn startBrowser(allocator: std.mem.Allocator, server: *http.Server) !*Browser {
    var proxy_buf: [64]u8 = undefined;
    const proxy = try server.proxyUrl(&proxy_buf);
    const browser = try Browser.init(allocator, .{
        .persist_storage = false,
        .snapshot_path = "",
        .proxy = .{ .manual = .{ .http = proxy, .no_proxy = "" } },
    });
    errdefer browser.deinit();
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body>", .{ .base_url = page_url });
    try expectEval(browser, cases_script ++ "; 'ok'", "ok");
    return browser;
}

const Global = enum { window, module_worker, classic_worker, shared_worker };

/// Run `moduleCases[name](base)` in `global` and answer what it resolved to.
fn runCase(browser: *Browser, global: Global, name: []const u8) ![]u8 {
    const launch = switch (global) {
        .window => try std.fmt.allocPrint(browser.allocator,
            \\globalThis.answer = 'pending';
            \\moduleCases.{s}('{s}').then(r => {{ answer = String(r); }}, e => {{ answer = 'threw:' + e; }});
            \\'ok'
        , .{ name, base }),
        else => try std.fmt.allocPrint(browser.allocator,
            \\globalThis.answer = 'pending';
            \\{{
            \\  const source = `globalThis.ticker = ${{ticker}}; globalThis.moduleCases = {{` +
            \\    Object.entries(moduleCases).map(([k, f]) => `${{f}}`).join(',') + `}};
            \\    const run = (port) => moduleCases.{s}('{s}').then(r => port.postMessage(String(r)), e => port.postMessage('threw:' + e));
            \\    if (typeof onconnect !== 'undefined' || self.constructor.name === 'SharedWorkerGlobalScope') self.onconnect = e => run(e.ports[0]);
            \\    else run(self);`;
            \\  const url = URL.createObjectURL(new Blob([source], {{ type: 'text/javascript' }}));
            \\  const type = '{s}';
            \\  const worker = type === 'shared' ? new SharedWorker(url, {{ type: 'module' }}) : new Worker(url, {{ type }});
            \\  const port = type === 'shared' ? worker.port : worker;
            \\  port.onmessage = e => {{ answer = e.data; if (type === 'shared') port.close(); else worker.terminate(); }};
            \\  worker.onerror = () => {{ answer = 'worker-error'; }};
            \\  if (type === 'shared') port.start();
            \\}}
            \\'ok'
        , .{ name, base, switch (global) {
            .module_worker => "module",
            .classic_worker => "classic",
            .shared_worker => "shared",
            .window => unreachable,
        } }),
    };
    defer browser.allocator.free(launch);
    try expectEval(browser, launch, "ok");
    return waitForAnswer(browser, 500);
}

fn expectCase(global: Global, name: []const u8, want: []const u8, path: []const u8, requests: u32) !void {
    const server = try http.Server.start(std.testing.allocator, &routes);
    defer server.stop();
    const browser = try startBrowser(std.testing.allocator, server);
    defer browser.deinit();
    const answer = try runCase(browser, global, name);
    defer std.testing.allocator.free(answer);
    try std.testing.expectEqualStrings(want, answer);
    try std.testing.expectEqual(requests, server.count(path));
}

fn onThread(comptime body: anytype, args: anytype) !void {
    const Run = struct {
        failure: ?anyerror = null,
        fn run(self: *@This(), a: @TypeOf(args)) void {
            @call(.auto, body, a) catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.run, .{ &run, args });
    thread.join();
    if (run.failure) |err| return err;
}

const globals = [_]Global{ .window, .module_worker, .classic_worker, .shared_worker };

test "module map: a failed fetch is not kept, and the next import fetches again" {
    for (globals) |global| try onThread(expectCase, .{ global, "retry", "TypeError,flaky,flaky", "/flaky.js", @as(u32, 2) });
}

test "module map: concurrent imports of one URL join a single fetch" {
    for (globals) |global| try onThread(expectCase, .{ global, "joined", "slow,slow,slow", "/slow.js", @as(u32, 1) });
}

test "module map: a joined import hears its own fetch's failure though a sibling refetches" {
    for (globals) |global| try onThread(expectCase, .{ global, "joinedFailure", "recovered,TypeError", "/slow-flaky.js", @as(u32, 2) });
}

test "module map: an import of a loaded module settles in microtasks, a fetched one after a task" {
    for (globals) |global| try onThread(expectCase, .{ global, "microtasks", "true,1000000", "/empty.js", @as(u32, 1) });
}

/// A worker ends with its import in flight: the import is finished without
/// running anything, and nothing is left behind (std.testing.allocator).
fn terminateWithImportInFlight(global: Global) !void {
    const server = try http.Server.start(std.testing.allocator, &routes);
    defer server.stop();
    const browser = try startBrowser(std.testing.allocator, server);
    defer browser.deinit();
    const launch = try std.fmt.allocPrint(browser.allocator,
        \\globalThis.answer = 'pending';
        \\{{
        \\  const source = `import('{s}/hang.js'); import('{s}/hang.js'); postMessage('started');`;
        \\  const url = URL.createObjectURL(new Blob([source], {{ type: 'text/javascript' }}));
        \\  const worker = new Worker(url, {{ type: '{s}' }});
        \\  worker.onmessage = () => {{ worker.terminate(); answer = 'terminated'; }};
        \\  worker.onerror = () => {{ answer = 'worker-error'; }};
        \\}}
        \\'ok'
    , .{ base, base, if (global == .module_worker) "module" else "classic" });
    defer browser.allocator.free(launch);
    try expectEval(browser, launch, "ok");
    const answer = try waitForAnswer(browser, 500);
    defer browser.allocator.free(answer);
    try std.testing.expectEqualStrings("terminated", answer);
    // Turn the loop past the worker's end.
    for (0..20) |_| _ = try browser.runEventLoopBlocking(10);
}

test "module map: a worker terminated with an import in flight leaves nothing behind" {
    try onThread(terminateWithImportInFlight, .{Global.module_worker});
    try onThread(terminateWithImportInFlight, .{Global.classic_worker});
}

/// Two Browsers on two threads, each with its own leak-checking allocator
/// (a shared one makes the threads take turns - lesson
/// testing-a-shared-test-allocator-makes-two-browsers-take-turns), load the
/// same graph - a diamond, root -> a, b -> c - in a worker at once, three
/// rounds each.
const TwoBrowsers = struct {
    server: *http.Server,
    failures: [2]?anyerror = .{ null, null },

    fn side(self: *TwoBrowsers, index: usize) void {
        self.steps() catch |err| {
            self.failures[index] = err;
        };
    }

    fn steps(self: *TwoBrowsers) !void {
        var debug_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
        const allocator = debug_allocator.allocator();
        {
            const browser = try startBrowser(allocator, self.server);
            defer browser.deinit();
            for (0..3) |_| {
                const answer = try runCase(browser, .module_worker, "graph");
                defer allocator.free(answer);
                try std.testing.expectEqualStrings("acbc", answer);
            }
        }
        if (debug_allocator.deinit() == .leak) return error.BrowserLeaked;
    }
};

test "module map: two Browsers on two threads load one module graph in their workers" {
    const server = try http.Server.start(std.testing.allocator, &routes);
    defer server.stop();
    var shared: TwoBrowsers = .{ .server = server };
    const a = try std.Thread.spawn(.{}, TwoBrowsers.side, .{ &shared, 0 });
    const b = try std.Thread.spawn(.{}, TwoBrowsers.side, .{ &shared, 1 });
    a.join();
    b.join();
    for (shared.failures) |failure| if (failure) |err| return err;
    // Each worker fetched each module once: three rounds, two Browsers.
    try std.testing.expectEqual(@as(u32, 6), server.count("/c.js"));
    try std.testing.expectEqual(@as(u32, 6), server.count("/root.js"));
}
