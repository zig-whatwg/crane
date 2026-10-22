const std = @import("std");
const Browser = @import("browser").Browser;
const engine = @import("engine");
const Server = @import("pv1_socket_server.zig").Server;

fn run(browser: *Browser, source: []const u8) !void {
    const held = try browser.evaluateScript(source);
    held.release();
}

fn waitFor(browser: *Browser, source: []const u8) !void {
    for (0..500) |_| {
        const held = try browser.evaluateScript(source);
        const yes = engine.toBoolean(browser.getRealm().?, held.borrow());
        held.release();
        if (yes) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.SocketTimedOut;
}

fn page(browser: *Browser) !void {
    const url = "http://127.0.0.1/pv1.html";
    try browser.navigateWithOptions(url, .window, .{ .skip_load = true });
    try browser.current_context.?.loadHTML("<!doctype html><body></body>", .{ .base_url = url });
}

const Shared = struct {
    opened: std.atomic.Value(u32) = .init(0),
    first_ended: std.atomic.Value(bool) = .init(false),
    failed: std.atomic.Value(bool) = .init(false),
};

const Side = struct {
    index: usize,
    shared: *Shared,
    failure: ?anyerror = null,
    // Per Browser, never std.testing.allocator: its shared lock masks races.
    debug: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init,

    fn entry(self: *Side) void {
        self.steps() catch |err| {
            self.failure = err;
            self.shared.failed.store(true, .release);
        };
        if (self.debug.deinit() == .leak) self.failure = error.Leaked;
    }

    fn steps(self: *Side) !void {
        var server: Server = undefined;
        try server.start();
        defer server.stop();
        const browser = try Browser.init(self.debug.allocator(), .{ .persist_storage = false, .snapshot_path = "" });
        var ended = false;
        defer if (!ended) browser.deinit();
        try page(browser);
        var url: [128]u8 = undefined;
        var script: [512]u8 = undefined;
        try run(browser, try std.fmt.bufPrint(&script, "globalThis.echoes=[]; globalThis.socket=new WebSocket('{s}'); socket.onmessage=e=>echoes.push(e.data);", .{try server.url(&url)}));
        try waitFor(browser, "socket.readyState===WebSocket.OPEN");
        _ = self.shared.opened.fetchAdd(1, .acq_rel);
        var turns: usize = 0;
        while (self.shared.opened.load(.acquire) != 2) : (turns += 1) {
            if (self.shared.failed.load(.acquire) or turns == 1000) return error.OtherBrowserFailed;
            _ = try browser.runEventLoopBlocking(10);
        }
        // Both sockets are OPEN. A's teardown must not cancel B's timer/transport.
        if (self.index == 0) {
            browser.deinit();
            ended = true;
            self.shared.first_ended.store(true, .release);
        } else {
            turns = 0;
            while (!self.shared.first_ended.load(.acquire)) : (turns += 1) {
                if (self.shared.failed.load(.acquire) or turns == 1000) return error.OtherBrowserFailed;
                _ = try browser.runEventLoopBlocking(10);
            }
            try run(browser, "socket.send('after-other-browser-ended')");
            try waitFor(browser, "echoes[0]==='after-other-browser-ended'");
            try run(browser, "socket.close(1000)");
            try waitFor(browser, "socket.readyState===WebSocket.CLOSED");
        }
        for (0..500) |_| {
            if (server.ended.load(.acquire)) break;
            std.Io.sleep(std.testing.io, .fromMilliseconds(10), .awake) catch {};
        }
        try std.testing.expectEqual(@as(u16, if (self.index == 0) 1001 else 1000), server.close_code.load(.acquire));
    }
};

test "two Browsers on two threads own open WebSockets independently through teardown" {
    var shared: Shared = .{};
    var sides = [_]Side{ .{ .index = 0, .shared = &shared }, .{ .index = 1, .shared = &shared } };
    const first = try std.Thread.spawn(.{}, Side.entry, .{&sides[0]});
    const second = std.Thread.spawn(.{}, Side.entry, .{&sides[1]}) catch |err| {
        shared.failed.store(true, .release);
        first.join();
        return err;
    };
    first.join();
    second.join();
    for (sides) |side| if (side.failure) |err| return err;
}

fn workerEnds() !void {
    var debug: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer std.testing.expect(debug.deinit() == .ok) catch @panic("worker Browser leaked");
    var server: Server = undefined;
    try server.start();
    defer server.stop();
    const browser = try Browser.init(debug.allocator(), .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try page(browser);
    var url: [128]u8 = undefined;
    var script: [1024]u8 = undefined;
    try run(browser, try std.fmt.bufPrint(&script,
        \\globalThis.workerOpened=false;
        \\globalThis.workerURL=URL.createObjectURL(new Blob([`
        \\  self.socket=new WebSocket('{s}');
        \\  socket.onopen=()=>{{postMessage('opened'); self.close()}};
        \\`], {{type:'text/javascript'}}));
        \\globalThis.worker=new Worker(workerURL);
        \\worker.onmessage=()=>workerOpened=true;
    , .{try server.url(&url)}));
    try waitFor(browser, "workerOpened");
    for (0..500) |_| {
        if (server.close_code.load(.acquire) != 0) break;
        _ = try browser.runEventLoopBlocking(10);
    }
    // Observe the peer while the Browser is still alive: worker end closed it.
    try std.testing.expectEqual(@as(u16, 1001), server.close_code.load(.acquire));
    try run(browser, "worker.terminate(); URL.revokeObjectURL(workerURL)");
}

test "a worker ending closes its open WebSocket before its Browser ends" {
    const Task = struct {
        fn entry(failure: *?anyerror) void {
            workerEnds() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Task.entry, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
