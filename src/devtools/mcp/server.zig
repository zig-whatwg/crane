//! One MCP server instance (design tmp/plans/mcp1-design.md 2.1-2.2): an
//! in-process CDP connection to Crane's devtools server, the MCP session over
//! it, and the protocol envelope. A transport feeds it messages - `serveStdio`
//! for `crane --mcp` (newline-delimited JSON-RPC on stdin and stdout,
//! https://modelcontextprotocol.io/specification/2025-11-25/basic/transports
//! "stdio": "Messages are delimited by newlines, and MUST NOT contain embedded
//! newlines"; nothing but MCP messages on stdout).

const std = @import("std");
const Allocator = std.mem.Allocator;
const DevtoolsServer = @import("../server.zig").Server;
const LocalLink = @import("../server.zig").LocalLink;
const DevtoolsCallback = @import("../server.zig").Callback;
const protocol = @import("protocol.zig");
const Session = @import("session.zig").Session;
const tools = @import("tools.zig");
const paths = @import("paths.zig");
const outbound = @import("../outbound.zig");
const platform = @import("platform");

const log = std.log.scoped(.mcp);

/// The serverInfo it names (Crane's, not chrome-devtools-mcp's).
pub const server_name = "crane";
pub const server_version = "0.1.0";

/// What a host configures (chrome-devtools-mcp's --filesystemRoot /
/// --workspace and --allow-unrestricted-paths).
pub const Options = struct {
    /// The directories tools may read and write; null: the OS temp
    /// directory (DEFAULT_FILESYSTEM_ROOT). Borrowed for the server's life.
    filesystem_roots: ?[]const []const u8 = null,
    /// No path check while the client has listed no roots (deprecated
    /// upstream in favour of --workspace=/).
    allow_unrestricted_paths: bool = false,
    /// How long the first tool call waits for the client's roots.
    roots_timeout_ms: i64 = protocol.roots_timeout_ms,
};

pub const McpServer = struct {
    allocator: Allocator,
    link: *LocalLink,
    session: *Session,
    tools_json: []u8,
    protocol: protocol.Protocol,
    roots_timeout_ms: i64 = protocol.roots_timeout_ms,

    pub fn create(allocator: Allocator, devtools: *DevtoolsServer) !*McpServer {
        return createWith(allocator, devtools, .{});
    }

    pub fn createWith(allocator: Allocator, devtools: *DevtoolsServer, options: Options) !*McpServer {
        const self = try allocator.create(McpServer);
        errdefer allocator.destroy(self);
        const link = try devtools.openLocal();
        errdefer link.close();
        const session = try Session.create(allocator, link);
        errdefer session.destroy();
        const tools_json = try tools.listJson(allocator);
        errdefer allocator.free(tools_json);
        // The input schemas each call is checked against.
        session.schemas = try std.json.parseFromSlice(std.json.Value, allocator, tools_json, .{});
        session.paths.configured = options.filesystem_roots;
        session.paths.allow_unrestricted = options.allow_unrestricted_paths;
        self.* = .{
            .allocator = allocator,
            .link = link,
            .session = session,
            .tools_json = tools_json,
            .protocol = .{
                .handler = .{ .context = session, .tools_json = tools_json, .call = tools.call, .disabled = tools.disabled },
                .info = .{ .name = server_name, .version = server_version },
                .roots = .{ .context = session, .set = setClientRoots },
            },
        };
        self.protocol.handler.tools_json = self.tools_json;
        self.roots_timeout_ms = options.roots_timeout_ms;
        return self;
    }

    pub fn destroy(self: *McpServer) void {
        self.session.destroy();
        self.link.close();
        self.allocator.free(self.tools_json);
        self.allocator.destroy(self);
    }

    /// Answer one message; the answer (null: none) lives in `arena`.
    pub fn handle(self: *McpServer, arena: Allocator, message: []const u8) !?[]u8 {
        return self.protocol.handle(arena, message);
    }

    /// The client's roots/list answer, for the path policy (#updateRoots).
    fn setClientRoots(context: *anyopaque, roots: []const protocol.RootEntry) void {
        const session: *Session = @ptrCast(@alignCast(context));
        var buffer: [64]paths.Root = undefined;
        const count = @min(roots.len, buffer.len);
        for (roots[0..count], 0..) |r, i| buffer[i] = .{ .uri = r.uri, .name = r.name };
        session.paths.setClientRoots(buffer[0..count]) catch |err| log.warn("mcp: the client's roots: {t}", .{err});
    }
};

/// MCP's stdio transport (newline-delimited JSON-RPC: "Messages are
/// delimited by newlines, and MUST NOT contain embedded newlines"), read the
/// way the remote end reads --remote-debugging-pipe: a thread of its own
/// waits on the client's end and a wake together (platform
/// devtoolsReadOrWake), so a shutdown wakes a read blocked on a client that
/// keeps its end open, and the reader is joined on every exit. The lines go
/// through a queue, so a tool call can wait - up to the roots timeout - for
/// the client's answer to the roots/list request sent before it, the other
/// lines that come meanwhile kept in order for after it (chrome-devtools-mcp
/// src/index.ts #getContext).
pub const Stdio = struct {
    allocator: Allocator,
    pipe: platform.DevtoolsPipe,
    wake: platform.DevtoolsWake,
    lines: *outbound.Outbound,
    thread: ?platform.Thread = null,
    inbox: Inbox,

    /// The longest line taken (the earlier reader's buffer): a longer one is
    /// refused whole ("Message too long").
    pub const max_line = 1 << 20;
    /// The client's end is read this much at a time (heap: no stack buffer).
    const read_chunk = 64 * 1024;

    /// Start reading `pipe.read` (the client's messages); answers go to
    /// `pipe.write`. Neither is closed by this.
    pub fn start(allocator: Allocator, pipe: platform.DevtoolsPipe) !*Stdio {
        const self = try allocator.create(Stdio);
        errdefer allocator.destroy(self);
        const wake = try platform.devtoolsWakeNew();
        errdefer platform.devtoolsWakeClose(wake);
        const lines = try outbound.Outbound.create(allocator);
        errdefer lines.release();
        self.* = .{ .allocator = allocator, .pipe = pipe, .wake = wake, .lines = lines, .inbox = .{ .allocator = allocator, .lines = lines } };
        self.thread = try platform.spawnThread(.{ .name = .from("mcp-stdin") }, readerMain, self);
        return self;
    }

    /// Stop reading, from any thread: a read blocked on the client's end
    /// returns (the wake), and no queued line is served any more.
    pub fn stop(self: *Stdio) void {
        platform.devtoolsWake(self.wake);
        self.lines.close();
    }

    /// The devtools server's `on_close` (Browser.close): `stop`, from the
    /// devtools thread - the serving loop ends, and `deinit` joins the reader.
    pub fn closeCallback(self: *Stdio) DevtoolsCallback {
        return .{ .context = self, .run = struct {
            fn run(context: ?*anyopaque) void {
                const stdio: *Stdio = @ptrCast(@alignCast(context.?));
                stdio.stop();
            }
        }.run };
    }

    /// Stop, join the reader, release everything.
    pub fn deinit(self: *Stdio) void {
        self.stop();
        if (self.thread) |t| platform.joinThread(t);
        self.inbox.deinit();
        self.lines.release();
        platform.devtoolsWakeClose(self.wake);
        self.allocator.destroy(self);
    }

    /// The next line to serve (OWNED by `allocator`), null once the input
    /// ended or `stop` was called.
    pub fn next(self: *Stdio) ?[]u8 {
        return self.inbox.next(null);
    }

    /// Write one message and its newline.
    pub fn write(self: *Stdio, message: []const u8) !void {
        try platform.devtoolsWrite(self.pipe.write, platform.Bytes.from(message));
        try platform.devtoolsWrite(self.pipe.write, platform.Bytes.from("\n"));
    }

    pub const too_long = "\x00too long";

    fn readerMain(context: ?*anyopaque) callconv(.c) void {
        const self: *Stdio = @ptrCast(@alignCast(context.?));
        // The end of the input: what is queued is still served.
        defer self.lines.finish();
        const buffer = self.allocator.alloc(u8, read_chunk) catch return;
        defer self.allocator.free(buffer);
        var partial: std.ArrayList(u8) = .empty;
        defer partial.deinit(self.allocator);
        var dropping = false;
        while (true) {
            // null: woken (stop); 0: the client closed its end.
            const n = (platform.devtoolsReadOrWake(self.pipe.read, buffer, self.wake) catch return) orelse return;
            if (n == 0) return;
            var rest = buffer[0..n];
            while (std.mem.indexOfScalar(u8, rest, '\n')) |nl| {
                if (dropping) {
                    // The end of a line already refused.
                    dropping = false;
                } else if (partial.items.len + nl > max_line) {
                    self.push(too_long) orelse return;
                } else {
                    partial.appendSlice(self.allocator, rest[0 .. nl + 1]) catch return;
                    self.push(partial.items) orelse return;
                }
                partial.clearRetainingCapacity();
                rest = rest[nl + 1 ..];
            }
            if (dropping) continue;
            if (partial.items.len + rest.len > max_line) {
                // Refused whole: the rest of it, up to its newline, dropped.
                self.push(too_long) orelse return;
                partial.clearRetainingCapacity();
                dropping = true;
                continue;
            }
            partial.appendSlice(self.allocator, rest) catch return;
        }
    }

    fn push(self: *Stdio, line: []const u8) ?void {
        const copy = self.allocator.dupe(u8, line) catch return null;
        self.lines.push(copy);
    }
};

/// Serve MCP over `stdio` until its input ends or it is stopped.
pub fn serveStdio(allocator: Allocator, devtools: *DevtoolsServer, stdio: *Stdio, options: Options) !void {
    const server = try McpServer.createWith(allocator, devtools, options);
    defer server.destroy();
    while (stdio.next()) |line| {
        defer allocator.free(line);
        try serveLine(allocator, server, stdio, line);
    }
}

/// Answer one line - a tool call first waiting for the client's roots when
/// it must.
fn serveLine(allocator: Allocator, server: *McpServer, stdio: *Stdio, line: []const u8) !void {
    const trimmed = std.mem.trim(u8, line, " \t\r\n");
    if (trimmed.len == 0) return;
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    if (std.mem.eql(u8, trimmed, Stdio.too_long)) {
        try stdio.write("{\"jsonrpc\":\"2.0\",\"id\":null,\"error\":{\"code\":-32600,\"message\":\"Message too long\"}}");
        return;
    }
    if (try server.protocol.rootsWaitRequest(arena, trimmed)) |request| {
        try stdio.write(request);
        try waitForRoots(allocator, server, stdio);
    }
    if (try server.handle(arena, trimmed)) |answer| try stdio.write(answer);
}

/// Read and handle the client's responses until the roots/list answer the
/// wait is for comes, or the time is up; any other line waits its turn.
fn waitForRoots(allocator: Allocator, server: *McpServer, stdio: *Stdio) !void {
    defer server.protocol.endRootsWait();
    const deadline = platform.monotonicMillis() + server.roots_timeout_ms;
    while (server.protocol.waitingForRoots()) {
        const now = platform.monotonicMillis();
        if (now >= deadline or stdio.inbox.ended) return;
        const line = stdio.inbox.take(@intCast((deadline - now) * std.time.ns_per_ms)) orelse continue;
        if (isResponse(allocator, line)) {
            defer allocator.free(line);
            var arena_state = std.heap.ArenaAllocator.init(allocator);
            defer arena_state.deinit();
            _ = try server.handle(arena_state.allocator(), std.mem.trim(u8, line, " \t\r\n"));
            continue;
        }
        try stdio.inbox.hold(line);
    }
}

/// A JSON-RPC response (an id and no method): what the client answers.
fn isResponse(allocator: Allocator, line: []const u8) bool {
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const parsed = std.json.parseFromSliceLeaky(std.json.Value, arena_state.allocator(), std.mem.trim(u8, line, " \t\r\n"), .{}) catch return false;
    if (parsed != .object) return false;
    return parsed.object.get("method") == null and parsed.object.get("id") != null;
}

/// The lines the reader queued, and those a roots wait set aside (served
/// first, in order). Lines are OWNED by the queue's allocator.
pub const Inbox = struct {
    allocator: Allocator,
    lines: *outbound.Outbound,
    held: std.ArrayList([]u8) = .empty,
    taken: std.ArrayList(outbound.Item) = .empty,
    ended: bool = false,

    fn deinit(self: *Inbox) void {
        for (self.held.items) |l| self.allocator.free(l);
        self.held.deinit(self.allocator);
        for (self.taken.items) |item| self.allocator.free(item.bytes);
        self.taken.deinit(self.allocator);
    }

    /// The next line to serve: one set aside first, else the queue's.
    fn next(self: *Inbox, timeout_ns: ?u64) ?[]u8 {
        if (self.held.items.len > 0) return self.held.orderedRemove(0);
        return self.take(timeout_ns);
    }

    /// The queue's next line, waiting up to `timeout_ns` (null: until one
    /// comes or the input ends); null on time-out or at the end.
    fn take(self: *Inbox, timeout_ns: ?u64) ?[]u8 {
        while (true) {
            if (self.taken.items.len > 0) return self.taken.orderedRemove(0).bytes;
            if (self.ended) return null;
            const state = self.lines.takeAll(&self.taken) catch return null;
            if (self.taken.items.len > 0) continue;
            if (state.closed or state.finishing) {
                self.ended = true;
                return null;
            }
            self.lines.wait(timeout_ns);
            if (timeout_ns != null) {
                const again = self.lines.takeAll(&self.taken) catch return null;
                if (self.taken.items.len > 0) continue;
                if (again.closed or again.finishing) self.ended = true;
                return null;
            }
        }
    }

    /// Set a line aside for after the wait.
    fn hold(self: *Inbox, line: []u8) !void {
        self.held.append(self.allocator, line) catch |err| {
            self.allocator.free(line);
            return err;
        };
    }
};
