//! The callbacks recover the naturally aligned WorkerHost from its own
//! embedded AgentHost. Exercise real threads, not a copied host record.
const std = @import("std");
const Browser = @import("browser").Browser;
const sw = @import("service_worker");
const testing = std.testing;

const service_source =
    \\importScripts('/imported.js');
    \\self.onmessage = e => e.waitUntil(import('data:text/javascript,export default 42')
    \\  .then(() => e.source.postMessage('unexpected-import'),
    \\    err => e.source.postMessage(imported + ':' + err.name)));
;

const host: sw.manager.Host = .{
    .fetch = tableFetch,
    .start = sw.run.host.start,
    .dispatch = sw.run.host.dispatch,
    .post_message = sw.run.host.post_message,
    .dispatch_fetch = sw.run.host.dispatch_fetch,
    .dispatch_functional = sw.run.host.dispatch_functional,
};

fn tableFetch(manager: *sw.Manager, plan: *const sw.registry.FetchPlan) sw.registry.FetchOutcome {
    return resources(manager.allocator, plan.script_url) catch .{ .failure = .network };
}

fn resources(a: std.mem.Allocator, script_url: []const u8) !sw.registry.FetchOutcome {
    var result: sw.registry.FetchOutcome = .{ .has_updated_resources = true, .checked_network = true };
    errdefer {
        for (result.resources.items) |*resource| resource.deinit(a);
        result.resources.deinit(a);
    }
    for ([_][]const u8{ script_url, "https://xw1.test/imported.js" }, [_][]const u8{ service_source, "globalThis.imported = 'stored-import';" }) |url, source| {
        const owned_url = try a.dupe(u8, url);
        errdefer a.free(owned_url);
        const body = try a.dupe(u8, source);
        errdefer a.free(body);
        const mime = try a.dupe(u8, "text/javascript");
        errdefer a.free(mime);
        try result.resources.append(a, .{ .url = owned_url, .body = body, .content_type = mime });
    }
    return result;
}

fn evaluate(browser: *Browser, source: []const u8) ![]u8 {
    return (browser.current_context orelse return error.NoContext).evaluateScriptToString(source, testing.allocator);
}

fn run(browser: *Browser, source: []const u8) !void {
    const result = try evaluate(browser, source);
    testing.allocator.free(result);
}

fn wait(browser: *Browser, want: []const u8) !void {
    for (0..1000) |_| {
        const result = try evaluate(browser, "globalThis.answer");
        defer testing.allocator.free(result);
        if (std.mem.eql(u8, result, want)) return;
        if (!std.mem.eql(u8, result, "pending")) {
            try testing.expectEqualStrings(want, result);
            return;
        }
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.WorkerNeverAnswered;
}

fn check() !void {
    const browser = try Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigateWithOptions("https://xw1.test/page.html", .window, .{ .skip_load = true });
    try browser.current_context.?.loadHTML("<!doctype html><body>", .{ .base_url = "https://xw1.test/page.html" });
    for ([_][]const u8{ "dedicated", "shared" }) |kind| {
        const source = try std.fmt.allocPrint(testing.allocator,
            \\globalThis.answer = 'pending';
            \\{{
            \\  const source = `const resolved = import.meta.resolve('https://xw1.test/value.js');
            \\    const run = p => import('data:text/javascript,export default 42').then(m => p.postMessage(resolved + '|' + m.default), e => p.postMessage(e.name));
            \\    if ('onconnect' in self) self.onconnect = e => run(e.ports[0]); else run(self);`;
            \\  const url = URL.createObjectURL(new Blob([source], {{type:'text/javascript'}}));
            \\  const shared = '{s}' === 'shared';
            \\  const worker = shared ? new SharedWorker(url, {{type:'module'}}) : new Worker(url, {{type:'module'}});
            \\  const port = shared ? worker.port : worker;
            \\  port.onmessage = e => {{ answer = e.data; URL.revokeObjectURL(url); if (shared) port.close(); else worker.terminate(); }};
            \\  worker.onerror = e => {{ answer = 'worker-error:' + e.message; }};
            \\}}
        , .{kind});
        defer testing.allocator.free(source);
        try run(browser, source);
        try wait(browser, "https://xw1.test/value.js|42");
    }
    const manager = sw.Manager.of(browser.getRealm().?) orelse return error.NoManager;
    manager.host = &host;
    try run(browser,
        \\globalThis.answer = 'pending';
        \\navigator.serviceWorker.onmessage = e => { answer = e.data; };
        \\navigator.serviceWorker.register('/sw.js').then(() => navigator.serviceWorker.ready)
        \\  .then(r => r.active.postMessage('check'), e => { answer = e.name; });
    );
    try wait(browser, "stored-import:TypeError");
}

test "xw1 aligned WorkerHost callbacks run in dedicated shared and service workers" {
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, struct {
        fn start(out: *anyerror!void) void {
            out.* = check();
        }
    }.start, .{&result});
    thread.join();
    try result;
}
