//! Streamable HTTP over TCP for Crane's built-in MCP server (lane mcp-http1;
//! design tmp/plans/mcp1-design.md 2.2 & 3; evidence 1.2-1.5).
//!
//! Serves both MCP eras on a single `/mcp` endpoint:
//! - Modern (`2026-07-28`): stateless POST-only, `MCP-Protocol-Version`
//!   validated against `_meta` (`400`/`-32020` on mismatch, `400`/`-32022`
//!   listing supported versions), `Mcp-Method`/`Mcp-Name` validation (including
//!   RFC `=?base64?...?=` decoding), `server/discover`, GET/DELETE -> `405`.
//! - Legacy (`2025-11-25` and earlier): `initialize` minting a cryptographically
//!   random `Mcp-Session-Id`, `GET /mcp` SSE stream with priming event, and
//!   `DELETE /mcp` session teardown (deleted sessions -> `404`).
//!
//! Security (section 3):
//! - Loopback (`127.0.0.1`) by default; non-loopback bind requires TLS (refused
//!   otherwise with `error.TlsRequired`, RFC 6750 5.3). Optional TLS on loopback
//!   too; ephemeral ECDSA P-256 self-signed cert with SHA-256 fingerprint or
//!   host-supplied PEM cert/key.
//! - Mandatory 256-bit cryptographically random pre-shared bearer token per
//!   start (`Authorization: Bearer <token>`, constant-time compare, never in
//!   query string, `401` when missing or wrong — required on loopback too).
//! - `Host` validation (IP literal or localhost, matching `devtools/http.zig`)
//!   and `Origin` validation (`403` when present and not allowed — DNS
//!   rebinding defense).
//! - Per-connection and per-token rate limiting (`429 Too Many Requests`).
//! - Wakeable poll loop; every worker thread finishes and joins cleanly on
//!   `stop()` with zero leaks.

const std = @import("std");
const Allocator = std.mem.Allocator;
const json = std.json;
const platform = @import("platform");
const devtools_http = @import("../http.zig");
const DevtoolsServer = @import("../server.zig").Server;
const DevtoolsCallback = @import("../server.zig").Callback;
const protocol = @import("protocol.zig");
const server_mod = @import("server.zig");
const McpServer = server_mod.McpServer;

const log = std.log.scoped(.mcp_http);

fn futexIo() std.Io {
    return std.Io.Threaded.global_single_threaded.io();
}

pub const TlsMode = enum {
    /// Plain HTTP on loopback; mandatory TLS on non-loopback.
    auto,
    /// Require TLS even on loopback.
    required,
    /// Refuse TLS (fails with `error.TlsRequired` on non-loopback).
    disabled,
};

pub const Options = struct {
    /// Bind host: empty, `"127.0.0.1"`, `"localhost"`, or `"::1"` for loopback;
    /// any other IPv4/IPv6 literal (`"0.0.0.0"`, `"::"`, LAN IP) for
    /// non-loopback.
    host: []const u8 = "127.0.0.1",
    /// 0: OS selects any free port.
    port: u16 = 0,
    /// TLS policy (non-loopback ALWAYS requires TLS).
    tls: TlsMode = .auto,
    /// Optional host-supplied PEM certificate (and chain); empty: ephemeral
    /// self-signed ECDSA P-256 certificate.
    cert_pem: []const u8 = "",
    /// Optional host-supplied PEM private key (required when `cert_pem` is set).
    key_pem: []const u8 = "",
    /// Origins allowed in the `Origin` header (`"*"` for any; empty refuses any
    /// request carrying an `Origin` header).
    allowed_origins: []const []const u8 = &.{},
    /// Max requests per TCP connection per window (0 = unlimited).
    max_requests_per_connection: u32 = 120,
    /// Max authenticated requests per bearer token per window (0 = unlimited).
    max_requests_per_token: u32 = 600,
    /// Rate limit window length in milliseconds.
    rate_limit_window_ms: u64 = 10_000,
    /// Max concurrent TCP connections accepted.
    max_connections: u32 = 32,
    /// Options passed through to `McpServer`.
    mcp: server_mod.Options = .{},
};

pub const max_body_bytes: usize = 4 * 1024 * 1024;
const read_chunk_size: usize = 16 * 1024;

/// Whether `host` names a loopback interface (`""`, `"localhost"`,
/// `"127.x.y.z"`, `"::1"`, `"[::1]"`).
pub fn isLoopbackHost(host: []const u8) bool {
    const trimmed = std.mem.trim(u8, host, " \t");
    if (trimmed.len == 0) return true;
    const no_dot = std.mem.trimEnd(u8, trimmed, ".");
    if (std.ascii.eqlIgnoreCase(no_dot, "localhost")) return true;
    if (std.mem.eql(u8, trimmed, "::1") or std.mem.eql(u8, trimmed, "[::1]")) return true;
    // IPv4 127.0.0.0/8 loopback block.
    var it = std.mem.splitScalar(u8, trimmed, '.');
    var idx: usize = 0;
    var first_octet: u8 = 0;
    while (it.next()) |part| {
        if (idx >= 4 or part.len == 0 or part.len > 3) return false;
        if (part.len > 1 and part[0] == '0') return false;
        const val = std.fmt.parseUnsigned(u8, part, 10) catch return false;
        if (idx == 0) first_octet = val;
        idx += 1;
    }
    return idx == 4 and first_octet == 127;
}

/// Format a 32-byte SHA-256 digest as uppercase colon-separated hex
/// (`"AA:BB:..."`, 95 bytes).
pub fn formatSha256Fingerprint(digest: [32]u8, out: *[95]u8) []const u8 {
    const hex = "0123456789ABCDEF";
    var pos: usize = 0;
    for (digest, 0..) |byte, i| {
        if (i != 0) {
            out[pos] = ':';
            pos += 1;
        }
        out[pos] = hex[byte >> 4];
        out[pos + 1] = hex[byte & 0x0F];
        pos += 2;
    }
    return out[0..pos];
}

fn encodeHexLower(bytes: []const u8, out: []u8) void {
    const hex = "0123456789abcdef";
    for (bytes, 0..) |b, i| {
        out[i * 2] = hex[b >> 4];
        out[i * 2 + 1] = hex[b & 0x0F];
    }
}

/// Constant-time check of `Authorization: Bearer <64-hex-token>`.
fn verifyBearerToken(expected: *const [64]u8, auth_header: ?[]const u8) bool {
    const raw = auth_header orelse return false;
    const trimmed = std.mem.trim(u8, raw, " \t");
    if (trimmed.len < 7) return false;
    if (!std.ascii.eqlIgnoreCase(trimmed[0..6], "bearer")) return false;
    if (trimmed[6] != ' ' and trimmed[6] != '\t') return false;
    const token = std.mem.trim(u8, trimmed[7..], " \t");
    if (token.len != expected.len) return false;
    var candidate: [64]u8 = undefined;
    @memcpy(&candidate, token);
    return std.crypto.timing_safe.eql([64]u8, expected.*, candidate);
}

/// Whether a URI target carries a bearer/access token in its query string
/// (forbidden by RFC 6750 / MCP auth spec).
fn queryHasToken(target: []const u8) bool {
    const q_start = std.mem.indexOfScalar(u8, target, '?') orelse return false;
    const query = target[q_start + 1 ..];
    var pairs = std.mem.tokenizeScalar(u8, query, '&');
    while (pairs.next()) |pair| {
        const eq = std.mem.indexOfScalar(u8, pair, '=') orelse pair.len;
        const key = pair[0..eq];
        if (std.ascii.eqlIgnoreCase(key, "token") or std.ascii.eqlIgnoreCase(key, "access_token")) return true;
    }
    return false;
}

/// Decode `=?base64?<data>?=` header values (MCP 2026-07-28 `Mcp-Name`), or
/// return `value` unchanged when not encoded.
fn decodeMcpHeaderValue(arena: Allocator, value: []const u8) Allocator.Error!?[]const u8 {
    const trimmed = std.mem.trim(u8, value, " \t");
    const prefix = "=?base64?";
    const suffix = "?=";
    if (trimmed.len >= prefix.len + suffix.len and
        std.ascii.eqlIgnoreCase(trimmed[0..prefix.len], prefix) and
        std.mem.endsWith(u8, trimmed, suffix))
    {
        const encoded = trimmed[prefix.len .. trimmed.len - suffix.len];
        const decoded_len = std.base64.standard.Decoder.calcSizeForSlice(encoded) catch return null;
        const out = try arena.alloc(u8, decoded_len);
        std.base64.standard.Decoder.decode(out, encoded) catch return null;
        return out;
    }
    return trimmed;
}

const RateWindow = struct {
    window_start_ns: u64 = 0,
    count: u32 = 0,

    fn allow(self: *RateWindow, limit: u32, window_ms: u64) bool {
        if (limit == 0) return true;
        const now = platform.monotonicNow().ns;
        const window_ns = window_ms * std.time.ns_per_ms;
        if (self.window_start_ns == 0 or now -| self.window_start_ns >= window_ns) {
            self.window_start_ns = now;
            self.count = 1;
            return true;
        }
        if (self.count >= limit) return false;
        self.count += 1;
        return true;
    }
};

/// One legacy (2025-11-25) HTTP session. Reference-counted under
/// `HttpServer.state_mutex` so a concurrent DELETE never frees a session while
/// a GET SSE worker holds it.
const HttpSession = struct {
    allocator: Allocator,
    id: [32]u8,
    proto: protocol.Protocol,
    sse_wake: platform.DevtoolsWake,
    sse_queue: std.ArrayList([]u8) = .empty,
    next_event_id: u64 = 2,
    deleted: bool = false,
    refs: u32 = 1,

    fn create(allocator: Allocator, mcp_server: *McpServer) !*HttpSession {
        const self = try allocator.create(HttpSession);
        errdefer allocator.destroy(self);
        const wake = try platform.devtoolsWakeNew();
        errdefer platform.devtoolsWakeClose(wake);
        var rand_bytes: [16]u8 = undefined;
        platform.fillRandom(&rand_bytes);
        var id: [32]u8 = undefined;
        encodeHexLower(&rand_bytes, &id);
        self.* = .{
            .allocator = allocator,
            .id = id,
            .proto = .{
                .handler = mcp_server.protocol.handler,
                .info = mcp_server.protocol.info,
                .roots = mcp_server.protocol.roots,
            },
            .sse_wake = wake,
        };
        return self;
    }

    fn destroy(self: *HttpSession) void {
        for (self.sse_queue.items) |msg| self.allocator.free(msg);
        self.sse_queue.deinit(self.allocator);
        platform.devtoolsWakeClose(self.sse_wake);
        self.allocator.destroy(self);
    }
};

const ActiveConn = struct {
    raw: platform.DevtoolsStream,
};

pub const HttpServer = struct {
    allocator: Allocator,
    options: Options,
    owned_origins: [][]u8,
    origin_slices: [][]const u8,
    listener: platform.DevtoolsListener,
    tls_server: ?*platform.DevtoolsTlsServer = null,
    fingerprint_buf: [95]u8 = undefined,
    has_fingerprint: bool = false,
    bearer_token: [64]u8 = undefined,
    wake: platform.DevtoolsWake,
    mcp_server: *McpServer,

    mcp_mutex: std.Io.Mutex = .init,
    state_mutex: std.Io.Mutex = .init,
    token_rate: RateWindow = .{},
    sessions: std.ArrayList(*HttpSession) = .empty,
    active_conns: std.ArrayList(ActiveConn) = .empty,

    acceptor: ?platform.Thread = null,
    stopping: std.atomic.Value(bool) = .init(false),
    closed: std.atomic.Value(u32) = .init(0),
    live_workers: std.atomic.Value(u32) = .init(0),

    pub fn start(allocator: Allocator, devtools: *DevtoolsServer, options: Options) !*HttpServer {
        const loopback = isLoopbackHost(options.host);
        if (!loopback and options.tls == .disabled) return error.TlsRequired;
        const use_tls = options.tls == .required or !loopback;
        if ((options.cert_pem.len != 0) != (options.key_pem.len != 0)) return error.InvalidTlsConfig;

        const self = try allocator.create(HttpServer);
        errdefer allocator.destroy(self);

        // Copy allowed origins so Options does not need to outlive start().
        const owned_origins = try allocator.alloc([]u8, options.allowed_origins.len);
        errdefer allocator.free(owned_origins);
        const origin_slices = try allocator.alloc([]const u8, options.allowed_origins.len);
        errdefer allocator.free(origin_slices);
        var copied: usize = 0;
        errdefer for (owned_origins[0..copied]) |o| allocator.free(o);
        for (options.allowed_origins, 0..) |o, i| {
            owned_origins[i] = try allocator.dupe(u8, o);
            origin_slices[i] = owned_origins[i];
            copied += 1;
        }

        // 256-bit cryptographically random pre-shared bearer token.
        var token_bytes: [32]u8 = undefined;
        platform.fillRandom(&token_bytes);
        var token_hex: [64]u8 = undefined;
        encodeHexLower(&token_bytes, &token_hex);

        var tls_handle: ?*platform.DevtoolsTlsServer = null;
        var fp_buf: [95]u8 = undefined;
        var has_fp = false;
        if (use_tls) {
            const tls_info = try platform.devtoolsTlsServerNew(allocator, &.{
                .cert_pem = platform.Bytes.from(options.cert_pem),
                .key_pem = platform.Bytes.from(options.key_pem),
                .common_name = platform.Str.from(options.host),
            });
            tls_handle = tls_info.handle;
            _ = formatSha256Fingerprint(tls_info.cert_sha256, &fp_buf);
            has_fp = true;
        }
        errdefer if (tls_handle) |h| platform.devtoolsTlsServerClose(h);

        const listener = try platform.devtoolsListenAddress(platform.Str.from(options.host), options.port);
        errdefer platform.devtoolsCloseListener(listener);

        const wake = try platform.devtoolsWakeNew();
        errdefer platform.devtoolsWakeClose(wake);

        const mcp_server = try McpServer.createWith(allocator, devtools, options.mcp);
        errdefer mcp_server.destroy();

        var stored_options = options;
        stored_options.allowed_origins = origin_slices;

        self.* = .{
            .allocator = allocator,
            .options = stored_options,
            .owned_origins = owned_origins,
            .origin_slices = origin_slices,
            .listener = listener,
            .tls_server = tls_handle,
            .fingerprint_buf = fp_buf,
            .has_fingerprint = has_fp,
            .bearer_token = token_hex,
            .wake = wake,
            .mcp_server = mcp_server,
        };

        self.acceptor = try platform.spawnThread(.{ .name = .from("mcp-http") }, acceptorMain, self);
        return self;
    }

    pub fn boundPort(self: *const HttpServer) u16 {
        return self.listener.port;
    }

    pub fn isTls(self: *const HttpServer) bool {
        return self.tls_server != null;
    }

    pub fn bearerToken(self: *const HttpServer) []const u8 {
        return &self.bearer_token;
    }

    pub fn certFingerprint(self: *const HttpServer) ?[]const u8 {
        if (!self.has_fingerprint) return null;
        return &self.fingerprint_buf;
    }

    pub fn wakeHandle(self: *const HttpServer) platform.DevtoolsWake {
        return self.wake;
    }

    /// Signal the server to stop (callable from any thread, including
    /// `devtools.Server.on_close`).
    pub fn requestStop(self: *HttpServer) void {
        self.stopping.store(true, .release);
        platform.devtoolsWake(self.wake);
        self.closed.store(1, .release);
        futexIo().futexWake(u32, &self.closed.raw, std.math.maxInt(u32));
    }

    pub fn closeCallback(self: *HttpServer) DevtoolsCallback {
        return .{ .context = self, .run = struct {
            fn run(ctx: ?*anyopaque) void {
                const srv: *HttpServer = @ptrCast(@alignCast(ctx.?));
                srv.requestStop();
            }
        }.run };
    }

    pub fn waitUntilClosed(self: *HttpServer) void {
        while (self.closed.load(.acquire) == 0) {
            futexIo().futexWaitTimeout(u32, &self.closed.raw, 0, .none) catch {};
        }
    }

    /// Stop accepting, wake and close all active connections & SSE streams,
    /// join every worker thread, and release all resources.
    pub fn stop(self: *HttpServer) void {
        self.requestStop();
        if (self.acceptor) |t| {
            platform.joinThread(t);
            self.acceptor = null;
        }
        // Wake every active session SSE stream and shut down every open socket.
        std.Io.Threaded.mutexLockUncancelable(&self.state_mutex);
        for (self.sessions.items) |s| {
            s.deleted = true;
            platform.devtoolsWake(s.sse_wake);
        }
        for (self.active_conns.items) |conn| {
            platform.devtoolsShutdown(conn.raw);
        }
        std.Io.Threaded.mutexUnlock(&self.state_mutex);

        while (true) {
            const live = self.live_workers.load(.acquire);
            if (live == 0) break;
            futexIo().futexWaitTimeout(u32, &self.live_workers.raw, live, .{ .duration = .{ .raw = .fromMilliseconds(50), .clock = .awake } }) catch {};
        }

        for (self.sessions.items) |s| s.destroy();
        self.sessions.deinit(self.allocator);
        self.active_conns.deinit(self.allocator);
        self.mcp_server.destroy();
        if (self.tls_server) |h| platform.devtoolsTlsServerClose(h);
        platform.devtoolsCloseListener(self.listener);
        platform.devtoolsWakeClose(self.wake);
        for (self.owned_origins) |o| self.allocator.free(o);
        self.allocator.free(self.owned_origins);
        self.allocator.free(self.origin_slices);
        self.allocator.destroy(self);
    }

    fn acceptorMain(ctx: ?*anyopaque) callconv(.c) void {
        const self: *HttpServer = @ptrCast(@alignCast(ctx.?));
        while (!self.stopping.load(.acquire)) {
            const stream = (platform.devtoolsAccept(self.listener, self.wake) catch |err| {
                if (self.stopping.load(.acquire)) break;
                log.warn("mcp-http: accept error: {t}", .{err});
                platform.sleepThread(50 * std.time.ns_per_ms);
                continue;
            }) orelse break;

            if (self.stopping.load(.acquire)) {
                platform.devtoolsClose(stream);
                break;
            }
            if (self.live_workers.load(.acquire) >= self.options.max_connections) {
                platform.devtoolsClose(stream);
                continue;
            }

            const worker = self.allocator.create(WorkerArg) catch {
                platform.devtoolsClose(stream);
                continue;
            };
            worker.* = .{ .server = self, .raw = stream };
            _ = self.live_workers.fetchAdd(1, .acq_rel);
            const thread = platform.spawnThread(.{ .name = .from("mcp-http-conn") }, workerMain, worker) catch {
                _ = self.live_workers.fetchSub(1, .acq_rel);
                futexIo().futexWake(u32, &self.live_workers.raw, std.math.maxInt(u32));
                self.allocator.destroy(worker);
                platform.devtoolsClose(stream);
                continue;
            };
            platform.detachThread(thread);
        }
    }

    const WorkerArg = struct {
        server: *HttpServer,
        raw: platform.DevtoolsStream,
    };

    fn workerMain(ctx: ?*anyopaque) callconv(.c) void {
        const arg: *WorkerArg = @ptrCast(@alignCast(ctx.?));
        const self = arg.server;
        const raw = arg.raw;
        self.allocator.destroy(arg);
        defer {
            if (self.live_workers.fetchSub(1, .acq_rel) == 1) {
                futexIo().futexWake(u32, &self.live_workers.raw, std.math.maxInt(u32));
            }
        }

        // Register raw socket so stop() can shut it down cleanly.
        std.Io.Threaded.mutexLockUncancelable(&self.state_mutex);
        self.active_conns.append(self.allocator, .{ .raw = raw }) catch {};
        std.Io.Threaded.mutexUnlock(&self.state_mutex);
        defer {
            std.Io.Threaded.mutexLockUncancelable(&self.state_mutex);
            for (self.active_conns.items, 0..) |c, i| {
                if (c.raw.handle == raw.handle) {
                    _ = self.active_conns.swapRemove(i);
                    break;
                }
            }
            std.Io.Threaded.mutexUnlock(&self.state_mutex);
            platform.devtoolsClose(raw);
        }

        var tls_stream: ?*platform.DevtoolsTlsStream = null;
        if (self.tls_server) |tls| {
            tls_stream = (platform.devtoolsTlsAccept(self.allocator, tls, raw, self.wake) catch return) orelse return;
        }
        defer if (tls_stream) |ts| platform.devtoolsTlsClose(ts);

        var conn: ConnIo = .{ .raw = raw, .tls = tls_stream, .wake = self.wake };
        self.serveConnection(&conn);
    }

    const ConnIo = struct {
        raw: platform.DevtoolsStream,
        tls: ?*platform.DevtoolsTlsStream,
        wake: platform.DevtoolsWake,

        fn read(self: *ConnIo, buf: []u8, wake: platform.DevtoolsWake) !?usize {
            if (self.tls) |ts| return platform.devtoolsTlsRead(ts, buf, wake);
            return platform.devtoolsReadOrWake(self.raw, buf, wake);
        }

        fn writeAll(self: *ConnIo, data: []const u8) !void {
            if (self.tls) |ts| return platform.devtoolsTlsWrite(ts, platform.Bytes.from(data));
            return platform.devtoolsWrite(self.raw, platform.Bytes.from(data));
        }
    };

    fn serveConnection(self: *HttpServer, conn: *ConnIo) void {
        var buffer: std.ArrayList(u8) = .empty;
        defer buffer.deinit(self.allocator);
        const chunk = self.allocator.alloc(u8, read_chunk_size) catch return;
        defer self.allocator.free(chunk);
        var conn_rate: RateWindow = .{};

        while (!self.stopping.load(.acquire)) {
            var arena_state = std.heap.ArenaAllocator.init(self.allocator);
            defer arena_state.deinit();
            const arena = arena_state.allocator();

            // 1. Read HTTP request head.
            const req: devtools_http.Request = blk: {
                while (true) {
                    const parsed = devtools_http.parseRequest(arena, buffer.items) catch return;
                    switch (parsed) {
                        .request => |r| break :blk r,
                        .bad => {
                            writeJsonResponse(conn, arena, 400, null, "{\"jsonrpc\":\"2.0\",\"id\":null,\"error\":{\"code\":-32600,\"message\":\"Bad HTTP request\"}}", true) catch {};
                            return;
                        },
                        .incomplete => {
                            const n = (conn.read(chunk, self.wake) catch return) orelse return;
                            if (n == 0) return;
                            buffer.appendSlice(self.allocator, chunk[0..n]) catch return;
                        },
                    }
                }
            };

            const close_after = req.headerHasToken("connection", "close");

            // 2. Read request body (Content-Length or Transfer-Encoding: chunked).
            const body_result = readBody(self.allocator, arena, conn, &buffer, chunk, &req) catch |err| {
                const status: u16 = if (err == error.BodyTooLarge) 413 else 400;
                writeJsonResponse(conn, arena, status, null, "{\"jsonrpc\":\"2.0\",\"id\":null,\"error\":{\"code\":-32600,\"message\":\"Invalid or oversized request body\"}}", true) catch {};
                return;
            };
            const body = body_result.body;
            const consumed = body_result.consumed;

            // 3. Handle request (may take over connection for GET SSE stream).
            const outcome = self.handleHttpRequest(arena, conn, &req, body, &conn_rate, close_after);

            // Consume this request's bytes from the pipelined buffer.
            if (consumed < buffer.items.len) {
                const rem = buffer.items.len - consumed;
                std.mem.copyForwards(u8, buffer.items[0..rem], buffer.items[consumed..]);
                buffer.shrinkRetainingCapacity(rem);
            } else {
                buffer.clearRetainingCapacity();
            }

            if (outcome == .close or close_after) return;
        }
    }

    const BodyResult = struct {
        body: []const u8,
        consumed: usize,
    };

    fn readBody(
        allocator: Allocator,
        arena: Allocator,
        conn: *ConnIo,
        buffer: *std.ArrayList(u8),
        chunk: []u8,
        req: *const devtools_http.Request,
    ) !BodyResult {
        if (req.headerHasToken("transfer-encoding", "chunked")) {
            var decoded: std.ArrayList(u8) = .empty;
            var pos = req.head_len;
            while (true) {
                while (std.mem.indexOf(u8, buffer.items[pos..], "\r\n") == null) {
                    const n = (try conn.read(chunk, conn.wake)) orelse return error.ConnectionClosed;
                    if (n == 0) return error.ConnectionClosed;
                    try buffer.appendSlice(allocator, chunk[0..n]);
                    if (buffer.items.len > max_body_bytes + devtools_http.max_head_bytes) return error.BodyTooLarge;
                }
                const line_rel = std.mem.indexOf(u8, buffer.items[pos..], "\r\n").?;
                const size_line = buffer.items[pos .. pos + line_rel];
                const semi = std.mem.indexOfScalar(u8, size_line, ';') orelse size_line.len;
                const chunk_len = std.fmt.parseUnsigned(usize, std.mem.trim(u8, size_line[0..semi], " \t"), 16) catch return error.BadChunk;
                pos += line_rel + 2;
                if (chunk_len == 0) {
                    // Consume trailing CRLF after 0-length chunk.
                    while (buffer.items.len < pos + 2) {
                        const n = (try conn.read(chunk, conn.wake)) orelse return error.ConnectionClosed;
                        if (n == 0) return error.ConnectionClosed;
                        try buffer.appendSlice(allocator, chunk[0..n]);
                    }
                    pos += 2;
                    break;
                }
                if (decoded.items.len + chunk_len > max_body_bytes) return error.BodyTooLarge;
                while (buffer.items.len < pos + chunk_len + 2) {
                    const n = (try conn.read(chunk, conn.wake)) orelse return error.ConnectionClosed;
                    if (n == 0) return error.ConnectionClosed;
                    try buffer.appendSlice(allocator, chunk[0..n]);
                }
                try decoded.appendSlice(arena, buffer.items[pos .. pos + chunk_len]);
                pos += chunk_len + 2;
            }
            return .{ .body = decoded.items, .consumed = pos };
        }

        const cl_header = req.header("content-length") orelse return .{ .body = "", .consumed = req.head_len };
        const cl = std.fmt.parseUnsigned(usize, std.mem.trim(u8, cl_header, " \t"), 10) catch return error.BadContentLength;
        if (cl > max_body_bytes) return error.BodyTooLarge;
        const needed = req.head_len + cl;
        while (buffer.items.len < needed) {
            const n = (try conn.read(chunk, conn.wake)) orelse return error.ConnectionClosed;
            if (n == 0) return error.ConnectionClosed;
            try buffer.appendSlice(allocator, chunk[0..n]);
        }
        // Copy body into arena before returning so buffer compaction cannot alias it.
        const body_copy = try arena.dupe(u8, buffer.items[req.head_len..needed]);
        return .{ .body = body_copy, .consumed = needed };
    }

    const ConnOutcome = enum { keep_alive, close };

    fn handleHttpRequest(
        self: *HttpServer,
        arena: Allocator,
        conn: *ConnIo,
        req: *const devtools_http.Request,
        body: []const u8,
        conn_rate: *RateWindow,
        close_after: bool,
    ) ConnOutcome {
        // Security 1: Host validation (DNS rebinding defense, matching devtools/http.zig).
        if (!devtools_http.hostIsSafe(req.header("host"))) {
            writeJsonResponse(conn, arena, 403, null, "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32600,\"message\":\"" ++ devtools_http.host_refused_message ++ "\"}}", true) catch {};
            return .close;
        }

        // Security 2: Origin validation (403 when present and not allowed).
        if (!devtools_http.originAllowed(req.header("origin"), self.options.allowed_origins)) {
            writeJsonResponse(conn, arena, 403, null, "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32600,\"message\":\"Origin not allowed\"}}", true) catch {};
            return .close;
        }

        // Security 3: Never accept bearer tokens in URI query string.
        if (queryHasToken(req.target)) {
            writeJsonResponse(conn, arena, 400, null, "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32600,\"message\":\"Access tokens must not be included in the URI query string\"}}", true) catch {};
            return .close;
        }

        // Security 4: Mandatory 256-bit pre-shared bearer token (loopback included).
        if (!verifyBearerToken(&self.bearer_token, req.header("authorization"))) {
            writeResponse(conn, arena, 401, "Unauthorized", "application/json", "WWW-Authenticate: Bearer\r\n", "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32600,\"message\":\"Unauthorized\"}}", true) catch {};
            return .close;
        }

        // Endpoint check: single `/mcp` endpoint.
        if (!std.mem.eql(u8, req.path(), "/mcp")) {
            writeJsonResponse(conn, arena, 404, null, "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32601,\"message\":\"Not found\"}}", close_after) catch return .close;
            return if (close_after) .close else .keep_alive;
        }

        // Security 5: Per-connection and per-token rate limiting (429).
        if (!conn_rate.allow(self.options.max_requests_per_connection, self.options.rate_limit_window_ms)) {
            writeResponse(conn, arena, 429, "Too Many Requests", "application/json", "Retry-After: 1\r\n", "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32000,\"message\":\"Rate limit exceeded\"}}", close_after) catch return .close;
            return if (close_after) .close else .keep_alive;
        }
        std.Io.Threaded.mutexLockUncancelable(&self.state_mutex);
        const token_ok = self.token_rate.allow(self.options.max_requests_per_token, self.options.rate_limit_window_ms);
        std.Io.Threaded.mutexUnlock(&self.state_mutex);
        if (!token_ok) {
            writeResponse(conn, arena, 429, "Too Many Requests", "application/json", "Retry-After: 1\r\n", "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32000,\"message\":\"Rate limit exceeded\"}}", close_after) catch return .close;
            return if (close_after) .close else .keep_alive;
        }

        // Dispatch by HTTP method.
        if (std.mem.eql(u8, req.method, "POST")) {
            return self.handlePost(arena, conn, req, body, close_after);
        }
        if (std.mem.eql(u8, req.method, "GET")) {
            return self.handleGet(arena, conn, req);
        }
        if (std.mem.eql(u8, req.method, "DELETE")) {
            return self.handleDelete(arena, conn, req, close_after);
        }

        writeResponse(conn, arena, 405, "Method Not Allowed", "application/json", "Allow: POST, GET, DELETE\r\n", "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32600,\"message\":\"Method Not Allowed\"}}", close_after) catch return .close;
        return if (close_after) .close else .keep_alive;
    }

    fn handlePost(
        self: *HttpServer,
        arena: Allocator,
        conn: *ConnIo,
        req: *const devtools_http.Request,
        body: []const u8,
        close_after: bool,
    ) ConnOutcome {
        const parsed = json.parseFromSliceLeaky(json.Value, arena, body, .{}) catch {
            const err_body = protocol.errorMessage(arena, .null, .parse_error, "Parse error", null) catch return .close;
            writeJsonResponse(conn, arena, 400, null, err_body, close_after) catch return .close;
            return if (close_after) .close else .keep_alive;
        };
        if (parsed != .object) {
            const err_body = protocol.errorMessage(arena, .null, .invalid_request, "Invalid Request", null) catch return .close;
            writeJsonResponse(conn, arena, 400, null, err_body, close_after) catch return .close;
            return if (close_after) .close else .keep_alive;
        }

        const obj = parsed.object;
        const id: json.Value = obj.get("id") orelse .null;
        const has_id = obj.get("id") != null;
        const method_str: ?[]const u8 = if (obj.get("method")) |m| (if (m == .string) m.string else null) else null;
        const params_obj: ?json.ObjectMap = if (obj.get("params")) |p| (if (p == .object) p.object else null) else null;
        const meta_obj: ?json.ObjectMap = if (params_obj) |p| (if (p.get("_meta")) |m| (if (m == .object) m.object else null) else null) else null;
        const meta_version: ?[]const u8 = if (meta_obj) |m| (if (m.get("io.modelcontextprotocol/protocolVersion")) |v| (if (v == .string) v.string else null) else null) else null;
        const header_version = req.header("mcp-protocol-version");

        // Validate MCP-Protocol-Version header against _meta and supported list.
        if (meta_version) |mv| {
            const hv = header_version orelse {
                const err_body = protocol.errorMessage(arena, id, .header_mismatch, "MCP-Protocol-Version header is required and must match _meta", null) catch return .close;
                writeJsonResponse(conn, arena, 400, null, err_body, close_after) catch return .close;
                return if (close_after) .close else .keep_alive;
            };
            if (!std.mem.eql(u8, hv, mv)) {
                const err_body = protocol.errorMessage(arena, id, .header_mismatch, "MCP-Protocol-Version header does not match _meta", null) catch return .close;
                writeJsonResponse(conn, arena, 400, null, err_body, close_after) catch return .close;
                return if (close_after) .close else .keep_alive;
            }
            if (!protocol.isSupported(mv)) {
                const err_body = protocol.unsupportedVersion(arena, id, mv) catch return .close;
                writeJsonResponse(conn, arena, 400, null, err_body, close_after) catch return .close;
                return if (close_after) .close else .keep_alive;
            }
        } else if (header_version) |hv| {
            if (!protocol.isSupported(hv)) {
                const err_body = protocol.unsupportedVersion(arena, id, hv) catch return .close;
                writeJsonResponse(conn, arena, 400, null, err_body, close_after) catch return .close;
                return if (close_after) .close else .keep_alive;
            }
            if (std.mem.eql(u8, hv, protocol.modern_version) and has_id and !(method_str != null and std.mem.eql(u8, method_str.?, "initialize"))) {
                const err_body = protocol.errorMessage(arena, id, .header_mismatch, "MCP-Protocol-Version 2026-07-28 requires matching _meta protocolVersion", null) catch return .close;
                writeJsonResponse(conn, arena, 400, null, err_body, close_after) catch return .close;
                return if (close_after) .close else .keep_alive;
            }
        }

        // Validate Mcp-Method header when present (400 / -32020 on mismatch).
        if (req.header("mcp-method")) |hm| {
            const bm = method_str orelse "";
            if (!std.mem.eql(u8, hm, bm)) {
                const err_body = protocol.errorMessage(arena, id, .header_mismatch, "Mcp-Method header does not match request method", null) catch return .close;
                writeJsonResponse(conn, arena, 400, null, err_body, close_after) catch return .close;
                return if (close_after) .close else .keep_alive;
            }
        }

        // Validate Mcp-Name header when present (including RFC =?base64?...?= decoding).
        if (req.header("mcp-name")) |hn| {
            const decoded_opt = decodeMcpHeaderValue(arena, hn) catch return .close;
            const decoded = decoded_opt orelse {
                const err_body = protocol.errorMessage(arena, id, .header_mismatch, "Malformed Mcp-Name header", null) catch return .close;
                writeJsonResponse(conn, arena, 400, null, err_body, close_after) catch return .close;
                return if (close_after) .close else .keep_alive;
            };
            const body_name: []const u8 = if (params_obj) |p| (if (p.get("name")) |n| (if (n == .string) n.string else "") else "") else "";
            if (!std.mem.eql(u8, decoded, body_name)) {
                const err_body = protocol.errorMessage(arena, id, .header_mismatch, "Mcp-Name header does not match params.name", null) catch return .close;
                writeJsonResponse(conn, arena, 400, null, err_body, close_after) catch return .close;
                return if (close_after) .close else .keep_alive;
            }
        }

        // Modern 2026-07-28 era: stateless, no Mcp-Session-Id minted or echoed.
        const is_modern = meta_version != null or (header_version != null and std.mem.eql(u8, header_version.?, protocol.modern_version));
        if (is_modern) {
            std.Io.Threaded.mutexLockUncancelable(&self.mcp_mutex);
            var stateless: protocol.Protocol = .{
                .handler = self.mcp_server.protocol.handler,
                .info = self.mcp_server.protocol.info,
                .roots = self.mcp_server.protocol.roots,
            };
            const answer = stateless.handle(arena, body) catch {
                std.Io.Threaded.mutexUnlock(&self.mcp_mutex);
                return .close;
            };
            std.Io.Threaded.mutexUnlock(&self.mcp_mutex);
            if (answer == null) {
                writeEmptyResponse(conn, arena, 202, "Accepted", null, close_after) catch return .close;
                return if (close_after) .close else .keep_alive;
            }
            const status = modernHttpStatus(arena, answer.?);
            writeJsonResponse(conn, arena, status, null, answer.?, close_after) catch return .close;
            return if (close_after) .close else .keep_alive;
        }

        // Legacy 2025-11-25 era: initialize mints a session; subsequent requests
        // route by Mcp-Session-Id.
        const is_init = method_str != null and std.mem.eql(u8, method_str.?, "initialize") and has_id;
        if (is_init) {
            const session = HttpSession.create(self.allocator, self.mcp_server) catch return .close;
            std.Io.Threaded.mutexLockUncancelable(&self.mcp_mutex);
            const answer = session.proto.handle(arena, body) catch {
                std.Io.Threaded.mutexUnlock(&self.mcp_mutex);
                session.destroy();
                return .close;
            };
            std.Io.Threaded.mutexUnlock(&self.mcp_mutex);

            std.Io.Threaded.mutexLockUncancelable(&self.state_mutex);
            self.sessions.append(self.allocator, session) catch {
                std.Io.Threaded.mutexUnlock(&self.state_mutex);
                session.destroy();
                return .close;
            };
            const sid_copy = session.id;
            std.Io.Threaded.mutexUnlock(&self.state_mutex);

            writeJsonResponse(conn, arena, 200, &sid_copy, answer orelse "{}", close_after) catch return .close;
            return if (close_after) .close else .keep_alive;
        }

        if (req.header("mcp-session-id")) |sid| {
            const session = self.acquireSession(sid) orelse {
                writeJsonResponse(conn, arena, 404, null, "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32000,\"message\":\"Session not found\"}}", close_after) catch return .close;
                return if (close_after) .close else .keep_alive;
            };
            defer self.releaseSession(session);

            std.Io.Threaded.mutexLockUncancelable(&self.mcp_mutex);
            const answer = session.proto.handle(arena, body) catch {
                std.Io.Threaded.mutexUnlock(&self.mcp_mutex);
                return .close;
            };
            std.Io.Threaded.mutexUnlock(&self.mcp_mutex);

            // A notification or client JSON-RPC response returns 202 Accepted;
            // any server-initiated request (such as roots/list) goes onto the
            // session's SSE queue if present.
            if (!has_id or method_str == null) {
                if (answer) |server_req| {
                    std.Io.Threaded.mutexLockUncancelable(&self.state_mutex);
                    if (!session.deleted) {
                        if (self.allocator.dupe(u8, server_req)) |dup| {
                            session.sse_queue.append(self.allocator, dup) catch self.allocator.free(dup);
                        } else |_| {}
                    }
                    std.Io.Threaded.mutexUnlock(&self.state_mutex);
                }
                writeEmptyResponse(conn, arena, 202, "Accepted", &session.id, close_after) catch return .close;
                return if (close_after) .close else .keep_alive;
            }
            writeJsonResponse(conn, arena, 200, &session.id, answer orelse "{}", close_after) catch return .close;
            return if (close_after) .close else .keep_alive;
        }

        // Stateless legacy request without Mcp-Session-Id (e.g. server/discover or ping).
        std.Io.Threaded.mutexLockUncancelable(&self.mcp_mutex);
        var stateless: protocol.Protocol = .{
            .handler = self.mcp_server.protocol.handler,
            .info = self.mcp_server.protocol.info,
            .roots = self.mcp_server.protocol.roots,
        };
        const answer = stateless.handle(arena, body) catch {
            std.Io.Threaded.mutexUnlock(&self.mcp_mutex);
            return .close;
        };
        std.Io.Threaded.mutexUnlock(&self.mcp_mutex);
        if (answer == null) {
            writeEmptyResponse(conn, arena, 202, "Accepted", null, close_after) catch return .close;
            return if (close_after) .close else .keep_alive;
        }
        writeJsonResponse(conn, arena, 200, null, answer.?, close_after) catch return .close;
        return if (close_after) .close else .keep_alive;
    }

    fn handleGet(self: *HttpServer, arena: Allocator, conn: *ConnIo, req: *const devtools_http.Request) ConnOutcome {
        const hv = req.header("mcp-protocol-version");
        const sid_opt = req.header("mcp-session-id");
        // Modern 2026-07-28 (or no legacy session): GET is 405 Method Not Allowed.
        if (sid_opt == null or (hv != null and std.mem.eql(u8, hv.?, protocol.modern_version))) {
            writeResponse(conn, arena, 405, "Method Not Allowed", "application/json", "Allow: POST\r\n", "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32600,\"message\":\"Method Not Allowed\"}}", true) catch {};
            return .close;
        }

        const session = self.acquireSession(sid_opt.?) orelse {
            writeJsonResponse(conn, arena, 404, null, "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32000,\"message\":\"Session not found\"}}", true) catch {};
            return .close;
        };
        defer self.releaseSession(session);

        // 2025-11-25 SSE stream with immediate priming event.
        const head = std.fmt.allocPrint(arena, "HTTP/1.1 200 OK\r\n" ++
            "Content-Type: text/event-stream\r\n" ++
            "Cache-Control: no-cache\r\n" ++
            "X-Accel-Buffering: no\r\n" ++
            "Mcp-Session-Id: {s}\r\n" ++
            "Connection: close\r\n\r\n" ++
            "id: 1\ndata:\n\n", .{session.id}) catch return .close;
        conn.writeAll(head) catch return .close;

        // Wait on peer disconnect or session SSE wake (DELETE, server stop, or queued event).
        var scratch: [256]u8 = undefined;
        while (!self.stopping.load(.acquire)) {
            if (!self.flushSseQueue(arena, conn, session)) return .close;
            std.Io.Threaded.mutexLockUncancelable(&self.state_mutex);
            const is_deleted = session.deleted;
            std.Io.Threaded.mutexUnlock(&self.state_mutex);
            if (is_deleted) return .close;

            const read_res = conn.read(&scratch, session.sse_wake) catch return .close;
            if (read_res) |n| {
                // 0: peer closed SSE connection cleanly.
                if (n == 0) return .close;
            } else {
                // Woken by session SSE queue, DELETE, or server stop.
                if (!self.flushSseQueue(arena, conn, session)) return .close;
                std.Io.Threaded.mutexLockUncancelable(&self.state_mutex);
                const gone = session.deleted;
                std.Io.Threaded.mutexUnlock(&self.state_mutex);
                if (gone or self.stopping.load(.acquire)) return .close;
            }
        }
        return .close;
    }

    fn flushSseQueue(self: *HttpServer, arena: Allocator, conn: *ConnIo, session: *HttpSession) bool {
        while (true) {
            std.Io.Threaded.mutexLockUncancelable(&self.state_mutex);
            if (session.sse_queue.items.len == 0) {
                std.Io.Threaded.mutexUnlock(&self.state_mutex);
                return true;
            }
            const msg = session.sse_queue.orderedRemove(0);
            const event_id = session.next_event_id;
            session.next_event_id += 1;
            std.Io.Threaded.mutexUnlock(&self.state_mutex);
            defer self.allocator.free(msg);

            const frame = std.fmt.allocPrint(arena, "id: {d}\nevent: message\ndata: {s}\n\n", .{ event_id, msg }) catch return false;
            conn.writeAll(frame) catch return false;
        }
    }

    fn handleDelete(self: *HttpServer, arena: Allocator, conn: *ConnIo, req: *const devtools_http.Request, close_after: bool) ConnOutcome {
        const hv = req.header("mcp-protocol-version");
        const sid_opt = req.header("mcp-session-id");
        // Modern 2026-07-28 (or no legacy session): DELETE is 405 Method Not Allowed.
        if (sid_opt == null or (hv != null and std.mem.eql(u8, hv.?, protocol.modern_version))) {
            writeResponse(conn, arena, 405, "Method Not Allowed", "application/json", "Allow: POST\r\n", "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32600,\"message\":\"Method Not Allowed\"}}", close_after) catch return .close;
            return if (close_after) .close else .keep_alive;
        }

        std.Io.Threaded.mutexLockUncancelable(&self.state_mutex);
        var found = false;
        for (self.sessions.items) |s| {
            if (!s.deleted and std.mem.eql(u8, &s.id, sid_opt.?)) {
                s.deleted = true;
                platform.devtoolsWake(s.sse_wake);
                found = true;
                break;
            }
        }
        std.Io.Threaded.mutexUnlock(&self.state_mutex);

        if (!found) {
            writeJsonResponse(conn, arena, 404, null, "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32000,\"message\":\"Session not found\"}}", close_after) catch return .close;
            return if (close_after) .close else .keep_alive;
        }
        writeEmptyResponse(conn, arena, 200, "OK", null, close_after) catch return .close;
        return if (close_after) .close else .keep_alive;
    }

    fn acquireSession(self: *HttpServer, sid: []const u8) ?*HttpSession {
        std.Io.Threaded.mutexLockUncancelable(&self.state_mutex);
        defer std.Io.Threaded.mutexUnlock(&self.state_mutex);
        for (self.sessions.items) |s| {
            if (!s.deleted and std.mem.eql(u8, &s.id, sid)) {
                s.refs += 1;
                return s;
            }
        }
        return null;
    }

    fn releaseSession(self: *HttpServer, session: *HttpSession) void {
        std.Io.Threaded.mutexLockUncancelable(&self.state_mutex);
        session.refs -= 1;
        std.Io.Threaded.mutexUnlock(&self.state_mutex);
    }

    fn modernHttpStatus(arena: Allocator, response_json: []const u8) u16 {
        const parsed = json.parseFromSliceLeaky(json.Value, arena, response_json, .{}) catch return 200;
        if (parsed != .object) return 200;
        const err_val = parsed.object.get("error") orelse return 200;
        if (err_val != .object) return 200;
        const code_val = err_val.object.get("code") orelse return 200;
        if (code_val != .integer) return 200;
        return switch (code_val.integer) {
            -32020, -32021, -32022, -32700, -32600 => 400,
            -32601 => 404,
            -32602 => blk: {
                if (err_val.object.get("message")) |m| {
                    if (m == .string and std.mem.indexOf(u8, m.string, "_meta") != null) break :blk 400;
                }
                break :blk 200;
            },
            else => 200,
        };
    }

    fn writeJsonResponse(conn: *ConnIo, arena: Allocator, status: u16, session_id: ?[]const u8, body: []const u8, close_conn: bool) !void {
        const extra = if (session_id) |sid| try std.fmt.allocPrint(arena, "Mcp-Session-Id: {s}\r\n", .{sid}) else "";
        try writeResponse(conn, arena, status, statusReason(status), "application/json", extra, body, close_conn);
    }

    fn writeEmptyResponse(conn: *ConnIo, arena: Allocator, status: u16, reason: []const u8, session_id: ?[]const u8, close_conn: bool) !void {
        const extra = if (session_id) |sid| try std.fmt.allocPrint(arena, "Mcp-Session-Id: {s}\r\n", .{sid}) else "";
        const raw = try std.fmt.allocPrint(arena, "HTTP/1.1 {d} {s}\r\n{s}Content-Length: 0\r\nConnection: {s}\r\n\r\n", .{
            status,
            reason,
            extra,
            if (close_conn) "close" else "keep-alive",
        });
        try conn.writeAll(raw);
    }

    fn writeResponse(
        conn: *ConnIo,
        arena: Allocator,
        status: u16,
        reason: []const u8,
        content_type: []const u8,
        extra_headers: []const u8,
        body: []const u8,
        close_conn: bool,
    ) !void {
        const raw = try std.fmt.allocPrint(arena, "HTTP/1.1 {d} {s}\r\nContent-Type: {s}\r\n{s}Content-Length: {d}\r\nConnection: {s}\r\n\r\n{s}", .{
            status,
            reason,
            content_type,
            extra_headers,
            body.len,
            if (close_conn) "close" else "keep-alive",
            body,
        });
        try conn.writeAll(raw);
    }

    fn statusReason(status: u16) []const u8 {
        return switch (status) {
            200 => "OK",
            202 => "Accepted",
            400 => "Bad Request",
            401 => "Unauthorized",
            403 => "Forbidden",
            404 => "Not Found",
            405 => "Method Not Allowed",
            413 => "Payload Too Large",
            429 => "Too Many Requests",
            else => "Error",
        };
    }
};

// ---------------------------------------------------------------------------
// Host C ABI (include/crane.h: crane_browser_start_mcp / stop_mcp / info_free)
// ---------------------------------------------------------------------------

pub const capi = struct {
    const browser_capi = @import("browser").capi;
    // direct-allocator: C ABI host allocator for external embedder handles and strings returned across include/crane.h
    const capi_allocator = std.heap.c_allocator;

    const Instance = struct {
        devtools_server: *DevtoolsServer,
        http_server: *HttpServer,
        owned_roots: [][]u8,
        root_slices: [][]const u8,

        fn stopAndFree(raw: *anyopaque) void {
            const self: *Instance = @ptrCast(@alignCast(raw));
            self.http_server.stop();
            self.devtools_server.stop();
            for (self.owned_roots) |r| capi_allocator.free(r);
            capi_allocator.free(self.owned_roots);
            capi_allocator.free(self.root_slices);
            capi_allocator.destroy(self);
        }
    };

    fn dupeZ(text: []const u8) ![*:0]u8 {
        return (try capi_allocator.dupeSentinel(u8, text, 0)).ptr;
    }

    pub export fn crane_browser_start_mcp(
        browser: ?*browser_capi.Handle,
        options: ?*const browser_capi.McpOptions,
        out: ?*browser_capi.McpInfo,
    ) callconv(.c) browser_capi.Status {
        const handle = browser orelse return .invalid_argument;
        const result = out orelse return .invalid_argument;
        result.* = .{};
        if (handle.browserHost().isBrowserThread()) return .wrong_thread;
        if (handle.hasMcp()) return .invalid_argument;

        var o: browser_capi.McpOptions = .{ .struct_size = @sizeOf(browser_capi.McpOptions) };
        if (options) |given| {
            if (given.struct_size < @sizeOf(u32)) return .invalid_argument;
            const covered = @min(given.struct_size, @sizeOf(browser_capi.McpOptions));
            const from: [*]const u8 = @ptrCast(given);
            @memcpy(std.mem.asBytes(&o)[0..covered], from[0..covered]);
        }

        const cert_pem: []const u8 = if (o.cert_pem) |p| std.mem.span(p) else "";
        const key_pem: []const u8 = if (o.key_pem) |p| std.mem.span(p) else "";
        if ((cert_pem.len != 0) != (key_pem.len != 0)) return .invalid_argument;
        if (o.filesystem_root_count > 0 and o.filesystem_roots == null) return .invalid_argument;
        if (o.allowed_origin_count > 0 and o.allowed_origins == null) return .invalid_argument;

        const host: []const u8 = if (o.host) |h| std.mem.span(h) else "127.0.0.1";

        const owned_roots = capi_allocator.alloc([]u8, o.filesystem_root_count) catch return .out_of_memory;
        errdefer capi_allocator.free(owned_roots);
        const root_slices = capi_allocator.alloc([]const u8, o.filesystem_root_count) catch return .out_of_memory;
        errdefer capi_allocator.free(root_slices);
        var roots_copied: usize = 0;
        errdefer for (owned_roots[0..roots_copied]) |r| capi_allocator.free(r);
        if (o.filesystem_roots) |list| {
            for (list[0..o.filesystem_root_count], 0..) |r, i| {
                owned_roots[i] = capi_allocator.dupe(u8, std.mem.span(r)) catch return .out_of_memory;
                root_slices[i] = owned_roots[i];
                roots_copied += 1;
            }
        }

        const origin_slices = capi_allocator.alloc([]const u8, o.allowed_origin_count) catch return .out_of_memory;
        defer capi_allocator.free(origin_slices);
        if (o.allowed_origins) |list| {
            for (list[0..o.allowed_origin_count], 0..) |orig, i| {
                origin_slices[i] = std.mem.span(orig);
            }
        }

        const inst = capi_allocator.create(Instance) catch return .out_of_memory;
        errdefer capi_allocator.destroy(inst);

        const dt = DevtoolsServer.start(capi_allocator, .{
            .default_host = handle.browserHost(),
        }) catch |err| return switch (err) {
            error.OutOfMemory => .out_of_memory,
            error.NotSupported => .unsupported,
            else => .internal,
        };
        errdefer dt.stop();

        const http_srv = HttpServer.start(capi_allocator, dt, .{
            .host = host,
            .port = o.port,
            .tls = if (o.tls) .required else .auto,
            .cert_pem = cert_pem,
            .key_pem = key_pem,
            .allowed_origins = origin_slices,
            .mcp = .{
                .filesystem_roots = if (root_slices.len > 0) root_slices else null,
                .allow_unrestricted_paths = o.allow_unrestricted_paths,
                .memory_debugging = o.memory_debugging,
            },
        }) catch |err| return switch (err) {
            error.OutOfMemory => .out_of_memory,
            error.NotSupported => .unsupported,
            error.AccessDenied, error.InvalidTlsConfig, error.TlsRequired => .invalid_argument,
            else => .internal,
        };
        errdefer http_srv.stop();

        const token_z = dupeZ(http_srv.bearerToken()) catch return .out_of_memory;
        errdefer capi_allocator.free(std.mem.span(token_z));
        const fp_z: ?[*:0]u8 = if (http_srv.certFingerprint()) |fp| (dupeZ(fp) catch return .out_of_memory) else null;
        errdefer if (fp_z) |f| capi_allocator.free(std.mem.span(f));

        inst.* = .{
            .devtools_server = dt,
            .http_server = http_srv,
            .owned_roots = owned_roots,
            .root_slices = root_slices,
        };
        handle.attachMcp(inst, Instance.stopAndFree);

        result.* = .{
            .port = http_srv.boundPort(),
            .tls = http_srv.isTls(),
            .bearer_token = token_z,
            .cert_fingerprint = fp_z,
        };
        return .ok;
    }

    pub export fn crane_browser_stop_mcp(browser: ?*browser_capi.Handle) callconv(.c) browser_capi.Status {
        const handle = browser orelse return .invalid_argument;
        if (handle.browserHost().isBrowserThread()) return .wrong_thread;
        handle.detachMcp();
        return .ok;
    }

    pub export fn crane_mcp_info_free(info: ?*browser_capi.McpInfo) callconv(.c) void {
        const i = info orelse return;
        if (i.bearer_token) |t| capi_allocator.free(std.mem.span(t));
        if (i.cert_fingerprint) |f| capi_allocator.free(std.mem.span(f));
        i.* = .{};
    }
};

// ---------------------------------------------------------------------------
// Unit tests
// ---------------------------------------------------------------------------

test "isLoopbackHost distinguishes loopback from non-loopback addresses" {
    try std.testing.expect(isLoopbackHost(""));
    try std.testing.expect(isLoopbackHost("127.0.0.1"));
    try std.testing.expect(isLoopbackHost("127.0.1.1"));
    try std.testing.expect(isLoopbackHost("localhost"));
    try std.testing.expect(isLoopbackHost("LOCALHOST."));
    try std.testing.expect(isLoopbackHost("::1"));
    try std.testing.expect(isLoopbackHost("[::1]"));
    try std.testing.expect(!isLoopbackHost("0.0.0.0"));
    try std.testing.expect(!isLoopbackHost("::"));
    try std.testing.expect(!isLoopbackHost("192.168.1.5"));
    try std.testing.expect(!isLoopbackHost("10.0.0.1"));
}

test "verifyBearerToken enforces exact constant-time Bearer token match and rejects query tokens" {
    var expected: [64]u8 = @splat('a');
    var header_buf: [128]u8 = undefined;
    const good = try std.fmt.bufPrint(&header_buf, "Bearer {s}", .{expected});
    try std.testing.expect(verifyBearerToken(&expected, good));
    const lower = try std.fmt.bufPrint(&header_buf, "bearer {s}", .{expected});
    try std.testing.expect(verifyBearerToken(&expected, lower));
    try std.testing.expect(!verifyBearerToken(&expected, null));
    try std.testing.expect(!verifyBearerToken(&expected, "Basic abc"));
    var bad_token = expected;
    bad_token[63] = 'b';
    const bad = try std.fmt.bufPrint(&header_buf, "Bearer {s}", .{bad_token});
    try std.testing.expect(!verifyBearerToken(&expected, bad));

    try std.testing.expect(queryHasToken("/mcp?token=abc"));
    try std.testing.expect(queryHasToken("/mcp?x=1&access_token=abc"));
    try std.testing.expect(!queryHasToken("/mcp"));
    try std.testing.expect(!queryHasToken("/mcp?foo=bar"));
}

test "decodeMcpHeaderValue decodes RFC =?base64?...?= and passes plain values through" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    try std.testing.expectEqualStrings("list_pages", (try decodeMcpHeaderValue(arena.allocator(), "list_pages")).?);
    try std.testing.expectEqualStrings("list_pages", (try decodeMcpHeaderValue(arena.allocator(), "=?base64?bGlzdF9wYWdlcw==?=")).?);
    try std.testing.expect((try decodeMcpHeaderValue(arena.allocator(), "=?base64?!!!?=")) == null);
}

test "formatSha256Fingerprint renders 95-char colon-separated uppercase hex" {
    var digest: [32]u8 = @splat(0);
    digest[0] = 0xAB;
    digest[1] = 0x05;
    digest[31] = 0xFF;
    var out: [95]u8 = undefined;
    const s = formatSha256Fingerprint(digest, &out);
    try std.testing.expectEqual(@as(usize, 95), s.len);
    try std.testing.expect(std.mem.startsWith(u8, s, "AB:05:00:"));
    try std.testing.expect(std.mem.endsWith(u8, s, ":FF"));
}
