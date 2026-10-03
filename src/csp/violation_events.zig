//! CSP §5.5 "Report a violation", the violation's part: what a violation
//! (§2.4) carries to the global whose policy it violated, and the attribute
//! values its securitypolicyviolation event takes from it (§5.2, §5.4).
//!
//! CSP knows policies, not globals or elements. Whoever finds a violation -
//! main fetch for a request (§4.1.1, §4.1.2), the inline script check for
//! an element (§4.2.3) - hands it to a `Reporter` the global's side supplies
//! (src/dom/csp_violations.zig), which owns the rest of the violation (its
//! global object, url, referrer and status) and queues the task that fires
//! the event.
//!
//! Not modelled, stated: report-uri and report-to (§5.5 steps 4-5, the
//! network reports), and a violation's source file, line and column number
//! (§2.4.1 step 2).
//!
//! Spec: https://w3c.github.io/webappsec-csp/#report-violation

const std = @import("std");
const types = @import("types.zig");

/// A violation's resource (§2.4): a URL, or one of the strings that name a
/// resource that is not one.
pub const Resource = union(enum) {
    /// A URL, serialized: a request's URL (§2.4.2 step 3).
    url: []const u8,
    @"inline",
    eval,
    wasm_eval,
    trusted_types_policy,
    trusted_types_sink,

    /// The string the resource is, for one that is not a URL.
    pub fn keyword(self: Resource) []const u8 {
        return switch (self) {
            .url => |u| u,
            .@"inline" => "inline",
            .eval => "eval",
            .wasm_eval => "wasm-eval",
            .trusted_types_policy => "trusted-types-policy",
            .trusted_types_sink => "trusted-types-sink",
        };
    }
};

/// A violation as its finder hands it over: everything but its global
/// object, which is the reporter's. Borrowed for the call.
pub const Violation = struct {
    /// "The policy that has been violated"; its disposition is the
    /// violation's.
    policy: *const types.Policy,
    /// "The directive whose enforcement caused the violation".
    effective_directive: []const u8,
    resource: Resource,
    /// The element, for a violation an element caused - opaque here, a
    /// `*runtime.Instance` to the reporter. Null for a request's.
    element: ?*anyopaque = null,
    /// The first 40 characters of the inline source, when the violated
    /// directive asks for a sample; else empty.
    sample: []const u8 = "",
};

/// What a finder reports a violation to: its global's side.
pub const Reporter = struct {
    context: *anyopaque,
    report: *const fn (context: *anyopaque, violation: *const Violation) void,

    pub fn reportViolation(self: Reporter, violation: *const Violation) void {
        self.report(self.context, violation);
    }
};

/// §5.4 Strip URL for use in reports, given a serialized URL. Owned.
pub fn stripUrlForReports(allocator: std.mem.Allocator, url: []const u8) error{OutOfMemory}![]u8 {
    const colon = std.mem.indexOfScalar(u8, url, ':') orelse return allocator.dupe(u8, url);
    const scheme = url[0..colon];
    // 1. "If url's scheme is not an HTTP(S) scheme, then return url's
    // scheme."
    if (!std.ascii.eqlIgnoreCase(scheme, "http") and !std.ascii.eqlIgnoreCase(scheme, "https")) {
        return allocator.dupe(u8, scheme);
    }
    // 2. "Set url's fragment to the empty string": the serializer then
    // writes no "#".
    const without_fragment = url[0 .. std.mem.indexOfScalar(u8, url, '#') orelse url.len];
    // 3-4. Username and password to the empty string: no userinfo.
    const authority_start = colon + 3;
    if (without_fragment.len < authority_start or !std.mem.startsWith(u8, without_fragment[colon..], "://")) {
        return allocator.dupe(u8, without_fragment);
    }
    const rest = without_fragment[authority_start..];
    const authority_end = std.mem.indexOfAny(u8, rest, "/?") orelse rest.len;
    const at = std.mem.lastIndexOfScalar(u8, rest[0..authority_end], '@') orelse return allocator.dupe(u8, without_fragment);
    // 5. Return the serialization.
    return std.mem.concat(allocator, u8, &.{ without_fragment[0..authority_start], rest[at + 1 ..] });
}

/// §5.2 Obtain the blockedURI of a violation's resource. Owned.
pub fn blockedUri(allocator: std.mem.Allocator, resource: Resource) error{OutOfMemory}![]u8 {
    return switch (resource) {
        // 2. A URL: stripped for use in reports.
        .url => |u| stripUrlForReports(allocator, u),
        // 3. "Return resource."
        else => allocator.dupe(u8, resource.keyword()),
    };
}

/// A violation's sample for `source` under `directive`: "the substring of
/// source containing its first 40 characters" when the directive's value
/// contains 'report-sample', else the empty string (§4.2.3 step 3.2.2 and
/// the other inline checks). Borrowed from `source`; never splits a UTF-8
/// sequence.
pub fn sampleFor(directive: *const types.Directive, source: []const u8) []const u8 {
    if (!directive.value.contains(.keyword_report_sample)) return "";
    var it = std.unicode.Utf8View.initUnchecked(source).iterator();
    var count: usize = 0;
    while (count < 40) : (count += 1) {
        _ = it.nextCodepointSlice() orelse break;
    }
    return source[0..it.i];
}

test "strip URL for use in reports: HTTP(S) URLs lose fragment and credentials, others are their scheme" {
    const allocator = std.testing.allocator;
    const cases = [_][2][]const u8{
        .{ "https://user:pw@a.test:8443/x/y.js?q=1#frag", "https://a.test:8443/x/y.js?q=1" },
        .{ "http://web-platform.test:8000/content-security-policy/support/resource.py?x", "http://web-platform.test:8000/content-security-policy/support/resource.py?x" },
        .{ "http://a.test/p?u=x@y#f", "http://a.test/p?u=x@y" },
        .{ "data:text/javascript,1", "data" },
        .{ "blob:https://a.test/0b2c", "blob" },
        .{ "wss://a.test/echo", "wss" },
    };
    for (cases) |case| {
        const stripped = try stripUrlForReports(allocator, case[0]);
        defer allocator.free(stripped);
        try std.testing.expectEqualStrings(case[1], stripped);
    }
}

test "blockedURI: a URL stripped, else the resource's string" {
    const allocator = std.testing.allocator;
    const url = try blockedUri(allocator, .{ .url = "https://a.test/x#y" });
    defer allocator.free(url);
    try std.testing.expectEqualStrings("https://a.test/x", url);
    const inline_resource = try blockedUri(allocator, .@"inline");
    defer allocator.free(inline_resource);
    try std.testing.expectEqualStrings("inline", inline_resource);
    const wasm = try blockedUri(allocator, .wasm_eval);
    defer allocator.free(wasm);
    try std.testing.expectEqualStrings("wasm-eval", wasm);
}

test "a sample is the first 40 characters, only under 'report-sample'" {
    const allocator = std.testing.allocator;
    const parsing = @import("parsing.zig");
    var with = try parsing.parseSerializedCSP(allocator, "script-src 'self' 'report-sample'", .header, .enforce);
    defer with.deinit();
    var without = try parsing.parseSerializedCSP(allocator, "script-src 'self'", .header, .enforce);
    defer without.deinit();
    const source = "alert('a fairly long inline script whose sample is cut') // \u{e9}";
    const sample = sampleFor(with.directive_set.get("script-src").?, source);
    try std.testing.expectEqual(@as(usize, 40), try std.unicode.utf8CountCodepoints(sample));
    try std.testing.expect(std.mem.startsWith(u8, source, sample));
    try std.testing.expectEqualStrings("", sampleFor(without.directive_set.get("script-src").?, source));
    // Short sources are whole; a multi-byte character is not split.
    try std.testing.expectEqualStrings("\u{e9}\u{e9}", sampleFor(with.directive_set.get("script-src").?, "\u{e9}\u{e9}"));
}
