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
//! Serialization is native; the global's side owns queued delivery.
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

/// Borrowed, already stripped report values. Both report mechanisms use the
/// same snapshot; only their wire keys and treatment of absent locations differ.
pub const ReportBody = struct {
    document_url: []const u8,
    referrer: []const u8 = "",
    blocked_url: []const u8,
    effective_directive: []const u8,
    original_policy: []const u8,
    sample: []const u8 = "",
    disposition: types.PolicyDisposition = .enforce,
    status_code: u16 = 0,
    source_file: ?[]const u8 = null,
    line_number: u32 = 0,
    column_number: u32 = 0,

    /// CSP §5.3 steps 1-4: the deprecated report-uri JSON object. An absent
    /// source file omits all three location members, rather than emitting null.
    pub fn serializeLegacy(self: ReportBody, allocator: std.mem.Allocator) ![]u8 {
        return std.json.Stringify.valueAlloc(allocator, .{ .@"csp-report" = .{
            .@"document-uri" = self.document_url,
            .referrer = self.referrer,
            .@"blocked-uri" = self.blocked_url,
            .@"effective-directive" = self.effective_directive,
            .@"violated-directive" = self.effective_directive,
            .@"original-policy" = self.original_policy,
            .@"script-sample" = self.sample,
            .disposition = @tagName(self.disposition),
            .@"status-code" = self.status_code,
            .@"source-file" = self.source_file,
            .@"line-number" = if (self.source_file != null) @as(?u32, self.line_number) else null,
            .@"column-number" = if (self.source_file != null) @as(?u32, self.column_number) else null,
        } }, .{ .emit_null_optional_fields = false });
    }

    /// CSP §5.5 step 3.5.1: Reporting API body members, including null
    /// sourceFile/lineNumber/columnNumber when no source location is known.
    pub fn serializeModern(self: ReportBody, allocator: std.mem.Allocator) ![]u8 {
        return std.json.Stringify.valueAlloc(allocator, .{
            .documentURL = self.document_url,
            .referrer = self.referrer,
            .blockedURL = self.blocked_url,
            .effectiveDirective = self.effective_directive,
            .originalPolicy = self.original_policy,
            .sample = self.sample,
            .disposition = @tagName(self.disposition),
            .statusCode = self.status_code,
            .sourceFile = self.source_file,
            .lineNumber = if (self.source_file != null) @as(?u32, self.line_number) else null,
            .columnNumber = if (self.source_file != null) @as(?u32, self.column_number) else null,
        }, .{});
    }
};

/// §5.4 Strip URL for use in reports, given a serialized URL. Owned.
pub fn stripUrlForReports(allocator: std.mem.Allocator, url: []const u8) error{OutOfMemory}![]u8 {
    const colon = std.mem.indexOfScalar(u8, url, ':') orelse return allocator.dupe(u8, url);
    const scheme = url[0..colon];
    // §5.4 step 1 says HTTP(S), but all three browsers also preserve WS(S):
    // Blink StripURLForUseInReport, Gecko StripURIForReporting (CSP issue
    // #735), and WebKit createURLForReporting. Keep their credentials and
    // fragment stripping below. Firefox/WebKit retain the query too.
    if (!std.ascii.eqlIgnoreCase(scheme, "http") and !std.ascii.eqlIgnoreCase(scheme, "https") and
        !std.ascii.eqlIgnoreCase(scheme, "ws") and !std.ascii.eqlIgnoreCase(scheme, "wss"))
    {
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

/// A violation's source file (§2.4.1 step 2) for use in reports: the
/// running script's URL - a sourceURL a script named itself - stripped as
/// §5.4 strips a URL; a string that is no absolute URL (no scheme) is no
/// source file, "". "User agents need to ensure that the source file is the
/// URL requested by the page, pre-redirects. If that's not possible, user
/// agents need to strip the URL down to an origin." Blink strips the same
/// way (StripURLForUseInReport over a KURL, invalid -> ""). Owned.
pub fn sourceFileForReports(allocator: std.mem.Allocator, url: []const u8) error{OutOfMemory}![]u8 {
    if (!hasScheme(url)) return allocator.dupe(u8, "");
    return stripUrlForReports(allocator, url);
}

/// Whether `url` starts with a URL scheme and its ':' - ASCII alpha, then
/// ASCII alphanumerics, '+', '-' or '.'.
fn hasScheme(url: []const u8) bool {
    const colon = std.mem.indexOfScalar(u8, url, ':') orelse return false;
    if (colon == 0 or !std.ascii.isAlphabetic(url[0])) return false;
    for (url[1..colon]) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '+' and c != '-' and c != '.') return false;
    }
    return true;
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

/// CSP §5.2, with the browsers' additional navigation privacy restriction.
/// The origin and resource URL are serialized by their owners. A cross-origin
/// frame-src/object-src resource exposes only its origin, even though §5.4
/// specifies stripping credentials and fragments alone. Blink implements this
/// in ContentSecurityPolicy::StripURLForUseInReport (crbug.com/633306):
/// https://raw.githubusercontent.com/chromium/chromium/main/third_party/blink/renderer/core/frame/csp/content_security_policy.cc
/// wpt.fyi aligned stable cc74d2669f: frame-src-blocked-path-matching.sub.html
/// Chrome/Firefox/Safari each 3/3 (runs 6218298311311360, 4877098740350976,
/// 5164107446878208). Same-origin paths and other directives are unchanged.
/// The returned string is owned by the caller.
pub fn blockedUriForPolicy(
    allocator: std.mem.Allocator,
    resource: Resource,
    effective_directive: []const u8,
    reporting_origin: []const u8,
) error{OutOfMemory}![]u8 {
    if (resource != .url or
        (!std.mem.eql(u8, effective_directive, "frame-src") and
            !std.mem.eql(u8, effective_directive, "object-src")))
        return blockedUri(allocator, resource);

    const Url = @import("request_check.zig").Url;
    const target = Url.ofSerialized(resource.url);
    // The frame/object navigation privacy rule applies to HTTP(S) URLs.
    if (!std.ascii.eqlIgnoreCase(target.scheme, "http") and
        !std.ascii.eqlIgnoreCase(target.scheme, "https"))
        return blockedUri(allocator, resource);
    const host = target.host orelse return blockedUri(allocator, resource);
    const origin = Url.ofSerialized(reporting_origin);
    const defaultPort = @import("matching.zig").getDefaultPort;
    const target_port = target.port orelse defaultPort(target.scheme);
    const origin_port = origin.port orelse defaultPort(origin.scheme);
    if (origin.host) |origin_host| {
        if (std.ascii.eqlIgnoreCase(target.scheme, origin.scheme) and
            std.ascii.eqlIgnoreCase(host, origin_host) and target_port == origin_port)
            return blockedUri(allocator, resource);
    }
    // Browser deviation from §5.4 step 5: serialize just the tuple origin.
    if (target.port) |port| {
        if (port != defaultPort(target.scheme))
            return std.fmt.allocPrint(allocator, "{s}://{s}:{d}", .{ target.scheme, host, port });
    }
    return std.fmt.allocPrint(allocator, "{s}://{s}", .{ target.scheme, host });
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

test "strip URL for use in reports: HTTP(S) and WS(S) lose fragment and credentials, others are their scheme" {
    const allocator = std.testing.allocator;
    const cases = [_][2][]const u8{
        .{ "https://user:pw@a.test:8443/x/y.js?q=1#frag", "https://a.test:8443/x/y.js?q=1" },
        .{ "http://web-platform.test:8000/content-security-policy/support/resource.py?x", "http://web-platform.test:8000/content-security-policy/support/resource.py?x" },
        .{ "http://a.test/p?u=x@y#f", "http://a.test/p?u=x@y" },
        .{ "data:text/javascript,1", "data" },
        .{ "blob:https://a.test/0b2c", "blob" },
        .{ "wss://a.test/echo", "wss://a.test/echo" },
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

test "a source file for reports: stripped like a URL, and no URL is no source file" {
    const cases = [_][2][]const u8{
        .{ "https://dummy.test/script1.js#frag", "https://dummy.test/script1.js" },
        .{ "https://user:password@dummy.test/script1.js", "https://dummy.test/script1.js" },
        .{ "https://dummy.test:8080/script1.js", "https://dummy.test:8080/script1.js" },
        .{ "script2.js", "" },
        .{ "", "" },
        .{ "file:///temp/script3.js", "file" },
        .{ "webpack://node_modules/sample/script4.js", "webpack" },
        .{ "about:blank", "about" },
        .{ "javascript:void(0)", "javascript" },
        .{ "blob:http://test.test/0123", "blob" },
    };
    for (cases) |case| {
        const got = try sourceFileForReports(std.testing.allocator, case[0]);
        defer std.testing.allocator.free(got);
        try std.testing.expectEqualStrings(case[1], got);
    }
}
