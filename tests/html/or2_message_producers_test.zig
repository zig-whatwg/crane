//! Exercise the MessageEvent producers through script, with an owned local
//! server for the network producers. No shared WPT server is required.
const std = @import("std");
const Browser = @import("browser").Browser;
const h = @import("refcount_holders_helpers.zig");

// Construction and Window's queued-origin lifetime cases are part of the
// same producer check, including when this file is run in isolation.
test {
    _ = @import("or2_message_construction_test.zig");
    _ = @import("or2_message_origin_test.zig");
}

const Server = struct {
    listener: std.Io.net.Server,
    thread: ?std.Thread = null,
    stopping: std.atomic.Value(bool) = .init(false),

    fn start() !*Server {
        const self = try std.testing.allocator.create(Server);
        errdefer std.testing.allocator.destroy(self);
        const address: std.Io.net.IpAddress = .{ .ip4 = std.Io.net.Ip4Address.loopback(0) };
        var listener = try address.listen(std.testing.io, .{ .reuse_address = true });
        errdefer listener.deinit(std.testing.io);
        self.* = .{ .listener = listener };
        self.thread = try std.Thread.spawn(.{}, serve, .{ self, listener });
        return self;
    }

    fn stop(self: *Server) void {
        self.stopping.store(true, .release);
        self.listener.deinit(std.testing.io);
        self.thread.?.join();
        std.testing.allocator.destroy(self);
    }

    fn serve(self: *Server, listener: std.Io.net.Server) void {
        var server = listener;
        while (!self.stopping.load(.acquire)) {
            const stream = server.accept(std.testing.io) catch continue;
            defer stream.close(std.testing.io);
            reply(stream) catch {};
        }
    }

    fn reply(stream: std.Io.net.Stream) !void {
        var input: [4096]u8 = undefined;
        var reader = stream.reader(std.testing.io, &input);
        const first = try reader.interface.takeDelimiterInclusive('\n');
        const events = std.mem.startsWith(u8, first, "GET /events ");
        const worker = std.mem.startsWith(u8, first, "GET /sw.js ");
        const socket = std.mem.startsWith(u8, first, "GET /socket ");
        var key: [64]u8 = undefined;
        var key_len: usize = 0;
        while (true) {
            const line = try reader.interface.takeDelimiterInclusive('\n');
            if (std.mem.eql(u8, line, "\r\n")) break;
            const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
            if (std.ascii.eqlIgnoreCase(line[0..colon], "Sec-WebSocket-Key")) {
                const value = std.mem.trim(u8, line[colon + 1 ..], " \t\r\n");
                if (value.len > key.len) return error.InvalidKey;
                @memcpy(key[0..value.len], value);
                key_len = value.len;
            }
        }
        var output: [512]u8 = undefined;
        var writer = stream.writer(std.testing.io, &output);
        if (socket) {
            if (key_len == 0) return error.NoKey;
            var challenge: [128]u8 = undefined;
            const raw = try std.fmt.bufPrint(&challenge, "{s}258EAFA5-E914-47DA-95CA-C5AB0DC85B11", .{key[0..key_len]});
            var digest: [20]u8 = undefined;
            std.crypto.hash.Sha1.hash(raw, &digest, .{});
            var encoded: [28]u8 = undefined;
            const accept = std.base64.standard.Encoder.encode(&encoded, &digest);
            try writer.interface.print("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: {s}\r\n\r\n", .{accept});
            // An unmasked text frame followed by a normal-close frame.
            try writer.interface.writeAll("\x81\x0aws-message\x88\x02\x03\xe8");
        } else {
            const body = if (events)
                "id: event-1\ndata: sse-message\n\n"
            else if (worker)
                "self.oninstall = e => e.waitUntil(self.skipWaiting());\n" ++
                    "self.onactivate = e => e.waitUntil(clients.claim());\n" ++
                    "self.onmessage = e => e.source.postMessage('sw:' + e.data);\n"
            else
                "<!doctype html><body></body>";
            const mime = if (events) "text/event-stream" else if (worker) "text/javascript" else "text/html";
            try writer.interface.print("HTTP/1.1 200 OK\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nConnection: close\r\nCache-Control: no-store\r\n\r\n{s}", .{ mime, body.len, body });
        }
        try writer.interface.flush();
    }
};

const Producer = enum { worker, shared_worker, port, broadcast, event_source, web_socket, service_worker_client, window_transfer };

fn exercise(comptime producer: Producer) !void {
    const server = try Server.start();
    defer server.stop();
    var url_buffer: [128]u8 = undefined;
    const url = try std.fmt.bufPrint(&url_buffer, "http://127.0.0.1:{d}/page", .{server.listener.socket.address.getPort()});
    const browser = try Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigateWithOptions(url, .window, .{ .skip_load = true });
    const page = browser.current_context.?;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = url });
    try page.runScript(
        \\globalThis.answer = 'pending';
        \\globalThis.kept = null;
        \\globalThis.receive = (event, expected) => {
        \\  kept = event;
        \\  answer = event instanceof MessageEvent && event.isTrusted &&
        \\    event.data === expected && Array.isArray(event.ports) ? 'ok' : 'bad-event';
        \\};
    );
    try page.runScript(switch (producer) {
        .worker =>
        \\globalThis.worker = new Worker('data:text/javascript,' + encodeURIComponent(
        \\  'onmessage = e => postMessage(e instanceof MessageEvent ? "worker:" + e.data : "bad");'));
        \\worker.onmessage = e => { receive(e, 'worker:payload'); worker.terminate(); };
        \\worker.onerror = () => { answer = 'worker-error'; };
        \\worker.postMessage('payload');
        ,
        .shared_worker =>
        \\globalThis.worker = new SharedWorker('data:text/javascript,' + encodeURIComponent(
        \\  'onconnect = e => { const p=e.ports[0]; p.postMessage(e instanceof MessageEvent ? "shared" : "bad"); p.close(); close(); };'));
        \\worker.port.onmessage = e => { receive(e, 'shared'); worker.port.close(); };
        \\worker.onerror = () => { answer = 'shared-worker-error'; };
        \\worker.port.start();
        ,
        .port =>
        \\globalThis.channel = new MessageChannel();
        \\channel.port1.onmessage = e => { receive(e, 'port'); channel.port1.close(); channel.port2.close(); };
        \\channel.port2.postMessage('port');
        ,
        .broadcast =>
        \\globalThis.sender = new BroadcastChannel('or2-producer');
        \\globalThis.receiver = new BroadcastChannel('or2-producer');
        \\receiver.onmessage = e => { receive(e, 'broadcast'); sender.close(); receiver.close(); };
        \\sender.postMessage('broadcast');
        ,
        .event_source =>
        \\globalThis.source = new EventSource('/events');
        \\source.onmessage = e => { receive(e, 'sse-message'); if (e.lastEventId !== 'event-1') answer = 'bad-id'; source.close(); };
        \\source.onerror = () => { if (answer === 'pending') answer = 'eventsource-error'; source.close(); };
        ,
        .web_socket =>
        \\globalThis.socket = new WebSocket('ws://' + location.host + '/socket');
        \\socket.onmessage = e => { receive(e, 'ws-message'); socket.close(); };
        \\socket.onerror = () => { if (answer === 'pending') answer = 'websocket-error'; };
        ,
        .service_worker_client =>
        \\navigator.serviceWorker.onmessage = e => {
        \\  receive(e, 'sw:payload');
        \\  if (!(e.source instanceof ServiceWorker)) answer = 'bad-sw-source';
        \\  registration.unregister();
        \\};
        \\navigator.serviceWorker.register('/sw.js').then(r => {
        \\  globalThis.registration = r;
        \\  const w = r.installing || r.waiting || r.active;
        \\  if (w.state === 'activated') w.postMessage('payload');
        \\  else w.addEventListener('statechange', () => { if (w.state === 'activated') w.postMessage('payload'); });
        \\}).catch(e => { answer = 'service-worker:' + e.name; });
        ,
        .window_transfer =>
        \\globalThis.channel = new MessageChannel();
        \\addEventListener('message', e => {
        \\  receive(e, 'transfer');
        \\  if (e.ports.length !== 1) answer = 'missing-port';
        \\  e.ports[0].close(); channel.port1.close();
        \\}, {once:true});
        \\postMessage('transfer', '*', [channel.port2]);
        ,
    });
    for (0..250) |_| {
        _ = try browser.runEventLoopBlocking(20);
        const answer = try page.evaluateScriptToString("answer", std.testing.allocator);
        defer std.testing.allocator.free(answer);
        if (!std.mem.eql(u8, answer, "pending")) {
            try std.testing.expectEqualStrings("ok", answer);
            try page.runScript("kept = null; TestUtils.gc(); TestUtils.gc();");
            return;
        }
    }
    std.debug.print("MessageEvent producer timed out: {s}\n", .{@tagName(producer)});
    return error.NoMessage;
}

fn run(comptime producer: Producer) !void {
    try h.onFreshThread(struct {
        fn body() !void {
            try exercise(producer);
        }
    }.body);
}

test "MessageEvent producer: dedicated worker round trip" {
    try run(.worker);
}
test "MessageEvent producer: shared worker connection and port delivery" {
    try run(.shared_worker);
}
test "MessageEvent producer: MessagePort" {
    try run(.port);
}
test "MessageEvent producer: BroadcastChannel" {
    try run(.broadcast);
}
test "MessageEvent producer: EventSource" {
    try run(.event_source);
}
test "MessageEvent producer: WebSocket" {
    try run(.web_socket);
}
test "MessageEvent producer: service worker client" {
    try run(.service_worker_client);
}
test "MessageEvent producer: Window with transferred ports" {
    try run(.window_transfer);
}
