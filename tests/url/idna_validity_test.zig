//! URL host parsing applies UTS #46 validity after mapping and normalization.
const std = @import("std");
const url = @import("url");

/// `s` repeated `n` times: what `s ** n` was (Zig 0.17 removes `**`; roadmap zig-017).
fn repeat(comptime s: []const u8, comptime n: usize) *const [s.len * n:0]u8 {
    return comptime blk: {
        @setEvalBranchQuota(10 * n + 1000);
        var out: [s.len * n:0]u8 = undefined;
        for (0..n) |i| @memcpy(out[i * s.len ..][0..s.len], s);
        const final = out;
        break :blk &final;
    };
}
const idna = url.idna;

fn ascii(input: []const u8, expected: []const u8, strict: bool) !void {
    const result = try idna.domainToASCII(std.testing.allocator, input, strict);
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings(expected, result);
}

fn invalid(input: []const u8, strict: bool) !void {
    if (idna.domainToASCII(std.testing.allocator, input, strict)) |result| {
        defer std.testing.allocator.free(result);
        std.debug.print("IDNA unexpectedly accepted {s} as {s}\n", .{ input, result });
        return error.TestUnexpectedResult;
    } else |err| {
        if (err == error.OutOfMemory) return err;
    }
}

test "URL preserves ASCII-only ACE labels but validates every label in a Unicode domain" {
    for ([_][]const u8{ "xn--", "xn--a", "xn--0", "xn--ascii-", "xn--8i7caa" }) |label| {
        try ascii(label, label, false);
        const mixed = try std.fmt.allocPrint(std.testing.allocator, "{s}.é", .{label});
        defer std.testing.allocator.free(mixed);
        try invalid(mixed, false);
        try invalid(label, true);
    }
    try ascii("XN--BCHER-KVA", "xn--bcher-kva", false);
    try ascii("xn--bcher-kva.é", "xn--bcher-kva.xn--9ca", false);
    try invalid("xn--tešla", false);
    try invalid("xn--u-ccb.é", false); // Decodes to decomposed u + diaeresis.
}

test "IDNA rejects leading marks including marks with combining class zero" {
    try invalid("\u{0308}a", false);
    try invalid("\u{0903}a", false); // Mc, canonical combining class zero.
    try invalid("\u{20dd}a", false); // Me, canonical combining class zero.
    try ascii("a\u{0308}", "xn--4ca", false);
}

test "IDNA rejects disallowed characters and follows ignored mapping data" {
    for ([_][]const u8{ "\u{0378}", "\u{fffd}", "\u{115f}" }) |label| try invalid(label, false);
    try ascii("a\u{00ad}b", "ab", false);
    for ([_][]const u8{ "a\u{115f}b", "a\u{1160}b", "a\u{3164}b", "a\u{ffa0}b", "a\u{17b4}b", "a\u{17b5}b", "a\u{1d176}b" }) |label| try ascii(label, "ab", false);
    try ascii("\u{1e9e}", "xn--zca", false);
}

test "IDNA applies RFC5893 to every nonempty label of a bidi domain" {
    for ([_][]const u8{ "aא", "אa", "א-", "א1١", "1.א", "a-.א", "١" }) |label| try invalid(label, false);
    try ascii("א", "xn--4db", false);
    try ascii("א\u{0308}", "xn--ssa73l", false);
    try ascii("a.א", "a.xn--4db", false);
    try ascii("a-.é", "a-.xn--9ca", false); // No bidi domain.
}

test "IDNA DNS length and hyphen checks are only strict" {
    try ascii("..", "..", false);
    try ascii("-a..é-.", "-a..xn----9fa.", false);
    try invalid("..", true);
    try invalid("a..b", true);
    try invalid("-a", true);
    try invalid("ab--c", true);
    try invalid("éa--b", true); // Third and fourth characters, not UTF-8 bytes.
    try ascii("é--a", "xn----a-9la", true);
    try invalid(&@as([64:0]u8, @splat('a')), true);
    try invalid(repeat(repeat("a", 63) ++ ".", 3) ++ &@as([62:0]u8, @splat('a')), true);
    try ascii(&@as([64:0]u8, @splat('a')), &@as([64:0]u8, @splat('a')), false);
    const maximum = repeat(repeat("a", 63) ++ ".", 3) ++ &@as([61:0]u8, @splat('a'));
    try ascii(maximum, maximum, true);
    try ascii(maximum ++ ".", maximum ++ ".", true);
}

test "host checks forbidden code points after NFC" {
    const parsed = try url.host_parser.parseHost(std.testing.allocator, "<\u{0338}", false, null);
    defer parsed.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("xn--gdh", parsed.domain);
}

test "IDNA rejects plane-three characters unassigned in the pinned Unicode17 data" {
    try invalid("\u{3f8cd}", false);
    try invalid("\u{3e8ac}.\u{0729}.쯙5", false);
}

test "IDNA normalization composes class-zero pairs and preserves blocking" {
    const n = idna.normalization_mod;
    const a = std.testing.allocator;
    const composed = try n.normalize(a, "\u{09c7}\u{09be}");
    defer a.free(composed);
    try std.testing.expectEqualStrings("\u{09cb}", composed);
    const blocked = try n.normalize(a, "A\u{0305}\u{0300}");
    defer a.free(blocked);
    try std.testing.expectEqualStrings("A\u{0305}\u{0300}", blocked);
}

fn allocationPaths(a: std.mem.Allocator) !void {
    const ascii_result = try idna.domainToASCII(a, "Example.COM", false);
    defer a.free(ascii_result);
    const unicode_result = try idna.domainToASCII(a, "Bücher.é", false);
    defer a.free(unicode_result);
    if (idna.domainToASCII(a, "a\u{200c}b", false)) |unexpected| {
        defer a.free(unexpected);
        return error.TestUnexpectedResult;
    } else |err| switch (err) {
        error.ContextError => {},
        else => return err,
    }
}

test "IDNA releases intermediates and propagates every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationPaths, .{});
}

test "host diagnostics record strict IDNA errors without rejecting ASCII compatibility" {
    const a = std.testing.allocator;
    var errors = @import("infra").List(url.validation.ValidationError).init(a);
    defer errors.deinit();
    const parsed = try url.host_parser.parseHost(a, "xn--a", false, &errors);
    defer parsed.deinit(a);
    try std.testing.expectEqualStrings("xn--a", parsed.domain);
    try std.testing.expectEqual(@as(usize, 1), errors.len);
    try std.testing.expectEqual(url.validation.ErrorType.domain_to_ascii, errors.items()[0].type);
    try std.testing.expect(!errors.items()[0].isFailure());
}

test "host records one strict IDNA diagnostic when non-strict parsing also fails" {
    const a = std.testing.allocator;
    var errors = @import("infra").List(url.validation.ValidationError).init(a);
    defer errors.deinit();
    try std.testing.expectError(error.InvalidHost, url.host_parser.parseHost(a, "a\u{200c}b", false, &errors));
    try std.testing.expectEqual(@as(usize, 1), errors.len);
    try std.testing.expectEqual(url.validation.ErrorType.domain_to_ascii, errors.items()[0].type);
}
