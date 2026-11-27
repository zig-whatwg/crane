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
//!
//! Lifetimes and limits (lane mcp3; audit report C, H1, M3 and M4):
//! - A legacy session is reference-counted: the session list holds one
//!   reference while it is listed, and each request or GET stream using it
//!   holds one more; its last release frees it. It is unlisted by DELETE, by
//!   going unused for `session_idle_timeout_ms`, by eviction - the list holds
//!   at most `max_sessions` (default twice `max_connections`), and an
//!   `initialize` beyond that evicts the session that nothing holds and that
//!   was used longest ago - and by `stop()`. A session the server ended
//!   answers 404 ("The server MAY terminate the session at any time, after
//!   which it MUST respond to requests containing that session ID with HTTP
//!   404 Not Found", 2025-11-25 transports, Session Management 3). It holds no
//!   descriptor unless its GET stream is waiting.
//! - A connection is PENDING until its first request authenticates: its TLS
//!   handshake and that request's head must come within `auth_timeout_ms`,
//!   and it counts against `max_pending_connections` (when that is full, the
//!   oldest pending connection is closed to make room), never against the
//!   `max_connections` authenticated slots - so sockets that never
//!   authenticate cannot lock the agent out. Lightpanda's `serve` keeps the
//!   same split (`cdp_max_pending_connections` 128 beside
//!   `cdp_max_connections` 16, src/Config.zig at 4a1a166cf; AGPL: behaviour
//!   read, nothing copied). The token is checked from the head alone, before
//!   any body is read.
//! - Deadlines, as Node's http.Server keeps them (lib/_http_server.js:
//!   keepAliveTimeout 5 s with its `Keep-Alive: timeout=` header,
//!   headersTimeout and requestTimeout, checked every
//!   connectionsCheckingInterval): a kept-alive connection waits
//!   `keep_alive_timeout_ms` for its next request, a started request has
//!   `request_timeout_ms` for its head and body, one write blocks at most
//!   `write_timeout_ms`. A reaper thread looks every `reap_interval_ms`, shuts
//!   a late connection's socket down - which ends the read or write its worker
//!   is blocked in, TLS included - and unlists sessions gone idle.
//! - A legacy session's first tools/call waits for the client's roots, as the
//!   stdio transport does (chrome-devtools-mcp v1.13.0 src/index.ts
//!   #getContext: `this.#initialRoots ??= this.#updateRoots(ROOTS_REQUEST_TIMEOUT)`
//!   - 5 s, once, one wait shared by concurrent calls). The roots/list request
//!   goes on the call's own SSE response when the client accepts
//!   text/event-stream (2025-11-25 transports, POST: "The server MAY send
//!   JSON-RPC requests and notifications before sending the JSON-RPC response.
//!   These messages SHOULD relate to the originating client request"), else on
//!   the session's GET stream; the tool's answer follows on the same channel.
//!   With neither, nothing can reach the client and the call does not wait.

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

fn nowNs() u64 {
    return platform.monotonicNow().ns;
}

/// `ms` after `now_ns`, or 0 (no deadline) when `ms` is 0.
fn deadlineFrom(now_ns: u64, ms: u64) u64 {
    if (ms == 0) return 0;
    return now_ns +| ms *| std.time.ns_per_ms;
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
    /// Connections whose first request authenticated, served at once; one
    /// more is answered 503.
    max_connections: u32 = 32,
    /// Connections that have not authenticated yet (at least 1). When full,
    /// a new one closes the oldest.
    max_pending_connections: u32 = 64,
    /// How long a new connection has for its TLS handshake and its first
    /// request's head (0: no limit).
    auth_timeout_ms: u32 = 10_000,
    /// How long a started request has for its head and body (0: no limit).
    request_timeout_ms: u32 = 60_000,
    /// How long a kept-alive connection may wait for its next request (0: no
    /// limit). Node's http.Server default.
    keep_alive_timeout_ms: u32 = 5_000,
    /// How long one write may block (0: no limit).
    write_timeout_ms: u32 = 30_000,
    /// Legacy sessions listed at once (0: twice `max_connections`).
    max_sessions: u32 = 0,
    /// How long a legacy session may go unused before it ends (0: never).
    session_idle_timeout_ms: u64 = 30 * std.time.ms_per_min,
    /// How often the deadlines are checked.
    reap_interval_ms: u32 = 1_000,
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

/// Whether the request's Accept lists `text/event-stream` (its parameters
/// aside): the client takes an SSE response.
fn acceptsEventStream(req: *const devtools_http.Request) bool {
    for (req.headers) |h| {
        if (!std.ascii.eqlIgnoreCase(h.name, "accept")) continue;
        var it = std.mem.tokenizeScalar(u8, h.value, ',');
        while (it.next()) |part| {
            const media = std.mem.trim(u8, part[0 .. std.mem.indexOfScalar(u8, part, ';') orelse part.len], " \t");
            if (std.ascii.eqlIgnoreCase(media, "text/event-stream")) return true;
        }
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

/// One legacy (2025-11-25) HTTP session. Everything but `roots_signal` is
/// under `HttpServer.state_mutex`; its protocol state (`proto`) is under
/// `HttpServer.mcp_mutex`.
const HttpSession = struct {
    allocator: Allocator,
    id: [32]u8,
    proto: protocol.Protocol,
    /// The list's reference while listed, plus one per request or stream
    /// using it; the last release frees it.
    refs: u32 = 1,
    /// Unlisted (DELETE, idle, evicted, stopping): a request naming it gets
    /// 404, its stream ends, a roots wait on it ends.
    ended: bool = false,
    /// When a request last used it (monotonic ms): the eviction order and
    /// the idle timeout.
    last_used_ms: i64,
    /// Server messages for the GET stream, oldest first.
    sse_queue: std.ArrayList([]u8) = .empty,
    /// The next SSE event id ("globally unique across all streams within
    /// that session"; 1 primes the GET stream).
    next_event_id: u64 = 2,
    /// The standalone GET stream is open (one at a time).
    stream_open: bool = false,
    /// What that stream waits on now. A platform wake stays woken once woken
    /// (kit/posix devtoolsWake: "every wait on it ... returns at once"), so
    /// the stream makes one for each wait and closes it once it fired.
    stream_wake: ?platform.DevtoolsWake = null,
    /// Bumped and futex-woken when a client response was handled, a roots
    /// wait ended or the session ended: what a call waiting for the client's
    /// roots waits on.
    roots_signal: std.atomic.Value(u32) = .init(0),

    /// Messages kept for a stream that is not there; beyond it the oldest go.
    const max_queued = 64;

    fn create(allocator: Allocator, mcp_server: *McpServer, now_ms: i64) !*HttpSession {
        const self = try allocator.create(HttpSession);
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
            .last_used_ms = now_ms,
        };
        return self;
    }

    fn destroy(self: *HttpSession) void {
        for (self.sse_queue.items) |msg| self.allocator.free(msg);
        self.sse_queue.deinit(self.allocator);
        if (self.stream_wake) |w| platform.devtoolsWakeClose(w);
        self.allocator.destroy(self);
    }

    /// Wake the stream's wait, if it waits (under the state lock).
    fn wakeStream(self: *HttpSession) void {
        if (self.stream_wake) |w| platform.devtoolsWake(w);
    }

    /// Queue a server message for the stream and wake it (under the state
    /// lock). OWNS `msg`.
    fn queue(self: *HttpSession, msg: []u8) void {
        if (self.sse_queue.items.len >= max_queued) self.allocator.free(self.sse_queue.orderedRemove(0));
        self.sse_queue.append(self.allocator, msg) catch {
            self.allocator.free(msg);
            return;
        };
        self.wakeStream();
    }

    fn signalRoots(self: *HttpSession) void {
        _ = self.roots_signal.fetchAdd(1, .release);
        futexIo().futexWake(u32, &self.roots_signal.raw, std.math.maxInt(u32));
    }
};

/// One accepted connection. Listed in `HttpServer.conns` from its accept
/// until its worker unlists it - and closed only after that, so the reaper
/// and `stop()`, which shut sockets down under the state lock, never touch a
/// descriptor number that was closed and reused meanwhile.
const Conn = struct {
    raw: platform.DevtoolsStream,
    accepted_ns: u64,
    /// When the reaper shuts it down (monotonic ns; 0: no deadline now).
    /// Its worker sets it before each wait.
    deadline_ns: std.atomic.Value(u64),
    /// Its first request authenticated: it holds an authenticated slot, not
    /// a pending one. Under the state lock.
    authenticated: bool = false,
    /// Shut down (a deadline, an eviction, `stop()`). Under the state lock.
    shut: bool = false,
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
    conns: std.ArrayList(*Conn) = .empty,
    /// Listed connections that have not authenticated / have. Under the
    /// state lock.
    pending_count: u32 = 0,
    authed_count: u32 = 0,

    acceptor: ?platform.Thread = null,
    reaper: ?platform.Thread = null,
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
        stored_options.max_pending_connections = @max(options.max_pending_connections, 1);

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

        self.reaper = try platform.spawnThread(.{ .name = .from("mcp-http-reap") }, reaperMain, self);
        errdefer {
            self.requestStop();
            platform.joinThread(self.reaper.?);
        }
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

    /// Legacy sessions listed now (tests).
    pub fn sessionCount(self: *HttpServer) usize {
        std.Io.Threaded.mutexLockUncancelable(&self.state_mutex);
        defer std.Io.Threaded.mutexUnlock(&self.state_mutex);
        return self.sessions.items.len;
    }

    /// Connections whose workers have not finished (tests).
    pub fn connectionCount(self: *const HttpServer) u32 {
        return self.live_workers.load(.acquire);
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

    /// Stop accepting, end every session and wake its waits, shut every
    /// connection down, join every worker thread, and release everything.
    pub fn stop(self: *HttpServer) void {
        self.requestStop();
        if (self.acceptor) |t| {
            platform.joinThread(t);
            self.acceptor = null;
        }
        if (self.reaper) |t| {
            platform.joinThread(t);
            self.reaper = null;
        }
        std.Io.Threaded.mutexLockUncancelable(&self.state_mutex);
        for (self.sessions.items) |s| {
            s.ended = true;
            s.wakeStream();
            s.signalRoots();
        }
        for (self.conns.items) |conn| shutConn(conn);
        std.Io.Threaded.mutexUnlock(&self.state_mutex);

        while (true) {
            const live = self.live_workers.load(.acquire);
            if (live == 0) break;
            futexIo().futexWaitTimeout(u32, &self.live_workers.raw, live, .{ .duration = .{ .raw = .fromMilliseconds(50), .clock = .awake } }) catch {};
        }

        // Every holder has released: each listed session holds only the
        // list's reference.
        for (self.sessions.items) |s| s.destroy();
        self.sessions.deinit(self.allocator);
        self.conns.deinit(self.allocator);
        self.mcp_server.destroy();
        if (self.tls_server) |h| platform.devtoolsTlsServerClose(h);
        platform.devtoolsCloseListener(self.listener);
        platform.devtoolsWakeClose(self.wake);
        for (self.owned_origins) |o| self.allocator.free(o);
        self.allocator.free(self.owned_origins);
        self.allocator.free(self.origin_slices);
        self.allocator.destroy(self);
    }

    // ------------------------------------------------------------------
    // Connections: admission, slots, deadlines
    // ------------------------------------------------------------------

    /// The most connections listed at once: the authenticated slots, the
    /// pending ones, and as many pending ones again on their way out after
    /// an eviction.
    fn connectionCap(self: *const HttpServer) usize {
        return @as(usize, self.options.max_connections) + 2 * @as(usize, self.options.max_pending_connections);
    }

    fn sessionCap(self: *const HttpServer) usize {
        if (self.options.max_sessions != 0) return self.options.max_sessions;
        return 2 * @as(usize, @max(self.options.max_connections, 1));
    }

    fn shutConn(conn: *Conn) void {
        if (conn.shut) return;
        conn.shut = true;
        platform.devtoolsShutdown(conn.raw);
    }

    /// List a just-accepted connection as pending, its deadline the auth
    /// deadline; null when none may be listed now (it is closed). Pending
    /// connections full: the oldest one not shut yet is shut down for it.
    fn admit(self: *HttpServer, stream: platform.DevtoolsStream) ?*Conn {
        const now = nowNs();
        std.Io.Threaded.mutexLockUncancelable(&self.state_mutex);
        defer std.Io.Threaded.mutexUnlock(&self.state_mutex);
        if (self.pending_count >= self.options.max_pending_connections) {
            var oldest: ?*Conn = null;
            for (self.conns.items) |c| {
                if (c.authenticated or c.shut) continue;
                if (oldest == null or c.accepted_ns < oldest.?.accepted_ns) oldest = c;
            }
            if (oldest) |c| shutConn(c);
        }
        if (self.conns.items.len >= self.connectionCap()) return null;
        const conn = self.allocator.create(Conn) catch return null;
        conn.* = .{ .raw = stream, .accepted_ns = now, .deadline_ns = .init(deadlineFrom(now, self.options.auth_timeout_ms)) };
        self.conns.append(self.allocator, conn) catch {
            self.allocator.destroy(conn);
            return null;
        };
        self.pending_count += 1;
        return conn;
    }

    /// The connection's first request authenticated: it takes an
    /// authenticated slot. False when none is free (or it was shut).
    fn promote(self: *HttpServer, conn: *Conn) bool {
        std.Io.Threaded.mutexLockUncancelable(&self.state_mutex);
        defer std.Io.Threaded.mutexUnlock(&self.state_mutex);
        if (conn.shut or self.authed_count >= self.options.max_connections) return false;
        self.pending_count -= 1;
        self.authed_count += 1;
        conn.authenticated = true;
        return true;
    }

    /// Unlist, then close and free, a connection whose worker is done.
    fn retire(self: *HttpServer, conn: *Conn) void {
        std.Io.Threaded.mutexLockUncancelable(&self.state_mutex);
        for (self.conns.items, 0..) |c, i| {
            if (c == conn) {
                _ = self.conns.swapRemove(i);
                break;
            }
        }
        if (conn.authenticated) self.authed_count -= 1 else self.pending_count -= 1;
        std.Io.Threaded.mutexUnlock(&self.state_mutex);
        platform.devtoolsClose(conn.raw);
        self.allocator.destroy(conn);
    }

    fn workerDone(self: *HttpServer) void {
        if (self.live_workers.fetchSub(1, .acq_rel) == 1) {
            futexIo().futexWake(u32, &self.live_workers.raw, std.math.maxInt(u32));
        }
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
            const conn = self.admit(stream) orelse {
                platform.devtoolsClose(stream);
                continue;
            };
            const worker = self.allocator.create(WorkerArg) catch {
                self.retire(conn);
                continue;
            };
            worker.* = .{ .server = self, .conn = conn };
            _ = self.live_workers.fetchAdd(1, .acq_rel);
            const thread = platform.spawnThread(.{ .name = .from("mcp-http-conn") }, workerMain, worker) catch {
                self.allocator.destroy(worker);
                self.retire(conn);
                self.workerDone();
                continue;
            };
            platform.detachThread(thread);
        }
    }

    /// Every `reap_interval_ms` until the server stops: shut down each
    /// connection past its deadline, unlist each session unused past
    /// `session_idle_timeout_ms` that nothing holds.
    fn reaperMain(ctx: ?*anyopaque) callconv(.c) void {
        const self: *HttpServer = @ptrCast(@alignCast(ctx.?));
        const interval: i64 = @max(self.options.reap_interval_ms, 1);
        while (!self.stopping.load(.acquire)) {
            futexIo().futexWaitTimeout(u32, &self.closed.raw, 0, .{ .duration = .{ .raw = .fromMilliseconds(interval), .clock = .awake } }) catch {};
            if (self.stopping.load(.acquire)) return;
            self.reap();
        }
    }

    fn reap(self: *HttpServer) void {
        const now_ns = nowNs();
        const now_ms = platform.monotonicMillis();
        std.Io.Threaded.mutexLockUncancelable(&self.state_mutex);
        defer std.Io.Threaded.mutexUnlock(&self.state_mutex);
        for (self.conns.items) |conn| {
            const deadline = conn.deadline_ns.load(.acquire);
            if (deadline != 0 and now_ns >= deadline) shutConn(conn);
        }
        const idle_ms = self.options.session_idle_timeout_ms;
        if (idle_ms == 0) return;
        var i: usize = self.sessions.items.len;
        while (i > 0) {
            i -= 1;
            const s = self.sessions.items[i];
            if (s.refs == 1 and now_ms - s.last_used_ms >= @as(i64, @intCast(idle_ms))) self.unlistAt(i);
        }
    }

    // ------------------------------------------------------------------
    // Sessions
    // ------------------------------------------------------------------

    /// Unlist session `i` (under the state lock): it ends, its stream and
    /// roots waits wake, and the list's reference goes.
    fn unlistAt(self: *HttpServer, i: usize) void {
        const s = self.sessions.swapRemove(i);
        s.ended = true;
        s.wakeStream();
        s.signalRoots();
        s.refs -= 1;
        if (s.refs == 0) s.destroy();
    }

    /// List a new session; when the list is full, the session nothing holds
    /// that was used longest ago is evicted for it. False when every listed
    /// session is held.
    fn listSession(self: *HttpServer, session: *HttpSession) bool {
        std.Io.Threaded.mutexLockUncancelable(&self.state_mutex);
        defer std.Io.Threaded.mutexUnlock(&self.state_mutex);
        if (self.sessions.items.len >= self.sessionCap()) {
            var oldest: ?usize = null;
            for (self.sessions.items, 0..) |s, i| {
                if (s.refs != 1) continue;
                if (oldest == null or s.last_used_ms < self.sessions.items[oldest.?].last_used_ms) oldest = i;
            }
            self.unlistAt(oldest orelse return false);
        }
        self.sessions.append(self.allocator, session) catch return false;
        return true;
    }

    fn acquireSession(self: *HttpServer, sid: []const u8) ?*HttpSession {
        std.Io.Threaded.mutexLockUncancelable(&self.state_mutex);
        defer std.Io.Threaded.mutexUnlock(&self.state_mutex);
        for (self.sessions.items) |s| {
            if (!s.ended and std.mem.eql(u8, &s.id, sid)) {
                s.refs += 1;
                s.last_used_ms = platform.monotonicMillis();
                return s;
            }
        }
        return null;
    }

    fn releaseSession(self: *HttpServer, session: *HttpSession) void {
        std.Io.Threaded.mutexLockUncancelable(&self.state_mutex);
        defer std.Io.Threaded.mutexUnlock(&self.state_mutex);
        session.last_used_ms = platform.monotonicMillis();
        session.refs -= 1;
        if (session.refs == 0) session.destroy();
    }

    // ------------------------------------------------------------------
    // One connection's requests
    // ------------------------------------------------------------------

    const WorkerArg = struct {
        server: *HttpServer,
        conn: *Conn,
    };

    fn workerMain(ctx: ?*anyopaque) callconv(.c) void {
        const arg: *WorkerArg = @ptrCast(@alignCast(ctx.?));
        const self = arg.server;
        const conn = arg.conn;
        self.allocator.destroy(arg);
        defer self.workerDone();
        defer self.retire(conn);

        // The handshake runs under the auth deadline set at accept.
        var tls_stream: ?*platform.DevtoolsTlsStream = null;
        if (self.tls_server) |tls| {
            tls_stream = (platform.devtoolsTlsAccept(self.allocator, tls, conn.raw, self.wake) catch return) orelse return;
        }
        defer if (tls_stream) |ts| platform.devtoolsTlsClose(ts);

        var io: ConnIo = .{ .server = self, .conn = conn, .tls = tls_stream };
        self.serveConnection(&io);
    }

    const ConnIo = struct {
        server: *HttpServer,
        conn: *Conn,
        tls: ?*platform.DevtoolsTlsStream,

        fn read(self: *ConnIo, buf: []u8, wake: platform.DevtoolsWake) !?usize {
            if (self.tls) |ts| return platform.devtoolsTlsRead(ts, buf, wake);
            return platform.devtoolsReadOrWake(self.conn.raw, buf, wake);
        }

        /// Write all of `data`; a write blocked past write_timeout_ms is
        /// ended by the reaper. The deadline before it comes back after.
        fn writeAll(self: *ConnIo, data: []const u8) !void {
            const before = self.conn.deadline_ns.load(.acquire);
            self.conn.deadline_ns.store(deadlineFrom(nowNs(), self.server.options.write_timeout_ms), .release);
            defer self.conn.deadline_ns.store(before, .release);
            if (self.tls) |ts| return platform.devtoolsTlsWrite(ts, platform.Bytes.from(data));
            return platform.devtoolsWrite(self.conn.raw, platform.Bytes.from(data));
        }

        /// The reaper ends the connection `ms` from now (0: never).
        fn setDeadline(self: *ConnIo, ms: u64) void {
            self.conn.deadline_ns.store(deadlineFrom(nowNs(), ms), .release);
        }
    };

    fn serveConnection(self: *HttpServer, io: *ConnIo) void {
        var buffer: std.ArrayList(u8) = .empty;
        defer buffer.deinit(self.allocator);
        const chunk = self.allocator.alloc(u8, read_chunk_size) catch return;
        defer self.allocator.free(chunk);
        var conn_rate: RateWindow = .{};
        // The first request authenticates the connection, under the auth
        // deadline its accept set.
        var first = true;

        while (!self.stopping.load(.acquire)) {
            var arena_state = std.heap.ArenaAllocator.init(self.allocator);
            defer arena_state.deinit();
            const arena = arena_state.allocator();

            // 1. The request head. Between requests a kept-alive connection
            //    has keep_alive_timeout_ms for the next one; once that one's
            //    first byte came, request_timeout_ms for its head and body.
            if (!first) io.setDeadline(if (buffer.items.len == 0) self.options.keep_alive_timeout_ms else self.options.request_timeout_ms);
            const req: devtools_http.Request = blk: {
                while (true) {
                    const parsed = devtools_http.parseRequest(arena, buffer.items) catch return;
                    switch (parsed) {
                        .request => |r| {
                            // Parsed again from a copy: reading the body may
                            // move `buffer`, which the first parse points into.
                            const head = arena.dupe(u8, buffer.items[0..r.head_len]) catch return;
                            switch (devtools_http.parseRequest(arena, head) catch return) {
                                .request => |copy| break :blk copy,
                                else => return,
                            }
                        },
                        .bad => {
                            writeJsonResponse(io, arena, 400, null, "{\"jsonrpc\":\"2.0\",\"id\":null,\"error\":{\"code\":-32600,\"message\":\"Bad HTTP request\"}}", true) catch {};
                            return;
                        },
                        .incomplete => {
                            const was_empty = buffer.items.len == 0;
                            const n = (io.read(chunk, self.wake) catch return) orelse return;
                            if (n == 0) return;
                            buffer.appendSlice(self.allocator, chunk[0..n]) catch return;
                            if (!first and was_empty) io.setDeadline(self.options.request_timeout_ms);
                        },
                    }
                }
            };

            const close_after = req.headerHasToken("connection", "close");

            // 2. Who asks, from the head alone: nothing more is read for a
            //    request refused here, and a connection takes an
            //    authenticated slot only once its first request passed.
            if (self.refuse(io, arena, &req)) return;
            if (first) {
                if (!self.promote(io.conn)) {
                    writeResponse(io, arena, 503, "Service Unavailable", "application/json", "Retry-After: 1\r\n", "{\"jsonrpc\":\"2.0\",\"id\":null,\"error\":{\"code\":-32000,\"message\":\"Too many connections\"}}", true) catch {};
                    return;
                }
                first = false;
                io.setDeadline(self.options.request_timeout_ms);
            }

            // 3. The body (Content-Length or Transfer-Encoding: chunked).
            const body_result = readBody(self.allocator, arena, io, &buffer, chunk, &req) catch |err| {
                const status: u16 = if (err == error.BodyTooLarge) 413 else 400;
                writeJsonResponse(io, arena, status, null, "{\"jsonrpc\":\"2.0\",\"id\":null,\"error\":{\"code\":-32600,\"message\":\"Invalid or oversized request body\"}}", true) catch {};
                return;
            };

            // 4. Handling has no deadline - a tool runs as long as it runs;
            //    each write keeps its own.
            io.setDeadline(0);
            const outcome = self.handleHttpRequest(arena, io, &req, body_result.body, &conn_rate, close_after);

            // Consume this request's bytes from the pipelined buffer.
            const consumed = body_result.consumed;
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
        io: *ConnIo,
        buffer: *std.ArrayList(u8),
        chunk: []u8,
        req: *const devtools_http.Request,
    ) !BodyResult {
        const wake = io.server.wake;
        if (req.headerHasToken("transfer-encoding", "chunked")) {
            var decoded: std.ArrayList(u8) = .empty;
            var pos = req.head_len;
            while (true) {
                while (std.mem.indexOf(u8, buffer.items[pos..], "\r\n") == null) {
                    const n = (try io.read(chunk, wake)) orelse return error.ConnectionClosed;
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
                        const n = (try io.read(chunk, wake)) orelse return error.ConnectionClosed;
                        if (n == 0) return error.ConnectionClosed;
                        try buffer.appendSlice(allocator, chunk[0..n]);
                    }
                    pos += 2;
                    break;
                }
                if (decoded.items.len + chunk_len > max_body_bytes) return error.BodyTooLarge;
                while (buffer.items.len < pos + chunk_len + 2) {
                    const n = (try io.read(chunk, wake)) orelse return error.ConnectionClosed;
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
            const n = (try io.read(chunk, wake)) orelse return error.ConnectionClosed;
            if (n == 0) return error.ConnectionClosed;
            try buffer.appendSlice(allocator, chunk[0..n]);
        }
        // Copy body into arena before returning so buffer compaction cannot alias it.
        const body_copy = try arena.dupe(u8, buffer.items[req.head_len..needed]);
        return .{ .body = body_copy, .consumed = needed };
    }

    const ConnOutcome = enum { keep_alive, close };

    /// The checks a request's head must pass before anything else of it is
    /// read: Host, Origin, no token in the query, the bearer token. True:
    /// refused (answered; the connection closes).
    fn refuse(self: *HttpServer, io: *ConnIo, arena: Allocator, req: *const devtools_http.Request) bool {
        // Security 1: Host validation (DNS rebinding defense, matching devtools/http.zig).
        if (!devtools_http.hostIsSafe(req.header("host"))) {
            writeJsonResponse(io, arena, 403, null, "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32600,\"message\":\"" ++ devtools_http.host_refused_message ++ "\"}}", true) catch {};
            return true;
        }

        // Security 2: Origin validation (403 when present and not allowed).
        if (!devtools_http.originAllowed(req.header("origin"), self.options.allowed_origins)) {
            writeJsonResponse(io, arena, 403, null, "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32600,\"message\":\"Origin not allowed\"}}", true) catch {};
            return true;
        }

        // Security 3: Never accept bearer tokens in URI query string.
        if (queryHasToken(req.target)) {
            writeJsonResponse(io, arena, 400, null, "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32600,\"message\":\"Access tokens must not be included in the URI query string\"}}", true) catch {};
            return true;
        }

        // Security 4: Mandatory 256-bit pre-shared bearer token (loopback included).
        if (!verifyBearerToken(&self.bearer_token, req.header("authorization"))) {
            writeResponse(io, arena, 401, "Unauthorized", "application/json", "WWW-Authenticate: Bearer\r\n", "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32600,\"message\":\"Unauthorized\"}}", true) catch {};
            return true;
        }
        return false;
    }

    fn handleHttpRequest(
        self: *HttpServer,
        arena: Allocator,
        io: *ConnIo,
        req: *const devtools_http.Request,
        body: []const u8,
        conn_rate: *RateWindow,
        close_after: bool,
    ) ConnOutcome {
        // Endpoint check: single `/mcp` endpoint.
        if (!std.mem.eql(u8, req.path(), "/mcp")) {
            writeJsonResponse(io, arena, 404, null, "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32601,\"message\":\"Not found\"}}", close_after) catch return .close;
            return if (close_after) .close else .keep_alive;
        }

        // Security 5: Per-connection and per-token rate limiting (429).
        if (!conn_rate.allow(self.options.max_requests_per_connection, self.options.rate_limit_window_ms)) {
            writeResponse(io, arena, 429, "Too Many Requests", "application/json", "Retry-After: 1\r\n", "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32000,\"message\":\"Rate limit exceeded\"}}", close_after) catch return .close;
            return if (close_after) .close else .keep_alive;
        }
        std.Io.Threaded.mutexLockUncancelable(&self.state_mutex);
        const token_ok = self.token_rate.allow(self.options.max_requests_per_token, self.options.rate_limit_window_ms);
        std.Io.Threaded.mutexUnlock(&self.state_mutex);
        if (!token_ok) {
            writeResponse(io, arena, 429, "Too Many Requests", "application/json", "Retry-After: 1\r\n", "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32000,\"message\":\"Rate limit exceeded\"}}", close_after) catch return .close;
            return if (close_after) .close else .keep_alive;
        }

        // Dispatch by HTTP method.
        if (std.mem.eql(u8, req.method, "POST")) {
            return self.handlePost(arena, io, req, body, close_after);
        }
        if (std.mem.eql(u8, req.method, "GET")) {
            return self.handleGet(arena, io, req);
        }
        if (std.mem.eql(u8, req.method, "DELETE")) {
            return self.handleDelete(arena, io, req, close_after);
        }

        writeResponse(io, arena, 405, "Method Not Allowed", "application/json", "Allow: POST, GET, DELETE\r\n", "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32600,\"message\":\"Method Not Allowed\"}}", close_after) catch return .close;
        return if (close_after) .close else .keep_alive;
    }

    fn handlePost(
        self: *HttpServer,
        arena: Allocator,
        io: *ConnIo,
        req: *const devtools_http.Request,
        body: []const u8,
        close_after: bool,
    ) ConnOutcome {
        const parsed = json.parseFromSliceLeaky(json.Value, arena, body, .{}) catch {
            const err_body = protocol.errorMessage(arena, .null, .parse_error, "Parse error", null) catch return .close;
            writeJsonResponse(io, arena, 400, null, err_body, close_after) catch return .close;
            return if (close_after) .close else .keep_alive;
        };
        if (parsed != .object) {
            const err_body = protocol.errorMessage(arena, .null, .invalid_request, "Invalid Request", null) catch return .close;
            writeJsonResponse(io, arena, 400, null, err_body, close_after) catch return .close;
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
                writeJsonResponse(io, arena, 400, null, err_body, close_after) catch return .close;
                return if (close_after) .close else .keep_alive;
            };
            if (!std.mem.eql(u8, hv, mv)) {
                const err_body = protocol.errorMessage(arena, id, .header_mismatch, "MCP-Protocol-Version header does not match _meta", null) catch return .close;
                writeJsonResponse(io, arena, 400, null, err_body, close_after) catch return .close;
                return if (close_after) .close else .keep_alive;
            }
            if (!protocol.isSupported(mv)) {
                const err_body = protocol.unsupportedVersion(arena, id, mv) catch return .close;
                writeJsonResponse(io, arena, 400, null, err_body, close_after) catch return .close;
                return if (close_after) .close else .keep_alive;
            }
        } else if (header_version) |hv| {
            if (!protocol.isSupported(hv)) {
                const err_body = protocol.unsupportedVersion(arena, id, hv) catch return .close;
                writeJsonResponse(io, arena, 400, null, err_body, close_after) catch return .close;
                return if (close_after) .close else .keep_alive;
            }
            if (std.mem.eql(u8, hv, protocol.modern_version) and has_id and !(method_str != null and std.mem.eql(u8, method_str.?, "initialize"))) {
                const err_body = protocol.errorMessage(arena, id, .header_mismatch, "MCP-Protocol-Version 2026-07-28 requires matching _meta protocolVersion", null) catch return .close;
                writeJsonResponse(io, arena, 400, null, err_body, close_after) catch return .close;
                return if (close_after) .close else .keep_alive;
            }
        }

        // Validate Mcp-Method header when present (400 / -32020 on mismatch).
        if (req.header("mcp-method")) |hm| {
            const bm = method_str orelse "";
            if (!std.mem.eql(u8, hm, bm)) {
                const err_body = protocol.errorMessage(arena, id, .header_mismatch, "Mcp-Method header does not match request method", null) catch return .close;
                writeJsonResponse(io, arena, 400, null, err_body, close_after) catch return .close;
                return if (close_after) .close else .keep_alive;
            }
        }

        // Validate Mcp-Name header when present (including RFC =?base64?...?= decoding).
        if (req.header("mcp-name")) |hn| {
            const decoded_opt = decodeMcpHeaderValue(arena, hn) catch return .close;
            const decoded = decoded_opt orelse {
                const err_body = protocol.errorMessage(arena, id, .header_mismatch, "Malformed Mcp-Name header", null) catch return .close;
                writeJsonResponse(io, arena, 400, null, err_body, close_after) catch return .close;
                return if (close_after) .close else .keep_alive;
            };
            const body_name: []const u8 = if (params_obj) |p| (if (p.get("name")) |n| (if (n == .string) n.string else "") else "") else "";
            if (!std.mem.eql(u8, decoded, body_name)) {
                const err_body = protocol.errorMessage(arena, id, .header_mismatch, "Mcp-Name header does not match params.name", null) catch return .close;
                writeJsonResponse(io, arena, 400, null, err_body, close_after) catch return .close;
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
                writeEmptyResponse(io, arena, 202, "Accepted", null, close_after) catch return .close;
                return if (close_after) .close else .keep_alive;
            }
            const status = modernHttpStatus(arena, answer.?);
            writeJsonResponse(io, arena, status, null, answer.?, close_after) catch return .close;
            return if (close_after) .close else .keep_alive;
        }

        // Legacy 2025-11-25 era: initialize mints a session; subsequent requests
        // route by Mcp-Session-Id.
        const is_init = method_str != null and std.mem.eql(u8, method_str.?, "initialize") and has_id;
        if (is_init) {
            const session = HttpSession.create(self.allocator, self.mcp_server, platform.monotonicMillis()) catch return .close;
            std.Io.Threaded.mutexLockUncancelable(&self.mcp_mutex);
            const answer = session.proto.handle(arena, body) catch {
                std.Io.Threaded.mutexUnlock(&self.mcp_mutex);
                session.destroy();
                return .close;
            };
            std.Io.Threaded.mutexUnlock(&self.mcp_mutex);

            // The id is copied before listing: once listed, another
            // connection may end and free the session.
            const sid_copy = session.id;
            if (!self.listSession(session)) {
                session.destroy();
                writeResponse(io, arena, 503, "Service Unavailable", "application/json", "Retry-After: 1\r\n", "{\"jsonrpc\":\"2.0\",\"id\":null,\"error\":{\"code\":-32000,\"message\":\"Too many sessions\"}}", true) catch {};
                return .close;
            }

            writeJsonResponse(io, arena, 200, &sid_copy, answer orelse "{}", close_after) catch return .close;
            return if (close_after) .close else .keep_alive;
        }

        if (req.header("mcp-session-id")) |sid| {
            const session = self.acquireSession(sid) orelse {
                writeJsonResponse(io, arena, 404, null, "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32000,\"message\":\"Session not found\"}}", close_after) catch return .close;
                return if (close_after) .close else .keep_alive;
            };
            defer self.releaseSession(session);

            // The first tools/call waits for the client's roots (#getContext);
            // true: its answer goes on the SSE response that wait opened.
            const on_stream = if (has_id and method_str != null and std.mem.eql(u8, method_str.?, "tools/call"))
                (self.waitForRoots(arena, io, req, session, body) catch return .close)
            else
                false;

            std.Io.Threaded.mutexLockUncancelable(&self.mcp_mutex);
            const answer = session.proto.handle(arena, body) catch {
                std.Io.Threaded.mutexUnlock(&self.mcp_mutex);
                return .close;
            };
            std.Io.Threaded.mutexUnlock(&self.mcp_mutex);

            // A notification or client JSON-RPC response returns 202 Accepted;
            // any server-initiated request (such as roots/list) goes onto the
            // session's SSE queue.
            if (!has_id or method_str == null) {
                // A response the client sent: a call waiting for its roots
                // asks again.
                if (method_str == null) session.signalRoots();
                if (answer) |server_req| {
                    std.Io.Threaded.mutexLockUncancelable(&self.state_mutex);
                    if (!session.ended) {
                        if (self.allocator.dupe(u8, server_req)) |dup| session.queue(dup) else |_| {}
                    }
                    std.Io.Threaded.mutexUnlock(&self.state_mutex);
                }
                writeEmptyResponse(io, arena, 202, "Accepted", &session.id, close_after) catch return .close;
                return if (close_after) .close else .keep_alive;
            }
            if (on_stream) {
                // "The final JSON-RPC response SHOULD terminate the stream."
                self.writeSseEvent(io, arena, session, answer orelse "{}") catch {};
                return .close;
            }
            writeJsonResponse(io, arena, 200, &session.id, answer orelse "{}", close_after) catch return .close;
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
            writeEmptyResponse(io, arena, 202, "Accepted", null, close_after) catch return .close;
            return if (close_after) .close else .keep_alive;
        }
        writeJsonResponse(io, arena, 200, null, answer.?, close_after) catch return .close;
        return if (close_after) .close else .keep_alive;
    }

    /// McpServer #getContext over HTTP: before a session's tools/call runs,
    /// when the client offers roots and none came yet, ask for them once and
    /// wait - up to the roots timeout, the session's end or the server's stop
    /// - for the answer; a call that comes while that wait is on joins it
    /// (`this.#initialRoots ??= ...`). The request goes on this call's own
    /// SSE response when the client takes one (true: the response is that
    /// stream now, its head written), else on the session's GET stream. With
    /// neither, nothing reaches the client and the call does not wait.
    fn waitForRoots(self: *HttpServer, arena: Allocator, io: *ConnIo, req: *const devtools_http.Request, session: *HttpSession, body: []const u8) !bool {
        const on_own_stream = acceptsEventStream(req);
        if (!on_own_stream) {
            std.Io.Threaded.mutexLockUncancelable(&self.state_mutex);
            const has_stream = session.stream_open;
            std.Io.Threaded.mutexUnlock(&self.state_mutex);
            if (!has_stream) return false;
        }

        std.Io.Threaded.mutexLockUncancelable(&self.mcp_mutex);
        const joining = session.proto.waitingForRoots();
        const request_text = if (joining) null else session.proto.rootsWaitRequest(arena, body) catch |err| {
            std.Io.Threaded.mutexUnlock(&self.mcp_mutex);
            return err;
        };
        std.Io.Threaded.mutexUnlock(&self.mcp_mutex);
        if (!joining and request_text == null) return false;

        var streaming = false;
        if (request_text) |text| {
            if (on_own_stream) {
                const head = try std.fmt.allocPrint(arena, "HTTP/1.1 200 OK\r\n" ++
                    "Content-Type: text/event-stream\r\n" ++
                    "Cache-Control: no-cache\r\n" ++
                    "X-Accel-Buffering: no\r\n" ++
                    "Mcp-Session-Id: {s}\r\n" ++
                    "Connection: close\r\n\r\n", .{session.id});
                try io.writeAll(head);
                streaming = true;
                try self.writeSseEvent(io, arena, session, text);
            } else {
                const copy = try self.allocator.dupe(u8, text);
                std.Io.Threaded.mutexLockUncancelable(&self.state_mutex);
                if (session.ended) self.allocator.free(copy) else session.queue(copy);
                std.Io.Threaded.mutexUnlock(&self.state_mutex);
            }
        }

        const deadline = platform.monotonicMillis() + self.mcp_server.roots_timeout_ms;
        while (!self.stopping.load(.acquire)) {
            const seen = session.roots_signal.load(.acquire);
            std.Io.Threaded.mutexLockUncancelable(&self.mcp_mutex);
            const waiting = session.proto.waitingForRoots();
            std.Io.Threaded.mutexUnlock(&self.mcp_mutex);
            if (!waiting) break;
            std.Io.Threaded.mutexLockUncancelable(&self.state_mutex);
            const ended = session.ended;
            std.Io.Threaded.mutexUnlock(&self.state_mutex);
            if (ended) break;
            const left = deadline - platform.monotonicMillis();
            if (left <= 0) break;
            futexIo().futexWaitTimeout(u32, &session.roots_signal.raw, seen, .{ .duration = .{ .raw = .fromMilliseconds(left), .clock = .awake } }) catch {};
        }
        // Answered or not, no call waits again; calls that joined go on.
        std.Io.Threaded.mutexLockUncancelable(&self.mcp_mutex);
        session.proto.endRootsWait();
        std.Io.Threaded.mutexUnlock(&self.mcp_mutex);
        session.signalRoots();
        return streaming;
    }

    /// One SSE event carrying `message` (its id the session's next).
    fn writeSseEvent(self: *HttpServer, io: *ConnIo, arena: Allocator, session: *HttpSession, message: []const u8) !void {
        std.Io.Threaded.mutexLockUncancelable(&self.state_mutex);
        const event_id = session.next_event_id;
        session.next_event_id += 1;
        std.Io.Threaded.mutexUnlock(&self.state_mutex);
        const frame = try std.fmt.allocPrint(arena, "id: {d}\nevent: message\ndata: {s}\n\n", .{ event_id, message });
        try io.writeAll(frame);
    }

    fn handleGet(self: *HttpServer, arena: Allocator, io: *ConnIo, req: *const devtools_http.Request) ConnOutcome {
        const hv = req.header("mcp-protocol-version");
        const sid_opt = req.header("mcp-session-id");
        // Modern 2026-07-28 (or no legacy session): GET is 405 Method Not Allowed.
        if (sid_opt == null or (hv != null and std.mem.eql(u8, hv.?, protocol.modern_version))) {
            writeResponse(io, arena, 405, "Method Not Allowed", "application/json", "Allow: POST\r\n", "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32600,\"message\":\"Method Not Allowed\"}}", true) catch {};
            return .close;
        }

        const session = self.acquireSession(sid_opt.?) orelse {
            writeJsonResponse(io, arena, 404, null, "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32000,\"message\":\"Session not found\"}}", true) catch {};
            return .close;
        };
        defer self.releaseSession(session);

        // One standalone stream per session: the MCP TypeScript SDK's
        // StreamableHTTPServerTransport answers a second GET 409 Conflict
        // ("Conflict: Only one SSE stream is allowed per session"); the spec
        // lets a server send each message on one stream only.
        std.Io.Threaded.mutexLockUncancelable(&self.state_mutex);
        const taken = session.stream_open;
        session.stream_open = true;
        std.Io.Threaded.mutexUnlock(&self.state_mutex);
        if (taken) {
            writeResponse(io, arena, 409, "Conflict", "application/json", "", "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32000,\"message\":\"Conflict: Only one SSE stream is allowed per session\"},\"id\":null}", true) catch {};
            return .close;
        }
        defer {
            std.Io.Threaded.mutexLockUncancelable(&self.state_mutex);
            session.stream_open = false;
            if (session.stream_wake) |w| platform.devtoolsWakeClose(w);
            session.stream_wake = null;
            std.Io.Threaded.mutexUnlock(&self.state_mutex);
        }

        // 2025-11-25 SSE stream with immediate priming event.
        const head = std.fmt.allocPrint(arena, "HTTP/1.1 200 OK\r\n" ++
            "Content-Type: text/event-stream\r\n" ++
            "Cache-Control: no-cache\r\n" ++
            "X-Accel-Buffering: no\r\n" ++
            "Mcp-Session-Id: {s}\r\n" ++
            "Connection: close\r\n\r\n" ++
            "id: 1\ndata:\n\n", .{session.id}) catch return .close;
        io.writeAll(head) catch return .close;

        // Send what is queued; then wait for the peer's end or the wake a
        // queued message, DELETE, the session's end or the server's stop
        // gives - a fresh wake each time, as a fired one stays fired.
        var taken_msgs: std.ArrayList([]u8) = .empty;
        defer {
            for (taken_msgs.items) |m| self.allocator.free(m);
            taken_msgs.deinit(self.allocator);
        }
        var scratch: [256]u8 = undefined;
        while (true) {
            std.Io.Threaded.mutexLockUncancelable(&self.state_mutex);
            if (session.ended or self.stopping.load(.acquire)) {
                std.Io.Threaded.mutexUnlock(&self.state_mutex);
                return .close;
            }
            var first_id: u64 = 0;
            var wake: ?platform.DevtoolsWake = null;
            if (session.sse_queue.items.len > 0) {
                std.mem.swap(std.ArrayList([]u8), &taken_msgs, &session.sse_queue);
                first_id = session.next_event_id;
                session.next_event_id += taken_msgs.items.len;
            } else {
                if (session.stream_wake == null) session.stream_wake = platform.devtoolsWakeNew() catch null;
                wake = session.stream_wake;
            }
            std.Io.Threaded.mutexUnlock(&self.state_mutex);

            if (taken_msgs.items.len > 0) {
                for (taken_msgs.items, 0..) |msg, i| {
                    const frame = std.fmt.allocPrint(arena, "id: {d}\nevent: message\ndata: {s}\n\n", .{ first_id + i, msg }) catch return .close;
                    io.writeAll(frame) catch return .close;
                }
                for (taken_msgs.items) |m| self.allocator.free(m);
                taken_msgs.clearRetainingCapacity();
                continue;
            }
            const w = wake orelse return .close;
            const read_res = io.read(&scratch, w) catch return .close;
            if (read_res) |n| {
                // 0: the peer closed the stream; anything else it sends is
                // not for this stream.
                if (n == 0) return .close;
            } else {
                std.Io.Threaded.mutexLockUncancelable(&self.state_mutex);
                if (session.stream_wake) |fired| platform.devtoolsWakeClose(fired);
                session.stream_wake = null;
                std.Io.Threaded.mutexUnlock(&self.state_mutex);
            }
        }
    }

    fn handleDelete(self: *HttpServer, arena: Allocator, io: *ConnIo, req: *const devtools_http.Request, close_after: bool) ConnOutcome {
        const hv = req.header("mcp-protocol-version");
        const sid_opt = req.header("mcp-session-id");
        // Modern 2026-07-28 (or no legacy session): DELETE is 405 Method Not Allowed.
        if (sid_opt == null or (hv != null and std.mem.eql(u8, hv.?, protocol.modern_version))) {
            writeResponse(io, arena, 405, "Method Not Allowed", "application/json", "Allow: POST\r\n", "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32600,\"message\":\"Method Not Allowed\"}}", close_after) catch return .close;
            return if (close_after) .close else .keep_alive;
        }

        std.Io.Threaded.mutexLockUncancelable(&self.state_mutex);
        var found = false;
        for (self.sessions.items, 0..) |s, i| {
            if (!s.ended and std.mem.eql(u8, &s.id, sid_opt.?)) {
                self.unlistAt(i);
                found = true;
                break;
            }
        }
        std.Io.Threaded.mutexUnlock(&self.state_mutex);

        if (!found) {
            writeJsonResponse(io, arena, 404, null, "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32000,\"message\":\"Session not found\"}}", close_after) catch return .close;
            return if (close_after) .close else .keep_alive;
        }
        writeEmptyResponse(io, arena, 200, "OK", null, close_after) catch return .close;
        return if (close_after) .close else .keep_alive;
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

    fn writeJsonResponse(io: *ConnIo, arena: Allocator, status: u16, session_id: ?[]const u8, body: []const u8, close_conn: bool) !void {
        const extra = if (session_id) |sid| try std.fmt.allocPrint(arena, "Mcp-Session-Id: {s}\r\n", .{sid}) else "";
        try writeResponse(io, arena, status, statusReason(status), "application/json", extra, body, close_conn);
    }

    fn writeEmptyResponse(io: *ConnIo, arena: Allocator, status: u16, reason: []const u8, session_id: ?[]const u8, close_conn: bool) !void {
        const extra = if (session_id) |sid| try std.fmt.allocPrint(arena, "Mcp-Session-Id: {s}\r\n", .{sid}) else "";
        const raw = try std.fmt.allocPrint(arena, "HTTP/1.1 {d} {s}\r\n{s}Content-Length: 0\r\n{s}\r\n", .{
            status,
            reason,
            extra,
            try connectionHeaders(io, arena, close_conn),
        });
        try io.writeAll(raw);
    }

    fn writeResponse(
        io: *ConnIo,
        arena: Allocator,
        status: u16,
        reason: []const u8,
        content_type: []const u8,
        extra_headers: []const u8,
        body: []const u8,
        close_conn: bool,
    ) !void {
        const raw = try std.fmt.allocPrint(arena, "HTTP/1.1 {d} {s}\r\nContent-Type: {s}\r\n{s}Content-Length: {d}\r\n{s}\r\n{s}", .{
            status,
            reason,
            content_type,
            extra_headers,
            body.len,
            try connectionHeaders(io, arena, close_conn),
            body,
        });
        try io.writeAll(raw);
    }

    /// `Connection: close`, or `Connection: keep-alive` and - when kept-alive
    /// connections time out - `Keep-Alive: timeout=<s>`, the seconds floored,
    /// as Node's http.Server writes it.
    fn connectionHeaders(io: *ConnIo, arena: Allocator, close_conn: bool) ![]const u8 {
        if (close_conn) return "Connection: close\r\n";
        const ms = io.server.options.keep_alive_timeout_ms;
        if (ms == 0) return "Connection: keep-alive\r\n";
        return std.fmt.allocPrint(arena, "Connection: keep-alive\r\nKeep-Alive: timeout={d}\r\n", .{ms / std.time.ms_per_s});
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
            409 => "Conflict",
            413 => "Payload Too Large",
            429 => "Too Many Requests",
            503 => "Service Unavailable",
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
