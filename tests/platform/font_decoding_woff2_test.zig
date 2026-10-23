//! WOFF 2.0 through `platform.decodeFont` (decision 20): kit/sfnt decodes it
//! as Google's woff2 library does (Blink, Gecko and WebKit all use it) and
//! then checks the sfnt as OTS does. The fixtures are the W3C WOFF2
//! conformance suite's fonts in WPT (css/WOFF2/support/), each expected to
//! load or not as its test's assertion and conformance anchor say - except
//! header-totalsfntsize-001, which the browser majority rejects (woff2.zig).

const std = @import("std");
const platform = @import("platform");

const testing = std.testing;

const limits: platform.FontLimits = .{ .max_bytes = 128 << 20, .max_sfnt_bytes = 128 << 20 };

const suite = "tests/wpt/css/WOFF2/support/";

fn read(path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(testing.io, path, testing.allocator, .limited(16 << 20));
}

fn decode(bytes: []const u8, name: []const u8) platform.FontError!platform.DecodedFont {
    return platform.decodeFont(testing.allocator, .from(bytes), .from(name), limits);
}

/// The suite's fonts that must load: valid-*, the noeffect and transform
/// cases, the alternate 255UInt16 encodings, custom tags for known tables,
/// a non-zero reserved field ("MUST NOT reject"), and the glyf sizes and
/// boxes the decoder must accept or compute.
const loads = [_][]const u8{
    "valid-001.woff2",                     "valid-002.woff2",                     "valid-003.woff2",
    "valid-004.woff2",                     "valid-005.woff2",                     "valid-006.woff2",
    "valid-007.woff2",                     "valid-008.woff2",                     "available-002.woff2",
    "datatypes-alt-255uint16-001.woff2",   "directory-knowntags-001.woff2",       "header-reserved-001.woff2",
    "header-totalsfntsize-002.woff2",      "metadata-noeffect-001.woff2",         "metadata-noeffect-002.woff2",
    "privatedata-noeffect-001.woff2",      "privatedata-noeffect-002.woff2",      "tabledata-glyf-bbox-001.woff2",
    "tabledata-glyf-origlength-001.woff2", "tabledata-glyf-origlength-002.woff2", "tabledata-glyf-origlength-003.woff2",
    "tabledata-recontruct-loca-001.woff2", "tabledata-transform-hmtx-001.woff2",  "tabledata-transform-hmtx-002.woff2",
};

/// The suite's fonts that must not load.
const rejected = [_][]const u8{
    "blocks-extraneous-data-001.woff2",        "blocks-extraneous-data-002.woff2",        "blocks-extraneous-data-003.woff2",
    "blocks-extraneous-data-004.woff2",        "blocks-extraneous-data-005.woff2",        "blocks-extraneous-data-006.woff2",
    "blocks-extraneous-data-007.woff2",        "blocks-extraneous-data-008.woff2",        "blocks-overlap-001.woff2",
    "blocks-overlap-002.woff2",                "blocks-overlap-003.woff2",                "datatypes-invalid-base128-001.woff2",
    "datatypes-invalid-base128-002.woff2",     "datatypes-invalid-base128-003.woff2",     "directory-mismatched-tables-001.woff2",
    "header-length-001.woff2",                 "header-length-002.woff2",                 "header-numTables-001.woff2",
    "header-signature-001.woff2",              "tabledata-bad-origlength-loca-001.woff2", "tabledata-bad-origlength-loca-002.woff2",
    "tabledata-brotli-001.woff2",              "tabledata-decompressed-length-001.woff2", "tabledata-decompressed-length-002.woff2",
    "tabledata-decompressed-length-003.woff2", "tabledata-decompressed-length-004.woff2", "tabledata-extraneous-data-001.woff2",
    "tabledata-glyf-bbox-002.woff2",           "tabledata-glyf-bbox-003.woff2",           "tabledata-non-zero-loca-001.woff2",
    "tabledata-transform-bad-flag-001.woff2",  "tabledata-transform-bad-flag-002.woff2",  "tabledata-transform-hmtx-003.woff2",
    "tabledata-transform-hmtx-004.woff2",
    // Below the file's own size: Blink and OTS refuse it (woff2.zig).
         "header-totalsfntsize-001.woff2",
};

test "the WOFF2 conformance suite: every font that must load, loads" {
    var failures: usize = 0;
    for (loads) |name| {
        const path = try std.mem.concat(testing.allocator, u8, &.{ suite, name });
        defer testing.allocator.free(path);
        const bytes = try read(path);
        defer testing.allocator.free(bytes);
        if (decode(bytes, "")) |face| {
            var f = face;
            f.deinit(testing.allocator);
        } else |err| {
            std.debug.print("{s}: {s}\n", .{ name, @errorName(err) });
            failures += 1;
        }
    }
    try testing.expectEqual(@as(usize, 0), failures);
}

test "the WOFF2 conformance suite: every font that must not load, does not" {
    var failures: usize = 0;
    for (rejected) |name| {
        const path = try std.mem.concat(testing.allocator, u8, &.{ suite, name });
        defer testing.allocator.free(path);
        const bytes = try read(path);
        defer testing.allocator.free(bytes);
        if (decode(bytes, "")) |face| {
            var f = face;
            f.deinit(testing.allocator);
            std.debug.print("{s}: loaded\n", .{name});
            failures += 1;
        } else |err| {
            // The signature is not wOF2, so it is no format at all.
            const expected: anyerror = if (std.mem.eql(u8, name, "header-signature-001.woff2")) error.UnsupportedFormat else error.Corrupt;
            if (err != expected) {
                std.debug.print("{s}: {s}\n", .{ name, @errorName(err) });
                failures += 1;
            }
        }
    }
    try testing.expectEqual(@as(usize, 0), failures);
}

test "the suite's metadata display fonts load: metadata never affects loading" {
    var dir = try std.Io.Dir.cwd().openDir(testing.io, suite, .{ .iterate = true });
    defer dir.close(testing.io);
    var it = dir.iterate();
    var count: usize = 0;
    var failures: usize = 0;
    while (try it.next(testing.io)) |entry| {
        if (!std.mem.startsWith(u8, entry.name, "metadatadisplay-") or !std.mem.endsWith(u8, entry.name, ".woff2")) continue;
        const bytes = try dir.readFileAlloc(testing.io, entry.name, testing.allocator, .limited(1 << 20));
        defer testing.allocator.free(bytes);
        count += 1;
        if (decode(bytes, "")) |face| {
            var f = face;
            f.deinit(testing.allocator);
        } else |err| {
            std.debug.print("{s}: {s}\n", .{ entry.name, @errorName(err) });
            failures += 1;
        }
    }
    try testing.expect(count > 200);
    try testing.expectEqual(@as(usize, 0), failures);
}

test "a WOFF2 collection: the first face, or the one its PostScript name selects" {
    const bytes = try read(suite ++ "available-002.woff2");
    defer testing.allocator.free(bytes);
    var first = try decode(bytes, "");
    defer first.deinit(testing.allocator);
    try testing.expect(!first.matched_name);
    try testing.expectEqualStrings("WOFFTestTTF0-Regular", first.postscript_name.slice());
    // available-002.xht names its faces "#1" and "#2", a 1-based scheme no
    // browser ships: neither is a PostScript name, so each is face 0.
    var numbered = try decode(bytes, "2");
    defer numbered.deinit(testing.allocator);
    try testing.expect(!numbered.matched_name);
    try testing.expectEqualStrings("WOFFTestTTF0-Regular", numbered.postscript_name.slice());
    var second = try decode(bytes, "WOFFTestTTF1-Regular");
    defer second.deinit(testing.allocator);
    try testing.expect(second.matched_name);
    try testing.expectEqualStrings("WOFFTestTTF1-Regular", second.postscript_name.slice());
}

test "WPT's WOFF2 fonts decode" {
    inline for (.{ "tests/wpt/fonts/noto/NotoNaskhArabic-regular.woff2", "tests/wpt/fonts/noto/NotoSansMongolian-regular.woff2", "tests/wpt/fonts/noto/NotoSansNko-regular-webfont.woff2" }) |path| {
        const bytes = try read(path);
        defer testing.allocator.free(bytes);
        var face = decode(bytes, "") catch |err| {
            std.debug.print("{s}: {s}\n", .{ path, @errorName(err) });
            return err;
        };
        face.deinit(testing.allocator);
    }
}

test "a WOFF2 decode fails cleanly at every allocation" {
    const bytes = try read(suite ++ "valid-005.woff2");
    defer testing.allocator.free(bytes);
    try testing.checkAllAllocationFailures(testing.allocator, struct {
        fn run(allocator: std.mem.Allocator, data: []const u8) !void {
            var face = try platform.decodeFont(allocator, .from(data), .{}, limits);
            face.deinit(allocator);
        }
    }.run, .{bytes});
}

test "the sfnt limit bounds a WOFF2's declared size" {
    const bytes = try read(suite ++ "valid-005.woff2");
    defer testing.allocator.free(bytes);
    const declared = std.mem.readInt(u32, bytes[16..20], .big);
    const small: platform.FontLimits = .{ .max_bytes = 128 << 20, .max_sfnt_bytes = declared - 1 };
    try testing.expectError(error.TooLarge, platform.decodeFont(testing.allocator, .from(bytes), .{}, small));
}
