//! Test IDs and run identity for wptreport.json, in the form wpt.fyi keys on.
//!
//! wpt.fyi identifies a test by its URL: `/console/x.any.html`,
//! `/console/x.any.worker.html`, `/dom/y.window.html`, `/a/b.html?variant`.
//! The runner's own display name is a source path plus a run label
//! (`console/x.any.js [window]`), which no other tool understands. The runner
//! took each run's URL from MANIFEST.json, so `resolveUrl` picks it from the
//! manifest's URL list for the source; `fallbackUrl` reconstructs one by WPT's
//! documented naming only where the manifest has none.
//!
//! std only, so the rules are pinned by tests `zig build test` runs.

const std = @import("std");

/// The run label the runner builds (`test_parser.runLabel`), taken apart:
/// `null`, `window`, `worker ?variant` or `?variant`.
pub const Label = struct {
    global: ?[]const u8,
    variant: []const u8,

    pub fn parse(label: ?[]const u8) Label {
        const l = label orelse return .{ .global = null, .variant = "" };
        if (l.len == 0) return .{ .global = null, .variant = "" };
        if (l[0] == '?') return .{ .global = null, .variant = l };
        if (std.mem.indexOfScalar(u8, l, ' ')) |sp| {
            return .{ .global = l[0..sp], .variant = std.mem.trim(u8, l[sp + 1 ..], " ") };
        }
        return .{ .global = l, .variant = "" };
    }
};

/// The URL suffix a `.any.js` source gets for a global, as WPT's `wpt serve`
/// and manifest name it. Null for a global name WPT has no `.any` form for.
pub fn anySuffix(global: []const u8) ?[]const u8 {
    const table = [_]struct { []const u8, []const u8 }{
        .{ "window", ".any.html" },
        .{ "worker", ".any.worker.html" },
        .{ "dedicatedworker", ".any.worker.html" },
        .{ "sharedworker", ".any.sharedworker.html" },
        .{ "serviceworker", ".any.serviceworker.html" },
        .{ "dedicatedworker-module", ".any.worker-module.html" },
        .{ "sharedworker-module", ".any.sharedworker-module.html" },
        .{ "serviceworker-module", ".any.serviceworker-module.html" },
        .{ "shadowrealm", ".any.shadowrealm.html" },
        .{ "shadowrealm-in-window", ".any.shadowrealm-in-window.html" },
        .{ "shadowrealm-in-dedicatedworker", ".any.shadowrealm-in-dedicatedworker.html" },
        .{ "shadowrealm-in-sharedworker", ".any.shadowrealm-in-sharedworker.html" },
        .{ "shadowrealm-in-shadowrealm", ".any.shadowrealm-in-shadowrealm.html" },
        .{ "shadowrealm-in-audioworklet", ".any.shadowrealm-in-audioworklet.html" },
        .{ "shadowrealm-in-serviceworker", ".any.shadowrealm-in-serviceworker.html" },
    };
    for (table) |e| if (std.mem.eql(u8, e[0], global)) return e[1];
    return null;
}

fn queryOf(url: []const u8) []const u8 {
    const q = std.mem.indexOfScalar(u8, url, '?') orelse return "";
    return url[q..];
}

fn pathOf(url: []const u8) []const u8 {
    const q = std.mem.indexOfScalar(u8, url, '?') orelse return url;
    return url[0..q];
}

/// The manifest URL (without leading slash, as the manifest stores it) of the
/// run `label` of `source`, out of `candidates` = every URL the manifest lists
/// for that source. Null when none matches, and the caller falls back.
pub fn pickManifestUrl(candidates: []const []const u8, source: []const u8, label: ?[]const u8) ?[]const u8 {
    const parsed = Label.parse(label);
    const is_any = std.mem.endsWith(u8, source, ".any.js");
    const want_suffix: ?[]const u8 = if (is_any) (if (parsed.global) |g| anySuffix(g) else null) else null;
    const base = if (is_any) source[0 .. source.len - ".any.js".len] else "";

    var first_without_global: ?[]const u8 = null;
    for (candidates) |url| {
        if (!std.mem.eql(u8, queryOf(url), parsed.variant)) continue;
        if (want_suffix) |suffix| {
            const p = pathOf(url);
            if (p.len == base.len + suffix.len and
                std.mem.startsWith(u8, p, base) and
                std.mem.endsWith(u8, p, suffix)) return url;
            continue;
        }
        if (first_without_global == null) first_without_global = url;
    }
    // A label naming a global we have no `.any` form for must not silently
    // take another global's URL.
    if (is_any and parsed.global != null and want_suffix == null) return null;
    return first_without_global;
}

/// WPT's documented naming, for a run the manifest has no URL for. Caller owns
/// the result; always begins with '/'.
pub fn fallbackUrl(allocator: std.mem.Allocator, source: []const u8, label: ?[]const u8) ![]u8 {
    const parsed = Label.parse(label);
    var path: []const u8 = source;
    var owned: ?[]u8 = null;
    defer if (owned) |o| allocator.free(o);

    if (std.mem.endsWith(u8, source, ".any.js")) {
        const base = source[0 .. source.len - ".any.js".len];
        const suffix = if (parsed.global) |g| (anySuffix(g) orelse ".any.html") else ".any.html";
        owned = try std.mem.concat(allocator, u8, &.{ base, suffix });
        path = owned.?;
    } else if (std.mem.endsWith(u8, source, ".window.js")) {
        owned = try std.mem.concat(allocator, u8, &.{ source[0 .. source.len - ".js".len], ".html" });
        path = owned.?;
    } else if (std.mem.endsWith(u8, source, ".worker.js")) {
        owned = try std.mem.concat(allocator, u8, &.{ source[0 .. source.len - ".js".len], ".html" });
        path = owned.?;
    }
    return std.fmt.allocPrint(allocator, "/{s}{s}", .{ path, parsed.variant });
}

/// The report's test ID: the manifest URL when there is one, else the fallback.
pub fn resolveUrl(allocator: std.mem.Allocator, candidates: ?[]const []const u8, source: []const u8, label: ?[]const u8) ![]u8 {
    if (candidates) |c| {
        if (pickManifestUrl(c, source, label)) |url| {
            return std.fmt.allocPrint(allocator, "/{s}", .{std.mem.trimStart(u8, url, "/")});
        }
    }
    return fallbackUrl(allocator, source, label);
}

/// Crane's own tests (tests/wpt/crane/) are not WPT and must not be uploaded.
pub fn isCraneTest(source: []const u8) bool {
    const s = std.mem.trimStart(u8, source, "/");
    return std.mem.startsWith(u8, s, "crane/");
}

/// The 40-hex-digit upstream commit in the contents of `.crane-upstream-revision`
/// (surrounding whitespace allowed), lower-cased; null when it is anything else.
pub fn parseUpstreamRevision(contents: []const u8, out: *[40]u8) ?[]const u8 {
    const t = std.mem.trim(u8, contents, &std.ascii.whitespace);
    if (t.len != 40) return null;
    for (t, 0..) |c, i| {
        if (!std.ascii.isHex(c)) return null;
        out[i] = std.ascii.toLower(c);
    }
    return out[0..40];
}

/// wptrunner's `os` value for the host.
pub fn osName(tag: std.Target.Os.Tag) []const u8 {
    return switch (tag) {
        .macos => "mac",
        .linux => "linux",
        .windows => "win",
        else => "unknown",
    };
}

/// wptrunner's (mozinfo's) `processor` value.
pub fn processorName(tag: std.Target.Os.Tag, arch: std.Target.Cpu.Arch) []const u8 {
    return switch (arch) {
        .aarch64 => if (tag == .macos) "arm64" else "aarch64",
        .x86_64 => "x86_64",
        .x86 => "x86",
        .arm => "arm",
        else => "unknown",
    };
}

/// `0.1.0-dev+<short commit>`; without a commit, `0.1.0-dev`.
pub fn browserVersion(allocator: std.mem.Allocator, short_commit: []const u8) ![]u8 {
    if (short_commit.len == 0) return allocator.dupe(u8, "0.1.0-dev");
    return std.fmt.allocPrint(allocator, "0.1.0-dev+{s}", .{short_commit});
}

// ---------------------------------------------------------------------------

const testing = std.testing;

test "Label.parse takes apart every label shape runLabel produces" {
    try testing.expectEqual(@as(?[]const u8, null), Label.parse(null).global);
    try testing.expectEqualStrings("", Label.parse(null).variant);
    try testing.expectEqualStrings("window", Label.parse("window").global.?);
    try testing.expectEqualStrings("", Label.parse("window").variant);
    try testing.expectEqual(@as(?[]const u8, null), Label.parse("?a=b").global);
    try testing.expectEqualStrings("?a=b", Label.parse("?a=b").variant);
    const both = Label.parse("dedicatedworker-module ?include=file");
    try testing.expectEqualStrings("dedicatedworker-module", both.global.?);
    try testing.expectEqualStrings("?include=file", both.variant);
}

test "pickManifestUrl picks each global of an .any.js source" {
    const urls = [_][]const u8{
        "console/x.any.html",
        "console/x.any.worker.html",
        "console/x.any.sharedworker.html",
        "console/x.any.serviceworker.html",
        "console/x.any.worker-module.html",
    };
    const src = "console/x.any.js";
    try testing.expectEqualStrings("console/x.any.html", pickManifestUrl(&urls, src, "window").?);
    try testing.expectEqualStrings("console/x.any.worker.html", pickManifestUrl(&urls, src, "worker").?);
    try testing.expectEqualStrings("console/x.any.sharedworker.html", pickManifestUrl(&urls, src, "sharedworker").?);
    try testing.expectEqualStrings("console/x.any.serviceworker.html", pickManifestUrl(&urls, src, "serviceworker").?);
    try testing.expectEqualStrings("console/x.any.worker-module.html", pickManifestUrl(&urls, src, "dedicatedworker-module").?);
}

test "pickManifestUrl: .any.worker.html is not mistaken for the window run of a sibling" {
    // x.any.js and x.any.worker.js can coexist in a directory; the base
    // must match exactly, not by prefix.
    const urls = [_][]const u8{ "d/x.any.worker.html", "d/x.any.html" };
    try testing.expectEqualStrings("d/x.any.html", pickManifestUrl(&urls, "d/x.any.js", "window").?);
}

test "pickManifestUrl: single-global sources carry no label" {
    const urls = [_][]const u8{"a/b.any.worker.html"};
    try testing.expectEqualStrings("a/b.any.worker.html", pickManifestUrl(&urls, "a/b.any.js", null).?);
    const w = [_][]const u8{"a/c.window.html"};
    try testing.expectEqualStrings("a/c.window.html", pickManifestUrl(&w, "a/c.window.js", null).?);
    const wk = [_][]const u8{"a/d.worker.html"};
    try testing.expectEqualStrings("a/d.worker.html", pickManifestUrl(&wk, "a/d.worker.js", null).?);
}

test "pickManifestUrl: variants select by query, with and without a global" {
    const html = [_][]const u8{ "e/f.html?windows-1252", "e/f.html?ibm866" };
    try testing.expectEqualStrings("e/f.html?ibm866", pickManifestUrl(&html, "e/f.html", "?ibm866").?);
    const any = [_][]const u8{ "u/g.any.html?include=file", "u/g.any.worker.html?include=file", "u/g.any.html?include=http", "u/g.any.worker.html?include=http" };
    try testing.expectEqualStrings("u/g.any.worker.html?include=http", pickManifestUrl(&any, "u/g.any.js", "worker ?include=http").?);
    try testing.expectEqualStrings("u/g.any.html?include=file", pickManifestUrl(&any, "u/g.any.js", "window ?include=file").?);
}

test "pickManifestUrl: no match is null, never another run's URL" {
    const urls = [_][]const u8{"c/x.any.html"};
    try testing.expectEqual(@as(?[]const u8, null), pickManifestUrl(&urls, "c/x.any.js", "worker"));
    try testing.expectEqual(@as(?[]const u8, null), pickManifestUrl(&urls, "c/x.any.js", "shadowrealm-bogus"));
    try testing.expectEqual(@as(?[]const u8, null), pickManifestUrl(&urls, "c/x.any.js", "?v"));
}

test "resolveUrl prefixes a slash and falls back to WPT naming" {
    const a = testing.allocator;
    const urls = [_][]const u8{"console/x.any.worker.html"};
    const hit = try resolveUrl(a, &urls, "console/x.any.js", "worker");
    defer a.free(hit);
    try testing.expectEqualStrings("/console/x.any.worker.html", hit);

    const cases = [_]struct { []const u8, ?[]const u8, []const u8 }{
        .{ "console/x.any.js", "window", "/console/x.any.html" },
        .{ "console/x.any.js", null, "/console/x.any.html" },
        .{ "console/x.any.js", "worker", "/console/x.any.worker.html" },
        .{ "console/x.any.js", "sharedworker", "/console/x.any.sharedworker.html" },
        .{ "console/x.any.js", "serviceworker", "/console/x.any.serviceworker.html" },
        .{ "console/x.any.js", "dedicatedworker-module", "/console/x.any.worker-module.html" },
        .{ "d/x.window.js", null, "/d/x.window.html" },
        .{ "d/x.worker.js", null, "/d/x.worker.html" },
        .{ "a/b.html", "?variant", "/a/b.html?variant" },
        .{ "a/b.https.html", null, "/a/b.https.html" },
        .{ "u/g.any.js", "worker ?include=file", "/u/g.any.worker.html?include=file" },
    };
    for (cases) |c| {
        const got = try resolveUrl(a, null, c[0], c[1]);
        defer a.free(got);
        try testing.expectEqualStrings(c[2], got);
    }
}

test "isCraneTest excludes only tests/wpt/crane" {
    try testing.expect(isCraneTest("crane/foo.html"));
    try testing.expect(isCraneTest("/crane/foo.any.js"));
    try testing.expect(!isCraneTest("dom/crane/foo.html"));
    try testing.expect(!isCraneTest("cranes/foo.html"));
}

test "parseUpstreamRevision accepts exactly 40 hex digits" {
    var buf: [40]u8 = undefined;
    const good = "0123456789abcdef0123456789ABCDEF01234567\n";
    try testing.expectEqualStrings("0123456789abcdef0123456789abcdef01234567", parseUpstreamRevision(good, &buf).?);
    try testing.expectEqual(@as(?[]const u8, null), parseUpstreamRevision("", &buf));
    try testing.expectEqual(@as(?[]const u8, null), parseUpstreamRevision("abc123", &buf));
    try testing.expectEqual(@as(?[]const u8, null), parseUpstreamRevision("0123456789abcdef0123456789abcdef0123456g", &buf));
    try testing.expectEqual(@as(?[]const u8, null), parseUpstreamRevision("0123456789abcdef0123456789abcdef012345678", &buf));
}

test "run_info names: os, processor, browser_version" {
    try testing.expectEqualStrings("mac", osName(.macos));
    try testing.expectEqualStrings("linux", osName(.linux));
    try testing.expectEqualStrings("arm64", processorName(.macos, .aarch64));
    try testing.expectEqualStrings("aarch64", processorName(.linux, .aarch64));
    try testing.expectEqualStrings("x86_64", processorName(.macos, .x86_64));
    const a = testing.allocator;
    const v = try browserVersion(a, "73e0b7764");
    defer a.free(v);
    try testing.expectEqualStrings("0.1.0-dev+73e0b7764", v);
    const n = try browserVersion(a, "");
    defer a.free(n);
    try testing.expectEqualStrings("0.1.0-dev", n);
}
