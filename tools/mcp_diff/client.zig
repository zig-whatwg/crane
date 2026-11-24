//! An MCP server run as a child process and spoken to over stdio, as an MCP
//! client does (the stdio transport: newline-delimited JSON-RPC on the
//! child's stdin and stdout; its stderr to a log file): requests wait for
//! the answer with their id, up to a deadline; notifications and the
//! server's own requests in between are skipped. The child runs in a process
//! group of its own, ended with it - a browser it started goes too.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const Server = struct {
    gpa: Allocator,
    io: Io,
    child: std.process.Child,
    pid: i32,
    stdin: ?Io.File,
    buffer: Io.File.MultiReader.Buffer(1) = undefined,
    reader: Io.File.MultiReader = undefined,
    next_id: u64 = 1,
    ended: bool = false,

    /// Spawn `argv` with its stderr to `stderr_path`.
    pub fn start(gpa: Allocator, io: Io, argv: []const []const u8, stderr_path: []const u8) !*Server {
        const log = try Io.Dir.cwd().createFile(io, stderr_path, .{});
        defer log.close(io);
        const self = try gpa.create(Server);
        errdefer gpa.destroy(self);
        self.* = .{
            .gpa = gpa,
            .io = io,
            .child = try std.process.spawn(io, .{
                .argv = argv,
                .stdin = .pipe,
                .stdout = .pipe,
                .stderr = .{ .file = log },
                .pgid = 0,
            }),
            .pid = undefined,
            .stdin = null,
        };
        self.pid = self.child.id.?;
        self.stdin = self.child.stdin.?;
        self.child.stdin = null;
        self.reader.init(gpa, io, self.buffer.toStreams(), &.{self.child.stdout.?});
        return self;
    }

    /// End the child (its stdin closed, then its group terminated) and free.
    pub fn stop(self: *Server) void {
        if (self.stdin) |f| f.close(self.io);
        self.stdin = null;
        std.posix.kill(-self.pid, .TERM) catch {};
        std.posix.kill(self.pid, .TERM) catch {};
        self.reader.deinit();
        _ = self.child.wait(self.io) catch {};
        // Whatever of the group outlived the TERM.
        std.posix.kill(-self.pid, .KILL) catch {};
        self.gpa.destroy(self);
    }

    fn writeLine(self: *Server, text: []const u8) !void {
        const f = self.stdin orelse return error.Closed;
        try f.writeStreamingAll(self.io, text);
        try f.writeStreamingAll(self.io, "\n");
    }

    pub fn notify(self: *Server, arena: Allocator, method: []const u8, params_json: ?[]const u8) !void {
        const line = if (params_json) |p|
            try std.fmt.allocPrint(arena, "{{\"jsonrpc\":\"2.0\",\"method\":{f},\"params\":{s}}}", .{ std.json.fmt(method, .{}), p })
        else
            try std.fmt.allocPrint(arena, "{{\"jsonrpc\":\"2.0\",\"method\":{f}}}", .{std.json.fmt(method, .{})});
        try self.writeLine(line);
    }

    /// Send a request and wait (up to `timeout_ms`) for its answer: the whole
    /// message, parsed into `arena`.
    pub fn request(self: *Server, arena: Allocator, method: []const u8, params_json: []const u8, timeout_ms: u64) !std.json.Value {
        const id = self.next_id;
        self.next_id += 1;
        try self.writeLine(try std.fmt.allocPrint(arena, "{{\"jsonrpc\":\"2.0\",\"id\":{d},\"method\":{f},\"params\":{s}}}", .{ id, std.json.fmt(method, .{}), params_json }));
        const began = Io.Timestamp.now(self.io, .awake);
        while (true) {
            const r = self.reader.reader(0);
            if (std.mem.indexOfScalar(u8, r.buffered(), '\n')) |end| {
                const line = try arena.dupe(u8, r.buffered()[0..end]);
                r.toss(end + 1);
                const message = std.json.parseFromSliceLeaky(std.json.Value, arena, line, .{}) catch continue;
                if (message != .object) continue;
                const got = message.object.get("id") orelse continue;
                // The server's own requests (ping, roots) carry ids too: an
                // answer has a result or an error.
                if (message.object.get("method") != null) continue;
                if (got == .integer and got.integer == @as(i64, @intCast(id))) return message;
                continue;
            }
            const elapsed: u64 = @intCast(@max(0, began.durationTo(Io.Timestamp.now(self.io, .awake)).toMilliseconds()));
            if (elapsed >= timeout_ms) return error.Timeout;
            const left: i64 = @intCast(timeout_ms - elapsed);
            self.reader.fill(4096, .{ .duration = .{ .raw = .fromMilliseconds(left), .clock = .awake } }) catch |err| switch (err) {
                error.Timeout => return error.Timeout,
                else => return error.ServerEnded,
            };
        }
    }
};

/// One tools/call's answer, as compared.
pub const Answer = struct {
    /// The text items, joined by newlines; or the JSON-RPC error's message.
    text: []const u8,
    is_error: bool,
    /// Image items (a screenshot): counted, not compared.
    images: usize = 0,
};

/// A tools/call answer message, read as compared.
pub fn answerOf(arena: Allocator, message: std.json.Value) !Answer {
    if (message.object.get("error")) |e| {
        const text = if (e == .object) (if (e.object.get("message")) |m| (if (m == .string) m.string else "") else "") else "";
        return .{ .text = try std.fmt.allocPrint(arena, "JSON-RPC error: {s}", .{text}), .is_error = true };
    }
    const result = (message.object.get("result") orelse return .{ .text = "(no result)", .is_error = true }).object;
    var texts: std.ArrayList([]const u8) = .empty;
    var images: usize = 0;
    if (result.get("content")) |content| if (content == .array) for (content.array.items) |item| {
        if (item != .object) continue;
        const kind = item.object.get("type") orelse continue;
        if (kind != .string) continue;
        if (std.mem.eql(u8, kind.string, "text")) {
            if (item.object.get("text")) |t| if (t == .string) try texts.append(arena, t.string);
        } else if (std.mem.eql(u8, kind.string, "image")) images += 1;
    };
    const is_error = if (result.get("isError")) |e| (e == .bool and e.bool) else false;
    return .{ .text = try std.mem.join(arena, "\n", texts.items), .is_error = is_error, .images = images };
}

test "a tools/call answer: its text items joined, isError, images counted; a JSON-RPC error as its message" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const ok = try std.json.parseFromSliceLeaky(std.json.Value, arena,
        \\{"jsonrpc":"2.0","id":3,"result":{"content":[{"type":"text","text":"a"},{"type":"image","data":"x","mimeType":"image/png"},{"type":"text","text":"b"}],"isError":true}}
    , .{});
    const a = try answerOf(arena, ok);
    try std.testing.expectEqualStrings("a\nb", a.text);
    try std.testing.expect(a.is_error);
    try std.testing.expectEqual(@as(usize, 1), a.images);
    const failed = try std.json.parseFromSliceLeaky(std.json.Value, arena,
        \\{"jsonrpc":"2.0","id":3,"error":{"code":-32602,"message":"Unknown tool: x"}}
    , .{});
    try std.testing.expectEqualStrings("JSON-RPC error: Unknown tool: x", (try answerOf(arena, failed)).text);
}
