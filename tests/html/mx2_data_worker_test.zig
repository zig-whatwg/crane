//! Data workers inherit their owner's mixed-content restriction, as the
//! browsers do. A real local proxy makes an allowed HTTP fetch succeed,
//! so a TypeError cannot pass merely because DNS or the network failed.
const std = @import("std");
const Browser = @import("browser").Browser;

/// A minimal HTTP proxy on an ephemeral loopback port. The requested host
/// remains mx2-resource.test, so mixed-content checks do not exempt it as
/// loopback. The counter distinguishes a blocked fetch from a network error.
const Proxy = struct {
    server: std.Io.net.Server,
    thread: ?std.Thread = null,
    stopping: std.atomic.Value(bool) = .init(false),
    received: std.atomic.Value(usize) = .init(0),

    fn start() !*Proxy {
        const self = try std.testing.allocator.create(Proxy);
        errdefer std.testing.allocator.destroy(self);
        const address: std.Io.net.IpAddress = .{ .ip4 = std.Io.net.Ip4Address.loopback(0) };
        var server = try address.listen(std.testing.io, .{ .reuse_address = true });
        errdefer server.deinit(std.testing.io);
        self.* = .{ .server = server };
        self.thread = try std.Thread.spawn(.{}, serve, .{ self, server });
        return self;
    }

    fn stop(self: *Proxy) void {
        self.stopping.store(true, .release);
        self.server.deinit(std.testing.io);
        self.thread.?.join();
        std.testing.allocator.destroy(self);
    }

    fn serve(self: *Proxy, listener: std.Io.net.Server) void {
        // stop() closes the shared socket, but accept reads a thread-local
        // copy of its descriptor and options while the close wakes it.
        var server = listener;
        while (!self.stopping.load(.acquire)) {
            const stream = server.accept(std.testing.io) catch continue;
            defer stream.close(std.testing.io);
            self.reply(stream) catch {};
        }
    }

    fn reply(self: *Proxy, stream: std.Io.net.Stream) !void {
        var input: [4096]u8 = undefined;
        var reader = stream.reader(std.testing.io, &input);
        try reader.interface.fillMore();
        if (reader.interface.buffered().len == 0) return;
        _ = self.received.fetchAdd(1, .release);
        var output: [0]u8 = .{};
        var writer = stream.writer(std.testing.io, &output);
        try writer.interface.writeAll("HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n");
        try writer.interface.flush();
    }
};

const launch_script =
    \\globalThis.answer = 'pending';
    \\globalThis.launch = (shared, type, nested) => {
    \\  const fetchSource = `
    \\    async function run(port) {
    \\      try { await fetch('http://mx2-resource.test/resource', {mode:'no-cors'}); port.postMessage('loaded'); }
    \\      catch (error) { port.postMessage(error.name); }
    \\      close();
    \\    }
    \\    self.onmessage = () => run(self);
    \\    self.onconnect = event => run(event.ports[0]);
    \\  `;
    \\  let source = fetchSource;
    \\  if (nested) {
    \\    const childURL = 'data:text/javascript,' + encodeURIComponent(fetchSource);
    \\    source = `
    \\      function run(port) {
    \\        const child = new Worker(${JSON.stringify(childURL)}, {type:${JSON.stringify(type)}});
    \\        child.onmessage = event => { port.postMessage(event.data); child.terminate(); close(); };
    \\        child.onerror = () => { port.postMessage('child-error'); close(); };
    \\        child.postMessage('start');
    \\      }
    \\      self.onmessage = () => run(self);
    \\      self.onconnect = event => run(event.ports[0]);
    \\    `;
    \\  }
    \\  const url = 'data:text/javascript,' + encodeURIComponent(source);
    \\  const worker = shared ? new SharedWorker(url, {type}) : new Worker(url, {type});
    \\  const port = shared ? worker.port : worker;
    \\  port.onmessage = event => { answer = event.data; if (shared) port.close(); else worker.terminate(); };
    \\  worker.onerror = () => { answer = 'worker-error'; };
    \\  if (shared) port.start(); else port.postMessage('start');
    \\  return 'started';
    \\};
    \\'ready'
;

fn check(shared: bool, worker_type: []const u8, nested: bool) !void {
    const allocator = std.testing.allocator;
    const server = try Proxy.start();
    defer server.stop();
    var proxy_buf: [128]u8 = undefined;
    const proxy = try std.fmt.bufPrint(&proxy_buf, "http://127.0.0.1:{d}", .{server.server.socket.address.getPort()});
    for ([_]bool{ false, true }) |secure_owner| {
        const before = server.received.load(.acquire);
        const browser = try Browser.init(allocator, .{
            .persist_storage = false,
            .snapshot_path = "",
            .proxy = .{ .manual = .{ .http = proxy, .no_proxy = "" } },
        });
        defer browser.deinit();
        try browser.navigate("about:blank", .window);
        const page = browser.current_context orelse return error.NoPage;
        try page.loadHTML("<!doctype html><body>", .{
            .base_url = if (secure_owner) "https://mx2-owner.test/" else "http://mx2-owner.test/",
        });
        const ready = try page.evaluateScriptToString(launch_script, allocator);
        defer allocator.free(ready);
        try std.testing.expectEqualStrings("ready", ready);
        const call = try std.fmt.allocPrint(allocator, "launch({s}, '{s}', {s})", .{
            if (shared) "true" else "false",
            worker_type,
            if (nested) "true" else "false",
        });
        defer allocator.free(call);
        const started = try page.evaluateScriptToString(call, allocator);
        defer allocator.free(started);
        try std.testing.expectEqualStrings("started", started);
        var answered = false;
        for (0..500) |_| {
            _ = try browser.runEventLoopBlocking(10);
            const answer = try page.evaluateScriptToString("answer", allocator);
            defer allocator.free(answer);
            if (std.mem.eql(u8, answer, "pending")) continue;
            try std.testing.expectEqualStrings(if (secure_owner) "TypeError" else "loaded", answer);
            answered = true;
            break;
        }
        try std.testing.expect(answered);
        try std.testing.expectEqual(before + @intFromBool(!secure_owner), server.received.load(.acquire));
    }
}

fn onThread(comptime shared: bool, comptime worker_type: []const u8, comptime nested: bool) !void {
    const Run = struct {
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            check(shared, worker_type, nested) catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.run, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

test "data worker restriction: dedicated classic, HTTP and HTTPS owners" {
    try onThread(false, "classic", false);
}

test "data worker restriction: dedicated module, HTTP and HTTPS owners" {
    try onThread(false, "module", false);
}

test "data worker restriction: shared classic, HTTP and HTTPS owners" {
    try onThread(true, "classic", false);
}

test "data worker restriction: shared module, HTTP and HTTPS owners" {
    try onThread(true, "module", false);
}

test "data worker restriction: a dedicated data worker inherits through a data worker" {
    try onThread(false, "classic", true);
    try onThread(false, "module", true);
}

test "data worker restriction: a dedicated data worker inherits through a shared data worker" {
    try onThread(true, "classic", true);
    try onThread(true, "module", true);
}
