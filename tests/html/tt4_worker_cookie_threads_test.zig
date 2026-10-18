//! Q4's concurrency pin: two Browsers, each with its own leak-checking
//! allocator and jar, fetch dedicated/shared worker responses together.
//! Workers also fetch a cookie-setting response while their creator starts
//! the other worker. All jar accesses use Fetch's locking cookie APIs.
const std = @import("std");
const Browser = @import("browser").Browser;

const worker_source =
    "async function ready(port) { await fetch('/setter'); port.postMessage('ready'); close(); }" ++
    "if ('onconnect' in self) onconnect = e => ready(e.ports[0]); else ready(self);";

const Server = struct {
    allocator: std.mem.Allocator,
    socket: std.Io.net.Server,
    thread: ?std.Thread = null,
    stopping: std.atomic.Value(bool) = .init(false),
    id: u8,

    fn start(allocator: std.mem.Allocator, id: u8) !*Server {
        const self = try allocator.create(Server);
        errdefer allocator.destroy(self);
        const address: std.Io.net.IpAddress = .{ .ip4 = std.Io.net.Ip4Address.loopback(0) };
        var socket = try address.listen(std.testing.io, .{ .reuse_address = true });
        errdefer socket.deinit(std.testing.io);
        self.* = .{ .allocator = allocator, .socket = socket, .id = id };
        self.thread = try std.Thread.spawn(.{}, serve, .{ self, socket });
        return self;
    }

    fn stop(self: *Server) void {
        self.stopping.store(true, .release);
        self.socket.deinit(std.testing.io);
        self.thread.?.join();
        self.allocator.destroy(self);
    }

    fn serve(self: *Server, listener: std.Io.net.Server) void {
        var socket = listener;
        while (!self.stopping.load(.acquire)) {
            const stream = socket.accept(std.testing.io) catch continue;
            defer stream.close(std.testing.io);
            self.reply(stream) catch {};
        }
    }

    fn reply(self: *Server, stream: std.Io.net.Stream) !void {
        var input: [8192]u8 = undefined;
        var reader = stream.reader(std.testing.io, &input);
        while (std.mem.indexOf(u8, reader.interface.buffered(), "\r\n\r\n") == null) try reader.interface.fillMore();
        const head = reader.interface.buffered();
        const line_end = std.mem.indexOf(u8, head, "\r\n") orelse return;
        const setter = std.mem.indexOf(u8, head[0..line_end], "/setter") != null;
        var credential_script: [512]u8 = undefined;
        const body = if (std.mem.indexOf(u8, head[0..line_end], "/credentials.js") != null) blk: {
            var lines = std.mem.splitSequence(u8, head, "\r\n");
            var has_seed = false;
            while (lines.next()) |line| {
                const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
                if (std.ascii.eqlIgnoreCase(line[0..colon], "Cookie") and
                    std.mem.indexOf(u8, line[colon + 1 ..], "worker_seed=1") != null) has_seed = true;
            }
            break :blk try std.fmt.bufPrint(&credential_script, "function ready(p) {{ p.postMessage('{s}'); close(); }} " ++
                "if ('onconnect' in self) onconnect=e=>ready(e.ports[0]); else ready(self);", .{if (has_seed) "cookie" else "empty"});
        } else if (setter) "" else worker_source;
        var output: [0]u8 = .{};
        var writer = stream.writer(std.testing.io, &output);
        try writer.interface.print("HTTP/1.1 200 OK\r\nContent-Type: text/javascript\r\nSet-Cookie: {s}={c}; Path=/; SameSite=Strict\r\nContent-Length: {d}\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n{s}", .{
            if (setter) "worker_fetch" else "worker_response", self.id, body.len, body,
        });
        try writer.interface.flush();
    }
};

const Shared = struct {
    arrived: std.atomic.Value(u32) = .init(0),
    failed: std.atomic.Value(bool) = .init(false),
    errors: [2]?anyerror = .{ null, null },

    fn meet(self: *Shared, round: u32) !void {
        _ = self.arrived.fetchAdd(1, .acq_rel);
        var spins: usize = 0;
        while (self.arrived.load(.acquire) < round * 2) : (spins += 1) {
            if (self.failed.load(.acquire) or spins > 20_000_000) return error.OtherBrowserDidNotArrive;
            std.Thread.yield() catch {};
        }
    }

    fn side(self: *Shared, index: usize) void {
        var gpa: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
        defer if (gpa.deinit() == .leak) {
            self.errors[index] = error.MemoryLeak;
        };
        self.exercise(index, gpa.allocator()) catch |err| {
            self.errors[index] = err;
            self.failed.store(true, .release);
        };
    }

    fn exercise(self: *Shared, index: usize, allocator: std.mem.Allocator) !void {
        const id: u8 = if (index == 0) 'A' else 'B';
        const server = try Server.start(allocator, id);
        defer server.stop();
        var proxy_buf: [128]u8 = undefined;
        const proxy = try std.fmt.bufPrint(&proxy_buf, "http://127.0.0.1:{d}", .{server.socket.socket.address.getPort()});
        const browser = try Browser.init(allocator, .{
            .persist_storage = false,
            .snapshot_path = "",
            .proxy = .{ .manual = .{ .http = proxy, .no_proxy = "" } },
        });
        defer browser.deinit();
        const url = "http://tt4-worker.test/page.html";
        try browser.navigateWithOptions(url, .window, .{ .skip_load = true });
        const page = browser.current_context orelse return error.NoPage;
        try page.loadHTML("<!doctype html><body>", .{ .base_url = url });
        for (1..7) |round| {
            try self.meet(@intCast(round));
            const source = try std.fmt.allocPrint(allocator,
                \\globalThis.answers = 0; globalThis.workerError = '';
                \\globalThis.dedicated = new Worker('/worker.js?dedicated={d}');
                \\dedicated.onmessage = () => {{ answers++; dedicated.terminate(); }};
                \\dedicated.onerror = e => {{ workerError = e.message || 'dedicated'; }};
                \\globalThis.shared = new SharedWorker('/worker.js?shared={d}');
                \\shared.port.onmessage = () => {{ answers++; shared.port.close(); }};
                \\shared.onerror = () => {{ workerError = 'shared'; }};
                \\shared.port.start(); 'started'
            , .{ round, round });
            defer allocator.free(source);
            const started = try page.evaluateScriptToString(source, allocator);
            defer allocator.free(started);
            try std.testing.expectEqualStrings("started", started);
            var complete = false;
            for (0..500) |_| {
                _ = try browser.runEventLoopBlocking(10);
                const answer = try page.evaluateScriptToString("workerError || String(answers)", allocator);
                defer allocator.free(answer);
                if (std.mem.eql(u8, answer, "0") or std.mem.eql(u8, answer, "1")) continue;
                try std.testing.expectEqualStrings("2", answer);
                complete = true;
                break;
            }
            try std.testing.expect(complete);
            const actual = try page.evaluateScriptToString("document.cookie.split('; ').sort().join('; ')", allocator);
            defer allocator.free(actual);
            var expected_buf: [100]u8 = undefined;
            const expected = try std.fmt.bufPrint(&expected_buf, "worker_fetch={c}; worker_response={c}", .{ id, id });
            try std.testing.expectEqualStrings(expected, actual);
        }
    }
};

test "two Browsers' dedicated/shared worker responses keep concurrent cookies in their own jars" {
    var shared: Shared = .{};
    const a = try std.Thread.spawn(.{}, Shared.side, .{ &shared, @as(usize, 0) });
    const b = std.Thread.spawn(.{}, Shared.side, .{ &shared, @as(usize, 1) }) catch |err| {
        shared.failed.store(true, .release);
        a.join();
        return err;
    };
    a.join();
    b.join();
    for (shared.errors) |failure| if (failure) |err| return err;
}

fn rootCredentials() !void {
    const allocator = std.testing.allocator;
    const server = try Server.start(allocator, 'R');
    defer server.stop();
    var proxy_buf: [128]u8 = undefined;
    const proxy = try std.fmt.bufPrint(&proxy_buf, "http://127.0.0.1:{d}", .{server.socket.socket.address.getPort()});
    const browser = try Browser.init(allocator, .{
        .persist_storage = false,
        .snapshot_path = "",
        .proxy = .{ .manual = .{ .http = proxy, .no_proxy = "" } },
    });
    defer browser.deinit();
    const url = "http://tt4-worker.test/page.html";
    try browser.navigateWithOptions(url, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body>", .{ .base_url = url });
    for ([_]bool{ false, true }) |shared| {
        for ([_][]const u8{ "classic", "module" }) |worker_type| {
            for ([_][]const u8{ "omit", "same-origin", "include" }) |credentials| {
                const source = try std.fmt.allocPrint(allocator,
                    \\document.cookie = 'worker_seed=1; Path=/';
                    \\document.cookie = 'worker_response=; Max-Age=0; Path=/';
                    \\globalThis.credentialAnswer = 'pending';
                    \\{{
                    \\const worker = new {s}('/credentials.js?type={s}&credentials={s}', {{type:'{s}', credentials:'{s}'}});
                    \\const port = {s} ? worker.port : worker;
                    \\port.onmessage = e => {{ credentialAnswer = e.data; if ({s}) port.close(); else worker.terminate(); }};
                    \\worker.onerror = () => credentialAnswer = 'error';
                    \\if ({s}) port.start();
                    \\}} 'started'
                , .{
                    if (shared) "SharedWorker" else "Worker", worker_type,                     credentials,                     worker_type, credentials,
                    if (shared) "true" else "false",          if (shared) "true" else "false", if (shared) "true" else "false",
                });
                defer allocator.free(source);
                const started = try page.evaluateScriptToString(source, allocator);
                defer allocator.free(started);
                try std.testing.expectEqualStrings("started", started);
                // HTML classic step 1 ignores WorkerOptions.credentials;
                // "fetch a module worker script graph" passes it through.
                const include = std.mem.eql(u8, worker_type, "classic") or !std.mem.eql(u8, credentials, "omit");
                var complete = false;
                for (0..500) |_| {
                    _ = try browser.runEventLoopBlocking(10);
                    const answer = try page.evaluateScriptToString("credentialAnswer", allocator);
                    defer allocator.free(answer);
                    if (std.mem.eql(u8, answer, "pending")) continue;
                    try std.testing.expectEqualStrings(if (include) "cookie" else "empty", answer);
                    complete = true;
                    break;
                }
                try std.testing.expect(complete);
                const stored = try page.evaluateScriptToString("document.cookie.includes('worker_response=R')", allocator);
                defer allocator.free(stored);
                try std.testing.expectEqualStrings(if (include) "true" else "false", stored);
            }
        }
    }
}

test "worker root credentials: classic ignores the option, module honors omit for sending and storing" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            rootCredentials() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
