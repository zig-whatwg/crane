//! A Browser's network context: what every request of one Browser - its
//! windows', its frames' and its workers', on whichever thread - shares with
//! the others and with no other Browser's (docs/instances.md: the Browser
//! owns "the HTTP cache and network"). Chromium's name for it:
//! network::NetworkContext, one per profile's storage partition, owning its
//! connection pools, host resolver cache, proxy settings and TLS
//! configuration.
//!
//! It holds:
//! - the connection share: curl's connection cache and DNS cache (a curl
//!   share handle), which every transfer of the Browser joins - so the
//!   Browser reuses its own connections and never another Browser's, which
//!   would let one profile observe another's;
//! - its options (BrowserConfig): the user agent string - Fetch's
//!   "environment default `User-Agent` value" its requests send and
//!   navigator.userAgent reads -, its proxy, and its TLS options
//!   (accept_insecure_certs, a CA bundle it trusts);
//! - WebSocket's CONNECTING gate (RFC 6455 4.1 step 2: "no more than one
//!   connection in a CONNECTING state" to a host and port - per client, and a
//!   Browser is the client, its workers included);
//! - the HTTP cache (`http_cache`, fetch/cache/http_cache.zig): every
//!   partition's stored responses, in memory, locked by itself - Chromium's
//!   NetworkContext owns its net::HttpCache the same way.
//!
//! A BrowserScope supplement (runtime.BrowserScope; `init(allocator)`,
//! `deinit`), made and `configure`d by Browser.init before any realm exists,
//! reached from a realm through dom.browser_state.networkOf. A request carries
//! its client's (`InternalRequest.network`), as it carries the cookie jar; a
//! request with none - a unit test's - uses the defaults and shares nothing.
//!
//! Reached from every thread of the Browser: the options are fixed by
//! `configure` before any request, the share is made once under `mutex` and
//! locked by curl through its lock callbacks, and the gate is under `mutex`.
//!
//! What stays process-wide is curl's global initialization (curl_backend's
//! reference count), which crane.Process holds from its start to its end: a
//! context takes none of it.
//!
//! The connection share is the platform's (src/platform/kit/curl/share.zig):
//! curl's share handle with its own locks, which this context makes on the
//! first transfer that needs it and ends with itself - the way the platform
//! protocol's BrowserPlatform will hold the whole network once transfers move
//! behind it (docs/platform-protocol.md 3.3). This file names no curl.

const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.network_context);
const backend = @import("backend.zig");
const user_agent = @import("../internal/user_agent.zig");
const Share = @import("kit_curl_share").Share;
const TrustStore = @import("kit_curl_share").trust.Store;

pub const CertVerifyOptions = backend.CertVerifyOptions;

pub const NetworkContext = struct {
    allocator: Allocator,
    /// Guards the share's making and the CONNECTING gate.
    mutex: std.Io.Mutex = .init,
    /// The connection and DNS cache every transfer of the Browser joins,
    /// with locks of its own (kit/curl): made on first use
    /// (`connectionShare`), null until then or if curl could not make one
    /// (then nothing is pooled).
    share: ?*Share = null,
    /// Whether the share was tried: it is made once.
    share_tried: bool = false,
    /// What `configure` set. OWNED copies.
    tls: CertVerifyOptions = .{},
    /// The certificates the Browser's connections verify against: the system
    /// roots and `tls.ca_bundle_path`, parsed the first time a connection asks
    /// (kit/curl trust.zig) - once for the Browser, not once per handshake.
    trust: TrustStore,
    /// WebSocket's CONNECTING gate: one holder per host and port.
    connecting: ConnectingGate = .{},
    /// HTTP/1.x connections per destination: at most `max_connections_per_
    /// host` transfers in flight to one scheme, host and port, Browser-wide.
    slots: ConnectionSlots = .{},
    /// The user agent string `configure` set (OWNED); null: the default.
    user_agent: ?[]u8 = null,
    /// Where the Browser's requests go (`configure`; OWNED strings).
    proxy: Proxy = .system,
    /// Browser-owned Fetch permission entries, independently locked.
    preflight_cache: @import("../cors/preflight_cache.zig").PreflightCache,
    /// The Browser's HTTP cache: made by `configure` (BrowserConfig
    /// .http_cache), fixed after, so read on any thread without a lock; the
    /// cache locks itself. Null: none (a context a test makes, or a cap of
    /// 0) - every request bypasses it.
    http_cache: ?*HttpCache = null,
    auth_entries: @import("auth_entries.zig").AuthEntries,
    /// What clears the Browser's site data for a response's
    /// `Clear-Site-Data` header (Clear Site Data 4.2; Chromium's
    /// NetworkContextClient::OnClearSiteData): set by the Browser before any
    /// realm exists, fixed after - so read on any thread without a lock.
    /// Null: nothing is cleared (a context a test makes).
    site_data: ?SiteDataClearer = null,

    pub const SiteDataClearer = @import("../algorithms/clear_site_data.zig").Clearer;

    /// The options a Browser gives its network (BrowserConfig).
    pub const Options = struct {
        /// A certificate authority bundle the Browser trusts besides the
        /// system's - the WPT runner's cacert.pem. Copied.
        ca_bundle_path: ?[]const u8 = null,
        /// The user agent string: the `User-Agent` its requests send and
        /// navigator.userAgent. Null: the default (fetch.internal.user_agent).
        /// Copied.
        user_agent: ?[]const u8 = null,
        /// Where its requests go. Copied.
        proxy: Proxy = .system,
        /// WebDriver's acceptInsecureCerts: certificates are not verified
        /// (neither the chain nor the host name).
        accept_insecure_certs: bool = false,
        /// The HTTP cache's caps; a max_bytes of 0 makes none.
        http_cache: HttpCacheConfig = .{},
    };

    pub const HttpCache = @import("../cache/http_cache.zig").HttpCache;
    pub const HttpCacheConfig = @import("../cache/http_cache.zig").Config;

    /// An explicit proxy configuration (docs/instances.md: explicit
    /// proxies only for 0.1; a PAC file and auto-detection are refused by
    /// Browser.init). WebDriver's proxyType "system", "direct" and "manual".
    pub const Proxy = union(enum) {
        /// What curl takes from the environment (http_proxy, https_proxy,
        /// no_proxy) - the process's own proxy settings. The default.
        system,
        /// No proxy, whatever the environment says.
        direct,
        /// A proxy per scheme, and the hosts that bypass it.
        manual: Manual,

        pub const Manual = struct {
            /// For http: and ws: URLs, e.g. "http://proxy.example:8080";
            /// null: such requests go direct.
            http: ?[]const u8 = null,
            /// For https: and wss: URLs; null: they go direct.
            https: ?[]const u8 = null,
            /// Comma-separated hosts that bypass the proxy (curl's NOPROXY).
            no_proxy: ?[]const u8 = null,
        };
    };

    pub fn init(allocator: Allocator) NetworkContext {
        return .{ .allocator = allocator, .preflight_cache = .init(allocator), .auth_entries = .init(allocator), .trust = .init(allocator) };
    }

    /// The end, with the Browser's scope - after every transfer of the
    /// Browser has ended (every agent's scheduler has closed): the share
    /// closes the connections it kept, an HTTP/2 one with a GOAWAY. A
    /// connection closed only by the process exiting ends with a bare FIN,
    /// and WPT's h2 server (:9000) spins a thread forever on each of those.
    pub fn deinit(self: *NetworkContext) void {
        // The stored responses go now; a body writer still collecting keeps
        // the cache's core until it ends, and stores nothing.
        if (self.http_cache) |cache| cache.close();
        self.http_cache = null;
        self.preflight_cache.deinit();
        self.auth_entries.deinit();
        if (self.share) |share| share.destroy();
        self.share = null;
        self.share_tried = false;
        // After the share closed the connections it kept: no connection of
        // the Browser reads the chain any more.
        self.trust.deinit();
        self.connecting.deinit(self.allocator);
        self.slots.deinit(self.allocator);
        if (self.tls.ca_bundle_path) |path| self.allocator.free(path);
        self.tls = .{};
        if (self.user_agent) |value| self.allocator.free(value);
        self.user_agent = null;
        self.freeProxy();
    }

    fn freeProxy(self: *NetworkContext) void {
        switch (self.proxy) {
            .manual => |manual| for ([_]?[]const u8{ manual.http, manual.https, manual.no_proxy }) |owned| {
                if (owned) |value| self.allocator.free(value);
            },
            else => {},
        }
        self.proxy = .system;
    }

    fn dupeOptional(self: *NetworkContext, value: ?[]const u8) Allocator.Error!?[]const u8 {
        return if (value) |v| try self.allocator.dupe(u8, v) else null;
    }

    /// Set the Browser's options, once, before any request.
    pub fn configure(self: *NetworkContext, options: Options) Allocator.Error!void {
        if (options.ca_bundle_path) |path| {
            const copy = try self.allocator.dupe(u8, path);
            if (self.tls.ca_bundle_path) |old| self.allocator.free(old);
            self.tls.ca_bundle_path = copy;
        }
        if (options.user_agent) |value| {
            const copy = try self.allocator.dupe(u8, value);
            if (self.user_agent) |old| self.allocator.free(old);
            self.user_agent = copy;
        }
        const proxy: Proxy = switch (options.proxy) {
            .system => .system,
            .direct => .direct,
            .manual => |manual| blk: {
                const http = try self.dupeOptional(manual.http);
                errdefer if (http) |v| self.allocator.free(v);
                const https = try self.dupeOptional(manual.https);
                errdefer if (https) |v| self.allocator.free(v);
                const no_proxy = try self.dupeOptional(manual.no_proxy);
                break :blk .{ .manual = .{ .http = http, .https = https, .no_proxy = no_proxy } };
            },
        };
        self.freeProxy();
        self.proxy = proxy;
        // acceptInsecureCerts: neither the certificate chain nor the host
        // name is checked (curl's VERIFYPEER and VERIFYHOST off).
        if (options.accept_insecure_certs) {
            self.tls.verify_peer = false;
            self.tls.verify_host = false;
        }
        // The HTTP cache, once, before any request.
        if (self.http_cache == null and options.http_cache.max_bytes > 0) {
            self.http_cache = try HttpCache.create(self.allocator, options.http_cache);
        }
    }

    /// The Browser's user agent string: Fetch's "environment default
    /// `User-Agent` value" for every environment settings object of the
    /// Browser - the `User-Agent` its requests send, navigator.userAgent in
    /// its windows and workers. BORROWED for the Browser's life.
    pub fn userAgent(self: *const NetworkContext) []const u8 {
        return self.user_agent orelse user_agent.default_user_agent;
    }

    /// HTML navigator.appVersion for this Browser's user agent string.
    pub fn appVersion(self: *const NetworkContext) []const u8 {
        return user_agent.appVersionOf(self.userAgent());
    }

    /// The proxy a request to `url` goes through: null for the system's
    /// (curl reads the environment), a proxy with an empty URL for none -
    /// curl's way to say "direct, whatever the environment says". Borrowed
    /// for the Browser's life.
    pub fn proxyFor(self: *const NetworkContext, url: []const u8) ?backend.ProxyConfig {
        return switch (self.proxy) {
            .system => null,
            .direct => .{ .url = "" },
            .manual => |manual| blk: {
                const secure = std.ascii.startsWithIgnoreCase(url, "https:") or std.ascii.startsWithIgnoreCase(url, "wss:");
                const chosen = if (secure) manual.https else manual.http;
                break :blk .{ .url = chosen orelse "", .no_proxy = manual.no_proxy };
            },
        };
    }

    /// The certificate options a request of this Browser is verified with.
    pub fn certOptions(self: *NetworkContext) CertVerifyOptions {
        var options = self.tls;
        options.trust = &self.trust;
        return options;
    }

    /// The connection share a transfer of this Browser joins, made on first
    /// use; null when curl cannot make one. curl's global state is
    /// initialized first (curl_backend's Transfer.create does).
    pub fn connectionShare(self: *NetworkContext) ?*Share {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        if (self.share_tried) return self.share;
        self.share_tried = true;
        self.share = Share.create(self.allocator) catch null;
        // No share: each transfer opens its own connection, which exhausts
        // sockets after roughly 25 requests.
        if (self.share == null) log.warn("no connection share; connections will not be pooled", .{});
        return self.share;
    }

    /// Take `key` (a host and port) for `holder`'s handshake, or report that
    /// another connection's handshake to it is in flight.
    pub fn tryAcquireConnecting(self: *NetworkContext, key: []const u8, holder: *const anyopaque) Allocator.Error!bool {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        return self.connecting.tryAcquire(self.allocator, key, holder);
    }

    /// Let go of whatever `holder` holds of the gate.
    pub fn releaseConnecting(self: *NetworkContext, holder: *const anyopaque) void {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        self.connecting.release(holder);
    }

    /// Take one of `destination`'s connection slots for `holder` (a
    /// transfer): true when it may start now - it got a slot, or the
    /// destination multiplexes and needs none - false when it must wait for
    /// one. `destination` is `destinationOf` a request URL.
    pub fn tryTakeConnectionSlot(self: *NetworkContext, destination: []const u8, holder: *const anyopaque) Allocator.Error!bool {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        return self.slots.tryTake(self.allocator, destination, holder);
    }

    /// Give back the slot `holder` took, if it took one.
    pub fn releaseConnectionSlot(self: *NetworkContext, holder: *const anyopaque) void {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        self.slots.release(holder);
    }

    /// `destination` answered over HTTP/2: its requests share one
    /// connection from now on and take no slots.
    pub fn noteMultiplexed(self: *NetworkContext, destination: []const u8) Allocator.Error!void {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        return self.slots.noteMultiplexed(self.allocator, destination);
    }
};

/// How many HTTP/1.x connections a Browser opens to one destination at once.
/// Every browser has six: Chromium, g_max_sockets_per_group's kNormal entry
/// ("Default to allow up to 6 connections per host",
/// net/socket/client_socket_pool_manager.cc); Firefox,
/// network.http.max-persistent-connections-per-server (6, modules/libpref/
/// init/all.js); Safari, CFNetwork's NSURLSessionConfiguration
/// HTTPMaximumConnectionsPerHost ("The default value is 6 in macOS").
/// HTTP/1.1 itself sets no number any more (RFC 9112 9.4: "A client ought to
/// limit the number of simultaneous open connections"), so golden rule 2
/// decides: the browsers' six. Without it a page with 34 XHRs opened 34
/// connections at once, and WPT's server, under a sweep's several runners,
/// reset connections past its listen queue - xhr/send-redirect.htm failed 35
/// of 150 runs under 6x load (lane flaky4). More transfers than that wait,
/// in order, for one to end; none fails.
///
/// Two kinds of connection do not count, as in Chromium:
/// - a WebSocket's: Chromium keeps them in a pool of their own
///   (g_max_sockets_per_group's kWebSocket entry, 255: "WebSocket connections
///   are long-lived, and should be treated differently"), so the gate they
///   pass is RFC 6455's one-CONNECTING-per-host (`ConnectingGate`) alone;
/// - a synchronous XMLHttpRequest's: its transfer (LibcurlBackend.send)
///   blocks its agent's thread until it ends, and with it the event loop
///   that would finish the agent's other transfers and free their slots -
///   waiting for a slot there would wait forever.
pub const max_connections_per_host = 6;

/// The destination a connection is for - "scheme://host:port", the port
/// explicit - from a request URL (with no userinfo: buildNetworkRequest
/// strips it). Chromium groups its sockets by scheme, host and port the same
/// way (ClientSocketPool::GroupId). `buffer` holds the result; a URL whose
/// destination does not fit gives null, and is not limited.
pub fn destinationOf(buffer: *[max_host_key]u8, url: []const u8) ?[]const u8 {
    const scheme_end = std.mem.indexOf(u8, url, "://") orelse return null;
    const scheme = url[0..scheme_end];
    const rest = url[scheme_end + 3 ..];
    const authority_end = std.mem.indexOfAny(u8, rest, "/?#") orelse rest.len;
    const authority = rest[0..authority_end];
    if (authority.len == 0) return null;
    // A port after the host ("]" ends an IPv6 literal, whose colons are not
    // ports).
    const host_end = if (std.mem.lastIndexOfScalar(u8, authority, ':')) |colon|
        (if (std.mem.lastIndexOfScalar(u8, authority, ']')) |bracket| (if (colon > bracket) colon else authority.len) else colon)
    else
        authority.len;
    const host = authority[0..host_end];
    const port: []const u8 = if (host_end < authority.len) authority[host_end + 1 ..] else if (std.ascii.eqlIgnoreCase(scheme, "https")) "443" else if (std.ascii.eqlIgnoreCase(scheme, "http")) "80" else return null;
    return std.fmt.bufPrint(buffer, "{s}://{s}:{s}", .{ scheme, host, port }) catch null;
}

/// The connection slots of a Browser's destinations (`max_connections_per_
/// host` each) and the destinations that multiplex. NOT locked: the
/// context's mutex guards it.
pub const ConnectionSlots = struct {
    taken: std.ArrayListUnmanaged(Slot) = .empty,
    /// Destinations that answered over HTTP/2.
    multiplexed: std.ArrayListUnmanaged(Key) = .empty,

    const Key = struct {
        bytes: [max_host_key]u8,
        len: usize,

        fn of(destination: []const u8) Key {
            var key: Key = .{ .bytes = undefined, .len = @min(destination.len, max_host_key) };
            @memcpy(key.bytes[0..key.len], destination[0..key.len]);
            return key;
        }

        fn is(self: *const Key, destination: []const u8) bool {
            return std.mem.eql(u8, self.bytes[0..self.len], destination);
        }
    };

    const Slot = struct {
        key: Key,
        holder: *const anyopaque,
    };

    /// A slot of `destination` for `holder` if one is free (or none is
    /// needed); `holder` asking again keeps the one it has.
    pub fn tryTake(self: *ConnectionSlots, allocator: Allocator, destination: []const u8, holder: *const anyopaque) Allocator.Error!bool {
        for (self.multiplexed.items) |*key| if (key.is(destination)) return true;
        var used: usize = 0;
        for (self.taken.items) |*slot| {
            if (!slot.key.is(destination)) continue;
            if (slot.holder == holder) return true;
            used += 1;
        }
        if (used >= max_connections_per_host) return false;
        try self.taken.append(allocator, .{ .key = .of(destination), .holder = holder });
        return true;
    }

    /// Give back `holder`'s slot, if it has one.
    pub fn release(self: *ConnectionSlots, holder: *const anyopaque) void {
        for (self.taken.items, 0..) |slot, i| {
            if (slot.holder != holder) continue;
            _ = self.taken.orderedRemove(i);
            return;
        }
    }

    pub fn noteMultiplexed(self: *ConnectionSlots, allocator: Allocator, destination: []const u8) Allocator.Error!void {
        for (self.multiplexed.items) |*key| if (key.is(destination)) return;
        try self.multiplexed.append(allocator, .of(destination));
    }

    pub fn deinit(self: *ConnectionSlots, allocator: Allocator) void {
        self.taken.deinit(allocator);
        self.multiplexed.deinit(allocator);
        self.* = .{};
    }
};

/// The longest host-and-port key the gate keeps.
pub const max_host_key = 300;

/// RFC 6455 § 4.1 step 2, which WebSockets § 2.1 keeps: "If the client already
/// has a WebSocket connection to the remote host ... identified by /host/ and
/// port /port/ pair ..., the client MUST wait until that connection has been
/// established or for that connection to have failed. There MUST be no more
/// than one connection in a CONNECTING state."
///
/// One holder per key: the connection whose handshake is in flight. Every
/// other connection to that host and port waits, handshake unstarted, until
/// the holder releases - websockets/constructor/014.html times two sockets to a
/// server that stalls each handshake for two seconds. When the handshake
/// blocked the whole event loop the rule held by accident. NOT locked: the
/// context's mutex guards it.
pub const ConnectingGate = struct {
    entries: std.ArrayListUnmanaged(Entry) = .empty,

    const Entry = struct {
        key: [max_host_key]u8,
        len: usize,
        holder: *const anyopaque,
    };

    /// Take `key` for `holder`, or report that someone else holds it.
    pub fn tryAcquire(self: *ConnectingGate, allocator: Allocator, key: []const u8, holder: *const anyopaque) Allocator.Error!bool {
        for (self.entries.items) |e| {
            if (std.mem.eql(u8, e.key[0..e.len], key)) return e.holder == holder;
        }
        var entry: Entry = .{ .key = undefined, .len = @min(key.len, max_host_key), .holder = holder };
        @memcpy(entry.key[0..entry.len], key[0..entry.len]);
        try self.entries.append(allocator, entry);
        return true;
    }

    /// Let go of whatever `holder` holds.
    pub fn release(self: *ConnectingGate, holder: *const anyopaque) void {
        var i: usize = 0;
        while (i < self.entries.items.len) {
            if (self.entries.items[i].holder == holder) {
                _ = self.entries.swapRemove(i);
            } else i += 1;
        }
    }

    pub fn deinit(self: *ConnectingGate, allocator: Allocator) void {
        self.entries.deinit(allocator);
        self.* = .{};
    }
};

test "six connection slots per destination; the seventh waits for a release" {
    var context = NetworkContext.init(std.testing.allocator);
    defer context.deinit();
    var holders: [8]u8 = undefined;
    for (0..max_connections_per_host) |i| try std.testing.expect(try context.tryTakeConnectionSlot("http://a.test:80", &holders[i]));
    try std.testing.expect(!try context.tryTakeConnectionSlot("http://a.test:80", &holders[6]));
    // A holder asking again keeps its slot; another destination has its own.
    try std.testing.expect(try context.tryTakeConnectionSlot("http://a.test:80", &holders[0]));
    try std.testing.expect(try context.tryTakeConnectionSlot("https://a.test:443", &holders[7]));
    context.releaseConnectionSlot(&holders[2]);
    try std.testing.expect(try context.tryTakeConnectionSlot("http://a.test:80", &holders[6]));
    try std.testing.expect(!try context.tryTakeConnectionSlot("http://a.test:80", &holders[2]));
    // Releasing what holds no slot changes nothing.
    var stranger: u8 = 0;
    context.releaseConnectionSlot(&stranger);
    try std.testing.expect(!try context.tryTakeConnectionSlot("http://a.test:80", &holders[2]));
}

test "a destination that multiplexes takes no connection slots" {
    var context = NetworkContext.init(std.testing.allocator);
    defer context.deinit();
    var holders: [8]u8 = undefined;
    for (0..max_connections_per_host) |i| try std.testing.expect(try context.tryTakeConnectionSlot("https://h2.test:9000", &holders[i]));
    try std.testing.expect(!try context.tryTakeConnectionSlot("https://h2.test:9000", &holders[6]));
    try context.noteMultiplexed("https://h2.test:9000");
    try std.testing.expect(try context.tryTakeConnectionSlot("https://h2.test:9000", &holders[6]));
    try std.testing.expect(try context.tryTakeConnectionSlot("https://h2.test:9000", &holders[7]));
}

test "a request URL's destination is its scheme, host and port" {
    var buffer: [max_host_key]u8 = undefined;
    try std.testing.expectEqualStrings("http://web-platform.test:8000", destinationOf(&buffer, "http://web-platform.test:8000/xhr/resources/redirect.py?code=301").?);
    try std.testing.expectEqualStrings("https://a.test:443", destinationOf(&buffer, "https://a.test/b").?);
    try std.testing.expectEqualStrings("http://a.test:80", destinationOf(&buffer, "http://a.test?q").?);
    try std.testing.expectEqualStrings("http://[::1]:8080", destinationOf(&buffer, "http://[::1]:8080/").?);
    try std.testing.expectEqualStrings("http://[::1]:80", destinationOf(&buffer, "http://[::1]/x").?);
    try std.testing.expectEqual(@as(?[]const u8, null), destinationOf(&buffer, "data:text/plain,x"));
    try std.testing.expectEqual(@as(?[]const u8, null), destinationOf(&buffer, "http:///x"));
}

test "the CONNECTING gate keeps one holder per host and port" {
    var context = NetworkContext.init(std.testing.allocator);
    defer context.deinit();
    var a: u8 = 0;
    var b: u8 = 0;
    try std.testing.expect(try context.tryAcquireConnecting("example.test:443", &a));
    try std.testing.expect(try context.tryAcquireConnecting("example.test:443", &a));
    try std.testing.expect(!try context.tryAcquireConnecting("example.test:443", &b));
    try std.testing.expect(try context.tryAcquireConnecting("other.test:443", &b));
    context.releaseConnecting(&a);
    try std.testing.expect(try context.tryAcquireConnecting("example.test:443", &b));
}

test "configure copies the trust it is given" {
    var context = NetworkContext.init(std.testing.allocator);
    defer context.deinit();
    var path = "/certs/ca.pem".*;
    try context.configure(.{ .ca_bundle_path = &path });
    path[1] = 'X';
    try std.testing.expectEqualStrings("/certs/ca.pem", context.certOptions().ca_bundle_path.?);
    try std.testing.expect(context.certOptions().verify_peer);
}

test "a manual proxy per scheme, none for a scheme it names none, the system's by default" {
    var context = NetworkContext.init(std.testing.allocator);
    defer context.deinit();
    try std.testing.expect(context.proxyFor("http://example.test/") == null);
    try context.configure(.{ .proxy = .{ .manual = .{ .http = "http://proxy.test:3128", .no_proxy = "localhost,.internal" } } });
    const http = context.proxyFor("http://example.test/").?;
    try std.testing.expectEqualStrings("http://proxy.test:3128", http.url);
    try std.testing.expectEqualStrings("localhost,.internal", http.no_proxy.?);
    try std.testing.expectEqualStrings("http://proxy.test:3128", context.proxyFor("ws://example.test/").?.url);
    // No https proxy: an https request goes direct.
    try std.testing.expectEqualStrings("", context.proxyFor("https://example.test/").?.url);
    try context.configure(.{ .proxy = .direct });
    try std.testing.expectEqualStrings("", context.proxyFor("http://example.test/").?.url);
}

test "the user agent string and insecure certificates are the Browser's options" {
    var context = NetworkContext.init(std.testing.allocator);
    defer context.deinit();
    try std.testing.expectEqualStrings(user_agent.default_user_agent, context.userAgent());
    try context.configure(.{ .user_agent = "Mozilla/5.0 (Test) Crane/1", .accept_insecure_certs = true });
    try std.testing.expectEqualStrings("Mozilla/5.0 (Test) Crane/1", context.userAgent());
    try std.testing.expectEqualStrings("5.0 (Test) Crane/1", context.appVersion());
    try std.testing.expect(!context.certOptions().verify_peer);
    try std.testing.expect(!context.certOptions().verify_host);
}
