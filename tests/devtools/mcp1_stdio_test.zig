//! Lane mcp1, batch 3: the MCP stdio transport's thread handoff
//! (devtools.mcp.server.Stdio): a reader thread waits on the client's end and
//! a wake together, as the remote end reads --remote-debugging-pipe, and
//! hands each line to the serving thread through a queue.
//! - lines come in order, then the end of the input ends the serving loop
//!   and the reader is joined;
//! - a shutdown while the client keeps its end open and silent wakes the
//!   blocked read (platform.devtoolsWake on the reader's wake: its poll
//!   returns for the wake's descriptor) and the reader is joined;
//! - a line over Stdio.max_line is refused whole, the next one served;
//! - served whole: a tool call waits for the client's answer to the roots
//!   request sent before it - other lines meanwhile kept for after - or for
//!   the roots timeout; Browser.close (the devtools server's on_close, as
//!   the console wires it) ends the serving while the client keeps its end
//!   open, and the reader is joined.

const std = @import("std");
const testing = std.testing;
const platform = @import("platform");
const browser_mod = @import("browser");
const devtools = @import("devtools");
const Stdio = devtools.mcp.server.Stdio;

const LeakChecked = @import("root").poisoning.DebugAllocator(.{ .thread_safe = true });

/// Two pipes: the client writes `to_server[1]`, the server reads
/// `to_server[0]` and writes `to_client[1]`, which the client reads.
const Pipes = struct {
    to_server: [2]c_int,
    to_client: [2]c_int,

    fn open() !Pipes {
        var self: Pipes = undefined;
        if (std.c.pipe(&self.to_server) != 0) return error.PipeFailed;
        if (std.c.pipe(&self.to_client) != 0) return error.PipeFailed;
        return self;
    }

    fn serverEnd(self: Pipes) platform.DevtoolsPipe {
        return .{ .read = .{ .handle = self.to_server[0] }, .write = .{ .handle = self.to_client[1] } };
    }

    fn send(self: Pipes, text: []const u8) !void {
        var rest = text;
        while (rest.len > 0) {
            const n = std.c.write(self.to_server[1], rest.ptr, rest.len);
            if (n <= 0) return error.WriteFailed;
            rest = rest[@intCast(n)..];
        }
    }

    fn closeClient(self: *Pipes) void {
        if (self.to_server[1] >= 0) _ = std.c.close(self.to_server[1]);
        self.to_server[1] = -1;
    }

    fn close(self: *Pipes) void {
        self.closeClient();
        for ([_]c_int{ self.to_server[0], self.to_client[0], self.to_client[1] }) |fd| _ = std.c.close(fd);
    }

    /// The server's next line, waiting up to `ms`.
    fn receiveLine(self: Pipes, buffer: *std.ArrayList(u8), allocator: std.mem.Allocator, ms: u32) ![]const u8 {
        var waited: u32 = 0;
        while (true) {
            if (std.mem.indexOfScalar(u8, buffer.items, '\n')) |nl| {
                const line = try allocator.dupe(u8, buffer.items[0..nl]);
                const rest = buffer.items[nl + 1 ..];
                std.mem.copyForwards(u8, buffer.items[0..rest.len], rest);
                buffer.shrinkRetainingCapacity(rest.len);
                return line;
            }
            var fds = [_]std.c.pollfd{.{ .fd = self.to_client[0], .events = std.c.POLL.IN, .revents = 0 }};
            if (std.c.poll(&fds, 1, 50) > 0) {
                var chunk: [4096]u8 = undefined;
                const n = std.c.read(self.to_client[0], &chunk, chunk.len);
                if (n <= 0) return error.ServerClosed;
                try buffer.appendSlice(allocator, chunk[0..@intCast(n)]);
                continue;
            }
            waited += 50;
            if (waited >= ms) return error.Timeout;
        }
    }
};

test "stdio: lines come in order, the end of the input ends the loop, the reader is joined" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    var pipes = try Pipes.open();
    defer pipes.close();
    const stdio = try Stdio.start(allocator, pipes.serverEnd());
    defer stdio.deinit();
    try pipes.send("one\ntw");
    try pipes.send("o\n\nthree\n");
    pipes.closeClient();
    var got: std.ArrayList([]u8) = .empty;
    defer {
        for (got.items) |l| allocator.free(l);
        got.deinit(allocator);
    }
    while (stdio.next()) |line| try got.append(allocator, line);
    try testing.expectEqual(@as(usize, 4), got.items.len);
    try testing.expectEqualStrings("one\n", got.items[0]);
    try testing.expectEqualStrings("two\n", got.items[1]);
    try testing.expectEqualStrings("\n", got.items[2]);
    try testing.expectEqualStrings("three\n", got.items[3]);
}

test "stdio: a shutdown while the client keeps its end open wakes the blocked read; the reader is joined" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    var pipes = try Pipes.open();
    defer pipes.close();
    const stdio = try Stdio.start(allocator, pipes.serverEnd());
    // The reader is blocked: nothing has come and the client's end stays open.
    platform.sleepThread(50 * std.time.ns_per_ms);
    stdio.stop();
    try testing.expectEqual(@as(?[]u8, null), stdio.next());
    // Returns only once the reader has been joined.
    stdio.deinit();
}

test "stdio: a line over the limit is refused whole and the next one served" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    var pipes = try Pipes.open();
    defer pipes.close();
    const stdio = try Stdio.start(allocator, pipes.serverEnd());
    defer stdio.deinit();
    const Writer = struct {
        fn run(p: Pipes) void {
            const big = std.heap.page_allocator.alloc(u8, Stdio.max_line + 10) catch return;
            defer std.heap.page_allocator.free(big);
            @memset(big, 'x');
            p.send(big) catch return;
            p.send("\nok\n") catch return;
        }
    };
    // A pipe holds less than the line: the client writes while the server reads.
    const writer = try std.Thread.spawn(.{}, Writer.run, .{pipes});
    const first = stdio.next().?;
    defer allocator.free(first);
    try testing.expectEqualStrings(Stdio.too_long, first);
    const second = stdio.next().?;
    defer allocator.free(second);
    try testing.expectEqualStrings("ok\n", second);
    writer.join();
}

const Served = struct {
    allocator: std.mem.Allocator,
    server: *devtools.Server,
    stdio: *Stdio,
    roots_timeout_ms: i64,
    result: anyerror!void = {},

    fn run(self: *Served) void {
        self.result = devtools.mcp.server.serveStdio(self.allocator, self.server, self.stdio, .{ .roots_timeout_ms = self.roots_timeout_ms });
    }
};

fn startServing(allocator: std.mem.Allocator, pipes: Pipes, roots_timeout_ms: i64) !struct { host: *browser_mod.BrowserHost, server: *devtools.Server, stdio: *Stdio, served: *Served, thread: std.Thread } {
    const host = try browser_mod.BrowserHost.start(allocator, .{});
    errdefer host.stop();
    const stdio = try Stdio.start(allocator, pipes.serverEnd());
    errdefer stdio.deinit();
    // As the console wires it: Browser.close stops the transport.
    const server = try devtools.Server.start(allocator, .{ .default_host = host, .on_close = stdio.closeCallback() });
    errdefer server.stop();
    const served = try allocator.create(Served);
    served.* = .{ .allocator = allocator, .server = server, .stdio = stdio, .roots_timeout_ms = roots_timeout_ms };
    const thread = try std.Thread.spawn(.{}, Served.run, .{served});
    return .{ .host = host, .server = server, .stdio = stdio, .served = served, .thread = thread };
}

test "stdio served: a tool call waits for the client's roots answer; a request sent meanwhile is answered after it" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    var pipes = try Pipes.open();
    defer pipes.close();
    const s = try startServing(allocator, pipes, 5_000);
    var buffer: std.ArrayList(u8) = .empty;
    defer buffer.deinit(allocator);

    try pipes.send("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-11-25\",\"capabilities\":{\"roots\":{\"listChanged\":true}},\"clientInfo\":{\"name\":\"t\",\"version\":\"1\"}}}\n");
    const initialized = try pipes.receiveLine(&buffer, allocator, 5000);
    allocator.free(initialized);
    try pipes.send("{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\"}\n");
    const first_roots = try pipes.receiveLine(&buffer, allocator, 5000);
    defer allocator.free(first_roots);
    try testing.expectEqualStrings("{\"jsonrpc\":\"2.0\",\"id\":0,\"method\":\"roots/list\"}", first_roots);
    // A tool call, then a ping, before any answer.
    try pipes.send("{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"list_pages\",\"arguments\":{}}}\n{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"ping\"}\n");
    const wait_roots = try pipes.receiveLine(&buffer, allocator, 5000);
    defer allocator.free(wait_roots);
    try testing.expectEqualStrings("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"roots/list\"}", wait_roots);
    try pipes.send("{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"roots\":[{\"uri\":\"file:///tmp\",\"name\":\"tmp\"}]}}\n");
    const call = try pipes.receiveLine(&buffer, allocator, 10_000);
    defer allocator.free(call);
    try testing.expect(std.mem.startsWith(u8, call, "{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":"));
    const ping = try pipes.receiveLine(&buffer, allocator, 5000);
    defer allocator.free(ping);
    try testing.expectEqualStrings("{\"jsonrpc\":\"2.0\",\"id\":3,\"result\":{}}", ping);

    pipes.closeClient();
    s.thread.join();
    try s.served.result;
    allocator.destroy(s.served);
    s.server.stop();
    s.stdio.deinit();
    s.host.stop();
}

test "stdio served: a client that never answers its roots request delays the first tool call by the roots timeout only" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    var pipes = try Pipes.open();
    defer pipes.close();
    const s = try startServing(allocator, pipes, 200);
    var buffer: std.ArrayList(u8) = .empty;
    defer buffer.deinit(allocator);

    try pipes.send("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-11-25\",\"capabilities\":{\"roots\":{}},\"clientInfo\":{\"name\":\"t\",\"version\":\"1\"}}}\n{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\"}\n");
    for (0..2) |_| allocator.free(try pipes.receiveLine(&buffer, allocator, 5000));
    try pipes.send("{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"list_pages\",\"arguments\":{}}}\n");
    allocator.free(try pipes.receiveLine(&buffer, allocator, 5000));
    const call = try pipes.receiveLine(&buffer, allocator, 10_000);
    defer allocator.free(call);
    try testing.expect(std.mem.startsWith(u8, call, "{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":"));
    // A second call does not wait again.
    try pipes.send("{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"list_pages\",\"arguments\":{}}}\n");
    const again = try pipes.receiveLine(&buffer, allocator, 10_000);
    defer allocator.free(again);
    try testing.expect(std.mem.startsWith(u8, again, "{\"jsonrpc\":\"2.0\",\"id\":3,\"result\":"));

    // The Browser closes (Browser.close's requestClose) while the client
    // keeps its end open and silent: the server's on_close wakes the reader
    // blocked in its read, the serving loop ends, and the reader is joined.
    s.server.requestClose();
    s.thread.join();
    try s.served.result;
    allocator.destroy(s.served);
    s.server.stop();
    s.stdio.deinit();
    s.host.stop();
}
