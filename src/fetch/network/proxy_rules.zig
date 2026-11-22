//! Chrome's manual proxy rules: the `--proxy-server` and CDP
//! Target.createBrowserContext `proxyServer` grammar, and the
//! `--proxy-bypass-list` / `proxyBypassList` bypass rules - reproduced from
//! Chromium (BSD-3; algorithms reproduced, no code copied):
//! - net/proxy_resolution/proxy_config.cc: ProxyConfig::ProxyRules::
//!   ParseFromString (a single list for every scheme, or "<scheme>=<list>"
//!   per scheme with "socks=" as the fallback), MapUrlSchemeToProxyList and
//!   GetProxyListForWebSocketScheme (which list a URL takes);
//! - net/base/proxy_string_util.cc ProxyUriToProxyServer ("[<scheme>://]
//!   <host>[:<port>]", the default port per scheme; "socks" means SOCKS5 in a
//!   URI and SOCKS4 as a "socks=" entry's default; quic is not allowed here,
//!   as ParseFromString disallows it; an invalid entry is skipped);
//! - net/proxy_resolution/proxy_bypass_rules.cc ParseFromString /
//!   ParseBypassRule / Matches / MatchesImplicitRules and
//!   net/base/scheme_host_port_matcher_rule.cc: "," or ";" separated rules -
//!   "<local>", "<-loopback>", "[<scheme>://]<host-pattern>[:<port>]" with
//!   `*` wildcards (".x.com" is "*.x.com"), IP literals, CIDR blocks; later
//!   rules win; with no explicit match, the implicit rules bypass localhost,
//!   loopback and link-local addresses unless "<-loopback>" subtracts them.
//! A proxy list is ordered: the first entry not marked bad is used, and a
//! failed one makes way for the next (NetworkContext's retry info,
//! net/proxy_resolution/proxy_list.cc ProxyList::Fallback).

const std = @import("std");
const Allocator = std.mem.Allocator;

/// A proxy server's scheme (net::ProxyServer::Scheme, the ones curl speaks).
pub const Scheme = enum { direct, http, https, socks4, socks5 };

pub const Server = struct {
    scheme: Scheme,
    /// The host as written: an IPv6 literal keeps its brackets.
    host: []const u8 = "",
    port: u16 = 0,
    /// `curlUrl`, made when the rules are parsed ("" for direct).
    url: []const u8 = "",

    /// The proxy URL curl takes for this server, OWNED; "" for direct. SOCKS5
    /// hands the destination's name to the proxy (Chrome's
    /// SOCKS5ClientSocket sends a domain name), so curl's "socks5h"; SOCKS4
    /// resolves it here (SOCKS4ClientSocket), "socks4".
    pub fn curlUrl(self: Server, allocator: Allocator) Allocator.Error![]u8 {
        const prefix = switch (self.scheme) {
            .direct => return allocator.dupe(u8, ""),
            .http => "http",
            .https => "https",
            .socks4 => "socks4",
            .socks5 => "socks5h",
        };
        return std.fmt.allocPrint(allocator, "{s}://{s}:{d}", .{ prefix, self.host, self.port });
    }

    pub fn eql(a: Server, b: Server) bool {
        return a.scheme == b.scheme and a.port == b.port and std.mem.eql(u8, a.host, b.host);
    }
};

/// "Use no proxy": the list a bypassed URL, or a scheme with none, takes.
pub const direct_list: []const Server = &.{.{ .scheme = .direct }};

/// One bypass rule (net::SchemeHostPortMatcherRule and the two special ones).
pub const BypassRule = union(enum) {
    /// "<local>": a host name with no dot that is no IP literal.
    local,
    /// "<-loopback>": what the implicit rules would bypass is not bypassed.
    subtract_implicit,
    /// "[<scheme>://]<pattern>[:<port>]": a host name pattern ("*" any run).
    host: struct { scheme: []const u8, pattern: []const u8, port: ?u16 },
    /// An IP literal ("[<scheme>://]<ip>[:<port>]") or a CIDR block.
    ip: struct { scheme: []const u8, address: [16]u8, prefix: u8, port: ?u16 },
};

/// What a rule says of a URL (net::SchemeHostPortMatcherResult).
const Verdict = enum { no_match, include, exclude };

/// A request's URL as the rules see it.
pub const Target = struct {
    scheme: []const u8,
    /// Lowercase, an IPv6 literal without its brackets.
    host: []const u8,
    port: u16,

    /// `url`'s scheme, host and port (its scheme's default port when it
    /// names none); null for a URL with no host.
    pub fn of(url: []const u8) ?Target {
        const colon = std.mem.indexOf(u8, url, "://") orelse return null;
        const scheme = url[0..colon];
        var rest = url[colon + 3 ..];
        const end = std.mem.indexOfAny(u8, rest, "/?#") orelse rest.len;
        rest = rest[0..end];
        if (std.mem.lastIndexOfScalar(u8, rest, '@')) |at| rest = rest[at + 1 ..];
        var host = rest;
        var port: ?u16 = null;
        if (std.mem.startsWith(u8, rest, "[")) {
            const close = std.mem.indexOfScalar(u8, rest, ']') orelse return null;
            host = rest[1..close];
            if (close + 1 < rest.len and rest[close + 1] == ':') port = std.fmt.parseUnsigned(u16, rest[close + 2 ..], 10) catch return null;
        } else if (std.mem.lastIndexOfScalar(u8, rest, ':')) |c| {
            host = rest[0..c];
            port = std.fmt.parseUnsigned(u16, rest[c + 1 ..], 10) catch return null;
        }
        if (host.len == 0) return null;
        return .{ .scheme = scheme, .host = host, .port = port orelse defaultPort(scheme) };
    }
};

fn defaultPort(scheme: []const u8) u16 {
    if (std.mem.eql(u8, scheme, "https") or std.mem.eql(u8, scheme, "wss")) return 443;
    if (std.mem.eql(u8, scheme, "ftp")) return 21;
    return 80;
}

/// A parsed `proxyServer` and `proxyBypassList`, every slice in its arena.
pub const Rules = struct {
    arena: std.heap.ArenaAllocator,
    /// ProxyRules::Type: EMPTY, PROXY_LIST (one list for every scheme), or
    /// PROXY_LIST_PER_SCHEME.
    kind: enum { empty, single, per_scheme } = .empty,
    single: []const Server = &.{},
    http: []const Server = &.{},
    https: []const Server = &.{},
    ftp: []const Server = &.{},
    /// "socks=": for every scheme with no list of its own.
    fallback: []const Server = &.{},
    bypass: []const BypassRule = &.{},
    /// The texts parsed, for `clone`.
    proxy_server: []const u8 = "",
    bypass_list: []const u8 = "",

    pub fn deinit(self: *Rules) void {
        self.arena.deinit();
    }

    /// Another Rules with the same meaning, OWNED by `allocator`.
    pub fn clone(self: *const Rules, allocator: Allocator) Allocator.Error!Rules {
        return parse(allocator, self.proxy_server, self.bypass_list);
    }

    /// ProxyRules::ParseFromString of `proxy_server` and ProxyBypassRules::
    /// ParseFromString of `bypass_list`. Entries Chrome would skip (an
    /// unknown scheme, a bad port) are skipped.
    pub fn parse(allocator: Allocator, proxy_server: []const u8, bypass_list: []const u8) Allocator.Error!Rules {
        var self: Rules = .{ .arena = .init(allocator) };
        errdefer self.arena.deinit();
        const a = self.arena.allocator();
        self.proxy_server = try a.dupe(u8, proxy_server);
        self.bypass_list = try a.dupe(u8, bypass_list);
        var http: std.ArrayList(Server) = .empty;
        var https: std.ArrayList(Server) = .empty;
        var ftp: std.ArrayList(Server) = .empty;
        var fallback: std.ArrayList(Server) = .empty;
        var groups = std.mem.tokenizeScalar(u8, self.proxy_server, ';');
        outer: while (groups.next()) |group| {
            var parts = std.mem.tokenizeScalar(u8, group, '=');
            while (parts.next()) |first| {
                const list = parts.next() orelse {
                    // No "=": one list for every scheme (ignored once the
                    // rules are per scheme).
                    if (self.kind == .per_scheme) continue;
                    var single: std.ArrayList(Server) = .empty;
                    try addUriList(a, first, &single, .http);
                    self.single = single.items;
                    self.kind = .single;
                    break :outer;
                };
                const url_scheme = std.mem.trim(u8, first, " \t\r\n");
                var default_scheme: Scheme = .http;
                const entry: ?*std.ArrayList(Server) = if (std.mem.eql(u8, url_scheme, "http"))
                    &http
                else if (std.mem.eql(u8, url_scheme, "https"))
                    &https
                else if (std.mem.eql(u8, url_scheme, "ftp"))
                    &ftp
                else if (std.mem.eql(u8, url_scheme, "socks")) blk: {
                    // "socks=X" is "everything else to SOCKS server X",
                    // SOCKS4 when X names no scheme.
                    default_scheme = .socks4;
                    break :blk &fallback;
                } else null;
                if (entry) |e| {
                    try addUriList(a, list, e, default_scheme);
                    self.kind = .per_scheme;
                }
            }
        }
        if (self.kind == .per_scheme) {
            self.http = http.items;
            self.https = https.items;
            self.ftp = ftp.items;
            self.fallback = fallback.items;
        }
        var rules: std.ArrayList(BypassRule) = .empty;
        var tokens = std.mem.tokenizeAny(u8, self.bypass_list, ",;");
        while (tokens.next()) |token| {
            if (try parseBypassRule(a, token)) |rule| try rules.append(a, rule);
        }
        self.bypass = rules.items;
        return self;
    }

    /// The proxies a request to `url` tries, in order (ProxyRules::Apply:
    /// a bypassed URL goes direct; else its scheme's list, a WebSocket's
    /// fallback/https/http list, then the "socks=" fallback; none: direct).
    pub fn listFor(self: *const Rules, url: []const u8) []const Server {
        const target = Target.of(url) orelse return direct_list;
        if (self.bypasses(target)) return direct_list;
        const list: []const Server = switch (self.kind) {
            .empty => &.{},
            .single => self.single,
            .per_scheme => self.mapUrlScheme(target.scheme),
        };
        return if (list.len == 0) direct_list else list;
    }

    fn mapUrlScheme(self: *const Rules, scheme: []const u8) []const Server {
        const own: []const Server = if (std.mem.eql(u8, scheme, "http"))
            self.http
        else if (std.mem.eql(u8, scheme, "https"))
            self.https
        else if (std.mem.eql(u8, scheme, "ftp"))
            self.ftp
        else
            &.{};
        if (own.len > 0) return own;
        if (std.mem.eql(u8, scheme, "ws") or std.mem.eql(u8, scheme, "wss")) {
            // GetProxyListForWebSocketScheme.
            if (self.fallback.len > 0) return self.fallback;
            if (self.https.len > 0) return self.https;
            return self.http;
        }
        return self.fallback;
    }

    /// ProxyBypassRules::Matches: the last explicit rule that decides wins;
    /// with none, the implicit rules.
    pub fn bypasses(self: *const Rules, target: Target) bool {
        var i = self.bypass.len;
        while (i > 0) {
            i -= 1;
            switch (evaluate(self.bypass[i], target)) {
                .include => return true,
                .exclude => return false,
                .no_match => {},
            }
        }
        return matchesImplicitRules(target);
    }
};

/// AddProxyURIListToProxyList: "," separated URIs, the invalid skipped.
fn addUriList(a: Allocator, text: []const u8, out: *std.ArrayList(Server), default_scheme: Scheme) Allocator.Error!void {
    var uris = std.mem.tokenizeScalar(u8, text, ',');
    while (uris.next()) |uri| {
        if (parseProxyUri(std.mem.trim(u8, uri, " \t\r\n"), default_scheme)) |server| {
            var copy = server;
            copy.host = try a.dupe(u8, server.host);
            copy.url = try copy.curlUrl(a);
            try out.append(a, copy);
        }
    }
}

/// ProxyUriToProxyServer, without quic (ParseFromString disallows it).
pub fn parseProxyUri(uri: []const u8, default_scheme: Scheme) ?Server {
    var scheme = default_scheme;
    var rest = uri;
    if (std.mem.indexOf(u8, uri, "://")) |sep| {
        scheme = schemeOfUri(uri[0..sep]) orelse return null;
        rest = uri[sep + 3 ..];
    }
    if (scheme == .direct) return if (rest.len == 0) .{ .scheme = .direct } else null;
    if (rest.len == 0) return null;
    var host = rest;
    var port: ?u16 = null;
    if (std.mem.startsWith(u8, rest, "[")) {
        const close = std.mem.indexOfScalar(u8, rest, ']') orelse return null;
        host = rest[0 .. close + 1];
        if (close + 1 < rest.len) {
            if (rest[close + 1] != ':') return null;
            port = std.fmt.parseUnsigned(u16, rest[close + 2 ..], 10) catch return null;
        }
    } else if (std.mem.lastIndexOfScalar(u8, rest, ':')) |c| {
        host = rest[0..c];
        port = std.fmt.parseUnsigned(u16, rest[c + 1 ..], 10) catch return null;
    }
    if (host.len == 0 or std.mem.indexOfAny(u8, host, "/?#@ ") != null) return null;
    return .{ .scheme = scheme, .host = host, .port = port orelse switch (scheme) {
        .http => 80,
        .https => 443,
        .socks4, .socks5 => 1080,
        .direct => unreachable,
    } };
}

/// GetSchemeFromUriScheme: "socks" is SOCKS5 in a URI.
fn schemeOfUri(text: []const u8) ?Scheme {
    const names = [_]struct { []const u8, Scheme }{
        .{ "http", .http },     .{ "https", .https },  .{ "socks4", .socks4 },
        .{ "socks5", .socks5 }, .{ "socks", .socks5 }, .{ "direct", .direct },
    };
    for (names) |n| if (std.ascii.eqlIgnoreCase(text, n[0])) return n[1];
    return null;
}

/// ParseBypassRule. Null: no rule (Chrome drops it).
fn parseBypassRule(a: Allocator, token: []const u8) Allocator.Error!?BypassRule {
    var raw = std.mem.trim(u8, token, " \t\r\n");
    if (raw.len == 0) return null;
    if (std.ascii.eqlIgnoreCase(raw, "<local>")) return .local;
    if (std.ascii.eqlIgnoreCase(raw, "<-loopback>")) return .subtract_implicit;
    var scheme: []const u8 = "";
    if (std.mem.indexOf(u8, raw, "://")) |sep| {
        scheme = try std.ascii.allocLowerString(a, raw[0..sep]);
        raw = raw[sep + 3 ..];
        if (scheme.len == 0) return null;
    }
    if (raw.len == 0) return null;
    // A slash: a CIDR block.
    if (std.mem.indexOfScalar(u8, raw, '/')) |slash| {
        const address = parseIp(stripBrackets(raw[0..slash])) orelse return null;
        const prefix = std.fmt.parseUnsigned(u8, raw[slash + 1 ..], 10) catch return null;
        if (prefix > (if (address.is_v4) @as(u8, 32) else 128)) return null;
        return .{ .ip = .{ .scheme = scheme, .address = address.bytes, .prefix = if (address.is_v4) prefix + 96 else prefix, .port = null } };
    }
    // An IP literal, with an optional port.
    if (hostAndPort(raw)) |hp| if (parseIp(stripBrackets(hp.host))) |address| {
        return .{ .ip = .{ .scheme = scheme, .address = address.bytes, .prefix = 128, .port = hp.port } };
    };
    // <hostname-pattern>[:port].
    var port: ?u16 = null;
    if (std.mem.lastIndexOfScalar(u8, raw, ':')) |c| {
        port = std.fmt.parseUnsigned(u16, raw[c + 1 ..], 10) catch return null;
        raw = raw[0..c];
    }
    const lowered = try std.ascii.allocLowerString(a, raw);
    // ".google.com" is "*.google.com".
    const pattern = if (std.mem.startsWith(u8, lowered, ".")) try std.mem.concat(a, u8, &.{ "*", lowered }) else lowered;
    return .{ .host = .{ .scheme = scheme, .pattern = pattern, .port = port } };
}

fn stripBrackets(text: []const u8) []const u8 {
    if (text.len >= 2 and text[0] == '[' and text[text.len - 1] == ']') return text[1 .. text.len - 1];
    return text;
}

fn hostAndPort(raw: []const u8) ?struct { host: []const u8, port: ?u16 } {
    if (std.mem.startsWith(u8, raw, "[")) {
        const close = std.mem.indexOfScalar(u8, raw, ']') orelse return null;
        if (close + 1 == raw.len) return .{ .host = raw[0 .. close + 1], .port = null };
        if (raw[close + 1] != ':') return null;
        return .{ .host = raw[0 .. close + 1], .port = std.fmt.parseUnsigned(u16, raw[close + 2 ..], 10) catch return null };
    }
    // An IPv6 literal without brackets has several colons: no port.
    if (std.mem.count(u8, raw, ":") > 1) return .{ .host = raw, .port = null };
    if (std.mem.lastIndexOfScalar(u8, raw, ':')) |c| {
        return .{ .host = raw[0..c], .port = std.fmt.parseUnsigned(u16, raw[c + 1 ..], 10) catch return null };
    }
    return .{ .host = raw, .port = null };
}

fn evaluate(rule: BypassRule, target: Target) Verdict {
    switch (rule) {
        .local => {
            if (parseIp(target.host) != null) return .no_match;
            return if (std.mem.indexOfScalar(u8, target.host, '.') == null) .include else .no_match;
        },
        .subtract_implicit => return if (matchesImplicitRules(target)) .exclude else .no_match,
        .host => |h| {
            if (h.port) |p| if (p != target.port) return .no_match;
            if (h.scheme.len > 0 and !std.mem.eql(u8, h.scheme, target.scheme)) return .no_match;
            return if (wildcardMatch(h.pattern, target.host)) .include else .no_match;
        },
        .ip => |r| {
            if (r.port) |p| if (p != target.port) return .no_match;
            if (r.scheme.len > 0 and !std.mem.eql(u8, r.scheme, target.scheme)) return .no_match;
            const address = parseIp(target.host) orelse return .no_match;
            return if (prefixMatches(address.bytes, r.address, r.prefix)) .include else .no_match;
        },
    }
}

/// MatchesImplicitRules: localhost names, loopback and link-local addresses
/// (net::HostStringIsLocalhost, IPAddress::IsLinkLocal).
pub fn matchesImplicitRules(target: Target) bool {
    const host = target.host;
    const names = [_][]const u8{ "localhost", "localhost.", "localhost.localdomain", "localhost6", "localhost6.localdomain6" };
    for (names) |n| if (std.ascii.eqlIgnoreCase(host, n)) return true;
    if (std.mem.endsWith(u8, host, ".localhost") or std.mem.endsWith(u8, host, ".localhost.")) return true;
    const address = parseIp(host) orelse return false;
    const b = address.bytes;
    if (address.is_v4) return b[12] == 127 or (b[12] == 169 and b[13] == 254);
    var loopback: [16]u8 = @splat(0);
    loopback[15] = 1;
    if (std.mem.eql(u8, &b, &loopback)) return true;
    return b[0] == 0xfe and (b[1] & 0xc0) == 0x80;
}

fn prefixMatches(address: [16]u8, block: [16]u8, prefix: u8) bool {
    var bits: u16 = prefix;
    for (address, block) |x, y| {
        if (bits == 0) return true;
        const take: u8 = @intCast(@min(bits, 8));
        const mask: u8 = if (take == 8) 0xff else ~(@as(u8, 0xff) >> @intCast(take));
        if ((x & mask) != (y & mask)) return false;
        bits -= take;
    }
    return true;
}

/// `pattern` with `*` for any run (base::MatchPattern, `?` not special here
/// as host names cannot hold one).
fn wildcardMatch(pattern: []const u8, text: []const u8) bool {
    var p: usize = 0;
    var t: usize = 0;
    var star: ?usize = null;
    var star_t: usize = 0;
    while (t < text.len) {
        if (p < pattern.len and pattern[p] == '*') {
            star = p;
            star_t = t;
            p += 1;
        } else if (p < pattern.len and pattern[p] == text[t]) {
            p += 1;
            t += 1;
        } else if (star) |s| {
            p = s + 1;
            star_t += 1;
            t = star_t;
        } else return false;
    }
    while (p < pattern.len and pattern[p] == '*') p += 1;
    return p == pattern.len;
}

const Ip = struct { bytes: [16]u8, is_v4: bool };

/// An IPv4 dotted quad (as an IPv4-mapped address) or an IPv6 literal.
fn parseIp(text: []const u8) ?Ip {
    if (parseIp4(text)) |v4| {
        // ::ffff:a.b.c.d
        var bytes: [16]u8 = @splat(0);
        bytes[10] = 0xff;
        bytes[11] = 0xff;
        @memcpy(bytes[12..16], &v4);
        return .{ .bytes = bytes, .is_v4 = true };
    }
    return if (parseIp6(text)) |v6| .{ .bytes = v6, .is_v4 = false } else null;
}

fn parseIp4(text: []const u8) ?[4]u8 {
    var out: [4]u8 = undefined;
    var parts = std.mem.splitScalar(u8, text, '.');
    var i: usize = 0;
    while (parts.next()) |part| : (i += 1) {
        if (i == 4 or part.len == 0 or part.len > 3) return null;
        out[i] = std.fmt.parseUnsigned(u8, part, 10) catch return null;
    }
    return if (i == 4) out else null;
}

fn parseIp6(text: []const u8) ?[16]u8 {
    if (std.mem.indexOfScalar(u8, text, ':') == null) return null;
    var groups: [8]u16 = @splat(0);
    var head: [8]u16 = undefined;
    var tail: [8]u16 = undefined;
    var head_n: usize = 0;
    var tail_n: usize = 0;
    const gap = std.mem.indexOf(u8, text, "::");
    const left = if (gap) |g| text[0..g] else text;
    const right = if (gap) |g| text[g + 2 ..] else "";
    if (left.len > 0) {
        var it = std.mem.splitScalar(u8, left, ':');
        while (it.next()) |g| {
            if (head_n == 8) return null;
            head[head_n] = std.fmt.parseUnsigned(u16, g, 16) catch return null;
            head_n += 1;
        }
    }
    if (right.len > 0) {
        var it = std.mem.splitScalar(u8, right, ':');
        while (it.next()) |g| {
            if (tail_n == 8) return null;
            tail[tail_n] = std.fmt.parseUnsigned(u16, g, 16) catch return null;
            tail_n += 1;
        }
    }
    if (gap == null and head_n != 8) return null;
    if (gap != null and head_n + tail_n > 7) return null;
    @memcpy(groups[0..head_n], head[0..head_n]);
    @memcpy(groups[8 - tail_n ..], tail[0..tail_n]);
    var bytes: [16]u8 = undefined;
    for (groups, 0..) |g, i| std.mem.writeInt(u16, bytes[i * 2 ..][0..2], g, .big);
    return bytes;
}

test "ParseFromString: one list for every scheme, with Chrome's default port and scheme" {
    var rules = try Rules.parse(std.testing.allocator, "foopy:99", "");
    defer rules.deinit();
    const list = rules.listFor("http://example.test/");
    try std.testing.expectEqual(@as(usize, 1), list.len);
    try std.testing.expect(list[0].eql(.{ .scheme = .http, .host = "foopy", .port = 99 }));
    try std.testing.expect(rules.listFor("https://example.test/")[0].eql(.{ .scheme = .http, .host = "foopy", .port = 99 }));
    var socks = try Rules.parse(std.testing.allocator, "socks5://proxy.test", "");
    defer socks.deinit();
    try std.testing.expect(socks.listFor("https://a.test/")[0].eql(.{ .scheme = .socks5, .host = "proxy.test", .port = 1080 }));
}

test "ParseFromString: per scheme, socks= as the fallback (SOCKS4 by default), WebSockets' order" {
    var rules = try Rules.parse(std.testing.allocator, "http=a:1,b:2;https=https://c;socks=d", "");
    defer rules.deinit();
    const http = rules.listFor("http://x.test/");
    try std.testing.expectEqual(@as(usize, 2), http.len);
    try std.testing.expect(http[1].eql(.{ .scheme = .http, .host = "b", .port = 2 }));
    try std.testing.expect(rules.listFor("https://x.test/")[0].eql(.{ .scheme = .https, .host = "c", .port = 443 }));
    // ftp has no list: the fallback; so does ws (GetProxyListForWebSocketScheme).
    try std.testing.expect(rules.listFor("ftp://x.test/")[0].eql(.{ .scheme = .socks4, .host = "d", .port = 1080 }));
    try std.testing.expect(rules.listFor("ws://x.test/")[0].eql(.{ .scheme = .socks4, .host = "d", .port = 1080 }));
    var no_fallback = try Rules.parse(std.testing.allocator, "http=a:1;https=c:3", "");
    defer no_fallback.deinit();
    try std.testing.expect(no_fallback.listFor("wss://x.test/")[0].eql(.{ .scheme = .http, .host = "c", .port = 3 }));
}

test "ParseFromString: direct:// in a list, invalid entries skipped, nothing parsed is direct" {
    var rules = try Rules.parse(std.testing.allocator, "quic://q:1,foo://bad,a:70000,b:8080,direct://", "");
    defer rules.deinit();
    const list = rules.listFor("http://x.test/");
    try std.testing.expectEqual(@as(usize, 2), list.len);
    try std.testing.expect(list[0].eql(.{ .scheme = .http, .host = "b", .port = 8080 }));
    try std.testing.expectEqual(Scheme.direct, list[1].scheme);
    try std.testing.expectEqualStrings("http://b:8080", list[0].url);
    try std.testing.expectEqualStrings("", list[1].url);
    var empty = try Rules.parse(std.testing.allocator, "", "");
    defer empty.deinit();
    try std.testing.expectEqual(Scheme.direct, empty.listFor("http://x.test/")[0].scheme);
}

test "ProxyBypassRules: patterns, ports, schemes, CIDR, <local>, the implicit loopback rules and <-loopback>" {
    var rules = try Rules.parse(std.testing.allocator, "p:1", ".example.test, *.other.test:8080; https://secure.test, 10.0.0.0/8, [::1]:9, <local>");
    defer rules.deinit();
    try std.testing.expectEqual(Scheme.direct, rules.listFor("http://a.example.test/")[0].scheme);
    try std.testing.expectEqual(Scheme.http, rules.listFor("http://example.test/")[0].scheme);
    try std.testing.expectEqual(Scheme.direct, rules.listFor("http://x.other.test:8080/")[0].scheme);
    try std.testing.expectEqual(Scheme.http, rules.listFor("http://x.other.test/")[0].scheme);
    try std.testing.expectEqual(Scheme.direct, rules.listFor("https://secure.test/")[0].scheme);
    try std.testing.expectEqual(Scheme.http, rules.listFor("http://secure.test/")[0].scheme);
    try std.testing.expectEqual(Scheme.direct, rules.listFor("http://10.1.2.3/")[0].scheme);
    try std.testing.expectEqual(Scheme.direct, rules.listFor("http://intranet/")[0].scheme);
    // Implicit: localhost and loopback go direct...
    try std.testing.expectEqual(Scheme.direct, rules.listFor("http://localhost:3000/")[0].scheme);
    try std.testing.expectEqual(Scheme.direct, rules.listFor("http://127.0.0.1:3000/")[0].scheme);
    // ...unless <-loopback> subtracts them.
    var proxied = try Rules.parse(std.testing.allocator, "p:1", "<-loopback>");
    defer proxied.deinit();
    try std.testing.expectEqual(Scheme.http, proxied.listFor("http://127.0.0.1:3000/")[0].scheme);
    try std.testing.expectEqual(Scheme.http, proxied.listFor("http://localhost/")[0].scheme);
}

test "a proxy server's URL for curl" {
    const a = std.testing.allocator;
    for ([_]struct { Server, []const u8 }{
        .{ .{ .scheme = .http, .host = "p", .port = 3128 }, "http://p:3128" },
        .{ .{ .scheme = .socks5, .host = "[::1]", .port = 1080 }, "socks5h://[::1]:1080" },
        .{ .{ .scheme = .socks4, .host = "s", .port = 1 }, "socks4://s:1" },
        .{ .{ .scheme = .direct }, "" },
    }) |case| {
        const url = try case[0].curlUrl(a);
        defer a.free(url);
        try std.testing.expectEqualStrings(case[1], url);
    }
}
