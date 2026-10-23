//! The sfnt container: a font's table directory, and a collection's list of
//! fonts - checked as the OpenType Sanitizer checks them (OTS ots.cc
//! ProcessTTF, ProcessTTC and ProcessGeneric), which Blink and Gecko run on
//! every web font before using it. What OTS only warns about (a wrong
//! searchRange, entrySelector or rangeShift, tables out of tag order, a tag
//! that is not printable ASCII) is accepted here; what it fails, fails.

const std = @import("std");
const bytes = @import("bytes.zig");

pub const Error = error{ Corrupt, OutOfMemory };

const tag = bytes.tag;

/// OTS's ValidateVersionTag: TrueType outlines, CFF outlines, and Apple's
/// 'true' (read as TrueType).
pub fn isSfntVersion(version: u32) bool {
    return version == 0x00010000 or version == tag("OTTO") or version == tag("true");
}

/// One table of a face: its tag and its bytes.
pub const Table = struct {
    tag: u32,
    data: []const u8,
};

/// One face's tables. `tables` is OWNED by the allocator that made it; the
/// bytes they point at are the caller's.
pub const Face = struct {
    version: u32,
    tables: []Table,

    pub fn find(self: Face, wanted: u32) ?[]const u8 {
        // The last of duplicate tags wins, as OTS's table map keeps it.
        var found: ?[]const u8 = null;
        for (self.tables) |t| {
            if (t.tag == wanted) found = t.data;
        }
        return found;
    }

    pub fn deinit(self: *Face, allocator: std.mem.Allocator) void {
        allocator.free(self.tables);
        self.* = undefined;
    }
};

/// OTS rejects any file over 1 GiB "for sanity".
pub const max_file = 1 << 30;

/// The face whose offset table is at `offset` in `data` (0 for a single
/// font): ProcessTTF's directory, then ProcessGeneric's checks of it.
pub fn parseFace(allocator: std.mem.Allocator, data: []const u8, offset: u32) Error!Face {
    if (data.len > max_file) return error.Corrupt;
    if (offset > data.len) return error.Corrupt;
    var r = bytes.Reader.init(data[offset..]);
    const version = try r.u32_();
    if (!isSfntVersion(version)) return error.Corrupt;
    const num_tables = try r.u16_();
    // searchRange is (largest power of 2 <= numTables) * 16, so numTables
    // is at most 2^12; OTS fixes the three search fields and only warns.
    if (num_tables == 0 or num_tables >= 4096) return error.Corrupt;
    try r.skip(6);
    const records = try allocator.alloc(Record, num_tables);
    defer allocator.free(records);
    for (records) |*record| {
        record.tag = try r.u32_();
        _ = try r.u32_(); // checksum: not verified, as OTS does not
        record.offset = try r.u32_();
        record.length = try r.u32_();
    }
    // ProcessGeneric: `data_offset` is the directory's end within the face.
    try checkRecords(allocator, records, r.pos, data.len, .sfnt);
    const tables = try allocator.alloc(Table, num_tables);
    for (records, tables) |record, *table| {
        table.* = .{ .tag = record.tag, .data = data[record.offset..][0..record.length] };
    }
    return .{ .version = version, .tables = tables };
}

/// A directory record as the container gives it.
pub const Record = struct {
    tag: u32,
    offset: u32,
    length: u32,
    /// For WOFF, the decompressed length; for an sfnt, `length`.
    uncompressed_length: u32 = 0,
};

pub const Container = enum { sfnt, woff };

/// ProcessGeneric's checks of a directory's records: each table 4-byte
/// aligned, past the directory, inside the file, of non-zero length (a WOFF
/// table's compressed length no larger than its decompressed one, and that
/// at most 150 MiB, OTS_MAX_DECOMPRESSED_TABLE_SIZE), and no two tables
/// overlapping.
pub fn checkRecords(allocator: std.mem.Allocator, records: []const Record, data_offset: usize, length: usize, container: Container) Error!void {
    var uncompressed_sum: u64 = 0;
    for (records) |record| {
        if (record.offset & 3 != 0) return error.Corrupt;
        if (record.offset < data_offset or record.offset >= length) return error.Corrupt;
        if (record.length < 1 or record.length > max_file) return error.Corrupt;
        if (container == .woff) {
            if (record.uncompressed_length < record.length) return error.Corrupt;
            if (record.uncompressed_length > record.length) {
                if (record.uncompressed_length > 150 << 20) return error.Corrupt;
                uncompressed_sum += record.uncompressed_length;
            }
        }
        var end: u64 = @as(u64, record.offset) + record.length;
        // WOFF tables are 4-byte aligned, so their padding is theirs.
        if (container == .woff) end = bytes.round4(end);
        if (end == 0 or end > length) return error.Corrupt;
    }
    // OTS_MAX_DECOMPRESSED_FILE_SIZE.
    if (uncompressed_sum > 300 << 20) return error.Corrupt;

    // No overlap: sort the starts and ends, and count how many tables are
    // open at each point (an end sorts before a start at the same offset,
    // so adjacent tables do not overlap).
    const Edge = struct {
        at: u64,
        start: u1,
        fn less(_: void, a: @This(), b: @This()) bool {
            return a.at < b.at or (a.at == b.at and a.start < b.start);
        }
    };
    const edges = try allocator.alloc(Edge, records.len * 2);
    defer allocator.free(edges);
    for (records, 0..) |record, i| {
        edges[2 * i] = .{ .at = record.offset, .start = 1 };
        edges[2 * i + 1] = .{ .at = @as(u64, record.offset) + record.length, .start = 0 };
    }
    std.mem.sort(Edge, edges, {}, Edge.less);
    var open: i32 = 0;
    for (edges) |edge| {
        open += if (edge.start == 1) 1 else -1;
        if (open > 1) return error.Corrupt;
    }
}

/// The offsets of a collection's fonts (OTS ProcessTTC): 'ttcf', version
/// 1.0 or 2.0, at most 0x10000 fonts. OWNED by `allocator`.
pub fn collectionOffsets(allocator: std.mem.Allocator, data: []const u8) Error![]u32 {
    if (data.len > max_file) return error.Corrupt;
    var r = bytes.Reader.init(data);
    if (try r.u32_() != tag("ttcf")) return error.Corrupt;
    const version = try r.u32_();
    if (version != 0x00010000 and version != 0x00020000) return error.Corrupt;
    const num_fonts = try r.u32_();
    if (num_fonts > 0x10000) return error.Corrupt;
    // Each offset needs its four bytes before anything is allocated for it.
    if (r.remaining() / 4 < num_fonts) return error.Corrupt;
    const offsets = try allocator.alloc(u32, num_fonts);
    errdefer allocator.free(offsets);
    for (offsets) |*offset| offset.* = try r.u32_();
    // Version 2.0's DSIG fields: read past, not checked.
    if (version == 0x00020000) try r.skip(12);
    return offsets;
}

/// A standalone sfnt holding `face`'s tables: a header, a directory sorted
/// by tag, and each table 4-byte padded - what a platform's font engine
/// takes for one face of a collection. OWNED by `allocator`.
pub fn writeStandalone(allocator: std.mem.Allocator, face: Face) Error![]u8 {
    const sorted = try allocator.dupe(Table, face.tables);
    defer allocator.free(sorted);
    std.mem.sort(Table, sorted, {}, struct {
        fn less(_: void, a: Table, b: Table) bool {
            return a.tag < b.tag;
        }
    }.less);
    const directory_end: u64 = 12 + 16 * @as(u64, sorted.len);
    var total: u64 = directory_end;
    for (sorted) |t| total += bytes.round4(t.data.len);
    if (total > max_file) return error.Corrupt;
    const out = try allocator.alloc(u8, @intCast(total));
    @memset(out, 0);
    const n: u16 = @intCast(sorted.len);
    var power: u16 = 1;
    var log2: u16 = 0;
    while (power * 2 <= n) : (log2 += 1) power *= 2;
    std.mem.writeInt(u32, out[0..4], if (face.version == tag("OTTO")) tag("OTTO") else 0x00010000, .big);
    std.mem.writeInt(u16, out[4..6], n, .big);
    std.mem.writeInt(u16, out[6..8], power * 16, .big);
    std.mem.writeInt(u16, out[8..10], log2, .big);
    std.mem.writeInt(u16, out[10..12], n * 16 - power * 16, .big);
    var at: usize = @intCast(directory_end);
    for (sorted, 0..) |t, i| {
        const record = out[12 + 16 * i ..][0..16];
        std.mem.writeInt(u32, record[0..4], t.tag, .big);
        std.mem.writeInt(u32, record[4..8], checksum(t.data), .big);
        std.mem.writeInt(u32, record[8..12], @intCast(at), .big);
        std.mem.writeInt(u32, record[12..16], @intCast(t.data.len), .big);
        @memcpy(out[at..][0..t.data.len], t.data);
        at += @intCast(bytes.round4(t.data.len));
    }
    return out;
}

/// The OpenType table checksum: the sum of its big-endian u32s, zero-padded.
pub fn checksum(data: []const u8) u32 {
    var sum: u32 = 0;
    var i: usize = 0;
    while (i + 4 <= data.len) : (i += 4) sum +%= std.mem.readInt(u32, data[i..][0..4], .big);
    if (i < data.len) {
        var last = [_]u8{0} ** 4;
        @memcpy(last[0 .. data.len - i], data[i..]);
        sum +%= std.mem.readInt(u32, &last, .big);
    }
    return sum;
}

const testing = std.testing;

fn directory(comptime n: usize, entries: [n]Record, comptime total: usize) [total]u8 {
    var out = [_]u8{0} ** total;
    std.mem.writeInt(u32, out[0..4], 0x00010000, .big);
    std.mem.writeInt(u16, out[4..6], n, .big);
    for (entries, 0..) |e, i| {
        const rec = out[12 + 16 * i ..][0..16];
        std.mem.writeInt(u32, rec[0..4], e.tag, .big);
        std.mem.writeInt(u32, rec[8..12], e.offset, .big);
        std.mem.writeInt(u32, rec[12..16], e.length, .big);
    }
    return out;
}

test "a directory's tables: aligned, inside the file, past the directory, not empty, not overlapping" {
    const good = directory(2, .{ .{ .tag = tag("aaaa"), .offset = 44, .length = 4 }, .{ .tag = tag("bbbb"), .offset = 48, .length = 4 } }, 52);
    var face = try parseFace(testing.allocator, &good, 0);
    defer face.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 4), face.find(tag("bbbb")).?.len);
    try testing.expect(face.find(tag("cccc")) == null);

    const misaligned = directory(1, .{.{ .tag = tag("aaaa"), .offset = 30, .length = 4 }}, 52);
    try testing.expectError(error.Corrupt, parseFace(testing.allocator, &misaligned, 0));
    const inside_directory = directory(1, .{.{ .tag = tag("aaaa"), .offset = 16, .length = 4 }}, 52);
    try testing.expectError(error.Corrupt, parseFace(testing.allocator, &inside_directory, 0));
    const past_end = directory(1, .{.{ .tag = tag("aaaa"), .offset = 28, .length = 40 }}, 52);
    try testing.expectError(error.Corrupt, parseFace(testing.allocator, &past_end, 0));
    const empty = directory(1, .{.{ .tag = tag("aaaa"), .offset = 28, .length = 0 }}, 52);
    try testing.expectError(error.Corrupt, parseFace(testing.allocator, &empty, 0));
    const overlap = directory(2, .{ .{ .tag = tag("aaaa"), .offset = 44, .length = 8 }, .{ .tag = tag("bbbb"), .offset = 48, .length = 4 } }, 52);
    try testing.expectError(error.Corrupt, parseFace(testing.allocator, &overlap, 0));
    var no_tables = directory(0, .{}, 52);
    try testing.expectError(error.Corrupt, parseFace(testing.allocator, &no_tables, 0));
    no_tables[0] = 'X';
    try testing.expectError(error.Corrupt, parseFace(testing.allocator, &no_tables, 0));
}

test "a collection header: version, font count, offsets" {
    var ttc = [_]u8{0} ** 20;
    @memcpy(ttc[0..4], "ttcf");
    std.mem.writeInt(u32, ttc[4..8], 0x00010000, .big);
    std.mem.writeInt(u32, ttc[8..12], 2, .big);
    std.mem.writeInt(u32, ttc[12..16], 100, .big);
    std.mem.writeInt(u32, ttc[16..20], 200, .big);
    const offsets = try collectionOffsets(testing.allocator, &ttc);
    defer testing.allocator.free(offsets);
    try testing.expectEqualSlices(u32, &.{ 100, 200 }, offsets);
    std.mem.writeInt(u32, ttc[4..8], 0x00030000, .big);
    try testing.expectError(error.Corrupt, collectionOffsets(testing.allocator, &ttc));
    std.mem.writeInt(u32, ttc[4..8], 0x00010000, .big);
    std.mem.writeInt(u32, ttc[8..12], 0x10001, .big);
    try testing.expectError(error.Corrupt, collectionOffsets(testing.allocator, &ttc));
    std.mem.writeInt(u32, ttc[8..12], 3, .big);
    try testing.expectError(error.Corrupt, collectionOffsets(testing.allocator, &ttc));
}

test "checksum pads the last word with zeros" {
    try testing.expectEqual(@as(u32, 0x01020304 +% 0x05000000), checksum(&.{ 1, 2, 3, 4, 5 }));
}
