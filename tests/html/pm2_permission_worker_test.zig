const std = @import("std");
const Browser = @import("browser").Browser;
const permissions = @import("permissions");
const engine = @import("engine");

const page_url = "https://pm2.example.test/page.html";
const key = "https://pm2.example.test";

fn open(browser: *Browser) !void {
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    try browser.current_context.?.loadHTML("<!doctype html><body></body>", .{ .base_url = page_url });
}

fn run(browser: *Browser, source: []const u8) !void {
    const result = try browser.evaluateScript(source);
    result.release();
}

fn waitFor(browser: *Browser, expression: []const u8) !void {
    for (0..500) |_| {
        const result = try browser.evaluateScript(expression);
        const ready = engine.toBoolean(browser.getRealm().?, result.borrow());
        result.release();
        if (ready) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.PermissionWorkerTimedOut;
}

fn workerDelivery() !void {
    var gpa: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer std.testing.expect(gpa.deinit() == .ok) catch @panic("permission Browser leaked");
    const browser = try Browser.init(gpa.allocator(), .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try open(browser);
    const store = try browser.getRealm().?.browser_scope.?.of(permissions.BrowserStore);
    const initial = try store.set(key, permissions.PermissionDescriptor.simple(.geolocation), .granted);
    defer initial.release();
    try std.testing.expect(initial.isDone());
    try run(browser,
        \\globalThis.answers = [];
        \\globalThis.workerFailed = false;
        \\const script = new Blob([`
        \\  navigator.permissions.query({name: 'geolocation'}).then(p => {
        \\    self.permissionStatus = p;
        \\    postMessage(p.state);
        \\    p.onchange = () => postMessage(p.state);
        \\  });
        \\`], {type: 'text/javascript'});
        \\globalThis.workerURL = URL.createObjectURL(script);
        \\globalThis.permissionWorker = new Worker(workerURL);
        \\permissionWorker.onmessage = e => answers.push(e.data);
        \\permissionWorker.onerror = () => workerFailed = true;
    );
    try waitFor(browser, "answers[0] === 'granted'");
    const changed = try store.set(key, permissions.PermissionDescriptor.simple(.geolocation), .denied);
    defer changed.release();
    try waitFor(browser, "answers.join(',') === 'granted,denied'");
    // postMessage can reach the owner while the worker is still returning
    // from its change listener. Completion includes that return as well.
    for (0..500) |_| {
        if (changed.isDone()) break;
        _ = try browser.runEventLoopBlocking(10);
    }
    try std.testing.expect(changed.isDone());
    try run(browser, "permissionWorker.terminate(); URL.revokeObjectURL(workerURL)");
}

fn browserIsolation() !void {
    for (0..2) |index| {
        var gpa: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
        defer std.testing.expect(gpa.deinit() == .ok) catch @panic("permission Browser leaked");
        const browser = try Browser.init(gpa.allocator(), .{ .persist_storage = false, .snapshot_path = "" });
        defer browser.deinit();
        try open(browser);
        if (index == 0) {
            const store = try browser.getRealm().?.browser_scope.?.of(permissions.BrowserStore);
            const changed = try store.set(key, permissions.PermissionDescriptor.simple(.geolocation), .granted);
            changed.release();
        }
        try run(browser, "globalThis.answer = ''; navigator.permissions.query({name:'geolocation'}).then(p => answer = p.state)");
        try waitFor(browser, if (index == 0) "answer === 'granted'" else "answer === 'prompt'");
    }
}

fn onThread(comptime body: fn () anyerror!void) !void {
    const Thread = struct {
        fn call(failure: *?anyerror) void {
            body() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Thread.call, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

test "a dedicated worker inherits its permission key and receives later Browser changes" {
    try onThread(workerDelivery);
}

test "ending a Browser releases its permission overrides before the next Browser" {
    try onThread(browserIsolation);
}
