//! A streaming fetch is still in flight when its Window or worker ends.
//! Dropping its last body reader reports timing during native teardown;
//! std.testing.allocator must see every timing entry released.
const std = @import("std");
const Browser = @import("browser").Browser;
const clock = @import("clock");
const testing = std.testing;

const Server = struct {
    socket: std.Io.net.Server,
    thread: ?std.Thread = null,
    stopping: std.atomic.Value(bool) = .init(false),

    fn start() !*Server {
        const self = try testing.allocator.create(Server);
        errdefer testing.allocator.destroy(self);
        const address: std.Io.net.IpAddress = .{ .ip4 = std.Io.net.Ip4Address.loopback(0) };
        var socket = try address.listen(testing.io, .{ .reuse_address = true });
        errdefer socket.deinit(testing.io);
        self.* = .{ .socket = socket };
        self.thread = try std.Thread.spawn(.{}, serve, .{ self, socket });
        return self;
    }

    fn stop(self: *Server) void {
        self.stopping.store(true, .release);
        self.socket.deinit(testing.io);
        self.thread.?.join();
        testing.allocator.destroy(self);
    }

    fn serve(self: *Server, listener: std.Io.net.Server) void {
        var socket = listener;
        const stream = socket.accept(testing.io) catch return;
        defer stream.close(testing.io);
        self.reply(stream) catch {};
    }

    fn reply(self: *Server, stream: std.Io.net.Stream) !void {
        var input: [8192]u8 = undefined;
        var reader = stream.reader(testing.io, &input);
        while (std.mem.indexOf(u8, reader.interface.buffered(), "\r\n\r\n") == null) try reader.interface.fillMore();
        var output: [0]u8 = .{};
        var writer = stream.writer(testing.io, &output);
        try writer.interface.writeAll("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 1048576\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n");
        const chunk = @as([32768]u8, @splat('x'));
        try writer.interface.writeAll(&chunk);
        try writer.interface.flush();
        // The advertised body never completes. Teardown must cancel it;
        // this server remains alive until the Browser has fully ended.
        while (!self.stopping.load(.acquire)) clock.sleep(std.time.ns_per_ms);
    }
};

const Kind = enum { window, dedicated, shared };

fn round(kind: Kind) !void {
    const server = try Server.start();
    defer server.stop();
    var base_buf: [128]u8 = undefined;
    const base = try std.fmt.bufPrint(&base_buf, "http://127.0.0.1:{d}/", .{server.socket.socket.address.getPort()});
    const browser = try Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigateWithOptions(base, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body>", .{ .base_url = base });
    const script = try std.fmt.allocPrint(testing.allocator,
        \\globalThis.ready = false; globalThis.failure = '';
        \\const url = '{s}body';
        \\async function receive(target) {{
        \\  try {{
        \\    const response = await fetch(url);
        \\    globalThis.reader = response.body.getReader();
        \\    const first = await reader.read();
        \\    if (first.done || !first.value.length) throw Error('no streaming bytes');
        \\    target('ready');
        \\  }} catch (e) {{ target('failure: ' + e); }}
        \\}}
        \\if ('{s}' === 'window') {{
        \\  receive(message => {{ if (message === 'ready') ready = true; else failure = message; }});
        \\}} else {{
        \\  const source = 'const url = ' + JSON.stringify(url) + ';' + receive.toString() +
        \\    ('{s}' === 'shared' ? 'onconnect = e => receive(message => e.ports[0].postMessage(message));' :
        \\                            'receive(message => postMessage(message));');
        \\  const scriptURL = URL.createObjectURL(new Blob([source], {{type:'text/javascript'}}));
        \\  globalThis.worker = '{s}' === 'shared' ? new SharedWorker(scriptURL) : new Worker(scriptURL);
        \\  const port = worker.port || worker;
        \\  port.onmessage = e => {{ if (e.data === 'ready') ready = true; else failure = e.data; }};
        \\  worker.onerror = () => {{ failure = 'worker error'; }};
        \\  if (port.start) port.start();
        \\}}
    , .{ base, @tagName(kind), @tagName(kind), @tagName(kind) });
    defer testing.allocator.free(script);
    try page.runScript(script);
    for (0..500) |_| {
        _ = try browser.runEventLoopBlocking(10);
        const state = try page.evaluateScriptToString("failure || String(ready)", testing.allocator);
        defer testing.allocator.free(state);
        if (std.mem.eql(u8, state, "false")) continue;
        try testing.expectEqualStrings("true", state);
        // Reader, response pipe and transfer are deliberately left alive.
        return;
    }
    return error.StreamDidNotStart;
}

fn exerciseOnFreshThread(kind: Kind) !void {
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, struct {
        fn run(selected: Kind, out: *anyerror!void) void {
            for (0..4) |_| round(selected) catch |err| {
                out.* = err;
                return;
            };
        }
    }.run, .{ kind, &result });
    thread.join();
    try result;
}

test "xw1 ending a Window with an unread fetch body releases resource timing entries" {
    try exerciseOnFreshThread(.window);
}

test "xw1 ending a dedicated worker with an unread fetch body releases resource timing entries" {
    try exerciseOnFreshThread(.dedicated);
}

test "xw1 ending a shared worker with an unread fetch body releases resource timing entries" {
    try exerciseOnFreshThread(.shared);
}
