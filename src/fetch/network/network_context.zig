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
//! - the TLS options its transfers verify certificates with;
//! - WebSocket's CONNECTING gate (RFC 6455 4.1 step 2: "no more than one
//!   connection in a CONNECTING state" to a host and port - per client, and a
//!   Browser is the client, its workers included).
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
const Share = @import("kit_curl_share").Share;

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
    /// WebSocket's CONNECTING gate: one holder per host and port.
    connecting: ConnectingGate = .{},

    /// The options a Browser gives its network (BrowserConfig).
    pub const Options = struct {
        /// A certificate authority bundle the Browser trusts besides the
        /// system's - the WPT runner's cacert.pem. Copied.
        ca_bundle_path: ?[]const u8 = null,
    };

    pub fn init(allocator: Allocator) NetworkContext {
        return .{ .allocator = allocator };
    }

    /// The end, with the Browser's scope - after every transfer of the
    /// Browser has ended (every agent's scheduler has closed): the share
    /// closes the connections it kept, an HTTP/2 one with a GOAWAY. A
    /// connection closed only by the process exiting ends with a bare FIN,
    /// and WPT's h2 server (:9000) spins a thread forever on each of those.
    pub fn deinit(self: *NetworkContext) void {
        if (self.share) |share| share.destroy();
        self.share = null;
        self.share_tried = false;
        self.connecting.deinit(self.allocator);
        if (self.tls.ca_bundle_path) |path| self.allocator.free(path);
        self.tls = .{};
    }

    /// Set the Browser's options, once, before any request.
    pub fn configure(self: *NetworkContext, options: Options) Allocator.Error!void {
        if (options.ca_bundle_path) |path| {
            const copy = try self.allocator.dupe(u8, path);
            if (self.tls.ca_bundle_path) |old| self.allocator.free(old);
            self.tls.ca_bundle_path = copy;
        }
    }

    /// The certificate options a request of this Browser is verified with.
    pub fn certOptions(self: *const NetworkContext) CertVerifyOptions {
        return self.tls;
    }

    /// The connection share a transfer of this Browser joins, made on first
    /// use; null when curl cannot make one. curl's global state is
    /// initialized first (curl_backend's Transfer.create does).
    pub fn connectionShare(self: *NetworkContext) ?*Share {
        std.Io.Threaded.mutexLock(&self.mutex);
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
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        return self.connecting.tryAcquire(self.allocator, key, holder);
    }

    /// Let go of whatever `holder` holds of the gate.
    pub fn releaseConnecting(self: *NetworkContext, holder: *const anyopaque) void {
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        self.connecting.release(holder);
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
