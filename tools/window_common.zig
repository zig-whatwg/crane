//! What the committed window runners share (lane tool1): `perf_bench
//! window` (tools/perf_bench/window.zig) and `wpt_ab`
//! (tests/wpt_runner/ab.zig) - the clock every line a person reads is
//! stamped with (12-hour US Eastern: AGENTS.md, "Times are US Eastern"),
//! commit abbreviations, and SHA256SUMS lines as shasum and sha256sum write
//! them. std only.

const std = @import("std");
const Allocator = std.mem.Allocator;

// The clock: 12-hour US Eastern.

/// Days from 1970-01-01 to the civil date (proleptic Gregorian; Howard
/// Hinnant's days_from_civil).
pub fn daysFromCivil(year: i64, month: u32, day: u32) i64 {
    const y = if (month <= 2) year - 1 else year;
    const era = @divFloor(y, 400);
    const yoe = y - era * 400;
    const m: i64 = month;
    const mp = if (m > 2) m - 3 else m + 9;
    const doy = @divFloor(153 * mp + 2, 5) + @as(i64, day) - 1;
    const doe = yoe * 365 + @divFloor(yoe, 4) - @divFloor(yoe, 100) + doy;
    return era * 146097 + doe - 719468;
}

/// The day of the month of the `nth` Sunday of `month` (1-based).
fn nthSunday(year: i64, month: u32, nth: u32) u32 {
    // 1970-01-01 was a Thursday: weekday 0 = Sunday.
    const first = daysFromCivil(year, month, 1);
    const weekday: u32 = @intCast(@mod(first + 4, 7));
    const first_sunday = 1 + (7 - weekday) % 7;
    return first_sunday + 7 * (nth - 1);
}

/// US Eastern's offset from UTC at `utc_s`, in hours: -4 in daylight time
/// (since 2007: from the second Sunday of March, 2:00 AM standard time, to
/// the first Sunday of November, 2:00 AM daylight time), else -5.
pub fn easternOffsetHours(utc_s: i64) i64 {
    const day = @divFloor(utc_s, std.time.s_per_day);
    const es: std.time.epoch.EpochDay = .{ .day = @intCast(day) };
    const year: i64 = es.calculateYearDay().year;
    const start = daysFromCivil(year, 3, nthSunday(year, 3, 2)) * std.time.s_per_day + 7 * 3600;
    const end = daysFromCivil(year, 11, nthSunday(year, 11, 1)) * std.time.s_per_day + 6 * 3600;
    return if (utc_s >= start and utc_s < end) -4 else -5;
}

/// A clock reading for a person: "10:06 PM ET"; with `date`,
/// "10:06 PM ET 2026-11-24" (the Eastern date).
pub fn easternTime(buf: []u8, utc_s: i64, date: bool) []const u8 {
    const local = utc_s + easternOffsetHours(utc_s) * 3600;
    const es: std.time.epoch.EpochSeconds = .{ .secs = @intCast(local) };
    const ds = es.getDaySeconds();
    const h24 = ds.getHoursIntoDay();
    const h12 = if (h24 % 12 == 0) 12 else h24 % 12;
    const half = if (h24 < 12) "AM" else "PM";
    if (!date) return std.fmt.bufPrint(buf, "{d}:{d:0>2} {s} ET", .{ h12, ds.getMinutesIntoHour(), half }) catch buf[0..0];
    const yd = es.getEpochDay().calculateYearDay();
    const md = yd.calculateMonthDay();
    return std.fmt.bufPrint(buf, "{d}:{d:0>2} {s} ET {d}-{d:0>2}-{d:0>2}", .{ h12, ds.getMinutesIntoHour(), half, yd.year, md.month.numeric(), md.day_index + 1 }) catch buf[0..0];
}

/// "20261124T220600Z": a UTC stamp for a name (data, not for a person).
pub fn utcStamp(buf: []u8, utc_s: i64) []const u8 {
    const es: std.time.epoch.EpochSeconds = .{ .secs = @intCast(utc_s) };
    const ds = es.getDaySeconds();
    const yd = es.getEpochDay().calculateYearDay();
    const md = yd.calculateMonthDay();
    return std.fmt.bufPrint(buf, "{d}{d:0>2}{d:0>2}T{d:0>2}{d:0>2}{d:0>2}Z", .{ yd.year, md.month.numeric(), md.day_index + 1, ds.getHoursIntoDay(), ds.getMinutesIntoHour(), ds.getSecondsIntoMinute() }) catch buf[0..0];
}

// Commits and SHA256SUMS.

pub fn isHex(c: u8) bool {
    return std.ascii.isDigit(c) or (c >= 'a' and c <= 'f');
}

/// Whether two abbreviations name one commit: both at least 7 hex digits,
/// the shorter a prefix of the longer.
pub fn sameCommit(a: []const u8, b: []const u8) bool {
    const x = std.mem.trim(u8, a, " \t\r\n");
    const y = std.mem.trim(u8, b, " \t\r\n");
    if (x.len < 7 or y.len < 7) return false;
    for (x) |c| if (!isHex(c)) return false;
    for (y) |c| if (!isHex(c)) return false;
    const n = @min(x.len, y.len);
    return std.mem.eql(u8, x[0..n], y[0..n]);
}

/// Whether `text` names `commit` (any run of hex digits that is the same
/// commit, `sameCommit`).
pub fn mentionsCommit(text: []const u8, commit: []const u8) bool {
    var i: usize = 0;
    while (i < text.len) {
        if (!isHex(text[i])) {
            i += 1;
            continue;
        }
        const start = i;
        while (i < text.len and isHex(text[i])) i += 1;
        // A whole token: not part of a longer word ("deadbeefcafe" in
        // "xdeadbeefcafe" is not a sha).
        const before_ok = start == 0 or !std.ascii.isAlphanumeric(text[start - 1]);
        const after_ok = i == text.len or !std.ascii.isAlphanumeric(text[i]);
        if (before_ok and after_ok and sameCommit(text[start..i], commit)) return true;
    }
    return false;
}

/// A SHA-256 in lowercase hex.
pub fn isSha256(text: []const u8) bool {
    if (text.len != 64) return false;
    for (text) |c| if (!isHex(c)) return false;
    return true;
}

/// One SHA256SUMS line: "<hex>  <file>" (shasum's output; "*" before the
/// name in binary mode).
pub const SumLine = struct { sha256: []const u8, file: []const u8 };

pub fn parseSums(arena: Allocator, text: []const u8) error{ OutOfMemory, BadSumsLine }![]const SumLine {
    var out: std.ArrayList(SumLine) = .empty;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0) continue;
        const sp = std.mem.indexOfAny(u8, line, " \t") orelse return error.BadSumsLine;
        const sha = line[0..sp];
        var name = std.mem.trimStart(u8, line[sp..], " \t");
        if (name.len > 0 and name[0] == '*') name = name[1..];
        if (!isSha256(sha) or name.len == 0 or std.mem.indexOfScalar(u8, name, '/') != null) return error.BadSumsLine;
        try out.append(arena, .{ .sha256 = sha, .file = name });
    }
    return out.items;
}

/// The SHA-256 of the file at `path`, in lowercase hex.
pub fn sha256File(io: std.Io, path: []const u8, out: *[64]u8) !void {
    var file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    var buf: [16 * 1024]u8 = undefined;
    var reader = file.reader(io, &buf);
    while (true) {
        const chunk = reader.interface.peekGreedy(1) catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };
        hasher.update(chunk);
        reader.interface.toss(chunk.len);
    }
    var digest: [32]u8 = undefined;
    hasher.final(&digest);
    out.* = std.fmt.bytesToHex(digest, .lower);
}

/// `dir`'s SHA256SUMS checked: every file it lists matches, and every name
/// in `required` is listed. Null when they hold; else what does not.
pub fn sumsProblem(arena: Allocator, io: std.Io, dir: []const u8, required: []const []const u8) !?[]const u8 {
    const path = try std.fs.path.join(arena, &.{ dir, "SHA256SUMS" });
    const text = std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 20)) catch return try std.fmt.allocPrint(arena, "{s} missing", .{path});
    const sums = parseSums(arena, text) catch return try std.fmt.allocPrint(arena, "{s}: a line is not \"<sha256>  <file>\"", .{path});
    for (required) |need| {
        for (sums) |s| {
            if (std.mem.eql(u8, s.file, need)) break;
        } else return try std.fmt.allocPrint(arena, "{s} does not cover {s}", .{ path, need });
    }
    for (sums) |s| {
        const p = try std.fs.path.join(arena, &.{ dir, s.file });
        var hex: [64]u8 = undefined;
        sha256File(io, p, &hex) catch |err| return try std.fmt.allocPrint(arena, "{s}: {t}", .{ p, err });
        if (!std.mem.eql(u8, &hex, s.sha256)) return try std.fmt.allocPrint(arena, "{s} does not match its SHA256SUMS", .{p});
    }
    return null;
}

const testing = std.testing;

test "the clock reads US Eastern, 12-hour, across both daylight-time changes" {
    var buf: [48]u8 = undefined;
    // 2026-11-25 03:06 UTC: 10:06 PM EST on the 24th.
    const t = daysFromCivil(2026, 11, 25) * 86400 + 3 * 3600 + 6 * 60;
    try testing.expectEqualStrings("10:06 PM ET", easternTime(&buf, t, false));
    try testing.expectEqualStrings("10:06 PM ET 2026-11-24", easternTime(&buf, t, true));
    // Summer: 2026-07-04 16:00 UTC is noon EDT.
    try testing.expectEqualStrings("12:00 PM ET", easternTime(&buf, daysFromCivil(2026, 7, 4) * 86400 + 16 * 3600, false));
    // Midnight is 12 AM: 2026-01-15 05:30 UTC.
    try testing.expectEqualStrings("12:30 AM ET", easternTime(&buf, daysFromCivil(2026, 1, 15) * 86400 + 5 * 3600 + 30 * 60, false));
    // Spring forward, 2026-03-08 (the second Sunday): 1:59 AM EST, then 3:00 AM EDT.
    const spring = daysFromCivil(2026, 3, 8) * 86400 + 7 * 3600;
    try testing.expectEqualStrings("1:59 AM ET", easternTime(&buf, spring - 60, false));
    try testing.expectEqualStrings("3:00 AM ET", easternTime(&buf, spring, false));
    // Fall back, 2026-11-01 (the first Sunday): 1:59 AM EDT, then 1:00 AM EST.
    const fall = daysFromCivil(2026, 11, 1) * 86400 + 6 * 3600;
    try testing.expectEqualStrings("1:59 AM ET", easternTime(&buf, fall - 60, false));
    try testing.expectEqualStrings("1:00 AM ET", easternTime(&buf, fall, false));
    try testing.expectEqual(@as(i64, -4), easternOffsetHours(fall - 1));
    try testing.expectEqual(@as(i64, -5), easternOffsetHours(fall));
    // Another year's rule days: 2027-03-14 and 2027-11-07.
    try testing.expectEqual(@as(u32, 14), nthSunday(2027, 3, 2));
    try testing.expectEqual(@as(u32, 7), nthSunday(2027, 11, 1));
    try testing.expectEqual(@as(i64, 0), daysFromCivil(1970, 1, 1));
    try testing.expectEqualStrings("20261125T030600Z", utcStamp(&buf, t));
}

test "commits: abbreviations of one commit match, BUILD_INFO names its tree's commit" {
    try testing.expect(sameCommit("635d7dfd6", "635d7dfd6a1b2c"));
    try testing.expect(sameCommit("635d7dfd6\n", " 635d7dfd6"));
    try testing.expect(!sameCommit("635d7dfd6", "635d7dfd7"));
    try testing.expect(!sameCommit("635d7d", "635d7dfd6"));
    try testing.expect(!sameCommit("main", "main"));
    const info = "host=chat built on chat 2026-11-24 22:41:00 UTC zig=0.17.1-dev+77c319a0f0 v8=15.7.112.43 tree=lane/hard1-b e87fbe638, round 10's sequence";
    try testing.expect(mentionsCommit(info, "e87fbe638"));
    try testing.expect(mentionsCommit(info, "e87fbe6380abcdef"));
    try testing.expect(!mentionsCommit(info, "8d44f5f90"));
    // A run of hex digits inside a word is not a sha.
    try testing.expect(!mentionsCommit("xe87fbe638", "e87fbe638"));
}

test "SHA256SUMS lines, as shasum writes them" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const sha = "abababababababababababababababababababababababababababababababab";
    const sums = try parseSums(a, sha ++ "  repl\n" ++ sha ++ " *whatwg_snapshot.bin\n\n");
    try testing.expectEqual(@as(usize, 2), sums.len);
    try testing.expectEqualStrings("repl", sums[0].file);
    try testing.expectEqualStrings("whatwg_snapshot.bin", sums[1].file);
    try testing.expectError(error.BadSumsLine, parseSums(a, "nothex  repl\n"));
    try testing.expectError(error.BadSumsLine, parseSums(a, sha ++ "  ../repl\n"));
}

test "a dir's SHA256SUMS: every listed file matches and the required ones are listed" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = "wpt_runner", .data = "runner" });
    const dir = try tmp.dir.realPathFileAlloc(io, ".", a);
    var hex: [64]u8 = undefined;
    try sha256File(io, try std.fs.path.join(a, &.{ dir, "wpt_runner" }), &hex);
    // sha256("runner")
    try testing.expectEqualStrings("527aa9f431539da8e151d5434d1d5e611d973f601d8e970790882624554146b0", &hex);
    try tmp.dir.writeFile(io, .{ .sub_path = "SHA256SUMS", .data = try std.fmt.allocPrint(a, "{s}  wpt_runner\n", .{&hex}) });
    try testing.expectEqual(@as(?[]const u8, null), try sumsProblem(a, io, dir, &.{"wpt_runner"}));
    try testing.expect(std.mem.indexOf(u8, (try sumsProblem(a, io, dir, &.{ "wpt_runner", "wpt_ab" })).?, "does not cover wpt_ab") != null);
    try tmp.dir.writeFile(io, .{ .sub_path = "wpt_runner", .data = "another runner" });
    try testing.expect(std.mem.indexOf(u8, (try sumsProblem(a, io, dir, &.{"wpt_runner"})).?, "does not match") != null);
}
