//! WOFF 1.0 through `platform.decodeFont` (decision 20): kit/sfnt unwraps
//! it as OTS does (ots.cc ProcessWOFF), which Blink and Gecko run on WOFF.
//! WPT's fonts/pass.woff is the fixture; each error class is a copy of it
//! with one field changed. Its expected description is fontTools 4.62's
//! reading of the same file.

const std = @import("std");
const platform = @import("platform");

const testing = std.testing;

const limits: platform.FontLimits = .{ .max_bytes = 128 << 20, .max_sfnt_bytes = 128 << 20 };

fn readWpt(comptime path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(testing.io, "tests/wpt/" ++ path, testing.allocator, .limited(16 << 20));
}

fn decode(bytes: []const u8) platform.FontError!platform.DecodedFont {
    return platform.decodeFont(testing.allocator, .from(bytes), .{}, limits);
}

fn set32(bytes: []u8, at: usize, value: u32) void {
    std.mem.writeInt(u32, bytes[at..][0..4], value, .big);
}

fn get32(bytes: []const u8, at: usize) u32 {
    return std.mem.readInt(u32, bytes[at..][0..4], .big);
}

test "pass.woff: unwrapped and described" {
    const bytes = try readWpt("fonts/pass.woff");
    defer testing.allocator.free(bytes);
    var face = try decode(bytes);
    defer face.deinit(testing.allocator);
    try testing.expectEqualStrings("WOFF Test TTF", face.family.slice());
    try testing.expectEqualStrings("WOFFTestTTF-Regular", face.postscript_name.slice());
    try testing.expectEqual(@as(u16, 2048), face.metrics.units_per_em);
    try testing.expectEqual(@as(f32, 1454), face.metrics.ascent);
    try testing.expectEqual(@as(f32, 20), face.metrics.descent);
    try testing.expect(face.metrics.x_height.present);
    try testing.expectEqual(@as(f32, 1024), face.metrics.x_height.value);
    try testing.expectEqual(@as(f32, 1536), face.metrics.cap_height.value);
}

test "every WOFF font WPT ships decodes" {
    inline for (.{ "fonts/fail.woff", "fonts/AD.woff", "fonts/GentiumPlus-R.woff", "fonts/mplus-1p-regular.woff", "fonts/Revalia.woff", "fonts/Scheherazade-Regular.woff", "fonts/sileot-webfont.woff", "fonts/tcu-font.woff", "fonts/noto/noto-sans-v8-latin-regular.woff" }) |path| {
        const bytes = try readWpt(path);
        defer testing.allocator.free(bytes);
        var face = decode(bytes) catch |err| {
            std.debug.print("{s}: {s}\n", .{ path, @errorName(err) });
            return err;
        };
        face.deinit(testing.allocator);
    }
}

test "the length field is the file's length" {
    const bytes = try readWpt("fonts/pass.woff");
    defer testing.allocator.free(bytes);
    set32(bytes, 8, get32(bytes, 8) + 4);
    try testing.expectError(error.Corrupt, decode(bytes));
}

test "nothing follows the last block (OTS: \"trailing junk\")" {
    const original = try readWpt("fonts/pass.woff");
    defer testing.allocator.free(original);
    const bytes = try std.mem.concat(testing.allocator, u8, &.{ original, &[_]u8{0} ** 4 });
    defer testing.allocator.free(bytes);
    set32(bytes, 8, @intCast(bytes.len));
    try testing.expectError(error.Corrupt, decode(bytes));
}

test "the reserved field is 0" {
    const bytes = try readWpt("fonts/pass.woff");
    defer testing.allocator.free(bytes);
    bytes[14] = 1;
    try testing.expectError(error.Corrupt, decode(bytes));
}

test "totalSfntSize is exactly the sfnt the directory declares" {
    const bytes = try readWpt("fonts/pass.woff");
    defer testing.allocator.free(bytes);
    set32(bytes, 16, get32(bytes, 16) - 4);
    try testing.expectError(error.Corrupt, decode(bytes));
}

test "a compressed table inflates to exactly its origLength, its Adler-32 intact" {
    const bytes = try readWpt("fonts/pass.woff");
    defer testing.allocator.free(bytes);
    // OS/2, the first record, is stored compressed (67 of 96 bytes): its
    // zlib checksum is its stored data's last four bytes.
    const offset = get32(bytes, 44 + 4);
    const stored = get32(bytes, 44 + 8);
    try testing.expect(stored < get32(bytes, 44 + 12));
    bytes[offset + stored - 1] ^= 0xff;
    try testing.expectError(error.Corrupt, decode(bytes));
}

test "data that ends early is Corrupt" {
    const bytes = try readWpt("fonts/pass.woff");
    defer testing.allocator.free(bytes);
    try testing.expectError(error.Corrupt, decode(bytes[0 .. bytes.len - 8]));
    try testing.expectError(error.Corrupt, decode(bytes[0..20]));
}

test "the sfnt limit: TooLarge before anything is inflated" {
    const bytes = try readWpt("fonts/pass.woff");
    defer testing.allocator.free(bytes);
    const total = get32(bytes, 16);
    const small: platform.FontLimits = .{ .max_bytes = 128 << 20, .max_sfnt_bytes = total - 1 };
    try testing.expectError(error.TooLarge, platform.decodeFont(testing.allocator, .from(bytes), .{}, small));
}

test "a WOFF decode fails cleanly at every allocation" {
    const bytes = try readWpt("fonts/pass.woff");
    defer testing.allocator.free(bytes);
    try testing.checkAllAllocationFailures(testing.allocator, struct {
        fn run(allocator: std.mem.Allocator, data: []const u8) !void {
            var face = try platform.decodeFont(allocator, .from(data), .{}, limits);
            face.deinit(allocator);
        }
    }.run, .{bytes});
}
