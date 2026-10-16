//! CSP Embedded Enforcement §§2.1, 3 and 4. Native policy data only.
//! https://w3c.github.io/webappsec-cspee/
//!
//! Chromium is the shipping implementation (aligned stable WPT cc74d2669f:
//! Chrome passes every embedded-enforcement file; Firefox/Safari do not ship
//! iframe.csp). Design reference: network::Subsumes, CSPSourceListSubsumes and
//! CSPSourcesIntersect in services/network/public/cpp/content_security_policy/.
//! Unlike the draft, Chromium checks source-list directives only, ignores
//! sandbox/disown-opener here, and does not add data:/blob: when expanding *.

const std = @import("std");
const types = @import("types.zig");
const parsing = @import("parsing.zig");
const fallback = @import("fallback.zig");
const matching = @import("matching.zig");
const Allocator = std.mem.Allocator;

/// §2.1: validate the whole attribute, not the parser's surviving directives.
/// `origin` is the prospective response origin, as Chromium's
/// NavigationRequest::SetupCSPEmbeddedEnforcement interprets 'self'.
pub fn isValidAttribute(allocator: Allocator, value: []const u8, parent: ?[]const u8, origin: ?*const types.Origin) !bool {
    if (value.len == 0 or value.len > 4096) return false;
    var tokens = std.mem.splitScalar(u8, value, ';');
    while (tokens.next()) |token| {
        const text = std.mem.trim(u8, token, " \t");
        if (text.len == 0) continue;
        const name_end = std.mem.indexOfAny(u8, text, " \t") orelse text.len;
        for (text[0..name_end]) |c| if (!std.ascii.isAlphanumeric(c) and c != '-') return false;
        for (text[name_end..]) |c| if ((c < 0x20 and c != '\t') or c > 0x7e or c == ',') return false;
        if (std.ascii.eqlIgnoreCase(text[0..name_end], "report-uri") or
            std.ascii.eqlIgnoreCase(text[0..name_end], "report-to")) return false;
    }
    const inherited = parent orelse return true;
    var required = try parsing.parseSerializedCSP(allocator, inherited, .header, .enforce);
    defer required.deinit();
    var candidate = try parsing.parseSerializedCSP(allocator, value, .header, .enforce);
    var candidate_owned = true;
    defer if (candidate_owned) candidate.deinit();
    if (origin) |o| candidate.self_origin = types.Origin.createBorrowed(o.scheme, o.host, o.port);
    var list = types.CSPList.init(allocator);
    defer list.deinit();
    try list.append(candidate);
    candidate_owned = false;
    return subsumes(allocator, &required, &list);
}

/// §4.2: accept a serialized origin or *. The navigation caller normalizes
/// header URLs to origins as Chromium does. Chromium also permits file: and
/// filesystem: responses (AllowsBlanketEnforcementOfRequiredCSP).
pub fn allowsBlanketEnforcement(parent_origin: []const u8, response_url: []const u8, header: ?[]const u8) bool {
    const end = std.mem.indexOfScalar(u8, response_url, ':') orelse 0;
    const scheme = response_url[0..end];
    for ([_][]const u8{ "about", "data", "blob", "file", "filesystem" }) |local| {
        if (std.ascii.eqlIgnoreCase(scheme, local)) return true;
    }
    const value = std.mem.trim(u8, header orelse return false, " \t");
    return std.mem.eql(u8, value, "*") or
        (!std.mem.eql(u8, parent_origin, "null") and std.mem.eql(u8, value, parent_origin));
}

const source_directives = [_][]const u8{
    "child-src",       "connect-src",     "font-src",       "frame-src",        "img-src",
    "manifest-src",    "media-src",       "object-src",     "script-src",       "script-src-attr",
    "script-src-elem", "style-src",       "style-src-attr", "style-src-elem",   "worker-src",
    "base-uri",        "frame-ancestors", "form-action",    "fenced-frame-src",
};

fn directiveFor(policy: *const types.Policy, name: []const u8) ?*const types.Directive {
    if (std.mem.eql(u8, name, "fenced-frame-src")) {
        return policy.getDirective(name) orelse policy.getDirective("frame-src") orelse
            policy.getDirective("child-src") orelse policy.getDirective("default-src");
    }
    return fallback.getEffectiveDirective(policy, name);
}

/// §3.2.1: A subsumes B iff the intersection of B permits no more than A.
/// Missing directives in B impose no restriction; report-only imposes none.
pub fn subsumes(allocator: Allocator, required: *const types.Policy, returned: *const types.CSPList) !bool {
    if (required.disposition == .report) return true;
    const origin: ?*const types.Origin = if (returned.self_origin) |*o| o else blk: {
        for (returned.policies.items) |*policy| if (policy.self_origin) |*o| break :blk o;
        break :blk null;
    };
    for (source_directives) |name| {
        const a = directiveFor(required, name) orelse continue;
        var lists: std.ArrayListUnmanaged(*const types.SourceList) = .empty;
        defer lists.deinit(allocator);
        for (returned.policies.items) |*policy| {
            if (policy.disposition == .report) continue;
            if (directiveFor(policy, name)) |b| try lists.append(allocator, &b.value);
        }
        if (lists.items.len == 0) return false;
        if (!try sourceListsSubsume(allocator, a, lists.items, origin)) return false;
    }
    return true;
}

fn validBase64(value: []const u8) bool {
    const unpadded = std.mem.trimEnd(u8, value, "=");
    if (unpadded.len == 0 or value.len - unpadded.len > 2) return false;
    for (unpadded) |c| if (!std.ascii.isAlphanumeric(c) and c != '+' and c != '/' and c != '-' and c != '_') return false;
    return true;
}

fn isNonce(expr: types.SourceExpression) bool {
    return expr.type == .nonce and validBase64(expr.nonce_value orelse "");
}

fn isHash(expr: types.SourceExpression) bool {
    const value = expr.hash_value orelse return false;
    return expr.type == .hash and validBase64(value) and std.mem.trimEnd(u8, value, "=").len % 4 != 1;
}

fn hasNonce(list: *const types.SourceList) bool {
    for (list.expressions.items) |expr| if (isNonce(expr)) return true;
    return false;
}

fn hasNonceOrHash(list: *const types.SourceList) bool {
    for (list.expressions.items) |expr| if (isNonce(expr) or isHash(expr)) return true;
    return false;
}

fn hashChar(c: u8) u8 {
    return switch (c) {
        'A'...'Z' => c - 'A',
        'a'...'z' => c - 'a' + 26,
        '0'...'9' => c - '0' + 52,
        '+', '-' => 62,
        '/', '_' => 63,
        else => unreachable, // isHash validated the unpadded alphabet.
    };
}

fn sameHash(a: types.SourceExpression, b: types.SourceExpression) bool {
    if (!isHash(a) or !isHash(b) or !std.ascii.eqlIgnoreCase(a.hash_algorithm.?, b.hash_algorithm.?)) return false;
    const left = std.mem.trimEnd(u8, a.hash_value.?, "=");
    const right = std.mem.trimEnd(u8, b.hash_value.?, "=");
    if (left.len != right.len) return false;
    // Chrome's ParseUnquotedHash stores decoded bytes. Compare sextets
    // without allocating, ignoring the final sextet's unused padding bits.
    for (left, right, 0..) |x, y, i| {
        const mask: u8 = if (i + 1 == left.len) switch (left.len % 4) {
            2 => 0x30,
            3 => 0x3c,
            else => 0x3f,
        } else 0x3f;
        if (hashChar(x) & mask != hashChar(y) & mask) return false;
    }
    return true;
}

fn containsIdentity(list: *const types.SourceList, expr: types.SourceExpression) bool {
    for (list.expressions.items) |other| {
        if (isNonce(expr) and isNonce(other) and std.mem.eql(u8, expr.nonce_value.?, other.nonce_value.?)) return true;
        if (sameHash(expr, other)) return true;
    }
    return false;
}

fn sourceListsSubsume(allocator: Allocator, required: *const types.Directive, lists: []const *const types.SourceList, origin: ?*const types.Origin) !bool {
    const a = &required.value;
    const ancestor = std.mem.eql(u8, required.name, "frame-ancestors");
    // §3.1.2: intersect nonces/hashes by identity, then §3.2.4: compare
    // nonce presence (never its value) and hash identity against A.
    if (!ancestor) for (lists[0].expressions.items) |expr| {
        if (!isNonce(expr) and !isHash(expr)) continue;
        const common = for (lists[1..]) |list| {
            if (!containsIdentity(list, expr)) break false;
        } else true;
        if (!common) continue;
        if (isNonce(expr) and !hasNonce(a)) return false;
        if (isHash(expr) and !containsIdentity(a, expr)) return false;
    };
    var inline_b = true;
    var eval_b = true;
    var dynamic_b = true;
    var hashes_b = true;
    var nonce_or_hash_b = true;
    for (lists) |list| {
        inline_b = inline_b and list.contains(.keyword_unsafe_inline);
        eval_b = eval_b and list.contains(.keyword_unsafe_eval);
        dynamic_b = dynamic_b and list.contains(.keyword_strict_dynamic);
        hashes_b = hashes_b and list.contains(.keyword_unsafe_hashes);
        nonce_or_hash_b = nonce_or_hash_b and hasNonceOrHash(list);
    }
    const script = std.mem.startsWith(u8, required.name, "script-src") or std.mem.eql(u8, required.name, "default-src");
    const style = std.mem.startsWith(u8, required.name, "style-src");
    if (script or style) {
        if (eval_b and !a.contains(.keyword_unsafe_eval)) return false;
        if (hashes_b and !a.contains(.keyword_unsafe_hashes)) return false;
        const all_inline_a = a.contains(.keyword_unsafe_inline) and !hasNonceOrHash(a) and (!script or !a.contains(.keyword_strict_dynamic));
        const all_inline_b = inline_b and !nonce_or_hash_b and (!script or !dynamic_b);
        if (all_inline_b and !all_inline_a) return false;
    }
    // §3.1.3-3.1.5: normalize *, 'self', and schemeless hosts before
    // intersecting source expressions. Descriptors borrow the parsed policy.
    var intersection = try normalize(allocator, lists[0], origin);
    defer intersection.deinit(allocator);
    for (lists[1..]) |list| {
        var next = try normalize(allocator, list, origin);
        defer next.deinit(allocator);
        var combined: std.ArrayListUnmanaged(Source) = .empty;
        errdefer combined.deinit(allocator);
        for (intersection.items) |left| for (next.items) |right| {
            if (intersect(left, right)) |source| try appendUnique(allocator, &combined, source);
        };
        intersection.deinit(allocator);
        intersection = combined;
    }
    if (script and (a.contains(.keyword_strict_dynamic) or dynamic_b)) {
        return a.contains(.keyword_strict_dynamic) and (dynamic_b or intersection.items.len == 0);
    }
    var allowed = try normalize(allocator, a, origin);
    defer allowed.deinit(allocator);
    for (intersection.items) |candidate| {
        const covered = for (allowed.items) |source| {
            if (sourceSubsumes(source, candidate)) break true;
        } else false;
        if (!covered) return false;
    }
    return true;
}

const Source = struct {
    scheme: []const u8,
    host: ?[]const u8 = null, // null is a scheme-source; "*" is a host wildcard.
    port: ?u16 = null,
    any_port: bool = false,
    path: []const u8 = "",
};

fn normalize(allocator: Allocator, list: *const types.SourceList, origin: ?*const types.Origin) !std.ArrayListUnmanaged(Source) {
    var result: std.ArrayListUnmanaged(Source) = .empty;
    errdefer result.deinit(allocator);
    for (list.expressions.items) |expr| switch (expr.type) {
        .wildcard => {
            for ([_][]const u8{ "http", "ws", "ftp" }) |scheme| try appendUnique(allocator, &result, .{ .scheme = scheme });
            if (origin) |o| try appendUnique(allocator, &result, .{ .scheme = o.scheme });
        },
        .keyword_self => if (origin) |o| {
            if (o.host.len > 0) try appendUnique(allocator, &result, .{ .scheme = o.scheme, .host = o.host, .port = o.port });
        },
        .scheme => try appendUnique(allocator, &result, .{ .scheme = std.mem.trimEnd(u8, expr.scheme_part.?, ":") }),
        .host => {
            const host = expr.host_part orelse continue;
            if (!validHost(host)) continue;
            const scheme = expr.scheme_part orelse if (origin) |o| o.scheme else continue;
            if (!validScheme(scheme)) continue;
            // A failed port parse must not become an unspecified/default port.
            var authority = expr.raw_value;
            if (std.mem.indexOf(u8, authority, "://")) |i| authority = authority[i + 3 ..];
            authority = authority[0 .. std.mem.indexOfScalar(u8, authority, '/') orelse authority.len];
            if (std.mem.indexOfScalar(u8, authority, ':')) |_| {
                if (expr.port_part == null and !expr.port_wildcard) continue;
            }
            const path = expr.path_part orelse "";
            try appendUnique(allocator, &result, .{
                .scheme = scheme,
                .host = host,
                .port = expr.port_part,
                .any_port = expr.port_wildcard,
                .path = path[0 .. std.mem.indexOfAny(u8, path, "?#") orelse path.len],
            });
        },
        else => {},
    };
    return result;
}

fn appendUnique(allocator: Allocator, list: *std.ArrayListUnmanaged(Source), source: Source) !void {
    for (list.items) |existing| {
        if (sourceSubsumes(existing, source) and sourceSubsumes(source, existing)) return;
    }
    try list.append(allocator, source);
}

fn validScheme(scheme: []const u8) bool {
    if (scheme.len == 0 or !std.ascii.isAlphabetic(scheme[0])) return false;
    for (scheme[1..]) |c| if (!std.ascii.isAlphanumeric(c) and c != '+' and c != '-' and c != '.') return false;
    return true;
}

fn validHost(host: []const u8) bool {
    if (std.mem.eql(u8, host, "*")) return true;
    const name = if (std.mem.startsWith(u8, host, "*.")) host[2..] else host;
    if (name.len == 0 or name[0] == '.' or std.mem.indexOf(u8, name, "..") != null) return false;
    for (name) |c| if (!std.ascii.isAlphanumeric(c) and c != '-' and c != '.') return false;
    return true;
}

fn schemeAllows(a: []const u8, b: []const u8) bool {
    return std.ascii.eqlIgnoreCase(a, b) or
        (std.ascii.eqlIgnoreCase(a, "http") and std.ascii.eqlIgnoreCase(b, "https")) or
        (std.ascii.eqlIgnoreCase(a, "ws") and std.ascii.eqlIgnoreCase(b, "wss"));
}

fn hostAllows(a: []const u8, b: []const u8) bool {
    if (std.mem.eql(u8, a, "*")) return true;
    if (std.mem.startsWith(u8, a, "*.")) {
        const suffix = a[1..];
        return b.len > suffix.len and std.ascii.eqlIgnoreCase(b[b.len - suffix.len ..], suffix);
    }
    return std.ascii.eqlIgnoreCase(a, b);
}

fn portAllows(a: Source, b: Source) bool {
    if (a.any_port) return true;
    if (b.any_port) return false;
    if (a.port == b.port) return true;
    if (a.port == null and matching.getDefaultPort(b.scheme) == b.port) return true;
    if (b.port == null and a.port == matching.getDefaultPort(b.scheme)) return true;
    return (a.port orelse matching.getDefaultPort(a.scheme) orelse return false) == 80 and
        (b.port orelse matching.getDefaultPort(b.scheme) orelse return false) == 443;
}

// Percent-decode without allocating; path case remains significant.
const PathBytes = struct {
    text: []const u8,
    fn next(self: *PathBytes) ?u8 {
        if (self.text.len == 0) return null;
        const c = self.text[0];
        if (c == '%' and self.text.len >= 3) {
            if (std.fmt.parseInt(u8, self.text[1..3], 16)) |byte| {
                self.text = self.text[3..];
                return byte;
            } else |_| {}
        }
        self.text = self.text[1..];
        return c;
    }
};

fn pathAllows(a: []const u8, b: []const u8) bool {
    if (a.len == 0 or (std.mem.eql(u8, a, "/") and b.len == 0)) return true;
    var left: PathBytes = .{ .text = a };
    var right: PathBytes = .{ .text = b };
    var last: u8 = 0;
    while (left.next()) |c| {
        if (right.next() != c) return false;
        last = c;
    }
    return last == '/' or right.next() == null;
}

fn sourceSubsumes(a: Source, b: Source) bool {
    if (!schemeAllows(a.scheme, b.scheme)) return false;
    const host = a.host orelse return true;
    return hostAllows(host, b.host orelse return false) and portAllows(a, b) and pathAllows(a.path, b.path);
}

fn intersect(a: Source, b: Source) ?Source {
    const scheme = if (schemeAllows(a.scheme, b.scheme)) b.scheme else if (schemeAllows(b.scheme, a.scheme)) a.scheme else return null;
    if (a.host == null or b.host == null) {
        var result = if (a.host == null) b else a;
        result.scheme = scheme;
        return result;
    }
    const host = if (hostAllows(a.host.?, b.host.?)) b.host else if (hostAllows(b.host.?, a.host.?)) a.host else return null;
    const port_source = if (b.any_port) a else if (a.any_port) b else if (portAllows(a, b) and !(a.port != null and b.port == null)) b else if (portAllows(b, a)) a else return null;
    const path = if (pathAllows(a.path, b.path)) b.path else if (pathAllows(b.path, a.path)) a.path else return null;
    return .{ .scheme = scheme, .host = host, .port = port_source.port, .any_port = port_source.any_port, .path = path };
}
